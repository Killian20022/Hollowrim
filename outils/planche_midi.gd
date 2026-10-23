extends SceneTree
## Lot C3 « midi » : planches RÉFÉRENCE | AVANT | APRÈS (une ligne par vue) et planche du cycle (9 h → 22 h).
##   godot --headless --path . --script res://outils/planche_midi.gd -- --ref=<exterieurs_v2_planche.png> --avant=<dossier>
##     --apres=<dossier> --sortie=<dossier> --poses=entree,foret,… --heure=12 [--nom=planche_12] [--cycle=entree,foret]
## Les captures sont <dossier>/<pose>_<heure>.png (outils/poses_midi.txt). La colonne référence alterne les vues de jour
## de la planche (1 chemin, 2 rivière, 4 forêt, 5 campement). --cycle : planche AVANT/APRÈS aux heures 09, 12, 15, 1730, 22.
const PLANCHE := preload("res://outils/planche.gd")
const L := 640
const H := 360
const HB := 22
const FOND := Color(0.07, 0.07, 0.09)
const TEXTE := Color(0.95, 0.85, 0.55)
const VUES_REF := [Rect2i(0, 0, 507, 315), Rect2i(520, 0, 495, 315), Rect2i(0, 368, 507, 262), Rect2i(520, 368, 495, 262)]
var glyphes: Dictionary

func _arg(n: String, d := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n):
			return a.substr(n.length() + 3)
	return d

func _texte(img: Image, s: String, pos: Vector2i, k: int = 2) -> void:
	var x := pos.x
	for ch in s.to_upper():
		var g = glyphes.get(ch)
		if g != null:
			for r in 7:
				for b in 5:
					if (int(g[r]) >> (4 - b)) & 1:
						img.fill_rect(Rect2i(x + b * k, pos.y + r * k, k, k), TEXTE)
		x += 6 * k

func _case(chemin: String) -> Image:
	var im := Image.load_from_file(chemin) if FileAccess.file_exists(chemin) else null
	if im == null:
		im = Image.create(L, H, false, Image.FORMAT_RGBA8)
		im.fill(Color(0.3, 0.0, 0.0))
		return im
	im.convert(Image.FORMAT_RGBA8)
	im.resize(L, H, Image.INTERPOLATE_LANCZOS)
	return im

func _ref(ref: Image, i: int) -> Image:
	var r: Rect2i = VUES_REF[i % VUES_REF.size()]
	# recadrage au format 16:9 centré
	var h := mini(r.size.y, int(r.size.x * 9.0 / 16.0))
	var w := int(h * 16.0 / 9.0)
	var im := ref.get_region(Rect2i(r.position.x + (r.size.x - w) / 2, r.position.y + (r.size.y - h) / 2, w, h))
	im.resize(L, H, Image.INTERPOLATE_LANCZOS)
	return im

func _grille(lignes: Array, entetes: PackedStringArray) -> Image:
	var cols: int = entetes.size()
	var img := Image.create(cols * L, HB + lignes.size() * (H + HB), false, Image.FORMAT_RGBA8)
	img.fill(FOND)
	for c in cols:
		_texte(img, entetes[c], Vector2i(c * L + 6, 4))
	for li in lignes.size():
		var y := HB + li * (H + HB)
		_texte(img, lignes[li][0], Vector2i(6, y + 4))
		for c in cols:
			img.blit_rect(lignes[li][1][c], Rect2i(0, 0, L, H), Vector2i(c * L, y + HB))
	return img

func _init() -> void:
	glyphes = PLANCHE.GLYPHES
	var avant := _arg("avant")
	var apres := _arg("apres")
	var sortie := _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var cycle := _arg("cycle")
	if cycle != "":
		var heures := ["09", "12", "15", "1730", "22"]
		var noms := PackedStringArray(["9H", "12H", "15H", "17H30", "22H"])
		for p in cycle.split(","):
			var lignes := []
			for d in [["AVANT", avant], ["APRES", apres]]:
				var cases := []
				for h in heures:
					var im := _case("%s/%s_%s.png" % [d[1], p, h])
					im.resize(L, H)
					cases.append(im)
				lignes.append(["%s %s" % [d[0], p.replace("_", " ")], cases])
			var g := _grille(lignes, noms)
			g.resize(g.get_width() / 2, g.get_height() / 2, Image.INTERPOLATE_LANCZOS)
			g.save_png("%s/planche_cycle_%s.png" % [sortie, p])
			print("planche_cycle_", p)
		quit()
		return
	var ref := Image.load_from_file(_arg("ref"))
	ref.convert(Image.FORMAT_RGBA8)
	var heure := _arg("heure", "12")
	var lignes := []
	var i := 0
	for p in _arg("poses").split(","):
		lignes.append([p.replace("_", " ") + " " + heure + "H", [_ref(ref, i), _case("%s/%s_%s.png" % [avant, p, heure]), _case("%s/%s_%s.png" % [apres, p, heure])]])
		i += 1
	var g := _grille(lignes, PackedStringArray(["REFERENCE", "AVANT", "APRES"]))
	var nom := _arg("nom", "planche_" + heure)
	g.save_png("%s/%s.png" % [sortie, nom])
	print(nom, " ", g.get_size())
	quit()
