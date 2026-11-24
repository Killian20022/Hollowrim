extends SceneTree
## Film « casse réaliste » (2026-11-24) : UN objet à la fois, caméra proche, lumière et shader PS1 du village, ralenti ×0,4 sur l'impact.
## Pour chaque objet (bûche, chaise, tonneau, jarre, sac, pelle, citrouille) : un lancer DOUX (4 m/s) puis un lancer VIOLENT (10 m/s) contre un
## mur ; légende du comportement. Même chaîne qu'en jeu : CasseObjets.morceaux / eclater / effets, seuils de MATIERES, modèles pq_* du jeu.
##   godot --path . --fixed-fps 30 --disable-vsync --script res://outils/film_casse_realiste.gd -- --sortie=<dossier> --planche=<dossier>
## Images : <sortie>/f_00000.png … ; <planche>/cle_<objet>.png : une image clé par objet (lancer violent, 0,5 s après l'impact).

const SCENE := preload("res://scenes/foret_test.tscn")
# [prop pq_, prop q_, matière, masse kg, nom, verbe du lancer violent]
const NOMS := [["pq_buche", "q_buche", "buche", 4.0, "Bûche", "fendue en 2"], ["pq_chaise", "q_chaise", "meuble_leger", 6.0, "Chaise", "démontée par pièces"],
	["pq_tonneau", "q_tonneau", "tonneau", 40.0, "Tonneau", "éclate en douelles"], ["pq_jarre", "q_jarre", "poterie", 4.0, "Jarre", "en tessons"],
	["pq_sac", "q_sac", "tissu", 25.0, "Sac", "déchiré en 2"], ["pq_pelle", "q_pelle", "bois_outil", 2.5, "Pelle", "cassée net en 2"],
	["pq_citrouille", "q_citrouille", "citrouille", 3.0, "Citrouille", "éclate en 3"]]
const RALENTI := 0.4

var s: Node3D
var j: CharacterBody3D
var sortie := ""
var planche := ""
var n := 0
var cam: Camera3D
var legende: Label
var base := Vector3.ZERO       ## pied du mur, face au joueur
var mur: StaticBody3D
var _eclats_film := []      ## tous les éclats créés par le film (effacés entre deux lancers)
var _gardes := []      ## maillages gardés vivants : le cache de découpe est indexé par identifiant d'instance (un identifiant libéré serait réutilisé)

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	s.cycle.heure = 11.0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/f_%05d.png" % [sortie, n])
	n += 1

func _cle(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/cle_%s.png" % [planche, nom])

func _monter_mur() -> void:
	mur = StaticBody3D.new()
	mur.name = "MurFilm"
	mur.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(7.0, 4.0, 0.4)
	cs.shape = bx
	mur.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bx.size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.46, 0.42, 0.38)
	m.roughness = 1.0
	mi.material_override = m
	mur.add_child(mi)
	s.add_child(mur)
	mur.global_position = base + Vector3(0, 1.6, -0.2)
	var sol := StaticBody3D.new()      # sol de terre battue
	sol.collision_layer = 1
	var cs2 := CollisionShape3D.new()
	var bx2 := BoxShape3D.new()
	bx2.size = Vector3(16, 0.5, 16)
	cs2.shape = bx2
	sol.add_child(cs2)
	var mi2 := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = bx2.size
	mi2.mesh = bm2
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.36, 0.27, 0.19)
	m2.roughness = 1.0
	mi2.material_override = m2
	sol.add_child(mi2)
	s.add_child(sol)
	sol.global_position = base + Vector3(0, -0.25, 4.0)

## Un lancer : renvoie le nombre de morceaux (0 : rebond).
func _lancer(rang: int, vitesse: float, violent: bool) -> void:
	var d: Array = NOMS[rang]
	var nom: String = d[0] if PropsQuaternius.existe(String(d[0])) or String(d[0]).begins_with("pq_") and PropsQuat.maillage(String(d[0]), "interieur") != null else d[1]
	var matiere: String = d[2]
	var masse: float = d[3]
	var mv := PropsQuaternius.mats_village(s.village)
	CasseObjets.noter_fer(mv["fer"])
	var morc := ObjetsVivants.morceaux_q(nom, func(m: String) -> Material: return mv.get(m, mv["bois"]))
	if morc.is_empty():
		print("FILM %s : modèle absent" % nom)
		return
	var bb := ObjetsVivants.boite_morceaux(morc)
	var am := ArrayMesh.new()
	_gardes.append(am)
	for m: Array in morc:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m[0])
		am.surface_set_material(am.get_surface_count() - 1, m[1])
	var b := RigidBody3D.new()
	b.collision_layer = 0
	b.collision_mask = 1
	b.mass = masse
	b.contact_monitor = true
	b.max_contacts_reported = 4
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = bb.size
	cs.shape = bx
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.position = -bb.get_center()
	b.add_child(mi)
	s.add_child(b)
	var dist := 4.5
	var t := dist / vitesse
	var y0 := base.y + bb.size.y * 0.5 + 0.35
	var vy := (base.y + 0.7 - y0 + 4.9 * t * t) / t      # parabole qui arrive à 0,7 m du sol sur le mur
	b.global_position = Vector3(base.x, y0, base.z + dist)
	b.linear_velocity = Vector3(0, vy, -vitesse)
	b.angular_velocity = Vector3(1.5, 0.5, 2.0)
	var e_att := CasseObjets.energie(Vector3(0, 0, -vitesse), masse)
	var seuil := CasseObjets.seuil(matiere)
	var etat := {"fini": false, "v": b.linear_velocity, "res": -1}
	b.body_entered.connect(func(c: Node) -> void:
		if etat["fini"] or c.name != "MurFilm":
			return
		etat["fini"] = true
		var v: Vector3 = etat["v"]
		var e := CasseObjets.energie(v, masse)
		if e >= seuil:
			var xf := mi.global_transform
			var pt := b.global_position + v.normalized() * 0.2
			b.visible = false
			b.collision_mask = 0
			b.set_deferred("freeze", true)
			var res := CasseObjets.eclater(s, am, xf, matiere, masse, pt, v * 0.3, 7)
			CasseObjets.effets(s, b.global_position, b.global_position - Vector3(0, bb.size.y * 0.5, 0), pt, matiere, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
			etat["res"] = res.size()
			_eclats_film.append_array(res)
			print("FILM %s %s : %.0f J >= %.0f J -> %d morceaux" % [d[4], "violent" if violent else "doux", e, seuil, res.size()])
		else:
			etat["res"] = 0
			CasseObjets.son_choc(s, matiere, b.global_position, e)
			print("FILM %s %s : %.0f J < %.0f J -> rebondit" % [d[4], "violent" if violent else "doux", e, seuil]))
	legende.text = "%s — lancer %s (%.0f m/s, %.0f J ; seuil %.0f J)" % [d[4], "violent" if violent else "doux", vitesse, e_att, seuil]
	# caméra proche, de trois quarts, sur le point d'impact
	var cible := base + Vector3(0, 0.7, 0.3)
	cam.global_position = base + Vector3(1.9, 1.15, 3.3)
	cam.look_at(cible)
	Engine.time_scale = 1.0
	var apres := -1
	var cle_ok := false
	for i in 150:
		if not etat["fini"] and is_instance_valid(b):
			b.linear_velocity.z = -vitesse      # la vitesse du lancer est tenue jusqu'au mur (le sol ne la freine pas)
			etat["v"] = b.linear_velocity
			if b.global_position.z - base.z < 1.8:
				Engine.time_scale = RALENTI
		await _image()
		if etat["fini"]:
			if apres < 0:
				apres = 0
				var r := int(etat["res"])
				legende.text = "%s — lancer %s : %s" % [d[4], "violent" if violent else "doux", ("rebondit, intacte" if r == 0 else "%s (%d morceaux)" % [d[5], r])]
			apres += 1
			if violent and not cle_ok and apres >= 5 and planche != "":
				cle_ok = true
				await _cle(String(d[4]).to_lower())
			if apres > 48:
				break
	Engine.time_scale = 1.0
	b.queue_free()
	for e in _eclats_film:
		if is_instance_valid(e):
			(e as Node).queue_free()
	_eclats_film.clear()
	await _images_vides(6)

func _images_vides(k: int) -> void:
	for i in k:
		await process_frame

func _go() -> void:
	sortie = _arg("sortie", "")
	planche = _arg("planche", "")
	DirAccess.make_dir_recursive_absolute(sortie)
	if planche != "":
		DirAccess.make_dir_recursive_absolute(planche)
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
	for l: Array in s.hud.lieux_nommes:
		s.hud.lieux_vus[l[2]] = true
	s.hud.aide_t = 0.0
	if s.hud.get("visible") != null:
		s.hud.set("visible", false)
	j.mains.visible = false
	j.set_physics_process(false)
	if s.get("crime") != null:
		(s.crime as Node).remove_from_group("crime")
	var p := Vector3(46.9, 0.0, 53.9)      # ruelle au sud de la place (sol plat, comme les films précédents)
	var h := 0.0
	for dx in [-1.5, 0.0, 1.5]:
		h = maxf(h, float(s.hauteur(p.x + dx, p.z)))
	base = Vector3(p.x, h + 60.0, p.z)      # l'arène flotte au-dessus du village : rien ne gêne le lancer, même soleil et même ciel
	cam = Camera3D.new()
	cam.fov = 55.0
	s.add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	cl.layer = 50
	s.add_child(cl)
	legende = Label.new()
	legende.position = Vector2(8, 6)
	legende.add_theme_font_size_override("font_size", 16)
	legende.add_theme_color_override("font_outline_color", Color.BLACK)
	legende.add_theme_constant_override("outline_size", 5)
	cl.add_child(legende)
	_monter_mur()
	for i in 20:
		await process_frame
	for k in NOMS.size():
		await _lancer(k, 4.0, false)
		await _lancer(k, 10.0, true)
	print("FILM %d images dans %s" % [n, sortie])
	quit(0)
