class_name ImpactsLances
extends RefCounted
## IMPACTS DES OBJETS LANCÉS (télékinésie, brief 2026-11-23 §2) : ce qui se passe quand un objet lancé touche quelque chose.
##   ImpactsLances.objet_touche(objet, cible, point, normale, vitesse, lanceur)    contrat avec la branche télékinésie
##   ImpactsLances.suivre(objet, lanceur)        facultatif : détection des contacts par balayage de la forme (SuiviLancer), qui
##                                               appelle objet_touche ; sert au lanceur de test et après une traversée
##   ImpactsLances.arracher(objet, giclee)       retire une arme plantée (re-saisie par télékinésie, reprise à la main)
## Règles :
## - OBJET quelconque : dégâts contondants selon l'énergie ½·m·v² (28 × √(E/1000 J), bornés 2..38 : un tonneau à 12 m/s ≈ un coup
##   lourd d'épée), déséquilibre selon la quantité de mouvement m·v (tonneau ≥ 110 kg·m/s : renversé ; ≥ 150 : tué = projeté loin),
##   puis Cassable.recevoir_choc sur l'objet ET sur ce qu'il percute ;
## - ARME (objet.donnees_arme() non nul) arrivée pointe en avant (≤ 44° de la trajectoire ; hache : le fil en avant) à ≥ 9 m/s : elle
##   SE PLANTE (accrochée à l'os touché par un RemoteTransform3D : suit l'animation et le ragdoll, reste dans le cadavre) ; dégâts =
##   dégâts lourds de l'arme × 1,2 × (v / 16 m/s, borné 0,6..1,3). Énergie ≥ 480 J × poids de la cible (× 0,7 si le coup tue) : elle
##   TRAVERSE (dégâts × 1,35), ressort derrière avec la vitesse restante et va se ficher dans le mur / sol / ennemi suivant ;
##   du plat, trop lente ou contondante (masse, marteau, bouclier) : rebond et dégâts contondants réduits ;
## - sang à l'entrée (CombatEnnemi.effets_impact) ET à la sortie (giclée dans le sens du vol, plaie), gouttes qui tombent de la plaie
##   d'une arme plantée, trace sur le mur où se fiche une lame ensanglantée ; squelette : éclats d'os, pas de sang ; draugr : son sang
##   noirci (ProfilCible.couleur_sang) ;
## - interrupteur `--sans-armes-plantees` : les armes se comportent comme des objets quelconques (rebond, dégâts selon l'énergie).
## Réseau : les dégâts passent par DegatsCombat.appliquer → recevoir_coup (marionnette → l'hôte valide, CombatCoop) ; plantage dans un
## corps / un mur = événements « lance_plante » / « lance_plante_mur » (copie visuelle de l'arme plantée chez les autres).

const V_MIN_PLANTER := 9.0
const COS_PLANTER := 0.72          # pointe à moins de ~44° de la trajectoire
const COS_FIL_HACHE := 0.6         # hache : le fil (+X du modèle) en avant
const SEUIL_TRAVERSEE := 480.0     # J (× ProfilCible.poids)
const PART_TRAVERSEE_MORT := 0.7   # un coup qui tue traverse plus facilement
const BONUS_LANCER := 1.2
const V_REF_ARME := 16.0
const MULT_TRAVERSEE := 1.35
const E_REF_OBJET := 1000.0
const DEGATS_OBJET := Vector2(2.0, 38.0)
const P_RENVERSER := 110.0         # kg·m/s
const P_PROJETER := 150.0
const V_RESTE_MIN := 9.0
const FAMILLES_CONTONDANTES := ["masse", "marteau", "bouclier"]
## Masse réelle (kg) d'une arme lancée, par famille (DonneesArme.poids est un poids d'inventaire).
const MASSES := {"dague": 0.5, "une_main": 1.3, "epee_longue": 1.6, "deux_mains": 3.0, "masse": 2.0, "marteau": 2.6, "bouclier": 4.0}
const EV_PLANTE := "lance_plante"
const EV_MUR := "lance_plante_mur"
const EV_CLOUE := "lance_cloue"
const MUR_MAX := 3.0               # m derrière la sortie : un mur plus loin ne cloue pas
## Clouage au mur d'un ennemi tué (désactivable pour comparer).
static var clouage_actif := true
## Os du squelette (Plaies) → os physique du ragdoll qui le porte.
const OS_RAGDOLL := {"spine_02": "spine_01", "neck_01": "spine_03"}
const CALQUE_PLANTEE := 64         # Cassable.CALQUE : visible des sorts / de la visée, franchissable par le joueur et les PNJ

static var _option := -1
## Dernier impact traité (tests, vidéo) : {issue: "plantee"|"traverse"|"rebond"|"objet"|"mur"|"bloque", degats, resultat, energie, ...}.
static var dernier := {}
static var _reseau_pret := false

static func armes_plantees() -> bool:
	if _option < 0:
		_option = 0 if OS.get_cmdline_user_args().has("--sans-armes-plantees") else 1
	return _option == 1

## Forcer l'interrupteur (tests) : true / false.
static func regler(actif: bool) -> void:
	_option = 1 if actif else 0

# ------------------------------------------------------------------------------------------------ contrat

static func objet_touche(objet: RigidBody3D, cible: Node, point: Vector3, normale: Vector3, vitesse: Vector3, lanceur: Node) -> void:
	if objet == null or not is_instance_valid(objet) or not objet.is_inside_tree() or objet.has_meta("plantee"):
		return
	var v := vitesse.length()
	if v < 0.5:
		return
	_installer_reseau()
	var dir := vitesse / v
	var ennemi := _ennemi_de(cible, lanceur)
	# même objet, même cible, dans le même instant (détection de la télékinésie + SuiviLancer) : une seule fois
	var cle := ennemi.get_instance_id() if ennemi != null else (cible.get_instance_id() if cible != null else 0)
	var t := Time.get_ticks_msec()
	if int(objet.get_meta("impact_cle", -1)) == cle and t - int(objet.get_meta("impact_t", 0)) < 250:
		return
	objet.set_meta("impact_cle", cle)
	objet.set_meta("impact_t", t)
	var masse := masse_de(objet)
	var arme: DonneesArme = null
	if armes_plantees() and objet.has_method("donnees_arme"):
		arme = objet.donnees_arme() as DonneesArme
	if ennemi == null:
		_toucher_decor(objet, cible, point, normale, vitesse, arme, masse, lanceur)
		return
	if ennemi.has_method("vivant") and not bool(ennemi.vivant()):
		# cadavre : une lame s'y fiche encore (sans dégâts), le reste rebondit sur le ragdoll
		if arme != null and _pointe_en_avant(objet, arme, dir) and v >= V_MIN_PLANTER:
			planter_corps(objet, ennemi, point, dir, v, _profil(ennemi), true)
			dernier = {"issue": "plantee", "degats": 0.0, "resultat": "cadavre", "ennemi": ennemi, "energie": 0.5 * masse * v * v}
		return
	if arme != null and arme.famille not in FAMILLES_CONTONDANTES and _pointe_en_avant(objet, arme, dir) and v >= V_MIN_PLANTER:
		_arme_dans_corps(objet, ennemi, point, normale, dir, v, masse, arme, lanceur)
	elif arme != null:
		_arme_rebond(objet, ennemi, point, normale, dir, v, masse, arme, lanceur)
	else:
		_objet_dans_corps(objet, ennemi, point, normale, dir, v, masse, lanceur)

## Détection des contacts d'un objet lancé par balayage de sa forme le long de sa vitesse (SuiviLancer) : appelle objet_touche avant que
## le moteur ne fasse rebondir l'objet. Facultatif pour la télékinésie (elle peut appeler objet_touche elle-même) ; idempotent.
static func suivre(objet: RigidBody3D, lanceur: Node, duree := 4.0) -> SuiviLancer:
	var s := objet.get_node_or_null("SuiviLancer") as SuiviLancer
	if s == null:
		s = SuiviLancer.new()
		s.name = "SuiviLancer"
		objet.add_child(s)
	s.objet = objet
	s.lanceur = lanceur
	if lanceur != null and not objet.has_meta("lance_par"):
		objet.set_meta("lance_par", lanceur)
	s.duree = duree
	s.t = 0.0
	return s

static func masse_de(objet: RigidBody3D) -> float:
	if objet.has_method("masse_telekinesie"):
		return maxf(float(objet.masse_telekinesie()), 0.05)
	return maxf(objet.mass, 0.05)

static func masse_arme(d: DonneesArme) -> float:
	if d == null:
		return 1.3
	return float(MASSES.get(d.famille, clampf(d.poids * 0.3, 0.4, 4.0)))

# ------------------------------------------------------------------------------------------------ ennemis

static func _ennemi_de(n: Node, lanceur: Node) -> Node3D:
	var c := n
	for i in 10:
		if c == null:
			return null
		if c == lanceur:
			return null
		if c is Node3D and c.has_method("recevoir_coup"):
			return c as Node3D
		c = c.get_parent()
	return null

static func _profil(ennemi: Node) -> ProfilCible:
	var c: Variant = ennemi.get("combat")
	if c is CombatEnnemi and (c as CombatEnnemi).profil != null:
		return (c as CombatEnnemi).profil
	var p: Variant = ennemi.get("profil")
	return p as ProfilCible if p is ProfilCible else null

static func _modele(ennemi: Node) -> Node3D:
	var m: Variant = ennemi.get("modele")
	return m as Node3D if m is Node3D else ennemi as Node3D

static func _couleur(p: ProfilCible) -> Color:
	return p.couleur_sang if p != null else Color(0.3, 0.03, 0.025)

static func _saigne(p: ProfilCible) -> bool:
	return p != null and p.sang and Sang.actif()

static func _os(p: ProfilCible) -> bool:
	return p != null and p.matiere == "os"

static func _vie(ennemi: Node) -> float:
	var v: Variant = ennemi.get("vie")
	return float(v) if v != null else 999.0

# ------------------------------------------------------------------------------------------------ géométrie de l'arme

## Pommeau (ou garde) et pointe de l'arme, en repère MONDE : nœuds « prise » / « garde » et « pointe » du modèle (armes du catalogue),
## sinon objet.axe_arme() -> [a, b] (repère de l'objet), sinon DonneesArme.garde / pointe dans le repère de l'objet.
static func axe_monde(objet: Node3D, d: DonneesArme) -> Array:
	if objet.has_method("axe_arme"):
		var ab: Array = objet.axe_arme()
		return [objet.global_transform * Vector3(ab[0]), objet.global_transform * Vector3(ab[1])]
	var po := objet.find_child("pointe", true, false) as Node3D
	var pr := objet.find_child("prise", true, false) as Node3D
	if pr == null:
		pr = objet.find_child("garde", true, false) as Node3D
	if po != null and pr != null:
		return [pr.global_position, po.global_position]
	var g := d.garde if d != null else Vector3(0, 0.1, 0)
	var p := d.pointe if d != null else Vector3(0, 0.84, 0)
	return [objet.global_transform * g, objet.global_transform * p]

static func _pointe_en_avant(objet: Node3D, d: DonneesArme, dir: Vector3) -> bool:
	var ab := axe_monde(objet, d)
	var axe: Vector3 = (Vector3(ab[1]) - Vector3(ab[0])).normalized()
	if axe.dot(dir) >= COS_PLANTER:
		return true
	if _hache(d):
		# hache : le fer arrive en premier, fil (+X du modèle) en avant
		var fil := objet.global_basis.x.normalized()
		var tete_devant := (Vector3(ab[1]) - objet.global_position).dot(dir) > 0.0
		return tete_devant and fil.dot(dir) >= COS_FIL_HACHE
	return false

static func _hache(d: DonneesArme) -> bool:
	return d != null and (d.id.contains("hache") or d.nom.to_lower().contains("hache"))

# ------------------------------------------------------------------------------------------------ arme dans un corps

static func _arme_dans_corps(objet: RigidBody3D, ennemi: Node3D, point: Vector3, normale: Vector3, dir: Vector3, v: float, masse: float, arme: DonneesArme, lanceur: Node) -> void:
	var p := _profil(ennemi)
	var e := 0.5 * masse * v * v
	var seuil := SEUIL_TRAVERSEE * maxf(p.poids if p != null else 1.0, 0.4)
	if p != null and (p.armure >= 2.0 or p.armure_part >= 0.06):
		seuil *= 1.25     # mailles : la lame passe moins facilement
	var degats := arme.degats_lourd * BONUS_LANCER * clampf(v / V_REF_ARME, 0.6, 1.3)
	var tue_probable := degats * MULT_TRAVERSEE >= _vie(ennemi)
	var traverse := e >= seuil or (tue_probable and e >= seuil * PART_TRAVERSEE_MORT)
	if traverse:
		degats *= MULT_TRAVERSEE
	var hache := _hache(arme)
	# le contact arrive sur la capsule de l'ennemi (0,38 m de rayon) : le vrai point d'entrée est sur le corps, le long du vol
	var vc := visee_corps(ennemi, point, dir)
	if bool(vc["frole"]):
		# la lame passe à côté du corps (contact sur le bord de la capsule) : elle continue son vol
		if ennemi is PhysicsBody3D:
			objet.add_collision_exception_with(ennemi)
		objet.linear_velocity = dir * v
		suivre(objet, lanceur, 2.0).ignorer(ennemi)
		dernier = {"issue": "frole", "degats": 0.0, "resultat": "", "energie": e, "ennemi": ennemi}
		return
	point = vc["entree"]
	var info := {"type": "tranchant", "point": point, "direction": dir, "normale": normale if normale.length() > 0.1 else -dir,
		"zone": DegatsCombat.zone(ennemi, point), "attaque": "lourde", "arme_lancee": arme.id, "lancer": true,
		"stagger": 14.0 + 0.6 * masse * v, "collider": ennemi, "affaibli": false, "charge": 0.0, "instant": 0.0}
	var res := DegatsCombat.appliquer(ennemi, degats, point - dir * 2.0, traverse, info)
	dernier = {"issue": "traverse" if traverse else "plantee", "degats": degats, "resultat": res, "energie": e, "seuil": seuil, "ennemi": ennemi,
		"hache": hache}
	if res == "bloque":
		dernier["issue"] = "bloque"
		GerbePixels.emettre(ennemi, point, (normale - dir * 0.3).normalized(), "etincelles", 1.0)
		objet.linear_velocity = (dir.bounce(normale.normalized() if normale.length() > 0.1 else -dir) * 0.3 + Vector3.UP * 1.5)
		objet.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		return
	if _os(p):
		EclatsOs.lancer(ennemi, point, (dir * 0.6 + Vector3.UP * 0.8).normalized(), 3 if traverse else 2, 0.9)
		RetourImpact.son(ennemi, "os_brise", point, -2.0)
	elif _saigne(p):
		RetourImpact.son(ennemi, "dechirure", point, -3.0)
	# tué avec un mur derrière (≤ 3 m dans l'axe du vol) : la lame reste dans le corps et le CLOUE au mur (« brochette »)
	if res == "tue" and clouage_actif:
		var mur := _mur_derriere(objet, ennemi, vc["sortie"], dir)
		if not mur.is_empty() and _clouer(objet, ennemi, point, dir, v, p, vc, mur):
			return
	if traverse:
		_traverser(objet, ennemi, point, dir, v, masse, e, seuil, p, lanceur, vc)
	else:
		planter_corps(objet, ennemi, point, dir, v, p, false, true, vc)

## Arme fichée dans un corps : accrochée à l'os le plus proche (Plaies : BoneAttachment3D qui suit animation et ragdoll) par un
## RemoteTransform3D (l'arme reste dans le monde : si le cadavre est retiré, elle tombe au sol au lieu de disparaître avec lui).
static func planter_corps(objet: RigidBody3D, ennemi: Node3D, point: Vector3, dir: Vector3, v: float, p: ProfilCible, cadavre: bool, reseau := true, vc := {}, prof_force := -1.0) -> void:
	if vc.is_empty():
		vc = visee_corps(ennemi, point, dir)
		point = vc["entree"]
	var accroche: Node3D = vc.get("accroche") if vc.get("accroche") != null else ennemi
	var os := String(vc.get("os", ""))
	var d: DonneesArme = objet.donnees_arme() if objet.has_method("donnees_arme") else null
	var ab := axe_monde(objet, d)
	var axe: Vector3 = (Vector3(ab[1]) - Vector3(ab[0])).normalized()
	var longueur: float = Vector3(ab[0]).distance_to(Vector3(ab[1]))
	# orientation : la lame se redresse vers la trajectoire (60 %), comme une lame qui entre droit
	var nouvel := axe.slerp(dir, 0.6).normalized()
	var b := Basis(Quaternion(axe, nouvel)) * objet.global_basis
	# profondeur : la pointe passe juste au-delà de l'axe de l'os touché (elle est DANS le corps, sans ressortir), la garde reste dehors
	var prof := float(vc.get("vers_axe", 0.14)) + clampf(0.03 + 0.05 * v / 20.0, 0.03, 0.08)
	prof = clampf(prof, 0.08, minf(longueur * 0.6, float(vc.get("vers_axe", 0.14)) + float(vc.get("rayon", 0.15)) * 0.8))
	if prof_force > 0.0:
		prof = minf(prof_force, longueur * 0.85)
	var pointe_loc := objet.global_transform.affine_inverse() * Vector3(ab[1])
	var xf := Transform3D(b, Vector3.ZERO)
	xf.origin = point + dir * prof - b * pointe_loc
	_figer(objet, xf)
	var rt := RemoteTransform3D.new()
	rt.name = "ArmePlantee"
	rt.update_scale = false
	accroche.add_child(rt)
	rt.global_transform = xf
	rt.remote_path = rt.get_path_to(objet)
	var couleur := _couleur(p)
	var sang := _saigne(p)
	objet.set_meta("plantee", {"dans": weakref(ennemi), "os": os, "rt": rt, "sang": sang, "couleur": couleur, "os_matiere": _os(p)})
	if sang:
		objet.set_meta("ensanglantee", couleur)
	var pl := Plantage.new()
	pl.name = "Plantage"
	pl.objet = objet
	pl.rt = rt
	pl.sang = sang and not cadavre
	pl.couleur = Plaies.sang_couleur_goutte(couleur) if sang else couleur
	pl.entree_local = xf.affine_inverse() * point
	objet.add_child(pl)
	objet.add_to_group("armes_plantees")
	if objet.has_method("sur_plantee"):
		objet.sur_plantee(ennemi)
	RetourImpact.son(ennemi, "os" if _os(p) else "chair_gore", point, -1.0, 0.85)
	if reseau and CombatCoop.en_ligne() and ennemi.get("ident") != null:
		var local := accroche.global_transform.affine_inverse() * xf
		CombatCoop.R().envoyer_evenement(EV_PLANTE, CombatCoop.id_de(ennemi), {"os": os, "xf": _xf_vers(local), "arme": d.id if d else "", "sang": sang})
	dernier["prof"] = prof

## Demi-épaisseur du corps autour de chaque os (m) : où la lame entre / ressort.
const RAYONS_OS := {"Head": 0.11, "neck_01": 0.07, "spine_03": 0.15, "spine_02": 0.14, "spine_01": 0.14, "pelvis": 0.15,
	"upperarm_l": 0.06, "upperarm_r": 0.06, "lowerarm_l": 0.05, "lowerarm_r": 0.05, "thigh_l": 0.08, "thigh_r": 0.08, "calf_l": 0.06, "calf_r": 0.06}

## Trajet d'une lame dans le corps : le vol (point de contact sur la capsule, direction) croise l'os le plus proche (tronc préféré
## aux membres) → {accroche, os, entree (sur la peau), vers_axe (m de l'entrée à l'axe de l'os), rayon, sortie (peau opposée),
## frole (le vol passe à côté du corps)}. Sans squelette : un cylindre de 0,15 m autour de l'axe vertical de l'ennemi.
static func visee_corps(ennemi: Node3D, point: Vector3, dir: Vector3) -> Dictionary:
	var modele := _modele(ennemi)
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D if modele != null else null
	if sq != null:
		Plaies.preparer(modele)
	var echelle := 1.0
	if ennemi.get("echelle") != null:
		echelle = maxf(float(ennemi.get("echelle")), 0.3)
	var meilleur: Node3D = null
	var best := {}
	var dmin := INF
	if modele != null and modele.has_meta("plaies_accroches"):
		for a: BoneAttachment3D in modele.get_meta("plaies_accroches"):
			if not is_instance_valid(a):
				continue
			var o := a.global_position
			var c := _plus_proche_segment(o, o + a.global_basis.y.normalized() * float(Plaies.LONGUEUR.get(a.bone_name, 0.26)) * echelle, point, dir)
			var t := (c - point).dot(dir)
			var q := point + dir * t
			var dp := c.distance_to(q)
			var r := float(RAYONS_OS.get(a.bone_name, 0.08)) * echelle
			var score := (dp - r) * (1.6 if a.bone_name in OS_MEMBRES else 1.0)
			if t > -0.1 and score < dmin:
				dmin = score
				meilleur = a
				best = {"t": t, "dp": dp, "r": r, "os": a.bone_name}
	if meilleur == null:
		var axe_o := ennemi.global_position
		var c2 := _plus_proche_segment(axe_o, axe_o + Vector3.UP * 1.8 * echelle, point, dir)
		var t2 := (c2 - point).dot(dir)
		best = {"t": t2, "dp": c2.distance_to(point + dir * t2), "r": 0.15 * echelle, "os": ""}
	var r: float = best["r"]
	var dp: float = best["dp"]
	var demi := sqrt(maxf(r * r - dp * dp, r * r * 0.15))
	var t: float = maxf(float(best["t"]), 0.0)
	var entree := point + dir * maxf(t - demi, 0.0)
	return {"accroche": meilleur, "os": String(best["os"]), "entree": entree, "vers_axe": t - maxf(t - demi, 0.0), "rayon": r,
		"sortie": point + dir * (t + demi), "frole": dp > r + 0.14 * echelle}

## Os (accroche de Plaies, suit animation et ragdoll) qui porte une arme fichée en `point` : le plus proche, le tronc préféré aux
## membres (un bras qui passe devant le torse ne doit pas emporter la lame plantée dans la poitrine).
const OS_MEMBRES := ["upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]
static func accroche_os(modele: Node3D, point: Vector3) -> BoneAttachment3D:
	if modele == null or not modele.has_meta("plaies_accroches"):
		return null
	var meilleur: BoneAttachment3D = null
	var dmin := INF
	for a: BoneAttachment3D in modele.get_meta("plaies_accroches"):
		if not is_instance_valid(a):
			continue
		var o := a.global_position
		var c := _plus_proche_segment(o, o + a.global_basis.y.normalized() * float(Plaies.LONGUEUR.get(a.bone_name, 0.26)), point, Vector3.ZERO)
		var dist := point.distance_to(c) * (1.8 if a.bone_name in OS_MEMBRES else 1.0)
		if dist < dmin:
			dmin = dist
			meilleur = a
	return meilleur

static func _plus_proche_segment(a: Vector3, b: Vector3, p: Vector3, dir: Vector3) -> Vector3:
	# point du segment [a, b] le plus proche de la droite (p, dir)
	var u := b - a
	var w := a - p
	var aa := u.dot(u)
	var bb := u.dot(dir)
	var dd := u.dot(w)
	var ee := dir.dot(w)
	var den := aa - bb * bb
	var s := clampf((bb * ee - dd) / den, 0.0, 1.0) if absf(den) > 1e-6 else 0.0
	return a + u * s

## Traversée : sang de sortie (giclée dans le sens du vol, plaie, gouttes), l'arme repart de l'autre côté avec la vitesse restante,
## nez dans le vol (SuiviLancer.stabiliser), et se fiche dans ce qu'elle rencontre ensuite.
static func _traverser(objet: RigidBody3D, ennemi: Node3D, point: Vector3, dir: Vector3, v: float, masse: float, e: float, seuil: float, p: ProfilCible, lanceur: Node, vc := {}) -> void:
	var modele := _modele(ennemi)
	if vc.is_empty():
		vc = visee_corps(ennemi, point, dir)
	var sortie: Vector3 = vc["sortie"]
	var couleur := _couleur(p)
	if _saigne(p):
		Sang.giclee(ennemi, sortie, (dir + Vector3.UP * 0.08).normalized(), 3.2, couleur)
		Sang.giclee(ennemi, sortie + dir * 0.1, dir, 1.6, couleur, false)
		Plaies.ajouter(modele, sortie, dir, dir, 0.45, couleur, p.matiere)
		var g := Plaies.sang_couleur_goutte(couleur)
		for i in 7:
			var jit := Vector3(randf_range(-0.06, 0.06), randf_range(-0.05, 0.05), randf_range(-0.06, 0.06))
			GouttesSang.lacher(ennemi, sortie + dir * (0.05 * i) + jit, g, dir * v * randf_range(0.12, 0.3) + Vector3.UP * randf_range(0.2, 1.2), true)
		objet.set_meta("ensanglantee", couleur)
		RetourImpact.son(ennemi, "giclee", sortie, -2.0)
	elif _os(p):
		EclatsOs.lancer(ennemi, sortie, (dir + Vector3.UP * 0.4).normalized(), 4, 1.2)
		Sang.eclats_matiere(ennemi, sortie, dir, 1.4, couleur)
	else:
		Sang.eclats_matiere(ennemi, sortie, dir, 1.0, couleur)
	var v_reste := minf(sqrt(maxf(2.0 * (e - seuil * 0.55) / masse, V_RESTE_MIN * V_RESTE_MIN)), v * 0.8)
	if ennemi is PhysicsBody3D:
		objet.add_collision_exception_with(ennemi)
	# l'arme ressort : pointe juste devant la sortie, nez dans le vol
	var d: DonneesArme = objet.donnees_arme() if objet.has_method("donnees_arme") else null
	var ab := axe_monde(objet, d)
	var axe: Vector3 = (Vector3(ab[1]) - Vector3(ab[0])).normalized()
	var b := Basis(Quaternion(axe, axe.slerp(dir, 0.85).normalized())) * objet.global_basis
	var pointe_loc := objet.global_transform.affine_inverse() * Vector3(ab[1])
	var xf := Transform3D(b, Vector3.ZERO)
	xf.origin = sortie + dir * 0.08 - b * pointe_loc
	objet.global_transform = xf
	objet.linear_velocity = dir * v_reste
	objet.angular_velocity = Vector3.ZERO
	objet.set_meta("traverse", weakref(ennemi))
	var s := suivre(objet, lanceur, 3.0)
	s.stabiliser = true
	s.ignorer(ennemi)
	dernier["sortie"] = sortie
	dernier["v_reste"] = v_reste

static func _arme_rebond(objet: RigidBody3D, ennemi: Node3D, point: Vector3, normale: Vector3, dir: Vector3, v: float, masse: float, arme: DonneesArme, lanceur: Node) -> void:
	var e := 0.5 * masse * v * v
	var contondante := arme.famille in FAMILLES_CONTONDANTES
	point = visee_corps(ennemi, point, dir)["entree"]
	# arme contondante (masse, marteau) : ses dégâts ; une lame de plat : le tiers de son coup léger + l'énergie
	var degats := (arme.degats_lourd * BONUS_LANCER * clampf(v / V_REF_ARME, 0.5, 1.25)) if contondante and v >= V_MIN_PLANTER \
		else (arme.degats_leger * 0.35 * clampf(v / V_REF_ARME, 0.4, 1.2) + _degats_energie(e) * 0.3)
	var info := {"type": "contondant", "point": point, "direction": dir, "normale": normale if normale.length() > 0.1 else -dir,
		"zone": DegatsCombat.zone(ennemi, point), "attaque": "lourde" if contondante else "legere", "arme_lancee": arme.id, "lancer": true,
		"stagger": 6.0 + 0.45 * masse * v, "collider": ennemi, "affaibli": false, "charge": 0.0, "instant": 0.0}
	var res := DegatsCombat.appliquer(ennemi, degats, point - dir * 2.0, contondante and masse * v > 60.0, info)
	dernier = {"issue": "rebond", "degats": degats, "resultat": res, "energie": e, "ennemi": ennemi}
	var n := normale.normalized() if normale.length() > 0.1 else -dir
	objet.linear_velocity = dir.bounce(n) * v * 0.25 + Vector3.UP * 1.2
	objet.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	RetourImpact.son(ennemi, "metal_blocage", point, -6.0, 1.1)

# ------------------------------------------------------------------------------------------------ clouage au mur

## Mur (corps fixe) derrière la sortie, dans l'axe du vol, à moins de MUR_MAX : {point, normale, collider} ou {}.
static func _mur_derriere(objet: RigidBody3D, ennemi: Node3D, sortie: Vector3, dir: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(sortie - dir * 0.05, sortie + dir * MUR_MAX, 1)
	var ex: Array[RID] = [objet.get_rid()]
	if ennemi is CollisionObject3D:
		ex.append((ennemi as CollisionObject3D).get_rid())
	q.exclude = ex
	var r := objet.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {}
	var c: Object = r["collider"]
	var n: Vector3 = r["normal"]
	if not (c is StaticBody3D or c is CSGShape3D) or dir.dot(-n) < 0.4:
		return {}
	return r

static func _ragdoll_de(ennemi: Node) -> Ragdoll:
	var rd: Variant = ennemi.get("_ragdoll")
	if rd is Ragdoll and is_instance_valid(rd):
		return rd
	var m := _modele(ennemi)
	return m.get_node_or_null("Ragdoll") as Ragdoll if m != null else null

static func os_ragdoll(rd: Ragdoll, os: String) -> String:
	if rd.os.has(os):
		return os
	var o := String(OS_RAGDOLL.get(os, ""))
	if rd.os.has(o):
		return o
	return "spine_03" if rd.os.has("spine_03") else ""

## « Brochette » : l'arme traverse le corps et le cloue au mur. Elle est plantée dans l'os traversé (pointe 12 cm hors du dos), l'os
## physique du ragdoll devient CINÉMATIQUE et glisse avec elle jusqu'au mur (Clouage), où il reste fixé : le reste du corps pend
## (articulations du ragdoll), se balance puis s'endort (Ragdoll.endormir_apres). Renvoie false s'il n'y a pas de ragdoll.
static func _clouer(objet: RigidBody3D, ennemi: Node3D, point: Vector3, dir: Vector3, v: float, p: ProfilCible, vc: Dictionary, mur: Dictionary) -> bool:
	var rd := _ragdoll_de(ennemi)
	if rd == null or not rd.actif:
		return false
	var nom := os_ragdoll(rd, String(vc.get("os", "")))
	if nom == "":
		return false
	var pb: PhysicalBone3D = rd.os[nom]
	var epaisseur := maxf((Vector3(vc["sortie"]) - point).dot(dir), 0.1)
	var prof := epaisseur + 0.12
	planter_corps(objet, ennemi, point, dir, v, p, false, false, vc, prof)
	var w: Vector3 = mur["position"]
	var n: Vector3 = mur["normal"]
	# translation qui amène la pointe 10 cm dans le mur (le dos du corps arrive contre la paroi)
	var pointe := point + dir * prof
	var delta := (w + dir * 0.1) - pointe
	var c := Clouage.new()
	c.name = "Clouage"
	c.rd = rd
	c.pb = pb
	c.depart = pb.global_transform
	c.delta = delta
	c.vitesse = clampf(v * 0.5, 6.0, 14.0)
	c.mur = w
	c.normale = n
	c.dir = dir
	c.couleur = _couleur(p)
	c.sang = _saigne(p)
	c.os_matiere = _os(p)
	c.objet = objet
	ennemi.add_child(c)
	PhysicsServer3D.body_set_mode(pb.get_rid(), PhysicsServer3D.BODY_MODE_KINEMATIC)
	pb.linear_velocity = Vector3.ZERO
	pb.angular_velocity = Vector3.ZERO
	rd.endormir_apres(3.5)
	objet.set_meta("cloue", {"dans": weakref(ennemi), "os": nom, "mur": w})
	dernier["issue"] = "cloue"
	dernier["os_cloue"] = nom
	dernier["mur"] = w
	dernier["cible_os"] = c.depart.origin + delta
	dernier["clouage"] = c
	if CombatCoop.en_ligne() and ennemi.get("ident") != null:
		var d: DonneesArme = objet.donnees_arme() if objet.has_method("donnees_arme") else null
		CombatCoop.R().envoyer_evenement(EV_CLOUE, CombatCoop.id_de(ennemi), {"os": nom, "os_arme": String(vc.get("os", "")),
			"xf_os": _xf_vers(Transform3D(c.depart.basis, c.depart.origin + delta)), "xf_arme": _xf_vers(Transform3D(objet.global_basis, objet.global_position + delta)),
			"arme": d.id if d else "", "mur": [w.x, w.y, w.z], "n": [n.x, n.y, n.z], "sang": c.sang})
	return true

## Nœud du clouage (enfant de l'ennemi) : glisse l'os cinématique jusqu'au mur, puis l'y tient ; impact au mur (son, étincelles, sang
## qui coule sous le corps, flaque au pied).
class Clouage extends Node:
	var rd: Ragdoll
	var pb: PhysicalBone3D
	var depart := Transform3D.IDENTITY
	var delta := Vector3.ZERO
	var vitesse := 10.0
	var mur := Vector3.ZERO
	var normale := Vector3.BACK
	var dir := Vector3.FORWARD
	var couleur := Color(0.3, 0.03, 0.025)
	var sang := true
	var os_matiere := false
	var objet: RigidBody3D
	var arrive := false
	var _t := 0.0
	var _tenu := 0.0

	func _ready() -> void:
		process_physics_priority = -5

	func cible() -> Vector3:
		return depart.origin + delta

	func _physics_process(dt: float) -> void:
		if not is_instance_valid(pb) or not is_instance_valid(rd):
			queue_free()
			return
		_t += dt
		var k := clampf(_t * vitesse / maxf(delta.length(), 0.01), 0.0, 1.0)
		var xf := Transform3D(depart.basis, depart.origin + delta * k)
		if rd.est_fige():
			set_physics_process(false)
			return
		pb.global_transform = xf
		PhysicsServer3D.body_set_state(pb.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		if k >= 1.0 and not arrive:
			arrive = true
			_au_mur()
		if arrive:
			_tenu += dt

	func _au_mur() -> void:
		var n := normale
		RetourImpact.son(pb, "pierre", mur, -1.0, 0.9)
		RetourImpact.son(pb, "metal_blocage", mur, -7.0, 0.75)
		RetourImpact.son(pb, "os" if os_matiere else "chair_gore", mur, -3.0, 0.8)
		GerbePixels.emettre(pb, mur, (n * 0.8 - dir * 0.2).normalized(), "etincelles", 0.6)
		GerbePixels.emettre(pb, mur, n, "poussiere", 0.7)
		if os_matiere:
			EclatsOs.lancer(pb, mur + n * 0.15, (n + Vector3.UP * 0.5).normalized(), 3, 0.8)
		if not sang or not Sang.actif():
			return
		var bas := Vector3.DOWN - n * Vector3.DOWN.dot(n)
		var d := bas.normalized() if bas.length() > 0.2 else Vector3.DOWN
		Sang.trace(pb, mur + n * 0.004, n, d, 0.32, couleur, "giclure")
		# coulure qui descend du point d'impact sous le corps, puis flaque au pied du mur
		Sang.trace(pb, mur + n * 0.005 + d * 0.35, n, d, 0.55, couleur, "trainee", 2.5, 0.4)
		var g := Plaies.sang_couleur_goutte(couleur)
		for i in 5:
			GouttesSang.lacher(pb, mur + n * 0.06 + d * randf_range(0.1, 0.4) + Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.05, 0.05)), g, Vector3.ZERO, true)
		var sol := Sang.sol_sous(pb, mur + n * 0.3, 0.2, 3.0)
		if not sol.is_empty():
			Sang.flaque(pb, Vector3(sol["position"]) + n * 0.05, couleur, 0.75, 6.0)

static func _sur_cloue(_exp: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary):
		return
	var e := CombatCoop.ennemi(String(id)) as Node3D
	if e == null:
		return
	# le cadavre (mort reçue par CombatCoop) passe en ragdoll : on attend un peu qu'il existe
	await (Engine.get_main_loop() as SceneTree).create_timer(0.1).timeout
	if not is_instance_valid(e):
		return
	var rd := _ragdoll_de(e)
	if rd == null or not rd.actif or not rd.os.has(String(d.get("os", ""))):
		return
	var pb: PhysicalBone3D = rd.os[String(d["os"])]
	var cible := _xf_de(d.get("xf_os", []))
	var c := Clouage.new()
	c.rd = rd
	c.pb = pb
	c.depart = pb.global_transform
	c.depart.basis = cible.basis
	c.delta = cible.origin - pb.global_position
	var m: Array = d.get("mur", [0, 0, 0])
	var nn: Array = d.get("n", [0, 0, 1])
	c.mur = Vector3(m[0], m[1], m[2])
	c.normale = Vector3(nn[0], nn[1], nn[2])
	c.sang = bool(d.get("sang", true))
	c.couleur = _couleur(_profil(e))
	e.add_child(c)
	PhysicsServer3D.body_set_mode(pb.get_rid(), PhysicsServer3D.BODY_MODE_KINEMATIC)
	rd.endormir_apres(3.5)
	# copie visuelle de l'arme, accrochée à l'os du squelette comme chez le lanceur
	var a := ArmeLancee.creer(String(d.get("arme", "")))
	if a != null:
		e.get_parent().add_child(a)
		var modele := _modele(e)
		Plaies.preparer(modele)
		var acc := modele.find_child("Plaies_" + String(d.get("os_arme", "")), true, false) as Node3D
		var xa := _xf_de(d.get("xf_arme", []))
		_figer(a, xa)
		if acc != null:
			var rt := RemoteTransform3D.new()
			rt.update_scale = false
			acc.add_child(rt)
			# l'os n'a pas encore glissé : l'arme est posée à sa place finale moins le trajet
			rt.global_transform = Transform3D(xa.basis, xa.origin - c.delta)
			rt.remote_path = rt.get_path_to(a)
			a.set_meta("plantee", {"dans": weakref(e), "rt": rt, "sang": c.sang, "couleur": c.couleur})

# ------------------------------------------------------------------------------------------------ objet quelconque

static func _degats_energie(e: float) -> float:
	return clampf(28.0 * sqrt(maxf(e, 0.0) / E_REF_OBJET), DEGATS_OBJET.x, DEGATS_OBJET.y)

static func _objet_dans_corps(objet: RigidBody3D, ennemi: Node3D, point: Vector3, normale: Vector3, dir: Vector3, v: float, masse: float, lanceur: Node) -> void:
	var e := 0.5 * masse * v * v
	var q := masse * v
	var degats := DegatsObjets.degats(e, ennemi, _degats_energie(e))   # courbe d'énergie + résistance des chefs (scripts/magie/degats_objets.gd)
	var renverse := q >= P_RENVERSER and masse >= 6.0
	point = point.lerp(visee_corps(ennemi, point, dir)["entree"], 0.7)   # un objet large touche la surface du corps, pas son axe
	var projete := q >= P_PROJETER and masse >= 6.0
	var dir_h := Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.05 else dir
	var info := {"type": "contondant", "point": point, "direction": dir_h, "normale": normale if normale.length() > 0.1 else -dir,
		"zone": "torse" if renverse else DegatsCombat.zone(ennemi, point), "attaque": "lourde" if q >= 40.0 else "legere", "lancer": true,
		"objet_lance": String(objet.name), "stagger": clampf(q * 0.25, 4.0, 60.0), "collider": ennemi, "affaibli": false, "charge": 0.0, "instant": 0.0,
		"renverser": renverse, "recul_mult": clampf(q / 80.0, 0.6, 2.2)}
	var res := DegatsCombat.appliquer(ennemi, degats, point - dir_h * 2.0, projete, info)
	var ve := DegatsObjets.apres_impact(ennemi, dir, masse, v, lanceur, String(res))   # choc fort : l'ennemi part en ragdoll puis se relève
	dernier = {"issue": "objet", "degats": degats, "resultat": res, "energie": e, "quantite_mvt": q, "renverse": renverse, "ennemi": ennemi, "ragdoll": ve}
	# l'objet encaisse le choc (il casse : branche cassables) ; sinon il retombe devant la cible
	var casse := false
	if objet.has_method("recevoir_choc"):
		casse = bool(objet.recevoir_choc(vitesse_de(dir, v), masse, point))
	if not casse and is_instance_valid(objet):
		objet.linear_velocity = -dir * v * 0.2 + Vector3.UP * (1.0 + minf(masse, 20.0) * 0.1) + dir.cross(Vector3.UP).normalized() * randf_range(-1.0, 1.0)
		objet.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-3, 3))
	dernier["casse"] = casse
	RetourImpact.son(ennemi, "bois", point, -2.0 if masse >= 6.0 else -6.0, 0.8 if masse >= 6.0 else 1.1)

static func vitesse_de(dir: Vector3, v: float) -> Vector3:
	return dir * v

# ------------------------------------------------------------------------------------------------ décor

static func _toucher_decor(objet: RigidBody3D, cible: Node, point: Vector3, normale: Vector3, vitesse: Vector3, arme: DonneesArme, masse: float, lanceur: Node) -> void:
	var v := vitesse.length()
	var dir := vitesse / v
	var n := normale.normalized() if normale.length() > 0.1 else -dir
	var casse_cible := false
	if cible != null and cible.has_method("recevoir_choc"):
		casse_cible = bool(cible.recevoir_choc(vitesse, masse, point))
	# lame qui arrive pointe en avant sur un solide fixe (mur, sol, pilier) : elle s'y fiche
	var fixe := cible is StaticBody3D or cible is CSGShape3D or (cible is RigidBody3D and (cible as RigidBody3D).freeze)
	if arme != null and arme.famille not in FAMILLES_CONTONDANTES and fixe and not casse_cible and v >= V_MIN_PLANTER * 0.85 \
			and _pointe_en_avant(objet, arme, dir) and dir.dot(-n) > 0.35:
		planter_mur(objet, point, n, dir, v)
		dernier = {"issue": "mur", "degats": 0.0, "resultat": "", "energie": 0.5 * masse * v * v, "cible": cible, "point": point}
		return
	var casse := false
	if objet.has_method("recevoir_choc"):
		casse = bool(objet.recevoir_choc(vitesse, masse, point))
	dernier = {"issue": "decor", "degats": 0.0, "resultat": "", "energie": 0.5 * masse * v * v, "cible": cible, "casse": casse, "casse_cible": casse_cible}
	if v > 5.0:
		RetourImpact.son(objet, "metal_blocage" if arme != null else ("bois" if masse >= 3.0 else "pierre"), point, -8.0 if arme != null else -4.0)

## Lame fichée dans un mur / le sol : immobile, pointe enfoncée selon la vitesse ; trace de sang si elle sort d'un corps, étincelles.
static func planter_mur(objet: RigidBody3D, point: Vector3, n: Vector3, dir: Vector3, v: float, reseau := true) -> void:
	var d: DonneesArme = objet.donnees_arme() if objet.has_method("donnees_arme") else null
	var ab := axe_monde(objet, d)
	var axe: Vector3 = (Vector3(ab[1]) - Vector3(ab[0])).normalized()
	var b := Basis(Quaternion(axe, axe.slerp(dir, 0.5).normalized())) * objet.global_basis
	var pointe_loc := objet.global_transform.affine_inverse() * Vector3(ab[1])
	var prof := clampf(0.04 + 0.1 * v / 20.0, 0.04, 0.16)
	var xf := Transform3D(b, Vector3.ZERO)
	xf.origin = point + dir * prof - b * pointe_loc
	_figer(objet, xf)
	objet.set_meta("plantee", {"mur": true, "sang": objet.has_meta("ensanglantee")})
	objet.add_to_group("armes_plantees")
	if objet.has_method("sur_plantee"):
		objet.sur_plantee(null)
	# la trace coule vers le bas le long du mur (au sol : dans le sens du vol)
	var bas := Vector3.DOWN - n * Vector3.DOWN.dot(n)
	var dir_t := bas.normalized() if bas.length() > 0.2 else ((dir - n * dir.dot(n)).normalized() if absf(dir.dot(n)) < 0.99 else Vector3.UP.cross(n).normalized())
	if objet.has_meta("ensanglantee") and Sang.actif():
		var c: Color = objet.get_meta("ensanglantee")
		Sang.trace(objet, point + n * 0.004, n, dir_t, randf_range(0.22, 0.32), c, "giclure")
		var g := Plaies.sang_couleur_goutte(c)
		for i in 3:
			GouttesSang.lacher(objet, point + n * 0.03 + Vector3(randf_range(-0.05, 0.05), -0.02, randf_range(-0.05, 0.05)), g, Vector3.ZERO, true)
	GerbePixels.emettre(objet, point, (n * 0.8 - dir * 0.2).normalized(), "etincelles", 0.7)
	GerbePixels.emettre(objet, point, n, "poussiere", 0.6)
	RetourImpact.son(objet, "pierre", point, -3.0, 1.15)
	RetourImpact.son(objet, "metal_blocage", point, -9.0, 0.8)
	if reseau and CombatCoop.en_ligne():
		CombatCoop.R().envoyer_evenement(EV_MUR, 0, {"xf": _xf_vers(xf), "arme": d.id if d else "", "sang": objet.has_meta("ensanglantee")})

# ------------------------------------------------------------------------------------------------ figer / arracher

static func _figer(objet: RigidBody3D, xf: Transform3D) -> void:
	if not objet.has_meta("plantee_calques"):
		objet.set_meta("plantee_calques", [objet.collision_layer, objet.collision_mask, objet.freeze_mode])
	objet.linear_velocity = Vector3.ZERO
	objet.angular_velocity = Vector3.ZERO
	objet.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	objet.freeze = true
	objet.collision_layer = CALQUE_PLANTEE
	objet.collision_mask = 0
	objet.global_transform = xf
	var s := objet.get_node_or_null("SuiviLancer")
	if s != null:
		s.queue_free()

static func plantee(objet: Node) -> bool:
	return objet != null and is_instance_valid(objet) and objet.has_meta("plantee")

## Retire une arme plantée : elle redevient un corps rigide libre ; `giclee` : sang à la plaie (arrachée par télékinésie).
static func arracher(objet: RigidBody3D, giclee := true) -> void:
	if not plantee(objet):
		return
	var m: Dictionary = objet.get_meta("plantee")
	var rt: Variant = m.get("rt")
	if is_instance_valid(rt) and rt is Node:      # (is_instance_valid d'abord : `is` sur une instance libérée est une erreur de script)
		(rt as Node).queue_free()
	var pl := objet.get_node_or_null("Plantage")
	var point: Vector3 = objet.global_position
	if pl != null:
		point = objet.global_transform * (pl as Plantage).entree_local
		pl.queue_free()
	objet.remove_meta("plantee")
	objet.remove_from_group("armes_plantees")
	var c: Array = objet.get_meta("plantee_calques", [1, 1, RigidBody3D.FREEZE_MODE_KINEMATIC])
	objet.collision_layer = int(c[0])
	objet.collision_mask = int(c[1])
	objet.freeze_mode = int(c[2])
	objet.freeze = false
	var dans: Variant = m.get("dans")
	var e: Node3D = (dans as WeakRef).get_ref() as Node3D if dans is WeakRef else null
	if e != null and e is PhysicsBody3D:
		objet.add_collision_exception_with(e)
	if giclee and bool(m.get("sang", false)) and e != null and Sang.actif():
		var d: DonneesArme = objet.donnees_arme() if objet.has_method("donnees_arme") else null
		var ab := axe_monde(objet, d)
		var sortie: Vector3 = (Vector3(ab[0]) - Vector3(ab[1])).normalized()
		Sang.giclee(e, point, sortie, 1.6, m.get("couleur", Color(0.3, 0.03, 0.025)))
		RetourImpact.son(e, "dechirure", point, -4.0)
	elif giclee and bool(m.get("os_matiere", false)) and e != null:
		EclatsOs.lancer(e, point, Vector3.UP, 2, 0.6)

## L'ancre de l'arme a disparu (cadavre retiré par le plafond de cadavres, membre tranché libéré) : elle tombe.
static func lacher(objet: RigidBody3D) -> void:
	if not plantee(objet):
		return
	arracher(objet, false)
	objet.linear_velocity = Vector3.DOWN * 0.5

# ------------------------------------------------------------------------------------------------ réseau

static func _xf_vers(x: Transform3D) -> Array:
	return [x.basis.x.x, x.basis.x.y, x.basis.x.z, x.basis.y.x, x.basis.y.y, x.basis.y.z, x.basis.z.x, x.basis.z.y, x.basis.z.z, x.origin.x, x.origin.y, x.origin.z]

static func _xf_de(a: Array) -> Transform3D:
	if a.size() < 12:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))

static func _installer_reseau() -> void:
	if _reseau_pret:
		return
	var r := CombatCoop.R()
	if r == null:
		return
	_reseau_pret = true
	r.abonner(EV_PLANTE, Callable(ImpactsLances, "_sur_plante"))
	r.abonner(EV_MUR, Callable(ImpactsLances, "_sur_mur"))
	r.abonner(EV_CLOUE, Callable(ImpactsLances, "_sur_cloue"))

static func _sur_plante(_exp: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary):
		return
	var e := CombatCoop.ennemi(String(id)) as Node3D
	if e == null:
		return
	var modele := _modele(e)
	Plaies.preparer(modele)
	var acc: Node3D = modele.find_child("Plaies_" + String(d.get("os", "")), true, false) as Node3D if modele != null else null
	if acc == null:
		acc = modele
	var a := ArmeLancee.creer(String(d.get("arme", "")))
	if a == null:
		return
	e.get_parent().add_child(a)
	var xf := acc.global_transform * _xf_de(d.get("xf", []))
	_figer(a, xf)
	var rt := RemoteTransform3D.new()
	rt.update_scale = false
	acc.add_child(rt)
	rt.global_transform = xf
	rt.remote_path = rt.get_path_to(a)
	a.set_meta("plantee", {"dans": weakref(e), "os": String(d.get("os", "")), "rt": rt, "sang": bool(d.get("sang", false)), "couleur": _couleur(_profil(e))})
	var pl := Plantage.new()
	pl.name = "Plantage"
	pl.objet = a
	pl.rt = rt
	a.add_child(pl)

static func _sur_mur(_exp: int, _id: Variant, d: Variant) -> void:
	if not (d is Dictionary):
		return
	var arbre := Engine.get_main_loop() as SceneTree
	var a := ArmeLancee.creer(String(d.get("arme", "")))
	if a == null or arbre.current_scene == null:
		return
	arbre.current_scene.add_child(a)
	_figer(a, _xf_de(d.get("xf", [])))
	a.set_meta("plantee", {"mur": true, "sang": bool(d.get("sang", false))})

# ------------------------------------------------------------------------------------------------ nœud de l'arme plantée

## Enfant de l'arme plantée : surveille son ancre (cadavre retiré → l'arme tombe) et fait goutter la plaie quelques secondes.
class Plantage extends Node:
	var objet: RigidBody3D
	var rt: RemoteTransform3D
	var sang := false
	var couleur := Color(0.3, 0.03, 0.025)
	var entree_local := Vector3.ZERO
	var _t := 0.0
	var _prochaine := 0.15
	var _gouttes := 0

	func _physics_process(dt: float) -> void:
		if not is_instance_valid(objet):
			queue_free()
			return
		if not is_instance_valid(rt) or not rt.is_inside_tree():
			ImpactsLances.lacher(objet)
			return
		_t += dt
		if sang and _t < 5.0:
			_prochaine -= dt
			if _prochaine <= 0.0:
				_prochaine = randf_range(0.2, 0.5) * (1.0 + _t * 0.5)
				_gouttes += 1
				var p := objet.global_transform * entree_local
				# une goutte sur trois tache le sol (sinon la flaque grossit trop vite sous un corps immobile)
				GouttesSang.lacher(objet, p + Vector3(randf_range(-0.03, 0.03), -0.02, randf_range(-0.03, 0.03)), couleur, Vector3.ZERO, _gouttes % 3 == 0)
