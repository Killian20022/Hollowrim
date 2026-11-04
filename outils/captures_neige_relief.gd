extends SceneTree
## Captures et film du MONDE RÉACTIF SUR LA NEIGE (EffetsSol : traces de pas, gerbes, neige fondue par le feu, blocs de glace
## qui fondent, brûlures, ombres), dans le vrai monde (scenes/foret_test.tscn), vue 3e personne, vraies entrées (marche, course,
## saut) et vrais sorts (MainSort). FENÊTRE (godot_slot.sh : hors écran), toujours avec --fixed-fps 60 :
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/captures_neige_relief.gd -- --nouvelle --paisible --heure=12 \
##       --sortie=<dossier> [--film=<dossier d'images>] [--taille=960x540] [--sonde]
## Images fixes : <sortie>/01_traces_de_pas.png …  Film : une image sur deux (30 /s) → ffmpeg -framerate 30 -i f_%05d.png.
## « 30 s plus tard » = saut d'horloge (EffetsSol.saut_de_temps) : le masque est fonction du temps, c'est le même rendu.
var monde: Node3D
var j: CharacterBody3D
var m: MainSort
var sortie := ""
var film := ""
var n_film := 0
var n_img := 0
var legende: Label
var spot := Vector3.ZERO
var cam: Camera3D
var cam_decal := Vector3(1.4, 1.8, 3.0)   # repère du joueur (lacet `cam_yaw`) : droite, haut, derrière
var cam_vise := Vector3(0, 0.6, -4.0)
var cam_yaw := 0.0
var cam_suit := true
var top_spots: Array = []

func _init() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

## Une image de jeu ; sauvegarde une image de film sur deux.
func _img() -> void:
	await process_frame
	j.mana = j.mana_max
	m.recharges.clear()
	if cam != null:
		var b := Basis(Vector3.UP, j.rotation.y if cam_suit else cam_yaw)
		cam.global_position = j.global_position + b * cam_decal
		cam.look_at(j.global_position + b * cam_vise, Vector3.UP)
	if film != "":
		n_img += 1
		if n_img % 2 == 0:
			await RenderingServer.frame_post_draw
			var im := root.get_viewport().get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			im.save_png(film.path_join("f_%05d.png" % n_film))
			n_film += 1

func _att(n: int) -> void:
	for i in n:
		await _img()

func _photo(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGB8)
	im.save_png(sortie.path_join(nom + ".png"))
	print("PHOTO ", nom, " ", im.get_size())

func _dire(texte: String) -> void:
	legende.text = texte

## Accéléré : `s` secondes de masque / de fonte en `frames` images (film).
func _acceler(s: float, frames: int) -> void:
	for i in frames:
		EffetsSol.saut_de_temps(s / frames)
		await _img()

## Meilleur emplacement de la zone témoin (forêt enneigée) : quatre couloirs de travail (x, z haut, z bas, demi-largeur) relatifs au
## spot — marche, feu, glace, électricité — le plus enneigé, plat et dégagé (arbres, rochers, disques réservés de la zone).
func _sur_eau(x: float, z: float) -> bool:
	for w in root.get_tree().get_nodes_in_group("eaux"):
		if w.contient(x, z):
			return true
	return false

func _chercher_spot() -> Vector3:
	var obstacles: Array = []   # [Vector2, rayon]
	for t in monde.arbres:
		if t is Transform3D:
			obstacles.append([Vector2(t.origin.x, t.origin.z), 0.6])
		elif t is Dictionary and t.has("pos"):
			obstacles.append([Vector2(t["pos"].x, t["pos"].z), 0.6])
	for r in SousBois._rochers(monde):
		obstacles.append([r["pos"], r["r"] + 0.5])
	for o in ZoneBiome.OCCUPATIONS:
		obstacles.append([o[0], o[1] + 1.0])
	var couloirs := [[0.0, 5.0, -12.0, 2.5], [6.0, 3.0, -9.0, 3.0], [-6.0, 3.0, -9.0, 3.0], [0.0, -6.0, -20.0, 3.0]]
	var meilleur := Vector3.INF
	var score_max := -1e9
	var top: Array = []
	for cx in range(-40, 41, 2):
		for cz in range(-30, 41, 2):
			var h0: float = monde.hauteur(cx, cz)
			if absf(h0 - 3.602231) < 0.02:
				continue   # plateforme du village
			var pts := 0
			var neige := 0
			var pente := 0.0
			var gene := 0
			for co in couloirs:
				var x0: float = cx + co[0] - co[3]
				var x1: float = cx + co[0] + co[3]
				var z0: float = cz + co[2]
				var z1: float = cz + co[1]
				for dz in range(int(co[2]), int(co[1]) + 1, 1):
					for dx in [-co[3], -co[3] * 0.5, 0.0, co[3] * 0.5, co[3]]:
						var px: float = cx + co[0] + dx
						var pz: float = cz + dz
						pts += 1
						neige += int(Sol.est_neige(px, pz) and not _sur_eau(px, pz))
						pente = maxf(pente, absf(float(monde.hauteur(px, pz)) - h0))
				for o in obstacles:
					var q: Vector2 = o[0]
					var dxr := maxf(maxf(x0 - q.x, q.x - x1), 0.0)
					var dzr := maxf(maxf(z0 - q.y, q.y - z1), 0.0)
					if dxr * dxr + dzr * dzr < float(o[1]) * float(o[1]):
						gene += 1
			var score := float(neige) / pts - 0.3 * gene - 0.5 * maxf(pente - 0.6, 0.0)
			top.append([score, Vector3(cx, h0, cz)])
			if score > score_max:
				score_max = score
				meilleur = Vector3(cx, h0, cz)
	top.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for i in mini(12, top.size()):
		print("TOP ", i, " ", top[i][0], " ", top[i][1])
		top_spots.append(top[i][1])
	print("SPOT score ", score_max)
	if _arg("spot") != "":
		var v := _arg("spot").split_floats(",")
		return Vector3(v[0], monde.hauteur(v[0], v[1]), v[1])
	return meilleur

func _go() -> void:
	sortie = _arg("sortie", "user://neige_sorts")
	film = _arg("film", "")
	if _arg("taille") != "":
		var wh := _arg("taille").split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(sortie)
	if film != "":
		DirAccess.make_dir_recursive_absolute(film)
	var t0 := Time.get_ticks_msec()
	while monde.get("joueur") == null and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	j = monde.joueur
	m = j.mains.magie
	if m.eq.has_method("apprendre_tout"):
		m.eq.apprendre_tout()
	for i in 240:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# interface masquée, sauf le post-traitement PS1 ; une légende pour le film
	for n in root.find_children("*", "CanvasLayer", true, false):
		for c in n.get_children():
			var garder: bool = c is ColorRect and (c as ColorRect).material is ShaderMaterial
			if c is CanvasItem and not garder:
				(c as CanvasItem).visible = false
	var cl := CanvasLayer.new()
	cl.layer = 90
	root.add_child(cl)
	legende = Label.new()
	legende.position = Vector2(14, 10)
	legende.add_theme_font_size_override("font_size", 22)
	legende.add_theme_color_override("font_color", Color(1, 1, 1))
	legende.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	legende.add_theme_constant_override("outline_size", 6)
	cl.add_child(legende)
	print("DEPART ", monde.depart_joueur, " matiere ", Sol.matiere_en(monde.depart_joueur.x, monde.depart_joueur.z), " neige_dehors ", EffetsSol.neige_dehors())
	spot = _chercher_spot()
	print("SPOT ", spot)
	if _arg("scan") != "":   # grandes plaques de neige (hors eau, plates) : candidats pour --spot=x,z
		var res: Array = []
		var troncs: Array = []
		for t in monde.arbres:
			if t is Transform3D:
				troncs.append(Vector2(t.origin.x, t.origin.z))
			elif t is Dictionary and t.has("pos"):
				troncs.append(Vector2(t["pos"].x, t["pos"].z))
		var dep := Vector2(56.0, 50.0)   # village (vu en capture) ; le départ du joueur est ailleurs
		for cx in range(-100, 101, 4):
			for cz in range(-100, 101, 4):
				if Vector2(cx, cz).distance_to(dep) < 45.0:
					continue   # village et ses abords
				var gene := 0
				for q: Vector2 in troncs:
					if absf(q.x - cx) < 9.0 and q.y > cz - 16.0 and q.y < cz + 6.0:
						gene += 1
				var h0: float = monde.hauteur(cx, cz)
				var ok := 0
				var pente := 0.0
				var piste := 0
				for dx in range(-2, 3):
					for dz in range(-10, 1):
						piste += int(not (Sol.est_neige(cx + dx, cz + dz) and not _sur_eau(cx + dx, cz + dz)))
				if piste > 3:
					continue   # la piste de marche doit être de la neige franche
				for dx in range(-8, 9, 2):
					for dz in range(-14, 5, 2):
						ok += int(Sol.est_neige(cx + dx, cz + dz) and not _sur_eau(cx + dx, cz + dz))
						pente = maxf(pente, absf(float(monde.hauteur(cx + dx, cz + dz)) - h0))
				res.append([float(ok) / (9 * 10) - 0.4 * maxf(pente - 0.8, 0.0) - 0.15 * gene, Vector2(cx, cz), pente, gene])
		res.sort_custom(func(a, b) -> bool: return a[0] > b[0])
		for i in 8:
			print("SCAN ", res[i])
		quit(0)
		return
	if _arg("sonde") != "":
		var h := {}
		var d0: Vector3 = monde.depart_joueur
		for x in range(-100, 101, 4):
			for z in range(-100, 101, 4):
				var mm := Sol.matiere_en(d0.x + x, d0.z + z)
				h[mm] = int(h.get(mm, 0)) + 1
		print("HISTO ", h, " arbres ", monde.arbres.size(), " type ", typeof(monde.arbres[0]) if monde.arbres.size() > 0 else -1)
	if _arg("apercu") != "":
		cam = Camera3D.new()
		cam.fov = 62.0
		root.add_child(cam)
		cam.current = true
		for i in 12:
			var p: Vector3 = top_spots[i]
			cam.global_position = p + Vector3(0, 13, 17)
			cam.look_at(p + Vector3(0, 0, -6), Vector3.UP)
			j.global_position = p + Vector3(0, 0.2, 0)
			for k in 12:
				await process_frame
			await _photo("ap_%02d" % i)
	if _arg("sonde") != "" or spot == Vector3.INF:
		quit(0)
		return
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 90.0
	root.add_child(cam)
	cam.current = true
	j.global_position = spot + Vector3(0, 0.15, 0)
	j.rotation.y = 0.0
	j.tete.rotation.x = deg_to_rad(-12)
	j.basculer_vue(true)
	cam.current = true
	await _att(60)
	if _arg("diag") != "":   # diagnostic : motifs posés à la main devant le joueur (empreintes, brûlure, ombre)
		var e := EffetsSol.obtenir()
		e._suivre_joueur(j)
		cam_decal = Vector3(0.0, 4.5, 2.0)
		cam_vise = Vector3(0, 0.0, -4.5)
		for k in 3:
			var o := Vector3(-2.5 + 2.5 * k, 0, -4.0)
			var pj := j.global_position + o
			if k == 0:
				for s in 6:
					e._empreinte(pj + Vector3(0, 0, -s * 0.8), Vector2(0, -1), s % 2 == 0, false)
			elif k == 1:
				e.bruler(pj.x, pj.z, 0.5)
			else:
				e.ombrer(pj.x, pj.z, 1.0)
		e._envoyer()
		print("DIAG masque ", e.lire(j.global_position.x + 2.5, j.global_position.z - 4.0), " rect ", e._rect_actif, " fin_vie ", e._fin_vie, " t ", e.t, " neige ", EffetsSol.est_neige(j.global_position.x, j.global_position.z - 4.0))
		await _att(90)
		await _photo("diag")
		var nb_eau := 0
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var mo: Material = (mi as MeshInstance3D).material_override
			if mo is ShaderMaterial and (mo as ShaderMaterial).shader != null and (mo as ShaderMaterial).shader.resource_path.ends_with("eau.gdshader"):
				(mi as MeshInstance3D).visible = false
				nb_eau += 1
		print("DIAG eau cachée : ", nb_eau)
		await _att(10)
		await _photo("diag_sans_eau")
		quit(0)
		return

	# ---------------------------------------------------------------- relief de la neige : marche, course, trou du feu
	var e := EffetsSol.obtenir()
	# 1. marche : trait de pas derrière le joueur, puis vues de jeu à 4-8 m
	_dire("Relief : marche dans la neige")
	cam_decal = Vector3(2.0, 1.4, 3.4)
	cam_vise = Vector3(0, 0.7, -1.0)
	Input.action_press("avant")
	await _att(150)
	Input.action_release("avant")
	await _att(25)
	await _photo("01_marche_vue_de_jeu")
	cam_decal = Vector3(2.6, 2.3, 5.2)                  # derrière, à ~5 m : la piste devant le joueur est derrière lui
	cam_vise = Vector3(0, 0.0, 2.4)
	await _att(10)
	await _photo("02_piste_vue_de_derriere")
	cam_decal = Vector3(0.5, 2.0, 5.5)                  # de dos, dans l'axe de la piste
	cam_vise = Vector3(0, 0.3, 0.0)
	await _att(10)
	await _photo("02b_marche_de_dos_dans_l_axe")
	cam_decal = Vector3(4.5, 1.2, 2.5)                  # côté, basse : lumière rasante sur le relief
	cam_vise = Vector3(0, -0.2, 2.5)
	await _att(10)
	await _photo("03_piste_de_cote_rasante")
	cam_decal = Vector3(0.7, 1.7, 1.6)                  # plongée rapprochée sur les dernières empreintes
	cam_vise = Vector3(0, -0.2, 2.4)
	await _att(10)
	await _photo("04_empreintes_plongee")
	cam_decal = Vector3(0.45, 0.85, 1.35)               # gros plan d'une empreinte
	cam_vise = Vector3(-0.1, -0.1, 1.0)
	await _att(10)
	await _photo("05_gros_plan_empreinte")
	# 2. course
	_dire("Relief : course, sillon plus profond")
	var rx: float = spot.x - 2.5
	var rz: float = spot.z + 8.0
	j.global_position = Vector3(rx, float(monde.hauteur(rx, rz)) + 0.3, rz)
	j.velocity = Vector3.ZERO
	j.rotation.y = 0.0
	await _att(20)
	print("COURSE depart ", j.global_position, " pas ", EffetsSol.stats["pas"], " vigueur ", j.vigueur)
	Input.action_press("avant")
	Input.action_press("course")
	await _att(90)
	print("COURSE fin ", j.global_position, " v ", j.velocity, " pas ", EffetsSol.stats["pas"], " vigueur ", j.vigueur)
	Input.action_release("course")
	Input.action_release("avant")
	await _att(40)
	cam_decal = Vector3(2.6, 2.3, 5.2)
	cam_vise = Vector3(0, 0.0, 2.4)
	await _att(10)
	await _photo("06_course_vue_de_derriere")
	cam_decal = Vector3(0.5, 2.0, 5.5)
	cam_vise = Vector3(0, 0.3, 0.0)
	await _att(10)
	await _photo("06b_course_de_dos_dans_l_axe")
	cam_decal = Vector3(3.2, 1.9, 3.6)
	cam_vise = Vector3(0, 0.0, 1.2)
	await _att(10)
	await _photo("06c_course_trois_quarts")
	cam_decal = Vector3(4.5, 1.2, 2.5)
	cam_vise = Vector3(0, -0.2, 2.5)
	await _att(10)
	await _photo("07_course_de_cote_rasante")
	cam_decal = Vector3(0.9, 1.8, 2.2)
	cam_vise = Vector3(0, -0.2, 3.0)
	await _att(10)
	await _photo("08_course_plongee")
	# 3. feu : boule de feu au sol
	_dire("Relief : trou du feu, bord épais, terre au fond")
	j.global_position = spot + Vector3(6.0, 0.15, 2.0)
	j.velocity = Vector3.ZERO
	j.rotation.y = deg_to_rad(-8)
	j.tete.rotation.x = deg_to_rad(-24)
	cam_decal = Vector3(1.6, 2.2, 3.4)
	cam_vise = Vector3(0, 0.0, -5.0)
	m.equiper("droite", "boule_feu")
	await _att(20)
	m.appuyer("droite")
	await _att(55)
	m.relacher("droite")
	await _att(40)
	await _photo("09_feu_trou_vue_de_jeu")
	cam_decal = Vector3(0.0, 4.0, -1.0)
	cam_vise = Vector3(0, -0.5, -5.5)
	await _att(10)
	await _photo("10_feu_trou_plongee")
	cam_decal = Vector3(3.2, 0.9, -3.0)
	cam_vise = Vector3(0, -0.2, -5.5)
	await _att(10)
	await _photo("11_feu_trou_rasant")
	await _acceler(20.0, 30)
	await _photo("12_feu_trou_20s_plus_tard")
	await _acceler(20.0, 30)
	await _photo("13_feu_trou_40s_plus_tard")
	print("FILM %d images ; stats %s ; relief_fin %.1f" % [n_film, EffetsSol.stats, e._relief_fin - e.t])
	quit(0)
