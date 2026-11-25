extends SceneTree
## FILM 1re personne de la traversée du repaire (retours exe 4, chantier 5) : entrée -> mine (raccourci) -> camp -> levier -> porte qui
## s'ouvre -> salle aux cristaux (~45 s à 30 i/s). Le joueur est posé image par image sur le trajet (pas de physique) ; la porte est
## ouverte par le VRAI levier (interactif). Fenêtre hors écran (godot_slot.sh, verrou rendu) :
##   godot --path . --fixed-fps 30 --resolution 1280x720 --disable-vsync --script res://outils/film_repaire.gd -- --nouvelle --paisible --grotte=3,0,0,0 --sortie=<dossier>
## Écrit <dossier>/f_00000.jpg…  (puis : ffmpeg -framerate 30 -i f_%05d.jpg -c:v libx264 -pix_fmt yuv420p film.mp4)
const SCENE := preload("res://scenes/foret_test.tscn")

var s: Node3D
var j: CharacterBody3D
var g: Grotte
var jeu: GrotteJeu
var sortie := ""
var n := 0

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	await process_frame
	# la caméra traverse le camp image par image (pas de physique) : un bandit à moins de 2,2 m masquerait l'écran (gros plan gris)
	var cp := j.global_position + Vector3(0, 1.6, 0)
	for e in get_nodes_in_group("ennemis"):
		if e is Node3D and is_instance_valid(e):
			(e as Node3D).visible = (e as Node3D).global_position.distance_to(cp) > 2.2
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("%s/f_%05d.jpg" % [sortie, n], 0.9)
	n += 1

## Pose le joueur au point (s global, lat), cap = celui de la galerie + dyaw (°), tangage (°).
func _pose(sg: float, lat: float, dyaw := 0.0, pitch := -3.0) -> void:
	j.velocity = Vector3.ZERO
	j.global_position = g.monde_sol(sg, lat) + Vector3(0, 0.05, 0)
	j.rotation.y = g.cap_monde(sg) + deg_to_rad(dyaw)
	j.tete.rotation.x = deg_to_rad(pitch)

## Marche de s0 à s1 en `t` secondes (lat constante, léger balayage du regard).
func _marche(s0: float, s1: float, lat: float, t: float, balayage := 10.0, pitch := -3.0) -> void:
	var nb := roundi(t * 30.0)
	for i in nb:
		var u := float(i) / float(nb)
		_pose(lerpf(s0, s1, u), lat, balayage * sin(u * TAU * 1.3), pitch)
		await _image()

func _vers(cible: Vector3) -> void:
	var d := cible - (j.global_position + Vector3(0, 1.6, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _go() -> void:
	sortie = _arg("sortie", "user://film_repaire")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 90:
		await process_frame
	j = s.joueur
	g = s.grotte
	jeu = s.grotte_acces.jeu
	s.hud.visible = false
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.set_process(false)
		ips.set("visible", false)
	j.set_physics_process(false)
	for i in 30:
		await process_frame
	var meta: Dictionary = g.get_meta("porte_goulot")
	var cm: float = (float(meta["lat_g"]) + float(meta["lat_d"])) * 0.5
	if _arg("diag") != "":      # diagnostic : mêmes images avec/sans corps visible et sans mains, puis fin
		_pose(2.0, 0.0, 0.0)
		for i in 10:
			await _image()
		var pile: Array = [root]
		while not pile.is_empty():
			var nd: Node = pile.pop_back()
			pile.append_array(nd.get_children())
			if nd is MeshInstance3D and (nd as MeshInstance3D).material_override is ShaderMaterial:
				var shd: Shader = ((nd as MeshInstance3D).material_override as ShaderMaterial).shader
				if shd != null and shd.resource_path.contains("flamme_pixels"):
					print("DIAGFLAMME ", nd.get_path(), " vis=", (nd as Node3D).is_visible_in_tree(), " layers=", (nd as VisualInstance3D).layers, " pos=", (nd as Node3D).global_position, " cam=", root.get_viewport().get_camera_3d().global_position)
		var cpos := root.get_viewport().get_camera_3d().global_position
		for q in root.get_viewport().get_camera_3d().get_children():
			print("CAMENFANT ", q.name, " ", q.get_class(), " script=", (q.get_script().resource_path if q.get_script() else ""), " vis=", (q as Node3D).visible if q is Node3D else "")
			for q2 in q.get_children():
				var sh2 := ""
				if q2 is MeshInstance3D:
					for k in (q2 as MeshInstance3D).mesh.get_surface_count():
						var am: Material = (q2 as MeshInstance3D).get_active_material(k)
						sh2 += (str((am as ShaderMaterial).shader.resource_path) if am is ShaderMaterial else str(am)) + ";"
				elif q2 is MultiMeshInstance3D:
					sh2 = "multimesh n=" + str((q2 as MultiMeshInstance3D).multimesh.visible_instance_count)
				print("   ENFANT ", q2.name, " ", q2.get_class(), " pos=", (q2 as Node3D).position if q2 is Node3D else "", " vis=", (q2 as Node3D).visible if q2 is Node3D else "", " ", sh2)
		pile = [root]
		while not pile.is_empty():
			var nd3: Node = pile.pop_back()
			pile.append_array(nd3.get_children())
			if nd3 is MeshInstance3D and (nd3 as Node3D).is_visible_in_tree() and (nd3 as Node3D).global_position.distance_to(cpos) < 6.0:
				var mi3 := nd3 as MeshInstance3D
				var mats: Array = [mi3.material_override, mi3.material_overlay]
				for k in (mi3.mesh.get_surface_count() if mi3.mesh else 0):
					mats.append(mi3.get_active_material(k))
				for m in mats:
					if m is ShaderMaterial and (m as ShaderMaterial).shader != null and ((m as ShaderMaterial).shader.resource_path.contains("flamme") or (m as ShaderMaterial).shader.resource_path.contains("feu")):
						print("FLAMMEPROCHE ", nd3.get_path(), " d=", (nd3 as Node3D).global_position.distance_to(cpos), " ", (m as ShaderMaterial).shader.resource_path, " scale=", (nd3 as Node3D).global_transform.basis.get_scale())
		pile = [root]
		while not pile.is_empty():
			var nd2: Node = pile.pop_back()
			pile.append_array(nd2.get_children())
			if nd2 is VisualInstance3D and (nd2 as Node3D).is_visible_in_tree() and (nd2 as Node3D).global_position.distance_to(cpos) < 1.2:
				var info := ""
				if nd2 is MeshInstance3D:
					var mo: Material = (nd2 as MeshInstance3D).material_override
					info = str((nd2 as MeshInstance3D).mesh.get_class()) + " " + (str((mo as ShaderMaterial).shader.resource_path) if mo is ShaderMaterial else str(mo))
				print("PROCHE ", nd2.get_class(), " ", nd2.get_path(), " d=", (nd2 as Node3D).global_position.distance_to(cpos), " ", info, " script=", (nd2.get_parent().get_script().resource_path if nd2.get_parent().get_script() else ""))
		print("DIAG corps ", j.corps.visible, " pivot_torche ", j.corps.pivot_torche.visible, " troisieme ", j.troisieme)
		j.corps.visible = false
		for i in 5:
			await _image()
		j.corps.visible = true
		j.mains.visible = false
		for i in 5:
			await _image()
		print("FILM ", n, " images")
		quit(0)
	if _arg("seul") == "fps":      # IPS au calme (sans --fixed-fps) : camp puis salle aux cristaux, regard fixe, 5 s chacun après 3 s de chauffe
		for v: Array in [["camp", 306.0, 0.0, 10.0], ["cristaux", 414.0, 0.0, 0.0]]:
			_pose(float(v[1]), float(v[2]), float(v[3]), -4.0)
			var t0 := Time.get_ticks_usec()
			while Time.get_ticks_usec() - t0 < 3000000:
				await process_frame
			var nf := 0
			t0 = Time.get_ticks_usec()
			while Time.get_ticks_usec() - t0 < 5000000:
				await process_frame
				nf += 1
			print("IPS %s : %.1f" % [v[0], float(nf) / (float(Time.get_ticks_usec() - t0) / 1e6)])
		quit(0)
	if _arg("seul") == "barres":      # diagnostic : quelle famille de maillages dessine les barres noires du goulet (vue 404.5, +30°)
		(jeu.interactifs["levier_goulot"] as Node3D).parler()
		var vv := _arg("vue", "404.5,%f,30" % cm).split(",")
		_pose(float(vv[0]), float(vv[1]), float(vv[2]), 0.0)
		for i in 90:
			await process_frame
		await _image()
		g.visible = false
		await _image()
		print("BARRES image %d : sans grotte" % (n - 1))
		g.visible = true
		var cls: Array = []
		var pc: Array = [root]
		while not pc.is_empty():
			var nd0: Node = pc.pop_back()
			pc.append_array(nd0.get_children())
			if (nd0 is CanvasLayer and (nd0 as CanvasLayer).visible) or (nd0 is CanvasItem and nd0.get_parent() == root and (nd0 as CanvasItem).visible):
				cls.append(nd0)
				print("BARRES calque ", nd0.get_path(), " ", nd0.get_class())
		for c0 in cls:
			c0.set("visible", false)
		await _image()
		print("BARRES image %d : sans calques 2D" % (n - 1))
		for c0 in cls:
			c0.set("visible", true)
		var lums: Array = []
		var pl: Array = [root]
		while not pl.is_empty():
			var nd1: Node = pl.pop_back()
			pl.append_array(nd1.get_children())
			if nd1 is Light3D and (nd1 as Light3D).visible and (nd1 as Light3D).shadow_enabled:
				lums.append(nd1)
				print("BARRES ombre ", nd1.get_path(), " d=%.1f" % (nd1 as Node3D).global_position.distance_to(root.get_viewport().get_camera_3d().global_position))
		for l0 in lums:
			(l0 as Light3D).shadow_enabled = false
		await _image()
		print("BARRES image %d : sans ombres" % (n - 1))
		for l0 in lums:
			(l0 as Light3D).shadow_enabled = true
		var mats := {}
		var pm: Array = [g]
		while not pm.is_empty():
			var nd2: Node = pm.pop_back()
			pm.append_array(nd2.get_children())
			if nd2 is GeometryInstance3D:
				var lm: Array = [(nd2 as GeometryInstance3D).material_override]
				if nd2 is MeshInstance3D and (nd2 as MeshInstance3D).mesh != null:
					for k in (nd2 as MeshInstance3D).mesh.get_surface_count():
						lm.append((nd2 as MeshInstance3D).get_active_material(k))
				for m0 in lm:
					if m0 is ShaderMaterial and (m0 as ShaderMaterial).get_shader_parameter("grille") != null:
						mats[m0] = (m0 as ShaderMaterial).get_shader_parameter("grille")
		for m0: ShaderMaterial in mats:
			m0.set_shader_parameter("grille", 0.0)
		await _image()
		print("BARRES image %d : sans accroche des sommets (%d matières)" % [n - 1, mats.size()])
		for m0: ShaderMaterial in mats:
			m0.set_shader_parameter("grille", mats[m0])
		var cam0 := root.get_viewport().get_camera_3d()
		print("BARRES camera near=%.3f fov=%.1f pos=%s" % [cam0.near, cam0.fov, cam0.global_position])
		var familles := {}
		var pile2: Array = [g]
		var cam3 := root.get_viewport().get_camera_3d().global_position
		while not pile2.is_empty():
			var nd: Node = pile2.pop_back()
			pile2.append_array(nd.get_children())
			if nd is VisualInstance3D and (nd as Node3D).is_visible_in_tree():
				var aabb := (nd as VisualInstance3D).get_aabb()
				var gt := (nd as Node3D).global_transform
				if not (gt * aabb).grow(1.5).has_point(cam3) or String(nd.name).begins_with("CoqueFine") or nd is Light3D:
					continue
				var nd_ := nd as VisualInstance3D
				var l0 := nd_.layers
				nd_.layers = 0
				await _image()
				nd_.layers = l0
				print("BARRES image %d : sans %s" % [n - 1, nd.get_path()])
				continue
				var fam := String(nd.name).get_slice("_", 0).rstrip("0123456789@")
				if nd.get_parent() != g:
					fam = String(nd.get_parent().name).get_slice("_", 0).rstrip("0123456789@") + "/" + fam
				if not familles.has(fam):
					familles[fam] = []
				(familles[fam] as Array).append(nd)
		for fam: String in familles:
			for nd: Node3D in familles[fam]:
				nd.visible = false
			await _image()
			print("BARRES image %d : sans %s (%d) %s" % [n - 1, fam, (familles[fam] as Array).size(), (familles[fam][0] as Node).get_path()])
			for nd: Node3D in familles[fam]:
				nd.visible = true
		quit(0)
	if _arg("seul") == "porte":      # mise au point rapide : porte ouverte d'office, seulement le passage du goulet et les cristaux (1 image sur 3)
		print("PORTE lat_g=%.2f lat_d=%.2f cm=%.2f" % [float(meta["lat_g"]), float(meta["lat_d"]), cm])
		_pose(400.2, cm, 0.0, 6.0)
		for i in 90:
			await process_frame
		for v: Array in [[400.2, cm, 0.0, 6.0], [401.0, cm - 0.2, -18.0, 2.0], [401.6, cm, 25.0, 14.0], [401.2, cm, -35.0, -8.0]]:
			_pose(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
			await _image()
		(jeu.interactifs["levier_goulot"] as Node3D).parler()
		_pose(399.2, cm)
		for i in 120:
			await process_frame
		var sg := 399.2
		while sg < 414.0:
			_pose(sg, cm if sg < 412.0 else 0.0, 0.0, -2.0)
			await _image()
			sg += 0.6
		for a: float in [-60.0, -30.0, 30.0, 60.0]:
			for sv: float in [403.0, 404.5, 406.0]:
				_pose(sv, cm, a, 0.0)
				await _image()
		print("FILM ", n, " images")
		quit(0)
	# 1. l'entrée
	await _marche(2.0, 30.0, 0.0, 8.0, 12.0)
	# 2. la mine (raccourci), puis le camp
	_pose(158.0, 0.0)
	for i in 30:
		await process_frame
	await _marche(158.0, 169.0, 0.0, 4.0, 5.0)
	_pose(304.0, 0.0)      # saut jusqu'au camp : on laisse la grotte allumer ses lanternes et faire apparaître les gens avant de filmer (sinon noir)
	for i in 45:
		await process_frame
	await _marche(304.0, 316.0, 0.0, 9.0, 22.0, -4.0)
	# 3. le levier : on s'approche du goulet, côté camp, et on le regarde
	_pose(399.2, cm)
	for i in 30:
		await process_frame
	var lev: Vector3 = g.to_global(meta["levier"])
	for i in 120:
		var u := float(i) / 120.0
		_pose(lerpf(399.2, 400.7, u), lerpf(cm, cm + 0.2, u))
		_vers(lev + Vector3(0, -0.1, 0))
		await _image()
	for i in 36:
		await _image()
	(jeu.interactifs["levier_goulot"] as Node3D).parler()
	for i in 120:         # le manche bascule, la porte s'ouvre (2,45 s)
		_pose(400.7, cm + 0.2)
		_vers(lev if i < 20 else g.to_global(meta["bas"]) + Vector3(0, 1.3, 0))
		await _image()
	# 4. on passe la porte et on découvre la salle aux cristaux
	await _marche(400.7, 412.0, cm, 6.0, 4.0, -2.0)
	await _marche(412.0, 424.0, 0.0, 6.0, 25.0, -4.0)
	for i in 60:
		_pose(424.0, 0.0, 40.0 * sin(float(i) / 60.0 * PI), -3.0)
		await _image()
	print("FILM ", n, " images")
	quit(0)
