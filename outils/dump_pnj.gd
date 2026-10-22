extends SceneTree
func _initialize() -> void:
	_go.call_deferred()
func _dump(n: Node, ind: String) -> void:
	var s := ind + n.name + " [" + n.get_class() + "]"
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var tr := 0
			for i in mi.mesh.get_surface_count():
				var ar := mi.mesh.surface_get_arrays(i)
				tr += ((ar[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if ar[Mesh.ARRAY_INDEX] != null else (ar[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			s += " surf=%d tri=%d vis=%s" % [mi.mesh.get_surface_count(), tr, mi.visible]
			for i in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(i)
				if m == null: m = mi.material_override
				if m is ShaderMaterial:
					s += " | " + str((m as ShaderMaterial).get_shader_parameter("teinte"))
	if n is BoneAttachment3D: s += " bone=" + (n as BoneAttachment3D).bone_name
	print(s)
	if n.get_class() == "Skeleton3D" or true:
		for c in n.get_children():
			if c.name == "Ragdoll": continue
			_dump(c, ind + "  ")
func _go() -> void:
	var arg := "G"
	for a in OS.get_cmdline_user_args(): arg = a
	var n: Node3D
	match arg:
		"G": n = GuerrierNordique.creer({"casque": true})
		"M": n = MageNordique.creer({})
		"C": n = ChasseresseNordique.creer({})
		"D": n = GardienNordique.creer({})
	print("=== ", arg)
	_dump(n, "")
	quit()
