class_name CercleRunique
## Cercle de sept pierres dressées autour d'une stèle gravée de runes qui luisent.
## Les hauteurs et inclinaisons des pierres consomment `monde.rng` : ne pas changer l'ordre.

static func texture_runes() -> ImageTexture:
	var img := Image.create(12, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.5, 1.6, 2.0)
	for r in 3:
		var y0 := 1 + r * 11
		for y in range(y0, y0 + 10):
			img.set_pixel(5, y, c)
		# branches façon futhark
		var motifs := [[[5, 1, 9, 5]], [[5, 2, 9, 0], [5, 6, 9, 4]], [[5, 4, 1, 0], [5, 4, 9, 0]], [[5, 1, 9, 5], [9, 5, 5, 9]]]
		for seg in motifs[(r * 3 + 1) % motifs.size()]:
			var a := Vector2(seg[0], y0 + seg[1])
			var b := Vector2(seg[2], y0 + seg[3])
			var pas := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
			for k in pas + 1:
				var p := a.lerp(b, float(k) / maxf(pas, 1))
				img.set_pixel(clampi(roundi(p.x), 0, 11), clampi(roundi(p.y), 0, 33), c)
	return ImageTexture.create_from_image(img)

static func creer(monde: Node) -> void:
	var rng: RandomNumberGenerator = monde.rng
	var cercle: Vector3 = monde.CERCLE
	var centre := Vector3(cercle.x, monde.h_cercle, cercle.z)
	var m := Palette.materiau(monde.tex_roche, Vector2(1, 2))
	var corps := StaticBody3D.new()
	monde.add_child(corps)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var haut := rng.randf_range(2.2, 3.4)
		var boite := BoxMesh.new()
		boite.size = Vector3(1.0, haut, 0.45)
		var mi := MeshInstance3D.new()
		mi.mesh = boite
		mi.material_override = m
		var p := centre + Vector3(cos(a) * 6.5, haut * 0.5 - 0.3, sin(a) * 6.5)
		mi.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5).rotated(Vector3(cos(a), 0, sin(a)), rng.randf_range(-0.08, 0.08)), p)
		monde.add_child(mi)
		var forme := CollisionShape3D.new()
		var bf := BoxShape3D.new()
		bf.size = boite.size
		forme.shape = bf
		forme.transform = mi.transform
		corps.add_child(forme)

	# pierre centrale gravée de runes qui luisent
	var stele := MeshInstance3D.new()
	var bs := BoxMesh.new()
	bs.size = Vector3(1.3, 3.6, 0.5)
	stele.mesh = bs
	stele.material_override = m
	stele.position = centre + Vector3(0, 1.5, 0)
	stele.rotation.y = 0.5
	monde.add_child(stele)
	var forme_s := CollisionShape3D.new()
	var bfs := BoxShape3D.new()
	bfs.size = bs.size
	forme_s.shape = bfs
	forme_s.transform = stele.transform
	corps.add_child(forme_s)
	var runes := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 2.1)
	runes.mesh = q
	var mr := StandardMaterial3D.new()
	mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mr.albedo_texture = texture_runes()
	mr.cull_mode = BaseMaterial3D.CULL_DISABLED
	runes.material_override = mr
	for cote in [1.0, -1.0]:
		var r := runes.duplicate() as MeshInstance3D
		r.position = Vector3(0, 0.2, 0.256 * cote)
		stele.add_child(r)
	runes.free()  # gabarit, jamais ajouté à la scène
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.35, 0.8, 1.0)
	lueur.light_energy = 1.2
	lueur.omni_range = 7.0
	lueur.position = Vector3(0, 0.3, 0)
	stele.add_child(lueur)