extends SceneTree
## Planche des props TEXTURÉS du Fantasy Props MegaKit (props/quaternius, 2026-11-10) : chaque prop rendu par le shader ps1 du jeu
## (PropsQuat, matériau partagé « exterieur »), vue 3/4, cellule 120 px agrandie x2 au plus proche (rendu PS1), nom + triangles.
##   godot --path . --script res://outils/planche_props_quat.gd -- --sortie=<png> [--colonnes=10] [--contexte=exterieur|interieur]
##         [--seulement=pq_a,pq_b] [--cell=120] [--nuit]
## Fenêtre requise (rendu réel) : passer par godot_slot.sh (hors écran).

var args := {}

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_go.call_deferred()

func _cellule(id: String, n: int, contexte: String, nuit: bool) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = Vector2i(n, n)
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.14) if not nuit else Color(0.03, 0.035, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.45, 0.58) if not nuit else Color(0.32, 0.40, 0.62)
	env.ambient_light_energy = 0.55 if not nuit else 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.86, 0.72) if not nuit else Color(0.62, 0.72, 1.0)
	sol.light_energy = 1.25 if not nuit else 0.6
	sol.rotation_degrees = Vector3(-48, 35, 0)
	sv.add_child(sol)
	var mi := PropsQuat.instancier(id, contexte)
	if mi == null:
		return sv
	sv.add_child(mi)
	var b := mi.get_aabb()
	var c := b.get_center()
	var r := maxf(b.size.length() * 0.5, 0.05)
	var cam := Camera3D.new()
	cam.fov = 30.0
	var d := Vector3(0.75, 0.55, 1.0).normalized()       # 3/4 avant-droite (avant du prop = +Z Godot)
	var pos := c + d * r / sin(deg_to_rad(cam.fov * 0.5)) * 1.08
	cam.transform = Transform3D(Basis.looking_at(c - pos, Vector3.UP), pos)
	sv.add_child(cam)
	cam.near = 0.01
	return sv

func _go() -> void:
	var cat := PropsQuat.catalogue()
	var ids: Array = cat.keys()
	if args.has("seulement"):
		ids = String(args["seulement"]).split(",")
	var cols := int(args.get("colonnes", "10"))
	var n := int(args.get("cell", "120"))
	var z := 2
	var contexte := String(args.get("contexte", "exterieur"))
	var nuit := args.has("nuit")
	var lw := n * z
	var lh := n * z + 34
	var rows := int(ceil(ids.size() / float(cols)))
	var W := cols * (lw + 6) + 6
	var Hh := rows * (lh + 6) + 6 + 40
	var grand := SubViewport.new()
	grand.size = Vector2i(W, Hh)
	grand.transparent_bg = false
	grand.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(grand)
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.05, 0.065)
	fond.size = Vector2(W, Hh)
	grand.add_child(fond)
	var titre := Label.new()
	var total := 0
	for id in ids:
		total += int(cat[id]["tris"])
	titre.text = "Fantasy Props MegaKit (Quaternius, CC0) -> PS1 texturé : %d props, %d triangles, atlas 128/256 px partagés  [%s%s]" % [ids.size(), total, contexte, ", nuit" if nuit else ""]
	titre.position = Vector2(10, 8)
	titre.add_theme_font_size_override("font_size", 20)
	grand.add_child(titre)
	var i := 0
	for id: String in ids:
		var e: Dictionary = cat[id]
		var sv := _cellule(id, n, contexte, nuit)
		grand.add_child(sv)
		var tr := TextureRect.new()
		tr.texture = sv.get_texture()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(lw, lw)
		var x := 6 + (i % cols) * (lw + 6)
		var y := 46 + (i / cols) * (lh + 6)
		tr.position = Vector2(x, y)
		grand.add_child(tr)
		var lb := Label.new()
		var dm: Array = e["dimensions_m"]
		lb.text = "%s  %d tri\n%.2f x %.2f x %.2f m" % [id.trim_prefix("pq_"), int(e["tris"]), dm[0], dm[1], dm[2]]
		lb.position = Vector2(x + 2, y + lw)
		lb.add_theme_font_size_override("font_size", 13)
		grand.add_child(lb)
		i += 1
	for k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := grand.get_texture().get_image()
	var sortie := String(args.get("sortie", "res://captures/props_quat/planche.png"))
	if sortie.begins_with("res://"):
		sortie = ProjectSettings.globalize_path(sortie)
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	img.save_png(sortie)
	print("PLANCHE ", sortie, " ", img.get_size(), " ", ids.size(), " props")
	quit()
