extends SceneTree
## Lot tripo/gardiens, prise d'épée : gros plans du poing droit du garde Tripo à l'épée, HORS du monde (fond neutre, lumière franche, rendu ps1
## des matériaux, sans post-traitement) : 3 angles (face, profil droit, dos) x états (clip:instant), une image 3x3 par appel.
##   godot --path . --script res://outils/gros_plan_prise_garde.gd -- --sortie=<dossier> [--nom=apres] [--etats=Idle:0.4,Walk:0.25,Sword_Idle:0.3]
##        [--centre=x,y,z] [--dir=x,y,z] [--ech=1.15]   (essais : remplacent GardeTripo.CENTRE_POING / EPEE_DIR / EPEE_ECH avant la création)
const T := 360
var sv: SubViewport
var cam: Camera3D

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var sortie := _arg("sortie", "user://prise_garde")
	DirAccess.make_dir_recursive_absolute(sortie)
	if _arg("centre") != "":
		GardeTripo.CENTRE_POING = _v3(_arg("centre"))
	if _arg("dir") != "":
		GardeTripo.EPEE_DIR = _v3(_arg("dir"))
	if OS.get_cmdline_user_args().has("--sans-poing"):
		GardeTripo.POING_FERME = false
	if _arg("ech") != "":
		GardeTripo.EPEE_ECH = float(_arg("ech"))
	sv = SubViewport.new()
	sv.size = Vector2i(T, T)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.own_world_3d = true
	root.add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.36, 0.42)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.9
	sv.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-35, 30, 0)
	soleil.light_energy = 1.3
	sv.add_child(soleil)
	var g := GardeTripo.creer(_arg("id", "tripo_garde_epee"))
	sv.add_child(g)
	cam = Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.02
	sv.add_child(cam)
	cam.make_current()
	if OS.get_cmdline_user_args().has("--sans-epee"):
		var e := g.find_child("EpeeJeu", true, false) as Node3D
		if e:
			e.visible = false
	var dist := float(_arg("dist", "0.85"))
	var ap: AnimationPlayer = g.get_node("Animations")
	var sq: Skeleton3D = g.find_child("Skeleton3D", true, false)
	var ib := sq.find_bone("lowerarm_r")
	var etats := _arg("etats", "Idle:0.4,Walk:0.25,Sword_Idle:0.3").split(",")
	var planche := Image.create(T * 3, T * etats.size(), false, Image.FORMAT_RGBA8)
	for r in etats.size():
		var clip := etats[r].get_slice(":", 0)
		var t := float(etats[r].get_slice(":", 1))
		ap.play(clip)
		ap.seek(t * ap.current_animation_length if t <= 1.0 else t, true)
		ap.pause()
		for i in 6:
			await process_frame
		# visée : centre du poing (CENTRE_POING dans le repère de lowerarm_r, là où l'épée est tenue)
		var bp := sq.global_transform * sq.get_bone_global_pose(ib)
		var vise := bp * (_v3(_arg("vise")) if _arg("vise") != "" else GardeTripo.CENTRE_POING)
		var axes := [Vector3(0, 0.05, 1), Vector3(-1, 0.05, 0), Vector3(0, 0.05, -1)]      # face, profil droit (côté -X du garde), dos
		if OS.get_cmdline_user_args().has("--dessous"):
			axes = [Vector3(-0.3, -1, 0.4), Vector3(-1, -0.6, 0), Vector3(0.6, -1, -0.2)]
		for c in 3:
			cam.global_position = vise + (axes[c] as Vector3).normalized() * dist
			cam.look_at(vise, Vector3.UP)
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var im := sv.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			planche.blit_rect(im, Rect2i(0, 0, T, T), Vector2i(c * T, r * T))
		print("ETAT ", clip, " ", t, " poing ", vise, " axes lowerarm_r (monde) x=", bp.basis.x.normalized(), " y=", bp.basis.y.normalized(), " z=", bp.basis.z.normalized())
	var nom := _arg("nom", "prise")
	planche.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", sortie.path_join(nom + ".png"))
	quit(0)
