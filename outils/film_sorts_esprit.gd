extends SceneTree
## FILMS de démonstration des SORTS DE L'ESPRIT (scripts/magie/sorts_esprit.gd) en vue FPS, pilote automatique, dans la crypte, ennemis
## avec leur IA ACTIVE (ils marchent sur le joueur) ; le joueur ne meurt pas et n'est pas interrompu (film).
##   --sort=repulsion   : un guerrier et deux squelettes approchent, onde chargée (ils volent contre les murs, urnes et tonneaux cassent),
##                        puis petite onde au tap sur celui qui revient ;
##   --sort=levitation  : un squelette soulevé (il se débat, suit le regard) projeté sur un draugr ; le draugr soulevé jeté dans des urnes ;
##                        un troll soulevé qui brise l'emprise ;
##   --sort=attraction  : un point lancé au milieu d'un groupe (ennemis, urnes, chaises) : tout tourne puis est relâché d'un coup.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_sorts_esprit.gd -- --nouvelle
##         --crypte=0,-24,0,-4 --paisible --sort=<nom> [--images=<dossier>]
## (--paisible fige les draugrs DE LA CRYPTE ; ceux du film ont leur IA.) « DEBUT_SEQUENCE <s> » : instant à garder au montage (ffmpeg -ss).

const DT := 1.0 / 30.0

var s: Node
var j: CharacterBody3D
var magie: MainSort
var es: SortsEsprit
var l: Label
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

## Une image : le joueur ne meurt pas (film), le mana ne manque pas entre deux gestes si demandé.
var _t_film := 0.0
func _image() -> void:
	_t_film += DT
	if j != null:
		j.vie = j.vie_max
	await process_frame

func _attendre(sec: float) -> void:
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

## Tourne la tête vers `p` en `duree` s (lissé) ; `suivre` : nœud dont on suit le centre (cible mobile).
func _regarder(p: Vector3, duree: float, suivre: Node3D = null) -> void:
	var n := maxi(1, roundi(duree / DT))
	var y0 := j.rotation.y
	var x0: float = j.tete.rotation.x
	for k in n:
		var cible := p
		if suivre != null and is_instance_valid(suivre):
			cible = Elements._centre(suivre)
		var o: Vector3 = j.camera.global_position
		var d := cible - o
		var y1 := atan2(-d.x, -d.z)
		var x1 := atan2(d.y, Vector2(d.x, d.z).length())
		var u := smoothstep(0.0, 1.0, float(k + 1) / n)
		j.rotation.y = lerp_angle(y0, y1, u)
		j.tete.rotation.x = lerpf(x0, x1, u)
		await _image()

func _draugr(p: Vector3, type: String, vie := -1.0) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(load("res://scripts/draugr.gd"))
	d.type = type
	d.joueur = j
	d.hud = s.get("hud")
	d.ident = "film_es_%s_%d" % [type, randi() % 100000]
	s.add_child(d)
	d.global_position = _sol(p)
	var v := j.global_position - d.global_position
	d.rotation.y = atan2(v.x, v.z)
	if vie > 0.0:
		d.vie_max = vie
		d.vie = vie
	_ennemis.append(d)
	return d

## Réveille l'IA : il traque le joueur.
func _ia(d: CharacterBody3D) -> void:
	d.set_physics_process(true)
	if d.has_method("_changer"):
		var cst: Dictionary = d.get_script().get_script_constant_map()
		if cst.has("TRAQUE"):
			d.call("_changer", cst["TRAQUE"])

func _troll(p: Vector3) -> CharacterBody3D:
	var t := CharacterBody3D.new()
	t.set_script(load("res://scripts/troll_givre_ia.gd"))
	t.set("joueur", j)
	s.add_child(t)
	t.global_position = _sol(p)
	var v := j.global_position - t.global_position
	t.rotation.y = atan2(v.x, v.z)
	_ennemis.append(t)
	return t

func _sol(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0, 1)
	q.exclude = [j.get_rid()]
	var r := j.get_world_3d().direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else p

func _devant(dist: float, cote := 0.0) -> Vector3:
	var av := -j.global_basis.z
	av.y = 0.0
	av = av.normalized()
	var dr := av.cross(Vector3.UP)
	return j.global_position + av * dist + dr * cote

## Point de sol libre devant le joueur, visible de l'œil, de `dist` m en se rapprochant.
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

## Cassables de la crypte (urnes, tonneaux : cassables partout) amenés autour de `p` (ils cassent quand on les projette).
func _cassables_vers(points: Array) -> Array:
	var res: Array = []
	var dispo: Array = []
	for n in get_nodes_in_group("telekinesable"):
		if n is Cassable and not (n as Cassable).casse and (n as Node3D).is_inside_tree():
			dispo.append(n)
	dispo.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(j.global_position) < (b as Node3D).global_position.distance_to(j.global_position))
	for i in mini(points.size(), dispo.size()):
		var c: Cassable = dispo[i]
		c.global_position = _sol(points[i])
		res.append(c)
	print("cassables posés : %d (disponibles %d)" % [res.size(), dispo.size()])
	return res

func _maintenir_vers(cible: Node3D, duree: float) -> void:
	await _regarder(Vector3.ZERO, duree, cible)

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
		j.touche.disconnect(magie._sur_touche)   # film : les coups reçus n'interrompent pas les sorts
	_etiquette(s)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.visible = false
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	await _regarder(_devant(5.0) + Vector3.UP * 1.4, 0.1)
	var sorte := _arg("sort", "repulsion")
	if es == null:
		_texte("--sans-sorts-esprit : pas de sort")
		await _attendre(2.0)
	else:
		match sorte:
			"repulsion":
				await _film_repulsion()
			"levitation":
				await _film_levitation()
			"attraction":
				await _film_attraction()
	_texte("")
	await _attendre(0.6)
	print("FIN_SEQUENCE")
	if es != null:
		for e in es.journal:
			print("ES %.2f %s" % [e[0], e[1]])
	for e in magie.journal.slice(-30):
		print("MAGIE ", e)
	quit(0)

func _debut(texte: String) -> void:
	await _attendre(0.8)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() * DT))
	_texte(texte)

# ------------------------------------------------------------------ Répulsion

func _film_repulsion() -> void:
	magie.equiper("gauche", "repulsion")
	var urnes := _cassables_vers([_devant(6.6, -2.2), _devant(7.0, 1.9), _devant(7.4, -0.6), _devant(6.2, 2.6)])
	var chaise := CorpsTelekinesie.creer("pq_chaise", s, Transform3D(Basis(Vector3.UP, 0.7), _sol(_devant(4.4, -1.4))))
	var tab := CorpsTelekinesie.creer("pq_tabouret", s, Transform3D(Basis(), _sol(_devant(4.0, 1.3))))
	var g := _draugr(_libre(8.5, 0.0), "guerrier")
	var s1 := _draugr(_libre(7.8, -1.6), "squelette")
	var s2 := _draugr(_libre(7.8, 1.6), "squelette")
	await _attendre(0.4)
	await _debut("Répulsion (G) : ils approchent… maintenir pour charger")
	for d in [g, s1, s2]:
		_ia(d)
	await _regarder(Elements._centre(g), 0.4)
	await _attendre(0.3)
	await _capture("approche")
	magie.appuyer("gauche")
	await _regarder(Vector3.ZERO, 1.35, g)
	await _capture("charge")
	_texte("relâcher : onde de choc")
	magie.relacher("gauche")
	await _attendre(0.15)
	await _capture("onde")
	await _attendre(0.2)
	await _capture("projetes")
	await _regarder(Vector3.ZERO, 0.9, g if SortsEsprit.vivant(g) else s1)
	await _attendre(1.0)
	# le premier qui revient : petite onde au tap
	var proche: CharacterBody3D = null
	for d in [g, s1, s2]:
		if SortsEsprit.vivant(d) and d.global_position.distance_to(j.global_position) < 9.0 and (proche == null or d.global_position.distance_to(j.global_position) < proche.global_position.distance_to(j.global_position)):
			proche = d
	if proche != null:
		_texte("Répulsion au tap : petite onde")
		await _regarder(Vector3.ZERO, 0.6, proche)
		var t_attente := _t_film + 2.5
		while proche.global_position.distance_to(j.global_position) > 3.6 and SortsEsprit.vivant(proche) and _t_film < t_attente:
			await _regarder(Vector3.ZERO, 0.1, proche)
		j.mana = j.mana_max
		magie.appuyer("gauche")
		await _attendre(0.08)
		magie.relacher("gauche")
		await _attendre(0.4)
		await _capture("tap")
		await _regarder(Vector3.ZERO, 1.4, proche)
	print("FILM urnes cassées : %d / %d" % [urnes.filter(func(c): return (c as Cassable).casse).size(), urnes.size()])
	if is_instance_valid(chaise) and is_instance_valid(tab):
		pass

# ------------------------------------------------------------------ Lévitation

func _film_levitation() -> void:
	magie.equiper("gauche", "levitation")
	var urnes := _cassables_vers([_devant(6.0, -2.6), _devant(6.4, -1.9), _devant(5.6, -3.1)])
	var sq := _draugr(_libre(4.5, -0.3), "squelette")
	var dr := _draugr(_libre(6.5, 2.0), "guerrier")
	await _attendre(0.4)
	await _debut("Lévitation (N) : viser un ennemi, maintenir")
	_ia(sq)
	_ia(dr)
	await _regarder(Elements._centre(sq), 0.5)
	magie.appuyer("gauche")
	await _attendre(0.6)
	await _capture("souleve")
	_texte("il se débat et suit le regard")
	await _regarder(Elements._centre(sq) + _gauche() * 1.6 + Vector3.UP * 0.4, 0.8)
	await _regarder(Elements._centre(dr) + Vector3.UP * 0.6, 0.8)
	await _capture("tenu")
	_texte("relâcher : projeté sur le draugr")
	await _regarder(Elements._centre(dr), 0.35)
	magie.relacher("gauche")
	await _attendre(0.5)
	await _capture("percute")
	await _attendre(1.4)
	# le draugr soulevé à son tour, jeté dans les urnes
	j.mana = j.mana_max
	if SortsEsprit.vivant(dr):
		_texte("Lévitation : un draugr ancien coûte plus")
		await _regarder(Elements._centre(dr), 0.45)
		magie.appuyer("gauche")
		await _attendre(0.9)
		var cible: Vector3 = Telekinesie.centre(urnes[0]) if not urnes.is_empty() else _devant(6.0, -2.6)
		await _regarder(cible + Vector3.UP * 0.5, 0.7)
		_texte("relâcher : dans les urnes")
		await _regarder(cible, 0.3)
		magie.relacher("gauche")
		await _attendre(0.5)
		await _capture("urnes")
		await _attendre(1.3)
	# troll : on le soulève à peine, il brise l'emprise
	j.mana = j.mana_max
	var tr := _troll(_libre(6.5, 0.6))
	await _attendre(0.3)
	_texte("Troll : 87 de mana… il brise l'emprise")
	await _regarder(Elements._centre(tr), 0.5)
	magie.appuyer("gauche")
	await _attendre(0.6)
	await _capture("troll")
	await _attendre(1.0)
	magie.relacher("gauche")
	await _attendre(1.2)
	print("FILM urnes cassées : %d / %d" % [urnes.filter(func(c): return (c as Cassable).casse).size(), urnes.size()])

func _gauche() -> Vector3:
	return -j.global_basis.x

# ------------------------------------------------------------------ Attraction

func _film_attraction() -> void:
	magie.equiper("gauche", "attraction")
	var centre := _libre(6.5, 0.0)
	var urnes := _cassables_vers([centre + _gauche() * 2.4 + Vector3(0, 0, 0), centre - _gauche() * 2.2, centre + (centre - j.global_position).normalized() * 2.0, centre + _gauche() * 1.4 - (centre - j.global_position).normalized() * 1.6])
	var c1 := CorpsTelekinesie.creer("pq_chaise", s, Transform3D(Basis(Vector3.UP, 1.1), _sol(centre - _gauche() * 1.6 - (centre - j.global_position).normalized() * 1.4)))
	var c2 := CorpsTelekinesie.creer("pq_tabouret", s, Transform3D(Basis(), _sol(centre + _gauche() * 2.0 + (centre - j.global_position).normalized() * 1.2)))
	var a := _draugr(centre + _gauche() * 1.5 + (centre - j.global_position).normalized() * 0.6, "squelette")
	var b := _draugr(centre - _gauche() * 1.5 + (centre - j.global_position).normalized() * 0.8, "squelette")
	var c := _draugr(centre + (centre - j.global_position).normalized() * 2.2, "sbire")
	await _attendre(0.4)
	await _debut("Attraction (U) : lancer un point au milieu du groupe")
	for d in [a, b, c]:
		_ia(d)
	await _regarder(centre + Vector3.UP * 0.4, 0.6)
	await _attendre(0.3)
	magie.appuyer("gauche")
	await _attendre(0.1)
	magie.relacher("gauche")
	await _attendre(0.6)
	await _capture("ouvert")
	_texte("…il aspire ennemis et objets")
	await _regarder(centre + Vector3.UP * 1.0, 1.2)
	await _capture("aspire")
	await _attendre(1.3)
	_texte("puis relâche tout d'un coup")
	await _attendre(0.5)
	await _capture("relache")
	await _attendre(2.3)
	print("FILM urnes cassées : %d / %d ; chaises %s %s" % [urnes.filter(func(x): return (x as Cassable).casse).size(), urnes.size(), is_instance_valid(c1), is_instance_valid(c2)])
