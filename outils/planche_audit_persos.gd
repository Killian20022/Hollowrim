extends SceneTree
## Planches de comparaison de l'audit des personnages (refonte/persos_audit) : référence pixel art | rendu actuel (640x360 natif, agrandi
## en plus proche voisin). Aucune police : l'ordre des panneaux est donné dans le nom et dans docs/AUDIT_PERSONNAGES.md.
##   godot --headless --path . --script res://outils/planche_audit_persos.gd -- --ref=<dossier références> --audit=<dossier audit>
func _init() -> void:
	var ref := _arg("ref", "")
	var audit := _arg("audit", "")
	# 1) référence draugr (persos_b) | draugr guerrier en jeu, crypte, 2 m, torche | galerie, crypte 2 m face | galerie, jour 2 m face
	var a := _hauteur(_lire(ref + "/personnages/persos_b.png"), 720)
	var b := _rogner_x2(_lire(audit + "/jeu/cr_ossuaire_2_2m_az0_torche.png"), Rect2i(200, 0, 240, 360))
	var g := _lire(audit + "/galerie/draugr_guerrier_planche.png")
	var c := _rogner_x2(g, Rect2i(640 * 0 + 200, 360 * 2, 240, 360))
	var d := _rogner_x2(g, Rect2i(200, 0, 240, 360))
	_rangee([a, b, c, d]).save_png(audit + "/planche_ref_draugr__jeu_crypte__galerie_crypte__galerie_jour.png")
	# 2) référence draugr | squelette guerrier en jeu (le seul ennemi au bouclier rond) | draugr sbire en jeu
	var e := _rogner_x2(_lire(audit + "/jeu/cr_ossuaire_sq1_3m_az0_torche.png"), Rect2i(160, 0, 240, 360))
	var f := _rogner_x2(_lire(audit + "/jeu/cr_ossuaire_1_3m_az0_torche.png"), Rect2i(200, 0, 240, 360))
	_rangee([a, e, f]).save_png(audit + "/planche_ref_draugr__squelette_jeu__sbire_jeu.png")
	# 3) référence ambiance village | garde en jeu (2 m) ; référence crypte | draugr en jeu (4 m)
	var r1 := _hauteur(_lire(ref + "/skyrim_32bits_reference.png"), 720)
	var j1 := _x2(_lire(audit + "/jeu/garde_2m_az0.png"))
	var r2 := _hauteur(_lire(ref + "/grottes_cryptes_2.png"), 720)
	var j2 := _x2(_lire(audit + "/jeu/cr_ossuaire_2_4m_az0_torche.png"))
	var haut := _rangee([r1, j1])
	var bas := _rangee([r2, j2])
	var p := Image.create(maxi(haut.get_width(), bas.get_width()), 1440 + 8, false, Image.FORMAT_RGBA8)
	p.fill(Color(0.1, 0.1, 0.1))
	p.blit_rect(haut, Rect2i(Vector2i.ZERO, haut.get_size()), Vector2i(0, 0))
	p.blit_rect(bas, Rect2i(Vector2i.ZERO, bas.get_size()), Vector2i(0, 728))
	p.save_png(audit + "/planche_ref_ambiance__garde_jeu__ref_crypte__draugr_jeu.png")
	# 4) référence ambiance | villageois en jeu à 4 m (garde 3/4 et dos, chasseuse, völva ; forgeron et cheffe masqués par le décor)
	var v := []
	for n in ["garde_4m_az35", "garde_4m_az180", "chasseuse_4m_az35", "volva_4m_az0"]:
		v.append(_rogner_x2(_lire(audit + "/jeu/%s.png" % n), Rect2i(220, 60, 200, 300)))
	_rangee([_hauteur(_lire(ref + "/skyrim_32bits_reference.png"), 600)] + v).save_png(audit + "/planche_ref_ambiance__villageois_4m_x2.png")
	# 5) échelle : garde en jeu à 2 / 4 / 8 m (à 15 m la palissade le cache), 640x360 natif (sans agrandissement)
	var ech := []
	for n in ["garde_2m_az0", "garde_4m_az0", "garde_8m_az0"]:
		if FileAccess.file_exists(audit + "/jeu/%s.png" % n):
			ech.append(_lire(audit + "/jeu/%s.png" % n))
	if not ech.is_empty():
		_rangee(ech).save_png(audit + "/planche_echelle_garde_2_4_8m_natif.png")
	print("PLANCHES OK")
	quit(0)

func _arg(nom: String, defaut: String) -> String:
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--%s=" % nom):
			return x.substr(nom.length() + 3)
	return defaut

func _lire(chemin: String) -> Image:
	var img := Image.load_from_file(chemin)
	if img == null:
		push_error("illisible : " + chemin)
		img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	return img

func _hauteur(img: Image, h: int) -> Image:
	var c := img.duplicate() as Image
	c.resize(int(round(img.get_width() * float(h) / img.get_height())), h, Image.INTERPOLATE_LANCZOS)
	return c

func _x2(img: Image) -> Image:
	var c := img.duplicate() as Image
	c.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return c

func _rogner_x2(img: Image, r: Rect2i) -> Image:
	return _x2(img.get_region(r))

func _rangee(imgs: Array) -> Image:
	var w := 0
	var h := 0
	for i: Image in imgs:
		w += i.get_width() + 8
		h = maxi(h, i.get_height())
	var out := Image.create(w - 8, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.1, 0.1))
	var x := 0
	for i: Image in imgs:
		out.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(x, 0))
		x += i.get_width() + 8
	return out
