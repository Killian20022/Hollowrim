extends Control
## HUD pixel art (écran 480x270) : boussole en haut, vie et vigueur en bas,
## barre de l'ennemi frappé. Les barres s'effacent quand tout est plein, comme dans Skyrim.
## Coordonnées : voir assets/ui/LISEZMOI.md.

const CADRE := preload("res://assets/ui/barre_cadre.svg")
const BOUSSOLE := preload("res://assets/ui/boussole.svg")
const REPERE := preload("res://assets/ui/boussole_repere.svg")
const LETTRES := preload("res://assets/ui/lettres_boussole.svg")
const RETICULE := preload("res://assets/ui/reticule.svg")
const ENNEMI := preload("res://assets/ui/indicateur_degat.svg")

const VIE := [Color("#e0574a"), Color("#b8322a"), Color("#7a1c1c")]
const VIGUEUR := [Color("#5fc27f"), Color("#2f8a56"), Color("#1f5a3a")]
const FOND := Color("#0b0f1a")
const PX_PAR_DEGRE := 0.8  # 150 px de bandeau ≈ 190° visibles
const CENTRE := 240.0

var joueur: CharacterBody3D
var lieux: Array = []  # [position, couleur] : points d'intérêt sur la boussole
var _a_vie := 0.0
var _a_vigueur := 0.0
var _a_cible := 0.0
var _cible: Node = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	if joueur == null:
		return
	var combat := false
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.en_combat():
			combat = true
			break
	var k := 1.0 - exp(-5.0 * dt)
	_a_vie = lerpf(_a_vie, 1.0 if (joueur.vie < joueur.vie_max - 0.5 or combat) else 0.0, k)
	_a_vigueur = lerpf(_a_vigueur, 1.0 if (joueur.vigueur < joueur.vigueur_max - 0.5 or combat) else 0.0, k)
	if joueur.ennemi_vise != null:
		_cible = joueur.ennemi_vise
		joueur.ennemi_vise = null
		_a_cible = 4.0
	_a_cible -= dt
	if _cible != null and not is_instance_valid(_cible):
		_cible = null
	queue_redraw()

func _barre(pos: Vector2, ratio: float, couleurs: Array, alpha: float) -> void:
	if alpha < 0.02:
		return
	var blanc := Color(1, 1, 1, alpha)
	draw_rect(Rect2(pos + Vector2(3, 2), Vector2(74, 3)), Color(FOND, alpha))
	# la barre se vide vers le centre
	var largeur := roundi(74.0 * clampf(ratio, 0.0, 1.0))
	var x := pos.x + 3.0 + floorf((74 - largeur) * 0.5)
	for ligne in 3:
		draw_rect(Rect2(x, pos.y + 2 + ligne, largeur, 1), Color(couleurs[ligne], alpha))
	draw_texture(CADRE, pos, blanc)

func _draw() -> void:
	if joueur == null:
		return
	# --- boussole ---
	draw_texture(BOUSSOLE, Vector2(160, 4))
	var cap := rad_to_deg(-joueur.rotation.y)
	for i in 8:
		var dx := wrapf(i * 45.0 - cap, -180.0, 180.0) * PX_PAR_DEGRE
		if absf(dx) > 72.0:
			continue
		var x := floorf(CENTRE + dx)
		if i % 2 == 0:
			draw_texture_rect_region(LETTRES, Rect2(x - 2, 6, 5, 7), Rect2((i / 2) * 6, 0, 5, 7))
		else:
			draw_rect(Rect2(x, 8, 1, 3), Color("#8a96ad"))
	for lieu in lieux:
		_marqueur(lieu[0], null, lieu[1])
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.en_combat() and e.global_position.distance_to(joueur.global_position) < 50.0:
			_marqueur(e.global_position, ENNEMI, Color.WHITE)
	draw_texture(REPERE, Vector2(238, 0))

	# --- réticule, barres ---
	draw_texture(RETICULE, Vector2(238, 133), Color(1, 1, 1, 0.7))
	_barre(Vector2(16, 256), joueur.vie / joueur.vie_max, VIE, _a_vie)
	_barre(Vector2(384, 256), joueur.vigueur / joueur.vigueur_max, VIGUEUR, _a_vigueur)
	if _cible != null and _a_cible > 0.0:
		_barre(Vector2(200, 19), _cible.vie / _cible.vie_max, VIE, clampf(_a_cible, 0.0, 1.0))

func _marqueur(pos: Vector3, tex: Texture2D, couleur: Color) -> void:
	var d := pos - joueur.global_position
	var dx := wrapf(rad_to_deg(atan2(d.x, -d.z)) - rad_to_deg(-joueur.rotation.y), -180.0, 180.0) * PX_PAR_DEGRE
	if absf(dx) > 72.0:
		return
	var x := floorf(CENTRE + dx)
	if tex != null:
		draw_texture(tex, Vector2(x - 2, 7))
	else:
		draw_rect(Rect2(x - 1, 8, 3, 3), Color("#0b0f1a"))
		draw_rect(Rect2(x, 9, 1, 1), couleur)
