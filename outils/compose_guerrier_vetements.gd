extends SceneTree
## Planches référence | avant | après du Guerrier (passe vêtements). Sans fenêtre :
##   godot --headless --path . --script res://outils/compose_guerrier_vetements.gd -- --avant=<dossier> --apres=<dossier> --sortie=<dossier>
## Référence : Image ChatGPT 14_01_55-1 (guerrier à cape bleue). Dossiers : captures de outils/poses_guerrier_vetements.txt.
const REF := "C:/Users/lopezk19/Downloads/Image ChatGPT 21 oct. 2026, 14_01_55-1.png"

func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return ""

func _init() -> void:
	var avant := _arg("avant")
	var apres := _arg("apres")
	var sortie := _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var ref := Image.load_from_file(REF)
	ref.convert(Image.FORMAT_RGBA8)
	var s := ref.get_width() / 1024.0
	# 2 m : référence (une fois) | avant | après pour face, 3/4, dos
	var fig := ref.get_region(Rect2i(int(30 * s), int(190 * s), int(810 * s), int(1210 * s)))
	fig.resize(482, 720, Image.INTERPOLATE_NEAREST)
	var pl := Image.create(482 + 640 * 6, 720, false, Image.FORMAT_RGBA8)
	pl.fill(Color(0.1, 0.1, 0.12))
	pl.blit_rect(fig, Rect2i(0, 0, 482, 720), Vector2i(0, 0))
	var x := 482
	for v in ["2m_face", "2m_34", "2m_dos"]:
		for d in [avant, apres]:
			var im := _ld("%s/p17_%s.png" % [d, v])
			im.resize(640, 360, Image.INTERPOLATE_NEAREST)
			var cr := im.get_region(Rect2i(160, 60, 320, 240))
			cr.resize(640, 720, Image.INTERPOLATE_NEAREST)
			pl.blit_rect(cr, Rect2i(0, 0, 640, 720), Vector2i(x, 0))
			x += 640
	pl.save_png(sortie + "/planche_2m_ref_avant_apres.png")
	# gros plans : ligne = référence | avant | après
	var crops := {"v_torse_1m": Rect2i(280, 340, 480, 270), "v_ceinture_1m": Rect2i(300, 560, 440, 248), "v_bas_1m": Rect2i(300, 760, 440, 248),
		"v_bottes_1m": Rect2i(200, 1040, 560, 315), "v_dos_1m": Rect2i(40, 560, 400, 225), "v_epaule_1m": Rect2i(260, 340, 400, 225),
		"v_bras_1m": Rect2i(240, 540, 400, 225)}
	var noms: Array = crops.keys()
	var gp := Image.create(640 * 3, 360 * noms.size(), false, Image.FORMAT_RGBA8)
	for i in noms.size():
		var r: Rect2i = crops[noms[i]]
		var rr := ref.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s), int(r.size.x * s), int(r.size.y * s)))
		rr.resize(640, 360, Image.INTERPOLATE_NEAREST)
		gp.blit_rect(rr, Rect2i(0, 0, 640, 360), Vector2i(0, i * 360))
		var col := 1
		for d in [avant, apres]:
			var im := _ld("%s/%s.png" % [d, noms[i]])
			# zoom x2 : découpe 640x360 autour du personnage (capture 1280x720), sans rééchantillonnage
			var oy: int = {"v_torse_1m": 140, "v_ceinture_1m": 230, "v_bas_1m": 230, "v_bottes_1m": 190, "v_dos_1m": 150, "v_epaule_1m": 60, "v_bras_1m": 250}[noms[i]]
			im = im.get_region(Rect2i(320, oy, 640, 360))
			gp.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * col, i * 360))
			col += 1
	gp.save_png(sortie + "/planche_gros_plans_ref_avant_apres.png")
	# 4 m et 8 m : avant | après, face, 3/4, dos (découpe centrale)
	var dd := Image.create(640 * 6, 360 * 2, false, Image.FORMAT_RGBA8)
	var r2 := 0
	for m in ["4m", "8m"]:
		var c := 0
		for v in ["face", "34", "dos"]:
			for d in [avant, apres]:
				var im := _ld("%s/p17_%s_%s.png" % [d, m, v])
				im.resize(640, 360, Image.INTERPOLATE_NEAREST)
				dd.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(c * 640, r2 * 360))
				c += 1
		r2 += 1
	dd.save_png(sortie + "/planche_4m_8m_avant_apres.png")
	# animations : après (grille 4 x 3)
	var an := ["an_idle", "an_garde", "an_marche_a", "an_marche_b", "an_course_a", "an_course_b", "an_attaque_a", "an_attaque_b", "an_coup", "an_mort_a", "an_mort_b"]
	var ga := Image.create(640 * 4, 360 * 3, false, Image.FORMAT_RGBA8)
	for i in an.size():
		var im := _ld("%s/%s.png" % [apres, an[i]])
		im.resize(640, 360, Image.INTERPOLATE_NEAREST)
		ga.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i((i % 4) * 640, (i / 4) * 360))
	ga.save_png(sortie + "/planche_animations_apres.png")
	quit(0)

func _ld(chemin: String) -> Image:
	var im := Image.load_from_file(chemin)
	im.convert(Image.FORMAT_RGBA8)
	return im
