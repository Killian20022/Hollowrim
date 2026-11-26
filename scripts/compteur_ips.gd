extends CanvasLayer
## Compteur d'images par seconde en haut à droite (option « Afficher les IPS », menu Options > affichage, désactivé par défaut).
## Autoload : présent sur l'écran titre comme en partie. Rafraîchi 2 fois par seconde (moyenne d'Engine) ; couleur selon le
## niveau (vert >= 50, jaune >= 30, rouge en dessous). Coût nul quand l'option est coupée (calque caché, aucun calcul).

const PERIODE := 0.5
var _texte: Label
var _t := 0.0

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS   # reste à jour dans le menu pause
	_texte = Label.new()
	_texte.name = "Ips"
	_texte.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texte.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_texte.offset_left = -90.0
	_texte.offset_right = -4.0
	_texte.offset_top = 2.0
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte.add_theme_font_size_override("font_size", 10)
	_texte.add_theme_constant_override("outline_size", 3)
	_texte.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_texte)
	visible = false

func _process(delta: float) -> void:
	_t += delta
	if _t < PERIODE:
		return
	_t = 0.0
	# --sans-hud (captures, planches) : pas de compteur sur les images
	visible = bool(Jeu.option("affichage", "afficher_ips")) and not OS.get_cmdline_user_args().has("--sans-hud")
	if not visible:
		return
	var ips := Engine.get_frames_per_second()
	_texte.text = "%d IPS" % ips
	_texte.add_theme_color_override("font_color",
		Color(0.55, 0.95, 0.5) if ips >= 50.0 else (Color(1.0, 0.85, 0.35) if ips >= 30.0 else Color(1.0, 0.4, 0.35)))
