extends SceneTree
## Non-régression de l'opti « pièces vides » (ArmureVisible._cacher_si_vide) : chaque garde de data/gardes.json est bâti deux fois (opti coupée
## puis active) ; toute pièce cachée par l'opti doit être SANS AIRE, et toute pièce visible avant doit l'être après (sinon ECHEC).
##   godot --headless --path . --script res://outils/test_pieces_vides.gd
func _init() -> void:
	_go.call_deferred()

func _tris(mi: MeshInstance3D) -> int:
	var n := 0
	if mi.mesh == null:
		return 0
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for t in range(0, ix.size() - 2, 3):
			if not (ix[t] == ix[t + 1] and ix[t] == ix[t + 2]):
				n += 1
	return n

func _etat(n: Node3D) -> Dictionary:
	var d := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		d[String(n.get_path_to(mi))] = [mi.is_visible_in_tree(), _tris(mi)]
	return d

func _go() -> void:
	var gardes: Array = GardesVillage.donnees().get("gardes", [])
	var ech := 0
	var cachees := 0
	for g: Dictionary in gardes:
		if not GardeMaison.actif(g):
			continue
		var res := []
		for opti in [false, true]:
			ArmureVisible.opti_vides = opti
			var n: Node3D = GardesVillage.creer_modele(g)
			root.add_child(n)
			res.append(_etat(n))
			n.queue_free()
		for k in res[0]:
			var a: Array = res[0][k]
			var b: Array = res[1].get(k, [false, 0])
			if a[0] and not b[0]:
				cachees += 1
				if int(a[1]) > 0:
					ech += 1
					print("ECHEC %s : %s cachée alors qu'elle a %d triangles" % [g.get("nom", g.get("id", "?")), k, a[1]])
			elif a[0] != b[0]:
				ech += 1
				print("ECHEC %s : %s visible %s -> %s" % [g.get("nom", "?"), k, a[0], b[0]])
	print("TEST_PIECES_VIDES %s : %d pièces vides cachées, %d erreurs" % ["OK" if ech == 0 else "ECHEC", cachees, ech])
	quit(0 if ech == 0 else 1)
