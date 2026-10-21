extends SceneTree
## Planches du look-dev guerrier (sans fenêtre) :
##   godot --headless --script res://outils/lookdev_planche.gd -- <dossier captures> <référence png> <dossier sortie>
## Écrit planche_<éclairage>_<dist>m.png (référence draugr | A | B | C, plus proche voisin) et
## stabilite_<éclairage>_<dist>m.png (3 captures successives, caméra déplacée de 2 cm, par échantillon) ;
## imprime un indice d'instabilité : part des pixels du cadre qui changent (> 10/255 en luminance) après recalage
## entier de la translation (la caméra a bougé de 2 cm : l'image doit glisser, pas « grouiller »).

var src := ""
var ref := ""
var out := ""
var cadres := {}

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	src = a[0]
	ref = a[1]
	out = a[2]
	DirAccess.make_dir_recursive_absolute(out)
	cadres = JSON.parse_string(FileAccess.get_file_as_string(src + "/cadres.json"))["cadres"]
	var reference := Image.load_from_file(ref)
	# draugr : buste, fourrure d'épaule, bouclier (région de l'illustration 1024×1536)
	var rc := reference.get_region(Rect2i(250, 330, 730, 700))
	var res := {}
	for ecl: String in ["crep", "torche"]:
		for dist: int in [2, 5]:
			var echelle := 3 if dist == 2 else 7
			for jeu: Array in [[["A", "B", "C"], "planche"], [["B", "C", "Cc"], "planche_contour"]]:
				var panneaux: Array[Image] = []
				var h := 0
				for s: String in jeu[0]:
					var p := _panneau("%s_%s_%dm_0" % [ecl, s, dist], echelle)
					panneaux.append(p)
					h = maxi(h, p.get_height())
				var r := rc.duplicate() as Image
				r.resize(int(float(rc.get_width()) * h / rc.get_height()), h, Image.INTERPOLATE_NEAREST)
				panneaux.push_front(r)
				_assembler(panneaux, "%s/%s_%s_%dm.png" % [out, jeu[1], ecl, dist])
			# stabilité
			var lignes: Array[Image] = []
			for s: String in ["A", "B", "C", "B0", "Bc", "Cc"]:
				var f0 := "%s_%s_%dm_" % [ecl, s, dist]
				if not cadres.has(f0 + "0"):
					continue
				var trio: Array[Image] = []
				var inst := 0.0
				for k in 3:
					trio.append(_panneau(f0 + str(k), echelle))
				for k in 2:
					inst += _instabilite(f0 + str(k), f0 + str(k + 1))
				res[f0] = inst / 2.0
				print("INSTABILITE %s%s = %.4f" % [f0, "", inst / 2.0])
				lignes.append(_assembler(trio, ""))
			_empiler(lignes, "%s/stabilite_%s_%dm.png" % [out, ecl, dist])
	var fj := FileAccess.open(out + "/instabilite.json", FileAccess.WRITE)
	fj.store_string(JSON.stringify(res))
	fj.close()
	quit(0)

func _image(nom: String) -> Image:
	return Image.load_from_file("%s/%s.png" % [src, nom])

func _rect(nom: String) -> Rect2i:
	var c: Array = cadres[nom]
	return Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3])).grow(4).intersection(Rect2i(0, 0, 640, 360))

func _panneau(nom: String, echelle: int) -> Image:
	var r := _rect(nom.left(nom.length() - 1) + "0")   # même cadre pour les 3 captures : on voit le glissement
	var img := _image(nom).get_region(r)
	img.resize(r.size.x * echelle, r.size.y * echelle, Image.INTERPOLATE_NEAREST)
	return img

func _assembler(imgs: Array[Image], chemin: String) -> Image:
	var w := 0
	var h := 0
	for i in imgs:
		w += i.get_width() + 6
		h = maxi(h, i.get_height())
	var o := Image.create(w, h, false, Image.FORMAT_RGBA8)
	o.fill(Color(0.05, 0.05, 0.06))
	var x := 0
	for i in imgs:
		i.convert(Image.FORMAT_RGBA8)
		o.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(x, 0))
		x += i.get_width() + 6
	if chemin != "":
		o.save_png(chemin)
	return o

func _empiler(imgs: Array[Image], chemin: String) -> void:
	var w := 0
	var h := 0
	for i in imgs:
		w = maxi(w, i.get_width())
		h += i.get_height() + 6
	var o := Image.create(w, h, false, Image.FORMAT_RGBA8)
	o.fill(Color(0.05, 0.05, 0.06))
	var y := 0
	for i in imgs:
		o.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(0, y))
		y += i.get_height() + 6
	o.save_png(chemin)

func _lum(img: Image) -> PackedFloat32Array:
	var l := PackedFloat32Array()
	l.resize(640 * 360)
	for y in 360:
		for x in 640:
			l[y * 640 + x] = img.get_pixel(x, y).get_luminance()
	return l

func _instabilite(n0: String, n1: String) -> float:
	var a := _lum(_image(n0))
	var b := _lum(_image(n1))
	var r := _rect(n0).grow(-6)
	var best := 1e9
	var total := float(r.size.x * r.size.y)
	var seuil := 10.0 / 255.0
	for dy in range(-2, 3):
		for dx in range(-7, 2):
			var diff := 0
			for y in range(r.position.y, r.end.y):
				var yb := clampi(y + dy, 0, 359)
				for x in range(r.position.x, r.end.x):
					if absf(a[y * 640 + x] - b[yb * 640 + clampi(x + dx, 0, 639)]) > seuil:
						diff += 1
			if diff < best:
				best = diff
	return best / total
