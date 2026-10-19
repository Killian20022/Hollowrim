extends SceneTree
## Planches de comparaison AVANT | APRÈS (côte à côte, bandeau de texte en police bitmap 5x7).
##   godot --headless --path . --script outils/planche.gd -- [dossier] [poses_recap] [apres] [poses]
## (lot 2 : [poses] = liste séparée par des virgules, défaut POSES ; ex. A2,A10,A30,A90)
## Lit <dossier>/avant_<pose>_<jour|nuit>.png et apres_… ; écrit <dossier>/planche_<pose>.png (jour au-dessus,
## nuit en dessous) et planche_recap_jour.png / planche_recap_nuit.png (poses_recap séparées par des virgules,
## 2 paires par ligne, images réduites de moitié). Largeur ≤ 1920 px.
var apres := "apres"
var sortie := "planche"
const POSES := ["P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10", "Q1", "Q2", "Q3", "Q4"]
const HB := 22  # hauteur du bandeau
const FOND := Color(0.07, 0.07, 0.09)
const TEXTE := Color(0.95, 0.85, 0.55)

# police 5x7 : chaque glyphe = 7 lignes de 5 bits
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
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else "res://captures/biome/final"
	apres = args[2] if args.size() > 2 else "apres"  # ex. apres2 → planche2_*.png
	sortie = "planche2" if apres == "apres2" else "planche"
	var recap: PackedStringArray = (args[1] if args.size() > 1 else "P2,P4,P5,P6,Q1,Q2").split(",")
	var poses: Array = Array(POSES) if args.size() <= 3 else Array(args[3].split(","))
	for p in poses:
		var jour := _paire(dossier, p, "jour", 1.0)
		var nuit := _paire(dossier, p, "nuit", 1.0)
		if jour == null or nuit == null:
			print("ignoré (image manquante) : ", p)
			continue
		var img := Image.create(jour.get_width(), jour.get_height() + nuit.get_height(), false, Image.FORMAT_RGBA8)
		img.blit_rect(jour, Rect2i(Vector2i.ZERO, jour.get_size()), Vector2i.ZERO)
		img.blit_rect(nuit, Rect2i(Vector2i.ZERO, nuit.get_size()), Vector2i(0, jour.get_height()))
		img.save_png("%s/%s_%s.png" % [dossier, sortie, p])
		print("%s_%s.png %dx%d" % [sortie, p, img.get_width(), img.get_height()])
	for phase in ["jour", "nuit"]:
		var paires: Array[Image] = []
		for p in recap:
			var im := _paire(dossier, p, phase, 0.5)
			if im != null:
				paires.append(im)
		if paires.is_empty():
			continue
		var h := paires[0].get_height()
		var lignes := (paires.size() + 1) / 2
		var out := Image.create(1920, lignes * h, false, Image.FORMAT_RGBA8)
		out.fill(FOND)
		for i in paires.size():
			out.blit_rect(paires[i], Rect2i(Vector2i.ZERO, paires[i].get_size()), Vector2i((i % 2) * 960, (i / 2) * h))
		out.save_png("%s/%s_recap_%s.png" % [dossier, sortie, phase])
		print("%s_recap_%s.png %dx%d" % [sortie, phase, out.get_width(), out.get_height()])
	quit()

## Une paire AVANT | APRÈS avec son bandeau ; `echelle` réduit les captures.
func _paire(dossier: String, pose: String, phase: String, echelle: float) -> Image:
	var a := Image.load_from_file("%s/avant_%s_%s.png" % [dossier, pose, phase])
	var b := Image.load_from_file("%s/%s_%s_%s.png" % [dossier, apres, pose, phase])
	if a == null or b == null:
		return null
	for im in [a, b]:
		im.convert(Image.FORMAT_RGBA8)
		if echelle != 1.0:
			im.resize(int(im.get_width() * echelle), int(im.get_height() * echelle), Image.INTERPOLATE_LANCZOS)
	var w := a.get_width()
	var out := Image.create(w * 2, a.get_height() + HB, false, Image.FORMAT_RGBA8)
	out.fill(FOND)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(0, HB))
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(w, HB))
	_texte(out, "AVANT %s %s" % [pose, phase.to_upper()], Vector2i(6, 4))
	_texte(out, "APRES %s %s" % [pose, phase.to_upper()], Vector2i(w + 6, 4))
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
