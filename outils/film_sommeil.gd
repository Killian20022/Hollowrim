extends SceneTree
## Film (≤ 20 s) du lot sommeil : la nuit, Sigrún entre chez elle, va à son lit, s'assoit, s'allonge et dort ; le matin, elle se redresse,
## se lève et ressort.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_sommeil.gd -- --nouvelle --sans-mains --paisible
## (fenêtre hors écran via godot_slot.sh). Imprime « FILM segment a b » (images à garder) pour le découpage ffmpeg.
const SCENE := "res://scenes/foret_test.tscn"
const OEIL := Vector3(2.7, 0.0, 0.9)        # repère de la maison de Sigrún : coin est, vers le lit (ouest) et la porte (+Z)
const VISE := Vector3(-2.2, 0.75, -0.6)
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _cam(pos: Vector3, cible: Vector3) -> void:
	j.global_position = pos
	j.velocity = Vector3.ZERO
	var d := cible - (pos + Vector3(0, j.tete.position.y, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _images(n: int, ip: Interieur) -> void:
	for i in n:
		_cam(ip.to_global(Vector3(OEIL.x, ip.sol_y + 0.02, OEIL.z)), ip.to_global(VISE))
		await process_frame

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	while not m.village.prets:
		await process_frame
	j = m.joueur
	j.vie = 1.0e6
	j.set_physics_process(false)
	if m.get("hud") != null:
		m.hud.visible = false
	if m.get("dialogue") != null:
		m.dialogue.visible = false
	j.mains.visible = false
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	var vie: Vie = m.vie
	var ip: Interieur = m.village.interieur("sigrun")
	j.camera.fov = 70.0
	var c: Dictionary = vie.civil("volva")
	var n: Node3D = c["n"]
	var rentree: float = float(c["f"].get("rentree", 21.5)) + EmploiDuTemps.decalage("volva")
	var reveil: float = float(c["f"].get("reveil", 6.5)) + EmploiDuTemps.decalage("volva")
	m.cycle.heure = rentree - 0.3
	m.cycle._process(0.0)
	vie.tick()
	await _images(60, ip)
	var porte: Vector3 = vie._portes["sigrun"]["pos"]
	n.installer(porte + (porte - ip.to_global(Vector3(0, 0, 0))).normalized() * 1.2, false)
	await _images(30, ip)
	# segment 1 : elle rentre et se couche
	m.cycle.heure = rentree + 0.02
	vie.tick()
	var a := Engine.get_frames_drawn()
	var fin := -1
	for i in 30 * 16:
		await _images(1, ip)
		if n.seq == "dort" and fin < 0:
			fin = i + 45            # encore 1,5 s de sommeil (respiration)
		if fin >= 0 and i >= fin:
			break
	print("FILM segment %d %d (fin=%s)" % [a, Engine.get_frames_drawn(), n.seq])
	# segment 2 : le matin
	m.cycle.heure = reveil - 0.05
	m.cycle._process(0.0)
	vie._heure_prec = m.cycle.heure
	vie.tick()
	await _images(20, ip)
	m.cycle.heure = reveil + 0.02
	m.cycle._process(0.0)
	vie.tick()
	var b := Engine.get_frames_drawn()
	for i in 30 * 9:
		await _images(1, ip)
		if n.seq == "" and not ip.dedans(ip.to_local(n.global_position), -0.3) and i > 60:
			break
	print("FILM segment %d %d (etat=%d)" % [b, Engine.get_frames_drawn(), n.etat])
	quit(0)
