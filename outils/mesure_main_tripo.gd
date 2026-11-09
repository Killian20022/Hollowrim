extends SceneTree
## Gantelet droit du maillage Tripo, dans le repère de chaque os PORTEUR (poses de liaison du skin, indépendantes de la pose) :
## pour chaque os de l'avant-bras / main droite : nombre de sommets dominants, centre et boîte dans le repère de l'os.
##   godot --headless --path . --script res://outils/mesure_main_tripo.gd
func _init() -> void:
	var h: Node3D = (GardeTripo.MODELES["tripo_garde_epee"] as PackedScene).instantiate()
	root.add_child(h)
	var sq: Skeleton3D = h.find_child("Skeleton3D", true, false)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if mi.skin == null:
			continue
		var res := {}
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var k := b.size() / maxi(v.size(), 1)
			for i in v.size():
				var best := -1
				var bw := 0.0
				for q in k:
					if w[i * k + q] > bw:
						bw = w[i * k + q]
						best = b[i * k + q]
				var nom := mi.skin.get_bind_name(best)
				if nom == "":
					nom = sq.get_bone_name(mi.skin.get_bind_bone(best))
				if not (nom.ends_with("_r") and (nom.begins_with("hand") or nom.begins_with("lowerarm") or nom.begins_with("index") or nom.begins_with("middle") or nom.begins_with("pinky") or nom.begins_with("ring") or nom.begins_with("thumb"))):
					continue
				var l: Vector3 = mi.skin.get_bind_pose(best) * v[i]
				if not res.has(nom):
					res[nom] = [0, Vector3.ZERO, Vector3(1e9, 1e9, 1e9), Vector3(-1e9, -1e9, -1e9)]
				var r: Array = res[nom]
				r[0] += 1
				r[1] += l
				r[2] = (r[2] as Vector3).min(l)
				r[3] = (r[3] as Vector3).max(l)
		for nom in res:
			var r: Array = res[nom]
			print(mi.name, " ", nom, " n=", r[0], " centre ", (r[1] as Vector3) / float(r[0]), " min ", r[2], " max ", r[3])
	quit()
