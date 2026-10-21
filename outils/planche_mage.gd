extends SceneTree
## Planches du Mage nordique à partir des captures en jeu (outils/poses_mage.txt + poses_mage_famille.txt, 1280x720) :
##   godot --headless --path . --script res://outils/planche_mage.gd -- --captures=<dossier> --sortie=<dossier> --ref=<recadrage du mage de la référence>
var cap := ""
var sortie := ""

func _arg(n: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n):
			return a.substr(n.length() + 3)
	return ""

func _img(nom: String) -> Image:
	var i := Image.load_from_file(cap.path_join(nom + ".png"))
	if i == null:
		push_error("capture absente " + nom)
		return Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	i.convert(Image.FORMAT_RGBA8)
	return i

func _bande(img: Image, larg: int) -> Image:
	return img.get_region(Rect2i((img.get_width() - larg) / 2, 0, larg, img.get_height()))

func _grille(noms: Array, colonnes: int, larg: int) -> Image:
	var lignes := ceili(float(noms.size()) / colonnes)
	var out := Image.create(larg * colonnes, 720 * lignes, false, Image.FORMAT_RGBA8)
	for i in noms.size():
		out.blit_rect(_bande(_img(noms[i]), larg), Rect2i(0, 0, larg, 720), Vector2i((i % colonnes) * larg, (i / colonnes) * 720))
	return out

func _init() -> void:
	cap = _arg("captures")
	sortie = _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	# (a) référence | grille 3 x 3 (face, 3/4, dos x 2, 4, 8 m) à l'entrée du village, 17h30
	var g := _grille(["p17_2m_face", "p17_2m_34", "p17_2m_dos", "p17_4m_face", "p17_4m_34", "p17_4m_dos", "p17_8m_face", "p17_8m_34", "p17_8m_dos"], 3, 480)
	var ref := Image.load_from_file(_arg("ref"))
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(int(ref.get_width() * float(g.get_height()) / ref.get_height()), g.get_height(), Image.INTERPOLATE_NEAREST)
	var p := Image.create(ref.get_width() + g.get_width(), g.get_height(), false, Image.FORMAT_RGBA8)
	p.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	p.blit_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i(ref.get_width(), 0))
	p.save_png(sortie.path_join("a_planche_ref__mage_face_34_dos_2_4_8m_17h30.png"))
	# (b) gros plans : visage (capuche, barbe), bâton (cristal, griffes, runes), torse (amulette, bande brodée) à 2 m et 1 m
	_grille(["gros_visage_2m", "gros_baton_2m", "gros_torse_2m", "gros_visage_1m", "gros_baton_1m", "gros_torse_1m"], 3, 640).save_png(sortie.path_join("b_planche_gros_plans_visage_baton_torse_2m_1m.png"))
	# (c) animations (3/4 côté bâton) + marche et course de profil (robe / jambes)
	_grille(["an_idle", "an_marche_a", "an_marche_b", "an_course_a", "an_course_b", "an_sort_a", "an_sort_b", "an_sort_c", "an_coup", "an_mort_a", "an_mort_b"], 11, 360).save_png(sortie.path_join("c_planche_animations_idle_marche_course_sort_coup_mort.png"))
	_grille(["pr_marche_a", "pr_marche_b", "pr_marche_c", "pr_marche_d", "pr_course_a", "pr_course_b"], 6, 420).save_png(sortie.path_join("c_planche_profil_marche_x4_course_x2_robe_jambes.png"))
	# (d) famille : mage + guerrier côte à côte
	_grille(["fam_2m_face", "fam_4m_face", "fam_4m_34", "fam_8m_face"], 2, 1280).save_png(sortie.path_join("d_planche_famille_mage_guerrier_2_4_8m.png"))
	# ambiances : entrée 17h30 / 21 h, nuit 3 m (cristal sans halo), sort de nuit
	_grille(["entree_17h5", "entree_21"], 2, 1280).save_png(sortie.path_join("planche_entree_village_17h30_21h.png"))
	_grille(["p21_3m_34", "p21_3m_sort"], 2, 640).save_png(sortie.path_join("planche_nuit_3m_idle_sort.png"))
	quit()
