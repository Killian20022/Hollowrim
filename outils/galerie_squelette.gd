extends SceneTree
## Galerie de contrôle du squelette guerrier (mêmes réglages jour/nuit que scripts/cycle.gd, fond magenta : le vide se voit).
##   godot --path . --script res://outils/galerie_squelette.gd -- --sortie=res://captures/squelette [--arme=epee|arc] [--pose=Idle]
##   --mode=fixe  : face / profil / dos × (jour 2 m, jour 8 m, nuit 2 m, nuit 8 m, jour 20 m)   (planche par arme)
##   --mode=anim  : 8 images d'un cycle × face / profil / dos, pour --pose=Walk|Sprint|Sword_Attack|Sword_Idle... (--dist=3 --nuit=0)
##   --mode=mort  : le corps après le ragdoll (t = 0,5 s ... 3 s), vu de 3 côtés
const ANGLES := [["face", 0.0], ["profil", 90.0], ["dos", 180.0]]
var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var cote := 270

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _regler(nuit: bool) -> void:
	env.ambient_light_color = Color(0.32, 0.4, 0.62) if nuit else Color(0.55, 0.62, 0.76)
	env.ambient_light_energy = 0.55 if nuit else 0.62
	soleil.light_color = Color(0.62, 0.72, 1.0) if nuit else Color(1.0, 0.86, 0.7)
	soleil.light_energy = 0.75 if nuit else 1.45
	soleil.rotation_degrees = Vector3(-50, 25, 0) if nuit else Vector3(-25, -30, 0)

func _prendre(az: float, dist: float, haut: float) -> Image:
	var a := deg_to_rad(az)
	var cible := Vector3(0, haut, 0)
	cam.global_position = cible + Vector3(sin(a), 0.0, cos(a)) * dist
	cam.look_at(cible, Vector3.UP)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _lancer() -> void:
	cote = int(_arg("cote", "270"))
	var sortie := _arg("sortie", "res://captures/squelette")
	var dossier := ProjectSettings.globalize_path(sortie)
	DirAccess.make_dir_recursive_absolute(dossier)
	sv = SubViewport.new()
	sv.size = Vector2i(cote, cote)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	soleil = DirectionalLight3D.new()
	sv.add_child(soleil)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	sv.add_child(cam)
	var mode := _arg("mode", "fixe")
	var pose := _arg("pose", "Idle")
	for arme: String in _arg("arme", "epee").split(",", false):
		var perso := SqueletteGuerrier.creer({"arme": arme})
		sv.add_child(perso)
		var ap: AnimationPlayer = perso.get_node("Animations")
		if mode == "fixe":
			var pose_fixe := _arg("pose", "Sword_Idle")
			ap.play(pose_fixe)
			ap.seek(float(_arg("t", "0.2")), true)
			ap.pause()
			for i in 3:
				await process_frame
			var rangs := _arg("rangs", "j2,j8,n2,n8,j20").split(",", false)
			var feuille := Image.create(cote * 3, cote * rangs.size(), false, Image.FORMAT_RGBA8)
			for r in rangs.size():
				_regler(rangs[r].begins_with("n"))
				var dist := float(rangs[r].substr(1))
				for c in 3:
					var img := await _prendre(ANGLES[c][1], dist, 1.1 if dist < 3.0 else 0.95)
					feuille.blit_rect(img, Rect2i(0, 0, cote, cote), Vector2i(c * cote, r * cote))
			feuille.save_png(dossier + "/fixe_%s%s.png" % [arme, _arg("suffixe", "")])
		elif mode == "anim":
			var nuit := _arg("nuit", "0") == "1"
			_regler(nuit)
			var dist := float(_arg("dist", "3.2"))
			var n := int(_arg("images", "8"))
			var dur := ap.get_animation(pose).length
			ap.play(pose)
			var lc := int(cote * float(_arg("rogne", "0.62")))   # largeur conservée au centre de chaque image
			var feuille := Image.create(lc * n, cote * 3, false, Image.FORMAT_RGBA8)
			for k in n:
				ap.seek(dur * k / n, true)
				ap.pause()
				for i in 2:
					await process_frame
				for c in 3:
					var img := await _prendre(ANGLES[c][1], dist, 0.95)
					feuille.blit_rect(img, Rect2i((cote - lc) / 2, 0, lc, cote), Vector2i(k * lc, c * cote))
			feuille.save_png(dossier + "/anim_%s_%s%s.png" % [arme, pose, "_nuit" if nuit else ""])
		perso.queue_free()
		await process_frame
	SqueletteGuerrier.vider()
	Palette.vider()
	Humain.vider()
	quit(0)
