extends SceneTree
## Planches de la Chasseresse nordique à partir des captures en jeu (outils/poses_chasseresse.txt et poses_chasseresse_cote.txt,
## sorties x2 de 1280x720) :
##   godot --headless --path . --script res://outils/planche_chasseresse.gd -- --captures=<dossier> --sortie=<dossier> --ref=<image> [--cote=<dossier>]
## (a) planche_ref__chasseresse_face_34_dos_2_4_8m.png : référence | grille 3 x 3 (face, 3/4, dos x 2, 4, 8 m)
## (b) planche_gros_plans_visage_arc_carquois_2m_1m.png ; (c) planche_animations_idle_marche_course_vise_tir_coup_mort.png ;
## (d) planche_cote_a_cote_guerrier.png ; + planche_entree_village_17h30_21h_torche.png.
var cap := ""
var sortie := ""

func _arg(n: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n):
			return a.substr(n.length() + 3)
	return ""

func _img(dossier: String, nom: String) -> Image:
	var i := Image.load_from_file(dossier.path_join(nom + ".png"))
	if i == null:
		push_error("capture absente " + nom)
		return Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	i.convert(Image.FORMAT_RGBA8)
	return i

func _grille(dossier: String, noms: Array, colonnes: int, larg: int) -> Image:
	var lignes := ceili(float(noms.size()) / colonnes)
	var out := Image.create(larg * colonnes, 720 * lignes, false, Image.FORMAT_RGBA8)
	for i in noms.size():
		var img := _img(dossier, noms[i])
		out.blit_rect(img.get_region(Rect2i((img.get_width() - larg) / 2, 0, larg, img.get_height())), Rect2i(0, 0, larg, 720), Vector2i((i % colonnes) * larg, (i / colonnes) * 720))
	return out

func _init() -> void:
	cap = _arg("captures")
	sortie = _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var g := _grille(cap, ["p17_2m_face", "p17_2m_34", "p17_2m_dos", "p17_4m_face", "p17_4m_34", "p17_4m_dos", "p17_8m_face", "p17_8m_34", "p17_8m_dos"], 3, 480)
	var ref := Image.load_from_file(_arg("ref"))
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(int(ref.get_width() * float(g.get_height()) / ref.get_height()), g.get_height(), Image.INTERPOLATE_NEAREST)
	var p := Image.create(ref.get_width() + g.get_width(), g.get_height(), false, Image.FORMAT_RGBA8)
	p.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	p.blit_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i(ref.get_width(), 0))
	p.save_png(sortie.path_join("planche_ref__chasseresse_face_34_dos_2_4_8m.png"))
	_grille(cap, ["gros_visage_2m", "gros_arc_2m", "gros_carquois_2m", "gros_visage_1m", "gros_arc_1m", "gros_carquois_1m"], 3, 640).save_png(sortie.path_join("planche_gros_plans_visage_arc_carquois_2m_1m.png"))
	_grille(cap, ["an_idle", "an_marche_a", "an_marche_b", "an_course_a", "an_course_b", "an_vise", "an_tir", "an_vise_profil", "an_coup", "an_mort_a", "an_mort_b"], 11, 360).save_png(sortie.path_join("planche_animations_idle_marche_course_vise_tir_coup_mort.png"))
	_grille(cap, ["entree_17h5", "entree_21_torche"], 2, 1280).save_png(sortie.path_join("planche_entree_village_17h30_21h_torche.png"))
	var cote := _arg("cote")
	if cote != "":
		_grille(cote, ["cote_2m_face", "cote_4m_face", "cote_4m_34", "cote_4m_dos", "cote_8m_face"], 5, 560).save_png(sortie.path_join("planche_cote_a_cote_guerrier.png"))
	quit()
