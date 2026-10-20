class_name TexturesBati
## Lot 5 (pierre et bâtiments) : textures pixel art des murs, de la pierre, du bois travaillé, du fer…
## dessinées par code en AMAS délibérés (assises de pierre, planches, strates), dans les rampes de la
## bible visuelle (docs/BIBLE_VISUELLE.md §2), à 16 texels/m (shader `ps1_bati.gdshader` : coordonnées
## d'objet en mètres, donc la même densité sur tous les murs, quelle que soit la taille de la boîte).
##
## Une toile = grille d'index (ton, rampe) : aucune couleur libre, tout reste dans la palette. Les
## tuiles bouclent sur leurs bords. Filtre « mode » à la fin : aucun texel isolé (pas de sel et poivre).
## Mipmaps maison (`TexturesArbres.avec_mips`) : vote de couleur 2×2 au lieu d'une moyenne floue.
## RNG propres à chaque texture : les tirages du monde ne bougent pas.

const SHADER := preload("res://shaders/ps1_bati.gdshader")

# rampes (bible §2) : index = identifiant de rampe
const PIERRE := 0
const NEIGE := 1
const VERT := 2       # épicéa aiguilles : lichen gris-vert (tons 3-4)
const BOIS := 3       # bois travaillé
const FER := 4
const CHAUME := 5     # tourbe, chaume, foin
const CUIR := 6
const ROUX := 7       # écorce de pin : lichen orangé
const BRAISE := 8
const RAMPES := [
	["#262a3b", "#3a4057", "#565b72", "#787d8e", "#a0a2ab"],
	["#4a557f", "#6877a3", "#8898bf", "#aab8d6", "#cdd7ec", "#f0eff4"],
	["#08161a", "#10272a", "#1a3d32", "#2c5a41", "#5b866f", "#6e9172"],
	["#2b1a1e", "#472a21", "#6a4229", "#92613a", "#bb8a53"],
	["#20252f", "#3a4256", "#5b6680", "#8a96ae", "#bcc6d8"],
	["#211e1c", "#3b3322", "#5c4e2d", "#82723f", "#b39d5d"],
	["#1f1418", "#3a261b", "#5b3d27", "#86603a"],
	["#3b1f24", "#6a3524", "#9c5129", "#cf7b3c", "#ecaa62"],
	["#5a1a1c", "#b3341f", "#ec6a1f", "#fcb53a", "#fff0a8"],
]

static var _cache := {}

class Toile:
	var w: int
	var h: int
	var t: PackedByteArray
	var r: PackedByteArray
	func _init(largeur: int, hauteur: int, ton0 := 0, rampe0 := 0) -> void:
		w = largeur
		h = hauteur
		t.resize(w * h)
		r.resize(w * h)
		t.fill(ton0)
		r.fill(rampe0)
	func k(x: int, y: int) -> int:
		return posmod(y, h) * w + posmod(x, w)
	func pose(x: int, y: int, ton: int, rampe: int) -> void:
		var i := k(x, y)
		t[i] = clampi(ton, 0, (RAMPES[rampe] as Array).size() - 1)
		r[i] = rampe
	func ton(x: int, y: int) -> int:
		return t[k(x, y)]
	func rampe_de(x: int, y: int) -> int:
		return r[k(x, y)]
	## Remplit une ellipse (centre cx, cy ; rayons rx, ry) avec `fn(x, y)` qui renvoie vrai si le texel est à poser.
	func ellipse(cx: float, cy: float, rx: float, ry: float, ton_: int, rampe: int, seulement_ton_min := 0) -> void:
		for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
			for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
				var dx := (x - cx) / rx
				var dy := (y - cy) / ry
				if dx * dx + dy * dy <= 1.0 and ton(x, y) >= seulement_ton_min:
					pose(x, y, ton_, rampe)
	## Filtre « mode » : un texel qui ne partage sa valeur avec aucun de ses 4 voisins prend la plus
	## fréquente autour (bible §4.2).
	func filtre_mode(passes := 1) -> void:
		for _p in passes:
			var t2 := t.duplicate()
			var r2 := r.duplicate()
			for y in h:
				for x in w:
					var i := k(x, y)
					var v := t[i] | (r[i] << 8)
					var comptes := {}
					var seul := true
					for j: int in [k(x - 1, y), k(x + 1, y), k(x, y - 1), k(x, y + 1)]:
						var u := t[j] | (r[j] << 8)
						if u == v:
							seul = false
							break
						comptes[u] = int(comptes.get(u, 0)) + 1
					if seul:
						var best := v
						var bc := 0
						for u: int in comptes:
							if int(comptes[u]) > bc:
								bc = int(comptes[u])
								best = u
						t2[i] = best & 0xff
						r2[i] = best >> 8
			t = t2
			r = r2
	func transposee() -> Toile:
		var o := Toile.new(h, w)
		for y in h:
			for x in w:
				var i := k(x, y)
				o.pose(y, x, t[i], r[i])
		return o
	func image() -> Image:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var i := y * w + x
				img.set_pixel(x, y, Color((RAMPES[r[i]] as Array)[t[i]]))
		return img

# --- outils -----------------------------------------------------------------------------------------

## Découpe `total` en morceaux de `mn` à `mx` (le dernier peut dépasser un peu) : somme exacte.
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

## Un amas (blob) irrégulier : ellipse dont le bord est rogné au hasard (pas de disque parfait).
static func _amas(t: Toile, rng: RandomNumberGenerator, cx: float, cy: float, rx: float, ry: float, ton: int, rampe: int, ton_min := 1) -> void:
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var d := dx * dx + dy * dy
			if d <= 0.62 or (d <= 1.0 and rng.randf() < 0.55):
				if t.ton(x, y) >= ton_min:
					t.pose(x, y, ton, rampe)

# --- pierre sèche (soubassements, murets, foyers, puits) -----------------------------------------------

## Appareil de pierres sèches : assises de 8 à 12 texels, pierres de 11 à 22 texels dont les joints
## verticaux ne tombent pas l'un sur l'autre, joint de 1 texel (ton 0), arête haute claire, ombre au
## pied, coins arrondis, quelques fissures, lichen gris-vert et orangé, neige dans les joints et en
## calotte sur quelques pierres (bible §6 : « assises irrégulières, arêtes claires, joints de 1 px »).
static func pierre_seche(graine: int, w := 128, h := 64, neige_part := 0.2, hmin := 8, hmax := 12, wmin := 11, wmax := 22) -> Toile:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(w, h, 0, PIERRE)
	var assises := _decouper(rng, h, hmin, hmax)
	var joints_prec: Array[int] = []
	var y := 0
	var pierres: Array = []   # [x0, y0, largeur, hauteur, ton]
	for hh in assises:
		var largeurs: Array[int] = []
		var depart := 0
		for essai in 24:
			largeurs = _decouper(rng, w, wmin, wmax)
			depart = rng.randi_range(0, wmax - 1)
			var ok := true
			var x := depart
			for lw in largeurs:
				for jp in joints_prec:
					if absi(posmod(x - jp + w / 2, w) - w / 2) < 3:
						ok = false
				x += lw
			if ok:
				break
		joints_prec.clear()
		var x := depart
		for lw in largeurs:
			joints_prec.append(posmod(x, w))
			var tirage := rng.randf()
			var base := 1 if tirage < 0.12 else (2 if tirage < 0.55 else 3)
			pierres.append([x, y, lw, hh, base])
			x += lw
		y += hh
	for p: Array in pierres:
		_une_pierre(t, rng, p[0], p[1], p[2], p[3], p[4])
	# neige en calotte sur quelques pierres (surtout les plus saillantes : ton clair)
	for p: Array in pierres:
		if rng.randf() < neige_part and p[2] >= wmin + 1:
			var x0: int = p[0]
			var lw: int = p[2]
			var prof := 1
			for dx in range(2, lw - 1):
				prof = clampi(prof + rng.randi_range(-1, 1), 1, 3)
				var bord := minf(dx - 1.0, lw - 1.0 - dx)
				var d := prof if bord > 2.0 else 1
				for dy in d:
					t.pose(x0 + dx, int(p[1]) + 1 + dy, 4 if dy == 0 else 3, NEIGE)
				t.pose(x0 + dx, int(p[1]) + 1 + d, 2, NEIGE)   # ombre sous le bord de la calotte
	# neige dans les joints horizontaux : quelques tronçons de 5 à 11 texels
	for i in int(w * h / 900.0) + 2:
		var p: Array = pierres[rng.randi_range(0, pierres.size() - 1)]
		var l := rng.randi_range(6, 11)
		var x1: int = int(p[0]) + rng.randi_range(0, maxi(int(p[2]) - l, 0))
		for dx in l:
			t.pose(x1 + dx, int(p[1]), 3 if dx > 0 and dx < l - 1 else 2, NEIGE)
	# lichen : taches gris-vert (le vert lumineux reste rare), quelques taches orangées
	for i in int(w * h / 620.0):
		var cx := rng.randf_range(0, w)
		var cy := rng.randf_range(0, h)
		_amas(t, rng, cx, cy, rng.randf_range(1.6, 3.4), rng.randf_range(1.0, 2.0), 4 if rng.randf() < 0.6 else 3, VERT, 2)
	t.filtre_mode(2)
	return t

static func _une_pierre(t: Toile, rng: RandomNumberGenerator, x0: int, y0: int, lw: int, hh: int, base: int) -> void:
	# corps : de (x0+1, y0+1) à (x0+lw-1, y0+hh-1) ; la rangée y0 et la colonne x0 sont des joints
	for dy in range(1, hh):
		for dx in range(1, lw):
			t.pose(x0 + dx, y0 + dy, base, PIERRE)
	# taches de ton voisin, en amas allongés : relief de la pierre, jamais un texel seul
	for i in 1 + lw * hh / 70:
		var cx := x0 + rng.randf_range(3.0, lw - 3.0)
		var cy := y0 + rng.randf_range(3.0, hh - 3.0)
		var plus_clair := cy < y0 + hh * 0.5 and rng.randf() < 0.65
		var ton := clampi(base + (1 if plus_clair else -1), 1, 3)
		_amas(t, rng, cx, cy, rng.randf_range(1.8, 3.6), rng.randf_range(1.0, 1.8), ton, PIERRE, 1)
	# arête haute claire, ombre au pied (biseau tolérée par la bible §4.6)
	for dx in range(2, lw - 1):
		t.pose(x0 + dx, y0 + 1, mini(base + 1, 4), PIERRE)
		t.pose(x0 + dx, y0 + hh - 1, maxi(base - 1, 1), PIERRE)
	# coins arrondis
	if lw >= 7 and hh >= 6:
		t.pose(x0 + 1, y0 + 1, 0, PIERRE)
		t.pose(x0 + lw - 1, y0 + 1, 0, PIERRE)
		t.pose(x0 + lw - 1, y0 + hh - 1, 0, PIERRE)
		t.pose(x0 + 1, y0 + hh - 1, 0, PIERRE)
		if rng.randf() < 0.35:
			t.pose(x0 + lw - 2, y0 + 1, 0, PIERRE)
			t.pose(x0 + lw - 1, y0 + 2, 0, PIERRE)
	# fissure : trait de 3 à 6 texels qui part du haut, ton 1, lèvre claire à droite
	if rng.randf() < 0.14:
		var fx := x0 + rng.randi_range(4, maxi(lw - 4, 5))
		var fy := y0 + 2
		for s in rng.randi_range(3, 6):
			t.pose(fx, fy, 1, PIERRE)
			t.pose(fx + 1, fy, mini(base + 1, 3), PIERRE)
			fy += 1
			fx += rng.randi_range(-1, 1)

# --- roche brute (rochers, menhirs, pierres du cercle, façade) ----------------------------------------------

## Roche fracturée : une douzaine de dalles (Voronoï périodique sur grille jittérée), chacune avec ses
## strates parallèles inclinées (ton qui alterne, liseré sombre, lèvre claire), joints de 1 texel entre
## dalles, arête haute claire et pied dans l'ombre, plaques de ton voisin, lichen, neige sur les replats.
## Boucle sur les quatre bords. (Rochers, menhirs, pierres du cercle, façade du tertre.)
static func roche_brute(graine: int, n := 64, neige_part := 1.0) -> Toile:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(n, n, 2, PIERRE)
	var cx_n := 4
	var cy_n := 3
	var graines: Array[Vector2] = []
	var cell_base: Array[int] = []
	var cell_ang: Array[float] = []
	var cell_bande: Array[float] = []
	var cell_dec: Array[float] = []
	for j in cy_n:
		for i in cx_n:
			graines.append(Vector2((i + rng.randf_range(0.15, 0.85)) * n / cx_n, (j + rng.randf_range(0.15, 0.85)) * n / cy_n))
			var v := rng.randf()
			cell_base.append(2 if v < 0.55 else 3)
			cell_ang.append(rng.randf_range(-0.28, 0.28))
			cell_bande.append(rng.randf_range(5.5, 8.5))
			cell_dec.append(rng.randf() * 20.0)
	var proche := PackedInt32Array()
	proche.resize(n * n)
	var marge := PackedFloat32Array()
	marge.resize(n * n)
	for y in n:
		for x in n:
			var d1 := INF
			var d2 := INF
			var i1 := 0
			for i in graines.size():
				var dd := Vector2(wrapf(x - graines[i].x, -n * 0.5, n * 0.5), wrapf(y - graines[i].y, -n * 0.5, n * 0.5))
				var d := dd.length()
				if d < d1:
					d2 = d1
					d1 = d
					i1 = i
				elif d < d2:
					d2 = d
			proche[y * n + x] = i1
			marge[y * n + x] = d2 - d1
	for y in n:
		for x in n:
			var c := proche[y * n + x]
			var dd := Vector2(wrapf(x - graines[c].x, -n * 0.5, n * 0.5), wrapf(y - graines[c].y, -n * 0.5, n * 0.5))
			var u := (-sin(cell_ang[c]) * dd.x + cos(cell_ang[c]) * dd.y + cell_dec[c]) / cell_bande[c]
			var bi := floori(u)
			var f := u - bi
			var ton := cell_base[c] + (0 if posmod(bi, 3) != 0 else -1)
			if f < 1.0 / cell_bande[c]:
				ton = 1
			elif f < 2.0 / cell_bande[c]:
				ton = mini(ton + 1, 3)
			if marge[y * n + x] < 1.15:
				ton = 1                          # joint entre dalles (le ton 0 reste pour les fissures)
			elif proche[t.k(x, y - 1)] != c:
				ton = mini(ton + 1, 4)           # arête haute
			elif proche[t.k(x, y + 1)] != c or proche[t.k(x, y + 2)] != c:
				ton = maxi(ton - 1, 1)           # pied dans l'ombre
			t.pose(x, y, ton, PIERRE)
	# plaques de ton voisin
	for i in 12:
		var cx := rng.randf_range(0, n)
		var cy := rng.randf_range(0, n)
		var base := t.ton(floori(cx), floori(cy))
		if base < 2:
			continue
		_amas(t, rng, cx, cy, rng.randf_range(2.5, 5.0), rng.randf_range(1.2, 2.4), clampi(base + (1 if rng.randf() < 0.45 else -1), 1, 3), PIERRE, 2)
	# grain de la roche : petits amas de ton voisin (3 à 8 texels), serrés mais jamais isolés
	for i in 46:
		var cx := rng.randf_range(0, n)
		var cy := rng.randf_range(0, n)
		var base := t.ton(floori(cx), floori(cy))
		if base < 2:
			continue
		_amas(t, rng, cx, cy, rng.randf_range(1.3, 2.3), rng.randf_range(0.9, 1.5), clampi(base + (1 if rng.randf() < 0.5 else -1), 1, 3), PIERRE, 2)
	# fissures secondaires
	for i in 4:
		var fx := rng.randi_range(0, n - 1)
		var fy := rng.randi_range(0, n - 1)
		var dir := 1 if rng.randf() < 0.5 else -1
		for s in rng.randi_range(6, 13):
			t.pose(fx, fy, 0, PIERRE)
			if t.ton(fx + 1, fy) >= 2:
				t.pose(fx + 1, fy, 3, PIERRE)
			fy += 1
			if rng.randf() < 0.4:
				fx += dir
	# lichen gris-vert en plaques franches, une tache orangée
	for i in 6:
		_amas(t, rng, rng.randf_range(0, n), rng.randf_range(0, n), rng.randf_range(2.5, 4.5), rng.randf_range(1.4, 2.4), 4 if rng.randf() < 0.65 else 3, VERT, 2)
	# neige sur les replats : sur l'arête haute claire (ton 3-4) d'une dalle, amas de 6 à 12 texels
	for i in int(7 * neige_part):
		var cx := rng.randi_range(0, n - 1)
		var cy := rng.randi_range(0, n - 1)
		for d in 20:
			if marge[posmod(cy - 1, n) * n + posmod(cx, n)] < 1.15 and t.ton(cx, cy) >= 2:
				break
			cy -= 1
		var l := rng.randi_range(6, 12)
		for dx in l:
			var bord := minf(dx, l - 1.0 - dx)
			if bord < 1.0:
				continue
			t.pose(cx + dx, cy, 4, NEIGE)
			t.pose(cx + dx, cy + 1, 3, NEIGE)
			if bord >= 2.0 and rng.randf() < 0.6:
				t.pose(cx + dx, cy + 2, 3, NEIGE)
	t.filtre_mode(2)
	return t

# --- bois travaillé ---------------------------------------------------------------------------------

## Planches : hauteurs de 7 à 9 texels, joint sombre en haut, arête claire dessous, ombre de recouvrement
## au pied, veines en courbes (traits de 8 à 24 texels), abouts décalés d'une planche à l'autre, nœuds.
## `vertical` : la toile est transposée (planches debout, pour poteaux, portes, caisses).
static func planches(graine: int, w := 64, h := 64, vertical := false, noeuds := 3) -> Toile:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(w, h, 2, BOIS)
	var hauteurs := _decouper(rng, h, 7, 9)
	var y0 := 0
	var rangs: Array = []
	var dernier := 2
	for hh in hauteurs:
		var base := 2 if dernier == 3 else 3
		if rng.randf() < 0.25:
			base = 2 if rng.randf() < 0.5 else 3
		dernier = base
		rangs.append([y0, hh, base])
		for dy in hh:
			for x in w:
				var ton := base
				if dy == 0:
					ton = 0
				elif dy == 1:
					ton = base + 1
				elif dy == hh - 1:
					ton = maxi(base - 1, 1)
				t.pose(x, y0 + dy, ton, BOIS)
		# veines : traits qui suivent une onde lente, un ton sous la base
		for i in 2 + w / 40:
			var x := rng.randi_range(0, w - 1)
			var y := y0 + rng.randi_range(3, maxi(hh - 3, 4))
			var l := rng.randi_range(9, 26)
			var amp := rng.randf_range(0.0, 1.4)
			var ph := rng.randf() * TAU
			var f := rng.randf_range(0.12, 0.3)
			for s in l:
				var yy := y + int(round(amp * sin(s * f + ph)))
				if yy > y0 + 1 and yy < y0 + hh - 1:
					t.pose(x + s, yy, maxi(base - 1, 1), BOIS)
					if rng.randf() < 0.3 and yy + 1 < y0 + hh - 1:
						t.pose(x + s, yy + 1, maxi(base - 1, 1), BOIS)
		# abouts : un joint vertical, le bois d'à côté un cran plus clair
		var xe := rng.randi_range(0, w - 1)
		for dy in range(1, hh):
			t.pose(xe, y0 + dy, 0 if dy < hh - 1 else 1, BOIS)
			if dy > 1:
				t.pose(xe + 1, y0 + dy, mini(base + 1, 4), BOIS)
		if w >= 96 and rng.randf() < 0.7:
			var xe2 := posmod(xe + rng.randi_range(w / 3, w * 2 / 3), w)
			for dy in range(1, hh):
				t.pose(xe2, y0 + dy, 0 if dy < hh - 1 else 1, BOIS)
				if dy > 1:
					t.pose(xe2 + 1, y0 + dy, mini(base + 1, 4), BOIS)
		y0 += hh
	# nœuds : anneau sombre, cœur très sombre, lèvre claire en haut à gauche
	for i in noeuds:
		var r: Array = rangs[rng.randi_range(0, rangs.size() - 1)]
		if int(r[1]) < 8:
			continue
		var cx := rng.randi_range(4, w - 5)
		var cy := int(r[0]) + int(r[1]) / 2 + 1
		var base: int = r[2]
		t.ellipse(cx, cy, 3.4, 2.4, maxi(base - 1, 1), BOIS, 1)
		t.ellipse(cx, cy, 1.9, 1.2, 0, BOIS, 1)
		t.pose(cx - 2, cy - 2, mini(base + 1, 4), BOIS)
		t.pose(cx - 3, cy - 1, mini(base + 1, 4), BOIS)
		t.pose(cx - 1, cy - 2, mini(base + 1, 4), BOIS)
	t.filtre_mode(2)
	return t.transposee() if vertical else t

# --- fer, cuir, foin, braises, fenêtre -------------------------------------------------------------------

static func fer(graine: int, n := 32) -> Toile:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(n, n, 2, FER)
	for i in 12:
		_amas(t, rng, rng.randf_range(0, n), rng.randf_range(0, n), rng.randf_range(2.5, 5.0), rng.randf_range(1.5, 3.0), 1 if rng.randf() < 0.55 else 3, FER, 0)
	# rayures fines, claires, un peu obliques
	for i in 5:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		for s in rng.randi_range(5, 10):
			t.pose(x + s, y + s / 4, 3, FER)
	t.filtre_mode(2)
	return t

static func cuir(graine: int, n := 32) -> Toile:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(n, n, 2, CUIR)
	for i in 10:
		_amas(t, rng, rng.randf_range(0, n), rng.randf_range(0, n), rng.randf_range(2.5, 5.0), rng.randf_range(1.8, 3.2), 1 if rng.randf() < 0.5 else 3, CUIR, 0)
	for i in 4:   # plis
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		for s in rng.randi_range(6, 11):
			t.pose(x + s, y + int(round(sin(s * 0.5))), 1, CUIR)
	t.filtre_mode(2)
	return t

static func foin(graine: int, n := 32) -> Toile:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(n, n, 1, CHAUME)
	for i in 160:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		var pente := rng.randf_range(-0.5, 0.5)
		var ton := 2 + (1 if rng.randf() < 0.5 else 0) + (1 if rng.randf() < 0.15 else 0)
		for s in rng.randi_range(4, 8):
			t.pose(x + int(round(pente * s)), y + s, ton, CHAUME)
	t.filtre_mode(2)
	return t

static func braises(graine: int, n := 32) -> Toile:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(n, n, 1, BRAISE)
	for i in 14:
		_amas(t, rng, rng.randf_range(0, n), rng.randf_range(0, n), rng.randf_range(2.5, 5.0), rng.randf_range(1.8, 3.0), 2, BRAISE, 0)
	for i in 7:
		_amas(t, rng, rng.randf_range(0, n), rng.randf_range(0, n), rng.randf_range(1.5, 3.0), rng.randf_range(1.2, 2.0), 3, BRAISE, 0)
	for i in 3:
		_amas(t, rng, rng.randf_range(0, n), rng.randf_range(0, n), 1.8, 1.2, 4, BRAISE, 0)
	t.filtre_mode(2)
	return t

## Vitrage d'une fenêtre de 0,55 × 0,36 m (9 × 6 texels, UV du quad : la tuile couvre exactement la vitre) :
## deux carreaux chauds (braise 3, cœur 4, bas 2) séparés par un meneau de bois. Le cadre est en géométrie.
static func fenetre() -> Toile:
	var t := Toile.new(9, 6, 3, BRAISE)
	for y in 6:
		for x in 9:
			if x == 4:
				t.pose(x, y, 1, BOIS)                  # meneau
			else:
				var cx := 1.5 if x < 4 else 6.5
				var d := absf(x - cx) / 2.0 + absf(y - 2.5) / 3.0
				t.pose(x, y, 4 if d < 0.55 else (3 if y < 5 else 2), BRAISE)
	return t

# --- neige de toit ---------------------------------------------------------------------------------------

## Neige épaisse des toits, des calottes de rochers et du tertre : grandes plaques calmes de deux tons
## proches, quelques congères longues (crête claire, ombre froide dessous) parallèles au faîte (axe x), des
## creux en amas ; aucun grain isolé (bible §6 : « plaques calmes de 2 tons proches + quelques croissants »).
static func neige_toit(graine := 5501, n := 128) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := Toile.new(n, n, 4, NEIGE)
	# plaques de ton 3 (bruit périodique étiré dans le sens du faîte, seuil franc : bords en amas) : deux tons
	# proches seulement, jamais de creux sombre
	for y in n:
		for x in n:
			var f := SolTuiles._fbm(x, y, n, 3, 7, 3, 5500 + graine % 97)
			if f > 0.57:
				t.pose(x, y, 3, NEIGE)
	# congères : crête claire (ton 5) sur 1 texel, bord inférieur ombré (ton 3 puis 2 aux extrémités)
	for i in 12:
		var cx := rng.randf_range(0, n)
		var cy := rng.randf_range(0, n)
		var l := rng.randi_range(10, 30)
		var pente := rng.randf_range(-0.12, 0.12)
		for dx in l:
			var bord := minf(dx, l - 1.0 - dx)
			if bord < 1.0:
				continue
			var y := int(round(cy + pente * dx))
			t.pose(int(cx) + dx, y, 5 if bord >= 2.0 else 4, NEIGE)
			t.pose(int(cx) + dx, y + 1, 3 if bord >= 3.0 else 4, NEIGE)
			if bord >= 5.0 and rng.randf() < 0.5:
				t.pose(int(cx) + dx, y + 2, 3, NEIGE)
	t.filtre_mode(2)
	return t.image()

# --- matériaux ------------------------------------------------------------------------------------------

## Mipmaps « pixel art » (tuiles opaques, côtés non carrés permis) : chaque niveau vote la couleur
## majoritaire d'un bloc 2×2 (à égalité : la plus sombre, pour garder joints et creux). Rien hors palette.
static func _mips(img: Image) -> ImageTexture:
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

## Texture à mipmaps par nom (cache) : `fabrique` renvoie une Image.
static func tex(nom: String, fabrique: Callable) -> ImageTexture:
	if not _cache.has(nom):
		_cache[nom] = _mips(fabrique.call())
	return _cache[nom]

static func tex_neige() -> ImageTexture:
	return tex("neige_toit", neige_toit)

## Matériau PS1 « bâti » : coordonnées d'objet en mètres (16 texels/m), mipmaps nearest, tremblement
## de sommets identique au reste du jeu. Enregistré dans Palette.materiaux (bouton --sans-ps1).
static func materiau(base: Texture2D, teinte := Color.WHITE, neige: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex_base", base)
	m.set_shader_parameter("tex_neige", neige if neige else tex_neige())
	m.set_shader_parameter("teinte", teinte)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.materiaux.append(m)
	return m

static func vider() -> void:
	_cache.clear()

# --- les matières du jeu -----------------------------------------------------------------------------------

static func m_pierre_seche(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau(tex("pierre_seche", func() -> Image: return pierre_seche(5101).image()), teinte)

## Pierre sèche à petits moellons (assises de 5 à 8 texels) pour les petits volumes : puits, foyers, marches, contreforts.
static func m_pierre_fine(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau(tex("pierre_fine", func() -> Image: return pierre_seche(5103, 128, 64, 0.2, 5, 8, 7, 14).image()), teinte)

static func m_roche(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau(tex("roche_brute", func() -> Image: return roche_brute(5201).image()), teinte)

## Bois : la rampe « bois travaillé » de la bible est chaude ; la scène est froide, on la désature un peu.
static func m_planches(teinte := Color.WHITE) -> ShaderMaterial:
	var m := materiau(tex("planches_h", func() -> Image: return planches(5301, 128, 64).image()), teinte)
	m.set_shader_parameter("saturation", 0.78)
	return m

static func m_bois_debout(teinte := Color.WHITE) -> ShaderMaterial:
	var m := materiau(tex("planches_v", func() -> Image: return planches(5302, 64, 64, true, 2).image()), teinte)
	m.set_shader_parameter("saturation", 0.78)
	return m

static func m_fer(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau(tex("fer", func() -> Image: return fer(5401).image()), teinte)

static func m_cuir(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau(tex("cuir", func() -> Image: return cuir(5402).image()), teinte)

static func m_foin(teinte := Color.WHITE) -> ShaderMaterial:
	var m := materiau(tex("foin", func() -> Image: return foin(5403).image()), teinte)
	m.set_shader_parameter("saturation", 0.8)
	return m

static func m_braises() -> ShaderMaterial:
	var m := materiau(tex("braises", func() -> Image: return braises(5404).image()))
	m.set_shader_parameter("emission", Color(1.6, 0.6, 0.15))
	m.set_shader_parameter("emission_texture", true)
	return m

static func m_fenetre() -> ShaderMaterial:
	var m := materiau(tex("fenetre", func() -> Image: return fenetre().image()))
	m.set_shader_parameter("uv_maillage", true)   # le vitrage est un quad : la tuile 9×6 le couvre exactement
	m.set_shader_parameter("emission", Color(1.5, 0.8, 0.35))
	m.set_shader_parameter("emission_texture", true)
	return m

static func m_ecorce(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau(tex("ecorce", func() -> Image: return TexturesArbres.ecorce_epicea_image()), teinte)

static func m_neige_toit() -> ShaderMaterial:
	return materiau(tex_neige())
