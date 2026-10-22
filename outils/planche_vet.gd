extends SceneTree
## Planches de la passe « vetements » du Mage (headless) :
##   godot --headless --path . --script res://outils/planche_vet.gd -- --avant=<dossier> --apres=<dossier> --sortie=<dossier> --ref=<png>
## (1) ref | avant | apres (2 m face, 3/4, dos) ; (2) gros plans avant / apres ; (3) 4 m et 8 m ; (4) animations.
var avant := ""
var apres := ""
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
		return Image.create(640, 360, false, Image.FORMAT_RGBA8)
	i.convert(Image.FORMAT_RGBA8)
	return i

## Bande centrale de largeur `larg` (en pixels de la capture), pleine hauteur.
func _bande(i: Image, larg: int) -> Image:
	var l := mini(larg, i.get_width())
	return i.get_region(Rect2i((i.get_width() - l) / 2, 0, l, i.get_height()))

func _ligne(imgs: Array, h: int) -> Image:
	var larg := 0
	var res := []
	for i: Image in imgs:
		var c := i.duplicate() as Image
		c.resize(int(c.get_width() * float(h) / c.get_height()), h, Image.INTERPOLATE_NEAREST)
		res.append(c)
		larg += c.get_width()
	var out := Image.create(larg, h, false, Image.FORMAT_RGBA8)
	var x := 0
	for c: Image in res:
		out.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(x, 0))
		x += c.get_width()
	return out

func _pile(lignes: Array) -> Image:
	var larg := 0
	var haut := 0
	for l: Image in lignes:
		larg = maxi(larg, l.get_width())
		haut += l.get_height()
	var out := Image.create(larg, haut, false, Image.FORMAT_RGBA8)
	var y := 0
	for l: Image in lignes:
		out.blit_rect(l, Rect2i(Vector2i.ZERO, l.get_size()), Vector2i(0, y))
		y += l.get_height()
	return out

func _init() -> void:
	avant = _arg("avant")
	apres = _arg("apres")
	sortie = _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var ref := Image.load_from_file(_arg("ref"))
	ref.convert(Image.FORMAT_RGBA8)
	# (1) ref | avant | apres, 2 m
	var a1 := []
	var p1 := []
	for n in ["v_2m_face", "v_2m_34", "v_2m_dos"]:
		a1.append(_bande(_img(avant, n), 330))
		p1.append(_bande(_img(apres, n), 330))
	var l1 := [ref] + a1 + p1
	_ligne(l1, 720).save_png(sortie.path_join("1_ref_avant_apres_2m.png"))
	# (2) gros plans a 1 m : une ligne par vue, avant | apres
	var noms2 := ["g_torse", "g_ceinture", "g_bas", "g_bottes", "g_dos"]
	var lignes := []
	for n in noms2:
		lignes.append(_ligne([_bande(_img(avant, n), 480), _bande(_img(apres, n), 480)], 360))
	_pile(lignes.slice(0, 3)).save_png(sortie.path_join("2a_gros_plans_torse_ceinture_bas.png"))
	_pile(lignes.slice(3)).save_png(sortie.path_join("2b_gros_plans_bottes_dos.png"))
	# (3) 4 m et 8 m
	var l3 := _ligne([_bande(_img(avant, "v_4m_34"), 360), _bande(_img(apres, "v_4m_34"), 360), _bande(_img(avant, "v_8m_face"), 360), _bande(_img(apres, "v_8m_face"), 360)], 540)
	l3.save_png(sortie.path_join("3_4m_8m_avant_apres.png"))
	# (4) animations
	var noms4 := ["a_marche", "a_course1", "a_course2", "a_sprint2", "a_sort", "a_mort"]
	var la := []
	var lp := []
	for n in noms4:
		la.append(_bande(_img(avant, n), 300))
		lp.append(_bande(_img(apres, n), 300))
	_pile([_ligne(la, 360), _ligne(lp, 360)]).save_png(sortie.path_join("4_animations_avant_apres.png"))
	quit()
