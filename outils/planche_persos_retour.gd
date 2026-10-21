extends SceneTree
## Planche « avant / maintenant / après retour » des personnages (refonte/persos_retour) : capture EN JEU (monde réel, shaders, lumière
## du cycle), chaque personnage amené au même endroit de la place du village, même pose (Idle figé), caméra du joueur (FOV 72°).
## Fonctionne sur toutes les versions (avant 2ec1c7e, kit Personnage, retour Humain) : l'apparence du bandit est prise dans le code présent.
##   godot --path . --disable-vsync --script res://outils/planche_persos_retour.gd -- --nouvelle --paisible --sans-particules --res=640x360 \
##        --sortie=<dossier absolu> [--heures=12,17.5] [--distances=2,4]
## Crépuscule : 17.5 depuis la refonte (cycle recalé), 15 avant (2ec1c7e^1 : clarté à mi-chemin entre 14 h et 16 h).
## Écrit <perso>_<heure>_<dist>m.png (640x360).
const PERSOS := ["chef", "forgeron", "garde", "chasseuse", "volva", "ancienne", "bandit", "joueur"]
var monde: Node
var cam: Camera3D

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

func _villageois(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if String(p.donnees.get("id", "")) == id:
			return p
	return null

## Apparence d'un bandit casqué (tenue 1) telle que le code présent la construit.
func _apparence_bandit() -> Dictionary:
	if "--persos-kit" in OS.get_cmdline_user_args() or not FileAccess.file_exists("res://scripts/persos_humains.gd"):
		for c: Dictionary in ProjectSettings.get_global_class_list():
			if c["class"] == "PersoDefs":
				return {"perso": load(c["path"]).bandit(1)}
	if FileAccess.file_exists("res://scripts/persos_humains.gd"):
		return load("res://scripts/persos_humains.gd").bandit(1)
	# avant 2ec1c7e : grotte_acces.gd, bandit k = 1
	var C := Color.WHITE
	return {"corps": "homme", "draugr": false, "peau": Color(0.93, 0.78, 0.7), "barbe": true, "casque": "casque_nasal",
		"tenue": {"tunique": C, "pantalon": C, "mante": C, "epaulieres": C, "pteruges": C, "bottes": C, "ceinture": C, "brassards": C},
		"etoffes": {"tunique": "cuir_b", "pantalon": "gris", "mante": "gris", "epaulieres": "cuir_a", "pteruges": "cuir_a", "bottes": "cuir_b", "ceinture": "cuir_a", "brassards": "cuir_a"},
		"cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.5, 0.35, 0.2)}

func _figer(n: Node) -> void:
	var ap := n.find_child("Animations", true, false) as AnimationPlayer
	if ap == null:
		return
	ap.play("Idle", 0.0)
	ap.seek(0.5, true)
	ap.pause()

func _lancer() -> void:
	await _attendre(7.0)
	var res := _arg("res", "")
	if res != "":       # les versions anciennes ne lisent pas --res : on l'applique ici
		var wh := res.split("x")
		root.content_scale_size = Vector2i(int(wh[0]), int(wh[1]))
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/persos_retour"))
	DirAccess.make_dir_recursive_absolute(sortie)
	var joueur: CharacterBody3D = monde.joueur
	joueur.mains.visible = false
	for c in monde.calque.get_children():        # interface cachée, post-traitement PS1 gardé
		if c is CanvasItem and (c as CanvasItem).material != monde.post:
			(c as CanvasItem).visible = false
	var village: Node3D = monde.village
	var spot: Vector3 = village.to_global(Vector3(-1.2, 0, 1.6))
	spot.y = monde.hauteur(spot.x, spot.z)
	var cap := village.global_rotation.y + PI * 0.8      # le personnage regarde par là ; la caméra est devant lui
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 900.0
	monde.add_child(cam)
	# bandit (même créature que le draugr), créé une fois, caché tant qu'il ne pose pas
	var bandit: CharacterBody3D = monde.creer_draugr("sbire", spot + Vector3(0, -50, 0), cap, false, {"ident": "bandit_planche", "nom_affiche": "Bandit", "apparence": _apparence_bandit()})
	bandit.set_physics_process(false)
	bandit.visible = false
	for p in get_nodes_in_group("villageois"):
		p.set_physics_process(false)
		p.set_process(false)
	var heures := _arg("heures", "12,17.5").split(",", false)
	var dists := _arg("distances", "2,4").split(",", false)
	for nom: String in PERSOS:
		var cible: Node3D
		if nom == "bandit":
			cible = bandit
		elif nom == "joueur":
			cible = joueur
		else:
			cible = _villageois(nom)
		if cible == null:
			push_error("introuvable : " + nom)
			continue
		var ancien := cible.global_transform
		for p in get_nodes_in_group("villageois"):
			p.visible = p == cible
		bandit.visible = cible == bandit
		cible.visible = true
		var face := cap
		if nom == "joueur":
			joueur.set_physics_process(false)
			joueur.corps.definir_vue(true)
			joueur.corps.set_process(false)
			joueur.corps.set_physics_process(false)
			face = cap + PI          # le modèle du joueur est tourné de PI (il regarde +Z, le joueur -Z)
		cible.global_position = spot + Vector3(0, 0.02, 0)
		cible.global_rotation = Vector3(0, face, 0)
		_figer(cible if nom != "joueur" else joueur.corps)
		for h: String in heures:
			monde.cycle.heure = float(h)
			monde.cycle._process(0.0)
			for d: String in dists:
				var dir := Vector3(sin(cap), 0, cos(cap))
				cam.global_position = spot + dir * float(d) + Vector3(0, 1.6, 0)
				cam.look_at(spot + Vector3(0, 1.0 if float(d) < 3.0 else 0.95, 0), Vector3.UP)
				cam.current = true
				await _attendre(0.8)
				await RenderingServer.frame_post_draw
				var img := root.get_viewport().get_texture().get_image()
				var f := "%s_%s_%sm.png" % [nom, h.replace(".", "h"), d]
				img.save_png(sortie.path_join(f))
				print("CAPTURE ", f, " ", img.get_width(), "x", img.get_height())
		if nom != "joueur" and nom != "bandit":
			cible.global_transform = ancien
	quit(0)
