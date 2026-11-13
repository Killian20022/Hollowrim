extends SceneTree
## Photos EN JEU (vraie crypte foret_test, rendu du jeu, corps créés par monde.creer_draugr = le vrai chemin) des ennemis avec leur arme :
## pour chaque cas, face / trois-quarts / profil / gros plan de la main droite, en garde (Sword_Idle), en marche (Walk) et en plein coup
## (Sword_Attack), puis à la mort (arme au sol près du corps : --mort).
##   godot --path . --script res://outils/captures_armes_ennemis.gd -- --nouvelle --sortie=<dossier> [--cas=draugr_epee_soldat,...] [--poses=garde,marche,coup] [--mort]
## Écrit <cas>__<pose>_<vue>.png ; affiche « CAS <cas> : arme <id> (ident) ».
## Un cas = [étiquette, type, options, arme attendue] ; l'identifiant est cherché (graine stable) jusqu'à ce que le tirage donne l'arme voulue.
const SCENE := preload("res://scenes/foret_test.tscn")
const POSES := {"garde": ["Sword_Idle", 0.5], "marche": ["Walk", 0.3], "coup": ["Sword_Attack", 0.38]}
const VUES := {"face": 0.0, "trois_quarts": 40.0, "profil_droit": -90.0}
const CAS := [
	["draugr_epee_soldat", "sbire", {}, "epee_soldat"], ["draugr_hache_guerre", "sbire", {}, "hache_guerre"],
	["draugr_masse_cloutee", "sbire", {}, "masse_cloutee"], ["draugr_hachette", "sbire", {}, "hachette"],
	["ancien_hache_guerre", "guerrier", {}, "hache_guerre"], ["ancien_marteau_guerre", "guerrier", {}, "marteau_guerre"],
	["squelette_epee_soldat", "squelette", {}, "epee_soldat"], ["squelette_gourdin", "squelette", {}, "gourdin"], ["squelette_hachette", "squelette", {}, "hachette"],
	["bandit_hachette", "sbire", {"b": 0}, "hachette"], ["bandit_gourdin", "sbire", {"b": 0}, "gourdin"], ["bandit_sabre_pillard", "sbire", {"b": 0}, "sabre_pillard"],
	["bandit_masse_cloutee", "sbire", {"b": 0}, "masse_cloutee"], ["bandit_costaud_hache_guerre", "sbire", {"b": 1}, "hache_guerre"],
	["bandit_costaud_marteau_guerre", "sbire", {"b": 1}, "marteau_guerre"], ["gobelin_dague", "gobelin", {}, "dague_acier"],
	["jarl_hache_kolbeinn", "guerrier", {"boss": "jarl"}, "hache_kolbeinn"],
]
var _sortie := ""

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _photo(chemin: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(chemin)

func _options(cas: Array, ident: String) -> Dictionary:
	var o: Dictionary = {"ident": ident, "dort": false}
	var c: Dictionary = cas[2]
	if c.has("boss"):
		o["boss"] = c["boss"]
		o["ident"] = String(c["boss"])
	elif c.has("b"):      # bandit humain : tenue de la grotte ; b = 1 : casqué (costaud)
		o["apparence"] = GrotteJeu.apparence_humain(absi(hash(ident)) % 4, "casque_nasal" if int(c["b"]) == 1 else "")
	return o

func _go() -> void:
	_sortie = _arg("sortie", "user://armes_ennemis")
	DirAccess.make_dir_recursive_absolute(_sortie)
	var filtre := _arg("cas", "").split(",", false)
	var poses := _arg("poses", "garde,marche,coup").split(",", false)
	var mort := OS.get_cmdline_user_args().has("--mort")
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	var j: CharacterBody3D = m.joueur
	for i in 5:
		await physics_frame
	var t = m.tertre
	t._passer(true)
	for i in 1200:
		if t.dedans:
			break
		await process_frame
	await create_timer(1.6, true, false, true).timeout
	m.post.set_shader_parameter("fondu", 0.0)
	var c: Node3D = t.crypte
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	j.global_position = c.to_global(Vector3(0.0, 0.1, -22.5))
	if j.mains.get("torche_lumiere") != null:
		j.mains.torche_lumiere.visible = true
	for k in 20:
		t._gerer_zones()
		await physics_frame
	for id in m.draugrs.keys():
		var d = m.draugrs[id]
		if is_instance_valid(d):
			d.visible = false
			d.process_mode = Node.PROCESS_MODE_DISABLED
			d.global_position += Vector3(0, -50, 0)
	var tors := _arg("torsion", "")
	if tors != "":      # essai de réglage : torsion imposée à toutes les armes photographiées (jamais écrite dans les données)
		var pr: Dictionary = ArmesEnnemis.donnees().get("prises", {})
		for cas0: Array in CAS:
			var r: Dictionary = (pr.get(String(cas0[3]), {}) as Dictionary).duplicate()
			r["torsion"] = float(tors)
			pr[String(cas0[3])] = r
		ArmesEnnemis.donnees()["prises"] = pr
	var lacet := c.global_rotation.y
	var spot := c.to_global(Vector3(0.0, 0.05, -27.0))
	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.72, 0.45)
	lum.light_energy = 2.2
	lum.omni_range = 7.0
	root.add_child(lum)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	for cas: Array in CAS:
		if not filtre.is_empty() and not filtre.has(String(cas[0])):
			continue
		var e: CharacterBody3D = null
		var ident := ""
		for k in 400:
			ident = "ae_%s_%d" % [cas[1], k]
			var opts := _options(cas, ident)
			e = m.creer_draugr(String(cas[1]), spot, lacet, false, opts)
			var a := ArmesEnnemis.arme_de(e.modele)
			if a == String(cas[3]):
				break
			m.draugrs.erase(e.ident)
			e.queue_free()
			e = null
			await process_frame
		if e == null:
			print("CAS %s : arme %s introuvable" % [cas[0], cas[3]])
			continue
		e.global_position = spot
		await physics_frame
		e.set_physics_process(false)
		e.set_process(false)
		var mod: Node3D = e.modele
		var sq := mod.find_child("Skeleton3D", true, false) as Skeleton3D
		print("CAS %s : arme %s (%s) variante %s" % [cas[0], ArmesEnnemis.arme_de(mod), e.ident, mod.get_meta("variante", "-")])
		var ap: AnimationPlayer = e.anim
		for p: String in poses:
			var def: Array = POSES[p]
			ap.speed_scale = 1.0
			ap.play(String(def[0]), 0.0)
			ap.seek(ap.current_animation_length * float(def[1]), true)
			ap.speed_scale = 0.0
			for i in 4:
				await process_frame
			var main_d: Vector3 = sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin
			var arme_n := sq.get_node_or_null("Arme/" + (sq.get_node("Arme").get_child(0).name if sq.get_node_or_null("Arme") != null else "")) as Node3D
			var centre_arme := main_d
			if arme_n != null:
				var pr := arme_n.get_node_or_null("prise") as Node3D
				var po := arme_n.get_node_or_null("pointe") as Node3D
				if pr != null and po != null:
					var v := po.global_position - pr.global_position
					centre_arme = (po.global_position + pr.global_position) * 0.5
					print("ARME %s %s : élévation %.0f° au-dessus de l'horizontale (+ = tête en haut), longueur %.2f m" % [cas[0], p, rad_to_deg(asin(v.y / maxf(v.length(), 0.001))), v.length()])
			for vue: String in VUES:
				var dir := Basis(Vector3.UP, lacet + deg_to_rad(float(VUES[vue]))) * Vector3(0, 0, 1)
				cam.fov = 40.0
				cam.global_position = e.global_position + dir * 2.7 + Vector3(0, 1.2, 0)
				cam.look_at(e.global_position + Vector3(0, 0.95, 0))
				lum.global_position = e.global_position + dir * 2.0 + Vector3(0.6, 1.9, 0)
				await _photo(_sortie.path_join("%s__%s_%s.png" % [cas[0], p, vue]))
			# gros plans : l'arme entière (face, côté) puis la main droite et la prise (face, côté ; « côté » = côté droit du personnage)
			for vue2: String in ["arme_face", "arme_cote", "main_face", "main_cote"]:
				var cote := vue2.ends_with("cote")
				var a2 := lacet + deg_to_rad(-80.0 if cote else 15.0)
				var dir2 := Basis(Vector3.UP, a2) * Vector3(0, 0, 1)
				cam.fov = 30.0
				var gros := vue2.begins_with("main")
				var cible_c := main_d if gros else (main_d + centre_arme) * 0.5
				cam.global_position = cible_c + dir2 * (1.0 if gros else 2.3) + Vector3(0, 0.15, 0)
				cam.look_at(cible_c)
				lum.global_position = cible_c + dir2 * 1.0 + Vector3(0.4, 0.8, 0)
				await _photo(_sortie.path_join("%s__%s_%s.png" % [cas[0], p, vue2]))
		if mort:
			# mort : le coup fatal, puis (3,5 s plus tard) l'arme au sol : de dessus, de côté bas, et plan large avec le corps
			e.set_process(true)
			e.set_physics_process(true)
			e.vie = 1.0
			e.recevoir_coup(50.0, e.global_position + Vector3(0, 0, 2.0))
			await create_timer(3.5, true, false, true).timeout
			var butin: Node3D = null
			for b in get_nodes_in_group("corps_butin"):
				butin = b
			var sol := butin.get_node_or_null(ArmesEnnemis.SOL) as Node3D if butin != null else null
			if sol == null:
				print("MORT %s : pas d'arme au sol (jarl : arme unique)" % cas[0])
			else:
				var pa := sol.global_position
				var boite := AABB()
				var premier := true
				for mi: MeshInstance3D in sol.find_children("*", "MeshInstance3D", true, false):
					var bb := mi.global_transform * mi.get_aabb()
					boite = bb if premier else boite.merge(bb)
					premier = false
				print("MORT %s : arme %s au sol à %.2f m du corps, hauteur du sol %.3f, épaisseur %.2f m, longueur %.2f m" % [cas[0], butin.get_meta("arme_sol"), pa.distance_to(e.global_position), pa.y - m.hauteur(pa.x, pa.z), boite.size.y, maxf(boite.size.x, boite.size.z)])
				lum.global_position = pa + Vector3(0.5, 1.6, 0.6)
				cam.fov = 40.0
				cam.global_position = pa + Vector3(0.3, 1.5, 0.9)
				cam.look_at(pa)
				await _photo(_sortie.path_join("%s__mort_dessus.png" % cas[0]))
				cam.global_position = pa + Vector3(0.0, 0.35, 1.4)
				cam.look_at(pa + Vector3(0, 0.05, 0))
				await _photo(_sortie.path_join("%s__mort_cote.png" % cas[0]))
				var cc: Vector3 = butin.global_position
				cam.fov = 45.0
				cam.global_position = (cc + pa) * 0.5 + Vector3(1.8, 1.9, 2.4)
				cam.look_at((cc + pa) * 0.5)
				await _photo(_sortie.path_join("%s__mort_large.png" % cas[0]))
			for b in get_nodes_in_group("corps_butin"):
				(b as Node).queue_free()
		m.draugrs.erase(e.ident)
		e.queue_free()
		await process_frame
	print("FIN")
	quit(0)
