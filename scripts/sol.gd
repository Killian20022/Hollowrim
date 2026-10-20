class_name Sol
## Sol de la zone témoin (lot D du biome, lot 3 de la mission graphisme) : une carte précalculée
## 960² (0,25 m/texel) lue par le shader du terrain, plus une carte d'empreintes à 1/32 m.
##   R = matière × 16 ; G = relief fin (128 + h × 400, h en m : congères, cuvettes, bosses) ;
##   B = 128 (zone) | variante << 5 | densité de détails << 3 | (creux + 4).
## Le shader dessine les tuiles pixel art de SolTuiles (16 texels/m) selon la matière, avec des bords
## en amas irréguliers, une lèvre/ombre entre matières, les empreintes et les détails épars.
## Hors zone, ou avec --biome=ancien, B vaut 0 partout : le terrain rend exactement comme avant.

const TAILLE := 960           # texels par côté
const TEXEL := 0.25           # m par texel (le shader lit toujours la même carte, 240 m)
const NOEUD := 4              # texels entre deux nœuds de la grille de hauteurs (1 m)
const ORIGINE := -120.0       # coin de la carte (m)
const NEIGE := 0              # matières (valeur de R / 16) : mêmes numéros que SolTuiles.M_*
const PIETINEE := 1
const TERRE := 2
const AIGUILLES := 3
const MOUSSE := 4
const ROCHE := 5
const GLACE := 6
const CROUTE := 7

const PENTE_ROCHE := 0.80     # normale.y sous laquelle c'est de la roche
const PENTE_AFFLEURE := 0.88  # entre les deux : pierre affleurante, tramée
const PART_AFFLEURE := 0.35
const BRUIT_ROCHE := 0.08     # amplitude du bruit sur le seuil de pente
const CHEMIN_NEIGE := 0.8     # m de l'axe : neige piétinée sur toute la largeur (1,6 m), bord tramé ±0,15 m
const ORNIERE_DIST := 0.35    # m de l'axe : les deux ornières
const ORNIERE_LARGE := 0.2    # demi-largeur des ornières (m)
const ORNIERE_PART := 0.5     # part de terre au cœur d'une ornière
const PLAQUE_PART := 0.25     # part de terre dans les plaques (bruit_clair > 0,5)
const RAYON_STELE := 3.5      # neige piétinée autour de la stèle (bande tramée 0,8 m)
const RAYON_PORTE := 3.0      # devant la porte du tertre
const RAYON_FEU := 5.0        # plateau du feu
const CREUX_SEUIL := 0.05     # creux : moyenne des voisins à 4 m − hauteur (m)
const MOUSSE_NORD := -0.2     # normale.z sous laquelle la pente regarde le nord
const MOUSSE_PART := 0.4
const GLACE_CREUX := 0.27     # creux plus marqué et plat : plaque de glace (eau de fonte regelée)
const CROUTE_BOSSE := -0.04   # bosse exposée au vent (creux < seuil) : neige croûtée
const CROUTE_BRUIT := 0.42    # ou plaques de croûte d'un bruit lent

const AIGUILLES_DENSITE := 0.45  # densité max d'aiguilles (hors cœur de tache) à ~0,3 × échelle du tronc
const AIGUILLES_COEUR := 0.5     # × échelle : agglomérat serré autour du tronc
const AIGUILLES_PLEIN := 0.9     # × échelle : le tapis s'éclaircit
const AIGUILLES_BORD := 1.6      # × échelle : quelques pixels épars
const GRAIN := 0.8               # part du bruit lisse dans les seuils de tramage (le reste : bruit blanc)
const MASQUE_BRUIT := 0.45       # part du bruit basse fréquence dans le seuil du masque de zone

# relief fin (m) : le vent souffle vers +z (même sens que les rides des tuiles)
const BOSSES := 0.035            # bosses allongées dans le sens du vent
const CUVETTE := 0.12            # creux au pied des arbres (r < CUVETTE_R × échelle)
const CUVETTE_R := 0.9
const BOURRELET := 0.045         # bourrelet autour de la cuvette
const CONGERE := 0.24            # congère sous le vent d'un obstacle (× rayon, plafonné)
const DOUVE := 0.08              # cuvette de vent autour de la base des obstacles
const CREUX_TON := [0.014, 0.06]   # laplacien (m) au-delà duquel le ton baisse de 1, de 2
const BOSSE_TON := -0.022          # en deçà : arête claire (+1)

# empreintes (carte 1/32 m de la zone)
const TRACES_ORIGINE := Vector2(ZoneBiome.X0, ZoneBiome.Z0)
const TRACES_RES := 32.0         # texels/m de la carte d'empreintes (formes de bottes lisibles de près)
const TRACES_W := int((ZoneBiome.X1 - ZoneBiome.X0) * TRACES_RES)
const TRACES_H := int((ZoneBiome.Z1 - ZoneBiome.Z0) * TRACES_RES)
const PISTES_CHEMIN := 11        # pistes de pas le long des chemins
const RENARDS := 3
const LIEVRES := 2

## Durée du dernier calcul (ms), pour les mesures.
static var temps_ms := 0.0

# Cartes précalculées (assets/sol/carte_sol.res + carte_traces.res) : le calcul dépend de tout le monde (relief, arbres,
# rochers, chemins) mais il est déterministe ; on le remplace donc par la lecture du fichier SI la signature des
# entrées (SHA-256 du relief échantillonné, des arbres, des obstacles, des chemins, du code de sol/zone/chemins)
# est identique, sinon repli sur le calcul. outils/precalculer_tout.gd régénère le fichier (mode ECRIRE).
const CACHE_CARTE := "res://assets/sol/carte_sol.res"
const CACHE_TRACES := "res://assets/sol/carte_traces.res"
const CACHE_VERSION := 1   # à incrémenter si le FORMAT du cache change (le code de sol.gd est déjà dans la signature)
enum { CACHE_LIRE, CACHE_ECRIRE, CACHE_VERIFIER }
static var cache_mode := CACHE_LIRE
static var cache_statut := ""   # "lu", "ecrit", "identique", "DIFFERENT", "perime", "absent" (pour les mesures)

static func _sha(ctx: HashingContext, octets: PackedByteArray) -> void:
	ctx.update(octets)
	ctx.update(PackedByteArray([0xff]))

static func _source(chemin: String) -> PackedByteArray:
	var sc := load(chemin) as GDScript
	return (sc.source_code if sc != null else "").to_utf8_buffer()

## Seuil de tramage : hachage de position, irrégulier (aucun motif périodique), dans [0 ; 1).
static func _alea(i: int, j: int, s: int) -> float:
	var h := (i * 374761393 + j * 668265263 + s * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 16)) * 2246822519 & 0x7fffffff
	h = h ^ (h >> 15)
	return float(h & 0xffff) / 65536.0

static var _t := 0
static func _chrono(etape: String) -> void:
	if OS.has_environment("SOL_DEBUG"):
		print("  sol %s : %d ms" % [etape, (Time.get_ticks_usec() - _t) / 1000])
	_t = Time.get_ticks_usec()

static func _bruit(graine: int, freq: float, octaves := 1) -> FastNoiseLite:
	var b := FastNoiseLite.new()
	b.seed = graine
	b.frequency = freq
	b.fractal_octaves = octaves
	return b

## `arbres` = transforms des arbres (monde.arbres), pour l'effet « sous les arbres ».
static func appliquer(mat_terrain: ShaderMaterial, monde: Node, arbres: Array) -> void:
	if not ZoneBiome.actif:
		return
	var t0 := Time.get_ticks_usec()
	var cartes := _calculer(monde, arbres)
	var carte := ImageTexture.create_from_image(cartes[0])
	var tuiles := SolTuiles.charger()
	mat_terrain.set_shader_parameter("carte_sol", carte)
	mat_terrain.set_shader_parameter("carte_relief", carte)
	mat_terrain.set_shader_parameter("carte_rect", Vector3(ORIGINE, ORIGINE, 1.0 / (TAILLE * TEXEL)))
	mat_terrain.set_shader_parameter("sol_index", tuiles["index"])
	mat_terrain.set_shader_parameter("sol_couleur", tuiles["couleur"])
	mat_terrain.set_shader_parameter("sol_details", tuiles["details"])
	mat_terrain.set_shader_parameter("sol_index2", tuiles["index2"])
	mat_terrain.set_shader_parameter("sol_details2", tuiles["details2"])
	mat_terrain.set_shader_parameter("sol_lut", SolTuiles.lut())
	mat_terrain.set_shader_parameter("sol_traces", ImageTexture.create_from_image(cartes[1]))
	mat_terrain.set_shader_parameter("traces_rect", Vector4(TRACES_ORIGINE.x, TRACES_ORIGINE.y, TRACES_W, TRACES_H))
	mat_terrain.set_shader_parameter("sol_carte", true)
	temps_ms = (Time.get_ticks_usec() - t0) / 1000.0
	print("Sol : carte de sol calculée en %.0f ms" % temps_ms)

## Obstacles qui retiennent la neige : [Vector2 centre, rayon (m)].
static func _obstacles(monde: Node, arbres_zone: Array) -> Array:
	var l: Array = []
	for r in SousBois._rochers(monde):
		l.append([r["pos"], r["r"] * 0.8])
	var c: Vector3 = monde.CERCLE
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		l.append([Vector2(c.x + cos(a) * 6.5, c.z + sin(a) * 6.5), 0.55])
	l.append([Vector2(c.x, c.z), 0.75])
	for o in ZoneBiome.OCCUPATIONS:
		l.append([o[0], minf(o[1] * 0.45, 1.2)])
	for a in arbres_zone:
		var p: Vector3 = a["pos"]
		l.append([Vector2(p.x, p.z), 0.18 * a["s"] + 0.1])
	for nd in monde.find_children("*", "MultiMeshInstance3D", true, false):
		if nd.has_meta("sous_bois") and nd.get_meta("sous_bois") == "souche":
			for t: Transform3D in nd.get_meta("transforms"):
				l.append([Vector2(t.origin.x, t.origin.z), 0.3 * t.basis.get_scale().x])
			break  # la liste est copiée sur chaque cellule : une seule suffit
	return l

static func _calculer(monde: Node, arbres: Array) -> Array:
	_chrono("début")
	var g0 := ZoneBiome.graine("sol")
	var bruit_roche := _bruit(g0, 0.18, 2)
	var bruit_clair := _bruit(g0 + 1, 0.35)
	var bruit_masque := _bruit(g0 + 2, 0.1, 2)      # fondu de la couture : taches de 5-10 m
	var bruit_tache := _bruit(g0 + 3, 0.9, 2)       # agglomérats d'aiguilles
	var bruit_fin := _bruit(g0 + 4, 1.3, 2)         # seuil de tramage : grain de 0,5-1 m
	var bruit_bosse := _bruit(g0 + 5, 0.5, 2)       # relief : bosses allongées dans le vent
	var bruit_croute := _bruit(g0 + 6, 0.07, 2)     # plaques de croûte
	var bruit_variante := _bruit(g0 + 7, 0.09, 2)   # plaques de variantes de tuiles
	var bruit_herbe := _bruit(g0 + 8, 0.12, 2)      # herbes sèches en clairière

	var i0 := maxi(0, int(floor((ZoneBiome.X0 - ORIGINE) / TEXEL)))
	var i1 := mini(TAILLE - 1, int(ceil((ZoneBiome.X1 - ORIGINE) / TEXEL)))
	var j0 := maxi(0, int(floor((ZoneBiome.Z0 - ORIGINE) / TEXEL)))
	var j1 := mini(TAILLE - 1, int(ceil((ZoneBiome.Z1 - ORIGINE) / TEXEL)))
	var gi0 := i0 - (i0 % NOEUD) - 5 * NOEUD  # les nœuds tombent sur des centres de texels
	var gj0 := j0 - (j0 % NOEUD) - 5 * NOEUD
	var gw := (i1 - gi0) / NOEUD + 7
	var gh := (j1 - gj0) / NOEUD + 7
	var h := PackedFloat32Array()
	h.resize(gw * gh)
	for gj in gh:
		var z := ORIGINE + (gj0 + NOEUD * gj + 0.5) * TEXEL
		for gi in gw:
			h[gj * gw + gi] = monde.hauteur(ORIGINE + (gi0 + NOEUD * gi + 0.5) * TEXEL, z)
	var g_ny := PackedFloat32Array()
	var g_nz := PackedFloat32Array()
	var g_cr := PackedFloat32Array()
	var g_pres := PackedByteArray()  # 1 si le chemin est à moins de 3 m (évite distance() partout)
	g_pres.resize(gw * gh)
	g_ny.resize(gw * gh)
	g_nz.resize(gw * gh)
	g_cr.resize(gw * gh)
	for gj in gh:
		for gi in gw:
			var gx := ORIGINE + (gi0 + NOEUD * gi + 0.5) * TEXEL
			var gz := ORIGINE + (gj0 + NOEUD * gj + 0.5) * TEXEL
			g_pres[gj * gw + gi] = 1 if monde.chemins.distance(gx, gz) < 3.0 else 0
	for gj in range(5, gh - 5):
		for gi in range(5, gw - 5):
			var gk := gj * gw + gi
			var dx := h[gk - 1] - h[gk + 1]
			var dz := h[gk - gw] - h[gk + gw]
			var inv := 1.0 / sqrt(dx * dx + 4.0 + dz * dz)  # normale à ±1 m, comme le maillage
			g_ny[gk] = 2.0 * inv
			g_nz[gk] = dz * inv
			g_cr[gk] = (h[gk - 4] + h[gk + 4] + h[gk - 4 * gw] + h[gk + 4 * gw]) * 0.25 - h[gk]

	_chrono("grille")
	var arbres_zone: Array = monde.get_meta("arbres_zone") if monde.has_meta("arbres_zone") else []
	var obstacles := _obstacles(monde, arbres_zone)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_sha(ctx, PackedInt32Array([CACHE_VERSION, TAILLE, gw, gh]).to_byte_array())
	_sha(ctx, h.to_byte_array())
	_sha(ctx, g_pres)
	var flux := PackedFloat32Array()
	for tr: Transform3D in arbres:
		flux.append_array([tr.basis.x.x, tr.basis.x.y, tr.basis.x.z, tr.basis.y.x, tr.basis.y.y, tr.basis.y.z, tr.basis.z.x, tr.basis.z.y, tr.basis.z.z, tr.origin.x, tr.origin.y, tr.origin.z])
	_sha(ctx, flux.to_byte_array())
	_sha(ctx, var_to_bytes([arbres_zone, obstacles, monde.chemins.points, monde.chemins.debuts, monde.CERCLE, monde.TUMULUS]))
	for chemin in ["res://scripts/sol.gd", "res://scripts/zone_biome.gd", "res://scripts/chemins.gd"]:
		_sha(ctx, _source(chemin))
	var signature := ctx.finish().hex_encode()
	if cache_mode == CACHE_LIRE and ResourceLoader.exists(CACHE_CARTE) and ResourceLoader.exists(CACHE_TRACES):
		var c1 := ResourceLoader.load(CACHE_CARTE) as Image
		var c2 := ResourceLoader.load(CACHE_TRACES) as Image
		if c1 != null and c2 != null and c1.get_meta("signature", "") == signature and c2.get_meta("signature", "") == signature:
			cache_statut = "lu"
			_chrono("cache lu")
			return [c1, c2]
	cache_statut = "perime" if cache_mode == CACHE_LIRE else cache_statut
	var mat := PackedByteArray()
	mat.resize(TAILLE * TAILLE)      # matière (0 = neige)
	var actif := PackedByteArray()
	actif.resize(TAILLE * TAILLE)    # 1 = texel de la zone
	var nz := PackedFloat32Array()   # normale.z, pour la mousse
	nz.resize(TAILLE * TAILLE)
	var creux := PackedFloat32Array()
	creux.resize(TAILLE * TAILLE)
	var dchemin := PackedFloat32Array()  # distance au chemin (INF au-delà de 3 m)
	dchemin.resize(TAILLE * TAILLE)

	var chemins = monde.chemins
	var stele := Vector2(monde.CERCLE.x, monde.CERCLE.z)
	var porte := Vector2(monde.TUMULUS.x, monde.TUMULUS.z + 2.8)  # = tertre.porte_dehors

	var xin0 := ZoneBiome.X0 + ZoneBiome.FONDU
	var xin1 := ZoneBiome.X1 - ZoneBiome.FONDU
	var zin0 := ZoneBiome.Z0 + ZoneBiome.FONDU
	var zin1 := ZoneBiome.Z1 - ZoneBiome.FONDU
	for j in range(j0, j1 + 1):
		var z := ORIGINE + (j + 0.5) * TEXEL
		for i in range(i0, i1 + 1):
			var x := ORIGINE + (i + 0.5) * TEXEL
			var b := clampf(lerpf(_alea(i, j, 2), 0.5 + 0.9 * bruit_fin.get_noise_2d(x, z), GRAIN), 0.0, 0.999)
			var cur := x > xin0 and x < xin1 and z > zin0 and z < zin1  # cœur : masque = 1
			var seuil := lerpf(_alea(i, j, 1), 0.5 + 0.5 * bruit_masque.get_noise_2d(x, z), MASQUE_BRUIT)
			var k := j * TAILLE + i
			dchemin[k] = INF
			if not cur and ZoneBiome.masque(x, z) <= seuil:
				continue  # tramage du masque : ce texel garde l'ancien rendu
			actif[k] = 1
			var u := float(i - gi0) / NOEUD
			var v := float(j - gj0) / NOEUD
			var gi := int(u)
			var gj := int(v)
			var fu := u - gi
			var fv := v - gj
			var gk := gj * gw + gi
			var ny := lerpf(lerpf(g_ny[gk], g_ny[gk + 1], fu), lerpf(g_ny[gk + gw], g_ny[gk + gw + 1], fu), fv)
			nz[k] = lerpf(lerpf(g_nz[gk], g_nz[gk + 1], fu), lerpf(g_nz[gk + gw], g_nz[gk + gw + 1], fu), fv)
			creux[k] = lerpf(lerpf(g_cr[gk], g_cr[gk + 1], fu), lerpf(g_cr[gk + gw], g_cr[gk + gw + 1], fu), fv)
			var mt := NEIGE
			var rb := bruit_roche.get_noise_2d(x, z) * BRUIT_ROCHE
			if ny < PENTE_ROCHE + rb or (ny < PENTE_AFFLEURE + rb and b < PART_AFFLEURE):
				mt = ROCHE
			else:
				var d := INF
				if g_pres[gk] + g_pres[gk + 1] + g_pres[gk + gw] + g_pres[gk + gw + 1] > 0:
					d = chemins.distance(x, z)
				dchemin[k] = d
				var t := 0.5 - b  # -0,5..0,5 : décale les seuils pour tramer
				if d < CHEMIN_NEIGE + 0.3 * t:
					mt = PIETINEE
					# terre clairsemée : deux ornières étroites + quelques plaques (parfois gelées)
					var pt := ORNIERE_PART * maxf(0.0, 1.0 - absf(d - ORNIERE_DIST) / ORNIERE_LARGE)
					var plaque := bruit_clair.get_noise_2d(x * 0.6, z * 0.6) > 0.5
					if plaque:
						pt = maxf(pt, PLAQUE_PART)
					if pt > b:
						mt = TERRE
				else:
					var p := Vector2(x, z)
					if p.distance_to(stele) < RAYON_STELE + 0.8 * t or p.distance_to(porte) < RAYON_PORTE + 0.8 * t or p.length() < RAYON_FEU + 0.8 * t:
						mt = PIETINEE
					elif creux[k] < CROUTE_BOSSE + 0.02 * t or bruit_croute.get_noise_2d(x, z) > CROUTE_BRUIT + 0.15 * t:
						mt = CROUTE
			mat[k] = mt

	_chrono("matières")
	# sous les arbres : tapis irrégulier (agglomérat serré au pied, puis taches de plus en plus éparses)
	for tr: Transform3D in arbres:
		var p := tr.origin
		if ZoneBiome.masque(p.x, p.z) <= 0.0:
			continue
		var s := tr.basis.get_scale().x
		var ci := int((p.x - ORIGINE) / TEXEL)
		var cj := int((p.z - ORIGINE) / TEXEL)
		var rt := int(ceil(AIGUILLES_BORD * s * 1.4 / TEXEL))
		for j in range(maxi(cj - rt, j0), mini(cj + rt, j1) + 1):
			var z := ORIGINE + (j + 0.5) * TEXEL
			for i in range(maxi(ci - rt, i0), mini(ci + rt, i1) + 1):
				var k := j * TAILLE + i
				if actif[k] == 0 or (mat[k] != NEIGE and mat[k] != CROUTE):
					continue
				var x := ORIGINE + (i + 0.5) * TEXEL
				var r := Vector2(x - p.x, z - p.z).length() / (s * (1.0 + 0.3 * bruit_clair.get_noise_2d(x * 1.7, z * 1.7)))
				if r >= AIGUILLES_BORD:
					continue
				var tache := 0.5 + 0.5 * bruit_tache.get_noise_2d(x, z)
				var dens: float
				if r < AIGUILLES_COEUR:
					dens = 0.75
				elif r < AIGUILLES_PLEIN:
					dens = lerpf(0.75, AIGUILLES_DENSITE * 0.5, (r - AIGUILLES_COEUR) / (AIGUILLES_PLEIN - AIGUILLES_COEUR))
				else:
					dens = AIGUILLES_DENSITE * 0.5 * (1.0 - (r - AIGUILLES_PLEIN) / (AIGUILLES_BORD - AIGUILLES_PLEIN))
				dens *= smoothstep(0.25, 0.75, tache) * 1.3
				if lerpf(_alea(i, j, 3), 0.5 + 0.9 * bruit_fin.get_noise_2d(x + 40.0, z), GRAIN) < dens:
					mat[k] = AIGUILLES
				elif mat[k] == CROUTE:
					mat[k] = NEIGE  # pas de croûte à l'abri des arbres

	# mousse (creux au nord, pied nord des roches) ; glace dans les creux plats plus marqués
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * TAILLE + i
			if actif[k] == 0 or (mat[k] != NEIGE and mat[k] != CROUTE):
				continue
			var x := ORIGINE + (i + 0.5) * TEXEL
			var z := ORIGINE + (j + 0.5) * TEXEL
			var s := lerpf(_alea(i, j, 4), 0.5 + 0.9 * bruit_fin.get_noise_2d(x - 40.0, z), GRAIN)
			# glace : seuil lisse (aucun bruit blanc) → quelques grandes plaques, seulement dans les creux
			if creux[k] > GLACE_CREUX - 0.06 * bruit_croute.get_noise_2d(x * 1.5, z * 1.5) and absf(nz[k]) < 0.15 and dchemin[k] > 4.0:
				mat[k] = GLACE
				continue
			if s >= MOUSSE_PART:
				continue
			var mousse: bool = creux[k] > CREUX_SEUIL and nz[k] < MOUSSE_NORD
			if not mousse:
				for dj in 6:
					if j + dj + 1 <= j1 and mat[(j + dj + 1) * TAILLE + i] == ROCHE:
						mousse = true
						break
			if mousse:
				mat[k] = MOUSSE

	_chrono("aiguilles mousse")
	# glace : pas d'éclats (moins de 5 voisins de glace → neige), puis bords arrondis d'un texel
	# dans les creux voisins (≥ 4 voisins de glace)
	for passe in 2:
		var mg := mat.duplicate()
		for j in range(j0 + 1, j1):
			for i in range(i0 + 1, i1):
				var k := j * TAILLE + i
				if actif[k] == 0 or (mat[k] != GLACE and (passe == 0 or mat[k] != NEIGE or creux[k] <= CREUX_SEUIL)):
					continue
				var ng := int(mat[k - 1] == GLACE) + int(mat[k + 1] == GLACE) + int(mat[k - TAILLE] == GLACE) + int(mat[k + TAILLE] == GLACE) \
					+ int(mat[k - TAILLE - 1] == GLACE) + int(mat[k - TAILLE + 1] == GLACE) + int(mat[k + TAILLE - 1] == GLACE) + int(mat[k + TAILLE + 1] == GLACE)
				if mat[k] == GLACE and ng < 5:
					mg[k] = NEIGE
				elif passe == 1 and mat[k] == NEIGE and ng >= 4 and creux[k] > CREUX_SEUIL:
					mg[k] = GLACE
		mat = mg
	_chrono("glace")
	# filtre de majorité (3×3) : pas de texel de matière isolé (les bords sont dessinés par le shader)
	var mat2 := mat.duplicate()
	for j in range(j0 + 1, j1):
		for i in range(i0 + 1, i1):
			var k := j * TAILLE + i
			if actif[k] == 0:
				continue
			var m0 := mat[k]
			if m0 == TERRE or (m0 == GLACE and dchemin[k] < 1.0):
				continue
			# chemin rapide : au moins 2 voisins (sur 4) de même matière → rien à faire
			var rapide := int(mat[k - 1] == m0) + int(mat[k + 1] == m0) + int(mat[k - TAILLE] == m0) + int(mat[k + TAILLE] == m0)
			if rapide >= 2:
				continue
			var meme := 0
			var comptes := {}
			for dj in range(-1, 2):
				for di in range(-1, 2):
					if di == 0 and dj == 0:
						continue
					var kk := k + dj * TAILLE + di
					if actif[kk] == 0:
						continue
					var mm := mat[kk]
					if mm == m0:
						meme += 1
					else:
						comptes[mm] = comptes.get(mm, 0) + 1
			if meme <= 1 and not comptes.is_empty():
				var best := m0
				var bc := 0
				for mm: int in comptes:
					if comptes[mm] > bc:
						bc = comptes[mm]
						best = mm
				mat2[k] = best
	mat = mat2

	_chrono("majorité")
	# --- relief fin ---
	var rel := PackedFloat32Array()
	rel.resize(TAILLE * TAILLE)
	for j in range(j0, j1 + 1):
		var z := ORIGINE + (j + 0.5) * TEXEL
		for i in range(i0, i1 + 1):
			var k := j * TAILLE + i
			if actif[k] == 0:
				continue
			var x := ORIGINE + (i + 0.5) * TEXEL
			var hb := BOSSES * bruit_bosse.get_noise_2d(x * 1.0, z * 0.4)
			if mat[k] == PIETINEE or mat[k] == TERRE:
				hb = 0.4 * hb + 0.015 * bruit_fin.get_noise_2d(x * 2.0, z * 2.0)
			elif mat[k] == ROCHE:
				hb = 0.0
			rel[k] = hb
	for o in obstacles:
		var c: Vector2 = o[0]
		var R: float = o[1]
		if ZoneBiome.masque(c.x, c.y) <= 0.0:
			continue
		var amp := CONGERE * minf(R, 1.2)
		var ci := int((c.x - ORIGINE) / TEXEL)
		var cj := int((c.y - ORIGINE) / TEXEL)
		var ri := int(ceil((R * 1.6 + 0.6) / TEXEL))
		var rj_av := int(ceil((R * 2.4 + 0.8) / TEXEL))
		var rj_ar := int(ceil((R * 5.0 + 1.0) / TEXEL))
		for j in range(maxi(cj - rj_av, j0), mini(cj + rj_ar, j1) + 1):
			var z := ORIGINE + (j + 0.5) * TEXEL
			var a := z - c.y  # > 0 : sous le vent
			for i in range(maxi(ci - ri, i0), mini(ci + ri, i1) + 1):
				var k := j * TAILLE + i
				if actif[k] == 0 or mat[k] == ROCHE or mat[k] == PIETINEE or mat[k] == TERRE:
					continue
				var x := ORIGINE + (i + 0.5) * TEXEL
				var lat := x - c.x
				var d := sqrt(lat * lat + a * a)
				var dh := -DOUVE * exp(-pow((d - R * 1.1) / 0.28, 2.0))
				if a > 0.0:
					var w := R * (0.8 + 0.25 * a / R)  # la queue s'élargit
					dh += amp * exp(-pow(lat / w, 2.0)) * (a / R) * exp(1.0 - a / (2.0 * R)) * 0.5
				else:
					dh += amp * 0.45 * exp(-pow(lat / (R * 1.2), 2.0)) * exp(-pow((-a - R * 1.7) / (0.6 * R + 0.2), 2.0))
				rel[k] += dh
	for a in arbres_zone:
		var p: Vector3 = a["pos"]
		var s: float = a["s"]
		var ci := int((p.x - ORIGINE) / TEXEL)
		var cj := int((p.z - ORIGINE) / TEXEL)
		var rt := int(ceil(s * 1.8 / TEXEL))
		for j in range(maxi(cj - rt, j0), mini(cj + rt, j1) + 1):
			var z := ORIGINE + (j + 0.5) * TEXEL
			for i in range(maxi(ci - rt, i0), mini(ci + rt, i1) + 1):
				var k := j * TAILLE + i
				if actif[k] == 0 or mat[k] == ROCHE:
					continue
				var x := ORIGINE + (i + 0.5) * TEXEL
				var r := Vector2(x - p.x, z - p.z).length() / s
				rel[k] += -CUVETTE * (1.0 - smoothstep(0.25, CUVETTE_R, r)) + BOURRELET * exp(-pow((r - 1.25) / 0.3, 2.0))

	_chrono("relief")
	# --- canaux B : creux (laplacien du relief), densité de détails, variante ---
	var data := PackedByteArray()
	data.resize(TAILLE * TAILLE * 4)
	for j in range(j0, j1 + 1):
		var z := ORIGINE + (j + 0.5) * TEXEL
		for i in range(i0, i1 + 1):
			var k := j * TAILLE + i
			data[k * 4 + 3] = 255
			if actif[k] == 0:
				continue
			var x := ORIGINE + (i + 0.5) * TEXEL
			var lap := 0.0
			if i - 2 >= i0 and i + 2 <= i1 and j - 2 >= j0 and j + 2 <= j1:
				lap = (rel[k - 2] + rel[k + 2] + rel[k - 2 * TAILLE] + rel[k + 2 * TAILLE]) * 0.25 - rel[k]
			var sc := 0
			var bf := 0.004 * bruit_fin.get_noise_2d(x * 0.7, z * 0.7)
			if lap > CREUX_TON[1] + bf:
				sc = -2
			elif lap > CREUX_TON[0] + bf:
				sc = -1
			elif lap < BOSSE_TON + bf:
				sc = 1
			var m := mat[k]
			# densité : 0 neige nue (reflets), 1 cailloux, 2 brindilles, 3 herbes sèches
			var dens := 0
			var dc := dchemin[k]
			if dc < 2.2 or bruit_herbe.get_noise_2d(x * 2.5, z * 2.5) > 0.35:
				dens = 1
			if m == AIGUILLES or m == MOUSSE:
				dens = 2
			if bruit_herbe.get_noise_2d(x, z) > 0.42 and dc > 1.0:
				dens = 3
			var variante := 1 if bruit_variante.get_noise_2d(x, z) > 0.0 else 0
			data[k * 4] = m * 16
			data[k * 4 + 1] = clampi(128 + int(round(rel[k] * 400.0)), 0, 255)
			data[k * 4 + 2] = 128 | (variante << 5) | (dens << 3) | (sc + 4)
	var carte := Image.create_from_data(TAILLE, TAILLE, false, Image.FORMAT_RGBA8, data)
	_chrono("canaux")
	if OS.has_environment("SOL_DEBUG"):
		_debug(OS.get_environment("SOL_DEBUG"), carte, mat, i0, i1, j0, j1)
	var tr := _traces(monde, mat, actif)
	_chrono("traces")
	if cache_mode == CACHE_ECRIRE:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_CARTE.get_base_dir()))
		carte.set_meta("signature", signature)
		tr.set_meta("signature", signature)
		ResourceSaver.save(carte, CACHE_CARTE, ResourceSaver.FLAG_COMPRESS)
		ResourceSaver.save(tr, CACHE_TRACES, ResourceSaver.FLAG_COMPRESS)
		cache_statut = "ecrit"
	elif cache_mode == CACHE_VERIFIER:
		var c1 := ResourceLoader.load(CACHE_CARTE) as Image if ResourceLoader.exists(CACHE_CARTE) else null
		var c2 := ResourceLoader.load(CACHE_TRACES) as Image if ResourceLoader.exists(CACHE_TRACES) else null
		if c1 == null or c2 == null:
			cache_statut = "absent"
		elif c1.get_meta("signature", "") != signature:
			cache_statut = "perime"
		else:
			cache_statut = "identique" if (c1.get_data() == carte.get_data() and c2.get_data() == tr.get_data()) else "DIFFERENT"
	return [carte, tr]

# --- empreintes -------------------------------------------------------------------------------------

## Carte d'empreintes 1/32 m de la zone : 128 = rien, < 128 creux (ton plus sombre), > 128 lèvre.
static func _traces(monde: Node, mat: PackedByteArray, actif: PackedByteArray) -> Image:
	_tt = PackedByteArray()
	_tt.resize(TRACES_W * TRACES_H)
	_tt.fill(128)
	var creux: Array[int] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine("traces")
	var ctx := {"creux": creux, "mat": mat, "actif": actif}
	# pas le long des chemins : plusieurs pistes décalées, dans les deux sens, avec des trous
	var pts: PackedVector2Array = monde.chemins.points
	var debuts: PackedInt32Array = monde.chemins.debuts
	for li in debuts.size():
		var a := debuts[li]
		var b := debuts[li + 1] if li + 1 < debuts.size() else pts.size()
		var ligne := pts.slice(a, b)
		var cumul := PackedFloat32Array([0.0])
		for k in range(1, ligne.size()):
			cumul.append(cumul[k - 1] + ligne[k].distance_to(ligne[k - 1]))
		var longueur := cumul[cumul.size() - 1]
		for piste in PISTES_CHEMIN:
			var decal := clampf(rng.randfn(0.0, 0.24), -0.55, 0.55)
			var sens := 1.0 if rng.randf() < 0.5 else -1.0
			var foulee := rng.randf_range(0.62, 0.78)
			var s := rng.randf_range(0.0, foulee)
			var pied := 0
			var trou := 0.0
			while s < longueur:
				var pt := _le_long(ligne, cumul, s)
				var pos: Vector2 = pt[0]
				var tan: Vector2 = pt[1] * sens
				var nrm := Vector2(-tan.y, tan.x)
				decal = clampf(decal + rng.randfn(0.0, 0.03), -0.65, 0.65)
				if trou > 0.0:
					trou -= foulee
				elif rng.randf() < 0.04:
					trou = rng.randf_range(1.0, 4.0)
				else:
					var cote := 0.09 if pied % 2 == 0 else -0.09
					var dir := tan.rotated(rng.randf_range(-0.12, 0.12) + (0.08 if cote > 0 else -0.08))
					_empreinte(ctx, pos + nrm * (decal + cote), dir, "botte")
				pied += 1
				s += foulee * rng.randf_range(0.93, 1.07)
	# piétinement autour du feu, de la stèle et devant la porte : pas en tous sens
	var porte := Vector2(monde.TUMULUS.x, monde.TUMULUS.z + 2.8)
	for c in [[Vector2.ZERO, RAYON_FEU, 110], [Vector2(monde.CERCLE.x, monde.CERCLE.z), RAYON_STELE, 70], [porte, RAYON_PORTE, 45]]:
		for n in c[2]:
			var r: float = c[1] * sqrt(rng.randf()) * 0.95
			var p: Vector2 = c[0] + Vector2(r, 0.0).rotated(rng.randf() * TAU)
			_empreinte(ctx, p, Vector2.RIGHT.rotated(rng.randf() * TAU), "botte")
	# pistes d'animaux : renard (ligne droite de petites pattes), lièvre (groupes de 4 bonds)
	for n in RENARDS + LIEVRES:
		var renard := n < RENARDS
		var p := Vector2(rng.randf_range(ZoneBiome.X0 + 12.0, ZoneBiome.X1 - 10.0), rng.randf_range(ZoneBiome.Z0 + 12.0, ZoneBiome.Z1 - 10.0))
		var cap := rng.randf() * TAU
		var pas := 0.34 if renard else 1.3
		var nb := int(rng.randf_range(26.0, 44.0) / pas)
		for k in nb:
			cap += rng.randfn(0.0, 0.08 if renard else 0.18)
			var dir := Vector2.RIGHT.rotated(cap)
			var nrm := Vector2(-dir.y, dir.x)
			if renard:
				_empreinte(ctx, p + nrm * (0.025 if k % 2 == 0 else -0.025), dir, "renard")
			else:
				_empreinte(ctx, p + dir * 0.22 + nrm * 0.07, dir, "lievre_av")
				_empreinte(ctx, p + dir * 0.22 - nrm * 0.07, dir, "lievre_av")
				_empreinte(ctx, p - dir * 0.05, dir, "lievre_ar")
				_empreinte(ctx, p - dir * 0.22 + nrm * 0.02, dir, "lievre_ar")
			p += dir * pas * rng.randf_range(0.9, 1.1)
	# lèvres claires : en bas à droite des creux (bible, échantillon C)
	var t := _tt
	_tt = PackedByteArray()
	for k: int in creux:
		for kk in [k + 1, k + TRACES_W]:
			if kk < t.size() and t[kk] == 128:
				t[kk] = 129
	return Image.create_from_data(TRACES_W, TRACES_H, false, Image.FORMAT_R8, t)

## Point et tangente à l'abscisse curviligne `s` d'une polyligne.
static func _le_long(ligne: PackedVector2Array, cumul: PackedFloat32Array, s: float) -> Array:
	var k := 1
	while k < cumul.size() - 1 and cumul[k] < s:
		k += 1
	var a := ligne[k - 1]
	var b := ligne[k]
	var l := maxf(cumul[k] - cumul[k - 1], 0.001)
	return [a.lerp(b, clampf((s - cumul[k - 1]) / l, 0.0, 1.0)), (b - a).normalized()]

const DIRECTIONS := 32  # orientations précalculées des tampons d'empreinte
static var _tampons := {}
static var _tt: PackedByteArray  # carte d'empreintes en cours (statique : pas de copie à l'écriture)

## Tampon d'une empreinte : liste [dx, dz, valeur] (unités 1/32 m) pour la direction `idx`/DIRECTIONS.
static func _tampon(forme: String, idx: int) -> Array:
	var cle := "%s%d" % [forme, idx]
	if _tampons.has(cle):
		return _tampons[cle]
	var L := 0.16   # demi-longueur (m)
	var W := 0.06   # demi-largeur
	match forme:
		"renard":
			L = 0.045
			W = 0.04
		"lievre_av":
			L = 0.11
			W = 0.035
		"lievre_ar":
			L = 0.04
			W = 0.035
	var dir := Vector2.RIGHT.rotated(TAU * idx / DIRECTIONS)
	var nrm := Vector2(-dir.y, dir.x)
	var r := int(ceil(L * TRACES_RES)) + 1
	var l: Array = []
	var dans := {}
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := Vector2(dx, dz) / TRACES_RES
			var u := c.dot(dir) / L
			var v := c.dot(nrm) / W
			if forme == "botte":
				# semelle : avant plus large que le talon, cambrure resserrée
				var w := 1.0 if u > 0.0 else 0.8
				if absf(u) > 1.0 or absf(v) > w:
					continue
				if u > -0.35 and u < -0.1 and absf(v) > 0.55:
					continue
			elif u * u + v * v > 1.0:
				continue
			dans[Vector2i(dx, dz)] = true
	# bord haut-gauche profond (ombre), intérieur peu creusé : la forme se lit
	for pt: Vector2i in dans:
		var bord: bool = not dans.has(pt - Vector2i(1, 0)) or not dans.has(pt - Vector2i(0, 1))
		l.append([pt.x, pt.y, 125 if bord else 127])
	_tampons[cle] = l
	return l

## Tamponne une empreinte orientée (`dir` = sens de la marche) dans la carte 1/32 m.
static func _empreinte(ctx: Dictionary, p: Vector2, dir: Vector2, forme: String) -> void:
	# pas d'empreinte sur la roche, la glace, hors zone
	var ci := int((p.x - ORIGINE) / TEXEL)
	var cj := int((p.y - ORIGINE) / TEXEL)
	if ci < 0 or cj < 0 or ci >= TAILLE or cj >= TAILLE:
		return
	var kc := cj * TAILLE + ci
	var mc: int = (ctx["mat"] as PackedByteArray)[kc]
	if (ctx["actif"] as PackedByteArray)[kc] == 0 or mc == ROCHE or mc == GLACE:
		return
	var creux: Array[int] = ctx["creux"]
	var idx := posmod(int(round(dir.angle() / TAU * DIRECTIONS)), DIRECTIONS)
	var qx := int(floor((p.x - TRACES_ORIGINE.x) * TRACES_RES))
	var qz := int(floor((p.y - TRACES_ORIGINE.y) * TRACES_RES))
	var tampon := _tampon(forme, idx)
	# une empreinte qui en recouvre déjà une autre (> 15 %) est omise : les pas restent lisibles
	var deja := 0
	for e: Array in tampon:
		var x2: int = qx + e[0]
		var z2: int = qz + e[1]
		if x2 >= 0 and z2 >= 0 and x2 < TRACES_W and z2 < TRACES_H and _tt[z2 * TRACES_W + x2] != 128:
			deja += 1
	if deja * 100 > tampon.size() * 15:
		return
	for e: Array in tampon:
		var x: int = qx + e[0]
		var z: int = qz + e[1]
		if x < 0 or z < 0 or x >= TRACES_W or z >= TRACES_H:
			continue
		var k := z * TRACES_W + x
		var profond: int = e[2]
		if _tt[k] == 128 or _tt[k] > profond:
			_tt[k] = profond
			creux.append(k)

## Débogage (variable d'environnement SOL_DEBUG = dossier) : matières, relief et creux de la zone en PNG.
static func _debug(dossier: String, carte: Image, mat: PackedByteArray, i0: int, i1: int, j0: int, j1: int) -> void:
	var couleurs := [Color("#e0e6f0"), Color("#8090b0"), Color("#6a4a30"), Color("#b05a20"), Color("#2c5a41"), Color("#404050"), Color("#40c0f0"), Color("#ffffff")]
	var w := i1 - i0 + 1
	var hh := j1 - j0 + 1
	var a := Image.create(w * 3, hh, false, Image.FORMAT_RGBA8)
	var comptes := [0, 0, 0, 0, 0, 0, 0, 0]
	for j in hh:
		for i in w:
			var c := carte.get_pixel(i0 + i, j0 + j)
			var b := int(round(c.b * 255.0))
			if b < 128:
				continue
			var m := mat[(j0 + j) * TAILLE + i0 + i]
			comptes[m] += 1
			a.set_pixel(i, j, couleurs[m])
			a.set_pixel(w + i, j, Color(c.g, c.g, c.g))
			var sc := (b & 7) - 4
			a.set_pixel(2 * w + i, j, Color(0.5 + sc * 0.2, 0.5 + sc * 0.2, 0.5 + ((b >> 3) & 3) * 0.15))
	a.save_png(dossier + "/carte_debug.png")
	print("Sol debug : matières ", comptes)
