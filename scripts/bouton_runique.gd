class_name BoutonRunique
extends Button
## Bouton du menu principal, dessiné à la main aux proportions de ref_menu/reference.png (aucune capture de l'image) :
## fond sombre translucide, bordure d'acier à double filet, losange runique à gauche, pointe ornée (chevrons) à droite,
## texte à empattements. Coordonnées en pixels de l'image de référence : le parent est mis à l'échelle de la fenêtre.
## - survol ou focus : le contour s'illumine en bleu en DUREE_LUEUR s, la rune s'allume ; signal `survole` (son joué par l'écran titre) ;
## - validation (clic, Entrée, A) : flash et balayage de lumière (valider()), l'action est lancée par l'écran titre à la fin ;
## - désactivé : grisé, ni focus ni survol (Continuer sans sauvegarde valide).
## Button.text reste le libellé (tests, lecteurs d'écran) ; il est dessiné ici, la police du thème est rendue invisible.

signal survole

const DUREE_LUEUR := 0.2
const POINTE := 50.0        # longueur de la pointe ornée (px de l'image)
const X_RUNE := 34.0        # centre du losange runique
const X_TEXTE := 74.0       # début du libellé

var police: Font
var taille_police := 33
var opacite_fond := 0.74
var _h := 0.0               # illumination 0..1 (focus)
var _v := 0.0               # flash de validation 0..1
var _balayage := -1.0       # position du balayage de lumière (0..1), < 0 : aucun
var _tw: Tween

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var vide := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, vide)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	if police == null:
		police = MenuStyle.police_titre(500)
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	focus_entered.connect(func() -> void:
		_vers(1.0)
		survole.emit())
	focus_exited.connect(func() -> void: _vers(0.0))

## Désactive (grisé, hors du parcours clavier) ou réactive le bouton.
func activer(actif: bool) -> void:
	disabled = not actif
	focus_mode = Control.FOCUS_ALL if actif else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actif else Control.CURSOR_ARROW
	if not actif:
		if has_focus():
			release_focus()
		_h = 0.0
	queue_redraw()

func _vers(cible: float) -> void:
	if _tw != null:
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_method(func(v: float) -> void:
		_h = v
		queue_redraw(), _h, cible, DUREE_LUEUR * absf(cible - _h) + 0.01)

## Animation de validation (≈ 0,45 s) ; attendre `await bouton.valider()` avant de lancer l'action.
func valider() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		_v = v
		queue_redraw(), 1.0, 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void:
		_balayage = v
		queue_redraw(), 0.0, 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_balayage = -1.0
	queue_redraw()

func _contour(inset: float) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var bout := w - POINTE
	return PackedVector2Array([
		Vector2(inset, inset), Vector2(bout - inset * 0.6, inset), Vector2(w - POINTE * 0.45 - inset * 1.2, h * 0.5),
		Vector2(bout - inset * 0.6, h - inset), Vector2(inset, h - inset), Vector2(inset, inset)])

func _draw() -> void:
	var w := size.x
	var h := size.y
	var eteint := disabled
	var a := 0.0 if eteint else _h
	var exterieur := _contour(0.0)
	# fond
	var fond := Color(MenuStyle.NUIT, opacite_fond).lerp(Color(MenuStyle.NUIT_BLEUE, maxf(opacite_fond, 0.8)), a)
	if eteint:
		fond = Color(MenuStyle.NUIT, opacite_fond * 0.9)
	fond = fond.lerp(Color(0.35, 0.6, 0.85, 0.85), _v * 0.35)
	var poly := exterieur.slice(0, 5)
	draw_colored_polygon(poly, fond)
	# reflet intérieur discret (dégradé vertical du métal : haut un peu plus clair)
	draw_polygon(PackedVector2Array([Vector2(2, 2), Vector2(w - POINTE - 2, 2), Vector2(w - POINTE - 2, h * 0.45), Vector2(2, h * 0.45)]),
		PackedColorArray([Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.035), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	# balayage de lumière (validation)
	if _balayage >= 0.0:
		var x := lerpf(-60.0, w, _balayage)
		var q := PackedVector2Array([Vector2(x - 40, 0), Vector2(x + 10, 0), Vector2(x + 50, h), Vector2(x, h)])
		for i in q.size():
			q[i].x = clampf(q[i].x, 0.0, w - POINTE)
		draw_polygon(q, PackedColorArray([Color(0.7, 0.9, 1, 0), Color(0.85, 0.95, 1, 0.35), Color(0.7, 0.9, 1, 0), Color(0.85, 0.95, 1, 0.35)]))
	# bordure : halo bleu (2 passes larges) puis filet net, filet intérieur
	var bord := MenuStyle.ACIER.lerp(MenuStyle.LUEUR, a)
	if eteint:
		bord = MenuStyle.ACIER_SOMBRE
	if a > 0.01:
		draw_polyline(exterieur, Color(MenuStyle.LUEUR, 0.10 * a), 10.0, true)
		draw_polyline(exterieur, Color(MenuStyle.LUEUR, 0.22 * a), 5.0, true)
	draw_polyline(exterieur, bord.lerp(Color.WHITE, 0.25 * a + 0.4 * _v), 1.6 + 0.6 * a, true)
	var interieur := _contour(4.0)
	draw_polyline(interieur, Color(MenuStyle.ACIER_SOMBRE.lerp(MenuStyle.LUEUR, a * 0.5), 0.9 if not eteint else 0.5), 1.0, true)
	# pointe ornée : deux chevrons emboîtés et un petit losange
	var c_chev := MenuStyle.ACIER.lerp(MenuStyle.LUEUR.lerp(Color.WHITE, 0.2), a)
	if eteint:
		c_chev = MenuStyle.ACIER_SOMBRE
	var bout := w - POINTE
	for k in 3:
		var ox := bout - 8.0 + k * 15.0
		var dy := 5.0 + k * 4.0
		var pts := PackedVector2Array([Vector2(ox, dy), Vector2(ox + (h * 0.5 - dy) * 1.05, h * 0.5), Vector2(ox, h - dy)])
		if a > 0.01:
			draw_polyline(pts, Color(MenuStyle.LUEUR, 0.18 * a), 5.0, true)
		draw_polyline(pts, c_chev, 1.6 if k < 2 else 2.0, true)
	for cl: Vector2 in [Vector2(bout - 20.0, h * 0.5), Vector2(bout - 8.0, h * 0.5 - 9.0), Vector2(bout - 8.0, h * 0.5 + 9.0)]:
		draw_polyline(MenuStyle._losange_pts(cl, 5.0, true), c_chev, 1.3, true)
	# losange runique
	MenuStyle.dessiner_losange(self, Vector2(X_RUNE, h * 0.5), h * 0.30, a, eteint)
	# libellé
	var couleur := MenuStyle.ARGENT.lerp(MenuStyle.GIVRE, a)
	if eteint:
		couleur = MenuStyle.ETEINT
	couleur = couleur.lerp(Color.WHITE, _v * 0.6)
	var asc := police.get_ascent(taille_police)
	var desc := police.get_descent(taille_police)
	var y := (h + asc - desc) * 0.5 - 1.0
	draw_string(police, Vector2(X_TEXTE + 2, y + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police, Color(0, 0, 0, 0.55))
	if a > 0.01:
		draw_string_outline(police, Vector2(X_TEXTE, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police, 8, Color(MenuStyle.LUEUR, 0.16 * a))
	draw_string(police, Vector2(X_TEXTE, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police, couleur)
