extends SceneTree
## FILM du RAGDOLL DE PROJECTION + RELEVÉ des sorts de l'esprit (scripts/magie/ragdoll_esprit.gd), vue FPS, pilote automatique, crypte,
## lumière de tournage (film seulement) :
##   1. Répulsion chargée à vitesse normale : 3 ennemis (2 squelettes, 1 draugr) projetés en ragdoll contre un mur et des tonneaux /
##      urnes, ils retombent, se relèvent (clips capturés) et reviennent ;
##   2. la même chose AU RALENTI (×0,3, physique à 200 Hz : pas de saccade) ;
##   3. Lévitation lâchée : un squelette soulevé puis lâché retombe en ragdoll et se relève.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_ragdoll_esprit.gd -- --nouvelle
##         --crypte=0,-24,0,-4 --paisible [--images=<dossier>] [--plans=normal,ralenti,levitation]
## MESURE de FPS en combat (sans --write-movie, avec --disable-vsync) : --mesure : 6 ennemis, Répulsion chargée toutes les 4 s pendant
##   ~16 s (ragdolls, relevés, retours), images comptées ; « MESURE fps_moyen=… p1_bas=… » ; à comparer avec -- --sans-ragdoll-esprit.
## « DEBUT_SEQUENCE <s> » : instant à garder au montage (ffmpeg -ss).

const DT := 1.0 / 30.0

var s: Node
var j: CharacterBody3D
var magie: MainSort
var es: SortsEsprit
var l: Label
var _lampe: OmniLight3D
var _dossier := ""
var _n_cap := 0
var _ennemis: Array = []

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _image() -> void:
	if j != null:
		j.vie = j.vie_max
	_suivre_lampe()
	await process_frame

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		await _image()

func _suivre_lampe() -> void:
	if _lampe != null and is_instance_valid(_lampe) and j != null:
		_lampe.global_position = j.camera.global_position + Vector3.UP * 0.8 - j.camera.global_basis.z * 2.5

func _texte(t: String) -> void:
	if l != null:
		l.text = t

func _capture(nom: String) -> void:
	if _dossier == "":
		return
	await process_frame
	var im := root.get_viewport().get_texture().get_image()
	_n_cap += 1
	im.save_png(_dossier.path_join("%02d_%s.png" % [_n_cap, nom]))

func _regarder(p: Vector3, duree: float, suivre: Node3D = null) -> void:
	var n := maxi(1, roundi(duree / DT))
	var y0 := j.rotation.y
	var x0: float = j.tete.rotation.x
	for k in n:
		var cible := p
		if suivre != null and is_instance_valid(suivre):
			cible = Elements._centre(suivre)
		var d := cible - (j.camera.global_position as Vector3)
		var u := smoothstep(0.0, 1.0, float(k + 1) / n)
		j.rotation.y = lerp_angle(y0, atan2(-d.x, -d.z), u)
		j.tete.rotation.x = lerpf(x0, atan2(d.y, Vector2(d.x, d.z).length()), u)
		await _image()

func _rayon(a: Vector3, b: Vector3, ex: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var e2: Array[RID] = ex.duplicate()
	e2.append(j.get_rid())
	q.exclude = e2
	return j.get_world_3d().direct_space_state.intersect_ray(q)

func _sol(p: Vector3) -> Vector3:
	var r := _rayon(p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0)
	return r["position"] if not r.is_empty() else p

## Un mur plein droit devant (cap balayé tous les 10°) entre `dmin` et `dmax` m, sol plat et dégagé jusqu'à lui.
func _mur(dmin: float, dmax: float) -> Dictionary:
	var o: Vector3 = j.camera.global_position - Vector3.UP * 0.4
	var y_sol := j.global_position.y
	for k in 36:
		var cap := j.rotation.y + deg_to_rad(10.0 * k)
		var dir := Vector3(-sin(cap), 0, -cos(cap))
		var r := _rayon(o, o + dir * dmax)
		if r.is_empty():
			continue
		var p: Vector3 = r["position"]
		var n: Vector3 = r["normal"]
		if o.distance_to(p) < dmin or n.dot(-dir) < 0.85 or not (r["collider"] is StaticBody3D):
			continue
		var plein := true
		var lat := dir.cross(Vector3.UP).normalized()
		for dec in [lat * 1.2, -lat * 1.2, Vector3.UP * 0.7 + lat * 0.6, Vector3.UP * 0.7 - lat * 0.6, Vector3.DOWN * 0.6]:
			var r2 := _rayon(o + dec, o + dec + dir * (dmax + 0.6))
			if r2.is_empty() or absf((Vector3(r2["position"]) - p).dot(n)) > 0.15:
				plein = false
				break
		if not plein:
			continue
		var plat := true
		for f in [0.25, 0.45, 0.65, 0.85]:
			var q := _sol(j.global_position + dir * o.distance_to(p) * f)
			if absf(q.y - y_sol) > 0.25:
				plat = false
		var bas := j.global_position + Vector3.UP * 0.45
		for dl in [0.0, 1.0, -1.0]:
			var r3 := _rayon(bas + lat * dl, bas + lat * dl + dir * (o.distance_to(p) - 0.3))
			if not r3.is_empty():
				plat = false
		if not plat:
			continue
		return {"cap": cap, "point": p, "normale": n, "dir": dir, "dist": o.distance_to(p)}
	return {}

func _draugr(p: Vector3, type: String) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(load("res://scripts/draugr.gd"))
	d.type = type
	d.joueur = j
	d.hud = s.get("hud")
	d.ident = "film_rd_%s_%d" % [type, randi() % 100000]
	s.add_child(d)
	d.global_position = _sol(p)
	var v := j.global_position - d.global_position
	d.rotation.y = atan2(v.x, v.z)
	_ennemis.append(d)
	return d

func _ia(d: CharacterBody3D) -> void:
	d.set_physics_process(true)
	var cst: Dictionary = d.get_script().get_script_constant_map()
	d.call("_changer", cst["TRAQUE"])

## Cassables de la crypte (urnes, tonneaux) amenés aux points voulus.
func _cassables_vers(points: Array) -> Array:
	var res: Array = []
	var dispo: Array = []
	for n in get_nodes_in_group("telekinesable"):
		if n is Cassable and not (n as Cassable).casse and (n as Node3D).is_inside_tree():
			dispo.append(n)
	dispo.sort_custom(func(a, b): return ((a as Cassable).genre == "tonneau") and not ((b as Cassable).genre == "tonneau"))
	for i in mini(points.size(), dispo.size()):
		var c: Cassable = dispo[i]
		c.global_position = _sol(points[i])
		res.append(c)
	return res

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
	var y0 := j.global_position.y
	var n := 0
	while n < 30 * 60 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
		await process_frame
		n += 1
	await _attendre(2.5)
	es = magie.esprit
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.visible = false
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	# lumière de tournage (film seulement)
	_lampe = OmniLight3D.new()
	_lampe.name = "LumiereTournage"
	_lampe.light_color = Color(1.0, 0.88, 0.72)
	_lampe.light_energy = 2.4
	_lampe.omni_range = 12.0
	_lampe.shadow_enabled = false
	s.add_child(_lampe)
	for we in s.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (we as WorldEnvironment).environment
		if env != null:
			env.ambient_light_energy = maxf(env.ambient_light_energy, 1.0) * 1.7
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(12, 448)
	calque.add_child(l)
	# film : les draugrs endormis de la crypte quittent le plateau (seuls ceux du film jouent)
	for e in get_nodes_in_group("ennemis"):
		if e is Node3D and (e as Node3D).global_position.distance_to(j.global_position) < 30.0:
			(e as Node).queue_free()
	await _attendre(0.2)
	var mur := _mur(6.5, 10.0)
	if mur.is_empty():
		mur = _mur(5.5, 12.0)
	print("FILM mur : ", mur)
	if not mur.is_empty():
		j.rotation.y = float(mur["cap"])
	await _regarder(j.camera.global_position + (-j.global_basis.z) * 5.0 + Vector3.DOWN * 0.3, 0.1)
	var plans := _arg("plans", "normal,ralenti,levitation").split(",")
	if _arg("mesure") != "":
		await _mesure(mur)
		quit(0)
		return
	if es == null or es.rag == null:
		_texte("ragdoll de l'esprit coupé")
		await _attendre(2.0)
	else:
		if "normal" in plans:
			await _plan_repulsion(mur, false)
		if "ralenti" in plans:
			await _plan_repulsion(mur, true)
		if "levitation" in plans:
			await _plan_levitation(mur)
	_texte("")
	await _attendre(0.5)
	print("FIN_SEQUENCE")
	for e in es.journal:
		print("ES %.2f %s" % [e[0], e[1]])
	for x in es.rag.journal:
		print("RD ", x)
	quit(0)

func _nettoyer() -> void:
	for d in _ennemis:
		if is_instance_valid(d):
			d.queue_free()
	_ennemis.clear()
	await _attendre(0.1)

## Répulsion chargée sur trois ennemis entre le joueur et le mur, tonneaux / urnes au pied du mur.
func _plan_repulsion(mur: Dictionary, ralenti: bool) -> void:
	await _nettoyer()
	magie.equiper("gauche", "repulsion")
	j.mana = j.mana_max
	var dir: Vector3 = mur.get("dir", -j.global_basis.z)
	var dist: float = float(mur.get("dist", 8.0))
	var lat := dir.cross(Vector3.UP).normalized()
	var base := j.global_position
	_cassables_vers([base + dir * (dist - 0.7) + lat * 0.9, base + dir * (dist - 0.75) - lat * 0.7, base + dir * (dist - 1.3) + lat * 0.1,
		base + dir * (dist - 0.6) - lat * 1.8])
	var a := _draugr(base + dir * 3.7 + lat * 0.9, "squelette")
	var b := _draugr(base + dir * 3.9 - lat * 0.8, "squelette")
	var c := _draugr(base + dir * 4.5 + lat * 0.05, "guerrier")
	await _attendre(0.3)
	await _regarder(base + dir * 4.5 + Vector3.UP * 0.9, 0.1)
	await _debut("Répulsion chargée%s" % (" — au ralenti" if ralenti else ""))
	magie.appuyer("gauche")
	await _attendre(0.9)
	for d in [a, b, c]:
		_ia(d)   # ils s'élancent sur le joueur à la fin de la charge
	await _attendre(0.4)
	await _capture("charge_%s" % ("ralenti" if ralenti else "normal"))
	if ralenti:
		Engine.physics_ticks_per_second = 200
		Engine.max_physics_steps_per_frame = 16
		Engine.time_scale = 0.3
	magie.relacher("gauche")
	await _attendre(0.25 / (0.3 if ralenti else 1.0) * (0.3 if ralenti else 1.0))
	await _capture("onde_%s" % ("ralenti" if ralenti else "normal"))
	# la caméra suit le groupe projeté vers le mur
	var t_vol := 1.3 if not ralenti else 1.3 / 0.3 * 0.75
	var k := 0.0
	while k < t_vol:
		var centre := Vector3.ZERO
		var nb := 0
		for d in [a, b, c]:
			if is_instance_valid(d):
				centre += Elements._centre(d)
				nb += 1
		if nb > 0:
			var vise := centre / nb
			vise.y = maxf(vise.y, j.camera.global_position.y - 0.9)   # cadrage : le groupe et le mur, pas le sol sous la caméra
			await _regarder(vise, DT * 4.0)
		k += DT * 4.0
		if absf(k - t_vol * 0.4) < DT * 2.0:
			await _capture("impact_%s" % ("ralenti" if ralenti else "normal"))
	if ralenti:
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = 60
		Engine.max_physics_steps_per_frame = 8
	_texte("ils se relèvent (relevé capturé)…")
	await _attendre(1.0)
	await _capture("releve_%s" % ("ralenti" if ralenti else "normal"))
	await _attendre(1.0)
	_texte("…et reviennent")
	await _regarder(Vector3.ZERO, 1.6, a if is_instance_valid(a) else c)
	await _capture("reviennent_%s" % ("ralenti" if ralenti else "normal"))

## Lévitation lâchée : un squelette soulevé, lâché (il retombe en ragdoll), puis il se relève.
func _plan_levitation(mur: Dictionary) -> void:
	await _nettoyer()
	magie.equiper("gauche", "levitation")
	j.mana = j.mana_max
	var dir: Vector3 = mur.get("dir", -j.global_basis.z)
	var lat := dir.cross(Vector3.UP).normalized()
	var d := _draugr(j.global_position + dir * 4.2 - lat * 0.4, "squelette")
	await _attendre(0.3)
	await _regarder(Elements._centre(d), 0.1)
	await _debut("Lévitation : soulevé… puis lâché")
	magie.appuyer("gauche")
	await _attendre(0.5)
	await _regarder(Elements._centre(d) + Vector3.UP * 0.5, 0.9)
	await _capture("souleve")
	_texte("lâché : il retombe en ragdoll")
	es.lacher("gauche")
	magie._couper("gauche", false)
	magie.inc["gauche"].changer(Incantation.REPOS)
	magie.inc["gauche"].tenu = false
	await _regarder(Vector3.ZERO, 1.0, d)
	await _capture("tombe")
	_texte("…et se relève")
	await _regarder(Vector3.ZERO, 2.4, d)
	await _capture("debout")
	_ia(d)
	await _attendre(0.6)

## Combat chargé : 6 ennemis devant le mur, Répulsion pleine charge toutes les 4 s ; FPS par image (temps réel).
func _mesure(mur: Dictionary) -> void:
	magie.equiper("gauche", "repulsion")
	var dir: Vector3 = mur.get("dir", -j.global_basis.z)
	var lat := dir.cross(Vector3.UP).normalized()
	var base := j.global_position
	var temps: Array[float] = []
	var t_repos: Array[float] = []
	# repos (aucun ragdoll) : 3 s
	var t0 := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var t1 := Time.get_ticks_usec()
		t_repos.append((t1 - t0) / 1000000.0)
		t0 = t1
	for cycle in 4:
		for d in _ennemis:
			if is_instance_valid(d):
				d.queue_free()
		_ennemis.clear()
		for k in 6:
			_draugr(base + dir * (3.2 + 0.5 * (k % 2)) + lat * (-1.5 + 0.6 * k), "squelette" if k % 3 != 2 else "guerrier")
		for d in _ennemis:
			_ia(d)
		j.mana = j.mana_max
		magie.appuyer("gauche")
		for i in 75:
			await process_frame
		magie.relacher("gauche")
		t0 = Time.get_ticks_usec()
		for i in 240:
			j.vie = j.vie_max
			await process_frame
			var t1 := Time.get_ticks_usec()
			temps.append((t1 - t0) / 1000000.0)
			t0 = t1
	var rapport := func(liste: Array[float]) -> String:
		var tri := liste.duplicate()
		tri.sort()
		var somme := 0.0
		for x in liste:
			somme += x
		var p99: float = tri[int(tri.size() * 0.99) - 1]
		return "fps_moyen=%.1f p1_bas=%.1f images=%d" % [liste.size() / somme, 1.0 / p99, liste.size()]
	print("MESURE repos %s ; ragdoll_actif=%s" % [rapport.call(t_repos), str(RagdollEsprit.actif)])
	print("MESURE combat %s ; ragdoll_actif=%s" % [rapport.call(temps), str(RagdollEsprit.actif)])
	for k in RagdollEsprit.profil:
		var d: Array = RagdollEsprit.profil[k]
		print("PROFIL %-22s n=%4d moyen=%7.0f µs max=%7.0f µs" % [k, d[0], float(d[1]) / maxf(d[0], 1), float(d[2])])

func _debut(texte: String) -> void:
	await _attendre(0.5)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() * DT))
	_texte(texte)
