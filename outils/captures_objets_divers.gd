extends SceneTree
## Captures EN JEU des OBJETS DIVERS (glb de sources_blender/objets/objets_divers.py via ObjetMonde) : potions et vivres sur les pavés,
## ingrédients dans la neige, tomes, reliques et objets de quête, objets lâchés autour du joueur, étal de Grima.
##   godot --path . --script res://outils/captures_objets_divers.gd -- --nouvelle --heure=12 --paisible --sortie=<dossier>
## (avec fenêtre : godot_slot.sh, hors écran). Vue subjective du joueur, figé ; rendu du jeu (640 x 360, post-traitement ps1).
const SCENE := preload("res://scenes/foret_test.tscn")
const GROUPES := [
	["1_potions_vivres_paves", false, ["potion_soin", "potion_soin_forte", "potion_mana", "potion_endurance", "pain_seigle", "viande_sechee"]],
	["2_ingredients_neige", true, ["os_draugr", "poussiere_tombe", "ecaille_dragon", "minerai_fer", "minerai_argent", "cristal_givre",
		"champignon_lumineux", "fourrure_troll", "croc_troll"]],
	["3_tomes_paves", false, ["tome_boule_feu", "tome_explosion_incendiaire", "tome_lance_givre", "tome_souffle_givre", "tome_nova_gelee",
		"tome_chaine_eclairs", "tome_tempete_statique", "tome_drain_vie", "tome_explosion_obscure", "tome_enchant_electricite",
		"tome_enchant_glace", "tome_enchant_tenebres"]],
	["4_divers_neige", true, ["lame_antique", "relique_offrande", "anneau_cuivre", "coupe_argent", "collier_or"]],
	["5_quete_paves", false, ["anneau_givre", "amulette_eirik", "fragment_sceau_os", "fragment_sceau_givre", "fragment_sceau_eau",
		"cle_archives", "registre_hrafn", "journal_sigrun", "broche_sigrun"]],
]
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

## Gros plan (caméra à part, accroupi) : œil à `haut` m au-dessus du sol, `recul` m devant la cible, champ serré.
func _gros_plan(cible: Vector3, recul: float, haut: float, champ: float, nom: String) -> void:
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = champ
	cam.near = 0.02
	var oeil := cible + Vector3(0.15, haut, -recul)
	cam.global_transform = Transform3D(Basis.looking_at(cible - oeil, Vector3.UP), oeil)
	cam.current = true
	await _att(8)
	await _cap(nom)
	cam.current = false
	j.camera.current = true
	cam.queue_free()

## Pose `ids` en rangées de `par_rang` (pas de `pas` m) autour de `c`, puis deux vues : de près (1,1 m) et à hauteur d'homme (2,4 m).
func _rangees(nom: String, c: Vector3, ids: Array, par_rang: int, pas: float) -> void:
	var rangs := ceili(float(ids.size()) / par_rang)
	for i in ids.size():
		var col := i % par_rang
		var rg := i / par_rang
		var n_rang := mini(par_rang, ids.size() - rg * par_rang)
		_poser(ids[i], c.x + (col - (n_rang - 1) * 0.5) * pas, c.z + (rg - (rangs - 1) * 0.5) * pas, 0.25 * (i % 3 - 1))
	var cible := Vector3(c.x, _sol(c.x, c.z), c.z)
	await _att(10)
	await _gros_plan(cible, 0.55 + rangs * pas * 0.9, 0.75 + rangs * 0.12, 44.0, nom + "_gros_plan.png")
	var recul := 0.75 + rangs * pas * 0.5
	_regarder(Vector3(c.x, _sol(c.x, c.z - recul), c.z - recul), cible)
	await _att(15)
	await _cap(nom + "_de_pres.png")
	_regarder(Vector3(c.x + 0.5, _sol(c.x + 0.5, c.z - recul - 1.4), c.z - recul - 1.4), cible)
	await _att(10)
	await _cap(nom + "_hauteur_homme.png")
	_vider()

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

	var c := Vector3(38.2, 0.0, 44.4)              # place pavée du village
	var cn := _zone_libre(c, 3.0, 4.0)             # neige dégagée la plus proche
	for g: Array in GROUPES:
		var ids: Array = g[2]
		var par := 5 if ids.size() > 6 else 3
		var pas := 0.5 if g[0] != "4_divers_neige" else 0.62
		if g[0] == "3_tomes_paves":
			par = 4
			pas = 0.4
		await _rangees(g[0], cn if g[1] else c, ids, par, pas)

	# objets lâchés depuis le sac autour du joueur (Lacher : l'objet lui-même, pas une sacoche)
	var inv: Inventaire = j.inventaire
	j.set_physics_process(true)
	j.global_position = Vector3(c.x, _sol(c.x, c.z) + 0.1, c.z)
	j.rotation.y = 0.0
	j.tete.rotation.x = 0.0
	await _att(20)
	for oid: String in ["potion_soin", "tome_boule_feu", "minerai_argent", "cristal_givre", "pain_seigle"]:
		inv.ajouter(oid, 1)
		Lacher.lacher(j, m.hud, oid, 1)
		j.rotation.y += TAU / 5.0
		await _att(4)
	await _att(6)
	var pied := j.global_position
	_regarder(pied + Vector3(0.3, 0, 2.3), pied)
	await _att(10)
	await _cap("6_objets_laches_autour_du_joueur.png")
	await _gros_plan(pied, 1.4, 0.9, 50.0, "6b_objets_laches_gros_plan.png")

	# étal de Grima (près du puits) : fioles, livres, vivres de son stock du moment
	var et: Node3D = m.find_child("Etal_ancienne", true, false)
	if et != null:
		print("INFO étal Grima : ", et.pieces(), " (stock ", Marchand.stock("ancienne").keys(), ")")
		var avant: Vector3 = et.global_transform * Vector3(0.2, 0.0, 1.3)
		avant.y = _sol(avant.x, avant.z)
		var haut: Vector3 = et.global_transform * Vector3(0.0, 0.55, 0.0)
		_regarder(avant, haut)
		await _att(15)
		await _cap("7_etal_grima.png")
		await _gros_plan(haut, 0.9, 0.45, 46.0, "7b_etal_grima_gros_plan.png")
		var loin: Vector3 = et.global_transform * Vector3(1.2, 0.0, 3.2)
		loin.y = _sol(loin.x, loin.z)
		_regarder(loin, haut)
		await _att(10)
		await _cap("8_etal_grima_recul.png")
	else:
		print("INFO pas d'étal de Grima")
	quit(0)
