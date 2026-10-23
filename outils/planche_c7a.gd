extends SceneTree
## C7a : planches RÉFÉRENCE | AVANT | APRÈS du village v2 (une par pose) + récapitulatif (dérivé de planche_c1b.gd).
##   godot --headless --path . --script res://outils/planche_c7a.gd -- <dossier avant> <dossier apres> <dossier sortie> <village_v2_planche.png> pose1,pose2,...
## Colonne RÉFÉRENCE : vue recadrée de references/village_v2_planche.png — entree* → vue 1 (entrée), place* → vue 2 (place),
## rue* / pente* → vue 3 (rue du village, escaliers).
const L := 640
const H := 360
const HB := 22
var G: Dictionary

func _texte(im: Image, x: int, y: int, t: String, c: Color) -> void:
	for ch in t.to_upper():
		var g: Array = G.get(ch, G[" "])
		for r in 7:
			for b in 5:
				if (int(g[r]) >> (4 - b)) & 1:
					im.fill_rect(Rect2i(x + b * 2, y + r * 2, 2, 2), c)
		x += 12

func _case(src: Image) -> Image:
	var im := src.duplicate() as Image
	im.convert(Image.FORMAT_RGBA8)
	var k := maxf(float(L) / im.get_width(), float(H) / im.get_height())
	im.resize(int(ceil(im.get_width() * k)), int(ceil(im.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return im.get_region(Rect2i((im.get_width() - L) / 2, (im.get_height() - H) / 2, L, H))

func _init() -> void:
	G = (load("res://outils/planche.gd") as Script).get_script_constant_map()["GLYPHES"]
	var a := OS.get_cmdline_user_args()
	var ref := Image.load_from_file(a[3])
	ref.convert(Image.FORMAT_RGBA8)
	var vues := {"entree": ref.get_region(Rect2i(0, 0, 505, 318)), "place": ref.get_region(Rect2i(515, 0, 505, 318)),
		"rue": ref.get_region(Rect2i(1035, 0, 501, 318)), "pente": ref.get_region(Rect2i(1035, 0, 501, 318))}
	var recap: Array[Image] = []
	for pose in a[4].split(","):
		var av := Image.load_from_file(a[0] + "/" + pose + ".png")
		var ap := Image.load_from_file(a[1] + "/" + pose + ".png")
		var cle := pose.get_slice("_", 0)
		var out := Image.create(L * 3, H + HB, false, Image.FORMAT_RGBA8)
		out.fill(Color(0.07, 0.07, 0.09))
		var cases := [_case(vues[cle]), _case(av), _case(ap)]
		var titres := ["REFERENCE", "AVANT " + pose, "APRES " + pose]
		for i in 3:
			out.blit_rect(cases[i], Rect2i(0, 0, L, H), Vector2i(i * L, HB))
			_texte(out, i * L + 6, 4, titres[i], Color(0.95, 0.85, 0.55))
		out.save_png(a[2] + "/planche_" + pose + ".png")
		recap.append(out)
	# récapitulatif : planches réduites de moitié, empilées
	var h2 := (H + HB) / 2
	var rc := Image.create(L * 3 / 2, h2 * recap.size(), false, Image.FORMAT_RGBA8)
	for i in recap.size():
		var r := recap[i].duplicate() as Image
		r.resize(L * 3 / 2, h2, Image.INTERPOLATE_LANCZOS)
		rc.blit_rect(r, Rect2i(0, 0, r.get_width(), h2), Vector2i(0, i * h2))
	rc.save_png(a[2] + "/planche_recap.png")
	print("PLANCHES : %d + recap -> %s" % [recap.size(), a[2]])
	quit(0)
