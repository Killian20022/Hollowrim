extends SceneTree
## Assemble des images en grille : godot --headless --script outils/montage.gd -- sortie.png colonnes largeur_case fichier1 fichier2 ...
## (cases réduites à la largeur donnée, plus proche voisin si agrandi ; fichier « - » = case vide)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var cols := int(a[1])
	var lc := int(a[2])
	var imgs: Array[Image] = []
	for i in range(3, a.size()):
		if a[i] == "-":
			imgs.append(null)
			continue
		var im := Image.load_from_file(a[i])
		im.convert(Image.FORMAT_RGBA8)
		var h := int(float(im.get_height()) * lc / im.get_width())
		im.resize(lc, h, Image.INTERPOLATE_LANCZOS if lc < im.get_width() else Image.INTERPOLATE_NEAREST)
		imgs.append(im)
	var hc := 0
	for im in imgs:
		if im:
			hc = maxi(hc, im.get_height())
	var rows := ceili(float(imgs.size()) / cols)
	var sortie := Image.create(cols * lc, rows * hc, false, Image.FORMAT_RGBA8)
	sortie.fill(Color(0.1, 0.1, 0.12))
	for i in imgs.size():
		if imgs[i]:
			sortie.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i((i % cols) * lc, (i / cols) * hc))
	sortie.save_png(a[0])
	quit()
