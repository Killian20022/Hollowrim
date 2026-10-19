extends CharacterBody3D
## Draugr : mort-vivant nordique (modèles squelettes KayKit, animés).
## Il dort au sol ou monte la garde ; il se réveille, traque, frappe, titube, meurt.
## Le guerrier porte un bouclier et bloque parfois les coups légers de face.

enum { DORT, REVEIL, GARDE, TRAQUE, ATTAQUE, TITUBE, MORT }

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

func _ready() -> void:
	add_to_group("ennemis")
	if type == "sbire":
		vie_max = 45.0
		degats = 12.0
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

	var app := {"corps": "homme", "draugr": true, "tenue": {"tunique": Color(0.42, 0.38, 0.34), "ceinture": Color(0.6, 0.6, 0.6), "brassards": Color(0.65, 0.62, 0.6)}}
	if type == "guerrier":
		app["tenue"]["mante"] = Color(0.5, 0.48, 0.45)
		app["tenue"]["bottes"] = Color(0.6, 0.6, 0.6)
		app["casque"] = "casque_draugr"
	app.merge(apparence, true)
	modele = Humain.creer(app)
	modele.scale = Vector3.ONE * echelle
	add_child(modele)
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		_mailles.append(mi)
	var squelette: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	_armer(squelette)
	anim = modele.get_node("Animations")
	_var = randf_range(0.94, 1.06)
	origine = global_position
	if dort:
		etat = DORT
		if debout:
			_jouer("Idle", 0.0)
			anim.speed_scale = 0.0  # figé dans sa niche
		else:
			# allongé : dernière image de l'animation de mort
			_jouer("Death01", 0.0)
			anim.seek(_duree("Death01") - 0.05, true)
			anim.pause()
	else:
		_jouer("Sword_Idle", 0.0)
		anim.seek(randf() * 2.0)  # phase au hasard : les gardes ne bougent pas en même temps

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

func vivant() -> bool:
	return etat != MORT

func en_combat() -> bool:
	return etat in [TRAQUE, ATTAQUE, TITUBE]

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

func _physics_process(dt: float) -> void:
	_t += dt
	_recharge -= dt
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	var vers := joueur.global_position - global_position
	vers.y = 0.0
	var dist := vers.length()
	var dir := vers / dist if dist > 0.01 else Vector3.ZERO
	var vitesse := 0.0
	var regard := true
	var vitesse_rot := ROT_MAX
	var loco := ""  # animation de déplacement voulue ("" = sur place)

	match etat:
		DORT:
			regard = false
			if dist < REVEIL_DISTANCE and not joueur.mort:
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
				vitesse = MARCHE
				loco = "Walk"
			else:
				regard = false
				_jouer("Sword_Idle")
			if dist < DETECTION and not joueur.mort:
				_changer(TRAQUE)
				Sons.jouer_a(self, ["mnstr1", "mnstr2", "mnstr3", "mnstr4"], global_position + Vector3.UP, -4.0, 0.15)
		TRAQUE:
			if joueur.mort or dist > ABANDON:
				_changer(GARDE)
			elif dist > PORTEE:
				vitesse = COURSE if dist > 4.0 else MARCHE_PROCHE
				loco = "Jog_Fwd" if dist > 4.0 else "Walk"
			else:
				_jouer("Sword_Idle")
				if _recharge <= 0.0:
					_attaque = ATTAQUES.pick_random()
					_coup_donne = false
					_changer(ATTAQUE)
					_jouer(_attaque, 0.1, true)
		ATTAQUE:
			var duree := _duree(_attaque)
			regard = _t < duree * 0.45  # il se vise avant de frapper
			vitesse_rot = 10.0
			if not _coup_donne and _t >= duree * 0.42:
				_coup_donne = true
				Sons.jouer_a(self, ["swing", "swing2", "swing3"], global_position + Vector3.UP, -6.0, 0.2)
				var face := global_transform.basis.z
				if dist < PORTEE + 0.6 and dir.dot(Vector3(face.x, 0, face.z).normalized()) > 0.4:
					var r: String = joueur.recevoir_coup(degats, global_position)
					if r == "parade":
						# parade réussie : le draugr est déséquilibré
						_tituber(Vector3.ZERO)
						return
			if _t >= duree * 0.92:
				_recharge = randf_range(0.5, 1.6)
				_changer(TRAQUE)
		TITUBE:
			regard = false
			if _t > 0.55:
				_changer(TRAQUE)
		MORT:
			regard = false
			if _t > 30.0:
				queue_free()

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

## Appelé par l'épée du joueur. Renvoie "bloque", "touche" ou "tue".
func recevoir_coup(quantite: float, origine_coup: Vector3, puissant: bool) -> String:
	if etat == MORT:
		return ""
	var vers := origine_coup - global_position
	vers.y = 0.0
	var de_face := vers.normalized().dot(global_transform.basis.z) > 0.3
	if type == "guerrier" and not puissant and de_face and etat in [TRAQUE] and randf() < 0.3:
		_jouer("Hit_Chest", 0.05, true)
		_changer(TITUBE)
		Sons.jouer_a(self, ["impactPlate_medium_000", "impactPlate_medium_001"], global_position + Vector3.UP, 0.0)
		Effets.eclats(self, global_position + Vector3(0, 1.1, 0) + vers.normalized() * 0.4, Color(3.0, 2.2, 0.8), 8, 2.5, true)
		return "bloque"
	vie -= quantite
	_eclair()
	Effets.eclats(self, global_position + Vector3(0, 1.1, 0), Color(0.75, 0.72, 0.6), 18 if puissant else 10, 3.5)
	Sons.jouer_a(self, ["knifeSlice", "knifeSlice2", "chop"], global_position + Vector3.UP, 2.0 if puissant else 0.0)
	if vie <= 0.0:
		_mourir()
		return "tue"
	if etat in [DORT, GARDE, REVEIL]:
		_changer(TRAQUE)
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

func _mourir() -> void:
	_changer(MORT)
	mort.emit(ident)
	_jouer("Death01", 0.1, true)
	collision_layer = 0
	collision_mask = 1
	Sons.jouer_a(self, ["mnstr5", "mnstr6"], global_position + Vector3.UP, 0.0, 0.1)
	Effets.eclats(self, global_position + Vector3(0, 0.8, 0), Color(0.75, 0.72, 0.6), 30, 4.0)
	_laisser_butin()

func _laisser_butin() -> void:
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = joueur
	b.hud = hud
	b.contenu = {"pieces": randi_range(4, 14), "os_draugr": randi_range(1, 2)}
	if randf() < 0.5:
		b.contenu["poussiere_tombe"] = 1
	if type == "guerrier" and randf() < 0.4:
		b.contenu["lame_antique"] = 1
	get_parent().add_child(b)
	b.global_position = global_position + global_transform.basis.z * 0.6
