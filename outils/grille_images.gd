extends SceneTree
## Planche-contact : plusieurs PNG réduits côte à côte (relecture rapide des captures).
##   godot --headless --path . --script res://outils/grille_images.gd -- <sortie.png> <colonnes> <largeur tuile> img1.png img2.png ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sortie := a[0]
	var cols := int(a[1])
	var lt := int(a[2])
	var imgs: Array[Image] = []
	for i in range(3, a.size()):
		var im := Image.load_from_file(a[i])
		if im == null:
			continue
		var ht := int(lt * im.get_height() / float(im.get_width()))
		im.resize(lt, ht, Image.INTERPOLATE_BILINEAR)
		imgs.append(im)
	if imgs.is_empty():
		quit(1)
		return
	var ht := imgs[0].get_height()
	var lignes := ceili(imgs.size() / float(cols))
	var out := Image.create(cols * lt + (cols - 1) * 4, lignes * ht + (lignes - 1) * 4, false, Image.FORMAT_RGB8)
	out.fill(Color(0.1, 0.1, 0.12))
	for i in imgs.size():
		var im := imgs[i]
		im.convert(Image.FORMAT_RGB8)
		out.blit_rect(im, Rect2i(0, 0, lt, mini(ht, im.get_height())), Vector2i((i % cols) * (lt + 4), (i / cols) * (ht + 4)))
	out.save_png(sortie)
	quit(0)
