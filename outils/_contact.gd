extends SceneTree
func _init() -> void:
	var d := "C:/Users/lopezk19/Jeux/nordique_pnj_ennemis/captures/ej_nouveau"
	var fs := []
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".png"):
			fs.append(f)
	fs.sort()
	var p := Image.create(3 * 640, 6 * 360, false, Image.FORMAT_RGB8)
	var txt := ""
	for i in fs.size():
		var im := Image.load_from_file(d + "/" + fs[i])
		im.convert(Image.FORMAT_RGB8)
		im.resize(640, 360)
		p.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
		txt += "%d=%s " % [i, fs[i]]
	p.save_png("C:/Users/lopezk19/Jeux/nordique_pnj_ennemis/captures/contact.png")
	print(txt)
	quit()
