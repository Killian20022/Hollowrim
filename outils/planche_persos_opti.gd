extends SceneTree
## Planche AVANT | APRÈS des optimisations persos_anim (2026-11-20) : mêmes poses, même heure. Lancer deux fois (avec et sans les --sans-opti-*)
## puis assembler. Le garde visé est figé (animation posée à t fixe, process coupé) pour que les deux images soient comparables.
##   godot --path . --script res://outils/planche_persos_opti.gd -- --nouvelle --paisible --heure=21 --garde=Garde_ronde_place --dist=2.2 --sortie=C:/.../x.png
## Plusieurs vues : --vues=face,profil,loin (suffixe _<vue> ajouté au nom de fichier).
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	var j: Node3D = m.joueur
	var th := Time.get_ticks_msec()
	while m.village.get("prets") != true and Time.get_ticks_msec() - th < 90000:
		await process_frame
	m.cycle.heure = float(_arg("heure", "21"))
	m.cycle._process(0.0)
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	for k in 240:
		await process_frame
	var g: Node3D = m.find_child(_arg("garde", "Garde_ronde_place"), true, false)
	if g == null:
		push_error("garde introuvable")
		quit(1)
		return
	var dist := float(_arg("dist", "2.2"))
	var sortie := _arg("sortie", "C:/Users/lopezk19/Jeux/rendus/planche.png")
	for vue in _arg("vues", "face").split(","):
		g.process_mode = Node.PROCESS_MODE_DISABLED
		g.global_position = Vector3(36.0, m.hauteur(36.0, 26.0), 26.0)
		g.rotation.y = 0.0
		var ap: AnimationPlayer = g.get("anim")
		if ap != null:
			ap.play("Idle")
			ap.seek(0.5, true)
			ap.pause()
		var angle := 0.0
		var d := dist
		match vue:
			"profil": angle = PI * 0.5
			"dos": angle = PI
			"loin": d = 9.0
		var dir := Vector3(sin(angle), 0, cos(angle))
		var p := g.global_position + dir * d
		j.global_position = Vector3(p.x, m.hauteur(p.x, p.z) + 0.05, p.z)
		j.velocity = Vector3.ZERO
		j.rotation.y = atan2(dir.x, dir.z)
		j.tete.rotation.x = deg_to_rad(-8.0 if d < 4.0 else -4.0)
		for k in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		var f := sortie.get_basename() + "_" + vue + ".png"
		im.save_png(f)
		print("PLANCHE ", f)
	quit(0)
