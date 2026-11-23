extends SceneTree
## FILM de démonstration de la TÉLÉKINÉSIE (scripts/magie/telekinesie.gd) en vue FPS, pilote automatique, dans la crypte :
## saisie d'un tonneau lancé sur un draugr, d'une chaise lancée sur un squelette, puis d'une épée au sol qui part dans un squelette.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_telekinesie.gd -- --nouvelle
##         --crypte=0,-24,0,-4 --paisible [--vue=tps] [--images=<dossier>] [--sans-telekinesie]
## La ligne « DEBUT_SEQUENCE <s> » donne l'instant à garder au montage (ffmpeg -ss). --images : PNG aux moments clés.

const DT := 1.0 / 30.0

var s: Node
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var l: Label
var _dossier := ""
var _n_cap := 0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		await process_frame

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 500)
	calque.add_child(l)

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

## Tourne la tête vers `p` en `duree` s (lissé) : caméra du joueur (lacet du corps, tangage de la tête).
func _regarder(p: Vector3, duree: float) -> void:
	var n := maxi(1, roundi(duree / DT))
	var y0 := j.rotation.y
	var x0: float = j.tete.rotation.x
	for k in n:
		var o: Vector3 = j.camera.global_position
		var d := p - o
		var y1 := atan2(-d.x, -d.z)
		var x1 := atan2(d.y, Vector2(d.x, d.z).length())
		var u := smoothstep(0.0, 1.0, float(k + 1) / n)
		j.rotation.y = lerp_angle(y0, y1, u)
		j.tete.rotation.x = lerpf(x0, x1, u)
		await process_frame

func _draugr(p: Vector3, type: String, vie := -1.0) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(load("res://scripts/draugr.gd"))
	d.type = type
	d.joueur = j
	d.hud = s.get("hud")
	d.ident = "film_tk_%s_%d" % [type, randi() % 100000]
	s.add_child(d)
	d.global_position = _sol(p)
	var v := j.global_position - d.global_position
	d.rotation.y = atan2(v.x, v.z)
	d.set_physics_process(false)
	if vie > 0.0:
		d.vie = vie
	return d

## Point du sol sous `p` (rayon vers le bas, décor).
func _sol(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0, 1)
	q.exclude = [j.get_rid()]
	var r := j.get_world_3d().direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else p

## Point de sol libre devant le joueur, visible de l'œil (rien entre l'œil et un corps debout là) : de `dist` m en se rapprochant.
func _libre(dist: float, cote: float) -> Vector3:
	var d := dist
	while d > 2.5:
		var p := _sol(_devant(d, cote))
		var o: Vector3 = j.camera.global_position
		var q := PhysicsRayQueryParameters3D.create(o, p + Vector3.UP * 1.1, 1)
		q.exclude = [j.get_rid()]
		var r := j.get_world_3d().direct_space_state.intersect_ray(q)
		# … et depuis l'objet tenu (à gauche de la vue, un peu bas) : rien sur la trajectoire du lancer
		var tenu: Vector3 = o + (-j.camera.global_basis.z) * 2.0 - j.camera.global_basis.x * 0.3 - Vector3.UP * 0.15
		var q2 := PhysicsRayQueryParameters3D.create(tenu, p + Vector3.UP * 1.1, 1)
		q2.exclude = [j.get_rid()]
		var r2 := j.get_world_3d().direct_space_state.intersect_ray(q2)
		if r.is_empty() and r2.is_empty() and absf(p.y - j.global_position.y) < 0.6:
			print("place libre %.1f m, côté %.1f" % [d, cote])
			return p
		d -= 0.5
	print("PAS DE PLACE LIBRE devant (côté %.1f)" % cote)
	return _sol(_devant(3.0, cote))

func _devant(dist: float, cote := 0.0) -> Vector3:
	var av := -j.global_basis.z
	av.y = 0.0
	av = av.normalized()
	var dr := av.cross(Vector3.UP)
	return j.global_position + av * dist + dr * cote

func _saisir_et_lancer(objet: Node3D, cible: Node3D, tenue: float, nom: String) -> void:
	_texte("Télékinésie : viser %s, maintenir" % nom)
	await _regarder(Telekinesie.centre(objet), 0.6)
	await _attendre(0.3)
	magie.appuyer("gauche")
	await _attendre(0.45)
	await _capture("saisie_" + nom)
	# tenue : l'objet lévite, petit mouvement de tête pour montrer l'inertie
	var t0 := 0.0
	var centre := Elements._centre(cible) if cible != null else _devant(6.0)
	await _regarder(centre.lerp(j.camera.global_position, 0.55) + Vector3.UP * 0.3, maxf(tenue * 0.45, 0.3))
	await _capture("tenue_" + nom)
	_texte("…relâcher : lancer vers le réticule")
	await _regarder(centre, maxf(tenue * 0.45, 0.3))
	await _attendre(0.1)
	magie.relacher("gauche")
	await _attendre(0.12)
	await _capture("lancer_" + nom)
	await _attendre(0.25)
	await _capture("impact_" + nom)
	await _attendre(1.2)

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
	mains = j.mains
	magie = mains.magie
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var y0 := j.global_position.y
	var n := 0
	while n < 30 * 60 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
		await process_frame
		n += 1
	await _attendre(2.5)
	if _arg("vue") == "tps" and j.has_method("basculer_vue"):
		j.basculer_vue(true)
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	if magie.tk != null:
		magie.equiper("gauche", "telekinesie")
	_etiquette(s)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)   # encart « Commandes » fermé (vidéo)
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.visible = false
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	# décor de la démo : tonneau, chaise, épée au sol ; un draugr et deux squelettes (figés : ils subissent)
	var tonneau := CorpsTelekinesie.creer("pq_tonneau", s, Transform3D(Basis(Vector3.UP, 0.4), _sol(_devant(2.6, -1.1))))
	var chaise := CorpsTelekinesie.creer("pq_chaise", s, Transform3D(Basis(Vector3.UP, 2.0), _sol(_devant(2.3, 1.2))))
	var epee := ObjetMonde.creer("epee_soldat", 1, j, s.get("dialogue"))
	s.add_child(epee)
	epee.global_position = _sol(_devant(2.0, 0.1))
	epee.rotation.y = j.rotation.y + PI * 0.5   # couchée en travers du regard : lisible au sol
	await _regarder(_devant(5.0) + Vector3.UP * 1.4, 0.1)
	var draugr := _draugr(_libre(5.0, -1.4), "guerrier")
	var squelette := _draugr(_libre(5.5, 1.5), "squelette")
	var squelette2 := _draugr(_libre(4.5, 0.2), "squelette", 20.0)
	await _attendre(1.2)
	print("DEBUT_SEQUENCE %.3f (images d'attente : %d)" % [Engine.get_process_frames() * DT, n])
	await _regarder(_devant(6.0) + Vector3.UP * 1.3, 0.5)
	_texte("Télékinésie (X) : main gauche, épée à droite")
	await _capture("depart")
	await _attendre(0.8)
	if magie.tk == null:
		_texte("--sans-telekinesie : pas de sort")
		await _attendre(2.0)
	else:
		await _saisir_et_lancer(tonneau, draugr, 1.6, "tonneau")
		await _saisir_et_lancer(chaise, squelette, 1.2, "chaise")
		await _saisir_et_lancer(epee, squelette2, 1.4, "epee")
	_texte("")
	await _attendre(1.0)
	print("FIN_SEQUENCE")
	if magie.tk != null:
		for e in magie.tk.journal:
			print("TK %.2f %s" % [e[0], e[1]])
	quit(0)
