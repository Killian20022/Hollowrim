extends SceneTree
## Props lot 4 : planches AVANT | APRÈS (vue de jeu), une par pose + un récapitulatif par zone.
##   godot --headless --path . --script res://outils/planche_lot4.gd -- <dossier zone> <dossier sortie> [prefixe]
## Lit <zone>/avant/<pose>.png et <zone>/apres/<pose>.png (mêmes noms) ; écrit <sortie>/<prefixe>_<pose>.png (paire en taille réelle)
## et <sortie>/<prefixe>_recap.png (paires réduites de moitié, une par ligne, largeur ≤ 1920 px).
const HB := 22
const FOND := Color(0.07, 0.07, 0.09)
const TEXTE := Color(0.95, 0.85, 0.55)
const GLYPHES := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"E": [31, 16, 16, 30, 16, 16, 31], "I": [14, 4, 4, 4, 4, 4, 14], "J": [7, 2, 2, 2, 2, 18, 12],
	"N": [17, 25, 21, 19, 17, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14], "P": [30, 17, 17, 30, 16, 16, 16],
	"Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17], "S": [15, 16, 16, 14, 1, 1, 30],
	"T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14], "V": [17, 17, 17, 17, 17, 10, 4],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [30, 1, 1, 14, 1, 1, 30], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12], "-": [0, 0, 0, 31, 0, 0, 0], " ": [0, 0, 0, 0, 0, 0, 0],
	"D": [30, 17, 17, 17, 17, 17, 30], "G": [14, 17, 16, 23, 17, 17, 15], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "H": [17, 17, 17, 31, 17, 17, 17], "F": [31, 16, 16, 30, 16, 16, 16],
	"K": [17, 18, 20, 24, 20, 18, 17], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31], "_": [0, 0, 0, 0, 0, 0, 31],
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var zone: String = args[0]
	var sortie: String = args[1]
	var pre: String = args[2] if args.size() > 2 else zone.get_file()
	DirAccess.make_dir_recursive_absolute(sortie)
	var noms: Array = []
	for f in DirAccess.get_files_at(zone + "/avant"):
		if f.ends_with(".png") and FileAccess.file_exists(zone + "/apres/" + f):
			noms.append(f.get_basename())
	noms.sort()
	var reduites: Array[Image] = []
	for n: String in noms:
		var p := _paire(zone, n, 1.0)
		if p == null:
			continue
		p.save_png("%s/%s_%s.png" % [sortie, pre, n])
		reduites.append(_paire(zone, n, 0.5))
	if reduites.is_empty():
		print("planche_lot4 : aucune paire dans ", zone)
		quit()
		return
	var w := 0
	var h := 0
	for im in reduites:
		w = maxi(w, im.get_width())
		h += im.get_height()
	var out := Image.create(mini(w, 1920), h, false, Image.FORMAT_RGBA8)
	out.fill(FOND)
	var y := 0
	for im in reduites:
		out.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(0, y))
		y += im.get_height()
	out.save_png("%s/%s_recap.png" % [sortie, pre])
	print("planche_lot4 : %d paires -> %s/%s_recap.png" % [noms.size(), sortie, pre])
	quit()

func _paire(zone: String, n: String, e: float) -> Image:
	var a := Image.load_from_file("%s/avant/%s.png" % [zone, n])
	var b := Image.load_from_file("%s/apres/%s.png" % [zone, n])
	if a == null or b == null:
		return null
	for im in [a, b]:
		im.convert(Image.FORMAT_RGBA8)
		if e != 1.0:
			im.resize(int(im.get_width() * e), int(im.get_height() * e), Image.INTERPOLATE_NEAREST)
	var w := a.get_width()
	var out := Image.create(w * 2 + 4, a.get_height() + HB, false, Image.FORMAT_RGBA8)
	out.fill(FOND)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(0, HB))
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(w + 4, HB))
	_texte(out, "AVANT EXE3  " + n.to_upper(), Vector2i(6, 4))
	_texte(out, "APRES LOT4  " + n.to_upper(), Vector2i(w + 10, 4))
	return out

func _texte(img: Image, s: String, pos: Vector2i, k: int = 2) -> void:
	var x := pos.x
	for c in s:
		var g: Array = GLYPHES.get(c, GLYPHES[" "])
		for ligne in 7:
			for col in 5:
				if (int(g[ligne]) >> (4 - col)) & 1:
					img.fill_rect(Rect2i(x + col * k, pos.y + ligne * k, k, k), TEXTE)
		x += 6 * k
