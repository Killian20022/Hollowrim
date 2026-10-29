extends SceneTree
## Avant / après des os de torsion des avant-bras (TorsionAvantBras) : chaque instant est rendu DEUX fois, même pose,
## modificateur coupé (« avant » : la torsion retombe sur lowerarm / hand comme dans l'ancien rig) puis actif (« après »).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_torsion_avant_bras.gd -- --sortie=<dossier> \
##       [--seq=repos,estoc,puissante,revers,zone,jet]
##   planche <sortie>/<seq>.png : une ligne par instant ; colonnes = gros plan avant | gros plan après | vue de jeu avant |
##   vue de jeu après. Gros plan : caméra qui suit l'avant-bras (côté extérieur), même cadrage pour les deux colonnes.
##   Lignes MESURE : torsion totale (main / charnière du coude) et torsion que portait lowerarm, en degrés.

const SCENE_COMBAT := preload("res://scenes/test_combat.tscn")
const SCENE_MAGIE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0
const W := 480
const H := 270

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sq: Skeleton3D
var sortie := ""
var l: Label
var cam_gp: Camera3D


func _init() -> void:
	_go.call_deferred()


func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut


func _monter(scene: PackedScene) -> void:
	if s != null:
		s.queue_free()
		await process_frame
	s = scene.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	sq = mains.get("_sq")
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false   # HUD masqué : on regarde les bras
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)
	cam_gp = Camera3D.new()
	cam_gp.fov = 38.0
	cam_gp.near = 0.01
	s.add_child(cam_gp)
	mains.pas_manuel = true


func _globale(i: int) -> Transform3D:
	var t := Transform3D()
	while i >= 0:
		t = sq.get_bone_pose(i) * t
		i = sq.get_bone_parent(i)
	return sq.global_transform * t


## Caméra de gros plan sur l'avant-bras `c` : au-dessus et côté extérieur, perpendiculaire à l'avant-bras.
func _cadrer(c: String) -> void:
	var co := _globale(sq.find_bone("lowerarm_" + c)).origin
	var po := _globale(sq.find_bone("hand_" + c)).origin
	var mi := co.lerp(po, 0.5)
	var b: Basis = j.camera.global_transform.basis
	var cote := 1.0 if c == "r" else -1.0
	var a := (po - co).normalized()
	var d := b.y + b.x * cote * 0.7 + b.z * 0.2
	d = (d - a * a.dot(d)).normalized()   # perpendiculaire à l'avant-bras : on le voit sur toute sa longueur
	var pos := mi + d * 0.5
	cam_gp.global_transform = Transform3D(Basis.looking_at(mi - pos, b.y), pos)


func _image() -> Image:
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	im.resize(W, H, Image.INTERPOLATE_BILINEAR)
	return im


## Rend la pose courante : [gros plan avant, gros plan après, jeu avant, jeu après]. Le temps ne bouge pas (pas manuel).
func _quatre(c: String, legende: String) -> Array:
	var out := []
	var tb: TorsionAvantBras = mains.torsion_bras
	for gros in [true, false]:
		for actif in [false, true]:
			tb.active = actif
			# re-marque le squelette modifié (pas d'animation qui avance)
			var i := sq.find_bone("clavicle_r")
			sq.set_bone_pose_rotation(i, sq.get_bone_pose_rotation(i))
			if gros:
				_cadrer(c)
				cam_gp.current = true
			else:
				j.camera.current = true
			l.text = "%s\n%s %s" % [legende, "AVANT (sans os de torsion)" if not actif else "APRES (os de torsion)", "gros plan" if gros else "vue de jeu"]
			await process_frame
			await process_frame
			out.append(await _image())
	tb.active = true
	return out


func _planche(nom: String, lignes: Array) -> void:
	var p := Image.create(W * 4, H * lignes.size(), false, Image.FORMAT_RGBA8)
	for r in lignes.size():
		for k in 4:
			p.blit_rect(lignes[r][k], Rect2i(0, 0, W, H), Vector2i(k * W, r * H))
	var f := sortie.path_join(nom + ".png")
	p.save_png(f)
	print("PLANCHE ", f)


func _mesure(nom: String, n: int, c: String) -> String:
	var tb: TorsionAvantBras = mains.torsion_bras
	# relevé du modificateur (pose finale, après animation et IK)
	var m := "torsion totale %+.0f deg (coude avant %+.0f)" % [float(tb.torsion[c]), float(tb.torsion_coude[c])]
	print("MESURE %s #%02d %s %s" % [nom, n, c, m])
	return m


## Coup d'épée pas à pas (scène de combat) ; `vues` = indices d'images à rendre.
func _coup(nom: String, actions: Dictionary, duree: float, vues: Array, geste_force := "") -> void:
	s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.7), 0.0)
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	for i in 50:
		mains.avancer(DT)
	var lignes := []
	var n := roundi(duree / DT)
	for i in n:
		if actions.has(i):
			for a in actions[i]:
				if a == "appuyer":
					mains.entrees.appuyer()
				elif a == "relacher":
					mains.entrees.relacher()
		mains.avancer(DT)
		if i == 1 and geste_force != "":
			mains._geste_nom = geste_force
			mains._preparer_geste(false)
		if i in vues:
			await process_frame
			var m := _mesure(nom, i, "r")
			lignes.append(await _quatre("r", "%s  image %d (%d ms)  %s" % [nom, i, roundi(i * DT * 1000.0), m]))
	await _planche(nom, lignes)


## Geste de magie pas à pas (scène de magie) : [sort gauche, sort droite], appui / relâche (images), main suivie.
func _sort(nom: String, gauche: String, droite: String, appui: int, relache: int, duree: float, vues: Array, c: String) -> void:
	var m: MainSort = s.magie
	m.equiper("droite", droite)
	m.equiper("gauche", gauche)
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	for i in 40:
		mains.avancer(DT)
	var lignes := []
	var n := roundi(duree / DT)
	var main := "gauche" if c == "l" else "droite"
	for i in n:
		s.joueur.mana = s.joueur.mana_max
		m.recharges.clear()
		if i == appui:
			m.appuyer(main)
		if i == relache:
			m.relacher(main)
		mains.avancer(DT)
		if i in vues:
			await process_frame
			var me := _mesure(nom, i, c)
			lignes.append(await _quatre(c, "%s  image %d (%d ms)  %s" % [nom, i, roundi(i * DT * 1000.0), me]))
	await _planche(nom, lignes)


func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/torsion_avant_bras"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	var seqs := Array(_arg("seq", "repos,estoc,puissante,revers,zone,jet").split(",", false))
	var combat := seqs.filter(func(q): return q in ["repos", "estoc", "puissante", "revers", "horizontale"])
	var magie := seqs.filter(func(q): return q in ["zone", "jet", "lance"])
	if not combat.is_empty():
		await _monter(SCENE_COMBAT)
		for q in combat:
			match q:
				"repos":
					await _coup("repos", {}, 0.1, [3])
				"estoc", "revers", "horizontale":
					var g: String = {"horizontale": "horizontale", "revers": "diag_gd", "estoc": "estoc"}[q]
					await _coup(q, {0: ["appuyer"], 2: ["relacher"]}, 0.62, [8, 14, 18, 22, 27, 33], g)
				"puissante":
					await _coup("puissante", {0: ["appuyer"], 52: ["relacher"]}, 1.6, [30, 55, 62, 68, 75, 90])
	if not magie.is_empty():
		await _monter(SCENE_MAGIE)
		for q in magie:
			match q:
				"zone":
					await _sort("zone", "explosion_obscure", "epee", 10, 88, 2.4, [20, 50, 80, 92, 100, 115], "l")
				"jet":
					await _sort("jet", "jet_flammes", "epee", 10, 140, 2.8, [16, 30, 60, 120, 146, 160], "l")
				"lance":
					await _sort("lance", "eclat_glace", "epee", 10, 15, 1.4, [14, 20, 26, 34, 44, 60], "l")
	quit()
