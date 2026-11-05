class_name StyleParchemin
extends RefCounted
## Habillage « parchemin et cuir » des menus hors du livre (menu pause, options en partie) : même famille que le menu du
## personnage (Parchemin : vélin, cuir, filet d'or, encre brune, rubrique vermillon).
##   - page() : cadre de cuir à filet d'or contenant une page de vélin (texte à l'encre, thème theme_encre()) ;
##   - cuir() : panneau de cuir sombre à filet d'or (texte clair, thème theme_cuir() = thème pixel de MenuStyle).
## Aucune ressource n'est gardée en statique (Godot plante à la fermeture, voir Palette.police) : tout est reconstruit à l'appel.

const MARGE := 12

## Feuille de vélin en StyleBoxTexture (bord irrégulier bruni, centre répété). Marges de contenu : MARGE.
static func velin() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(Parchemin.feuille(Vector2i(96, 96), 21))
	s.set_texture_margin_all(6)
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.content_margin_left = MARGE + 4
	s.content_margin_right = MARGE + 4
	s.content_margin_top = MARGE
	s.content_margin_bottom = MARGE
	return s

static func _cuir_boite(marge: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Parchemin.CUIR[1]
	b.border_color = Parchemin.OR_TERNI
	b.set_border_width_all(1)
	b.anti_aliasing = false
	b.shadow_color = Color(Parchemin.CUIR[0], 0.6)
	b.shadow_size = 3
	b.content_margin_left = marge
	b.content_margin_right = marge
	b.content_margin_top = marge
	b.content_margin_bottom = marge
	return b

## Thème du cuir : le thème pixel du jeu, avec un panneau de cuir sombre et du texte clair.
static func theme_cuir() -> Theme:
	var t := MenuStyle.theme().duplicate() as Theme
	var b := _cuir_boite(8)
	b.bg_color = Color(Parchemin.CUIR[0].lerp(Parchemin.CUIR[1], 0.5), 0.97)
	t.set_stylebox("panel", "PanelContainer", b)
	t.set_color("font_color", "Label", Parchemin.CLAIR)
	return t

## Thème de l'encre : texte brun sur vélin, ligne choisie surlignée (cuir clair) et rubrique vermillon.
static func theme_encre() -> Theme:
	var t := MenuStyle.theme().duplicate() as Theme
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = 12
	vide.content_margin_right = 12
	vide.content_margin_top = 1
	vide.content_margin_bottom = 1
	var choisi := StyleBoxFlat.new()
	choisi.bg_color = Color(Parchemin.SURLIGNE, 0.75)
	choisi.border_color = Parchemin.RUBRIQUE
	choisi.set_border_width_all(0)
	choisi.border_width_left = 2
	choisi.anti_aliasing = false
	choisi.content_margin_left = 12
	choisi.content_margin_right = 12
	choisi.content_margin_top = 1
	choisi.content_margin_bottom = 1
	for type in ["Button", "CheckButton"]:
		t.set_stylebox("normal", type, vide)
		for etat in ["hover", "pressed", "focus", "hover_pressed"]:
			t.set_stylebox(etat, type, choisi)
		t.set_color("font_color", type, Parchemin.ENCRE)
		for etat in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			t.set_color(etat, type, Parchemin.RUBRIQUE)
		t.set_color("font_disabled_color", type, Parchemin.PALE)
	t.set_color("font_color", "Label", Parchemin.ENCRE)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	return t

## Cadre de cuir + page de vélin : renvoie [cadre (PanelContainer à mettre dans l'arbre), contenu (PanelContainer à remplir)].
static func page() -> Array:
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", _cuir_boite(4))
	var contenu := PanelContainer.new()
	contenu.add_theme_stylebox_override("panel", velin())
	cadre.add_child(contenu)
	return [cadre, contenu]
