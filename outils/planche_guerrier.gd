extends SceneTree
## Planches du Guerrier pilote à partir des captures en jeu (outils/poses_guerrier.txt, sorties x2 de 1280x720) :
##   godot --headless --path . --script res://outils/planche_guerrier.gd -- --captures=<dossier> --sortie=<dossier> --ref=<persos_b.png>
## planche_ref_draugr__guerrier_2_4_8m.png : référence | grille 3 x 3 (face, 3/4, dos x 2, 4, 8 m), bande centrale de chaque capture
## planche_animations.png, planche_scintillement.png (+ mesure : part des pixels qui changent entre vues décalées de 2 cm),
## planche_casque.png, planche_ambiances.png.
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
	# 1. référence | grille
	var g := _grille(["p17_2m_face", "p17_2m_34", "p17_2m_dos", "p17_4m_face", "p17_4m_34", "p17_4m_dos", "p17_8m_face", "p17_8m_34", "p17_8m_dos"], 3, 480)
	var ref := Image.load_from_file(_arg("ref"))
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(int(ref.get_width() * float(g.get_height()) / ref.get_height()), g.get_height(), Image.INTERPOLATE_NEAREST)
	# --passe1=<ancienne planche ref | grille> : la grille de la passe 1 (moitié droite) s'intercale (référence | passe 1 | passe 2)
	var p1 := Image.new()
	if _arg("passe1") != "":
		var anc := Image.load_from_file(_arg("passe1"))
		anc.convert(Image.FORMAT_RGBA8)
		p1 = anc.get_region(Rect2i(anc.get_width() - g.get_width(), 0, g.get_width(), g.get_height()))
	var larg_p1 := p1.get_width() if not p1.is_empty() else 0
	var p := Image.create(ref.get_width() + larg_p1 + g.get_width(), g.get_height(), false, Image.FORMAT_RGBA8)
	p.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	if larg_p1 > 0:
		p.blit_rect(p1, Rect2i(Vector2i.ZERO, p1.get_size()), Vector2i(ref.get_width(), 0))
	p.blit_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i(ref.get_width() + larg_p1, 0))
	# --noms=<colonne précédente>,<colonne actuelle> (défaut passe1,passe2) : nom du fichier de la planche à 3 colonnes
	var noms := (_arg("noms") if _arg("noms") != "" else "passe1,passe2").split(",")
	p.save_png(sortie.path_join(("planche_ref_draugr__%s__%s_face_34_dos_2_4_8m.png" % [noms[0], noms[1]]) if larg_p1 > 0 else "planche_ref_draugr__guerrier_face_34_dos_2_4_8m.png"))
	# gros plans (passe 2) : visage et bouclier à 2 m (bande centrale) et à 1-1,3 m
	if FileAccess.file_exists(cap.path_join("gros_visage_2m.png")):
		if FileAccess.file_exists(cap.path_join("nuque_1m.png")):
			# finition : + profil et nuque à 1 m (mèches détachées)
			_grille(["gros_visage_2m", "gros_bouclier_2m", "gros_torse_2m", "profil_1m", "gros_visage_1m", "gros_bouclier_1m", "gros_torse_1m", "nuque_1m"], 4, 640).save_png(sortie.path_join("planche_gros_plans_visage_bouclier_torse_profil_nuque_2m_1m.png"))
		else:
			_grille(["gros_visage_2m", "gros_bouclier_2m", "gros_torse_2m", "gros_visage_1m", "gros_bouclier_1m", "gros_torse_1m"], 3, 640).save_png(sortie.path_join("planche_gros_plans_visage_bouclier_torse_2m_1m.png"))
		_grille(["p17_8m_face", "p17_8m_face_idle"], 2, 640).save_png(sortie.path_join("planche_silhouette_8m_garde_idle.png"))
	# 2. animations
	_grille(["an_idle", "an_garde", "an_marche_a", "an_marche_b", "an_course_a", "an_course_b", "an_attaque_a", "an_attaque_b", "an_coup", "an_mort_a", "an_mort_b"], 11, 360).save_png(sortie.path_join("planche_animations_idle_garde_marche_course_attaque_coup_mort.png"))
	# 3. ambiances
	_grille(["entree_17h5", "entree_21", "entree_21_torche"], 3, 1280).save_png(sortie.path_join("planche_entree_village_17h30_21h_torche.png"))
	_grille(["p21_3m_34", "p21_3m_34_torche"], 2, 640).save_png(sortie.path_join("planche_nuit_3m_sans_avec_torche.png"))
	# 4. casque
	if FileAccess.file_exists(cap.path_join("c17_2m_face.png")):
		_grille(["p17_2m_face", "c17_2m_face", "p17_2m_34", "c17_2m_34"], 4, 480).save_png(sortie.path_join("planche_sans_avec_casque_2m.png"))
	# finition : planche « avec casque » (2 m face / 3/4 / dos, 4 m et 8 m 3/4, gros plan visage et nuque à 1 m)
	if FileAccess.file_exists(cap.path_join("c_gros_visage_1m.png")):
		_grille(["c17_2m_face", "c17_2m_34", "c17_2m_dos", "c17_4m_34", "c17_8m_34", "c_gros_visage_1m", "c_nuque_1m", "c21_3m_34_torche"], 4, 480).save_png(sortie.path_join("planche_avec_casque_2_4_8m_gros_plans_nuit.png"))
	# 5. scintillement : bande centrale 200x400 (perso), pixels qui changent de plus de 24/255 d'une vue à la suivante
	var s := _grille(["scint_0", "scint_1", "scint_2"], 3, 480)
	s.save_png(sortie.path_join("planche_scintillement_camera_2cm.png"))
	var txt := ""
	for k in 2:
		var a := _img("scint_%d" % k).get_region(Rect2i(540, 160, 200, 400))
		var b := _img("scint_%d" % (k + 1)).get_region(Rect2i(540, 160, 200, 400))
		var n := 0
		for y in 400:
			for x in 200:
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 24.0 / 255.0:
					n += 1
		txt += "scint_%d -> scint_%d : %.1f %% des pixels de la bande du personnage changent (> 24/255)\n" % [k, k + 1, 100.0 * n / 80000.0]
	print(txt)
	var f := FileAccess.open(sortie.path_join("scintillement.txt"), FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	quit()
