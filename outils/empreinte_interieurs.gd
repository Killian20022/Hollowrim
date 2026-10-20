extends SceneTree
## Empreinte des intérieurs construits (maillages, lumières, collisions) : à lancer sur deux versions et comparer les lignes.
##   godot --headless --path . --script res://outils/empreinte_interieurs.gd -- --nouvelle
## (en headless les RenderingServer sont factices : on lit les tableaux de sommets gardés par ArrayMesh, jamais le rendu.)
var monde: Node3D

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	var v: Node3D = monde.village
	for i in 3000:
		if v.prets:
			break
		await process_frame
	print("EMP prets=%s" % v.prets)
	for ip in v.interieurs:
		var h := 0.0
		var nv := 0
		var nm := 0
		for mi in ip.racine.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh as ArrayMesh
			if m == null:
				continue
			nm += 1
			for s in m.get_surface_count():
				var a := m.surface_get_arrays(s)
				var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				nv += pv.size()
				for p in pv:                             # sommes : indépendantes de l'ordre des maillages
					h += p.x + p.y * 2.0 + p.z * 3.0
				for u in (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
					h += u.x * 5.0 + u.y * 7.0
				for c in (a[Mesh.ARRAY_COLOR] as PackedColorArray):
					h += c.r + c.g + c.b
		var mm: int = ip.racine.find_children("*", "MultiMeshInstance3D", true, false).size()
		var nl: int = ip.lumieres.size()
		var e := 0.0
		for l in ip.lumieres:
			e += (l[1] as float) + (l[0] as OmniLight3D).omni_range + (l[0] as OmniLight3D).position.x
		print("EMP %s maillages=%d sommets=%d somme=%.2f multimesh=%d lumieres=%d somme_lum=%.3f" % [ip.nom, nm, nv, h, mm, nl, e])
	var nc := 0
	var sc := 0.0
	for c in v.corps.get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		nc += 1
		sc += cs.position.x * 1.0 + cs.position.y * 3.0 + cs.position.z * 7.0 + cs.shape.get_debug_mesh().get_faces().size() * 0.001
	print("EMP collisions=%d signature=%.3f" % [nc, sc])
	quit()
