extends SceneTree
## Planche d'un ensemble d'armure HD (charte conception_rpg/CHARTE_ARMURES_HD.md) à partir des captures de
## outils/captures_armures_portees.gd : ligne 1 = face | 3/4 | dos | profil (360x540) ; ligne 2 = buste 3/4 face | buste 3/4 dos
## (480x540) | pièces au sol (720x400, centrée).
##   godot --headless --path . --script res://outils/planche_armures_hd.gd -- --dossier=<captures> --familles=rubis,saphir
## Écrit <dossier>/planche_<famille>.png.
const FOND := Color(0.07, 0.07, 0.09)

func _init() -> void:
	var dossier := ""
	var familles: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
		elif a.begins_with("--familles="):
			familles = a.substr(11).split(",")
	for f in familles:
		var lignes := [["face", "tq", "dos", "profil"], ["buste", "buste_dos", "sol"]]
		var imgs := []
		var largeur := 0
		var hauteur := 0
		for l in lignes:
			var rang := []
			var w := 0
			var h := 0
			for v in l:
				var img := Image.load_from_file(dossier.path_join("%s_%s.png" % [f, v]))
				if img == null:
					continue
				img.convert(Image.FORMAT_RGBA8)
				rang.append(img)
				w += img.get_width()
				h = maxi(h, img.get_height())
			imgs.append([rang, w, h])
			largeur = maxi(largeur, w)
			hauteur += h
		var p := Image.create(largeur, hauteur, false, Image.FORMAT_RGBA8)
		p.fill(FOND)
		var y := 0
		for r in imgs:
			var x := (largeur - int(r[1])) / 2
			for img: Image in r[0]:
				p.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y + (int(r[2]) - img.get_height()) / 2))
				x += img.get_width()
			y += int(r[2])
		p.save_png(dossier.path_join("planche_%s.png" % f))
		print("PLANCHE ", f, " ", p.get_size())
	quit()
