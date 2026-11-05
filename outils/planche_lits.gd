extends SceneTree
## Lot sommeil : captures des lits en jeu (fenêtre hors écran via godot_slot.sh).
##   godot --path . --resolution 960x540 --script res://outils/planche_lits.gd -- --nouvelle --sans-mains --paisible --sortie=<dossier> [--plans] [--lits] [--fenetre] [--avant]
##   --plans   : plan de chaque intérieur vu d'en haut (caméra orthogonale sous le plafond ; haut de l'image = fond -Z, droite = +X)
##   --lits    : chaque lit (Sommeil.lits) vu de trois quarts, de nuit, intérieur allumé
##   --fenetre : la fenêtre « Dormir » ouverte devant un lit
##   --avant   : (base d'avant le lot) vues de trois quarts aux mêmes emplacements, d'après outils/poses_lits.txt
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var cam: Camera3D
var sortie := "user://planche_lits"

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return ""

func _a(nom: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + nom)

func _go() -> void:
	if _arg("sortie") != "":
		sortie = _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	for i in 150:
		await process_frame
	if m.get("hud") != null:
		m.hud.visible = false
	m.joueur.mains.visible = false
	m.joueur.vie = 1.0e6
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 21.0
	m.cycle._process(0.0)
	cam = Camera3D.new()
	m.add_child(cam)
	cam.current = true
	if _a("plans"):
		await _plans()
	if _a("lits"):
		await _lits()
	if _a("avant"):
		await _avant()
	if _a("fenetre"):
		await _fenetre()
	print("PLANCHE finie")
	quit(0)

func _shot(nom: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom)

## Joueur loin (la caméra suit la nôtre ; les intérieurs se règlent sur la caméra active).
func _ecarter_joueur(p: Vector3) -> void:
	m.joueur.global_position = p + Vector3(0, -30, 0)
	m.joueur.set_physics_process(false)

func _plans() -> void:
	for id in ["halle", "sigrun", "chasseurs", "grima", "forge"]:
		var ip: Interieur = m.village.interieur(id)
		if ip == null:
			continue
		var taille := maxf(ip.demi.x * 2.0 + 0.4, (ip.demi.y * 2.0 + 0.4) * 16.0 / 9.0)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.size = taille
		cam.near = 0.05
		cam.far = 10.0
		var haut := ip.to_global(Vector3(0, 2.2, 0))
		var arriere := ip.global_transform.basis * Vector3(0, 0, -1)
		cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, arriere), haut)
		_ecarter_joueur(haut)
		await _shot("plan_" + id)
		print("PLAN %s taille=%.2f demi=%s" % [id, taille, str(ip.demi)])

func _lits() -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 60.0
	var sm: Node = m.get("sommeil")
	if sm == null:
		return
	var k := 0
	for l: Lit in sm.lits:
		var c: float = l.cotes_libres[0]
		var xf := l.global_transform
		var oeil := xf * Vector3(c * (l.largeur * 0.5 + 1.25), 1.45, -l.longueur * 0.5 - 0.6)
		var vise := xf * Vector3(0, 0.45, 0.1)
		cam.global_transform = Transform3D(Basis.looking_at(vise - oeil, Vector3.UP), oeil)
		_ecarter_joueur(oeil)
		await _shot("lit_%02d_%s_%s" % [k, l.foyer, l.proprietaire.replace(",", "+") if l.proprietaire != "" else "libre"])
		print("LIT %d foyer=%s prop=%s places=%d pos=%s" % [k, l.foyer, l.proprietaire, l.places(), str(l.global_position)])
		k += 1

## Base d'avant le lot : poses « nom bat x z lacet » (repère du bâtiment) lues dans outils/poses_lits.txt.
func _avant() -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 62.0
	cam.near = 0.05
	var f := FileAccess.get_file_as_string("res://outils/poses_lits.txt")
	for ligne in f.split("\n"):
		var p := ligne.strip_edges().split(" ", false)
		if p.size() < 7 or p[0].begins_with("#"):
			continue
		var ip: Interieur = m.village.interieur(p[1])
		if ip == null:
			continue
		var oeil := ip.to_global(Vector3(float(p[2]), float(p[3]), float(p[4])))
		var vise := ip.to_global(Vector3(float(p[5]), 0.87, float(p[6])))
		cam.global_transform = Transform3D(Basis.looking_at(vise - oeil, Vector3.UP), oeil)
		_ecarter_joueur(oeil)
		await _shot("avant_" + p[0])

func _fenetre() -> void:
	var sm: Node = m.get("sommeil")
	if sm == null or sm.lits.is_empty():
		return
	var l: Lit = sm.lits[0]
	for x: Lit in sm.lits:
		if x.foyer == "sigrun":
			l = x
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 62.0
	var xf := l.global_transform
	var oeil := xf * Vector3(l.cotes_libres[0] * 1.3, 1.6, -1.6)
	var vise := xf * Vector3(0, 0.5, 0.2)
	cam.global_transform = Transform3D(Basis.looking_at(vise - oeil, Vector3.UP), oeil)
	m.joueur.global_position = Vector3(oeil.x, oeil.y - 1.5, oeil.z)
	m.hud.visible = true
	sm.demander("dormir", l)
	await _shot("fenetre_dormir")
	sm.fenetre.fermer()
	sm.demander("attendre")
	sm.fenetre.regler(3)
	await _shot("fenetre_attendre")
	sm.fenetre.fermer()
