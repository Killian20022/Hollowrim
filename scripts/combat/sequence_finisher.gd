class_name SequenceFinisher
extends RefCounted
## Déroulé d'un finisher aligné (catalogue : Finishers) — bras du joueur ET victime animés en synchro :
## - le clip du bras (bibliothèque bras_finishers.tres) est joué au temps de la séquence (vitesse 1) ;
## - la caméra se verrouille (lacet vers la cible, tangage RÉSOLU pour que la victime garde les pieds au sol) et le joueur est
##   tenu en place ;
## - la victime glisse à sa place : pour chaque alignement, l'os visé (buste, cou, tête) rejoint le point de l'épée voulu à
##   l'instant du contact (la pointe est DANS le torse pendant la phase plantée ; mesuré : `mesure`) ; sa pose (PoseFinisher)
##   suit les clés du catalogue ;
## - événements : entrée de la lame (giclée, plaie, son selon la matière / l'armure, arrêt bref), jet pulsé + flaque pendant la
##   tenue, giclée au retrait, mort (subir_finisher : ragdoll, décapitation…), gouttes secouées de la lame.

var mains: Node3D
var joueur: CharacterBody3D
var cible: Node3D
var combat: CombatEnnemi
var nom := ""
var categorie := ""
var d: Dictionary
var clip := ""
var m := {}
var t := 0.0
var mort := false
## Résultat de subir_finisher ("tue" …) et mesure de la phase plantée : images, images avec la pointe dans le torse, distance
## max de la pointe à l'axe du torse (m), rayon du torse (m), garde hors du corps (images).
var resultat := ""
var mesure := {"images": 0, "dedans": 0, "dist_max": 0.0, "rayon": 0.0, "garde_dehors": 0}
## Point d'entrée de la lame (monde, mis à jour avec le corps) et direction de la lame au contact.
var entree := Vector3.ZERO
var dir_lame := Vector3.FORWARD

var _pose: PoseFinisher
var _pos_joueur := Vector3.ZERO
var _lacet0 := 0.0
var _tangage0 := 0.0
var _lacet := 0.0
var _racine0 := Vector3.ZERO
var _lacet_cible0 := 0.0
var _lacet_cible := 0.0
var _plans: Array = []          # {t, depuis, racine, tangage, os}
var _faits := {}
var _y_modele := 0.0
var _accroche_entree: Node3D
var _entree_locale := Vector3.ZERO
var _t_trainee := 0.0

const RAYON_TORSE := 0.17       # m à l'échelle 1 (draugr, bandit, squelette : cage, cotte comprise)

func demarrer(p_mains: Node3D, p_cible: Node3D, p_categorie: String, p_nom: String) -> void:
	mains = p_mains
	joueur = mains.joueur
	cible = p_cible
	combat = cible.get("combat") as CombatEnnemi
	categorie = p_categorie
	nom = p_nom
	d = Finishers.donnees(nom)
	clip = String(d["clip"])
	m = mains.anim.marqueurs(clip)
	Finishers.dernier = nom
	_pos_joueur = joueur.global_position
	_lacet0 = joueur.rotation.y
	_tangage0 = joueur.tete.rotation.x
	var v := cible.global_position - joueur.global_position
	_lacet = atan2(-v.x, -v.z) if Vector2(v.x, v.z).length() > 0.05 else _lacet0
	_racine0 = cible.global_position
	_lacet_cible0 = cible.rotation.y
	_y_modele = combat.modele.position.y
	_pose = combat.commencer_finisher(bool(d.get("sol", false)))
	_planifier()

## Lacet de la cible (rotation.y) pour qu'elle présente sa face / son dos au joueur depuis `racine`.
func _lacet_victime(racine: Vector3) -> float:
	var o := String(d["orientation"])
	if o == "garder":
		return _lacet_cible0
	var v := _pos_joueur - racine
	var y := atan2(v.x, v.z)
	return y + PI if o == "dos" else y

## Repère monde de l'épée (dans la main) au temps `tc` du clip, caméra au lacet / tangage donnés (calcul, rien n'est affiché).
func _epee_monde(lacet: float, tangage: float, tc: float) -> Transform3D:
	var l0 := joueur.rotation.y
	var p0: float = joueur.tete.rotation.x
	joueur.rotation.y = lacet
	joueur.tete.rotation.x = tangage
	var xf: Transform3D = mains.global_transform * mains.anim.pose_arme(clip, tc)
	joueur.rotation.y = l0
	joueur.tete.rotation.x = p0
	return xf

## Plan de chaque alignement : tangage de la caméra et position de la cible (racine) qui posent l'os sur le point de l'épée.
func _planifier() -> void:
	var sol_y := cible.global_position.y
	var base_victime := Basis(Vector3.UP, _lacet_victime(cible.global_position))
	for a: Dictionary in d["alignements"]:
		var tc := float(m[a["marqueur"]])
		var acc := combat._accroche(String(a["os"]))
		var off_local := cible.global_transform.affine_inverse() * (acc.global_position if acc != null else cible.global_position + Vector3(0, 1.3, 0))
		var meilleur := {}
		var err_min := INF
		var tg := -1.25
		while tg <= 0.45:
			var xf := _epee_monde(_lacet, tg, tc)
			var cam_b := Basis(Vector3.UP, _lacet) * Basis(Vector3.RIGHT, tg)
			var point := xf * Vector3(0, float(a["y_lame"]), 0) + cam_b * Vector3(a["decalage"])
			var bv := Basis(Vector3.UP, _lacet_victime(point)) if String(d["orientation"]) != "garder" else base_victime
			var racine := point - bv * off_local
			var err := absf(racine.y - sol_y)
			if err < err_min:
				err_min = err
				meilleur = {"t": tc, "depuis": float(a["depuis"]), "racine": Vector3(racine.x, sol_y, racine.z), "tangage": tg, "os": String(a["os"]), "ecart_sol": err}
			tg += 0.01
		_plans.append(meilleur)
	_lacet_cible = _lacet_victime(_plans[0]["racine"])

func _accroche(os: String) -> Node3D:
	return combat._accroche(os)

func _lisse(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x) if b > a else (1.0 if x >= a else 0.0)

## Une image. Renvoie true quand le geste arrive au suivi (mains passe en récupération).
func avancer(dt: float) -> bool:
	t += dt
	joueur.global_position = _pos_joueur
	joueur.velocity = Vector3.ZERO
	# caméra : lacet verrouillé avant le premier contact, tangage d'alignement en alignement
	var t0 := float(_plans[0]["t"])
	var k := _lisse(0.0, t0 * 0.85, t)
	joueur.rotation.y = lerp_angle(_lacet0, _lacet, k)
	var tg := lerpf(_tangage0, float(_plans[0]["tangage"]), k)
	var racine := _racine0.lerp(_plans[0]["racine"], _lisse(0.0, t0 * 0.9, t))
	for i in range(1, _plans.size()):
		var p: Dictionary = _plans[i]
		var s := _lisse(float(p["depuis"]), float(p["t"]) - 0.03, t)
		tg = lerpf(tg, float(p["tangage"]), s)
		racine = racine.lerp(p["racine"], s)
	joueur.tete.rotation.x = tg
	mains.anim.regler(t)
	if not mort and is_instance_valid(cible) and cible.is_inside_tree():
		cible.global_position = racine
		cible.rotation.y = lerp_angle(_lacet_cible0, _lacet_cible, _lisse(0.0, t0 * 0.8, t))
		var c := Finishers.pose_a(d["pose"], t)
		if _pose != null:
			_pose.repere = cible.global_transform.basis
			for canal: String in c:
				_pose.set(canal, float(c[canal]))
			combat.modele.position.y = _y_modele - PoseFinisher.baisse(float(c.get("genoux", 0.0)), combat.modele.scale.y)
		_mesurer()
	if bool(d.get("trainee", false)):
		_trainee()
	for e: Array in d["evenements"]:
		var cle := String(e[0]) + ":" + String(e[1])
		if not _faits.has(cle) and m.has(e[0]) and t >= float(m[e[0]]):
			_faits[cle] = true
			_evenement(String(e[1]))
	return t >= float(m.get("suivi", m["fin"]))

## Annule (cible disparue, joueur mort) : la cible reprend sa vie.
func annuler() -> void:
	if not mort and combat != null and is_instance_valid(combat):
		combat.annuler_finisher()

# ------------------------------------------------------------------ mesures (tests)

## Pointe de l'épée (monde) dans le volume du torse (capsule bassin → cou) pendant la tenue plantée.
func _mesurer() -> void:
	if not m.has("plante") or t < float(m["plante"]) + 0.02 or t > float(m.get("retrait", 0.0)):
		return
	var a := _accroche("spine_01")
	var b := _accroche("neck_01")
	if a == null or b == null:
		return
	var xf: Transform3D = mains.global_transform * mains.anim.pose_affichee()
	var pointe := xf * Vector3(0, Finishers.POINTE, 0)
	var garde := xf * Vector3(0, Finishers.GARDE, 0)
	var r := RAYON_TORSE * combat.modele.scale.y
	var dp := _dist_segment(pointe, a.global_position, b.global_position)
	var dg := _dist_segment(garde, a.global_position, b.global_position)
	mesure["images"] += 1
	mesure["rayon"] = r
	if dp <= r:
		mesure["dedans"] += 1
	if dg > r:
		mesure["garde_dehors"] += 1
	mesure["dist_max"] = maxf(float(mesure["dist_max"]), dp)
	# profondeur de la pointe dans le corps (repère de la victime : + = vers son dos depuis l'axe du torse) et écart latéral
	var bv := cible.global_transform.basis
	var c3 := _accroche("spine_03")
	if c3 != null:
		var v := pointe - c3.global_position
		var avant := bv.z.normalized() * (-1.0 if String(d["orientation"]) == "dos" else 1.0)
		mesure["serie"] = mesure.get("serie", []) + [Vector3(t, -v.dot(avant), v.dot(bv.x.normalized()))]

static func _dist_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * u)

# ------------------------------------------------------------------ traînée (coupe)

func _trainee() -> void:
	var f0 := float(m.get("frappe", 0.0))
	var f1 := float(m.get("fin_frappe", f0))
	if t < f0:
		return
	if _t_trainee <= 0.0:
		mains.trainee.couper()
		_t_trainee = f0
	var fin := minf(t, f1)
	while _t_trainee + TraceLame.PAS <= fin + 1e-9:
		_t_trainee += TraceLame.PAS
		mains._echantillon_trainee(mains._couche() * mains.anim.pose_arme(clip, _t_trainee), t - _t_trainee)

# ------------------------------------------------------------------ événements

func _epee() -> Transform3D:
	return mains.global_transform * mains.anim.pose_affichee()

func _couleur() -> Color:
	return combat.profil.couleur_sang

func _saigne() -> bool:
	return combat.profil.sang and Sang.actif()

## Armure au torse (cotte de mailles, plates) : le contact de la lame y racle le métal.
func _armure_torse() -> bool:
	return combat.profil.armure >= 2.0 or combat.profil.armure_part >= 0.06

func _evenement(sorte: String) -> void:
	var corps := cible
	if not is_instance_valid(corps) or not corps.is_inside_tree():
		return
	match sorte:
		"entree":
			var xf := _epee()
			var pointe := xf * Vector3(0, Finishers.POINTE, 0)
			dir_lame = (xf.basis.y).normalized()
			var os_vise := String(_plans[_plans.size() - 1]["os"])
			var acc := _accroche(os_vise)
			var c := acc.global_position if acc != null else pointe
			var proj := pointe + dir_lame * (c - pointe).dot(dir_lame)
			entree = proj - dir_lame * RAYON_TORSE * 0.8 * combat.modele.scale.y
			_accroche_entree = acc
			if acc != null:
				_entree_locale = acc.to_local(entree)
			var vers_joueur := -dir_lame
			if _saigne():
				Sang.giclee(corps, entree, (_lat() * 0.8 + Vector3.UP * 0.5 - vers_joueur * 0.1).normalized(), 1.5, _couleur())
			else:
				Sang.eclats_matiere(corps, entree, vers_joueur, 1.6, _couleur() if not combat.profil.sang else Color(0.45, 0.42, 0.38))
			if _armure_torse():
				Effets.eclats(corps, entree + vers_joueur * 0.04, Color(3.0, 2.2, 0.8), 4, 1.4, true)   # la lame racle la cotte : peu d'étincelles (la cible reste lisible)
			Plaies.ajouter(combat.modele, entree, vers_joueur, Vector3.UP, 0.42, _couleur(), combat.profil.matiere)
			var p := ProfilImpact.de("lourd")
			RetourImpact.son_impact(corps, combat.profil.matiere, p, entree, _armure_torse())
			RetourImpact.cri(corps, "douleur", entree, combat.profil.matiere, combat.profil.mort_vivant)
			RetourImpact.jouer(corps, p, joueur)
			if "tassement" in joueur:
				joueur.tassement = maxf(joueur.tassement, 0.7)
		"pommeau":
			var tete := _accroche("Head")
			var pt := (tete.global_position if tete != null else corps.global_position + Vector3(0, 1.6, 0)) + (joueur.global_position - corps.global_position).normalized() * 0.1
			var casque := combat.profil.armure_tete > 0.0
			if casque:
				RetourImpact.son(corps, "armure", pt, 2.0, 0.85)
				Effets.eclats(corps, pt, Color(3.0, 2.2, 0.8), 4, 1.2, true)
			elif combat.profil.matiere == "os":
				RetourImpact.son(corps, "os", pt, 3.0, 1.0)
				Sang.eclats_matiere(corps, pt, -_epee().basis.z, 0.8, _couleur())
			else:
				RetourImpact.son(corps, "chair", pt, 2.0, 0.8)
				RetourImpact.son(corps, "os", pt, -2.0, 1.2)
				if _saigne():
					Sang.giclee(corps, pt, (joueur.global_position - pt).normalized() * -1.0 + Vector3.UP * 0.4, 0.7, _couleur())
			RetourImpact.cri(corps, "douleur", pt, combat.profil.matiere, combat.profil.mort_vivant)
			RetourImpact.jouer(corps, ProfilImpact.de("moyen"), joueur)
		"jet":
			if _saigne() and _accroche_entree != null:
				# jet pulsé qui sort de la plaie vers le joueur (et un peu vers le haut), il goutte au sol ; flaque qui grossit
				var loc := _entree_locale
				# jet de côté et vers le haut (jamais droit sur la caméra : à 1 m, les gouttes deviendraient des pavés)
				var y := (_accroche_entree.global_transform.basis.inverse() * (dir_lame * 0.35 + _lat() * 0.8 + Vector3.UP * 0.6)).normalized()
				var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
				Sang.jet(_accroche_entree, Transform3D(Basis(x, y, x.cross(y)), loc), _couleur(), 2.2)
				Sang.flaque(corps, corps.global_position + (joueur.global_position - corps.global_position).normalized() * 0.15, _couleur(), 1.1, 1.6)
				RetourImpact.son(corps, "jet_sang", entree, -2.0)
		"retrait":
			var pt := _accroche_entree.to_global(_entree_locale) if _accroche_entree != null else entree
			if _saigne():
				Sang.giclee(corps, pt, (-dir_lame * 0.15 + _lat() * 0.8 + Vector3.UP * 0.45).normalized(), 2.2, _couleur())
				Sang.giclee(corps, pt, (-dir_lame * 0.3 - _lat() * 0.5 + Vector3.DOWN * 0.6).normalized(), 1.6, _couleur())
			else:
				Sang.eclats_matiere(corps, pt, -dir_lame, 1.4, _couleur() if not combat.profil.sang else Color(0.45, 0.42, 0.38))
			RetourImpact.son(corps, "dechirure" if combat.profil.matiere == "chair" else "os", pt, 1.0, 0.9)
			if combat.profil.matiere == "chair":
				RetourImpact.son(corps, "chair_gore", pt, -1.0, 0.8)
			if "secousse" in joueur:
				joueur.secousse = maxf(float(joueur.secousse), 0.35)
		"mort", "tranche":
			_tuer(sorte == "tranche")
		"secoue":
			# le héros secoue la lame : gouttes projetées depuis le milieu de la lame vers le bas
			if Sang.actif() and combat.profil.sang:
				var xf2 := _epee()
				Sang.giclee(mains, xf2 * Vector3(0, 0.6, 0), (xf2.basis.y * 0.3 + Vector3.DOWN).normalized(), 0.5, _couleur())

## Côté (horizontal) perpendiculaire à la lame, vers la gauche de l'écran (là où la lame n'est pas).
func _lat() -> Vector3:
	var l := Vector3.UP.cross(dir_lame)
	return l.normalized() if l.length() > 0.01 else Vector3.RIGHT

func _tuer(tranche: bool) -> void:
	mort = true
	if not is_instance_valid(cible) or (cible.has_method("vivant") and not cible.vivant()):
		return
	var point := entree
	var direction := dir_lame
	if tranche:
		var cou := _accroche("neck_01")
		point = cou.global_position if cou != null else cible.global_position + Vector3(0, 1.55, 0)
		var tc := float(m["contact"])
		direction = (mains.global_transform.basis * (mains.anim.pose_arme(clip, tc + 0.02).origin - mains.anim.pose_arme(clip, tc - 0.02).origin)).normalized()
	elif _accroche_entree != null:
		point = _accroche_entree.to_global(_entree_locale)
	var vers := point - joueur.global_position
	vers.y = 0.0
	combat.terminer_finisher()
	var info := {
		"type": mains.arme.type_degats, "point": point, "direction": direction, "normale": -vers.normalized(),
		"zone": "tete" if tranche else "torse", "attaque": "finisher", "arme": mains.arme.id, "stagger": 999.0,
		"collider": cible, "origine": joueur.global_position, "puissant": mains.arme.poids >= 2.4,
		"finisher_nom": nom, "mort_finisher": String(d.get("mort", "")),
	}
	resultat = String(cible.subir_finisher(categorie, info))
