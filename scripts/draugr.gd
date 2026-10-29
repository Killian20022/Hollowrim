extends CharacterBody3D
## Draugr : mort-vivant nordique (modèles squelettes KayKit, animés).
## Il dort au sol ou monte la garde ; il se réveille, traque, frappe, titube, meurt.
## Le guerrier porte un bouclier et bloque parfois les coups légers de face.
## Types « squelette » (épée) et « squelette_archer » (arc : variante visuelle, aucun système de tir) : ossements nordiques
## (SqueletteGuerrier), plus rapides et plus fragiles aux coups puissants que les draugrs ; même squelette, mêmes animations.
##
## Options de monde.creer_draugr (donjons) — toutes facultatives, posées avant add_child :
##   "patrouille": Array[Vector3]  points MONDE ; état PATROUILLE (marche lente, pause à chaque point, retour après abandon).
##   "archer": true                tir à l'arc réel (Projectile) : distance 6-15 m, ligne de vue, armement annoncé ~1,1 s ; le type
##                                 « squelette_archer » est archer d'office. Corps à corps faible si le joueur est collé.
##   "poste": true                 archer qui ne bouge pas (corniche, hauteur) : tire jusqu'à 18 m, voit le joueur 7 m plus haut/bas.
##   "degats_tir": float           dégâts de la flèche (10 par défaut).
##   "reveil_evt": "<événement>"   dort (même debout) jusqu'à ce que quetes.signaler(<événement>) survienne (réveil immédiat si déjà vu).
##   "boss": "svanhild" | "hrafn" | "jarl"   voir _regler_boss ; l'ident vaut le nom du boss si aucun ident n'est donné.
## Méthodes publiques : vivant(), en_combat(), recevoir_coup(), alerter() ; signal mort(ident).
## Combat (branche combat/degats_gore) : dégâts, posture, réactions, sang, plaies et morts par le composant CombatEnnemi
## (scripts/combat/) ; finishers : finisher_possible(joueur) -> catégorie, subir_finisher(categorie, info) ; voir docs/DEGATS.md.

enum { DORT, REVEIL, GARDE, TRAQUE, ATTAQUE, TITUBE, MORT, PATROUILLE, VISE, APPEL, ANNONCE, SOUFFLE, ETOURDI, CHUTE }

signal mort(ident: String)

const EPEE := preload("res://assets/modeles/joueur/epee_nordique.glb")
## Prise de l'épée dans la main droite (repère de l'os hand_r) : lame de l'auriculaire vers
## l'index, poignée au creux des doigts — calculée par outils/calcul_prise.gd.
var prise := Transform3D(Basis(Vector3(-0.999251, -0.038334, -0.005288), Vector3(-0.014458, 0.24307, 0.969901), Vector3(-0.035895, 0.969252, -0.243442)), Vector3(-0.007936, 0.142938, 0.002241))
const ATTAQUES := ["Sword_Attack", "Sword_Attack", "Punch_Cross"]

const GRAVITE := 13.0
const DETECTION := 17.0
const REVEIL_DISTANCE := 10.0
const ABANDON := 45.0
const PORTEE := 1.9
const MARCHE := 0.85  # démarche lente et raide (Walk à ~0,82 de sa vitesse d'origine)
const MARCHE_PROCHE := 1.2  # derniers mètres avant le corps à corps
const COURSE := 3.4
## Vitesses du corps supposées par les animations de la bibliothèque (mesurées avec
## outils/mesure_pas.gd : pied d'appui) : Walk 1,03 m/s, Jog_Fwd ≈ 6 m/s. speed_scale = vitesse réelle / référence
## évite que les pieds glissent (Walk à 0,85 m/s => ~0,82 ; Jog_Fwd à 3,4 m/s => ~0,57 : course lourde de mort-vivant).
const REF_MARCHE := 1.03
const REF_COURSE := 6.0
const ACCEL := 8.0  # m/s²
const ROT_MAX := 6.0  # rad/s ; 10 pendant le geste d'attaque

var type := "guerrier"
var _os := false  # type « squelette* » (renseigné dans _ready)
var _humain := false  # bandit vivant (personnage de base) : bourse « cadavre_bandit » au lieu de « cadavre_draugr »
## Allures propres au type (le squelette est plus vif que le draugr, dont la marche est lente et raide).
var _marche := MARCHE
var _marche_proche := MARCHE_PROCHE
var _course := COURSE
var dort := false
var joueur: CharacterBody3D
var vie := 70.0
var vie_max := 70.0
var degats := 16.0
var nom_affiche := "Draugr"
# réglages facultatifs, posés avant add_child (boss…)
var echelle := 1.0
var apparence := {}  # remplace des éléments de l'allure (corps, cheveux, tenue)
var teinte := Color(0.78, 0.82, 0.92)
var saturation := 0.3
var vie_imposee := 0.0
var degats_imposes := 0.0
var debout := false  # endormi debout (niches) plutôt qu'allongé
var variante := ""  # squelettes : arme imposée (« epee », « arc », « hache ») ; vide = tirée de l'identifiant
var teinte_os := ""    # squelettes : teinte imposée (« givre », « sang », « braise », « ivoire ») ; vide = tirée de l'identifiant (C10)
var ident := ""  # pour la sauvegarde (les draugrs tués restent morts)
var hud: Control
var quetes: Node  # posé par monde.creer_draugr (événements de réveil)
# --- options donjons (voir l'en-tête) ---
var patrouille: Array = []
var archer := false
var poste := false
var degats_tir := 10.0
var reveil_evt := ""
var boss := ""
var _attend := false           # endormi jusqu'à l'événement reveil_evt
var _p_i := 0
var _p_pause := 0.0
var _rythme := 1.0             # vitesse des gestes d'attaque (boss lents)
var _bouclier := 0.3           # chance de bloquer un coup léger de face
var _phase := 1
var _combo := 0
var _appel := ""
var _appel_fait := false
var _cri_fait := false
var _cd_souffle := 4.0
var _souffle_dir := Vector3.ZERO
var _cone: Node3D
var _tir_fait := false
var _tir_cible := Vector3.ZERO
var _los := true
var _t_los := 0.0
var _coince := 0.0
var _retr := false
var _pos_prec := Vector3.ZERO
const VISE_DUREE := 1.1
const PORTEE_TIR := 15.0
const DIST_MIN_TIR := 6.0
## Contournement des obstacles par rayons (bandits de la grotte : caisses, tables, colonnes, parois) ; les draugrs des
## cryptes gardent leur marche en ligne droite.
var contourne := false
var _cote := 1.0               # côté préféré pour longer un obstacle (+1 gauche, -1 droite)
var _tenue := 0.0              # durée pendant laquelle la direction de contournement est conservée (pas d'hésitation)
var _dir_evit := Vector3.ZERO
var _detour := 0.0             # durée restante d'un détour forcé (bloqué)
var _dernier := Vector3.ZERO
var _t_bloque := 0.0
const BUTIN := preload("res://scripts/butin.gd")
## Un ennemi immobile au sol ne relance move_and_slide() qu'à cette période (re-vérifie le sol sous ses pieds).
const IMMO_PERIODE := 0.4

var etat := GARDE
var modele: Node3D
var anim: AnimationPlayer
var origine := Vector3.ZERO
var _t := 0.0
var _anim := ""
var _attaque := ""
var _coup_donne := false
var _recharge := 0.0
var _recul := Vector3.ZERO
var _mailles: Array[MeshInstance3D] = []
var _var := 1.0  # petite variation de rythme propre à chaque draugr
var _vit := 0.0
var _pieds: PiedsAuSol  # pieds posés sur le terrain (coupé tant qu'il dort ou se relève allongé)
var _ragdoll: Ragdoll  # corps physique à la mort
var _gele := false             # gelé par SalleActive (hors salle active) : process coupé et caché
var _mode_avant := Node.PROCESS_MODE_INHERIT
var _immo := 0.0               # durée depuis le dernier move_and_slide d'un ennemi immobile au sol
## Combat : composant (dégâts, posture, effets), durée de la titubation en cours, phase de la chute (CHUTE).
var combat: CombatEnnemi
var _duree_titube := 0.55
var _releve := false

## Nom lisible (barre de l'ennemi du HUD) quand aucun nom n'est imposé (options, boss) : d'après le profil de combat.
func _nommer(profil_nom: String) -> void:
	if nom_affiche == "Draugr":
		match profil_nom:
			"draugr_guerrier":
				nom_affiche = "Draugr ancien"
			"bandit":
				nom_affiche = "Bandit"

func _ready() -> void:
	add_to_group("ennemis")
	_os = type.begins_with("squelette")
	if type == "sbire":
		vie_max = 45.0
		degats = 12.0
	elif _os:
		nom_affiche = "Squelette"
		vie_max = 70.0
		degats = 14.0
		_marche = 1.05
		_marche_proche = 1.5
		_course = 4.3
	if type == "squelette_archer":
		archer = true
	if archer:
		if not _os:
			nom_affiche = "Bandit archer"
		degats = minf(degats, 8.0)  # corps à corps faible : l'arc est son arme
		contourne = true
	if not patrouille.is_empty():
		contourne = true
	_regler_boss()
	if vie_imposee > 0.0:
		vie_max = vie_imposee
	if degats_imposes > 0.0:
		degats = degats_imposes
	vie = vie_max
	floor_snap_length = 0.4
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	add_child(forme)

	var app := EnnemisNordiques.apparence_defaut(type, apparence)
	_humain = app.has("perso")
	if app.has("perso"):
		modele = Personnage.creer(app["perso"])      # bandits vivants : personnage de base unifie (PersoDef)
	elif _os:
		modele = EnnemisNordiques.squelette({"type": type, "archer": archer, "ident": ident, "variante": variante, "teinte": teinte_os})   # copie d'un gabarit préconstruit
	else:
		# pnj/ennemis : archétypes nordiques + variante (EnnemisNordiques) ; --pnj-anciens = ancien corps Humain
		modele = EnnemisNordiques.creer({"type": type, "archer": archer, "boss": boss, "ident": ident, "apparence": app})
		if modele == null:
			modele = Humain.creer(app)
	modele.scale = Vector3.ONE * echelle
	add_child(modele)
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		_mailles.append(mi)
	var squelette: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	if not _os and not modele.has_meta("armes_nordiques"):
		if archer:
			_armer_arc(squelette)
		else:
			_armer(squelette)  # le squelette porte son arme dans son modèle
	_pieds = PiedsAuSol.equiper(modele, self) as PiedsAuSol
	anim = modele.get_node("Animations")
	var profil := ProfilCible.pour(ProfilCible.nom_pour(type, boss, modele))
	if boss != "":
		profil.posture_max *= 2.2
	combat = CombatEnnemi.equiper(self, modele, profil)
	combat.boss = boss != ""
	_nommer(profil.nom)
	_var = randf_range(0.94, 1.06)
	origine = global_position
	_pos_prec = global_position
	_immo = randf() * IMMO_PERIODE   # phases différentes : les ennemis immobiles ne relancent pas move_and_slide la même image
	if reveil_evt != "" and quetes != null and not quetes.vus.has(reveil_evt):
		_attend = true
		dort = true
		quetes.evenement.connect(_sur_evenement)
	if dort:
		etat = DORT
		_regler_pieds()
		if debout:
			_jouer("Idle", 0.0)
			anim.speed_scale = 0.0  # figé dans sa niche
			anim.advance(0.0)       # pose appliquée tout de suite : sous --paisible (process coupé), plus de T-pose
		else:
			# allongé : dernière image de l'animation de mort
			_jouer("Death01", 0.0)
			anim.seek(_duree("Death01") - 0.05, true)
			anim.pause()
	else:
		if not patrouille.is_empty():
			etat = PATROUILLE
			_p_i = _plus_proche()
		_jouer("Sword_Idle", 0.0)
		anim.seek(randf() * 2.0, true)  # phase au hasard : les gardes ne bougent pas en même temps (update immédiat : pas de T-pose si le process est coupé)

## Le réveil : un dormeur allongé rejoue sa mort à l'envers et se relève.
func _reveiller() -> void:
	anim.speed_scale = 1.0
	if debout:
		_jouer("Sword_Idle", 0.6)
	else:
		_anim = "reveil"
		anim.play_backwards("Death01")

func _duree_reveil() -> float:
	return 0.8 if debout else _duree("Death01")

## Lame nordique rouillée (modèle du joueur) tenue dans la main droite.
func _armer(squelette: Skeleton3D) -> void:
	var accroche := BoneAttachment3D.new()
	accroche.bone_name = "hand_r"
	squelette.add_child(accroche)
	var arme: Node3D = EPEE.instantiate()
	arme.transform = prise
	accroche.add_child(arme)
	var rouille := Palette.materiau(Palette.tex("rouille", ["#2a1c14", "#3b2a1e", "#4f3a2a", "#5e5048"], 4, 0.7), Vector2(1, 3))
	rouille.set_shader_parameter("tex_neige", rouille.get_shader_parameter("tex_base"))
	for mi: MeshInstance3D in arme.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = rouille
		_mailles.append(mi)

## Réglages des trois chefs (n'écrase pas vie_imposee / degats_imposes / echelle donnés par l'appelant).
func _regler_boss() -> void:
	match boss:
		"svanhild":
			nom_affiche = "Svanhild, Dame de givre"
			vie_max = 260.0
			degats = 24.0
		"hrafn":
			nom_affiche = "Hrafn, chef des bandits"
			vie_max = 230.0
			degats = 20.0
			_rythme = 0.85
			if echelle == 1.0:
				echelle = 1.08
		"jarl":
			nom_affiche = "Jarl Kolbeinn le Gelé"
			vie_max = 320.0
			degats = 38.0
			_rythme = 0.7
			_bouclier = 0.6
			if echelle == 1.0:
				echelle = 1.12

## Arc du bandit archer : le maillage « arc » du squelette (même rig) est repris sur le squelette humain.
func _armer_arc(squelette: Skeleton3D) -> void:
	if squelette == null:
		return
	var copie := SqueletteGuerrier.arc()
	squelette.add_child(copie)
	copie.skeleton = NodePath("..")
	var bois := Palette.materiau(Palette.tex("bois_arc", ["#2a1c10", "#3b2a18", "#4f3a22", "#5e4a30"], 4, 0.7), Vector2(1, 3))
	bois.set_shader_parameter("tex_neige", bois.get_shader_parameter("tex_base"))
	for s in copie.mesh.get_surface_count():
		copie.set_surface_override_material(s, bois)
	_mailles.append(copie)

func _plus_proche() -> int:
	var best := 0
	var d_best := INF
	for i in patrouille.size():
		var d: float = (patrouille[i] as Vector3).distance_to(global_position)
		if d < d_best:
			d_best = d
			best = i
	return best

func _sur_evenement(evt: String) -> void:
	if _attend and evt == reveil_evt:
		_attend = false
		degeler()
		if etat == DORT:
			_changer(REVEIL)
			_reveiller()
			Sons.jouer_a(self, ["giant1", "giant2", "giant3"], global_position + Vector3.UP, -2.0, 0.15)

## Un chef (ou un cri) met en alerte : les gardes et patrouilleurs se lancent à la poursuite.
func alerter() -> void:
	degeler()
	if etat in [GARDE, PATROUILLE]:
		_changer(TRAQUE)
	elif etat == DORT and not _attend:
		_changer(REVEIL)
		_reveiller()

func _ligne_de_vue() -> bool:
	var de := global_position + Vector3(0, 1.5 * echelle, 0)
	var vers_p: Vector3 = joueur.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(de, vers_p)
	var ex: Array[RID] = [get_rid(), joueur.get_rid()]
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is CollisionObject3D and e != self:
			ex.append((e as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func vivant() -> bool:
	return etat != MORT

func en_combat() -> bool:
	return etat in [TRAQUE, ATTAQUE, TITUBE, VISE, APPEL, ANNONCE, SOUFFLE, ETOURDI, CHUTE]

## --- gel hors salle active (SalleActive) -------------------------------------------------
## Seuls les dormeurs, gardes et patrouilleurs peuvent être gelés : jamais un ennemi qui poursuit, frappe ou se relève.
func peut_geler() -> bool:
	return etat == DORT or etat == GARDE or etat == PATROUILLE

func est_gele() -> bool:
	return _gele

## Process, physique, animation et modificateurs de squelette coupés (process_mode DISABLED) et corps caché. Les signaux restent actifs
## (réveil par événement) : alerter(), _sur_evenement() et recevoir_coup() dégèlent d'eux-mêmes. La collision reste en place.
func geler() -> void:
	if _gele or etat == MORT or not peut_geler():
		return
	_gele = true
	_mode_avant = process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false

func degeler() -> void:
	if not _gele:
		return
	_gele = false
	process_mode = _mode_avant
	visible = true

func _jouer(nom: String, fondu := 0.15, forcer := false) -> void:
	if _anim == nom and not forcer:
		return
	_anim = nom
	if forcer:
		anim.stop()
	anim.play(nom, fondu)
	# Walk et Jog_Fwd : speed_scale réglé à chaque image sur la vitesse réelle
	if nom != "Walk" and nom != "Jog_Fwd":
		anim.speed_scale = _var if nom in ["Sword_Idle", "Idle"] else 1.0

func _duree(nom: String) -> float:
	return anim.get_animation(nom).length

func _changer(nouvel: int) -> void:
	etat = nouvel
	_t = 0.0
	_regler_pieds()

## Les pieds épousent le sol sauf s'il dort ou se relève de sa pose allongée (Death01 à l'envers).
func _regler_pieds() -> void:
	if _pieds == null:
		return
	var voulu := not (etat == DORT or etat == MORT or etat == CHUTE or (etat == REVEIL and not debout))
	if _pieds.actif != voulu:
		_pieds.actif = voulu

func _physics_process(dt: float) -> void:
	_t += dt
	if etat == MORT:
		# le cadavre est un ragdoll : plus de déplacement ni d'orientation
		if _t > 30.0:
			queue_free()
		return
	_recharge -= dt
	_cd_souffle -= dt
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	var vers := joueur.global_position - global_position
	vers.y = 0.0
	var dist := vers.length()
	var dir := vers / dist if dist > 0.01 else Vector3.ZERO
	# Étages différents (crypte sous le cercle de pierres, joueur au-dessus ou l'inverse) : il ne
	# l'entend ni ne le voit, et ne peut pas le frapper à travers le sol.
	var ecart_y := absf(joueur.global_position.y - global_position.y)
	if ecart_y > (7.0 if archer else 3.5):
		dist = 1000.0
	elif ecart_y > 3.5 and dist < PORTEE + 1.0:
		dist = PORTEE + 1.0  # pas de corps à corps à travers un étage
	var vitesse := 0.0
	var regard := true
	var vitesse_rot := ROT_MAX
	var loco := ""  # animation de déplacement voulue ("" = sur place)

	match etat:
		DORT:
			regard = false
			if dist < REVEIL_DISTANCE and not joueur.mort and not _attend:
				_changer(REVEIL)
				_reveiller()
				Sons.jouer_a(self, ["giant1", "giant2", "giant3"], global_position + Vector3.UP, -2.0, 0.15)
		REVEIL:
			regard = _t > 0.6
			if _t >= _duree_reveil() * 0.95:
				_changer(TRAQUE)
		GARDE:
			var retour := origine - global_position
			retour.y = 0.0
			if retour.length() > 1.5:
				dir = retour.normalized()
				vitesse = _marche
				loco = "Walk"
			else:
				regard = false
				_jouer("Sword_Idle")
			if dist < DETECTION and not joueur.mort:
				_changer(TRAQUE)
				Sons.jouer_a(self, ["mnstr1", "mnstr2", "mnstr3", "mnstr4"], global_position + Vector3.UP, -4.0, 0.15)
		PATROUILLE:
			if _p_pause > 0.0:
				_p_pause -= dt
				regard = false
				_jouer("Sword_Idle")
			else:
				var a: Vector3 = (patrouille[_p_i] as Vector3) - global_position
				a.y = 0.0
				if a.length() < 0.9:
					_p_pause = randf_range(1.2, 2.8)
					_p_i = (_p_i + 1) % patrouille.size()
				else:
					dir = a.normalized()
					vitesse = _marche * 0.85
					loco = "Walk"
			# détection : à plus de 8 m, il lui faut voir le joueur (pas de repérage à travers les murs)
			if dist < DETECTION and not joueur.mort and (dist < 8.0 or _voit(dt)):
				_changer(TRAQUE)
				Sons.jouer_a(self, ["mnstr1", "mnstr2", "mnstr3", "mnstr4"], global_position + Vector3.UP, -4.0, 0.15)
		TRAQUE:
			if joueur.mort or dist > ABANDON:
				_p_i = _plus_proche() if not patrouille.is_empty() else 0
				_changer(PATROUILLE if not patrouille.is_empty() else GARDE)
			elif boss == "hrafn" and not _cri_fait:
				_cri_fait = true
				_lancer_appel("archers")
			elif boss == "svanhild" and _phase == 1 and vie <= vie_max * 0.5:
				_phase = 2
				_lancer_appel("squelettes")
			elif boss == "svanhild" and _phase == 2 and _cd_souffle <= 0.0 and dist > 2.5 and dist < 11.0:
				_lancer_souffle(dir)
			elif archer and dist > PORTEE:
				var av := global_position.distance_to(_pos_prec)
				_pos_prec = global_position
				if _retr and _vit > 0.3 and av < _vit * dt * 0.3:
					_coince += dt
				else:
					_coince = maxf(_coince - dt * 0.5, 0.0)
				_retr = false
				var voit := _voit(dt)
				var tir_max := 18.0 if poste else PORTEE_TIR
				if dist < DIST_MIN_TIR and not poste and _coince < 0.6:
					# trop près : il recule (dos tourné, il se retourne à distance) pour retrouver sa portée de tir
					dir = -dir
					vitesse = _course * 0.75
					loco = "Jog_Fwd"
					_retr = true
				elif (dist > tir_max or not voit) and not poste:
					vitesse = _course if dist > 6.0 else _marche_proche
					loco = "Jog_Fwd" if dist > 6.0 else "Walk"
				elif voit and dist <= tir_max and _recharge <= 0.0:
					_changer(VISE)
					_tir_fait = false
					_jouer("Pistol_Aim_Neutral", 0.12, true)
					anim.speed_scale = 1.4
					_eclair()  # éclat bref : l'armement est annoncé
					Sons.jouer_a(self, ["cloth1", "cloth2"], global_position + Vector3.UP, -2.0, 0.1)
				else:
					_jouer("Sword_Idle")
			elif dist > PORTEE:
				vitesse = _course if dist > 4.0 else _marche_proche
				loco = "Jog_Fwd" if dist > 4.0 else "Walk"
			else:
				_jouer("Sword_Idle")
				if _recharge <= 0.0:
					_attaque = (["Sword_Attack"] if _os else ATTAQUES).pick_random()  # le squelette frappe à l’arme (pas de coup de poing : la lame traverserait la tête)
					if boss == "hrafn":
						_attaque = "Sword_Attack"
					_coup_donne = false
					_combo = 0
					_changer(ATTAQUE)
					_jouer(_attaque, 0.1, true)
					anim.speed_scale = _rythme
		VISE:
			# il suit le joueur des yeux, puis fige sa visée (dernier quart de seconde : le tir est évitable)
			vitesse_rot = 4.0
			regard = _t < VISE_DUREE - 0.3
			if regard:
				_tir_cible = joueur.global_position + Vector3(0, 1.1, 0)
			if not _tir_fait and _t >= VISE_DUREE:
				_tir_fait = true
				_tirer()
				_jouer("Pistol_Shoot", 0.05, true)
			if _t >= VISE_DUREE + 0.45:
				_recharge = randf_range(1.6, 2.4)
				_changer(TRAQUE)
		APPEL:
			regard = true
			vitesse_rot = 3.0
			if not _appel_fait and _t >= 0.6:
				_appel_fait = true
				_faire_appel()
			if _t >= 1.5:
				_recharge = 0.8
				_changer(TRAQUE)
		ANNONCE:
			# le cône de givre est dessiné au sol, direction FIGÉE : 0,8 s pour sortir du cône
			regard = false
			if _t >= 0.8:
				_changer(SOUFFLE)
				_jouer("Spell_Simple_Shoot", 0.05, true)
				_souffler()
		SOUFFLE:
			regard = false
			if _t >= 0.7:
				_cd_souffle = randf_range(6.5, 8.5)
				_recharge = 1.0
				_changer(TRAQUE)
		ATTAQUE:
			var duree := _duree(_attaque) / _rythme
			regard = _t < duree * 0.45  # il se vise avant de frapper
			vitesse_rot = 10.0
			if not _coup_donne and _t >= duree * 0.42:
				_coup_donne = true
				Sons.jouer_a(self, ["swing", "swing2", "swing3"], global_position + Vector3.UP, -6.0, 0.2)
				var face := global_transform.basis.z
				if dist < PORTEE + 0.6 and dir.dot(Vector3(face.x, 0, face.z).normalized()) > 0.4:
					var r: String = joueur.recevoir_coup(degats * (1.25 if _combo == 1 else 1.0), global_position)
					if r == "parade":
						# parade réussie : le draugr est déséquilibré (grosse usure de posture, fenêtre de finisher)
						combat.subir_parade()
						if combat.etourdi > 0.0:
							_etourdir()
						else:
							_tituber(-dir * 1.2, 0.7)
						return
			if _t >= duree * 0.92:
				if boss == "hrafn" and _combo == 0 and dist < PORTEE + 1.2:
					# enchaînement lisible : deuxième coup d'un autre geste, un peu plus fort
					_combo = 1
					_attaque = "Punch_Cross"
					_coup_donne = false
					_changer(ATTAQUE)
					_jouer(_attaque, 0.1, true)
					anim.speed_scale = _rythme
					return
				_combo = 0
				_recharge = randf_range(1.8, 2.8) if boss != "" else randf_range(0.5, 1.6)
				_changer(TRAQUE)
		TITUBE:
			regard = false
			if _t > _duree_titube:
				_changer(TRAQUE)
		ETOURDI:
			# posture brisée : il titube sur place, sans frapper (fenêtre de finisher) ; le corps se balance (ReactionOs)
			regard = false
			if _t > 0.5 and _anim != "Sword_Idle":
				_jouer("Sword_Idle", 0.3)
				anim.speed_scale = 0.45
			if combat.etourdi <= 0.0:
				anim.speed_scale = 1.0
				_recharge = 0.6
				_changer(TRAQUE)
		CHUTE:
			# renversé : chute (Death01 accélérée), au sol ~1,3 s (finisher « sol »), puis se relève (Death01 à l'envers)
			regard = false
			var d_chute := _duree("Death01") / 1.6
			if not _releve and _t >= d_chute + 1.3:
				_releve = true
				combat.au_sol = false
				anim.speed_scale = 1.4
				anim.play_backwards("Death01")
				_anim = "releve"
			elif not _releve and _t >= d_chute * 0.6:
				combat.au_sol = true
			if _releve and _t >= d_chute + 1.3 + _duree("Death01") / 1.4 * 0.95:
				anim.speed_scale = 1.0
				_releve = false
				_recharge = 0.5
				_changer(TRAQUE)
		MORT:
			regard = false

	if contourne and loco != "":
		dir = _eviter(dir, dt)
	else:
		_detour = 0.0
		_t_bloque = 0.0
	var ecart := 0.0
	if (regard or loco != "") and dist > 0.01:
		var cible := atan2(dir.x, dir.z)
		ecart = angle_difference(rotation.y, cible)
		var pas := ecart * (1.0 - exp(-8.0 * dt))
		rotation.y += clampf(pas, -vitesse_rot * dt, vitesse_rot * dt)
	# déplacement : il ne court pas de dos ni de travers ; très désaligné, il pivote sur place
	var aligne := clampf(1.0 - (absf(ecart) - 0.3) / 1.0, 0.0, 1.0)
	if loco != "" and aligne >= 0.25:
		_vit = move_toward(_vit, vitesse * aligne, ACCEL * dt)
		_jouer(loco)
		anim.speed_scale = clampf(_vit / (REF_COURSE if loco == "Jog_Fwd" else REF_MARCHE), 0.4, 1.5)
	else:
		_vit = 0.0
		vitesse = 0.0
		if loco != "":
			_jouer("Sword_Idle")
	_recul = _recul.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	var fv := Statuts.facteur_vitesse(self)   # magie : gel (docs/MAGIE.md)
	if fv < 1.0 and loco != "" and _vit > 0.01:   # la marche vient d'être réglée : jamais cumulé d'une image à l'autre
		anim.speed_scale *= fv
	velocity.x = dir.x * _vit * fv + _recul.x
	velocity.z = dir.z * _vit * fv + _recul.z
	# Ennemi immobile au sol : pas de move_and_slide à chaque pas (le plus gros coût de physique contre la coque de la grotte) ; relancé
	# toutes les IMMO_PERIODE s pour revérifier le sol, et tout de suite dès qu'il bouge, tombe ou est repoussé.
	if absf(velocity.x) + absf(velocity.z) < 0.01 and velocity.y > -0.01 and is_on_floor() and _immo < IMMO_PERIODE:
		_immo += dt
		return
	_immo = 0.0
	move_and_slide()

## Ligne de vue vers le joueur, rafraîchie 5 fois par seconde.
func _voit(dt: float) -> bool:
	_t_los -= dt
	if _t_los <= 0.0:
		_t_los = 0.2
		_los = _ligne_de_vue()
	return _los

func _tirer() -> void:
	var depart := global_position + Vector3(0, 1.4 * echelle, 0) + global_transform.basis.z * 0.5
	var main := EnnemisNordiques.main_de_tir(modele)   # la flèche part de la main qui tient l'arc
	if main != Vector3.INF and main.distance_to(global_position + Vector3(0, 1.2 * echelle, 0)) < 1.6:
		depart = main + global_transform.basis.z * 0.15
	var d := Projectile.cap_visee(depart, _tir_cible)
	d = d.rotated(Vector3.UP, randf_range(-0.025, 0.025))
	Projectile.tirer(get_parent(), depart, d, self, degats_tir, joueur)
	Sons.jouer_a(self, ["swing2", "swing3"], depart, -2.0, 0.1)

# --- chefs : appel de renforts, souffle de givre ---------------------------------------

func _lancer_appel(quoi: String) -> void:
	_appel = quoi
	_appel_fait = false
	_changer(APPEL)
	_jouer("Spell_Simple_Shoot" if quoi == "squelettes" else "Interact", 0.1, true)
	_eclair()
	Sons.jouer_a(self, ["mnstr1", "mnstr2"], global_position + Vector3.UP, 2.0, 0.1)

func _faire_appel() -> void:
	if _appel == "archers":
		# le cri de Hrafn : tous les archers et gardes à portée se lancent
		for e in get_tree().get_nodes_in_group("ennemis"):
			if e != self and e.has_method("alerter") and e.global_position.distance_to(global_position) < 45.0:
				e.alerter()
	elif _appel == "squelettes":
		var monde := get_parent()
		if monde == null or not monde.has_method("creer_draugr"):
			return
		var droite := global_transform.basis.x
		for k in 2:
			var id := "svanhild_garde_%d" % (k + 1)
			var ex: Variant = monde.get("draugrs")
			if ex is Dictionary and ex.has(id) and is_instance_valid(ex[id]):
				continue
			var cote := -1.0 if k == 0 else 1.0
			var pos := global_position + droite * cote * 2.6 + global_transform.basis.z * 0.8
			var sq: CharacterBody3D = monde.creer_draugr("squelette", pos, rotation.y, false, {"ident": id, "contourne": true})
			GerbePixels.emettre(self, pos + Vector3(0, 0.6, 0), Vector3.UP, "givre_lueur", 1.5)
			if sq != null:
				sq.alerter()
	Sons.jouer_a(self, ["giant1", "giant2"], global_position + Vector3.UP, 0.0, 0.1)

const SOUFFLE_LONG := 9.0
const SOUFFLE_DEMI_ANGLE := 0.5  # rad (≈ 29°)

func _lancer_souffle(vers_joueur: Vector3) -> void:
	_souffle_dir = vers_joueur.normalized()
	rotation.y = atan2(_souffle_dir.x, _souffle_dir.z)
	_changer(ANNONCE)
	_jouer("Spell_Simple_Enter", 0.1, true)
	_cone = _fabriquer_cone()
	Sons.jouer_a(self, ["mnstr3", "mnstr4"], global_position + Vector3.UP, 0.0, 0.1)

func _fabriquer_cone() -> Node3D:
	var n := MeshInstance3D.new()
	var m := ArrayMesh.new()
	var pts := PackedVector3Array([Vector3.ZERO])
	var segs := 14
	for i in segs + 1:
		var a := lerpf(-SOUFFLE_DEMI_ANGLE, SOUFFLE_DEMI_ANGLE, float(i) / segs)
		pts.append(Vector3(sin(a), 0.0, cos(a)) * SOUFFLE_LONG)
	var idx := PackedInt32Array()
	for i in segs:
		idx.append_array([0, i + 2, i + 1])  # sens horaire vu de dessus : face visible depuis le haut
	var tab := []
	tab.resize(Mesh.ARRAY_MAX)
	tab[Mesh.ARRAY_VERTEX] = pts
	tab[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
	n.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.85, 1.0, 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(n)
	n.global_position = global_position + Vector3(0, 0.08, 0)
	n.rotation.y = atan2(_souffle_dir.x, _souffle_dir.z)
	# le cône se remplit pendant l'annonce (0,8 s)
	var tw := n.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.5, 0.8)
	return n

func _dans_cone(pos: Vector3) -> bool:
	var v := pos - global_position
	v.y = 0.0
	var l := v.length()
	if l > SOUFFLE_LONG or l < 0.01:
		return l < 0.01
	return absf(Vector3(0, 0, 1).rotated(Vector3.UP, atan2(_souffle_dir.x, _souffle_dir.z)).signed_angle_to(v / l, Vector3.UP)) < SOUFFLE_DEMI_ANGLE

func _souffler() -> void:
	if is_instance_valid(_cone):
		var cone := _cone
		var mat: StandardMaterial3D = (cone as MeshInstance3D).material_override
		var tw := cone.create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
		tw.tween_callback(cone.queue_free)
		_cone = null
	for k in 4:   # gerbes de pixels de givre le long du souffle (pool GerbePixels)
		var d := _souffle_dir * (1.5 + k * 2.1)
		GerbePixels.emettre(self, global_position + Vector3(0, 1.0, 0) + d, (_souffle_dir + Vector3.UP * 0.4).normalized(), "givre_lueur", 1.4)
	Sons.jouer_a(self, ["mnstr5", "mnstr6"], global_position + Vector3.UP, 2.0, 0.1)
	if not joueur.mort and absf(joueur.global_position.y - global_position.y) < 3.0 and _dans_cone(joueur.global_position):
		joueur.recevoir_coup(degats * 0.9, global_position)

## Rayon horizontal de 1,3 m à hauteur de genou : libre si rien (hors lui, le joueur et les autres ennemis) ne le coupe.
func _libre(d: Vector3, longueur: float) -> bool:
	var de := global_position + Vector3(0, 0.55, 0)
	var q := PhysicsRayQueryParameters3D.create(de, de + d * longueur)
	var ex: Array[RID] = [get_rid()]
	if joueur != null:
		ex.append(joueur.get_rid())
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is CollisionObject3D and e != self:
			ex.append((e as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Direction voulue corrigée pour longer les obstacles : trois rayons (droit, ±35°, ±70°, ±110°), côté mémorisé pour ne pas
## hésiter ; si le bandit n'avance plus (coincé dans un angle), détour forcé d'une demi-seconde du côté opposé.
func _eviter(dir: Vector3, dt: float) -> Vector3:
	var avance := global_position.distance_to(_dernier)
	_dernier = global_position
	if _vit > 0.3 and avance < _vit * dt * 0.3:
		_t_bloque += dt
	else:
		_t_bloque = maxf(_t_bloque - dt, 0.0)
	if _t_bloque > 0.4:
		_t_bloque = 0.0
		_cote = -_cote
		_detour = 0.7
	if _detour > 0.0:
		_detour -= dt
		var forc := dir.rotated(Vector3.UP, _cote * 1.2)
		if _libre(forc, 1.0):
			return forc
	if _tenue > 0.0:
		_tenue -= dt
		if _libre(_dir_evit, 1.0):
			return _dir_evit
		_tenue = 0.0
	if _libre(dir, 1.4):
		return dir
	for a in [0.6, 1.2, 1.9]:
		for c in [_cote, -_cote]:
			var d := dir.rotated(Vector3.UP, c * a)
			if _libre(d, 1.2):
				_cote = c
				_dir_evit = d
				_tenue = 0.7
				return d
	_dir_evit = dir.rotated(Vector3.UP, _cote * 2.4)
	_tenue = 0.5
	return _dir_evit

## Appelé par l'épée du joueur (et les tests). Renvoie "bloque", "touche" ou "tue".
## `info` (facultatif, contrat avec l'épée FPS) : "type", "point", "direction", "normale", "zone", "attaque", "arme", "stagger",
## "collider" ; sans info, tout est déduit (CalculDegats.completer).
func recevoir_coup(quantite: float, origine_coup: Vector3, puissant := false, info: Dictionary = {}) -> String:
	if etat == MORT:
		return ""
	degeler()
	if etat == DORT and _attend:
		_attend = false
	var vers := origine_coup - global_position
	vers.y = 0.0
	var de_face := vers.normalized().dot(global_transform.basis.z) > 0.3
	var peut_bloquer := (type == "guerrier" or _os or boss == "jarl") and etat in [TRAQUE]
	var r := combat.analyser(quantite, origine_coup, puissant, info, {"de_face": de_face, "peut_bloquer": peut_bloquer,
		"en_attaque": etat == ATTAQUE, "coup_donne": _coup_donne, "hauteur_visee": CombatEnnemi.hauteur_visee(joueur, self)})
	if r["bloque"]:
		_jouer("Hit_Chest", 0.05, true)
		_duree_titube = 0.4
		_changer(TITUBE)
		combat.effets_blocage(r, false)
		return "bloque"
	# (le finisher n'est plus déclenché ici : c'est l'épée du joueur qui le lance, mains._tenter_finisher → subir_finisher)
	vie -= float(r["degats"])
	_eclair()
	if r["brise_garde"]:
		combat.effets_blocage(r, true)
	combat.effets_impact(r, joueur)
	if vie <= 0.0:
		_mourir_coup(r)
		return "tue"
	if etat in [DORT, GARDE, REVEIL, PATROUILLE]:
		_attend = false
		_changer(TRAQUE)
	var reaction := String(r["reaction"])
	if reaction == "etourdi" and combat.etourdi <= 0.0:
		combat.briser_posture()
		if etat in [APPEL, ANNONCE, SOUFFLE]:
			return "touche"   # un chef qui lance son pouvoir reste debout (mais sa garde est ouverte)
		_etourdir()
		return "touche"
	if etat in [APPEL, ANNONCE, SOUFFLE, ETOURDI, CHUTE]:
		return "touche"  # pouvoir en cours, étourdi ou au sol : seule la réaction procédurale (ReactionOs)
	if boss != "" and reaction == "leger" and randf() < 0.6:
		return "touche"  # les chefs encaissent mieux
	var recul := -vers.normalized() / maxf(combat.profil.poids, 0.3)
	match reaction:
		"chute":
			_chuter(recul * 2.5)
		"recul":
			_tituber(recul * 6.0, 0.85)
		"lourd":
			_tituber(recul * 3.5, 0.7)
		"moyen":
			_tituber(recul * 1.8, 0.55)
		_:
			if etat != ATTAQUE or r["interrompt"]:
				_tituber(recul * 0.8, 0.32)
	return "touche"

func _tituber(recul: Vector3, duree := 0.55) -> void:
	_recul = recul
	_duree_titube = duree
	_changer(TITUBE)
	_jouer(combat.anim_coup(), 0.05, true)   # selon la zone touchée
	anim.speed_scale = clampf(0.55 / duree, 0.6, 1.6)

## Posture brisée : étourdi (CombatEnnemi.etourdi s), fenêtre de finisher.
func _etourdir() -> void:
	_recul = Vector3.ZERO
	_changer(ETOURDI)
	_jouer("Hit_Head", 0.05, true)
	anim.speed_scale = 0.6

## Renversé : il tombe, reste au sol un instant (finisher « sol »), se relève.
func _chuter(recul: Vector3) -> void:
	_recul = recul
	_releve = false
	_changer(CHUTE)
	_jouer("Death01", 0.08, true)
	anim.speed_scale = 1.6

# --- finishers (API pour l'épée FPS : finisher_possible / subir_finisher) -------------------------------

## Catégorie de finisher possible pour ce joueur ("" = aucun) : "etourdi" (posture brisée), "sol" (renversé), "apres_parade",
## "rapide" (presque mort, posture entamée), "lateral" (étourdi ou presque mort, pris de côté).
func finisher_possible(j: Node3D) -> String:
	if etat == MORT or combat == null or etat in [DORT, APPEL, ANNONCE, SOUFFLE]:
		return ""
	return combat.finisher_possible(j, vie, vie_max)

## Achève l'ennemi par un finisher : mort spéciale (décapitation pour les catégories de taille, coup de grâce au sol…).
## `categorie` : celle de finisher_possible() (ou "puissant" : arme lourde) ; `info` : comme recevoir_coup. Renvoie "tue".
func subir_finisher(categorie: String, info: Dictionary = {}) -> String:
	if etat == MORT:
		return ""
	var o: Vector3 = info.get("origine", joueur.global_position if joueur else global_position - global_transform.basis.z)
	var i := CalculDegats.completer(info, self, vie, o, true, combat.hauteur)
	i["attaque"] = "finisher"
	i["categorie"] = categorie
	var r := {"info": i, "degats": vie, "stagger": 999.0, "critique": true, "impact": "finisher", "bloque": false, "brise_garde": false, "reaction": "finisher", "finisher": categorie}
	vie = 0.0
	if not info.has("finisher_nom"):
		_eclair()   # finisher aligné : l'éclair a déjà eu lieu au contact de la lame
	_mourir_coup(r, "finisher")
	return "tue"

func _mourir_coup(r: Dictionary, sorte := "") -> void:
	var i: Dictionary = r["info"]
	_mourir(i["origine"], float(r["degats"]), bool(i.get("puissant", false)), r, sorte if sorte != "" else combat.type_mort(r))

## Éclair blanc du coup reçu (en temps réel : il ne reste pas figé pendant l'arrêt sur image, et il ne masque plus les plaies).
func _eclair() -> void:
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_method(func(v: float) -> void:
		for mi in _mailles:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("eclair", v), 0.14, 0.0, 0.06)   # éclair bref et léger : la réaction du corps reste lisible (§8)

## Mort : le corps passe de l'animation au ragdoll, projeté dans le sens du coup ; morts variées selon le coup
## (CombatEnnemi.type_mort) : "legere" (s'effondre), "titubante" (encaisse, chancelle, puis tombe), "lourde", "recul" (projeté),
## "chute" (fauché aux jambes), "puissant" (projeté loin, sang à flots, voile rouge), "finisher" (décapitation, coup de grâce…).
## Le butin tombe et le signal mort (sauvegarde des morts) part dans TOUS les cas.
func _mourir(origine_coup := Vector3.ZERO, quantite := 20.0, puissant := false, r: Dictionary = {}, sorte := "") -> void:
	degeler()
	_changer(MORT)
	if is_instance_valid(_cone):
		_cone.queue_free()
	mort.emit(ident)
	collision_layer = 0
	collision_mask = 0
	var vitesse_avant := Vector3(velocity.x, 0.0, velocity.z).limit_length(6.0)
	velocity = Vector3.ZERO
	var dir := global_position - origine_coup
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z
	if sorte == "":
		sorte = "lourde" if puissant else "legere"
	var info: Dictionary = r.get("info", {})
	var categorie := String(r.get("finisher", ""))
	var force := (350.0 if puissant else 120.0) * clampf(quantite / (34.0 if puissant else 14.0), 0.7, 1.6)
	var haut := String(info.get("zone", "")) == "tete"
	var point: Vector3 = info.get("point", global_position + Vector3(0.0, 1.5 if haut else 1.15, 0.0) - dir * 0.2)
	var os_touche := "Head" if haut else "spine_03"
	var montee := 0.15
	var decapiter := false
	match sorte:
		"legere":
			force = 100.0
		"titubante":
			force = 70.0
		"lourde":
			force = maxf(force, 330.0)
		"recul":
			force = 520.0
			montee = 0.25
		"chute":
			force = 300.0
			os_touche = "calf_l" if randf() < 0.5 else "calf_r"
			montee = 0.05
		"puissant":
			force = 680.0
			montee = 0.35
		"finisher":
			# réglages selon le finisher joué (épée plantée : s'effondre ; décapitation ; coup de grâce au sol…)
			var rf := combat.reglage_mort_finisher(categorie, info)
			force = float(rf["force"])
			montee = float(rf["montee"])
			os_touche = String(rf["os"])
			decapiter = bool(rf["decapiter"])
	# l'animation de l'encaissement d'abord (mort titubante), puis le ragdoll
	var lancer := func() -> void:
		if not is_instance_valid(self) or not is_inside_tree():
			return
		_ragdoll = Ragdoll.equiper(modele) as Ragdoll
		if _ragdoll:
			if joueur:
				_ragdoll.ignorer(joueur)
			_ragdoll.endormir_apres(4.0)
			_ragdoll.declencher(dir * force + Vector3.UP * force * montee, point, os_touche, vitesse_avant)
		else:
			_jouer("Death01", 0.1, true)
		if decapiter:
			var imp := (Vector3(info.get("direction", dir)) * 0.6 + dir * 0.4 + Vector3.UP * 0.7).normalized() * 16.0
			Decapitation.decapiter(modele, imp, combat.profil.couleur_sang, combat.profil.sang, combat.profil.matiere)
	if sorte == "titubante":
		_jouer(combat.anim_coup(), 0.05, true)   # selon la zone touchée
		anim.speed_scale = 0.7
		get_tree().create_timer(0.38).timeout.connect(lancer)
	else:
		lancer.call()
	if combat.reaction_os:
		combat.reaction_os.active = sorte == "titubante"
	if sorte == "finisher":
		RetourImpact.son_finisher(self, point, combat.profil.matiere, decapiter)
	combat.effets_mort(r if not r.is_empty() else {"info": {"point": point, "direction": dir, "normale": -dir}}, sorte, joueur)
	_laisser_butin()

## Table de la bourse (data/butin/cadavres.json) : graine = ident (un même ennemi laisse toujours la même bourse).
func table_butin() -> String:
	return ButinTables.table_pour("bandit" if _humain else "draugr")

func _laisser_butin() -> void:
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = joueur
	b.hud = hud
	b.nom_corps = nom_affiche       # L3 : titre de la fenêtre de butin (« Fouiller » le corps)
	if ident != "":
		b.cle_sauvegarde = "ennemi:" + ident      # objets laissés dans le corps : sauvegardés (ButinTables.restes / corps)
	b.contenu = ButinTables.contenu(ButinTables.tirer_pour("ennemi:" + (ident if ident != "" else str(get_instance_id())), table_butin()))
	var rng := RandomNumberGenerator.new()   # or des chefs : même graine que la bourse (même chef = même somme)
	rng.seed = ButinTables.graine("ennemi_or:" + ident)
	if boss == "hrafn":
		b.contenu["pieces"] = rng.randi_range(90, 140)
	elif boss == "jarl":
		b.contenu["pieces"] = rng.randi_range(70, 110)
	get_parent().add_child(b)
	b.global_position = global_position + global_transform.basis.z * 0.6
