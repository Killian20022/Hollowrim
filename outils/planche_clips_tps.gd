extends SceneTree
## Planche des clips d'incantation du corps (3e personne) : le héros posé à N instants de chaque clip, vu de 3/4 avant.
##   godot --path . --script res://outils/planche_clips_tps.gd -- --sortie=<dossier> [--clips=A,B,...] [--vue=face|dos]
var N := 6
var cam: Camera3D
var heros: Node3D
var ap: AnimationPlayer

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	N = int(_arg("n", "6"))
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	monde.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	monde.add_child(sol)
	heros = HerosSkarnholt.creer({})
	monde.add_child(heros)
	ap = heros.get_node("Animations")
	ap.add_animation_library("s", load("res://assets/modeles/humains/animations_sorts_tps.res"))
	cam = Camera3D.new()
	monde.add_child(cam)
	var dos := _arg("vue", "face") == "dos"
	cam.position = Vector3(1.6, 1.4, -2.6) if dos else Vector3(1.8, 1.3, 2.6)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.fov = 45
	var clips := _arg("clips", "").split(",", false)
	if clips.is_empty():
		clips = PackedStringArray(["Spell_Simple_Enter", "Spell_Simple_Idle", "Spell_Simple_Shoot", "Spell_Simple_Exit", "Idle_Torch"])
		for n in ap.get_animation_library("s").get_animation_list():
			if not String(n).ends_with("_G"):
				clips.append("s/" + n)
	var dossier := _arg("sortie", "res://captures/clips_tps")
	DirAccess.make_dir_recursive_absolute(dossier)
	for _i in 10:
		await process_frame
	var w := 160
	var h := 200
	var planche := Image.create(w * N, h * clips.size(), false, Image.FORMAT_RGBA8)
	for c in clips.size():
		var nom := clips[c]
		var a := ap.get_animation(nom)
		for k in N:
			var t := a.length * k / float(N - 1)
			ap.play(nom)
			ap.seek(t, true)
			ap.pause()
			await process_frame
			await process_frame
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var cw := img.get_width()
			var ch := img.get_height()
			var r := Rect2i(int(cw * 0.5 - ch * 0.4), 0, int(ch * 0.8), ch)
			var sub := img.get_region(r)
			sub.resize(w, h, Image.INTERPOLATE_BILINEAR)
			planche.blit_rect(sub, Rect2i(0, 0, w, h), Vector2i(k * w, c * h))
		print("CLIP ", c, " ", nom, " ", a.length)
	planche.save_png(dossier.path_join("planche_clips_%s.png" % _arg("vue", "face")))
	print("PLANCHE ", dossier)
	quit(0)
