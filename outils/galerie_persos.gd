extends SceneTree
## Lot 4 : galerie de contrôle des personnages, comme en jeu (SubViewport 270x270, mêmes réglages jour/nuit que scripts/cycle.gd).
## Une planche par personnage : colonnes face / profil / dos, lignes jour 2 m, jour 8 m, nuit 2 m, nuit 8 m (fond magenta : le vide se voit).
##   godot --path . --script res://outils/galerie_persos.gd -- --sortie=res://captures/lot4/apres [--perso=a,b] [--pose=Idle] [--cote=270] [--zoom=2]
## Les vues à 8 m sont aussi écrites agrandies (_zoom) : image 8 m recadrée sur le personnage et x4 en plus-proche-voisin.
const ANGLES := [["face", 0.0], ["profil", 90.0], ["dos", 180.0]]
const POSES := {"Idle": ["Idle", 0.3], "Walk": ["Walk", 0.35], "Sword_Idle": ["Sword_Idle", 0.2], "T": ["A_TPose", 0.0]}
const C := Color.WHITE
var cote := 270
var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var courant: Node3D

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _persos() -> Dictionary:
	var vill: Dictionary = load("res://scripts/villageois.gd").APPARENCES
	var d := {}
	for id: String in vill:
		d["pnj_" + id] = vill[id]
	d["joueur"] = {"corps": "homme", "tenue": {"tunique": Color(0.35, 0.4, 0.55), "pantalon": Color(0.8, 0.75, 0.7), "bottes": C, "ceinture": C,
		"mante": Color(1.1, 1.0, 0.95), "brassards": C, "gants": C},
		"etoffes": {"tunique": "bleu", "mante": "gris", "pantalon": "brun", "bottes": "cuir_a", "ceinture": "cuir_a", "brassards": "cuir_a", "gants": "cuir_a"}, "cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.42, 0.28, 0.17), "barbe": true}
	d["draugr_sbire"] = {"corps": "homme", "draugr": true, "tenue": {"tunique": C, "ceinture": C, "brassards": C, "haillons": C}}
	d["draugr_guerrier"] = {"corps": "homme", "draugr": true, "casque": "casque_draugr", "etoffes": {"tunique": "mailles_rouille", "brassards": "draugr"},
		"tenue": {"tunique": C, "ceinture": C, "brassards": C, "mante": C, "bottes": C, "epaulieres": C, "pteruges": C, "cape_courte": C}}
	for k in 4:
		d["bandit_%d" % k] = _bandit(k)
	d["svanhild"] = {"corps": "femme", "draugr": true, "casque": "couronne_givre", "cheveux": "Hair_Long", "teinte_cheveux": Color(1.1, 1.15, 1.25),
		"tenue": {"tunique": C, "robe": C, "cape": C, "mante": C, "brassards": C, "ceinture": C, "bottes": C, "epaulieres": C},
		"etoffes": {"tunique": "draugr", "robe": "draugr", "cape": "draugr", "mante": "blanc", "epaulieres": "draugr"}}
	return d

func _bandit(k: int) -> Dictionary:
	# même définition que scripts/grotte_acces.gd (_bandits) : recopiée ici, pas de dépendance au monde
	var tenues := [
		["tunique", "pantalon", "mante", "capuche", "sacoche", "bottes", "ceinture", "brassards", "gants"],
		["tunique", "pantalon", "mante", "epaulieres", "pteruges", "bottes", "ceinture", "brassards"],
		["tunique", "pantalon", "cape_courte", "capuche", "sacoche", "bottes", "ceinture", "gants"],
		["tunique", "pantalon", "mante", "carquois", "pteruges", "bottes", "ceinture", "brassards"]]
	var et := [
		{"tunique": "cuir_a", "pantalon": "brun", "mante": "brun", "capuche": "brun", "sacoche": "cuir_b", "bottes": "cuir_b", "ceinture": "cuir_b", "brassards": "cuir_b", "gants": "cuir_b"},
		{"tunique": "cuir_b", "pantalon": "gris", "mante": "gris", "epaulieres": "cuir_a", "pteruges": "cuir_a", "bottes": "cuir_b", "ceinture": "cuir_a", "brassards": "cuir_a"},
		{"tunique": "lin", "pantalon": "noir", "cape_courte": "brun", "capuche": "gris", "sacoche": "cuir_a", "bottes": "cuir_a", "ceinture": "cuir_b", "gants": "cuir_b"},
		{"tunique": "cuir_a", "pantalon": "brun", "mante": "blanc", "carquois": "cuir_b", "pteruges": "cuir_b", "bottes": "cuir_b", "ceinture": "cuir_b", "brassards": "cuir_b"}]
	var t := {}
	for n: String in tenues[k]:
		t[n] = C
	var coupes := ["Hair_Buzzed", "Hair_SimpleParted", "Hair_Long", "Hair_Buzzed"]
	var app := {"corps": "homme", "tenue": t, "etoffes": et[k], "cheveux": coupes[k], "teinte_cheveux": Color(0.4, 0.28, 0.16), "barbe": k != 2, "peau": Color(0.93, 0.78, 0.7)}
	if k == 1:
		app["casque"] = "casque_nasal"
	return app

func _regler(nuit: bool) -> void:
	env.ambient_light_color = Color(0.32, 0.4, 0.62) if nuit else Color(0.55, 0.62, 0.76)
	env.ambient_light_energy = 0.55 if nuit else 0.62
	soleil.light_color = Color(0.62, 0.72, 1.0) if nuit else Color(1.0, 0.86, 0.7)
	soleil.light_energy = 0.75 if nuit else 1.45
	# soleil bas au sud / lune haute, vus du personnage (le personnage regarde +Z)
	soleil.rotation_degrees = Vector3(-50, 25, 0) if nuit else Vector3(-25, -30, 0)

func _lancer() -> void:
	cote = int(_arg("cote", "270"))
	var sortie := _arg("sortie", "res://captures/lot4/apres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
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
	var persos := _persos()
	var choix := _arg("perso", "").split(",", false)
	var pose: String = _arg("pose", "Idle")
	for nom: String in persos:
		if not choix.is_empty() and not (nom in choix):
			continue
		courant = Humain.creer(persos[nom])
		sv.add_child(courant)
		var ap: AnimationPlayer = courant.get_node("Animations")
		var def: Array = POSES[pose]
		ap.play(def[0])
		ap.seek(ap.get_animation(def[0]).length * float(def[1]), true)
		ap.pause()
		for i in 3:
			await process_frame
		var rangs := _arg("rangs", "j2,j8,n2,n8").split(",", false)
		var feuille := Image.create(cote * ANGLES.size(), cote * rangs.size(), false, Image.FORMAT_RGBA8)
		var zoom := Image.create(cote * ANGLES.size(), cote * rangs.size(), false, Image.FORMAT_RGBA8)
		for rang in rangs.size():
			var nuit: bool = rangs[rang].begins_with("n")
			var dist := float(rangs[rang].substr(1))
			_regler(nuit)
			for col in ANGLES.size():
				var az := deg_to_rad(float(ANGLES[col][1]))
				var haut := float(_arg("haut", "1.15")) if dist < 3.0 else 0.95
				var cible := Vector3(0, haut, 0)
				cam.global_position = cible + Vector3(sin(az), 0.0, cos(az)) * dist
				cam.look_at(cible, Vector3.UP)
				for i in 2:
					await process_frame
				await RenderingServer.frame_post_draw
				var img := sv.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				feuille.blit_rect(img, Rect2i(0, 0, cote, cote), Vector2i(col * cote, rang * cote))
				if dist > 3.0:
					var r := Rect2i(cote / 2 - 34, cote / 2 - 56, 68, 112)   # personnage de 8 m, recadré
					var p := img.get_region(r)
					p.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
					zoom.blit_rect(p, Rect2i(0, 0, p.get_width(), p.get_height()), Vector2i(col * cote + (cote - p.get_width()) / 2, rang * cote + 20))
		feuille.save_png(ProjectSettings.globalize_path(sortie) + "/%s.png" % nom)
		zoom.save_png(ProjectSettings.globalize_path(sortie) + "/%s_zoom8m.png" % nom)
		courant.queue_free()
		await process_frame
	Palette.vider()
	Humain.vider()
	quit(0)
