extends SceneTree
## Assemble la planche de choix : godot --path . --script outils/assembler_planche_armes.gd -- <dossier captures> <fichier sortie>
const FICHES := [
	["01_sword", "Épée 1 (Sword)", "1 main"], ["02_sword_2", "Épée 2 (Sword_2)", "1 main"],
	["03_sword_golden", "Épée dorée (Sword_Golden)", "1 main"], ["04_dagger", "Dague (Dagger)", "1 main"],
	["05_claymore", "Claymore (lame rouge)", "2 mains"], ["06_axe", "Hache (Axe)", "1 main"],
	["07_axe_small", "Petite hache (Axe_Small)", "1 main"], ["08_hammer_small", "Petit marteau (Hammer_Small)", "1 main"],
	["09_hammer_double", "Marteau double (Hammer_Double)", "2 mains"], ["10_club_mace", "Masse (Club)", "1 main"],
	["11_shield_round", "Bouclier rond (Shield_Round)", "bouclier"], ["12_shield_heater", "Bouclier écu (Shield_Heater_2)", "bouclier"],
	["00_jeu_actuel", "ÉPÉE ACTUELLE DU JEU (référence)", "1 main"],
]
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var d: String = args[0]
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(d.path_join("../armes_info.json")))
	var vp := SubViewport.new()
	vp.size = Vector2i(2880, 5 * 560)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fond := ColorRect.new(); fond.color = Color("#1c1e24"); fond.size = Vector2(vp.size); vp.add_child(fond)
	for k in FICHES.size():
		var f: Array = FICHES[k]
		var ox := (k % 3) * 960
		var oy := (k / 3) * 560
		var id: String = f[0]
		var n := d.path_join("neutre_%s.png" % id)
		if FileAccess.file_exists(n):
			var t := TextureRect.new(); t.texture = ImageTexture.create_from_image(Image.load_from_file(n))
			t.position = Vector2(ox, oy); t.size = Vector2(960, 270); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode = TextureRect.STRETCH_SCALE
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; vp.add_child(t); t.size = Vector2(960, 270)
		var p := TextureRect.new(); p.texture = ImageTexture.create_from_image(Image.load_from_file(d.path_join("fps_%s.png" % id)))
		p.position = Vector2(ox, oy + 275); p.size = Vector2(480, 270); p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; p.stretch_mode = TextureRect.STRETCH_SCALE
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; vp.add_child(p); p.size = Vector2(480, 270)
		var l := Label.new()
		var tris: String = "%d tris" % int(info[id]["triangles"]) if info.has(id) else "(référence)"
		l.text = "%s\n%s\n%s\n%s" % [id.substr(0, 2) if id != "00_jeu_actuel" else "REF", f[1], f[2], tris]
		l.position = Vector2(ox + 500, oy + 285); l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color("#f2e6c8")); vp.add_child(l)
	for i in 10:
		await process_frame
	var img := vp.get_texture().get_image()
	img.save_png(args[1])
	print("planche ", img.get_size())
	quit()
