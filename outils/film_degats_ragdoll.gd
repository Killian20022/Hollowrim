extends SceneTree
## FILM des DÉGÂTS D'OBJETS et de l'ENNEMI LANCÉ (scripts/magie/degats_objets.gd, ragdoll_esprit.gd), vue FPS, pilote automatique, crypte,
## lumière de tournage (film seulement) :
##   1. « dos »     : un tonneau saisi derrière un ennemi (au bord de la visée) est attiré vers la main et s'écrase sur lui ;
##   2. « tonneau » : un tonneau lancé à pleine charge sur un bandit (ralenti à l'impact) : le bandit meurt, le tonneau explose ;
##   3. « mur »     : un ennemi lévité puis lancé contre un mur : ragdoll, dégâts d'écrasement légers, relevé animé (ralenti à l'impact).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   flock /tmp/hollowrim_rendu.lock godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_degats_ragdoll.gd -- --nouvelle
##         --crypte=0,-24,0,-4 --paisible [--images=<dossier>] [--plans=dos,tonneau,mur]
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
		j.mana = j.mana_max
	_suivre_cam()
	_suivre_lampe()
	await process_frame

## Caméra de tournage (le film ne se joue pas en vue FPS : l'action est cadrée de près, de côté) : position fixe, vise `_cam_cible` (lissé).
var _cam: Camera3D
var _cam_cible := Callable()

func _cam_sur(pos: Vector3, cible: Callable, fov := 62.0) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "CameraTournage"
		s.add_child(_cam)
	_cam.fov = fov
	_cam.global_position = pos
	_cam_cible = cible
	if cible.is_valid():
		_cam.look_at(cible.call(), Vector3.UP)
	_cam.current = true

## Poste de caméra dégagé (rien entre le poste et le milieu de l'action, ni entre le poste et le but) parmi des décalages latéraux / arrière.
func _poste(milieu: Vector3, dir: Vector3, lat: Vector3, but: Vector3) -> Vector3:
	var essais: Array = [lat * 3.4, -lat * 3.4, lat * 2.4, -lat * 2.4, lat * 4.6, -lat * 4.6, -dir * 3.0 + lat * 1.6, -dir * 3.0 - lat * 1.6, lat * 1.6, -lat * 1.6]
	for hauteur in [1.5, 2.2]:
		for off in essais:
			var p: Vector3 = milieu + off + Vector3.UP * hauteur
			if _rayon(milieu + Vector3.UP * 1.0, p).is_empty() and _rayon(p, but + Vector3.UP * 0.9).is_empty() and _rayon(p, milieu + dir * 1.5 + Vector3.UP * 0.9).is_empty():
				return p
	return milieu + lat * 2.0 + Vector3.UP * 2.4

func _cam_vers_joueur() -> void:
	_cam_cible = Callable()
	if _cam != null:
		_cam.current = false
	j.camera.current = true

func _suivre_cam() -> void:
	if _cam == null or not _cam.current or not _cam_cible.is_valid():
		return
	var v: Vector3 = _cam_cible.call() - _cam.global_position
	if v.length() < 0.1:
		return
	var voulu := Basis.looking_at(v.normalized(), Vector3.UP)
	_cam.global_basis = _cam.global_basis.slerp(voulu, 0.22)

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		await _image()

func _suivre_lampe() -> void:
	if _lampe != null and is_instance_valid(_lampe) and j != null:
		var c: Camera3D = _cam if _cam != null and _cam.current else j.camera
		_lampe.global_position = c.global_position + Vector3.UP * 0.8 - c.global_basis.z * 2.5

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
	j.mana_max = 600.0   # un tonneau de 53 kg coûte cher à tenir : pas de panne de mana dans le film
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
	var plans := _arg("plans", "dos,tonneau,mur").split(",")
	if es == null or es.rag == null:
		_texte("ragdoll de l'esprit coupé")
		await _attendre(2.0)
	else:
		if "dos" in plans:
			await _plan_dos(mur)
		if "tonneau" in plans:
			await _plan_tonneau(mur)
		if "mur" in plans:
			await _plan_mur(mur)
	_texte("")
	await _attendre(0.5)
	print("FIN_SEQUENCE")
	for e in es.journal:
		print("ES %.2f %s" % [e[0], e[1]])
	for x in es.rag.journal:
		print("RD ", x)
	for x in magie.tk.journal:
		print("TK %.2f %s" % [x[0], x[1]])
	quit(0)

func _nettoyer() -> void:
	for d in _ennemis:
		if is_instance_valid(d):
			d.queue_free()
	_ennemis.clear()
	magie._couper("gauche", false)
	magie.inc["gauche"].changer(Incantation.REPOS)
	magie.inc["gauche"].tenu = false
	es.tout_lacher()
	await _attendre(0.1)

func _ralenti(actif: bool) -> void:
	if actif:
		Engine.physics_ticks_per_second = 200
		Engine.max_physics_steps_per_frame = 16
		Engine.time_scale = 0.3
	else:
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = 60
		Engine.max_physics_steps_per_frame = 8

func _tonneau_vers(p: Vector3) -> Cassable:
	var res := _cassables_vers([p])
	return res[0] if not res.is_empty() else null

## 1. Un tonneau saisi derrière un ennemi (à 50 cm de la ligne de visée, côté main : le rayon le frôle), attiré vers la main : il l'écrase.
func _plan_dos(mur: Dictionary) -> void:
	await _nettoyer()
	magie.equiper("gauche", "telekinesie")
	var dir: Vector3 = mur.get("dir", -j.global_basis.z)
	var dist: float = float(mur.get("dist", 8.0))
	var lat := dir.cross(Vector3.UP).normalized()
	var base := j.global_position
	var t := _tonneau_vers(base + dir * (dist - 0.9))
	var d := _draugr(base + dir * (dist - 3.4) - lat * 0.5, "draugr")
	await _attendre(0.3)
	await _regarder(Elements._centre(t) if t != null else base + dir * 6.0, 0.1)
	var milieu := base + dir * (dist * 0.55)
	_cam_sur(_poste(milieu, dir, lat, Elements._centre(d)), func(): return Elements._centre(d) + dir * 0.6 if is_instance_valid(d) else milieu)
	await _debut("Télékinésie : le tonneau, derrière l'ennemi, est attiré vers moi")
	var vie0: float = d.vie
	magie.appuyer("gauche")
	var k := 0
	var saisi: Variant = null
	while k < 120 and is_instance_valid(d) and d.vie >= vie0 - 3.0:
		await _image()
		k += 1
		if saisi == null and magie.tk.tient("gauche"):
			saisi = magie.tk.tenue["gauche"].get("corps")
		if k == 18:
			await _capture("dos_1_saisi")
		if k == 26:
			await _capture("dos_2_arrive")
	await _capture("dos_3_impact")
	_texte("choc : %.0f PV perdus sur %.0f, le tonneau éclate" % [vie0 - maxf(d.vie, 0.0), vie0])
	magie.relacher("gauche")
	_ia(d)
	await _attendre(0.5)
	await _capture("dos_4_apres")
	await _attendre(1.3)
	print("FILM dos : ennemi %.0f -> %.0f PV, tonneau saisi brisé=%s" % [vie0, d.vie, str(saisi != null and (not is_instance_valid(saisi) or bool(saisi.get("casse"))))])
	_cam_vers_joueur()

## 2. Un tonneau lancé à pleine charge sur un bandit : il meurt, le tonneau explose (impact au ralenti).
func _plan_tonneau(mur: Dictionary) -> void:
	await _nettoyer()
	magie.equiper("gauche", "telekinesie")
	var dir: Vector3 = mur.get("dir", -j.global_basis.z)
	var lat := dir.cross(Vector3.UP).normalized()
	var base := j.global_position
	var t := _tonneau_vers(base + dir * 2.2 - lat * 1.0)
	var d := _draugr(base + dir * 5.4 + lat * 0.2, "draugr")
	await _attendre(0.3)
	await _regarder(Elements._centre(t) if t != null else base + dir * 2.0, 0.1)
	var milieu := base + dir * 3.8
	_cam_sur(_poste(milieu, dir, lat, Elements._centre(d)), func(): return (t.global_position if is_instance_valid(t) and not t.casse else Elements._centre(d)).lerp(Elements._centre(d), 0.5) if is_instance_valid(d) else milieu)
	await _debut("Un tonneau lancé à pleine force sur un bandit")
	var vie0: float = d.vie
	magie.appuyer("gauche")
	await _attendre(1.5)
	await _capture("tonneau_1_charge")
	await _regarder(Elements._centre(d), 0.4)
	magie.relacher("gauche")
	await _attendre(0.25)
	_ralenti(true)
	var k := 0
	while k < 140 and is_instance_valid(d) and d.vie >= vie0 - 1.0:
		await _image()
		k += 1
	await _capture("tonneau_2_impact")
	var n := 0
	while n < 40:
		await _image()
		n += 1
		if n == 20:
			await _capture("tonneau_3_apres")
	_ralenti(false)
	_texte("%.0f PV perdus sur %.0f" % [vie0 - maxf(d.vie, 0.0), vie0])
	await _attendre(1.8)
	await _capture("tonneau_4_fin")
	print("FILM tonneau : bandit %.0f -> %.0f PV, tonneau brisé=%s" % [vie0, d.vie, str(t != null and t.casse)])
	_cam_vers_joueur()

## 3. Un ennemi lévité puis lancé contre le mur : ragdoll, écrasement léger, relevé animé.
func _plan_mur(mur: Dictionary) -> void:
	await _nettoyer()
	magie.equiper("gauche", "levitation")
	var dir: Vector3 = mur.get("dir", -j.global_basis.z)
	var dist: float = float(mur.get("dist", 8.0))
	var lat := dir.cross(Vector3.UP).normalized()
	var base := j.global_position
	var d := _draugr(base + dir * 3.2 - lat * 0.3, "draugr")
	await _attendre(0.3)
	await _regarder(Elements._centre(d), 0.1)
	var milieu := base + dir * (dist * 0.6)
	_cam_sur(_poste(milieu, dir, lat, Elements._centre(d)), func(): return Elements._centre(d) if is_instance_valid(d) else milieu)
	await _debut("Lévitation : soulevé, puis lancé contre le mur")
	var vie0: float = d.vie
	magie.appuyer("gauche")
	await _attendre(1.3)
	await _capture("mur_1_leve")
	await _regarder(base + dir * (dist - 0.3) + Vector3.UP * 1.2, 0.5)
	magie.relacher("gauche")
	var k := 0
	var choc := false
	_ralenti(true)
	while k < 200:
		await _image()
		k += 1
		if not choc and es.journal.any(func(x): return String(x[1]).begins_with("choc")):
			choc = true
			await _capture("mur_2_impact")
			k = 150
		if es.rag.phase(d) != "vol" and choc:
			break
		if k == 40:
			await _capture("mur_vol")
	_ralenti(false)
	_texte("écrasement : %.0f PV perdus sur %.0f" % [vie0 - maxf(d.vie, 0.0), vie0])
	await _attendre(0.5)
	await _capture("mur_3_au_sol")
	_texte("…et il se relève (relevé capturé)")
	await _attendre(0.9)
	await _capture("mur_4_releve")
	await _attendre(1.0)
	await _capture("mur_5_debout")
	_ia(d)
	await _attendre(0.5)
	print("FILM mur : ennemi %.0f -> %.0f PV" % [vie0, d.vie])
	_cam_vers_joueur()

func _debut(texte: String) -> void:
	await _attendre(0.5)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() * DT))
	_texte(texte)
