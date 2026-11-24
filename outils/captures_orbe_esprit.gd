extends SceneTree
## Captures 1re personne de l'ORBE DE L'ESPRIT en main (scripts/magie/orbe_esprit.gd) : au repos pour chaque sort de l'esprit, puis
## en effort (maintien / charge). Dans la crypte (par défaut) ou à l'air libre de nuit (--dehors).
##   godot --path . --resolution 1280x720 --script res://outils/captures_orbe_esprit.gd -- --nouvelle --crypte=0,-24,0,-4 --paisible --images=<dossier>
## Options : --dehors (pas de descente dans la crypte), --film (images continues toutes les 2 images pour une vidéo : --images)

const DT := 1.0 / 30.0
var s: Node
var j: CharacterBody3D
var magie: MainSort
var _dossier := ""
var _n := 0
var _film := false

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.vie = j.vie_max
		j.mana = j.mana_max
		await process_frame
		if _film and i % 2 == 0:
			_cap("film")

func _cap(nom: String) -> void:
	if _dossier == "":
		return
	var im := root.get_viewport().get_texture().get_image()
	_n += 1
	im.save_png(_dossier.path_join("%s_%04d.png" % [nom, _n]))

func _go() -> void:
	RetourImpact.muet = false
	_dossier = _arg("images", "")
	_film = _arg("film") != ""
	if _dossier != "":
		DirAccess.make_dir_recursive_absolute(_dossier)
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	magie = j.mains.magie
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var y0 := j.global_position.y
	var n := 0
	if _arg("dehors") == "":
		while n < 30 * 60 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
			await process_frame
			n += 1
	await _attendre(2.5)
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.visible = false
	var tag := _arg("tag", "")
	for sort in (["telekinesie", "repulsion", "levitation", "attraction"] if _arg("rien") == "" else []):
		magie.equiper("gauche", sort)
		await _attendre(1.6)
		_cap(tag + sort + "_repos")
		if _arg("rapide") != "":
			continue
		if _arg("debug") != "":
			_debug()
		# effort : maintien (télékinésie, lévitation) ou charge (répulsion, attraction) : orbites resserrées et rapides
		magie.appuyer("gauche")
		await _attendre(1.2)
		_cap(tag + sort + "_effort")
		await _attendre(0.8)
		_cap(tag + sort + "_effort2")
		magie.relacher("gauche")
		await _attendre(1.0)
	if _arg("fps") != "":
		var t0 := Time.get_ticks_usec()
		var f := 0
		magie.equiper("gauche", _arg("fpssort", "telekinesie"))
		await _attendre(0.5)
		t0 = Time.get_ticks_usec()
		for i in 240:
			await process_frame
			f += 1
		print("FPS_ORBE ", float(f) / (float(Time.get_ticks_usec() - t0) / 1e6))
	print("CAPTURES_OK ", _n)
	quit()

func _debug() -> void:
	var cam := root.get_viewport().get_camera_3d()
	for r in root.find_children("Runes_gauche", "RunesOrbite", true, false):
		var o: OrbeEsprit = r.orbe
		print("DBG runes pos ", r.global_position, " ecole ", r.ecole, " sort ", r.sort, " orbe ", o)
		if o == null:
			continue
		print("DBG ecran centre ", cam.unproject_position(o.global_position), " cam ", cam.global_position, " dist ", cam.global_position.distance_to(o.global_position))
		for c in o.get_children():
			var mi := c as MeshInstance3D
			print("DBG ", mi.mesh.get_class(), " vis ", mi.is_visible_in_tree(), " scale ", mi.transform.basis.get_scale(), " pos ", mi.global_position, " layers ", mi.layers)
