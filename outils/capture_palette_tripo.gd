extends SceneTree
## Planches AVANT / APRÈS de la passe palette Tripo (PaletteTripo, job G1 de l'audit 2026-11-10), dans le vrai jeu (foret_test), fenêtre
## HORS ÉCRAN (godot_slot.sh). Chaque modèle est photographié EN SITUATION à côté d'un garde Tripo de référence, au même cadrage d'une
## passe à l'autre : on lance deux fois, avec et sans `--palette-tripo-ancienne`, et outils/planche_palette_tripo.sh colle les paires.
##   --vue=village : garde doré (halle_e) à côté du lancier (halle_o), de jour ; puits de la place de jour avec un garde à côté.
##   --vue=crypte  : draugr guerrier + archer draugr + garde de référence ; squelette Tripo à côté de l'archer squelette (ancien corps) + garde.
##   --vue=grotte  : gobelin (bandit_4, entrée de la grotte des bandits) + garde de référence.
##   godot --path . --resolution 960x540 --script res://outils/capture_palette_tripo.gd -- --nouvelle --vue=crypte [--palette-tripo-ancienne] --sortie=<dossier>
## Écrit <sortie>/<vue>_<plan>_<avant|apres>.png.
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D
var cam: Camera3D
var sortie := "user://palette_tripo"
var suffixe := "_apres"

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		if is_instance_valid(j):
			j.vie = j.vie_max
		await process_frame

func _photo(nom: String) -> void:
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = cl == _etiquette
	(_etiquette.get_child(0) as Label).text = ("AVANT  (réglages d'origine)" if PaletteTripo.ancienne else "APRÈS  (PaletteTripo)") + "   " + nom
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(sortie.path_join("%s%s.png" % [nom, suffixe]))
	print("PHOTO ", nom)

var _etiquette: CanvasLayer

## Étiquette incrustée dans la photo (coin haut gauche) : AVANT / APRÈS + nom du plan.
func _etiqueter() -> void:
	_etiquette = CanvasLayer.new()
	_etiquette.layer = 120
	var l := Label.new()
	l.position = Vector2(8, 6)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if PaletteTripo.ancienne else Color(0.7, 0.95, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	_etiquette.add_child(l)
	root.add_child(_etiquette)

func _figer(n: Node, anim := "Idle") -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED
	var ap: AnimationPlayer = n.get("anim") if n.get("anim") is AnimationPlayer else n.find_child("Animations", true, false) as AnimationPlayer
	if ap:
		ap.process_mode = Node.PROCESS_MODE_ALWAYS
		ap.play(anim if ap.has_animation(anim) else "Idle")
		ap.seek(0.4, true)
		ap.speed_scale = 0.0     # même pose d'une passe à l'autre

## Garde Tripo de référence (garde à l'épée), modèle seul, figé en Idle.
func _garde_ref(parent: Node3D) -> Node3D:
	var g := GardeTripo.creer("tripo_garde_epee", false, false)
	g.name = "GardeReference"
	parent.add_child(g)
	_figer(g)
	return g

func _go() -> void:
	sortie = _arg("sortie", sortie)
	if PaletteTripo.ancienne:
		suffixe = "_avant"
	DirAccess.make_dir_recursive_absolute(sortie)
	_etiqueter()
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
	var vue := _arg("vue", "village")
	print("CAPTURE vue=", vue, " palette ancienne=", PaletteTripo.ancienne)
	if vue == "crypte":
		await _crypte()
	elif vue == "grotte":
		await _grotte()
	else:
		await _village()
	sc.queue_free()
	for i in 5:
		await process_frame
	quit(0)

func _nouvelle_camera(fov := 50.0) -> void:
	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	m.add_child(cam)
	cam.make_current()

func _village() -> void:
	_nouvelle_camera()
	await _attendre(120)
	var gardes := {}
	for g in m.get_node("GardesVillage").gardes:
		gardes[String(g.donnees.get("id", ""))] = g
	var dore: Node3D = gardes.get("halle_e")
	var lancier: Node3D = gardes.get("halle_o")
	var epee: Node3D = gardes.get("ronde_place")
	for g in [dore, lancier, epee]:
		if g != null:
			_figer(g)
	j.global_position = Vector3(40.0, m.hauteur(40.0, 60.0) + 0.2, 60.0)
	# 1) garde doré à côté du lancier, sur la place (dallage, maisons derrière), plein jour
	var base := Vector3(33.0, 0.0, 43.0)
	var poser := func(n: Node3D, x: float, z: float) -> void:
		n.global_position = Vector3(x, m.hauteur(x, z) + 0.02, z)
		n.rotation.y = 0.0
	poser.call(lancier, base.x, base.z)
	poser.call(dore, base.x + 1.5, base.z)
	await _attendre(30)
	poser.call(lancier, base.x, base.z)
	poser.call(dore, base.x + 1.5, base.z)
	var mil := base + Vector3(0.75, 0, 0)
	cam.global_position = Vector3(mil.x + 0.5, m.hauteur(mil.x, mil.z + 3.4) + 1.45, mil.z + 3.4)
	cam.look_at(Vector3(mil.x, m.hauteur(mil.x, mil.z) + 1.0, mil.z), Vector3.UP)
	await _attendre(4)
	await _photo("village_garde_dore")
	cam.global_position = Vector3(base.x + 1.5 + 0.3, m.hauteur(base.x + 1.5, base.z + 1.9) + 1.5, base.z + 1.9)
	cam.look_at(Vector3(base.x + 1.5, m.hauteur(base.x + 1.5, base.z) + 1.25, base.z), Vector3.UP)
	await _attendre(4)
	await _photo("village_garde_dore_gros")
	# 2) puits de la place, de jour, un garde à l'épée à côté (laissé où il est : on ne déplace que le garde)
	var puits := m.find_child("PuitsTripo", true, false) as Node3D
	var cp := puits.global_position if puits != null else Vector3(42.0, m.hauteur(42.0, 38.0), 38.0)
	print("PUITS tripo=", puits != null, " ", cp)
	if epee != null:
		poser.call(epee, cp.x - 2.0, cp.z + 1.6)
	poser.call(dore, cp.x + 40.0, cp.z + 40.0)
	poser.call(lancier, cp.x + 42.0, cp.z + 40.0)
	await _attendre(10)
	cam.fov = 60.0
	cam.global_position = cp + Vector3(-4.6, 2.0, 5.6)
	cam.look_at(cp + Vector3(-0.8, 1.0, 0), Vector3.UP)
	await _attendre(4)
	await _photo("village_puits")

func _crypte() -> void:
	for i in 5:
		await physics_frame
	var t = m.tertre
	t._passer(true)
	var t_max := Time.get_ticks_msec() + 30000
	while not t.dedans and Time.get_ticks_msec() < t_max:
		await process_frame
	await create_timer(1.6, true, false, true).timeout
	print("CRYPTE dedans=", t.dedans)
	var c: Node3D = t.crypte
	j.global_position = c.to_global(Vector3(0.0, 0.1, -21.0))
	j.velocity = Vector3.ZERO
	if j.mains.get("torche_lumiere") != null:
		j.mains.torche_lumiere.visible = true
	for k in 20:
		t._gerer_zones()
		await physics_frame
	for id in m.draugrs.keys():
		var d = m.draugrs[id]
		if is_instance_valid(d):
			d.visible = false
			d.process_mode = Node.PROCESS_MODE_DISABLED
			d.global_position += Vector3(0, -50, 0)
	var lacet := c.global_rotation.y
	var face := Basis(Vector3.UP, lacet).z
	var lat := Basis(Vector3.UP, lacet).x
	# même emplacement (vestibule, z -27) pour les deux groupes, photographiés l'un après l'autre : garde de référence à gauche,
	# puis draugr guerrier + archer draugr ; ensuite squelette Tripo + archer squelette (ancien corps)
	var defs := [["draugr_guerrier", "guerrier", {}], ["draugr_archer", "sbire", {"archer": true}],
		["squelette", "squelette", {"variante": "epee"}], ["squelette_archer", "squelette_archer", {}]]
	var cibles := {}
	for d0: Array in defs:
		var opts: Dictionary = (d0[2] as Dictionary).duplicate()
		opts["ident"] = "palette_" + String(d0[0])
		opts["dort"] = false
		cibles[d0[0]] = m.creer_draugr(String(d0[1]), c.to_global(Vector3(0.0, -40.0, -27.0)), lacet, false, opts)
	var g := _garde_ref(m)
	await _attendre(20)
	for k: String in cibles:
		_figer(cibles[k], "Pistol_Aim_Neutral" if k.ends_with("archer") else "Sword_Idle")
	g.global_position = c.to_global(Vector3(-1.7, 0.05, -27.0))
	g.global_rotation.y = lacet
	_nouvelle_camera()
	var lum := OmniLight3D.new()      # torche d'appoint (même réglage que capture_integration_tripo)
	lum.omni_range = 9.0
	lum.light_energy = 1.6
	lum.light_color = Color(1.0, 0.78, 0.55)
	m.add_child(lum)
	for groupe: Array in [["crypte_draugrs", "draugr_guerrier", "draugr_archer"], ["crypte_squelettes", "squelette", "squelette_archer"]]:
		for k: String in cibles:
			(cibles[k] as Node3D).global_position = c.to_global(Vector3(0.0, -40.0, -27.0))
		var a1: Node3D = cibles[groupe[1]]
		var a2: Node3D = cibles[groupe[2]]
		a1.global_position = c.to_global(Vector3(0.0, 0.05, -27.0))
		a2.global_position = c.to_global(Vector3(1.7, 0.05, -27.0))
		a1.global_rotation.y = lacet
		a2.global_rotation.y = lacet
		await _attendre(10)
		for p: Array in [[String(groupe[0]), Vector3(0.0, 0.05, -27.0), 4.6], [String(groupe[0]) + "_gros", Vector3(0.6, 0.05, -27.0), 2.4]]:
			var cible: Vector3 = c.to_global(p[1])
			cam.global_position = cible + face * float(p[2]) + Vector3(0, 1.45, 0) + lat * 0.3
			cam.look_at(cible + Vector3(0, 1.0, 0), Vector3.UP)
			lum.global_position = cam.global_position + Vector3(0, 0.6, 0)
			await _attendre(4)
			await _photo(String(p[0]))

func _inter(nom: String) -> Node3D:
	for n in m.find_children("*", "Node3D", true, false):
		if n.get("verbe") != null and n.get("nom") == nom:
			return n
	return null

func _grotte() -> void:
	for i in 5:
		await physics_frame
	var a: Node3D = m.grotte_acces
	a.attendre_exterieur()
	await _attendre(6)
	j.global_position = a.porte_dehors + Vector3(0, 0.5, 0)
	await _attendre(10)
	var bouche := _inter("Grotte des bandits")
	if bouche == null:
		print("ECHEC bouche de la grotte introuvable")
		return
	m.dialogue.inviter(bouche)
	bouche.parler()
	var t0 := Time.get_ticks_msec()
	while not a.dedans and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
	await _attendre(40)
	var e: CharacterBody3D = null
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		e = a.jeu.ennemis.get("bandit_4")
		if e != null and is_instance_valid(e):
			break
		await physics_frame
	if e == null:
		print("ECHEC gobelin introuvable")
		return
	var dirj: Vector3 = j.global_position - e.global_position
	dirj.y = 0.0
	dirj = dirj.normalized()
	var lat := Vector3(-dirj.z, 0, dirj.x)
	_figer(e, "Sword_Idle")
	e.global_rotation.y = atan2(dirj.x, dirj.z)
	var g := _garde_ref(e.get_parent() as Node3D)
	g.global_position = e.global_position + lat * 1.3
	g.global_rotation.y = atan2(dirj.x, dirj.z)
	j.global_position = e.global_position + dirj * 8.0 + Vector3(0, 0.1, 0)
	_nouvelle_camera()
	var lum := OmniLight3D.new()      # torche du joueur, tenue près de la caméra
	lum.omni_range = 9.0
	lum.light_energy = 1.6
	lum.light_color = Color(1.0, 0.78, 0.55)
	m.add_child(lum)
	await _attendre(10)
	var mil := e.global_position + lat * 0.65
	for p: Array in [["grotte_gobelin", 3.6], ["grotte_gobelin_gros", 2.0]]:
		var cible: Vector3 = mil if p[0] == "grotte_gobelin" else e.global_position
		cam.global_position = cible + dirj * float(p[1]) + Vector3(0, 1.3, 0) - lat * 0.3
		cam.look_at(cible + Vector3(0, 0.8 if p[0] == "grotte_gobelin" else 0.6, 0), Vector3.UP)
		lum.global_position = cam.global_position + Vector3(0, 0.5, 0)
		await _attendre(4)
		await _photo(String(p[0]))
