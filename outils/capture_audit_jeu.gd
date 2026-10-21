extends SceneTree
## Captures EN JEU pour l'audit des personnages (refonte/persos_audit) : monde réel, shaders, lumière du jeu, résolution --res.
## Place le joueur devant chaque cible (villageois par id, ennemi par ident), mains cachées, et enregistre l'image (640x360 natif).
##   godot --path . --script res://outils/capture_audit_jeu.gd -- --nouvelle --paisible --sans-particules --res=640x360 \
##        --cibles=garde:2:0,garde:4:35,cr_ossuaire_2:2:0 --sortie=<dossier absolu> [--heure=12] [--lister]
## Cible = id:distance:azimut° (azimut autour de la cible, 0 = devant elle) ; les villageois d'abord, puis les ennemis de la crypte.
var t := 0.0
var monde: Node

func _init() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await process_frame

func _trouver(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if String(p.donnees.get("id", "")) == id:
			return p
	for e in get_nodes_in_group("ennemis"):
		if "ident" in e and String(e.ident) == id:
			return e
	return null

func _lancer() -> void:
	await _attendre(7.0)
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/audit_persos/jeu"))
	DirAccess.make_dir_recursive_absolute(sortie)
	var joueur: CharacterBody3D = monde.joueur
	joueur.mains.visible = false
	monde.cycle.heure = float(_arg("heure", "12"))
	monde.cycle._process(0.0)
	var dessous := false
	for c: String in _arg("cibles", "").split(",", false):
		var p := c.split(":")
		var id := p[0]
		var dist := float(p[1]) if p.size() > 1 else 3.0
		var az := deg_to_rad(float(p[2]) if p.size() > 2 else 0.0)
		var cible := _trouver(id)
		if cible == null and not dessous:
			monde.tertre._passer(true)
			await _attendre(1.5)
			monde._ouvrir_donjon("s1,s2,s3,secret,herse")
			dessous = true
			if _arg("lister", "") != "":
				for e in get_nodes_in_group("ennemis"):
					print("ENNEMI ", e.ident, " ", e.type, " ", e.global_position)
			cible = _trouver(id)
		if cible == null:
			push_error("cible introuvable : " + id)
			continue
		if cible.has_method("set_physics_process"):
			cible.set_physics_process(false)
		var lacet: float = cible.global_rotation.y + az
		var dir := Vector3(sin(lacet), 0, cos(lacet))   # devant le personnage (+Z local)
		joueur.global_position = cible.global_position + dir * dist + Vector3(0, 0.1, 0)
		joueur.velocity = Vector3.ZERO
		joueur.rotation.y = atan2(dir.x, dir.z)            # la caméra regarde -Z : vers la cible
		var oeil: float = joueur.tete.global_position.y
		var vise: float = cible.global_position.y + 1.0
		joueur.tete.rotation.x = atan2(vise - oeil, dist)
		joueur.mains.visible = dessous and _arg("torche", "") != ""   # --torche : sous terre, mains et torche visibles (éclairage réel du joueur)
		await _attendre(1.2)
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		var nom := "%s_%sm_az%d%s" % [id, p[1] if p.size() > 1 else "3", int(rad_to_deg(az)), "_torche" if joueur.mains.visible else ""]
		img.save_png(sortie.path_join(nom + ".png"))
		print("CAPTURE ", nom, " ", img.get_width(), "x", img.get_height(), " cible=", cible.global_position)
	quit(0)
