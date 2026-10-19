extends CharacterBody3D
## Villageois : habitant du hameau (modèles KayKit animés, comme les draugrs).
## Il reste à son poste avec une petite activité, se promène de temps en temps,
## interpelle le joueur qui passe et lui parle quand on le regarde (touche E).
## Propriétés à poser AVANT add_child : donnees, joueur, dialogue, points.

enum { POSTE, ALLER, PAUSE, RETOUR }

const GRAVITE := 13.0
const MARCHE := 1.1
const DIST_REGARD := 4.0
const DIST_INTERPELLE := 5.0
const DIST_PARLER := 2.6
const DOT_PARLER := 0.85
const BOUCLE := ["Idle", "Walking_A", "Use_Item", "Interact", "Spellcasting", "Sit_Floor_Idle"]
## Activité au poste selon le lieu (une animation en boucle ; "PickUp" = ponctuelle).
const ACTIVITES := {
	"forge": "Use_Item",
	"puits": "Idle",
	"place": "Spellcasting",
	"enclos": "PickUp",
	"longue_maison": "Idle",
	"porte": "Idle",
}

var donnees: Dictionary = {}
var joueur: CharacterBody3D
var dialogue: Control
var points: Array = []  # de Vector3
var deja_parle := false
var quetes: Node = null  # posé par le monde

var etat := POSTE
var modele: Node3D
var anim: AnimationPlayer
var _anim := ""
var _t := 0.0
var _prochaine_promenade := 20.0
var _delai_interpelle := 0.0
var _delai_activite := 0.0
var _en_conversation := false
var _debut_conversation := 0.0
var _bloque := 0.0
var _invite := false
var _squelette: Skeleton3D
var _os_tete := -1

## Lit res://data/villageois.json et renvoie la liste des villageois (vide si absent ou invalide).
static func charger() -> Array:
	var chemin := "res://data/villageois.json"
	if not FileAccess.file_exists(chemin):
		push_warning("Villageois : fichier introuvable : " + chemin)
		return []
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		push_warning("Villageois : lecture impossible : " + chemin)
		return []
	var json: Variant = JSON.parse_string(f.get_as_text())
	if not (json is Dictionary) or not (json as Dictionary).get("villageois") is Array:
		push_warning("Villageois : JSON invalide : " + chemin)
		return []
	return (json as Dictionary)["villageois"]

func _ready() -> void:
	add_to_group("villageois")
	floor_snap_length = 0.4
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	add_child(forme)

	var nom_modele: String = donnees.get("modele", "Barbarian")
	var chemin := "res://assets/modeles/villageois/%s.glb" % nom_modele
	if not ResourceLoader.exists(chemin):
		push_warning("Villageois : modèle introuvable : " + chemin)
		chemin = "res://assets/modeles/villageois/Barbarian.glb"
	modele = load(chemin).instantiate()
	modele.scale = Vector3.ONE * 0.86
	add_child(modele)
	_ranger_accessoires()
	Palette.convertir(modele, 128, Color(0.86, 0.88, 0.95), 0.4)

	_squelette = modele.find_child("Skeleton3D", true, false)
	anim = modele.find_child("AnimationPlayer", true, false)
	if _squelette != null:
		_os_tete = _squelette.find_bone("head")
	if anim != null:
		anim.mixer_applied.connect(_proportions)
		for nom in BOUCLE:
			if anim.has_animation(nom):
				anim.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
	if points.is_empty():
		points.append(global_position)
	rotation.y = randf() * TAU
	_prochaine_promenade = randf_range(8.0, 40.0)
	_delai_interpelle = randf_range(0.0, 15.0)
	_activite(true)
	if anim != null:
		anim.seek(randf() * 2.0)

## Les modèles KayKit portent tous leurs accessoires à la fois (épées, boucliers, livres…) :
## on ne garde que ceux du rôle.
const ACCESSOIRES := {"garde": ["1H_Sword", "Round_Shield"], "forgeron": ["1H_Axe"], "chef": ["1H_Sword"], "chasseuse": ["Knife"], "volva": ["2H_Staff"], "ancienne": []}
const MOTS_ACCESSOIRES := ["Sword", "Shield", "Axe", "Crossbow", "Staff", "Wand", "Dagger", "Knife", "Mug", "Spellbook", "Bow", "Quiver", "Throwable"]

func _ranger_accessoires() -> void:
	var gardes: Array = ACCESSOIRES.get(donnees.get("id", ""), [])
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		var nom := String(mi.name)
		for mot in MOTS_ACCESSOIRES:
			if mot in nom and not nom in gardes:
				mi.visible = false

func _proportions() -> void:
	if _os_tete >= 0:
		_squelette.set_bone_pose_scale(_os_tete, Vector3.ONE * 0.8)

func nom_affiche() -> String:
	return donnees.get("nom", "Villageois")

## Appelé par le dialogue : renvoie les répliques (1re fois puis « apres »).
func parler() -> Array:
	# la première fois il se présente ; ses répliques de quête viennent ensuite
	var lignes: Array = [] if deja_parle else donnees.get("lignes", []).duplicate()
	var de_quete: Array = quetes.repliques(donnees.get("id", "")) if quetes != null else []
	if not de_quete.is_empty():
		lignes += de_quete
	elif deja_parle:
		lignes = donnees.get("apres", [])
	if lignes.is_empty():
		lignes = donnees.get("lignes", ["…"])
	deja_parle = true
	_en_conversation = true
	_debut_conversation = 0.0
	etat = POSTE
	_t = 0.0
	_jouer("Interact", 0.2)
	return lignes

## Facultatif : le dialogue peut prévenir de la fin (sinon détecté via joueur.en_dialogue).
func fin_conversation() -> void:
	_en_conversation = false
	_activite()

func _jouer(nom: String, fondu := 0.2) -> void:
	if anim == null or _anim == nom or not anim.has_animation(nom):
		return
	_anim = nom
	anim.play(nom, fondu)

## Animation d'activité du poste (PickUp : ponctuelle, entre deux Idle).
func _activite(immediat := false) -> void:
	var lieu: String = donnees.get("lieu", "")
	var nom: String = ACTIVITES.get(lieu, "Idle")
	if nom == "PickUp":
		nom = "Idle"
		_delai_activite = randf_range(4.0, 9.0)
	_jouer(nom, 0.0 if immediat else 0.3)

func _physics_process(dt: float) -> void:
	_t += dt
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	if joueur == null or not is_instance_valid(joueur):
		move_and_slide()
		return
	var vers := joueur.global_position - global_position
	vers.y = 0.0
	var dist := vers.length()
	var dir := vers / dist if dist > 0.01 else Vector3.ZERO

	# la conversation se termine d'elle-même quand le dialogue rend la main au joueur
	if _en_conversation:
		_debut_conversation += dt
		if not joueur.en_dialogue and _debut_conversation > 0.3:
			fin_conversation()

	var cap := Vector3.ZERO  # direction de marche
	var regarde := _en_conversation or dist < DIST_REGARD
	if _en_conversation:
		_t = 0.0
		if _debut_conversation > 1.2:
			_jouer("Idle", 0.3)
	else:
		match etat:
			POSTE:
				_t_poste(dt)
			ALLER:
				cap = _vers_point(points[_cible_index()], dt)
			PAUSE:
				if _t > _duree_pause:
					etat = RETOUR
					_t = 0.0
					_jouer("Walking_A", 0.3)
			RETOUR:
				cap = _vers_point(points[0], dt)
		if cap == Vector3.ZERO and etat == POSTE and anim != null and _anim == "Idle" \
				and ACTIVITES.get(donnees.get("lieu", ""), "") == "PickUp":
			_delai_activite -= dt
			if _delai_activite <= 0.0:
				_jouer("PickUp", 0.2)
				_delai_activite = randf_range(6.0, 14.0)
				get_tree().create_timer(anim.get_animation("PickUp").length).timeout.connect(_activite)

	# orientation : vers le joueur s'il est proche, sinon vers où il marche
	var vise := Vector3.ZERO
	if regarde:
		vise = dir
	elif cap != Vector3.ZERO:
		vise = cap
	if vise != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(vise.x, vise.z), 1.0 - exp(-6.0 * dt))

	velocity.x = cap.x * MARCHE
	velocity.z = cap.z * MARCHE
	move_and_slide()

	_interactions(dist, dt)

func _t_poste(_dt: float) -> void:
	if _t >= _prochaine_promenade and points.size() > 1:
		etat = ALLER
		_t = 0.0
		_bloque = 0.0
		_jouer("Walking_A", 0.3)
	elif _t >= _prochaine_promenade:
		_t = 0.0
		_prochaine_promenade = randf_range(15.0, 40.0)

var _cible := 1
var _duree_pause := 3.0

func _cible_index() -> int:
	return clampi(_cible, 0, points.size() - 1)

## Avance vers p ; renvoie la direction (ZERO une fois arrivé ou coincé).
func _vers_point(p: Vector3, dt: float) -> Vector3:
	var d := p - global_position
	d.y = 0.0
	var vitesse_reelle := Vector2(velocity.x, velocity.z).length()
	_bloque = _bloque + dt if (_t > 1.0 and vitesse_reelle < 0.2) else 0.0
	if d.length() < 0.25 or _bloque > 2.0 or _t > 40.0:
		_bloque = 0.0
		if etat == ALLER:
			# petite pause sur place puis retour au poste
			etat = PAUSE
			_t = 0.0
			_duree_pause = randf_range(2.0, 5.0)
			_jouer("Idle", 0.3)
		else:
			etat = POSTE
			_t = 0.0
			_prochaine_promenade = randf_range(15.0, 40.0)
			_cible = 1 + randi() % maxi(points.size() - 1, 1)
			_activite()
		return Vector3.ZERO
	return d.normalized()

func _interactions(dist: float, dt: float) -> void:
	if dialogue == null or not is_instance_valid(dialogue):
		return
	# interpellation au passage
	_delai_interpelle -= dt
	var phrases: Array = donnees.get("interpellations", [])
	if dist < DIST_INTERPELLE and _delai_interpelle <= 0.0 and not phrases.is_empty() and not _en_conversation:
		_delai_interpelle = 40.0
		dialogue.dire_au_passage(nom_affiche(), phrases.pick_random())
	# invite « E Parler » si le joueur est proche et regarde ce villageois
	var veut := false
	var cam: Camera3D = joueur.camera
	if dist < DIST_PARLER and not _en_conversation and cam != null:
		var avant := -cam.global_transform.basis.z
		var cible := (global_position + Vector3.UP * 1.4 - cam.global_position).normalized()
		veut = avant.dot(cible) > DOT_PARLER
	if veut and not _invite:
		_invite = true
		dialogue.inviter(self)
	elif not veut and _invite:
		_invite = false
		dialogue.retirer_invite(self)
