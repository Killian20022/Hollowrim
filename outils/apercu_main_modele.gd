extends SceneTree
## Aperçu du modèle de la main gauche de bras_fps.glb, hors jeu : pose de repos des os (main ouverte, T-pose) et, en
## option, doigts fléchis d'une même fraction (--flexion=0.4 : chaque doigt tourné vers le poing de mains.gd n'existe pas
## ici, on plie chaque phalange autour de son axe local X de flexion × la fraction donnée en degrés --degres=<a,b,c>).
## FENÊTRE (godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/apercu_main_modele.gd -- --sortie=<fichier.png> [--degres=10,20,25] [--glb=res://…]
##   planche 2×2 : dos de la main | profil (côté pouce) | paume | trois-quarts, fond gris, lumière blanche.

const W := 480
const H := 360

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _squelette(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _squelette(c)
		if s:
			return s
	return null

func _go() -> void:
	var glb: PackedScene = load(_arg("glb", "res://assets/modeles/joueur/bras_fps.glb"))
	var bras: Node3D = glb.instantiate()
	root.add_child(bras)
	var sq := _squelette(bras)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.33, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var lum := DirectionalLight3D.new()
	lum.basis = Basis.looking_at(Vector3(-0.3, -1.0, -0.5), Vector3.FORWARD)
	root.add_child(lum)
	var deg := Array(_arg("degres", "0,0,0").split(",")).map(func(x): return float(x))
	for i in sq.get_bone_count():
		var n := sq.get_bone_name(i)
		if not n.ends_with("_l") or n.contains("leaf"):
			continue
		for d in ["index", "middle", "ring", "pinky"]:
			if n.begins_with(d + "_0"):
				var rang := int(n.get_slice("_", 1)) - 1
				# flexion : vers la paume (axe local X des os Mixamo-UE de ce rig : mesuré à l'œil, voir planche)
				sq.set_bone_pose_rotation(i, sq.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(deg[rang])))
	await process_frame
	await process_frame
	var ih := sq.find_bone("hand_l")
	var im := sq.find_bone("middle_02_l")
	var g := sq.global_transform
	var c: Vector3 = g * sq.get_bone_global_pose(ih).origin.lerp(sq.get_bone_global_pose(im).origin, 0.55)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.01
	root.add_child(cam)
	cam.current = true
	var vues := [Vector3(0, 0, 1), Vector3(0, -1, 0.15), Vector3(0, 0, -1), Vector3(0.5, -0.6, 0.6)]
	var p := Image.create(W * 2, H * 2, false, Image.FORMAT_RGBA8)
	root.get_viewport().size = Vector2i(W, H)
	for k in vues.size():
		var d: Vector3 = (vues[k] as Vector3).normalized()
		# Godot : Y en haut (Blender Z), -Z = Blender +Y ; vues données en repère Blender (x, y, z) -> (x, z, -y)
		var dg := Vector3(d.x, d.z, -d.y)
		var haut := Vector3.UP if absf(dg.y) < 0.9 else Vector3(1, 0, 0)
		cam.global_transform = Transform3D(Basis.looking_at(-dg, haut), c + dg * 0.42)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(W, H)
		p.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((k % 2) * W, (k / 2) * H))
	p.save_png(_arg("sortie", "user://apercu_main.png"))
	print("APERCU ", _arg("sortie"))
	quit()
