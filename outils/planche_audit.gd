extends SceneTree
## Planche des captures d'un dossier (ordre alphabétique) : grille de vignettes numérotées (le numéro = préfixe NN_ du fichier).
##   godot --headless --path . --script res://outils/planche_audit.gd -- <dossier> <sortie.png> [colonnes=4] [largeur_vignette=480]
const CHIFFRES := {
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"], "2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", "###", "..#", "###"], "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."], "8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
}

func _num(img: Image, x: int, y: int, txt: String, e: int) -> void:
	img.fill_rect(Rect2i(x - e, y - e, (txt.length() * 4 + 1) * e, 7 * e), Color(0, 0, 0, 0.85))
	for ch in txt:
		if CHIFFRES.has(ch):
			var gl: Array = CHIFFRES[ch]
			for r in 5:
				for c in 3:
					if (gl[r] as String)[c] == "#":
						img.fill_rect(Rect2i(x + c * e, y + r * e, e, e), Color(1.0, 0.85, 0.3))
		x += 4 * e

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dossier: String = a[0]
	var sortie: String = a[1]
	var cols := int(a[2]) if a.size() > 2 else 4
	var lv := int(a[3]) if a.size() > 3 else 480
	var hv := lv * 9 / 16
	var fichiers: Array = []
	for f in DirAccess.get_files_at(dossier):
		if f.ends_with(".png"):
			fichiers.append(f)
	fichiers.sort()
	var lignes := ceili(fichiers.size() / float(cols))
	var out := Image.create(cols * lv + (cols + 1) * 4, lignes * hv + (lignes + 1) * 4, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.06, 0.07, 0.09))
	for i in fichiers.size():
		var im := Image.load_from_file(dossier.path_join(fichiers[i]))
		im.convert(Image.FORMAT_RGBA8)
		im.resize(lv, hv, Image.INTERPOLATE_BILINEAR)
		var x := 4 + (i % cols) * (lv + 4)
		var y := 4 + (i / cols) * (hv + 4)
		out.blit_rect(im, Rect2i(0, 0, lv, hv), Vector2i(x, y))
		var n := String(fichiers[i]).get_slice("_", 0)
		_num(out, x + 8, y + 8, n, 4)
	out.save_png(sortie)
	print("PLANCHE %d vignettes -> %s" % [fichiers.size(), sortie])
	quit(0)
