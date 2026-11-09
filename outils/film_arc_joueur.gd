extends SceneTree
## Film de l'ARC DU JOUEUR (fenêtre hors écran, via godot_slot.sh) :
##   godot --path . --resolution 1280x720 --fixed-fps 60 --disable-vsync --script res://outils/film_arc_joueur.gd -- --vue=1|3 --sortie=<dossier>
##        [--mode=poses]   (images fixes : repos, mi-tension, pleine tension, lâcher, rechargement)
## Images f_00000.png… (une sur 2 : 30 i/s). Décor : mannequin à 8 m, mur de planches à 14 m, palissade fine (3 cm) à 22 m.
## Scénario : arc au repos, bandage lent et tir plein dans le mannequin, tir court qui retombe au sol, tir moyen, tirs pleins dans le
## mur et la palissade, tension tenue (tremblement), puis on s'approche des flèches fichées. Trace de trajectoire (pointillés) et
## « + » au centre de l'écran : aides de lecture du FILM seulement (pas en jeu). --vue=3 : caméra d'observation derrière l'épaule droite.

const SCENE := preload("res://scenes/test_combat.tscn")
var s: Node3D
var j: CharacterBody3D
var arc: ArcJoueur
var sortie := ""
var vue := "1"
var mode := "film"
var legende: Label
var cam: Camera3D
var n := 0
var _imp := false
var _traces: Array = []   # [projectile, ImmediateMesh, points, compteur]
var _cible_vise := Vector3.ZERO
var _dernier := ""
var _plan := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _boite(p: Vector3, taille: Vector3, m: Material) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = p
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	f.shape = bs
	b.add_child(f)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	b.add_child(mi)
	s.add_child(b)
	return b

func _go() -> void:
	sortie = _arg("sortie", "user://film_arc")
	vue = _arg("vue", "1")
	mode = _arg("mode", "film")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	arc = j.arc
	arc.souris_reelle = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(-1.2, 0, -8)
	s.mur.position = Vector3(30, 1.3, 30)   # mur de la scène hors champ
	var planches := Palette.materiau(Palette.tex("planches_film", Palette.PLANCHES, 4, 0.5), Vector2(3, 2))
	_boite(Vector3(0.6, 1.25, -14.0), Vector3(3.4, 2.5, 0.2), planches)
	_boite(Vector3(-0.6, 1.0, -22.0), Vector3(4.0, 2.0, 0.03), planches)   # palissade FINE (3 cm)
	var env: Environment = s.env
	env.background_color = Color(0.30, 0.27, 0.31)
	env.ambient_light_color = Color(0.52, 0.48, 0.56)
	env.ambient_light_energy = 0.45
	var so: DirectionalLight3D = s.soleil
	so.basis = Basis.looking_at(Vector3(-0.35, -0.45, -0.8), Vector3.UP)
	so.light_color = Color(1.0, 0.8, 0.62)
	so.light_energy = 0.75
	for c in root.find_children("*", "CanvasLayer", true, false):
		for k in c.get_children():
			var garder: bool = k is ColorRect and (k as ColorRect).material is ShaderMaterial
			if k is CanvasItem and not garder:
				(k as CanvasItem).visible = false
	var cl := CanvasLayer.new()
	cl.layer = 50
	root.add_child(cl)
	legende = Label.new()
	legende.add_theme_font_override("font", Palette.police())
	legende.add_theme_font_size_override("font_size", 26)
	legende.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	legende.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03))
	legende.add_theme_constant_override("outline_size", 8)
	legende.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	legende.offset_top = -66.0
	legende.offset_left = 20.0
	cl.add_child(legende)
	var croix := Label.new()
	croix.text = "+"
	croix.add_theme_font_size_override("font_size", 22)
	croix.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	croix.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	croix.offset_left = -6
	croix.offset_top = -14
	cl.add_child(croix)
	arc.tir.connect(_sur_tir)
	j.inventaire.ajouter("arc_chasseur", 1)
	j.inventaire.ajouter("fleche", 14)
	s.placer_joueur(Vector3(0.0, 0, 3.0), 0.0)
	j.mains.pas_manuel = false
	for i in 40:
		await process_frame
	if vue == "3":
		j.basculer_vue(true)
		cam = Camera3D.new()
		cam.fov = 58.0
		s.add_child(cam)
		# plan « épaule » (derrière l'épaule droite, comme la vue de jeu, un peu plus large) puis plan latéral
		cam.current = true
		_plan = _arg("cam", "epaule")
		croix.visible = false
	arc.equiper()
	if mode == "poses":
		await _poses()
		quit(0)
		return
	await _viser(Vector3(-1.2, 1.25, -8))
	await _filmer(36, "Arc au repos : flèche encochée")
	await _tir(1.6, "Bandage lent : la corde vient à la joue")
	await _filmer(55, "")
	await _viser(Vector3(0.6, 1.3, -14.0))
	await _filmer(10, "")
	await _tir(0.22, "Tir court (faible tension) : la flèche retombe")
	await _filmer(50, "")
	await _tir(0.5, "Tir moyen")
	await _filmer(50, "")
	await _viser(Vector3(0.9, 1.6, -14.0))
	await _tir(1.3, "Tir plein (tendu) dans le mur à 14 m")
	await _filmer(48, "")
	if vue == "3":
		_plan = "lateral"   # la courbe des trajectoires vue de côté
	await _viser(Vector3(-0.5, 1.2, -22.0))
	await _filmer(12, "")
	await _tir(1.3, "Tir plein : palissade fine à 22 m (pas de traversée)")
	await _filmer(55, "")
	await _viser(Vector3(0.2, 1.1, -14.0))
	await _tir(4.6, "Tension tenue trop longtemps : les bras tremblent")
	await _filmer(45, "")
	await _approcher(Vector3(0.2, 0, -9.5), 110, "On s'approche des flèches fichées")
	await _filmer(30, "Flèches fichées : %d au sac" % arc.fleches())
	print("FILM %d images, flèches %d" % [n, arc.fleches()])
	quit(0)

func _poses() -> void:
	await _viser(Vector3(0.6, 1.3, -14.0))
	await _attendre(30)
	await _photo("repos")
	arc.appuyer()
	await _attendre(16)
	await _photo("mi_tension")
	await _attendre(60)
	await _photo("pleine")
	if vue == "3":
		# contrôle de la main de corde à pleine tension (le corps tourné de profil, épaule gauche vers la cible) :
		# profil droit de la tête (caméra derrière), 3/4 dos, face (devant le torse) et dessus
		var p0 := _plan
		for pl in ["profil", "dos34", "face", "dessus"]:
			_plan = pl
			await _photo("pleine_" + pl)
		_plan = p0
		await _cadre_attente()
	arc.relacher()
	await _attendre(3)
	await _photo("lacher")
	await _attendre(16)
	await _photo("rechargement")
	for k in 4:
		await _attendre(7)
		await _photo("rechargement_%d" % (k + 1))
	await _attendre(40)
	await _photo("repos_apres")
	await _attendre(20)

func _cadre_attente() -> void:
	_cadre()
	await process_frame

func _attendre(k: int) -> void:
	for i in k:
		_cadre()
		_maj_traces()
		await process_frame

func _photo(nom: String) -> void:
	_cadre()
	await process_frame
	if not j.troisieme:
		var c: Camera3D = j.camera
		var inv := c.global_transform.affine_inverse()
		var sq: Skeleton3D = arc._sq
		var mg := inv * (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_l")).origin)
		var md := inv * (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin)
		print("POSE %s main_g %s main_d %s poignee %s encoche %s pointe %s" % [nom, mg, md, inv * arc._vm.global_position, inv * arc._vm.encoche_monde(), inv * arc._vm.pointe()])
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(sortie.path_join("pose_%s_v%s.png" % [nom, vue]))

## Vise un point : la caméra de visée (1re : la tête ; 3e : caméra derrière l'épaule) amène le centre de l'écran sur `c`.
func _viser(c: Vector3) -> void:
	_cible_vise = c
	for it in 6:
		var camv: Camera3D = arc._camera_visee()
		var d: Vector3 = c - camv.global_position
		var lacet := atan2(-d.x, -d.z)
		var tang := atan2(d.y, Vector2(d.x, d.z).length())
		var fwd := -camv.global_transform.basis.z
		var l_act := atan2(-fwd.x, -fwd.z)
		var t_act := asin(clampf(fwd.y, -1.0, 1.0))
		j.rotation.y += wrapf(lacet - l_act, -PI, PI)
		j.tete.rotation.x = clampf(j.tete.rotation.x + (tang - t_act), -1.2, 1.2)
		await process_frame
		await process_frame

func _cadre() -> void:
	if cam != null and _plan == "epaule":
		var be: Basis = Basis(Vector3.UP, j.rotation.y)
		cam.global_position = j.global_position + be * Vector3(1.4, 1.9, 2.6)
		cam.look_at(j.global_position + be * Vector3(-0.5, 1.35, -5.0))
	elif cam != null and _plan in ["profil", "dos34", "face", "dessus"]:
		var bp: Basis = Basis(Vector3.UP, j.rotation.y)
		var pos: Vector3 = {"profil": Vector3(0.05, 1.55, 1.5), "dos34": Vector3(-1.1, 1.85, 1.2), "face": Vector3(1.5, 1.5, -0.25), "dessus": Vector3(0.15, 3.0, 0.05)}[_plan]
		cam.global_position = j.global_position + bp * pos
		cam.look_at(j.global_position + bp * Vector3(0.0, 1.45, -0.25), bp * Vector3(0, 0, -1) if _plan == "dessus" else Vector3.UP)
	elif cam != null and cam.current:
		# plan latéral (côté droit de l'archer, un peu devant) : l'archer à gauche, les flèches filent vers la droite
		var b: Basis = Basis(Vector3.UP, j.rotation.y)
		cam.global_position = j.global_position + b * Vector3(2.7, 1.4, -1.9)
		cam.look_at(j.global_position + b * Vector3(0.0, 1.2, -1.45))

func _sur_tir(info: Dictionary) -> void:
	var p: Projectile = info["projectile"]
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.4)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(mi)
	_traces.append([p, im, [], 0])
	p.touche.connect(func(_r: String) -> void: _dernier = "touché : %d dégâts (impact à %.0f m/s)" % [roundi(p.degats_impact), p.vitesse_impact])
	p.plante.connect(func(_pos: Vector3) -> void: _dernier = "fichée (impact à %.0f m/s)" % p.vitesse_impact)

func _maj_traces() -> void:
	for t in _traces:
		var p: Variant = t[0]
		var pts: Array = t[2]
		if is_instance_valid(p) and not (p as Projectile).plantee:
			t[3] += 1
			pts.append((p as Projectile).global_position)
		var im: ImmediateMesh = t[1]
		im.clear_surfaces()
		if pts.size() < 2:
			continue
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(0, pts.size() - 1, 2):
			im.surface_add_vertex(pts[i])
			im.surface_add_vertex(pts[i + 1])
		im.surface_end()

func _texte_etat(texte: String) -> String:
	var e := "%s  [tension %d %%  flèches %d]" % [texte, roundi(arc.tension * 100.0), arc.fleches()]
	if arc.tremblement > 0.05:
		e += "  tremblement %d %%" % roundi(arc.tremblement * 100.0)
	return e

func _tir(duree: float, texte: String) -> void:
	await _viser(_cible_vise)
	_dernier = ""
	arc.appuyer()
	for i in roundi(duree * 60.0):
		legende.text = _texte_etat(texte)
		await _filmer(1, "")
	arc.relacher()
	legende.text = texte

func _approcher(p: Vector3, k: int, texte: String) -> void:
	var p0 := j.global_position
	legende.text = texte
	_dernier = ""
	for i in k:
		var u := smoothstep(0.0, 1.0, float(i) / k)
		j.global_position = p0.lerp(p, u)
		j.velocity = Vector3.ZERO
		j.rotation.y = lerp_angle(j.rotation.y, 0.25, 0.05)
		j.tete.rotation.x = lerpf(j.tete.rotation.x, -0.12, 0.05)
		await _filmer(1, "")

func _filmer(k: int, texte: String) -> void:
	if texte != "":
		legende.text = texte
	for i in k:
		_cadre()
		_maj_traces()
		if _dernier != "" and arc.etat != ArcJoueur.BANDE:
			legende.text = legende.text.get_slice("  —", 0) + "  — " + _dernier
		await process_frame
		_imp = not _imp
		if _imp:
			continue
		await RenderingServer.frame_post_draw
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.save_png(sortie.path_join("f_%05d.png" % n))
		n += 1
