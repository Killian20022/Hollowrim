extends SceneTree
## FILM et MESURE des SORTS DE FOUDRE (branche magie/foudre_v2, docs/MAGIE_FOUDRE_V2.md) en vue FPS dans la crypte :
## main au repos (arc électrique équipé), canalisation de l'arc sur un draugr, puis éclair lancé / chaîne d'éclairs sur 3 draugrs.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_foudre.gd -- --nouvelle
##         --paisible [--images=<dossier>] [--foudre-v1] [--sans-lumiere-film] [--vue=tps]
##   --perf : pas de film, temps réels ; alterne ancien (v1) / nouveau (v2) rendu 2 fois chacun dans la même séance et imprime
##            « PERF <rendu> repos <ips> canal <ips> gpu <ms> » (mêmes conditions pour les deux rendus).
## « DEBUT_SEQUENCE <s> » : instant à garder au montage (ffmpeg -ss).

const DT := 1.0 / 30.0

var s: Node
var j: CharacterBody3D
var magie: MainSort
var l: Label
var _dossier := ""
var _n_cap := 0
var _perf := false

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

var _t_film := 0.0
func _image() -> void:
	_t_film += DT
	if j != null:
		j.vie = j.vie_max
		j.mana = j.mana_max
	await process_frame

func _attendre(sec: float) -> void:
	if _perf:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < sec * 1000.0:
			await _image()
		return
	for i in maxi(1, roundi(sec / DT)):
		await _image()

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(12, 12)
	calque.add_child(l)

func _texte(t: String) -> void:
	if l != null:
		l.text = t

func _capture(nom: String) -> void:
	if _dossier == "":
		return
	var im := root.get_viewport().get_texture().get_image()
	_n_cap += 1
	im.save_png(_dossier.path_join("%02d_%s.png" % [_n_cap, nom]))

func _regarder(p: Vector3, duree: float, suivre: Node3D = null, haut := 0.0) -> void:
	var n := maxi(1, roundi(duree / DT))
	var y0 := j.rotation.y
	var x0: float = j.tete.rotation.x
	for k in n:
		var cible := p
		if suivre != null and is_instance_valid(suivre):
			cible = Elements._centre(suivre) + Vector3.UP * haut
		var o: Vector3 = j.camera.global_position
		var d := cible - o
		var y1 := atan2(-d.x, -d.z)
		var x1 := atan2(d.y, Vector2(d.x, d.z).length())
		var u := smoothstep(0.0, 1.0, float(k + 1) / n)
		j.rotation.y = lerp_angle(y0, y1, u)
		j.tete.rotation.x = lerpf(x0, x1, u)
		await _image()

func _draugr(p: Vector3, type: String) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(load("res://scripts/draugr.gd"))
	d.type = type
	d.joueur = j
	d.hud = s.get("hud")
	d.ident = "film_foudre_%s_%d" % [type, randi() % 100000]
	s.add_child(d)
	d.global_position = _sol(p)
	var v := j.global_position - d.global_position
	d.rotation.y = atan2(v.x, v.z)
	d.vie_max = 9000.0
	d.vie = 9000.0
	# film : il reste sur place (IA active pour ses réactions, mais il ne marche pas sur le joueur)
	for k in ["_marche", "_marche_proche", "_course"]:
		d.set(k, 0.0)
	d.set_physics_process(true)
	if d.has_method("_changer"):
		var cst: Dictionary = d.get_script().get_script_constant_map()
		if cst.has("TRAQUE"):
			d.call("_changer", cst["TRAQUE"])
	return d

func _sol(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0, 1)
	q.exclude = [j.get_rid()]
	var r := j.get_world_3d().direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else p

func _devant(dist: float, cote := 0.0) -> Vector3:
	var av := -j.global_basis.z
	av.y = 0.0
	av = av.normalized()
	return j.global_position + av * dist + av.cross(Vector3.UP) * cote

func _libre(dist: float, cote: float) -> Vector3:
	var d := dist
	while d > 2.5:
		var p := _sol(_devant(d, cote))
		var o: Vector3 = j.camera.global_position
		var q := PhysicsRayQueryParameters3D.create(o, p + Vector3.UP * 1.1, 1)
		q.exclude = [j.get_rid()]
		var r := j.get_world_3d().direct_space_state.intersect_ray(q)
		if r.is_empty() and absf(p.y - j.global_position.y) < 0.6:
			return p
		d -= 0.5
	return _sol(_devant(3.0, cote))

## Lumière de tournage (film seulement) : la crypte est très sombre au 480x270 ; une lampe douce au-dessus du joueur.
func _lumiere_film() -> void:
	if _arg("sans-lumiere-film") != "" or _perf:
		return
	var lu := OmniLight3D.new()
	lu.light_color = Color(1.0, 0.92, 0.8)
	lu.light_energy = 1.1
	lu.omni_range = 16.0
	lu.shadow_enabled = false
	j.camera.add_child(lu)
	lu.position = Vector3(0.0, 1.2, 1.5)

func _go() -> void:
	RetourImpact.muet = false
	_perf = _arg("perf") != ""
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
	var y0 := j.global_position.y
	var n := 0
	while n < 30 * 60 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
		await process_frame
		n += 1
	await _attendre(2.5)
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	if _arg("vue") == "tps" and j.has_method("basculer_vue"):
		j.call("basculer_vue", true)
	_etiquette(s)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.visible = false
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	_lumiere_film()
	await _regarder(_devant(5.0) + Vector3.UP * 1.2, 0.1)
	if _perf:
		await _mesure()
	elif _arg("tous") != "":
		await _film_tous()
	else:
		await _film()
	_texte("")
	await _attendre(0.4)
	print("FIN_SEQUENCE")
	quit(0)

# ------------------------------------------------------------------ film

func _film() -> void:
	var rendu := "AVANT (v1)" if GestionMagie.foudre_v1 else "APRÈS (v2)"
	magie.equiper("gauche", "arc_electrique")
	var d := _draugr(_libre(3.8, 0.3), "guerrier")
	var d2 := _draugr(_libre(7.0, -2.4), "squelette")
	var d3 := _draugr(_libre(7.6, 2.2), "guerrier")
	await _attendre(0.5)
	await _regarder(Elements._centre(d) + Vector3.DOWN * 0.15, 0.2)
	await _attendre(0.6)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() * DT))
	_texte("%s : main au repos" % rendu)
	await _attendre(1.0)
	await _capture("repos")
	await _attendre(0.6)
	_texte("%s : arc électrique canalisé" % rendu)
	magie.appuyer("gauche")
	await _attendre(DT * 2)
	await _capture("depart")
	await _attendre(DT * 4)
	await _capture("arcs_en_vol")
	var jr: Dictionary = FoudreV2.journal
	if not jr.is_empty():
		var o: Vector3 = jr.o
		print("JOURNAL doigts-paume ", (jr.doigts as PackedVector3Array).size(), " ", Array(jr.doigts).map(func(p): return snappedf((p as Vector3).distance_to(o), 0.001)), " bouts ", Array(jr.bouts).map(func(p): return snappedf((p as Vector3).distance_to(o), 0.01)))
	await _regarder(Vector3.ZERO, 0.9, d, -0.15)
	await _capture("impact")
	await _regarder(Vector3.ZERO, 0.6, d, -0.15)
	await _capture("convulsion")
	await _regarder(Vector3.ZERO, 1.6, d, -0.15)
	magie.relacher("gauche")
	await _attendre(0.9)
	_texte("%s : éclair lancé, chaîne d'éclairs" % rendu)
	magie.equiper("gauche", "chaine_eclairs")
	await _attendre(0.8)
	await _regarder(Vector3.ZERO, 0.4, d2, -0.1)
	magie.appuyer("gauche")
	await _attendre(DT)
	magie.relacher("gauche")
	await _attendre(0.25)
	await _capture("chaine")
	await _attendre(1.4)
	await _regarder(Vector3.ZERO, 0.4, d3, -0.1)
	magie.appuyer("gauche")
	await _attendre(DT)
	magie.relacher("gauche")
	await _attendre(0.2)
	await _capture("chaine2")
	await _attendre(1.6)

# ------------------------------------------------------------------ film de TOUS les sorts électriques (--tous)

func _titre(rendu: String, t: String) -> void:
	_texte("%s : %s" % [rendu, t])
	print("TITRE %.3f %s" % [Engine.get_process_frames() * DT, t])

func _lancer(sort: String, charge := 0.0, maintien := 0.0) -> void:
	magie.equiper("gauche", sort)
	await _attendre(0.35)
	magie.appuyer("gauche")
	await _attendre(maxf(DT, charge + maintien))
	magie.relacher("gauche")

func _film_tous() -> void:
	var rendu := "AVANT (v1)" if GestionMagie.foudre_v1 else "APRÈS (v2)"
	var d := _draugr(_libre(3.8, 0.3), "guerrier")
	var d2 := _draugr(_libre(7.0, -2.4), "squelette")
	var d3 := _draugr(_libre(7.6, 2.2), "guerrier")
	magie.equiper("gauche", "arc_electrique")
	await _attendre(0.5)
	await _regarder(Elements._centre(d) + Vector3.DOWN * 0.15, 0.2)
	await _attendre(0.6)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() * DT))
	# 1. arc électrique (canalisé)
	_titre(rendu, "arc électrique (canalisé)")
	await _attendre(0.5)
	magie.appuyer("gauche")
	await _attendre(0.8)
	await _capture("arc")
	await _regarder(Vector3.ZERO, 1.0, d, -0.15)
	magie.relacher("gauche")
	await _attendre(0.5)
	# 2. chaîne d'éclairs
	_titre(rendu, "chaîne d'éclairs")
	magie.equiper("gauche", "chaine_eclairs")
	await _regarder(Vector3.ZERO, 0.5, d2, -0.1)
	magie.appuyer("gauche")
	await _attendre(DT)
	magie.relacher("gauche")
	await _attendre(0.25)
	await _capture("chaine")
	await _attendre(0.9)
	# 3. statut choc (étincelles et arcs sur le corps de la cible)
	_titre(rendu, "statut choc sur la cible")
	await _regarder(Vector3.ZERO, 0.4, d2, -0.1)
	await _capture("choc")
	await _attendre(0.5)
	# 4. orage runique (sort chargé, éclairs de Force)
	_titre(rendu, "orage runique (chargé)")
	magie.equiper("gauche", "orage_runique")
	await _regarder(Vector3.ZERO, 0.5, d, -0.2)
	magie.appuyer("gauche")
	await _attendre(0.5)
	await _capture("orage_charge")
	await _attendre(0.65)
	magie.relacher("gauche")
	await _attendre(0.3)
	await _capture("orage")
	await _attendre(1.1)
	# 5. tempête statique (zone)
	_titre(rendu, "tempête statique (zone)")
	magie.equiper("gauche", "tempete_statique")
	var milieu := (d2.global_position + d3.global_position) * 0.5
	await _regarder(milieu + Vector3.UP * 0.3, 0.5)
	magie.appuyer("gauche")
	await _attendre(0.75)
	magie.relacher("gauche")
	await _attendre(0.9)
	await _capture("tempete")
	await _attendre(1.5)
	# 6. impact électrique au sol (chaîne dans le vide, sur la dalle)
	_titre(rendu, "impact électrique au sol")
	magie.equiper("gauche", "chaine_eclairs")
	await _regarder(_sol(_devant(3.2, -1.6)) + Vector3.UP * 0.05, 0.5)
	magie.appuyer("gauche")
	await _attendre(DT)
	magie.relacher("gauche")
	await _attendre(0.12)
	await _capture("impact_sol")
	await _attendre(1.0)
	# 7. lame d'orage (enchantement de l'épée), puis coups sur le draugr
	_titre(rendu, "lame d'orage (enchantement)")
	magie.equiper("gauche", "enchant_electricite")
	await _attendre(0.35)
	magie.appuyer("gauche")
	await _attendre(0.6)
	magie.relacher("gauche")
	await _attendre(0.8)
	await _regarder(_devant(2.0) + Vector3.UP * 0.6, 0.4)
	await _capture("lame")
	var v := d.global_position - j.global_position
	v.y = 0.0
	j.global_position = d.global_position - v.normalized() * 1.7
	await _regarder(Vector3.ZERO, 0.3, d, -0.1)
	for _k in 2:
		j.mains.entrees.appuyer()
		await _attendre(DT * 2)
		j.mains.entrees.relacher()
		await _attendre(0.25)
		await _capture("lame_coup")
		await _attendre(0.45)
	await _attendre(0.6)

# ------------------------------------------------------------------ mesure

## --perf --tous : orage runique (1,2 s après le relâchement) et tempête statique (3 s de zone), v1 / v2 entrelacés.
func _mesure_tous(d: Node3D) -> void:
	for tour in int(_arg("tours", "4")):
		GestionMagie.foudre_v1 = tour % 2 == 0
		var nom := "v1" if GestionMagie.foudre_v1 else "v2"
		await _regarder(Vector3.ZERO, 0.3, d, -0.2)
		magie.equiper("gauche", "orage_runique")
		await _attendre(0.4)
		magie.appuyer("gauche")
		await _attendre(1.1)
		magie.relacher("gauche")
		await _attendre(DT * 2)
		var orage := await _fenetre(1.2, d)
		await _attendre(1.0)
		magie.equiper("gauche", "tempete_statique")
		await _attendre(0.4)
		magie.appuyer("gauche")
		await _attendre(0.75)
		magie.relacher("gauche")
		await _attendre(0.4)
		var tempete := await _fenetre(3.0, d)
		await _attendre(2.5)
		print("PERF %s orage %.1f ips (gpu %.2f ms) tempete %.1f ips (gpu %.2f ms)" % [nom, orage[0], orage[1], tempete[0], tempete[1]])


func _fenetre(duree: float, suivre: Node3D) -> Array:
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var t0 := Time.get_ticks_usec()
	var nb := 0
	var gpu := 0.0
	var cpu := 0.0
	while Time.get_ticks_usec() - t0 < int(duree * 1e6):
		if suivre != null:
			var o: Vector3 = j.camera.global_position
			var dd := Elements._centre(suivre) - o
			j.rotation.y = atan2(-dd.x, -dd.z)
			j.tete.rotation.x = atan2(dd.y, Vector2(dd.x, dd.z).length())
		await _image()
		nb += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var sec := float(Time.get_ticks_usec() - t0) / 1e6
	return [nb / sec, gpu / maxi(nb, 1), cpu / maxi(nb, 1)]

func _mesure() -> void:
	magie.equiper("gauche", "arc_electrique")
	var d := _draugr(_libre(4.6, 0.3), "guerrier")
	await _attendre(1.5)
	if _arg("tous") != "":
		await _mesure_tous(d)
		return
	for tour in int(_arg("tours", "6")):
		GestionMagie.foudre_v1 = tour % 2 == 0
		var nom := "v1" if GestionMagie.foudre_v1 else "v2"
		magie.equiper("gauche", "chaine_eclairs")
		await _attendre(0.3)
		magie.equiper("gauche", "arc_electrique")
		await _attendre(1.0)
		var repos := await _fenetre(2.0, d)
		magie.appuyer("gauche")
		await _attendre(0.6)
		FoudreV2.prof_us = 0
		FoudreV2.prof_img = 0
		GestionMagie.prof_us = 0
		var f0 := Engine.get_process_frames()
		var canal := await _fenetre(4.0, d)
		print("PROF %s GestionMagie._process : %.3f ms par image" % [nom, GestionMagie.prof_us / 1000.0 / maxi(Engine.get_process_frames() - f0, 1)])
		if FoudreV2.prof_img > 0:
			print("PROF canal v2 : %.3f ms par image (%d images)" % [FoudreV2.prof_us / 1000.0 / FoudreV2.prof_img, FoudreV2.prof_img])
		magie.relacher("gauche")
		await _attendre(1.0)
		print("PERF %s repos %.1f ips (gpu %.2f ms) canal %.1f ips (gpu %.2f ms, process %.2f ms)" % [nom, repos[0], repos[1], canal[0], canal[1], canal[2]])
