extends SceneTree
## Film d'un ennemi Tripo EN SITUATION dans la vraie crypte (foret_test) : il est posé devant la caméra du joueur (invulnérable, caché), reste immobile
## (Idle), marche vers lui, l'attaque, puis est abattu (mort). IA et animations du jeu, rien de truqué.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_ennemis_tripo.gd -- --ennemis-tripo --nouvelle --cible=draugr|archer|squelette|gobelin [--sortie=<dossier>]
## Affiche « PLAN nom image » pour chaque étape ; photo fixe <sortie>/<cible>_milieu.png au milieu de l'attaque.
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var j: CharacterBody3D
var img := 0

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _pf() -> void:
	img += 1
	j.vie = j.vie_max
	j.esquive_t = 0.0      # fenêtre d'invulnérabilité de l'esquive : aucun coup ne touche (pas de voile rouge)
	await process_frame

func _att(sec: float) -> void:
	for i in roundi(sec * 30.0):
		await _pf()

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://film"))
	Effets.niveau_force = 1
	Sang.niveau_force = 2
	RetourImpact.muet = true
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	j = m.joueur
	for i in 5:
		await physics_frame
	var t = m.tertre
	t._passer(true)      # entrée normale dans la crypte (fondu), comme le joueur
	await create_timer(1.6, true, false, true).timeout
	var c: Node3D = t.crypte
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	for n in j.camera.get_children():
		if n is Node3D:
			n.visible = false
	j.camera.fov = 52.0
	var pos: Vector3 = c.to_global(Vector3(0.0, 0.05, -27.0))       # couloir large du vestibule : sol plat, rien devant
	var face := Basis(Vector3.UP, c.global_rotation.y).z
	j.global_position = c.to_global(Vector3(0.0, 0.1, -22.5))
	j.velocity = Vector3.ZERO
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
	var cible := _arg("cible", "draugr")
	var type := "guerrier"
	var opts := {"ident": "film_" + cible, "dort": false}
	match cible:
		"squelette":
			type = "squelette"
		"archer":
			type = "sbire"
			opts["archer"] = true
		"gobelin":
			type = "gobelin"
	var lacet := c.global_rotation.y
	var spot := pos
	var e = m.creer_draugr(type, spot, lacet, false, opts)
	e.global_position = spot
	e.rotation.y = lacet
	j.global_position = c.to_global(Vector3(0.0, 0.1, -27.0 + float(_arg("dist", "4.5"))))
	await _att(0.3)
	print("DEBUG crypte %s joueur %s ennemi %s pos %s dedans %s vis %s" % [c.global_position, j.global_position, e.global_position, pos, t.dedans, c.visible])
	e.set_physics_process(true)
	var viser := func() -> void:
		var v: Vector3 = e.global_position - j.global_position
		j.rotation.y = atan2(-v.x, -v.z)
		j.tete.rotation.x = clampf(atan2(e.global_position.y + 1.0 * e.echelle - (j.global_position.y + 1.6), maxf(Vector2(v.x, v.z).length(), 0.1)), -0.5, 0.5)
		j.velocity = Vector3.ZERO
		var plat := Vector2(v.x, v.z)
		if cible == "archer" and plat.length() > 0.0 and e.vivant():      # l'archer recule pour tirer : on le garde sur place (il bande l'arc et tire)
			e.global_position = Vector3(spot.x, e.global_position.y, spot.z)
			e.velocity = Vector3.ZERO
	e.etat = e.GARDE
	e.anim.play("Sword_Idle" if cible != "archer" else "Idle", 0.0)
	print("DEBUT %d" % Engine.get_frames_drawn())
	print("PLAN idle %d" % img)
	for i in 75:
		viser.call()
		await _pf()
	print("PLAN approche_attaque %d" % img)
	e.alerter()
	var mi_pris := false
	for i in 210:
		viser.call()
		if not mi_pris and i > 120 and String(e._anim).contains("Attack"):
			mi_pris = true
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(_arg("sortie", "user://film").path_join(cible + "_attaque.png"))
		await _pf()
	print("PLAN mort %d" % img)
	var c0: Vector3 = e.global_position + Vector3(0, float(e.combat.hauteur) * 0.6, 0)
	var dirj: Vector3 = (c0 - j.global_position).normalized()
	var info := {"type": "tranchant", "point": c0 - dirj * 0.25, "direction": j.global_transform.basis.x, "normale": -dirj, "zone": "torse",
		"attaque": "legere", "arme": j.mains.arme.id, "stagger": DegatsCombat.stagger(j.mains.arme, "legere"), "collider": e}
	e.vie = 1.0
	DegatsCombat.appliquer(e, 999.0, j.global_position, true, info)
	for i in 100:
		viser.call()
		await _pf()
	print("FIN %d" % img)
	quit(0)
