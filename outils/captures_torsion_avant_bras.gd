extends SceneTree
## Avant / après des os de torsion des avant-bras (TorsionAvantBras) : chaque instant est rendu DEUX fois, même pose,
## modificateur coupé (« avant » : la torsion retombe sur lowerarm / hand comme dans l'ancien rig) puis actif (« après »).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_torsion_avant_bras.gd -- --sortie=<dossier> \
##       [--seq=repos,diagonale,revers,estoc,puissante,zone,jet,lance]
##   planche <sortie>/<seq>.png : une ligne par instant ; colonnes = gros plan avant | gros plan après | vue de jeu avant |
##   vue de jeu après. Gros plan : caméra qui suit l'avant-bras (côté extérieur), même cadrage pour les deux colonnes.
##   Lignes MESURE : torsion totale (main / charnière du coude) et torsion que portait lowerarm, en degrés.
##   Lignes PINCEMENT : rapport minimal rayon posé / rayon au repos de la peau, de la manche, du revers et du gant autour de
##   l'axe de l'avant-bras, au coude et au poignet, avant -> après (1 = rond ; < 1 = pincé, effet « papillote »).

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
var _accroches := {}
var _globales: Array[Transform3D] = []   # pose finale (après tous les modificateurs), relevée à skeleton_updated
var _peaux := []                         # [sommets, os (indices d'os du squelette), poids, pose de liaison par sommet]
var _pincement := {}                     # "avant" / "apres" -> [coude, poignet] (rapport de rayon minimal)


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
	sq.skeleton_updated.connect(_sur_maj)
	_preparer_peaux()
	_accroches.clear()
	for n in ["lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]:
		var a := BoneAttachment3D.new()
		a.bone_name = n
		sq.add_child(a)
		_accroches[n] = a


## Caméra de gros plan sur l'avant-bras `c` : au-dessus et côté extérieur, perpendiculaire à l'avant-bras.
func _cadrer(c: String) -> void:
	# pose FINALE (après IK et modificateurs) : accroches d'os, mises à jour après le squelette
	var co: Vector3 = (_accroches["lowerarm_" + c] as Node3D).global_position
	var po: Vector3 = (_accroches["hand_" + c] as Node3D).global_position
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


func _sur_maj() -> void:
	var n := sq.get_bone_count()
	_globales.resize(n)
	for i in n:
		var p := sq.get_bone_parent(i)
		_globales[i] = (_globales[p] if p >= 0 else Transform3D()) * sq.get_bone_pose(i)


## Peaux VISIBLES suivies pour la mesure de pincement : manche, revers du coude, gants (la sous-couche de peau, cachée, et
## le brassard, rigide, n'y sont pas).
func _preparer_peaux() -> void:
	_peaux.clear()
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		if not (mi.name in ["manches", "gants", "revers_l", "revers_r"]) or mi.skin == null:
			continue
		var a := mi.mesh.surface_get_arrays(0)
		var binds := []
		var poses := []
		for k in mi.skin.get_bind_count():
			var b := mi.skin.get_bind_bone(k)
			if b < 0:
				b = sq.find_bone(mi.skin.get_bind_name(k))
			binds.append(b)
			poses.append(mi.skin.get_bind_pose(k))
		_peaux.append([a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_BONES], a[Mesh.ARRAY_WEIGHTS], binds, poses])


## Rapport minimal (rayon posé / rayon au repos autour de l'axe coude → poignet) des sommets de l'avant-bras `c`, au coude
## (côté avant-bras, avant le brassard : s ∈ [0,02 ; 0,15]) et au poignet (s ∈ [0,8 ; 1]) : 1 = rond, < 1 = pincé (torsion concentrée, « papillote »).
func _pincer(c: String) -> Array:
	var il := sq.find_bone("lowerarm_" + c)
	var ih := sq.find_bone("hand_" + c)
	var e0 := sq.get_bone_global_rest(il).origin
	var w0 := sq.get_bone_global_rest(ih).origin
	var e1 := _globales[il].origin
	var w1 := _globales[ih].origin
	var res := [9.0, 9.0]
	for pk in _peaux:
		var v: PackedVector3Array = pk[0]
		var bo: PackedInt32Array = pk[1]
		var we: PackedFloat32Array = pk[2]
		var nb := bo.size() / v.size()
		for i in v.size():
			var p := v[i]
			if (p.x > 0.0) != (c == "l"):
				continue
			var ax0 := w0 - e0
			var t := (p - e0).dot(ax0) / ax0.length_squared()
			var zone := 0 if (t > 0.02 and t < 0.15) else (1 if (t > 0.8 and t < 1.0) else -1)
			if zone < 0:
				continue
			var r0 := (p - (e0 + ax0 * t)).length()
			if r0 < 0.01:
				continue
			var q := Vector3.ZERO
			for k in nb:
				var w := we[i * nb + k]
				if w <= 0.0:
					continue
				var bi: int = bo[i * nb + k]
				q += w * ((_globales[pk[3][bi]] * (pk[4][bi] as Transform3D)) * p)
			var ax1 := w1 - e1
			var t1 := (q - e1).dot(ax1) / ax1.length_squared()
			var r1 := (q - (e1 + ax1 * t1)).length()
			res[zone] = minf(res[zone], r1 / r0)
	return res


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
			if gros:
				_pincement["apres" if actif else "avant"] = _pincer(c)
	tb.active = true
	var pa: Array = _pincement["avant"]
	var pp: Array = _pincement["apres"]
	print("PINCEMENT %s : coude %.2f -> %.2f   poignet %.2f -> %.2f" % [legende.get_slice("  ", 0) + " " + legende.get_slice("  ", 1), pa[0], pp[0], pa[1], pp[1]])
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
	var combat := seqs.filter(func(q): return q in ["repos", "estoc", "puissante", "revers", "diagonale"])
	var magie := seqs.filter(func(q): return q in ["zone", "jet", "lance"])
	if not combat.is_empty():
		await _monter(SCENE_COMBAT)
		for q in combat:
			match q:
				"repos":
					await _coup("repos", {}, 0.1, [3])
				"estoc", "revers", "diagonale":
					# coups du combo validé (Mixamo v3) : 3 estoc (coup_c), 2 revers horizontal (coup_b), 1 diagonale (coup_a)
					var g: String = {"diagonale": "diag_dg", "revers": "revers_gd", "estoc": "estoc_combo"}[q]
					await _coup(q, {0: ["appuyer"], 2: ["relacher"]}, 0.62, [6, 11, 16, 21, 26, 31], g)
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
