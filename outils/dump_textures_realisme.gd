extends SceneTree
## [pnj/realisme_v1] Images des textures repeintes (sans rendu, headless) : visage (crop de l'atlas de peau x4) et étoffes, avant / après.
##   godot --headless --path . --script res://outils/dump_textures_realisme.gd -- --sortie=<dossier> [--ids=forgeron,chasseuse]
func _initialize() -> void:
	_l.call_deferred()
func _arg(nom: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return d
func _img(n: Node3D, piece: String) -> Image:
	var mi := n.find_child(piece, true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return null
	var m := mi.get_active_material(0) as ShaderMaterial
	var t := m.get_shader_parameter("tex_base") as Texture2D if m else null
	if t == null:
		return null
	var i := t.get_image().duplicate() as Image
	if i.is_compressed():
		i.decompress()
	i.clear_mipmaps()
	i.convert(Image.FORMAT_RGBA8)
	return i
func _l() -> void:
	CachePersos.actif = false
	var sortie := _arg("sortie", "C:/tmp")
	DirAccess.make_dir_recursive_absolute(sortie)
	for id: String in _arg("ids", "forgeron,chasseuse").split(","):
		var res := []
		for ancien in [1, 0]:
			RealismePnj._ancien = ancien
			PnjNordique.vider()
			res.append(PnjNordique._creer(id))
		for piece in ["peau", "tunique", "pantalon", "mante", "bottes", "Hair_Long", "Hair_Beard", "capuche", "jupe"]:
			var a := _img(res[0], piece)
			var b := _img(res[1], piece)
			if a == null:
				continue
			if piece == "peau":
				var W := a.get_width()
				var r := Rect2i(int(W * 0.03), int(W * 0.06), int(W * 0.32), int(W * 0.30))
				a = a.get_region(r)
				b = b.get_region(r)
			var k := 4 if a.get_width() <= 128 else 2
			var pl := Image.create(a.get_width() * k * 2 + 4, a.get_height() * k, false, Image.FORMAT_RGBA8)
			pl.fill(Color(0.2, 0.2, 0.2))
			a.resize(a.get_width() * k, a.get_height() * k, Image.INTERPOLATE_NEAREST)
			b.resize(b.get_width() * k, b.get_height() * k, Image.INTERPOLATE_NEAREST)
			pl.blend_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
			pl.blend_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + 4, 0))
			pl.save_png(sortie + "/%s_%s.png" % [id, piece])
		for n in res:
			n.free()
	print("DUMP OK")
	quit()
