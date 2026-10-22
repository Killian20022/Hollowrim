extends SceneTree
## Planches de la passe Blender du Guerrier : référence | avant | après (captures de galerie_guerrier.gd --mode=vet). Sans fenêtre :
##   godot --headless --path . --script res://outils/compose_guerrier_blender.gd -- --avant=<dossier> --apres=<dossier> --sortie=<dossier> [--forgeron=<dossier>]
## Référence : Image ChatGPT 21 oct. 2026, 14_01_55-1.png (guerrier à cape bleue).
const REF := "C:/Users/lopezk19/Downloads/Image ChatGPT 21 oct. 2026, 14_01_55-1.png"

func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return ""

func _img(dossier: String, nom: String, w: int, h: int) -> Image:
	var i := Image.load_from_file("%s/%s.png" % [dossier, nom])
	i.convert(Image.FORMAT_RGBA8)
	i.resize(w, h, Image.INTERPOLATE_NEAREST)
	return i

func _ligne(pl: Image, dossier: String, noms: Array, x0: int, y: int, w: int, h: int) -> void:
	for k in noms.size():
		pl.blit_rect(_img(dossier, noms[k], w, h), Rect2i(0, 0, w, h), Vector2i(x0 + k * w, y))

func _init() -> void:
	var avant := _arg("avant")
	var apres := _arg("apres")
	var sortie := _arg("sortie")
	var forg := _arg("forgeron")
	DirAccess.make_dir_recursive_absolute(sortie)
	var ref := Image.load_from_file(REF)
	ref.convert(Image.FORMAT_RGBA8)
	var s := ref.get_width() / 1024.0
	# 2 m : référence | (avant / après) x face, 3/4, dos
	var fig := ref.get_region(Rect2i(int(30 * s), int(190 * s), int(810 * s), int(1210 * s)))
	fig.resize(482, 720, Image.INTERPOLATE_NEAREST)
	var pl := Image.create(482 + 640 * 3, 720, false, Image.FORMAT_RGBA8)
	pl.fill(Color(0.1, 0.1, 0.12))
	pl.blit_rect(fig, Rect2i(0, 0, 482, 720), Vector2i.ZERO)
	_ligne(pl, avant, ["2m_face", "2m_34", "2m_dos"], 482, 0, 640, 360)
	_ligne(pl, apres, ["2m_face", "2m_34", "2m_dos"], 482, 360, 640, 360)
	pl.save_png(sortie + "/planche_2m_ref_avant_apres.png")
	# gros plans : avant (haut) / après (bas)
	var g := ["gros_bas", "gros_ceinture", "gros_torse", "gros_dos", "gros_cape_dos", "gros_epaule"]
	var pg := Image.create(427 * 6, 480, false, Image.FORMAT_RGBA8)
	_ligne(pg, avant, g, 0, 0, 427, 240)
	_ligne(pg, apres, g, 0, 240, 427, 240)
	pg.save_png(sortie + "/planche_gros_plans_avant_apres.png")
	# 4 m et 8 m
	var d := ["4m_face", "4m_34", "4m_dos", "8m_face", "8m_34", "8m_dos"]
	var p4 := Image.create(427 * 6, 480, false, Image.FORMAT_RGBA8)
	_ligne(p4, avant, d, 0, 0, 427, 240)
	_ligne(p4, apres, d, 0, 240, 427, 240)
	p4.save_png(sortie + "/planche_4m_8m_avant_apres.png")
	if forg != "":
		var f := ["2m_face", "2m_34", "gros_bras", "gros_torse", "gros_epaule", "gros_bas"]
		var pf := Image.create(427 * 6, 240, false, Image.FORMAT_RGBA8)
		_ligne(pf, forg, f, 0, 0, 427, 240)
		pf.save_png(sortie + "/planche_forgeron_avant_bras_nus.png")
	quit(0)
