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
## Activité au poste selon le lieu (une animation en boucle ; "PickUp" = ponctuelle).
const ACTIVITES := {
	"forge": "Fixing_Kneeling",
	"puits": "Idle",
	"place": "Spell_Simple_Idle",
	"enclos": "PickUp_Table",
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

	modele = Humain.creer(APPARENCES.get(donnees.get("id", ""), APPARENCES["chef"]))
	add_child(modele)
	anim = modele.get_node("Animations")
	if points.is_empty():
		points.append(global_position)
	rotation.y = randf() * TAU
	_prochaine_promenade = randf_range(8.0, 40.0)
	_delai_interpelle = randf_range(0.0, 15.0)
	_activite(true)
	if anim != null:
		anim.seek(randf() * 2.0)

## Allure de chaque habitant (corps, couleurs de la tenue, cheveux) ; trousse commune :
## pantalon, bottes et ceinture.
const C := Color.WHITE
const APPARENCES := {
	"chef": {"corps": "femme", "tenue": {"tunique": Color(0.42, 0.5, 0.78), "mante": Color(1.15, 1.1, 1.05), "brassards": C, "pantalon": Color(0.7, 0.65, 0.6), "bottes": C, "ceinture": C},
		"cheveux": "Hair_Long", "teinte_cheveux": Color(1.0, 0.82, 0.55)},
	"forgeron": {"corps": "homme", "tenue": {"tunique": Color(0.62, 0.48, 0.38), "brassards": C, "gants": C, "pantalon": Color(0.65, 0.6, 0.55), "bottes": C, "ceinture": C},
		"cheveux": "Hair_Buzzed", "barbe": true, "teinte_cheveux": Color(0.35, 0.22, 0.12), "peau": Color(0.95, 0.8, 0.72)},
	"chasseuse": {"corps": "femme", "tenue": {"tunique": Color(0.45, 0.58, 0.4), "mante": Color(0.95, 0.85, 0.75), "brassards": C, "gants": C, "pantalon": Color(0.6, 0.55, 0.5), "bottes": C, "ceinture": C},
		"cheveux": "Hair_Buns", "teinte_cheveux": Color(0.85, 0.38, 0.2)},
	"volva": {"corps": "femme", "tenue": {"tunique": Color(0.48, 0.38, 0.6), "mante": Color(0.45, 0.45, 0.5), "pantalon": Color(0.5, 0.45, 0.5), "bottes": C, "ceinture": C},
		"cheveux": "Hair_Long", "teinte_cheveux": Color(1.15, 1.15, 1.2), "peau": Color(0.9, 0.85, 0.85)},
	"garde": {"corps": "homme", "tenue": {"tunique": Color(0.72, 0.3, 0.26), "mante": C, "brassards": C, "gants": C, "pantalon": Color(0.65, 0.6, 0.55), "bottes": C, "ceinture": C},
		"cheveux": "Hair_SimpleParted", "barbe": true, "teinte_cheveux": Color(0.55, 0.38, 0.22), "casque": "casque_nasal", "bouclier": true},
	"ancienne": {"corps": "femme", "tenue": {"tunique": Color(0.58, 0.52, 0.46), "mante": Color(0.85, 0.8, 0.75), "pantalon": Color(0.55, 0.5, 0.45), "bottes": C, "ceinture": C},
		"cheveux": "Hair_Buns", "teinte_cheveux": Color(1.1, 1.1, 1.1), "peau": Color(0.92, 0.84, 0.8)},
}

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
	if nom == "PickUp_Table":
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
			_jouer("Idle_Talking", 0.3)
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
					_jouer("Walk", 0.3)
			RETOUR:
				cap = _vers_point(points[0], dt)
		if cap == Vector3.ZERO and etat == POSTE and anim != null and _anim == "Idle" \
				and ACTIVITES.get(donnees.get("lieu", ""), "") == "PickUp_Table":
			_delai_activite -= dt
			if _delai_activite <= 0.0:
				_jouer("PickUp_Table", 0.2)
				_delai_activite = randf_range(6.0, 14.0)
				get_tree().create_timer(anim.get_animation("PickUp_Table").length).timeout.connect(_activite)

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
		_jouer("Walk", 0.3)
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
