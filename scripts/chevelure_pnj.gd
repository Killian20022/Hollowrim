class_name ChevelurePnj
## [pnj/realisme_v1, passe 2] Chevelures en CARTES DE MÈCHES (alpha coupé, double face, style PS1) pour les PNJ maison, au lieu du
## casque lisse Quaternius (Hair_Long : raie nette, surface d'un seul tenant) : une calotte de mèches courtes épouse le crâne (le cuir
## chevelu ne se voit pas entre les cartes), puis des cartes de 2 à 4 cm de large suivent le crâne et retombent selon la coiffure.
## Tout est porté par l'os Head (poids 1) : rien ne bouge par rapport aux animations existantes.
## Coiffures : court, rase, chauve (couronne sur les côtés et la nuque), long (libre jusqu'aux épaules, derrière), attache (queue sur la
## nuque), nattes (deux nattes derrière les oreilles), chignon. Texture : brins dessinés dans la couleur du poil (racine sombre, reflets,
## pointes effilées découpées), générée par couleur (cache mémoire ; le PNJ entier est mis en cache disque par CachePersos).

const TW := 64
const TH := 128
static var _tex := {}
static var _mx := Mutex.new()

## Repère du crâne tiré des sommets de la peau pesés sur l'os Head : centre et demi-axes (le visage et la mâchoire exclus).
static func _crane(sq: Skeleton3D) -> Dictionary:
	var peau := sq.get_node_or_null("peau") as MeshInstance3D
	var head := sq.find_bone("Head")
	var o := sq.get_bone_global_rest(head).origin
	var haut := o.y + 0.21
	var zmin := o.z - 0.09
	var zmax := o.z + 0.13
	var xmax := 0.09
	if peau != null and peau.mesh != null:
		var a := peau.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var nb := bo.size() / maxi(1, v.size())
		var hb := {}
		var skin := peau.skin
		haut = -9.0
		zmin = 9.0
		zmax = -9.0
		xmax = 0.0
		for k in v.size():
			var wh := 0.0
			for j in nb:
				var bi := bo[k * nb + j]
				if not hb.has(bi):
					hb[bi] = Doigts.os_de(sq, skin, bi) == head
				if hb[bi]:
					wh += w[k * nb + j]
			if wh > 0.6 and v[k].y > o.y + 0.06:
				haut = maxf(haut, v[k].y)
				zmin = minf(zmin, v[k].z)
				zmax = maxf(zmax, v[k].z)
				xmax = maxf(xmax, absf(v[k].x))
	var ry := 0.100
	var c := Vector3(0.0, haut - ry, (zmin + minf(zmax, zmin + 0.21)) * 0.5 - 0.004)
	return {"c": c, "r": Vector3(xmax * 1.0, ry, (minf(zmax, zmin + 0.21) - zmin) * 0.5), "head": head}

## Point du crâne : θ autour de l'axe vertical (0 = devant, +z), φ depuis le sommet ; k : facteur de rayon (1 = peau).
static func _pt(cr: Dictionary, th: float, ph: float, k: float) -> Vector3:
	var r: Vector3 = cr["r"]
	return (cr["c"] as Vector3) + Vector3(r.x * sin(ph) * sin(th), r.y * cos(ph), r.z * sin(ph) * cos(th)) * k

## Lisière : φ de la naissance des cheveux selon θ (front haut, tempes, au-dessus des oreilles, nuque basse).
static func _lisiere(th: float) -> float:
	var t := (1.0 - cos(th)) * 0.5
	return lerpf(0.98, 2.25, t) + 0.10 * exp(-pow((absf(th) - 1.15) / 0.3, 2))

# ------------------------------------------------------------------------------------------------ construction
class Bati:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	## Bande (carte) le long d'un chemin : largeur `larg` (m), normale `dehors(p)`, u de u0 à u1, v de 0 (racine) à v1 (pointe) ; ombre
	## à la racine (couleur de sommet).
	func carte(pts: Array, larg: float, dehors: Callable, u0: float, u1: float, v1: float, ombre := 0.72) -> void:
		var n := pts.size()
		var base := v.size()
		for i in n:
			var p: Vector3 = pts[i]
			var t: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
			var nn: Vector3 = dehors.call(p)
			var cote := t.cross(nn).normalized()
			if cote.length() < 0.5:
				cote = Vector3.RIGHT
			var f := float(i) / (n - 1)
			var w := larg * (1.0 - 0.45 * f * f)
			var nn2 := cote.cross(t).normalized()
			if nn2.dot(nn) < 0.0:
				nn2 = -nn2
			for s in [-1.0, 1.0]:
				v.append(p + cote * (w * 0.5 * s))
				nrm.append(nn2)
				uv.append(Vector2(lerpf(u0, u1, (s + 1.0) * 0.5), v1 * f))
				var o := lerpf(ombre, 1.0, minf(1.0, f * 1.6))
				col.append(Color(o, o, o, 1.0))
		for i in n - 1:
			var a := base + i * 2
			idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])

	func mesh(sq: Skeleton3D, os_: int, mat: Material) -> MeshInstance3D:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = col
		var bo := PackedInt32Array()
		var w := PackedFloat32Array()
		for i in v.size():
			bo.append_array([os_, 0, 0, 0])
			w.append_array([1.0, 0.0, 0.0, 0.0])
		arr[Mesh.ARRAY_BONES] = bo
		arr[Mesh.ARRAY_WEIGHTS] = w
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		sq.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.skin = sq.create_skin_from_rest_transforms()
		return mi

static func _h(a: int, b: int, g: int) -> float:
	return RealismePnj._h(a, b, g)

static func _r(g: int, k: int, s: int) -> float:
	return RealismePnj._h(k, s, g)

## Chevelure complète de `coiffure` sur le squelette (nœud « chevelure »).
static func batir(sq: Skeleton3D, coiffure: String, poil: Color, femme: bool, g: int) -> MeshInstance3D:
	var cr := _crane(sq)
	var c: Vector3 = cr["c"]
	var b := Bati.new()
	var dehors := func(p: Vector3) -> Vector3: return (p - c).normalized()
	var dehors_h := func(p: Vector3) -> Vector3:
		var d := p - c
		d.y *= 0.25
		return d.normalized()
	# ---- calotte : grille θ x φ jusqu'à la lisière, mèches qui descendent (v vers la pointe), bord découpé
	var nt := 18
	var nph := 5
	var kc := 1.035 if coiffure != "rase" else 1.012
	if coiffure != "chauve":
		for i in nt:
			var t0 := -PI + TAU * float(i) / nt
			var t1 := -PI + TAU * float(i + 1) / nt
			var base := b.v.size()
			for j in nph + 1:
				var f := float(j) / nph
				for tt in [t0, t1]:
					var ph := _lisiere(tt) * f
					var p := _pt(cr, tt, ph, kc + 0.012 * sin(float(i * 7 + j * 3 + g)))
					b.v.append(p)
					b.nrm.append((p - c).normalized())
					b.uv.append(Vector2((0.125 if tt == t0 else 0.25) + float(i % 4) * 0.25, 0.08 + 0.86 * f if coiffure != "rase" else 0.05 + 0.55 * f))
					var o := 0.80 + 0.2 * f
					b.col.append(Color(o, o, o, 1.0))
			for j in nph:
				var a := base + j * 2
				b.idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	# ---- cartes
	match coiffure:
		"court", "rase":
			var n := 64 if coiffure == "court" else 0
			for k in n:
				var th := -PI + TAU * _r(g, k, 1)
				var lis := _lisiere(th)
				var ph0 := lis * (0.15 + 0.75 * _r(g, k, 2))
				var lg := 0.35 + 0.30 * _r(g, k, 3)
				var pts := []
				for i in 4:
					var f := float(i) / 3.0
					pts.append(_pt(cr, th + (_r(g, k, 4) - 0.5) * 0.35 * f, minf(ph0 + lg * f, lis + 0.08), 1.06 + 0.07 * f * f + 0.04 * _r(g, k, 5)))
				var u0 := float(k % 8) / 8.0
				b.carte(pts, 0.026 + 0.012 * _r(g, k, 6), dehors, u0, u0 + 0.125, 0.55)
		"chauve":
			# couronne : côtés et nuque (le sommet du crâne reste nu), mèches courtes
			for k in 34:
				var th := PI * (0.42 + 1.16 * _r(g, k, 1)) * (1.0 if k % 2 == 0 else -1.0)
				var lis := _lisiere(th)
				var ph0 := lis - 0.55 - 0.15 * _r(g, k, 2)
				var pts := []
				for i in 4:
					var f := float(i) / 3.0
					pts.append(_pt(cr, th, ph0 + (0.55 + 0.1 * _r(g, k, 3)) * f, 1.03 + 0.04 * f))
				var u0 := float(k % 8) / 8.0
				b.carte(pts, 0.03, dehors, u0, u0 + 0.125, 0.6)
		"long", "attache", "nattes", "chignon":
			# mèches peignées vers l'arrière : de la lisière (devant, côtés) et du sommet jusqu'au point de rassemblement
			var points_r := []
			if coiffure == "nattes":
				points_r = [_pt(cr, 2.25, 2.05, 1.06), _pt(cr, -2.25, 2.05, 1.06)]
			elif coiffure == "chignon":
				points_r = [_pt(cr, PI, 1.55, 1.08)]
			elif coiffure == "attache":
				points_r = [_pt(cr, PI, 1.95, 1.07)]
			var n := 40
			for k in n:
				var th := -PI + TAU * (float(k) + _r(g, k, 1) * 0.8) / n
				var lis := _lisiere(th)
				var ph0 := lis * (0.86 + 0.12 * _r(g, k, 2))     # lisière irrégulière
				if absf(th) > 2.2:
					ph0 = lis * (0.35 + 0.3 * _r(g, k, 2))   # nuque : les cartes partent plus haut
				var pts := []
				if coiffure == "long":
					# libres : peignées vers l'arrière (le devant ne retombe pas sur les yeux), puis retombent derrière et sur les côtés
					var tb := th
					if absf(th) < 1.6:
						tb = signf(th if th != 0.0 else 1.0) * lerpf(1.6, 2.6, 1.0 - absf(th) / 1.6)
					var bout := _pt(cr, tb, _lisiere(tb) + 0.1, 1.06)
					var chute := 0.05 + (0.20 if absf(th) > 1.9 else (0.10 if absf(th) > 1.2 else 0.0)) * (0.8 + 0.4 * _r(g, k, 3))
					for i in 4:
						var f := float(i) / 3.0
						pts.append(_pt(cr, lerpf(th, tb, f), lerpf(0.9 * lis if absf(th) < 1.6 else 0.3 * lis, _lisiere(tb) + 0.1, f), 1.06 + 0.04 * sin(f * PI)))
					pts.append(bout + Vector3(0, -chute * 0.5, 0) + (bout - c).normalized() * Vector3(1, 0, 1) * 0.015)
					pts.append(bout + Vector3(0, -chute, 0) + (bout - c).normalized() * Vector3(1, 0, 1) * 0.03)
					var u0 := float(k % 8) / 8.0
					b.carte(pts, 0.034 + 0.01 * _r(g, k, 6), dehors, u0, u0 + 0.125, 1.0)
					continue
				var cible: Vector3 = points_r[0]
				if points_r.size() == 2:
					# pas de raie nette au milieu : le devant part vers la nuque entre les deux nattes
					cible = points_r[0] if th > 0.0 else points_r[1]
					if absf(th) < 0.7:
						cible = (points_r[0] + points_r[1]) * 0.5 + Vector3((_r(g, k, 9) - 0.5) * 0.04, 0.0, 0.0)
				# chemin : de la racine (lisière) vers la cible, collé au crâne (interpolation puis projection sur la calotte)
				var r0 := _pt(cr, th, ph0, 1.04)
				for i in 6:
					var f := float(i) / 5.0
					var q := r0.lerp(cible, f)
					var d := (q - c)
					var r: Vector3 = cr["r"]
					var e := Vector3(d.x / r.x, d.y / r.y, d.z / r.z).length()
					q = c + d / maxf(e, 0.001) * (1.06 + (0.05 + 0.05 * _r(g, k, 8)) * sin(f * PI))     # volume (pas de casque plaqué)
					pts.append(q)
				var u0 := float(k % 8) / 8.0
				b.carte(pts, 0.032 + 0.012 * _r(g, k, 6), dehors, u0, u0 + 0.125, 0.9, 0.92)
			# mèches folles qui s'échappent aux tempes et sur la nuque (coiffures attachées)
			if coiffure != "long":
				for k in 6:
					var th := (0.9 + 0.5 * _r(g, k, 30)) * (1.0 if k % 2 == 0 else -1.0)
					if k >= 4:
						th = PI - 0.4 * (_r(g, k, 31) - 0.5)
					var r0 := _pt(cr, th, _lisiere(th) - 0.15, 1.06)
					var lg := 0.07 + 0.07 * _r(g, k, 32)
					var pts := [r0, r0 + Vector3(0, -lg * 0.5, 0) + (r0 - c).normalized() * 0.012, r0 + Vector3(0, -lg, 0) + (r0 - c).normalized() * 0.02]
					var u0 := float((k + 3) % 8) / 8.0
					b.carte(pts, 0.018, dehors_h, u0, u0 + 0.125, 0.8, 0.95)
			# queue, nattes, chignon
			match coiffure:
				"attache":
					var q0: Vector3 = points_r[0]
					for k in 5:
						var a := TAU * float(k) / 5.0
						var dec := Vector3(cos(a), 0, sin(a) * 0.4) * 0.012
						var pts := []
						for i in 5:
							var f := float(i) / 4.0
							pts.append(q0 + dec * (1.0 + f) + Vector3(0, -0.20 * f - (0.05 if femme else 0.0) * f, -0.035 * f + 0.02 * f * f))
						var u0 := float(k % 8) / 8.0
						var nq := Vector3(cos(a), 0, sin(a))
						b.carte(pts, 0.035, func(_p: Vector3) -> Vector3: return nq, u0, u0 + 0.125, 1.0, 0.6)
					# lien de cuir (anneau sombre)
					_anneau(b, q0 + Vector3(0, -0.02, -0.005), 0.016, 0.02)
				"nattes":
					for q0: Vector3 in points_r:
						_natte(b, q0, 0.24 if femme else 0.18, g)
				"chignon":
					var q0: Vector3 = points_r[0]
					for k in 8:
						var a := TAU * float(k) / 8.0
						var pts := []
						for i in 4:
							var f := float(i) / 3.0
							var ang := a + f * 2.2
							pts.append(q0 + Vector3(cos(ang) * 0.032, sin(ang) * 0.028, -0.025 - 0.01 * sin(f * PI)))
						var u0 := float(k % 8) / 8.0
						b.carte(pts, 0.03, func(p: Vector3) -> Vector3: return (p - q0 + Vector3(0, 0, -0.02)).normalized(), u0, u0 + 0.125, 0.5, 0.65)
	var mi := b.mesh(sq, int(cr["head"]), _materiau(poil))
	mi.name = "chevelure"
	return mi

## Natte : 7 tronçons de cartes croisées (deux plans à 90°, en quinconce) de la racine vers le bas, effilée, lien au bout.
static func _natte(b: Bati, q0: Vector3, lg: float, g: int) -> void:
	var n := 7
	for i in n:
		var f0 := float(i) / n
		var f1 := float(i + 1) / n
		var p0 := q0 + Vector3(0, -lg * f0, -0.015 * f0)
		var p1 := q0 + Vector3(0, -lg * f1, -0.015 * f1)
		var larg := 0.030 * (1.0 - 0.35 * f0)
		var ax := Vector3(1, 0, 1).normalized() if i % 2 == 0 else Vector3(1, 0, -1).normalized()
		var u0 := float((i + g) % 8) / 8.0
		b.carte([p0, (p0 + p1) * 0.5 + Vector3(0, 0, 0.004), p1], larg, func(_p: Vector3) -> Vector3: return ax.cross(Vector3.UP).normalized(), u0, u0 + 0.125, 0.35, 0.7)
		b.carte([p0, (p0 + p1) * 0.5 - Vector3(0, 0, 0.004), p1], larg * 0.9, func(_p: Vector3) -> Vector3: return ax, u0, u0 + 0.125, 0.35, 0.7)
	_anneau(b, q0 + Vector3(0, -lg + 0.01, -0.015), 0.011, 0.015)

## Petit anneau sombre (lien) : 6 côtés, texels sombres de la racine (v = 0).
static func _anneau(b: Bati, p: Vector3, r: float, h: float) -> void:
	var base := b.v.size()
	for i in 7:
		var a := TAU * float(i) / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		for y in [h * 0.5, -h * 0.5]:
			b.v.append(p + d * r + Vector3(0, y, 0))
			b.nrm.append(d)
			b.uv.append(Vector2(0.06, 0.01))
			b.col.append(Color(0.35, 0.30, 0.27, 1.0))
	for i in 6:
		var a := base + i * 2
		b.idx.append_array([a, a + 2, a + 3, a, a + 3, a + 1])

## Matériau des mèches : shader des personnages double face, découpe, sans contour ; texture dans la couleur du poil.
static func _materiau(poil: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GuerrierNordique.shader(true)
	m.set_shader_parameter("tex_base", texture(poil))
	m.set_shader_parameter("decoupe", true)
	m.set_shader_parameter("contour_froid", Vector3(0.08, 0.10, 0.14))
	m.set_shader_parameter("ombre_froide", Vector3(0.34, 0.36, 0.44))
	m.set_shader_parameter("rehaut", 0.5)
	m.set_shader_parameter("saturation", 0.85)
	Palette.suivre(m)
	Palette._appliquer(m, Palette._ps1_actif)
	return m

## Atlas des mèches (64 x 128, 8 colonnes de 8 texels, racine en haut) : 3 à 4 brins par colonne, racine sombre, reflets, pointes
## effilées de longueurs inégales (alpha 0 au-delà : bord découpé).
static func texture(poil: Color) -> ImageTexture:
	var cle := poil.to_html()
	_mx.lock()
	var t: ImageTexture = _tex.get(cle)
	_mx.unlock()
	if t != null:
		return t
	var img := Image.create(TW, TH, false, Image.FORMAT_RGBA8)
	img.fill(Color(poil.r * 0.5, poil.g * 0.5, poil.b * 0.5, 0.0))
	var sombre := Color(poil.r * 0.45, poil.g * 0.42, poil.b * 0.40)
	var clair := Color(minf(1.0, poil.r * 1.30 + 0.03), minf(1.0, poil.g * 1.28 + 0.03), minf(1.0, poil.b * 1.25 + 0.03))
	for col in 8:
		var ox := col * 8
		var nb := 3 + col % 2
		for s in nb:
			var x0 := 0.8 + (6.4 / nb) * (s + 0.5) + (_h(col, s, 71) - 0.5) * 1.2
			var lg := 0.78 + 0.22 * _h(col, s, 72)
			var derive := (_h(col, s, 73) - 0.5) * 2.4
			var larg := 1.4 + 1.2 * _h(col, s, 74)
			var ton := 0.85 + 0.3 * _h(col, s, 75)
			for y in TH:
				var f := float(y) / TH
				if f > lg:
					break
				var t2 := f / lg
				var cx := x0 + derive * t2 * t2 + sin(f * 9.0 + s) * 0.35
				var demi := larg * 0.5 * (1.0 - smoothstep(0.65, 1.0, t2) * 0.85)
				for x in range(int(floorf(cx - demi)), int(ceilf(cx + demi))):
					if x < 0 or x > 7:
						continue
					var c := poil * ton
					var bord := absf(x + 0.5 - cx) / maxf(demi, 0.5)
					if bord > 0.6:
						c = c.lerp(sombre, 0.45)
					if x == int(floorf(cx - demi)) + 1 and _h(x + ox, y / 3, 76) > 0.45:
						c = c.lerp(clair, 0.55)          # brin qui accroche la lumière
					if _h(x + ox, y, 77) > 0.86:
						c = c.lerp(sombre, 0.35)
					if f < 0.04:
						c = c.lerp(sombre, 0.35 * (1.0 - f / 0.04))   # racine dans l'ombre de la chevelure
					c.a = 1.0
					img.set_pixel(ox + x, y, c)
		# fond de la colonne (sous les brins) : sombre et opaque près de la racine, pour la calotte
		for y in int(TH * 0.55):
			for x in 8:
				if img.get_pixel(ox + x, y).a < 0.5:
					var c2 := sombre.lerp(poil * 0.8, _h(ox + x, y, 78) * 0.5)
					c2.a = 1.0
					img.set_pixel(ox + x, y, c2)
	img.generate_mipmaps()
	t = ImageTexture.create_from_image(img)
	_mx.lock()
	_tex[cle] = t
	_mx.unlock()
	return t

## Barbe (maillage Hair_Beard gardé) : repeinte en brins de la couleur du poil, sans contour.
static func barbe(mi: MeshInstance3D, poil: Color, g: int) -> void:
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var brin := RealismePnj.bruit(x * 4, y, 128, 64, 32, 6, g + 91)
			var f := 0.62 + 0.55 * brin + (_h(x, y, g + 92) - 0.5) * 0.18
			var c := poil * f
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = GuerrierNordique.shader(true)
	m.set_shader_parameter("tex_base", ImageTexture.create_from_image(img))
	m.set_shader_parameter("contour_froid", Vector3(0.08, 0.10, 0.14))
	m.set_shader_parameter("ombre_froide", Vector3(0.34, 0.36, 0.44))
	Palette.suivre(m)
	Palette._appliquer(m, Palette._ps1_actif)
	mi.material_override = m
