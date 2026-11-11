extends SceneTree
## Test « cadavres debout » (bug 2026-11-11) : chaque type de draugr est tué, on mesure la hauteur de la tête et du bassin au-dessus du terrain
## 3 s et 10 s après la mort (ragdoll), puis on pose la DÉPOUILLE STATIQUE du même type (Butin.modele_depouille : plafond de cadavres,
## partie rechargée) et on la mesure aussi. Un corps « couché » a la tête à moins de 0,6 m du sol.
## Cause du bug : la dépouille statique, bâtie hors de l'arbre, gardait des poses globales périmées (corps Tripo à l'épée, jarl :
## DEBOUT en pose de repos) — corrigé par Draugr.figer_pose_allongee.
##   godot --headless --path . --script res://outils/test_cadavres_couches.gd -- --nouvelle
##   godot --path . --script res://outils/test_cadavres_couches.gd -- --nouvelle --sortie=<dossier>   (captures, fenêtre hors écran)
const SCENE := preload("res://scenes/foret_test.tscn")
const BUTIN := preload("res://scripts/butin.gd")
const TYPES := [
	["kaykit_guerrier", "guerrier", {"modele_ancien": true}],
	["tripo_guerrier", "guerrier", {}],
	["tripo_archer", "guerrier", {"archer": true}],
	["tripo_squelette", "squelette", {}],
	["ancien_squelette", "squelette", {"modele_ancien": true}],
	["jarl_kolbeinn", "guerrier", {"boss": "jarl", "ident": "jarl_diag"}],
	["endormi_allonge", "guerrier", {"dort": true}],
	["gardien_debout", "guerrier", {"dort": true, "debout": true}],
]

var m: Node3D
var sortie := ""
var _cam: Camera3D
var _echecs := 0

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	_go.call_deferred()

func _att(modele: Node3D, os_nom: String) -> Node3D:
	var sq: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	if sq == null or sq.find_bone(os_nom) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = os_nom
	sq.add_child(ba)
	return ba

func _h(n: Node3D) -> float:
	if n == null or not is_instance_valid(n):
		return -99.0
	var p := n.global_position
	return p.y - m.hauteur(p.x, p.z)

func _capturer(nom: String, cible: Vector3) -> void:
	if sortie == "":
		return
	var depuis := cible + Vector3(2.2, 1.3, 2.2)
	_cam.global_position = depuis
	_cam.look_at(cible + Vector3(0, 0.4, 0))
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(sortie)
	img.save_png(sortie.path_join(nom + ".png"))

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await process_frame
	m.joueur.global_position = Vector3(60, m.hauteur(60, 60) + 1.0, 60)
	_cam = Camera3D.new()
	root.add_child(_cam)
	_cam.current = true
	var corps := []
	var i := 0
	for t: Array in TYPES:
		var x := -6.0 + 4.0 * i
		var z := 10.0
		var opts: Dictionary = (t[2] as Dictionary).duplicate()
		var dort := bool(opts.get("dort", false))
		opts.erase("dort")
		opts["vie_imposee"] = 10.0
		var d: CharacterBody3D = m.creer_draugr(t[1], Vector3(x, m.hauteur(x, z) + 0.05, z), 0.0, dort, opts)
		corps.append({"nom": t[0], "d": d, "type": t[1], "opts": t[2]})
		i += 1
	for k in 40:
		await physics_frame
	for c: Dictionary in corps:
		var d: CharacterBody3D = c["d"]
		c["tete"] = _att(d.modele, "Head")
		c["bassin"] = _att(d.modele, "pelvis")
		c["variante"] = String(d.modele.get_meta("variante", "?"))
	await process_frame
	for c: Dictionary in corps:
		print("AVANT  %-18s variante=%s tete=%.2f bassin=%.2f" % [c["nom"], c["variante"], _h(c["tete"]), _h(c["bassin"])])
	for c: Dictionary in corps:
		var d: CharacterBody3D = c["d"]
		d._mourir(d.global_position + Vector3(-1.5, 0, 0), 20.0, false)
	var temps := 0.0
	for jalon: float in [3.0, 10.0]:
		while temps < jalon:
			await physics_frame
			temps += 1.0 / Engine.physics_ticks_per_second
		for c: Dictionary in corps:
			var d: CharacterBody3D = c["d"]
			var rd: Ragdoll = d._ragdoll if is_instance_valid(d) else null
			var ht := _h(c["tete"])
			print("MORT+%ds %-18s tete=%.2f bassin=%.2f ragdoll=%s os=%d actif=%s fige=%s anim=%s %s" % [int(jalon), c["nom"], ht, _h(c["bassin"]),
				rd != null, rd.os.size() if rd else 0, rd.actif if rd else false, rd.est_fige() if rd else false,
				d.anim.current_animation if is_instance_valid(d) and d.anim else "?", "COUCHE" if ht < 0.6 else "DEBOUT/HAUT"])
			_verif(ht < 0.6 and _h(c["bassin"]) < 0.5 and ht > -0.1, "%s : couché %d s après la mort (ragdoll)" % [c["nom"], int(jalon)])
			if jalon >= 10.0:
				_verif(rd != null and rd.est_fige(), "%s : corps figé à 10 s" % c["nom"])
			if is_instance_valid(c["tete"]):
				await _capturer("%s_%ds" % [c["nom"], int(jalon)], (c["bassin"] as Node3D).global_position)
	# dépouilles statiques (plafond de cadavres / partie rechargée)
	i = 0
	for c: Dictionary in corps:
		var d: CharacterBody3D = c["d"]
		var b := Node3D.new()
		m.add_child(b)
		var x := -6.0 + 4.0 * i
		var z := 18.0
		b.global_position = Vector3(x, m.hauteur(x, z), z)
		var dep: Node3D = BUTIN.modele_depouille(d.spec_depouille())
		b.add_child(dep)
		c["dep"] = dep
		c["dtete"] = _att(dep, "Head")
		c["dbassin"] = _att(dep, "pelvis")
		i += 1
	for k in 20:
		await process_frame
	for c: Dictionary in corps:
		var ht := _h(c["dtete"])
		var ap := (c["dep"] as Node).get_node_or_null("Animations") as AnimationPlayer
		print("DEPOUILLE %-18s tete=%.2f bassin=%.2f death01=%s %s" % [c["nom"], ht, _h(c["dbassin"]), ap != null and ap.has_animation("Death01"), "COUCHE" if ht < 0.6 else "DEBOUT/HAUT"])
		_verif(ht < 0.6 and ht > -0.15, "%s : dépouille statique couchée" % c["nom"])
		if ap:
			var sqd: Skeleton3D = (c["dep"] as Node).find_child("Skeleton3D", true, false)
			var ip := sqd.find_bone("pelvis")
			print("    ap: anim=%s pos=%.2f playing=%s active=%s root=%s lib=%s pelvis_pose=%s rest=%s mods=%s" % [ap.current_animation, ap.current_animation_position if ap.current_animation != "" else -1.0, ap.is_playing(), ap.active, ap.root_node, ap.get_animation_library_list(), sqd.get_bone_pose_position(ip), sqd.get_bone_rest(ip).origin, sqd.get_children().map(func(n): return n.name)])
		await _capturer("%s_depouille" % c["nom"], (c["dbassin"] as Node3D).global_position if c["dbassin"] else (c["dep"] as Node3D).global_position)
	print("TEST CADAVRES COUCHES : ", "OK" if _echecs == 0 else "ÉCHEC (%d)" % _echecs)
	quit(1 if _echecs > 0 else 0)
