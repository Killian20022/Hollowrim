extends SceneTree
## Captures EN JEU des objets du monde (ObjetMonde) : bijoux posés au sol, objets lâchés, armures au sol, étals de Brodd et Grima.
##   godot --path . --script res://outils/captures_objets_monde.gd -- --nouvelle --heure=12 --paisible --sortie=<dossier>
## (avec fenêtre : godot_slot.sh, hors écran). Vue subjective du joueur, figé ; rendu du jeu (640 x 360, post-traitement ps1).
const SCENE := preload("res://scenes/foret_test.tscn")
const BIJOUX := ["amulette_givre", "amulette_ours", "amulette_arcaniste", "collier_portefaix", "anneau_coureur", "anneau_adepte",
	"anneau_braise", "anneau_orage", "anneau_berserker", "anneau_marchand"]
var _dossier := ""
var m: Node3D
var j: CharacterBody3D
var _poses: Array[Node3D] = []

func _init() -> void:
	_go.call_deferred()

func _att(n: int) -> void:
	for i in n:
		await process_frame

func _cap(nom: String) -> void:
	await _att(8)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_dossier)
	root.get_texture().get_image().save_png(_dossier.path_join(nom))
	print("CAPTURE ", nom)

## Dessus de la surface au point (pavés, plancher, terrain) : rayon vers le bas, joueur exclu ; repli = hauteur du terrain.
func _sol(x: float, z: float) -> float:
	var h := float(m.hauteur(x, z))
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 3.0, z), Vector3(x, h - 3.0, z))
	q.exclude = [j.get_rid()]
	var r := m.get_world_3d().direct_space_state.intersect_ray(q)
	var y := float(r["position"].y) if not r.is_empty() else h
	return y + ObjetMonde.hausse_sol(Vector3(x, y, z), m)

## Zone de neige dégagée (hors pavés, sans bâtiment, presque plate) de rx x rz m la plus proche de `centre` (spirale par pas de 1 m).
func _zone_libre(centre: Vector3, rx: float, rz: float) -> Vector3:
	for rayon in 16:
		for dx in range(-rayon, rayon + 1):
			for dz in range(-rayon, rayon + 1):
				if maxi(absi(dx), absi(dz)) != rayon:
					continue
				var c := centre + Vector3(dx, 0, dz)
				var ok := true
				var hmin := INF
				var hmax := -INF
				for ix in 5:
					for iz in 5:
						var x := c.x + (ix / 4.0 - 0.5) * rx
						var z := c.z + (iz / 4.0 - 0.5) * rz
						var h := float(m.hauteur(x, z))
						var y := _sol(x, z)
						var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 15.0, z), Vector3(x, h - 1.0, z))
						q.exclude = [j.get_rid()]
						var r := m.get_world_3d().direct_space_state.intersect_ray(q)
						var haut := float(r["position"].y) if not r.is_empty() else h
						if absf(y - h) > 0.04 or absf(haut - h) > 0.04:          # pavés, plancher, rocher, toit, bâtiment
							ok = false
						hmin = minf(hmin, h)
						hmax = maxf(hmax, h)
				if ok and hmax - hmin < 0.35:
					print("ZONE libre ", c)
					return c
	return centre

## Vue de dessus (repérage) : caméra à part, au-dessus de `centre`.
func _dessus(centre: Vector3, haut: float, nom: String) -> void:
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1, -0.001), Vector3(0, 0, -1)), centre + Vector3(0, haut, 0))
	cam.current = true
	await _att(6)
	await _cap(nom)
	cam.current = false
	j.camera.current = true
	cam.queue_free()

## Joueur figé à `oeil_xz` (sol relu) regardant le point `cible` (monde).
func _regarder(pied: Vector3, cible: Vector3) -> void:
	j.set_physics_process(false)
	j.velocity = Vector3.ZERO
	j.global_position = pied + Vector3(0, 0.05, 0)
	var off := pied - cible
	j.rotation.y = atan2(off.x, off.z)
	var oeil: Vector3 = j.camera.global_position
	j.tete.rotation.x = -atan2(oeil.y - cible.y, Vector2(off.x, off.z).length())

func _vider() -> void:
	for n in _poses:
		if is_instance_valid(n):
			n.queue_free()
	_poses.clear()

func _poser(oid: String, x: float, z: float, lacet: float) -> void:
	var o := ObjetMonde.creer(oid)
	m.add_child(o)
	o.global_position = Vector3(x, _sol(x, z), z)
	o.rotation.y = lacet
	_poses.append(o)
	print("POSE ", oid, " ", o.global_position, " boite ", ObjetMonde.boite(o, o.global_transform), " terrain ", m.hauteur(x, z))

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_dossier = a.substr(9)
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _att(40)
	j = m.joueur
	j.mains.visible = false                 # vue dégagée : ni bras, ni torche, ni interface
	for cl in m.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	if m.hud != null:
		m.hud.visible = false
	if m.get("village") != null and m.village.has_signal("bati_fini") and not m.village.bati:
		await m.village.bati_fini
	await _att(20)

	# 1. bijoux posés sur la place du village (deux rangées, vus de près puis à hauteur d'homme)
	var c := Vector3(38.2, 0.0, 44.4)
	for i in BIJOUX.size():
		var col := i % 5
		var rg := i / 5
		_poser(BIJOUX[i], c.x + (col - 2) * 0.34, c.z + rg * 0.36, 0.3 * (i % 3 - 1))
	var cible := Vector3(c.x, _sol(c.x, c.z + 0.18), c.z + 0.18)
	_regarder(Vector3(c.x, _sol(c.x, c.z - 0.75), c.z - 0.75), cible)
	await _att(20)
	print("CAM ", j.camera.global_position, " -> ", cible)
	await _cap("1_bijoux_au_sol_de_pres.png")
	if OS.get_cmdline_user_args().has("--sans-paves"):
		for n in m.find_children("*", "Node3D", true, false):
			if n is RuesVillage:
				(n as Node3D).visible = false
				print("PAVES cachés ", n.get_path())
		await _cap("1b_sans_paves.png")
	_regarder(Vector3(c.x + 0.6, _sol(c.x + 0.6, c.z - 2.2), c.z - 2.2), cible)
	await _att(10)
	await _cap("2_bijoux_au_sol_hauteur_homme.png")
	_vider()
	# 1 bis. les mêmes dans la neige (hors pavés)
	var cn := _zone_libre(c, 3.0, 4.0)
	if OS.get_cmdline_user_args().has("--reperage"):
		await _dessus(Vector3(cn.x, _sol(cn.x, cn.z), cn.z), 14.0, "0_reperage_neige.png")
	for i in BIJOUX.size():
		_poser(BIJOUX[i], cn.x + (i % 5 - 2) * 0.34, cn.z + (i / 5) * 0.36, 0.3 * (i % 3 - 1))
	var cible_n := Vector3(cn.x, _sol(cn.x, cn.z + 0.18), cn.z + 0.18)
	_regarder(Vector3(cn.x, _sol(cn.x, cn.z - 0.75), cn.z - 0.75), cible_n)
	await _att(15)
	await _cap("1c_bijoux_dans_la_neige.png")
	_vider()

	# 2. objets lâchés depuis le sac (Lacher : l'objet lui-même au sol ; sans modèle -> sacoche)
	var inv: Inventaire = j.inventaire
	j.set_physics_process(true)
	j.global_position = Vector3(c.x, _sol(c.x, c.z) + 0.1, c.z)
	j.rotation.y = 0.0
	j.tete.rotation.x = 0.0
	await _att(20)
	for oid: String in ["anneau_braise", "epee_or", "amulette_givre"]:
		inv.ajouter(oid, 1)
		Lacher.lacher(j, m.hud, oid, 1)
		j.rotation.y += 0.9
		await _att(4)
	inv.ajouter("potion_soin", 2)
	inv.ajouter("minerai_fer", 2)
	Lacher.lacher(j, m.hud, "potion_soin", 1)
	j.rotation.y += 0.9
	await _att(4)
	Lacher.lacher(j, m.hud, "minerai_fer", 1)
	await _att(6)
	var pied := j.global_position
	_regarder(pied + Vector3(0.2, 0, 2.1), pied)
	await _att(10)
	await _cap("3_objets_laches_autour_du_joueur.png")

	# 3. armures au sol (celles qui ont un modèle : glb « sol » des agents X / Y ou version affaissée)
	var armures: Array = []
	for oid: String in Inventaire.ids_connus():
		if Inventaire.categorie_de(oid) == "armure" and ObjetMonde.chemin_modele(oid) != "":
			armures.append(oid)
	if not armures.is_empty():
		var choix: Array = []          # une pièce par emplacement et par matière, variée (cuir, fourrure, os, fer, acier)
		for pref: String in ["cuirasse_acier_nordique", "armure_fourrure", "casque_os", "heaume_jarl", "gantelets_fer", "bottes_cuir"]:
			if pref in armures:
				choix.append(pref)
		if choix.is_empty():
			choix = armures.slice(0, 6)
		var c2 := _zone_libre(Vector3(41.0, 0.0, 46.5), 3.0, 4.0)
		for i in choix.size():
			_poser(choix[i], c2.x + (i % 3 - 1) * 1.0, c2.z + (i / 3) * 1.0, 0.25 * (i % 3 - 1))
		var cb := Vector3(c2.x, _sol(c2.x, c2.z + 0.5), c2.z + 0.5)
		_regarder(Vector3(c2.x, _sol(c2.x, c2.z - 1.9), c2.z - 1.9), cb)
		await _att(15)
		await _cap("4_armures_au_sol.png")
		_vider()
	else:
		print("INFO aucune armure avec modèle au sol")

	if OS.get_cmdline_user_args().has("--reperage"):
		var fg: Node3D = m.find_child("Forge", true, false)
		if fg != null:
			await _dessus(fg.global_position, 9.0, "0_reperage_forge.png")
	# 4. étals : Brodd (devant la forge), Grima (près du puits)
	for nom: String in ["forgeron", "ancienne"]:
		var et: Node3D = m.find_child("Etal_" + nom, true, false)
		if et == null:
			print("INFO pas d'étal ", nom)
			continue
		print("INFO étal ", nom, " : ", et.pieces(), " (stock ", Marchand.stock(nom).keys(), ")")
		var avant: Vector3 = et.global_transform * Vector3(0.35, 0.0, 1.45)
		avant.y = _sol(avant.x, avant.z)
		var haut: Vector3 = et.global_transform * Vector3(0.0, 0.62, 0.0)
		_regarder(avant, haut)
		await _att(15)
		await _cap("5_etal_%s.png" % ("brodd" if nom == "forgeron" else "grima"))
		var loin: Vector3 = et.global_transform * Vector3(1.4, 0.0, 3.4)
		loin.y = _sol(loin.x, loin.z)
		_regarder(loin, haut)
		await _att(10)
		await _cap("6_etal_%s_recul.png" % ("brodd" if nom == "forgeron" else "grima"))
	quit(0)
