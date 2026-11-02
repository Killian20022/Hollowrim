extends SceneTree
## Exporte les maillages VISIBLES du héros (HerosSkarnholt, pose de repos, repère Godot : y haut, z devant) en OBJ pour Blender :
## sources_blender/armures/heros/<maillage>.obj (accessoires : une surface par fichier). Sert de surface de collision / d'ajustement
## aux armures portées (sources_blender/armures/*/gen_*.py).
##   godot --headless --path . --script res://outils/exporter_heros_obj.gd -- --nouvelle
func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var h := HerosSkarnholt.creer({})
	root.add_child(h)
	var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var dossier := ProjectSettings.globalize_path("res://sources_blender/armures/heros")
	DirAccess.make_dir_recursive_absolute(dossier)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for i in v.size():
					idx.append(i)
			var nom := String(mi.name) + ("_%d" % s if mi.mesh.get_surface_count() > 1 else "")
			var f := FileAccess.open(dossier + "/" + nom + ".obj", FileAccess.WRITE)
			for p in v:
				f.store_line("v %.5f %.5f %.5f" % [p.x, p.y, p.z])
			for t in uv:
				f.store_line("vt %.5f %.5f" % [t.x, t.y])
			for t in range(0, idx.size(), 3):
				if uv.is_empty():
					f.store_line("f %d %d %d" % [idx[t] + 1, idx[t + 1] + 1, idx[t + 2] + 1])
				else:
					f.store_line("f %d/%d %d/%d %d/%d" % [idx[t] + 1, idx[t] + 1, idx[t + 1] + 1, idx[t + 1] + 1, idx[t + 2] + 1, idx[t + 2] + 1])
			f.close()
			print("OBJ ", nom, " ", v.size(), " sommets ", idx.size() / 3, " triangles")
	quit()
