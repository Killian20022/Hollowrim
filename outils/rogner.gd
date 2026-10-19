extends SceneTree
## Rogne et agrandit (plus proche voisin) une zone d'une image : godot --headless --script outils/rogner.gd -- entree.png sortie.png x y l h echelle
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var r := Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))
	var c := img.get_region(r)
	var e := int(a[6])
	c.resize(r.size.x * e, r.size.y * e, Image.INTERPOLATE_NEAREST)
	c.save_png(a[1])
	quit()
