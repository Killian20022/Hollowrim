class_name CapucheMage
## Capuche v3 des mages (persos/capuche_v3, 2026-11-02) : capuche de laine épaisse MODELÉE dans Blender sur le crâne réel
## (sources_blender/scripts/capuche_mage.py) au lieu de l'ancienne cagoule Quaternius gonflée « coquille d'œuf » : elle suit la forme
## de la tête (pointe molle qui tombe vers l'arrière, couture du milieu), encadre le visage d'un bord roulé épais, se resserre au cou
## et retombe en plis sur les épaules. Deux variantes : « ombre » (mage ennemi : bord avancé, visage dans l'ombre aux yeux luisants)
## et « visage » (völva / ancienne : bord reculé, le visage reçoit la lumière).
## Peau d'os calculée ici : poids de la peau de la tête la plus proche en haut, de la pèlerine la plus proche en bas, fondus sur
## la hauteur du cou puis lissés sur le maillage (le col ne se déchire pas quand la tête tourne).
##   CapucheMage.poser(sq, pieces, visage, femme) -> bool   (false : glb absent, l'appelant garde l'ancienne capuche)

const GLB := "res://assets/persos/mage/blender/capuche_mage.glb"
const GLB_FEMME := "res://assets/persos/mage/blender/capuche_mage_femme.glb"
## false : ancienne capuche (comparaisons avant / après)
static var actif := true
## maillages peau d'os déjà calculés (« femme|visage ») : même corps, mêmes os -> calcul fait une fois par variante
static var _cache := {}

static func poser(sq: Skeleton3D, pieces: Dictionary, visage: bool, femme: bool) -> bool:
	if not actif:
		return false
	var cle := "%s|%s" % [femme, visage]
	if _cache.has(cle):
		_appliquer(sq, pieces, _cache[cle], femme)
		return true
	var chemin := GLB_FEMME if femme else GLB
	if not ResourceLoader.exists(chemin):
		push_warning("CapucheMage : glb absent " + chemin)
		return false
	var ps := load(chemin) as PackedScene
	var inst := ps.instantiate()
	var src: MeshInstance3D = inst.find_child("capuche_visage" if visage else "capuche_ombre", true, false)
	if src == null:
		inst.free()
		return false
	var a := src.mesh.surface_get_arrays(0)
	var tr: Transform3D = src.global_transform if src.is_inside_tree() else src.transform
	inst.free()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	for i in v.size():
		v[i] = tr * v[i]
		nr[i] = (tr.basis * nr[i]).normalized()
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var peau: MeshInstance3D = pieces.get("peau")
	var mante: MeshInstance3D = pieces.get("mante")
	var tete := sq.get_bone_global_rest(sq.find_bone("Head")).origin
	var cou := sq.get_bone_global_rest(sq.find_bone("neck_01")).origin
	var sp := _grille(_sommets_poids(sq, peau, func(p: Vector3) -> bool: return p.y > cou.y - 0.06 and absf(p.x) < 0.16))
	var sm := _grille(_sommets_poids(sq, mante, func(p: Vector3) -> bool: return true))
	# poids bruts : tête en haut, pèlerine en bas, fondu entre le bas du crâne et la base du cou
	var poids: Array[Dictionary] = []
	poids.resize(v.size())
	var y_haut := tete.y + 0.0
	var y_bas := cou.y - 0.035
	for i in v.size():
		var p := v[i]
		var t := smoothstep(y_bas, y_haut, p.y)
		var d := {}
		if t > 0.0:
			_ajouter(d, _proche(sp, p), t)
		if t < 1.0:
			_ajouter(d, _proche(sm, p) if not sm.is_empty() else _proche(sp, p), 1.0 - t)
		poids[i] = d
	# lissage sur le maillage (voisins par arêtes, sommets confondus réunis)
	var voisins := _voisins(v, idx)
	for it in 4:
		var nouv: Array[Dictionary] = []
		nouv.resize(v.size())
		for i in v.size():
			var d := {}
			_ajouter(d, poids[i], 0.5)
			var nv: PackedInt32Array = voisins[i]
			for j in nv:
				_ajouter(d, poids[j], 0.5 / nv.size())
			nouv[i] = d
		poids = nouv
	var bones := PackedInt32Array()
	var ws := PackedFloat32Array()
	for i in v.size():
		var paires := []
		for b: int in poids[i]:
			paires.append([poids[i][b], b])
		paires.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		var somme := 0.0
		for j in mini(4, paires.size()):
			somme += paires[j][0]
		for j in 4:
			if j < paires.size():
				bones.append(paires[j][1])
				ws.append(paires[j][0] / maxf(somme, 1e-6))
			else:
				bones.append(0)
				ws.append(0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
	arr[Mesh.ARRAY_INDEX] = idx
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = ws
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache[cle] = m
	_appliquer(sq, pieces, m, femme)
	return true

static func _appliquer(sq: Skeleton3D, pieces: Dictionary, m: ArrayMesh, femme: bool) -> void:
	var mi: MeshInstance3D = pieces["capuche"]
	mi.mesh = m
	mi.skin = sq.create_skin_from_rest_transforms()
	# une seule face (la doublure modelée fait l'intérieur) : la coque de contour ne passe plus devant le capuchon
	mi.material_override = GuerrierNordique.materiau(MageTextures.tex("capuche_v3_femme" if femme else "capuche_v3"), false)
	mi.set_meta("capuche_v3", true)

static func vider() -> void:
	_cache.clear()

## Sommets (repos) et poids (os du squelette) d'une pièce, filtrés par `garder`.
static func _sommets_poids(sq: Skeleton3D, mi: MeshInstance3D, garder: Callable) -> Array:
	var res := []
	if mi == null or mi.mesh == null:
		return res
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / v.size()
	for i in v.size():
		if not garder.call(v[i]):
			continue
		var d := {}
		for j in nb:
			var wj := w[i * nb + j]
			if wj > 0.0:
				var b := GuerrierNordique._os_de_bind(mi.skin, sq, bones[i * nb + j]) if mi.skin else bones[i * nb + j]
				d[b] = float(d.get(b, 0.0)) + wj
		res.append([v[i], d])
	return res

const CASE := 0.04

## Grille de cases de 4 cm sur une liste [position, poids] (recherche du plus proche sans tout parcourir).
static func _grille(liste: Array) -> Dictionary:
	var g := {}
	for e: Array in liste:
		var c := Vector3i(((e[0] as Vector3) / CASE).floor())
		if not g.has(c):
			g[c] = []
		g[c].append(e)
	return g

static func _proche(g: Dictionary, p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	var c0 := Vector3i((p / CASE).floor())
	for r in range(0, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if maxi(absi(dx), maxi(absi(dy), absi(dz))) != r:
						continue
					var c := c0 + Vector3i(dx, dy, dz)
					if not g.has(c):
						continue
					for e: Array in g[c]:
						var dd := (e[0] as Vector3).distance_squared_to(p)
						if dd < bd:
							bd = dd
							best = e[1]
		# au-delà de l'anneau r, aucun point ne peut être plus proche que r * CASE
		if bd < (r * CASE) * (r * CASE):
			break
	return best

static func _ajouter(d: Dictionary, src: Dictionary, f: float) -> void:
	for b: int in src:
		d[b] = float(d.get(b, 0.0)) + float(src[b]) * f

static func _voisins(v: PackedVector3Array, idx: PackedInt32Array) -> Array:
	# sommets confondus (coutures d'UV) : même groupe
	var groupe := {}
	var rep := PackedInt32Array()
	rep.resize(v.size())
	for i in v.size():
		var k := v[i].snapped(Vector3.ONE * 0.0005)
		if not groupe.has(k):
			groupe[k] = i
		rep[i] = groupe[k]
	var ens := {}
	for t in range(0, idx.size(), 3):
		for k in 3:
			var a := rep[idx[t + k]]
			var b := rep[idx[t + (k + 1) % 3]]
			if not ens.has(a):
				ens[a] = {}
			if not ens.has(b):
				ens[b] = {}
			ens[a][b] = true
			ens[b][a] = true
	var res := []
	res.resize(v.size())
	for i in v.size():
		var r := rep[i]
		var l := PackedInt32Array()
		if ens.has(r):
			for j: int in ens[r]:
				l.append(j)
		res[i] = l
	return res
