extends SceneTree
## Icône du jeu (Hollowrim) : pierre runique givrée (rune Hagalaz ᚺ, la grêle — le H du titre) devant un tumulus enneigé,
## sous une aurore. Dessinée par une fonction de (u, v) ∈ [0,1]² échantillonnée à chaque taille (16 → 256 px) : chaque taille
## a ses propres pixels nets, sans réduction floue. Sorties :
##   assets/ui/icone.png (256)  ·  assets/ui/icone.ico (16, 24, 32, 48, 64, 128, 256 ; PNG dans l'ICO, Windows Vista et +)
##   godot --headless --path . --script res://outils/generer_icone.gd

const TAILLES := [16, 24, 32, 48, 64, 128, 256]
const NUIT_HAUT := Color("#1b2a4a")
const NUIT_BAS := Color("#0b0f1a")
const AURORE_A := Color("#5fe3a1")
const AURORE_B := Color("#6fd8ff")
const NEIGE := Color("#dfe8f5")
const NEIGE_OMBRE := Color("#8794b0")
const TERRE := Color("#2a3346")
const PIERRE := Color("#5d6474")
const PIERRE_CLAIRE := Color("#8a90a0")
const PIERRE_SOMBRE := Color("#3a3f4c")
const RUNE := Color("#7fe6ff")
const CONTOUR := Color("#070a12")

func _init() -> void:
	var pngs := []
	for t: int in TAILLES:
		var img := dessiner(t)
		pngs.append(img.save_png_to_buffer())
		if t == 256:
			img.save_png(ProjectSettings.globalize_path("res://assets/ui/icone.png"))
	_ecrire_ico(ProjectSettings.globalize_path("res://assets/ui/icone.ico"), pngs)
	print("ICONE : assets/ui/icone.png + icone.ico (", TAILLES, ")")
	quit()

## Échantillonne le dessin : n×n sous-pixels par pixel (lissage léger des bords aux petites tailles seulement).
func dessiner(t: int) -> Image:
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	var n := 1 if t >= 64 else 2
	# grande taille : dessin en 64x64 agrandi sans lissage (pixels nets, style du jeu)
	var base := mini(t, 64)
	var k := t / base
	for y in base:
		for x in base:
			var acc := Color(0, 0, 0, 0)
			for sy in n:
				for sx in n:
					var c := couleur((x + (sx + 0.5) / n) / base, (y + (sy + 0.5) / n) / base, base)
					acc += Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
			acc /= float(n * n)
			if acc.a > 0.0:
				acc = Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a)
			for yy in k:
				for xx in k:
					img.set_pixel(x * k + xx, y * k + yy, acc)
	return img

## Couleur du dessin au point (u, v) (v vers le bas). `base` = taille de la grille (pour l'épaisseur des traits).
func couleur(u: float, v: float, base: int) -> Color:
	var px := 1.0 / base
	# coins arrondis (carré de rayon 0,14)
	var r := 0.14
	var cx := clampf(u, r, 1.0 - r)
	var cy := clampf(v, r, 1.0 - r)
	if Vector2(u - cx, v - cy).length() > r:
		return Color(0, 0, 0, 0)
	var bord := Vector2(u - cx, v - cy).length() > r - px * 1.2 and (u < r or u > 1.0 - r or v < r or v > 1.0 - r)
	if bord or u < px or v < px or u > 1.0 - px or v > 1.0 - px:
		return CONTOUR
	# ciel : dégradé + aurore ondulée + quelques étoiles
	var c := NUIT_BAS.lerp(NUIT_HAUT, clampf(1.0 - v * 1.4, 0.0, 1.0))
	var onde := 0.30 + sin(u * 7.0 + 0.6) * 0.06 + sin(u * 15.0) * 0.015
	var d := absf(v - onde)
	if d < 0.11 and v < 0.62:
		var force := pow(1.0 - d / 0.11, 1.6) * 0.85
		# rideau : stries verticales
		force *= 0.75 + 0.25 * sin(u * 60.0)
		c = c.lerp(AURORE_A.lerp(AURORE_B, clampf(u * 1.2 - 0.1, 0.0, 1.0)), force)
	for e: Vector2 in [Vector2(0.18, 0.12), Vector2(0.80, 0.10), Vector2(0.62, 0.20), Vector2(0.10, 0.42), Vector2(0.88, 0.44)]:
		if absf(u - e.x) < px * 0.6 and absf(v - e.y) < px * 0.6:
			c = Color("#e8eefc")
	# tumulus : demi-ellipse enneigée, ombrée à droite et vers le bas
	var tu := (u - 0.5) / 0.48
	var tv := (v - 0.98) / 0.40
	var dt := tu * tu + tv * tv
	if dt < 1.0 and v < 0.98:
		var ombre := clampf(tu * 0.6 + (1.0 - sqrt(dt)) * -0.3 + 0.35, 0.0, 1.0)
		c = Color("#c3cfe2").lerp(NEIGE_OMBRE, ombre)
		# pierres du tertre qui percent la neige
		for pr: Vector2 in [Vector2(0.20, 0.80), Vector2(0.27, 0.71), Vector2(0.76, 0.74), Vector2(0.83, 0.83), Vector2(0.68, 0.66)]:
			if Vector2((u - pr.x) * 1.0, (v - pr.y) * 1.6).length() < 0.022:
				c = PIERRE_SOMBRE
		if dt > 1.0 - px * 6.0:
			c = c.lerp(CONTOUR, 0.55)   # liseré de la crête
	# sol enneigé
	if v > 0.86:
		c = NEIGE_OMBRE.lerp(TERRE, clampf((v - 0.86) / 0.12, 0.0, 1.0) * 0.6)
	# pierre levée : trapèze arrondi en haut
	var haut := 0.24
	var bas := 0.90
	if v >= haut and v <= bas:
		var t := (v - haut) / (bas - haut)
		var demi := lerpf(0.085, 0.135, t)
		var dome := 0.0
		# sommet en biais (plus haut à gauche), arrondi
		var du := u - 0.5
		var sommet := haut + 0.05 + du * 0.25
		if v < sommet:
			demi = 0.0
		var top_local := v - sommet
		if absf(du) <= demi:
			if absf(du) > demi - px * 1.2 or top_local < px * 1.5 or v > bas - px * 1.2:
				return CONTOUR
			c = PIERRE.lerp(PIERRE_CLAIRE, clampf(-du / demi * 0.8, 0.0, 1.0)).lerp(PIERRE_SOMBRE, clampf(du / demi, 0.0, 1.0) * 0.7)
			# neige sur le sommet de la pierre
			if top_local < 0.035:
				c = NEIGE
			dome = 1.0
			# rune Hagalaz ᚺ : deux montants et une barre oblique, lumineux
			var ep := maxf(px * 1.1, 0.032)
			var r_haut := 0.40
			var r_bas := 0.78
			var x_g := 0.5 - 0.050
			var x_d := 0.5 + 0.050
			var sur := false
			if v > r_haut and v < r_bas:
				if absf(u - x_g) < ep * 0.5 or absf(u - x_d) < ep * 0.5:
					sur = true
				# barre oblique de (x_g, 0.53) à (x_d, 0.63)
				var s := clampf((u - x_g) / (x_d - x_g), 0.0, 1.0)
				var y_barre := lerpf(0.555, 0.615, s)
				if u > x_g - ep * 0.5 and u < x_d + ep * 0.5 and absf(v - y_barre) < ep * 0.55:
					sur = true
			if sur:
				return RUNE
			# halo de la rune
			var halo := 0.0
			if v > r_haut - 0.04 and v < r_bas + 0.04 and absf(u - 0.5) < 0.09:
				halo = 0.22
			c = c.lerp(RUNE, halo)
	return c

## ICO : en-tête + une entrée par taille (PNG intégrés).
func _ecrire_ico(chemin: String, pngs: Array) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_16(0)
	f.store_16(1)
	f.store_16(pngs.size())
	var decalage := 6 + 16 * pngs.size()
	for i in pngs.size():
		var t: int = TAILLES[i]
		var data: PackedByteArray = pngs[i]
		f.store_8(0 if t >= 256 else t)
		f.store_8(0 if t >= 256 else t)
		f.store_8(0)
		f.store_8(0)
		f.store_16(1)
		f.store_16(32)
		f.store_32(data.size())
		f.store_32(decalage)
		decalage += data.size()
	for data: PackedByteArray in pngs:
		f.store_buffer(data)
	f.close()
