extends SceneTree
## Planches des GARDES EN ARMURE MAISON (scripts/garde_maison.gd) : scène de combat de jour (test_combat), fenêtre hors écran (godot_slot.sh).
## Par garde (data/gardes.json, + Haldor) : face, 3/4, profil, dos en pose de repos ; gros plans cou, épaules, aisselles et coudes en
## pose d'attaque (bras levé), plus la pose de marche ; tout assemblé dans <sortie>/planche_<id>.png (+ les vues séparées).
##   godot --path . --resolution 960x540 --script res://outils/planches_gardes_maison.gd -- --nouvelle --sortie=<dossier> [--ids=so,n_e,...]
const DT := 1.0 / 30.0
const IDS := ["so", "n_o", "e_n", "e_s", "n_e", "halle_e", "vigie", "ronde_nord", "ronde_rue", "ronde_est", "ronde_ouest", "ronde_place", "haldor"]
var s: Node
var cam: Camera3D
var l: Label
var sortie := "user://gardes_maison"
var ids: Array = IDS

func _init() -> void:
	_go.call_deferred()

func _attendre(n := 2) -> void:
	for i in n:
		await process_frame

func _donnees(id: String) -> Dictionary:
	var d := GardesVillage.donnees()
	if id == "haldor":
		var h: Dictionary = (d.get("haldor", {}) as Dictionary).duplicate()
		h["id"] = "haldor"
		h["type"] = "poste"
		return h
	for g: Dictionary in d["gardes"]:
		if String(g.get("id", "")) == id:
			return g
	return {}

## Soleil venant de derrière la caméra, un peu de côté et au-dessus.
func _soleil() -> void:
	var avant := -cam.global_transform.basis.z
	avant.y = 0.0
	avant = avant.normalized().rotated(Vector3.UP, deg_to_rad(-25.0))
	s.soleil.global_transform = Transform3D(Basis.looking_at((avant + Vector3(0, -0.85, 0)).normalized(), Vector3.UP), Vector3.ZERO)

func _photo(texte: String, region := Rect2i()) -> Image:
	_soleil()
	l.text = texte
	l.position = Vector2(region.position) + Vector2(6, 4)
	l.size = Vector2(maxf(region.size.x, 300) - 12, 0)
	await _attendre(3)
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	if im.get_height() != 540:
		im.resize(960, 540, Image.INTERPOLATE_NEAREST)
	if region.size != Vector2i.ZERO:
		im = im.get_region(region)
	return im

## Fige le clip `clip` à `t` s.
func _poser(mod: Node3D, clip: String, t: float) -> void:
	var ap := mod.get_node("Animations") as AnimationPlayer
	var c := clip if ap.has_animation(clip) else "Idle"
	ap.play(c, 0.0)
	ap.seek(minf(t, ap.get_animation(c).length - 0.01), true)
	ap.pause()

## Caméra : depuis la direction `deg` autour du modèle (0 = de face, 90 = profil gauche du garde), à `dist` m, œil à `hc`, visée à `h`.
func _cadrer(deg: float, dist: float, h: float, hc: float, fov := 40.0) -> void:
	var dir := Vector3(sin(deg_to_rad(deg)), 0, cos(deg_to_rad(deg)))
	cam.fov = fov
	cam.global_position = dir * dist + Vector3(0, hc, 0)
	cam.look_at(Vector3(0, h, 0), Vector3.UP)

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--ids="):
			ids = a.substr(6).split(",")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	await _attendre(5)
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	s.joueur.global_position = Vector3(0, 0, 18)
	s.joueur.visible = false
	s.joueur.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("mur") != null:
		s.mur.visible = false
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var calque := CanvasLayer.new()
	calque.layer = 60
	root.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calque.add_child(l)
	cam = Camera3D.new()
	s.add_child(cam)
	cam.make_current()
	for id: String in ids:
		var g := _donnees(id)
		if g.is_empty():
			print("INCONNU ", id)
			continue
		var mod := GardeMaison.creer(g)
		s.add_child(mod)
		mod.global_position = Vector3.ZERO
		await _attendre(4)
		var nom := "%s  [%s]  %s" % [id, GardeMaison.role_de(g), ", ".join(GardeMaison.pieces_portees(mod))]
		print("GARDE ", nom, "  maillages ", mod.find_child("Skeleton3D", true, false).find_children("*", "MeshInstance3D", false, false).size())
		var vues: Array = []
		_poser(mod, "Idle", 0.6)
		var cadre := Rect2i(300, 0, 360, 540)
		var pp := GardeMaison.pieces_portees(mod)
		var defaut := "\ncol de fourrure trop haut :\ndefaut du glb (correction\nen cours, armures lourdes)" if pp.has("cuirasse_fer") or pp.has("cuirasse_acier_nordique") else ""
		for v: Array in [[0.0, "face"], [35.0, "3/4"], [90.0, "profil"], [180.0, "dos"]]:
			_cadrer(v[0], 3.3, 0.95, 1.25)
			vues.append(await _photo(id + "  " + String(v[1]) + ("\n" + String(GardeMaison.role_de(g)) + " : " + ", ".join(pp) + defaut if v[1] == "face" else ""), cadre))
		var attaque := "Lance_Estoc" if GardeMaison.arme_de(g) == "lance" else ("Pistol_Aim_Neutral" if GardeMaison.arme_de(g) == "arc" else "Sword_Attack")
		var gros: Array = []
		var cg := Rect2i(240, 30, 480, 480)
		_poser(mod, "Idle", 0.6)
		_cadrer(30.0, 0.95, 1.45, 1.6, 45.0)
		gros.append(await _photo("cou / epaules (repos)", cg))
		_cadrer(200.0, 0.95, 1.45, 1.6, 45.0)
		gros.append(await _photo("nuque / epaules (dos)", cg))
		_poser(mod, attaque, 0.45)
		_cadrer(70.0, 1.15, 1.25, 1.3, 50.0)
		gros.append(await _photo("aisselle / coude droit (%s)" % attaque, cg))
		_cadrer(-70.0, 1.15, 1.25, 1.3, 50.0)
		gros.append(await _photo("aisselle / coude gauche (%s)" % attaque, cg))
		_cadrer(0.0, 1.2, 1.2, 1.35, 50.0)
		gros.append(await _photo("face, bras leves (%s)" % attaque, cg))
		_poser(mod, "Walk", 0.35)
		_cadrer(35.0, 1.6, 1.0, 1.3, 50.0)
		gros.append(await _photo("marche 3/4", cg))
		# planche : 4 vues (360x540) en haut, 6 gros plans (480x480) sur deux rangées
		var pl := Image.create(1440, 540 + 960, false, Image.FORMAT_RGB8)
		pl.fill(Color(0.08, 0.08, 0.1))
		for i in vues.size():
			pl.blit_rect(vues[i], Rect2i(Vector2i.ZERO, vues[i].get_size()), Vector2i(i * 360, 0))
		for i in gros.size():
			var im: Image = gros[i]
			pl.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % 3) * 480, 540 + (i / 3) * 480))
		pl.save_png(sortie.path_join("planche_%s.png" % id))
		print("PLANCHE ", id, "  ", nom)
		mod.queue_free()
		await _attendre(2)
	print("FIN planches")
	quit()
