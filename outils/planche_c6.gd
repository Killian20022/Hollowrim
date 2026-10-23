extends SceneTree
## Planche C6 : RÉFÉRENCE | AVANT | APRÈS (une ligne par vue), sans texte (les noms sont dans le fichier).
##   godot --headless --script outils/planche_c6.gd -- <ref.png> <dossier_avant> <dossier_apres> <sortie.png> vue1,vue2,…
## La référence est recadrée sur la vue 6 de exterieurs_v2_planche (rectangle REF_RECT) ; chaque image ramenée à 480x270.
const REF_RECT := Rect2i(1030, 368, 506, 262)
const L := 480
const H := 270
const MARGE := 4

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var ref := Image.load_from_file(a[0])
	ref = ref.get_region(REF_RECT)
	ref.resize(L, H, Image.INTERPOLATE_BILINEAR)
	var vues: PackedStringArray = a[4].split(",")
	var img := Image.create(3 * L + 4 * MARGE, vues.size() * (H + MARGE) + MARGE, false, Image.FORMAT_RGB8)
	img.fill(Color(0.07, 0.07, 0.09))
	for i in vues.size():
		var y := MARGE + i * (H + MARGE)
		img.blit_rect(ref, Rect2i(0, 0, L, H), Vector2i(MARGE, y))
		for j in 2:
			var f: String = (a[1] if j == 0 else a[2]) + "/" + vues[i] + ".png"
			var im := Image.load_from_file(f)
			if im == null:
				push_error("manque " + f)
				continue
			im.convert(Image.FORMAT_RGB8)
			im.resize(L, H, Image.INTERPOLATE_NEAREST)
			img.blit_rect(im, Rect2i(0, 0, L, H), Vector2i(MARGE + (j + 1) * (L + MARGE), y))
	img.save_png(a[3])
	print("PLANCHE ", a[3])
	quit()
