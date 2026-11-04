extends SceneTree
## Court film des habitants et bêtes Quaternius EN JEU (persos/quaternius_jeu, 2026-11-04), pour Movie Maker :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_persos_jeu.gd -- --nouvelle [--persos-anciens]
## (fenêtre hors écran via godot_slot.sh). Le monde charge (images enregistrées aussi), puis les plans s'enchaînent ; chacun est
## annoncé par `SEGMENT <nom> <première image> <dernière image>` pour la découpe (ffmpeg).
##   place (jour) · chasseurs · loups (la meute repère le joueur, l'encercle) · cerfs (broutent, puis fuient quand on approche) · place (nuit)

const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _image() -> int:
	return Engine.get_frames_drawn()

func _attendre(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	var n := int(s * 30.0)        # --fixed-fps 30 : le temps du jeu avance d'1/30 s par image
	for i in n:
		await process_frame
		if paused:
			paused = false
	if Time.get_ticks_msec() < fin:
		pass

func _poser(x: float, z: float, lacet: float, tangage: float) -> void:
	j.global_position = Vector3(x, m.hauteur(x, z) + 0.1, z)
	j.rotation.y = deg_to_rad(lacet)
	j.tete.rotation.x = deg_to_rad(tangage)
	j.velocity = Vector3.ZERO

func _heure(h: float) -> void:
	m.cycle.heure = h
	m.cycle._process(0.0)

func _plan(nom: String, x: float, z: float, lacet: float, tangage: float, h: float, duree: float, avance := Vector3.ZERO) -> void:
	_heure(h)
	_poser(x, z, lacet, tangage)
	await _attendre(1.0)          # lumière et brume locale posées
	var d := _image()
	if avance == Vector3.ZERO:
		await _attendre(duree)
	else:
		# le joueur avance lentement (approche du gibier) : avance = (dx, dz, vitesse)
		var n := int(duree * 30.0)
		for i in n:
			var p := j.global_position + Vector3(avance.x, 0, avance.y).normalized() * avance.z / 30.0
			j.global_position = Vector3(p.x, m.hauteur(p.x, p.z) + 0.1, p.z)
			j.velocity = Vector3.ZERO
			await process_frame
	print("SEGMENT %s %d %d" % [nom, d, _image()])

## Bête par son ident (groupe faune / ennemis), null si absente.
func _bete(id: String) -> Node3D:
	for g in ["faune", "ennemis"]:
		for n in get_nodes_in_group(g):
			if n.get("ident") == id:
				return n
	return null

## Cerfs : la harde est figée pendant le placement, caméra à 21 m de la biche (côté de la vue cerfs_jour_b, hors détection),
## puis elle est relâchée et le joueur avance vers elle -> elle fuit.
func _plan_cerfs() -> void:
	var harde: Array = []
	for id in ["cerf_pre", "biche_pre_a", "biche_pre_b"]:
		var b := _bete(id)
		if b != null:
			harde.append(b)
	if harde.is_empty():
		print("SEGMENT_ABSENT cerfs")
		return
	var centre := Vector3.ZERO
	for b: Node3D in harde:
		b.set_physics_process(false)
		b.velocity = Vector3.ZERO
		centre += b.global_position
		print("CERF %s %s" % [b.ident, b.global_position])
	centre /= harde.size()
	var bi: Node3D = _bete("biche_pre_a") if _bete("biche_pre_a") != null else harde[0]
	centre = bi.global_position                 # EXACTEMENT la vue de la capture cerfs_jour_b (12 m, 120° de la face de la biche)
	var d: Vector3 = bi.global_basis.z.rotated(Vector3.UP, deg_to_rad(120.0))
	d.y = 0.0
	var p := centre + d.normalized() * 21.0       # hors de leur détection (16-18 m) : elles broutent, puis fuient quand on approche
	var dx := centre.x - p.x
	var dz := centre.z - p.z
	var tang := rad_to_deg(atan2(centre.y + 0.9 - (m.hauteur(p.x, p.z) + 1.72), Vector2(dx, dz).length()))   # la harde est en haut du pré : on lève les yeux
	_heure(12.0)
	_poser(p.x, p.z, rad_to_deg(atan2(-dx, -dz)), tang)
	await _attendre(1.0)
	for b: Node3D in harde:
		b.set_physics_process(true)
		print("CERF_AVANT %s pos=%s vis=%s etat=%s" % [b.ident, b.global_position, b.is_visible_in_tree(), b.get("etat")])
	print("JOUEUR pos=%s lacet=%.0f vise=%s cam=%s" % [j.global_position, rad_to_deg(j.rotation.y), p, root.get_camera_3d().global_position if root.get_camera_3d() else Vector3.ZERO])
	await _plan("cerfs", p.x, p.z, rad_to_deg(atan2(-dx, -dz)), tang, 12.0, 10.0, Vector3(dx, dz, 1.4))

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
		if m == null:
			m = sc if sc.get("pret") != null else null
	j = m.joueur
	j.mort = false
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	j.vie = 100000.0           # film : la meute mord, le joueur ne meurt pas
	await _attendre(2.0)
	if "--seulement-cerfs" in OS.get_cmdline_user_args():
		await _plan_cerfs()
		print("FILM fini")
		quit(0)
		return
	await _plan("place", 32.5, 44.5, -54.0, -4.0, 11.0, 8.0)
	await _plan("chasseurs", 53.5, 31.5, -61.0, -4.0, 15.0, 6.0)
	await _plan("loups", -13.5, -16.5, 0.0, -8.0, 13.0, 10.0)
	await _plan_cerfs()
	await _plan("place_nuit", 32.5, 44.5, -54.0, -4.0, 22.0, 7.0)
	print("FILM fini")
	quit(0)
