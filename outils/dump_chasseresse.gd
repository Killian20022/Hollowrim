extends SceneTree
## Export (pour Blender) des pièces de la chasseresse au repos : OBJ par pièce + os.json.
##   godot --headless --path . --script res://outils/dump_chasseresse.gd -- --nouvelle [homme]
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var homme := OS.get_cmdline_user_args().has("homme")
	var n := ChasseresseNordique.creer({"arc": false, "carquois": false, "couteau": false, "corps": "homme"} if homme else {"arc": false, "carquois": false, "couteau": false})
	root.add_child(n)
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var dossier := ProjectSettings.globalize_path("res://sources_blender/chasseresse/") + ("homme_" if homme else "")
	for nom in ["tunique", "brassards", "cape", "mante", "pantalon", "bottes", "peau"]:
		var mi := sq.get_node_or_null(nom) as MeshInstance3D
		if mi == null:
			continue
		var s := ""
		var off := 1
		for k in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(k)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for p in v:
				s += "v %f %f %f\n" % [p.x, p.y, p.z]
			for t in range(0, idx.size(), 3):
				s += "f %d %d %d\n" % [idx[t] + off, idx[t + 1] + off, idx[t + 2] + off]
			off += v.size()
		FileAccess.open(dossier + nom + ".obj", FileAccess.WRITE).store_string(s)
	var os_ := {}
	for i in sq.get_bone_count():
		var o := sq.get_bone_global_rest(i).origin
		os_[sq.get_bone_name(i)] = [o.x, o.y, o.z]
	FileAccess.open(dossier + "os.json", FileAccess.WRITE).store_string(JSON.stringify(os_))
	print("DUMP ok ", dossier)
	quit()
