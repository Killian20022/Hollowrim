extends SceneTree
## Planche AVANT | APRÈS des vues joueur de chaque salle de la crypte (chantier crypte_trous, 2026-11-25), sans rendu (headless) :
##   godot --headless --path . --script res://outils/planche_crypte_trous.gd -- --avant=<dossier vues> --apres=<dossier vues>
##         --sortie=<dossier> [--bilan_avant=<bilan.txt>] [--bilan_apres=<bilan.txt>] [--par=12]
## Une ligne par salle : nom (et pixels de vide avant -> après si les bilans sont donnés), 4 vues avant (0/90/180/270°), 4 vues après.
## Écrit <sortie>/planche_avant_apres_<n>.png.
const W := 320
const H := 180
const HB := 22
const FOND := Color(0.07, 0.07, 0.09)
const TEXTE := Color(0.95, 0.85, 0.55)
const GLYPHES := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14], "D": [30, 17, 17, 17, 17, 17, 30],
	"E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16], "G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17],
	"I": [14, 4, 4, 4, 4, 4, 14], "J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 25, 21, 19, 17, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14], "P": [30, 17, 17, 30, 16, 16, 16],
	"Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17], "S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4],
	"U": [17, 17, 17, 17, 17, 17, 14], "V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31], "0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14],
	"2": [14, 17, 1, 2, 4, 8, 31], "3": [30, 1, 1, 14, 1, 1, 30], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14], "9": [14, 17, 17, 15, 1, 2, 12],
	"-": [0, 0, 0, 31, 0, 0, 0], " ": [0, 0, 0, 0, 0, 0, 0], "_": [0, 0, 0, 0, 0, 0, 31], ">": [8, 4, 2, 1, 2, 4, 8], ":": [0, 4, 0, 0, 0, 4, 0],
	"|": [4, 4, 4, 4, 4, 4, 4], "(": [2, 4, 8, 8, 8, 4, 2], ")": [8, 4, 2, 2, 2, 4, 8], ".": [0, 0, 0, 0, 0, 0, 4],
}

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _texte(img: Image, x: int, y: int, s: String, ech := 2) -> void:
	var cx := x
	for ch in s.to_upper():
		var g: Array = GLYPHES.get(ch, GLYPHES[" "])
		for r in 7:
			for c in 5:
				if int(g[r]) & (1 << (4 - c)):
					img.fill_rect(Rect2i(cx + c * ech, y + r * ech, ech, ech), TEXTE)
		cx += 6 * ech

func _bilan(chemin: String) -> Dictionary:
	var r := {}
	if chemin == "" or not FileAccess.file_exists(chemin):
		return r
	for l in FileAccess.get_file_as_string(chemin).split("\n"):
		var t := l.strip_edges()
		var i := t.find(" vues ")
		var k := t.find("| vide ")
		if i > 0 and k > 0:
			r[t.substr(0, i).strip_edges()] = int(t.substr(k + 7).strip_edges().split(" ")[0])
	return r

func _vue(dossier: String, nom: String) -> Image:
	var p := dossier + "/" + nom
	var img := Image.new()
	if FileAccess.file_exists(p) and img.load(p) == OK:
		img.convert(Image.FORMAT_RGB8)
		img.resize(W, H, Image.INTERPOLATE_NEAREST)
		return img
	img = Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0, 0.2))
	return img

func _init() -> void:
	var av := _arg("avant")
	var ap := _arg("apres")
	var so := _arg("sortie")
	var par := int(_arg("par", "12"))
	DirAccess.make_dir_recursive_absolute(so)
	var ba := _bilan(_arg("bilan_avant"))
	var bp := _bilan(_arg("bilan_apres"))
	var salles: Array = []
	for f in DirAccess.get_files_at(av):
		if f.ends_with("_0.png"):
			salles.append(f.trim_suffix("_0.png"))
	salles.sort()
	var n := 0
	for debut in range(0, salles.size(), par):
		var lot := salles.slice(debut, debut + par)
		var lw := 8 * W + 16
		var img := Image.create(lw, HB * 2 + lot.size() * (H + HB), false, Image.FORMAT_RGB8)
		img.fill(FOND)
		_texte(img, 8, 6, "AVANT (0 90 180 270)", 2)
		_texte(img, 4 * W + 16 + 8, 6, "APRES (0 90 180 270)", 2)
		for i in lot.size():
			var s: String = lot[i]
			var y := HB * 2 + i * (H + HB)
			var lib := s
			if ba.has(s) or bp.has(s):
				lib += "   VIDE %d PX > %d PX" % [int(ba.get(s, -1)), int(bp.get(s, -1))]
			_texte(img, 8, y - HB + 5, lib, 2)
			for a in 4:
				img.blit_rect(_vue(av, "%s_%d.png" % [s, a * 90]), Rect2i(0, 0, W, H), Vector2i(a * W, y))
				img.blit_rect(_vue(ap, "%s_%d.png" % [s, a * 90]), Rect2i(0, 0, W, H), Vector2i(4 * W + 16 + a * W, y))
		n += 1
		img.save_png("%s/planche_avant_apres_%d.png" % [so, n])
	print("PLANCHES ", n, " (", salles.size(), " salles)")
	quit(0)
