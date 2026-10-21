extends SceneTree
## Planche « avant / maintenant / après retour » des personnages (refonte/persos_retour) : capture EN JEU (monde réel, shaders, lumière
## du cycle), chaque personnage amené au même endroit de la place du village, même pose (Idle figé), caméra du joueur (FOV 72°).
## Fonctionne sur toutes les versions (avant 2ec1c7e, kit Personnage, retour Humain) : l'apparence du bandit est prise dans le code présent.
##   godot --path . --disable-vsync --script res://outils/planche_persos_retour.gd -- --nouvelle --paisible --sans-particules --res=640x360 \
##        --sortie=<dossier absolu> [--heures=12,17.5] [--distances=2,4] [--persos=hrafn,archer] (hrafn / archer : versions avec grotte_jeu.gd)
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
	var src_perso := FileAccess.get_file_as_string("res://scripts/personnage.gd")
	var interrupteur := src_perso.contains("func kit_actif")
	if interrupteur and not ("--persos-kit" in OS.get_cmdline_user_args()):
		return load("res://scripts/grotte_jeu.gd").apparence_humain(1, "casque_nasal")      # retour Humain (refonte/persos_retour)
	if src_perso != "":
		return {"perso": load("res://scripts/perso_defs.gd").bandit(1)}                    # kit Personnage (2ec1c7e → refonte/base)
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
	var liste := _arg("persos", ",".join(PERSOS)).split(",", false)
	var ennemis := {}
	for nom: String in liste:
		if nom in ["bandit", "hrafn", "archer"]:
			var app := _apparence_bandit()
			if nom != "bandit":
				var kit := "--persos-kit" in OS.get_cmdline_user_args()
				var gj: GDScript = load("res://scripts/grotte_jeu.gd")
				app = ({"perso": load("res://scripts/perso_def.gd").depuis(gj.HRAFN)} if kit else gj.apparence_humain(4)) if nom == "hrafn" \
					else ({"perso": load("res://scripts/perso_defs.gd").bandit(3)} if kit else gj.apparence_humain(3))
			var opts := {"ident": nom + "_planche", "nom_affiche": "Bandit", "apparence": app}
			if nom == "archer":
				opts["archer"] = true
			var e: CharacterBody3D = monde.creer_draugr("sbire", spot + Vector3(0, -50, 0), cap, false, opts)
			e.set_physics_process(false)
			e.visible = false
			ennemis[nom] = e
	for p in get_nodes_in_group("villageois"):
		p.set_physics_process(false)
		p.set_process(false)
	var heures := _arg("heures", "12,17.5").split(",", false)
	var dists := _arg("distances", "2,4").split(",", false)
	for nom: String in liste:
		var cible: Node3D
		if ennemis.has(nom):
			cible = ennemis[nom]
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
		for e: Node3D in ennemis.values():
			e.visible = e == cible
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
		if nom != "joueur" and not ennemis.has(nom):
			cible.global_transform = ancien
	quit(0)
