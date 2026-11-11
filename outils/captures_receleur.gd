extends SceneTree
## Captures du receleur (gameplay/economie, docs/ECONOMIE.md) — FENÊTRE hors écran via godot_slot.sh :
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_receleur.gd -- --nouvelle --paisible --sortie=<dossier>
##   --plan : vue de dessus du village (choix du coin du receleur), positions des lieux et des bâtiments imprimées.
## Vues : le receleur à son coin (jour, nuit), son dialogue, sa boutique (Acheter, Vendre avec objets volés), la boutique de Brodd
## qui refuse un objet volé, et la boutique du receleur en 480x270.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var sortie := ""
var args := {}

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sortie = String(args.get("sortie", "res://captures/receleur"))
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	var f := dossier.path_join(nom + ".png")
	img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size())

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if p.donnees.get("id") == id:
			return p
	return null

func _devant(p: Node3D, dist := 1.7) -> void:
	p.set_physics_process(false)
	var dir: Vector3 = p.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
	var j: CharacterBody3D = m.joueur
	j.global_position = p.global_position + dir * dist + Vector3(0, 0.1, 0)
	j.velocity = Vector3.ZERO
	m._viser(p.global_position + Vector3(0, 1.45, 0))

func _heure(h: float) -> void:
	m.cycle.heure = h
	m.cycle._process(0.0)

func _plan() -> void:
	for nom: String in m.village.lieux:
		print("LIEU ", nom, " ", m.village.lieux[nom])
	for ip: Node in m.village.interieurs:
		print("BATI ", ip.name, " ", (ip as Node3D).global_position if ip is Node3D else "")
	for p: Node in get_nodes_in_group("villageois"):
		print("PNJ ", p.donnees.get("id"), " ", (p as Node3D).global_position)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args.get("taille", "56"))
	var c := Vector3(float(args.get("cx", "44")), 0, float(args.get("cz", "40")))
	root.add_child(cam)
	cam.global_position = c + Vector3(0, 80, 0)
	cam.look_at(c, Vector3.FORWARD)
	cam.far = 200.0
	cam.make_current()
	_heure(12.0)
	await _images(30)
	await _capturer("plan_village")

## Coins candidats (x;z|x;z…, --sondes=…) : sol, obstacle à hauteur de corps, et une vue depuis 6 m au sud-est.
func _sondes() -> void:
	var etat := m.get_world_3d().direct_space_state
	var j: CharacterBody3D = m.joueur
	_heure(15.0)
	var k := 0
	for s: String in String(args.get("sondes", "")).split("|"):
		var xz := s.split(";")
		var x := float(xz[0])
		var z := float(xz[1])
		var y := float(m.hauteur(x, z))
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.4
		q.shape = cap
		q.transform = Transform3D(Basis.IDENTITY, Vector3(x, y + 1.0, z))
		q.exclude = [j.get_rid()]
		var touche := etat.intersect_shape(q, 4)
		var noms: Array = touche.map(func(t: Dictionary) -> String: return str(t["collider"].name) if t["collider"] else "?")
		print("SONDE %s : sol %.2f, obstacles %s" % [s, y, str(noms)])
		var poteau := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.2
		bm.bottom_radius = 0.2
		bm.height = 1.8
		poteau.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 1)
		poteau.material_override = mat
		m.add_child(poteau)
		poteau.global_position = Vector3(x, y + 0.9, z)
		var off := Vector3(float(args.get("ox", "4.5")), 0, float(args.get("oz", "4.5")))
		j.global_position = Vector3(x, 0, z) + off
		j.global_position.y = float(m.hauteur(j.global_position.x, j.global_position.z)) + 0.1
		j.velocity = Vector3.ZERO
		m._viser(poteau.global_position)
		await _images(40)
		_heure(15.0)
		await _capturer("sonde_%d" % k)
		poteau.queue_free()
		k += 1

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(60)
	m.hud.aide_t = 0.0
	m.joueur.mains.visible = false
	if args.has("plan"):
		await _plan()
		quit()
		return
	if args.has("sondes"):
		await _sondes()
		quit()
		return
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	var d: Control = m.dialogue
	var mb: Marchand = m.marchand
	var bersi := _pnj("receleur")
	if bersi == null:
		print("ECHEC receleur introuvable")
		quit(1)
		return
	# --- le receleur à son coin, vu de loin (jour puis crépuscule)
	bersi.set_physics_process(false)
	var dir: Vector3 = bersi.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	j.global_position = bersi.global_position + dir * 5.0 + Vector3(0, 0.1, 0)
	m._viser(bersi.global_position + Vector3(0, 1.2, 0))
	_heure(15.0)
	await _images(90)
	_heure(15.0)
	await _capturer("1_receleur_coin_jour")
	_heure(20.5)
	await _images(30)
	_heure(20.5)
	await _capturer("2_receleur_coin_soir")
	# --- dialogue
	_heure(15.0)
	_devant(bersi)
	await _images(30)
	d._ouvrir(bersi)
	await _images(150)
	_heure(15.0)
	await _capturer("3_dialogue_receleur")
	d._fermer()
	await _images(4)
	# --- boutique : sac garni d'objets volés et honnêtes
	var cr := Crime.trouver(m)
	for oid: String in ["collier_or", "coupe_argent", "anneau_cuivre", "potion_soin", "minerai_fer"]:
		inv.ajouter(oid, 2 if oid in ["potion_soin", "minerai_fer"] else 1)
	if cr != null:
		cr.voles["collier_or"] = 1
		cr.voles["coupe_argent"] = 1
		cr.voles["potion_soin"] = 1
	inv.pieces = 180
	mb.ouvrir("receleur")
	await _images(8)
	await _capturer("4_boutique_receleur_acheter")
	mb.changer_onglet(1)
	await _images(6)
	await _capturer("5_boutique_receleur_vendre")
	mb.traiter(0)
	await _images(4)
	await _capturer("6_boutique_receleur_apres_vente")
	mb.changer_onglet(0)
	root.content_scale_size = Vector2i(480, 270)
	await _images(6)
	await _capturer("7_boutique_receleur_480x270")
	root.content_scale_size = Vector2i(640, 360)
	await _images(4)
	mb.fermer()
	await _images(4)
	# --- Brodd refuse l'objet volé
	mb.ouvrir("forgeron")
	mb.changer_onglet(1)
	var i_vole := -1
	for i in mb.lignes.size():
		if bool(mb.lignes[i].get("vole", false)):
			i_vole = i
			break
	mb._choisir(maxi(0, i_vole))
	await _images(6)
	await _capturer("8_boutique_brodd_refuse_vole")
	mb.fermer()
	quit()
