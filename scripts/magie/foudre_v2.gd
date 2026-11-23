class_name FoudreV2
extends RefCounted
## FOUDRE v2 (branche magie/foudre_v2, docs/MAGIE_FOUDRE_V2.md) : éclairs STRUCTURÉS, d'après le principe des éclairs de
## Force (The Force Unleashed, Battlefront II) et des sorts de foudre de Skyrim (references/foudre/planches) :
##   - un TRONC fin et lumineux (cœur blanc-bleu, halo bleu au milieu, violet au bord) qui se ramifie en 2-4 BRANCHES plus
##     fines, puis en FILAMENTS ; nervures d'un bruit fractal cohérent (bruit de valeur à interpolation linéaire, 4 octaves :
##     coudes nets mais une seule direction générale), jamais de zigzag au hasard ;
##   - RÉGÉNÉRATION par à-coups : la forme est figée 2 à 4 images puis tirée à neuf (nouvelle graine des octaves fines,
##     l'octave lente dérive doucement : la trajectoire générale ne saute pas) ; l'ancienne forme reste 1-2 images en
##     rémanence, plus pâle ; l'éclat retombe par paliers entre deux formes (la lumière de la scène suit cet éclat) ;
##   - canalisation (Canal) : arcs qui partent du BOUT DES DOIGTS, s'écartent en cône puis CONVERGENT sur la cible et
##     l'accrochent en plusieurs points du corps (os du squelette, suivis chaque image : l'arc suit le corps qui se
##     convulse) ; petites griffes qui rampent sur le corps au point d'accroche ;
##   - entre deux formes, le maillage n'est pas refait : il est seulement recalé (rotation + échelle) sur ses deux bouts.
## Peu de géométrie : rubans à 2 sommets par point et par couche (halo, cœur), largeur entière en pixels écran
## (shaders/foudre_v2.gdshader), aucune particule de plus. `GestionMagie.foudre_v1` (`-- --foudre-v1`) remet l'ancien rendu.

const SH := preload("res://shaders/foudre_v2.gdshader")
## Images (à 60 i/s) entre deux formes d'un arc : tirées dans [2, 4].
const REGEN_MIN := 2
const REGEN_MAX := 4
## Plafonds (contrôlés par outils/test_foudre_v2.gd).
const MAX_ARCS_CANAL := 6
const MAX_POINTS_TRONC := 40
## Éclat de la forme selon son âge (en images depuis la régénération) ; rémanence de l'ancienne forme.
const ECLAT_AGE := [1.0, 0.8, 0.7, 0.62, 0.55]
const REMANENCE := [0.5, 0.25]
## Os du corps où les arcs s'accrochent (noms des squelettes Mixamo / Tripo / ancien corps), doigts et orteils exclus.
const OS_CORPS := ["spine", "chest", "neck", "head", "shoulder", "clavicle", "upperarm", "arm", "forearm", "hand", "pelvis", "hips", "thigh", "upleg"]
const OS_EXCLUS := ["finger", "thumb", "index", "middle", "ring", "pinky", "toe", "foot_end", "end", "twist", "ik", "pole", "eye", "jaw"]

## Dernière image d'un Canal (tests, outils) : paume, bouts des doigts, départs et bouts des arcs.
static var journal := {}
static var _mats := {}
static var _os_cache := {}        # id du squelette -> PackedInt32Array des os d'accroche
static var _doigts_cache := {}    # id du squelette + côté -> [[os_02, os_03] x 5]

# ====================================================================== bruit fractal cohérent

static func _h(i: int, g: int) -> float:
	var n := (i * 374761393 + g * 668265263 + 1013904223) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 32767.5 - 1.0

## Bruit de valeur 1D à interpolation LINÉAIRE : des coudes nets (l'éclair casse), pas de vagues.
static func _bruit(x: float, g: int) -> float:
	var i := floori(x)
	return lerpf(_h(i, g), _h(i + 1, g), x - i)

## 4 octaves ; l'octave 0 (la direction générale) prend sa graine `g_lente` (elle dérive lentement d'une forme à l'autre),
## les fines la graine `g` (tirée à neuf à chaque forme).
static func fbm(x: float, g: int, g_lente: float) -> float:
	var v := _bruit(x + g_lente, 17) * 1.0
	var f := 2.3
	var a := 0.58
	for o in range(1, 4):
		v += _bruit(x * f + float(o) * 3.1, g + o * 977) * a
		f *= 2.3
		a *= 0.58
	return v / 2.11

static func base_perp(d: Vector3) -> Basis:
	var dn := d.normalized() if d.length_squared() > 1e-10 else Vector3.FORWARD
	var u := dn.cross(Vector3.UP if absf(dn.y) < 0.92 else Vector3.RIGHT).normalized()
	return Basis(u, dn.cross(u), dn)

## Nervure de a à b (Bézier quadratique par c), décalée par le bruit fractal dans le plan perpendiculaire.
## `libre` : le bout b n'est pas tenu (branche, filament : l'enveloppe ne revient pas à zéro).
static func nervure(a: Vector3, c: Vector3, b: Vector3, ampl: float, n: int, g: int, g_lente: float, libre := false) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.resize(n + 1)
	var bs := base_perp(b - a)
	var l := a.distance_to(b)
	var freq := clampf(l * 2.0, 1.8, 13.0)   # nombre de grands coudes le long du trait
	for i in n + 1:
		var t := float(i) / n
		var q := a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t
		var env := pow(sin(PI * t), 0.7) if not libre else pow(sin(PI * 0.5 * t), 0.8)
		var x := t * freq
		q += (bs.x * fbm(x, g, g_lente) + bs.y * fbm(x + 37.0, g + 5, g_lente * 0.8 + 11.0)) * ampl * env
		pts[i] = q
	return pts

## Arbre d'éclair : tronc + branches + filaments. Renvoie des traits {p: points, niv: 0|1|2, a: [intensités], w: [largeurs]}.
## o : {ampl, branches, filaments (0..1), libre, griffes (Array de [depart, fin])}.
static func arbre(a: Vector3, c: Vector3, b: Vector3, rng: RandomNumberGenerator, g_lente: float, o := {}) -> Array:
	var traits: Array = []
	var l := a.distance_to(b)
	if l < 0.02:
		return traits
	var ampl: float = o.get("ampl", clampf(l * 0.055, 0.012, 0.32))
	var n := clampi(int(l / 0.11) + 6, 6, MAX_POINTS_TRONC)
	var g := rng.randi()
	var tronc := nervure(a, c, b, ampl, n, g, g_lente, bool(o.get("libre", false)))
	var ia := PackedFloat32Array()
	var iw := PackedFloat32Array()
	ia.resize(n + 1)
	iw.resize(n + 1)
	var largeur: float = o.get("largeur", 1.0)
	for i in n + 1:
		var t := float(i) / n
		ia[i] = 1.0 if not o.get("libre", false) else lerpf(1.0, 0.35, t * t)
		iw[i] = largeur * (lerpf(0.55, 1.0, clampf(t / 0.12, 0.0, 1.0)))   # fin au bout des doigts, il prend corps
	traits.append({"p": tronc, "niv": 0, "a": ia, "w": iw})
	# branches : 2 à 4 sur le tronc, de part et d'autre (côtés alternés), tournées vers l'avant
	var nb: int = o.get("branches", rng.randi_range(2, 4))
	var ang := rng.randf() * TAU
	for k in nb:
		var ts := rng.randf_range(float(o.get("branche_min", 0.14)), 0.78)
		var i0 := clampi(int(ts * n), 1, n - 1)
		var p0 := tronc[i0]
		var tan := (tronc[i0 + 1] - tronc[i0 - 1]).normalized()
		var bs := base_perp(tan)
		ang += PI + rng.randf_range(-0.7, 0.7)
		var cote := bs.x * cos(ang) + bs.y * sin(ang)
		var dir := (tan * 0.78 + cote * rng.randf_range(0.45, 0.8)).normalized()
		var lb := l * (1.0 - ts) * rng.randf_range(0.12, 0.3)
		lb = minf(lb, 1.4)
		var fin := p0 + dir * lb
		var nn := clampi(int(lb / 0.06) + 3, 4, 12)
		var br := nervure(p0, p0 + dir * lb * 0.5 + cote * lb * 0.12, fin, lb * 0.16, nn, rng.randi(), g_lente * 1.3 + k, true)
		var ba := PackedFloat32Array()
		var bw := PackedFloat32Array()
		ba.resize(nn + 1)
		bw.resize(nn + 1)
		for i in nn + 1:
			var t := float(i) / nn
			ba[i] = lerpf(0.8, 0.2, t)
			bw[i] = largeur * lerpf(0.6, 0.35, t)
		traits.append({"p": br, "niv": 1, "a": ba, "w": bw})
		# filaments : 0 à 2 par branche
		var nf := 0
		var pf: float = o.get("filaments", 0.75)
		if rng.randf() < pf:
			nf = 1 + (1 if rng.randf() < pf * 0.5 else 0)
		for _f in nf:
			var j0 := clampi(rng.randi_range(nn / 4, nn * 3 / 4), 1, nn - 1)
			var q0 := br[j0]
			var td := (br[j0 + 1] - br[j0 - 1]).normalized()
			var bf := base_perp(td)
			var a2 := rng.randf() * TAU
			var df := (td * 0.6 + (bf.x * cos(a2) + bf.y * sin(a2)) * 0.8).normalized()
			var lf := lb * rng.randf_range(0.3, 0.55)
			var fl := nervure(q0, q0 + df * lf * 0.5, q0 + df * lf, lf * 0.2, 4, rng.randi(), g_lente * 1.7, true)
			var fa := PackedFloat32Array([0.55, 0.45, 0.32, 0.2, 0.1])
			var fw := PackedFloat32Array([0.35, 0.3, 0.3, 0.25, 0.2])
			traits.append({"p": fl, "niv": 2, "a": fa, "w": fw})
	# griffes : petits arcs qui rampent sur le corps au point d'accroche (les deux bouts tenus)
	for gr in o.get("griffes", []):
		var ga: Vector3 = gr[0]
		var gb: Vector3 = gr[1]
		var lg := ga.distance_to(gb)
		if lg < 0.03:
			continue
		var dv: Vector3 = gr[2] if gr.size() > 2 else Vector3.ZERO
		var mid: Vector3 = ga.lerp(gb, 0.5) + dv * lg * 0.25
		var gp := nervure(ga, mid, gb, lg * 0.18, clampi(int(lg / 0.04) + 3, 4, 10), rng.randi(), g_lente * 2.1)
		var na := PackedFloat32Array()
		var nw := PackedFloat32Array()
		na.resize(gp.size())
		nw.resize(gp.size())
		for i in gp.size():
			na[i] = 0.75
			nw[i] = largeur * 0.45
		traits.append({"p": gp, "niv": 1, "a": na, "w": nw})
	return traits

# ====================================================================== maillage (rubans)

## Ruban : 2 sommets par point et par couche (halo, puis cœur), direction moyenne au point (le shader élargit à l'écran).
## Filaments (niv 2) : cœur seul. Coordonnées relatives à `origine` (le nœud est recalé chaque image).
static func construire(m: ArrayMesh, traits: Array, origine: Vector3) -> int:
	m.clear_surfaces()
	var nv := 0
	var ni := 0
	for t in traits:
		var c: int = (t.p as PackedVector3Array).size()
		if c < 2:
			continue
		var couches := 1 if int(t.niv) >= 2 else 2
		nv += c * 2 * couches
		ni += (c - 1) * 6 * couches
	if nv == 0:
		return 0
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	v.resize(nv)
	nr.resize(nv)
	col.resize(nv)
	uv.resize(nv)
	uv2.resize(nv)
	idx.resize(ni)
	var k := 0
	var q := 0
	for t in traits:
		var p: PackedVector3Array = t.p
		var c := p.size()
		if c < 2:
			continue
		var niv := float(t.niv)
		var ia: PackedFloat32Array = t.a
		var iw: PackedFloat32Array = t.w
		var couches: Array = [1.0] if int(t.niv) >= 2 else [0.0, 1.0]
		for couche: float in couches:
			var k0 := k
			for i in c:
				var d := p[mini(i + 1, c - 1)] - p[maxi(i - 1, 0)]
				if d.length_squared() < 1e-12:
					d = Vector3.FORWARD
				var pos := p[i] - origine
				var cc := Color(1, 1, 1, ia[i])
				var w := Vector2(iw[i], niv)
				v[k] = pos
				nr[k] = d
				col[k] = cc
				uv[k] = Vector2(couche, -1.0)
				uv2[k] = w
				v[k + 1] = pos
				nr[k + 1] = d
				col[k + 1] = cc
				uv[k + 1] = Vector2(couche, 1.0)
				uv2[k + 1] = w
				k += 2
			for i in c - 1:
				var s := k0 + i * 2
				idx[q] = s
				idx[q + 1] = s + 1
				idx[q + 2] = s + 3
				idx[q + 3] = s
				idx[q + 4] = s + 3
				idx[q + 5] = s + 2
				q += 6
	var ar := []
	ar.resize(Mesh.ARRAY_MAX)
	ar[Mesh.ARRAY_VERTEX] = v
	ar[Mesh.ARRAY_NORMAL] = nr
	ar[Mesh.ARRAY_COLOR] = col
	ar[Mesh.ARRAY_TEX_UV] = uv
	ar[Mesh.ARRAY_TEX_UV2] = uv2
	ar[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar)
	return nv

## Matériau partagé (un par réglage : largeurs en pixels du halo et du cœur).
static func materiau(halo_px := 5.0, coeur_px := 2.0, force := 1.6) -> ShaderMaterial:
	var cle := "%s|%s|%s" % [halo_px, coeur_px, force]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH
		m.set_shader_parameter("largeur_halo", halo_px)
		m.set_shader_parameter("largeur_coeur", coeur_px)
		m.set_shader_parameter("force", force)
		_mats[cle] = m
	return _mats[cle]

static func _mi(parent: Node, mat: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ArrayMesh.new()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	mi.layers = CoucheMagie.CALQUE
	mi.visible = false
	parent.add_child(mi)
	return mi

## Transformation qui envoie le segment (a0, b0) sur (a, b) : rotation la plus courte + échelle uniforme.
static func recaler(a0: Vector3, b0: Vector3, a: Vector3, b: Vector3) -> Transform3D:
	var d0 := b0 - a0
	var d1 := b - a
	var l0 := d0.length()
	var l1 := d1.length()
	if l0 < 1e-4 or l1 < 1e-4:
		return Transform3D(Basis.IDENTITY, a)
	var bs := Basis.IDENTITY
	var x := d0 / l0
	var y := d1 / l1
	var ax := x.cross(y)
	var s := ax.length()
	if s > 1e-5:
		bs = Basis(ax / s, atan2(s, x.dot(y)))
	elif x.dot(y) < 0.0:
		bs = Basis(base_perp(x).x, PI)
	return Transform3D(bs.scaled(Vector3.ONE * clampf(l1 / l0, 0.5, 2.0)), a)

# ====================================================================== un arc vivant (forme + rémanence)

class Arc:
	extends RefCounted
	var mi: MeshInstance3D
	var rem: MeshInstance3D
	var a0 := Vector3.ZERO
	var b0 := Vector3.ZERO
	var ra0 := Vector3.ZERO
	var rb0 := Vector3.ZERO
	var prochaine := 0          # image (Engine.get_process_frames) de la prochaine forme
	var nee := -100             # image de la forme actuelle
	var formes := 0
	var sommets := 0
	var eclat := 0.0
	var actif := false

	func _init(parent: Node, mat: ShaderMaterial) -> void:
		mi = FoudreV2._mi(parent, mat)
		rem = FoudreV2._mi(parent, mat)

	## Vrai si l'arc doit prendre une nouvelle forme à cette image.
	func a_refaire(img: int) -> bool:
		return img >= prochaine or not actif

	## Nouvelle forme (traits en coordonnées monde, bouts a et b) ; l'ancienne passe en rémanence.
	func former(traits: Array, a: Vector3, b: Vector3, img: int, rng: RandomNumberGenerator) -> void:
		if actif and sommets > 0:
			var m: Mesh = rem.mesh
			rem.mesh = mi.mesh
			mi.mesh = m
			ra0 = a0
			rb0 = b0
			rem.visible = true
		a0 = a
		b0 = b
		sommets = FoudreV2.construire(mi.mesh as ArrayMesh, traits, a)
		nee = img
		prochaine = img + rng.randi_range(FoudreV2.REGEN_MIN, FoudreV2.REGEN_MAX)
		formes += 1
		actif = true

	## Recalage de l'image : la forme suit ses deux bouts ; éclat par paliers selon l'âge.
	func placer(a: Vector3, b: Vector3, img: int, force := 1.0) -> void:
		if not actif or sommets == 0:
			mi.visible = false
			rem.visible = false
			eclat = 0.0
			return
		var age := img - nee
		eclat = float(FoudreV2.ECLAT_AGE[mini(age, FoudreV2.ECLAT_AGE.size() - 1)]) * force
		mi.visible = true
		mi.global_transform = FoudreV2.recaler(a0, b0, a, b)
		mi.set_instance_shader_parameter("eclat", eclat)
		if age < FoudreV2.REMANENCE.size() and rem.visible:
			rem.global_transform = FoudreV2.recaler(ra0, rb0, a, b)
			rem.set_instance_shader_parameter("eclat", float(FoudreV2.REMANENCE[age]) * force)
		else:
			rem.visible = false

	func eteindre() -> void:
		actif = false
		sommets = 0
		if is_instance_valid(mi):
			mi.visible = false
		if is_instance_valid(rem):
			rem.visible = false

	func liberer() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
		if is_instance_valid(rem):
			rem.queue_free()

# ====================================================================== repères : doigts et corps

## Bouts des 5 doigts de la main qui porte `origine` (nœud paume sous un BoneAttachment3D du squelette des mains, ou corps
## TPS / ennemi) ; repli : un éventail autour de la paume, tourné vers `dir`.
static func bouts_doigts(origine: Node3D, dir: Vector3) -> PackedVector3Array:
	var res := PackedVector3Array()
	var sq: Skeleton3D = null
	var ba: BoneAttachment3D = null
	var cote := "l"
	var n: Node = origine
	for _i in 6:
		if n == null:
			break
		if n is BoneAttachment3D:
			ba = n
			var bn := String((n as BoneAttachment3D).bone_name)
			cote = "r" if bn.ends_with("_r") or bn.to_lower().contains("right") else "l"
		if n is Skeleton3D:
			sq = n
			break
		n = n.get_parent()
	if origine.name.ends_with("droite"):
		cote = "r"
	if sq != null:
		var cle := "%d%s" % [sq.get_instance_id(), cote]
		if not _doigts_cache.has(cle):
			var l: Array = []
			for f in ["thumb", "index", "middle", "ring", "pinky"]:
				var i2 := sq.find_bone("%s_02_%s" % [f, cote])
				var i3 := sq.find_bone("%s_03_%s" % [f, cote])
				if i2 >= 0 and i3 >= 0:
					l.append([i2, i3])
			_doigts_cache[cle] = l
		var os: Array = _doigts_cache[cle]
		if os.size() >= 4:
			# repère : celui de l'os de la main tel que l'accroche le voit (le squelette des mains FPS est rendu ailleurs que sa
			# transformation globale ne le dit) ; poses relatives des doigts
			var xf := sq.global_transform
			if ba != null:
				var hb := sq.find_bone(String(ba.bone_name))
				if hb >= 0:
					xf = ba.global_transform * sq.get_bone_global_pose(hb).affine_inverse()
			for p in os:
				var a := xf * sq.get_bone_global_pose(p[0]).origin
				var b := xf * sq.get_bone_global_pose(p[1]).origin
				res.append(b + (b - a) * 0.9)
			return res
	# repli (corps TPS, mage ennemi) : cinq points en arc devant la paume
	var o := origine.global_position
	var bs := base_perp(dir)
	for k in 5:
		var a := (float(k) - 2.0) * 0.32
		res.append(o + dir * 0.06 + (bs.x * sin(a) + bs.y * (cos(a) - 0.8)) * 0.045)
	return res

## Os d'accroche du corps de `cible` (squelette) ; vide si la cible n'a pas de squelette.
static func os_corps(cible: Node3D) -> Array:
	var sqs := cible.find_children("*", "Skeleton3D", true, false)
	if sqs.is_empty():
		return []
	var sq: Skeleton3D = sqs[0]
	var cle := sq.get_instance_id()
	if not _os_cache.has(cle):
		var l := PackedInt32Array()
		for i in sq.get_bone_count():
			var nom := sq.get_bone_name(i).to_lower()
			var ok := false
			for m in OS_CORPS:
				if nom.contains(m):
					ok = true
					break
			for m in OS_EXCLUS:
				if nom.contains(m):
					ok = false
					break
			if ok:
				l.append(i)
		_os_cache[cle] = l
	return [sq, _os_cache[cle]]

static func pos_os(sq: Skeleton3D, i: int) -> Vector3:
	return sq.global_transform * sq.get_bone_global_pose(i).origin

# ====================================================================== canalisation (arc électrique)

## Rendu d'un jet d'électricité : `n` arcs (doigts -> points du corps), recalés chaque image, reformés par à-coups.
class Canal:
	extends RefCounted
	var gm: Node3D
	var racine: Node3D
	var arcs: Array = []
	var dbl := false
	var rng := RandomNumberGenerator.new()
	var _accroche: Array = []   # par arc : [os, formes restantes] (l'arc garde son point d'accroche 2-3 formes)
	var _lat: Array = []        # par arc : angle de l'éventail
	var _g_lente := 0.0
	var _img := -1
	## éclat combiné (0..1) des arcs : la lumière de la scène le suit ; « formes » : nouvelles formes à cette image
	var eclat := 0.0
	var formes_image := 0
	var points_touches: Array = []

	func _init(g: Node3D, double: bool) -> void:
		gm = g
		dbl = double
		rng.randomize()
		racine = Node3D.new()
		racine.name = "FoudreCanal"
		g.add_child(racine)
		var n := 5 if dbl else 4
		for k in mini(n, FoudreV2.MAX_ARCS_CANAL):
			var mat := FoudreV2.materiau(5.0, 2.0, 1.55) if k == 0 else FoudreV2.materiau(4.0, 1.0, 1.3)
			arcs.append(FoudreV2.Arc.new(racine, mat))
			_accroche.append([-1, 0])
			_lat.append(float(k) / n * TAU + rng.randf_range(-0.4, 0.4))

	func liberer() -> void:
		for a in arcs:
			a.liberer()
		if is_instance_valid(racine):
			racine.queue_free()

	## Une image : `o` paume, `fin` point visé / touché, `cible` corps visé (ou null), `dir` direction de visée.
	func maj(origine: Node3D, o: Vector3, fin: Vector3, dir: Vector3, cible: Node3D, touche: bool, espace: PhysicsDirectSpaceState3D, exclus: Array[RID], force := 1.0) -> void:
		var img := Engine.get_process_frames()
		if img == _img:
			return   # déjà placé à cette image (le jet est placé par le lanceur ET par GestionMagie._maj_jets)
		_img = img
		var l := o.distance_to(fin)
		var doigts := FoudreV2.bouts_doigts(origine, dir)
		var corps: Array = FoudreV2.os_corps(cible) if cible != null and is_instance_valid(cible) else []
		var bs := FoudreV2.base_perp(fin - o)
		_g_lente += 0.016 * 0.9
		formes_image = 0
		points_touches.clear()
		var somme := 0.0
		var departs: Array = []
		var bouts: Array = []
		for k in arcs.size():
			var arc: FoudreV2.Arc = arcs[k]
			# départ : le tronc (k = 0) part du majeur, les autres de l'index, de l'annulaire, du pouce, de l'auriculaire
			var di: int = [2, 1, 3, 0, 4, 2][k % 6]
			var a: Vector3 = doigts[mini(di, doigts.size() - 1)]
			var b := _bout(k, a, fin, l, bs, corps, touche)
			if arc.a_refaire(img):
				_lat[k] = float(_lat[k]) + rng.randf_range(-0.5, 0.5) + 0.35
				var lat: float = _lat[k]
				var ecart := clampf(l * (0.07 if k == 0 else 0.13), 0.04, 0.9)
				var c := a.lerp(b, 0.42) + (bs.x * cos(lat) + bs.y * sin(lat)) * ecart
				if espace != null and k > 0 and corps.is_empty():
					# dans le vide ou sur un mur : l'arc s'accroche à la première surface rencontrée
					var q := PhysicsRayQueryParameters3D.create(a, a + (b - a) * 1.1, 0xFFFFFFFF, exclus)
					var r := espace.intersect_ray(q)
					if not r.is_empty():
						b = r.position
				var griffes: Array = []
				if not corps.is_empty() and rng.randf() < 0.75:
					griffes = _griffes(b, corps, k)
				var tr := FoudreV2.arbre(a, c, b, rng, _g_lente + k * 13.0, {
					"branches": (rng.randi_range(2, 3) if k == 0 else rng.randi_range(0, 1)),
					"filaments": 0.6 if k == 0 else 0.25, "libre": not touche and corps.is_empty() and k > 0,
					"largeur": 1.0 if k == 0 else 0.8, "griffes": griffes})
				arc.former(tr, a, b, img, rng)
				formes_image += 1
				if touche or not corps.is_empty():
					points_touches.append(b)
			arc.placer(a, b, img, force)
			somme += arc.eclat
			departs.append(a)
			bouts.append(b)
		eclat = somme / maxf(arcs.size(), 1)
		FoudreV2.journal = {"o": o, "doigts": doigts, "departs": departs, "bouts": bouts, "img": img, "formes": formes_image}

	## Bout de l'arc k : un os du corps (gardé 2-3 formes), sinon un point du disque autour du point visé.
	func _bout(k: int, a: Vector3, fin: Vector3, l: float, bs: Basis, corps: Array, _touche: bool) -> Vector3:
		if not corps.is_empty():
			var sq: Skeleton3D = corps[0]
			var lst: PackedInt32Array = corps[1]
			if lst.size() > 0 and is_instance_valid(sq):
				var acc: Array = _accroche[k]
				var arc: FoudreV2.Arc = arcs[k]
				if int(acc[0]) < 0 or (arc.a_refaire(Engine.get_process_frames()) and int(acc[1]) <= 0):
					acc[0] = lst[rng.randi() % lst.size()]
					acc[1] = rng.randi_range(2, 3)
				elif arc.a_refaire(Engine.get_process_frames()):
					acc[1] = int(acc[1]) - 1
				var po := FoudreV2.pos_os(sq, int(acc[0]))
				return po + (a - po).normalized() * 0.1   # à la surface du corps, côté lanceur (l'os est dedans)
		if k == 0:
			return fin
		var ang: float = _lat[k] * 0.5 + float(k) * 1.9
		var r := clampf(l * 0.09, 0.08, 0.55)
		return fin + (bs.x * cos(ang) + bs.y * sin(ang)) * r - bs.z * r * 0.3

	## 1 à 2 petites griffes du point d'accroche vers des os voisins (elles rampent sur le corps).
	func _griffes(b: Vector3, corps: Array, k: int) -> Array:
		var sq: Skeleton3D = corps[0]
		var lst: PackedInt32Array = corps[1]
		var res: Array = []
		var n := 1 + (1 if k == 0 else 0)
		for _i in 6:
			if res.size() >= n or lst.is_empty():
				break
			var p := FoudreV2.pos_os(sq, lst[rng.randi() % lst.size()])
			var d := p.distance_to(b)
			if d > 0.08 and d < 0.6:
				res.append([b, p, Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()])
		return res

	func nb_arcs_visibles() -> int:
		var n := 0
		for a in arcs:
			if (a as FoudreV2.Arc).mi.visible:
				n += 1
		return n

	func sommets() -> int:
		var n := 0
		for a in arcs:
			n += (a as FoudreV2.Arc).sommets
		return n

	func eteindre() -> void:
		for a in arcs:
			a.eteindre()

# ====================================================================== convulsions de la cible

## Secousse de la cible électrisée, au rythme des nouvelles formes des arcs : une impulsion courte (0,1 s) vers une image
## d'une RÉACTION CAPTURÉE de la cible (Hit_Chest, Hit_Head… de son AnimationPlayer : aucune pose écrite à la main),
## posée par-dessus son animation par un SkeletonModifier3D (influence = poids de l'impulsion). Purement visuel : l'état et
## la logique de l'ennemi ne changent pas. Sans réaction capturée : rien.
static func convulser(cible: Node3D, k := 1.0) -> void:
	if cible == null or not is_instance_valid(cible) or not cible.is_inside_tree():
		return
	var cv: Convulsion = null
	if cible.has_meta("foudre_convulsion"):
		var mv: Variant = cible.get_meta("foudre_convulsion")
		if mv is Convulsion:
			cv = mv
		elif mv is bool:
			return   # déjà essayé : pas de réaction capturée
	if cv == null or not is_instance_valid(cv):
		var ap: Variant = cible.get("anim")
		if not (ap is AnimationPlayer):
			var l := cible.find_children("*", "AnimationPlayer", true, false)
			ap = l[0] if not l.is_empty() else null
		var sqs := cible.find_children("*", "Skeleton3D", true, false)
		if ap == null or sqs.is_empty():
			cible.set_meta("foudre_convulsion", false)
			return
		var clips: Array = []
		for nom in (ap as AnimationPlayer).get_animation_list():
			var b := String(nom).to_lower()
			if b.contains("hit") or b.contains("impact") or b.contains("react"):
				clips.append(nom)
		if clips.is_empty():
			cible.set_meta("foudre_convulsion", false)
			return
		cv = Convulsion.new()
		cv.name = "FoudreConvulsion"
		cv.player = ap
		cv.clips = clips
		(sqs[0] as Skeleton3D).add_child(cv)
		cible.set_meta("foudre_convulsion", cv)
	cv.impulsion(k)

class Convulsion:
	extends SkeletonModifier3D
	var player: AnimationPlayer
	var clips: Array = []
	var _pistes := {}          # clip -> [[piste, os], ...] (rotations du haut du corps)
	var _clip: Animation
	var _t := 0.0
	var _debut := -10.0
	var _poids := 0.0
	const DUREE := 0.11
	const ECART := 0.1          # s minimum entre deux impulsions

	func _ready() -> void:
		influence = 0.0

	func impulsion(k: float) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _debut < ECART:
			return
		var nom: StringName = clips[randi() % clips.size()]
		var an := player.get_animation(nom)
		if an == null:
			return
		_clip = an
		_t = randf_range(0.06, minf(0.3, an.length * 0.6))
		_debut = now
		_poids = clampf(0.42 * k + randf_range(-0.08, 0.08), 0.0, 0.7)
		active = true
		if not _pistes.has(nom):
			var sq := get_skeleton()
			var l: Array = []
			for i in an.get_track_count():
				if an.track_get_type(i) != Animation.TYPE_ROTATION_3D:
					continue
				var os := sq.find_bone(String(an.track_get_path(i).get_concatenated_subnames()))
				if os < 0:
					continue
				var bn := sq.get_bone_name(os).to_lower()
				if bn.contains("leg") or bn.contains("foot") or bn.contains("toe") or bn.contains("thigh") or bn.contains("calf") or bn.contains("hips") or bn.contains("pelvis") or bn.contains("root"):
					continue   # le bas du corps reste à l'animation (les pieds ne glissent pas)
				l.append([i, os])
			_pistes[nom] = l
		set_meta("pistes", _pistes[nom])

	func _process_modification() -> void:
		var sq := get_skeleton()
		if sq == null or _clip == null:
			return
		var age := Time.get_ticks_msec() / 1000.0 - _debut
		if age > DUREE:
			influence = 0.0
			active = false
			return
		# attaque nette, retombée rapide (secousse, pas un mouvement)
		influence = _poids * (1.0 - smoothstep(0.03, DUREE, age))
		for p in get_meta("pistes", []):
			sq.set_bone_pose_rotation(p[1], _clip.rotation_track_interpolate(p[0], _t + age * 0.5))
