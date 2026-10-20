extends SceneTree
## Planche des écorces du lot 2 « troncs » (tuile ×5 + mosaïque 2×2 en 32 texels/m, + niveau de mipmap 1) :
##   godot --headless --path . --script res://outils/planche_ecorces.gd [-- dossier]
## Écrit <dossier>/ecorces.png (lignes = essences, colonnes = haut | pied) et les temps de génération.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else "res://captures/arbres/textures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var k := 4
	var tuiles: Array[Image] = []
	var t0 := Time.get_ticks_msec()
	for nom in Ecorces.NOMS:
		var t := Time.get_ticks_msec()
		var img := Ecorces.image(nom)
		print("%s : %d ms" % [nom, Time.get_ticks_msec() - t])
		tuiles.append(img)
	print("total images : %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()
	for nom in Ecorces.NOMS:
		Ecorces.tuile(nom)
	print("total avec mips : %d ms" % (Time.get_ticks_msec() - t0))
	var S := Ecorces.N * 2 * k
	var out := Image.create(S * 2, S * 4, false, Image.FORMAT_RGBA8)
	for i in tuiles.size():
		var img := tuiles[i]
		var rgb := Image.create(Ecorces.N, Ecorces.N, false, Image.FORMAT_RGBA8)
		for y in Ecorces.N:
			for x in Ecorces.N:
				var c := img.get_pixel(x, y)
				c.a = 1.0
				rgb.set_pixel(x, y, c)
		var gros := rgb.duplicate()
		gros.resize(Ecorces.N * k, Ecorces.N * k, Image.INTERPOLATE_NEAREST)
		var ox := (i % 2) * S
		var oy := (i / 2) * S
		for j in 4:
			out.blit_rect(gros, Rect2i(0, 0, Ecorces.N * k, Ecorces.N * k), Vector2i(ox + (j % 2) * Ecorces.N * k, oy + (j / 2) * Ecorces.N * k))
	out.save_png(ProjectSettings.globalize_path(dossier + "/ecorces.png"))
	quit()
