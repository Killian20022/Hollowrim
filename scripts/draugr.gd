extends CharacterBody3D
## Draugr : mort-vivant nordique (modèles squelettes KayKit, animés).
## Il dort au sol ou monte la garde ; il se réveille, traque, frappe, titube, meurt.
## Le guerrier porte un bouclier et bloque parfois les coups légers de face.

enum { DORT, REVEIL, GARDE, TRAQUE, ATTAQUE, TITUBE, MORT }

const MODELES := {
	"guerrier": "res://assets/modeles/squelettes/Skeleton_Warrior.glb",
	"sbire": "res://assets/modeles/squelettes/Skeleton_Minion.glb",
}
const LAME := preload("res://assets/modeles/squelettes/Skeleton_Blade.gltf")
const HACHE := preload("res://assets/modeles/squelettes/Skeleton_Axe.gltf")
const BOUCLIER := preload("res://assets/modeles/squelettes/Skeleton_Shield_Small_A.gltf")
const BOUCLE := ["Idle", "Idle_Combat", "Walking_D_Skeletons", "Running_C", "Blocking", "Skeletons_Inactive_Floor_Pose"]
const ATTAQUES := ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal"]

const GRAVITE := 13.0
const DETECTION := 17.0
const REVEIL_DISTANCE := 10.0
const ABANDON := 45.0
const PORTEE := 1.9
const MARCHE := 1.5
const COURSE := 3.4

var type := "guerrier"
var dort := false
var joueur: CharacterBody3D
var vie := 70.0
var vie_max := 70.0
var degats := 16.0
var nom_affiche := "Draugr"

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
var _squelette: Skeleton3D
var _os_tete := -1

func _ready() -> void:
	add_to_group("ennemis")
	if type == "sbire":
		vie_max = 45.0
		degats = 12.0
	vie = vie_max
	floor_snap_length = 0.4
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	add_child(forme)

	modele = load(MODELES[type]).instantiate()
	modele.scale = Vector3.ONE * 0.86
	add_child(modele)
	# os sales et bleuis par le froid
	Palette.convertir(modele, 128, Color(0.78, 0.82, 0.92), 0.3)
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		_mailles.append(mi)
		if mi.name.ends_with("Eyes"):
			mi.material_override = Palette.lueur(Color(0.6, 1.8, 2.4))
	var squelette: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	_armer(squelette, "handslot.r", HACHE if type == "sbire" else LAME)
	if type == "guerrier":
		_armer(squelette, "handslot.l", BOUCLIER)

	anim = modele.find_child("AnimationPlayer", true, false)
	# tête rétrécie après chaque animation : moins « jouet », plus mort-vivant
	_squelette = squelette
	_os_tete = squelette.find_bone("head")
	anim.mixer_applied.connect(_proportions)
	for nom in BOUCLE:
		if anim.has_animation(nom):
			anim.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
	origine = global_position
	if dort:
		etat = DORT
		_jouer("Skeletons_Inactive_Floor_Pose", 0.0)
	else:
		_jouer("Idle", 0.0)
		anim.seek(randf() * 2.0)

func _armer(squelette: Skeleton3D, os: String, scene: PackedScene) -> void:
	var accroche := BoneAttachment3D.new()
	accroche.bone_name = os
	squelette.add_child(accroche)
	var arme: Node3D = scene.instantiate()
	Palette.convertir(arme, 64, Color(0.75, 0.78, 0.86), 0.45)
	accroche.add_child(arme)
	for mi: MeshInstance3D in arme.find_children("*", "MeshInstance3D", true, false):
		_mailles.append(mi)

func _proportions() -> void:
	if _os_tete >= 0:
		_squelette.set_bone_pose_scale(_os_tete, Vector3.ONE * 0.74)

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

	match etat:
		DORT:
			regard = false
			if dist < REVEIL_DISTANCE and not joueur.mort:
				_changer(REVEIL)
				_jouer("Skeletons_Awaken_Floor", 0.1)
				Sons.jouer_a(self, ["giant1", "giant2", "giant3"], global_position + Vector3.UP, -2.0, 0.15)
		REVEIL:
			regard = _t > 0.6
			if _t >= _duree("Skeletons_Awaken_Floor") * 0.95:
				_changer(TRAQUE)
		GARDE:
			var retour := origine - global_position
			retour.y = 0.0
			if retour.length() > 1.5:
				dir = retour.normalized()
				vitesse = MARCHE
				_jouer("Walking_D_Skeletons")
			else:
				regard = false
				_jouer("Idle")
			if dist < DETECTION and not joueur.mort:
				_changer(TRAQUE)
				Sons.jouer_a(self, ["mnstr1", "mnstr2", "mnstr3", "mnstr4"], global_position + Vector3.UP, -4.0, 0.15)
		TRAQUE:
			if joueur.mort or dist > ABANDON:
				_changer(GARDE)
			elif dist > PORTEE:
				vitesse = COURSE if dist > 4.0 else MARCHE * 1.4
				_jouer("Running_C" if dist > 4.0 else "Walking_D_Skeletons")
			else:
				_jouer("Idle_Combat")
				if _recharge <= 0.0:
					_attaque = ATTAQUES.pick_random()
					_coup_donne = false
					_changer(ATTAQUE)
					_jouer(_attaque, 0.1, true)
		ATTAQUE:
			var duree := _duree(_attaque)
			regard = _t < duree * 0.3
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

	if regard and dist > 0.01:
		var cible := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, cible, 1.0 - exp(-8.0 * dt))
	_recul = _recul.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	velocity.x = dir.x * vitesse + _recul.x
	velocity.z = dir.z * vitesse + _recul.z
	move_and_slide()

## Appelé par l'épée du joueur. Renvoie "bloque", "touche" ou "tue".
func recevoir_coup(quantite: float, origine_coup: Vector3, puissant: bool) -> String:
	if etat == MORT:
		return ""
	var vers := origine_coup - global_position
	vers.y = 0.0
	var de_face := vers.normalized().dot(global_transform.basis.z) > 0.3
	if type == "guerrier" and not puissant and de_face and etat in [TRAQUE] and randf() < 0.3:
		_jouer("Block_Hit", 0.05, true)
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
	_jouer(["Hit_A", "Hit_B"].pick_random(), 0.05, true)

func _eclair() -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		for mi in _mailles:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("eclair", v), 0.9, 0.0, 0.18)

func _mourir() -> void:
	_changer(MORT)
	_jouer("Death_A", 0.1, true)
	collision_layer = 0
	collision_mask = 1
	Sons.jouer_a(self, ["mnstr5", "mnstr6"], global_position + Vector3.UP, 0.0, 0.1)
	Effets.eclats(self, global_position + Vector3(0, 0.8, 0), Color(0.75, 0.72, 0.6), 30, 4.0)
