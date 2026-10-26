class_name MenuStyle
## Thème commun des menus (écran titre, pause, options, crédits) : police pixel du jeu (Palette.police, taille native 16),
## cadre parchemin sombre du dialogue (assets/ui/dialogue_cadre.svg), couleurs du HUD. Tailles en pixels de l'écran
## logique 640x360 (EchelleUi : ×1 à 640x360, pixels nets).

const FOND := Color("#0b0f1a")
const PARCHEMIN := Color("#e8e0c8")
const OR := Color("#e8a64a")
const RUNE := Color("#6fd8ff")
const GRIS := Color("#6d7488")
const TAILLE := Palette.TAILLE_POLICE

static var _theme: Theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var police := Palette.police()
	t.default_font = police
	t.default_font_size = TAILLE
	# boutons : texte seul, doré et marqué d'un losange quand ils ont le focus (souris, clavier ou manette)
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = 12
	vide.content_margin_right = 12
	vide.content_margin_top = 1
	vide.content_margin_bottom = 1
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(OR, 0.14)
	focus.border_color = Color(OR, 0.55)
	focus.set_border_width_all(0)
	focus.border_width_left = 2
	focus.content_margin_left = 12
	focus.content_margin_right = 12
	focus.content_margin_top = 1
	focus.content_margin_bottom = 1
	focus.anti_aliasing = false
	for type in ["Button", "CheckButton"]:
		t.set_stylebox("normal", type, vide)
		t.set_stylebox("hover", type, focus)
		t.set_stylebox("pressed", type, focus)
		t.set_stylebox("focus", type, focus)
		t.set_stylebox("hover_pressed", type, focus)
		t.set_stylebox("disabled", type, vide)
		t.set_color("font_color", type, PARCHEMIN)
		t.set_color("font_hover_color", type, OR)
		t.set_color("font_focus_color", type, OR)
		t.set_color("font_pressed_color", type, OR)
		t.set_color("font_hover_pressed_color", type, OR)
		t.set_color("font_disabled_color", type, GRIS)
		t.set_color("font_outline_color", type, FOND)
		t.set_constant("outline_size", type, 0)
	t.set_color("font_color", "Label", PARCHEMIN)
	t.set_color("font_shadow_color", "Label", FOND)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	# curseurs : rail sombre, remplissage doré, poignée carrée
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("#1c2333")
	rail.border_color = Color("#3a4358")
	rail.set_border_width_all(1)
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	rail.anti_aliasing = false
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(OR, 0.8)
	plein.content_margin_top = 2
	plein.content_margin_bottom = 2
	plein.anti_aliasing = false
	var plein_focus := plein.duplicate() as StyleBoxFlat
	plein_focus.bg_color = OR
	t.set_stylebox("slider", "HSlider", rail)
	t.set_stylebox("grabber_area", "HSlider", plein)
	t.set_stylebox("grabber_area_highlight", "HSlider", plein_focus)
	var cadre_focus := StyleBoxFlat.new()
	cadre_focus.draw_center = false
	cadre_focus.border_color = OR
	cadre_focus.set_border_width_all(1)
	cadre_focus.anti_aliasing = false
	t.set_stylebox("focus", "HSlider", cadre_focus)
	var poignee := _carre(6, PARCHEMIN)
	t.set_icon("grabber", "HSlider", poignee)
	t.set_icon("grabber_highlight", "HSlider", _carre(6, OR))
	t.set_icon("grabber_disabled", "HSlider", _carre(6, GRIS))
	t.set_icon("tick", "HSlider", ImageTexture.new())
	# cases à cocher (CheckButton) : petit carré plein ou vide
	t.set_icon("checked", "CheckButton", _case(true))
	t.set_icon("unchecked", "CheckButton", _case(false))
	t.set_icon("checked_disabled", "CheckButton", _case(true))
	t.set_icon("unchecked_disabled", "CheckButton", _case(false))
	t.set_icon("checked_mirrored", "CheckButton", _case(true))
	t.set_icon("unchecked_mirrored", "CheckButton", _case(false))
	# cadre des panneaux : celui des dialogues
	t.set_stylebox("panel", "PanelContainer", cadre())
	t.set_stylebox("panel", "Panel", cadre())
	# défilement des crédits
	t.set_stylebox("scroll", "VScrollBar", rail)
	t.set_stylebox("grabber", "VScrollBar", plein)
	t.set_stylebox("grabber_highlight", "VScrollBar", plein_focus)
	t.set_stylebox("grabber_pressed", "VScrollBar", plein_focus)
	_theme = t
	return t

static func cadre() -> StyleBox:
	var c := StyleBoxTexture.new()
	c.texture = load("res://assets/ui/dialogue_cadre.svg")
	c.set_texture_margin_all(8)
	c.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	c.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	c.content_margin_left = 14
	c.content_margin_right = 14
	c.content_margin_top = 10
	c.content_margin_bottom = 10
	return c

static func _carre(cote: int, couleur: Color) -> ImageTexture:
	var img := Image.create(cote, cote + 4, false, Image.FORMAT_RGBA8)
	img.fill(couleur)
	for x in cote:
		img.set_pixel(x, 0, FOND)
		img.set_pixel(x, cote + 3, FOND)
	for y in cote + 4:
		img.set_pixel(0, y, FOND)
		img.set_pixel(cote - 1, y, FOND)
	return ImageTexture.create_from_image(img)

static func _case(cochee: bool) -> ImageTexture:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 10:
		for c: Vector2i in [Vector2i(i, 0), Vector2i(i, 9), Vector2i(0, i), Vector2i(9, i)]:
			img.set_pixelv(c, PARCHEMIN)
	if cochee:
		for y in range(2, 8):
			for x in range(2, 8):
				img.set_pixel(x, y, OR)
	return ImageTexture.create_from_image(img)

## Bouton de menu : le survol de la souris lui donne le focus (une seule surbrillance pour souris, clavier et manette).
static func bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(func() -> void:
		Sons.jouer(b, ["cloth1", "cloth2"], -14.0)
		action.call())
	return b

## Étiquette en police pixel ; `echelle` entière (2, 3…) pour les titres (reste net).
static func etiquette(texte: String, couleur := PARCHEMIN, echelle := 1) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_color_override("font_color", couleur)
	if echelle > 1:
		l.add_theme_font_size_override("font_size", TAILLE * echelle)
		l.add_theme_constant_override("shadow_offset_x", echelle)
		l.add_theme_constant_override("shadow_offset_y", echelle)
	return l

## Relie les boutons d'une colonne en boucle (haut/bas) pour le clavier et la manette.
static func chainer(boutons: Array) -> void:
	var actifs := boutons.filter(func(b: Control) -> bool: return b.visible and not (b is BaseButton and b.disabled))
	for i in actifs.size():
		var b: Control = actifs[i]
		b.focus_neighbor_top = b.get_path_to(actifs[(i - 1 + actifs.size()) % actifs.size()])
		b.focus_neighbor_bottom = b.get_path_to(actifs[(i + 1) % actifs.size()])
