extends SceneTree
## Test headless des habitants anonymes (retours6/pnj) : godot --headless -s res://outils/test_habitants_pnj.gd
## Chaque habitant de data/habitants.json pointe une variante de PnjNordique.HABITANTS ; chaque variante est un archétype validé
## (65 os, clips du gameplay et de l'activité du poste, budget de triangles, Ragdoll et PiedsAuSol équipables, visage peint) et les
## variantes se distinguent (matériaux ou teinte de cheveux différents).
const CLIPS := ["Idle", "Walk", "Idle_Talking", "Fixing_Kneeling", "Death01", "Sword_Idle", "Interact", "Jog_Fwd"]
var _echecs := 0
func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1
func _initialize() -> void:
	_lancer.call_deferred()
## Empreinte visuelle : teinte des cheveux + identifiants des textures de toutes les pièces visibles.
func _empreinte(n: Node3D) -> String:
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var e := []
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var m: Material = mi.material_override
		if m == null and mi.mesh.get_surface_count() > 0:
			m = mi.get_surface_override_material(0) if mi.get_surface_override_material(0) else mi.mesh.surface_get_material(0)
		if m is ShaderMaterial:
			var t: Variant = (m as ShaderMaterial).get_shader_parameter("tex_base")
			e.append("%s:%s:%s" % [mi.name, str((m as ShaderMaterial).get_shader_parameter("teinte")), str(t.get_rid().get_id()) if t is Texture2D else ""])
	return "|".join(e)
func _lancer() -> void:
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/habitants.json"))
	var utilises := {}
	for h: Dictionary in (json as Dictionary)["habitants"]:
		var v := String(h.get("pnj", ""))
		_verif(PnjNordique.HABITANTS.has(v), "%s : variante « %s » connue" % [h["id"], v])
		_verif(not utilises.has(v), "%s : variante non partagée avec un autre habitant" % h["id"])
		utilises[v] = true
	var empreintes := {}
	for id: String in PnjNordique.HABITANTS:
		var n := PnjNordique.creer(id)
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := n.get_node_or_null("Animations") as AnimationPlayer
		_verif(sq != null and ap != null, "%s : Skeleton3D + Animations" % id)
		if sq == null or ap == null:
			continue
		_verif(n.get_meta("pnj_nordique", "") == id, "%s : méta pnj_nordique" % id)
		_verif(sq.get_bone_count() == 65, "%s : 65 os (%d)" % [id, sq.get_bone_count()])
		var manque := []
		for a in CLIPS:
			if not ap.has_animation(a):
				manque.append(a)
		_verif(manque.is_empty(), "%s : clips %s" % [id, str(manque)])
		var tris := 0
		var surfaces := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			for s in mi.mesh.get_surface_count():
				surfaces += 1
				tris += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
		_verif(tris > 3000 and tris <= 8000, "%s : %d triangles (budget 8000)" % [id, tris])
		_verif(surfaces <= 12, "%s : %d surfaces visibles (<= 12)" % [id, surfaces])
		_verif(sq.find_bone("Head") >= 0 and sq.find_bone("foot_l") >= 0, "%s : os Head / foot_l" % id)
		_verif(sq.get_node_or_null("peau") != null and (sq.get_node_or_null("peau") as MeshInstance3D).visible, "%s : peau (visage peint) visible" % id)
		_verif(PiedsAuSol.equiper(n, null) != null, "%s : PiedsAuSol équipable" % id)
		var emp := _empreinte(n)
		_verif(not empreintes.has(emp), "%s : apparence distincte des autres variantes" % id)
		empreintes[emp] = id
		n.queue_free()
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
