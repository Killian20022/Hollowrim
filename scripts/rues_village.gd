class_name RuesVillage
extends AbordsVillage
## Lot C7a (village v2, plan docs/PLAN_VILLAGE_V2.md, référence references/village_v2_planche.png vues 1-3 et 6) :
## sols et rues du village posés sur le relief de `ReliefVillage`.
## - PAVÉS irréguliers (même pierre bombée gris-bleu que le kit d'AbordsVillage / C1b, plus simple : ~20 triangles par pavé)
##   sur la place, la rue principale, les rues du pont, de la porte N, de la porte E et du quai, et les paliers de la haute rue ;
##   joints : neige au pied des flancs (alpha 0) sur terre / neige piétinée peinte par la carte de sol (`matiere_sol`).
##   Découpés en tuiles de 16 m (une par MeshInstance) pour le tri hors champ.
## - ESCALIERS de pierre : 3 volées de 10 marches dans le couloir x 42..46 ; collision = une RAMPE INVISIBLE (boîte inclinée)
##   par volée, posée au milieu des contremarches (le pied ne flotte ni ne s'enfonce de plus d'une demi-marche).
## - MURS DE SOUTÈNEMENT en pierre sèche sur chaque transition de bande du relief (et joues du couloir d'escalier) :
##   le bloc remplit la case de transition (2 m), dessus plat au niveau de la terrasse haute, collision en boîtes.
## - CHAMPS à sillons (bourrelets de neige sur la terre labourée peinte par la carte de sol), clôtures du kit, lanternes du kit.
## - Le mobilier (modules Blender) est posé par `MobilierVillage` (scripts/mobilier_village.gd).
## Pas de fumée, pas de lumière réelle ici (les lanternes sont émissives ; flaques de lumière additives du kit).

const PAVE := 0.46          # pas moyen des pavés (m) ; la taille varie par plaques (0,75 à 1,3 ×)
const TUILE := 16.0         # côté des tuiles de pavés (m)
const PORTEE_PAVES := 50.0   # perf (C7a) : au-delà, la carte de sol peint déjà terre et neige piétinée sous les pavés
const PORTEE_FLANCS := 20.0  # perf : au-delà, version « loin » des tuiles (dessus seuls, sans les flancs : 1/3 des triangles)

## Place principale (polygone du plan).
const PLACE := [Vector2(31, 28), Vector2(52, 27.5), Vector2(56, 33), Vector2(55, 45), Vector2(46, 48.5), Vector2(33, 46.5), Vector2(30, 38)]
## Rues pavées : [points, largeur].
const RUES := [
	[[Vector2(27.7, 25.2), Vector2(33, 30), Vector2(38, 32.5)], 4.0],      # porte SO → place
	[[Vector2(44, 47.0), Vector2(44, 57.2)], 3.6],                        # place → pont
	[[Vector2(53, 28.5), Vector2(53.6, 19.0), Vector2(54, 14.3)], 3.2],   # place → porte N
	[[Vector2(55.0, 37), Vector2(64, 36.4), Vector2(73.5, 36)], 3.2],     # place → porte E
	[[Vector2(33, 46.0), Vector2(30.5, 53), Vector2(27.5, 57.6)], 2.6],   # place → moulin à eau / quai
]
## Paliers pavés de la haute rue : Rect2 (x, z, largeur, profondeur).
const PALIERS := [Rect2(39, 70, 11, 2), Rect2(39, 76, 12, 2), Rect2(37, 82.4, 18, 8.4)]
## Couloir d'escalier (sans pavés : marches).
const COULOIR := Rect2(42, 66, 4, 16)
## Chemins de terre : [points, largeur] (porte N → piste de la grotte, ferme B, porte E → fermes / moulin à vent).
## Fermes et moulin à vent aux positions de C7b : FA (79,5 ; 24,5), GA (87 ; 24), FB (61 ; 3,5), MV (95,5 ; 13).
const CHEMINS_TERRE := [
	[[Vector2(54, 14.3), Vector2(53.4, 9), Vector2(53, 4), Vector2(53.2, -3), Vector2(53, -8), Vector2(53.8, -13), Vector2(54, -18), Vector2(53.5, -22), Vector2(53, -26.5)], 3.0],
	[[Vector2(53, 4), Vector2(56, 4.6), Vector2(58.5, 5.8)], 2.2],
	[[Vector2(73.5, 36), Vector2(76.0, 33.5), Vector2(76.6, 30.4), Vector2(78.5, 28.6)], 2.6],
	[[Vector2(76.6, 30.4), Vector2(81, 28.6), Vector2(86, 28.4), Vector2(90, 25.5), Vector2(92.5, 21), Vector2(94.5, 16.5)], 2.2],
]
## Champs : [coins (x0, z0, x1, z1), direction des sillons (Vector2), écart des sillons].
const CHAMPS := [
	[Rect2(77, 30.2, 13, 9.3), Vector2(0, 1), 0.95],
	[Rect2(76, 41.5, 10, 8.5), Vector2(0, 1), 0.95],
	[Rect2(57, -11, 13, 8), Vector2(1, 0), 0.9],
]
## Lanternes sur potence (émissives) : [x, z, côté de la potence (Vector2 monde)].
const LANTERNES := [
	[41.4, 56.4, Vector2(1, 0)], [46.6, 56.4, Vector2(-1, 0)],        # tête de pont
	[46.7, 70.7, Vector2(-1, 0)], [46.7, 76.7, Vector2(-1, 0)], [41.0, 83.0, Vector2(1, 0)],   # haute rue
	[30.6, 30.6, Vector2(0.6, -0.8)],                                  # rue principale
]

var _tuiles := {}           # Vector2i → BatiGeo.Maillage (pavés, dessus + flancs)
var _tuiles_loin := {}      # Vector2i → BatiGeo.Maillage (pavés, dessus seuls, au-delà de PORTEE_FLANCS)
var _marches := BatiGeo.Maillage.new()
var _murs := BatiGeo.Maillage.new()
var _sillons := BatiGeo.Maillage.new()
var _nb_paves := 0
var _neige_bruit := FastNoiseLite.new()   # plaques de neige cohérentes d'un pavé à l'autre

static func creer(monde_: Node, graine := 0) -> AbordsVillage:
	var r := RuesVillage.new()
	r.name = "RuesVillage"
	r.monde = monde_
	r.rng.seed = (graine if graine != 0 else hash("rues_village")) & 0x7fffffff
	r.origine = Vector2.ZERO
	r.axe = Vector2.RIGHT
	r.droite = Vector2.DOWN   # (0, 1) : _p(u, v) = (u, v) = coordonnées monde
	monde_.add_child(r)
	r._corps = StaticBody3D.new()
	r._corps.name = "CollisionsRues"
	r.add_child(r._corps)
	r._construire()
	return r

func _p(u: float, v: float) -> Vector2:
	return Vector2(u, v)

## Hauteur exacte du maillage du terrain (comme DetailsSol.hauteur_maillage) avec les sommets (cases de 2 m) en cache :
## les pavés interrogent le sol ~35 000 fois, monde.hauteur coûte cher (relief, village, rivière).
var _cache_h := {}
func _sommet(i: int, j: int) -> float:
	var cle := i * 4096 + j
	if not _cache_h.has(cle):
		var pas: float = monde.TAILLE / monde.CASES
		var demi: float = monde.TAILLE * 0.5
		_cache_h[cle] = monde.hauteur(i * pas - demi, j * pas - demi)
	return _cache_h[cle]

func _sol(p: Vector2) -> float:
	var pas: float = monde.TAILLE / monde.CASES
	var demi: float = monde.TAILLE * 0.5
	var u := (p.x + demi) / pas
	var v := (p.y + demi) / pas
	var i := floori(u)
	var j := floori(v)
	var fu := u - i
	var fv := v - j
	var ha := _sommet(i, j)
	var hb := _sommet(i + 1, j)
	var hc := _sommet(i, j + 1)
	if fu + fv <= 1.0:
		return ha + (hb - ha) * fu + (hc - ha) * fv
	var hd := _sommet(i + 1, j + 1)
	return hd + (hc - hd) * (1.0 - fu) + (hb - hd) * (1.0 - fv)

## Précalcul (SOCLE §6) : géométrie, collisions et touffes sont lues dans CACHE si la signature des entrées (sources, relief
## échantillonné) n'a pas changé ; sinon recalculées (≈ 1 s). `outils/generer_rues_village.gd` écrit / vérifie le fichier.
const CACHE := "res://assets/modeles/rues_village.cache"
const CACHE_VERSION := 2
enum { CACHE_LIRE, CACHE_ECRIRE, CACHE_VERIFIER }
static var cache_mode := CACHE_LIRE
static var cache_statut := ""   # "lu", "ecrit", "identique", "DIFFERENT", "perime", "absent"
static var temps_ms := 0

func _construire() -> void:
	var t0 := Time.get_ticks_msec()
	var h0: float = monde.h_village
	var sig := _signature()
	var lu := false
	if cache_mode == CACHE_LIRE and FileAccess.file_exists(CACHE):
		var f := FileAccess.open_compressed(CACHE, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		var d = f.get_var(false)
		if d is Dictionary and d.get("signature", "") == sig:
			_restaurer(d)
			lu = true
			cache_statut = "lu"
	if not lu:
		_paves()
		_escaliers(h0)
		_murs_soutenement(h0)
		_champs()
		for l: Array in LANTERNES:
			droite = l[2]
			_poteau_lanterne(l[0], l[1], 1.0, false)
		droite = Vector2.DOWN
		var d := _exporter(sig)
		if cache_mode == CACHE_ECRIRE:
			var f := FileAccess.open_compressed(CACHE, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
			f.store_var(d, false)
			cache_statut = "ecrit"
		elif cache_mode == CACHE_VERIFIER:
			if not FileAccess.file_exists(CACHE):
				cache_statut = "absent"
			else:
				var f := FileAccess.open_compressed(CACHE, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
				cache_statut = "identique" if var_to_bytes(f.get_var(false)) == var_to_bytes(d) else "DIFFERENT"
		else:
			cache_statut = "perime"
	_finaliser_rues()
	temps_ms = Time.get_ticks_msec() - t0
	print("RuesVillage (%s) : %d tri pavés en %d tuiles, %d tri marches, %d tri murs, %d tri sillons, %d formes de collision, %d ms" % [
		cache_statut, _compte_tuiles(), _tuiles.size(), _marches.v.size() / 3, _murs.v.size() / 3, _sillons.v.size() / 3, _corps.get_child_count(), temps_ms])

## Signature : version, sources qui façonnent la géométrie, hauteur du relief tous les 4 m sur l'emprise (x 20..100, z -12..92).
func _signature() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([CACHE_VERSION, monde.h_village]))
	for chemin in ["res://scripts/rues_village.gd", "res://scripts/relief_village.gd", "res://scripts/abords_village.gd", "res://scripts/bati_geo.gd"]:
		ctx.update((load(chemin) as GDScript).source_code.to_utf8_buffer())
	var hs := PackedFloat32Array()
	var x := 20.0
	while x <= 100.0:
		var z := -12.0
		while z <= 92.0:
			hs.append(monde.hauteur(x, z))
			z += 4.0
		x += 4.0
	ctx.update(hs.to_byte_array())
	return ctx.finish().hex_encode()

func _maillages() -> Dictionary:
	var m := {"marches": _marches, "murs": _murs, "sillons": _sillons, "bois": _bois, "bouts": _bouts, "fer": _fer, "verre": _verre, "pierre": _pierre, "flaques": _flaques}
	for cle: Vector2i in _tuiles:
		m["paves_%d_%d" % [cle.x, cle.y]] = _tuiles[cle]
	for cle: Vector2i in _tuiles_loin:
		m["loin_%d_%d" % [cle.x, cle.y]] = _tuiles_loin[cle]
	return m

func _exporter(sig: String) -> Dictionary:
	var geo := {}
	var ms := _maillages()
	for nom: String in ms:
		var mm: BatiGeo.Maillage = ms[nom]
		geo[nom] = [mm.v, mm.n, mm.uv, mm.c]
	var formes: Array = []
	for cs: CollisionShape3D in _corps.get_children():
		var sh := cs.shape
		if sh is BoxShape3D:
			formes.append(["boite", (sh as BoxShape3D).size, cs.transform])
		elif sh is CylinderShape3D:
			formes.append(["cyl", Vector2((sh as CylinderShape3D).radius, (sh as CylinderShape3D).height), cs.transform])
		elif sh is ConvexPolygonShape3D:
			formes.append(["convexe", (sh as ConvexPolygonShape3D).points, cs.transform])
	return {"signature": sig, "geo": geo, "formes": formes, "touffes": _touffes, "buissons": _buissons, "nb_paves": _nb_paves}

func _restaurer(d: Dictionary) -> void:
	var geo: Dictionary = d["geo"]
	for nom: String in geo:
		var mm: BatiGeo.Maillage
		if nom.begins_with("paves_") or nom.begins_with("loin_"):
			var k := nom.split("_")
			mm = BatiGeo.Maillage.new()
			(_tuiles if k[0] == "paves" else _tuiles_loin)[Vector2i(int(k[1]), int(k[2]))] = mm
		else:
			mm = _maillages()[nom]
		var a: Array = geo[nom]
		mm.v = a[0]
		mm.n = a[1]
		mm.uv = a[2]
		mm.c = a[3]
	for f: Array in d["formes"]:
		var cs := CollisionShape3D.new()
		match f[0]:
			"boite":
				var b := BoxShape3D.new()
				b.size = f[1]
				cs.shape = b
			"cyl":
				var c := CylinderShape3D.new()
				c.radius = (f[1] as Vector2).x
				c.height = (f[1] as Vector2).y
				cs.shape = c
			_:
				var cv := ConvexPolygonShape3D.new()
				cv.points = f[1]
				cs.shape = cv
		cs.transform = f[2]
		_corps.add_child(cs)
	_touffes = d["touffes"]
	_buissons = d["buissons"]
	_nb_paves = d["nb_paves"]

func _compte_tuiles() -> int:
	var n := 0
	for k in _tuiles:
		n += (_tuiles[k] as BatiGeo.Maillage).v.size() / 3
	return n

# ------------------------------------------------------------------ zones (statiques : aussi lues par la carte de sol)

static func _d_polyligne(p: Vector2, pts: Array) -> float:
	var d := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		d = minf(d, p.distance_to(a + ab * t))
	return d

static func _d_polygone(p: Vector2, poly: Array) -> float:
	var dmin := INF
	var dedans := false
	var n := poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		dmin = minf(dmin, p.distance_to(a + ab * t))
		if (a.y > p.y) != (b.y > p.y) and p.x < a.x + (p.y - a.y) * ab.x / ab.y:
			dedans = not dedans
	return -dmin if dedans else dmin

static func _d_rect(p: Vector2, r: Rect2) -> float:
	var q := (p - r.get_center()).abs() - r.size * 0.5
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)

## Profondeur (m) à l'intérieur de la zone pavée (négatif dehors).
static func profondeur_pave(p: Vector2) -> float:
	if p.x < 22.0 or p.x > 76.0 or p.y < 12.0 or p.y > 92.0:
		return -INF
	var e := -_d_polygone(p, PLACE)
	for r: Array in RUES:
		e = maxf(e, float(r[1]) * 0.5 - _d_polyligne(p, r[0]))
	var palier := -INF
	for rc: Rect2 in PALIERS:
		palier = maxf(palier, -_d_rect(p, rc))
	if COULOIR.has_point(p) and palier < 0.0:
		return -INF
	e = maxf(e, palier)
	# devant la porte SO, le dallage d'AbordsVillage prend le relais (il dépasse de 1,6 m à l'intérieur)
	var porte := Vector2(27.7, 25.2)
	var dehors := Vector2(5.0, 4.6) - porte
	if (p - porte).dot(dehors.normalized()) > -1.9:
		return minf(e, -0.5)
	return e

## Matière de sol de la carte de sol (Sol) dans le village, ou -1 : terre/neige piétinée sous les pavés et sur les chemins,
## terre labourée entre les sillons des champs. `t` ∈ [-0,5 ; 0,5] : décalage de tramage de Sol.
static func matiere_sol(x: float, z: float, t: float, terre: int, pietinee: int) -> int:
	if x < 20.0 or x > 100.0 or z < -32.0 or z > 93.0:
		return -1
	var p := Vector2(x, z)
	var e := profondeur_pave(p)
	if e > -0.4 + 0.3 * t:
		# joints enneigés (neige = 0) ; terre et neige piétinée par plaques (passages, usure)
		var pl := sin(x * 0.61 + 1.3 * sin(z * 0.23)) * sin(z * 0.47 + 0.9 * sin(x * 0.19))
		if e > 0.5 and pl > 0.62 + 0.3 * t:
			return terre
		return pietinee if pl > 0.25 + 0.3 * t else 0
	for c: Array in CHEMINS_TERRE:
		var d := _d_polyligne(p, c[0])
		var demi := float(c[1]) * 0.5
		if d < demi + 0.3 * t:
			return terre if d < demi - 0.55 + 0.4 * t else pietinee
	for ch: Array in CHAMPS:
		var rc: Rect2 = ch[0]
		if rc.grow(-0.3).has_point(p):
			var dir: Vector2 = ch[1]
			var s := fposmod(p.dot(dir.orthogonal()), float(ch[2])) / float(ch[2])
			return terre if absf(s - 0.5) < 0.17 + 0.12 * t else -1
	return -1

## Zone à dégager d'arbres/rochers en plus de l'enceinte : champs, chemins de terre.
static func exclu(x: float, z: float) -> bool:
	if x < 45.0 or x > 100.0 or z < -32.0 or z > 52.0:
		return false
	var p := Vector2(x, z)
	for ch: Array in CHAMPS:
		if (ch[0] as Rect2).grow(1.2).has_point(p):
			return true
	for c: Array in CHEMINS_TERRE:
		if _d_polyligne(p, c[0]) < float(c[1]) * 0.5 + 1.0:
			return true
	return false

# ------------------------------------------------------------------ pavés

func _paves() -> void:
	var bruit := FastNoiseLite.new()
	bruit.seed = rng.randi()
	bruit.frequency = 0.35
	var sites: Array[Vector2] = []
	var prof := PackedFloat32Array()
	var joints := PackedFloat32Array()
	var grille := {}
	var taille := FastNoiseLite.new()
	taille.seed = rng.randi()
	taille.frequency = 0.12
	_neige_bruit.seed = rng.randi()
	_neige_bruit.frequency = 0.45
	_neige_bruit.fractal_octaves = 2
	var z := 12.0
	var rang := 0
	while z < 92.0:
		var pas_z := PAVE * (1.0 + 0.28 * taille.get_noise_2d(48.0, z))
		var x := 22.0 + (pas_z * 0.5 if rang % 2 == 1 else 0.0)
		while x < 76.0:
			var pas := PAVE * (1.02 + 0.3 * taille.get_noise_2d(x, z))
			var s := Vector2(x + rng.randf_range(-0.3, 0.3) * pas, z + rng.randf_range(-0.24, 0.24) * pas_z)
			var e := profondeur_pave(s)
			if e > -0.6:
				var cle := Vector2i(floori(s.x), floori(s.y))
				if not grille.has(cle):
					grille[cle] = []
				grille[cle].append(sites.size())
				sites.append(s)
				prof.append(e)
				joints.append(rng.randf_range(0.035, 0.065))
			x += pas * rng.randf_range(0.8, 1.2)
		z += pas_z * rng.randf_range(0.88, 1.12)
		rang += 1
	for i in sites.size():
		var s := sites[i]
		var e := prof[i]
		# bord déchiqueté : quelques pavés manquent près du bord ; ~3 % manquent ailleurs (usure)
		var seuil := 0.1 + 0.25 * bruit.get_noise_2d(s.x, s.y)
		if e < seuil or rng.randf() < 0.03 + 0.35 * (1.0 - smoothstep(seuil, seuil + 0.8, e)):
			continue
		var r := PAVE * 0.95
		var poly: Array[Vector2] = [s + Vector2(-r, -r), s + Vector2(r, -r), s + Vector2(r, r), s + Vector2(-r, r)]
		var cle := Vector2i(floori(s.x), floori(s.y))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				for jq in grille.get(cle + Vector2i(dx, dy), []):
					if jq == i:
						continue
					var q := sites[jq]
					if q.distance_squared_to(s) > 1.6:
						continue
					poly = _couper(poly, s, (q - s).normalized(), (q - s).length() * 0.5 - (joints[i] + joints[jq]) * 0.5)
					if poly.size() < 3:
						break
		if poly.size() < 3:
			continue
		var aire := 0.0
		for k in poly.size():
			aire += (poly[k] - s).cross(poly[(k + 1) % poly.size()] - s) * 0.5
		if absf(aire) < 0.06:
			continue
		_pave(poly, s, e)

## Un pavé : dessus en éventail autour d'un sommet bombé, flancs jusque sous le sol (pied en neige : joints enneigés).
func _pave(poly: Array[Vector2], c2: Vector2, e: float) -> void:
	var cle := Vector2i(floori(c2.x / TUILE), floori(c2.y / TUILE))
	if not _tuiles.has(cle):
		_tuiles[cle] = BatiGeo.Maillage.new()
	var m: BatiGeo.Maillage = _tuiles[cle]
	if not _tuiles_loin.has(cle):
		_tuiles_loin[cle] = BatiGeo.Maillage.new()
	var ml: BatiGeo.Maillage = _tuiles_loin[cle]
	var kt := rng.randf_range(0.74, 1.14) * (0.84 if rng.randf() < 0.18 else 1.0)   # quelques pierres plus sombres (usées, humides)
	var chaud := rng.randf() < 0.25
	var tc := Vector3(1.07, 1.0, 0.9) if chaud else Vector3(0.93, 0.97, 1.05)
	var col_sommet := Color(kt * 1.1 * tc.x, kt * 1.1 * tc.y, kt * 1.1 * tc.z, 1.0)
	var col_bord := Color(kt * 0.78 * tc.x, kt * 0.78 * tc.y, kt * 0.8 * tc.z, 1.0)
	var col_flanc := Color(kt * 0.5, kt * 0.5, kt * 0.54, 1.0)
	var col_pied := Color(0.88, 0.88, 0.93, 0.0)
	# neige : plus au bord de la zone pavée, peu au milieu (piétiné) ; quelques plaques
	var p_neige := 0.2 + 0.45 * (1.0 - smoothstep(0.2, 1.8, e))
	var enfoui := rng.randf() < 0.1 + 0.25 * (1.0 - smoothstep(0.0, 1.0, e))
	var epais := rng.randf_range(-0.005, 0.01) if enfoui else rng.randf_range(0.02, 0.035)
	var bascule := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.01, 0.03)
	var rayon := 0.0
	for q in poly:
		rayon = maxf(rayon, q.distance_to(c2))
	var bombe := clampf(rayon * rng.randf_range(0.08, 0.13), 0.015, 0.045)
	var haut: Array[Vector3] = []
	var bas: Array[Vector3] = []
	var cols: Array[Color] = []
	var y_moy := 0.0
	for q in poly:
		var y := _sol(q) + epais + (q - c2).dot(bascule) * 2.0
		y_moy += y
		haut.append(Vector3(q.x, y, q.y))
		var d := (q - c2).normalized() * 0.035
		var wb := q + d
		bas.append(Vector3(wb.x, _sol(wb) - 0.03, wb.y))
		# neige : champ de bruit (plaques qui débordent d'un pavé sur l'autre), plus dense au bord de la zone pavée
		var nb := _neige_bruit.get_noise_2d(q.x, q.y) * 0.5 + 0.5 + rng.randf_range(-0.06, 0.06)
		cols.append(Color(col_bord.r, col_bord.g, col_bord.b, 0.0 if nb < p_neige * 0.55 else (0.3 if nb < p_neige else 1.0)))
	y_moy /= poly.size()
	var ctr := Vector3(c2.x, y_moy + bombe, c2.y)
	var dessous := ctr - Vector3(0, 1.0, 0)
	var n := poly.size()
	for i in n:
		var i2 := (i + 1) % n
		m.tri(haut[i], haut[i2], ctr, cols[i], cols[i2], col_sommet, dessous)
		ml.tri(haut[i], haut[i2], ctr, cols[i], cols[i2], col_sommet, dessous)
		m.quad(bas[i], bas[i2], haut[i2], haut[i], col_pied, col_pied, col_flanc, col_flanc, ctr - Vector3(0, 0.03, 0))
	_nb_paves += 1

# ------------------------------------------------------------------ escaliers

func _escaliers(h0: float) -> void:
	var nb := 10
	var demi := 1.8   # rampes : voir plus bas (pied prolongé sous le sol)
	for vi in ReliefVillage.VOLEES.size():
		var v: Array = ReliefVillage.VOLEES[vi]
		var z0: float = v[0]
		var z1: float = v[1]
		var ha: float = h0 if vi == 0 else float(ReliefVillage.VOLEES[vi - 1][2])
		var hb: float = v[2]
		var giron := (z1 - z0) / nb
		var contre := (hb - ha) / nb
		for k in nb:
			var za := z0 + k * giron
			var zb := za + giron + 0.04   # recouvrement sous la marche suivante
			var y := ha + (k + 1) * contre + rng.randf_range(-0.012, 0.012)
			# marche faite de 2 ou 3 dalles de longueurs inégales
			var x := ReliefVillage.ESCALIER_X - demi
			var fin := ReliefVillage.ESCALIER_X + demi
			while x < fin - 0.3:
				var l := minf(rng.randf_range(0.9, 1.6), fin - x)
				if fin - (x + l) < 0.45:
					l = fin - x
				_marche(Vector3(x + 0.015, ha + k * contre - 0.12, za), Vector3(x + l - 0.015, y, zb), absf(x + l * 0.5 - ReliefVillage.ESCALIER_X) / demi)
				x += l
		# rampe de collision invisible : plan des marches décalé d'une demi-marche (de (z0 - g/2, ha) à (z1 - g/2, hb))
		var a := Vector3(ReliefVillage.ESCALIER_X, ha, z0 - giron * 0.5)
		var b := Vector3(ReliefVillage.ESCALIER_X, hb, z1 - giron * 0.5)
		var axe3 := (b - a).normalized()                       # (0, sy, sz), sz > 0
		# le pied de la rampe plonge sous le sol devant la 1re marche (sinon son bout forme une marche de 0,2 à 0,4 m que
		# le CharacterBody ne franchit pas : au pied de la 1re volée, la berge du lit de la rivière est plus basse que le plateau)
		a -= axe3 * 1.4
		var haut_n := Vector3(0.0, axe3.z, -axe3.y)            # normale du plan de la rampe (y > 0)
		var bs := Basis(Vector3.RIGHT, haut_n, axe3)
		var ep := 0.4
		var forme := CollisionShape3D.new()
		forme.name = "RampeEscalier%d" % (vi + 1)
		var bx := BoxShape3D.new()
		bx.size = Vector3(demi * 2.0 + 0.2, ep, a.distance_to(b))
		forme.shape = bx
		forme.transform = Transform3D(bs, (a + b) * 0.5 - haut_n * (ep * 0.5))
		_corps.add_child(forme)

## Une dalle de marche, boîte de (x0, ybas, z0) à (x1, yhaut, z1) ; nez légèrement arrondi, neige vers les bouts (bord = 1).
func _marche(mn: Vector3, mx: Vector3, bord: float) -> void:
	var cg := (mn + mx) * 0.5
	# neige tassée au fond du giron (contre la contremarche suivante), surtout vers les bouts ; milieu piétiné
	var neige := rng.randf() < (0.85 if bord > 0.6 else 0.35)
	var ao_h := Color(1.0, 1.0, 1.0, 0.0 if neige else 1.0)
	var ao_n := Color(0.97, 0.97, 0.97, 1.0)
	var ao_gf := Color(0.97, 0.97, 0.97, 0.0 if neige and bord > 0.75 else 1.0)   # avant du giron : bouts entièrement enneigés
	var ao_b := Color(0.58, 0.58, 0.62, 1.0)
	var j := func() -> float: return rng.randf_range(-0.012, 0.012)
	var p := [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mn.x, mn.y, mx.z),
		Vector3(mn.x, mx.y + j.call(), mn.z + 0.02), Vector3(mx.x, mx.y + j.call(), mn.z + 0.02), Vector3(mx.x, mx.y + j.call(), mx.z), Vector3(mn.x, mx.y + j.call(), mx.z)]
	var nez := [Vector3(mn.x, mx.y - 0.05, mn.z), Vector3(mx.x, mx.y - 0.05, mn.z)]
	_marches.quad(p[4], p[5], p[6], p[7], ao_gf, ao_gf, ao_h, ao_h, cg - Vector3(0, 1, 0))          # giron
	_marches.quad(p[0], p[1], nez[1], nez[0], ao_b, ao_b, ao_n, ao_n, cg)                       # contremarche
	_marches.quad(nez[0], nez[1], p[5], p[4], ao_n, ao_n, ao_n, ao_n, cg)                       # nez chanfreiné
	_marches.quad(p[0], p[3], p[7], p[4], ao_b, ao_b, ao_n, ao_n, cg)                           # bouts
	_marches.quad(p[1], p[2], p[6], p[5], ao_b, ao_b, ao_n, ao_n, cg)

# ------------------------------------------------------------------ murs de soutènement

func _murs_soutenement(h0: float) -> void:
	var xc: float = ReliefVillage.ESCALIER_X
	var jo: float = ReliefVillage.ESCALIER_DEMI + ReliefVillage.ESCALIER_JOUE   # 4 : bord extérieur des joues
	for cote: float in [-1.0, 1.0]:
		var murs: Array = ReliefVillage.MURS_OUEST if cote < 0.0 else ReliefVillage.MURS_EST
		for w in murs.size():
			var zb: float = murs[w][0]
			var zh: float = murs[w][1]
			var hh: float = murs[w][2]
			var hb: float = h0 if w == 0 else float(murs[w - 1][2])
			# étendue en x : du couloir (bord extérieur de la joue) jusqu'à la palissade (0,4 m en dedans)
			var x_int := xc + cote * jo
			var x_ext := x_int
			var pas := 0.5
			while absf(x_ext - xc) < 40.0:
				var xn: float = x_ext + cote * pas
				if not ReliefVillage.dans_enceinte(xn, zb + 1.0, -0.4) or not ReliefVillage.dans_enceinte(xn, zh - 0.2, -0.4):
					break
				x_ext = xn
			if absf(x_ext - x_int) < 0.5:
				continue
			_mur(minf(x_int, x_ext), maxf(x_int, x_ext), zb, zh, hb, hh)
		# joues du couloir : bloc de x (couloir ± 2) à (couloir ± 4) partout où bande et rampe diffèrent
		var xa := xc + cote * ReliefVillage.ESCALIER_DEMI
		var xb := xc + cote * jo
		var z := 66.0
		var debut := -1.0
		while z <= 82.01:
			var diff := absf(_bande_mur(cote, z, h0).y - ReliefVillage.cible(xa - cote * 0.01, z, h0))
			if diff > 0.08 and debut < 0.0:
				debut = z
			elif (diff <= 0.08 or z >= 82.0) and debut >= 0.0:
				_joue(minf(xa, xb), maxf(xa, xb), debut, z, cote, h0)
				debut = -1.0
			z += 0.25

## Mur plein de la ligne z = zb (face visible, au pied h_bas) à zh (dessus au niveau h_haut), de x0 à x1.
func _mur(x0: float, x1: float, zb: float, zh: float, h_bas: float, h_haut: float) -> void:
	var n := maxi(1, ceili((x1 - x0) / 0.7))
	var bas := h_bas - 0.35
	var av := zb - 0.02
	var hf := h_haut + 0.02                       # haut de la face, CONSTANT : une seule face pour tout le mur
	var zf := av + (hf - bas) * 0.04              # fruit de 4 % : le haut recule
	var neige := Color(1, 1, 1, 0.0)
	var ao_t := Color(1.0, 1.0, 1.0, 1.0)
	var ao_p := Color(0.84, 0.82, 0.8, 1.0)
	var cm := Vector3((x0 + x1) * 0.5, (bas + hf) * 0.5, (zb + zh) * 0.5)
	# face avant d'un seul tenant (les tronçons séparés laissaient des fentes avec l'accrochage des sommets du shader ps1)
	_murs.quad(Vector3(x0, bas, av), Vector3(x1, bas, av), Vector3(x1, hf, zf), Vector3(x0, hf, zf), ao_p, ao_p, ao_t, ao_t, cm)
	for xe: float in [x0, x1]:
		_murs.quad(Vector3(xe, bas, av), Vector3(xe, hf, zf), Vector3(xe, hf, zh + 0.05), Vector3(xe, bas, zh + 0.05), ao_p, ao_t, ao_t, ao_p, cm)
	# chaperon de pierres inégales posé sur la face (un peu en surplomb, enneigé)
	for i in n:
		var xa := lerpf(x0, x1, float(i) / n) - (0.0 if i == 0 else 0.01)
		var xb := lerpf(x0, x1, float(i + 1) / n) + (0.0 if i == n - 1 else 0.01)
		var top := hf + rng.randf_range(0.01, 0.07)
		var c := Vector3((xa + xb) * 0.5, top - 0.5, (zb + zh) * 0.5)
		var t0 := Vector3(xa, top, zf - 0.06)
		var t1 := Vector3(xb, top, zf - 0.06)
		var t2 := Vector3(xb, top, zh + 0.05)
		var t3 := Vector3(xa, top, zh + 0.05)
		_murs.quad(t0, t1, t2, t3, neige, neige, neige, neige, c)
		_murs.quad(Vector3(xa, hf - 0.04, zf - 0.06), Vector3(xb, hf - 0.04, zf - 0.06), t1, t0, ao_t, ao_t, neige, neige, c)
		for xe: float in [xa, xb]:
			_murs.quad(Vector3(xe, hf - 0.04, zf - 0.06), t0 if xe == xa else t1, t3 if xe == xa else t2, Vector3(xe, hf - 0.04, zh + 0.05), ao_t, neige, neige, ao_t, c)
	var forme := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(x1 - x0, h_haut + 0.03 - bas, zh - zb + 0.02)
	forme.shape = bx
	forme.position = Vector3((x0 + x1) * 0.5, (h_haut + 0.03 + bas) * 0.5, (zb + zh) * 0.5 - 0.01)
	_corps.add_child(forme)

## Bande à côté du couloir en z : (pied, dessus) ; hors d'une ligne de mur les deux valent la hauteur de la bande.
func _bande_mur(cote: float, z: float, h0: float) -> Vector2:
	var murs: Array = ReliefVillage.MURS_OUEST if cote < 0.0 else ReliefVillage.MURS_EST
	for w in murs.size():
		if z > float(murs[w][0]) + 0.001 and z < float(murs[w][1]) - 0.001:
			return Vector2(h0 if w == 0 else float(murs[w - 1][2]), float(murs[w][2]))
	var h := ReliefVillage._profil(z, h0, murs)
	return Vector2(h, h)

## Joue du couloir d'escalier de z0 à z1 entre x0 et x1 : dessus = la plus haute des deux surfaces (bande / rampe),
## faces jusqu'à la plus basse. Collision : un prisme convexe par tranche de 0,5 m.
func _joue(x0: float, x1: float, z0: float, z1: float, cote: float, h0: float) -> void:
	var xc: float = ReliefVillage.ESCALIER_X
	var n := maxi(1, ceili((z1 - z0) / 0.5))
	var ao_t := Color(1.0, 1.0, 1.0, 1.0)
	var ao_p := Color(0.84, 0.82, 0.8, 1.0)
	var neige := Color(1, 1, 1, 0.0)
	var x_couloir := xc + cote * ReliefVillage.ESCALIER_DEMI
	var x_bande := xc + cote * (ReliefVillage.ESCALIER_DEMI + ReliefVillage.ESCALIER_JOUE)
	for i in n:
		var za := lerpf(z0, z1, float(i) / n)
		var zb := lerpf(z0, z1, float(i + 1) / n)
		var hc_a := ReliefVillage.cible(x_couloir, za, h0)
		var hc_b := ReliefVillage.cible(x_couloir, zb, h0)
		# côté bande : sur une ligne de mur, la surface est le DESSUS du mur (plat, h haute) et son pied (h basse)
		var bd_a := _bande_mur(cote, za, h0)
		var bd_b := _bande_mur(cote, zb, h0)
		var top_a := maxf(hc_a, bd_a.y) + 0.04
		var top_b := maxf(hc_b, bd_b.y) + 0.04
		var bas_a := minf(hc_a, bd_a.x) - 0.35
		var bas_b := minf(hc_b, bd_b.x) - 0.35
		var c := Vector3((x0 + x1) * 0.5, (top_a + bas_a) * 0.5, (za + zb) * 0.5)
		_murs.quad(Vector3(x0, top_a, za), Vector3(x1, top_a, za), Vector3(x1, top_b, zb), Vector3(x0, top_b, zb), neige, neige, neige, neige, c - Vector3(0, 2, 0))
		for xe: float in [x0, x1]:
			_murs.quad(Vector3(xe, bas_a, za), Vector3(xe, bas_b, zb), Vector3(xe, top_b, zb), Vector3(xe, top_a, za), ao_p, ao_p, ao_t, ao_t, c)
		if i == 0:
			_murs.quad(Vector3(x0, bas_a, za), Vector3(x1, bas_a, za), Vector3(x1, top_a, za), Vector3(x0, top_a, za), ao_p, ao_p, ao_t, ao_t, c)
		if i == n - 1:
			_murs.quad(Vector3(x0, bas_b, zb), Vector3(x1, bas_b, zb), Vector3(x1, top_b, zb), Vector3(x0, top_b, zb), ao_p, ao_p, ao_t, ao_t, c)
		var pts := PackedVector3Array([Vector3(x0, bas_a, za), Vector3(x1, bas_a, za), Vector3(x0, top_a, za), Vector3(x1, top_a, za),
			Vector3(x0, bas_b, zb), Vector3(x1, bas_b, zb), Vector3(x0, top_b, zb), Vector3(x1, top_b, zb)])
		var cv := ConvexPolygonShape3D.new()
		cv.points = pts
		var forme := CollisionShape3D.new()
		forme.shape = cv
		_corps.add_child(forme)

# ------------------------------------------------------------------ champs

func _champs() -> void:
	for ch: Array in CHAMPS:
		var rc: Rect2 = ch[0]
		var dir: Vector2 = ch[1]
		var ecart: float = ch[2]
		var perp := dir.orthogonal()
		# sillons : bourrelets de neige le long de `dir`, espacés de `ecart`
		var c0 := rc.position.dot(perp)
		var c1 := (rc.position + rc.size).dot(perp)
		var a0 := minf(c0, c1) + ecart * 0.5
		var a1 := maxf(c0, c1) - ecart * 0.3
		var l0 := minf(rc.position.dot(dir), (rc.position + rc.size).dot(dir)) + 0.5
		var l1 := maxf(rc.position.dot(dir), (rc.position + rc.size).dot(dir)) - 0.5
		var a := a0
		while a < a1:
			var prec: Array = []
			var l := l0
			while l <= l1 + 0.01:
				var p := dir * l + perp * (a + 0.05 * sin(l * 0.7 + a))
				var y := _sol(p)
				var hb := 0.13 + 0.04 * sin(l * 1.3 + a * 2.0)
				var lat := Vector3(perp.x, 0, perp.y) * 0.3
				var cur := [Vector3(p.x, y - 0.03, p.y) + lat, Vector3(p.x, y + hb, p.y), Vector3(p.x, y - 0.03, p.y) - lat]
				if not prec.is_empty():
					var cc := Vector3(p.x, y - 0.5, p.y)
					var bl := Color(1, 1, 1, 0.0)
					_sillons.quad(prec[0], cur[0], cur[1], prec[1], bl, bl, bl, bl, cc)
					_sillons.quad(prec[1], cur[1], cur[2], prec[2], bl, bl, bl, bl, cc)
				prec = cur
				l += 1.0
			a += ecart
		# clôture de rondins autour (piquets tous les ~2,2 m), une ouverture du côté du chemin
		var coins := [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]
		for k in 4:
			var pa: Vector2 = coins[k]
			var pb: Vector2 = coins[(k + 1) % 4]
			var nb := maxi(2, ceili(pa.distance_to(pb) / 2.2))
			var pts: Array = []
			for i in nb + 1:
				var q := pa.lerp(pb, float(i) / nb) + (rc.get_center() - pa.lerp(pb, float(i) / nb)).normalized() * -0.6
				pts.append(q)
			if k == 3:   # ouverture (barrière ouverte) au milieu du côté ouest / nord
				var mi := pts.size() / 2
				_barriere(pts.slice(0, mi))
				_barriere(pts.slice(mi + 1))
			else:
				_barriere(pts)

# ------------------------------------------------------------------ finalisation

func _finaliser_rues() -> void:
	var ab := monde.get_node_or_null("AbordsVillage")
	var mat := func(nom: String) -> Material:
		var mi := ab.get_node_or_null(nom) as MeshInstance3D if ab != null else null
		return mi.material_override if mi != null else null
	var mat_paves: Material = mat.call("Dalles")
	if mat_paves == null:
		mat_paves = materiau_dalles(rng)
	for cle: Vector2i in _tuiles:
		var mi := _mesh(_tuiles[cle], mat_paves, false, "Paves_%d_%d" % [cle.x, cle.y])
		if mi != null:
			mi.visibility_range_end = PORTEE_FLANCS
		var ml := _mesh(_tuiles_loin.get(cle, BatiGeo.Maillage.new()), mat_paves, false, "PavesLoin_%d_%d" % [cle.x, cle.y])
		if ml != null:
			ml.visibility_range_begin = PORTEE_FLANCS
			ml.visibility_range_end = PORTEE_PAVES
	_mesh(_marches, TexturesBati.m_pierre_fine_e(Color(1.22, 1.24, 1.32)), true, "Marches")   # pierre claire usée (vue 3 de la planche)
	# D/neige_murs : pierre chaude à assises irrégulières (référence village_v2, cohérente avec les maisons C7b) au lieu
	# de la pierre sèche gris-bleu à rangs réguliers ; teinte légèrement chaude pour tenir sous la lumière froide du ciel
	var mur := _mesh(_murs, TexturesBati.m_pierre_mur_e(Color(1.62, 1.47, 1.3)), true, "MursSoutenement")
	if mur != null:
		mur.visibility_range_end = 0.0   # visibles de loin (haute rue vue de toute la cuvette)
	_mesh(_sillons, TexturesBati.m_neige_toit_e(), false, "Sillons")
	# kit (lanternes, clôtures) : mêmes matières que les abords de l'entrée (pas de textures recalculées)
	if ab == null or mat.call("Bois") == null:
		_finaliser()
		return
	_mesh(_pierre, mat.call("PierreNeige"), true, "PierreNeige")
	_mesh(_bois, mat.call("Bois"), true, "Bois")
	_mesh(_bouts, mat.call("Bouts"), true, "Bouts")
	_mesh(_fer, mat.call("Fer"), true, "Fer")
	_mesh(_verre, mat.call("Verre"), false, "Verre")
	_mat_flaque = mat.call("Flaques")
	_mesh(_flaques, _mat_flaque, false, "Flaques")
	set_process(false)   # les flaques sont réglées par AbordsVillage (même matière)
	if not _touffes.is_empty():
		var mesh_t: Mesh = null
		for n in monde.get_children():
			if n is MultiMeshInstance3D and n.get_meta("abords", "") == "touffe":
				mesh_t = (n as MultiMeshInstance3D).multimesh.mesh
				break
		if mesh_t == null:
			mesh_t = SousBois.mesh_touffe(SousBois.materiau_herbe(texture_touffe_givree(rng.randi() % 10000), Color(0.92, 0.86, 0.82)))
		_touffes = PosesDecor.filtrer(monde, _touffes, "touffe", mesh_t)   # passe D : règles de pose
		for mmi in Instanciation.repartir(monde, mesh_t, _touffes, {"portee": 35.0, "ombre": false}):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
