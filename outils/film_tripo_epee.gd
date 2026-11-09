extends SceneTree
## Film en VUE 1re PERSONNE d'une épée pour comparer « verre » (actuelle) / « tripo_verre » (A, Tripo pur) / « tripo_hybride »
## (B, matériaux PS1 verre/or/cuir). FENÊTRE (godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_tripo_epee.gd -- --nouvelle \
##         --epee=verre|tripo_verre|tripo_hybride --titre="Actuelle" --sortie=<dossier des fixes>
## Séquence (~9 s) : jour sur neige (repos qui respire, 2 coups sur le mannequin, léger mouvement de caméra), puis nuit à la torche
## (repos, 1 coup). Fixe <sortie>/fixe_<epee>.png : même pose (repos, jour, image 25). Le modèle du catalogue « epee_verre » est
## simplement redirigé vers le glb demandé (aucune donnée du jeu n'est écrite).
const DT := 1.0 / 30.0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var l: Label
var epee := "verre"

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _att(sec: float) -> void:
	for i in roundi(sec / DT):
		j.vigueur = j.vigueur_max
		await process_frame

func _coup() -> void:
	mains.entrees.appuyer()
	await _att(0.07)
	mains.entrees.relacher()
	await _att(0.55)

func _go() -> void:
	epee = _arg("epee", "verre")
	RetourImpact.muet = false
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cl := CanvasLayer.new()
	cl.layer = 60
	s.add_child(cl)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.text = _arg("titre", epee)
	l.position = Vector2(12, 320)   # le rendu du jeu est en 480x270 étiré : la police suit la taille de fenêtre
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -52.0
	l.offset_left = 18.0
	cl.add_child(l)
	for i in 20:
		await process_frame
	var d: DonneesArme = load("res://data/armes/epee_verre.tres")
	d.modele = EpeesLongues.DOSSIER + epee + ".glb"
	# nœuds vides du glb (le nouvel export les nomme « garde.001 », « pointe.001 » : mains.gd cherche le nom exact) -> on les lit ici
	var tmp: Node3D = load(d.modele).instantiate()
	var g3: Node3D = tmp.find_child("garde*", true, false)
	var p3: Node3D = tmp.find_child("pointe*", true, false)
	if g3 != null and p3 != null:
		d.garde = g3.position
		d.pointe = p3.position
	tmp.free()
	if epee == "tripo_verre":
		d.materiau_lame = ""   # le matériau « verre » partagé n'est pas posé sur cette épée
	mains.magie.equiper("gauche", "")
	mains.magie.equiper("droite", "epee_verre")
	s.mannequin.position = Vector3(0.0, 0.0, -1.75)
	# --- jour, neige
	s.placer_joueur(Vector3(0.0, 0.0, 0.0), 0.0, 4.0)
	mains.combat.forcer(EtatCombat.REPOS)
	await _att(0.8)
	print("DEBUT_SEQUENCE %d" % Engine.get_process_frames())
	await _att(1.2)                       # repos, l'épée respire
	var im := root.get_viewport().get_texture().get_image()
	await RenderingServer.frame_post_draw
	im = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://tripo"))
	im.save_png(_arg("sortie", "user://tripo").path_join("fixe_%s.png" % epee))
	# gros plan (fixe) : caméra du joueur, cadrée sur le bas de la lame et la garde, champ resserré
	var mod: Node3D = mains._modele_arme_d
	var pr: Node3D = mod.find_child("prise*", true, false)
	var po: Node3D = mod.find_child("pointe*", true, false)
	var cg := Camera3D.new()
	cg.near = 0.01
	cg.fov = 38.0
	s.add_child(cg)
	var cible: Vector3 = pr.global_position.lerp(po.global_position, 0.35)
	cg.global_transform = Transform3D(Basis.looking_at(cible - j.camera.global_position, Vector3.UP), j.camera.global_position)
	cg.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_arg("sortie", "user://tripo").path_join("gros_%s.png" % epee))
	cg.queue_free()
	j.camera.current = true
	await process_frame
	print("LONGUEUR_LAME %.3f" % pr.global_position.distance_to(po.global_position))
	await _coup()
	await _coup()
	await _att(0.5)
	for k in 45:                          # léger mouvement de caméra (balayage + tangage)
		var t := k / 45.0
		j.rotation.y = deg_to_rad(sin(t * TAU) * 14.0)
		j.tete.rotation.x = deg_to_rad(4.0 - sin(t * PI) * 8.0)
		await process_frame
	s.placer_joueur(Vector3(0.0, 0.0, 0.0), 0.0, 4.0)
	await _att(0.3)
	# --- nuit, torche en main gauche
	var env: Environment = s.env
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_energy = 0.12
	s.soleil.light_energy = 0.12
	mains.magie.equiper("gauche", "torche")
	await _att(1.6)
	await _coup()
	await _att(0.8)
	print("FIN_SEQUENCE %d" % Engine.get_process_frames())
	quit(0)
