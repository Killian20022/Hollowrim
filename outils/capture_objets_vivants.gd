extends SceneTree
## Captures « avant | après » des objets vivants (même cadrage, même heure) : halle de Gunnhild (table servie) et étal des primeurs.
##   godot --path . --disable-vsync --script res://outils/capture_objets_vivants.gd -- --nouvelle --paisible --sortie=<dossier> --nom=apres
##   (avant : même commande avec -- --sans-objets-vivants --nom=avant : tout reste fondu dans le décor)
## Images : <dossier>/<nom>_halle.png, <nom>_marche.png.

const SCENE := preload("res://scenes/foret_test.tscn")

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _photo(chemin: String) -> void:
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	im.convert(Image.FORMAT_RGB8)
	im.save_png(chemin)

func _go() -> void:
	var sortie := _arg("sortie", "user://")
	var nom := _arg("nom", "apres")
	var s: Node3D = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 2400:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	var j: CharacterBody3D = s.joueur
	s.cycle.heure = 21.0
	s.cycle._process(0.0)
	s.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	for l: Array in s.hud.lieux_nommes:      # ni annonce de lieu, ni aide des touches, ni bras : on regarde le décor
		s.hud.lieux_vus[l[2]] = true
	s.hud.aide_t = 0.0
	j.mains.visible = false
	var ip: Interieur = s.village.interieur("halle")
	j.global_position = ip.to_global(Vector3(3.4, ip.sol_y + 0.05, 0.9))
	j.velocity = Vector3.ZERO
	j.rotation.y = ip.global_rotation.y + deg_to_rad(25.0)
	j.tete.rotation.x = deg_to_rad(-14.0)
	await _photo("%s/%s_halle.png" % [sortie, nom])
	# table servie de près (cadrage du film)
	var centre := ip.to_global(Vector3(3.9, ip.sol_y + 0.65, -1.75))
	j.global_position = ip.to_global(Vector3(3.6, ip.sol_y + 0.02, -0.25))
	j.velocity = Vector3.ZERO
	for i in 10:
		await process_frame
	var dc: Vector3 = centre - j.camera.global_position
	j.rotation.y = atan2(-dc.x, -dc.z)
	j.tete.rotation.x = atan2(dc.y, Vector2(dc.x, dc.z).length())
	await _photo("%s/%s_table.png" % [sortie, nom])
	# étal des primeurs (marché) de jour : premier étal de MobilierVillage.POSES, vu du côté des clients
	s.cycle.heure = 12.0
	s.cycle._process(0.0)
	var p := Vector3(51.5, 0.0, 30.5)
	var cote := Basis(Vector3.UP, deg_to_rad(180.0)) * Vector3(0.0, 0.0, -2.1)
	var oeil := p + cote
	j.global_position = Vector3(oeil.x, s.hauteur(oeil.x, oeil.z) + 0.05, oeil.z)
	j.velocity = Vector3.ZERO
	var d := p + Vector3(0, s.hauteur(p.x, p.z) + 0.8, 0) - (j.global_position + Vector3(0, 1.62, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await _photo("%s/%s_marche.png" % [sortie, nom])
	print("CAPTURES %s dans %s" % [nom, sortie])
	quit(0)
