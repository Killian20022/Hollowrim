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

enum { DORT, REVEIL, GARDE, TRAQUE, ATTAQUE, TITUBE, MORT, PATROUILLE, VISE, APPEL, ANNONCE, SOUFFLE }

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

	var app := {"corps": "homme", "draugr": true, "tenue": {"tunique": Color(0.42, 0.38, 0.34), "ceinture": Color(0.6, 0.6, 0.6), "brassards": Color(0.65, 0.62, 0.6), "haillons": Color.WHITE}}
	if type == "guerrier":
		# lot 4 : cotte de mailles rouillée, épaulières, jupe de lanières, cape en lambeaux
		app["tenue"]["mante"] = Color(0.5, 0.48, 0.45)
		app["tenue"]["bottes"] = Color(0.6, 0.6, 0.6)
		app["tenue"]["epaulieres"] = Color.WHITE
		app["tenue"]["pteruges"] = Color.WHITE
		app["tenue"]["cape_courte"] = Color.WHITE
		app["etoffes"] = {"tunique": "mailles_rouille", "brassards": "draugr"}
		app["casque"] = "casque_draugr"
	app.merge(apparence, true)
	if app.has("perso"):
		modele = Personnage.creer(app["perso"])      # bandits vivants : personnage de base unifie (PersoDef)
	elif _os:
		modele = SqueletteGuerrier.creer({"arme": "arc" if archer else "epee"})
	else:
		modele = Humain.creer(app)
	modele.scale = Vector3.ONE * echelle
	add_child(modele)
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		_mailles.append(mi)
	var squelette: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	if not _os:
		if archer:
			_armer_arc(squelette)
		else:
			_armer(squelette)  # le squelette porte son arme dans son modèle
	_pieds = PiedsAuSol.equiper(modele, self) as PiedsAuSol
	anim = modele.get_node("Animations")
	_var = randf_range(0.94, 1.06)
	origine = global_position
	_pos_prec = global_position
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
	var src: Node3D = SqueletteGuerrier.creer({"arme": "arc"})
	var arc: MeshInstance3D = null
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) == "arc":
			arc = mi
	if arc == null or squelette == null:
		src.free()
		return
	var copie := MeshInstance3D.new()
	copie.mesh = arc.mesh
	copie.skin = arc.skin
	copie.name = "arc"
	squelette.add_child(copie)
	copie.skeleton = NodePath("..")
	var bois := Palette.materiau(Palette.tex("bois_arc", ["#2a1c10", "#3b2a18", "#4f3a22", "#5e4a30"], 4, 0.7), Vector2(1, 3))
	bois.set_shader_parameter("tex_neige", bois.get_shader_parameter("tex_base"))
	for s in copie.mesh.get_surface_count():
		copie.set_surface_override_material(s, bois)
	_mailles.append(copie)
	src.free()

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
		if etat == DORT:
			_changer(REVEIL)
			_reveiller()
			Sons.jouer_a(self, ["giant1", "giant2", "giant3"], global_position + Vector3.UP, -2.0, 0.15)

## Un chef (ou un cri) met en alerte : les gardes et patrouilleurs se lancent à la poursuite.
func alerter() -> void:
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
	return etat in [TRAQUE, ATTAQUE, TITUBE, VISE, APPEL, ANNONCE, SOUFFLE]

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
	var voulu := not (etat == DORT or etat == MORT or (etat == REVEIL and not debout))
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
						# parade réussie : le draugr est déséquilibré
						_tituber(Vector3.ZERO)
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
			if _t > 0.55:
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
	velocity.x = dir.x * _vit + _recul.x
	velocity.z = dir.z * _vit + _recul.z
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
			Effets.eclats(self, pos + Vector3(0, 0.6, 0), Color(0.6, 0.85, 1.4), 24, 3.0, true)
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
	for k in 7:
		var d := _souffle_dir * (1.5 + k * 1.2)
		Effets.eclats(self, global_position + Vector3(0, 1.0, 0) + d, Color(0.6, 0.9, 1.6), 14, 4.0, true)
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

## Appelé par l'épée du joueur. Renvoie "bloque", "touche" ou "tue".
func recevoir_coup(quantite: float, origine_coup: Vector3, puissant: bool) -> String:
	if etat == MORT:
		return ""
	if etat == DORT and _attend:
		_attend = false
	var vers := origine_coup - global_position
	vers.y = 0.0
	var de_face := vers.normalized().dot(global_transform.basis.z) > 0.3
	if (type == "guerrier" or _os or boss == "jarl") and not puissant and de_face and etat in [TRAQUE] and randf() < _bouclier:
		_jouer("Hit_Chest", 0.05, true)
		_changer(TITUBE)
		Sons.jouer_a(self, ["impactPlate_medium_000", "impactPlate_medium_001"], global_position + Vector3.UP, 0.0)
		Effets.eclats(self, global_position + Vector3(0, 1.1, 0) + vers.normalized() * 0.4, Color(3.0, 2.2, 0.8), 8, 2.5, true)
		return "bloque"
	if _os and puissant:
		quantite *= 1.3  # des os secs : les coups puissants (contondants) les brisent
	vie -= quantite
	_eclair()
	Effets.eclats(self, global_position + Vector3(0, 1.1, 0), Color(0.75, 0.72, 0.6), 18 if puissant else 10, 3.5)
	Sons.jouer_a(self, ["knifeSlice", "knifeSlice2", "chop"], global_position + Vector3.UP, 2.0 if puissant else 0.0)
	if vie <= 0.0:
		_mourir(origine_coup, quantite, puissant)
		return "tue"
	if etat in [DORT, GARDE, REVEIL, PATROUILLE]:
		_attend = false
		_changer(TRAQUE)
	if etat in [APPEL, ANNONCE, SOUFFLE]:
		return "touche"  # un chef qui lance son pouvoir ne titube pas
	if boss != "" and not puissant and randf() < 0.6:
		return "touche"  # les chefs encaissent mieux
	if puissant or etat != ATTAQUE or randf() < 0.3:
		_tituber(-vers.normalized() * (3.5 if puissant else 1.5))
	return "touche"

func _tituber(recul: Vector3) -> void:
	_recul = recul
	_changer(TITUBE)
	_jouer(["Hit_Chest", "Hit_Head"].pick_random(), 0.05, true)

func _eclair() -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		for mi in _mailles:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("eclair", v), 0.9, 0.0, 0.18)

## Mort : le corps passe de l'animation au ragdoll, projeté dans le sens du coup (de
## l'origine du coup vers lui) ; plus le coup est puissant, plus il chute loin.
func _mourir(origine_coup := Vector3.ZERO, quantite := 20.0, puissant := false) -> void:
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
	var force := (350.0 if puissant else 120.0) * clampf(quantite / (34.0 if puissant else 14.0), 0.7, 1.6)
	# coup porté vers le haut (tête levée du joueur) : la tête est touchée, sinon le torse
	var tete_joueur: Variant = joueur.get("tete") if joueur else null
	var haut: bool = tete_joueur != null and (tete_joueur as Node3D).rotation.x > 0.05
	var point := global_position + Vector3(0.0, 1.5 if haut else 1.15, 0.0) - dir * 0.2
	_ragdoll = Ragdoll.equiper(modele) as Ragdoll
	if _ragdoll:
		if joueur:
			_ragdoll.ignorer(joueur)
		_ragdoll.endormir_apres(4.0)
		_ragdoll.declencher(dir * force + Vector3.UP * force * 0.15, point, "Head" if haut else "spine_03", vitesse_avant)
	else:
		_jouer("Death01", 0.1, true)
	if _os:
		Sons.jouer_a(self, ["impactWood_heavy_000", "chop"], global_position + Vector3.UP, 4.0, 0.1)  # os qui s'entrechoquent
	else:
		Sons.jouer_a(self, ["mnstr5", "mnstr6"], global_position + Vector3.UP, 0.0, 0.1)
	Effets.eclats(self, global_position + Vector3(0, 0.8, 0), Color(0.75, 0.72, 0.6), 44 if _os else 30, 4.0)
	_laisser_butin()

func _laisser_butin() -> void:
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = joueur
	b.hud = hud
	b.contenu = {"pieces": randi_range(4, 14), "os_draugr": randi_range(1, 2)}
	if boss == "hrafn":
		b.contenu["pieces"] = randi_range(90, 140)
	elif boss == "jarl":
		b.contenu["pieces"] = randi_range(70, 110)
	if randf() < 0.5:
		b.contenu["poussiere_tombe"] = 1
	if (type == "guerrier" or _os) and randf() < 0.4:
		b.contenu["lame_antique"] = 1
	get_parent().add_child(b)
	b.global_position = global_position + global_transform.basis.z * 0.6
