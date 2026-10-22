extends SceneTree
## Planches de la passe VETEMENTS de la chasseresse (captures de outils/poses_chasseresse_vet.txt) :
##   godot --headless --path . --script res://outils/planche_chasseresse_vet.gd -- --avant=<dossier> --apres=<dossier> --sortie=<dossier> --ref=<image>
## (1) ref_avant_apres_2m ; (2) gros_plans_1m (avant | apres par paire) ; (3) distances 4 et 8 m ; (4) animations (apres).
func _arg(n: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n):
			return a.substr(n.length() + 3)
	return ""

func _img(d: String, nom: String, larg: int) -> Image:
	var i := Image.load_from_file(d.path_join(nom + ".png"))
	if i == null:
		push_error("absente " + nom)
		return Image.create(larg, 720, false, Image.FORMAT_RGBA8)
	i.convert(Image.FORMAT_RGBA8)
	return i.get_region(Rect2i((i.get_width() - larg) / 2, 0, larg, i.get_height()))

func _ligne(imgs: Array, ecart := 8) -> Image:
	var w := 0
	var h := 0
	for i: Image in imgs:
		w += i.get_width() + ecart
		h = maxi(h, i.get_height())
	var o := Image.create(w, h, false, Image.FORMAT_RGBA8)
	o.fill(Color(0.05, 0.05, 0.06))
	var x := 0
	for i: Image in imgs:
		o.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(x, 0))
		x += i.get_width() + ecart
	return o

func _pile(imgs: Array, ecart := 8) -> Image:
	var w := 0
	var h := 0
	for i: Image in imgs:
		h += i.get_height() + ecart
		w = maxi(w, i.get_width())
	var o := Image.create(w, h, false, Image.FORMAT_RGBA8)
	o.fill(Color(0.05, 0.05, 0.06))
	var y := 0
	for i: Image in imgs:
		o.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(0, y))
		y += i.get_height() + ecart
	return o

func _init() -> void:
	var av := _arg("avant")
	var ap := _arg("apres")
	var so := _arg("sortie")
	DirAccess.make_dir_recursive_absolute(so)
	var ref := Image.load_from_file(_arg("ref"))
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(int(ref.get_width() * 720.0 / ref.get_height()), 720, Image.INTERPOLATE_NEAREST)
	var v2 := ["v2m_face", "v2m_34", "v2m_dos"]
	var a: Array = [ref]
	for n in v2:
		a.append(_img(av, n, 420))
	for n in v2:
		a.append(_img(ap, n, 420))
	_ligne(a).save_png(so.path_join("1_ref_avant_apres_2m_face_34_dos.png"))
	var gp := ["g1_torse", "g1_torse34", "g1_ceinture", "g1_ceinture34", "g1_jupe", "g1_jupe34", "g1_bottes", "g1_dos", "g1_dos34", "g1_col", "g1_bras"]
	var lignes: Array = []
	for i in range(0, gp.size(), 2):
		var l: Array = []
		for j in range(i, mini(i + 2, gp.size())):
			l.append(_img(av, gp[j], 640))
			l.append(_img(ap, gp[j], 640))
		lignes.append(_ligne(l))
	# deux planches pour rester lisibles
	_pile(lignes.slice(0, 3)).save_png(so.path_join("2a_gros_plans_1m_torse_ceinture_jupe_avant_apres.png"))
	_pile(lignes.slice(3)).save_png(so.path_join("2b_gros_plans_1m_bottes_dos_col_bras_avant_apres.png"))
	var d: Array = []
	for n in ["v4m_face", "v4m_34", "v4m_dos", "v8m_face", "v8m_34", "v8m_dos"]:
		d.append(_img(av, n, 360))
	var d2: Array = []
	for n in ["v4m_face", "v4m_34", "v4m_dos", "v8m_face", "v8m_34", "v8m_dos"]:
		d2.append(_img(ap, n, 360))
	_pile([_ligne(d), _ligne(d2)]).save_png(so.path_join("3_4m_8m_avant_puis_apres.png"))
	var an: Array = []
	for n in ["an_idle", "an_marche_a", "an_marche_b", "an_course_a", "an_course_b", "an_vise", "an_tir", "an_coup", "an_mort_a", "an_mort_b"]:
		an.append(_img(ap, n, 360))
	_pile([_ligne(an.slice(0, 5)), _ligne(an.slice(5))]).save_png(so.path_join("4_animations_apres.png"))
	quit()
