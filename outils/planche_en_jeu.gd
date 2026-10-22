extends SceneTree
## Juxtapose ancien | nouveau : godot --headless --script res://outils/planche_en_jeu.gd -- --anc=<dossier> --nou=<dossier> --sortie=<dossier>
func _arg(n: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n):
			return a.substr(n.length() + 3)
	return ""
func _init() -> void:
	var anc := _arg("anc")
	var nou := _arg("nou")
	var sortie := _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	for f in DirAccess.get_files_at(nou):
		if not f.ends_with(".png") or not FileAccess.file_exists(anc + "/" + f):
			continue
		var a := Image.load_from_file(anc + "/" + f)
		a.convert(Image.FORMAT_RGB8)
		var b := Image.load_from_file(nou + "/" + f)
		b.convert(Image.FORMAT_RGB8)
		var p := Image.create(a.get_width() * 2 + 8, a.get_height(), false, Image.FORMAT_RGB8)
		p.fill(Color.BLACK)
		p.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
		p.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + 8, 0))
		p.save_png(sortie + "/" + f.get_basename() + "_ancien_nouveau.png")
		print("PLANCHE ", f)
	quit()
