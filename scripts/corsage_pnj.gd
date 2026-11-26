class_name CorsagePnj
## [pnj/realisme_v2, 2026-11-26] Corsages / tuniques de laine des PNJ femmes du village. Défaut corrigé : toutes les femmes gardaient
## la jaque à écailles (cuir à « mailles / clous ») de l'archétype Chasseresse ; seules mante, robe et coiffure les distinguaient.
## Ici le TORSE et les MANCHES de l'atlas de la tunique (UV de la jaque, 256 x 128, v < ChasseresseTextures.V_JUPE) sont repeints
## par individu : laine ou lin d'une couleur sourde, tissage propre (toile, sergé, chevrons, losanges, côtelé), coutures latérales,
## galon tissé à l'encolure, et un fermoir de poitrine : paire de fibules ovales (bronze) reliées par un rang de perles avec les
## bretelles de la robe-tablier, laçage de cuir à l'encolure fendue, ou broche ronde. Usure, plis, taches et boue viennent ensuite de
## RealismePnj._usure (même passe, images précalculées). Géométrie, squelette, poids et animations INCHANGÉS (texture seulement).
## Les positions de la poitrine (fibules, encolure) sont MESURÉES sur les sommets de la tunique (ancres), pas devinées dans l'atlas.

## laine : couleur de base ; tissage ; fermoir (fibules | lacets | broche) ; galon (couleur du galon d'encolure, ou absent) ;
## perles : couleurs du rang de perles (fibules).
const CORSAGES := {
	"hab_paysanne_a":    {"laine": Color(0.30, 0.37, 0.48), "tissage": "toile", "fermoir": "fibules", "galon": Color(0.62, 0.55, 0.40),
			"perles": [Color(0.55, 0.36, 0.14), Color(0.22, 0.38, 0.40), Color(0.60, 0.56, 0.46)]},
	"hab_paysanne_b":    {"laine": Color(0.62, 0.57, 0.47), "tissage": "toile", "fermoir": "lacets"},
	"hab_paysanne_c":    {"laine": Color(0.50, 0.27, 0.17), "tissage": "chevrons", "fermoir": "fibules", "galon": Color(0.30, 0.34, 0.24),
			"perles": [Color(0.20, 0.30, 0.36), Color(0.58, 0.40, 0.16), Color(0.16, 0.14, 0.12)]},
	"hab_chasseresse_a": {"laine": Color(0.27, 0.33, 0.23), "tissage": "serge", "fermoir": "lacets"},
	"hab_chasseresse_b": {"laine": Color(0.40, 0.30, 0.22), "tissage": "losanges", "fermoir": "broche", "galon": Color(0.48, 0.24, 0.17)},
	"chasseuse":         {"laine": Color(0.34, 0.28, 0.22), "tissage": "cotele", "fermoir": "lacets", "galon": Color(0.27, 0.33, 0.23)},
	"chef":              {"laine": Color(0.22, 0.26, 0.36), "tissage": "chevrons", "fermoir": "fibules", "galon": Color(0.55, 0.26, 0.18),
			"perles": [Color(0.60, 0.42, 0.15), Color(0.62, 0.58, 0.50), Color(0.18, 0.34, 0.38), Color(0.45, 0.16, 0.12)]},
}

static func concerne(id: String) -> bool:
	return CORSAGES.has(id)

## Ancres mesurées sur la tunique au repos (texels de l'atlas) : fibules gauche / droite, encolure (rang de l'encolure au devant).
static func ancres(mi: MeshInstance3D, W: int, H: int) -> Dictionary:
	var d := {}
	if mi == null or mi.mesh == null:
		return d
	var arr := mi.mesh.surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	if uv.size() != vv.size():
		return d
	# encolure : sommet du devant le plus haut près de l'axe
	var ycol := -1.0
	var icol := -1
	for i in vv.size():
		var v := vv[i]
		if v.z > 0.02 and absf(v.x) < 0.04 and v.y > ycol and uv[i].y < ChasseresseTextures.V_JUPE:
			ycol = v.y
			icol = i
	if icol < 0:
		return d
	d["col"] = Vector2(uv[icol].x * W, uv[icol].y * H)
	d["y_col"] = ycol
	# fibules : sur le haut de la poitrine, à 0,075 m de l'axe, 0,12 m sous l'encolure ; sommet le plus en avant
	for cote in [-1, 1]:
		var cible := Vector2(0.075 * cote, ycol - 0.12)
		var best := -1
		var bd := 1e9
		for i in vv.size():
			var v := vv[i]
			if v.z < 0.02 or uv[i].y >= ChasseresseTextures.V_JUPE:
				continue
			# parmi les sommets à moins de 2,5 cm de la cible, le plus en avant (pas la doublure intérieure au même endroit)
			if Vector2(v.x, v.y).distance_to(cible) > 0.025:
				continue
			if -v.z < bd:
				bd = -v.z
				best = i
		if best >= 0:
			d["fib_g" if cote < 0 else "fib_d"] = Vector2(uv[best].x * W, uv[best].y * H)
	return d

# ------------------------------------------------------------------------------------------------ peinture
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	var W := img.get_width()
	var xx := posmod(x, W)
	if y < 0 or y >= img.get_height():
		return
	var a := img.get_pixel(xx, y).a
	if a < 0.05:
		return
	img.set_pixel(xx, y, Color(c.r, c.g, c.b, a))

static func _mul(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)

## Facteur de tissage d'un texel (valeur autour de 1).
static func _trame(t: String, x: int, y: int) -> float:
	match t:
		"toile":
			return 1.05 if (x + y) % 2 == 0 else 0.96
		"serge":
			return 1.06 if posmod(x + y, 4) < 2 else 0.95
		"chevrons":
			var s := x if (x / 6) % 2 == 0 else -x
			return 1.07 if posmod(s + y, 4) < 2 else 0.94
		"losanges":
			var k := absi(posmod(x, 10) - 5) + absi(posmod(y, 8) - 4)
			return 1.07 if k % 4 < 2 else 0.95
		"cotele":
			return 1.06 if x % 3 != 0 else 0.90
	return 1.0

static func peindre(img: Image, c: Dictionary, g: int) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var yj := int(ChasseresseTextures.V_JUPE * H)
	var laine: Color = c["laine"]
	var tissage := String(c.get("tissage", "toile"))
	# 1. torse et manches : laine tissée (fils flammés, nuages de teinture inégale, coutures latérales)
	for y in yj:
		for x in W:
			var a := img.get_pixel(x, y).a
			if a < 0.05:
				continue
			var f := _trame(tissage, x, y)
			f += (RealismePnj.bruit(x, y, W, H, 12, 5, g + 401) - 0.5) * 0.16      # teinture inégale
			f += (RealismePnj._h(x / 3, y, g + 403) - 0.5) * 0.08                 # fil flammé (irrégulier sur 3 texels)
			if RealismePnj._h(x, y, g + 405) > 0.985:
				f -= 0.12                                                          # bouloches / fil sombre
			var col := laine
			var dt := RealismePnj.bruit(x, y, W, H, 5, 3, g + 407) - 0.5
			col = Color(col.r * (1.0 + dt * 0.10), col.g * (1.0 + dt * 0.04), col.b * (1.0 - dt * 0.06))   # bain de teinture
			if posmod(x - W / 4, W / 2) == 0:
				f *= 0.72                                                          # coutures des flancs
			elif posmod(x - W / 4, W / 2) == 1:
				f *= 1.06
			if y == yj - 1 or y == yj - 2:
				f *= 0.80                                                          # couture de taille
			img.set_pixel(x, y, Color(clampf(col.r * f, 0, 1), clampf(col.g * f, 0, 1), clampf(col.b * f, 0, 1), a))
	var an: Dictionary = c.get("ancres", {})
	if not an.has("col"):
		return
	var col_pos: Vector2 = an["col"]
	var yn := int(col_pos.y)
	# 2. galon tissé à l'encolure (tour du cou), motif de petits chevrons
	if c.has("galon"):
		var gc: Color = c["galon"]
		for y in range(maxi(yn - 1, 0), mini(yn + 3, yj)):
			for x in W:
				var k := posmod(x + (y - yn) * (1 if (x / 4) % 2 == 0 else -1), 4)
				var cc := gc if k < 2 else gc.darkened(0.30)
				if y == yn + 2:
					cc = gc.darkened(0.45)                                         # lisière
				_px(img, x, y, cc)
	var x0 := int(col_pos.x)
	match String(c.get("fermoir", "")):
		"lacets":
			# encolure fendue au milieu du devant, laçage croisé de cuir sur 18 texels
			var cuir := Color(0.26, 0.19, 0.13)
			for y in range(yn, mini(yn + 18, yj)):
				_px(img, x0, y, Color(0.09, 0.07, 0.06))
				var dy := y - yn
				var e := 2 if dy % 6 < 3 else 3
				var k := dy % 6
				_px(img, x0 - 1 - (k if k < 3 else 5 - k), y, cuir)
				_px(img, x0 + 1 + (k if k < 3 else 5 - k), y, cuir.lightened(0.12))
				if dy % 6 == 0:
					_px(img, x0 - e - 1, y, Color(0.12, 0.10, 0.08))                  # œillets
					_px(img, x0 + e + 1, y, Color(0.12, 0.10, 0.08))
		"broche":
			# broche ronde de bronze sous l'encolure (disque à bossette, 7 texels)
			_broche(img, x0, yn + 6, 3.4, 3.0)
		"fibules":
			if an.has("fib_g") and an.has("fib_d"):
				var pg: Vector2 = an["fib_g"]
				var pd: Vector2 = an["fib_d"]
				# bretelles de la robe-tablier (laine plus sombre) des fibules à la taille
				var bret := laine.darkened(0.30)
				for p in [pg, pd]:
					for y in range(int(p.y), yj):
						for dx in range(-2, 2):
							_px(img, int(p.x) + dx, y, _mul(bret, _trame("serge", int(p.x) + dx, y) * (0.85 if dx == -2 else 1.0)))
				# rang de perles en guirlande d'une fibule à l'autre (passe par le milieu du devant : u = 0)
				var perles: Array = c.get("perles", [Color(0.55, 0.36, 0.14)])
				var a0 := pg.x
				var a1 := pd.x
				if a1 - a0 > W / 2:
					a0 += W
				elif a0 - a1 > W / 2:
					a1 += W
				var n := int(absf(a1 - a0) / 2.0)
				for i in range(1, n):
					var t := float(i) / n
					var px := lerpf(a0, a1, t)
					var py := lerpf(pg.y, pd.y, t) + 6.0 * sin(t * PI)
					var pc: Color = perles[i % perles.size()]
					_px(img, int(roundf(px)), int(roundf(py)), pc)
					_px(img, int(roundf(px)), int(roundf(py)) + 1, pc.darkened(0.40))
				for p in [pg, pd]:
					_broche(img, int(p.x), int(p.y), 3.6, 2.8)

## Fibule ovale / broche ronde en bronze terni : contour sombre, dôme, rehaut, bossettes.
static func _broche(img: Image, cx: int, cy: int, rx: float, ry: float) -> void:
	var bronze := Color(0.44, 0.35, 0.20)
	for y in range(-int(ceil(ry)) - 1, int(ceil(ry)) + 2):
		for x in range(-int(ceil(rx)) - 1, int(ceil(rx)) + 2):
			var d := pow(x / (rx + 0.5), 2) + pow(y / (ry + 0.5), 2)
			if d > 1.0:
				continue
			var c := bronze
			if d > 0.62:
				c = Color(0.16, 0.12, 0.08)                     # contour / ombre
			elif x < 0 and y < 0 and d < 0.35:
				c = bronze.lightened(0.28)                      # rehaut du dôme
			elif d > 0.30 and (x + y) % 2 == 0:
				c = bronze.darkened(0.25)                       # ajours ciselés
			if x == 0 and y == 0:
				c = Color(0.60, 0.50, 0.32)                     # bossette
			_px(img, cx + x, cy + y, c)
