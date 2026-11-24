extends "res://outils/film_rayon_v3.gd"
## FILM des SORTS DE FEU en vue FPS (chantier magie/feu_v2) : boule de feu à deux mains (charge entre les mains, tir, explosion),
## boule de feu à une main, jet de flammes (allumage, jet en l'air, impact sur un mur et sur le sol).
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_feu_v2.gd -- --nouvelle
##         --paisible [--crypte] [--images=<dossier>] [--cas=boule2,boule1,jet] [--perf]
## Sans --crypte : plein air de nuit (arène à 500 m, comme film_rayon_v3). --crypte : descend dans le tertre.
## --perf : imprime les FPS moyens par phase (« PERF <phase> <ips> »).

var _mur_p := Vector3.ZERO
var _mur_n: StaticBody3D

func _go() -> void:
	RetourImpact.muet = false
	_dossier = _arg("images", "")
	if _dossier != "":
		DirAccess.make_dir_recursive_absolute(_dossier)
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	magie = j.mains.magie
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _arg("crypte") != "":
		var y0 := j.global_position.y
		var n := 0
		while n < 30 * 60 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
			await process_frame
			n += 1
	await _attendre(3.0)
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	_etiquette(s)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var cip := root.get_node_or_null("CompteurIps")
	if cip != null:
		cip.visible = false
		cip.process_mode = Node.PROCESS_MODE_DISABLED
	if _arg("perf") != "":
		Engine.max_fps = 0
	if _arg("crypte") == "":
		await _site_ouvert()
		await _mur_pose(6.5)
	await _film_feu()
	_texte("")
	await _attendre(0.6)
	print("FIN_SEQUENCE")
	if not _ips.is_empty():
		_bilan_ips()
	quit(0)

## Mur large à `dist` m devant le joueur (plein air) : le jet et la boule y éclatent.
func _mur_pose(dist: float) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(10, 5, 0.6)
	cs.shape = bx
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bx.size
	mi.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.28, 0.27)
	mt.roughness = 1.0
	mi.material_override = mt
	b.add_child(mi)
	s.add_child(b)
	_mur_n = b
	var o: Vector3 = j.global_position
	b.global_position = Vector3(o.x + 3.0, o.y + 2.2, o.z - dist)
	_mur_p = b.global_position + Vector3(0, -2.2, 0.3)

func _cap_seq(nom: String, n: int, pas: float) -> void:
	for k in n:
		await _capture("%s_%d" % [nom, k])
		await _attendre(pas)

func _film_feu() -> void:
	var cas := _arg("cas", "boule2,boule1,jet").split(",", false)
	var crypte := _arg("crypte") != ""
	var cible: Vector3
	if crypte:
		cible = _libre(7.0, 0.0) + Vector3.UP * 1.2
	else:
		cible = Vector3(j.global_position.x + 3.0, j.global_position.y + 1.2, j.global_position.z - 6.0)
	var dr: CharacterBody3D = null
	if crypte:
		dr = _draugr(_libre(7.0, 0.0), "guerrier", 9000.0)
		dr.set("_course", 0.0)
	await _regarder(cible, 0.6)
	var gm := GestionMagie.obtenir()
	print("COUCHE niveau=%s k=%s fine=%s fin_actif=%s feu_v1=%s" % [gm.couche.niveau if gm.couche != null else "-", gm.couche.k if gm.couche != null else "-", gm.couche.fine() if gm.couche != null else "-", gm.fin_actif, GestionMagie.feu_v1])
	await _debut("sorts de feu")
	if "boule2" in cas:
		magie.equiper("gauche", "boule_feu")
		magie.equiper("droite", "boule_feu")
		await _attendre(0.5)
		_phase = "boule2"
		_texte("boule de feu à deux mains")
		magie.appuyer("gauche")
		await _attendre(0.05)
		magie.appuyer("droite")
		await _attendre(0.25)
		await _capture("b2_charge0")
		await _attendre(0.35)
		await _capture("b2_charge1")
		await _attendre(0.45)
		await _capture("b2_charge2")
		await _attendre(0.6)
		await _capture("b2_pleine")
		await _attendre(0.5)
		magie.relacher("gauche")
		magie.relacher("droite")
		await _attendre(0.07)
		await _capture("b2_tir0")
		await _attendre(0.15)
		await _capture("b2_tir1")
		await _attendre(0.2)
		await _capture("b2_vol")
		await _attendre(0.2)
		await _capture("b2_impact0")
		await _attendre(0.15)
		await _capture("b2_impact1")
		await _attendre(0.25)
		await _capture("b2_impact2")
		await _attendre(1.6)
	if "boule1" in cas:
		magie.equiper("gauche", "")
		magie.equiper("droite", "boule_feu")
		await _attendre(0.5)
		_phase = "boule1"
		_texte("boule de feu à une main")
		magie.appuyer("droite")
		await _attendre(0.3)
		await _capture("b1_charge0")
		await _attendre(0.9)
		await _capture("b1_charge1")
		await _attendre(0.6)
		await _capture("b1_pleine")
		magie.relacher("droite")
		await _attendre(0.12)
		await _capture("b1_tir")
		await _attendre(0.3)
		await _capture("b1_impact0")
		await _attendre(0.3)
		await _capture("b1_impact1")
		await _attendre(1.8)
	if "jet" in cas:
		magie.equiper("droite", "epee")
		magie.equiper("gauche", "jet_flammes")
		await _attendre(0.5)
		_phase = "jet"
		_texte("jet de flammes")
		if _mur_n != null:
			# mur plus près pour que l'impact du jet se lise (portée 9 m)
			_mur_n.global_position = Vector3(j.global_position.x + 1.4, _mur_n.global_position.y, j.global_position.z - 3.6)
			await _regarder(Vector3(j.global_position.x + 1.4, j.global_position.y + 1.3, j.global_position.z - 3.6), 0.4)
		magie.appuyer("gauche")
		await _attendre(0.2)
		await _capture("jet_allumage")
		await _attendre(0.6)
		await _capture("jet_impact0")
		await _attendre(0.8)
		await _capture("jet_impact1")
		# regard vers le sol à ~3 m
		var o: Vector3 = j.camera.global_position
		var av: Vector3 = -j.camera.global_basis.z
		av.y = 0.0
		av = av.normalized()
		await _regarder(o + av * 3.0 + Vector3.DOWN * 1.5, 0.5)
		await _attendre(0.7)
		await _capture("jet_sol")
		await _attendre(0.6)
		await _capture("jet_sol1")
		magie.relacher("gauche")
		await _attendre(0.6)
		await _capture("jet_fin")
		await _attendre(1.5)
