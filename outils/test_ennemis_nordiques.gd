extends SceneTree
## Test du lot ENNEMIS (pnj/ennemis) : chaque variante d'EnnemisNordiques est créée, du bon archétype, avec 65 os, les clips
## de l'IA (marche, attaque, visée, tir, appel, mort), un ragdoll de 16 os et un budget de triangles ; l'arme est posée ;
## les matériaux clonés (teinte) gardent le shader PS1 à accroche ; l'interrupteur --pnj-anciens rend null.
##   godot --headless --path . --script res://outils/test_ennemis_nordiques.gd -- --nouvelle
const ANIMS := ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "Punch_Cross", "Hit_Chest", "Hit_Head", "Death01", "Pistol_Aim_Neutral", "Pistol_Shoot", "Spell_Simple_Shoot", "Spell_Simple_Enter", "Interact"]
const BUDGET := 9000
const GJ := preload("res://scripts/grotte_jeu.gd")
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _draugr_app(guerrier: bool) -> Dictionary:
	var app := {"corps": "homme", "draugr": true, "tenue": {"haillons": Color.WHITE}}
	if guerrier:
		app["casque"] = "casque_draugr"
	return app

func _lancer() -> void:
	var cas := [
		["draugr épée", {"type": "guerrier", "ident": "guerrier_0", "apparence": _draugr_app(true)}, "draugr_nordique"],
		["draugr sbire", {"type": "sbire", "ident": "sbire_1", "apparence": _draugr_app(false)}, "draugr_nordique"],
		["draugr sbire 2", {"type": "sbire", "ident": "sbire_7", "apparence": _draugr_app(false)}, "draugr_nordique"],
		["draugr archer", {"type": "sbire", "archer": true, "ident": "sbire_2", "apparence": _draugr_app(false)}, "draugr_nordique"],
		["draugr patrouille", {"type": "guerrier", "ident": "guerrier_9", "apparence": _draugr_app(true)}, "draugr_nordique"],
		["bandit 0", {"type": "sbire", "ident": "g_b0", "apparence": GJ.apparence_humain(0)}, "guerrier_nordique"],
		["bandit 1", {"type": "sbire", "ident": "g_b1", "apparence": GJ.apparence_humain(1)}, "guerrier_nordique"],
		["bandit 2", {"type": "sbire", "ident": "g_b2", "apparence": GJ.apparence_humain(2)}, "guerrier_nordique"],
		["archer bandit", {"type": "sbire", "archer": true, "ident": "g_a3", "apparence": GJ.apparence_humain(3)}, "chasseresse_nordique"],
		["Hrafn", {"type": "sbire", "boss": "hrafn", "ident": "hrafn", "apparence": GJ.apparence_humain(4)}, "guerrier_nordique"],
		["Svanhild", {"type": "guerrier", "boss": "svanhild", "ident": "svanhild", "apparence": _draugr_app(true)}, "draugr_nordique"],
		["jarl gelé", {"type": "guerrier", "boss": "jarl", "ident": "jarl", "apparence": _draugr_app(true)}, "draugr_nordique"],
	]
	var variantes := {}
	for c: Array in cas:
		var t0 := Time.get_ticks_usec()
		var n := EnnemisNordiques.creer(c[1])
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		ok(n != null, "%s : créé (%.0f ms)" % [c[0], ms])
		if n == null:
			continue
		root.add_child(n)
		ok(n.has_meta(c[2]), "%s : archétype %s" % [c[0], c[2]])
		ok(n.has_meta("armes_nordiques"), "%s : arme déjà posée (méta armes_nordiques)" % c[0])
		variantes[n.get_meta("variante")] = true
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		ok(sq != null and sq.get_bone_count() == 65, "%s : 65 os" % c[0])
		var ap := n.get_node_or_null("Animations") as AnimationPlayer
		var manque := []
		for a in ANIMS:
			if ap == null or not ap.has_animation(a):
				manque.append(a)
		ok(manque.is_empty(), "%s : clips de l'IA présents %s" % [c[0], str(manque)])
		var tr := _tris(n)
		ok(tr <= BUDGET, "%s : %d triangles (budget %d)" % [c[0], tr, BUDGET])
		var grilles := 0
		var total := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_surface_override_material(s)
				if m == null:
					m = mi.material_override
				if m == null:
					m = mi.mesh.surface_get_material(s)
				if m is ShaderMaterial:
					total += 1
					if (m as ShaderMaterial).get_shader_parameter("grille") != null:
						grilles += 1
		ok(grilles == total, "%s : %d/%d surfaces au shader PS1 à accroche" % [c[0], grilles, total])
		# ragdoll
		var rd := Ragdoll.equiper(n) as Ragdoll
		ok(rd != null and rd.os.size() == 16, "%s : ragdoll %d os" % [c[0], rd.os.size() if rd else 0])
		if c[2] == "chasseresse_nordique" or c[1].get("archer", false):
			ap.play("Pistol_Aim_Neutral")
			ap.seek(0.3, true)
			var main := EnnemisNordiques.main_de_tir(n)
			ok(main != Vector3.INF and main.y > 0.8 and main.y < 2.0, "%s : la flèche part de la main (hand_l à y=%.2f)" % [c[0], main.y])
	ok(variantes.size() >= 10, "variantes distinctes : %d" % variantes.size())
	ok(not EnnemisNordiques.anciens(), "--pnj-anciens absent : nouveaux corps")
	print("TEST ENNEMIS NORDIQUES : %s (%d échecs)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
