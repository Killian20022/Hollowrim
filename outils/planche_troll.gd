extends SceneTree
## Planches du Troll de givre à partir des captures en jeu (outils/poses_troll.txt, sorties x2 de 1280x720) :
##   godot --headless --path . --script res://outils/planche_troll.gd -- --captures=<dossier> --sortie=<dossier> --ref=<image de référence>
##        [--passe1=<planche_ref__troll_... de la passe précédente>] [--noms=passe2__passe3] : ajoute la colonne de la passe précédente
##        (référence | passe N-1 | passe N) et la planche de nuit.
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

func _grille(noms: Array, colonnes: int, larg: int) -> Image:
	var lignes := ceili(float(noms.size()) / colonnes)
	var out := Image.create(larg * colonnes, 720 * lignes, false, Image.FORMAT_RGBA8)
	for i in noms.size():
		var img := _img(noms[i])
		out.blit_rect(img.get_region(Rect2i((img.get_width() - larg) / 2, 0, larg, 720)), Rect2i(0, 0, larg, 720), Vector2i((i % colonnes) * larg, (i / colonnes) * 720))
	return out

func _avec_ref(g: Image) -> Image:
	var ref := Image.load_from_file(_arg("ref"))
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(int(ref.get_width() * float(g.get_height()) / ref.get_height()), g.get_height(), Image.INTERPOLATE_LANCZOS)
	var p := Image.create(ref.get_width() + g.get_width(), g.get_height(), false, Image.FORMAT_RGBA8)
	p.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	p.blit_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i(ref.get_width(), 0))
	return p

func _init() -> void:
	cap = _arg("captures")
	sortie = _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var p1 := _arg("passe1")
	if p1 != "":
		var g2 := _grille(["p17_2m_face", "p17_2m_34", "p17_2m_dos", "p17_4m_face", "p17_4m_34", "p17_4m_dos", "p17_8m_face", "p17_8m_34", "p17_8m_dos"], 3, 560)
		var ancien := Image.load_from_file(p1)
		ancien.convert(Image.FORMAT_RGBA8)
		var g1 := ancien.get_region(Rect2i(ancien.get_width() - g2.get_width(), 0, g2.get_width(), g2.get_height()))
		var bande := Image.create(g1.get_width() + 24 + g2.get_width(), g2.get_height(), false, Image.FORMAT_RGBA8)
		bande.fill(Color(0.9, 0.9, 0.9))
		bande.blit_rect(g1, Rect2i(Vector2i.ZERO, g1.get_size()), Vector2i.ZERO)
		bande.blit_rect(g2, Rect2i(Vector2i.ZERO, g2.get_size()), Vector2i(g1.get_width() + 24, 0))
		var noms := _arg("noms")
		if noms == "":
			noms = "passe1__passe2"
		_avec_ref(bande).save_png(sortie.path_join("planche_ref__%s_face_34_dos_2_4_8m_entree_17h30.png" % noms))
		_grille(["nuit_4m_face", "nuit_4m_34", "nuit_tete_2m"], 3, 1000).save_png(sortie.path_join("planche_nuit_23h_4m_tete_2m.png"))
	_avec_ref(_grille(["p17_2m_face", "p17_2m_34", "p17_2m_dos", "p17_4m_face", "p17_4m_34", "p17_4m_dos", "p17_8m_face", "p17_8m_34", "p17_8m_dos"], 3, 560)).save_png(sortie.path_join("planche_ref__troll_face_34_dos_2_4_8m_entree_17h30.png"))
	_grille(["gros_tete_2m", "gros_main_2m", "gros_tete_1m", "gros_main_1m"], 2, 800).save_png(sortie.path_join("planche_gros_plans_tete_griffes_2m_1m.png"))
	if FileAccess.file_exists(cap.path_join("gros_torse_1m.png")):
		_grille(["gros_torse_2m", "gros_torse_1m", "gros_pied_1m"], 3, 1000).save_png(sortie.path_join("planche_gros_plans_torse_2m_1m_pied_1m.png"))
		_grille(["an_idle", "an_marche_a", "an_marche_b", "an_course_a", "an_course_b", "an_attaque_a", "an_attaque_b", "an_griffes_a", "an_griffes_b", "an_coup", "an_mort_a", "an_mort_b"], 12, 420).save_png(sortie.path_join("planche_animations_idle_marche_course_attaque_griffes_coup_mort.png"))
	else:
		_grille(["an_idle", "an_marche_a", "an_marche_b", "an_course_a", "an_course_b", "an_attaque_a", "an_attaque_b", "an_coup", "an_mort_a", "an_mort_b"], 10, 420).save_png(sortie.path_join("planche_animations_idle_marche_course_attaque_coup_mort.png"))
	_grille(["entree_17h5", "echelle_face", "echelle_34"], 3, 1000).save_png(sortie.path_join("planche_echelle_a_cote_du_guerrier_entree_17h30.png"))
	_avec_ref(_grille(["grotte_lac", "grotte_lac_b", "grotte_caverne"], 3, 1000)).save_png(sortie.path_join("planche_grotte_caverne_du_lac.png"))
	print("PLANCHES : ", sortie)
	quit()
