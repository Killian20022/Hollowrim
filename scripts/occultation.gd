class_name Occultation
## Opti 2026-11-20 (domaine appels de dessin) : OCCLUSION CULLING des bâtiments enterables du village.
## Chaque bâtiment ouvert (BatimentsOuverts.ouvrir, et les 4 maisons d'origine) reçoit un ArrayOccluder3D : ses 4 murs, plans au MILIEU
## de l'épaisseur du mur (entre la face intérieure et la face extérieure, donc dans la matière pleine), du seuil au haut des murs, avec
## la PORTE et TOUTES les fenêtres découpées (chaque vitrage posé dehors est noté au moment où il est bâti, vraie fenêtre ou non, + marge) :
## partout où un mur laisse voir à travers, l'occulteur a un trou. Pignons, toits et socles ne sont pas des occulteurs (prudent).
## Effet : dedans, le dehors caché par les murs (végétation, autres maisons, feu, PNJ) n'est plus dessiné ; dehors, ce qui est entièrement
## derrière une maison non plus. Seule la passe principale est concernée (les ombres restent) : image identique.
## `-- --sans-opti-occlusion` : pas d'occulteur, occlusion du viewport coupée (comportement d'avant).

static var actif := not ("--sans-opti-occlusion" in OS.get_cmdline_user_args())
const MARGE := 0.12           # agrandit chaque trou (m)
const PRES_MUR := 0.6         # un vitrage à moins de cette distance du plan d'un mur y fait un trou

static var _vitrages: Array[AABB] = []      # boîtes MONDE des vitrages du dehors
static var _batiments: Array = []           # [Node3D pivot, Vector2 demi milieu du mur, float y0, float y1, Array portes [Vector3 c (pivot), Vector3 n, larg, haut]]

static func remettre() -> void:
	_vitrages.clear()
	_batiments.clear()

## Un vitrage du dehors : `pts` en coordonnées MONDE.
static func noter_vitrage(pts: PackedVector3Array) -> void:
	if not actif or pts.is_empty():
		return
	var bb := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		bb = bb.expand(p)
	_vitrages.append(bb)

## Un bâtiment (repère du pivot `p` : murs alignés sur X et Z). `int_` / `ext` : demi-emprises des faces intérieure et extérieure des murs.
static func batiment(p: Node3D, int_: Vector2, ext: Vector2, y0: float, y1: float, portes: Array) -> void:
	if not actif:
		return
	_batiments.append([p, (int_ + ext) * 0.5, y0, y1, portes])

## Pose les occulteurs (fin du bâti du village : tous les vitrages sont notés) et allume l'occlusion du viewport.
static func construire(v: Node3D) -> void:
	if v.get_viewport() != null:
		v.get_viewport().use_occlusion_culling = actif
	if not actif:
		return
	var n := 0
	var nq := 0
	for b: Array in _batiments:
		var p: Node3D = b[0]
		if not is_instance_valid(p) or not p.is_inside_tree():
			continue
		var m: Vector2 = b[1]
		var y0: float = b[2]
		var y1: float = b[3]
		var inv := p.global_transform.affine_inverse()
		var trous_vit: Array[AABB] = []
		for bb in _vitrages:
			var c := inv * bb.get_center()
			if absf(c.x) < m.x + 1.5 and absf(c.z) < m.y + 1.5:
				trous_vit.append(inv * bb)
		var verts := PackedVector3Array()
		var idx := PackedInt32Array()
		# 4 murs : [axe normal X ?, signe]
		for mur: Array in [[true, 1.0], [true, -1.0], [false, 1.0], [false, -1.0]]:
			var sur_x: bool = mur[0]
			var sg: float = mur[1]
			var plan: float = (m.x if sur_x else m.y) * sg
			var demi_t: float = m.y if sur_x else m.x
			var trous: Array = []
			for pt: Array in b[4]:
				var c: Vector3 = pt[0]
				var nn: Vector3 = pt[1]
				var sur_ce_mur := (absf(nn.x) > 0.5) == sur_x and signf(nn.x if sur_x else nn.z) == sg
				if not sur_ce_mur:
					continue
				var t: float = c.z if sur_x else c.x
				trous.append(Rect2(t - float(pt[2]) * 0.5 - MARGE, c.y - 0.3, float(pt[2]) + 2.0 * MARGE, float(pt[3]) + 0.3 + MARGE))
			for bb in trous_vit:
				var cc := bb.get_center()
				if absf((cc.x if sur_x else cc.z) - plan) > PRES_MUR:
					continue
				var t0: float = bb.position.z if sur_x else bb.position.x
				var lt: float = bb.size.z if sur_x else bb.size.x
				trous.append(Rect2(t0 - MARGE, bb.position.y - MARGE, lt + 2.0 * MARGE, bb.size.y + 2.0 * MARGE))
			for r: Rect2 in decouper(Rect2(-demi_t, y0, demi_t * 2.0, y1 - y0), trous):
				var a := _point(sur_x, plan, r.position.x, r.position.y)
				var bq := _point(sur_x, plan, r.end.x, r.position.y)
				var cq := _point(sur_x, plan, r.end.x, r.end.y)
				var dq := _point(sur_x, plan, r.position.x, r.end.y)
				var k := verts.size()
				verts.append_array([a, bq, cq, dq])
				idx.append_array([k, k + 1, k + 2, k, k + 2, k + 3])
				nq += 1
		if verts.is_empty():
			continue
		var ao := ArrayOccluder3D.new()
		ao.set_arrays(verts, idx)
		var oi := OccluderInstance3D.new()
		oi.name = "Occulteur_" + String(p.name)
		oi.occluder = ao
		v.add_child(oi)
		oi.global_transform = p.global_transform
		n += 1
	print("Occultation : %d bâtiments, %d rectangles de mur, %d vitrages notés" % [n, nq, _vitrages.size()])
	remettre()

static func _point(sur_x: bool, plan: float, t: float, y: float) -> Vector3:
	return Vector3(plan, y, t) if sur_x else Vector3(t, y, plan)

## Rectangle `r` (t, y) moins les trous : rectangles disjoints (tranches verticales entre les bords des trous).
static func decouper(r: Rect2, trous: Array) -> Array[Rect2]:
	var bords: Array[float] = [r.position.x, r.end.x]
	var utiles: Array[Rect2] = []
	for h: Rect2 in trous:
		var hh := h.intersection(r)
		if hh.size.x <= 0.0 or hh.size.y <= 0.0:
			continue
		utiles.append(hh)
		bords.append(hh.position.x)
		bords.append(hh.end.x)
	bords.sort()
	var res: Array[Rect2] = []
	for i in bords.size() - 1:
		var a: float = bords[i]
		var b: float = bords[i + 1]
		if b - a < 0.01:
			continue
		var milieu := (a + b) * 0.5
		var ys: Array = []          # intervalles y couverts par des trous dans cette tranche
		for h in utiles:
			if h.position.x <= milieu and h.end.x >= milieu:
				ys.append([h.position.y, h.end.y])
		ys.sort_custom(func(u, w): return u[0] < w[0])
		var y := r.position.y
		for iv in ys:
			if iv[0] > y + 0.01:
				res.append(Rect2(a, y, b - a, iv[0] - y))
			y = maxf(y, iv[1])
		if r.end.y > y + 0.01:
			res.append(Rect2(a, y, b - a, r.end.y - y))
	return res
