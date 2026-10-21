extends SceneTree
## Test des personnages « base unifiee » : fabrique, squelette (RIG18 + os secondaires <= 26), budgets de triangles, animations existantes, atlas,
## ressorts (la cape ne traverse jamais le dos ni le bassin pendant une course). Sans fenetre : godot --headless --script res://outils/test_persos_base.gd -- --nouvelle
const BUDGET_CORPS := 800          # corps + bagues (v2 : 780 = jambes galbees + bottes a bout rond ; v1 : 748)
const BUDGET_TOTAL := 1500         # le variant le plus charge (corps + tete + coiffure + barbe + accessoires)
const ANIMS := ["Idle", "Walk", "Sprint", "Sword_Attack", "Sword_Idle", "Fixing_Kneeling", "Interact", "Idle_Talking", "Death01"]
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _tris(mi: MeshInstance3D) -> int:
	var n := 0
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		n += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var rig := FileAccess.get_file_as_string("res://sources_blender/rig18.txt").split("\n", false)
	var defs := PersoDefs.toutes()
	for nom: String in defs:
		var def: PersoDef = defs[nom]
		var t0 := Time.get_ticks_usec()
		var m := Personnage.creer(def)
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		root.add_child(m)
		var sq := m.find_child("Skeleton3D", true, false) as Skeleton3D
		ok(sq != null and m.has_node("Animations"), "%s : squelette et AnimationPlayer (creer %.1f ms)" % [nom, dt])
		ok(sq.get_bone_count() <= 26, "%s : %d os (<= 26)" % [nom, sq.get_bone_count()])
		var manque := []
		for o: String in rig:
			if sq.find_bone(o.strip_edges()) < 0:
				manque.append(o)
		ok(manque.is_empty(), "%s : les %d os de rig18.txt existent %s" % [nom, rig.size(), manque])
		var corps := 0
		var total := 0
		var sans_mat := 0
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
			var t := _tris(mi)
			total += t
			if mi.name in ["corps", "bagues"]:
				corps += t
			if mi.material_override == null:
				sans_mat += 1
		ok(corps <= BUDGET_CORPS, "%s : corps + bagues = %d triangles (<= %d)" % [nom, corps, BUDGET_CORPS])
		ok(total <= BUDGET_TOTAL, "%s : variante complete = %d triangles (<= %d)" % [nom, total, BUDGET_TOTAL])
		ok(sans_mat == 0, "%s : toutes les pieces ont le materiau partage" % nom)
		m.queue_free()
	# materiaux partages : 2 par morphologie, pas un par PNJ
	var avant := Palette.materiaux.size()
	for i in 5:
		root.add_child(Personnage.creer(PersoDefs.villageois("chef")))
	ok(Palette.materiaux.size() == avant, "5 PNJ de plus : 0 materiau cree (%d -> %d)" % [avant, Palette.materiaux.size()])
	# animations : toutes les pistes d'os existent (hors doigts et orteils retires de RIG18)
	var m2 := Personnage.creer(PersoDefs.joueur())
	root.add_child(m2)
	var ap: AnimationPlayer = m2.get_node("Animations")
	var sq2 := m2.find_child("Skeleton3D", true, false) as Skeleton3D
	for a in ANIMS:
		if not ap.has_animation(a):
			ok(false, "animation absente : " + a)
			continue
		var anim := ap.get_animation(a)
		var pistes := 0
		var absentes := 0
		for i in anim.get_track_count():
			var chemin := String(anim.track_get_path(i))
			var os := chemin.get_slice(":", 1)
			pistes += 1
			if sq2.find_bone(os) < 0 and not (os.begins_with("thumb") or os.begins_with("index") or os.begins_with("middle") or os.begins_with("ring") or os.begins_with("pinky") or os.begins_with("ball")):
				absentes += 1
		ok(absentes == 0, "animation %s : %d pistes, %d os absents hors doigts/orteils" % [a, pistes, absentes])
	# atlas
	for sexe in ["homme", "femme"]:
		var tex := PersoAtlas.texture(sexe)
		ok(tex.get_width() == 256 and tex.get_height() == 256, "atlas %s : %dx%d, densite %.0f texels/m" % [sexe, tex.get_width(), tex.get_height(), PersoAtlas.densite(sexe)])
	m2.queue_free()
	await _ressorts()
	print("ECHECS : %d" % echecs if echecs > 0 else "TEST PERSOS BASE : OK")
	quit(echecs)

## Course d'une volva (robe + cape longue + capuche) : les os de cape restent hors du dos et du bassin (collisions des ressorts).
func _ressorts() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	scene.add_child(env)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 1.5, 4)
	var m := Personnage.creer(PersoDefs.villageois("volva"))
	scene.add_child(m)
	var ap: AnimationPlayer = m.get_node("Animations")
	ap.play("Sprint")
	var sq := m.find_child("Skeleton3D", true, false) as Skeleton3D
	var attaches := {}
	for n in ["cape_1", "cape_2", "spine_01", "spine_03", "pelvis", "pan_av_1", "thigh_l", "thigh_r"]:
		var ba := BoneAttachment3D.new()
		ba.bone_name = n
		sq.add_child(ba)
		attaches[n] = ba
	var pire_dos := 9.0
	var pire_cuisse := 9.0
	var vit := 4.5
	for i in 240:
		m.position.z += vit / 60.0
		await process_frame
		if i < 60:
			continue
		# distance de l'articulation de cape (cape_2) a l'axe du dos (spine_01 -> spine_03)
		var a: Vector3 = attaches["spine_01"].global_position
		var b: Vector3 = attaches["spine_03"].global_position
		var p: Vector3 = attaches["cape_2"].global_position
		var proche := Geometry3D.get_closest_point_to_segment(p, a, b)
		pire_dos = minf(pire_dos, p.distance_to(proche))
		var pp: Vector3 = attaches["pan_av_1"].global_position
		for c in ["thigh_l", "thigh_r"]:
			pire_cuisse = minf(pire_cuisse, pp.distance_to(attaches[c].global_position))
	ok(pire_dos > 0.10, "course : l'os de cape reste a %.3f m de l'axe du dos (capsule 0.15, tolerance >= 0.10)" % pire_dos)
	ok(pire_cuisse > 0.04, "course : le pan avant reste a %.3f m des hanches" % pire_cuisse)
	scene.queue_free()
