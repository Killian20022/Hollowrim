extends SceneTree
## Analyse du relief de la carte actuelle pour PROPOSER (sans rien poser) l'emplacement de l'eau : rivière, ruisseaux, lac.
##   godot --headless --path . --script res://outils/carte_eau.gd -- --sortie=<dossier>
## Écrit <sortie>/carte_relief.png (ombrage + courbes de niveau + lieux), <sortie>/carte_eau.png (même fond + écoulement et bassins) et
## affiche les chiffres (profondeur des cuvettes, bassin versant, longueur des écoulements) repris dans docs/EAU.md.
## Le relief est celui de monde.gd `_hauteur_ancienne` + aplanissement de la grotte : il ne contient pas les retouches de la zone témoin
## (plateaux et chemins, ~±0,3 m) ; c'est suffisant pour décider où l'eau s'écoule.
const T := 240.0
const PAS := 2.0                    # m par case de l'analyse
const N := 120                      # = T / PAS
const IMG := 720                    # pixels de l'image (3 px par case)
const CAP_REMPLISSAGE := 1.2        # m : une cuvette moins profonde est comblée (le ruisseau la traverse), sinon c'est un puits
const PROF_LAC := 1.5               # m : profondeur de la nappe d'un lac au-dessus du point bas d'un puits
const LIEUX := {
	"feu": [Vector2(0, 0), Color(1.0, 0.65, 0.2)], "cercle": [Vector2(-38, -34), Color(0.4, 0.9, 1.0)], "tumulus": [Vector2(-38, -48), Color(0.4, 0.9, 1.0)],
	"village": [Vector2(44, 40), Color(1.0, 0.3, 0.3)], "grotte": [Vector2(92, -27), Color(0.9, 0.5, 1.0)],
}

var monde: Node
var H := PackedFloat32Array()

func _init() -> void:
	_lancer.call_deferred()

func _h(x: float, z: float) -> float:
	return GrotteAcces.aplani(x, z, monde._hauteur_ancienne(x, z), monde.h_grotte)

func _lancer() -> void:
	var sortie := "res://captures/eau/carte"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	DirAccess.make_dir_recursive_absolute(sortie)
	monde = (load("res://scripts/monde.gd") as GDScript).new()
	monde.rng.seed = 1234
	monde.bruit.seed = 7
	monde.bruit.frequency = 0.009
	monde.bruit.fractal_octaves = 4
	monde.bruit_detail.seed = 11
	monde.bruit_detail.frequency = 0.06
	monde.h_centre = monde._hauteur_brute(0.0, 0.0)
	for k in 8:
		var a := TAU * k / 8.0
		monde.h_village += monde._hauteur_brute(monde.VILLAGE.x + cos(a) * 30.0, monde.VILLAGE.z + sin(a) * 30.0) / 8.0
		monde.h_cercle += monde._hauteur_brute(monde.CERCLE.x + cos(a) * 16.0, monde.CERCLE.z + sin(a) * 16.0) / 8.0
	monde.h_grotte = monde._hauteur_ancienne(GrotteAcces.SITE.x - 1.0, GrotteAcces.SITE.y)
	H.resize(N * N)
	for j in N:
		for i in N:
			H[j * N + i] = _h(-T / 2 + (i + 0.5) * PAS, -T / 2 + (j + 0.5) * PAS)
	# --- remplissage des cuvettes (priority-flood) depuis le bord de la carte
	var F := H.duplicate()
	var etat := PackedByteArray()
	etat.resize(N * N)
	var file: Array = []                      # tas simple [hauteur, index]
	for k in N:
		for idx in [k, (N - 1) * N + k, k * N, k * N + N - 1]:
			if etat[idx] == 0:
				etat[idx] = 1
				file.append([F[idx], idx])
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	var ordre := PackedInt32Array()           # ordre de remplissage (pour l'accumulation)
	while not file.is_empty():
		var mi := 0
		for q in file.size():
			if file[q][0] < file[mi][0]:
				mi = q
		var cur: Array = file[mi]
		file[mi] = file[-1]
		file.pop_back()
		var ci: int = cur[1]
		ordre.append(ci)
		var cx := ci % N
		var cy := ci / N
		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= N or ny >= N or etat[ny * N + nx] != 0:
				continue
			etat[ny * N + nx] = 1
			if F[ci] - H[ny * N + nx] > CAP_REMPLISSAGE:
				F[ny * N + nx] = H[ny * N + nx]          # cuvette trop profonde pour être « comblée » : elle reste un puits (lac possible)
			else:
				F[ny * N + nx] = maxf(F[ny * N + nx], F[ci] + 0.0005)
			file.append([F[ny * N + nx], ny * N + nx])
	# --- accumulation d'écoulement D8 sur le relief rempli
	var acc := PackedFloat32Array()
	acc.resize(N * N)
	acc.fill(1.0)
	var vers := PackedInt32Array()
	vers.resize(N * N)
	vers.fill(-1)
	for ci in N * N:
		var cx := ci % N
		var cy := ci / N
		var best := -1
		var pente_max := 0.0
		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= N or ny >= N:
				continue
			var s := (F[ci] - F[ny * N + nx]) / (PAS * Vector2(d).length())
			if s > pente_max:
				pente_max = s
				best = ny * N + nx
		vers[ci] = best
	for k in range(ordre.size() - 1, -1, -1):
		var ci := ordre[k]
		if vers[ci] >= 0:
			acc[vers[ci]] += acc[ci]
	# --- lac : on cherche la cuvette où une nappe à +1 m du point bas couvre 2 000 à 6 000 m² d'un seul tenant (peu de terrassement),
	#     hors zone témoin, à plus de 40 m du village, 25 m du feu, 30 m de la grotte
	var lac_de := PackedInt32Array()
	lac_de.resize(N * N)
	lac_de.fill(-1)
	var stamp := PackedInt32Array()
	stamp.resize(N * N)
	var cap_cases := 1500
	var meilleurs: Array = []
	var essai := 0
	for sj in range(2, N - 2, 2):
		for si in range(2, N - 2, 2):
			var ci0 := sj * N + si
			var xm := -T / 2 + (si + 0.5) * PAS
			var zm := -T / 2 + (sj + 0.5) * PAS
			var pm := Vector2(xm, zm)
			if pm.length() > 88.0 or pm.distance_to(Vector2(44, 40)) < 40.0 or pm.length() < 25.0 or pm.distance_to(GrotteAcces.SITE) < 30.0:
				continue
			if xm > ZoneBiome.X0 - 8.0 and xm < ZoneBiome.X1 + 8.0 and zm > ZoneBiome.Z0 - 8.0 and zm < ZoneBiome.Z1 + 8.0:
				continue
			# la graine doit être un point bas local (rayon 6 m)
			var bas := true
			for dj in range(-3, 4):
				for di in range(-3, 4):
					var ni := si + di
					var nj2 := sj + dj
					if ni >= 0 and nj2 >= 0 and ni < N and nj2 < N and H[nj2 * N + ni] < H[ci0] - 0.001:
						bas = false
			if not bas:
				continue
			essai += 1
			var niv := H[ci0] + 1.0
			var pile: Array = [ci0]
			stamp[ci0] = essai
			var cases: Array = []
			var deborde := false
			while not pile.is_empty():
				var c: int = pile.pop_back()
				cases.append(c)
				if cases.size() > cap_cases:
					deborde = true
					break
				for d in dirs:
					var nx: int = c % N + d.x
					var ny: int = c / N + d.y
					if nx < 0 or ny < 0 or nx >= N or ny >= N:
						continue
					var nj := ny * N + nx
					if stamp[nj] != essai and H[nj] < niv:
						stamp[nj] = essai
						pile.append(nj)
			if deborde or cases.size() < 500:
				continue
			meilleurs.append({"graine": ci0, "niveau": niv, "cases": cases})
	meilleurs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cases"].size() > b["cases"].size())
	var retenus: Array = []
	for m in meilleurs:
		var cm := Vector2(-T / 2 + (m["graine"] % N + 0.5) * PAS, -T / 2 + (m["graine"] / N + 0.5) * PAS)
		var loin := true
		for r in retenus:
			if r["centre"].distance_to(cm) < 45.0:
				loin = false
		if loin:
			var sx0 := 0.0
			var sz0 := 0.0
			for c: int in m["cases"]:
				sx0 += -T / 2 + (c % N + 0.5) * PAS
				sz0 += -T / 2 + (c / N + 0.5) * PAS
			m["centre"] = Vector2(sx0, sz0) / m["cases"].size()
			retenus.append(m)
		if retenus.size() >= 4:
			break
	print("lacs candidats (nappe à +1 m du point bas, 2 000 à 6 000 m², d'un seul tenant) : %d cuvettes testées, %d retenues" % [essai, retenus.size()])
	var imin_lac := -1
	for k in retenus.size():
		var m: Dictionary = retenus[k]
		print("  lac %d : %d m² à %.1f m, centre (%.0f, %.0f), %.0f m du feu, %.0f m du village" % [k + 1, m["cases"].size() * 4, m["niveau"], m["centre"].x, m["centre"].y,
			m["centre"].length(), m["centre"].distance_to(Vector2(44, 40))])
		var bx0 := 1e9
		var bx1 := -1e9
		var bz0 := 1e9
		var bz1 := -1e9
		for c: int in m["cases"]:
			lac_de[c] = 0 if k == 0 else 2
			var cxl := -T / 2 + (c % N + 0.5) * PAS
			var czl := -T / 2 + (c / N + 0.5) * PAS
			bx0 = minf(bx0, cxl)
			bx1 = maxf(bx1, cxl)
			bz0 = minf(bz0, czl)
			bz1 = maxf(bz1, czl)
		print("    emprise : x %.0f à %.0f, z %.0f à %.0f" % [bx0, bx1, bz0, bz1])
		if k == 0:
			imin_lac = m["graine"]
	# longueur aval de chaque case jusqu'au point bas (suivi de `vers`)
	var longueur := PackedFloat32Array()
	longueur.resize(N * N)
	longueur.fill(-1.0)
	for ci in N * N:
		if lac_de[ci] == 0:
			longueur[ci] = 0.0
	var source := -1
	for ci in N * N:
		var chemin: Array = []
		var c := ci
		var guard := 0
		while c >= 0 and longueur[c] == -1.0 and guard < 4000:
			chemin.append(c)
			c = vers[c]
			guard += 1
		var base := -1.0
		if c >= 0 and longueur[c] >= 0.0:
			base = longueur[c]
		for k in range(chemin.size() - 1, -1, -1):
			if base < 0.0:
				longueur[chemin[k]] = -2.0
			else:
				base += PAS
				longueur[chemin[k]] = base
	var best_len := 0.0
	for ci in N * N:
		var xm := -T / 2 + (ci % N + 0.5) * PAS
		var zm := -T / 2 + (ci / N + 0.5) * PAS
		if longueur[ci] > best_len and Vector2(xm, zm).length() < 100.0:
			best_len = longueur[ci]
			source = ci
	var riviere: Array = []
	var c2 := source
	while c2 >= 0 and lac_de[c2] != 0 and riviere.size() < 4000:
		riviere.append(c2)
		c2 = vers[c2]
	print("  rivière candidate : %d m de la source (%.0f, %.0f, h=%.1f) au lac, dénivelé %.1f m" % [int(best_len), -T / 2 + (source % N + 0.5) * PAS, -T / 2 + (source / N + 0.5) * PAS, H[source], H[source] - H[imin_lac]])
	var s_txt := ""
	for k in range(0, riviere.size(), 5):
		var cr: int = riviere[k]
		var px := -T / 2 + (cr % N + 0.5) * PAS
		var pz := -T / 2 + (cr / N + 0.5) * PAS
		s_txt += "(%.0f,%.0f|h%.1f|acc%d) " % [px, pz, H[cr], int(acc[cr])]
	print("  tracé : ", s_txt)
	var pmin_feu := 1e9
	var pmin_vil := 1e9
	var pmin_tum := 1e9
	for cr: int in riviere:
		var pp := Vector2(-T / 2 + (cr % N + 0.5) * PAS, -T / 2 + (cr / N + 0.5) * PAS)
		pmin_feu = minf(pmin_feu, pp.length())
		pmin_vil = minf(pmin_vil, pp.distance_to(Vector2(44, 40)))
		pmin_tum = minf(pmin_tum, pp.distance_to(Vector2(-38, -48)))
	print("  distances minimales du tracé : feu %.0f m, village %.0f m, tumulus %.0f m" % [pmin_feu, pmin_vil, pmin_tum])
	for cr: int in riviere:
		lac_de[cr] = 1
	# --- un ruisseau côté village : plus fort écoulement à l'est (x > 20), hors lac, suivi jusqu'à ce qu'il quitte la plaine
	var src_e := -1
	for ci in N * N:
		var xm := -T / 2 + (ci % N + 0.5) * PAS
		var zm := -T / 2 + (ci / N + 0.5) * PAS
		var r := Vector2(xm, zm).length()
		if xm > 20.0 and r > 55.0 and r < 90.0 and lac_de[ci] != 0 and (src_e < 0 or acc[ci] > acc[src_e]):
			if Vector2(xm - 44.0, zm - 40.0).length() > 30.0 and Vector2(xm, zm).distance_to(GrotteAcces.SITE) > 22.0:
				src_e = ci
	if src_e >= 0:
		var txt := ""
		var c3 := src_e
		var n3 := 0
		while c3 >= 0 and n3 < 60:
			if n3 % 5 == 0:
				txt += "(%.0f,%.0f|h%.1f|acc%d) " % [-T / 2 + (c3 % N + 0.5) * PAS, -T / 2 + (c3 / N + 0.5) * PAS, H[c3], int(acc[c3])]
			lac_de[c3] = 3 if lac_de[c3] != 0 else lac_de[c3]
			c3 = vers[c3]
			n3 += 1
		print("  ruisseau est (", n3 * 2, " m) : ", txt)
	# --- statistiques
	var rempl_max := 0.0
	var surf_cuvette := 0
	for ci in N * N:
		var p := F[ci] - H[ci]
		rempl_max = maxf(rempl_max, p)
		if p > 0.25:
			surf_cuvette += 1
	var hmin := 1e9
	var hmax := -1e9
	var imin := 0
	for ci in N * N:
		if Vector2(-T / 2 + (ci % N + 0.5) * PAS, -T / 2 + (ci / N + 0.5) * PAS).length() < 100.0:
			if H[ci] < hmin:
				hmin = H[ci]
				imin = ci
		hmax = maxf(hmax, H[ci])
	print("relief : %.1f m à %.1f m (point bas dans r<100 m : x=%.0f z=%.0f)" % [hmin, hmax, -T / 2 + (imin % N + 0.5) * PAS, -T / 2 + (imin / N + 0.5) * PAS])
	print("cuvettes naturelles (> 25 cm de remplissage) : %d m², remplissage max %.2f m" % [surf_cuvette * 4, rempl_max])
	# --- images
	var img := Image.create(IMG, IMG, false, Image.FORMAT_RGB8)
	var img2 := Image.create(IMG, IMG, false, Image.FORMAT_RGB8)
	var k3 := IMG / N
	var lum := Vector3(-0.6, 0.55, -0.55).normalized()
	for py in IMG:
		for px in IMG:
			var x := -T / 2 + (px + 0.5) * T / IMG
			var z := -T / 2 + (py + 0.5) * T / IMG
			var h := _h(x, z)
			var gx := (_h(x + 1.0, z) - _h(x - 1.0, z)) * 0.5
			var gz := (_h(x, z + 1.0) - _h(x, z - 1.0)) * 0.5
			var n := Vector3(-gx, 1.0, -gz).normalized()
			var e := clampf(0.35 + 0.65 * n.dot(lum), 0.0, 1.0)
			var t := clampf((h - hmin) / (hmax - hmin), 0.0, 1.0)
			var base := Color(0.46, 0.52, 0.62).lerp(Color(0.93, 0.95, 1.0), t)
			var c := Color(base.r * e, base.g * e, base.b * e)
			if fmod(h + 1000.0, 2.0) < 0.12:
				c = c.darkened(0.18)           # courbes de niveau tous les 2 m
			img.set_pixel(px, py, c)
			img2.set_pixel(px, py, c)
	# écoulements (accumulation) et cuvettes sur la 2e image
	var seuil_ruisseau := 14.0
	var seuil_riviere := 60.0
	var n_ruisseau := 0
	var n_riviere := 0
	for ci in N * N:
		var cx := ci % N
		var cy := ci / N
		var col := Color(0, 0, 0, 0)
		if lac_de[ci] == 0:
			col = Color(0.95, 0.35, 0.85)
		elif lac_de[ci] == 1 or lac_de[ci] == 3:
			col = Color(0.1, 0.2, 1.0)
		elif acc[ci] >= seuil_riviere:
			col = Color(0.1, 0.45, 1.0)
			n_riviere += 1
		elif acc[ci] >= seuil_ruisseau:
			col = Color(0.35, 0.8, 1.0)
			n_ruisseau += 1
		if col == Color(0, 0, 0, 0):
			continue
		for dy in k3:
			for dx in k3:
				img2.set_pixel(cx * k3 + dx, cy * k3 + dy, img2.get_pixel(cx * k3 + dx, cy * k3 + dy).lerp(col, 0.85))
	print("écoulement : %d cases de ruisseau (>= %d cases amont, %d m), %d de rivière (>= %d, %d m)" % [n_ruisseau, seuil_ruisseau, n_ruisseau * 2, n_riviere, seuil_riviere, n_riviere * 2])
	# lieux et zone témoin
	for im in [img, img2]:
		for nom in LIEUX:
			var p: Vector2 = LIEUX[nom][0]
			_disque(im, p, 3.2, LIEUX[nom][1])
		_cadre(im, Rect2(ZoneBiome.X0, ZoneBiome.Z0, ZoneBiome.X1 - ZoneBiome.X0, ZoneBiome.Z1 - ZoneBiome.Z0), Color(1, 1, 0.3))
		_ligne(im, Vector2(0, 0), Vector2(44, 40) - Vector2(44, 40).normalized() * 22.0, Color(0.9, 0.8, 0.4))
	img.save_png(sortie + "/carte_relief.png")
	img2.save_png(sortie + "/carte_eau.png")
	# --- exports pour la proposition : points du plus gros écoulement et centre de la plus grande cuvette
	var tete := 0
	for ci in N * N:
		if acc[ci] > acc[tete] and F[ci] - H[ci] < 0.25:
			tete = ci
	print("plus gros écoulement hors cuvette : %d cases (%.1f ha) en x=%.0f z=%.0f h=%.1f" % [acc[tete], acc[tete] * PAS * PAS / 10000.0,
		-T / 2 + (tete % N + 0.5) * PAS, -T / 2 + (tete / N + 0.5) * PAS, H[tete]])
	var sx := 0.0
	var sz := 0.0
	var sn := 0
	for ci in N * N:
		if F[ci] - H[ci] > 0.25:
			sx += -T / 2 + (ci % N + 0.5) * PAS
			sz += -T / 2 + (ci / N + 0.5) * PAS
			sn += 1
	if sn > 0:
		print("centre moyen des cuvettes : x=%.0f z=%.0f (%d cases)" % [sx / sn, sz / sn, sn])
	monde.free()
	quit()

func _px(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x + T / 2) * IMG / T), int((p.y + T / 2) * IMG / T))

func _disque(im: Image, p: Vector2, r: float, c: Color) -> void:
	var q := _px(p)
	var rp := int(r * IMG / T)
	for dy in range(-rp, rp + 1):
		for dx in range(-rp, rp + 1):
			if dx * dx + dy * dy <= rp * rp and q.x + dx >= 0 and q.y + dy >= 0 and q.x + dx < IMG and q.y + dy < IMG:
				im.set_pixel(q.x + dx, q.y + dy, c)

func _cadre(im: Image, r: Rect2, c: Color) -> void:
	_ligne(im, r.position, Vector2(r.end.x, r.position.y), c)
	_ligne(im, Vector2(r.end.x, r.position.y), r.end, c)
	_ligne(im, r.end, Vector2(r.position.x, r.end.y), c)
	_ligne(im, Vector2(r.position.x, r.end.y), r.position, c)

func _ligne(im: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(a.distance_to(b) * IMG / T) + 1
	for k in n + 1:
		var q := _px(a.lerp(b, float(k) / n))
		if q.x >= 0 and q.y >= 0 and q.x < IMG and q.y < IMG:
			im.set_pixel(q.x, q.y, c)
