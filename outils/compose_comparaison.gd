extends SceneTree
## Planche RÉFÉRENCE | AVANT | APRÈS (même taille de tuile). Usage :
##   godot --headless --path . --script res://outils/compose_comparaison.gd -- planche.png x,y,w,h avant.png apres.png sortie.png
## planche.png + x,y,w,h = vignette de la référence (rogne), les deux captures sont réduites à 640x360.
const FONT := {
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"], "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."], "N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
	"C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"], "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."], "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."], "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
}

func _texte(img: Image, x: int, y: int, mot: String, ech: int, col: Color) -> void:
	for ch in mot:
		if FONT.has(ch):
			var g: Array = FONT[ch]
			for r in 7:
				for c in 5:
					if (g[r] as String)[c] == "#":
						img.fill_rect(Rect2i(x + c * ech, y + r * ech, ech, ech), col)
		x += 6 * ech

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 5:
		print("usage : -- planche.png x,y,w,h avant.png apres.png sortie.png")
		quit(2)
		return
	var r := Image.load_from_file(a[0])
	var rc := a[1].split(",")
	r = r.get_region(Rect2i(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3])))
	var av := Image.load_from_file(a[2])
	var ap := Image.load_from_file(a[3])
	for im: Image in [r, av, ap]:
		im.convert(Image.FORMAT_RGBA8)
	r.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	av.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	ap.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(1920, 392, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.06, 0.08))
	out.blit_rect(r, Rect2i(0, 0, 640, 360), Vector2i(0, 32))
	out.blit_rect(av, Rect2i(0, 0, 640, 360), Vector2i(640, 32))
	out.blit_rect(ap, Rect2i(0, 0, 640, 360), Vector2i(1280, 32))
	_texte(out, 10, 6, "REFERENCE", 3, Color(0.9, 0.85, 0.7))
	_texte(out, 650, 6, "AVANT", 3, Color(0.9, 0.5, 0.45))
	_texte(out, 1290, 6, "APRES", 3, Color(0.55, 0.9, 0.6))
	out.save_png(a[4])
	print("planche : ", a[4])
	quit()
