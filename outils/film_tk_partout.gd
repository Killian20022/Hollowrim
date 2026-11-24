extends SceneTree
## FILM « télékinésie partout, camps » (2026-11-24) : en vue FPS, au camp de départ (tonneau et caisse à côté de la tente), au camp de chasseur
## et au bûcher, la télékinésie saisit un objet (visée légèrement à CÔTÉ du centre), le tient, le balance au regard, puis le lance : il se
## brise contre le décor. Preuve de la règle unique ObjetsVivants.mobile (plus de props fondus dans ces lieux).
##   godot --path . --fixed-fps 30 --disable-vsync --script res://outils/film_tk_partout.gd -- --nouvelle --sortie=<dossier>
## Images : <dossier>/f_00000.png … (puis ffmpeg). « DEBUT » / « OBJET » : repères du journal.

const SCENE := preload("res://scenes/foret_test.tscn")
## Cibles : [genres acceptés, lieu (préfixe d'ident), étiquette]
const CIBLES := [
	[["pq_tonneau"], "camp:", "Camp de depart : tonneau a cote de la tente"],
	[["pq_caisse", "pq_cageot_vide"], "camp:", "Camp de depart : caisse"],
	[["pq_seau_bois", "pq_marmite_camp", "pq_hache_camp", "pq_sac"], "lot_camp_chasseur", "Camp de chasseur"],
	[["pq_buche", "q_buche", "pq_rondin", "q_rondin", "pq_hache_camp"], "lot_bucher_feu", "Bucher"],
]

var s: Node3D
var j: CharacterBody3D
var magie: MainSort
var tk: Telekinesie
var sortie := ""
var n := 0
var l: Label
var sol_fixe := NAN

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	j.mana = j.mana_max
	j.vie = j.vie_max
	await process_frame
	await RenderingServer.frame_post_draw
	if sortie != "":
		root.get_texture().get_image().save_png("%s/f_%05d.png" % [sortie, n])
	n += 1

func _filmer(k: int) -> void:
	for i in k:
		await _image()

func _regarder(p: Vector3, decal := Vector3.ZERO) -> void:
	var o: Vector3 = j.camera.global_position
	var d := p + decal - o
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _etiquette(texte: String) -> void:
	l.text = texte

## Point de vue DÉGAGÉ sur `c` (12 directions, distance 2,5 m) : un rayon de l'œil touche le centre sans mur ni meuble. Renvoie
## [point, nombre de directions dégagées] : plus il y en a, plus l'objet est en terrain ouvert (cadrage lisible).
func _vue_degagee(o: Node3D, c: Vector3) -> Array:
	var espace := j.get_world_3d().direct_space_state
	var meilleur := Vector3.INF
	var nb := 0
	var base := atan2(j.global_position.x - c.x, j.global_position.z - c.z)
	for k in 12:
		var a: float = base + TAU * k / 12.0
		var p := c + Vector3(sin(a), 0, cos(a)) * 2.5
		var y: float = sol_fixe if not is_nan(sol_fixe) else float(s.hauteur(p.x, p.z))
		var oeil := Vector3(p.x, y + 1.55, p.z)
		var q := PhysicsRayQueryParameters3D.create(oeil, c, 1 | Cassable.CALQUE, [j.get_rid()])
		var r := espace.intersect_ray(q)
		var pied := PhysicsRayQueryParameters3D.create(oeil, Vector3(p.x, y - 0.3, p.z), 1, [j.get_rid()])
		var rp := espace.intersect_ray(pied)
		var haut := PhysicsRayQueryParameters3D.create(oeil, oeil + Vector3.UP * 1.2, 1, [j.get_rid()])      # pas sous un toit bas ni contre un mur
		if not r.is_empty() and (r["collider"] == o or (r["position"] as Vector3).distance_to(c) < 0.5) and (rp.is_empty() or float((rp["position"] as Vector3).y) < y + 0.1) and espace.intersect_ray(haut).is_empty():
			nb += 1
			if meilleur == Vector3.INF:
				meilleur = Vector3(p.x, y, p.z)
	return [meilleur, nb]

## Premier candidat (groupe telekinesable) du genre voulu dans le lieu voulu, avec un point de vue dégagé.
func _trouver(genres: Array, lieu: String, sauf: Array) -> Array:
	var cands: Array = []
	for o in get_nodes_in_group(Telekinesie.GROUPE):
		if o == null or not is_instance_valid(o) or o in sauf:
			continue
		var g := String(o.get("genre")) if o.get("genre") != null else ""
		g = g.trim_prefix("tk_")
		if genres == ["arme"]:
			if not o.has_meta("tk_arme"):
				continue
		elif not (g in genres):
			continue
		var ident := String(o.get("ident")) if o.get("ident") != null else ""
		if lieu != "" and not ident.begins_with(lieu):
			continue
		if o.has_meta("pris") or (o is ObjetVivant and (o as ObjetVivant).casse):
			continue
		cands.append(o)
	# dehors d'abord (jour, neige : image claire), puis les plus dégagés, puis les plus proches de la place
	var notes: Array = []
	var ref := Vector3(0, 0, 4)
	for o: Node3D in cands:
		var c := Telekinesie.centre(o)
		if c.distance_to(ref) > 70.0:
			continue
		var v := _vue_degagee(o, c)
		if (v[0] as Vector3) == Vector3.INF or int(v[1]) < 2:
			continue
		var ident := String(o.get("ident")) if o.get("ident") != null else ""
		var dedans := ident.begins_with("halle") or ident.begins_with("sigrun") or ident.begins_with("grima") or ident.begins_with("chasseurs") or ident.begins_with("forge") or ident.begins_with("crypte")
		notes.append([(1000 if dedans else 0) - int(v[1]) * 10 + c.distance_to(ref) * 0.2, o, v[0]])
	notes.sort_custom(func(x, y): return x[0] < y[0])
	if notes.is_empty():
		return []
	return [notes[0][1], notes[0][2]]

func _go() -> void:
	sortie = _arg("sortie", "")
	if sortie != "":
		DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 2400:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	j = s.joueur
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.set("visible", false)
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	s.cycle.heure = 11.0
	for lx: Array in s.hud.lieux_nommes:
		s.hud.lieux_vus[lx[2]] = true
	s.hud.aide_t = 0.0
	j.set_physics_process(false)
	if s.get("crime") != null:
		(s.crime as Node).remove_from_group("crime")
	magie = j.mains.magie
	magie.eq.apprendre_tout()
	magie.equiper("gauche", "telekinesie")
	tk = magie.tk
	var cal := CanvasLayer.new()
	cal.layer = 60
	root.add_child(cal)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.position = Vector2(14, 14)
	cal.add_child(l)
	var ip: Interieur = s.village.interieur("halle")
	var place := Vector3(0, float(s.hauteur(0, 4)), 4)
	var halle := ip.to_global(Vector3(0, ip.sol_y + 0.6, 0))
	j.global_position = place
	for i in 30:
		await physics_frame
	# l'épée au sol de la dernière cible, posée sur la place
	var epee := ObjetMonde.creer("epee_soldat", 1)
	s.add_child(epee)
	var pe := Vector3(5.0, float(s.hauteur(5.0, 9.0)), 9.0)
	epee.global_position = pe
	await _filmer(20)
	print("DEBUT %.2f" % (n / 30.0))
	var deja: Array = []
	for cb: Array in CIBLES:
		sol_fixe = NAN
		j.global_position = place
		await physics_frame
		var t: Array = [epee, Vector3.INF] if cb[0] == ["arme"] else _trouver(cb[0], String(cb[1]), deja)
		if t.is_empty():
			print("OBJET %s : introuvable" % cb[2])
			continue
		var o: Node3D = t[0]
		deja.append(o)
		var c := Telekinesie.centre(o)
		var ident_o := String(o.get("ident")) if o.get("ident") != null else ""
		if ident_o.begins_with("halle"):
			sol_fixe = ip.to_global(Vector3(0, ip.sol_y, 0)).y
		var vp: Vector3 = t[1]
		if vp == Vector3.INF:      # épée au sol : à 2,3 m, du côté de la place
			var dd := (place - c)
			dd.y = 0.0
			vp = c + dd.normalized() * 2.3
			vp.y = float(s.hauteur(vp.x, vp.z))
		j.global_position = vp + Vector3(0, 0.02, 0)
		j.velocity = Vector3.ZERO
		for i in 2:
			await physics_frame
		# visée légèrement à CÔTÉ du centre (indulgence) : 0,22 m sur la droite de l'écran
		var droite := j.global_basis.x
		_regarder(c, droite * 0.22)
		_etiquette("%s - %.0f kg" % [cb[2], Telekinesie.masse_de(o)])
		print("OBJET %s : %s (%s) a %.2f s, masse %.1f kg" % [cb[2], String(o.get("genre")) if o.get("genre") != null else o.name, str(o.get("ident")), n / 30.0, Telekinesie.masse_de(o)])
		await _filmer(14)
		magie.appuyer("gauche")
		var pris := false
		for i in 40:
			await _image()
			if tk.tient("gauche"):
				pris = true
				break
		print("   saisi : %s" % pris)
		# tenu : il suit le regard (on tourne la tête de ~24 degres, puis on revient)
		for i in 30:
			j.rotation.y += deg_to_rad(24.0) / 30.0 * (1.0 if i < 15 else -1.0)
			await _image()
		await _filmer(8)
		# lancé vers le point visé (le réticule) : on relève un peu la tête
		j.tete.rotation.x += 0.12
		magie.relacher("gauche")
		await _filmer(26)
		magie.relacher("gauche")
		await _filmer(8)
	_etiquette("")
	await _filmer(10)
	print("FIN %.2f s (%d images)" % [n / 30.0, n])
	quit()
