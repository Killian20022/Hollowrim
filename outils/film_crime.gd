extends SceneTree
## Films du système de crime (≤ 18 s), lot de preuves « crime » :
##   --plan=vol      : le joueur prend une coupe d'argent sous les yeux de son propriétaire, qui crie et l'attaque ;
##   --plan=gardes   : un premier coup sur un garde (avertissement), un second (agression) : toute la garde accourt et frappe ;
##   --plan=crochet  : le coffre de Gunnar dans la longue maison : mini-jeu, un crochet cassé, la serrure cède, on fouille.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_crime.gd -- --nouvelle --plan=vol
## (fenêtre hors écran via godot_slot.sh).
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D
var cr: Crime
var plan := "vol"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plan="):
			plan = a.get_slice("=", 1)
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
		j.vie = j.vie_max          # le film ne doit pas finir au feu de camp
		if chaque.is_valid():
			chaque.call(i)
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
	j.vie_max = 100000.0
	j.vie = 100000.0
	cr = Crime.trouver(m)
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 11.0
	m.cycle._process(0.0)
	if m.hud.has_method("demarrer"):
		m.hud.aide_t = 0.0
	for i in 150:
		await process_frame
	print("FILM début image ", Engine.get_frames_drawn())
	match plan:
		"vol":
			await _vol()
		"gardes":
			await _gardes()
		"crochet":
			await _crochet()
	print("FILM fini images=%d" % Engine.get_frames_drawn())
	quit(0)

# ------------------------------------------------------------------ vol devant le propriétaire
func _vol() -> void:
	var p: Node3D = null
	for id in ["hab_chasseur_1", "hab_paysan_1", "chasseuse", "hab_chasseur_2", "forgeron"]:
		p = _pnj(id)
		if p != null:
			break
	var av := p.global_transform.basis.z
	av.y = 0.0
	av = av.normalized()
	var pos := p.global_position + av * 3.4
	pos.y = m.hauteur(pos.x, pos.z) + 0.1
	j.global_position = pos
	var coupe := ObjetMonde.visuel("coupe_argent", "sol")
	m.add_child(coupe)
	var pc := pos - av * 1.1
	coupe.global_position = Vector3(pc.x, m.hauteur(pc.x, pc.z) + 0.02, pc.z)
	coupe.scale = Vector3.ONE * 2.0
	var oeil := p.global_position + Vector3.UP * 1.2
	j.mains.visible = false
	await _images(75, func(_i: int) -> void: _viser(oeil.lerp(coupe.global_position, 0.75)))
	# il ramasse la coupe
	var obj := Node3D.new()
	obj.set_meta("id_objet", "coupe_argent")
	m.add_child(obj)
	obj.global_position = coupe.global_position
	var coupe_pos := coupe.global_position
	coupe.queue_free()
	j.inventaire.ajouter("coupe_argent", 1)
	Sons.jouer(j, ["ui_ramasse"], -6.0)
	cr.signaler_vol(obj, String(p.donnees.get("id", "")), obj.global_position)
	var c := cr.combattant_de(p)
	print("FILM vol : témoins %d, combattant %s" % [int(cr.dernier.get("temoins", 0)), c.mode if c else "-"])
	await _images(int(11.0 * 30), func(i: int) -> void:
		var cible: Node3D = c if c != null and is_instance_valid(c) else p
		var k := clampf(float(i) / 20.0, 0.0, 1.0)
		_viser((oeil.lerp(coupe_pos, 0.75)).lerp(cible.global_position + Vector3.UP * 1.25, k)))

# ------------------------------------------------------------------ garde frappé, toute la garde accourt
func _gardes() -> void:
	var gv: Node = m.get_node("GardesVillage")
	var g: Node3D = null
	for x in gv.gardes:
		if String(x.donnees.get("id", "")) == "ronde_place":     # ronde de la place : terrain dégagé pour la vue de dos
			g = x
	var av := g.global_transform.basis.z
	av.y = 0.0
	av = av.normalized()
	var pos := g.global_position + av * 2.2
	pos.y = m.hauteur(pos.x, pos.z) + 0.1
	j.global_position = pos
	var tete := g.global_position + Vector3.UP * 1.5
	await _images(30, func(_i: int) -> void: _viser(tete))
	j.mains.attaquer()
	await _images(10, func(_i: int) -> void: _viser(tete))
	g.recevoir_coup(12.0, j.global_position, false, {})        # 1er coup : avertissement
	await _images(55, func(_i: int) -> void: _viser(tete))
	j.mains.attaquer()
	await _images(10, func(_i: int) -> void: _viser(tete))
	g.recevoir_coup(12.0, j.global_position, false, {})        # 2e coup : agression, toute la garde
	print("FILM gardes : hostiles %d" % cr.combattants.size())
	# vue à la troisième personne, face à la longue maison (postes de la halle, de la tour) : la garde accourt de partout
	var place: Vector3 = m.village.lieux["longue_maison"]
	j.basculer_vue(true)
	var lacet0 := j.rotation.y
	var vers := place - j.global_position
	var lacet1 := atan2(-vers.x, -vers.z)
	await _images(int(12.5 * 30), func(i: int) -> void:
		var k := clampf(float(i) / 30.0, 0.0, 1.0)
		j.rotation.y = lerp_angle(lacet0, lacet1, k)
		j.tete.rotation.x = lerpf(0.0, -0.22, k))
	var n := 0
	for c in cr.combattants:
		if is_instance_valid(c) and c.est_garde:
			n += 1
	print("FILM gardes : %d gardes hostiles à la fin" % n)

# ------------------------------------------------------------------ crochetage du coffre de Gunnar
func _crochet() -> void:
	var ip: Node3D = m.village.interieur("halle")
	var coffre: Node3D = ip.find_child("coffre_gunnhild", true, false)
	var p := ip.to_global(Vector3(5.0, Interieurs.F, 1.2))
	j.global_position = p + Vector3(0, 0.1, 0)
	j.inventaire.ajouter("crochet", 4)
	m.cycle.heure = 3.0     # la nuit : la halle est vide (Gunnar dort), personne ne voit
	m.cycle._process(0.0)
	await _images(50, func(_i: int) -> void: _viser(coffre.global_position))
	coffre.parler()
	var ck: Crochetage = cr.crochetage
	ck.set_meta("pilote", true)
	var secret := ck.angle_secret
	var faux := secret - 65.0 if secret > 0.0 else secret + 65.0
	# 1) on cherche (balayage lent), 2) on force loin de la zone : le crochet casse, 3) on approche : ça tourne un peu, 4) dans la zone
	var etapes := [[0.0, -40.0, 1.0, false], [-40.0, faux, 0.8, false], [faux, faux, 1.6, true], [faux, secret + ck.largeur * 0.5 + 18.0, 1.2, false],
		[secret + ck.largeur * 0.5 + 18.0, secret + ck.largeur * 0.5 + 18.0, 1.0, true], [secret + ck.largeur * 0.5 + 18.0, secret, 1.0, false],
		[secret, secret, 1.5, true]]
	for e: Array in etapes:
		var n := int(float(e[2]) * 30.0)
		for i in n:
			if not ck.ouvert:
				break
			ck.tourne = bool(e[3])
			if not ck.tourne:
				ck.angle = lerpf(float(e[0]), float(e[1]), float(i + 1) / float(n))
			ck.pas(1.0 / 30.0)
			ck._vue.queue_redraw()
			await process_frame
		ck.tourne = false
		if not ck.ouvert:
			break
		for i in 8:
			ck.pas(1.0 / 30.0)
			await process_frame
	print("FILM crochet : résultat %s, crochets cassés %d" % [ck.resultat, ck.casses])
	await _images(20, func(_i: int) -> void: _viser(coffre.global_position))
	m.dialogue.engager(coffre)          # « Fouiller le coffre » : la boîte dit ce qu'on prend
	await _images(int(3.0 * 30), func(_i: int) -> void: _viser(coffre.global_position))
