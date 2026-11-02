extends RefCounted
## Habillage « cuir enluminé » du HUD de jeu (barre d'objets de hud_combat.gd, boussole de hud.gd), même famille que le
## menu personnage « parchemin et cuir enluminé » (scripts/rpg/livre_parchemin.gd, maquettes Desktop/Skyrim captures/
## maquettes_menu/A_parchemin) mais en version DISCRÈTE pour la vue de jeu : cuir sombre à grain, filet d'or fin,
## numéros gravés, sceau de cire vermillon pour la case active. Dessin en pixels entiers (repère logique EchelleUi).
##
## Trois propositions (planche Desktop/Skyrim captures/barre_objets/planche.png), choisies par l'argument
## `--barre=a|b|c|ancienne` (défaut : STYLE_DEFAUT) ou par HudCuir.style_force (tests) :
##   a = « cartouche et ruban » : au repos, un seul cartouche (mains tenues) ; le ruban des 10 raccourcis se déroule au
##       changement puis se replie ; boussole = bandeau de cuir effilé ;
##   b = « rangée fine » : les 10 cases toujours là, fines et estompées ; boussole = fil d'or sans fond ;
##   c = « éventail » : cartouche + 2 voisins de chaque côté en arc ; boussole = bande de vélin à l'encre ;
##   ancienne = barre de fer d'avant (comparaison).
## Aucun class_name (pas de réimport nécessaire) : preload("res://scripts/hud_cuir.gd").

const STYLE_DEFAUT := "a"

const ENCRE := Color("#2b1a1e")
const RUBRIQUE := Color("#8a1c1c")
const OR_TERNI := Color("#b8762a")
const OR_CLAIR := Color("#e0a648")
const OR_SOMBRE := Color("#6e4818")
const LETTRINE_OR := Color("#fcb53a")
const SUR_CUIR := Color("#cca066")
const CLAIR := Color("#e8e0c8")
const CIRE := Color("#5a1a1c")
const CIRE_CLAIRE := Color("#b3341f")
const CIRE_REFLET := Color("#de6a42")
const VELIN := Color("#cdb88e")
const VELIN_CLAIR := Color("#e2d2a6")
const NOIR := Color("#0a0604")
const BLEU_MAIN := Color("#7fa6e0")

## Chiffres et lettres 3x5 (bits de gauche à droite, ligne par ligne).
const MINI := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
	"G": ["111", "100", "101", "101", "111"], "D": ["110", "101", "101", "101", "110"],
	"x": ["000", "101", "010", "101", "000"],
}

static var style_force := ""
static var _style := ""
static var _cuir: ImageTexture
static var _velin: ImageTexture

## Style courant (a, b, c ou ancienne).
static func style() -> String:
	if style_force != "":
		return style_force
	if _style == "":
		_style = STYLE_DEFAUT
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--barre="):
				var s := a.substr(8).to_lower()
				if s in ["a", "b", "c", "ancienne"]:
					_style = s
	return _style

static func _hash(x: int, y: int, graine: int) -> float:
	var h := (x * 374761393 + y * 668265263 + graine * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0

## Bruit de valeur lissé (grain du cuir) ; jamais de trame ordonnée.
static func _bruit(x: float, y: float, pas: float, graine: int, periode: int) -> float:
	var gx := x / pas
	var gy := y / pas
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var fx := gx - x0
	var fy := gy - y0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var p := maxi(1, int(periode / pas))
	var a := _hash(posmod(x0, p), posmod(y0, p), graine)
	var b := _hash(posmod(x0 + 1, p), posmod(y0, p), graine)
	var c := _hash(posmod(x0, p), posmod(y0 + 1, p), graine)
	var d := _hash(posmod(x0 + 1, p), posmod(y0 + 1, p), graine)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

static func _texture_grain(sombre: Color, clair: Color, graine: int) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := 0.55 * _bruit(x, y, 8.0, graine, n) + 0.3 * _bruit(x, y, 4.0, graine + 1, n) + 0.15 * _hash(x, y, graine + 2)
			img.set_pixel(x, y, sombre.lerp(clair, clampf(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## Cuir sombre à grain (64x64, se répète : le Control doit avoir texture_repeat activé).
static func cuir() -> ImageTexture:
	if _cuir == null:
		_cuir = _texture_grain(Color("#160d07"), Color("#33200f"), 11)
	return _cuir

static func velin() -> ImageTexture:
	if _velin == null:
		_velin = _texture_grain(Color("#b9a072"), VELIN_CLAIR, 23)
	return _velin

static func vider() -> void:
	_cuir = null
	_velin = null

## Plaque de cuir : contour noir à coins coupés, cuir à grain, filet d'or biseauté (clair en haut/gauche).
## `filet` = couleur du filet (alpha 0 = sans filet).
static func plaque(ci: CanvasItem, r: Rect2, alpha: float, filet: Color = OR_TERNI, fond := 0.92) -> void:
	if alpha < 0.01:
		return
	var n := Color(NOIR, 0.85 * alpha)
	ci.draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(r.size.x - 2, r.size.y)), n)
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(r.size.x, r.size.y - 2)), n)
	ci.draw_texture_rect(cuir(), Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), true, Color(1, 1, 1, fond * alpha))
	if filet.a > 0.0:
		cadre(ci, Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), filet, alpha)

## Filet d'un pixel autour de r : haut et gauche éclaircis, bas et droite assombris (biseau gravé).
static func cadre(ci: CanvasItem, r: Rect2, c: Color, alpha: float) -> void:
	var haut := Color(c.lerp(Color.WHITE, 0.18), c.a * alpha)
	var bas := Color(c.darkened(0.35), c.a * alpha)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), haut)
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, r.size.y - 1)), haut)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 1), Vector2(r.size.x - 1, 1)), bas)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 1), Vector2(1, r.size.y - 2)), bas)

## Petit glyphe 3x5 cerné de noir (lisible sur la neige comme dans la nuit) ; e = agrandissement entier.
static func glyphe(ci: CanvasItem, ch: String, pos: Vector2, couleur: Color, e := 1, ombre_a := 0.8) -> void:
	var g: Array = MINI.get(ch, MINI["x"])
	var ombre := Color(NOIR, ombre_a * couleur.a)
	var u := Vector2(e, e)
	if ombre_a > 0.0:
		for y in 5:
			for x in 3:
				if g[y][x] == "1":
					for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1)]:
						var q: Vector2 = Vector2(x, y) + d
						if q.x < 0 or q.x > 2 or q.y < 0 or q.y > 4 or g[int(q.y)][int(q.x)] != "1":
							ci.draw_rect(Rect2(pos + q * e, u), ombre)
	for y in 5:
		for x in 3:
			if g[y][x] == "1":
				ci.draw_rect(Rect2(pos + Vector2(x, y) * e, u), couleur)

## Chiffre gravé dans le cuir : creux sombre décalé en haut à gauche, métal (or terni) dessus.
static func grave(ci: CanvasItem, ch: String, pos: Vector2, alpha: float, couleur: Color = SUR_CUIR) -> void:
	glyphe(ci, ch, pos, Color(couleur, alpha), 1, 0.9)

## Sceau de cire 9x9 (vermillon, reflet en haut à gauche) portant le chiffre `ch` en clair ; c = centre.
static func sceau(ci: CanvasItem, ch: String, c: Vector2, alpha: float) -> void:
	if alpha < 0.01:
		return
	var larg := [5, 7, 9, 9, 9, 9, 9, 7, 5]
	var o := c - Vector2(4, 4)
	for y in 9:
		var w: int = larg[y]
		ci.draw_rect(Rect2(o.x + (9 - w) / 2 - 1, o.y + y, w + 2, 1), Color(NOIR, 0.8 * alpha))
	ci.draw_rect(Rect2(o.x + 2, o.y - 1, 5, 1), Color(NOIR, 0.8 * alpha))
	ci.draw_rect(Rect2(o.x + 2, o.y + 9, 5, 1), Color(NOIR, 0.8 * alpha))
	for y in 9:
		var w: int = larg[y]
		ci.draw_rect(Rect2(o.x + (9 - w) / 2, o.y + y, w, 1), Color(CIRE, alpha))
	var larg2 := [3, 5, 7, 7, 7, 7, 7, 5, 3]
	for y in range(1, 8):
		var w: int = larg2[y]
		ci.draw_rect(Rect2(o.x + (9 - w) / 2, o.y + y, w, 1), Color(CIRE_CLAIRE, alpha))
	ci.draw_rect(Rect2(o.x + 2, o.y + 2, 2, 1), Color(CIRE_REFLET, alpha))
	ci.draw_rect(Rect2(o.x + 2, o.y + 3, 1, 1), Color(CIRE_REFLET, alpha))
	glyphe(ci, ch, o + Vector2(3, 2), Color(CLAIR, alpha), 1, 0.0)

## Losange 5x5 (marqueur de boussole) : contour noir, cœur de couleur, reflet d'un pixel.
static func losange(ci: CanvasItem, c: Vector2, couleur: Color, alpha: float, creux := false) -> void:
	for dy in range(-3, 4):
		var r := 3 - absi(dy)
		ci.draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(NOIR, 0.85 * alpha))
	for dy in range(-2, 3):
		var r := 2 - absi(dy)
		ci.draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(couleur, alpha))
	if creux:
		ci.draw_rect(Rect2(c.x, c.y, 1, 1), Color(NOIR, 0.85 * alpha))
	else:
		ci.draw_rect(Rect2(c.x - 1, c.y - 1, 1, 1), Color(couleur.lerp(Color.WHITE, 0.5), alpha))

## Jauge de ressource 80x7 (même encombrement que l'ancien assets/ui/barre_cadre.svg) : plaque de cuir à filet d'or,
## remplissage 76x3 (reflet / base / ombre) qui se vide vers le centre, fond noir ; pointes d'or aux deux bouts.
static func jauge(ci: CanvasItem, pos: Vector2, ratio: float, couleurs: Array, alpha: float) -> void:
	if alpha < 0.02:
		return
	plaque(ci, Rect2(pos, Vector2(80, 7)), alpha, OR_TERNI, 0.9)
	ci.draw_rect(Rect2(pos + Vector2(2, 2), Vector2(76, 3)), Color(NOIR, 0.9 * alpha))
	var l := roundi(76.0 * clampf(ratio, 0.0, 1.0))
	var x := pos.x + 2.0 + floorf((76 - l) * 0.5)
	for ligne in 3:
		ci.draw_rect(Rect2(x, pos.y + 2 + ligne, l, 1), Color(couleurs[ligne], alpha))
	if l > 0 and l < 76:   # bords du remplissage soulignés d'or pâle : on lit le niveau même sur la neige
		ci.draw_rect(Rect2(x - 1, pos.y + 2, 1, 3), Color(OR_SOMBRE, alpha))
		ci.draw_rect(Rect2(x + l, pos.y + 2, 1, 3), Color(OR_SOMBRE, alpha))

## Gemme 9x9 devant une jauge : contour noir, sertissure d'or, cœur de la couleur de la ressource, reflet.
static func gemme(ci: CanvasItem, c: Vector2, couleurs: Array, alpha: float) -> void:
	for dy in range(-4, 5):
		var r := 4 - absi(dy)
		ci.draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(NOIR, 0.9 * alpha))
	for dy in range(-3, 4):
		var r := 3 - absi(dy)
		ci.draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(OR_CLAIR if dy < 0 else OR_TERNI, alpha))
	for dy in range(-2, 3):
		var r := 2 - absi(dy)
		ci.draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(couleurs[0] if dy < 0 else couleurs[1], alpha))
	ci.draw_rect(Rect2(c.x, c.y + 2, 1, 1), Color(couleurs[2], alpha))
	ci.draw_rect(Rect2(c.x - 1, c.y - 1, 1, 1), Color(1, 1, 1, 0.6 * alpha))
