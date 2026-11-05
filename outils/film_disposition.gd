extends SceneTree
## Film de la disposition (≤ 20 s), lot de preuves « disposition » : lame levée devant un civil (remarque), puis devant un garde
## (avertissement, dernier avertissement, il attaque) ; arme baissée, il propose de se rendre ; « Plaider ta cause » : rejeté, prime
## majorée, le garde reprend l'arrestation ; on paie.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 1280x720 --script res://outils/film_disposition.gd -- --nouvelle --paisible
## (fenêtre hors écran via godot_slot.sh). Seul raccourci : l'attente de 8 s avant « Rends-toi » est écourtée.
const SCENE := "res://scenes/foret_test.tscn"
const GARDE := 5
var m: Node3D
var j: CharacterBody3D
var cr: Crime
var brandir := false

func _init() -> void:
	_go.call_deferred()

func _viser(cible: Vector3) -> void:
	var d := cible - (j.global_position + Vector3(0, j.tete.position.y, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _pnj(id: String) -> Node3D:
	for v in get_nodes_in_group("villageois"):
		if "donnees" in v and String(v.donnees.get("id", "")) == id and v.visible:
			return v
	return null

func _images(n: int, chaque := Callable()) -> void:
	for i in n:
		j.vie = j.vie_max
		if brandir:
			j.mains.etat = GARDE
		if chaque.is_valid():
			chaque.call(i)
		await process_frame

func _devant(n: Node3D, d: float) -> void:
	var av := n.global_transform.basis.z
	av.y = 0.0
	av = av.normalized()
	var p := n.global_position + av * d
	p.y = m.hauteur(p.x, p.z) + 0.1
	j.global_position = p
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
	j.inventaire.pieces = 300
	cr = Crime.trouver(m)
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 11.0
	m.cycle._process(0.0)
	if m.hud.has_method("demarrer"):
		m.hud.aide_t = 0.0
	j.mains.torche_sortie = false
	for i in 150:
		await process_frame
	print("FILM début image ", Engine.get_frames_drawn())
	# ------------------------------------------------------------------ civil : « Range ça. »
	var civil: Node3D = null
	for id in ["chasseuse", "hab_chasseur_1", "hab_paysan_1", "ancienne", "forgeron"]:
		civil = _pnj(id)
		if civil != null:
			_devant(civil, 3.6)
			await process_frame
			if cr.voit(civil, j.global_position):
				break
	var tete := civil.global_position + Vector3.UP * 1.5
	await _images(20, func(_i: int) -> void: _viser(tete))
	brandir = true
	await _images(70, func(_i: int) -> void: _viser(civil.global_position + Vector3.UP * 1.5))
	brandir = false
	print("FILM civil %s : remarques %d" % [civil.nom_affiche(), cr.disposition.remarques])
	# ------------------------------------------------------------------ garde : avertissements, il attaque
	var gv: Node = m.get_node("GardesVillage")
	var g: Node3D = null
	for x in gv.gardes:
		if String(x.donnees.get("id", "")) == "halle_o":
			g = x
	_devant(g, 4.5)
	var tg := g.global_position + Vector3.UP * 1.5
	await _images(15, func(_i: int) -> void: _viser(tg))
	brandir = true
	var c: PnjCombat = null
	for i in int(9.0 * 30):
		await _images(1, func(_i: int) -> void:
			var cible: Node3D = c if c != null and is_instance_valid(c) else g
			_viser(cible.global_position + Vector3.UP * 1.5))
		if c == null:
			c = cr.combattant_de(g)
			if c != null:
				print("FILM garde hostile après %.1f s" % (i / 30.0))
				break
	await _images(30, func(_i: int) -> void: _viser(c.global_position + Vector3.UP * 1.5))
	brandir = false
	# arme baissée : il propose de se rendre (attente écourtée)
	cr._dernier_coup = cr._horloge - Crime.SE_RENDRE - 0.1
	for i in 6 * 30:
		await _images(1, func(_i: int) -> void: _viser(c.global_position + Vector3.UP * 1.5) if is_instance_valid(c) else null)
		if j.en_dialogue:
			break
	# la machine à écrire jusqu'aux choix, à vitesse lisible
	for k in 200:
		await _images(1)
		if m.dialogue._choix_vis or not m.dialogue._ouvert:
			break
		if k % 25 == 24:
			m.dialogue._suite()
	await _images(20)
	m.dialogue._choisir(1)               # « Plaider ta cause »
	await _images(25)
	cr.reputation[Crime.JURIDICTION] = 10.0
	m.dialogue._fermer()
	cr.plaider(60.0)                     # jet fixe : rejeté (le film doit montrer l'échec)
	print("FILM plaider : prime %.0f, dialogue %s" % [cr.prime(), j.en_dialogue])
	for k in 120:
		await _images(1)
		if m.dialogue._choix_vis:
			break
		if k % 40 == 39:
			m.dialogue._suite()
	await _images(25)
	m.dialogue._choisir(0)
	await _images(10)
	m.dialogue._valider_choix()
	await _images(45, func(_i: int) -> void: _viser(g.global_position + Vector3.UP * 1.5) if is_instance_valid(g) else null)
	print("FILM fini images=%d prime %.0f" % [Engine.get_frames_drawn(), cr.prime()])
	quit(0)
