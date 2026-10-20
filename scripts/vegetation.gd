class_name Vegetation
## Forêt (épicéas et arbres morts) et couvre-sol (genévriers). Deux étapes séparées :
## PLACEMENT (calcul des transforms, seul consommateur du RNG `monde.rng`) puis
## INSTANCIATION (MultiMesh via Instanciation, colliders des troncs).
## L'ordre des tirages est figé : positions, puis formes/échelles/rotations, puis couvre-sol.

## Lot 7 : portées réglées sur le brouillard (cycle.gd, FIN_MAX = 75 m : tout est invisible au-delà).
const PORTEE_PLEINE := 48.0   # mesh complet et ombres : le brouillard y est déjà à 60-80 %
const PORTEE_LOD := 80.0      # silhouettes d'horizon, juste au-delà de la fin maximale du brouillard
const NB_SAPINS := 1500
const NB_BUISSONS := 900

## Place toute la végétation, puis l'instancie. Renvoie les transforms des arbres.
static func creer(monde: Node) -> Array:
	var foret := placer_foret(monde)
	var buissons := placer_couvre_sol(monde)
	_degager_grotte(foret, buissons)
	return instancier(monde, foret, buissons)

## Dégage l'entrée de la grotte (disque, masse rocheuse, piste) APRÈS le placement : le RNG et la forêt d'ailleurs ne changent pas.
static func _degager_grotte(foret: Dictionary, buissons: Array[Transform3D]) -> void:
	for lot: Array in foret["lots"]:
		for i in range(lot.size() - 1, -1, -1):
			var o: Vector3 = (lot[i] as Transform3D).origin
			if GrotteAcces.exclu(o.x, o.z):
				lot.remove_at(i)
	for i in range(buissons.size() - 1, -1, -1):
		var o: Vector3 = buissons[i].origin
		if GrotteAcces.exclu(o.x, o.z):
			buissons.remove_at(i)

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
	if ZoneBiome.actif:
		lots = _remanier_zone(monde, lots)
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
	# trois formes d'épicéa et des arbres morts, chacun dans son MultiMesh
	# lot 2 : épicéas en cartes de rameaux pixel art (tronc + rameaux, matériaux partagés)
	var t0 := Time.get_ticks_usec()
	var mats_ep := Arbres.materiaux_epicea()
	var mort := Arbres.arbre_mort(14)
	var pin := Arbres.pin(31, Arbres.materiaux_essence("pin"))
	var bouleau := Arbres.bouleau(41, Arbres.materiaux_essence("bouleau"))
	# formes : 0-2 épicéas, 3 arbre mort, 4 pin sylvestre, 5 bouleau (4 et 5 : zone témoin seulement)
	var modeles: Array[Mesh] = [Arbres.epicea(0, 11, mats_ep), Arbres.epicea(1, 12, mats_ep), Arbres.epicea(2, 13, mats_ep), mort, pin, bouleau]
	# silhouettes simplifiées pour la vue lointaine (au-delà de la portée du mesh complet)
	var lointains: Array[Mesh] = [Arbres.epicea_lointain(0, 11, mats_ep), Arbres.epicea_lointain(1, 12, mats_ep), Arbres.epicea_lointain(2, 13, mats_ep), Arbres.arbre_mort(14, [], true), Arbres.pin(31, Arbres.materiaux_essence("pin"), true), Arbres.bouleau(41, Arbres.materiaux_essence("bouleau"), true)]
	# lot 2 : silhouettes d'ombre opaques des épicéas (les cartes en alpha coûtent cher en passe d'ombre)
	var ombres: Array[Mesh] = [Arbres.epicea_ombre(0, 11, mats_ep[0]), Arbres.epicea_ombre(1, 12, mats_ep[0]), Arbres.epicea_ombre(2, 13, mats_ep[0]), mort, pin, bouleau]
	var variantes: Array[Mesh] = [Arbres.epicea(0, 111, mats_ep), Arbres.epicea(1, 112, mats_ep)]
	print("Lot 2 : textures et modèles d'arbres en %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
	var lots: Array = foret["lots"]
	var corps := StaticBody3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = 0.35
	cylindre.height = 4.0
	var arbres: Array = []
	for i in lots.size():
		if lots[i].is_empty():
			continue
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
		# lot 7 : mesh complet jusqu'à PORTEE_PLEINE (le brouillard est alors à 60-80 % : détail inutile), silhouette
		# simplifiée jusqu'à PORTEE_LOD (> fin maximale du brouillard) : l'arbre sort de la brume sans « pop »
		var reglages := {"portee": PORTEE_PLEINE, "marge": 4.0, "ombre_proche": PORTEE_PLEINE, "lod_mesh": lointains[i], "ombre_mesh": ombres[i],
			"lod_debut": PORTEE_PLEINE - 4.0, "lod_portee": PORTEE_LOD}
		if i <= 1:
			# lot 2 : deux graines pour les épicéas courants (formes 0 et 1), choisies par hachage de
			# position (aucun tirage RNG) : deux arbres voisins n'ont pas les mêmes branches
			var lot_a: Array = []
			var lot_b: Array = []
			for t: Transform3D in lots[i]:
				(lot_b if ZoneBiome.alea_pos(t.origin.x, t.origin.z, 11) < 0.5 else lot_a).append(t)
			# ombre et LOD communs aux deux graines (un MMI de chaque par cellule), affichage proche par graine
			var commun := reglages.duplicate()
			commun["principal"] = false
			Instanciation.repartir(monde, modeles[i], lots[i], commun)
			Instanciation.repartir(monde, modeles[i], lot_a, {"portee": PORTEE_PLEINE, "marge": 4.0, "ombre": false})
			Instanciation.repartir(monde, variantes[i], lot_b, {"portee": PORTEE_PLEINE, "marge": 4.0, "ombre": false})
		else:
			Instanciation.repartir(monde, modeles[i], lots[i], reglages)
	monde.add_child(corps)
	Instanciation.repartir(monde, Arbres.buisson(21, mats), buissons, {"ombre": false, "portee": PORTEE_PLEINE, "marge": 4.0})
	return arbres

# --- Lot E : forêt écologique de la zone témoin ------------------------------------------------
## La forêt ancienne est générée à l'identique (tirages sur `monde.rng`), puis dans la zone :
## 1. les arbres anciens sont retirés après coup si `alea_pos(x,z,1) < masque` (fondu tramé) ;
## 2. de NOUVEAUX arbres sont tirés (RNG propre `ZoneBiome.graine("foret_zone")`, jamais `monde.rng`)
##    par amas et vraies clairières, jusqu'à retrouver le nombre d'arbres d'avant dans la zone.
## `monde.arbres_zone` (meta) : Array de Dictionary {"pos": Vector3 (pied), "s": float (échelle),
## "forme": int (0-2 épicéa, 3 mort), "nouveau": bool, "lisiere": bool} pour tous les arbres de la zone.

const AMAS_FREQ := 0.045          # fréquence du champ d'amas (2 octaves)
const AMAS_AMPLITUDE := 0.95      # D = 0.5 + amplitude × bruit
const D_CLAIRIERE := 0.15         # en dessous : vraie clairière, aucun arbre
const D_LISIERE_MAX := 0.35       # D ∈ [0,15 ; 0,35] : lisière
const DIST_MIN_LARGE := 4.0       # distance minimale entre arbres quand D = 0
const DIST_MIN_SERRE := 2.2       # idem quand D = 1
const R_FEU := 11.5               # exclusion autour du feu (0, 0)
const CERCLE_RAYON := 12.0        # cercle irrégulier 12 ± 3 (borné 10-15)
const CERCLE_VARIATION := 3.0
const ELLIPSE_CENTRE := Vector2(-38.0, -54.5)  # tumulus
const ELLIPSE_RAYONS := Vector2(10.0, 12.0)
const MARGE_CHEMIN_ARBRE := 2.5
const ESSAIS_ZONE := 20000        # plafond d'essais (on s'arrête dès que la cible est atteinte)
const JEUNES_MIN := 25
const JEUNES_MAX := 35
const PIN_BUTTE := 0.3            # lot 2 : h − h_moy_r12 au-dessus duquel un arbre peut être un pin
const PIN_PART := 0.75            # part de pins sur ces buttes (hachage de position)
const BOULEAU_CREUX := -0.4       # h − h_moy_r12 en dessous duquel un arbre peut être un bouleau
const BOULEAU_PART := 0.4

static func nouveau_bruit_amas() -> FastNoiseLite:
	var b := FastNoiseLite.new()
	b.seed = ZoneBiome.graine("foret_zone")
	b.frequency = AMAS_FREQ
	b.fractal_octaves = 2
	return b

static func densite_amas(bruit: FastNoiseLite, x: float, z: float) -> float:
	return 0.5 + AMAS_AMPLITUDE * bruit.get_noise_2d(x, z)

## Rayon du cercle d'exclusion irrégulier autour des pierres, dans la direction `angle` (10-15 m).
static func rayon_cercle(angle: float) -> float:
	var b := 0.55 * sin(2.0 * angle + 0.7) + 0.3 * sin(3.0 * angle + 2.1) + 0.15 * sin(7.0 * angle)
	return clampf(CERCLE_RAYON + CERCLE_VARIATION * b, 10.0, 15.0)

## Exclusions de décor : feu, cercle irrégulier, ellipse du tumulus, disques de composition.
static func exclu_decor(x: float, z: float) -> bool:
	if x * x + z * z < R_FEU * R_FEU:
		return true
	var c := Vector2(x + 38.0, z + 34.0)
	if c.length() < rayon_cercle(atan2(c.y, c.x)):
		return true
	var e := Vector2((x - ELLIPSE_CENTRE.x) / ELLIPSE_RAYONS.x, (z - ELLIPSE_CENTRE.y) / ELLIPSE_RAYONS.y)
	if e.length_squared() < 1.0:
		return true
	for o in ZoneBiome.OCCUPATIONS:
		if Vector2(x, z).distance_to(o[0]) < o[1]:
			return true
	return false

## Bord de clairière « de décor » : une exclusion (feu, cercle, tumulus) à moins de 3,5 m.
static func bord_de_decor(x: float, z: float) -> bool:
	for k in 8:
		var a := TAU * k / 8.0
		if exclu_decor(x + cos(a) * 3.5, z + sin(a) * 3.5):
			return true
	return false

## Distance aux ruines (cercle de pierres ou tumulus).
static func distance_ruines(x: float, z: float) -> float:
	return minf(Vector2(x + 38.0, z + 34.0).length(), Vector2(x, z).distance_to(ELLIPSE_CENTRE))

## Hauteur moyenne sur un anneau de rayon 12 m (pour juger hauteur/creux).
static func hauteur_moyenne_r12(monde: Node, x: float, z: float) -> float:
	var somme := 0.0
	for k in 8:
		var a := TAU * k / 8.0
		somme += monde.hauteur(x + cos(a) * 12.0, z + sin(a) * 12.0)
	return somme / 8.0

## Ancrage sur pente : le plus bas de 4 points à r = 0,35 × s, moins 0,12 m.
static func ancrage(monde: Node, x: float, z: float, s: float) -> float:
	var r := 0.35 * s
	return minf(minf(monde.hauteur(x - r, z), monde.hauteur(x + r, z)), minf(monde.hauteur(x, z - r), monde.hauteur(x, z + r))) - 0.12

## Pente locale (norme du gradient, sans unité).
static func pente(monde: Node, x: float, z: float) -> float:
	var gx: float = (monde.hauteur(x + 1.0, z) - monde.hauteur(x - 1.0, z)) * 0.5
	var gz: float = (monde.hauteur(x, z + 1.0) - monde.hauteur(x, z - 1.0)) * 0.5
	return Vector2(gx, gz).length()

static func _cle(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / 2.0), floori(z / 2.0))

static func _voisin_trop_proche(grille: Dictionary, x: float, z: float, dmin: float) -> bool:
	var c := _cle(x, z)
	var n := ceili(dmin / 2.0)
	for i in range(c.x - n, c.x + n + 1):
		for j in range(c.y - n, c.y + n + 1):
			for q: Vector2 in grille.get(Vector2i(i, j), []):
				if q.distance_to(Vector2(x, z)) < dmin:
					return true
	return false

static func _ajouter_grille(grille: Dictionary, x: float, z: float) -> void:
	var c := _cle(x, z)
	if not grille.has(c):
		grille[c] = []
	grille[c].append(Vector2(x, z))

## Transform d'un arbre posé en (x, z) : inclinaison sur axe aléatoire (plus forte sur pente), ancrage sur pente.
static func _transform_arbre(monde: Node, rng: RandomNumberGenerator, x: float, z: float, s: float, sy: float) -> Transform3D:
	var a := rng.randf() * TAU
	var inclinaison := rng.randf_range(0.0, 0.06) + 0.12 * clampf(pente(monde, x, z), 0.0, 0.6)
	var b := Basis(Vector3(cos(a), 0.0, sin(a)), inclinaison) * Basis(Vector3.UP, rng.randf() * TAU)
	b = b.scaled(Vector3(s, s * sy, s))
	return Transform3D(b, Vector3(x, ancrage(monde, x, z, s), z))

static func _remanier_zone(monde: Node, lots: Array) -> Array:
	var chemins = monde.chemins
	var nv: Array = [[], [], [], [], [], []]
	var infos: Array = []
	var grille := {}
	var avant := 0
	var gardes := 0
	for f in 4:
		for t: Transform3D in lots[f]:
			var o := t.origin
			var m := ZoneBiome.masque(o.x, o.z)
			if m > 0.0:
				avant += 1
				if ZoneBiome.alea_pos(o.x, o.z, 1) < m or exclu_decor(o.x, o.z) or chemins.distance(o.x, o.z) < MARGE_CHEMIN_ARBRE:
					continue
				# arbre ancien conservé dans la bande de fondu : reposé sur la pente (position seulement)
				var sc := t.basis.get_scale()
				var t2 := t
				t2.origin.y = ancrage(monde, o.x, o.z, sc.x)
				nv[f].append(t2)
				_ajouter_grille(grille, o.x, o.z)
				infos.append({"pos": t2.origin, "s": sc.x, "forme": f, "nouveau": false, "lisiere": false})
				gardes += 1
			else:
				nv[f].append(t)
	# nouveaux arbres
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine("foret_zone")
	var bruit := nouveau_bruit_amas()
	var cible := avant - gardes
	var crees: Array[Dictionary] = []
	var essais := 0
	while crees.size() < cible and essais < ESSAIS_ZONE:
		essais += 1
		var x := rng.randf_range(ZoneBiome.X0, ZoneBiome.X1)
		var z := rng.randf_range(ZoneBiome.Z0, ZoneBiome.Z1)
		var mk := ZoneBiome.masque(x, z)
		var D := densite_amas(bruit, x, z)
		var tirage := rng.randf()  # tiré toujours : le flux du RNG ne dépend pas des refus
		if mk <= 0.0 or D < D_CLAIRIERE or tirage >= D * mk:
			continue
		if exclu_decor(x, z) or monde._pres_du_chemin(x, z, 3.0):
			continue
		var dc: float = chemins.distance(x, z)
		if dc < MARGE_CHEMIN_ARBRE or chemins.dans_cone_vue(x, z):
			continue
		if _voisin_trop_proche(grille, x, z, lerpf(DIST_MIN_LARGE, DIST_MIN_SERRE, clampf(D, 0.0, 1.0))):
			continue
		_ajouter_grille(grille, x, z)
		var lisiere := (D >= D_CLAIRIERE and D <= D_LISIERE_MAX) or (dc >= MARGE_CHEMIN_ARBRE and dc <= 5.0) or bord_de_decor(x, z)
		crees.append({"x": x, "z": z, "D": D, "lisiere": lisiere, "r": rng.randf(), "r2": rng.randf()})
	# choix des jeunes arbres : lisières d'abord, entre JEUNES_MIN et JEUNES_MAX
	var lis: Array[int] = []
	for i in crees.size():
		if crees[i]["lisiere"]:
			lis.append(i)
	var jeunes := {}
	for i in lis:
		if jeunes.size() < JEUNES_MAX and crees[i]["r"] < 0.6:
			jeunes[i] = true
	var k := 0
	while jeunes.size() < JEUNES_MIN and k < lis.size():
		jeunes[lis[k]] = true
		k += 1
	for i in crees.size():
		var c := crees[i]
		var x: float = c["x"]
		var z: float = c["z"]
		var h: float = monde.hauteur(x, z)
		var hm: float = hauteur_moyenne_r12(monde, x, z)
		var forme := 0
		var s := 1.0
		var sy := 1.0
		if jeunes.has(i):
			forme = 2
			s = rng.randf_range(0.35, 0.6)
			sy = rng.randf_range(0.9, 1.2)
		else:
			var pm := 0.04 + 0.25 * smoothstep(1.0, 3.0, h - hm) + 0.30 * (1.0 - smoothstep(10.0, 22.0, distance_ruines(x, z)))
			if c["r2"] < pm:
				forme = 3
			elif h - hm < -0.7:
				forme = 1
			else:
				forme = 0 if rng.randf() < 0.5 else 1
			s = rng.randf_range(0.75, 1.3)
			sy = rng.randf_range(0.9, 1.2)
			# lot 2 : essences secondaires, choisies par hachage de position (aucun tirage RNG en plus) :
			# pin sylvestre sur les buttes sèches, bouleau dans les creux humides
			var ess := ZoneBiome.alea_pos(x, z, 7)
			if forme != 3 and h - hm > PIN_BUTTE and ess < PIN_PART:
				forme = 4
			elif forme != 3 and h - hm < BOULEAU_CREUX and ess < BOULEAU_PART:
				forme = 5
		var t := _transform_arbre(monde, rng, x, z, s, sy)
		nv[forme].append(t)
		infos.append({"pos": t.origin, "s": s, "forme": forme, "nouveau": true, "lisiere": c["lisiere"]})
	monde.set_meta("arbres_zone", infos)
	monde.set_meta("arbres_zone_avant", avant)  # nombre d'arbres anciens dans la zone (référence des tests)
	var nb_ess := [nv[4].size(), nv[5].size()]
	print("Lot 2 : %d pins, %d bouleaux dans la zone" % nb_ess)
	print("Biome lot E : zone %d arbres avant, %d anciens gardés + %d nouveaux (dont %d jeunes), %d essais" % [avant, gardes, crees.size(), jeunes.size(), essais])
	return nv
