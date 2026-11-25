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
