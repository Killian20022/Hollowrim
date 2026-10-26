class_name PeintureBati
## Lot 5, 2e passe « réalisme 32 bits » : textures du bâti PEINTES à partir d'un champ de hauteur.
##
## Au lieu de poser des amas de pixels (lot 5, 4 tons : « coloriage »), chaque matière est d'abord un RELIEF
## (pierres bombées aux joints creux, rondins fibreux, facettes de roche fracturée…) ; on l'éclaire (lumière
## rasante venue du haut à gauche), on y ajoute ombres portées, occlusion ambiante, dégradés propres à chaque
## pierre / planche, usure (coulures, lichen, neige sur les replats) puis on lit la clarté dans une rampe de
## 12 tons (les rampes de la bible, étendues : sombre = froid et violet, clair = chaud) avec un léger tramage
## ordonné. Résultat : 32 texels/m (le shader `ps1_bati` retombe à 16 texels/m au-delà de ~10 m), mêmes
## teintes que la bible, mais profondeur et variété de tons d'une texture photo réduite à la main.
##
## Chaque génération rend [albédo RGBA8, relief RGB8] : le relief (gradient de hauteur, R = d/du, G = d/dv)
## sert au shader à pencher la normale : les lumières du jeu (soleil rasant, torches) sculptent la pierre.
## Les textures sont CUITES hors ligne (`outils/cuire_bati.gd` → `assets/bati/*.res`, avec mipmaps « vote de
## couleur ») : au lancement on ne fait que les charger. Toute la génération est déterministe (graines).

const N := 12                       # tons par matière
const PENTE_K := 6.0                # profondeur d'un relief de hauteur 1 (en texels)
const LUMIERE := Vector3(-0.45, -0.55, 0.70)
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# --- clés de rampes (bible §2 étendue : on garde les teintes, on ajoute des tons intermédiaires) -------------
const K_PIERRE := ["#12141d", "#1e2230", "#2c3145", "#3f455c", "#565c73", "#6f758a", "#8a8d9e", "#a3a5af", "#bbbab9"]
const K_PIERRE_CH := ["#16141a", "#242024", "#383037", "#4f434a", "#67595d", "#826f6d", "#9d8b85", "#b7a89f"]
const K_PIERRE_VERT := ["#11161a", "#1c2429", "#2b373b", "#3f4e4f", "#566763", "#6f8077", "#8c9a8d", "#a7b0a2"]
## grès / granite chaud (murs de soutènement du village, D/neige_murs) : gris-brun ocré, référence village_v2_planche
const K_PIERRE_OCRE := ["#16120f", "#28201a", "#3c3127", "#544435", "#6d5a47", "#87725c", "#a08b74", "#b8a48c", "#cdbca6"]
const K_LICHEN := ["#10191a", "#1c2a27", "#2c3f35", "#43584a", "#5d7260", "#7a8d76", "#97a88f"]
const K_LICHEN_ROUX := ["#2a1e20", "#43302a", "#5e402c", "#7d5733", "#9a7040", "#b58a55", "#cba66f"]
const K_NEIGE := ["#3a4469", "#4a557f", "#5d6a95", "#6877a3", "#7b8bb3", "#8898bf", "#99a9cb", "#aab8d6", "#bcc8e1", "#cdd7ec", "#e0e6f2", "#f0eff4"]
const K_BOIS := ["#150d10", "#2b1a1e", "#3a2320", "#472a21", "#58361f", "#6a4229", "#7e4f31", "#92613a", "#a87546", "#bb8a53", "#cca066"]
const K_BOIS_GRIS := ["#14151b", "#24252d", "#363740", "#4a4a54", "#605f69", "#777580", "#908c93", "#a9a4a6"]
const K_FER := ["#12151c", "#20252f", "#2e3544", "#3a4256", "#4b556d", "#5b6680", "#738098", "#8a96ae", "#a3aec3", "#bcc6d8"]
const K_ROUILLE := ["#2a1a1e", "#4a281f", "#6e3a24", "#92502b", "#b0662f"]
const K_CHAUME := ["#16130f", "#211e1c", "#2e2a20", "#3b3322", "#4b4128", "#5c4e2d", "#6f6034", "#82723f", "#9a8750", "#b39d5d", "#c9b574"]
const K_CUIR := ["#140c10", "#1f1418", "#2c1c19", "#3a261b", "#4a3022", "#5b3d27", "#6f4b2f", "#86603a", "#9b7347"]
const K_TERRE := ["#0f0d0f", "#1a1416", "#261d1c", "#352a26", "#463a31", "#5a4b3d", "#6e5f4e"]
const K_BRAISE := ["#2a0e12", "#5a1a1c", "#8a2a1c", "#b3341f", "#d4501f", "#ec6a1f", "#f68a28", "#fcb53a", "#fed36a", "#fff0a8"]

static var _rampes := {}

static func rampe(cles: Array, n := N) -> Array[Color]:
	var cle := "%s|%d" % [cles[0] + cles[cles.size() - 1] + str(cles.size()), n]
	if _rampes.has(cle):
		return _rampes[cle]
	var cs: Array[Color] = []
	for c in cles:
		cs.append(Color(c))
	var out: Array[Color] = []
	for i in n:
		var t := float(i) / (n - 1) * (cs.size() - 1)
		var k := mini(int(t), cs.size() - 2)
		out.append(cs[k].lerp(cs[k + 1], t - k))
	_rampes[cle] = out
	return out

# --- outils de champs -------------------------------------------------------------------------------------

static func _decouper(rng: RandomNumberGenerator, total: int, mn: int, mx: int) -> Array[int]:
	var l: Array[int] = []
	var reste := total
	while reste > 0:
		if reste <= mx:
			if reste >= mn or l.is_empty():
				l.append(reste)
			else:
				l[l.size() - 1] += reste
			break
		var v := rng.randi_range(mn, mx)
		if reste - v < mn:
			v = reste - mn
		l.append(v)
		reste -= v
	return l

## Bruit de valeur lisse, périodique sur la tuile (cx × cy cellules), valeurs 0..1.
static func bruit(w: int, h: int, cx: int, cy: int, graine: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine * 7919 + cx * 31 + cy
	var lat := PackedFloat32Array()
	lat.resize(cx * cy)
	for i in lat.size():
		lat[i] = rng.randf()
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		var gy := float(y) * cy / h
		var yi := int(gy)
		var fy := gy - yi
		fy = fy * fy * (3.0 - 2.0 * fy)
		var r0 := (yi % cy) * cx
		var r1 := ((yi + 1) % cy) * cx
		for x in w:
			var gx := float(x) * cx / w
			var xi := int(gx)
			var fx := gx - xi
			fx = fx * fx * (3.0 - 2.0 * fx)
			var x0 := xi % cx
			var x1 := (xi + 1) % cx
			var a := lat[r0 + x0] + (lat[r0 + x1] - lat[r0 + x0]) * fx
			var b := lat[r1 + x0] + (lat[r1 + x1] - lat[r1 + x0]) * fx
			out[y * w + x] = a + (b - a) * fy
	return out

static func fbm(w: int, h: int, cx: int, cy: int, octaves: int, graine: int) -> PackedFloat32Array:
	var out := bruit(w, h, cx, cy, graine)
	var tot := 1.0
	var amp := 0.5
	for o in range(1, octaves):
		var f := bruit(w, h, cx * (1 << o), cy * (1 << o), graine + o * 13)
		for i in out.size():
			out[i] += f[i] * amp
		tot += amp
		amp *= 0.5
	for i in out.size():
		out[i] /= tot
	return out

## Flou en boîte (rayon r) périodique : occlusion ambiante par différence avec la hauteur.
static func flou(f: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var k := 1.0 / (2 * r + 1)
	for y in h:
		var s := 0.0
		for dx in range(-r, r + 1):
			s += f[y * w + posmod(dx, w)]
		for x in w:
			tmp[y * w + x] = s * k
			s += f[y * w + posmod(x + r + 1, w)] - f[y * w + posmod(x - r, w)]
	for x in w:
		var s := 0.0
		for dy in range(-r, r + 1):
			s += tmp[posmod(dy, h) * w + x]
		for y in h:
			out[y * w + x] = s * k
			s += tmp[posmod(y + r + 1, h) * w + x] - tmp[posmod(y - r, h) * w + x]
	return out

## Clarté de la pente sous la lumière rasante (0,5 = plat ; > 0,5 = tourné vers la lumière).
static func eclairage(hf: PackedFloat32Array, w: int, h: int, k := PENTE_K) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	var l := LUMIERE.normalized()
	for y in h:
		var ym := posmod(y - 1, h) * w
		var yp := ((y + 1) % h) * w
		var y0 := y * w
		for x in w:
			var xm := (x - 1 + w) % w
			var xp := (x + 1) % w
			var gx := (hf[y0 + xp] - hf[y0 + xm]) * 0.5 * k
			var gy := (hf[yp + x] - hf[ym + x]) * 0.5 * k
			var lam := (-gx * l.x - gy * l.y + l.z) / sqrt(gx * gx + gy * gy + 1.0)
			out[y0 + x] = clampf((lam - l.z) * 1.35 + 0.5, 0.0, 1.0)
	return out

## Ombre portée (0 ou 1) : on remonte vers la lumière (haut gauche) sur 8 texels.
static func ombres(hf: PackedFloat32Array, w: int, h: int, pente := 0.16, e := 1) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var h0 := hf[y * w + x]
			var o := 0.0
			for s in range(1, 8 * e + 1):
				var xx := posmod(x - int(round(0.62 * s)), w)
				var yy := posmod(y - int(round(0.78 * s)), h)
				if hf[yy * w + xx] > h0 + float(s) / e * pente * 0.5:
					o = 1.0
					break
			out[y * w + x] = o
	return out

## Relief encodé : R = dh/du, G = dh/dv (gradient × PENTE_K, borné à ±1, centré sur 0,5), B = hauteur.
static func relief_image(hf: PackedFloat32Array, w: int, h: int, k := PENTE_K) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var ym := posmod(y - 1, h) * w
		var yp := ((y + 1) % h) * w
		var y0 := y * w
		for x in w:
			var xm := (x - 1 + w) % w
			var xp := (x + 1) % w
			var gx := clampf((hf[y0 + xp] - hf[y0 + xm]) * 0.5 * k, -1.0, 1.0)
			var gy := clampf((hf[yp + x] - hf[ym + x]) * 0.5 * k, -1.0, 1.0)
			img.set_pixel(x, y, Color(gx * 0.5 + 0.5, gy * 0.5 + 0.5, clampf(hf[y0 + x], 0.0, 1.0)))
	return img

## Index de ton (0..N-1) pour une clarté L (0..1), avec tramage ordonné d'amplitude < 1 ton.
static func ton(L: float, x: int, y: int, n := N) -> int:
	var b: int = BAYER[(y & 3) * 4 + (x & 3)]
	return clampi(int(floor(L * (n - 1) + (b / 16.0 - 0.47) * 0.55 + 0.5)), 0, n - 1)

## Ton pour la passe « 64 texels/m » (`e` = 2) : tramage par BRUIT blanc stable (jamais de Bayer, interdit par la bible) ;
## `e` = 1 garde le tramage historique (les textures dérivées, ex. l'intérieur, restent identiques octet pour octet).
static func ton_e(L: float, x: int, y: int, e: int, n := N, graine := 0) -> int:
	if e <= 1:
		return ton(L, x, y, n)
	var hsh := fposmod(sin(float(x) * 12.9898 + float(y) * 78.233 + float(graine) * 3.7) * 43758.5453, 1.0)
	return clampi(int(floor(L * (n - 1) + (hsh - 0.5) * 0.5 + 0.5)), 0, n - 1)

## Nettoyage : un texel qui ne ressemble à AUCUN de ses 8 voisins (tuile raccordée) prend la couleur la plus fréquente
## autour de lui. Deux passes (la première peut isoler un voisin). Les lignes d'un texel (joints, fibres) survivent :
## elles sont continues, donc leurs texels ont au moins un voisin identique.
static func nettoie(img: Image, passes := 2) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	for _p in passes:
		var src := img.duplicate() as Image
		for y in h:
			for x in w:
				var c := src.get_pixel(x, y)
				var cnt := {}
				var egal := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var v := src.get_pixel(posmod(x + dx, w), posmod(y + dy, h))
						if v == c:
							egal = true
						cnt[v] = int(cnt.get(v, 0)) + 1
				if egal:
					continue
				var best := c
				var bn := 0
				for v: Color in cnt:
					var n: int = cnt[v]
					if n > bn or (n == bn and absf(v.get_luminance() - c.get_luminance()) < absf(best.get_luminance() - c.get_luminance())):
						bn = n
						best = v
				img.set_pixel(x, y, best)
	return img

## Nombre de texels isolés (aucun des 8 voisins identique) : mesure de qualité, en pourcentage.
static func part_isolee(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var n := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var egal := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and img.get_pixel(posmod(x + dx, w), posmod(y + dy, h)) == c:
						egal = true
			if not egal:
				n += 1
	return 100.0 * n / (w * h)

static func _sstep(a: float, b: float, v: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# --- pierre sèche en assises ------------------------------------------------------------------------------

## Mur de pierres sèches : assises ondulantes, pierres bombées (arrondies, une sur cinq saille davantage),
## joints creux et irréguliers, éclats facettés, lumière rasante + ombres + occlusion, teinte et clarté propres à
## chaque pierre, dégradé haut clair / bas sombre dans chaque pierre, coulures, lichen gris-vert et orangé,
## calottes de neige sur les replats, neige dans les joints. Tuile 256 × 128 texels = 8 × 4 m à 32 texels/m.
## `chaud` : palette gris-brun/ocre (quelques pierres froides seulement) ; `incl` : inclinaison max des assises.
static func mur_pierre(graine: int, w := 256, h := 128, hmin := 9, hmax := 15, wmin := 15, wmax := 34, part_neige := 0.3, rayon := 3.0, e := 1, chaud := false, incl := 0.2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var assises := _decouper(rng, h, hmin, hmax)
	var nc := assises.size()
	var y0 := PackedInt32Array()
	y0.resize(nc)
	var row_c := PackedInt32Array()
	row_c.resize(h)
	var yy := 0
	for c in nc:
		y0[c] = yy
		for r in assises[c]:
			row_c[yy + r] = c
		yy += assises[c]
	var starts: Array = []
	var tilt := PackedFloat32Array()
	var base_id := PackedInt32Array()
	var total := 0
	var prec := PackedFloat32Array()
	for c in nc:
		var larg: Array[int] = []
		var dep := 0.0
		var st := PackedFloat32Array()
		for essai in 14:
			larg = _decouper(rng, w, wmin, wmax)
			dep = rng.randf_range(0, wmax)
			st = PackedFloat32Array()
			var x := dep
			var ok := true
			for lw in larg:
				st.append(x)
				for p in prec:
					if absf(fposmod(x - p + w * 0.5, w) - w * 0.5) < 4.0 * e:
						ok = false
				x += lw
			if ok:
				break
		prec = st
		starts.append(st)
		tilt.append(rng.randf_range(-incl, incl))
		base_id.append(total)
		total += larg.size()
	# attributs par pierre
	var l0 := PackedFloat32Array()
	var tint := PackedFloat32Array()
	var proud := PackedFloat32Array()
	var neige_d := PackedFloat32Array()
	var lich := PackedFloat32Array()
	for i in total:
		l0.append(rng.randf_range(0.42, 0.7))
		tint.append(rng.randf())
		proud.append(rng.randf_range(0.55, 0.85) if rng.randf() > 0.2 else rng.randf_range(0.9, 1.0))
		neige_d.append(rng.randf_range(2.0 * e, 5.5 * e) if rng.randf() < part_neige else 0.0)
		lich.append(rng.randf())
	# ondulation des assises
	var ond := PackedInt32Array()
	ond.resize(w)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	for x in w:
		ond[x] = int(round(e * (1.4 * sin(TAU * 2 * x / w + p1) + 0.9 * sin(TAU * 5 * x / w + p2))))
	var nj := bruit(w, h, 24, 12, graine + 1)
	var chip := fbm(w, h, 10, 6, 3, graine + 2)
	var meso := fbm(w, h, 12, 6, 3, graine + 3)
	var grain := bruit(w, h, w / 2, h / 2, graine + 4)
	var sid := PackedInt32Array()
	sid.resize(w * h)
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	var vfr := PackedFloat32Array()
	vfr.resize(w * h)
	var vloc := PackedFloat32Array()
	vloc.resize(w * h)
	var uu := PackedFloat32Array()
	uu.resize(w * h)
	var hf := PackedFloat32Array()
	hf.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var yv := posmod(y + ond[x], h)
			var c := row_c[yv]
			var hh: float = assises[c]
			var v := float(yv - y0[c]) + 0.5
			var xx := fposmod(x - tilt[c] * (v - hh * 0.5), w)
			var st: PackedFloat32Array = starts[c]
			if xx < st[0]:
				xx += w
			var k := st.size() - 1
			for j in st.size() - 1:
				if xx < st[j + 1]:
					k = j
					break
			var sw: float = (st[k + 1] if k + 1 < st.size() else st[0] + w) - st[k]
			var u := xx - st[k]
			var jit := (nj[i] - 0.5) * 2.4 * e
			var du := minf(u, sw - u) + jit
			var dv := minf(v, hh - v) + (nj[(i + w * 3) % (w * h)] - 0.5) * 1.6 * e
			var ex := minf(du, dv)
			if du < rayon and dv < rayon:
				ex = rayon - sqrt((rayon - du) * (rayon - du) + (rayon - dv) * (rayon - dv))
			var id := base_id[c] + k
			sid[i] = id
			vfr[i] = v / hh
			vloc[i] = v
			uu[i] = u
			var jw := (0.3 + nj[(i + 7) % (w * h)] * 0.45) * (1.0 if e == 1 else 1.7)
			dist[i] = ex - jw
			var t := clampf((ex - jw) / (rayon + 1.5 * e * (1.0 - proud[id])), 0.0, 1.0)
			var prof := _sstep(0.0, 1.0, t)
			var dome := 1.0 - 0.5 * (pow(u / sw * 2.0 - 1.0, 2.0) + pow(v / hh * 2.0 - 1.0, 2.0))
			var ht := proud[id] * (0.5 + 0.5 * pow(prof, 0.8)) + 0.2 * dome + (meso[i] - 0.5) * 0.4 + (grain[i] - 0.5) * 0.07
			if chip[i] > 0.7 and ex > jw + 0.5 * e:
				ht -= 0.16 + (chip[i] - 0.7) * 0.9
			hf[i] = 0.0 if ex < jw else maxf(ht, 0.04)
	# calottes de neige : relief ajouté avant l'éclairage (la neige est un volume sur le replat)
	var nsn := bruit(w, h, 32, 12, graine + 5)
	var neige := PackedFloat32Array()
	neige.resize(w * h)
	for i in w * h:
		var id := sid[i]
		var d := neige_d[id]
		if d > 0.0 and hf[i] > 0.0:
			var prof := d * (0.45 + nsn[i] * 0.9)
			if vloc[i] < prof and dist[i] > -0.2 * e:
				neige[i] = 1.0
				hf[i] += 0.16 + 0.06 * (1.0 - vloc[i] / prof)
	var lit := eclairage(hf, w, h, PENTE_K * e)
	var omb := ombres(hf, w, h, 0.16, e)
	var hb := flou(hf, w, h, 2 * e)
	var lev := PackedFloat32Array()    # 64 texels/m : lèvre claire sous le joint du haut, ombre au bas de chaque pierre
	lev.resize(w * h)
	if e > 1:
		for i in w * h:
			if hf[i] > 0.0 and dist[i] < 1.7 * e:
				lev[i] = 1.0 if vfr[i] < 0.5 else -1.0
	var coul_a := rampe(K_PIERRE_CH if chaud else K_PIERRE)
	var coul_b := rampe(K_PIERRE_OCRE if chaud else K_PIERRE_CH)
	var coul_c := rampe(K_PIERRE if chaud else K_PIERRE_VERT)
	var coul_l := rampe(K_LICHEN)
	var coul_r := rampe(K_LICHEN_ROUX)
	var coul_n := rampe(K_NEIGE)
	var lk := fbm(w, h, 9, 5, 3, graine + 6)
	var lk2 := bruit(w, h, 16, 8, graine + 7)
	var strie := bruit(w, h, 44, 3, graine + 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var id := sid[i]
			var joint := hf[i] <= 0.0
			var ao := clampf(hb[i] - hf[i], 0.0, 0.3)
			var L := l0[id] + (lit[i] - 0.5) * 0.85 - ao * 0.6 + clampf(hf[i] - hb[i], 0.0, 0.3) * 0.7
			L += (0.5 - vfr[i]) * 0.2 + (meso[i] - 0.5) * 0.18 + (grain[i] - 0.5) * 0.14 + (grain[(i * 7 + 13) % (w * h)] - 0.5) * 0.08
			L -= omb[i] * 0.1
			var s := strie[i]
			if s > 0.6:
				L -= (s - 0.6) * 0.5 * (1.0 - vfr[i] * 0.5)
			if lev[i] > 0.5:
				L += 0.1
			elif lev[i] < -0.5:
				L -= 0.07
			if joint:
				L = 0.04 + grain[i] * 0.06
			var t := tint[id]
			var col: Color
			var ix := ton_e(L, x, y, e, N, graine)
			if chaud:
				# surtout gris-brun et ocre, une pierre sur huit plus froide (gris bleuté)
				if t < 0.5:
					col = coul_a[ix].lerp(coul_b[ix], t / 0.5)
				elif t < 0.875:
					col = coul_b[ix].lerp(coul_a[ix], (t - 0.5) / 0.375 * 0.5)
				else:
					col = coul_a[ix].lerp(coul_c[ix], 0.55)
			elif t < 0.45:
				col = coul_a[ix].lerp(coul_b[ix], t / 0.45 * 0.6)
			elif t < 0.8:
				col = coul_a[ix].lerp(coul_c[ix], (t - 0.45) / 0.35 * 0.7)
			else:
				col = coul_b[ix].lerp(coul_c[ix], 0.35)
			# lichen
			var m := lk[i] + (lk2[i] - 0.5) * 0.2 + (lich[id] - 0.5) * 0.28
			if not joint and m > (0.86 if chaud else 0.73) and neige[i] < 0.5 and lit[i] > 0.3:   # chaud : lichen rare (pas de taches)
				col = coul_l[ton_e(L * 0.95 + 0.06, x, y, e, N, graine)] if lk2[i] < 0.72 else coul_r[ton_e(L * 0.95 + 0.04, x, y, e, N, graine)]
			if neige[i] > 0.5:
				var ln := 0.82 + (lit[i] - 0.5) * 0.7 - (vloc[i] / maxf(neige_d[id], float(e))) * 0.22 - omb[i] * 0.1
				col = coul_n[ton_e(ln, x, y, e, N, graine)]
			elif not joint and dist[i] < 1.0 * e and neige_d[id] > 0.0 and vloc[i] < neige_d[id] + 2.5 * e:
				col = col.darkened(0.25)   # ombre sous la calotte
			img.set_pixel(x, y, col)
	return [img, relief_image(hf, w, h, PENTE_K * e)]

# --- roche fracturée (menhirs, rochers, façade) ---------------------------------------------------------------

## Granite fracturé : facettes de Voronoï inclinées (chacune a sa pente, donc sa clarté sous la lumière rasante),
## fractures sombres à lèvre claire, strates fines, lichen, neige sur les facettes tournées vers le ciel.
## Tuile 128 × 128 = 4 × 4 m. Boucle sur les quatre bords.
static func roche(graine: int, n := 128, cellules := 5, part_neige := 1.0, fissures := 1.0, e := 1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var gr: Array[Vector2] = []
	var off := PackedFloat32Array()
	var sx := PackedFloat32Array()
	var sy := PackedFloat32Array()
	var l0 := PackedFloat32Array()
	var tint := PackedFloat32Array()
	var ang := PackedFloat32Array()
	var bande := PackedFloat32Array()
	var dec := PackedFloat32Array()
	for j in cellules:
		for i in cellules:
			gr.append(Vector2((i + rng.randf_range(0.12, 0.88)) * n / cellules, (j + rng.randf_range(0.12, 0.88)) * n / cellules))
			off.append(rng.randf_range(0.35, 0.6))
			sx.append(rng.randf_range(-0.02, 0.02) * 2.0)
			sy.append(rng.randf_range(-0.026, 0.026) * 2.0)
			l0.append(rng.randf_range(0.46, 0.7))
			tint.append(rng.randf())
			ang.append(rng.randf_range(-0.3, 0.3))
			bande.append(rng.randf_range(4.5, 8.0) * e)
			dec.append(rng.randf() * 30.0 * e)
	var nc := gr.size()
	var cid := PackedInt32Array()
	cid.resize(n * n)
	var marge := PackedFloat32Array()
	marge.resize(n * n)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	var strat := PackedFloat32Array()
	strat.resize(n * n)
	var meso := fbm(n, n, 7, 7, 3, graine + 1)
	var grain := bruit(n, n, n / 2, n / 2, graine + 2)
	var fin := fbm(n, n, 16, 16, 3, graine + 3)
	var rupt := fbm(n, n, 8, 8, 2, graine + 9)
	var seuil_f := 0.42 + (1.0 - fissures) * 0.4
	var wx := fbm(n, n, 5, 5, 2, graine + 10)
	var wy := fbm(n, n, 5, 5, 2, graine + 11)
	for y in n:
		for x in n:
			var d1 := 1e9
			var d2 := 1e9
			var i1 := 0
			var qx := x + (wx[y * n + x] - 0.5) * 14.0 * e
			var qy := y + (wy[y * n + x] - 0.5) * 14.0 * e
			for k in nc:
				var dx := wrapf(qx - gr[k].x, -n * 0.5, n * 0.5)
				var dy := wrapf(qy - gr[k].y, -n * 0.5, n * 0.5) * 0.6
				var d := sqrt(dx * dx + dy * dy)
				if d < d1:
					d2 = d1
					d1 = d
					i1 = k
				elif d < d2:
					d2 = d
			var i := y * n + x
			cid[i] = i1
			marge[i] = d2 - d1
			var dx1 := wrapf(qx - gr[i1].x, -n * 0.5, n * 0.5)
			var dy1 := wrapf(qy - gr[i1].y, -n * 0.5, n * 0.5)
			var u := (-sin(ang[i1]) * dx1 + cos(ang[i1]) * dy1 + dec[i1]) / bande[i1]
			var f := fposmod(u, 1.0)
			strat[i] = 1.0 if f < 0.16 else (0.5 if f < 0.32 else 0.0)
			var ht := off[i1] + (sx[i1] * dx1 + sy[i1] * dy1) * PENTE_K * 0.18 / e
			ht += (meso[i] - 0.5) * 0.28 + (fin[i] - 0.5) * 0.12 + (grain[i] - 0.5) * 0.06
			ht -= strat[i] * 0.05
			var bord := minf(marge[i] / (5.0 * e), 1.0)
			ht = ht * (0.55 + 0.45 * sqrt(bord))
			if marge[i] < 0.75 * e and rupt[i] > seuil_f:
				ht = 0.0
			hf[i] = ht
	var lit := eclairage(hf, n, n, PENTE_K * e)
	var omb := ombres(hf, n, n, 0.16, e)
	var hb := flou(hf, n, n, 3 * e)
	var coul_a := rampe(K_PIERRE)
	var coul_b := rampe(K_PIERRE_CH)
	var coul_c := rampe(K_PIERRE_VERT)
	var coul_l := rampe(K_LICHEN)
	var coul_r := rampe(K_LICHEN_ROUX)
	var coul_n := rampe(K_NEIGE)
	var lk := fbm(n, n, 6, 6, 3, graine + 4)
	var lk2 := bruit(n, n, 14, 14, graine + 5)
	var sn := fbm(n, n, 4, 4, 3, graine + 6)
	var nm := PackedFloat32Array()
	nm.resize(n * n)
	for i in n * n:
		nm[i] = 1.0 if (lit[i] > 0.58 and not (marge[i] < 0.75 * e and rupt[i] > seuil_f) and sn[i] + (lit[i] - 0.58) * 0.7 > 0.56 / part_neige) else 0.0
	nm = flou(nm, n, n, e)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var c := cid[i]
			var joint := marge[i] < 0.75 * e and rupt[i] > seuil_f
			var ao := clampf(hb[i] - hf[i], 0.0, 0.3)
			var L := l0[c] + (lit[i] - 0.5) * 1.2 - ao * 0.8 + (meso[i] - 0.5) * 0.2 + (grain[i] - 0.5) * 0.12 - omb[i] * 0.1
			L += (strat[i] - 0.3) * -0.07
			L += clampf(marge[i] / 14.0 - 0.5, -0.4, 0.0) * 0.0
			if joint:
				L = 0.03 + grain[i] * 0.06
			elif marge[i] < 2.0 * e and lit[i] > 0.52:
				L += 0.12   # lèvre claire de la fracture
			var ix := ton_e(L, x, y, e, N, graine)
			var t := tint[c]
			var col := coul_a[ix].lerp(coul_b[ix], t * 0.55) if t < 0.65 else coul_a[ix].lerp(coul_c[ix], (t - 0.65) / 0.35 * 0.7)
			var m := lk[i] + (lk2[i] - 0.5) * 0.25
			if not joint and m > 0.7 and lit[i] > 0.3:
				col = coul_l[ton_e(L * 0.95 + 0.06, x, y, e, N, graine)] if lk2[i] < 0.8 else coul_r[ton_e(L * 0.95 + 0.04, x, y, e, N, graine)]
			if not joint and nm[i] > 0.5:
				col = coul_n[ton_e(0.7 + (lit[i] - 0.5) * 0.6 - omb[i] * 0.12 - ao * 0.6, x, y, e, N, graine)]
			img.set_pixel(x, y, col)
	return [img, relief_image(hf, n, n, PENTE_K * e)]

# --- bois : planches debout, rondins, bout de rondin ---------------------------------------------------------

## Planches debout (le shader ne tourne rien : `horizontal` les couche). Planches de 6 à 9 texels (19 à 28 cm),
## joint sombre, chanfrein (arête claire à gauche, ombre à droite), fil du bois ondulé, nœuds à anneaux, fentes,
## clous à tête claire, teinte qui va du brun chaud au gris argenté d'une planche à l'autre, coulures.
static func planches(graine: int, w := 128, h := 128, horizontal := false, e := 1, gris := 0.0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var larg := _decouper(rng, w, 6 * e, 9 * e)
	var bid := PackedInt32Array()
	bid.resize(w)
	var bx0 := PackedInt32Array()
	var bw := PackedInt32Array()
	var x := 0
	for k in larg.size():
		bx0.append(x)
		bw.append(larg[k])
		for j in larg[k]:
			bid[x + j] = k
		x += larg[k]
	var nb := larg.size()
	var l0 := PackedFloat32Array()
	var tint := PackedFloat32Array()
	var decal := PackedInt32Array()
	for k in nb:
		l0.append(rng.randf_range(0.46, 0.74))
		tint.append(rng.randf())
		decal.append(rng.randi_range(0, h - 1))
	var fib := bruit(w, h, w / 3, 4, graine + 1)
	var fib2 := bruit(w, h, w / 2, 9, graine + 2)
	var onde := bruit(w, h, 6, 6, graine + 3)
	var meso := fbm(w, h, 8, 8, 3, graine + 4)
	var grain := bruit(w, h, w / 2, h / 2, graine + 5)
	var strie := bruit(w, h, 40, 2, graine + 6)
	var hf := PackedFloat32Array()
	hf.resize(w * h)
	var ligne := PackedFloat32Array()   # variation de ton du fil
	ligne.resize(w * h)
	var joint := PackedByteArray()
	joint.resize(w * h)
	for y in h:
		for xx in w:
			var i := y * w + xx
			var xs := posmod(xx + int((onde[i] - 0.5) * 3.0 * e), w)
			var b := bid[xs]
			var u := float(xs - bx0[b]) + 0.5
			var du := minf(u, bw[b] - u)
			var g := fib[i] * 0.6 + fib2[i] * 0.4
			ligne[i] = g
			var jw := 1.0 if e == 1 else 1.5
			var prof := _sstep(0.9 * e, 2.0 * e, u) * (1.0 - 0.3 * _sstep(bw[b] - 2.0 * e, bw[b] - 0.5 * e, u))
			var ht := 0.5 * prof + 0.4 + (g - 0.5) * 0.22 + (grain[i] - 0.5) * 0.05
			if u < jw:
				joint[i] = 1
				ht = 0.0
			hf[i] = ht
	# nœuds, fentes, clous : sur le relief et sur la clarté
	var noeuds: Array = []
	for k in 3 + w / 64:
		var b := rng.randi_range(0, nb - 1)
		noeuds.append(Vector3(bx0[b] + bw[b] * 0.5, rng.randf_range(10 * e, h - 10 * e), b))
	var fentes: Array = []
	for k in 2 + w / 50:
		var b := rng.randi_range(0, nb - 1)
		fentes.append([bx0[b] + rng.randi_range(2 * e, maxi(bw[b] - 3 * e, 3 * e)), rng.randi_range(0, h - 1), rng.randi_range(10 * e, 30 * e), b])
	var clou := PackedByteArray()
	clou.resize(w * h)
	for b in nb:
		for yy in [(5 + decal[b] % 11) * e, h / 2 + (5 + decal[b] % 11) * e]:
			var kc := 2 if e == 1 else 3
			for dx in kc:
				for dy in kc:
					var cx: int = bx0[b] + bw[b] / 2 - kc / 2 + dx
					var cy: int = yy + dy
					clou[posmod(cy, h) * w + posmod(cx, w)] = 1 if (dx + dy < kc) else 2
	var ring := PackedFloat32Array()
	ring.resize(w * h)
	for nd: Vector3 in noeuds:
		for dy in range(-7 * e, 7 * e + 1):
			for dx in range(-4 * e, 4 * e + 1):
				var r := sqrt((dx / (3.4 * e)) * (dx / (3.4 * e)) + (dy / (6.0 * e)) * (dy / (6.0 * e)))
				if r < 1.0:
					var i := posmod(int(nd.y) + dy, h) * w + posmod(int(nd.x) + dx, w)
					if joint[i] == 0:
						ring[i] = 0.5 + 0.5 * cos(r * 9.0)
						hf[i] -= 0.1 * (1.0 - r) + 0.05 * ring[i]
	for ft: Array in fentes:
		var fx: float = ft[0]
		var fy: int = ft[1]
		for s in int(ft[2]):
			var i := posmod(fy + s, h) * w + posmod(int(round(fx + sin(s * 0.3 / e + ft[3]) * 0.8 * e)), w)
			if joint[i] == 0:
				hf[i] -= 0.4
				ring[i] = -1.0
	var lit := eclairage(hf, w, h, PENTE_K * e)
	var omb := ombres(hf, w, h, 0.16, e)
	var hb := flou(hf, w, h, 2 * e)
	var coul_a := rampe(K_BOIS)
	var coul_g := rampe(K_BOIS_GRIS)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for xx in w:
			var i := y * w + xx
			var xs := posmod(xx + int((onde[i] - 0.5) * 3.0 * e), w)
			var b := bid[xs]
			var ao := clampf(hb[i] - hf[i], 0.0, 0.5)
			var L := l0[b] + (lit[i] - 0.5) * 0.7 - ao * 0.7 + (ligne[i] - 0.5) * 0.42 + (meso[i] - 0.5) * 0.14
			L -= omb[i] * 0.1
			var s := strie[i]
			if s > 0.7:
				L -= (s - 0.7) * 0.4
			if ring[i] > 0.0:
				L -= 0.07 + ring[i] * 0.07
			elif ring[i] < 0.0:
				L = 0.08
			if clou[i] == 1:
				L = 0.82
			elif clou[i] == 2:
				L = 0.1
			if joint[i] == 1:
				L = 0.05 + grain[i] * 0.05
			var ix := ton_e(L, xx, y, e, N, graine)
			var t := tint[b]
			var col := coul_a[ix].lerp(coul_g[clampi(int(ix * 7.0 / (N - 1) + 0.5), 0, 7)], clampf(t * 1.15 - 0.15 + gris, 0.0, 0.85))
			img.set_pixel(xx, y, col)
	var rel := relief_image(hf, w, h, PENTE_K * e)
	if horizontal:
		return [_transposee(img), _transposee(rel, true)]
	return [img, rel]

static func _transposee(img: Image, relief := false) -> Image:
	var o := Image.create(img.get_height(), img.get_width(), false, img.get_format())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if relief:
				c = Color(c.g, c.r, c.b)   # u et v échangés
			o.set_pixel(y, x, c)
	return o

## Rondins : 4 bandes de 32 texels (≈ 1 m de pourtour d'un rondin de 28 cm) × 256 texels (8 m de long). Fil du
## bois dans le sens de la longueur, fentes de séchage, nœuds, plaques d'écorce, bords des bandes assombris
## (le rondin se creuse là où il rejoint le suivant). Pas de lumière dirigée cuite : l'éclairage vient de la
## géométrie (rondin à 8 pans) et du relief.
static func rondins(graine: int, w := 256, h := 128, e := 1, gris := 0.0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var bandes := 4
	var bh := h / bandes
	var fib := bruit(w, h, 10, h / 2, graine + 1)
	var fib2 := bruit(w, h, 24, h / 4, graine + 2)
	var onde := bruit(w, h, 5, bandes * 3, graine + 3)
	var meso := fbm(w, h, 8, 8, 3, graine + 4)
	var grain := bruit(w, h, w / 2, h / 2, graine + 5)
	var hf := PackedFloat32Array()
	hf.resize(w * h)
	var ring := PackedFloat32Array()
	ring.resize(w * h)
	var teinte := PackedFloat32Array()
	for b in bandes:
		teinte.append(rng.randf())
	for y in h:
		for x in w:
			var i := y * w + x
			var yb := y % bh
			var v := (yb + 0.5) / bh
			var edge := minf(v, 1.0 - v)
			var g := fib[i] * 0.55 + fib2[i] * 0.45
			hf[i] = 0.55 + (g - 0.5) * 0.28 + (meso[i] - 0.5) * 0.18 + (grain[i] - 0.5) * 0.05 - (0.35 * pow(1.0 - minf(edge * 6.0, 1.0), 2.0))
	# fentes de séchage longitudinales (2 à 3 par bande) + nœuds
	for b in bandes:
		for k in rng.randi_range(2, 3):
			var fy := b * bh + rng.randi_range(5, bh - 6)
			var fx := rng.randi_range(0, w - 1)
			var l := rng.randi_range(30 * e, 90 * e)
			for s in l:
				var yy := fy + int(round(sin(s * 0.09 / e + k) * 1.2 * e))
				var i := posmod(yy, h) * w + posmod(fx + s, w)
				var prof := minf(float(s), float(l - s)) / (6.0 * e)
				hf[i] -= 0.38 * clampf(prof, 0.0, 1.0)
				ring[i] = -clampf(prof, 0.0, 1.0)
		if rng.randf() < 0.9:
			var cx := rng.randi_range(8 * e, w - 9 * e)
			var cy := b * bh + rng.randi_range(9 * e, bh - 10 * e)
			for dy in range(-6 * e, 6 * e + 1):
				for dx in range(-8 * e, 8 * e + 1):
					var r := sqrt((dx / (7.5 * e)) * (dx / (7.5 * e)) + (dy / (5.5 * e)) * (dy / (5.5 * e)))
					if r < 1.0:
						var i := posmod(cy + dy, h) * w + posmod(cx + dx, w)
						ring[i] = maxf(ring[i], 0.5 + 0.5 * cos(r * 11.0))
						hf[i] -= 0.1 * (1.0 - r)
	var lit := eclairage(hf, w, h, 5.0 * e)
	var hb := flou(hf, w, h, 2 * e)
	var ecorce := fbm(w, h, 6, 6, 3, graine + 6)
	var coul_a := rampe(K_BOIS)
	var coul_g := rampe(K_BOIS_GRIS)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var b := y / bh
			var yb := y % bh
			var v := (yb + 0.5) / bh
			var edge := minf(v, 1.0 - v)
			var ao := clampf(hb[i] - hf[i], 0.0, 0.5)
			var L := 0.5 + (lit[i] - 0.5) * 0.6 - ao * 1.2 + (fib[i] * 0.55 + fib2[i] * 0.45 - 0.5) * 0.5 + (meso[i] - 0.5) * 0.2
			L -= (1.0 - minf(edge * 7.0, 1.0)) * 0.18
			if ring[i] > 0.0:
				L -= 0.05 + ring[i] * 0.09
			elif ring[i] < 0.0:
				L = lerpf(L, 0.1, -ring[i])
			var ix := ton_e(L, x, y, e, N, graine)
			var t := clampf(teinte[b] * 0.9 + (ecorce[i] - 0.5) * 0.7 - 0.1 + gris, 0.0, 0.9)
			img.set_pixel(x, y, coul_a[ix].lerp(coul_g[clampi(int(ix * 7.0 / (N - 1) + 0.5), 0, 7)], t))
	return [img, relief_image(hf, w, h, 5.0 * e)]

## Bout de rondin (64 texels/m : 32 × 32 = 0,5 m, le rondin de 28 cm est au centre) : cernes, fentes radiales,
## écorce sombre au bord.
static func bout_rondin(graine: int, n := 32) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	var gr := bruit(n, n, 4, 4, graine + 1)
	var grain := bruit(n, n, n / 2, n / 2, graine + 2)
	var coul_a := rampe(K_BOIS)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n * 0.5 - 0.5
	var fentes: Array[float] = []
	for k in 3:
		fentes.append(rng.randf() * TAU)
	for y in n:
		for x in n:
			var dx := x - c
			var dy := y - c
			var r := sqrt(dx * dx + dy * dy)
			var a := atan2(dy, dx)
			var cerne := 0.5 + 0.5 * sin(r * 1.55 + gr[y * n + x] * 3.0)
			var L := 0.62 - r * 0.012 + cerne * 0.14 - 0.1 * (gr[y * n + x] - 0.5) + (grain[y * n + x] - 0.5) * 0.08
			if r > 8.6:
				L = 0.22 + grain[y * n + x] * 0.12     # écorce
			elif r > 7.6:
				L -= 0.14
			for fa in fentes:
				if absf(angle_difference(a, fa)) < 0.09 and r < 8.0 and r > 1.0:
					L = 0.12
			hf[y * n + x] = 0.5 + cerne * 0.1
			img.set_pixel(x, y, coul_a[ton_e(L, x, y, 2, N, graine)])
	return [nettoie(img), relief_image(hf, n, n)]

# --- neige de toit -----------------------------------------------------------------------------------------

## Neige : houle large, rides du vent, creux à l'ombre bleutée, crêtes claires. 12 tons de la bible, de
## `#3a4469` (creux à l'ombre) à `#f0eff4`. Tuile 256 × 256 = 8 × 8 m.
static func neige(graine := 5501, n := 256, e := 1) -> Array:
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	var g1 := fbm(n, n, 3, 3, 4, graine + 1)
	var g2 := fbm(n, n, 4, 20, 3, graine + 2)    # rides étirées dans le sens x
	var g3 := bruit(n, n, n / 3, n / 3, graine + 3)
	for i in n * n:
		hf[i] = g1[i] * 0.6 + g2[i] * 0.3 + (g3[i] - 0.5) * 0.04
	var lit := eclairage(hf, n, n, 7.0 * e)
	var omb := ombres(hf, n, n, 0.2, e)
	var hb := flou(hf, n, n, 4 * e)
	var coul := rampe(K_NEIGE)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.7 + (lit[i] - 0.5) * 1.0 + (hf[i] - 0.5) * 0.3 - clampf(hb[i] - hf[i], 0.0, 0.3) * 1.2 - omb[i] * 0.12
			img.set_pixel(x, y, coul[ton_e(L, x, y, e, N, graine)])
	return [img, relief_image(hf, n, n, 7.0 * e)]

# --- fer, cuir, foin, tourbe, vitrage -----------------------------------------------------------------------

static func fer(graine: int, n := 64, e := 1) -> Array:
	n *= e
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var meso := fbm(n, n, 5, 5, 3, graine + 1)
	var grain := bruit(n, n, n / 2, n / 2, graine + 2)
	var piq := bruit(n, n, n / 2, n / 2, graine + 3)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	var raies := PackedFloat32Array()
	raies.resize(n * n)
	for i in n * n:
		hf[i] = 0.5 + (meso[i] - 0.5) * 0.4 + (grain[i] - 0.5) * 0.12 - (0.25 if piq[i] > 0.86 else 0.0)
	for k in 9:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		for s in rng.randi_range(8 * e, 22 * e):
			var i := posmod(y + s / 5, n) * n + posmod(x + s, n)
			raies[i] = 1.0
			hf[i] -= 0.08
	var lit := eclairage(hf, n, n, 5.0 * e)
	var coul := rampe(K_FER)
	var cr := rampe(K_ROUILLE, 8)
	var rl := fbm(n, n, 4, 4, 3, graine + 4)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.42 + (lit[i] - 0.5) * 0.8 + (meso[i] - 0.5) * 0.35 + (grain[i] - 0.5) * 0.12 + raies[i] * 0.16
			if piq[i] > 0.86:
				L -= 0.2
			var col := coul[ton_e(L, x, y, 2, N, graine)]
			if rl[i] > 0.6 and piq[i] > 0.45:
				col = cr[ton_e(0.35 + (lit[i] - 0.5) * 0.7 + (grain[i] - 0.5) * 0.2, x, y, 2, 8, graine)]
			img.set_pixel(x, y, col)
	return [img, relief_image(hf, n, n, 5.0 * e)]

static func cuir(graine: int, n := 64, e := 1) -> Array:
	n *= e
	var cell := bruit(n, n, 16, 16, graine + 1)
	var meso := fbm(n, n, 4, 4, 3, graine + 2)
	var grain := bruit(n, n, n / 2, n / 2, graine + 3)
	var plis := bruit(n, n, 3, 9, graine + 4)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	for i in n * n:
		hf[i] = 0.5 + (cell[i] - 0.5) * 0.3 + (meso[i] - 0.5) * 0.3 - (0.3 if absf(plis[i] - 0.5) < 0.03 else 0.0)
	var lit := eclairage(hf, n, n, 5.0 * e)
	var coul := rampe(K_CUIR)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.48 + (lit[i] - 0.5) * 0.9 + (meso[i] - 0.5) * 0.3 + (grain[i] - 0.5) * 0.1
			img.set_pixel(x, y, coul[ton_e(L, x, y, 2, N, graine)])
	return [img, relief_image(hf, n, n, 5.0 * e)]

static func foin(graine: int, n := 64, e := 1) -> Array:
	n *= e
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	hf.fill(0.3)
	var teinte := PackedFloat32Array()
	teinte.resize(n * n)
	teinte.fill(0.35)
	for k in n * 5:
		var x := rng.randf_range(0, n)
		var y := rng.randf_range(0, n)
		var pente := rng.randf_range(-0.6, 0.6)
		var l := rng.randi_range(8 * e, 20 * e)
		var t := rng.randf_range(0.3, 0.95)
		for s in l:
			var i := posmod(int(y + s), n) * n + posmod(int(round(x + pente * s)), n)
			hf[i] = maxf(hf[i], 0.3 + 0.5 * (1.0 - absf(s - l * 0.5) / (l * 0.5)) * t)
			teinte[i] = t
	var lit := eclairage(hf, n, n, 4.0 * e)
	var coul := rampe(K_CHAUME)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.32 + hf[i] * 0.55 + (lit[i] - 0.5) * 0.5 + (teinte[i] - 0.5) * 0.2
			img.set_pixel(x, y, coul[ton_e(L, x, y, 2, N, graine)])
	return [img, relief_image(hf, n, n, 4.0 * e)]

## Tourbe du bord de toit : terre sombre, racines et touffes d'herbe sèche pendantes.
static func tourbe(graine: int, n := 64, e := 1) -> Array:
	n *= e
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var meso := fbm(n, n, 5, 5, 3, graine + 1)
	var grain := bruit(n, n, n / 2, n / 2, graine + 2)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	var herbe := PackedFloat32Array()
	herbe.resize(n * n)
	for i in n * n:
		hf[i] = 0.4 + (meso[i] - 0.5) * 0.4 + (grain[i] - 0.5) * 0.15
	for k in n * 2:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		var pente := rng.randf_range(-0.5, 0.5)
		for s in rng.randi_range(5 * e, 14 * e):
			var i := posmod(y + s, n) * n + posmod(int(round(x + pente * s)), n)
			herbe[i] = 1.0
			hf[i] += 0.2
	var lit := eclairage(hf, n, n, 5.0 * e)
	var terre := rampe(K_TERRE)
	var chaume := rampe(K_CHAUME)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.4 + (lit[i] - 0.5) * 0.8 + (meso[i] - 0.5) * 0.35 + (grain[i] - 0.5) * 0.15
			var col := terre[ton_e(L, x, y, 2, N, graine)]
			if herbe[i] > 0.5:
				col = chaume[ton_e(0.28 + (lit[i] - 0.5) * 0.5 + (grain[i] - 0.5) * 0.2, x, y, 2, N, graine)]
			img.set_pixel(x, y, col)
	return [img, relief_image(hf, n, n, 5.0 * e)]

static func braises(graine: int, n := 32) -> Array:
	var cell := bruit(n, n, 6, 6, graine + 1)
	var fin := fbm(n, n, 8, 8, 3, graine + 2)
	var grain := bruit(n, n, n / 2, n / 2, graine + 3)
	var coul := rampe(K_BRAISE)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var chaud := cell[i] * 0.55 + fin[i] * 0.45
			var L := chaud * 1.15 - 0.12 + (grain[i] - 0.5) * 0.12
			if chaud < 0.34:
				L = 0.04 + chaud * 0.4        # croûte de cendre
			img.set_pixel(x, y, coul[ton_e(L, x, y, 2, 10, 7)])
	return [img, null]

## Vitrage d'une fenêtre de 0,55 × 0,36 m (18 × 12 texels, UV du quad) : deux carreaux de verre chaud à
## plomb, éclat plus clair en haut à gauche, bas plus sombre ; le meneau de bois est un ton sombre.
static func fenetre() -> Array:
	var w := 18
	var h := 12
	var coul := rampe(K_BRAISE)
	var bois := rampe(K_BOIS)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var col: Color
			if x == 8 or x == 9:
				col = bois[ton_e(0.32 + (0.15 if x == 8 else 0.0), x, y, 2)]
			else:
				var px := x if x < 8 else x - 10
				var d := absf(px - 3.5) / 4.2 + absf(y - 5.0) / 7.0
				var L := 1.04 - d * 0.5 - (0.12 if y > 8 else 0.0)
				if px == 0 or y == 0:
					L -= 0.18
				col = coul[ton_e(L, x, y, 2, 10, 7)]
			img.set_pixel(x, y, col)
	return [img, null]

# --- mipmaps « vote de couleur » (aucune couleur nouvelle) -------------------------------------------------------

static func avec_mips(img: Image, relief: Image = null) -> ImageTexture:
	var niveaux: Array[Image] = [img]
	var cur := img
	while cur.get_width() > 1 or cur.get_height() > 1:
		var w := maxi(cur.get_width() / 2, 1)
		var h := maxi(cur.get_height() / 2, 1)
		var nxt := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var cnt := {}
				for dy in 2:
					for dx in 2:
						var c := cur.get_pixel(mini(x * 2 + dx, cur.get_width() - 1), mini(y * 2 + dy, cur.get_height() - 1))
						cnt[c] = int(cnt.get(c, 0)) + 1
				var best := Color.BLACK
				var bn := 0
				for c: Color in cnt:
					if int(cnt[c]) > bn or (int(cnt[c]) == bn and c.get_luminance() < best.get_luminance()):
						bn = int(cnt[c])
						best = c
				nxt.set_pixel(x, y, best)
		niveaux.append(nxt)
		cur = nxt
	var data := PackedByteArray()
	for n in niveaux:
		data.append_array(n.get_data())
	return ImageTexture.create_from_image(Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data))

static func relief_mips(rel: Image) -> ImageTexture:
	var r := rel.duplicate() as Image
	r.generate_mipmaps()
	return ImageTexture.create_from_image(r)

static func _net(r: Array) -> Array:
	nettoie(r[0])
	return r

## Liste des textures cuites : nom → fabrique (renvoie [albédo, relief|null]).
static func fabriques() -> Dictionary:
	var base := {
		"pierre_seche": func() -> Array: return mur_pierre(5111, 256, 128, 9, 15, 15, 34, 0.12),
		"pierre_fine": func() -> Array: return mur_pierre(5113, 256, 128, 6, 10, 9, 20, 0.06, 2.0),
		"roche": func() -> Array: return roche(5211),
		"pierre_brute": func() -> Array: return roche(5217, 128, 3, 0.4, 0.2),
		"planches_v": func() -> Array: return planches(5311),
		"planches_h": func() -> Array: return planches(5312, 128, 128, true),
		"rondins": func() -> Array: return rondins(5321),
		"bout_rondin": func() -> Array: return bout_rondin(5322),
		"neige": func() -> Array: return neige(),
		"fer": func() -> Array: return _net(fer(5411)),
		"cuir": func() -> Array: return _net(cuir(5412)),
		"foin": func() -> Array: return _net(foin(5413)),
		"tourbe": func() -> Array: return _net(tourbe(5414)),
		"braises": func() -> Array: return _net(braises(5415)),
		"fenetre": func() -> Array: return _net(fenetre()),
	}
	# Passe « extérieur à 64 texels/m » (`_e`, lues avec texels_par_m = 64) : génération native à 2× la résolution (mêmes
	# dimensions en mètres), tramage par bruit, nettoyage des texels isolés. Les anciennes (32 texels/m) restent pour
	# les rochers, le tertre, l'intérieur (fer, cuir, foin) qui les lisent encore.
	base["pierre_seche_e"] = func() -> Array: return _net(mur_pierre(5111, 512, 256, 16, 28, 30, 68, 0.12, 6.0, 2))
	# murs de soutènement (D/neige_murs) : pierre chaude, assises de 0,22 à 0,7 m, pierres de 0,35 à 1,6 m, rangs inclinés
	base["pierre_mur_e"] = func() -> Array: return _net(mur_pierre(5119, 512, 256, 14, 44, 22, 104, 0.10, 7.0, 2, true, 0.45))
	# murs des maisons en pierre, tour, murets, pont (E/pierre_chaude) : même pierre chaude que les soutènements, assises
	# plus régulières de maçonnerie (0,25 à 0,44 m, pierres de 0,45 à 1,1 m, rangs peu inclinés)
	base["pierre_maison_e"] = func() -> Array: return _net(mur_pierre(5121, 512, 256, 16, 28, 28, 70, 0.10, 6.0, 2, true, 0.12))
	base["pierre_fine_e"] = func() -> Array: return _net(mur_pierre(5113, 512, 256, 12, 20, 18, 40, 0.06, 4.0, 2))
	base["pierre_brute_e"] = func() -> Array: return _net(roche(5217, 256, 3, 0.4, 0.2, 2))
	base["planches_v_e"] = func() -> Array: return _net(planches(5311, 256, 256, false, 2, 0.3))
	base["planches_h_e"] = func() -> Array: return _net(planches(5312, 256, 256, true, 2, 0.3))
	base["rondins_e"] = func() -> Array: return _net(rondins(5321, 512, 256, 2, 0.3))
	base["neige_e"] = func() -> Array: return _net(neige(5501, 512, 2))
	base["fer_e"] = func() -> Array: return _net(fer(5411, 64, 2))
	base["cuir_e"] = func() -> Array: return _net(cuir(5412, 64, 2))
	base["foin_e"] = func() -> Array: return _net(foin(5413, 64, 2))
	base["tourbe_e"] = func() -> Array: return _net(tourbe(5414, 64, 2))
	base.merge(PeintureInterieur.fabriques())   # lot « intérieurs » : tentures, peaux, terre battue, charbon, vitrage
	return base

const DOSSIER := "res://assets/bati/"

## Écrit toutes les textures cuites (`assets/bati/<nom>.res` et `<nom>_relief.res`).
static func cuire(noms: Array = []) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	var f := fabriques()
	for nom: String in f:
		if not noms.is_empty() and not noms.has(nom):
			continue
		var t0 := Time.get_ticks_msec()
		var r: Array = (f[nom] as Callable).call()
		var tex := avec_mips(r[0])
		ResourceSaver.save(tex, DOSSIER + nom + ".res")
		if r[1] != null:
			ResourceSaver.save(relief_mips(r[1]), DOSSIER + nom + "_relief.res")
		print("cuit %s (%d ms)" % [nom, Time.get_ticks_msec() - t0])
