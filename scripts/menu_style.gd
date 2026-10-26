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
	# boutons : texte seul ; avec le focus (souris, clavier ou manette), contour bleu et texte givré comme le menu principal
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = 12
	vide.content_margin_right = 12
	vide.content_margin_top = 1
	vide.content_margin_bottom = 1
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(RUNE, 0.12)
	focus.border_color = Color(RUNE, 0.7)
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
		t.set_color("font_hover_color", type, GIVRE)
		t.set_color("font_focus_color", type, GIVRE)
		t.set_color("font_pressed_color", type, GIVRE)
		t.set_color("font_hover_pressed_color", type, GIVRE)
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

# --- style « runique » du menu principal (écran titre en haute définition) -------------------------------------------------
## Menu principal (scripts/ecran_titre.gd) dessiné à la résolution de l'écran, aux proportions de ref_menu/reference.png :
## fond sombre translucide, bordure d'acier, losange runique, contour bleu lumineux sur l'élément choisi, police à empattements
## (Alegreya, OFL) rendue en MSDF (nette à toute échelle). Tailles en pixels de l'image de référence (1672x941), que l'écran titre
## met à l'échelle de la fenêtre. Le menu pause reste en police pixel, mais reprend le contour bleu (focus) et les couleurs.

const ACIER := Color("#80858e")          # bordure métallique
const ACIER_SOMBRE := Color("#3b4049")   # filet intérieur, bordures éteintes
const ARGENT := Color("#b4b7bd")         # texte normal
const GIVRE := Color("#d8eeff")          # texte sélectionné
const LUEUR := Color("#46b8ff")          # contour bleu lumineux
const NUIT := Color(0.035, 0.047, 0.066, 0.74)   # fond des boutons
const NUIT_BLEUE := Color(0.045, 0.085, 0.135, 0.80)   # fond du bouton sélectionné
const ETEINT := Color("#5b6069")         # texte désactivé
const PANNEAU := Color(0.03, 0.04, 0.058, 0.90)       # fond des panneaux (Charger, Options…)

static var _polices := {}
static var _theme_titre: Theme

## Police à empattements du menu principal (Alegreya variable, `graisse` 400 à 900), en MSDF.
static func police_titre(graisse := 500) -> Font:
	return _police_msdf("res://assets/polices/Alegreya-Variable.ttf", graisse)

## Capitales gravées (Cinzel variable) : titres des panneaux, écran de chargement.
static func police_capitales(graisse := 600) -> Font:
	return _police_msdf("res://assets/polices/Cinzel-Variable.ttf", graisse)

static func _police_msdf(chemin: String, graisse: int) -> Font:
	var cle := "%s:%d" % [chemin, graisse]
	if _polices.has(cle):
		return _polices[cle]
	var base_cle := chemin
	var base: FontFile = _polices.get(base_cle)
	if base == null:
		base = (load(chemin) as FontFile).duplicate()
		base.multichannel_signed_distance_field = true
		base.msdf_pixel_range = 12
		base.msdf_size = 64
		base.generate_mipmaps = true
		_polices[base_cle] = base
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): graisse}
	_polices[cle] = v
	return v

## À appeler quand l'écran titre se ferme (ressources statiques libérées avant l'arrêt du moteur de rendu, voir Palette.vider).
static func vider_titre() -> void:
	_polices.clear()
	_theme_titre = null

## Thème des panneaux du menu principal (Charger, Options, Crédits, confirmation), en pixels de l'image de référence.
static func theme_titre() -> Theme:
	if _theme_titre != null:
		return _theme_titre
	var t := Theme.new()
	t.default_font = police_titre(500)
	t.default_font_size = 30
	var normal := _boite(NUIT, ACIER_SOMBRE, 1.5)
	var allume := _boite(NUIT_BLEUE, LUEUR, 2.0)
	allume.shadow_color = Color(LUEUR, 0.35)
	allume.shadow_size = 8
	var eteint := _boite(Color(NUIT, 0.4), Color(ACIER_SOMBRE, 0.5), 1.0)
	var cadre_case := StyleBoxFlat.new()   # case à cocher : simple liseré bleu autour, sans fond
	cadre_case.draw_center = false
	cadre_case.border_color = Color(LUEUR, 0.8)
	cadre_case.set_border_width_all(1)
	cadre_case.set_corner_radius_all(3)
	cadre_case.shadow_color = Color(LUEUR, 0.25)
	cadre_case.shadow_size = 4
	cadre_case.content_margin_left = 6
	cadre_case.content_margin_right = 6
	for type in ["Button", "CheckButton"]:
		var foc := allume if type == "Button" else cadre_case
		t.set_stylebox("normal", type, normal if type == "Button" else StyleBoxEmpty.new())
		t.set_stylebox("hover", type, foc)
		t.set_stylebox("pressed", type, foc if type == "Button" else StyleBoxEmpty.new())
		t.set_stylebox("focus", type, foc)
		t.set_stylebox("hover_pressed", type, foc)
		t.set_stylebox("disabled", type, eteint)
		t.set_color("font_color", type, ARGENT)
		t.set_color("font_hover_color", type, GIVRE)
		t.set_color("font_focus_color", type, GIVRE)
		t.set_color("font_pressed_color", type, GIVRE)
		t.set_color("font_hover_pressed_color", type, GIVRE)
		t.set_color("font_disabled_color", type, ETEINT)
		t.set_constant("h_separation", type, 14)
	t.set_color("font_color", "Label", ARGENT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)
	# curseurs : rail d'acier, remplissage bleu, poignée en losange
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.02, 0.03, 0.045, 0.9)
	rail.border_color = ACIER_SOMBRE
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(2)
	rail.content_margin_top = 4
	rail.content_margin_bottom = 4
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(LUEUR, 0.55)
	plein.set_corner_radius_all(2)
	plein.content_margin_top = 4
	plein.content_margin_bottom = 4
	var plein_focus := plein.duplicate() as StyleBoxFlat
	plein_focus.bg_color = LUEUR
	plein_focus.shadow_color = Color(LUEUR, 0.4)
	plein_focus.shadow_size = 5
	t.set_stylebox("slider", "HSlider", rail)
	t.set_stylebox("grabber_area", "HSlider", plein)
	t.set_stylebox("grabber_area_highlight", "HSlider", plein_focus)
	var cadre_focus := StyleBoxFlat.new()
	cadre_focus.draw_center = false
	cadre_focus.border_color = Color(LUEUR, 0.7)
	cadre_focus.set_border_width_all(1)
	cadre_focus.set_corner_radius_all(3)
	cadre_focus.expand_margin_left = 6
	cadre_focus.expand_margin_right = 6
	cadre_focus.expand_margin_top = 4
	cadre_focus.expand_margin_bottom = 4
	t.set_stylebox("focus", "HSlider", cadre_focus)
	t.set_icon("grabber", "HSlider", _icone_losange(26, ARGENT, false))
	t.set_icon("grabber_highlight", "HSlider", _icone_losange(26, GIVRE, true))
	t.set_icon("grabber_disabled", "HSlider", _icone_losange(26, ETEINT, false))
	t.set_icon("tick", "HSlider", ImageTexture.new())
	for nom in ["checked", "checked_disabled", "checked_mirrored", "checked_disabled_mirrored"]:
		t.set_icon(nom, "CheckButton", _icone_case(30, true))
	for nom in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]:
		t.set_icon(nom, "CheckButton", _icone_case(30, false))
	t.set_stylebox("panel", "PanelContainer", panneau_titre())
	t.set_stylebox("panel", "Panel", panneau_titre())
	t.set_stylebox("scroll", "VScrollBar", rail)
	t.set_stylebox("grabber", "VScrollBar", plein)
	t.set_stylebox("grabber_highlight", "VScrollBar", plein_focus)
	t.set_stylebox("grabber_pressed", "VScrollBar", plein_focus)
	t.set_stylebox("tooltip_panel", "TooltipPanel", panneau_titre())
	_theme_titre = t
	return t

static func _boite(fond: Color, bord: Color, epaisseur: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fond
	b.border_color = bord
	b.set_border_width_all(int(ceilf(epaisseur)))
	b.set_corner_radius_all(2)
	b.corner_detail = 2
	b.content_margin_left = 22
	b.content_margin_right = 22
	b.content_margin_top = 6
	b.content_margin_bottom = 8
	b.anti_aliasing = true
	return b

## Cadre des panneaux du menu principal : nuit translucide, double filet d'acier (le filet intérieur est dessiné par l'ombre).
static func panneau_titre() -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = PANNEAU
	c.border_color = ACIER
	c.set_border_width_all(2)
	c.set_corner_radius_all(3)
	c.shadow_color = Color(0, 0, 0, 0.55)
	c.shadow_size = 18
	c.content_margin_left = 40
	c.content_margin_right = 40
	c.content_margin_top = 30
	c.content_margin_bottom = 30
	return c

## Losange runique (bouton du menu, rail, écran de chargement) : losange extérieur, losange intérieur, trait vertical à deux crochets.
## `allume` 0..1 : de l'acier au bleu lumineux, avec halo.
static func dessiner_losange(ci: CanvasItem, c: Vector2, r: float, allume: float, eteint := false) -> void:
	var base := ETEINT if eteint else ACIER
	var c_trait := base.lerp(LUEUR.lerp(Color.WHITE, 0.25), allume)
	if allume > 0.01:
		for k in 3:   # halo
			var rr := r * (1.25 + 0.3 * k)
			ci.draw_colored_polygon(_losange_pts(c, rr), Color(LUEUR, 0.07 * allume))
		ci.draw_colored_polygon(_losange_pts(c, r * 0.62), Color(LUEUR, 0.30 * allume))
	ci.draw_polyline(_losange_pts(c, r, true), c_trait, maxf(1.5, r * 0.10), true)
	ci.draw_polyline(_losange_pts(c, r * 0.58, true), c_trait, maxf(1.0, r * 0.07), true)
	var h := r * 0.42
	var w := maxf(1.0, r * 0.07)
	ci.draw_line(c + Vector2(0, -h), c + Vector2(0, h), c_trait, w, true)
	ci.draw_line(c + Vector2(0, -h * 0.35), c + Vector2(h * 0.45, -h * 0.75), c_trait, w, true)
	ci.draw_line(c + Vector2(0, h * 0.35), c + Vector2(-h * 0.45, h * 0.75), c_trait, w, true)

static func _losange_pts(c: Vector2, r: float, ferme := false) -> PackedVector2Array:
	var p := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if ferme:
		p.append(p[0])
	return p

static func _icone_losange(cote: int, couleur: Color, halo: bool) -> ImageTexture:
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	var m := (cote - 1) / 2.0
	for y in cote:
		for x in cote:
			var d := absf(x - m) + absf(y - m)
			var a := clampf(m * 0.80 - d + 0.5, 0.0, 1.0)
			var col := couleur
			if d > m * 0.80 - 2.0:
				col = col.darkened(0.35)
			if halo and a <= 0.0:
				col = LUEUR
				a = clampf((m - d) / (m * 0.2), 0.0, 1.0) * 0.5
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)

static func _icone_case(cote: int, cochee: bool) -> ImageTexture:
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.03, 0.045, 0.85))
	for i in cote:
		for k in 2:
			for c: Vector2i in [Vector2i(i, k), Vector2i(i, cote - 1 - k), Vector2i(k, i), Vector2i(cote - 1 - k, i)]:
				img.set_pixelv(c, ACIER if k == 0 else ACIER_SOMBRE)
	if cochee:
		var m := (cote - 1) / 2.0
		for y in cote:
			for x in cote:
				var d := absf(x - m) + absf(y - m)
				if d < m * 0.55:
					img.set_pixel(x, y, LUEUR.lerp(Color.WHITE, 0.2 * (1.0 - d / (m * 0.55))))
	return ImageTexture.create_from_image(img)

## Flou très large et lisse d'une image (fond de l'écran de chargement, bandes latérales du titre) : moyennes successives (shrink_x2,
## sans crénelage) jusqu'à ~26 px de large, puis agrandissement bicubique en deux temps jusqu'à 512 px.
static func flouter(img: Image) -> void:
	img.clear_mipmaps()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	while img.get_width() > 40:
		img.shrink_x2()
	var h := maxi(1, roundi(256.0 * img.get_height() / img.get_width()))
	img.resize(256, h, Image.INTERPOLATE_CUBIC)
	img.resize(512, h * 2, Image.INTERPOLATE_CUBIC)
