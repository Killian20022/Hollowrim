extends SceneTree
## Statistiques de « bruit » des textures (lot 5) : part de texels isolés (aucun voisin 4-connexe de même
## couleur) et taille moyenne des amas de même couleur, ancien générateur (Palette.texture) contre TexturesBati.
##   godot --headless --path . --script outils/stat_textures.gd

func _stats(nom: String, img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var vu := PackedByteArray()
	vu.resize(w * h)
	var amas := 0
	var isoles := 0
	var couleurs := {}
	for y in h:
		for x in w:
			couleurs[img.get_pixel(x, y)] = true
			if vu[y * w + x] == 1:
				continue
			var c := img.get_pixel(x, y)
			var pile: Array[Vector2i] = [Vector2i(x, y)]
			vu[y * w + x] = 1
			var n := 0
			while not pile.is_empty():
				var p: Vector2i = pile.pop_back()
				n += 1
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(posmod(p.x + d.x, w), posmod(p.y + d.y, h))
					if vu[q.y * w + q.x] == 0 and img.get_pixel(q.x, q.y) == c:
						vu[q.y * w + q.x] = 1
						pile.append(q)
			amas += 1
			if n == 1:
				isoles += 1
	print("%-22s %3dx%-3d couleurs %2d | amas %4d | texels isolés %5.2f %% | taille moyenne d'amas %6.1f texels" % [nom, w, h, couleurs.size(), amas, 100.0 * isoles / (w * h), float(w * h) / amas])

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	print("--- AVANT (Palette.texture : bruit de valeur quantifié + grain aléatoire + paillettes)")
	_stats("roche (monde)", Palette.texture(32, Palette.ROCHE, 4, 2, 0.45, rng).get_image())
	_stats("planches (village)", Palette.texture(32, Palette.PLANCHES, 4, "planches".hash() & 0xff, 0.5, rng).get_image())
	_stats("neige (paillettes)", Palette.pailleter(Palette.texture(64, Palette.NEIGE, 3, 1, 0.12, rng), 0.012).get_image())
	_stats("écorce (poteaux)", Palette.texture(32, Palette.ECORCE, 4, "ecorce".hash() & 0xff, 0.4, rng).get_image())
	print("--- APRÈS (TexturesBati : amas dessinés + filtre mode)")
	var f := PeintureBati.fabriques()
	for nom: String in ["pierre_seche", "roche", "planches_v", "rondins", "neige", "fer"]:
		_stats(nom, ((f[nom] as Callable).call() as Array)[0])
	quit()
