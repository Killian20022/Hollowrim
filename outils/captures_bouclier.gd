extends SceneTree
## Planches du bouclier et de la main gauche (scenes/test_magie.tscn ; FENÊTRE via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_bouclier.gd -- --nouvelle --sortie=<dossier> [--cas=nom1,nom2]
## Une image par cas (<sortie>/<nn>_<cas>.png), une planche (<sortie>/planche_bouclier.png, 3 colonnes, ordre du rapport)
## et un rapport de mesures (<sortie>/mesures.txt) :
##   - couverture de l'objet de la main gauche (bouclier, torche) : pixels qui changent quand on le masque, en % de l'écran
##     et en % du tiers central (cadre 1/3 x 1/3 au centre) ;
##   - main gauche : cadre écran des os (avant-bras, main, bouts des doigts), part du tiers central couverte ;
##   - traversées : distance mini caméra → main gauche (< 0,10 m = la main traverse la vue), et main gauche → bras droit /
##     épée (< 0,06 m = les mains se traversent).

const SCENE := preload("res://scenes/test_magie.tscn")

var s: Node3D
var m: MainSort
var mains: Node3D
var sortie := ""
var _n := 0
var _vignettes: Array[Image] = []
var _lignes: PackedStringArray = []
var _os := {}   # nom -> BoneAttachment3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _attendre(t: float) -> void:
	await create_timer(t).timeout

func _go() -> void:
	sortie = _arg("sortie", "user://captures_bouclier")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	s.options = {"draugr": "fige", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	m = s.magie
	mains = s.joueur.mains
	if s.get("titre") != null:
		s.titre.visible = false
	var sq: Skeleton3D = mains._sq
	for nom in ["lowerarm_l", "hand_l", "middle_03_l", "index_03_l", "pinky_03_l", "thumb_03_l", "lowerarm_r", "hand_r"]:
		var b := BoneAttachment3D.new()
		b.bone_name = nom
		sq.add_child(b)
		_os[nom] = b
	await _cas()
	_planche()
	var f := FileAccess.open(sortie.path_join("mesures.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lignes) + "\n")
	f.close()
	quit(0)

## Cas : [nom, gauche, droite, action, attente avant capture (s)].
func _cas() -> void:
	var cas := [
		["torche_epee_repos", "torche", "epee", "", 0.0],
		["vide_epee_repos", "vide", "epee", "", 0.0],
		["bouclier_repos", "bouclier", "epee", "", 0.0],
		["bouclier_garde", "bouclier", "epee", "garde", 0.45],
		["bouclier_bloc", "bouclier", "epee", "bloc", 0.07],
		["bouclier_parade", "bouclier", "epee", "parade", 0.09],
		["bouclier_brisee", "bouclier", "epee", "brisee", 0.14],
		["bouclier_attaque", "bouclier", "epee", "attaque", 0.16],
		["feu_repos", "jet_flammes", "epee", "", 0.0],
		["feu_incante", "jet_flammes", "epee", "gauche", 0.12],
		["feu_canalise", "jet_flammes", "epee", "gauche", 0.6],
		["boule_charge", "boule_feu", "epee", "gauche", 0.7],
		["glace_lance", "eclat_glace", "epee", "tape", 0.1],
		["glace_repos", "eclat_glace", "epee", "", 0.0],
		["electricite_repos", "arc_electrique", "epee", "", 0.0],
		["tenebres_repos", "trait_ombre", "epee", "", 0.0],
		["feu_epee_attaque", "jet_flammes", "epee", "attaque", 0.16],
		["bouclier_sort_droite", "bouclier", "arc_electrique", "", 0.0],
		["modele_face_dos", "vide", "epee", "vitrine", 0.1],
	]
	var filtre := _arg("cas")
	for c in cas:
		if filtre != "" and not (String(c[0]) in filtre.split(",")):
			continue
		m.equiper("droite", c[2])
		m.equiper("gauche", c[1])
		s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
		var j: CharacterBody3D = s.joueur
		j.mana = 100.0
		j.vigueur = j.vigueur_max
		mains.defense = DefenseJoueur.new()
		m.recharges.clear()
		await _attendre(0.9)
		var devant := j.global_position + Vector3(0, 0, -1.5)
		match String(c[3]):
			"gauche":
				m.appuyer("gauche")
			"tape":
				m.appuyer("gauche")
				await _attendre(0.05)
				m.relacher("gauche")
			"garde":
				mains.entrees.forcer_garde(3.0)
			"bloc":
				mains.entrees.forcer_garde(3.0)
				await _attendre(0.4)
				j.recevoir_coup(12.0, devant)
			"parade":
				mains.entrees.forcer_garde(3.0)
				await _attendre(0.05)
				j.recevoir_coup(12.0, devant)
			"brisee":
				mains.entrees.forcer_garde(3.0)
				await _attendre(0.4)
				j.vigueur = 1.0
				j.recevoir_coup(30.0, devant)
			"vitrine":
				# le modèle seul, face peinte et dos, posé devant la caméra (la peinture ne se voit pas en vue FPS : on tient
				# le bouclier par derrière)
				for k in 2:
					var v: Node3D = (load("res://assets/modeles/armes/bouclier_nordique.glb") as PackedScene).instantiate()
					BouclierNordique.habiller(v)
					s.add_child(v)
					var ct: Transform3D = j.camera.global_transform
					var vers_cam := ct.basis.z
					var cote := ct.basis.x * (-0.42 if k == 0 else 0.42)
					var nrm := vers_cam if k == 0 else -vers_cam
					v.global_transform = Transform3D(Basis(nrm, ct.basis.y, nrm.cross(ct.basis.y)), ct.origin - vers_cam * 1.25 + cote)
					v.set_meta("vitrine", true)
			"attaque":
				mains.entrees.appuyer()
				await _attendre(0.05)
				mains.entrees.relacher()
		await _attendre(c[4])
		await _capturer(String(c[0]), String(c[3]) == "")
		mains.entrees.forcer_garde(0.0)
		m.relacher("gauche")
		m.relacher("droite")
		await _attendre(0.7)

func _capturer(nom: String, mesurer_objet: bool) -> void:
	_n += 1
	var img := await _image()
	img.save_png(sortie.path_join("%02d_%s.png" % [_n, nom]))
	print("CAPTURE ", nom)
	var v := img.duplicate() as Image
	v.resize(480, 270, Image.INTERPOLATE_NEAREST)
	_vignettes.append(v)
	var ligne := "%02d %-22s" % [_n, nom]
	# couverture de l'objet de la main gauche (au repos seulement : l'image suivante doit être la même pose)
	if mesurer_objet:
		var objets: Array = []
		for o in [mains.get("_modele_gauche"), m.get("_bouclier")]:
			if is_instance_valid(o) and (o as Node3D).visible and not objets.has(o):
				objets.append(o)
		if mains.porte_torche.visible:
			objets.append(mains.porte_torche)
		if not objets.is_empty():
			var couches := {}
			for o: Node in objets:
				for g in o.find_children("*", "VisualInstance3D", true, false):
					couches[g] = g.layers
					g.layers = 0
			var sans := await _image()
			for g in couches:
				g.layers = couches[g]
			var cov := _couverture(img, sans)
			ligne += "  objet G : %4.1f %% écran, %4.1f %% du tiers central" % [cov.x * 100.0, cov.y * 100.0]
	ligne += "  " + _mesures_main()
	_lignes.append(ligne)
	print(ligne)

## Part des pixels qui changent (écran entier, tiers central).
func _couverture(a: Image, b: Image) -> Vector2:
	var w := a.get_width()
	var h := a.get_height()
	var n := 0
	var nc := 0
	var tc := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var diff := absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06
			var centre := x > w / 3 and x < w * 2 / 3 and y > h / 3 and y < h * 2 / 3
			if centre:
				tc += 1
			if diff:
				n += 1
				if centre:
					nc += 1
	return Vector2(float(n) / float((w / 2) * (h / 2)), float(nc) / maxf(tc, 1))

func _mesures_main() -> String:
	var cam: Camera3D = s.joueur.camera
	var vp := root.get_viewport().get_visible_rect().size
	var pts_g: Array[Vector3] = []
	for nom in ["lowerarm_l", "hand_l", "middle_03_l", "index_03_l", "pinky_03_l", "thumb_03_l"]:
		pts_g.append((_os[nom] as Node3D).global_position)
	var mini := INF
	var r := Rect2()
	var premier := true
	for p in pts_g:
		mini = minf(mini, cam.global_position.distance_to(p))
		if cam.is_position_behind(p):
			continue
		var e := cam.unproject_position(p) / vp
		if premier:
			r = Rect2(e, Vector2.ZERO)
			premier = false
		else:
			r = r.expand(e)
	var centre := Rect2(Vector2(1.0 / 3.0, 1.0 / 3.0), Vector2(1.0 / 3.0, 1.0 / 3.0))
	var inter := r.intersection(centre)
	var part := inter.get_area() / centre.get_area() if r.intersects(centre) else 0.0
	# main gauche ↔ bras droit / épée
	var droite: Array[Vector3] = [(_os["hand_r"] as Node3D).global_position, (_os["lowerarm_r"] as Node3D).global_position]
	if is_instance_valid(mains._modele_arme_d) and mains._modele_arme_d.visible:
		var a: Transform3D = mains._modele_arme_d.global_transform
		for k in 6:
			droite.append(a * mains._garde_lame.lerp(mains._pointe_lame, k / 5.0))
	var d_bras := INF
	for p in pts_g.slice(1):
		for q in droite:
			d_bras = minf(d_bras, p.distance_to(q))
	return "main G : cadre x %.2f-%.2f y %.2f-%.2f, tiers central %4.1f %%, caméra→main %.2f m, main G→bras D/épée %.2f m" % [r.position.x, r.end.x, r.position.y, r.end.y, part * 100.0, mini, d_bras]

func _planche() -> void:
	var col := 3
	var lig := ceili(_vignettes.size() / float(col))
	var p := Image.create(480 * col + 4 * (col - 1), 270 * lig + 4 * (lig - 1), false, Image.FORMAT_RGBA8)
	p.fill(Color(0.05, 0.05, 0.06))
	for i in _vignettes.size():
		var v: Image = _vignettes[i]
		v.convert(Image.FORMAT_RGBA8)
		p.blit_rect(v, Rect2i(0, 0, 480, 270), Vector2i((i % col) * 484, (i / col) * 274))
	p.save_png(sortie.path_join("planche_bouclier.png"))
	print("PLANCHE ", sortie.path_join("planche_bouclier.png"))
