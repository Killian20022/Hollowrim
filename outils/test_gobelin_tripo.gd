extends SceneTree
## Gobelin Tripo EN COMBAT dans la vraie grotte des bandits (foret_test) : avec --gobelin-tripo il remplace le guetteur de l'entrée (bandit_4).
## Test : il apparaît (corps Tripo, ~1,2 m), est alerté, marche, ATTAQUE et blesse le joueur, puis meurt sous un coup létal.
## Film : --film (joueur invulnérable, caméra sur le gobelin, HUD caché ; plans affichés « PLAN nom image », photo <sortie>/gobelin_grotte_attaque.png).
##   godot --headless --path . --script res://outils/test_gobelin_tripo.gd -- --gobelin-tripo --ennemis-tripo --nouvelle
##   godot --path . --write-movie f.avi --fixed-fps 30 --resolution 960x540 --script res://outils/test_gobelin_tripo.gd -- --gobelin-tripo --nouvelle --film --sortie=<dossier>
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var j: CharacterBody3D
var film := false
var echecs := 0
var img := 0

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func ok(c: bool, msg: String) -> void:
	print(("OK     " if c else "ECHEC  ") + msg)
	if not c:
		echecs += 1

func _pf() -> void:
	img += 1
	if film:
		j.vie = j.vie_max
		j.esquive_t = 0.0
	await physics_frame

func _att(n: int) -> void:
	for i in n:
		await _pf()

func _inter(nom: String) -> Node3D:
	for n in m.find_children("*", "Node3D", true, false):
		if n.get("verbe") != null and n.get("nom") == nom:
			return n
	return null

func _go() -> void:
	film = OS.get_cmdline_user_args().has("--film")
	var sortie := _arg("sortie", "user://film")
	DirAccess.make_dir_recursive_absolute(sortie)
	ok(EnnemiTripo.gobelin_actif(), "option --gobelin-tripo reconnue")
	if film:
		Effets.niveau_force = 1
		Sang.niveau_force = 2
		RetourImpact.muet = true
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	j = m.joueur
	for i in 5:
		await physics_frame
	var a: Node3D = m.grotte_acces
	a.attendre_exterieur()
	await _att(6)
	j.global_position = a.porte_dehors + Vector3(0, 0.5, 0)
	await _att(10)
	var bouche := _inter("Grotte des bandits")
	ok(bouche != null, "bouche de la grotte trouvée")
	if bouche == null:
		quit(1)
		return
	m.dialogue.inviter(bouche)
	bouche.parler()
	var t0 := Time.get_ticks_msec()
	while not a.dedans and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
	ok(a.dedans, "entrée dans la grotte")
	await _att(40)
	var e: CharacterBody3D = null
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		e = a.jeu.ennemis.get("bandit_4")
		if e != null and is_instance_valid(e):
			break
		await physics_frame
	ok(e != null, "le gobelin de test (bandit_4) est apparu")
	if e == null:
		quit(1)
		return
	var tripo := false
	for n in e.find_children("*", "Node3D", true, false):
		if n.has_meta("tripo_ennemi") and n.get_meta("tripo_ennemi") == "gobelin":
			tripo = true
	ok(tripo, "corps Tripo gobelin")
	ok(String(e.get("type")) == "gobelin" or float(e.echelle) < 0.8, "ennemi de type gobelin (échelle %.2f)" % float(e.echelle))
	if film:
		if m.get("hud") != null:
			m.hud.visible = false
		j.mains.visible = false
		for n in j.camera.get_children():
			if n is Node3D:
				n.visible = false
		j.camera.fov = 52.0
	var vie0: float = j.vie
	var viser := func() -> void:
		var v: Vector3 = e.global_position - j.global_position
		j.rotation.y = atan2(-v.x, -v.z)
		j.tete.rotation.x = clampf(atan2(e.global_position.y + 0.6 - (j.global_position.y + 1.6), maxf(Vector2(v.x, v.z).length(), 0.1)), -0.5, 0.5)
		j.velocity = Vector3.ZERO
	# approche : le joueur se place à ~5 m en face du gobelin, de l'autre côté
	var dirj: Vector3 = (j.global_position - e.global_position)
	dirj.y = 0.0
	dirj = dirj.normalized()
	j.global_position = Vector3(e.global_position.x + dirj.x * 5.0, e.global_position.y + 0.1, e.global_position.z + dirj.z * 5.0)
	print("PLAN idle %d" % img)
	for i in 45:
		viser.call()
		await _pf()
	e.alerter()
	print("PLAN approche_attaque %d" % img)
	var attaque := false
	var photo := false
	var marche := false
	for i in 420:
		viser.call()
		var an := String(e._anim)
		if an.contains("Walk") or an.contains("Jog"):
			marche = true
		if an.contains("Attack") or an.contains("Punch"):
			attaque = true
			if film and not photo and i > 60:
				photo = true
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(sortie.path_join("gobelin_grotte_attaque.png"))
		await _pf()
		if attaque and (j.vie < vie0 or film) and i > 240:
			break
	ok(marche, "le gobelin marche vers le joueur")
	ok(attaque, "le gobelin attaque (clip %s)" % e._anim)
	if not film:
		ok(j.vie < vie0, "il blesse le joueur (%.1f -> %.1f)" % [vie0, j.vie])
	print("PLAN mort %d" % img)
	var c0: Vector3 = e.global_position + Vector3(0, float(e.combat.hauteur) * 0.6, 0)
	var dj: Vector3 = (c0 - j.global_position).normalized()
	var info := {"type": "tranchant", "point": c0 - dj * 0.25, "direction": j.global_transform.basis.x, "normale": -dj, "zone": "torse",
		"attaque": "legere", "arme": j.mains.arme.id, "stagger": DegatsCombat.stagger(j.mains.arme, "legere"), "collider": e}
	e.vie = 1.0
	DegatsCombat.appliquer(e, 999.0, j.global_position, true, info)
	await _att(100 if film else 30)
	ok(not e.vivant(), "le gobelin meurt sous un coup létal")
	print("FIN %d" % img)
	print("ECHECS : %d" % echecs if echecs > 0 else "TOUT OK")
	quit(echecs)
