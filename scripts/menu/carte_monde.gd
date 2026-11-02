class_name CarteMonde
extends Node3D
## Générateur de la CARTE DU MONDE (onglet Carte, scripts/menu/onglet_carte.gd) : une maquette 3D basse définition du vrai
## terrain, vue de haut en perspective inclinée façon Skyrim, rendue dans un SubViewport à part (own_world_3d) au rendu PS1.
## TOUT vient des données du monde, rien n'est dessiné à la main (la carte suivra l'agrandissement à ~1 km²) :
##   - relief : monde.hauteurs_maillage (grille du terrain, monde.CASES + 1 au carré) ; pourtour : monde.hauteur() à 4 m ;
##   - couleurs (carte_couleur, 1 m/texel) : matières de la carte de sol 960² (mat_terrain « carte_sol », R = matière × 16),
##     pente (roche), lac (EauVillage.sous_le_lac), rivière (ReliefVillage.niveau_eau), chemins (monde.chemins, axe du
##     village, piste de la grotte), enceinte (ReliefVillage.PALISSADE), champs (VillageBati.CHAMPS), sous-bois (arbres) ;
##   - volumes : sapins (monde.arbres, MultiMesh), bâtiments (village.emprises), palissade, pierres du cercle, tertre, pont ;
##   - ambiance : lumière rasante du nord-ouest (convention des cartes), nuages qui dérivent et leurs ombres, brume de bord.
## Coût : ~0,3-0,6 s à la première ouverture de l'onglet (puis gardé). Aucune règle de jeu, aucune écriture dans le monde.

const SHADER_TERRAIN := preload("res://shaders/carte_terrain.gdshader")
const SHADER_OBJET := preload("res://shaders/carte_objet.gdshader")
const SHADER_NUAGES := preload("res://shaders/carte_nuages.gdshader")

const HORS := 80.0          # m de pourtour montré au-delà de l'aire de jeu (noyé dans la brume)
const PAS_HORS := 4.0       # pas de la grille du pourtour (m)
const RES := 1.0            # m par texel de carte_couleur
const SAPINS_HORS := 1400   # sapins procéduraux sur le pourtour

## Couleurs d'albédo par matière de sol (Sol.NEIGE … Sol.CROUTE).
const COULEURS_SOL := [Color("#e4eaef"), Color("#c3c3c2"), Color("#7a5d44"), Color("#5b5040"), Color("#7d8a6a"),
	Color("#77777e"), Color("#b9d2e0"), Color("#eef2f5")]
const NEIGE := Color("#e4eaef")
const ROCHE := Color("#6f7078")
const GLACE := Color("#a9c6d8")
const EAU := Color("#35566e")
const EAU_LIBRE := Color("#2b4a63")
const CHEMIN := Color("#a89a86")
const ENCEINTE := Color("#b8b2a8")
const SOUS_BOIS := Color("#3d4a3c")
const SAPIN := Color("#1b2e24")
const SAPIN_NEIGE := Color("#8fa39a")
const BOIS := Color("#4a3020")
const TOIT := Color("#eef0ee")
const PIERRE := Color("#8a8f99")
const TERRE_TERTRE := Color("#cfd5d6")

var monde: Node
var demi := 120.0
var pas := 2.0
var n := 121
var hs := PackedFloat32Array()        # hauteurs de l'aire de jeu (n × n, pas `pas`)
var h_min := 0.0
var h_max := 0.0
var carte_couleur: ImageTexture
var tex_nuages: NoiseTexture2D
var materiaux: Array[ShaderMaterial] = []
var mat_nuages: ShaderMaterial
var lumiere: DirectionalLight3D
var nb_sapins := 0
var nb_batiments := 0
var temps_ms := 0
var pret := false

## Construit la maquette depuis `monde_` (monde.gd chargé : pret). Renvoie false si le monde n'a pas de relief (scène d'essai).
func construire(monde_: Node) -> bool:
	var t0 := Time.get_ticks_msec()
	monde = monde_
	if monde == null or not (monde.get("hauteurs_maillage") is PackedFloat64Array) or (monde.hauteurs_maillage as PackedFloat64Array).is_empty():
		return false
	var h64: PackedFloat64Array = monde.hauteurs_maillage
	n = int(round(sqrt(float(h64.size()))))
	demi = float(monde.TAILLE) * 0.5
	pas = float(monde.TAILLE) / float(n - 1)
	hs.resize(h64.size())
	h_min = INF
	h_max = -INF
	for i in h64.size():
		hs[i] = h64[i]
		h_min = minf(h_min, hs[i])
		h_max = maxf(h_max, hs[i])
	tex_nuages = NoiseTexture2D.new()
	tex_nuages.width = 256
	tex_nuages.height = 256
	tex_nuages.seamless = true
	var bn := FastNoiseLite.new()
	bn.seed = 41
	bn.frequency = 0.012
	bn.fractal_octaves = 4
	tex_nuages.noise = bn
	_couleurs()
	_relief()
	_sapins()
	_batiments()
	_reperes()
	_nuages()
	_lumiere()
	temps_ms = Time.get_ticks_msec() - t0
	pret = true
	return true

## Hauteur du relief de la maquette en (x, z) (bilinéaire dans l'aire de jeu, monde.hauteur() au-delà).
func hauteur(x: float, z: float) -> float:
	var fx := (x + demi) / pas
	var fz := (z + demi) / pas
	if fx < 0.0 or fz < 0.0 or fx > n - 1 or fz > n - 1:
		return monde.hauteur(x, z) if monde != null and monde.has_method("hauteur") else 0.0
	var i := mini(int(fx), n - 2)
	var j := mini(int(fz), n - 2)
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(hs[j * n + i], hs[j * n + i + 1], tx)
	var b := lerpf(hs[(j + 1) * n + i], hs[(j + 1) * n + i + 1], tx)
	return lerpf(a, b, tz)

## Temps des nuages (le jeu est en pause pendant le menu : l'onglet avance l'horloge lui-même).
func regler_temps(t: float, clair: float) -> void:
	for m in materiaux:
		m.set_shader_parameter("temps", t)
	if mat_nuages != null:
		mat_nuages.set_shader_parameter("temps", t)
		mat_nuages.set_shader_parameter("clair", clair)

func _normale(i: int, j: int) -> Vector3:
	var hg := hs[j * n + maxi(i - 1, 0)]
	var hd := hs[j * n + mini(i + 1, n - 1)]
	var hh := hs[maxi(j - 1, 0) * n + i]
	var hb := hs[mini(j + 1, n - 1) * n + i]
	return Vector3(hg - hd, 2.0 * pas, hh - hb).normalized()

# ------------------------------------------------------------------ couleurs (carte_couleur)

func _couleurs() -> void:
	var N := int(round(2.0 * demi / RES))
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	# matières de la carte de sol, si elle existe (lue sur le CPU, échantillon au centre du texel de carte)
	var sol: Image = null
	var mt = monde.get("mat_terrain")
	if mt is ShaderMaterial:
		var tex = (mt as ShaderMaterial).get_shader_parameter("carte_sol")
		if tex is Texture2D:
			sol = (tex as Texture2D).get_image()
			if sol != null and sol.is_compressed():
				sol.decompress()
	# densité d'arbres (sous-bois sombre)
	var dens := PackedFloat32Array()
	dens.resize(N * N)
	for t in monde.get("arbres") if monde.get("arbres") is Array else []:
		var o: Vector3 = (t as Transform3D).origin
		var ci := int((o.x + demi) / RES)
		var cj := int((o.z + demi) / RES)
		for dj in range(-3, 4):
			for di in range(-3, 4):
				var ii := ci + di
				var jj := cj + dj
				if ii < 0 or jj < 0 or ii >= N or jj >= N:
					continue
				var d2 := float(di * di + dj * dj)
				if d2 <= 9.0:
					dens[jj * N + ii] += 1.0 - d2 / 10.0
	# chemins : masque des axes (distance < 1,1 m)
	var chem := PackedByteArray()
	chem.resize(N * N)
	for ligne: PackedVector2Array in _lignes_chemins():
		for k in ligne.size() - 1:
			_tracer(chem, N, ligne[k], ligne[k + 1], 1.1)
	var palissade := PackedVector2Array(ReliefVillage.PALISSADE)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 77
	for j in N:
		for i in N:
			var x := -demi + (i + 0.5) * RES
			var z := -demi + (j + 0.5) * RES
			var h := hauteur(x, z)
			var gi := clampi(int(round((x + demi) / pas)), 0, n - 1)
			var gj := clampi(int(round((z + demi) / pas)), 0, n - 1)
			var nrm := _normale(gi, gj)
			var c := NEIGE
			if sol != null:
				var sx := clampi(int((x - Sol.ORIGINE) / Sol.TEXEL), 0, sol.get_width() - 1)
				var sz := clampi(int((z - Sol.ORIGINE) / Sol.TEXEL), 0, sol.get_height() - 1)
				var mat := clampi(int(round(sol.get_pixel(sx, sz).r8 / 16.0)), 0, COULEURS_SOL.size() - 1)
				c = COULEURS_SOL[mat]
			elif nrm.y < Sol.PENTE_ROCHE:
				c = ROCHE
			if nrm.y < Sol.PENTE_ROCHE - 0.05:
				c = c.lerp(ROCHE, 0.6)
			var d := dens[j * N + i]
			if d > 0.3:
				c = c.lerp(SOUS_BOIS, clampf((d - 0.3) * 0.35, 0.0, 0.55))
			var dans_boite := ReliefVillage.BOITE.has_point(Vector2(x, z))   # le village et sa rivière : hors de la boîte, rien à tester
			if dans_boite and Geometry2D.is_point_in_polygon(Vector2(x, z), palissade):
				c = c.lerp(ENCEINTE, 0.35)
			for r: Rect2 in VillageBati.CHAMPS:
				if r.has_point(Vector2(x, z)):
					c = c.lerp(Color("#b7ad9c"), 0.5 if int(z - r.position.y) % 2 == 0 else 0.15)
			if chem[j * N + i] > 0:
				c = c.lerp(CHEMIN, 0.75)
			# eau
			if dans_boite and not is_nan(ReliefVillage.niveau_eau(x, z)):
				c = EAU
			elif EauVillage.sous_le_lac(x, z, h) and EauVillage.LAC_RECT.has_point(Vector2(x, z)) and h < EauVillage.LAC_NIVEAU + 0.05:
				var libre := Vector2(x, z).distance_to(EauVillage.LAC_ARRIVEE) < EauVillage.LAC_LIBRE
				c = EAU_LIBRE if libre else GLACE.lerp(Color("#c9dbe6"), rnd.randf() * 0.25)
			img.set_pixel(i, j, c)
	img.generate_mipmaps()
	carte_couleur = ImageTexture.create_from_image(img)

## Polylignes des chemins connus du monde (x, z).
func _lignes_chemins() -> Array:
	var res: Array = []
	var ch = monde.get("chemins")
	if ch is Chemins:
		var c: Chemins = ch
		for l in c.debuts.size():
			var i0 := c.debuts[l]
			var i1 := (c.debuts[l + 1] if l + 1 < c.debuts.size() else c.points.size())
			res.append(c.points.slice(i0, i1))
	res.append(Chemins.axe_village(monde))   # sentier feu → porte du village (monde._pres_du_chemin)
	var piste := PackedVector2Array()
	var x := 46.0
	while x <= GrotteAcces.SITE.x:
		piste.append(Vector2(x, GrotteAcces.axe_piste(x)))
		x += 2.0
	res.append(piste)
	return res

func _tracer(masque: PackedByteArray, N: int, a: Vector2, b: Vector2, largeur: float) -> void:
	var l := maxf(a.distance_to(b), 0.01)
	var etapes := int(ceil(l / (RES * 0.5)))
	var r := int(ceil(largeur / RES))
	for s in etapes + 1:
		var p := a.lerp(b, float(s) / etapes)
		var ci := int((p.x + demi) / RES)
		var cj := int((p.y + demi) / RES)
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				var ii := ci + di
				var jj := cj + dj
				if ii < 0 or jj < 0 or ii >= N or jj >= N:
					continue
				var cx := -demi + (ii + 0.5) * RES
				var cz := -demi + (jj + 0.5) * RES
				if Vector2(cx, cz).distance_to(p) <= largeur:
					masque[jj * N + ii] = 1

# ------------------------------------------------------------------ relief

func _materiau(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("nuages", tex_nuages)
	m.set_shader_parameter("brume_dist", Vector2(demi - 4.0, demi + HORS * 0.55))
	materiaux.append(m)
	return m

func _relief() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# aire de jeu : grille exacte du terrain
	for j in n:
		for i in n:
			st.set_normal(_normale(i, j))
			st.add_vertex(Vector3(-demi + i * pas, hs[j * n + i], -demi + j * pas))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + n)
			st.add_index(a + 1); st.add_index(a + n + 1); st.add_index(a + n)
	var m := _materiau(SHADER_TERRAIN)
	m.set_shader_parameter("carte_couleur", carte_couleur)
	m.set_shader_parameter("rect", Vector4(-demi, -demi, 1.0 / (2.0 * demi), demi))
	var mi := MeshInstance3D.new()
	mi.name = "Relief"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# pourtour (anneau à 4 m), relief de monde.hauteur()
	var ext := demi + HORS
	var k := int(round(2.0 * ext / PAS_HORS)) + 1
	var hp := PackedFloat32Array()
	hp.resize(k * k)
	for j in k:
		for i in k:
			hp[j * k + i] = monde.hauteur(-ext + i * PAS_HORS, -ext + j * PAS_HORS)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in k:
		for i in k:
			var hg := hp[j * k + maxi(i - 1, 0)]
			var hd := hp[j * k + mini(i + 1, k - 1)]
			var hh := hp[maxi(j - 1, 0) * k + i]
			var hb := hp[mini(j + 1, k - 1) * k + i]
			st2.set_normal(Vector3(hg - hd, 2.0 * PAS_HORS, hh - hb).normalized())
			st2.add_vertex(Vector3(-ext + i * PAS_HORS, hp[j * k + i], -ext + j * PAS_HORS))
	for j in k - 1:
		for i in k - 1:
			var x0 := -ext + i * PAS_HORS
			var z0 := -ext + j * PAS_HORS
			if x0 >= -demi - 0.01 and x0 + PAS_HORS <= demi + 0.01 and z0 >= -demi - 0.01 and z0 + PAS_HORS <= demi + 0.01:
				continue
			var a := j * k + i
			st2.add_index(a); st2.add_index(a + 1); st2.add_index(a + k)
			st2.add_index(a + 1); st2.add_index(a + k + 1); st2.add_index(a + k)
	var mi2 := MeshInstance3D.new()
	mi2.name = "Pourtour"
	mi2.mesh = st2.commit()
	mi2.material_override = m
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi2)

# ------------------------------------------------------------------ sapins

## Épicéa à deux étages (6 pans), neige sur les pointes. Hauteur 1, rayon de base 0,36 (mis à l'échelle par instance).
static func _maillage_sapin() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var etages := [[0.18, 0.62, 0.36], [0.5, 1.0, 0.25]]   # [bas, haut, rayon]
	for e: Array in etages:
		var y0: float = e[0]
		var y1: float = e[1]
		var r: float = e[2]
		for s in 6:
			var a0 := TAU * s / 6.0
			var a1 := TAU * (s + 1) / 6.0
			var p0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, y0, sin(a1) * r)
			var top := Vector3(0, y1, 0)
			var nrm := (p1 - p0).cross(top - p0).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			st.set_normal(nrm)
			var pan := SAPIN if s % 2 == 0 else SAPIN.lightened(0.08)   # pans alternés : facettes lisibles
			st.set_color(pan.lerp(Color("#dfe7ea"), 0.35))   # neige sur le bord des branches
			st.add_vertex(p0)
			st.set_color(SAPIN_NEIGE)
			st.add_vertex(top)
			st.set_color(pan)
			st.add_vertex(p1)
	# tronc (petit prisme sombre)
	for s in 4:
		var a0 := TAU * s / 4.0
		var a1 := TAU * (s + 1) / 4.0
		var q0 := Vector3(cos(a0) * 0.04, 0.0, sin(a0) * 0.04)
		var q1 := Vector3(cos(a1) * 0.04, 0.0, sin(a1) * 0.04)
		st.set_normal(((q0 + q1) * 0.5).normalized())
		st.set_color(BOIS)
		st.add_vertex(q0)
		st.add_vertex(q0 + Vector3(0, 0.2, 0))
		st.add_vertex(q1)
		st.add_vertex(q1)
		st.add_vertex(q0 + Vector3(0, 0.2, 0))
		st.add_vertex(q1 + Vector3(0, 0.2, 0))
	return st.commit()

func _sapins() -> void:
	var liste: Array = []
	for t in monde.get("arbres") if monde.get("arbres") is Array else []:
		var tr := t as Transform3D
		if absf(tr.origin.x) <= demi and absf(tr.origin.z) <= demi:
			liste.append(tr)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 2026
	var bruit := FastNoiseLite.new()
	bruit.seed = 5
	bruit.frequency = 0.03
	var ext := demi + HORS
	var essais := 0
	var hors := 0
	while hors < SAPINS_HORS and essais < SAPINS_HORS * 8:
		essais += 1
		var x := rnd.randf_range(-ext, ext)
		var z := rnd.randf_range(-ext, ext)
		if absf(x) < demi + 2.0 and absf(z) < demi + 2.0:
			continue
		if bruit.get_noise_2d(x, z) < 0.05:
			continue
		var h: float = monde.hauteur(x, z)
		var hx: float = monde.hauteur(x + 2.0, z) - h
		var hz: float = monde.hauteur(x, z + 2.0) - h
		if absf(hx) > 1.4 or absf(hz) > 1.4:
			continue
		liste.append(Transform3D(Basis().scaled(Vector3.ONE * rnd.randf_range(0.8, 1.3)), Vector3(x, h, z)))
		hors += 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _maillage_sapin()
	mm.instance_count = liste.size()
	for i in liste.size():
		var tr: Transform3D = liste[i]
		var ech := tr.basis.get_scale().y
		var haut := clampf(ech, 0.5, 2.0) * 8.5   # ~8,5 m pour un épicéa d'échelle 1 (lisible : clairières et chemins restent visibles)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(haut * 0.85, haut, haut * 0.85)), tr.origin - Vector3(0, 0.3, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sapins"
	mmi.multimesh = mm
	mmi.material_override = _materiau(SHADER_OBJET)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	nb_sapins = liste.size()

# ------------------------------------------------------------------ bâtiments, palissade, repères

## Boîte orientée (couleur unie) + toit à deux pans enneigé (si `toit` > 0).
static func _maison(st: SurfaceTool, tr: Transform3D, demi_: Vector2, haut: float, toit: float, mur: Color) -> void:
	var dx := demi_.x
	var dz := demi_.y
	var c := [Vector3(-dx, 0, -dz), Vector3(dx, 0, -dz), Vector3(dx, 0, dz), Vector3(-dx, 0, dz)]
	for s in 4:
		var a: Vector3 = c[s]
		var b: Vector3 = c[(s + 1) % 4]
		_quad(st, tr, a, b, b + Vector3(0, haut, 0), a + Vector3(0, haut, 0), mur)
	if toit <= 0.0:
		_quad(st, tr, c[3] + Vector3(0, haut, 0), c[2] + Vector3(0, haut, 0), c[1] + Vector3(0, haut, 0), c[0] + Vector3(0, haut, 0), mur.lightened(0.15))
		return
	# faîtage le long du grand côté
	var long_x := dx >= dz
	var y := haut
	var yt := haut + toit
	var deb := 0.4   # débord
	if long_x:
		var r0 := Vector3(-dx - deb, yt, 0)
		var r1 := Vector3(dx + deb, yt, 0)
		_quad(st, tr, Vector3(-dx - deb, y - 0.3, dz + deb), Vector3(dx + deb, y - 0.3, dz + deb), r1, r0, TOIT)
		_quad(st, tr, Vector3(dx + deb, y - 0.3, -dz - deb), Vector3(-dx - deb, y - 0.3, -dz - deb), r0, r1, TOIT.darkened(0.1))
		_tri(st, tr, Vector3(-dx, y, dz), Vector3(-dx, yt, 0), Vector3(-dx, y, -dz), mur)
		_tri(st, tr, Vector3(dx, y, -dz), Vector3(dx, yt, 0), Vector3(dx, y, dz), mur)
	else:
		var r0 := Vector3(0, yt, -dz - deb)
		var r1 := Vector3(0, yt, dz + deb)
		_quad(st, tr, Vector3(dx + deb, y - 0.3, -dz - deb), Vector3(dx + deb, y - 0.3, dz + deb), r1, r0, TOIT)
		_quad(st, tr, Vector3(-dx - deb, y - 0.3, dz + deb), Vector3(-dx - deb, y - 0.3, -dz - deb), r0, r1, TOIT.darkened(0.1))
		_tri(st, tr, Vector3(-dx, y, -dz), Vector3(0, yt, -dz), Vector3(dx, y, -dz), mur)
		_tri(st, tr, Vector3(dx, y, dz), Vector3(0, yt, dz), Vector3(-dx, y, dz), mur)

static func _quad(st: SurfaceTool, tr: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, tr, a, b, c, col)
	_tri(st, tr, a, c, d, col)

static func _tri(st: SurfaceTool, tr: Transform3D, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var pa := tr * a
	var pb := tr * b
	var pc := tr * c
	var nrm := (pc - pa).cross(pb - pa).normalized()
	# normale tournée vers l'extérieur (vers le haut pour les toits, hors du volume pour les murs) : l'ordre des sommets
	# varie d'une face à l'autre et le matériau n'élimine aucune face
	var dehors := (pa + pb + pc) / 3.0 - tr.origin
	dehors.y = 0.0
	if nrm.y < -0.05 or (absf(nrm.y) < 0.5 and nrm.dot(dehors) < 0.0):
		nrm = -nrm
	st.set_color(col)
	st.set_normal(nrm)
	st.add_vertex(pa)
	st.add_vertex(pc)
	st.add_vertex(pb)

func _batiments() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var village: Node = monde.get("village")
	if village != null and village.get("emprises") is Array:
		for e: Array in village.emprises:
			var p := e[0] as Node3D
			if p == null or not is_instance_valid(p) or not p.is_inside_tree():
				continue
			var dm: Vector2 = e[1]
			var dec: Vector2 = e[2]
			var g := p.global_transform
			var bas := Basis(Vector3.UP, g.basis.get_euler().y)
			var centre := g * Vector3(dec.x, 0, dec.y)
			var tr := Transform3D(bas, Vector3(centre.x, minf(centre.y, hauteur(centre.x, centre.z)) - 0.2, centre.z))
			var dmi := Vector2(maxf(dm.x - 0.5, 1.0), maxf(dm.y - 0.5, 1.0))
			_maison(st, tr, dmi, 3.4, minf(dmi.x, dmi.y) * 1.25, BOIS)
			nb_batiments += 1
	# palissade : planches sombres le long du tracé (2,6 m)
	var P := PackedVector2Array(ReliefVillage.PALISSADE)
	for k in P.size() - 1:
		var a := P[k]
		var b := P[k + 1]
		var l := a.distance_to(b)
		var m := (a + b) * 0.5
		var ang := atan2(b.x - a.x, b.y - a.y)
		var tr := Transform3D(Basis(Vector3.UP, ang), Vector3(m.x, minf(hauteur(a.x, a.y), hauteur(b.x, b.y)) - 0.3, m.y))
		_maison(st, tr, Vector2(0.35, l * 0.5), 3.0, 0.0, Color("#4a3220"))
	# pierres du cercle (8 menhirs + stèle)
	var c := Vector2(-38.0, -34.0)
	if monde.get("CERCLE") is Vector3:
		c = Vector2(monde.CERCLE.x, monde.CERCLE.z)
	for s in 8:
		var a := TAU * s / 8.0
		var q := c + Vector2(cos(a), sin(a)) * 7.0
		_maison(st, Transform3D(Basis(Vector3.UP, -a), Vector3(q.x, hauteur(q.x, q.y) - 0.2, q.y)), Vector2(0.45, 0.3), 2.6, 0.0, PIERRE)
	_maison(st, Transform3D(Basis(), Vector3(c.x, hauteur(c.x, c.y) - 0.2, c.y)), Vector2(0.5, 0.5), 3.4, 0.0, Color("#5f6f86"))
	# pont de pierre (axe nord-sud, 9 m)
	var pont := EauVillage.PONT
	var hv: float = monde.get("h_village") if monde.get("h_village") != null else hauteur(pont.x, pont.z)
	_maison(st, Transform3D(Basis(), Vector3(pont.x, hv - 0.4, pont.z)), Vector2(1.6, 4.8), 0.7, 0.0, PIERRE)
	var mi := MeshInstance3D.new()
	mi.name = "Bati"
	mi.mesh = st.commit()
	mi.material_override = _materiau(SHADER_OBJET)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Tertre (dôme enneigé derrière la façade), foyer du feu de camp (point chaud), bouche de la grotte (arc sombre).
func _reperes() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var td := Vector2(-38.0, -54.5)
	if monde.get("TUMULUS_DISQUE") is Vector2:
		td = monde.TUMULUS_DISQUE
	var base := hauteur(td.x, td.y) - 0.5
	var anneaux := 4
	var secteurs := 12
	for r in anneaux:
		for s in secteurs:
			var a0 := TAU * s / secteurs
			var a1 := TAU * (s + 1) / secteurs
			var t0 := float(r) / anneaux
			var t1 := float(r + 1) / anneaux
			var f := func(t: float, a: float) -> Vector3:
				var rr := cos(t * PI * 0.5) * 7.5
				return Vector3(cos(a) * rr * 1.2, sin(t * PI * 0.5) * 4.0, sin(a) * rr)
			var p00: Vector3 = f.call(t0, a0)
			var p01: Vector3 = f.call(t0, a1)
			var p10: Vector3 = f.call(t1, a0)
			var p11: Vector3 = f.call(t1, a1)
			_quad(st, Transform3D(Basis(), Vector3(td.x, base, td.y)), p00, p01, p11, p10, TERRE_TERTRE)
	# façade de pierre du tertre (côté sud, vers le cercle)
	var fa := Vector2(-38.0, -48.0)
	if monde.get("TUMULUS") is Vector3:
		fa = Vector2(monde.TUMULUS.x, monde.TUMULUS.z)
	_maison(st, Transform3D(Basis(), Vector3(fa.x, hauteur(fa.x, fa.y) - 0.3, fa.y - 1.2)), Vector2(2.4, 0.7), 3.2, 0.0, Color("#5c5f66"))
	# bouche de la grotte : arc sombre tourné vers l'ouest
	var g := GrotteAcces.SITE
	_maison(st, Transform3D(Basis(), Vector3(g.x + 1.5, hauteur(g.x, g.y) - 0.5, g.y)), Vector2(1.2, 2.6), 3.6, 0.0, Color("#15161b"))
	var mi := MeshInstance3D.new()
	mi.name = "Reperes"
	mi.mesh = st.commit()
	mi.material_override = _materiau(SHADER_OBJET)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# braises du feu de camp (émissif)
	var feu := MeshInstance3D.new()
	feu.name = "Feu"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.5, 1.6)
	feu.mesh = bm
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = Color("#fcb53a")
	feu.material_override = mf
	var hc: float = monde.get("h_centre") if monde.get("h_centre") != null else hauteur(0, 0)
	feu.position = Vector3(0, hc + 0.1, 0)
	add_child(feu)

# ------------------------------------------------------------------ ambiance

func _nuages() -> void:
	var pm := PlaneMesh.new()
	var ext := demi + HORS
	pm.size = Vector2(ext * 2.2, ext * 2.2)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	var mi := MeshInstance3D.new()
	mi.name = "Nuages"
	mi.mesh = pm
	mat_nuages = ShaderMaterial.new()
	mat_nuages.shader = SHADER_NUAGES
	mat_nuages.set_shader_parameter("nuages", tex_nuages)
	mat_nuages.set_shader_parameter("bord", Vector2(demi - 4.0, demi + HORS * 0.65))
	mi.material_override = mat_nuages
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, h_max + 26.0, 0)
	add_child(mi)

func _lumiere() -> void:
	lumiere = DirectionalLight3D.new()
	lumiere.name = "Soleil"
	lumiere.light_color = Color("#fff1dc")
	lumiere.light_energy = 1.2
	lumiere.shadow_enabled = false
	add_child(lumiere)
	# lumière de l'ouest-sud-ouest, assez haute : les versants ouest et les faces tournées vers le lecteur (la caméra regarde
	# le nord) sont éclairés, les versants est restent dans l'ombre → le relief se lit sans noircir toits et façades
	lumiere.basis = Basis.looking_at(Vector3(0.9, -1.0, -0.35).normalized(), Vector3.UP)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#d0d5d8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb0c4")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
