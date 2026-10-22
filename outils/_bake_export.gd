extends SceneTree
## Export JETABLE pour la passe Blender (bake AO/cavité) : maillages visibles du gardien ou du troll au repos, par surface
## (positions, normales, UV, indices, nom de texture) -> JSON lu par sources_blender/scripts/bake_persos.py.
##   godot --headless --path . --script res://outils/_bake_export.gd -- gardien|troll <fichier.json>
func _init() -> void:
	_go.call_deferred()

func _noms(qui: String) -> Dictionary:
	var d := {}
	if qui == "gardien":
		for n in ["mailles", "accessoires", "decoupes", "mante", "bottes", "pantalon", "brassards"]:
			d[GardienTextures.tex(n)] = n
	else:
		for n in ["peau", "meches", "accessoires", "yeux"]:
			d[TrollTextures.tex(n)] = n
	return d

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var qui := args[0]
	var g: Node3D = GardienNordique.creer({}) if qui == "gardien" else TrollGivre.creer({})
	root.add_child(g)
	var noms := _noms(qui)
	var out := []
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var xf := g.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s)
			if m == null: m = mi.material_override
			var tex = (m as ShaderMaterial).get_shader_parameter("tex_base") if m is ShaderMaterial else null
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for k in v.size(): idx.append(k)
			var fv := PackedFloat32Array()
			var fn := PackedFloat32Array()
			var fu := PackedFloat32Array()
			for k in v.size():
				var p := xf * v[k]
				fv.append(p.x); fv.append(p.y); fv.append(p.z)
				if k < n.size():
					var q := (xf.basis * n[k]).normalized()
					fn.append(q.x); fn.append(q.y); fn.append(q.z)
				if k < uv.size():
					fu.append(uv[k].x); fu.append(uv[k].y)
			out.append({"mesh": String(mi.name), "surf": s, "tex": noms.get(tex, "?"), "v": fv, "n": fn, "uv": fu, "i": idx,
				"skin": mi.skin != null, "tw": (tex.get_width() if tex is Texture2D else 0), "th": (tex.get_height() if tex is Texture2D else 0)})
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	for o in out:
		print("%s/%d tex=%s v=%d tris=%d" % [o["mesh"], o["surf"], o["tex"], (o["v"] as PackedFloat32Array).size() / 3, (o["i"] as PackedInt32Array).size() / 3])
	quit()
