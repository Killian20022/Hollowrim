class_name TexturesArbres
## Lot 2 (arbres) : textures pixel art des arbres, dessinées par code avec des amas délibérés
## (jamais de bruit), dans les rampes de docs/BIBLE_VISUELLE.md. Chaque texture a son propre RNG
## (graine fixe) : aucun effet sur `monde.rng` ni sur le RNG partagé de Palette.
## Les cartes de feuillage ont des mipmaps « pixel art » (réduction par vote de couleur, couverture
## conservée) : à distance les rameaux ne se dissolvent pas et ne scintillent pas.

const AIGUILLES := ["#08161a", "#10272a", "#1a3d32", "#2c5a41", "#5b866f", "#6e9172"]
const ECORCE := ["#241a22", "#3a2a2a", "#54402f", "#735b43", "#947c5e"]
const PIN := ["#3b1f24", "#6a3524", "#9c5129", "#cf7b3c", "#ecaa62"]
const BOULEAU := ["#17151d", "#3f3d4c", "#787f9e", "#a9aec4", "#d6d8e2", "#f4f0e8"]
const BOIS_MORT := ["#3d3c4a", "#5b5a66", "#7f7d82", "#a7a19b"]
const NEIGE := ["#4a557f", "#6877a3", "#8898bf", "#aab8d6", "#cdd7ec", "#f0eff4"]
const CLEAR := Color(0, 0, 0, 0)

## Taille des atlas pin / bouleau (uv_region par défaut).
const ATLAS := 128
## Régions de l'atlas des épicéas (256×256, rameaux longs à 128 px : détail du gros plan), en pixels.
const ATLAS_EPICEA := 256
const R_LONG_A := Rect2i(0, 0, 128, 128)
const R_LONG_B := Rect2i(128, 0, 128, 128)
const R_COURT_A := Rect2i(0, 128, 64, 64)
const R_COURT_B := Rect2i(64, 128, 64, 64)
const R_FLECHE := Rect2i(0, 192, 64, 64)
const R_COEUR := Rect2i(64, 192, 64, 64)
const R_CRETE_X := 128         # crêtes de neige : bandes CRETE_W×CRETE_H en (128, 128 + CRETE_H·k)
const R_CRETE_Y := 128
const CRETE_W := 128
const CRETE_H := 16
const CRETES := 8

const DOSSIER := "res://assets/arbres"   # atlas précalculés par outils/generer_arbres.gd (outils/precalculer_tout.gd)
const VERSION := 1                        # à incrémenter à chaque changement de dessin : les .res périmés sont ignorés
const PRECALCULES := ["atlas_epicea", "atlas_pin", "atlas_bouleau"]

static var _cache := {}

## Texture lue dans assets/arbres/<nom>.res si le fichier existe ET porte la VERSION courante, sinon null (repli : calcul).
static func _precalcule(nom: String) -> ImageTexture:
	var chemin := "%s/%s.res" % [DOSSIER, nom]
	if not ResourceLoader.exists(chemin):
		return null
	var img := ResourceLoader.load(chemin) as Image
	if img == null or img.get_meta("version", -1) != VERSION:
		return null
	return ImageTexture.create_from_image(img)

## Image finale (avec mipmaps) d'un atlas précalculable : calcul direct, sans lire le disque.
static func image_precalculee(nom: String) -> Image:
	match nom:
		"atlas_epicea": return mips_image(atlas_epicea_image())
		"atlas_pin": return mips_image(rameau_pin(801, 0.7))
		"atlas_bouleau": return mips_image(ramilles_bouleau(901), 2)
	return null

static func _c(rampe: Array, i: int) -> Color:
	return Color(rampe[clampi(i, 0, rampe.size() - 1)])

# ------------------------------------------------------------------ outils d'image
static func _px(img: Image, x: int, y: int, c: Color, wrap := false) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if wrap:
		x = posmod(x, w)
		y = posmod(y, h)
	elif x < 0 or y < 0 or x >= w or y >= h:
		return
	img.set_pixel(x, y, c)

static func _ligne(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, wrap := false) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_px(img, x0, y0, c, wrap)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

static func _est_neige(c: Color) -> bool:
	return c.b > c.r + 0.05 and c.get_luminance() > 0.4

## Filtre « mode » : un pixel sans voisin de même couleur prend la couleur dominante (pas de sel-et-poivre).
static func _lisser(img: Image, wrap: bool, seuil := 2) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var meme := 0
			var cnt := {}
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if wrap:
					nx = posmod(nx, w)
					ny = posmod(ny, h)
				elif nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n := src.get_pixel(nx, ny)
				if n.a == 0.0:
					continue
				if n == c:
					meme += 1
				cnt[n] = int(cnt.get(n, 0)) + 1
			if meme < 1:
				var best := c
				var bn := 0
				for k in cnt:
					if cnt[k] > bn:
						bn = cnt[k]
						best = k
				if bn >= seuil:
					img.set_pixel(x, y, best)

## Sprite : pixels orphelins supprimés, petits trous bouchés (couleur la plus sombre des voisins).
static func _nettoyer(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for passe in 2:
		var src := img.duplicate() as Image
		for y in h:
			for x in w:
				var c := src.get_pixel(x, y)
				var voisins := 0
				var d4 := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
							voisins += 1
							if dx == 0 or dy == 0:
								d4 += 1
				if c.a > 0.0 and voisins <= 1:
					img.set_pixel(x, y, CLEAR)
				elif c.a == 0.0 and d4 >= 3:
					var best := Color(1, 1, 1, 1)
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx := x + d.x
						var ny := y + d.y
						if nx >= 0 and ny >= 0 and nx < w and ny < h:
							var n := src.get_pixel(nx, ny)
							if n.a > 0.0 and n.get_luminance() < best.get_luminance():
								best = n
					img.set_pixel(x, y, best)

## Mipmaps pixel art : chaque bloc 2×2 devient opaque si au moins 2 pixels le sont, avec la couleur
## la plus fréquente (à égalité : la plus sombre, pour garder la masse). Aucune couleur hors palette,
## pas de fondu d'alpha : la carte garde sa silhouette à distance.
static func avec_mips(img: Image, seuil := 2) -> ImageTexture:
	return ImageTexture.create_from_image(mips_image(img, seuil))

## Image finale (RGBA8, chaîne de mipmaps incluse) : ce que `avec_mips` met dans la texture, et ce que
## `outils/generer_arbres.gd` précalcule.
static func mips_image(img: Image, seuil := 2) -> Image:
	var niveaux: Array[Image] = [img]
	var cur := img
	while cur.get_width() > 1 and cur.get_height() > 1:
		var w := cur.get_width() / 2
		var h := cur.get_height() / 2
		var nxt := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var cnt := {}
				var opaques := 0
				for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var c := cur.get_pixel(x * 2 + d.x, y * 2 + d.y)
					if c.a > 0.5:
						opaques += 1
						cnt[c] = int(cnt.get(c, 0)) + 1
				if opaques >= seuil:
					var best := Color.BLACK
					var bn := 0
					for k: Color in cnt:
						if cnt[k] > bn or (cnt[k] == bn and k.get_luminance() < best.get_luminance()):
							bn = cnt[k]
							best = k
					best.a = 1.0
					nxt.set_pixel(x, y, best)
				else:
					nxt.set_pixel(x, y, CLEAR)
		niveaux.append(nxt)
		cur = nxt
	var data := PackedByteArray()
	for n in niveaux:
		data.append_array(n.get_data())
	return Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data)

## Mipmaps d'une tuile opaque (écorce) : vote de couleur 2×2, sans transparence.
static func tuile_mips(img: Image) -> ImageTexture:
	return avec_mips(img)

# ------------------------------------------------------------------ rameau d'épicéa (vu de dessus)
## Rameau S×S (S = 128 pour les longs, 64 pour les courts), vu de dessus, base en bas (côté tronc),
## pointe en haut. La tige principale suit l'axe vertical (colonnes S/2-1 et S/2 : la carte est
## légèrement pliée le long de cette ligne) et se ramifie : 2 sous-rameaux majeurs près de la base,
## puis des rameaux secondaires alternés, eux-mêmes ramifiés. Les aiguilles sont des TOUFFES de traits
## courts parallèles, orientés vers l'avant le long de chaque rameau (pas un semis) ; leurs bouts font le
## bord dentelé. Lumière de la texture : haut-gauche (face claire / face sombre de chaque touffe).
## `neige` 0..1 : quantité de neige ; `densite` 0..1 : remplissage (1 = touffu).
static func rameau_epicea(S: int, graine: int, neige: float, densite: float) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var k := S / 64.0
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	var cx := S * 0.5 - 0.5
	var axes: Array = []      # {"pts": [Vector2], "dirs": [Vector2], "prof": int}
	var base := Vector2(cx, S - 2.0)
	_axe_rameau(axes, rng, base, Vector2(0, -1), S - 4.0 - 2.0 * k, 0, k, densite, S)
	# --- aiguilles : touffes de 2-3 traits parallèles de part et d'autre de chaque rameau
	var lumiere := Vector2(-0.6, -0.8)
	var traits: Array = []
	for ax: Dictionary in axes:
		var pts: Array = ax["pts"]
		var dirs: Array = ax["dirs"]
		var prof: int = ax["prof"]
		var n := pts.size()
		var pas := maxi(2, int(round(1.6 * k)))
		var ph := rng.randf() * TAU
		var j := 1 if prof == 0 else 0
		while j < n:
			var s := float(j) / maxf(n - 1, 1)
			var p: Vector2 = pts[j]
			var d: Vector2 = dirs[j]
			var amas := 0.5 + 0.5 * sin(j * 0.55 + ph)
			for cote in [-1.0, 1.0]:
				if prof == 0 and rng.randf() < 0.45:
					continue    # la tige principale reste lisible par endroits
				var ang: float = deg_to_rad(rng.randf_range(38.0, 52.0)) * cote
				var v := d.rotated(ang)
				var L := (1.5 + 1.15 * k) * (1.0 - 0.4 * s) * lerpf(0.8, 1.15, amas)
				if prof == 0:
					L *= 0.8
				if rng.randf() > lerpf(0.75, 0.95, densite):
					L *= 0.55
				var dl := v.dot(lumiere)
				# rampe remontée côté lumière : le fond est le ton 2, la lumière le ton 3, l'ombre franche le ton 1
				var ton := 2
				if dl > 0.2 and amas > 0.3:
					ton = 3
				elif dl < -0.35 or amas < 0.2:
					ton = 0 if amas < 0.06 else 1
				var givre := prof == 2 and s > 0.8 and dl > 0.2 and rng.randf() < 0.3
				var nb := 3 + (1 if amas > 0.55 else 0)
				for t in nb:
					var q := p + d * (t * 1.0 - 0.5) + v.orthogonal() * 0.0
					var e := q + v * (L - t * 0.6)
					traits.append([4 if givre and t == 0 else ton, q.x, q.y, e.x, e.y])
			j += pas
	traits.sort_custom(func(u, w): return u[0] < w[0])
	for t in traits:
		_ligne(img, roundi(t[1]), roundi(t[2]), roundi(t[3]), roundi(t[4]), _c(AIGUILLES, t[0]))
	# --- bois : tige principale brune, sous-rameaux bruns au cœur, rameaux fins sombres (ombre)
	for ax: Dictionary in axes:
		var pts: Array = ax["pts"]
		var prof: int = ax["prof"]
		var n := pts.size()
		var fin := n if prof == 0 else int(n * (0.6 if prof == 1 else 0.35))
		for j in fin:
			var p: Vector2 = pts[j]
			var s := float(j) / maxf(n - 1, 1)
			if prof == 0:
				_px(img, roundi(p.x), roundi(p.y), _c(ECORCE, 1))
				if s < 0.55:
					_px(img, roundi(p.x) + 1, roundi(p.y), _c(ECORCE, 1))
			elif prof == 1:
				_px(img, roundi(p.x), roundi(p.y), _c(ECORCE, 1))
			else:
				_px(img, roundi(p.x), roundi(p.y), _c(ECORCE, 1 if j < fin * 0.6 else 0))
	# --- neige : paquets allongés posés sur le cœur des rameaux (amas francs), ombrés côté base
	if neige > 0.0:
		var cases: Array = []
		for ax: Dictionary in axes:
			var pts: Array = ax["pts"]
			var dirs: Array = ax["dirs"]
			var prof: int = ax["prof"]
			var n := pts.size()
			if n < 5:
				continue
			var proba := neige * (0.9 if prof < 2 else 0.4)
			var nb_paquets := 2 if prof == 0 else 1
			for pk in nb_paquets:
				if rng.randf() > proba:
					continue
				var j0: int
				var j1: int
				if prof == 0:
					j0 = int(n * (0.1 + 0.3 * pk + rng.randf_range(0.0, 0.08)))
					j1 = mini(n - 2, j0 + int(n * rng.randf_range(0.1, 0.18)) + 2)
				else:
					j0 = int(rng.randf_range(0.05, 0.25) * n)
					j1 = mini(n - 2, j0 + int(rng.randf_range(0.18, 0.4) * n) + 2)
				# amas irrégulier : taille propre à chaque paquet, bord qui ondule (deux ondes déphasées),
				# interruptions (le paquet se coupe en deux lobes), grumeaux isolés sur le flanc haut
				var emax := (0.7 + (1.5 if prof < 2 else 0.7) * neige * k) * rng.randf_range(0.55, 1.15)
				var ph1 := rng.randf() * TAU
				var ph2 := rng.randf() * TAU
				var coupe := rng.randf_range(0.35, 0.7) if (j1 - j0 > 9 and rng.randf() < 0.5) else -1.0
				for jj in range(j0, j1 + 1):
					var p: Vector2 = pts[jj]
					var d: Vector2 = dirs[jj]
					var nrm := d.orthogonal()
					var u := (float(jj - j0) / maxf(j1 - j0, 1)) * 2.0 - 1.0
					var prof_u := sqrt(maxf(1.0 - u * u, 0.0))
					var ond := 0.55 * sin(jj * 0.9 + ph1) + 0.4 * sin(jj * 2.1 + ph2)
					if coupe > 0.0 and absf((u + 1.0) * 0.5 - coupe) < 0.07:
						prof_u *= 0.25
					var e_h := int(round(emax * prof_u + ond * prof_u))     # demi-largeur côté lumière (haut)
					var e_b := int(round(emax * prof_u * 0.8 - ond * 0.5 * prof_u))  # côté bas : plus court
					for dd in range(-e_b, e_h + 1):
						var q := p + nrm * dd
						var bas := (nrm * dd).y > 0.3
						var ton := 4
						if dd == e_h and e_h > 0:
							ton = 5 if (not bas and ond > 0.1) else 4
						elif dd == -e_b and e_b > 0:
							ton = 3 if bas else 4
						elif bas and dd <= -e_b + 1:
							ton = 3
						cases.append([roundi(q.x), roundi(q.y), ton])
					# ombre portée sous le paquet (côté base de l'image), seulement là où il déborde
					if e_b > 0 and ond > -0.4:
						var sous := p + Vector2(0, e_b + 1)
						cases.append([roundi(sous.x), roundi(sous.y), 2])
		cases.sort_custom(func(a, b): return a[2] < b[2])
		for c in cases:
			_px(img, c[0], c[1], _c(NEIGE, c[2]))
	_nettoyer(img)
	_lisser(img, false)
	# contour sélectif : bord côté base des masses d'aiguilles plus sombre (épaisseur du rameau)
	var src := img.duplicate() as Image
	for yy in range(0, S - 1):
		for xx in S:
			var c := src.get_pixel(xx, yy)
			if c.a > 0.0 and src.get_pixel(xx, yy + 1).a == 0.0 and not _est_neige(c):
				img.set_pixel(xx, yy, _c(AIGUILLES, 1))
	return img

## Un axe du rameau (récursif) : avance pixel par pixel en se courbant vers la pointe (y-), pose ses
## enfants en alterné. prof 0 = tige, 1 = sous-rameau majeur, 2 = rameau fin (sans enfant).
static func _axe_rameau(axes: Array, rng: RandomNumberGenerator, p0: Vector2, d0: Vector2, L: float, prof: int, k: float, densite: float, S: int) -> void:
	var pts: Array = []
	var dirs: Array = []
	var p := p0
	var d := d0.normalized()
	var n := maxi(int(L), 3)
	var avant := Vector2(0, -1)
	for s in n:
		# reste dans la carte : marge de 3 px pour les aiguilles
		if p.x < 3.0 or p.x > S - 4.0 or p.y < 3.0:
			break
		pts.append(p)
		dirs.append(d)
		if prof > 0:
			d = (d + avant * 0.025).normalized()
		p += d
	axes.append({"pts": pts, "dirs": dirs, "prof": prof})
	if prof == 2 or pts.size() < 6:
		return
	var m := pts.size()
	var cote := -1.0 if rng.randf() < 0.5 else 1.0
	if prof == 0:
		# deux sous-rameaux majeurs (la tige se ramifie), puis des rameaux fins alternés
		var j_maj := [int(m * rng.randf_range(0.14, 0.2)), int(m * rng.randf_range(0.3, 0.38))]
		for q in 2:
			var j: int = j_maj[q]
			var c := cote if q == 0 else -cote
			var dd: Vector2 = (dirs[j] as Vector2).rotated(deg_to_rad(rng.randf_range(34.0, 42.0)) * c)
			_axe_rameau(axes, rng, pts[j], dd, (m - j) * rng.randf_range(0.6, 0.7), 1, k, densite, S)
		var j2 := int(m * 0.42)
		var ecart := lerpf(7.5, 6.0, densite) * k * 0.5
		while j2 < m - 3:
			var t := float(j2) / m
			var dd: Vector2 = (dirs[j2] as Vector2).rotated(deg_to_rad(lerpf(55.0, 38.0, t) + rng.randf_range(-5, 5)) * cote)
			var Lc := ((m - j2) * 0.5 + 2.0 * k) * rng.randf_range(0.8, 1.0)
			_axe_rameau(axes, rng, pts[j2], dd, Lc, 2, k, densite, S)
			cote = -cote
			j2 += maxi(2, int(ecart * rng.randf_range(0.85, 1.15)))
		# quelques rameaux fins à la base, entre les deux sous-rameaux majeurs
		for j in [int(m * 0.06), int(m * 0.25)]:
			var dd: Vector2 = (dirs[j] as Vector2).rotated(deg_to_rad(rng.randf_range(60.0, 70.0)) * cote)
			_axe_rameau(axes, rng, pts[j], dd, m * 0.22 * rng.randf_range(0.8, 1.0), 2, k, densite, S)
			cote = -cote
	else:
		var j := 3
		var ecart := lerpf(7.0, 5.5, densite) * k * 0.5
		while j < m - 3:
			var t := float(j) / m
			var dd: Vector2 = (dirs[j] as Vector2).rotated(deg_to_rad(lerpf(52.0, 36.0, t) + rng.randf_range(-6, 6)) * cote)
			var Lc := ((m - j) * 0.48 + 1.5 * k) * rng.randf_range(0.75, 1.0)
			_axe_rameau(axes, rng, pts[j], dd, Lc, 2, k, densite, S)
			cote = -cote
			j += maxi(2, int(ecart * rng.randf_range(0.85, 1.15)))

## Flèche (sommet) vue de côté, S×S : tige dressée, courtes branches relevées, capuchon de neige.
static func fleche_epicea(S: int, graine: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	var cx := S / 2
	for y in range(2, S):
		var t := float(y) / S    # 0 haut → 1 bas
		var demi := int(round(lerpf(0.5, S * 0.42, pow(t, 1.1))))
		# étages de petites branches relevées
		if y % 4 == 1 or y < 4:
			for c in [-1, 1]:
				var L := demi + rng.randi_range(-1, 1)
				_ligne(img, cx, y + 2, cx + c * L, y, _c(AIGUILLES, 2 if c < 0 else 3))
				_ligne(img, cx, y + 3, cx + c * (L - 1), y + 2, _c(AIGUILLES, 1))
		_px(img, cx, y, _c(ECORCE, 1))
		if t > 0.6:
			_px(img, cx - 1, y, _c(ECORCE, 0))
	# neige : petits chapeaux sur les étages
	for y in range(3, S - 2, 4):
		var demi := int(round(lerpf(0.5, S * 0.42, pow(float(y) / S, 1.1)) * 0.5))
		for dx in range(-demi, demi + 1):
			if rng.randf() < 0.75:
				_px(img, cx + dx, y - 1, _c(NEIGE, 4 if absi(dx) < demi else 3))
	_px(img, cx, 1, _c(NEIGE, 4))
	_px(img, cx, 2, _c(NEIGE, 3))
	_nettoyer(img)
	_lisser(img, false)
	return img

## Crête de neige posée sur un rameau, vue de côté : bande 64×8 (×f), amas irréguliers (longueurs 4 à 17 px,
## sommet décentré, flancs qui ondulent), interruptions, dessous en dents de scie : jamais des « gélules » régulières.
static func crete_neige(graine: int, f := 1) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var W := 64 * f
	var H := 8 * f
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	var x := rng.randi_range(0, 6) * f
	var bas0 := rng.randi_range(5, 7) * f + (f - 1)
	while x < W - 3 * f:
		var grand := rng.randf() < 0.3
		var L := (rng.randi_range(11, 17) if grand else rng.randi_range(4, 10)) * f
		var hmax := (rng.randf_range(3.5, 5.5) if grand else rng.randf_range(1.5, 3.2)) * f
		var pic := rng.randf_range(0.2, 0.75)
		var bas := bas0
		var bruit := 0.0
		for d in L:
			if x + d >= W - 1:
				break
			var u := float(d) / L
			var prof := pow(u / pic, 0.65) if u < pic else pow((1.0 - u) / (1.0 - pic), 0.9)
			if d % f == 0:
				bruit = clampf(bruit + rng.randf_range(-0.9, 0.9), -1.3, 1.3)   # flanc qui ondule, par paliers
			var h := int(round(hmax * prof + bruit * f * 0.5)) + 1
			if d % (3 * f) == 0 and rng.randf() < 0.45:
				bas = clampi(bas0 + rng.randi_range(-1, 0) * f, 0, H - 1)       # dents sous la crête
			var top := bas - h
			for yy in range(top, bas + 1):
				var ton := 4
				if yy == top:
					ton = 5 if (u < pic and h > 2 * f) else 4
				elif yy >= bas - f:
					ton = 2
				elif yy >= bas - 2 * f:
					ton = 3
				_px(img, x + d, yy, _c(NEIGE, ton))
		x += L + rng.randi_range(1, 7) * f
	_nettoyer(img)
	return img

## Atlas des épicéas 256×256 (voir les régions R_*), avec mipmaps pixel art.
static func atlas_epicea() -> ImageTexture:
	if _cache.has("atlas_epicea"):
		return _cache["atlas_epicea"]
	var t := _precalcule("atlas_epicea")
	if t == null:
		t = avec_mips(atlas_epicea_image())
	_cache["atlas_epicea"] = t
	return t

static func atlas_epicea_image() -> Image:
	var img := Image.create(ATLAS_EPICEA, ATLAS_EPICEA, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	img.blit_rect(rameau_epicea(128, 501, 0.75, 1.0), Rect2i(0, 0, 128, 128), R_LONG_A.position)
	img.blit_rect(rameau_epicea(128, 502, 0.95, 0.85), Rect2i(0, 0, 128, 128), R_LONG_B.position)
	img.blit_rect(rameau_epicea(64, 503, 0.8, 1.0), Rect2i(0, 0, 64, 64), R_COURT_A.position)
	img.blit_rect(rameau_epicea(64, 504, 0.95, 0.9), Rect2i(0, 0, 64, 64), R_COURT_B.position)
	img.blit_rect(fleche_epicea(64, 505), Rect2i(0, 0, 64, 64), R_FLECHE.position)
	img.blit_rect(rameau_epicea(64, 506, 0.0, 1.0), Rect2i(0, 0, 64, 64), R_COEUR.position)
	for k in CRETES:
		img.blit_rect(crete_neige(510 + k, 2), Rect2i(0, 0, CRETE_W, CRETE_H), Vector2i(R_CRETE_X, R_CRETE_Y + CRETE_H * k))
	return img

## Rectangle UV (0..1) d'une région d'un atlas de côté `taille`.
static func uv_region(r: Rect2i, taille := ATLAS) -> Rect2:
	return Rect2(Vector2(r.position) / taille, Vector2(r.size) / taille)

## Rectangle UV d'une région de l'atlas des épicéas.
static func uv_epicea(r: Rect2i) -> Rect2:
	return uv_region(r, ATLAS_EPICEA)

# ------------------------------------------------------------------ écorces (tuiles 32×32)
static func _onde(x: float, y: float, n: int, fx: int, fy: int, ph: float) -> float:
	return sin(TAU * (float(fx * x + fy * y) / n) + ph)

## Écorce d'épicéa : plaques verticales séparées par des sillons sinueux, cassures décalées, givre.
static func ecorce_epicea_image() -> Image:
	var N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var plaques := 4
	var bases := [2, 3, 1, 3]
	for y in N:
		for x in N:
			var w := 1.3 * _onde(x, y, N, 0, 1, 0.9) + 0.6 * _onde(x, y, N, 0, 2, 2.4)
			var u := (x + w) / N * plaques
			var cell := posmod(int(floor(u)), plaques)
			var f: float = u - floor(u)
			var base: int = bases[cell]
			var ton := base
			if f < 0.12 or f > 0.93:
				ton = 0
			elif f < 0.26:
				ton = maxi(base - 1, 0)
			elif f > 0.52 and f < 0.72:
				ton = mini(base + 1, 4)
			if ton != 0 and (y == (cell * 9 + 5) % N or y == (cell * 13 + 20) % N):
				ton = 0
			elif ton != 0 and (y == (cell * 9 + 6) % N or y == (cell * 13 + 21) % N):
				ton = mini(base + 1, 4)
			img.set_pixel(x, y, _c(ECORCE, ton))
	for p: Vector2i in [Vector2i(5, 7), Vector2i(14, 21), Vector2i(23, 12), Vector2i(29, 27), Vector2i(10, 29)]:
		for j in 3:
			_px(img, p.x + j, p.y, _c(ECORCE, 0), true)
		_px(img, p.x + 1, p.y + 1, _c(ECORCE, 4), true)
	for p: Vector2i in [Vector2i(18, 4), Vector2i(7, 17), Vector2i(26, 20)]:
		for j in 2:
			_px(img, p.x, p.y + j, _c(ECORCE, 4), true)
		_px(img, p.x + 1, p.y, _c(ECORCE, 4), true)
	_lisser(img, true)
	return img

static func ecorce_epicea() -> ImageTexture:
	if not _cache.has("ecorce_epicea"):
		_cache["ecorce_epicea"] = tuile_mips(ecorce_epicea_image())
	return _cache["ecorce_epicea"]

# ------------------------------------------------------------------ pin sylvestre
## Rameau de pin vu de dessus, 64×64 : tige orangée, 3 houppes d'aiguilles longues en étoile (bleu-vert),
## chapeau de neige au centre de chaque houppe. Même convention que le rameau d'épicéa (tige au centre,
## base en bas, pointe en haut) : il se plie en toit le long de la tige.
static func rameau_pin(graine: int, neige: float) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	var cx := 31
	# tige
	for y in range(6, S - 1):
		_px(img, cx, y, _c(PIN, 2 if y % 7 != 3 else 3))
		_px(img, cx + 1, y, _c(PIN, 1))
	var houppes := [[13.0, 12.0], [32.0, 15.0], [50.0, 11.0]]   # [y centre, rayon]
	var traits: Array = []
	for h in houppes:
		var hy: float = h[0] + rng.randf_range(-1.5, 1.5)
		var R: float = h[1] * rng.randf_range(0.9, 1.05)
		for n in 44:
			var a := rng.randf() * TAU
			# les aiguilles partent vers la pointe et les côtés plus que vers la base
			if sin(a) > 0.55 and rng.randf() < 0.6:
				a = -a
			var L := R * rng.randf_range(0.55, 1.0)
			var x0 := cx + 0.5 + cos(a) * 1.5
			var y0 := hy + sin(a) * 1.5
			var vers_base := sin(a) > 0.2
			var ton := 1 if vers_base else (3 if rng.randf() < 0.55 else 2)
			if not vers_base and L > R * 0.85 and rng.randf() < 0.35:
				ton = 4
			traits.append([ton, x0, y0, x0 + cos(a) * L, y0 + sin(a) * L])
	traits.sort_custom(func(u, v): return u[0] < v[0])
	for t in traits:
		_ligne(img, roundi(t[1]), roundi(t[2]), roundi(t[3]), roundi(t[4]), _c(AIGUILLES, t[0]))
	# chapeaux de neige : 2 à 3 paquets ronds qui se chevauchent (jamais un disque régulier)
	if neige > 0.0:
		for h in houppes:
			if rng.randf() > neige + 0.25:
				continue
			var hy: float = h[0]
			var cases := {}
			for q in rng.randi_range(2, 4):
				var ox := rng.randf_range(-h[1] * 0.45, h[1] * 0.45)
				var oy := rng.randf_range(-3.0, 1.5)
				var r := rng.randf_range(1.3, 2.3) * (0.8 + neige * 0.4)
				for dy in range(-int(r), int(r) + 1):
					for dx in range(-int(r * 1.4), int(r * 1.4) + 1):
						if pow(dx / (r * 1.4), 2) + pow(dy / r, 2) <= 1.0:
							cases[Vector2i(cx + 1 + int(ox) + dx, int(hy + oy) + dy)] = true
			for c: Vector2i in cases:
				var ton := 4
				if not cases.has(c + Vector2i(0, -1)):
					ton = 5
				elif not cases.has(c + Vector2i(0, 1)):
					ton = 3
				elif not cases.has(c + Vector2i(0, 2)):
					ton = 3 if (c.x % 3) == 0 else 4
				_px(img, c.x, c.y, _c(NEIGE, ton))
	_nettoyer(img)
	_lisser(img, false)
	return img

## Écorce de pin sylvestre : plaques orangées irrégulières (amas), fissures sombres, reflets clairs.
static func ecorce_pin_image() -> Image:
	var N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var w := 1.6 * _onde(x, y, N, 1, 2, 0.4) + 0.8 * _onde(x, y, N, 2, 1, 1.7)
			var u := (x + w) / N * 4.0
			var v := (y + 1.5 * _onde(x, y, N, 1, 0, 0.9) + floorf((x + w) / N * 4.0) * 5.0) / N * 3.0
			var fu: float = u - floor(u)
			var fv: float = v - floor(v)
			var cell := posmod(int(floor(u)) * 7 + int(floor(v)) * 3, 4)
			var ton: int = [2, 1, 2, 2][cell]
			if fu < 0.1 or (fv < 0.06 and fu < 0.7):
				ton = 0
			elif fu < 0.26:
				ton = maxi(ton - 1, 0)
			elif fu > 0.6 and fu < 0.8 and fv > 0.3 and fv < 0.75 and cell == 3:
				ton = 3
			img.set_pixel(x, y, _c(PIN, ton))
	_lisser(img, true)
	return img

# ------------------------------------------------------------------ bouleau
## Écorce de bouleau : blanc froid, lenticelles horizontales sombres (tirets), marques noires en losange.
static func ecorce_bouleau_image() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 601
	var N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var f := 0.6 * _onde(x, y, N, 1, 0, 0.3) + 0.4 * _onde(x, y, N, 0, 3, 1.1)
			img.set_pixel(x, y, _c(BOULEAU, 4 if f < 0.55 else 5))
	# lenticelles : nombreux tirets horizontaux de 2 à 7 px
	for n in 34:
		var x := rng.randi_range(0, N - 1)
		var y := rng.randi_range(0, N - 1)
		var L := rng.randi_range(2, 7)
		for d in L:
			_px(img, x + d, y, _c(BOULEAU, 1 if d > 0 and d < L - 1 and L > 3 else 2), true)
	# bandes noires irrégulières (écorce fendue) : 2 par tuile, larges et basses, bord adouci
	for b in 2:
		var x0 := rng.randi_range(0, N - 1)
		var y0 := 4 + b * 16 + rng.randi_range(-2, 2)
		var L := rng.randi_range(9, 15)
		for d in L:
			var h := 1 + int(2.2 * sin(PI * float(d) / L)) + rng.randi_range(0, 1)
			for e in h:
				_px(img, x0 + d, y0 + e, _c(BOULEAU, 0), true)
			_px(img, x0 + d, y0 - 1, _c(BOULEAU, 2), true)
			_px(img, x0 + d, y0 + h, _c(BOULEAU, 1), true)
	_lisser(img, true)
	return img

## Ramilles de bouleau d'hiver vues de côté, 64×64 : rameau qui part du haut et retombe, fines ramilles
## pendantes violacées (amas de traits fins), quelques grains de neige sur le dessus.
static func ramilles_bouleau(graine: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	# ramilles violacées et grises (BOULEAU 1-2, ECORCE 1-2) : un voile léger, pas une masse brune
	var brun := [Color("#3a2a2a"), Color("#3f3d4c"), Color("#787f9e"), Color("#54402f")]
	# trois rameaux en éventail depuis le coin haut gauche, en arcs qui retombent, avec des ramilles
	# pendantes (traits fins en amas) ; neige en grains sur le dessus des rameaux
	for r in 3:
		var pts: Array = []
		var x := 2.0
		var y := 4.0 + r * 9.0
		var a := deg_to_rad(-18.0 + r * 16.0)
		while x < S - 3 and y < S - 3 and pts.size() < 90:
			pts.append(Vector2(x, y))
			x += cos(a)
			y += sin(a)
			a += deg_to_rad(1.3 + r * 0.4)
		for i in pts.size():
			var p: Vector2 = pts[i]
			_px(img, roundi(p.x), roundi(p.y), brun[1])
			if i < pts.size() * 0.3:
				_px(img, roundi(p.x), roundi(p.y) + 1, brun[0])
		for i in range(2, pts.size(), 2):
			var p: Vector2 = pts[i]
			if rng.randf() < 0.45:
				continue
			var L := rng.randf_range(5, 15) * (1.0 - float(i) / pts.size() * 0.5)
			var q := p
			var aa := deg_to_rad(rng.randf_range(60, 85))
			var c: Color = brun[rng.randi_range(0, 2)]
			for s2 in int(L):
				_px(img, roundi(q.x), roundi(q.y), c)
				q += Vector2(cos(aa), sin(aa))
				aa = lerpf(aa, deg_to_rad(90), 0.1)
				if s2 % 4 == 3 and rng.randf() < 0.6:
					var cote := -1 if rng.randf() < 0.5 else 1
					_ligne(img, roundi(q.x), roundi(q.y), roundi(q.x + cote * 2), roundi(q.y + 2), brun[3] if rng.randf() < 0.3 else c)
		for i in range(3, int(pts.size() * 0.6), 7):
			if rng.randf() < 0.55:
				for d in rng.randi_range(2, 4):
					var p: Vector2 = pts[mini(i + d, pts.size() - 1)]
					_px(img, roundi(p.x), roundi(p.y) - 1, _c(NEIGE, 4 if d % 2 == 0 else 3))
	return img

# ------------------------------------------------------------------ bois mort
## Bois mort sans écorce : fibres verticales argentées, fentes sombres, nœuds, givre clair en amas.
static func bois_mort_image() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 701
	var N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var w := 1.2 * _onde(x, y, N, 0, 1, 0.5) + 0.7 * _onde(x, y, N, 1, 2, 2.0)
			var u := (x + w) / N * 6.0
			var f: float = u - floor(u)
			var ton := 2
			if f < 0.15:
				ton = 1
			elif f > 0.6 and f < 0.85:
				ton = 3
			img.set_pixel(x, y, _c(BOIS_MORT, ton))
	# fentes longues
	for p: Vector2i in [Vector2i(5, 2), Vector2i(19, 14), Vector2i(27, 24)]:
		for d in rng.randi_range(6, 11):
			_px(img, p.x + (1 if d > 5 else 0), p.y + d, _c(BOIS_MORT, 0), true)
	# nœud
	for dy in range(-2, 3):
		for dx in range(-1, 2):
			_px(img, 12 + dx, 24 + dy, _c(BOIS_MORT, 0 if absi(dx) + absi(dy) < 2 else 1), true)
	_lisser(img, true)
	return img

## Atlas des essences secondaires (128×64) : rameau de pin (0,0) et (64,0) n'existe pas : ramilles de bouleau.
const R_PIN := Rect2i(0, 0, 64, 64)
const R_BOULEAU := Rect2i(64, 0, 64, 64)

static func atlas_pin() -> ImageTexture:
	if not _cache.has("atlas_pin"):
		_cache["atlas_pin"] = _precalcule("atlas_pin")
		if _cache["atlas_pin"] == null:
			_cache["atlas_pin"] = avec_mips(rameau_pin(801, 0.7))
	return _cache["atlas_pin"]

static func atlas_bouleau() -> ImageTexture:
	if not _cache.has("atlas_bouleau"):
		# ramilles fines : à distance elles s'effacent (vote 2 sur 4) au lieu de former des paquets flottants
		_cache["atlas_bouleau"] = _precalcule("atlas_bouleau")
		if _cache["atlas_bouleau"] == null:
			_cache["atlas_bouleau"] = avec_mips(ramilles_bouleau(901), 2)
	return _cache["atlas_bouleau"]

static func _tuile(nom: String, img_f: Callable) -> ImageTexture:
	if not _cache.has(nom):
		_cache[nom] = tuile_mips(img_f.call())
	return _cache[nom]

static func ecorce_pin() -> ImageTexture:
	return _tuile("ecorce_pin", ecorce_pin_image)

static func ecorce_bouleau() -> ImageTexture:
	return _tuile("ecorce_bouleau", ecorce_bouleau_image)

static func bois_mort() -> ImageTexture:
	return _tuile("bois_mort", bois_mort_image)

## Images à montrer en planche (outils/planche_arbres.gd).
static func planches() -> Dictionary:
	return {"atlas_epicea": atlas_epicea_image(), "ecorce_epicea": ecorce_epicea_image(),
		"rameau_pin": rameau_pin(801, 0.7), "ecorce_pin": ecorce_pin_image(),
		"ramilles_bouleau": ramilles_bouleau(901), "ecorce_bouleau": ecorce_bouleau_image(),
		"bois_mort": bois_mort_image()}
