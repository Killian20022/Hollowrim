extends SceneTree
## Diagnostic sans fenêtre : ennemis à < 30 m du joueur (grotte), couleur moyenne (texture x teinte) de chaque surface visible.
##   godot --headless --path . --script res://outils/diag_bleu.gd -- --nouvelle --paisible --reveiller --grotte=110,0,0,-4
func _init() -> void:
	root.add_child((load("res://scenes/foret_test.tscn") as PackedScene).instantiate())
	_suite.call_deferred()

func _moy(m: Material) -> String:
	if not (m is ShaderMaterial):
		return "?"
	var t: Variant = m.get_shader_parameter("tex_base")
	var te: Variant = m.get_shader_parameter("teinte")
	var c := Color(0.5, 0.5, 0.5)
	if t is Texture2D:
		var im: Image = (t as Texture2D).get_image()
		if im != null:
			if im.is_compressed():
				im.decompress()
			var n := 0
			var s := Vector3.ZERO
			for y in range(0, im.get_height(), 2):
				for x in range(0, im.get_width(), 2):
					var p := im.get_pixel(x, y)
					if p.a > 0.5:
						s += Vector3(p.r, p.g, p.b)
						n += 1
			if n > 0:
				s /= n
				c = Color(s.x, s.y, s.z)
	if te is Color:
		c = Color(c.r * te.r, c.g * te.g, c.b * te.b)
	var bleu := c.b > c.r * 1.3 and c.b > c.g * 1.05 and c.b > 0.2
	return "(%.2f %.2f %.2f)%s" % [c.r, c.g, c.b, " <== BLEU" if bleu else ""]

func _suite() -> void:
	for i in 700:
		await process_frame
	var monde := root.get_child(0)
	var j: Node3D = monde.get("joueur") if monde.get("joueur") else null
	if j == null:
		for n in root.find_children("*", "CharacterBody3D", true, false):
			if n.is_in_group("joueur"):
				j = n
	print("DIAG joueur=", j.global_position if j else "?", " ennemis=", get_nodes_in_group("ennemis").size())
	for e in get_nodes_in_group("ennemis"):
		var d := (e as Node3D).global_position.distance_to(j.global_position) if j else 0.0
		if d > 30.0:
			continue
		var mod: Node = e.get("modele")
		print("DIAG ENNEMI %s type=%s boss=%s archer=%s d=%.1f variante=%s archetype=%s" % [e.get("ident"), e.get("type"), e.get("boss"), e.get("archer"), d,
			mod.get_meta("variante", "?") if mod else "?",
			("guerrier" if mod.has_meta("guerrier_nordique") else "chasseresse" if mod.has_meta("chasseresse_nordique") else "draugr" if mod.has_meta("draugr_nordique") else "ancien") if mod else "?"])
		if mod == null:
			continue
		for mi: MeshInstance3D in mod.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree() or mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_surface_override_material(s)
				var o := "surface_override"
				if m == null:
					m = mi.material_override
					o = "material_override"
				if m == null:
					m = mi.mesh.surface_get_material(s)
					o = "mesh"
				print("DIAG   %s s%d %s %s" % [mi.name, s, o, _moy(m)])
	quit()
