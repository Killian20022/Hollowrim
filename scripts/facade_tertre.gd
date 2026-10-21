class_name FacadeTertre
## Lot 5, 2e passe : façade du tertre en pierre taillée irrégulière (au lieu de quatre boîtes) : deux pierres levées
## effilées, linteau en bloc chanfreiné chargé de neige, jambages et assises de pierre autour de la porte, seuil
## de dalles, dalle de porte enfoncée. Les COLLISIONS sont celles d'origine (mêmes boîtes) : seul l'habillage change.

static func _mesh(parent: Node3D, m: BatiGeo.Maillage, pos: Vector3, mat: Material, lacet := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m.mesh()
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, lacet), pos)
	parent.add_child(mi)

static func _collision(corps: StaticBody3D, taille: Vector3, pos: Vector3) -> void:
	var bs := BoxShape3D.new()
	bs.size = taille
	var cs := CollisionShape3D.new()
	cs.shape = bs
	corps.add_child(cs)
	cs.transform = Transform3D(Basis(), pos)

static func construire(parent: Node3D, corps: StaticBody3D, m_facade: Material, m_dalle: Material) -> void:
	# deux pierres levées de part et d'autre de la porte (collision d'origine : 0,8 × 3,0 × 0,8)
	for x in [-1.3, 1.3]:
		_mesh(parent, BatiGeo.pierre_levee(Vector3(0.8, 3.0, 0.8), 910 + int(x * 10.0)), Vector3(x, 1.3, -0.4), m_facade, 0.2 * signf(x))
		_collision(corps, Vector3(0.8, 3.0, 0.8), Vector3(x, 1.3, -0.4))
		# assises de pierre qui calent le pied et jambage extérieur
		for i in 2:
			_mesh(parent, BatiGeo.bloc(Vector3(1.0 - i * 0.18, 0.4, 0.95), 920 + i + int(x * 4.0), 0.2, 0.08, 0.3), Vector3(x * (1.0 + 0.04 * i) + signf(x) * 0.12, -0.05 + i * 0.36, -0.35), m_facade, 0.1 * i * signf(x))
	# linteau : grosse dalle posée sur les deux pierres (collision d'origine : 3,6 × 0,7 × 1,0)
	_mesh(parent, BatiGeo.bloc(Vector3(3.7, 0.72, 1.05), 931, 0.12, 0.03, 1.0, 0.8), Vector3(0, 3.0, -0.4), m_facade)
	_collision(corps, Vector3(3.6, 0.7, 1.0), Vector3(0, 3.0, -0.4))
	# cales de pierre entre linteau et piliers
	for x in [-1.75, 1.75]:
		_mesh(parent, BatiGeo.bloc(Vector3(0.5, 0.36, 0.7), 940 + int(x * 3.0), 0.2, 0.08, 0.5), Vector3(x, 2.62, -0.4), m_facade)
	# dalle de porte enfoncée (collision d'origine : 1,9 × 2,6 × 0,2)
	_mesh(parent, BatiGeo.bloc(Vector3(1.9, 2.6, 0.2), 950, 0.06, 0.02, 0.0, 0.8), Vector3(0, 1.2, -0.75), m_dalle)
	_collision(corps, Vector3(1.9, 2.6, 0.2), Vector3(0, 1.2, -0.75))
	# seuil : trois dalles posées (visuel seul : 8 cm de haut, la montée reste franchissable)
	for k in 3:
		_mesh(parent, BatiGeo.bloc(Vector3(0.95, 0.1, 0.8), 960 + k, 0.25, 0.08, 0.4), Vector3(-0.95 + k * 0.95, 0.0, 0.25), m_facade, 0.06 * (k - 1))
	_monumental(parent, corps, m_facade, m_dalle)

# --- Refonte crypte (référence « entrée de crypte bleue ») : façade sculptée monumentale -----------------------
## Mur appareillé qui sort de la butte, fronton à panneau d'entrelacs, pilastres sculptés coiffés de neige,
## glaçons sous le linteau et le fronton, escalier de dalles, pierres levées gravées le long de l'allée,
## sceau cyan sur la dalle de porte et lueur bleue au fond. Collisions d'origine inchangées ; les seules
## collisions ajoutées sont celles des pilastres et des pierres levées de l'allée (hors du passage de 2,6 m).

const RUNE_CYAN := Color(0.25, 0.82, 0.82)

static func _ajoute(dst: BatiGeo.Maillage, src: BatiGeo.Maillage, xf: Transform3D) -> void:
	for i in src.v.size():
		dst.v.append(xf * src.v[i])
		dst.n.append((xf.basis * src.n[i]).normalized())
		dst.c.append(src.c[i])
		dst.uv.append(src.uv[i])

## Panneau plat (UV 0..1) : centre, normale horizontale `vers`, largeur, hauteur, rotation dans son plan.
static func _panneau(dst: BatiGeo.Maillage, centre: Vector3, vers: Vector3, l: float, h: float, rot := 0.0) -> void:
	var nn := vers.normalized()
	var dr := Vector3.UP.cross(nn).normalized()
	var up := Vector3.UP
	var b := Basis(nn, rot)
	dr = b * dr
	up = b * up
	var p := [centre - dr * l * 0.5 - up * h * 0.5, centre + dr * l * 0.5 - up * h * 0.5, centre + dr * l * 0.5 + up * h * 0.5, centre - dr * l * 0.5 + up * h * 0.5]
	var u := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k: Array in [[0, 1, 2], [0, 2, 3]]:
		for i: int in k:
			dst.v.append(p[i])
			dst.n.append(nn)
			dst.c.append(Color.WHITE)
			dst.uv.append(u[i])
	# l'ordre (0,1,2) donne une normale -nn avec dr×up : on retourne si besoin
	var a: Vector3 = dst.v[dst.v.size() - 6]
	var bb: Vector3 = dst.v[dst.v.size() - 5]
	var cc: Vector3 = dst.v[dst.v.size() - 4]
	if (cc - a).cross(bb - a).dot(nn) < 0.0:
		var s := dst.v.size() - 6
		for t in 2:
			var i0 := s + t * 3
			var tv: Vector3 = dst.v[i0 + 1]
			dst.v[i0 + 1] = dst.v[i0 + 2]
			dst.v[i0 + 2] = tv
			var tu: Vector2 = dst.uv[i0 + 1]
			dst.uv[i0 + 1] = dst.uv[i0 + 2]
			dst.uv[i0 + 2] = tu

## Glaçon : pyramide à 4 pans, pointe en bas.
static func _glacon(dst: BatiGeo.Maillage, haut: Vector3, longueur: float, r: float) -> void:
	var pointe := haut - Vector3(0, longueur, 0)
	var q: Array = []
	for k in 4:
		var a := PI * 0.5 * k + 0.4
		q.append(haut + Vector3(cos(a) * r, 0, sin(a) * r))
	var cg := haut - Vector3(0, longueur * 0.3, 0)
	for k in 4:
		dst.tri(q[k], q[(k + 1) % 4], pointe, Color.WHITE, Color.WHITE, Color(0.8, 0.85, 0.9), cg, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))

static func _rangee_glacons(dst: BatiGeo.Maillage, a: Vector3, b: Vector3, nb: int, lmax: float, graine: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for i in nb:
		var t := (float(i) + rng.randf_range(0.15, 0.85)) / float(nb)
		var l := lmax * rng.randf_range(0.25, 1.0)
		if rng.randf() < 0.25:
			l *= 0.35
		_glacon(dst, a.lerp(b, t), l, clampf(l * 0.11, 0.025, 0.07))

static func _boite_col(corps: StaticBody3D, taille: Vector3, pos: Vector3) -> void:
	_collision(corps, taille, pos)

static func _monumental(parent: Node3D, corps: StaticBody3D, m_facade: Material, _m_dalle: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	var pierre := BatiGeo.Maillage.new()
	var panneaux := BatiGeo.Maillage.new()
	var glace := BatiGeo.Maillage.new()
	# 1) mur appareillé derrière les pierres levées (z ≈ -1,05) : assises irrégulières, ouverture de porte réservée
	var y := -0.3
	var rang := 0
	var hauts := [0.62, 0.5, 0.58, 0.46, 0.6, 0.52, 0.56, 0.5]
	while y < 4.3:
		var hr: float = hauts[rang % hauts.size()]
		var demi := 3.6 if y < 3.4 else (2.9 if y < 3.9 else 2.1)
		var x := -demi - rng.randf_range(0.0, 0.5) * float(rang % 2)
		while x < demi:
			var w := rng.randf_range(0.65, 1.25)
			w = minf(w, demi - x + 0.05)
			if w < 0.3:
				break
			var cx := x + w * 0.5
			var cy := y + hr * 0.5
			if not (absf(cx) < 1.8 and cy < 2.75):
				var b := BatiGeo.bloc(Vector3(w - 0.04, hr - 0.04, 0.55 + rng.randf_range(0.0, 0.12)), 7400 + rang * 37 + int(x * 10.0), 0.14, 0.035, 0.85 if cy > 3.2 else 0.15)
				_ajoute(pierre, b, Transform3D(Basis(), Vector3(cx, cy, -1.08 + rng.randf_range(-0.03, 0.03))))
			x += w
		y += hr
		rang += 1
	# 2) fronton : dalle pointue (pentagone) portant un panneau d'entrelacs en losange, cadre de blocs
	var fr := BatiGeo.bloc(Vector3(1.9, 1.5, 0.5), 7501, 0.1, 0.02, 0.0)
	_ajoute(pierre, fr, Transform3D(Basis(), Vector3(0, 4.05, -0.72)))
	var pointe := BatiGeo.bloc(Vector3(1.25, 1.25, 0.46), 7502, 0.08, 0.02, 1.0)
	_ajoute(pierre, pointe, Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), Vector3(0, 4.85, -0.74)))
	_panneau(panneaux, Vector3(0, 4.25, -0.455), Vector3(0, 0, 1), 1.3, 1.3, PI * 0.25)
	for sx: float in [-1.0, 1.0]:      # rampants du fronton
		var r := BatiGeo.bloc(Vector3(1.5, 0.3, 0.55), 7510 + int(sx), 0.12, 0.03, 1.0)
		_ajoute(pierre, r, Transform3D(Basis(Vector3(0, 0, 1), -sx * 0.62), Vector3(sx * 0.95, 4.75, -0.7)))
	# 3) pilastres sculptés de part et d'autre (collisions ajoutées : hors du passage)
	for sx: float in [-1.0, 1.0]:
		var px := sx * 2.6
		var hp := 0.0
		var k := 0
		for hb: float in [0.7, 1.05, 1.05, 0.95, 0.6]:
			var lb := 0.98 if k == 0 or k == 4 else 0.86
			var b := BatiGeo.bloc(Vector3(lb, hb - 0.03, lb), 7600 + k + int(sx * 50.0), 0.12, 0.025, 1.0 if k == 4 else 0.0)
			_ajoute(pierre, b, Transform3D(Basis(), Vector3(px, hp - 0.4 + hb * 0.5, -0.55)))
			hp += hb
			k += 1
		_panneau(panneaux, Vector3(px, 1.75, -0.105), Vector3(0, 0, 1), 0.66, 0.66 * 2.0, 0.0)
		_collision(corps, Vector3(0.9, 4.0, 0.9), Vector3(px, 1.6, -0.55))
		# glaçons sous le chapiteau
		_rangee_glacons(glace, Vector3(px - 0.45, hp - 0.4 - 0.6, -0.04), Vector3(px + 0.45, hp - 0.4 - 0.6, -0.04), 4, 0.5, 7650 + int(sx))
	# 4) glaçons sous le linteau et sous le fronton
	_rangee_glacons(glace, Vector3(-1.8, 2.66, 0.08), Vector3(1.8, 2.66, 0.08), 13, 0.75, 7700)
	_rangee_glacons(glace, Vector3(-0.9, 3.32, -0.42), Vector3(0.9, 3.32, -0.42), 6, 0.35, 7701)
	_rangee_glacons(glace, Vector3(-3.5, 3.38, -0.78), Vector3(-1.9, 3.38, -0.78), 5, 0.55, 7702)
	_rangee_glacons(glace, Vector3(1.9, 3.38, -0.78), Vector3(3.5, 3.38, -0.78), 5, 0.55, 7703)
	# 5) escalier de dalles devant le seuil (visuel : 8 cm, franchissable) ; contremarches enterrées
	for s in 5:
		var z := 1.05 + s * 0.85
		var yt := 0.07 - 0.0 * s
		for c in 3:
			var w := 0.95 + rng.randf_range(-0.12, 0.12)
			var b := BatiGeo.bloc(Vector3(w, 0.6, 0.8), 7800 + s * 5 + c, 0.18, 0.05, 0.0, 0.45)
			_ajoute(pierre, b, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), Vector3(-0.98 + c * 0.98, yt - 0.3, z)))
	# 6) pierres levées gravées le long de l'allée (deux paires), enterrées de 0,8 m ; collisions ajoutées
	var i := 0
	for z: float in [3.0, 5.8]:
		for sx: float in [-1.0, 1.0]:
			var hs := 2.3 if z < 4.0 else 1.7
			var b := BatiGeo.bloc(Vector3(0.72, hs + 0.8, 0.5), 7900 + i, 0.12, 0.04, 1.0)
			var pos := Vector3(sx * 2.45, (hs + 0.8) * 0.5 - 0.8, z)
			var lacet := sx * 0.18 + rng.randf_range(-0.05, 0.05)
			var xf := Transform3D(Basis(Vector3.UP, lacet), pos)
			_ajoute(pierre, b, xf)
			_panneau(panneaux, xf * Vector3(0, 0.25 + hs * 0.08, 0.262), xf.basis * Vector3(0, 0, 1), 0.56, minf(hs * 0.62, 1.2))
			_collision(corps, Vector3(0.72, hs + 0.8, 0.5), pos)
			i += 1
	# maillages
	_mesh(parent, pierre, Vector3.ZERO, m_facade)
	var img: Image = ResourceLoader.load("res://assets/crypte/entrelacs.res") if ResourceLoader.exists("res://assets/crypte/entrelacs.res") else null
	if img:
		var m_ent := Palette.materiau(ImageTexture.create_from_image(img) if img.has_mipmaps() else CrypteTextures._mips(img), Vector2.ONE, Color(0.78, 0.8, 0.86))
		_mesh(parent, panneaux, Vector3.ZERO, m_ent)
	var m_glace := Palette.materiau(Palette.tex("glacons_tertre", ["#29354a", "#33577f", "#4f86ae", "#86bfd3"], 2, 0.3), Vector2.ONE, Color(0.85, 0.92, 1.0))
	_mesh(parent, glace, Vector3.ZERO, m_glace)
	# 7) sceau cyan gravé sur la dalle de porte + lueur bleue au fond de la porte
	var sceau := BatiGeo.Maillage.new()
	var zc := -0.64
	for r: float in [0.42, 0.24]:
		for k in 4:
			var a0 := PI * 0.5 * k
			var a1 := PI * 0.5 * (k + 1)
			var q0 := Vector3(cos(a0) * r, 1.72 + sin(a0) * r, zc)
			var q1 := Vector3(cos(a1) * r, 1.72 + sin(a1) * r, zc)
			var d := (q1 - q0).normalized()
			var e := Vector3(-d.y, d.x, 0) * 0.025
			sceau.quad(q0 - e, q1 - e, q1 + e, q0 + e, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector3(0, 1.72, zc - 1.0))
	sceau.quad(Vector3(-0.025, 1.3, zc), Vector3(0.025, 1.3, zc), Vector3(0.025, 2.15, zc), Vector3(-0.025, 2.15, zc), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector3(0, 1.72, zc - 1.0))
	_mesh(parent, sceau, Vector3.ZERO, Palette.lueur(RUNE_CYAN))
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.35, 0.8, 1.0)
	lueur.light_energy = 0.7
	lueur.omni_range = 3.6
	lueur.omni_attenuation = 1.5
	lueur.position = Vector3(0, 1.2, 0.2)
	parent.add_child(lueur)
