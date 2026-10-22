extends SceneTree
## Planche JETABLE avant | après du relief cuit (texture seule) : godot --headless --script res://outils/_bake_planche.gd -- gardien|troll <dossier abs>
func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var qui := a[0]
	var sortie := a[1]
	DirAccess.make_dir_recursive_absolute(sortie)
	var cas := []
	if qui == "gardien":
		cas = [["accessoires", GardienTextures.accessoires()], ["decoupes", GardienTextures.decoupes()]]
	else:
		TrollGivre.creer({}).free()
		cas = [["peau", TrollTextures.peau()]]
	for c in cas:
		var avant: Image = c[1]
		var apres := BakeRelief.appliquer(avant.duplicate(), "res://sources_blender/bake/%s/bake_%s.png" % [qui, c[0]], 1.0, {})
		var st := {}
		BakeRelief.appliquer(avant.duplicate(), "res://sources_blender/bake/%s/bake_%s.png" % [qui, c[0]], 1.0, st)
		print(c[0], " ", st)
		var k := 3 if avant.get_width() <= 256 else 1
		var w := avant.get_width() * k
		var h := avant.get_height() * k
		var pl := Image.create(w * 2 + 8, h, false, Image.FORMAT_RGBA8)
		pl.fill(Color(0.2, 0.2, 0.2))
		for im in [[avant, 0], [apres, w + 8]]:
			var s: Image = (im[0] as Image).duplicate()
			s.resize(w, h, Image.INTERPOLATE_NEAREST)
			pl.blend_rect(s, Rect2i(0, 0, w, h), Vector2i(im[1], 0))
		pl.save_png("%s/%s_avant_apres_%s.png" % [sortie, qui, c[0]])
	quit()
