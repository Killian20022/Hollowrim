extends SceneTree
## Génère assets/magie/bruit_vague.png (bruit de la vague de flammes, shaders/magie_vague.gdshader) :
##   godot --headless --path . --script res://outils/generer_bruit_vague.gd
## Déterministe (graine 4242) : relancer donne le même fichier.

func _init() -> void:
	bruit().save_png("res://assets/magie/bruit_vague.png")
	print("bruit_vague.png écrit")
	quit()

## Bruit fractal périodique de la vague (64², RGBA = 4 bruits indépendants ; 3 octaves de bruit de valeur, périodes de
## 8, 16 et 32 cases) : le shader lit le motif au lieu de le calculer (coût GPU : 2 lectures au lieu de ~28 hachages par pixel).
static func bruit() -> Image:
	var t := 64
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var grilles: Array = []   # [canal][octave] -> PackedFloat32Array (p × p)
	for c in 4:
		var oct: Array = []
		for p: int in [8, 16, 32]:
			var g := PackedFloat32Array()
			g.resize(p * p)
			for i in p * p:
				g[i] = rng_b.randf()
			oct.append(g)
		grilles.append(oct)
	for y in t:
		for x in t:
			var px := Color()
			for c in 4:
				var v := 0.0
				var poids := 0.5
				var k := 0
				for p: int in [8, 16, 32]:
					var fx := float(x * p) / t
					var fy := float(y * p) / t
					var ix := int(fx)
					var iy := int(fy)
					var ux: float = fx - ix
					var uy: float = fy - iy
					ux = ux * ux * (3.0 - 2.0 * ux)
					uy = uy * uy * (3.0 - 2.0 * uy)
					var g: PackedFloat32Array = grilles[c][k]
					var a := g[iy * p + ix]
					var b := g[iy * p + (ix + 1) % p]
					var d := g[((iy + 1) % p) * p + ix]
					var e := g[((iy + 1) % p) * p + (ix + 1) % p]
					v += poids * lerpf(lerpf(a, b, ux), lerpf(d, e, ux), uy)
					poids *= 0.5
					k += 1
				px[c] = v / 0.875
			img.set_pixel(x, y, px)
	return img

