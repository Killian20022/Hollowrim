extends SceneTree
## Intégration retours exe 5 : de nuit (23 h), les villageois sont-ils COUCHÉS dans leur lit des maisons ouvertes (intérieurs à la
## demande + Sommeil.scanner -> Vie.lits_poses) ? La caméra approche de chaque maison par dehors (comme le joueur), attend que
## l'intérieur se construise et que ses lits soient posés, puis entre et vise le lit. Pas de HUD.
##   godot --path . --resolution 960x540 --script res://outils/captures_couches.gd -- --nouvelle --sans-mains --paisible --sortie=<dossier> [--maisons=h1,h3,h5]
## Imprime « COUCHE <maison> lit=<i> occupants=[...] » et « DORMEURS <maison> ... » pour chaque maison.
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var cam: Camera3D
var sortie := "user://captures_couches"

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return ""

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _shot(nom: String) -> void:
	await _attendre(8)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

func _go() -> void:
	if _arg("sortie") != "":
		sortie = _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var maisons: PackedStringArray = (_arg("maisons") if _arg("maisons") != "" else "h1,h3,h5").split(",")
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	await _attendre(120)
	if m.get("hud") != null:
		m.hud.visible = false
	if m.get("dialogue") != null:
		m.dialogue.visible = false
	m.joueur.mains.visible = false
	m.joueur.vie = 1.0e6
	m.joueur.set_physics_process(false)
	cam = Camera3D.new()
	m.add_child(cam)
	cam.current = true
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 80.0
	# caméra loin du village pendant que la nuit tombe (aucun intérieur chargé)
	_poser(Vector3(0, 60, 400), Vector3(0, 0, 0))      # (joueur à 56 m de haut, loin : rien ne se charge)
	await _attendre(30)
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 23.0
	m.cycle._process(0.0)
	var vie: Vie = m.vie
	vie._heure_prec = -1.0
	vie.tick()
	await _attendre(60)
	for id in maisons:
		await _maison(id)
	print("CAPTURES finies")
	quit(0)

func _poser(oeil: Vector3, vise: Vector3) -> void:
	cam.global_transform = Transform3D(Basis.looking_at(vise - oeil, Vector3.UP), oeil)
	m.joueur.global_position = oeil + Vector3(0, -4, 0)      # sous le plancher, hors champ : Vie cache les dormeurs à plus de 16 m du joueur

func _maison(id: String) -> void:
	var ip: Interieur = m.village.interieur(id)
	if ip == null:
		print("COUCHE %s : pas d'intérieur" % id)
		return
	# approche par dehors, devant la porte (+Z local), à ~14 m : chargement à la demande dans un fil
	var dehors := ip.to_global(Vector3(0, 2.0, ip.demi.y + 14.0))
	_poser(dehors, ip.to_global(Vector3(0, 1.0, 0)))
	var t0 := Time.get_ticks_msec()
	while (not ip.construit or ip.en_cours) and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	await _attendre(150)          # Sommeil.scanner (toutes les secondes) pose les lits -> Vie.lits_poses
	var sm: Node = m.get("sommeil")
	var lits: Array = []
	for l: Lit in sm.lits:
		if is_instance_valid(l) and ip.dedans(ip.to_local(l.global_position), 0.2):
			lits.append(l)
	var dormeurs := []
	for c: Dictionary in m.vie.civils:
		var n: Node3D = c["n"]
		if String(c["f"].get("maison", "")) == id or (ip.habitants.has(String(c["id"]))):
			dormeurs.append("%s(mode=%s endormi=%s au_lit=%s seq=%s visible=%s)" % [c["id"], c["mode"], n.est_endormi(), n.au_lit(), n.get("seq"), n.visible])
	print("DORMEURS %s construit=%s lits=%d %s" % [id, ip.construit, lits.size(), str(dormeurs)])
	var k := 0
	for l: Lit in lits:
		var occ := []
		for o in l.occupants:
			occ.append(String(o.name) if o != null else "-")
		print("COUCHE %s lit=%d foyer=%s prop=%s occupants=%s" % [id, k, l.foyer, l.proprietaire, str(occ)])
		sm._regler_cotes(l)
		var c: float = l.cotes_libres[0] if not l.cotes_libres.is_empty() else 1.0
		var xf := l.global_transform
		var oeil := xf * Vector3(c * (l.largeur * 0.5 + 1.1), 1.5, -l.longueur * 0.5 - 0.5)
		if not ip.dedans(ip.to_local(oeil), -0.15):
			oeil = ip.to_global(Vector3(0, ip.sol_y + 1.5, 0))
		_poser(oeil, xf * Vector3(0, 0.45, 0.1))
		await _attendre(120)      # un tick de Vie (niveau de détail des dormeurs, d'après le joueur)
		var vus := []
		for o in l.occupants:
			if o != null and is_instance_valid(o):
				var an: AnimationPlayer = o.get("anim")
				var pi: Variant = o.get("_pieds")
				var te: Variant = o.get("_tete")
				vus.append("%s visible=%s seq=%s anim=%s@%.2f pieds=%s tete=%s type=%s" % [o.get("id_vie") if o.get("id_vie") != null else o.name, o.visible, o.get("seq"),
					an.current_animation if an != null else "?", an.current_animation_position if an != null else -1.0,
					pi.get("actif") if pi != null else "-", (te as SkeletonModifier3D).active if te != null else "-", o.get_script().resource_path.get_file()])
		print("VUS %s lit=%d %s" % [id, k, str(vus)])
		await _shot("%s_lit%d" % [id, k])
		var dessus := xf * Vector3(0.0, 2.3, -0.05)
		cam.global_transform = Transform3D(Basis.looking_at((xf * Vector3(0, 0.4, 0.0)) - dessus, xf.basis.z), dessus)
		await _shot("%s_lit%d_dessus" % [id, k])
		k += 1
