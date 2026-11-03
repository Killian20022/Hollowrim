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

## Cadre des panneaux (pause, options, inventaire, panneau Tab) : le cadre ornementé du lot L7 (voir cadre_orne).
static func cadre() -> StyleBox:
	var c := cadre_orne()
	c.content_margin_left = 14
	c.content_margin_right = 14
	c.content_margin_top = 10
	c.content_margin_bottom = 10
	return c

# --- lot L7 : police des titres et cadre ornementé ------------------------------------------------------------------------
## Police des TITRES : « Jacquard », gothique pixel de Sarah Cadigan-Fried (SIL OFL 1.1, assets/polices/OFL_Jacquard.txt ;
## sans nom réservé). Deux dessins, chacun à sa taille NATIVE (un pixel de police = un pixel logique : net, sans flou) :
##   Jacquard 24 (grille de 24 px, `grande`) : LA police des titres du HUD : nom de l'ennemi, titres du panneau Tab et de l'aide,
##   annonces centrées (lieu découvert, quête, niveau) ;
##   Jacquard 12 (grille de 12 px) : essayé pour les noms, trop serré à 12 px (le s final se lit « x ») : pas utilisé, gardé pour
##   d'éventuelles mentions très courtes. Texte courant et nombres : Palette.police.
## Ses chiffres sont « elzéviriens » (le 1 ressemble à un ı) : écrire les nombres avec Palette.police (corps du texte).
## Une copie par appelant, comme Palette.police (une police gardée en statique fait planter Godot à la fermeture).
const TITRE_PETIT := 12
const TITRE_GRAND := 24
static func police_gothique(grande := false) -> FontFile:
	var chemin := "res://assets/polices/Jacquard24-Regular.ttf" if grande else "res://assets/polices/Jacquard12-Regular.ttf"
	var p := (load(chemin) as FontFile).duplicate()
	p.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	p.hinting = TextServer.HINTING_NONE
	p.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	p.generate_mipmaps = false
	return p

## Texte détouré de 1 px (contour FOND sur les 8 voisins + ombre portée) : lisible sur la neige comme dans le noir, sans flou.
## `contour` faux : ombre portée (1, 1) seule. Pour Jacquard 12 et la police du corps : leurs lettres ne sont séparées que d'un
## pixel, le contour complet les soude (« Draugr ancien » devenait une bande noire) ; on le garde pour Jacquard 24.
static func texte_detoure(ci: CanvasItem, police: Font, pos: Vector2, texte: String, taille: int, couleur: Color, alpha := 1.0, contour := false) -> void:
	var c_fond := Color(FOND, alpha * couleur.a)
	var voisins: Array = [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1), Vector2(1, 2)] if contour else [Vector2(1, 1)]
	for d: Vector2 in voisins:
		ci.draw_string(police, pos + d, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, c_fond)
	ci.draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(couleur, alpha * couleur.a))

## Coin haut-gauche (12x12) du cadre ornementé : plaque de fer à nœud d'entrelacs or (deux boucles croisées ; « b » = brin qui
## passe dessous), puis le départ des bords. k contour, h reflet, m fer, s ombre, d filet sombre, f fond, o or, b or sombre.
## La colonne 11 = bord du haut, la ligne 11 = bord de gauche (même suite que _BORD_ORNE).
const _COIN_ORNE := [
	"kkkkkkkkkkkk",
	"khhhhhhhhhkh",
	"khmoomoomskm",
	"khommommoskm",
	"khombmbmosks",
	"khmomomomskd",
	"khombmbmoskf",
	"khommommoskb",
	"khmoomoomskf",
	"khsssssssskf",
	"kkkkkkkkkkkf",
	"khmmsdfbffff",
]
const _COULEURS_ORNE := {"k": Color("#0b0f1a"), "h": Color("#8a96ad"), "m": Color("#56627a"), "s": Color("#3a4458"),
	"d": Color("#1a2233"), "f": Color(0.043, 0.059, 0.102, 0.85), "o": Color("#e8a64a"), "b": Color("#b8762a")}
## Bord (12 px, de l'extérieur vers l'intérieur) : contour, reflet, fer, fer, ombre, filet sombre, fond, filet or, fond.
## Bords du bas et de droite : le reflet devient ombre (comme dialogue_cadre.svg, lumière venue d'en haut à gauche).
const _BORD_ORNE := "khmmsdfbffff"

## Cadre ornementé (9-slice 32x32, marges 12) : bords du cadre du designer (dialogue_cadre.svg : contour, reflet, bande de fer,
## ombre) + un filet or intérieur, et des coins en plaques de fer à nœud d'entrelacs. Pixels entiers, filtre Nearest.
static func cadre_orne() -> StyleBoxTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(_COULEURS_ORNE["f"])
	for i in 12:   # bords (répétés en mode Tile)
		var c: Color = _COULEURS_ORNE[_BORD_ORNE[i]]
		var c2: Color = _COULEURS_ORNE["s"] if _BORD_ORNE[i] == "h" else c
		for t in range(12, 20):
			img.set_pixel(t, i, c)
			img.set_pixel(i, t, c)
			img.set_pixel(t, 31 - i, c2)
			img.set_pixel(31 - i, t, c2)
	for y in 12:   # coins : le coin haut-gauche en miroir, reflet / ombre échangés sur les côtés retournés
		for x in 12:
			var ch: String = _COIN_ORNE[y][x]
			img.set_pixel(x, y, _COULEURS_ORNE[ch])
			img.set_pixel(31 - x, y, _COULEURS_ORNE[_eclairage(ch, x, y, true, false)])
			img.set_pixel(x, 31 - y, _COULEURS_ORNE[_eclairage(ch, x, y, false, true)])
			img.set_pixel(31 - x, 31 - y, _COULEURS_ORNE[_eclairage(ch, x, y, true, true)])
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.set_texture_margin_all(12)
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s

## Pixel (x, y) du coin haut-gauche recopié en miroir : sur un côté retourné, le reflet (h) devient ombre (s) et l'inverse
## (côtés de la plaque : colonnes / lignes 1 et 9 ; bord : pixel 1 de la ligne / colonne 11).
static func _eclairage(ch: String, x: int, y: int, miroir_x: bool, miroir_y: bool) -> String:
	var plaque := x <= 9 and y <= 9 and x >= 1 and y >= 1
	var vertical := (plaque and (x == 1 or x == 9)) or (y == 11 and x == 1)
	var horizontal := (plaque and (y == 1 or y == 9)) or (x == 11 and y == 1)
	if (miroir_x and vertical) or (miroir_y and horizontal):
		return {"h": "s", "s": "h"}.get(ch, ch) if plaque else ("s" if ch == "h" else ch)
	return ch

## Filet ornemental horizontal centré sur cx (annonces) : trait or de `demi` px de chaque côté, losanges or au centre et aux bouts.
static func dessiner_filet(ci: CanvasItem, cx: float, y: float, demi: float, alpha := 1.0) -> void:
	var o := Color(OR, alpha)
	var b := Color("#b8762a", alpha)
	var k := Color(FOND, 0.8 * alpha)
	ci.draw_rect(Rect2(cx - demi, y - 1, demi * 2.0 + 1.0, 3), k)
	ci.draw_rect(Rect2(cx - demi, y, demi * 2.0 + 1.0, 1), b)
	for x0: float in [cx - demi - 3.0, cx, cx + demi + 3.0]:
		ci.draw_rect(Rect2(x0 - 2, y - 3, 5, 7), k)
		ci.draw_rect(Rect2(x0, y - 2, 1, 5), o)
		ci.draw_rect(Rect2(x0 - 1, y - 1, 3, 3), o)
		ci.draw_rect(Rect2(x0, y, 1, 1), b)

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

# --- lot C : menu personnage, direction A « parchemin et cuir enluminé » ---------------------------------------------------
## Le livre, les signets, les touches, les titres à lettrine, filets, barres et règles viennent de Parchemin
## (scripts/menu/parchemin.gd, base commune du lot D reprise À L'IDENTIQUE). Ici, seulement ce qui manque au menu du lot C :
## arche du héros, vignettes d'emplacement, cadre d'icône, marques, étoile de favori, icônes d'objets.
const RARETE_ENCRE := {"commun": Color("#56627a"), "peu_commun": Color("#1f5a3a"), "rare": Color("#1f3a7a"), "unique": Color("#b8762a")}

## Arche romane enluminée (fond d'azur semé d'or, filets encre + or, sol de terre, clé de voûte) de taille l x h : le cadre du
## héros de l'onglet Équipement (maquette direction.js : arche). Transparente hors de l'arche. Bruit seulement (pas de Bayer).
static func image_arche(l: int, h: int) -> Image:
	var img := Image.create_empty(l + 2, h + 1, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_VALUE
	bruit.seed = 3
	bruit.frequency = 1.0 / 6.0
	var x0 := 1.0
	var x1 := float(l)
	var y1 := float(h)
	var rayon := (x1 - x0) * 0.5
	var cx := (x0 + x1) * 0.5
	var cy := rayon
	for y in range(0, h + 1):
		for x in range(0, l + 2):
			var d := minf(minf(x - x0, x1 - x), y1 - y)
			if y < cy:
				d = minf(d, rayon - Vector2(x - cx, y - cy).length())
			if d < 0.0:
				continue
			var col: Color
			if d < 1.0:
				col = Parchemin.ENCRE
			elif d < 2.0:
				col = Parchemin.OR_VIF
			elif d < 3.0:
				col = Parchemin.OR_TERNI
			elif d < 4.0:
				col = Parchemin.ENCRE
			else:
				var v: float = (bruit.get_noise_2d(x, y) * 0.5 + 0.5) * 0.7 + rng.randf() * 0.3
				col = Color("#1f2a44") if v < 0.4 else (Color("#1f3a7a") if v < 0.75 else Color("#2f5fb8"))
				if rng.randf() < 0.012:
					col = Parchemin.OR_VIF
			img.set_pixel(x, y, col)
	for x in range(int(x0) + 4, int(x1) - 3):   # sol : bande de terre sous les pieds
		for k in 3:
			img.set_pixel(x, int(y1) - 6 + k, Parchemin.CUIR[2] if k == 0 else Parchemin.CUIR[1])
	for p: Vector2i in [Vector2i(0, -2), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0),
			Vector2i(1, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]:
		img.set_pixel(roundi(cx) + p.x, 3 + p.y, Parchemin.RUBRIQUE if p == Vector2i.ZERO else Parchemin.OR_VIF)
	return img

## Coupe un texte trop long avec « … ».
static func raccourcir(police: Font, texte: String, larg: float) -> String:
	if police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE).x <= larg:
		return texte
	var t := texte
	while t.length() > 1 and police.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE).x > larg:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"

## Vignette d'emplacement (maquette : .slot) : cadre encre, double liseré or / clair ; choisie = liseré vermillon.
static func vignette(ci: CanvasItem, r: Rect2, choisie := false, vide := false) -> void:
	ci.draw_rect(r, Parchemin.RUBRIQUE if choisie else Parchemin.ENCRE)
	ci.draw_rect(r.grow(-1), Parchemin.OR_VIF if choisie else Parchemin.OR_TERNI)
	ci.draw_rect(r.grow(-2), Parchemin.RUBRIQUE if choisie else Parchemin.CLAIR)
	ci.draw_rect(r.grow(-3), Parchemin.CLAIR if choisie else (Color("#cdb88e") if vide else Color("#d8c69e")))

## Cadre d'icône sur fond de nuit (maquette : .cadre-ico) pour les grandes icônes de fiche.
static func cadre_icone(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Parchemin.ENCRE)
	ci.draw_rect(r.grow(-1), Parchemin.OR_VIF)
	ci.draw_rect(r.grow(-2), Parchemin.OR_TERNI)
	ci.draw_rect(r.grow(-3), Color("#1f2a44"))

## Cadre de l'aperçu 3D (ApercuObjet) : filet d'encre et d'or, fond de vélin ombré vers les bords (l'objet se détache au centre).
static func cadre_apercu(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Parchemin.ENCRE)
	ci.draw_rect(r.grow(-1), Parchemin.OR_VIF)
	ci.draw_rect(r.grow(-2), Parchemin.OR_TERNI)
	ci.draw_rect(r.grow(-3), Parchemin.VELIN[2])
	ci.draw_rect(r.grow(-5), Parchemin.VELIN[3])
	ci.draw_rect(r.grow(-8), Parchemin.VELIN[4])

## Marque d'objet porté (D, G, P) : petit carré vermillon, lettre claire (maquette : .marque).
static func marque(ci: CanvasItem, police: Font, x: float, y: float, lettre: String) -> void:
	ci.draw_rect(Rect2(x, y, 9, 9), Parchemin.RUBRIQUE_SOMBRE)
	ci.draw_rect(Rect2(x + 1, y + 1, 7, 7), Parchemin.RUBRIQUE)
	var l := police.get_string_size(lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE).x
	ci.draw_string(police, Vector2(roundf(x + 5.0 - l * 0.5), y + 8.0), lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE, Parchemin.CLAIR)

## Petite étoile or (favori).
static func etoile(ci: CanvasItem, x: float, y: float) -> void:
	for p: Vector2i in [Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
			Vector2i(4, 2), Vector2i(1, 3), Vector2i(3, 3), Vector2i(0, 4), Vector2i(4, 4)]:
		ci.draw_rect(Rect2(x + p.x, y + p.y, 1, 1), Parchemin.OR_TERNI if p.y < 3 else Parchemin.RUBRIQUE)

# --- icônes du menu ----------------------------------------------------------------------------------------------------------
## Icônes 16x16 au format d'IconesCombat (motif ASCII, contour automatique) pour ce qu'IconesCombat ne dessine pas encore :
## emplacements d'armure (vides), bijoux, butin (maquettes_menu/commun/ui.js : AJOUTS). IconesCombat reste prioritaire.
const MOTIFS_MENU := {
	"casque": ["metal", ["................", "................", ".....mllllm.....", "....mlsswslm....", "...mlsssssslm...", "...mllssssllm...",
		"...mmllllllmm...", "...ggggggggggg..", "...dmm.ll.mmd...", "...dm..ll..md...", "...dm..ll..md...", "...dm..mm..md...",
		"....d......d....", "................", "................", "................"]],
	"capuche": ["cuir", ["................", "......2222......", ".....233332.....", "....23344332....", "...2334..4332...", "...234....432...",
		"...23......32...", "...23......32...", "...234....432...", "..22344..44322..", "..123344443321..", ".11223333332211.",
		".1112222222211..", "................", "................", "................"]],
	"plastron": ["cuir", ["................", "...ss......ss...", "..sllss..sslls..", "..s1234334321s..", "...12344443321..", "...1234gg4321...",
		"...123444G321...", "...12344443321..", "...bBBBgBBBBb...", "...12344443321..", "...1234444321...", "...1233443321...",
		"...1223333221...", "....11111111....", "................", "................"]],
	"gants": ["cuir", ["................", "................", "....2.2.2.......", "....3.3.3.2.....", "....3.3.3.3.....", "....3333333.....",
		"....3444443..2..", "....34444433.3..", "....3444444333..", "....344444433...", ".....4444443....", ".....mllllm.....",
		".....m3333m.....", ".....222222.....", "................", "................"]],
	"bottes": ["cuir", ["................", "...sslls........", "...sllll........", "...2333..2......", "...2343.........", "...2343.........",
		"...2343.........", "...2343.........", "...23443........", "...234443.......", "...2344443333...", "...23444444443..",
		"...12222222222..", "...dmmmmmmmmmd..", "................", "................"]],
	"jambieres": ["cuir", ["................", "...BBBBBBBBBB...", "...3444444443...", "...3444334443...", "...3444..4443...", "...3444..4443...", "...344....443...", "...344....443...", "...344....443...", "...344....443...", "...3444..4443...", "...3444..4443...", "...244....442...", "...222....222...", "................", "................"]],
	"anneau": ["metal", ["................", "................", "................", "......uUUu......", ".....uw..Uu.....", "......UuuU......",
		".....gGGGGg.....", "....gG....Gg....", "...gG......Gg...", "...g........g...", "...gG......Gg...", "....gG....Gg....",
		".....gGGGGg.....", "................", "................", "................"]],
	"amulette": ["metal", ["................", "...l........l...", "....l......l....", ".....l....l.....", "......l..l......", ".......ll.......",
		"......gGGg......", ".....gRrrRg.....", ".....gRwrRg.....", ".....gRrrRg.....", "......gRRg......", ".......gg.......",
		"................", "................", "................", "................"]],
	"os": ["metal", ["................", "................", "..ss............", ".swls...........", "..slls..........", "...slls.........",
		"....slls........", ".....slls.......", "......slls......", ".......slls.....", "........slls....", ".........sllws..",
		"..........slws..", "...........ss...", "................", "................"]],
	"minerai": ["metal", ["................", "................", "................", "......mml.......", "....mmllldm.....", "...mlsldmmdm....",
		"...mdlmmgdmmm...", "..mmmdmmmmlsdm..", "..mlsdmgdmldmm..", "..dmmmdmmmmmdd..", "...ddmmmdmmdd...", ".....dddddd.....",
		"................", "................", "................", "................"]],
	"cristal": ["glace", ["................", ".......5........", "......545.......", "......545...4...", ".....54435.434..", ".....54435.434..",
		"..4..5443354334.", ".434.54433543.3.", ".4433544335433..", ".44335443354333.", "..333544335433..", "..2222222222222.",
		"...1111111111...", "................", "................", "................"]],
	"fourrure": ["cuir", ["................", "................", "...ss.s..s.ss...", "..slllslsllsls..", "..sl444444444s..", ".sl44555555444s.",
		"..s4455555544s..", ".sl44555555444s.", "..s4445555444ls.", ".sl44444444444s.", "..sll4ls4l4lls..", "...s.s..s..s....",
		"................", "................", "................", "................"]],
	"relique": ["metal", ["................", "................", "......gggg......", ".....gGGGGg.....", "....gG.uU.Gg....", "....gGuwuUGg....",
		"....gG.uU.Gg....", ".....gGGGGg.....", "......gGGg......", ".......gg.......", ".....gggggg.....", "....gGGGGGGg....",
		"................", "................", "................", "................"]],
	"bourse": ["cuir", ["................", "................", "......2gg2......", ".......33.......", ".....233332.....", "....23444432....",
		"...2344g44432...", "...2344g44432...", "...234g4g4432...", "...23444g4432...", "....23344332....", ".....222222.....",
		"................", "................", "................", "................"]],
	"hache": ["metal", ["................", "........llls....", ".......lssswl...", "......lsswwwl...", ".....bBlssssl...", "....bB..llsl....",
		"...bB.....l.....", "..bB............", ".bB.............", "bB..............", "................", "................",
		"................", "................", "................", "................"]],
	"marteau": ["metal", ["................", ".........mlls...", "........mlswls..", ".......mlswwlsm.", "......bmllsllm..", ".....bB.mmllm...",
		"....bB...mm.....", "...bB...........", "..bB............", ".bB.............", "................", "................",
		"................", "................", "................", "................"]],
	"cle": ["metal", ["................", "................", "...gggg.........", "..gG..Gg........", "..g....g........", "..gG..Gg........",
		"...gGGgggggggg..", "..........G.G...", "..........g.g...", "................", "................", "................",
		"................", "................", "................", "................"]],
}
## Teintes de lame par matériau (pixels w / s / l du motif « epee » d'IconesCombat ; maquette : LAMES).
const LAMES := {
	"rubis": ["#ffd8d0", "#e0473a", "#8a1c1c"], "verre": ["#d8ffe0", "#7fc87a", "#3f8a4a"], "saphir": ["#c8ecff", "#3a7fd0", "#1f4a8a"],
	"obsidienne": ["#ec6a1f", "#3a2a3a", "#1a1018"], "or": ["#fff2c0", "#e8a64a", "#a8702a"], "fer": ["#c8d0dc", "#8a96ad", "#56627a"],
}
## Icône par emplacement de corps vide (silhouette pâle) et par catégorie sans motif.
const ICONE_EMPLACEMENT := {"tete": "casque", "torse": "plastron", "mains": "gants", "pieds": "bottes", "cou": "amulette", "anneau": "anneau", "jambes": "jambieres"}
const ICONE_DEFAUT := {"arme": "epee", "armure": "plastron", "bijou": "anneau", "ingredient": "minerai", "quete": "cle", "divers": "relique",
	"consommable": "potion_soin"}
## Icônes d'objets connus sans champ « icone » dans le registre (lecture seule du registre : lot A pourra les y écrire).
const ICONE_OBJET := {"hache_kolbeinn": "hache", "os_draugr": "os", "minerai_fer": "minerai", "minerai_argent": "minerai", "cristal_givre": "cristal",
	"fourrure_troll": "fourrure", "relique_offrande": "relique", "lame_antique": "epee", "anneau_cuivre": "anneau", "anneau_givre": "anneau",
	"amulette_givre": "amulette", "amulette_eirik": "amulette", "collier_or": "amulette", "cle_archives": "cle", "coupe_argent": "relique",
	"broche_sigrun": "relique", "ecaille_dragon": "cristal", "croc_troll": "os", "poussiere_tombe": "bourse", "champignon_lumineux": "bourse",
	"journal_sigrun": "tome", "registre_hrafn": "tome"}

static var _icones_menu := {}

## Icône 16x16 d'un objet (identifiant du registre, de l'équipement des mains ou d'un sort) : icône DESSINÉE DEPUIS LE MODÈLE 3D
## (IconesObjets, atlas d'outils/generer_icones.gd) s'il y en a une ; sinon (icone_pixel) motif d'IconesCombat s'il existe
## (champ « icone » du registre, sinon l'id), sinon motif du menu ; lame teintée par le matériau (épées du catalogue et épées
## écrites à la main : epee_or, epee_rubis…). `pale` : silhouette d'emplacement vide (encre pâlie).
static func icone_objet(id: String, pale := false) -> Texture2D:
	if not pale:
		var t := IconesObjets.icone(id, 16)
		if t != null:
			return t
	return icone_pixel(id, pale)

## Icône 32 px (fiches détaillées) : objet dessiné depuis son modèle, sinon l'icône pixel agrandie ×2 à l'affichage (null ici).
static func icone_objet_32(id: String) -> Texture2D:
	return IconesObjets.icone(id, 32)

## Ancienne icône pixel 16x16 (motifs IconesCombat / MOTIFS_MENU) : repli des objets sans modèle, sorts, silhouettes pâles.
static func icone_pixel(id: String, pale := false) -> Texture2D:
	var cle := id + ("|p" if pale else "")
	if _icones_menu.has(cle):
		return _icones_menu[cle]
	var f := Inventaire.objet(id)
	var motif := String(f.get("icone", ""))
	if motif == "":
		motif = String(ICONE_OBJET.get(id, ""))
	if motif == "" and (IconesCombat.connu(id) or MOTIFS_MENU.has(id)):
		motif = id
	if motif == "" and not f.is_empty():
		motif = String(ICONE_DEFAUT.get(String(f.get("categorie", "")), "inconnu"))
	if motif == "":
		motif = "inconnu"
	var materiau := String(f.get("materiau", ""))
	if materiau == "":
		for m: String in LAMES:
			if id.ends_with("_" + m):
				materiau = m
	var img: Image
	if MOTIFS_MENU.has(motif) and not IconesCombat.connu(motif):
		img = IconesCombat.image(MOTIFS_MENU[motif])
	else:
		img = IconesCombat.icone(motif).get_image()
	if img == null:
		img = IconesCombat.image(MOTIFS_MENU["relique"])
	img = img.duplicate()
	if materiau != "" and LAMES.has(materiau) and motif == "epee":
		var lame: Array = LAMES[materiau]
		var src := {Color(IconesCombat.FIXES["w"]).to_html(): Color(lame[0]), Color(IconesCombat.FIXES["s"]).to_html(): Color(lame[1]),
			Color(IconesCombat.FIXES["l"]).to_html(): Color(lame[2])}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y).to_html()
				if src.has(c):
					img.set_pixel(x, y, src[c])
	if pale:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					img.set_pixel(x, y, Color(Parchemin.PALE, 0.35 + 0.25 * c.get_luminance()))
	var tex := ImageTexture.create_from_image(img)
	_icones_menu[cle] = tex
	return tex

## Icône d'un emplacement de corps vide.
static func icone_emplacement(emplacement: String) -> Texture2D:
	var m := String(ICONE_EMPLACEMENT.get(emplacement, "inconnu"))
	var cle := "@" + emplacement
	if not _icones_menu.has(cle):
		var img := IconesCombat.image(MOTIFS_MENU[m]) if MOTIFS_MENU.has(m) else IconesCombat.icone(m).get_image()
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					img.set_pixel(x, y, Color(Parchemin.PALE, 0.30 + 0.25 * c.get_luminance()))
		_icones_menu[cle] = ImageTexture.create_from_image(img)
	return _icones_menu[cle]

## Libère les textures gardées en statique (à la fermeture : voir Palette.vider).
static func vider_menu() -> void:
	_icones_menu.clear()
	IconesObjets.vider()
