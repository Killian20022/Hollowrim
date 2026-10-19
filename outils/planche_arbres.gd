extends SceneTree
## Planche des textures d'arbres du lot 2 (agrandies ×8, plus les mipmaps pixel art) :
##   godot --headless --path . --script outils/planche_arbres.gd [-- dossier]
## Écrit <dossier>/atlas_epicea_x8.png, mips_epicea.png, ecorce_epicea_x8.png… (défaut res://captures/arbres/textures)

func _agrandi(img: Image, k: int, fond := Color(0.16, 0.18, 0.24)) -> Image:
	var o := Image.create(img.get_width() * k, img.get_height() * k, false, Image.FORMAT_RGBA8)
	o.fill(fond)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				o.fill_rect(Rect2i(x * k, y * k, k, k), c)
	return o

func _mosaique(src: Image, n: int) -> Image:
	var o := Image.create(src.get_width() * n, src.get_height() * n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			o.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(i * src.get_width(), j * src.get_height()))
	return o

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else "res://captures/arbres/textures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var sorties := TexturesArbres.planches()
	for nom: String in sorties:
		var img: Image = sorties[nom]
		var k := 8 if img.get_width() <= 128 else 4
		_agrandi(img, k).save_png("%s/%s_x%d.png" % [dossier, nom, k])
		# mipmaps : niveaux 1 à 3 agrandis à la taille du niveau 0
		var tex := TexturesArbres.avec_mips(img)
		var full := tex.get_image()
		var bande := Image.create(img.get_width() * 4 * 2, img.get_height() * 2, false, Image.FORMAT_RGBA8)
		bande.fill(Color(0.16, 0.18, 0.24))
		for lv in 4:
			var mi := full.duplicate() as Image
			var w := maxi(img.get_width() >> lv, 1)
			var h := maxi(img.get_height() >> lv, 1)
			var off := full.get_mipmap_offset(lv)
			var data := full.get_data().slice(off, off + w * h * 4)
			var niveau := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
			var grand := _agrandi(niveau, 2 << lv)
			bande.blit_rect(grand, Rect2i(Vector2i.ZERO, grand.get_size()), Vector2i(lv * img.get_width() * 2, 0))
		bande.save_png("%s/%s_mips.png" % [dossier, nom])
		if nom.begins_with("ecorce"):
			_agrandi(_mosaique(img, 3), 4).save_png("%s/%s_mosaique.png" % [dossier, nom])
	print("planches : ", sorties.keys())
	quit()
