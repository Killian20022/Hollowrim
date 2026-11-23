extends SceneTree
## FILM des IMPACTS D'OBJETS LANCÉS (ImpactsLances) : salle de pierre bâtie dans scenes/test_combat.tscn, caméra à hauteur d'yeux,
## objets jetés par le lanceur de test (outils/test_impacts_lances.gd, jeter) depuis la main droite. FENÊTRE hors écran (godot_slot.sh) :
##   godot --path . --write-movie <x.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/video_impacts_lances.gd -- --nouvelle
##         [--sortie=<dossier des captures>] [--plans=bandit,traverse,tonneau,squelette] [--sans-ralenti]
## Plans : épée plantée dans un bandit ; épée qui traverse un draugr et se fiche au mur ; tonneau qui renverse un bandit ; épée dans
## un squelette qui se disloque. Ralenti à l'impact (×0,3, pas physiques resserrés : pas d'à-coups) ; captures rapprochées PNG.

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")
const LANCEUR := preload("res://outils/test_impacts_lances.gd")

var s: Node3D
var cam: Camera3D
var sortie := ""
var ralenti := true
## --vues : vues fixes rapprochées en plus (temps figé : à lancer SANS --write-movie, elles feraient des sauts dans le film).
var vues := false

func _vue(nom: String) -> bool:
	return nom.ends_with("_profil") or nom.ends_with("_face") or nom.ends_with("_cote") or nom.ends_with("_dessus")
var _n := 0
var _cam_de := Transform3D.IDENTITY
var _cam_vers := Transform3D.IDENTITY
var _cam_t := 0.0
var _cam_duree := 0.0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		var dt := 1.0 / 30.0 * Engine.time_scale
		t += dt
		_bouger_camera(dt)

func _bouger_camera(dt: float) -> void:
	if _cam_duree <= 0.0:
		return
	_cam_t = minf(_cam_t + dt, _cam_duree)
	var k := smoothstep(0.0, 1.0, _cam_t / _cam_duree)
	cam.global_transform = _cam_de.interpolate_with(_cam_vers, k)

func _camera(pos: Vector3, regard: Vector3) -> void:
	_cam_duree = 0.0
	cam.global_transform = Transform3D(Basis.looking_at(regard - pos, Vector3.UP), pos)

func _travelling(pos: Vector3, regard: Vector3, duree: float) -> void:
	_cam_de = cam.global_transform
	_cam_vers = Transform3D(Basis.looking_at(regard - pos, Vector3.UP), pos)
	_cam_t = 0.0
	_cam_duree = duree

func _temps(echelle: float) -> void:
	if not ralenti:
		return
	Engine.time_scale = echelle
	Engine.physics_ticks_per_second = int(round(60.0 / echelle))

func _capture(nom: String) -> void:
	if sortie == "" or (_vue(nom) and not vues):
		return
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(sortie.path_join(nom + ".png"))
	print("capture ", nom)

func _ennemi(genre: String, pos: Vector3, vie: float, lacet := 0.0) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "film_lance_%d" % _n
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = vie
	d.vie_max = maxf(vie, 80.0)
	d.combat.profil.chance_blocage = 0.0
	# reste sur place (il encaisse, titube, tombe, se tourne) : pas de course vers le joueur hors champ
	d._marche = 0.0
	d._marche_proche = 0.0
	d._course = 0.0
	return d

## Salle de pierre : dalles, mur du fond (face à z = -7), murs latéraux, plafond, torches chaudes, pénombre.
## Faces visibles en QuadMesh (UV 0..1 par face) : textures de crypte de 4 m (CrypteTextures), à l'échelle.
func _salle() -> void:
	var t_mur := ImageTexture.create_from_image(CrypteTextures.mur_image(0))
	var dal: Variant = CrypteTextures.dalle_paire(3)[0]
	var t_dal: Texture2D = dal if dal is Texture2D else ImageTexture.create_from_image(dal as Image)
	# sol (12 x 14), mur du fond, murs latéraux, plafond ; solides en boîtes, visuels en quads tournés vers la salle
	_paroi(Vector3(0, -0.03, -2.0), Vector3(12, 0.1, 14), t_dal, Vector3(0, 0.02, -2.0), Vector3.UP, Vector2(12, 14))   # 2 cm au-dessus du sol de la scène (sinon z-fighting)
	_paroi(Vector3(0, 2.0, -7.15), Vector3(12, 4.0, 0.3), t_mur, Vector3(0, 2.0, -7.0), Vector3.BACK, Vector2(12, 4))
	_paroi(Vector3(-4.6, 2.0, -2.0), Vector3(0.3, 4.0, 14), t_mur, Vector3(-4.45, 2.0, -2.0), Vector3.RIGHT, Vector2(14, 4))
	_paroi(Vector3(4.6, 2.0, -2.0), Vector3(0.3, 4.0, 14), t_mur, Vector3(4.45, 2.0, -2.0), Vector3.LEFT, Vector2(14, 4))
	_paroi(Vector3(0, 4.1, -2.0), Vector3(12, 0.2, 14), t_mur, Vector3(0, 4.0, -2.0), Vector3.DOWN, Vector2(12, 14))
	for p in [Vector3(-4.3, 2.3, -5.0), Vector3(4.3, 2.3, -5.0), Vector3(-4.3, 2.3, -0.5), Vector3(4.3, 2.3, -0.5), Vector3(1.6, 2.5, -6.85)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.32)
		l.light_energy = 2.0
		l.omni_range = 7.0
		l.shadow_enabled = false   # ombres des torches : bandes de pixels bruités au sol (rendu PS1) ; la pénombre suffit
		s.add_child(l)
		l.global_position = p
		var flamme := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.12
		flamme.mesh = sm
		flamme.material_override = Palette.lueur(Color(2.2, 1.3, 0.5))
		s.add_child(flamme)
		flamme.global_position = p
	s.soleil.light_energy = 0.0
	s.env.ambient_light_color = Color(0.36, 0.36, 0.42)
	s.env.ambient_light_energy = 0.7
	s.env.background_color = Color(0.02, 0.02, 0.03)
	s.env.fog_enabled = true
	s.env.fog_light_color = Color(0.22, 0.18, 0.15)
	s.env.fog_density = 0.03
	# le joueur (hors champ) n'éclaire rien : sa torche portait une ombre au sol devant la caméra
	for l in s.joueur.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = false

func _paroi(p: Vector3, taille: Vector3, tex: Texture2D, face: Vector3, n: Vector3, dim: Vector2) -> void:
	var b := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	f.shape = bs
	b.add_child(f)
	s.add_child(b)
	b.global_position = p
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = dim
	mi.mesh = q
	mi.material_override = Palette.materiau(tex, dim / 4.0)
	s.add_child(mi)
	var haut := Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD
	# QuadMesh : face vers +Z local
	mi.global_transform = Transform3D(Basis.looking_at(-n, haut), face)

## Efface le sang et les os des plans précédents (chaque plan repart d'un sol propre).
func _effacer_sang() -> void:
	var g := get_first_node_in_group("gestion_sang")
	if g != null:
		for c in g.get_children():
			c.queue_free()
		g.set_meta("traces", [])

func _main() -> Vector3:
	# main droite du lanceur : sous et à droite de l'œil, un peu devant
	return cam.global_transform * Vector3(0.32, -0.28, -0.55)

func _go() -> void:
	sortie = _arg("sortie", "")
	ralenti = _arg("sans-ralenti") == ""
	vues = _arg("vues") != ""
	if sortie != "":
		DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": "", "nuit": ""}
	root.add_child(s)
	current_scene = s
	for i in 20:
		await process_frame
	s.mannequin.position = Vector3(30, 0, 30)
	s.mur.position = Vector3(30, 1.3, 30)
	s.placer_joueur(Vector3(15, 0, 15), 180.0)
	s.hud.visible = false
	Sang.niveau_force = 2
	_salle()
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	s.add_child(cam)
	cam.make_current()
	var plans := _arg("plans", "bandit,traverse,tonneau,squelette").split(",")
	for p in plans:
		match p:
			"bandit":
				await _plan_bandit()
			"traverse":
				await _plan_traverse()
			"tonneau":
				await _plan_tonneau()
			"squelette":
				await _plan_squelette()
	_temps(1.0)
	quit(0)

func _nettoyer(noeuds: Array) -> void:
	for n in noeuds:
		if is_instance_valid(n):
			n.queue_free()
	for n in s.get_children():
		if n is RigidBody3D or String(n.name).begins_with("Butin") or n.get_script() == preload("res://scripts/butin.gd"):
			n.queue_free()
	_effacer_sang()
	await _attendre(0.1)

## Jette `quoi` de la main droite vers `cible`, ralentit juste avant l'impact.
func _jeter(quoi: Variant, cible: Vector3, v: float, ech := 0.3, avant := 0.12, duree_ralenti := 1.1) -> RigidBody3D:
	var de := _main()
	var o: RigidBody3D = LANCEUR.jeter(s, quoi, de, cible, v, s.joueur)
	var t_vol := de.distance_to(cible) / v
	await _attendre(maxf(t_vol - avant, 0.0))
	_temps(ech)
	await _attendre(duree_ralenti * ech)
	_temps(1.0)
	return o

func _plan_bandit() -> void:
	print("DEBUT_PLANS image ", Engine.get_frames_drawn())
	var b := _ennemi("bandit", Vector3(0.2, 0, -2.8), 400.0)
	_camera(Vector3(0.0, 1.62, 0.2), Vector3(0.2, 1.25, -2.8))
	await _attendre(0.9)
	var o := await _jeter("epee_soldat", b.global_position + Vector3(0, 1.3, 0), 17.0)
	await _attendre(0.5)
	_travelling(Vector3(-0.9, 1.45, -1.5), b.global_position + Vector3(0, 1.15, 0), 1.6)
	await _attendre(1.8)
	await _capture("bandit_plantee_proche")
	# vues fixes rapprochées (captures seulement, hors film : le temps est figé pendant les prises)
	var garde := cam.global_transform
	var c := b.global_position + Vector3(0, 1.15, 0)
	if vues:
		await _vues_bandit(c)
	cam.global_transform = garde
	await _nettoyer([b, o])

func _vues_bandit(c: Vector3) -> void:
	Engine.time_scale = 0.0
	_camera(c + Vector3(1.3, 0.1, 0.0), c)
	await _capture("bandit_plantee_profil")
	_camera(c + Vector3(-0.5, 0.15, 1.1), c)
	await _capture("bandit_plantee_face")
	Engine.time_scale = 1.0

func _plan_traverse() -> void:
	var d := _ennemi("guerrier", Vector3(0.5, 0, -5.0), 20.0)
	_camera(Vector3(-0.6, 1.62, -2.0), Vector3(0.4, 1.25, -5.4))
	await _attendre(0.9)
	var o := await _jeter("epee_soldat", d.global_position + Vector3(0, 1.25, 0), 30.0, 0.25, 0.1, 1.6)
	await _attendre(0.8)
	var mur := o.global_position
	var ab := ImpactsLances.axe_monde(o, o.donnees_arme())
	var pointe: Vector3 = ab[1]
	_travelling(Vector3(pointe.x - 0.8, pointe.y + 0.05, pointe.z + 1.6), pointe + Vector3(0, -0.05, 0.3), 1.6)
	await _attendre(1.9)
	await _capture("traverse_mur_proche")
	if vues:
		Engine.time_scale = 0.0
		_camera(pointe + Vector3(0.9, 0.05, 0.6), pointe + Vector3(0, 0, 0.25))
		await _capture("traverse_mur_cote")
		Engine.time_scale = 1.0
	print("traverse : ", ImpactsLances.dernier.get("issue", "?"), " plantee=", ImpactsLances.plantee(o))
	await _nettoyer([d, o])

func _tonneau() -> RigidBody3D:
	var t := RigidBody3D.new()
	t.mass = 15.0
	t.name = "TonneauFilm"
	var mi := PropsQuat.instancier("pq_tonneau", "interieur")
	var f := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.32
	cyl.height = 0.85
	f.shape = cyl
	t.add_child(f)
	if mi != null:
		var bb := mi.get_aabb()
		mi.position = -bb.get_center()
		t.add_child(mi)
	t.angular_damp = 0.5
	return t

func _plan_tonneau() -> void:
	var b := _ennemi("bandit", Vector3(-0.2, 0, -3.0), 400.0)
	_camera(Vector3(0.9, 1.7, 0.3), Vector3(-0.3, 0.9, -3.2))
	await _attendre(0.8)
	var t := _tonneau()
	var o := await _jeter(t, b.global_position + Vector3(0, 1.15, 0), 13.0, 0.35, 0.1, 1.4)
	await _attendre(2.2)
	await _nettoyer([b, o])

func _plan_squelette() -> void:
	var q := _ennemi("squelette", Vector3(0.1, 0, -2.9), 10.0)
	_camera(Vector3(0.0, 1.62, 0.2), Vector3(0.1, 1.2, -2.9))
	await _attendre(0.9)
	var o := await _jeter("epee_soldat", q.global_position + Vector3(0, 1.2, 0), 18.0, 0.3, 0.1, 1.4)
	await _attendre(1.0)
	_travelling(Vector3(-0.9, 1.2, -1.6), q.global_position + Vector3(0, 0.3, 0), 1.4)
	await _attendre(1.6)
	await _capture("squelette_proche")
	if vues:
		Engine.time_scale = 0.0
		var os_c := q.global_position + Vector3(0, 0.3, 0)
		_camera(os_c + Vector3(0.9, 0.7, 0.6), os_c)
		await _capture("squelette_dessus")
		Engine.time_scale = 1.0
	await _nettoyer([q, o])
