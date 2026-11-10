extends SceneTree
## Planche des clips candidats aux gestes de métier (lot vie/metiers) : un corps PnjNordique par case, 4 instants par clip, vue de profil 3/4.
##   godot --path . --script res://outils/planche_clips_metiers.gd -- --sortie=<png> [--clips=a,b,c] [--perso=forgeron]
const CW := 150
const CH := 210
var clips := ["Fixing_Kneeling", "Push", "Interact", "PickUp_Table", "Spell_Simple_Idle", "Crouch_Idle", "Sitting_Idle", "Sitting_Talking", "Idle_Torch", "Sword_Idle", "Driving", "vertical"]

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return d

func _lancer() -> void:
	if _arg("clips", "") != "":
		clips = _arg("clips", "").split(",")
	var n := 4
	var sv := SubViewport.new()
	sv.size = Vector2i(CW, CH)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	sv.add_child(sol)
	var plan := MeshInstance3D.new()
	plan.mesh = PlaneMesh.new()
	(plan.mesh as PlaneMesh).size = Vector2(10, 10)
	sv.add_child(plan)
	# repère de hauteur : banc de 0,48 m (boîte 1,8 x 0,48 x 0,38) derrière le corps
	var banc := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.48, 0.38)
	banc.mesh = bm
	banc.position = Vector3(0, 0.24, -0.30)
	sv.add_child(banc)
	var corps := PnjNordique.creer(_arg("perso", "forgeron"))
	sv.add_child(corps)
	var ap: AnimationPlayer = corps.get_node("Animations")
	var coups: AnimationLibrary = load("res://assets/animations/corps_coups_tps.res")
	var lib := ap.get_animation_library("")
	for c in coups.get_animation_list():
		if not lib.has_animation(c):
			lib.add_animation(c, coups.get_animation(c))
	var cam := Camera3D.new()
	cam.fov = 40.0
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(3.2, 1.3, 2.2), Vector3(0, 0.85, 0))
	var img := Image.create(CW * n, CH * clips.size(), false, Image.FORMAT_RGB8)
	for ci in clips.size():
		var c: String = clips[ci]
		banc.visible = c.begins_with("Sitting")
		if not ap.has_animation(c):
			print("absent : ", c)
			continue
		var L := ap.get_animation(c).length
		for k in n:
			ap.play(c, 0.0)
			ap.seek(L * float(k) / float(n), true)
			ap.advance(0.0)
			for f in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var im := sv.get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			img.blit_rect(im, Rect2i(0, 0, CW, CH), Vector2i(k * CW, ci * CH))
		print("clip ", c, " ", L)
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/planche_clips_metiers.png"))
	img.save_png(sortie)
	print("PLANCHE ", sortie)
	quit()
