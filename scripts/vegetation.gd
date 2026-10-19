class_name Vegetation
## Forêt (épicéas et arbres morts) et couvre-sol (genévriers). Deux étapes séparées :
## PLACEMENT (calcul des transforms, seul consommateur du RNG `monde.rng`) puis
## INSTANCIATION (MultiMesh via Instanciation, colliders des troncs).
## L'ordre des tirages est figé : positions, puis formes/échelles/rotations, puis couvre-sol.

const NB_SAPINS := 1500
const NB_BUISSONS := 900

## Place toute la végétation, puis l'instancie. Renvoie les transforms des arbres.
static func creer(monde: Node) -> Array:
	var foret := placer_foret(monde)
	var buissons := placer_couvre_sol(monde)
	return instancier(monde, foret, buissons)

## Positions puis formes : {"lots": [4 listes de Transform3D par forme]}.
## Formes : 0-2 épicéas, 3 arbre mort.
static func placer_foret(monde: Node) -> Dictionary:
	var rng: RandomNumberGenerator = monde.rng
	var cercle: Vector3 = monde.CERCLE
	var village: Vector3 = monde.VILLAGE
	var tumulus: Vector3 = monde.TUMULUS
	var clairiere: float = monde.RAYON_CLAIRIERE
	var positions: Array[Vector3] = []
	var grille := {}
	var essais := 0
	while positions.size() < NB_SAPINS and essais < NB_SAPINS * 20:
		essais += 1
		var x := rng.randf_range(-116.0, 116.0)
		var z := rng.randf_range(-116.0, 116.0)
		var d := Vector2(x, z).length()
		if d < clairiere + 2.5 or Vector2(x - cercle.x, z - cercle.z).length() < 11.0 or Vector2(x - village.x, z - village.z).length() < 31.0 or monde._pres_du_chemin(x, z, 3.0) or Vector2(x - tumulus.x, z - (tumulus.z - 6.0)).length() < 11.0:
			continue
		# la forêt s'épaissit et s'éclaircit par plaques
		var densite: float = monde.bruit_densite.get_noise_2d(x, z) * 0.5 + 0.6 + smoothstep(14.0, 30.0, d) * 0.2
		if rng.randf() > densite:
			continue
		var cle := Vector2i(floori(x / 3.0), floori(z / 3.0))
		if grille.has(cle):
			continue
		grille[cle] = true
		positions.append(Vector3(x, monde.hauteur(x, z) - 0.15, z))

	var lots: Array = [[], [], [], []]
	for p in positions:
		var tirage := rng.randf()
		var forme := 0 if tirage < 0.5 else (1 if tirage < 0.8 else (2 if tirage < 0.95 else 3))
		var s := rng.randf_range(0.75, 1.3)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		b = Basis(Vector3(1, 0, 0), rng.randf_range(-0.04, 0.04)) * b
		b = b.scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		lots[forme].append(Transform3D(b, p))
	return {"lots": lots}

## Genévriers bas et branches mortes à moitié enfouies : le sol n'est plus nu.
## Renvoie la liste des Transform3D.
static func placer_couvre_sol(monde: Node) -> Array[Transform3D]:
	var rng: RandomNumberGenerator = monde.rng
	var cercle: Vector3 = monde.CERCLE
	var village: Vector3 = monde.VILLAGE
	var clairiere: float = monde.RAYON_CLAIRIERE
	var xfs: Array[Transform3D] = []
	var essais := 0
	while xfs.size() < NB_BUISSONS and essais < 20000:
		essais += 1
		var x := rng.randf_range(-112.0, 112.0)
		var z := rng.randf_range(-112.0, 112.0)
		if Vector2(x, z).length() < clairiere + 1.0 or Vector2(x - village.x, z - village.z).length() < 26.0 or monde._pres_du_chemin(x, z, 1.8) or Vector2(x - cercle.x, z - cercle.z).length() < 8.0:
			continue
		# plus dense là où la forêt l'est
		if rng.randf() > monde.bruit_densite.get_noise_2d(x, z) * 0.6 + 0.45:
			continue
		var s := rng.randf_range(0.6, 1.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.0), s))
		xfs.append(Transform3D(b, Vector3(x, monde.hauteur(x, z) - 0.25, z)))
	return xfs

## Crée matériaux, MultiMesh et colliders. Renvoie les transforms de tous les arbres.
static func instancier(monde: Node, foret: Dictionary, buissons: Array) -> Array:
	var mats := [
		Palette.materiau(monde.tex_ecorce, Vector2(1, 1)),
		Palette.materiau(Arbres.texture_aiguilles(3), Vector2(1, 1), Color(1.25, 1.3, 1.25)),
		Palette.materiau(Arbres.texture_neige_branches(9), Vector2(1, 1)),
	]
	var mats_mort := [Palette.materiau(monde.tex_roche, Vector2(1, 2), Color(0.95, 0.92, 0.88)), null, mats[2]]
	# trois formes d'épicéa et des arbres morts, chacun dans son MultiMesh
	var modeles: Array[Mesh] = [Arbres.epicea(0, 11, mats), Arbres.epicea(1, 12, mats), Arbres.epicea(2, 13, mats), Arbres.arbre_mort(14, mats_mort)]
	var lots: Array = foret["lots"]
	var corps := StaticBody3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = 0.35
	cylindre.height = 4.0
	var arbres: Array = []
	for i in 4:
		for t: Transform3D in lots[i]:
			arbres.append(t)
			var forme_col := CollisionShape3D.new()
			if ZoneBiome.masque(t.origin.x, t.origin.z) > 0.0:
				# dans la zone : tronc ∝ échelle (rayon min 0,15 ; hauteur 4 × échelle)
				var sc := t.basis.get_scale()
				var cyl_zone := CylinderShape3D.new()
				cyl_zone.radius = maxf(0.15, 0.35 * sc.x)
				cyl_zone.height = 4.0 * sc.y
				forme_col.shape = cyl_zone
				forme_col.position = t.origin + Vector3(0, 2.0 * sc.y, 0)
			else:
				forme_col.shape = cylindre
				forme_col.position = t.origin + Vector3(0, 2, 0)
			corps.add_child(forme_col)
		Instanciation.repartir(monde, modeles[i], lots[i])
	monde.add_child(corps)
	Instanciation.repartir(monde, Arbres.buisson(21, mats), buissons, {"ombre": false})
	return arbres
