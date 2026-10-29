extends SceneTree
## Test des objets cassables (lot L5, scripts/cassable.gd) : urnes et tonneaux du décor de la crypte et de la grotte.
##   godot --headless --path . --script res://outils/test_cassables.gd -- --nouvelle
##   (fenêtre hors écran + --captures=<dossier> : captures avant / après la casse de l'essai A)
## A. Décor isolé : urne et tonneau deviennent des Cassable (identifiant stable, maillage et solide propres), le rng du décor est
##    intact (mêmes tirages avec ou sans cassables), un coup (rayon de la lame) les brise, éclats, butin à graine fixe, état « pillé »
##    sauvegardé et rendu à un décor reconstruit (casse silencieuse, éclats au sol).
## B. Crypte réelle : des cassables existent, ids uniques, un seul « crypte:… » par objet, solide en place, casse + sort (briser_sort).
const SCENE := preload("res://scenes/foret_test.tscn")

var _echecs := 0
var _captures := ""

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await physics_frame

func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	root.get_texture().get_image().save_png(_captures.path_join(nom))
	print("CAPTURE ", _captures.path_join(nom))

## Un décor de crypte isolé avec deux urnes et deux tonneaux, plus un tirage de rng pour comparer.
func _decor(parent: Node3D, avec: bool) -> Dictionary:
	var racine := Node3D.new()
	parent.add_child(racine)
	var corps := StaticBody3D.new()
	racine.add_child(corps)
	var d := CrypteDecor.new(racine, corps)
	d.cass_actif = avec
	d.urne(Vector3(0.0, 0.0, 0.0), 1.2)
	d.urne(Vector3(1.6, 0.0, 0.2), 1.0)
	d.tonneau(Vector3(-1.6, 0.0, 0.1), 1.0)
	d.tonneau(Vector3(3.0, 0.0, 0.0), 0.9)
	var rd := d.rng.randi()
	var rdd := d.rng_deco.randi()
	d.finir()
	return {"racine": racine, "d": d, "rng": rd, "rng_deco": rdd}

func _tester() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_captures = a.substr(11)
	ButinTables.reinitialiser()
	# ---------------------------------------------------------------- A
	var scene_a := Node3D.new()
	scene_a.name = "EssaiA"
	root.add_child(scene_a)
	var cam := Camera3D.new()
	scene_a.add_child(cam)
	cam.position = Vector3(0.6, 1.1, 3.2)
	cam.look_at(Vector3(0.6, 0.3, 0.0))
	cam.current = true
	var lum := OmniLight3D.new()
	scene_a.add_child(lum)
	lum.position = Vector3(0.5, 2.0, 1.8)
	lum.omni_range = 9.0
	lum.light_energy = 2.5
	var sol := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(12, 8)
	sol.mesh = pl
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.22, 0.23, 0.26)
	sol.material_override = ms
	scene_a.add_child(sol)
	var sans := _decor(scene_a, false)
	var avec := _decor(scene_a, true)
	(sans["racine"] as Node3D).visible = false
	_verif(sans["rng"] == avec["rng"] and sans["rng_deco"] == avec["rng_deco"], "rng et rng_deco identiques avec ou sans cassables")
	var racine: Node3D = avec["racine"]
	var cass: Array = racine.find_children("*", "Cassable", false, false)
	_verif(cass.size() == 4, "4 cassables (2 urnes, 2 tonneaux) : %d" % cass.size())
	var ids := {}
	for c: Cassable in cass:
		ids[c.ident] = true
	_verif(ids.size() == cass.size(), "identifiants uniques et stables : %s" % str(ids.keys()))
	var u: Cassable = null
	var t: Cassable = null
	for c: Cassable in cass:
		if c.genre == "urne" and u == null:
			u = c
		if c.genre == "tonneau" and t == null:
			t = c
	_verif(u != null and t != null and u.is_in_group("cassables"), "urne et tonneau dans le groupe « cassables »")
	_verif(u != null and u.get_child_count() >= 2 and u.find_children("*", "MeshInstance3D", false, false).size() >= 1, "l'urne a son maillage et son solide")
	await _attendre(3)
	# rayon de la lame : touche le Cassable, TraceLame le reconnaît comme cible
	var ss := root.get_world_3d().direct_space_state
	var de := u.global_position + Vector3(0, 0.3, 2.0)
	var q := PhysicsRayQueryParameters3D.create(de, u.global_position + Vector3(0, 0.3, 0), TraceLame.MASQUE)
	var r := ss.intersect_ray(q)
	_verif(not r.is_empty() and TraceLame.cible_de(r["collider"]) == u, "le rayon de la lame touche l'urne (cible « cassable »)")
	var r1 := ss.intersect_ray(PhysicsRayQueryParameters3D.create(de, u.global_position + Vector3(0, 0.3, 0), 1))
	_verif(r1.is_empty(), "le joueur (masque 1) traverse l'urne : pas de collision bloquante")
	await _capture("A1_avant.png")
	var pieces0 := ButinTables.pilles.size()
	_verif(u.frapper(false, de), "frapper() casse l'urne d'un coup léger")
	_verif(u.casse and not u.is_in_group("cassables") and ButinTables.est_pille(u.ident), "urne cassée : sortie du groupe, état pillé noté (%s)" % u.ident)
	_verif(not u.frapper(true, de), "une urne déjà cassée ne se casse pas deux fois")
	t.briser_sort(t.global_position + Vector3(0, 0.4, 0.4))
	_verif(t.casse and ButinTables.est_pille(t.ident), "briser_sort() casse le tonneau")
	var eclats := u.find_children("*", "MeshInstance3D", false, false).filter(func(n): return n.visible)
	_verif(eclats.size() >= 3 and eclats.size() <= 7, "l'urne se brise en %d éclats visibles (3 à 7)" % eclats.size())
	await _attendre(0.2)
	await _capture("A2_casse_vol.png")
	await _attendre(1.3)
	await _capture("A3_casse_repos.png")
	var bas := true
	for n: MeshInstance3D in eclats:
		if n.position.y > 0.3 or n.position.y < -0.01:
			bas = false
	_verif(bas, "les éclats sont retombés au sol")
	var ex := ButinTables.exporter()
	_verif((ex["pilles"] as Array).size() == pieces0 + 2, "deux objets pillés dans l'état exporté")
	# butin à graine fixe : même id = même tirage
	var l1 := ButinTables.tirer_pour(u.ident, ButinTables.table_pour("urne", "crypte"), "crypte")
	var l2 := ButinTables.tirer_pour(u.ident, ButinTables.table_pour("urne", "crypte"), "crypte")
	_verif(str(l1) == str(l2), "butin d'une urne déterministe : %s" % str(ButinTables.contenu(l1)))
	_verif(ButinTables.table_pour("tonneau", "crypte") != "", "table « tonneau » trouvée pour la crypte (repli défaut)")
	# partie rechargée : décor reconstruit, états importés → casse silencieuse au premier contrôle
	var etat := ButinTables.exporter()
	scene_a.free()
	ButinTables.importer(etat)
	var scene_b := Node3D.new()
	root.add_child(scene_b)
	var d2 := _decor(scene_b, true)
	var c2: Array = (d2["racine"] as Node3D).find_children("*", "Cassable", false, false)
	var cassees := 0
	await _attendre(1.2)
	for c: Cassable in c2:
		if c.casse:
			cassees += 1
	_verif(c2.size() == 4 and cassees == 2, "partie rechargée : 2 objets déjà cassés, 2 intacts (%d/%d)" % [cassees, c2.size()])
	for c: Cassable in c2:
		if c.casse:
			var vis := c.find_children("*", "MeshInstance3D", false, false).filter(func(n): return n.visible)
			_verif(vis.size() >= 3 and not c.is_in_group("cassables") and c.collision_layer == 0, "%s : éclats au sol, plus de collision" % c.ident)
			break
	scene_b.free()
	ButinTables.reinitialiser()
	# ---------------------------------------------------------------- B
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	m.tertre.attendre_donjon()
	for i in 5:
		await physics_frame
	var toutes: Array = m.tertre.crypte.get_parent().find_children("*", "Cassable", true, false)
	toutes.append_array(m.find_children("*", "Cassable", true, false))
	var uniques := {}
	for c: Cassable in toutes:
		uniques[c.get_instance_id()] = c
	var nb_urnes := 0
	var nb_tonneaux := 0
	var ident_vus := {}
	var doublon := false
	for c: Cassable in uniques.values():
		if c.genre == "urne":
			nb_urnes += 1
		else:
			nb_tonneaux += 1
		if ident_vus.has(c.ident):
			doublon = true
		ident_vus[c.ident] = true
	print("crypte : %d urnes, %d tonneaux cassables" % [nb_urnes, nb_tonneaux])
	_verif(nb_urnes >= 10 and nb_tonneaux >= 5, "la crypte contient des urnes et des tonneaux cassables")
	_verif(not doublon, "identifiants uniques dans la crypte")
	var pris: Cassable = null
	for c: Cassable in uniques.values():
		if c.genre == "urne" and not ButinTables.contenu(ButinTables.tirer_pour(c.ident, ButinTables.table_pour("urne", "crypte"), "crypte")).is_empty():
			pris = c
			break
	var j: CharacterBody3D = m.joueur
	var bourses0 := m.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("butin.gd")).size()
	pris.frapper(true, j.global_position)
	_verif(pris.casse and ButinTables.est_pille(pris.ident) and String(pris.ident).begins_with("crypte:"), "urne de la crypte brisée, état « crypte:… » noté")
	await _attendre(0.3)
	var bourses1 := m.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("butin.gd")).size()
	print("bourses : %d -> %d" % [bourses0, bourses1])
	_verif(bourses1 == bourses0 + 1, "l'urne cassée laisse une bourse (scripts/butin.gd) : %s" % str(ButinTables.contenu(ButinTables.tirer_pour(pris.ident, "urne", "crypte"))))
	# butin : sur l'ensemble des objets, la plupart donnent quelque chose mais pas tous (« parfois »)
	var avec_butin := 0
	for c: Cassable in uniques.values():
		var zone := c.ident.get_slice(":", 0)
		if not ButinTables.contenu(ButinTables.tirer_pour(c.ident, ButinTables.table_pour(c.genre, zone), zone)).is_empty():
			avec_butin += 1
	print("objets avec butin : %d / %d" % [avec_butin, uniques.size()])
	_verif(avec_butin > 0 and avec_butin < uniques.size(), "le butin est occasionnel (%d / %d)" % [avec_butin, uniques.size()])
	# --- grotte : tonneaux cassables, états sous le préfixe de la grotte
	var ga: Node3D = m.grotte_acces
	ga.attendre_exterieur()
	var gr: Grotte = ga.obtenir()
	var gc: Array = gr.find_children("*", "Cassable", true, false)
	print("grotte : %d cassables" % gc.size())
	_verif(gc.size() > 0, "la grotte contient des objets cassables")
	if gc.size() > 0:
		var gcs: Cassable = gc[0]
		_verif(String(gcs.ident).begins_with(String(gr.def.get("id", "grotte")) + ":"), "état de la grotte sous son préfixe (%s)" % gcs.ident)
		gcs.frapper(false, gcs.global_position + Vector3(1, 1, 0))
		_verif(gcs.casse and ButinTables.est_pille(gcs.ident), "objet de la grotte brisé et noté pillé")
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
