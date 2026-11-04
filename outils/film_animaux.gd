extends SceneTree
## Films des animaux Quaternius EN JEU (gen/animaux, 2026-11-04), pour Movie Maker, jour (12 h), un plan de ~7 s par animal :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_animaux.gd -- --nouvelle --sans-mains [--seulement=cheval,vache]
## (fenêtre hors écran via godot_slot.sh). Chaque plan est annoncé par `SEGMENT <animal> <première image> <dernière image>` (découpe ffmpeg).
## La bête est prise à son poste (monde.BETES / DOMESTIQUES), son IA est coupée : le film la mène sur un cercle (repos, marche aux pieds
## justes, trot ou course, puis broute / mord) ; la caméra du joueur reste en place et la suit du regard. L'araignée est filmée dans la galerie
## de la mine (grotte). Le rendu est celui du jeu (shaders PS1, lumière, brume).

const SCENE := "res://scenes/foret_test.tscn"
## animal -> [ident, distance caméra, cap caméra° (0 = au sud +Z, 90 = à l'est +X), rayon du cercle, vitesse de course, hauteur de visée, hauteur de l'œil]
const S_ARAIGNEE := 69.0               # abscisse locale (branche A, galerie du retour de la mine)
const STUDIO := Vector2(38.0, 43.5)      # la place du village : plate, pavée, maisons au fond (les villageois sont écartés)
const PLANS := {
	"loup": ["loup_bois_a", 3.6, 60.0, 1.4, 3.2, 0.5, 0.95],
	"cerf": ["cerf_pre", 5.2, 60.0, 1.6, 3.2, 1.0, 1.5],
	"biche": ["biche_pre_a", 4.4, 60.0, 1.4, 3.0, 0.8, 1.3],
	"renard": ["renard_fermes", 2.1, 60.0, 0.8, 2.4, 0.3, 0.6],
	"araignee": ["araignee_film", 5.2, 0.0, 0.8, 2.0, 0.5, 1.0],
	"cheval": ["cheval_pre", 4.8, 60.0, 1.5, 3.0, 0.9, 1.5],
	"cheval_blanc": ["cheval_blanc_pre", 4.8, 60.0, 1.5, 3.0, 0.9, 1.5],
	"ane": ["ane_pre", 3.8, 60.0, 1.2, 2.6, 0.7, 1.2],
	"vache": ["vache_enclos_a", 4.2, 60.0, 1.3, 2.2, 0.7, 1.3],
	"taureau": ["taureau_enclos", 4.2, 60.0, 1.3, 2.2, 0.8, 1.3],
	"husky": ["husky_chasseurs", 2.2, 60.0, 0.8, 2.6, 0.35, 0.65],
}
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _image() -> int:
	return Engine.get_frames_drawn()

func _attendre(s: float) -> void:
	for i in int(s * 30.0):
		await process_frame
		if paused:
			paused = false

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _bete(id: String) -> Node3D:
	for g in ["faune", "ennemis"]:
		for n in get_nodes_in_group(g):
			if n.get("ident") == id:
				return n
	return null

## Les araignées de la mine (IA propre, apparaissent à l'approche) sont écartées : seule celle du film est filmée.
func _ecarter_araignees() -> void:
	for n in get_nodes_in_group("bete_quat"):
		if n.get("ident") != "araignee_film" and n.get("espece") == "araignee":
			n.set_physics_process(false)
			n.visible = false
			n.global_position = Vector3(0, -300, 0)

func _sol(p: Vector3) -> float:
	if m.get("grotte") != null and m.grotte != null and m.grotte.visible and j.global_position.y < -5.0:
		return p.y
	return m.hauteur(p.x, p.z)

## Place la caméra (le joueur) et vise le point `cible`.
func _cam(pos: Vector3, cible: Vector3) -> void:
	j.global_position = pos
	j.velocity = Vector3.ZERO
	var d := cible - (pos + Vector3(0, j.tete.position.y, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _plan(nom: String) -> void:
	var p: Array = PLANS[nom]
	var cave := nom == "araignee"
	var b := _bete(String(p[0]))
	if b == null:
		print("SEGMENT_ABSENT ", nom)
		return
	b.visible = true
	b.set_physics_process(false)
	b.set_process(false)
	b.velocity = Vector3.ZERO
	var dist: float = p[1]
	var R: float = p[3]
	var vit_course: float = p[4]
	var haut: float = p[5]
	j.tete.position.y = float(p[6])
	j.camera.fov = 58.0 if cave else 40.0        # focale plus longue : l'animal remplit le cadre sans coller la caméra
	var fiche: Dictionary = b.fiche
	var centre: Vector3 = b.global_position
	var cam_pos := Vector3.ZERO
	var haut_sol := 0.0
	if cave:
		var g: Node3D = m.grotte
		centre = g.monde_sol(S_ARAIGNEE, 0.0, "A") + Vector3(0, 0.05, 0)
		cam_pos = g.monde_sol(S_ARAIGNEE - dist, 0.0, "A") + Vector3(0, 0.1, 0)
		var torche := OmniLight3D.new()           # la torche du joueur (la galerie est sombre)
		torche.light_color = Color(1.0, 0.86, 0.66)
		torche.light_energy = 1.6
		torche.omni_range = 12.0
		j.tete.add_child(torche)
	else:
		centre = Vector3(STUDIO.x, m.hauteur(STUDIO.x, STUDIO.y) + 0.02, STUDIO.y)
		var a := deg_to_rad(float(_arg("cap", str(p[2]))))
		var c2 := centre + Vector3(sin(a), 0, cos(a)) * dist
		cam_pos = Vector3(c2.x, m.hauteur(c2.x, c2.z) + 0.1, c2.z)
		m.cycle.heure = 12.0
		m.cycle._process(0.0)
	var hl: float = fiche["haut"]
	var ang := randf() * TAU
	var tt := 0.0
	var t_idle := 1.5
	var t_marche := 3.3
	var t_course := 1.6
	var t_fin := 1.5
	var total := t_idle + t_marche + t_course + t_fin
	var cible := centre
	b.global_position = centre
	_cam(cam_pos, centre + Vector3(0, haut, 0))
	b._jouer("Idle", 0.0)
	if cave:
		_ecarter_araignees()
	await _attendre(1.0)          # lumière, brume et nuage de poussière posés
	var d0 := _image()
	var cam := root.get_camera_3d()
	print("DEBUG %s bete=%s joueur=%s camera=%s fov=%.0f" % [nom, b.global_position, j.global_position, cam.global_position if cam else "?", cam.fov if cam else 0.0])
	var n := int(total * 30.0)
	var phase := ""
	var ang_v := 0.0
	for i in n:
		tt = float(i) / 30.0
		var nouvelle := "idle" if tt < t_idle else ("marche" if tt < t_idle + t_marche else ("course" if tt < t_idle + t_marche + t_course else "fin"))
		var vit := 0.0
		if nouvelle == "marche":
			vit = float(fiche["ref_marche"])
		elif nouvelle == "course":
			vit = vit_course
		if nouvelle != phase:
			phase = nouvelle
			match phase:
				"idle":
					b._jouer("Idle", 0.2)
					b.anim.speed_scale = 1.0
				"marche":
					b._jouer("Walk", 0.25)
				"course":
					b._jouer("Run" if b.anim.has_animation("Run") else "Walk", 0.25)
				"fin":
					var f := "Attack" if bool(fiche["hostile"]) else ("Eat" if b.anim.has_animation("Eat") else "Idle_2")
					b._jouer(f if b.anim.has_animation(f) else "Idle", 0.25)
					b.anim.speed_scale = 1.0
					# la bête se tourne vers la caméra pour la morsure / le broutement
		if vit > 0.0:
			var ref := float(fiche["ref_course"]) if phase == "course" else float(fiche["ref_marche"])
			b.anim.speed_scale = clampf(vit / ref, 0.5, 2.0)
			ang_v = vit / R
			ang += ang_v / 30.0
			var np := centre + Vector3(sin(ang), 0, cos(ang)) * R
			var tang := Vector3(cos(ang), 0, -sin(ang))      # sens horaire
			np.y = _sol(np) if not cave else centre.y
			b.global_position = np
			b.rotation.y = atan2(tang.x, tang.z)
		elif phase == "fin":
			var vers := cam_pos - b.global_position
			b.rotation.y = lerp_angle(b.rotation.y, atan2(vers.x, vers.z), 0.12)
		if cave and i % 10 == 0:
			_ecarter_araignees()
		_cam(cam_pos, b.global_position + Vector3(0, haut, 0))
		await process_frame
	print("SEGMENT %s %d %d" % [nom, d0, _image()])
	b.visible = false          # hors champ pour les plans suivants
	b.global_position = Vector3(0, -80, 0)

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	j = m.joueur
	j.mort = false
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	j.vie = 100000.0
	if m.get("dialogue") != null:
		m.dialogue.visible = false      # pas de sous-titres de gardes dans le film
	await _attendre(2.0)
	for g in ["villageois", "gardes", "garde_village"]:
		for n in get_nodes_in_group(g):
			if n is Node3D:
				n.visible = false
				n.process_mode = Node.PROCESS_MODE_DISABLED
	var voulus: PackedStringArray = PLANS.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			voulus = a.substr(12).split(",")
	for nom in PLANS:
		if nom in voulus and nom != "araignee":
			await _plan(nom)
	if "araignee" in voulus:
		m._aller_grotte("60,0,0,0")      # (le joueur est replacé par _plan)
		# les araignées de la mine apparaissent à l'approche (grotte_jeu) ; ici on en pose une à nous, au même endroit, pour le plan
		var g: Node3D = m.grotte
		var pos: Vector3 = g.monde_sol(S_ARAIGNEE, 0.0, "A") + Vector3(0, 0.05, 0)
		m.creer_ennemi(load("res://scripts/bete_quat.gd"), pos, 0.0, {"espece": "araignee", "ident": "araignee_film"})
		_ecarter_araignees()
		await _attendre(1.0)
		await _plan("araignee")
	print("FILM fini images=%d" % _image())
	quit(0)
