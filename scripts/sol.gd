class_name Sol
## Sol écologique de la zone témoin (lot D) : une carte précalculée 480² (0,5 m/texel) lue par
## le shader du terrain. R = matière × 32, G = clarté, B = zone (0 = ancien rendu, inchangé).
## Hors zone, ou avec --biome=ancien, B vaut 0 partout : le terrain rend exactement comme avant.

const TAILLE := 480           # texels par côté
const TEXEL := 0.5            # m par texel
const ORIGINE := -120.0       # coin de la carte (m)
const NEIGE := 0              # matières (valeur de R / 32)
const PIETINEE := 1
const TERRE := 2
const AIGUILLES := 3
const MOUSSE := 4
const ROCHE := 5

const PENTE_ROCHE := 0.80     # normale.y sous laquelle c'est de la roche
const PENTE_AFFLEURE := 0.88  # entre les deux : pierre affleurante, tramée
const PART_AFFLEURE := 0.35
const BRUIT_ROCHE := 0.08     # amplitude du bruit sur le seuil de pente
const CHEMIN_TERRE := 1.0     # m de l'axe : terre, de plus en plus clairsemée (pleine sous 0,4 m, nulle à 1 m)
const CHEMIN_NEIGE := 1.8     # m : neige piétinée (bande tramée ±0,3 m)
const RAYON_STELE := 3.5      # neige piétinée autour de la stèle (bande tramée 0,8 m)
const RAYON_PORTE := 3.0      # devant la porte du tertre
const RAYON_FEU := 5.0        # plateau du feu
const AIGUILLES_PLEIN := 1.2  # × échelle de l'arbre : 70 % d'aiguilles
const AIGUILLES_BORD := 2.0   # × échelle : 30 % tramé
const CREUX_SEUIL := 0.05     # creux : moyenne des voisins à 4 m − hauteur (m)
const MOUSSE_NORD := -0.2     # normale.z sous laquelle la pente regarde le nord
const MOUSSE_PART := 0.4

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Durée du dernier calcul (ms), pour les mesures.
static var temps_ms := 0.0

static func _bayer(i: int, j: int) -> float:
	return (float(BAYER[(i & 3) + ((j & 3) << 2)]) + 0.5) / 16.0

## `arbres` = transforms des arbres (monde.arbres), pour l'effet « sous les arbres ».
static func appliquer(mat_terrain: ShaderMaterial, monde: Node, arbres: Array) -> void:
	if not ZoneBiome.actif:
		return
	var t0 := Time.get_ticks_usec()
	var img := _calculer(monde, arbres)
	mat_terrain.set_shader_parameter("carte_sol", ImageTexture.create_from_image(img))
	mat_terrain.set_shader_parameter("carte_rect", Vector3(ORIGINE, ORIGINE, 1.0 / (TAILLE * TEXEL)))
	mat_terrain.set_shader_parameter("tex_terre", Palette.texture_terre())
	mat_terrain.set_shader_parameter("tex_mousse", Palette.texture_mousse())
	mat_terrain.set_shader_parameter("tex_aiguilles_sol", Palette.texture_aiguilles_sol())
	mat_terrain.set_shader_parameter("tex_neige_pietinee", Palette.texture_neige_pietinee())
	mat_terrain.set_shader_parameter("sol_carte", true)
	temps_ms = (Time.get_ticks_usec() - t0) / 1000.0
	print("Sol : carte de sol calculée en %.0f ms" % temps_ms)

static func _calculer(monde: Node, arbres: Array) -> Image:
	var bruit_roche := FastNoiseLite.new()
	bruit_roche.seed = ZoneBiome.graine("sol")
	bruit_roche.frequency = 0.18
	bruit_roche.fractal_octaves = 2
	var bruit_clair := FastNoiseLite.new()
	bruit_clair.seed = ZoneBiome.graine("sol") + 1
	bruit_clair.frequency = 0.35

	# texels de la zone ; hauteurs sur une grille de 1 m (un texel sur deux, marge de 5 m pour le
	# laplacien à 4 m), puis normale / creux calculés aux nœuds et interpolés par texel
	var i0 := maxi(0, int(floor((ZoneBiome.X0 - ORIGINE) / TEXEL)))
	var i1 := mini(TAILLE - 1, int(ceil((ZoneBiome.X1 - ORIGINE) / TEXEL)))
	var j0 := maxi(0, int(floor((ZoneBiome.Z0 - ORIGINE) / TEXEL)))
	var j1 := mini(TAILLE - 1, int(ceil((ZoneBiome.Z1 - ORIGINE) / TEXEL)))
	var gi0 := i0 - (i0 & 1) - 10  # pair : les nœuds tombent sur des centres de texels
	var gj0 := j0 - (j0 & 1) - 10
	var gw := (i1 - gi0) / 2 + 7
	var gh := (j1 - gj0) / 2 + 7
	var h := PackedFloat32Array()
	h.resize(gw * gh)
	for gj in gh:
		var z := ORIGINE + (gj0 + 2 * gj + 0.5) * TEXEL
		for gi in gw:
			h[gj * gw + gi] = monde.hauteur(ORIGINE + (gi0 + 2 * gi + 0.5) * TEXEL, z)
	var g_ny := PackedFloat32Array()
	var g_nz := PackedFloat32Array()
	var g_cr := PackedFloat32Array()
	g_ny.resize(gw * gh)
	g_nz.resize(gw * gh)
	g_cr.resize(gw * gh)
	for gj in range(5, gh - 5):
		for gi in range(5, gw - 5):
			var gk := gj * gw + gi
			var dx := h[gk - 1] - h[gk + 1]
			var dz := h[gk - gw] - h[gk + gw]
			var inv := 1.0 / sqrt(dx * dx + 4.0 + dz * dz)  # normale à ±1 m, comme le maillage
			g_ny[gk] = 2.0 * inv
			g_nz[gk] = dz * inv
			g_cr[gk] = (h[gk - 4] + h[gk + 4] + h[gk - 4 * gw] + h[gk + 4 * gw]) * 0.25 - h[gk]

	var mat := PackedByteArray()
	mat.resize(TAILLE * TAILLE)      # matière (0 = neige)
	var actif := PackedByteArray()
	actif.resize(TAILLE * TAILLE)    # 1 = texel de la zone (B = 255)
	var clair := PackedByteArray()
	clair.resize(TAILLE * TAILLE)
	var nz := PackedFloat32Array()   # normale.z, pour la mousse
	nz.resize(TAILLE * TAILLE)
	var creux := PackedFloat32Array()
	creux.resize(TAILLE * TAILLE)

	var chemins = monde.chemins
	var stele := Vector2(monde.CERCLE.x, monde.CERCLE.z)
	var porte := Vector2(monde.TUMULUS.x, monde.TUMULUS.z + 2.8)  # = tertre.porte_dehors

	for j in range(j0, j1 + 1):
		var z := ORIGINE + (j + 0.5) * TEXEL
		for i in range(i0, i1 + 1):
			var x := ORIGINE + (i + 0.5) * TEXEL
			var b := _bayer(i, j)
			if ZoneBiome.masque(x, z) <= b:
				continue  # tramage du masque : ce texel garde l'ancien rendu
			var k := j * TAILLE + i
			actif[k] = 1
			var u := (i - gi0) * 0.5
			var v := (j - gj0) * 0.5
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
				var d: float = chemins.distance(x, z)
				var t := 0.5 - b  # -0,5..0,5 : décale les seuils pour tramer
				if (CHEMIN_TERRE - d) / 0.6 > b:
					mt = TERRE
				elif d < CHEMIN_NEIGE + 0.6 * t:
					mt = PIETINEE
				else:
					var p := Vector2(x, z)
					if p.distance_to(stele) < RAYON_STELE + 0.8 * t or p.distance_to(porte) < RAYON_PORTE + 0.8 * t or p.length() < RAYON_FEU + 0.8 * t:
						mt = PIETINEE
			mat[k] = mt
			var c := 128.0 + bruit_clair.get_noise_2d(x, z) * 22.0
			clair[k] = clampi(int(c * (0.85 if mt == ROCHE else 1.0)), 0, 255)

	# sous les arbres : aiguilles (70 % jusqu'à 1,2 × échelle, 30 % tramé jusqu'à 2 × échelle)
	for tr: Transform3D in arbres:
		var p := tr.origin
		if ZoneBiome.masque(p.x, p.z) <= 0.0:
			continue
		var s := tr.basis.get_scale().x
		var ci := int((p.x - ORIGINE) / TEXEL)
		var cj := int((p.z - ORIGINE) / TEXEL)
		var rt := int(ceil(AIGUILLES_BORD * s * 1.3 / TEXEL))
		for j in range(maxi(cj - rt, j0), mini(cj + rt, j1) + 1):
			var z := ORIGINE + (j + 0.5) * TEXEL
			for i in range(maxi(ci - rt, i0), mini(ci + rt, i1) + 1):
				var k := j * TAILLE + i
				if actif[k] == 0 or mat[k] != NEIGE:
					continue
				var x := ORIGINE + (i + 0.5) * TEXEL
				# rayon bruité : jamais un disque régulier
				var r := Vector2(x - p.x, z - p.z).length() / (s * (1.0 + 0.25 * bruit_clair.get_noise_2d(x * 1.7, z * 1.7)))
				var b := _bayer(i, j)
				if (r < AIGUILLES_PLEIN and b < 0.7) or (r < AIGUILLES_BORD and b < 0.3):
					mat[k] = AIGUILLES

	# mousse : creux ET pente au nord, tramée 40 % ; un peu au pied des roches, côté nord
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * TAILLE + i
			if actif[k] == 0 or mat[k] != NEIGE or _bayer(i, j) >= MOUSSE_PART:
				continue
			var mousse: bool = creux[k] > CREUX_SEUIL and nz[k] < MOUSSE_NORD
			if not mousse:
				# roche au sud (z croissant) à 1-3 texels : on est du côté nord de la roche
				for dj in 3:
					if j + dj + 1 <= j1 and mat[(j + dj + 1) * TAILLE + i] == ROCHE:
						mousse = true
						break
			if mousse:
				mat[k] = MOUSSE

	var data := PackedByteArray()
	data.resize(TAILLE * TAILLE * 4)
	for k in TAILLE * TAILLE:
		if actif[k] == 1:
			data[k * 4] = mat[k] * 32
			data[k * 4 + 1] = clair[k]
			data[k * 4 + 2] = 255
		data[k * 4 + 3] = 255
	return Image.create_from_data(TAILLE, TAILLE, false, Image.FORMAT_RGBA8, data)
