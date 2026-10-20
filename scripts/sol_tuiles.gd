class_name SolTuiles
## Tuiles pixel art du sol (lot 3 de la mission graphisme), dessinées par code avec des amas
## délibérés : neige fraîche (vagues de vent), neige piétinée, terre gelée, tapis d'aiguilles,
## mousse givrée, roche affleurante, glace, neige croûtée ; deux variantes par matière.
##
## Les tuiles sont des cartes d'INDEX : chaque texel porte (ton, rampe) et non une couleur. Le shader
## ps1 (branche `sol_carte`) lit la couleur dans `lut()` (rampes de la bible visuelle) après avoir
## décalé le ton (creux, bord dessiné entre matières, empreintes) : tout reste dans la palette.
##
## 16 texels/m (bible §3) ; une tuile fait 128 px = 8 m, sans élément unique dominant. Les tuiles sont
## précalculées par `outils/generer_sol.gd` dans `assets/sol/*.res` (le calcul GDScript prend
## plusieurs secondes : on ne le refait pas au chargement du jeu). Si les ressources manquent,
## `charger()` les recalcule (lent, mais le jeu marche).

const N := 128            # texels par côté d'une tuile (8 m)
const ND := 80            # côté de la texture de détails (5 m : période différente des tuiles)
const NB_MATIERES := 8
const VARIANTES := 2
const DOSSIER := "res://assets/sol"

# rampes (bible visuelle §2) ; l'index de la liste est l'identifiant de rampe lu par le shader
const NEIGE := 0
const GLACE := 1
const PIERRE := 2
const TERRE := 3      # écorce d'épicéa : terre gelée, aiguilles mortes, cônes
const VERT := 4       # épicéa aiguilles : mousse, lichen gris-vert
const TOURBE := 5     # herbes sèches
const BOIS := 6       # bois mort : brindilles
const ROUX := 7       # écorce de pin : aiguilles rousses
const RAMPES := [
	["#4a557f", "#6877a3", "#8898bf", "#aab8d6", "#cdd7ec", "#f0eff4"],
	["#33577f", "#4f86ae", "#86bfd3", "#cfeef0"],
	["#262a3b", "#3a4057", "#565b72", "#787d8e", "#a0a2ab"],
	["#241a22", "#3a2a2a", "#54402f", "#735b43", "#947c5e"],
	["#08161a", "#10272a", "#1a3d32", "#2c5a41", "#5b866f", "#6e9172"],
	["#211e1c", "#3b3322", "#5c4e2d", "#82723f", "#b39d5d"],
	["#3d3c4a", "#5b5a66", "#7f7d82", "#a7a19b"],
	["#3b1f24", "#6a3524", "#9c5129", "#cf7b3c", "#ecaa62"],
]

# matières (valeur de R / 16 dans la carte de sol) ; la couche d'une tuile = matière × 2 + variante
const M_NEIGE := 0
const M_PIETINEE := 1
const M_TERRE := 2
const M_AIGUILLES := 3
const M_MOUSSE := 4
const M_ROCHE := 5
const M_GLACE := 6
const M_CROUTE := 7

# classes de la texture de détails (canal B)
const D_ECLAT := 1      # scintillements en petits amas (neige)
const D_CAILLOU := 2
const D_BRINDILLE := 3
const D_HERBE := 4

## Toile d'index (ton, rampe) qui boucle sur ses bords.
class Toile:
	var n: int
	var ton: PackedByteArray
	var rampe: PackedByteArray
	var classe: PackedByteArray
	func _init(taille: int) -> void:
		n = taille
		ton.resize(n * n)
		rampe.resize(n * n)
		classe.resize(n * n)
	func k(x: int, y: int) -> int:
		return posmod(y, n) * n + posmod(x, n)
	func pose(x: int, y: int, t: int, r: int) -> void:
		var i := k(x, y)
		ton[i] = clampi(t, 0, (RAMPES[r] as Array).size() - 1)
		rampe[i] = r
	func t_de(x: int, y: int) -> int:
		return ton[k(x, y)]
	func r_de(x: int, y: int) -> int:
		return rampe[k(x, y)]
	## Filtre « mode » : un texel qui ne partage sa valeur avec aucun de ses 4 voisins prend la
	## valeur la plus fréquente autour (pas de sel et poivre, bible §4.2).
	func filtre_mode(passes := 1) -> void:
		for p in passes:
			var t2 := ton.duplicate()
			var r2 := rampe.duplicate()
			for y in n:
				for x in n:
					var i := k(x, y)
					var v := ton[i] | (rampe[i] << 8)
					var voisins := [k(x - 1, y), k(x + 1, y), k(x, y - 1), k(x, y + 1)]
					var seul := true
					var comptes := {}
					for j: int in voisins:
						var w := ton[j] | (rampe[j] << 8)
						if w == v:
							seul = false
							break
						comptes[w] = comptes.get(w, 0) + 1
					if seul:
						var best := v
						var bc := 0
						for w: int in comptes:
							if comptes[w] > bc:
								bc = comptes[w]
								best = w
						t2[i] = best & 0xff
						r2[i] = best >> 8
			ton = t2
			rampe = r2

# --- bruits périodiques (bouclent sur la tuile) -------------------------------------------------

static func _h(x: int, y: int, g: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (g * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

## Bruit de valeur périodique, périodes distinctes en x et y (formes allongées).
static func _vp(x: float, y: float, px: int, py: int, g: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _h(posmod(xi, px), posmod(yi, py), g)
	var b := _h(posmod(xi + 1, px), posmod(yi, py), g)
	var c := _h(posmod(xi, px), posmod(yi + 1, py), g)
	var d := _h(posmod(xi + 1, px), posmod(yi + 1, py), g)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

## fbm périodique sur une toile de côté n : `px`, `py` = nombre de cellules par tuile à la 1re octave.
static func _fbm(x: float, y: float, n: int, px: int, py: int, octaves: int, g: int) -> float:
	var v := 0.0
	var amp := 0.5
	var tot := 0.0
	for o in octaves:
		v += _vp(x / n * px, y / n * py, px, py, g * 7 + o) * amp
		tot += amp
		amp *= 0.5
		px *= 2
		py *= 2
	return v / tot

# --- primitives de dessin -------------------------------------------------------------------------

## Croissant de neige soufflée (crête horizontale, le vent souffle vers +y) : crête claire, ombre
## froide sous la crête qui s'effile aux pointes (bible, échantillon B).
static func _ride(t: Toile, cx: int, cy: int, L: int, H: int, base := 4) -> void:
	var demi := maxi(1, L / 2)
	for lx in range(-demi, demi + 1):
		var u := float(lx) / demi
		var hc := int(round(H * (1.0 - u * u)))
		var arc := int(round(1.5 * u * u))
		var ycr := cy + arc - hc
		for d in range(0, hc + 1):
			var ton := base
			if d == 0:
				ton = base + 1 if absf(u) < 0.45 and H >= 1 else base
			t.pose(cx + lx, ycr + d, ton, NEIGE)
		# ombre sous la crête, plus épaisse au centre
		var ep := 1 if absf(u) > 0.55 or hc == 0 else 2
		for d in ep:
			t.pose(cx + lx, ycr + hc + 1 + d, base - 2 if d == 0 and absf(u) < 0.5 and H >= 2 else base - 1, NEIGE)

## Orientation locale du vent (rad.), champ lent commun aux deux couches (coordonnées normalisées).
static func _flux(x: float, y: float, n: int, g: int) -> float:
	return (_fbm(x, y, n, 2, 2, 2, 7420 + g) - 0.5) * 2.0 * 0.95

## Ride libre : croissant d'axe incliné de `ang`, courbé (`courb` > 0 ouvert vers le bas, < 0 vers le
## haut), crête claire (interrompue par endroits si `trous`), corps de ton `base`, ombre froide dessous
## qui s'effile aux pointes. `H` = épaisseur du corps (0 = simple trait crête + ombre).
static func _ride_libre(t: Toile, cx: float, cy: float, ang: float, L: float, courb: float, H: int, base: int, trous := 0.0, g := 0) -> void:
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)
	var pas := 0.5
	var demi := L * 0.5
	var s := -demi
	var vus := {}
	while s <= demi:
		var u := s / demi
		var p := Vector2(cx, cy) + dir * s + perp * (courb * (1.0 - u * u) * demi * 0.35)
		var px := roundi(p.x)
		var py := roundi(p.y)
		s += pas
		if vus.has(Vector2i(px, py)):
			continue
		vus[Vector2i(px, py)] = true
		var hc := int(round(H * (1.0 - u * u)))
		var cret := base + 1 if (absf(u) < 0.5 and H >= 1) else base
		if trous > 0.0 and _h(px, py, 733 + g) < trous:
			cret = base  # crête interrompue : plaque lisse à la place
		t.pose(px, py, cret, NEIGE)
		for d in range(1, hc + 1):
			t.pose(px, py + d, base, NEIGE)
		var ep := 2 if (absf(u) < 0.45 and H >= 2) else 1
		for d in ep:
			t.pose(px, py + hc + 1 + d, base - 2 if d == 0 and absf(u) < 0.4 and H >= 2 else base - 1, NEIGE)

## Langue de sastrugi (allongée dans le sens du vent, +y) : bout au vent creusé (ombre), dos clair.
static func _sastrugi(t: Toile, cx: int, cy: int, L: int, W: int) -> void:
	for ly in L:
		var u := float(ly) / L
		var w := int(round(W * sin(PI * pow(u, 0.6)) * 0.5))
		var dx := int(round(1.5 * sin(u * 3.0)))
		for lx in range(-w, w + 1):
			var ton := 4
			if lx == 0 and u > 0.2 and u < 0.6:
				ton = 5
			if lx == w and w >= 2:
				ton = 3
			t.pose(cx + lx + dx, cy + ly, ton, NEIGE)
		if ly == 0:
			for lx in range(-w, w + 1):
				t.pose(cx + lx + dx, cy - 1, 3 if absi(lx) == w else 2, NEIGE)

## Fissure : marche aléatoire de 1 px, ton `ton`, avec lèvre claire `levre` d'un côté.
static func _fissure(t: Toile, r: RandomNumberGenerator, x: int, y: int, longueur: int, ton: int, rampe: int, levre := -1, rampe_levre := -1) -> void:
	var dir := Vector2i([1, -1][r.randi() % 2], [1, -1][r.randi() % 2])
	var horiz := r.randf() < 0.5
	for i in longueur:
		t.pose(x, y, ton, rampe)
		if levre >= 0:
			t.pose(x, y + 1, levre, rampe if rampe_levre < 0 else rampe_levre)
		if horiz:
			x += dir.x
			if r.randf() < 0.35:
				y += dir.y if r.randf() < 0.7 else -dir.y
		else:
			y += dir.y
			if r.randf() < 0.35:
				x += dir.x if r.randf() < 0.7 else -dir.x
		if r.randf() < 0.06:
			horiz = not horiz

## Amas arrondi (galet, motte, coussin) : centre (cx, cy), rayons rx/ry ; biseau clair en haut,
## ombre en bas (seul biseau toléré par la bible, §4.6).
static func _amas(t: Toile, cx: int, cy: int, rx: float, ry: float, ton: int, rampe: int, biseau := true, ombre := -1, rampe_ombre := -1) -> void:
	var ix := int(ceil(rx))
	var iy := int(ceil(ry))
	for dy in range(-iy, iy + 1):
		for dx in range(-ix, ix + 1):
			var q := (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
			if q > 1.0:
				continue
			var tt := ton
			if biseau:
				var haut := (dx * dx) / (rx * rx) + ((dy + 1) * (dy + 1)) / (ry * ry) > 1.0
				var bas := (dx * dx) / (rx * rx) + ((dy - 1) * (dy - 1)) / (ry * ry) > 1.0
				if haut and not bas:
					tt = ton + 1
				elif bas and dy > 0:
					tt = ton - 1
			t.pose(cx + dx, cy + dy, tt, rampe)
	if ombre >= 0:
		for dx in range(-ix + 1, ix):
			t.pose(cx + dx, cy + iy + 1, ombre, rampe if rampe_ombre < 0 else rampe_ombre)

static func _trait(t: Toile, x0: int, y0: int, dx: int, dy: int, l: int, ton: int, rampe: int) -> void:
	for i in l:
		t.pose(x0 + dx * i, y0 + dy * i, ton, rampe)

# --- tuiles ---------------------------------------------------------------------------------------

## Fond de neige : grandes plaques calmes de 2 tons proches, allongées dans le sens du vent (+y).
static func _fond_neige(t: Toile, g: int, clair: int, sombre: int, part_sombre: float, creux := 0.0) -> void:
	for y in t.n:
		for x in t.n:
			var w := _fbm(x, y, t.n, 4, 4, 2, g + 1) - 0.5
			var f := _fbm(x + w * 10.0, y, t.n, 10, 5, 3, g)
			var ton := clair
			if f < part_sombre:
				ton = sombre
			if f < creux:
				ton = sombre - 1
			t.pose(x, y, ton, NEIGE)
	t.filtre_mode(2)

static func tuile_neige(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5101 + v * 17
	_fond_neige(t, 510 + v * 3, 4, 3, 0.40 if v == 0 else 0.33, 0.16)
	# rides de vent organiques : orientation qui suit un champ de vent lent (±55°), longueurs, courbures
	# et épaisseurs variables, crêtes interrompues ; quelques congères longues et basses
	var nr := 70 if v == 0 else 46
	for i in nr:
		var cx := r.randi_range(0, N - 1)
		var cy := r.randi_range(0, N - 1)
		var ang := _flux(cx, cy, N, v) + r.randf_range(-0.3, 0.3)
		var u := r.randf()
		var L := r.randf_range(5.0, 11.0) if u < 0.5 else (r.randf_range(10.0, 20.0) if u < 0.85 else r.randf_range(18.0, 30.0))
		var H := 0 if u < 0.3 else (1 if u < 0.8 else 2)
		_ride_libre(t, cx, cy, ang, L, r.randf_range(-0.9, 0.9), H, 4, 0.18, v)
		if u > 0.6 and r.randf() < 0.5:
			# deuxième crête à l'écart, plus courte, pas parallèle tout à fait
			var d := r.randf_range(4.0, 8.0)
			_ride_libre(t, cx - sin(ang) * d, cy + cos(ang) * d, ang + r.randf_range(-0.25, 0.25), L * r.randf_range(0.5, 0.85), r.randf_range(-0.7, 0.7), mini(H, 1), 4, 0.25, v)
	for i in (7 if v == 0 else 5):
		var cx := r.randi_range(0, N - 1)
		var cy := r.randi_range(0, N - 1)
		_ride_libre(t, cx, cy, _flux(cx, cy, N, v) + r.randf_range(-0.2, 0.2), r.randf_range(32.0, 54.0), r.randf_range(-0.5, 0.5), 3, 4, 0.3, v)
	# petits creux (vent tourbillonnant) en amas de 2-3 px
	for i in 40:
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		_trait(t, x, y, 1, 0, r.randi_range(2, 4), 3, NEIGE)
		_trait(t, x + 1, y + 1, 1, 0, r.randi_range(1, 3), 2, NEIGE)
	# grains de reflet : paires/trios alignés
	for i in 28:
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		t.pose(x, y, 5, NEIGE)
		t.pose(x + 1, y - (i % 2), 5, NEIGE)
	return t

static func tuile_croute(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5701 + v * 17
	_fond_neige(t, 570 + v * 3, 4, 3, 0.45, 0.0)
	# langues de sastrugi dans le sens du vent
	for i in (9 if v == 0 else 6):
		_sastrugi(t, r.randi_range(0, N - 1), r.randi_range(0, N - 1), r.randi_range(14, 28), r.randi_range(2, 4))
	# croûte fendue : fissures sombres à lèvre claire
	for i in (10 if v == 0 else 14):
		_fissure(t, r, r.randi_range(0, N - 1), r.randi_range(0, N - 1), r.randi_range(8, 22), 2, NEIGE, 4)
	# reflets polis en petits amas alignés
	for i in 18:
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		t.pose(x, y, 5, NEIGE)
		t.pose(x + 1, y, 5, NEIGE)
		if i % 3 == 0:
			t.pose(x + 2, y - 1, 5, NEIGE)
	return t

static func tuile_pietinee(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5201 + v * 17
	# neige tassée et brassée : bosses et creux de 3-8 px
	for y in N:
		for x in N:
			var f := _fbm(x, y, N, 12, 12, 2, 520 + v)
			var ton := 3
			if f < 0.32:
				ton = 2
			elif f > 0.72:
				ton = 4
			t.pose(x, y, ton, NEIGE)
	t.filtre_mode(2)
	# vieilles empreintes à moitié effacées (le shader en ajoute de nettes, orientées sur le chemin)
	for i in (26 if v == 0 else 18):
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		var vert := r.randf() < 0.6
		for a in 5:
			for b in 3:
				if (a == 0 or a == 4) and (b == 0 or b == 2):
					continue
				var px := x + (b if vert else a)
				var py := y + (a if vert else b)
				t.pose(px, py, 2, NEIGE)
	# saletés : terre et aiguilles écrasées, en amas de 2-3 px
	for i in (10 if v == 0 else 16):
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		t.pose(x, y, 2, TERRE)
		t.pose(x + 1, y, 3, TERRE)
		if r.randf() < 0.5:
			t.pose(x, y + 1, 2, TERRE)
	return t

static func tuile_terre(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5301 + v * 17
	for y in N:
		for x in N:
			var f := _fbm(x, y, N, 8, 8, 3, 530 + v)
			var ton := 2
			if f < 0.36:
				ton = 1
			elif f > 0.64:
				ton = 3
			t.pose(x, y, ton, TERRE)
	t.filtre_mode(2)
	# mottes gelées
	for i in 70:
		_amas(t, r.randi_range(0, N - 1), r.randi_range(0, N - 1), r.randf_range(1.2, 2.8), r.randf_range(1.0, 2.0), r.randi_range(2, 3), TERRE, true, 0)
	# givre dans les creux (amas irréguliers)
	for y in N:
		for x in N:
			var f := _fbm(x, y, N, 10, 10, 2, 535 + v)
			if f > 0.70:
				t.pose(x, y, 3 if f < 0.76 else 4, NEIGE)
	# cailloux
	for i in 22:
		var cx := r.randi_range(0, N - 1)
		var cy := r.randi_range(0, N - 1)
		_amas(t, cx, cy, r.randf_range(1.0, 2.2), r.randf_range(0.8, 1.6), r.randi_range(2, 3), PIERRE, true, 1, TERRE)
	# aiguilles rousses éparses
	for i in 14:
		var d: Vector2i = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)][r.randi() % 4]
		_trait(t, r.randi_range(0, N - 1), r.randi_range(0, N - 1), d.x, d.y, r.randi_range(2, 3), 1, ROUX)
	t.filtre_mode(1)
	return t

static func tuile_aiguilles(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5401 + v * 17
	# fond : neige ombrée sous le couvert, terre là où le tapis est épais
	for y in N:
		for x in N:
			var f := _fbm(x, y, N, 6, 6, 3, 540 + v)
			if f < 0.6:
				t.pose(x, y, 3 if f > 0.42 else 2, NEIGE)
			else:
				t.pose(x, y, 2 if f > 0.68 else 3, TERRE)
	t.filtre_mode(2)
	# aiguilles : traits de 2-4 px, groupés là où le tapis est dense
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	for i in (900 if v == 0 else 700):
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		var f := _fbm(x, y, N, 6, 6, 3, 540 + v)
		if r.randf() > f * 1.6:
			continue
		var d: Vector2i = dirs[r.randi() % 4]
		var rp := ROUX if r.randf() < 0.25 else TERRE
		var ton := r.randi_range(2, 3) if rp == TERRE else 1
		_trait(t, x, y, d.x, d.y, r.randi_range(2, 4), ton, rp)
	# cônes d'épicéa (4×2) et brindilles
	for i in 9:
		var cx := r.randi_range(0, N - 1)
		var cy := r.randi_range(0, N - 1)
		_amas(t, cx, cy, 1.0, 2.0, 2, TERRE, true, 0)
	for i in 6:
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		var d: Vector2i = dirs[r.randi() % 4]
		var l := r.randi_range(6, 11)
		_trait(t, x, y, d.x, d.y, l, 2, BOIS)
		_trait(t, x + d.x * (l / 2), y + d.y * (l / 2), d.y if d.y != 0 else 1, d.x, 3, 1, BOIS)
	# paquets de neige tombés des branches
	for i in 7:
		_amas(t, r.randi_range(0, N - 1), r.randi_range(0, N - 1), r.randf_range(2.0, 3.5), r.randf_range(1.5, 2.5), 4, NEIGE, true, 2)
	return t

static func tuile_mousse(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5501 + v * 17
	for y in N:
		for x in N:
			t.pose(x, y, 1, VERT)
	# coussins de mousse : amas arrondis, sommet givré
	for i in (150 if v == 0 else 120):
		var cx := r.randi_range(0, N - 1)
		var cy := r.randi_range(0, N - 1)
		var rx := r.randf_range(1.8, 4.5)
		_amas(t, cx, cy, rx, rx * r.randf_range(0.6, 0.9), r.randi_range(2, 3), VERT, true, 0)
		if r.randf() < 0.55:
			t.pose(cx, cy - int(rx * 0.6), 4, VERT)
			t.pose(cx + 1, cy - int(rx * 0.6), 5 if r.randf() < 0.5 else 4, VERT)
	# poches de neige entre les coussins
	for y in N:
		for x in N:
			var f := _fbm(x, y, N, 7, 7, 2, 550 + v)
			if f > 0.68:
				t.pose(x, y, 3 if f < 0.74 else 4, NEIGE)
	# givre : aiguilles de cristal en amas de 2-3 px
	for i in 40:
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		t.pose(x, y, 4, NEIGE)
		t.pose(x + 1, y + (1 if i % 2 == 0 else 0), 4, NEIGE)
	t.filtre_mode(1)
	return t

static func tuile_roche(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5601 + v * 17
	# dalles : Voronoï périodique, chaque dalle a son ton ; arête haute claire, bas plus sombre,
	# joints de 1 px
	var graines: Array[Vector2] = []
	var tons: Array[int] = []
	for i in 14:
		graines.append(Vector2(r.randf() * N, r.randf() * N * 0.9))
		tons.append(r.randi_range(2, 3))
	var proche := PackedInt32Array()
	proche.resize(N * N)
	var marge := PackedFloat32Array()
	marge.resize(N * N)
	for y in N:
		for x in N:
			var d1 := INF
			var d2 := INF
			var i1 := 0
			for i in graines.size():
				var dd := Vector2(wrapf(x - graines[i].x, -N * 0.5, N * 0.5), wrapf(y - graines[i].y, -N * 0.5, N * 0.5) * 1.5)
				var d := dd.length()
				if d < d1:
					d2 = d1
					d1 = d
					i1 = i
				elif d < d2:
					d2 = d
			proche[y * N + x] = i1
			marge[y * N + x] = d2 - d1
	for y in N:
		for x in N:
			var k := y * N + x
			var ton := tons[proche[k]]
			if marge[k] < 1.1:
				ton = 0
			elif proche[t.k(x, y - 1)] != proche[k] or proche[t.k(x, y - 2)] != proche[k]:
				ton += 1  # arête haute
			elif proche[t.k(x, y + 2)] != proche[k]:
				ton -= 1  # bas de dalle, dans l'ombre
			t.pose(x, y, ton, PIERRE)
	# fissures fines
	for i in 10:
		_fissure(t, r, r.randi_range(0, N - 1), r.randi_range(0, N - 1), r.randi_range(5, 12), 1, PIERRE)
	# lichen gris-vert et quelques taches rousses
	for i in 26:
		var cx := r.randi_range(0, N - 1)
		var cy := r.randi_range(0, N - 1)
		if t.t_de(cx, cy) == 0:
			continue
		_amas(t, cx, cy, r.randf_range(1.0, 2.2), r.randf_range(0.8, 1.6), 4, VERT, false)
	for i in 8:
		var cx := r.randi_range(0, N - 1)
		var cy := r.randi_range(0, N - 1)
		t.pose(cx, cy, 4, TOURBE)
		t.pose(cx + 1, cy, 3, TOURBE)
	# neige dans les joints et sur le haut des dalles
	for y in N:
		for x in N:
			var f := _fbm(x, y, N, 5, 5, 2, 560 + v)
			if f > (0.62 if v == 0 else 0.56) and (t.t_de(x, y) == 0 or t.t_de(x, y) >= 3 or f > 0.72):
				t.pose(x, y, 4 if f > 0.68 else 3, NEIGE)
	t.filtre_mode(1)
	return t

## Fissure fine de glace : trait de 1 texel à direction persistante (dérive lente), quelques
## embranchements courts ; ton sombre, lèvre claire sur une partie seulement.
static func _fente(t: Toile, r: RandomNumberGenerator, x0: float, y0: float, ang: float, longueur: int, ton: int, branche := true) -> void:
	var p := Vector2(x0, y0)
	var a := ang
	var pas_levre := r.randi_range(3, 7)
	for i in longueur:
		a += r.randf_range(-0.22, 0.22)
		p += Vector2(cos(a), sin(a))
		var px := roundi(p.x)
		var py := roundi(p.y)
		t.pose(px, py, ton, GLACE)
		if (i / pas_levre) % 2 == 0:
			t.pose(px, py - 1, 3, GLACE)  # lèvre claire côté haut, par tronçons
		if branche and i > 4 and i < longueur - 6 and r.randf() < 0.06:
			_fente(t, r, p.x, p.y, a + r.randf_range(0.6, 1.1) * (1.0 if r.randf() < 0.5 else -1.0), r.randi_range(4, 9), ton, false)

static func tuile_glace(v: int) -> Toile:
	var t := Toile.new(N)
	var r := RandomNumberGenerator.new()
	r.seed = 5801 + v * 17
	# glace lisse : fond uni ton 2 (bleu clair, aucun bruit) ; le reflet est un voile de ton 3 en bandes
	# allongées, effilées et interrompues (ciel qui se mire) ; une ou deux fissures fines, quelques bulles.
	for y in N:
		for x in N:
			t.pose(x, y, 2, GLACE)
	# reflets : bandes de ton 3 de 1-2 texels de haut, 8-26 de long, légèrement inclinées, alignées
	# sur un même sens (la lumière) ; elles s'effilent et se cassent
	var sens := r.randf_range(-0.35, 0.1)
	for i in 11:
		var cx := r.randf_range(0.0, N)
		var cy := r.randf_range(0.0, N)
		var L := r.randf_range(14.0, 44.0)
		var ep := 1 if r.randf() < 0.45 else (2 if r.randf() < 0.7 else 3)
		var a := sens + r.randf_range(-0.12, 0.12)
		for q in int(L):
			var u := float(q) / L
			var h := ep if (u > 0.2 and u < 0.8) else 1
			var px := roundi(cx + cos(a) * q)
			var py := roundi(cy + sin(a) * q)
			if _h(px, py, 589 + v) < 0.12:
				continue
			for d in h:
				t.pose(px, py + d, 3, GLACE)
	# deux fissures fines, rares
	for i in 2:
		_fente(t, r, r.randf_range(0.0, N), r.randf_range(0.0, N), r.randf_range(0.0, TAU), r.randi_range(22, 44), 1)
	# bulles d'air : amas de 2-3 texels clairs
	for i in 9:
		var x := r.randi_range(0, N - 1)
		var y := r.randi_range(0, N - 1)
		t.pose(x, y, 3, GLACE)
		t.pose(x + 1, y, 3, GLACE)
		if i % 3 == 0:
			t.pose(x, y + 1, 3, GLACE)
	t.filtre_mode(1)
	return t

static func tuile(matiere: int, v: int) -> Toile:
	match matiere:
		M_NEIGE: return tuile_neige(v)
		M_PIETINEE: return tuile_pietinee(v)
		M_TERRE: return tuile_terre(v)
		M_AIGUILLES: return tuile_aiguilles(v)
		M_MOUSSE: return tuile_mousse(v)
		M_ROCHE: return tuile_roche(v)
		M_GLACE: return tuile_glace(v)
	return tuile_croute(v)

## Agrandissement pixel art ×2 (Scale2x / EPX) : arrondit les diagonales sans créer de couleur.
static func scale2x(t: Toile) -> Toile:
	var o := Toile.new(t.n * 2)
	for y in t.n:
		for x in t.n:
			var p := t.ton[t.k(x, y)] | (t.rampe[t.k(x, y)] << 8)
			var A := t.ton[t.k(x, y - 1)] | (t.rampe[t.k(x, y - 1)] << 8)
			var B := t.ton[t.k(x + 1, y)] | (t.rampe[t.k(x + 1, y)] << 8)
			var C := t.ton[t.k(x - 1, y)] | (t.rampe[t.k(x - 1, y)] << 8)
			var D := t.ton[t.k(x, y + 1)] | (t.rampe[t.k(x, y + 1)] << 8)
			var e := [p, p, p, p]
			if C == A and C != D and A != B:
				e[0] = A
			if A == B and A != C and B != D:
				e[1] = B
			if D == C and D != B and C != A:
				e[2] = C
			if B == D and B != A and D != C:
				e[3] = D
			for q in 4:
				var i := o.k(x * 2 + (q & 1), y * 2 + (q >> 1))
				o.ton[i] = e[q] & 0xff
				o.rampe[i] = e[q] >> 8
			var c := t.classe[t.k(x, y)]
			for q in 4:
				o.classe[o.k(x * 2 + (q & 1), y * 2 + (q >> 1))] = c
	return o

## Vagues de vent à 32 texels/m : traits courts de crête claire (+ ombre froide d'un texel dessous),
## en PLAQUES (zones de neige lisse entre elles), d'orientation, d'espacement et de longueur variables
## par plaque, lignes interrompues. Détail fin seulement : les grandes formes restent celles de la
## couche 16 texels/m (fondu 4-8 m imperceptible).
static func _rides_fines(t: Toile, matiere: int, v: int) -> void:
	var n := t.n
	var r := RandomNumberGenerator.new()
	r.seed = 7400 + v * 5 + matiere
	var essais := 300 if matiere == M_NEIGE else 200
	for i in essais:
		var cx := r.randi_range(0, n - 1)
		var cy := r.randi_range(0, n - 1)
		if t.r_de(cx, cy) != NEIGE:
			continue
		# plaques : la densité varie de 0 (neige lisse) à 1 (neige très ridée)
		var dens := _fbm(cx, cy, n, 3, 3, 2, 7400 + v * 5 + matiere)
		if dens < 0.42 or r.randf() > (dens - 0.3) * 2.2:
			continue
		var ang := _flux(cx, cy, n, v) + r.randf_range(-0.35, 0.35)
		var u := r.randf()
		var L := r.randf_range(5.0, 12.0) if u < 0.6 else r.randf_range(12.0, 26.0)
		_ride_libre(t, cx, cy, ang, L, r.randf_range(-1.0, 1.0), 0 if u < 0.8 else 1, t.t_de(cx, cy), 0.3, v + 5)

## Détail de proximité à 32 texels/m, semé sur la tuile agrandie : amas de 2-5 px d'un ton voisin
## (grains, cristaux, fines ombres, aiguilles, fissures capillaires). Jamais un pixel isolé.
static func affiner(t: Toile, matiere: int, v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7301 + matiere * 31 + v * 7
	var n := t.n
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	if matiere == M_NEIGE or matiere == M_CROUTE:
		_rides_fines(t, matiere, v)
	var nb := 300 if matiere in [M_TERRE, M_ROCHE] else (700 if matiere in [M_NEIGE, M_CROUTE, M_PIETINEE] else 550)
	for i in nb:
		var x := r.randi_range(0, n - 1)
		var y := r.randi_range(0, n - 1)
		var t0 := t.t_de(x, y)
		var r0 := t.r_de(x, y)
		match matiere:
			M_NEIGE, M_CROUTE, M_PIETINEE:
				if r0 != NEIGE:
					continue
				# les petits détails se groupent en plaques (jamais semés uniformément)
				if matiere != M_PIETINEE and _fbm(x, y, n, 3, 3, 2, 7440 + v) < 0.45:
					continue
				var u := r.randf()
				if u < 0.35:
					# fine ombre sous un grain : 2-3 px un ton plus bas
					_trait(t, x, y, 1, 0, r.randi_range(2, 3), t0 - 1, NEIGE)
					t.pose(x, y - 1, mini(t0 + 1, 5), NEIGE)
				elif u < 0.55:
					# cristaux : paire claire
					t.pose(x, y, mini(t0 + 1, 5), NEIGE)
					t.pose(x + 1, y + (i % 2), mini(t0 + 1, 5), NEIGE)
				elif matiere == M_CROUTE and u < 0.7:
					_trait(t, x, y, 1, 0, r.randi_range(3, 5), t0 - 1, NEIGE)  # fissure capillaire
				elif matiere == M_PIETINEE:
					t.pose(x, y, t0 - 1, NEIGE)
					t.pose(x, y + 1, t0 - 1, NEIGE)
			M_TERRE:
				if i % 3 == 0:
					t.pose(x, y, r.randi_range(2, 3), PIERRE)
					t.pose(x + 1, y, 2, PIERRE)
				elif i % 3 == 1:
					t.pose(x, y, 4, NEIGE)
					t.pose(x + 1, y + 1, 3, NEIGE)
				else:
					t.pose(x, y, t0 + 1, r0)
					t.pose(x, y + 1, t0 + 1, r0)
			M_AIGUILLES:
				var d: Vector2i = dirs[r.randi() % 4]
				var rp := ROUX if r.randf() < 0.3 else TERRE
				_trait(t, x, y, d.x, d.y, r.randi_range(3, 5), 1 if rp == ROUX else r.randi_range(2, 3), rp)
			M_MOUSSE:
				if r0 == VERT:
					t.pose(x, y, mini(t0 + 1, 5), VERT)
					t.pose(x + 1, y, mini(t0 + 1, 5), VERT)
			M_ROCHE:
				if r0 == PIERRE and i % 2 == 0:
					var d: Vector2i = dirs[r.randi() % 4]
					_trait(t, x, y, d.x, d.y, r.randi_range(3, 6), maxi(t0 - 1, 0), PIERRE)
				elif r0 == PIERRE:
					t.pose(x, y, mini(t0 + 1, 4), PIERRE)
					t.pose(x, y + 1, mini(t0 + 1, 4), PIERRE)
			M_GLACE:
				pass  # glace lisse : aucun grain en proximité

## Détails épars (période 5 m, décalée de celle des tuiles) : R ton, G rampe, B classe (0 = rien).
static func toile_details() -> Toile:
	var t := Toile.new(ND)
	var r := RandomNumberGenerator.new()
	r.seed = 5901
	var occupe := func(x: int, y: int, l: int) -> bool:
		for dy in range(-1, 3):
			for dx in range(-1, l + 1):
				if t.classe[t.k(x + dx, y + dy)] != 0:
					return true
		return false
	var marque := func(x: int, y: int, ton: int, rampe: int, c: int) -> void:
		t.pose(x, y, ton, rampe)
		t.classe[t.k(x, y)] = c
	# scintillements : paires et trios alignés de reflets
	for i in 70:
		var x := r.randi_range(0, ND - 1)
		var y := r.randi_range(0, ND - 1)
		if occupe.call(x, y, 3):
			continue
		var d: Vector2i = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(1, 1)][i % 3]
		var l := 2 if i % 4 else 3
		for s in l:
			marque.call(x + d.x * s, y + d.y * s, 5, NEIGE, D_ECLAT)
	# cailloux qui percent : galet de 2-4 px, chapeau de neige
	for i in 11:
		var x := r.randi_range(0, ND - 1)
		var y := r.randi_range(0, ND - 1)
		if occupe.call(x - 2, y - 2, 6):
			continue
		var w := r.randi_range(2, 4)
		var h := 2 if w < 4 else 3
		for dy in h:
			for dx in w:
				if (dx == 0 or dx == w - 1) and (dy == 0 or dy == h - 1) and w > 2:
					continue
				var ton := 3 if dy == 0 else (2 if dy < h - 1 else 1)
				marque.call(x + dx, y + dy, ton, PIERRE, D_CAILLOU)
		for dx in range(1, w - 1 if w > 2 else w):
			marque.call(x + dx, y - 1, 4, NEIGE, D_CAILLOU)
		for dx in range(0, w):
			marque.call(x + dx, y + h, 2, NEIGE, D_CAILLOU)  # ombre portée courte
	# brindilles : trait de 5-11 px et une fourche
	var dirs := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1), Vector2i(0, 1)]
	for i in 9:
		var x := r.randi_range(0, ND - 1)
		var y := r.randi_range(0, ND - 1)
		var d: Vector2i = dirs[r.randi() % 4]
		var l := r.randi_range(5, 11)
		if occupe.call(x, y, l):
			continue
		for s in l:
			marque.call(x + d.x * s, y + d.y * s, 1 if s % 4 else 2, BOIS if i % 3 else TERRE, D_BRINDILLE)
		var f := r.randi_range(2, l - 2)
		var fd := Vector2i(d.x, -1 if d.y >= 0 else 1) if d.x != 0 else Vector2i(1, 1)
		for s in 3:
			marque.call(x + d.x * f + fd.x * (s + 1), y + d.y * f + fd.y * (s + 1), 2, BOIS, D_BRINDILLE)
	# herbes sèches qui percent : touffes vues de dessus, brins rayonnants autour d'un cœur sombre
	var rayons := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(0, 1)]
	for i in 18:
		var x := r.randi_range(0, ND - 1)
		var y := r.randi_range(0, ND - 1)
		if occupe.call(x - 3, y - 3, 6):
			continue
		marque.call(x, y, 1, TOURBE, D_HERBE)
		var nb := r.randi_range(4, 7)
		for b2 in nb:
			var d: Vector2i = rayons[(b2 * 3 + i) % rayons.size()]
			var l := r.randi_range(1, 3)
			for s2 in l:
				var ton := 2 if s2 == 0 else (3 if s2 < l - 1 else 4)
				marque.call(x + d.x * (s2 + 1), y + d.y * (s2 + 1), ton, TOURBE, D_HERBE)
	return t

# --- assemblage en textures ----------------------------------------------------------------------

static func _couleurs() -> Array:
	var l: Array = []
	for rp: Array in RAMPES:
		var c: Array[Color] = []
		for h: String in rp:
			c.append(Color(h))
		l.append(c)
	return l

## Rampes en texture 8×8 (ligne = rampe, colonne = ton, dernier ton répété).
static func lut() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cs := _couleurs()
	for y in 8:
		var c: Array = cs[mini(y, cs.size() - 1)]
		for x in 8:
			img.set_pixel(x, y, c[mini(x, c.size() - 1)])
	return ImageTexture.create_from_image(img)

static func image_index(t: Toile, avec_classe := false) -> Image:
	var data := PackedByteArray()
	var c := 3 if avec_classe else 2
	data.resize(t.n * t.n * c)
	for k in t.n * t.n:
		data[k * c] = t.ton[k]
		data[k * c + 1] = t.rampe[k]
		if avec_classe:
			data[k * c + 2] = t.classe[k]
	return Image.create_from_data(t.n, t.n, false, Image.FORMAT_RGB8 if avec_classe else Image.FORMAT_RG8, data)

static func image_couleur(t: Toile, fond := Color(0, 0, 0, 0)) -> Image:
	var cs := _couleurs()
	var img := Image.create(t.n, t.n, false, Image.FORMAT_RGBA8)
	for y in t.n:
		for x in t.n:
			var k := y * t.n + x
			if t.classe[k] == 0 and fond.a > 0.0 and t.n == ND:
				img.set_pixel(x, y, fond)
			else:
				img.set_pixel(x, y, cs[t.rampe[k]][t.ton[k]])
	return img

## Calcule toutes les ressources : {"index": Texture2DArray, "couleur": Texture2DArray, "details": ImageTexture, "toiles": Array}.
static func calculer() -> Dictionary:
	var index: Array[Image] = []
	var couleur: Array[Image] = []
	var toiles: Array = []
	for m in NB_MATIERES:
		for v in VARIANTES:
			var t := tuile(m, v)
			toiles.append(t)
			index.append(image_index(t))
			var c := image_couleur(t)
			c.generate_mipmaps()
			couleur.append(c)
	var ai := Image.create(N, N * index.size(), false, Image.FORMAT_RG8)
	var ac := Image.create(N, N * index.size(), false, Image.FORMAT_RGBA8)
	for i in index.size():
		ai.blit_rect(index[i], Rect2i(0, 0, N, N), Vector2i(0, i * N))
		var c0 := couleur[i].duplicate()
		c0.clear_mipmaps()
		ac.blit_rect(c0, Rect2i(0, 0, N, N), Vector2i(0, i * N))
	# tuiles de proximité (32 texels/m) : Scale2x de chaque tuile + détail fin
	var ai2 := Image.create(N * 2, N * 2 * index.size(), false, Image.FORMAT_RG8)
	for i in index.size():
		var t2 := scale2x(toiles[i])
		affiner(t2, i / 2, i % 2)
		ai2.blit_rect(image_index(t2), Rect2i(0, 0, N * 2, N * 2), Vector2i(0, i * N * 2))
	var d := toile_details()
	toiles.append(d)
	var d2 := image_index(scale2x(d), true)
	var res := _textures(ai, ac, image_index(d, true), ai2, d2)
	res["toiles"] = toiles
	res["atlas_index"] = ai
	res["atlas_couleur"] = ac
	res["image_details"] = image_index(d, true)
	res["atlas_index2"] = ai2
	res["image_details2"] = d2
	return res

## Atlas (couches empilées verticalement) → Texture2DArray ; couleur avec mipmaps (lointain).
static func _textures(ai: Image, ac: Image, det: Image, ai2: Image, det2: Image) -> Dictionary:
	var index: Array[Image] = []
	var couleur: Array[Image] = []
	for i in ai.get_height() / N:
		index.append(ai.get_region(Rect2i(0, i * N, N, N)))
		var c := ac.get_region(Rect2i(0, i * N, N, N))
		c.generate_mipmaps()
		couleur.append(c)
	var ti := Texture2DArray.new()
	ti.create_from_images(index)
	var tc := Texture2DArray.new()
	tc.create_from_images(couleur)
	var index2: Array[Image] = []
	for i in ai2.get_height() / (N * 2):
		index2.append(ai2.get_region(Rect2i(0, i * N * 2, N * 2, N * 2)))
	var ti2 := Texture2DArray.new()
	ti2.create_from_images(index2)
	return {"index": ti, "couleur": tc, "details": ImageTexture.create_from_image(det),
		"index2": ti2, "details2": ImageTexture.create_from_image(det2)}

## Ressources précalculées (outils/generer_sol.gd), recalculées si absentes.
static func charger() -> Dictionary:
	var fi := DOSSIER + "/sol_index.res"
	var fc := DOSSIER + "/sol_couleur.res"
	var fd := DOSSIER + "/sol_details.res"
	var fi2 := DOSSIER + "/sol_index2.res"
	var fd2 := DOSSIER + "/sol_details2.res"
	if ResourceLoader.exists(fi) and ResourceLoader.exists(fc) and ResourceLoader.exists(fd) and ResourceLoader.exists(fi2) and ResourceLoader.exists(fd2):
		return _textures(load(fi), load(fc), load(fd), load(fi2), load(fd2))
	push_warning("SolTuiles : ressources absentes, calcul au chargement (lancer outils/generer_sol.gd)")
	return calculer()
