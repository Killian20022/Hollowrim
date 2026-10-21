extends SceneTree
## Outil (guerrier pilote) : statistiques UV / positions des pièces de homme_vetu.glb.
func _init() -> void:
	var scene: Node = load("res://assets/modeles/humains/homme_vetu.glb").instantiate()
	for nom in OS.get_cmdline_user_args():
		var mi := scene.find_child(nom, true, false) as MeshInstance3D
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var bones = a[Mesh.ARRAY_BONES]
		var w = a[Mesh.ARRAY_WEIGHTS]
		print(nom, " sommets=", v.size(), " bones/sommet=", bones.size() / v.size(), " skin=", mi.skin, " uvmin/max=", _mm(uv))
		# échantillons : sommets triés par y, 1 sur N
		var pas := maxi(1, v.size() / 40)
		for i in range(0, v.size(), pas):
			print("  p=", v[i].snapped(Vector3.ONE * 0.001), " uv=", uv[i].snapped(Vector2.ONE * 0.001), " os=", bones[i * 4], "/", bones[i * 4 + 1], " w=", snappedf(w[i * 4], 0.01))
		# bords libres
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var aretes := {}
		for t in range(0, idx.size(), 3):
			for k in 3:
				var i0: int = idx[t + k]
				var i1: int = idx[t + (k + 1) % 3]
				var p0 := v[i0].snapped(Vector3.ONE * 0.0005)
				var p1 := v[i1].snapped(Vector3.ONE * 0.0005)
				var cle := [p0, p1] if str(p0) < str(p1) else [p1, p0]
				aretes[cle] = int(aretes.get(cle, 0)) + 1
		var libres := 0
		var ys := []
		for c in aretes:
			if aretes[c] == 1:
				libres += 1
				ys.append(snappedf(c[0].y, 0.02))
		var hist := {}
		for y in ys:
			hist[y] = int(hist.get(y, 0)) + 1
		var cles := hist.keys()
		cles.sort()
		var s := ""
		for k in cles:
			s += "%.2f:%d " % [k, hist[k]]
		print("  bords libres=", libres, " par y : ", s)
	scene.free()
	quit()

func _mm(uv: PackedVector2Array) -> String:
	var mn := Vector2(1e9, 1e9)
	var mx := -mn
	for u in uv:
		mn = mn.min(u)
		mx = mx.max(u)
	return str(mn) + " " + str(mx)
