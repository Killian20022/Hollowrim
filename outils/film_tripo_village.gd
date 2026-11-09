extends SceneTree
## Essai Tripo, INTÉGRATION au village : le jarl Tripo à la place du chef (id « chef »), trois gardes Tripo à la place de gardes de Skarnholt.
##   --plan=patrouille : le garde à l'épée (ronde de la place) puis l'archère (ronde du nord) marchent leur ronde ;
##   --plan=jarl       : le jarl à sa place, vu de près puis parlé ;
##   --plan=reaction   : le garde à l'épée est frappé (avertissement), puis agressé : il dégaine et poursuit le joueur (Crime).
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_tripo_village.gd -- --nouvelle --jarl-tripo --gardes-tripo --plan=patrouille
## (fenêtre hors écran via godot_slot.sh). Caméra propre (Camera3D du script), pas d'interface.
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D
var cr: Crime
var cam: Camera3D
var plan := "patrouille"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plan="):
			plan = a.get_slice("=", 1)
	_go.call_deferred()

func _images(n: int, chaque := Callable()) -> void:
	for i in n:
		j.vie = j.vie_max
		if chaque.is_valid():
			chaque.call(i)
		await process_frame

func _garde(id: String) -> Node3D:
	for x in m.get_node("GardesVillage").gardes:
		if String(x.donnees.get("id", "")) == id:
			return x
	return null

func _pnj(id: String) -> Node3D:
	for v in get_nodes_in_group("villageois"):
		if "donnees" in v and String(v.donnees.get("id", "")) == id and not (v is GardeVillage_):
			return v
	return null

const GardeVillage_ := preload("res://scripts/garde_village.gd")

## Caméra à `d` m derrière-à-côté de la cible (dans son repère), regardant sa poitrine.
func _suivre(c: Node3D, d: Vector3, hauteur := 1.0) -> void:
	var b := c.global_transform.basis
	var p := c.global_position + b.x * d.x + b.z * d.z
	p.y = m.hauteur(p.x, p.z) + d.y
	cam.global_position = p
	cam.look_at(c.global_position + Vector3(0, hauteur, 0), Vector3.UP)

func _poser_joueur(pres_de: Vector3) -> void:
	j.global_position = Vector3(pres_de.x + 6.0, m.hauteur(pres_de.x + 6.0, pres_de.z) + 0.2, pres_de.z)
	j.velocity = Vector3.ZERO

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	while not m.village.prets:
		await process_frame
	j = m.joueur
	j.vie_max = 100000.0
	j.vie = 100000.0
	cr = Crime.trouver(m)
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 11.0
	m.cycle._process(0.0)
	if m.hud.has_method("demarrer"):
		m.hud.aide_t = 0.0
	m.hud.visible = false
	j.mains.visible = false
	for c in j.camera.get_children():
		if c is Node3D:
			c.visible = false
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	m.add_child(cam)
	cam.make_current()
	for i in 150:
		await process_frame
	print("FILM début image ", Engine.get_frames_drawn())
	match plan:
		"patrouille":
			await _patrouille()
		"jarl":
			await _jarl()
		"reaction":
			await _reaction()
	print("FILM fini images=%d" % Engine.get_frames_drawn())
	quit(0)

func _patrouille() -> void:
	var e := _garde("ronde_place")
	print("GARDE épée : ", e.modele.name, " pos ", e.global_position)
	_poser_joueur(e.global_position + Vector3(0, 0, 30))
	await _images(30)
	await _images(int(9.0 * 30), func(_i: int) -> void: _suivre(e, Vector3(1.4, 1.2, 2.7), 1.0))
	var a := _garde("ronde_nord")
	print("GARDE archère : ", a.modele.name, " pos ", a.global_position)
	_poser_joueur(a.global_position + Vector3(0, 0, 30))
	await _images(30)
	await _images(int(8.0 * 30), func(_i: int) -> void: _suivre(a, Vector3(-1.5, 1.2, 2.9), 1.0))

func _jarl() -> void:
	var c := _pnj("chef")
	print("JARL : ", c.modele.name, " pos ", c.global_position, " visible ", c.visible, " cap z ", c.global_transform.basis.z)
	j.global_position = c.global_position + Vector3(0, 0.3, 5.0)
	await _images(30)
	var t := 0.0
	await _images(int(15.0 * 30), func(i: int) -> void:
		var k := float(i) / 450.0
		var b := c.global_transform.basis          # +Z local = devant le jarl : caméra de face puis 3/4
		var p := c.global_position + b.z * lerpf(3.0, 2.4, k) + b.x * lerpf(1.1, -0.6, k)
		p.y = c.global_position.y + 1.45
		cam.global_position = p
		cam.look_at(c.global_position + Vector3(0, 1.15, 0), Vector3.UP))

func _reaction() -> void:
	var g := _garde("ronde_place")
	var av := g.global_transform.basis.z
	av.y = 0.0
	av = av.normalized()
	var pos := g.global_position + av * 2.4
	pos.y = m.hauteur(pos.x, pos.z) + 0.1
	j.global_position = pos
	var tete := g.global_position + Vector3.UP * 1.4
	var d := tete - (j.global_position + Vector3(0, 1.6, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	var suit := func(_i: int) -> void:
		var e: Node3D = g      # on garde le modèle Tripo à l'image (le combattant sans texture reste hors cadre)
		var p := j.global_position - av * 0.0 + Vector3(0, 1.7, 0) + (j.global_transform.basis.x * 1.2) + j.global_transform.basis.z * 1.8
		cam.global_position = p
		cam.look_at(e.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	await _images(45, suit)
	j.mains.attaquer()
	await _images(10, suit)
	g.recevoir_coup(12.0, j.global_position, false, {})
	await _images(60, suit)
	j.mains.attaquer()
	await _images(10, suit)
	g.recevoir_coup(12.0, j.global_position, false, {})
	print("FILM réaction : hostiles %d" % cr.combattants.size())
	var w := Vector3(0, 0, 0)
	await _images(int(9.0 * 30), func(i: int) -> void:
		j.global_position += Vector3(0, 0, 0)
		suit.call(i))
