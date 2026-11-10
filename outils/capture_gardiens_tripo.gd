extends SceneTree
## Preuves du lot tripo/gardiens (gardes du village sur les corps GardeTripo), dans le vrai jeu (foret_test), fenêtre HORS ÉCRAN (godot_slot.sh).
##   --vue=postes     : chaque garde converti (10 de data/gardes.json + Haldor) photographié SUR SON POSTE (rondes : à leur point de départ),
##                      de face à 2,6 m, en Idle ; avec --modeles-anciens=gardes les MÊMES gardes en ancien corps (suffixe _anciens).
##                      Écrit <sortie>/poste_<id>[_anciens].png et <sortie>/planche_postes[_anciens].png.
##   --vue=mains      : gros plans de la main droite et de l'épée (garde n_e, épée ; garde so, lancier ; Haldor) en Idle et à 4 instants
##                      de Walk : <sortie>/main_<id>_<clip>_<t>.png + planche_mains.png.
##   --vue=patrouille : film (avec --write-movie <f.avi> --fixed-fps 30) : la ronde de l'est puis la ronde de l'ouest, caméra qui suit.
##   godot --path . --resolution 960x540 --script res://outils/capture_gardiens_tripo.gd -- --nouvelle --vue=postes --sortie=<dossier>
const SCENE := "res://scenes/foret_test.tscn"
const IDS := ["so", "haldor", "n_o", "n_e", "e_n", "e_s", "tour", "vigie", "ronde_rue", "ronde_est", "ronde_ouest"]
var m: Node3D
var j: CharacterBody3D
var cam: Camera3D
var sortie := "user://gardiens_tripo"
var suffixe := ""
var photos: Array = []      # [nom, Image]

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _attendre(n: int, chaque := Callable()) -> void:
	for i in n:
		if is_instance_valid(j):
			j.vie = j.vie_max
		if chaque.is_valid():
			chaque.call(i)
		await process_frame

func _photo(nom: String) -> void:
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(sortie.path_join("%s%s.png" % [nom, suffixe]))
	photos.append([nom, im])
	print("PHOTO ", nom)

func _garde(id: String) -> Node3D:
	if id == "haldor":
		for v in get_nodes_in_group("villageois"):
			if "donnees" in v and String(v.donnees.get("id", "")) == "garde" and not v.has_method("alerter"):
				return v
		return null
	for g in m.get_node("GardesVillage").gardes:
		if String(g.donnees.get("id", "")) == id:
			return g
	return null

## Caméra à `dist` m devant la cible (son +Z), décalée de `cote` sur sa droite, œil à `h_oeil`, visée à `h_vise`.
func _cadrer(c: Node3D, dist := 2.6, cote := 0.35, h_oeil := 1.45, h_vise := 1.0) -> void:
	var b := c.global_transform.basis.orthonormalized()
	var p := c.global_position + b.z * dist + b.x * cote
	p.y = c.global_position.y + h_oeil
	cam.global_position = p
	cam.look_at(c.global_position + Vector3(0, h_vise, 0), Vector3.UP)

## Comme _cadrer, mais tourne autour du garde (face, 3/4, profils, puis dos) jusqu'à voir sa poitrine sans obstacle (palissade des portes).
func _cadrer_libre(c: Node3D) -> void:
	var b := c.global_transform.basis.orthonormalized()
	var vise := c.global_position + Vector3(0, 1.0, 0)
	var esp := m.get_world_3d().direct_space_state
	for ang: float in [0.0, 35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0, -150.0, 180.0]:
		var dirv := (Basis(Vector3.UP, deg_to_rad(ang)) * b.z).normalized()
		var p := c.global_position + dirv * 2.6 + (Basis(Vector3.UP, deg_to_rad(ang)) * b.x).normalized() * 0.35
		p.y = c.global_position.y + 1.45
		var rq := PhysicsRayQueryParameters3D.create(p, vise)
		rq.exclude = [c.get_rid()] if c is CollisionObject3D else []
		var hit := esp.intersect_ray(rq)
		if hit.is_empty() or (hit["position"] as Vector3).distance_to(vise) < 0.5 or hit["collider"] == c:
			cam.global_position = p
			cam.look_at(vise, Vector3.UP)
			if ang != 0.0:
				print("CADRAGE %s : %.0f°" % [c.name, ang])
			return
	_cadrer(c)

func _planche(nom: String, cols := 4) -> void:
	var w := 480
	var h := 270
	var rangs := ceili(photos.size() / float(cols))
	var pl := Image.create(w * cols, h * rangs, false, Image.FORMAT_RGBA8)
	pl.fill(Color(0.05, 0.05, 0.05))
	for i in photos.size():
		var im: Image = (photos[i][1] as Image).duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_NEAREST)
		pl.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	pl.save_png(sortie.path_join("planche_%s%s.png" % [nom, suffixe]))
	print("PLANCHE ", nom, " ", photos.size(), " photos")

func _go() -> void:
	sortie = _arg("sortie", sortie)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--modeles-anciens"):
			suffixe = "_anciens"
	DirAccess.make_dir_recursive_absolute(sortie)
	Effets.niveau_force = 1
	RetourImpact.muet = true
	var sc := (load(SCENE) as PackedScene).instantiate()
	sc.set_meta("test", true)
	root.add_child(sc)
	current_scene = sc
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	while not m.village.prets:
		await process_frame
	j = m.joueur
	j.vie_max = 100000.0
	j.vie = 100000.0
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 11.0
	m.cycle._process(0.0)
	if m.get("hud") != null:
		if "aide_t" in m.hud:
			m.hud.aide_t = 0.0
		m.hud.visible = false
	j.mains.visible = false
	for c in j.camera.get_children():
		if c is Node3D:
			c.visible = false
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	m.add_child(cam)
	cam.make_current()
	var vue := _arg("vue", "postes")
	print("CAPTURE vue=", vue, " tripo gardes=", ModelesTripo.actif("gardes"))
	match vue:
		"mains":
			await _mains()
			_planche("mains", 4)
		"patrouille":
			await _patrouille()
		_:
			await _postes()
			_planche("postes", 4)
	sc.queue_free()
	for i in 5:
		await process_frame
	quit(0)

## Garde figé (plus de déplacement ni d'IA), son AnimationPlayer joue `clip` (Idle par défaut).
func _figer(g: Node3D, clip := "Idle") -> AnimationPlayer:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	var ap: AnimationPlayer = g.get("anim")
	if ap:
		ap.process_mode = Node.PROCESS_MODE_ALWAYS
		ap.speed_scale = 1.0
		ap.play(clip)
	return ap

func _postes() -> void:
	await _attendre(90)
	var gardes: Array = []
	for id: String in IDS:
		var g := _garde(id)
		if g == null:
			print("ABSENT ", id)
			continue
		var p := g.global_position
		print("GARDE %-11s corps=%s variante=%s pos=(%.1f ; %.1f)" % [id, g.modele.get_meta("pnj_nordique", g.modele.name), g.modele.get_meta("variante_tripo", "-"), p.x, p.z])
		gardes.append([id, g])
	for x: Array in gardes:
		var g: Node3D = x[1]
		_figer(g)
	for x: Array in gardes:
		var g: Node3D = x[1]
		# le joueur à l'écart (les gardes ne se tournent pas vers lui) ; le garde reçoit le LOD complet de près
		j.global_position = g.global_position + g.global_transform.basis.z.normalized() * 9.0 + Vector3(0, 0.3, 0)
		j.velocity = Vector3.ZERO
		if String(x[0]) == "vigie":
			_cadrer(g, 2.2, 0.2, 1.5, 1.0)
		else:
			_cadrer_libre(g)
		await _attendre(8)
		await _photo("poste_" + String(x[0]))

## Instants de Walk photographiés (s) : contact, passage, contact opposé, passage.
const INSTANTS := [0.0, 0.25, 0.5, 0.75]

func _mains() -> void:
	await _attendre(90)
	for id: String in ["n_e", "so", "haldor"]:
		var g := _garde(id)
		if g == null:
			continue
		# posé sur la place (sol plat, lumière franche), tourné vers +Z
		var x := 40.0
		var z := 44.0
		var ap := _figer(g)
		g.global_position = Vector3(x, m.hauteur(x, z) + 0.02, z)
		g.rotation.y = 0.0
		j.global_position = Vector3(x + 8.0, m.hauteur(x + 8.0, z + 8.0) + 0.3, z + 8.0)
		var sq: Skeleton3D = g.modele.find_child("Skeleton3D", true, false)
		var main := sq.find_bone("hand_r")
		for clip: String in ["Idle", "Walk"]:
			var ts: Array = [0.4] if clip == "Idle" else INSTANTS
			for t: float in ts:
				ap.play(clip)
				ap.seek(t * (1.0 if clip == "Idle" else ap.current_animation_length), true)
				ap.pause()
				await _attendre(3)
				var pm := sq.global_transform * sq.get_bone_global_pose(main).origin
				# gros plan de 3/4 avant-droit sur la main ; un plan de profil pour l'axe de l'épée en marche
				var de := g.global_transform.basis.orthonormalized()
				if clip == "Idle":
					cam.global_position = pm + de.z * 0.75 + de.x * 0.45 + Vector3(0, 0.15, 0)
				else:
					cam.global_position = pm + de.x * 1.5 + de.z * 0.25 + Vector3(0, 0.05, 0)
					pm += Vector3(0, -0.25, 0)
				cam.look_at(pm, Vector3.UP)
				await _attendre(3)
				await _photo("main_%s_%s_%d" % [id, clip, int(t * 100)])

func _suivre(c: Node3D, d: Vector3, hauteur := 1.0) -> void:
	var b := c.global_transform.basis.orthonormalized()
	var p := c.global_position + b.x * d.x + b.z * d.z
	p.y = m.hauteur(p.x, p.z) + d.y
	cam.global_position = cam.global_position.lerp(p, 0.15) if cam.global_position.distance_to(p) < 4.0 else p
	cam.look_at(c.global_position + Vector3(0, hauteur, 0), Vector3.UP)

func _patrouille() -> void:
	cam.fov = 55.0
	for i in 60:
		await process_frame
	for x: Array in [["ronde_est", Vector3(1.6, 1.3, 2.9), 9.0], ["ronde_ouest", Vector3(-1.6, 1.3, 2.9), 7.0]]:
		var g := _garde(String(x[0]))
		print("PATROUILLE ", x[0], " corps=", g.modele.get_meta("pnj_nordique", g.modele.name), " livree=", g.modele.get_meta("variante_tripo", "-"))
		j.global_position = g.global_position + Vector3(0, 0.3, 25.0)
		j.global_position.y = m.hauteur(j.global_position.x, j.global_position.z) + 0.3
		j.velocity = Vector3.ZERO
		cam.global_position = Vector3(0, -100, 0)
		await _attendre(int(float(x[2]) * 30), func(_i: int) -> void: _suivre(g, x[1], 1.0))
