class_name Cassable
extends StaticBody3D
## OBJET CASSABLE du décor (lot L5) : urne ou tonneau de la crypte et de la grotte. Un coup d'arme (mains.gd : groupe « cassables »,
## frapper()) ou un sort (briser_sort(), appelé par ProjectileSort et les jets de GestionMagie) le brise.
## Fabriqué par CrypteDecor.finir() à partir des triangles que l'objet a versés dans un tampon à part (lot « cass:<id> ») : même
## matière et mêmes couleurs que le décor, mais un maillage et un solide propres (le reste du décor est fusionné par cases de 8 m).
## Casse : le maillage entier est caché, ses triangles sont répartis en ÉCLATS (secteurs × 2 hauteurs ; jamais plus de 7 nœuds, aucun
## RigidBody) qui retombent à la main ; gerbe de gros pixels (GerbePixels), son, et parfois une bourse (scripts/butin.gd) tirée par
## ButinTables.tirer_pour(<id>) (graine stable). État : ButinTables.piller(<id>) → sauvegardé (clé « butin » de monde.gd) ; un objet déjà
## pillé se brise sans bruit au premier contrôle (le monde est bâti avant le chargement de la partie), ses éclats restent au sol.
## Origine du nœud = pied de l'objet (repère de la racine du décor).

## Calque propre (bit 7) : touché par la lame (TraceLame.MASQUE) et par les sorts (rayons sur tous les calques), mais franchissable par
## le joueur et les ennemis (masque 1) : comme avant le lot L5, urnes et tonneaux du décor ne bloquent pas le passage (parcours de test_crypte).
const CALQUE := 64
const GRAVITE := 9.0
const DUREE_VOL := 0.9
const PERIODE := 0.75        ## s entre deux contrôles de l'état « pillé » (une partie chargée arrive après la construction)

var ident := ""
var genre := "urne"
var casse := false
var haut := 0.55
var rayon := 0.24
var _mis: Array[MeshInstance3D] = []
var _forme: CollisionShape3D
var _eclats: Array = []      # [{n: MeshInstance3D, v: Vector3 (global), w: Vector3, repos: Vector3 (local), q: Basis}]
var _vol := -1.0
var _veille := 0.0

## Appelé par CrypteDecor.finir() : `tampons` = [{"nom": matériau, "v", "n", "u", "c"}] relatifs à l'origine du nœud.
func monter(id: String, genre_: String, ech: float, tampons: Array, materiaux: Dictionary, boite := Vector3.ZERO) -> void:
	ident = id
	genre = genre_
	name = "Cass_" + id.replace(":", "_")
	haut = (0.95 if genre == "tonneau" else 0.55) * ech
	rayon = (0.38 if genre == "tonneau" else 0.24) * ech
	if boite != Vector3.ZERO:      # caisse : boîte exacte, et elle BLOQUE le passage tant qu'elle est intacte (remplace le solide fixe du décor)
		haut = boite.y
		rayon = maxf(boite.x, boite.z) * 0.5
	for t: Dictionary in tampons:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = t["v"]
		arr[Mesh.ARRAY_NORMAL] = t["n"]
		arr[Mesh.ARRAY_TEX_UV] = t["u"]
		arr[Mesh.ARRAY_COLOR] = t["c"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = materiaux[t["nom"]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_mis.append(mi)
	collision_layer = CALQUE | (1 if boite != Vector3.ZERO else 0)
	collision_mask = 0
	var cs := CollisionShape3D.new()
	if boite != Vector3.ZERO:
		var bs := BoxShape3D.new()
		bs.size = boite
		cs.shape = bs
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = rayon
		cyl.height = haut
		cs.shape = cyl
	cs.position = Vector3(0, haut * 0.5, 0)
	add_child(cs)
	_forme = cs
	add_to_group("cassables")
	_veille = fposmod(float(ident.hash() % 1000) / 1000.0 * PERIODE, PERIODE)

func est_casse() -> bool:
	return casse

## Coup d'arme (mains.gd, « cassable ») : cède toujours, léger ou puissant.
func frapper(_puissant: bool, origine: Vector3) -> bool:
	if casse:
		return false
	casser(true, origine)
	return true

## Sort (projectile ou jet) : `point` = impact.
func briser_sort(point: Vector3) -> void:
	if not casse:
		casser(true, point)

func _process(dt: float) -> void:
	if _vol >= 0.0:
		_animer(dt)
	if casse:
		if _vol < 0.0:
			set_process(false)
		return
	_veille += dt
	if _veille >= PERIODE:
		_veille = 0.0
		if ButinTables.est_pille(ident):
			casser(false, global_position + Vector3(0, haut, 0))

func casser(avec_effets: bool, origine: Vector3) -> void:
	if casse:
		return
	casse = true
	remove_from_group("cassables")
	collision_layer = 0
	if _forme != null:
		_forme.set_deferred("disabled", true)
	var centre := global_position + Vector3(0, haut * 0.5, 0)
	_eclater(avec_effets, centre, origine)
	for mi in _mis:
		mi.visible = false
	if not avec_effets:
		return
	ButinTables.piller(ident)
	var dir := centre - origine
	dir.y = 0.0
	dir = (dir.normalized() if dir.length() > 0.01 else Vector3.UP) * 0.6 + Vector3.UP
	var matiere := "bois" if genre in ["tonneau", "caisse"] else "pierre"
	GerbePixels.emettre(self, centre, dir.normalized(), matiere, 1.5)
	GerbePixels.emettre(self, global_position + Vector3(0, 0.1, 0), Vector3.UP, "poussiere", 0.9)
	Sons.jouer_a(self, ["impactWood_heavy_000"] if genre in ["tonneau", "caisse"] else ["impactPlate_medium_000", "impactPlate_medium_001"], centre, 2.0)
	_butin(centre)

## Éclats : les triangles de chaque surface sont rangés par secteur (angle autour de l'axe) et par moitié (haut / bas).
func _eclater(avec_effets: bool, centre: Vector3, origine: Vector3) -> void:
	var secteurs := 3
	var morceaux := {}     # clé (secteur, étage) -> {surface (matériau) -> {v, n, u, c}}
	for mi in _mis:
		var arr := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uu: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var cc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for q in range(0, v.size(), 3):
			var c := (v[q] + v[q + 1] + v[q + 2]) / 3.0
			var s := clampi(int((atan2(c.z, c.x) + PI) / TAU * secteurs), 0, secteurs - 1)
			var e := 1 if c.y > haut * 0.5 else 0
			var cle := s * 2 + e
			if not morceaux.has(cle):
				morceaux[cle] = {}
			var par_mat: Dictionary = morceaux[cle]
			if not par_mat.has(mi):
				par_mat[mi] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()]
			var b: Array = par_mat[mi]      # tableaux compactés : modifiés en place (pas de copie par le transtypage)
			for k in 3:
				b[0].append(v[q + k])
				b[1].append(nn[q + k])
				b[2].append(uu[q + k])
				b[3].append(cc[q + k])
	var rng := RandomNumberGenerator.new()
	rng.seed = ident.hash()
	var cles: Array = morceaux.keys()
	cles.sort()
	var hors := centre - origine
	hors.y = 0.0
	hors = hors.normalized() if hors.length() > 0.01 else Vector3.ZERO
	for cle in cles:
		var par_mat: Dictionary = morceaux[cle]
		# centre du morceau (moyenne de ses sommets) : le nœud d'éclat y est posé, les sommets recentrés
		var somme := Vector3.ZERO
		var nb := 0
		for mi in par_mat:
			for p: Vector3 in par_mat[mi][0]:
				somme += p
				nb += 1
		if nb == 0:
			continue
		var cen := somme / float(nb)
		var m := ArrayMesh.new()
		var mats: Array[Material] = []
		for mi in par_mat:
			var b: Array = par_mat[mi]
			var vv: PackedVector3Array = b[0]
			for k in vv.size():
				vv[k] -= cen
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = vv
			arr[Mesh.ARRAY_NORMAL] = b[1]
			arr[Mesh.ARRAY_TEX_UV] = b[2]
			arr[Mesh.ARRAY_COLOR] = b[3]
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mats.append((mi as MeshInstance3D).material_override)
		var ec := MeshInstance3D.new()
		ec.mesh = m
		for k in mats.size():
			ec.set_surface_override_material(k, mats[k])
		ec.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ec)
		ec.position = cen
		var taille := m.get_aabb().size
		var repos_y := minf(taille.x, minf(taille.y, taille.z)) * 0.4
		var dehors := Vector3(cen.x, 0.0, cen.z)
		dehors = dehors.normalized() if dehors.length() > 0.01 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var rep := Vector3(cen.x, repos_y, cen.z) + dehors * rng.randf_range(0.12, 0.3)
		var q := Basis.from_euler(Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-1.2, 1.2)))
		var e := {"n": ec, "repos": rep, "q": q, "q0": Basis(),
			"v": (global_transform.basis * (dehors * rng.randf_range(1.2, 2.6) + Vector3.UP * rng.randf_range(1.6, 3.2))) + hors * 0.8,
			"w": Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))}
		_eclats.append(e)
		if not avec_effets:
			ec.position = rep
			ec.basis = q
	if avec_effets:
		_vol = 0.0
	else:
		_vol = -1.0

func _animer(dt: float) -> void:
	_vol += dt
	var fin := _vol >= DUREE_VOL
	for e: Dictionary in _eclats:
		var ec: MeshInstance3D = e["n"]
		if fin:
			ec.position = e["repos"]
			ec.basis = e["q"]
			continue
		var vit: Vector3 = e["v"]
		vit.y -= GRAVITE * dt
		e["v"] = vit
		var p := ec.position + (global_transform.basis.inverse() * vit) * dt
		var plancher: float = (e["repos"] as Vector3).y
		if p.y < plancher:      # sol : l'éclat s'arrête là où il est tombé (plat, à plat sur le pied de l'objet)
			p.y = plancher
			vit = Vector3.ZERO
			e["v"] = vit
		ec.position = p
		var w: Vector3 = e["w"]
		if vit != Vector3.ZERO:
			ec.rotate_object_local(w.normalized(), w.length() * dt)
		else:
			ec.basis = ec.basis.orthonormalized().slerp(e["q"], minf(dt * 12.0, 1.0))
	if fin:
		_vol = -1.0

## Parfois une petite bourse (table « urne » / « tonneau » de data/butin/contenants.json) ; la liste est tirée à graine fixe.
func _butin(_centre: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get("joueur") == null:      # (tests : la scène est ajoutée à la racine sans devenir la scène courante)
		scene = null
		for n in get_tree().root.get_children():
			if n.get("joueur") != null and n.get("hud") != null:
				scene = n
				break
	if scene == null:
		return
	var joueur: Variant = scene.get("joueur")
	var hud: Variant = scene.get("hud")
	if joueur == null or hud == null:
		return
	var zone := ident.get_slice(":", 0)
	var liste := ButinTables.tirer_pour(ident, ButinTables.table_pour(genre, zone), zone)
	var contenu := ButinTables.contenu(liste)
	if contenu.is_empty():
		return
	var b := Node3D.new()
	b.set_script(preload("res://scripts/butin.gd"))
	b.joueur = joueur
	b.hud = hud
	b.contenu = contenu
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(0, 0.25, 0)
