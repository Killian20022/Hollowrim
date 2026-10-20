extends SceneTree
## Planche des textures du lot 5 (2e passe : textures de PeintureBati, sans cuisson) (pierre, bois, fer…) : chaque tuile ×6 + mosaïque 3×3 ×3 + taille réelle ×1.
##   godot --headless --path . --script outils/planche_bati.gd [-- dossier]
## Écrit <dossier>/<nom>_x6.png, <nom>_mosaique.png et planche_textures.png (défaut res://captures/batiments/textures).

func _agrandi(img: Image, k: int) -> Image:
	var o := Image.create(img.get_width() * k, img.get_height() * k, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			o.fill_rect(Rect2i(x * k, y * k, k, k), img.get_pixel(x, y))
	return o

func _mosaique(src: Image, n: int) -> Image:
	var o := Image.create(src.get_width() * n, src.get_height() * n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			o.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(i * src.get_width(), j * src.get_height()))
	return o

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else "res://captures/batiments/textures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var chrono := Time.get_ticks_msec()
	var liste := {}
	var f := PeintureBati.fabriques()
	for nom: String in f:
		liste[nom] = ((f[nom] as Callable).call() as Array)[0]
	print("génération : %d ms" % (Time.get_ticks_msec() - chrono))
	for nom: String in liste:
		var img: Image = liste[nom]
		_agrandi(img, 6 if img.get_width() <= 64 else 4).save_png("%s/%s_x6.png" % [dossier, nom])
		_agrandi(_mosaique(img, 3), 3 if img.get_width() <= 64 else 2).save_png("%s/%s_mosaique.png" % [dossier, nom])
	# planche : pierre, roche, planches h/v côte à côte en mosaïque 2×2 x3
	var noms := ["pierre_seche", "roche", "planches_h", "planches_v", "rondins", "fer", "cuir", "foin", "neige"]
	var tuiles: Array[Image] = []
	for nom in noms:
		tuiles.append(_agrandi(_mosaique(liste[nom], 2), 2))
	var cw := 0
	var ch := 0
	for t in tuiles:
		cw = maxi(cw, t.get_width())
		ch = maxi(ch, t.get_height())
	var sheet := Image.create(cw * 3, ch * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in tuiles.size():
		sheet.blit_rect(tuiles[i], Rect2i(Vector2i.ZERO, tuiles[i].get_size()), Vector2i((i % 3) * cw, (i / 3) * ch))
	sheet.save_png("%s/planche_textures.png" % dossier)
	quit()
