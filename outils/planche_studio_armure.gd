extends SceneTree
## Planche « studio » d'un ensemble : colonne de la planche de référence (rognée) | studio face | studio 3/4 ligne 1 ; gros plans torse,
## tête, jambes et cuirasse posée ligne 2 (captures de outils/captures_armures_portees.gd --studio).
##   godot --headless --path . --script res://outils/planche_studio_armure.gd -- --dossier=<captures> --reference=<png> --crop=x,y,w,h --familles=rubis,saphir
## Écrit <dossier>/studio_<famille>.png.
func _init() -> void:
	var dossier := ""
	var ref := ""
	var crop := Rect2i(590, 140, 290, 580)
	var familles: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="): dossier = a.substr(10)
		elif a.begins_with("--reference="): ref = a.substr(12)
		elif a.begins_with("--crop="):
			var v := a.substr(7).split(",")
			crop = Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3]))
		elif a.begins_with("--familles="): familles = a.substr(11).split(",")
	var r := Image.load_from_file(ref)
	r.convert(Image.FORMAT_RGBA8)
	var c := r.get_region(crop)
	c.resize(int(crop.size.x * 540.0 / crop.size.y), 540, Image.INTERPOLATE_LANCZOS)
	for f in familles:
		var l1: Array = [c]
		for n in ["studio", "studio_tq"]:
			l1.append(Image.load_from_file(dossier.path_join("%s_%s.png" % [f, n])))
		var l2: Array = []
		for n in ["gp_torse", "gp_tete", "gp_jambes", "sol_cuirasse"]:
			l2.append(Image.load_from_file(dossier.path_join("%s_%s.png" % [f, n])))
		var w1 := 0
		for i: Image in l1: w1 += i.get_width()
		var w2 := 0
		for i: Image in l2: w2 += i.get_width()
		var p := Image.create(maxi(w1, w2), 1080, false, Image.FORMAT_RGBA8)
		p.fill(Color(0.07, 0.07, 0.09))
		var x := 0
		for i: Image in l1:
			i.convert(Image.FORMAT_RGBA8)
			p.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(x, 0)); x += i.get_width()
		x = 0
		for i: Image in l2:
			i.convert(Image.FORMAT_RGBA8)
			p.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(x, 540)); x += i.get_width()
		p.save_png(dossier.path_join("studio_%s.png" % f))
		print("STUDIO ", f, " ", p.get_size())
	quit()
