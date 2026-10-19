class_name Arbres
## Arbres procéduraux, version 2 : épicéas à étages de branches en étoile, pointes qui
## tombent, dessous sombre, neige posée sur le dessus des branches ; plus des arbres morts.
## Chaque modèle est un ArrayMesh à trois surfaces (tronc, aiguilles, neige).

## Texture d'aiguilles : courts traits obliques sur fond sombre (plutôt que du bruit).
static func texture_aiguilles(graine: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := 32
	var fond := [Color("#09140f"), Color("#0d1a13")]
	var traits := [Color("#163024"), Color("#1d3b2b"), Color("#26493a"), Color("#33584a")]
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	for y in t:
		for x in t:
			img.set_pixel(x, y, fond[(x * 7 + y * 3 + rng.randi_range(0, 1)) % 2])
	for n in 150:
		var x := rng.randi_range(0, t - 1)
		var y := rng.randi_range(0, t - 1)
		var c: Color = traits[rng.randi_range(0, 3)]
		var dx := 1 if rng.randf() < 0.5 else -1
		for k in rng.randi_range(2, 4):
			img.set_pixel(posmod(x + k * dx, t), posmod(y + k, t), c)
	return ImageTexture.create_from_image(img)

## Neige sur les branches : blanc bleuté, quelques creux plus sombres.
static func texture_neige_branches(graine: int) -> ImageTexture:
	return Palette.texture(32, ["#8c9cb8", "#a9b7cf", "#c3cfe2", "#dde5f1"], 4, graine, 0.25)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca); st.set_uv(ua); st.add_vertex(a)
	st.set_color(cb); st.set_uv(ub); st.add_vertex(b)
	st.set_color(cc); st.set_uv(uc); st.add_vertex(c)

## Un étage de branches en étoile : `pointes` branches qui retombent autour du tronc.
static func _etage(feuille: SurfaceTool, neige: SurfaceTool, rng: RandomNumberGenerator, y_haut: float, rayon: float, chute: float, pointes: int, rot: float, enneige: float) -> void:
	var sommet := Vector3(0, y_haut, 0)
	var dessous := Vector3(0, y_haut - chute * 0.55, 0)
	var bouts: Array[Vector3] = []
	var creux: Array[Vector3] = []
	for k in pointes:
		var a := rot + TAU * k / pointes
		var r := rayon * rng.randf_range(0.85, 1.12)
		var tombe := chute * rng.randf_range(0.85, 1.25)
		bouts.append(Vector3(cos(a) * r, y_haut - tombe, sin(a) * r))
		var a2 := a + TAU * 0.5 / pointes
		creux.append(Vector3(cos(a2) * r * 0.52, y_haut - chute * 0.45, sin(a2) * r * 0.52))
	# couleurs de sommet plafonnées à 1 : le matériau éclaircit l'ensemble (teinte)
	var clair := Color(1.0, 1.0, 0.95)
	var moyen := Color(0.72, 0.72, 0.72)
	var sombre := Color(0.27, 0.29, 0.33)
	for k in pointes:
		var b0 := bouts[k]
		var c0 := creux[k]
		var b1 := bouts[(k + 1) % pointes]
		var u := float(k) / pointes * 3.0
		# dessus : le sommet est plus sombre (au cœur de l'arbre), les pointes plus claires
		_tri(feuille, sommet, c0, b0, Vector2(u, 0), Vector2(u + 0.5, 0.6), Vector2(u, 1), moyen, moyen, clair)
		_tri(feuille, sommet, b1, c0, Vector2(u, 0), Vector2(u + 1, 1), Vector2(u + 0.5, 0.6), moyen, clair, moyen)
		# dessous, dans l'ombre
		_tri(feuille, dessous, b0, c0, Vector2(u, 0), Vector2(u, 1), Vector2(u + 0.5, 0.6), sombre, moyen, sombre)
		_tri(feuille, dessous, c0, b1, Vector2(u, 0), Vector2(u + 0.5, 0.6), Vector2(u + 1, 1), sombre, sombre, moyen)
		# neige posée sur le dessus, sans atteindre les pointes (qui restent vertes)
		if rng.randf() < enneige:
			var f := rng.randf_range(0.62, 0.9)
			var hausse := Vector3(0, 0.1, 0)
			var nb0 := sommet.lerp(b0, f) + hausse
			var nb1 := sommet.lerp(b1, f * rng.randf_range(0.85, 1.0)) + hausse
			var nc := sommet.lerp(c0, f * 1.05) + hausse
			var blanc := Color.WHITE
			_tri(neige, sommet + hausse * 1.5, nc, nb0, Vector2(u, 0), Vector2(u + 0.5, 0.6), Vector2(u, 1), blanc, blanc, blanc)
			_tri(neige, sommet + hausse * 1.5, nb1, nc, Vector2(u, 0), Vector2(u + 1, 1), Vector2(u + 0.5, 0.6), blanc, blanc, blanc)

static func _tronc(st: SurfaceTool, rayon: float, hauteur: float, cotes := 6) -> void:
	for k in cotes:
		var a0 := TAU * k / cotes
		var a1 := TAU * (k + 1) / cotes
		# évasement au pied
		var p0 := Vector3(cos(a0) * rayon * 1.6, -0.5, sin(a0) * rayon * 1.6)
		var p1 := Vector3(cos(a1) * rayon * 1.6, -0.5, sin(a1) * rayon * 1.6)
		var m0 := Vector3(cos(a0) * rayon, 0.4, sin(a0) * rayon)
		var m1 := Vector3(cos(a1) * rayon, 0.4, sin(a1) * rayon)
		var h0 := Vector3(cos(a0) * rayon * 0.35, hauteur, sin(a0) * rayon * 0.35)
		var h1 := Vector3(cos(a1) * rayon * 0.35, hauteur, sin(a1) * rayon * 0.35)
		var sombre := Color(0.6, 0.6, 0.6)
		var w := Color.WHITE
		_tri(st, p0, p1, m1, Vector2(k, 4), Vector2(k + 1, 4), Vector2(k + 1, 3), sombre, sombre, w)
		_tri(st, p0, m1, m0, Vector2(k, 4), Vector2(k + 1, 3), Vector2(k, 3), sombre, w, w)
		_tri(st, m0, m1, h1, Vector2(k, 3), Vector2(k + 1, 3), Vector2(k + 1, 0), w, w, w)
		_tri(st, m0, h1, h0, Vector2(k, 3), Vector2(k + 1, 0), Vector2(k, 0), w, w, w)

## Épicéa : `forme` 0 élancé, 1 large et touffu, 2 jeune et clairsemé.
static func epicea(forme: int, graine: int, materiaux: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var tronc := SurfaceTool.new()
	tronc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var feuille := SurfaceTool.new()
	feuille.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neige := SurfaceTool.new()
	neige.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hauteur: float = [9.5, 7.5, 5.0][forme]
	var base: float = [2.3, 2.9, 1.7][forme]
	var etages: int = [8, 7, 5][forme]
	var bas: float = [1.3, 0.9, 0.8][forme]
	_tronc(tronc, 0.2 if forme != 2 else 0.13, hauteur * 0.92)
	for e in etages:
		var k := float(e) / (etages - 1)
		var y := lerpf(bas + 1.1, hauteur, k)
		# les étages du bas sont larges et tombants, ceux du haut serrés et pointus
		var rayon := base * (1.0 - k * 0.82) * rng.randf_range(0.9, 1.08)
		var chute := lerpf(1.25, 0.55, k) * (hauteur / 9.0)
		var pointes := 7 + int((1.0 - k) * 5.0) + rng.randi_range(0, 1)
		_etage(feuille, neige, rng, y, rayon, chute, pointes, rng.randf() * TAU, lerpf(0.8, 1.0, k))
	# flèche au sommet
	_etage(feuille, neige, rng, hauteur + 0.7, 0.35, 0.9, 5, rng.randf() * TAU, 1.0)
	var mesh := ArrayMesh.new()
	var surfaces := [tronc, feuille, neige]
	for i in 3:
		var st: SurfaceTool = surfaces[i]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, materiaux[i])
	return mesh

## Arbre mort : tronc gris et quelques branches nues tordues, un peu de neige.
static func arbre_mort(graine: int, materiaux: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var tronc := SurfaceTool.new()
	tronc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neige := SurfaceTool.new()
	neige.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tronc(tronc, 0.18, 6.0, 5)
	for n in 9:
		var y := rng.randf_range(2.2, 5.6)
		var a := rng.randf() * TAU
		var longueur := rng.randf_range(0.8, 2.0) * (1.2 - y / 8.0)
		var d := Vector3(cos(a), rng.randf_range(0.15, 0.7), sin(a)).normalized()
		var p0 := Vector3(0, y, 0)
		var p1 := p0 + d * longueur
		var cote := d.cross(Vector3.UP).normalized() * 0.05
		var w := Color(0.85, 0.85, 0.85)
		_tri(tronc, p0 - cote, p0 + cote, p1, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0), w, w, w)
		_tri(tronc, p0 + cote, p0 - cote, p1, Vector2(1, 1), Vector2(0, 1), Vector2(0.5, 0), w, w, w)
		var haut := Vector3(0, 0.05, 0)
		var blanc := Color.WHITE
		_tri(neige, p0 - cote + haut, p0 + cote + haut, p0.lerp(p1, 0.7) + haut, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0), blanc, blanc, blanc)
	var mesh := ArrayMesh.new()
	for i in 2:
		var st: SurfaceTool = [tronc, neige][i]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, materiaux[[0, 2][i]])
	return mesh

## Petit genévrier bas, à moitié sous la neige (couvre-sol).
static func buisson(graine: int, materiaux: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var feuille := SurfaceTool.new()
	feuille.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neige := SurfaceTool.new()
	neige.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		_etage(feuille, neige, rng, 0.55 + i * 0.12, rng.randf_range(0.5, 0.8), 0.5, 7, rng.randf() * TAU, 0.8)
	var mesh := ArrayMesh.new()
	for i in 2:
		var st: SurfaceTool = [feuille, neige][i]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, materiaux[[1, 2][i]])
	return mesh

## Semis (lot E) : jeune épicéa de sous-bois, deux étages de 5 pointes (~40 triangles), sans tronc.
## Surfaces : 0 aiguilles, 1 neige.
static func semis(graine: int, materiaux: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var feuille := SurfaceTool.new()
	feuille.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neige := SurfaceTool.new()
	neige.begin(Mesh.PRIMITIVE_TRIANGLES)
	_etage(feuille, neige, rng, 0.45, 0.42, 0.4, 5, rng.randf() * TAU, 0.7)
	_etage(feuille, neige, rng, 0.85, 0.22, 0.4, 5, rng.randf() * TAU, 0.8)
	var mesh := ArrayMesh.new()
	for i in 2:
		var st: SurfaceTool = [feuille, neige][i]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, materiaux[[1, 2][i]])
	return mesh
