extends SceneTree
## FILM 1re personne de la traversée de la crypte du tertre (chantier crypte_trous, 2026-11-25) : le joueur est posé image par image
## sur un trajet (pas de physique ; sol trouvé par rayon), regard dans le sens de la marche avec un lent balayage gauche-droite,
## toutes les portes ouvertes ; salle active, brume, lumières et post-traitement du jeu. Fenêtre hors écran (godot_slot.sh, verrou rendu) :
##   godot --path . --fixed-fps 30 --resolution 1280x720 --disable-vsync --script res://outils/film_crypte_trous.gd -- --nouvelle --paisible
##         --crypte=0,0.5,0,0 --sortie=<dossier> [--trajet="x,z[,y];x,z;..."] [--vitesse=2.2] [--balayage=35]
## Écrit <dossier>/f_00000.jpg… (ffmpeg -framerate 30 -i f_%05d.jpg -c:v libx264 -pix_fmt yuv420p film.mp4)
const TRAJET := "0,2.5;0,-8;0,-17;-3,-19.8;-10,-19.8;-15.5,-19.8;-16,-23;-16,-27;-16,-37,-6;-15,-43,-6;-8,-43,-6;-2,-43,-6;4,-45,-6"

var s: Node3D
var t: Node3D
var j: Node3D
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
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("%s/f_%05d.jpg" % [sortie, n], 0.9)
	n += 1

func _sol(x: float, z: float, y_ref: float) -> Vector3:
	var c: Node3D = t.crypte
	var ss := s.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(c.to_global(Vector3(x, y_ref + 1.5, z)), c.to_global(Vector3(x, y_ref - 3.0, z)))
	q.collision_mask = 1
	var exclus: Array[RID] = []
	for nd in s.find_children("*", "CharacterBody3D", true, false):
		exclus.append((nd as CharacterBody3D).get_rid())
	q.exclude = exclus
	var r := ss.intersect_ray(q)
	return c.to_local(r["position"]) if not r.is_empty() else Vector3(x, y_ref, z)

func _go() -> void:
	sortie = _arg("sortie", "user://film_crypte")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	var k := 0
	while k < 60 * 90 and not (s.tertre != null and s.tertre.dedans):
		await process_frame
		k += 1
	t = s.tertre
	t.attendre_donjon()
	s._ouvrir_donjon("s1,s2,s3,secret,herse")
	t._porte_haut("arene", true)
	t._porte_haut("tombe", true)
	t._etat_donjon()
	for e in get_nodes_in_group("ennemis"):      # film de décor : pas de gardien qui se lève dans le champ
		if e is Node3D:
			(e as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
	var hud = s.get("hud")
	if hud != null and hud is CanvasItem:
		(hud as CanvasItem).visible = false
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.set_process(false)
		ips.set("visible", false)
	j.set_physics_process(false)
	for i in 60:
		await process_frame
	# trajet : points du sol, puis échantillonnage à vitesse constante
	var pts: Array = []
	var y := 0.0
	for e in _arg("trajet", TRAJET).split(";"):
		var f := e.split_floats(",")
		if f.size() > 2:
			y = f[2]
		var p := _sol(f[0], f[1], y)
		y = p.y
		pts.append(p)
	var v := float(_arg("vitesse", "2.2"))
	var bal := float(_arg("balayage", "35"))
	var cap := 0.0
	var tps := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var nb := maxi(1, roundi(a.distance_to(b) / v * 30.0))
		for q in nb:
			var u := float(q) / nb
			var p := a.lerp(b, u)
			p = _sol(p.x, p.z, p.y)
			var d := b - a
			var cap_voulu := atan2(-d.x, -d.z)
			cap = lerp_angle(cap, cap_voulu, 0.08) if tps > 0.0 else cap_voulu
			tps += 1.0 / 30.0
			j.velocity = Vector3.ZERO
			j.global_position = t.crypte.to_global(p + Vector3(0, 0.05, 0))
			j.rotation.y = t.crypte.global_rotation.y + cap + deg_to_rad(bal * sin(tps * 0.9))
			j.tete.rotation.x = deg_to_rad(-4.0 + 9.0 * sin(tps * 0.37))
			await _image()
	print("FILM ", n, " images")
	quit(0)
