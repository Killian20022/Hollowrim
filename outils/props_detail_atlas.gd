extends SceneTree
## props/detail_v5 (2026-11-19) : atlas DÉTAILLÉS des props Quaternius texturés (pq_*), « que ça fasse moins jouet ».
## Les atlas d'origine (sources_blender/scripts/props_quaternius.py, faire_atlas) réduisent les trims 2048 px du pack par MOYENNE de
## blocs 16 x 16 : veines, fentes, clous, biseaux et joints de planches y disparaissent (grands aplats de 4-5 tons). Ici chaque atlas
## est REPEINT à la même taille et à la même disposition (les UV des 254 pq_* ne changent pas, densité ~80 texels/m comme avant,
## proche des 64 texels/m du bâti) avec le PEINTRE DU BÂTI (PeintureBati : rampes étendues de 12 tons de la bible, lumière rasante
## du haut à gauche, tramage par bruit, nettoyage des texels isolés) :
##   - structure tirée du trim source à pleine résolution : normales (biseaux, clous, rivets, bords de panneaux -> éclairage), creux
##     (minimum de clarté du bloc -> joints, fentes), filets clairs (maximum du bloc -> arêtes usées, fil du bois) ;
##   - matière : la rampe de la bible de chaque texel de l'ancien atlas (bois, fer, cuir, écru, laine...) devient la rampe ÉTENDUE du
##     bâti (K_BOIS / K_BOIS_GRIS des planches, K_FER + rouille, K_CUIR, K_CHAUME, laines de PeintureInterieur...) et reçoit le grain de
##     cette matière (fil et nœuds du bois, planche par planche : ton et gris tirés comme dans PeintureBati.planches ; piqûres et
##     rouille du fer ; grain du cuir ; trame du tissu) ;
##   - clarté moyenne de chaque matière recalée sur l'ancien atlas (les réglages de patine PropsRealisme / PATINE_V5 restent justes).
## Variantes « _v » (multipliées par la couleur de sommet) : même calcul, sortie en luminance (9 paliers gris à peine chauds).
## Sortie : assets/modeles/props_quat/textures/pq_<atlas>_d.png (les anciens pq_<atlas>.png restent : `-- --sans-detail-v5`).
##   godot --headless --path <worktree> --script res://outils/props_detail_atlas.gd [-- --seulement=bois,fer] [--src=<dossier trims>]

const SRC_DEF := "C:/Users/lopezk19/Jeux/sources_quaternius/fantasy_props_megakit/Textures/"
const TEX := "res://assets/modeles/props_quat/textures/"
## atlas -> [trim source, taille, variante luminance, graine]
const ATLAS := {
	"bois": ["T_Trim_Furniture", 128, false, 7101],
	"fer": ["T_Trim_Metal", 128, false, 7102],
	"fer_v": ["T_Trim_Metal", 128, true, 7103],
	"tissu": ["T_Trim_Cloth", 256, false, 7104],
	"tissu_v": ["T_Trim_Cloth", 256, true, 7105],
	"props": ["T_Trim_Props", 128, false, 7106],
	"props_v": ["T_Trim_Props", 128, true, 7107],
}
## Rampes de la bible utilisées par faire_atlas (props_quaternius.py, RAMPES) : retrouver la matière d'un texel de l'ancien atlas.
const BIBLE := {
	"bois": "#2b1a1e #472a21 #6a4229 #92613a #bb8a53", "bois_mort": "#3d3c4a #5b5a66 #7f7d82 #a7a19b",
	"ecorce": "#241a22 #3a2a2a #54402f #735b43 #947c5e", "cuir": "#1f1418 #3a261b #5b3d27 #86603a",
	"tourbe": "#211e1c #3b3322 #5c4e2d #82723f #b39d5d", "fer": "#20252f #3a4256 #5b6680 #8a96ae #bcc6d8",
	"or": "#4a3419 #7b5a26 #a98638 #d3b25c", "pierre": "#262a3b #3a4057 #565b72 #787d8e #a0a2ab",
	"laine_rouge": "#351520 #5c1f2b #8a2f35 #b9504a", "laine_bleue": "#1b2a52 #2a4382 #4468ac #7b9ad0",
	"ecru": "#8e8688 #b9ae9f #dbd0b6 #efe7d0", "fourrure": "#25262f #3d3e4a #5c5d68 #85848c #b3b0b4",
	"ombre": "#090808 #0f0b08 #14161a",
}
const K_OR := ["#21170d", "#3a2914", "#4a3419", "#634721", "#7b5a26", "#927030", "#a98638", "#bf9c4a", "#d3b25c"]
const K_ECRU := ["#3e3734", "#57504b", "#726a63", "#8e8688", "#a59c94", "#b9ae9f", "#cbbfaa", "#dbd0b6", "#e6dcc3", "#efe7d0"]
const K_FOURRURE_G := ["#16171d", "#25262f", "#31323c", "#3d3e4a", "#4c4d59", "#5c5d68", "#71717b", "#85848c", "#9c9aa0", "#b3b0b4"]
const K_OMBRE := ["#060505", "#090808", "#0f0b08", "#14161a", "#1c1e24", "#26282f"]
const K_LAINE_B := ["#0e1428", "#16213f", "#1b2a52", "#223259", "#2a4382", "#33487a", "#4468ac", "#4a629c", "#6b84bd", "#7b9ad0"]
const K_LAINE_R := ["#1b0b10", "#2a0f16", "#351520", "#521820", "#5c1f2b", "#722228", "#8a2f35", "#923030", "#b04838", "#b9504a"]
## Force de la structure du trim (normales, creux, filets) : pq_fer_v sert AUSSI de matière unie (projection sur toute la surface) aux
## pierres, os, poteries et nourritures du catalogue v5 : les rangées de rivets du trim de métal y sortaient en « plaques ».
const STRUCTURE := {"fer_v": 0.3}
const LUM_V := [0.42, 0.5, 0.58, 0.66, 0.74, 0.82, 0.88, 0.94, 1.0]

var _bible := {}       # Color (hex) -> [rampe, position 0..1]

func _rampe_de(nom: String) -> Array[Color]:
	match nom:
		"bois", "ecorce":
			return PeintureBati.rampe(PeintureBati.K_BOIS)
		"bois_mort":
			return PeintureBati.rampe(PeintureBati.K_BOIS_GRIS)
		"cuir":
			return PeintureBati.rampe(PeintureBati.K_CUIR)
		"tourbe":
			return PeintureBati.rampe(PeintureBati.K_CHAUME)
		"fer":
			return PeintureBati.rampe(PeintureBati.K_FER)
		"pierre":
			return PeintureBati.rampe(PeintureBati.K_PIERRE)
		"or":
			return PeintureBati.rampe(K_OR)
		"ecru":
			return PeintureBati.rampe(K_ECRU)
		"fourrure":
			return PeintureBati.rampe(K_FOURRURE_G)
		"laine_bleue":
			return PeintureBati.rampe(K_LAINE_B)
		"laine_rouge":
			return PeintureBati.rampe(K_LAINE_R)
	return PeintureBati.rampe(K_OMBRE)

func _init() -> void:
	var src := SRC_DEF
	var seul: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--src="):
			src = String(a).get_slice("=", 1)
		elif String(a).begins_with("--seulement="):
			seul = String(a).get_slice("=", 1).split(",")
	for r: String in BIBLE:
		var cs := String(BIBLE[r]).split(" ")
		for i in cs.size():
			_bible[Color(cs[i]).to_html(false)] = [r, float(i) / maxf(cs.size() - 1, 1)]
	for k: String in ATLAS:
		if not seul.is_empty() and not (k in seul):
			continue
		var t0 := Time.get_ticks_msec()
		var img := peindre(k, src)
		var chemin := ProjectSettings.globalize_path(TEX + "pq_%s_d.png" % k)
		img.save_png(chemin)
		print("ATLAS_D pq_%s_d %d px  isolés %.1f %%  %d ms" % [k, img.get_width(), PeintureBati.part_isolee(img), Time.get_ticks_msec() - t0])
	quit(0)

## Statistiques par bloc du trim source (pleine résolution) : couleur moyenne, clarté min / max / moyenne, normale moyenne.
func _blocs(base: Image, nrm: Image, n: int) -> Dictionary:
	var w := base.get_width()
	var b := w / n
	var db := base.get_data()
	var dn := nrm.get_data()
	var cb := 4 if base.get_format() == Image.FORMAT_RGBA8 else 3
	var cn := 4 if nrm.get_format() == Image.FORMAT_RGBA8 else 3
	var moy := PackedColorArray()
	var lmin := PackedFloat32Array()
	var lmax := PackedFloat32Array()
	var lmoy := PackedFloat32Array()
	var nor := PackedVector3Array()
	moy.resize(n * n)
	lmin.resize(n * n)
	lmax.resize(n * n)
	lmoy.resize(n * n)
	nor.resize(n * n)
	var inv := 1.0 / (b * b * 255.0)
	for by in n:
		for bx in n:
			var sr := 0
			var sg := 0
			var sb := 0
			var mn := 999
			var mx := 0
			var nx := 0
			var ny := 0
			var nz := 0
			for y in range(by * b, by * b + b):
				var o := (y * w + bx * b) * cb
				var on := (y * w + bx * b) * cn
				for x in b:
					var r := db[o]
					var g := db[o + 1]
					var bl := db[o + 2]
					sr += r
					sg += g
					sb += bl
					var l := (r * 3 + g * 6 + bl) / 10
					mn = mini(mn, l)
					mx = maxi(mx, l)
					nx += dn[on]
					ny += dn[on + 1]
					nz += dn[on + 2]
					o += cb
					on += cn
			var i := by * n + bx
			moy[i] = Color(sr * inv, sg * inv, sb * inv)
			lmoy[i] = (sr * 0.3 + sg * 0.6 + sb * 0.1) * inv
			lmin[i] = mn / 255.0
			lmax[i] = mx / 255.0
			var v := Vector3(nx * inv * 2.0 - 1.0, ny * inv * 2.0 - 1.0, nz * inv * 2.0 - 1.0)
			nor[i] = v.normalized() if v.length_squared() > 1e-6 else Vector3(0, 0, 1)
	return {"moy": moy, "lmin": lmin, "lmax": lmax, "lmoy": lmoy, "nor": nor}

func _flou_n(f: PackedFloat32Array, n: int, r: int) -> PackedFloat32Array:
	return PeintureBati.flou(f, n, n, r)

## Matières de l'ancien atlas regroupées : l'accroche OKLab avait éparpillé le bois des trims entre bois, écorce, tourbe, cuir et bois
## mort ; dans les atlas de bois, tout ce qui est brun est du BOIS (hors cordage du bas de pq_bois, gardé en chaume).
func _regrouper(k: String, m: String, y: int, n: int) -> String:
	if k == "bois":
		if y >= n * 0.89 and m != "fer":
			return "tourbe"
		if m in ["tourbe", "ecorce", "cuir", "bois_mort"]:
			return "bois"
	elif k.begins_with("props"):
		if m in ["tourbe", "ecorce", "bois_mort"] and (y < n * 0.2 or y > n * 0.86):
			return "bois"
	return m

func peindre(k: String, src: String) -> Image:
	var spec: Array = ATLAS[k]
	var n: int = spec[1]
	var lumi: bool = spec[2]
	var graine: int = spec[3]
	var base := Image.load_from_file(src + String(spec[0]) + "_BaseColor.png")
	var nrm := Image.load_from_file(src + String(spec[0]) + "_Normal.png")
	for im: Image in [base, nrm]:
		if im.is_compressed():
			im.decompress()
		if im.get_format() != Image.FORMAT_RGBA8 and im.get_format() != Image.FORMAT_RGB8:
			im.convert(Image.FORMAT_RGBA8)
	var st := _blocs(base, nrm, n)
	# ancien atlas (même disposition) : matière (rampe de la bible) et ton de chaque texel ; pour les « _v », matière de la version
	# colorée du même trim (fer_v -> fer, tissu_v -> tissu, props_v -> props) et clarté de l'ancienne variante
	var cle_col := k.trim_suffix("_v")
	var anc_col := Image.load_from_file(ProjectSettings.globalize_path(TEX + "pq_%s.png" % cle_col))
	var anc := Image.load_from_file(ProjectSettings.globalize_path(TEX + "pq_%s.png" % k))
	var mat := PackedStringArray()
	var pos := PackedFloat32Array()
	mat.resize(n * n)
	pos.resize(n * n)
	var coul_anc := PackedColorArray()
	coul_anc.resize(n * n)
	for y in n:
		for x in n:
			var c := anc_col.get_pixel(x, y)
			var e: Array = _bible.get(c.to_html(false), [])
			if e.is_empty():       # (filtre « mode » : toujours une couleur de palette ; au cas où) plus proche couleur
				var best := 9.0
				for h: String in _bible:
					var d := Color(h)
					var dd := (d.r - c.r) * (d.r - c.r) + (d.g - c.g) * (d.g - c.g) + (d.b - c.b) * (d.b - c.b)
					if dd < best:
						best = dd
						e = _bible[h]
			mat[y * n + x] = _regrouper(k, String(e[0]), y, n)
			coul_anc[y * n + x] = c
	# texels isolés d'une autre matière (bruit de l'accroche de l'ancien atlas) : matière majoritaire de la fenêtre 5 x 5
	var mat2 := mat.duplicate()
	for y in n:
		for x in n:
			var cnt := {}
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var m2 := mat[posmod(y + dy, n) * n + posmod(x + dx, n)]
					cnt[m2] = int(cnt.get(m2, 0)) + 1
			if int(cnt[mat[y * n + x]]) < 5:
				var best_m := mat[y * n + x]
				var bn := 0
				for m2: String in cnt:
					if int(cnt[m2]) > bn:
						bn = cnt[m2]
						best_m = m2
				mat2[y * n + x] = best_m
	mat = mat2
	# ton de départ = clarté de l'ancien texel retrouvée dans la rampe ÉTENDUE de sa matière (les rampes courtes de la bible et les
	# rampes de 12 tons du bâti n'ont pas les mêmes bornes : on compare des clartés, pas des rangs)
	for i in n * n:
		if lumi:
			pos[i] = clampf((anc.get_pixel(i % n, i / n).r - LUM_V[0]) / (1.0 - LUM_V[0]), 0.0, 1.0)
			continue
		var ramp := _rampe_de(mat[i])
		var lc := coul_anc[i].get_luminance()
		var bi := 0
		var bd := 9.0
		for j in ramp.size():
			var dd := absf(ramp[j].get_luminance() - lc)
			if dd < bd:
				bd = dd
				bi = j
		pos[i] = float(bi) / (ramp.size() - 1)
	var lmoy: PackedFloat32Array = st["lmoy"]
	var lmin: PackedFloat32Array = st["lmin"]
	var lmax: PackedFloat32Array = st["lmax"]
	var nor: PackedVector3Array = st["nor"]
	var env := _flou_n(lmoy, n, 2)      # clarté du voisinage (5 x 5 texels) : creux et filets se lisent par rapport à elle
	# éclairage des normales du trim (vert = haut de l'image, convention OpenGL du pack) : lumière rasante du haut à gauche comme
	# PeintureBati.LUMIERE ; creux = minimum du bloc nettement sous le voisinage ; filet = maximum nettement au-dessus
	var l := Vector3(-0.45, 0.55, 0.70).normalized()
	var lit := PackedFloat32Array()
	var creux := PackedFloat32Array()
	var filet := PackedFloat32Array()
	lit.resize(n * n)
	creux.resize(n * n)
	filet.resize(n * n)
	for i in n * n:
		var v := nor[i]
		lit[i] = clampf((v.dot(l) - l.z) * 1.6 + 0.5, 0.0, 1.0)
		var ref := maxf(env[i], 0.04)
		creux[i] = clampf((ref - lmin[i]) / ref * 1.6 - 0.35, 0.0, 1.0)
		filet[i] = clampf((lmax[i] - ref) / ref * 1.4 - 0.3, 0.0, 1.0)
	# planches : composantes 4-connexes des texels de bois hors joints (creux marqué) ; ton et gris par planche (PeintureBati.planches)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var bois := PackedByteArray()
	bois.resize(n * n)
	for i in n * n:
		bois[i] = 1 if (mat[i] == "bois" or mat[i] == "ecorce" or mat[i] == "bois_mort") else 0
	var joint := PackedByteArray()
	joint.resize(n * n)
	for i in n * n:
		joint[i] = 1 if bois[i] == 1 and creux[i] > 0.55 else 0
	var comp := PackedInt32Array()
	comp.resize(n * n)
	comp.fill(-1)
	var l0 := PackedFloat32Array()
	var gris := PackedFloat32Array()
	var aire := PackedInt32Array()
	var nb := 0
	for i0 in n * n:
		if bois[i0] == 0 or joint[i0] == 1 or comp[i0] >= 0:
			continue
		var pile := [i0]
		comp[i0] = nb
		var a := 0
		while not pile.is_empty():
			var i: int = pile.pop_back()
			a += 1
			var x := i % n
			var y := i / n
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := x + d.x
				var yy := y + d.y
				if xx < 0 or yy < 0 or xx >= n or yy >= n:
					continue
				var j := yy * n + xx
				if bois[j] == 1 and joint[j] == 0 and comp[j] < 0:
					comp[j] = nb
					pile.append(j)
		l0.append(rng.randf_range(-0.09, 0.09))
		gris.append(clampf(rng.randf() * 0.5 - 0.12, 0.0, 0.35))
		aire.append(a)
		nb += 1
	# grain : fil du bois HORIZONTAL (les trims du pack posent les planches le long de U), trame de tissu, piqûres du fer
	var fib := PeintureBati.bruit(n, n, maxi(n / 24, 3), n / 2, graine + 1)
	var fib2 := PeintureBati.bruit(n, n, maxi(n / 12, 5), n, graine + 2)
	var strie := PeintureBati.bruit(n, n, 3, n / 3, graine + 6)
	var meso := PeintureBati.fbm(n, n, 8, 8, 3, graine + 4)
	var grain := PeintureBati.bruit(n, n, n / 2, n / 2, graine + 5)
	var piq := PeintureBati.bruit(n, n, n / 2, n / 2, graine + 3)
	var rouille := PeintureBati.fbm(n, n, 10, 10, 3, graine + 7)
	var cell := PeintureBati.bruit(n, n, n / 4, n / 4, graine + 8)
	# nœuds : dans les grandes planches (un par ~700 texels), anneaux sombres étirés le long du fil
	var ring := PackedFloat32Array()
	ring.resize(n * n)
	var e := 2 if n <= 128 else 3
	for c in nb:
		if aire[c] < 160:
			continue
		var cand: Array = []
		for i in n * n:
			if comp[i] == c:
				cand.append(i)
		for _q in maxi(1, aire[c] / 700):
			var ic: int = cand[rng.randi_range(0, cand.size() - 1)]
			var cx := ic % n
			var cy := ic / n
			for dy in range(-3 * e, 3 * e + 1):
				for dx in range(-5 * e, 5 * e + 1):
					var rr := sqrt(pow(dx / (4.2 * e), 2.0) + pow(dy / (1.9 * e), 2.0))
					if rr < 1.0:
						var j := posmod(cy + dy, n) * n + posmod(cx + dx, n)
						if comp[j] == c:
							ring[j] = 0.5 + 0.5 * cos(rr * 9.0)
	# clarté brute par texel
	var L := PackedFloat32Array()
	L.resize(n * n)
	for i in n * n:
		var m := mat[i]
		var v := 0.5 + (pos[i] - 0.5) * 0.45
		v += ((lit[i] - 0.5) * 0.7 - creux[i] * 0.42 + filet[i] * 0.16) * float(STRUCTURE.get(k, 1.0))
		v += (meso[i] - 0.5) * 0.12 + (grain[i] - 0.5) * 0.06
		if bois[i] == 1:
			var g := fib[i] * 0.6 + fib2[i] * 0.4
			v += (g - 0.5) * 0.38
			if strie[i] > 0.7:
				v -= (strie[i] - 0.7) * 0.4
			if comp[i] >= 0:
				v += l0[comp[i]]
			if ring[i] > 0.0:
				v -= 0.08 + ring[i] * 0.09
			if joint[i] == 1:
				v = 0.06 + grain[i] * 0.05
		elif m == "fer" or m == "or" or m == "pierre":
			v += (meso[i] - 0.5) * (0.32 if k == "fer_v" else 0.2) + (cell[i] - 0.5) * (0.14 if k == "fer_v" else 0.0)
			if piq[i] > 0.86:
				v -= 0.16
		elif m == "cuir":
			v += (cell[i] - 0.5) * 0.18
		elif m == "ecru" or m.begins_with("laine") or m == "fourrure" or m == "tourbe":
			# trame : un texel sur deux décalé (toile) + fils plus clairs
			v += (0.035 if ((i % n) + (i / n)) % 2 == 0 else -0.035) + (fib2[i] - 0.5) * 0.12
		L[i] = v
	# recalage : clarté moyenne de chaque matière = celle de l'ancien atlas (position moyenne dans la rampe)
	var som := {}
	for i in n * n:
		var m := mat[i] if not lumi else "_v"
		var s: Array = som.get(m, [0.0, 0.0, 0])
		s[0] += L[i]
		s[1] += pos[i]
		s[2] += 1
		som[m] = s
	for i in n * n:
		var s: Array = som[mat[i] if not lumi else "_v"]
		L[i] += (float(s[1]) - float(s[0])) / float(s[2])
	if OS.get_cmdline_user_args().has("--diag"):
		for m: String in som:
			var cr0 := 0.0
			var fi0 := 0.0
			var c0 := 0
			for i in n * n:
				if (mat[i] if not lumi else "_v") == m:
					cr0 += creux[i]
					fi0 += filet[i]
					c0 += 1
			print("  %s %-12s n=%5d pos=%.2f L=%.2f creux=%.2f filet=%.2f" % [k, m, som[m][2], som[m][1] / som[m][2], som[m][0] / som[m][2], cr0 / c0, fi0 / c0])
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var cr := PeintureBati.rampe(PeintureBati.K_ROUILLE, 8)
	var cg := PeintureBati.rampe(PeintureBati.K_BOIS_GRIS)
	for y in n:
		for x in n:
			var i := y * n + x
			var col: Color
			if lumi:
				var q := clampi(int(round(clampf(L[i], 0.0, 1.0) * (LUM_V.size() - 1) + (fposmod(sin(x * 12.9898 + y * 78.233 + graine) * 43758.5453, 1.0) - 0.5) * 0.5)), 0, LUM_V.size() - 1)
				var gv: float = LUM_V[q]
				col = Color(gv, gv * 0.985, gv * 0.965)
			else:
				var ramp := _rampe_de(mat[i])
				var ix := PeintureBati.ton_e(L[i], x, y, 2, ramp.size(), graine)
				col = ramp[ix]
				if bois[i] == 1 and mat[i] != "bois_mort" and comp[i] >= 0:
					col = col.lerp(cg[clampi(int(ix * 7.0 / 11.0 + 0.5), 0, cg.size() - 1)], gris[comp[i]])
				elif mat[i] == "fer" and rouille[i] > 0.64 and (creux[i] > 0.12 or piq[i] > 0.8):
					col = cr[PeintureBati.ton_e(0.35 + (lit[i] - 0.5) * 0.7 + (grain[i] - 0.5) * 0.2, x, y, 2, 8, graine)]
			img.set_pixel(x, y, col)
	return PeintureBati.nettoie(img, 2)
