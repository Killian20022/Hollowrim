class_name CombatEnnemi
extends Node
## Composant de combat d'un ennemi (branché par draugr.gd, réutilisable par tout ennemi humanoïde) : calcul des dégâts
## (CalculDegats + ProfilCible), jauge de posture, choix de la réaction, fenêtre de finisher, effets d'impact (sang, plaies, sons,
## retour écran), type de mort et effets de mort (décapitation…). L'ennemi garde sa machine d'états : il applique la réaction.
##
##   var c := CombatEnnemi.equiper(ennemi, modele, ProfilCible.pour("draugr"))
##   var r := c.analyser(degats, origine, puissant, info, etat)     # -> résultat (voir CalculDegats.calculer) + "reaction", "interrompt"
##   c.effets_impact(r) ; c.effets_mort(r, type_mort) ; c.finisher_possible(joueur) -> String
## Réactions : "leger", "moyen", "lourd", "recul", "chute", "etourdi" (posture brisée) ; "bloque" ; voir docs/DEGATS.md.

signal posture_brisee
## Affiche dégâts flottants, jauge de posture, réaction et finisher disponible au-dessus de l'ennemi (scène de test).
static var debug := false
## Étiquette de débogage au-dessus de l'ennemi (le mannequin a la sienne).
var etiquette := true

var corps: Node3D
var modele: Node3D
var profil: ProfilCible
var posture := 60.0
var boss := false
var hauteur := 1.8
var etourdi := 0.0           # s restantes de posture brisée
var au_sol := false
var fenetre_parade := 0.0    # s restantes après une parade du joueur (finisher « apres_parade »)
var derniere_reaction := ""
var dernier_resultat := {}
var reaction_os: ReactionOs
var _sans_coup := 0.0
var _etiquette: Label3D
var _debug_t := 0.0

static func equiper(ennemi: Node3D, mod: Node3D, p: ProfilCible) -> CombatEnnemi:
	var c := CombatEnnemi.new()
	c.name = "Combat"
	c.corps = ennemi
	c.modele = mod
	c.profil = p
	c.posture = p.posture_max
	ennemi.add_child(c)
	c._installer()
	return c

func _installer() -> void:
	RetourImpact.precharger()
	if corps.is_inside_tree():   # pools des gerbes et des os créés à l'apparition, pas au premier coup
		GerbePixels.obtenir(corps)
		EclatsOs.obtenir(corps)
	if modele == null:
		return
	Plaies.marquer(modele)
	Plaies.preparer(modele)
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq != null and sq.find_bone("spine_01") >= 0:
		reaction_os = ReactionOs.new()
		reaction_os.name = "ReactionOs"
		sq.add_child(reaction_os)
	hauteur = 1.8 * modele.scale.y

func _process(dt: float) -> void:
	_sans_coup += dt
	if etourdi > 0.0:
		etourdi -= dt
		if etourdi <= 0.0:
			posture = profil.posture_max
			if reaction_os:
				reaction_os.etourdi = false
	elif _sans_coup > profil.posture_delai:
		posture = minf(profil.posture_max, posture + profil.posture_regen * dt)
	fenetre_parade = maxf(0.0, fenetre_parade - dt)
	if debug and etiquette:
		_maj_debug(dt)

## Hauteur (m, au-dessus des pieds de `cible`) où passe le regard du joueur à la distance de la cible ; -1 si inconnue / trop loin.
static func hauteur_visee(joueur: Node, cible: Node3D) -> float:
	if joueur == null or not is_instance_valid(joueur):
		return -1.0
	var cam: Variant = joueur.get("camera")
	if not (cam is Camera3D) or not (cam as Camera3D).is_inside_tree():
		return -1.0
	var o := (cam as Camera3D).global_position
	var f := -(cam as Camera3D).global_transform.basis.z
	if o.y - cible.global_position.y < 0.9 or o.y - cible.global_position.y > 2.6:
		return -1.0   # caméra pas à hauteur d'yeux (joueur factice, cible très en contrebas) : regard inconnu
	var d := Vector2(cible.global_position.x - o.x, cible.global_position.z - o.z).length()
	var horiz := Vector2(f.x, f.z).length()
	if d > 3.5 or horiz < 0.1:
		return -1.0
	return o.y + f.y / horiz * maxf(d - 0.3, 0.0) - cible.global_position.y

func ratio_posture() -> float:
	return clampf(posture / maxf(profil.posture_max, 1.0), 0.0, 1.0)

## Analyse d'un coup reçu. `etat` (fourni par l'ennemi) : {"de_face", "peut_bloquer", "en_attaque", "coup_donne", "hauteur_visee"}.
func analyser(quantite: float, origine: Vector3, puissant: bool, info: Dictionary, etat: Dictionary) -> Dictionary:
	# taille réelle du moment (draugr voûté, ennemi qui titube) : sommet du crâne = os de la tête + 12 cm
	var tete := _accroche("Head")
	if tete != null:
		var h := tete.global_position.y - corps.global_position.y + 0.12
		if h > 0.6:
			hauteur = h
	var i := CalculDegats.completer(info, corps, quantite, origine, puissant, hauteur, float(etat.get("hauteur_visee", -1.0)))
	var e := etat.duplicate()
	e["posture"] = posture
	e["etourdi"] = etourdi > 0.0
	e["au_sol"] = au_sol
	e["boss"] = boss
	var r := CalculDegats.calculer(i, profil, e)
	_sans_coup = 0.0
	var avant := posture
	posture = maxf(0.0, posture - float(r["stagger"]))
	r["posture_avant"] = avant
	if r["bloque"]:
		r["reaction"] = "bloque"
		r["interrompt"] = false
	else:
		r["reaction"] = _reaction(r, e, avant)
		r["interrompt"] = e.get("en_attaque", false) and not e.get("coup_donne", false) and (r["reaction"] != "leger" or ratio_posture() < 0.5)
	derniere_reaction = r["reaction"]
	dernier_resultat = r
	return r

func _reaction(r: Dictionary, e: Dictionary, avant: float) -> String:
	var s := float(r["stagger"])
	var attaque := String(r["info"]["attaque"])
	if etourdi > 0.0:
		return "lourd" if s >= profil.seuil_moyen else "moyen"
	if avant > 0.0 and posture <= 0.0:
		return "etourdi"
	var lourde := attaque in ["lourde", "chargee_max", "contre"]
	if s >= profil.seuil_chute and lourde and not boss and String(r["info"]["zone"]) == "jambes":
		return "chute"
	if s >= profil.seuil_lourd:
		return "recul" if attaque == "chargee_max" else "lourd"
	if s >= profil.seuil_moyen:
		return "moyen"
	return "leger"

## Posture brisée : étourdi `profil.duree_etourdi` s (fenêtre de finisher), signal sonore et visuel.
func briser_posture() -> void:
	etourdi = profil.duree_etourdi * (0.6 if boss else 1.0)
	posture = 0.0
	if reaction_os:
		reaction_os.etourdi = true
	var tete := corps.global_position + Vector3(0, hauteur * 0.95, 0)
	RetourImpact.son_finisher_dispo(corps, tete)
	RetourImpact.cri(corps, "etourdi", tete, profil.matiere, profil.mort_vivant)
	GerbePixels.emettre(corps, tete, Vector3.UP, "etincelles", 1.4)
	posture_brisee.emit()
	if debug:
		_flottant("POSTURE BRISEE", tete + Vector3(0, 0.35, 0), Color(1.0, 0.85, 0.3))

## Parade réussie du joueur : grosse usure de posture et fenêtre de finisher « apres_parade ».
## Part de posture retirée par la PROCHAINE parade (posée par mains.defendre juste avant que l'attaquant n'appelle
## subir_parade : DonneesArme.posture_parade de l'arme qui pare — le coup de bouclier déséquilibre davantage).
static var part_parade := 0.45

func subir_parade() -> void:
	_sans_coup = 0.0
	posture = maxf(0.0, posture - profil.posture_max * part_parade)
	part_parade = 0.45
	fenetre_parade = 1.4
	if posture <= 0.0 and etourdi <= 0.0:
		briser_posture()

## Catégorie de finisher possible pour `joueur` ("" = aucun) : "etourdi", "sol", "apres_parade", "rapide", "lateral".
## L'ennemi doit être vivant (vérifié par l'appelant), à portée (≤ 2,6 m) et pas trop haut / bas.
func finisher_possible(joueur: Node3D, vie := 1.0, vie_max := 1.0) -> String:
	if joueur == null:
		return ""
	var v := joueur.global_position - corps.global_position
	if absf(v.y) > 1.5:
		return ""
	v.y = 0.0
	if v.length() > 2.6:
		return ""
	var cat := ""
	if au_sol:
		cat = "sol"
	elif etourdi > 0.0:
		cat = "etourdi"
	elif fenetre_parade > 0.0:
		cat = "apres_parade"
	elif vie <= vie_max * profil.seuil_finisher_vie and ratio_posture() < 0.6:
		cat = "rapide"
	if cat in ["etourdi", "rapide"]:
		var face := corps.global_transform.basis.z
		var ang := absf(Vector2(face.x, face.z).angle_to(Vector2(v.x, v.z)))
		if ang > deg_to_rad(65.0) and ang < deg_to_rad(140.0):
			cat = "lateral"
	return cat

# ------------------------------------------------------------------ finisher aligné (SequenceFinisher)

## En plein finisher : la victime ne pense plus (process physique coupé), ses pieds ne cherchent plus le sol, sa pose est
## pilotée par la séquence (PoseFinisher par-dessus l'animation de base). Renvoie le modificateur de pose.
var en_finisher := false
var pose_finisher: PoseFinisher
var _sauve_fin := {}

func commencer_finisher(au_sol := false) -> PoseFinisher:
	en_finisher = true
	var pieds: Variant = corps.get("_pieds")
	_sauve_fin = {"phys": corps.is_physics_processing(), "y": modele.position.y, "pieds": (pieds as PiedsAuSol).actif if pieds is PiedsAuSol else false}
	corps.set_physics_process(false)
	if corps is CollisionObject3D:
		# la victime est posée contre le joueur : sa capsule ne doit pas le pousser (ni rien d'autre) pendant la séquence
		_sauve_fin["couche"] = (corps as CollisionObject3D).collision_layer
		_sauve_fin["masque"] = (corps as CollisionObject3D).collision_mask
		(corps as CollisionObject3D).collision_layer = 0
		(corps as CollisionObject3D).collision_mask = 0
	if corps is CharacterBody3D:
		(corps as CharacterBody3D).velocity = Vector3.ZERO
	if pieds is PiedsAuSol:
		(pieds as PiedsAuSol).actif = false
	if reaction_os:
		reaction_os.etourdi = false
	var ap: Variant = corps.get("anim")
	if ap is AnimationPlayer and not au_sol:
		var a := ap as AnimationPlayer
		for nom in ["Idle", "Sword_Idle"]:
			if a.has_animation(nom):
				a.play(nom, 0.2)
				a.speed_scale = 0.45
				break
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	pose_finisher = PoseFinisher.new()
	pose_finisher.name = "PoseFinisher"
	sq.add_child(pose_finisher)
	return pose_finisher

## Fin du finisher (juste avant la mort) : la pose pilotée s'efface, le process physique revient (état MORT, ragdoll).
func terminer_finisher() -> void:
	if is_instance_valid(pose_finisher):
		pose_finisher.queue_free()
	pose_finisher = null
	if en_finisher:
		modele.position.y = float(_sauve_fin.get("y", modele.position.y))
		corps.set_physics_process(bool(_sauve_fin.get("phys", true)))
	en_finisher = false

## Finisher interrompu (joueur mort, cible disparue) : tout revient comme avant.
func annuler_finisher() -> void:
	var etait := en_finisher
	terminer_finisher()
	var pieds: Variant = corps.get("_pieds")
	if etait and pieds is PiedsAuSol:
		(pieds as PiedsAuSol).actif = bool(_sauve_fin.get("pieds", true))
	if etait and corps is CollisionObject3D and _sauve_fin.has("couche"):
		(corps as CollisionObject3D).collision_layer = int(_sauve_fin["couche"])
		(corps as CollisionObject3D).collision_mask = int(_sauve_fin["masque"])

## Mort d'un finisher : réglages du ragdoll selon le finisher joué (info["mort_finisher"], SequenceFinisher) ou la catégorie
## (ancien finisher court : décapitation, coup de grâce au sol) → {force, montee, os, decapiter}.
func reglage_mort_finisher(categorie: String, info: Dictionary) -> Dictionary:
	var decap := profil.decapitable and Sang.niveau() > 0
	match String(info.get("mort_finisher", "")):
		"effondre":
			# la lame retirée, le corps s'affaisse sur place : presque aucune poussée, vers le bas
			return {"force": 45.0, "montee": -0.8, "os": "spine_03", "decapiter": false}
		"cloue":
			return {"force": 30.0, "montee": -1.0, "os": "spine_03", "decapiter": false}
		"decapite":
			return {"force": 200.0, "montee": 0.1, "os": "spine_03", "decapiter": decap}
	if categorie == "sol":
		return {"force": 60.0, "montee": -0.6, "os": "spine_03", "decapiter": false}
	return {"force": 260.0, "montee": 0.15, "os": "spine_03", "decapiter": decap}

# ------------------------------------------------------------------ effets

func effets_impact(r: Dictionary, joueur: Node) -> void:
	var i: Dictionary = r["info"]
	var p := ProfilImpact.de(String(r["impact"]))
	var point: Vector3 = i["point"]
	var dir: Vector3 = i["direction"]
	var zone := String(i["zone"])
	var armure := (profil.armure >= 2.0 or profil.armure_part >= 0.06) and zone in ["torse", "bras"]
	# casque : un coup à la tête sonne sur le métal (étincelles, moins de sang : la lame glisse sur le casque)
	var casque := profil.armure_tete > 0.0 and zone == "tete"
	var part_sang := 0.25 if bool(i.get("continu", false)) else (0.6 if i.has("ecole") else 1.0)   # magie : moins de sang
	if casque:
		part_sang *= 0.35
	if profil.sang and Sang.actif():
		Sang.giclee(corps, point, dir, p.sang * part_sang, profil.couleur_sang)
	else:
		Sang.eclats_matiere(corps, point, dir, p.sang * 0.8, profil.couleur_sang if not profil.sang else Color(0.45, 0.42, 0.38))
	var magie := i.has("ecole")
	# gerbe de gros pixels de la matière touchée (os, draugr, sang, bois ; GerbePixels) : vers l'attaquant et le long de la lame
	var dir_g := (Vector3(i.get("normale", -dir)) * 0.7 + dir * 0.5 + Vector3.UP * 0.35).normalized()
	var mat_g := matiere_gerbe()
	if not magie and not bool(i.get("continu", false)):
		if mat_g in ["draugr", "sang", "chair"]:   # (os, bois, poussière : déjà par Sang.eclats_matiere ci-dessus)
			GerbePixels.emettre(corps, point, dir_g, mat_g, GerbePixels.force_de(p.nom) * (0.7 if mat_g == "sang" else 1.0))
		# os qui volent : coups forts sur un squelette ou un draugr
		if mat_g in ["os", "draugr"] and p.nom in ["lourd", "critique", "finisher"]:
			var n_os := {"lourd": 3, "critique": 4, "finisher": 6}
			EclatsOs.lancer(corps, point, (dir * 0.8 + Vector3.UP * 0.9).normalized(), int(n_os[p.nom]) - (2 if mat_g == "draugr" else 0), GerbePixels.force_de(p.nom) * 0.6)   # le long de la lame, pas vers la caméra
	if armure or casque:
		# étincelles sur les mailles / le casque : plus nombreuses au coup lourd, jamais au point de masquer la cible
		GerbePixels.emettre(corps, point - dir * 0.05, dir_g, "etincelles", 0.8 if p.nom in ["leger", "moyen"] else 1.4)
	# chiffres de dégâts (option, désactivée par défaut) ; les tics d'un sort canalisé s'additionnent
	ChiffresDegats.ajouter(corps, point + Vector3(0, 0.2, 0), float(r["degats"]), ChiffresDegats.sorte_de(r), bool(i.get("continu", false)))
	var taille := 0.32 if p.nom == "leger" else (0.4 if p.nom == "moyen" else 0.5)
	# magie (docs/MAGIE.md) : un tic de sort canalisé ne laisse ni plaie ni arrêt sur image ; un sort élémentaire ne taille pas
	if bool(i.get("continu", false)):
		return
	if String(i.get("type", "tranchant")) in ["tranchant", "contondant"]:
		Plaies.ajouter(modele, point, i["normale"], dir, taille, profil.couleur_sang, profil.matiere)
	RetourImpact.son_impact(corps, profil.matiere, p, point, armure)
	if casque:
		RetourImpact.son(corps, "armure", point, p.volume_db, 1.2)          # tintement du casque (plus aigu que la cotte)
	if profil.poids >= 2.0 and profil.matiere == "chair":
		RetourImpact.son(corps, "chair_gore", point, p.volume_db - 3.0, 0.7)   # chair épaisse (troll) : impact sourd
	if r["reaction"] in ["moyen", "lourd", "recul", "chute"] and randf() < 0.6:
		RetourImpact.cri(corps, "douleur", point, profil.matiere, profil.mort_vivant)
	RetourImpact.jouer(corps, p, joueur)
	if reaction_os:
		# réaction selon la zone, la direction de la lame et la puissance : léger = sursaut nerveux, lourd = le corps encaisse
		var f := {"leger": 0.18, "moyen": 0.32, "lourd": 0.55, "recul": 0.7, "chute": 0.6, "etourdi": 0.6}
		var reac := String(r["reaction"])
		reaction_os.frapper_zone(dir, float(f.get(reac, 0.25)) / sqrt(maxf(profil.poids, 0.5)), zone, reac not in ["leger", "moyen"])
	if debug:
		var txt := "-%d%s" % [roundi(float(r["degats"])), "!" if r["critique"] else ""]
		_flottant(txt, point + Vector3(0, 0.25, 0), Color(1.0, 0.55, 0.2) if r["critique"] else Color(1, 0.95, 0.85))
		_flottant(String(r["reaction"]).to_upper() + (" INTERROMPU" if r.get("interrompt", false) else ""), point + Vector3(0, 0.05, 0), Color(0.75, 0.85, 1.0))

func effets_blocage(r: Dictionary, brise: bool) -> void:
	var i: Dictionary = r["info"]
	var point: Vector3 = i["point"]
	RetourImpact.son_blocage(corps, point, brise)
	# coup paré au bouclier : échardes du bois et étincelles de l'umbo, vers l'attaquant
	var vers := (Vector3(i["origine"]) - corps.global_position)
	vers.y = 0.0
	vers = vers.normalized() if vers.length() > 0.01 else -corps.global_transform.basis.z
	var pt := corps.global_position + Vector3(0, 1.1, 0) + vers * 0.4
	var d_g := (vers + Vector3.UP * 0.5).normalized()
	GerbePixels.emettre(corps, pt, d_g, "bois", 1.6 if brise else 1.0)
	GerbePixels.emettre(corps, pt, d_g, "etincelles", 2.2 if brise else 1.6)   # fer de l'umbo : traits nets (passe « intensité »)
	ChiffresDegats.ajouter(corps, point + Vector3(0, 0.2, 0), float(r.get("degats", 0.0)), ChiffresDegats.BLOQUE)
	if debug:
		_flottant("GARDE BRISEE" if brise else "BLOQUE", point + Vector3(0, 0.25, 0), Color(0.7, 0.8, 1.0))

## Animation de coup reçu selon la zone du dernier coup (tête : Hit_Head ; ailleurs : Hit_Chest).
func anim_coup() -> String:
	var z := String(dernier_resultat.get("info", {}).get("zone", ""))
	return "Hit_Head" if z == "tete" else "Hit_Chest"

## Type de mort selon le coup : "legere", "titubante", "lourde", "recul", "chute", "puissant" (le finisher a la sienne).
func type_mort(r: Dictionary) -> String:
	var i: Dictionary = r["info"]
	var attaque := String(i["attaque"])
	if attaque == "chargee_max" or (r["critique"] and attaque != "legere"):
		return "puissant"
	if attaque in ["lourde", "contre"]:
		if String(i["zone"]) == "jambes":
			return "chute"
		return "recul" if randf() < 0.45 else "lourde"
	return "titubante" if randf() < 0.45 else "legere"

## Effets de la mort (avant/après le ragdoll : appelés par l'ennemi juste après l'avoir déclenché).
func effets_mort(r: Dictionary, sorte: String, joueur: Node) -> void:
	var i: Dictionary = r.get("info", {})
	var point: Vector3 = i.get("point", corps.global_position + Vector3(0, 1.1, 0))
	var dir: Vector3 = i.get("direction", -corps.global_transform.basis.z)
	var gros := sorte in ["puissant", "recul", "lourde", "finisher"]
	var p := ProfilImpact.de("finisher" if sorte == "finisher" else ("critique" if sorte == "puissant" else ("lourd" if gros else "moyen")))
	# finisher aligné (épée plantée, plongé) : le gros du sang a coulé pendant la séquence (jets, giclée au retrait) ; à la
	# mort, une giclée de lourd seulement (une explosion de gouttes devant la caméra masquerait la chute du corps)
	var k_sang := 2.2 / p.sang if String(i.get("mort_finisher", "")) in ["effondre", "cloue"] else 1.0
	if profil.sang and Sang.actif():
		Sang.giclee(corps, point, dir, p.sang * 1.3 * k_sang, profil.couleur_sang)
		if gros and k_sang >= 1.0:
			Sang.giclee(corps, point + Vector3(0, 0.1, 0), (dir + Vector3.UP * 0.5).normalized(), p.sang, profil.couleur_sang, false)
		# la flaque s'étale sous le corps une fois tombé
		var c := corps
		var couleur := profil.couleur_sang
		var bassin := _accroche("pelvis")
		corps.get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if is_instance_valid(c) and c.is_inside_tree():
				var pos := bassin.global_position if is_instance_valid(bassin) else c.global_position
				Sang.flaque(c, pos, couleur, randf_range(0.9, 1.3) * (1.25 if gros else 1.0), 5.0))
	else:
		Sang.eclats_matiere(corps, point, dir, p.sang * 1.4, profil.couleur_sang if not profil.sang else Color(0.45, 0.42, 0.38))
	# mort : le squelette éclate en os (pixels + morceaux qui rebondissent) ; draugr achevé fort : quelques esquilles
	var mat_g := matiere_gerbe()
	if not i.has("ecole") and mat_g in ["os", "draugr"]:
		var d_os := (dir + Vector3.UP * 0.8).normalized()
		if mat_g == "draugr":
			GerbePixels.emettre(corps, point, d_os, "draugr", GerbePixels.force_de(p.nom))
		if mat_g == "os" or gros:
			EclatsOs.lancer(corps, point, d_os, (8 if mat_g == "os" else 3) if gros else 4, 1.0)
	Plaies.ajouter(modele, point, i.get("normale", -dir), dir, 0.5, profil.couleur_sang, profil.matiere)
	RetourImpact.son_impact(corps, profil.matiere, p, point, false)
	RetourImpact.cri(corps, "mort", point, profil.matiere, profil.mort_vivant)
	var c2 := corps
	corps.get_tree().create_timer(0.55 if sorte != "titubante" else 0.9).timeout.connect(func() -> void:
		if is_instance_valid(c2) and c2.is_inside_tree():
			RetourImpact.son_chute(c2, c2.global_position))
	RetourImpact.jouer(corps, p, joueur)
	if reaction_os:
		reaction_os.active = false
	if debug:
		_flottant("MORT " + sorte.to_upper(), point + Vector3(0, 0.45, 0), Color(1.0, 0.3, 0.25))

## Matière de la gerbe de pixels (GerbePixels.MATIERES) : squelette → os ; mannequin → bois ; draugr → os et sang noirci ;
## chair vivante (bandit, mage) → sang ; chair épaisse (troll) → sang vif et peau ; sang coupé (option gore) → os pour les
## draugrs, poussière sinon.
func matiere_gerbe() -> String:
	match profil.matiere:
		"os":
			return "os"
		"bois":
			return "bois"
	if profil.nom.begins_with("draugr"):
		return "draugr" if Sang.niveau() > 0 else "os"
	if Sang.niveau() <= 0:
		return "poussiere"
	return "chair" if profil.nom.begins_with("troll") else "sang"

## Accroche d'os préparée par Plaies (position visible, suit le ragdoll).
func _accroche(os: String) -> Node3D:
	if modele == null or not modele.has_meta("plaies_accroches"):
		return null
	for a: BoneAttachment3D in modele.get_meta("plaies_accroches"):
		if is_instance_valid(a) and a.bone_name == os:
			return a
	return null

# ------------------------------------------------------------------ débogage (scène de test)

func _flottant(texte: String, pos: Vector3, couleur: Color) -> void:
	if not corps.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = texte
	l.font = Palette.police()
	l.font_size = 32
	l.pixel_size = 0.006
	l.modulate = couleur
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	var scene := corps.get_tree().current_scene
	(scene if scene else corps.get_tree().root).add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(randf_range(-0.15, 0.15), 0.6, 0), 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

func _maj_debug(dt: float) -> void:
	_debug_t -= dt
	if _debug_t > 0.0:
		return
	_debug_t = 0.1
	if _etiquette == null:
		_etiquette = Label3D.new()
		_etiquette.font = Palette.police()
		_etiquette.font_size = 26
		_etiquette.pixel_size = 0.005
		_etiquette.outline_size = 6
		_etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_etiquette.no_depth_test = true
		corps.add_child(_etiquette)
		_etiquette.position = Vector3(0, hauteur + 0.45, 0)
	var n := 10
	var plein := roundi(ratio_posture() * n)
	var barre := "[" + "#".repeat(plein) + "-".repeat(n - plein) + "]"
	var vie_txt := ""
	if "vie" in corps and "vie_max" in corps:
		vie_txt = "vie %d/%d  " % [roundi(float(corps.vie)), roundi(float(corps.vie_max))]
	var fin := ""
	var j: Variant = corps.get("joueur")
	if j is Node3D and corps.has_method("finisher_possible"):
		fin = String(corps.finisher_possible(j))
	_etiquette.text = "%sposture %s\n%s%s" % [vie_txt, barre, ("ETOURDI " if etourdi > 0.0 else "") + ("AU SOL " if au_sol else ""), ("FINISHER: " + fin) if fin != "" else ""]
	_etiquette.modulate = Color(1.0, 0.85, 0.3) if fin != "" else Color(0.9, 0.92, 1.0)
