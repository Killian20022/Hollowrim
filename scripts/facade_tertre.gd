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
	# 2e passe : porte OUVERTE sur un couloir sombre (voir _monumental) ; la collision d'origine de la dalle reste
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
	var roc := BatiGeo.Maillage.new()
	var tunnel := BatiGeo.Maillage.new()
	var panneaux := BatiGeo.Maillage.new()
	var glace := BatiGeo.Maillage.new()
	# 1) PAROI ROCHEUSE taillée (8 m au centre, 3,5 m aux ailes) dans laquelle la façade est encastrée
	var x := -8.4
	var ib := 0
	while x < 8.4:
		var w := rng.randf_range(1.7, 2.8)
		var cx := x + w * 0.5
		var htot := 8.4 - 0.58 * absf(cx) + rng.randf_range(-0.5, 0.5)
		var yb := -0.6
		var zf := (-1.55 if absf(cx) < 3.6 else -0.9) - rng.randf_range(0.0, 0.6) - 0.05 * absf(cx)
		while yb < htot - 0.3:
			var hb := minf(rng.randf_range(1.8, 2.9), htot - yb)
			var centre_bas := absf(cx) < 3.6 and yb < 3.2
			if not centre_bas:
				var dep := 5.2
				var b := BatiGeo.bloc(Vector3(w + 0.15, hb + 0.1, dep), 8100 + ib, 0.22, 0.09, 1.0 if yb + hb >= htot - 0.31 else 0.25, 0.55)
				_ajoute(roc, b, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)), Vector3(cx, yb + hb * 0.5, zf - dep * 0.5 + rng.randf_range(-0.2, 0.2))))
				# corniches de neige / glaçons sous les ressauts
				if rng.randf() < 0.6:
					_rangee_glacons(glace, Vector3(cx - w * 0.4, yb - 0.05, zf + 0.05), Vector3(cx + w * 0.4, yb - 0.05, zf + 0.05), 6, 0.9, 8300 + ib)
			yb += hb
			ib += 1
		x += w
	# masses de collision de la paroi (hors du passage)
	for sx: float in [-1.0, 1.0]:
		_collision(corps, Vector3(5.0, 6.0, 6.4), Vector3(sx * 5.8, 2.4, -4.2))
	# 2) FRONTISPICE : mur appareillé jusqu'à 5,2 m, ouverture de porte réservée
	var y := -0.3
	var rang := 0
	var hauts := [0.62, 0.5, 0.58, 0.46, 0.6, 0.52, 0.56, 0.5]
	while y < 5.2:
		var hr: float = hauts[rang % hauts.size()]
		var demi := 3.4
		var xx := -demi - rng.randf_range(0.0, 0.5) * float(rang % 2)
		while xx < demi:
			var w := minf(rng.randf_range(0.65, 1.25), demi - xx + 0.05)
			if w < 0.3:
				break
			var cx := xx + w * 0.5
			var cy := y + hr * 0.5
			if not (absf(cx) < 1.8 and cy < 2.75):
				var b := BatiGeo.bloc(Vector3(w - 0.04, hr - 0.04, 0.55 + rng.randf_range(0.0, 0.12)), 7400 + rang * 37 + int(xx * 10.0), 0.14, 0.035, 0.0)
				_ajoute(pierre, b, Transform3D(Basis(), Vector3(cx, cy, -1.08 + rng.randf_range(-0.03, 0.03))))
			xx += w
		y += hr
		rang += 1
	# entablement + glaçons
	_ajoute(pierre, BatiGeo.bloc(Vector3(7.4, 0.55, 1.0), 7480, 0.1, 0.02, 1.0), Transform3D(Basis(), Vector3(0, 5.42, -0.72)))
	_ajoute(pierre, BatiGeo.bloc(Vector3(7.0, 0.22, 0.85), 7481, 0.1, 0.02, 0.0), Transform3D(Basis(), Vector3(0, 5.05, -0.74)))
	_rangee_glacons(glace, Vector3(-3.6, 5.12, -0.24), Vector3(3.6, 5.12, -0.24), 26, 1.1, 7482)
	# 3) FRONTON pointu : remplissage en assises décroissantes, rampants enneigés, grand losange sculpté
	var yy := 5.7
	var lg := 6.2
	var k := 0
	while lg > 0.8:
		_ajoute(pierre, BatiGeo.bloc(Vector3(lg, 0.5, 0.5), 7490 + k, 0.1, 0.03, 0.0), Transform3D(Basis(), Vector3(0, yy + 0.25, -0.98)))
		yy += 0.5
		lg -= 1.45
		k += 1
	for sx: float in [-1.0, 1.0]:
		var ang := atan2(2.3, 3.3)
		var r := BatiGeo.bloc(Vector3(4.15, 0.42, 0.75), 7510 + int(sx), 0.12, 0.03, 1.0)
		_ajoute(pierre, r, Transform3D(Basis(Vector3(0, 0, 1), -sx * ang), Vector3(sx * 1.62, 6.82, -0.8)))
		_rangee_glacons(glace, Vector3(sx * 3.2, 5.85, -0.45), Vector3(sx * 0.35, 7.8, -0.45), 9, 0.5, 7520 + int(sx))
	_ajoute(pierre, BatiGeo.bloc(Vector3(1.75, 1.75, 0.46), 7502, 0.06, 0.015, 0.0), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), Vector3(0, 6.55, -0.72)))
	_panneau(panneaux, Vector3(0, 6.55, -0.485), Vector3(0, 0, 1), 1.75, 1.75, PI * 0.25)
	# 4) COLONNES à entrelacs (5,6 m) de part et d'autre, chapiteaux enneigés, glaçons
	for sx: float in [-1.0, 1.0]:
		var px := sx * 2.75
		var hp := 0.0
		var kk := 0
		for hb: float in [0.7, 1.0, 1.0, 1.0, 1.0, 0.55, 0.45]:
			var lb := 1.12 if kk == 0 or kk >= 5 else 0.96
			var b := BatiGeo.bloc(Vector3(lb, hb - 0.03, lb), 7600 + kk + int(sx * 50.0), 0.1, 0.02, 1.0 if kk == 6 else 0.0)
			_ajoute(pierre, b, Transform3D(Basis(), Vector3(px, hp - 0.4 + hb * 0.5, -0.55)))
			hp += hb
			kk += 1
		for yc: float in [1.55, 3.35]:
			_panneau(panneaux, Vector3(px, yc, -0.065), Vector3(0, 0, 1), 0.74, 1.5, 0.0)
		_collision(corps, Vector3(1.0, 5.6, 1.0), Vector3(px, 2.4, -0.55))
		_rangee_glacons(glace, Vector3(px - 0.5, 4.35, 0.02), Vector3(px + 0.5, 4.35, 0.02), 5, 0.7, 7650 + int(sx))
	# 5) glaçons sous le linteau d'origine
	_rangee_glacons(glace, Vector3(-1.8, 2.66, 0.08), Vector3(1.8, 2.66, 0.08), 14, 0.7, 7700)
	# 6) CASCADES GELÉES sur la paroi, de part et d'autre
	for sx: float in [-1.0, 1.0]:
		var gx := sx * 4.7
		var rc := RandomNumberGenerator.new()
		rc.seed = 7750 + int(sx)
		for i in 26:
			var hx := gx + rc.randf_range(-0.75, 0.75)
			var top := rc.randf_range(3.0, 6.6) - absf(hx - gx) * 0.8
			var l := rc.randf_range(1.2, top + 0.2)
			_glacon(glace, Vector3(hx, top, -0.85 + rc.randf_range(-0.25, 0.1)), l, rc.randf_range(0.12, 0.3))
		var pied := BatiGeo.bloc(Vector3(2.0, 0.7, 1.4), 7760 + int(sx), 0.35, 0.12, 0.0)
		_ajoute(glace, pied, Transform3D(Basis(), Vector3(gx, 0.0, -0.6)))
	# 7) COULOIR OUVERT, sombre, lueur bleue au fond
	var zt := -7.0
	_ajoute(tunnel, BatiGeo.bloc(Vector3(2.3, 0.2, -zt), 7800, 0.02, 0.01, 0.0), Transform3D(Basis(), Vector3(0, -0.12, zt * 0.5 - 0.3)))
	_ajoute(tunnel, BatiGeo.bloc(Vector3(2.3, 0.3, -zt), 7801, 0.02, 0.01, 0.0), Transform3D(Basis(), Vector3(0, 2.78, zt * 0.5 - 0.3)))
	for sx: float in [-1.0, 1.0]:
		_ajoute(tunnel, BatiGeo.bloc(Vector3(0.3, 2.8, -zt), 7802 + int(sx), 0.02, 0.01, 0.0), Transform3D(Basis(), Vector3(sx * 1.1, 1.3, zt * 0.5 - 0.3)))
	var zz := -1.6
	var ia := 0
	while zz > zt + 0.8:      # doubleaux et jambages à l'intérieur : rythme qui creuse la profondeur
		for sx: float in [-1.0, 1.0]:
			_ajoute(tunnel, BatiGeo.bloc(Vector3(0.22, 2.6, 0.4), 7820 + ia, 0.08, 0.02, 0.0), Transform3D(Basis(), Vector3(sx * 0.88, 1.25, zz)))
		_ajoute(tunnel, BatiGeo.bloc(Vector3(2.0, 0.3, 0.4), 7840 + ia, 0.08, 0.02, 0.0), Transform3D(Basis(), Vector3(0, 2.48, zz)))
		zz -= 1.35
		ia += 1
	_ajoute(tunnel, BatiGeo.bloc(Vector3(2.3, 3.0, 0.3), 7860, 0.02, 0.01, 0.0), Transform3D(Basis(), Vector3(0, 1.3, zt - 0.1)))
	# 8) PERRON : plate-forme et deux marches de 15 cm qui montent à la porte (collisions ajoutées, franchissables)
	var marches := [[0.45, -0.7, 0.9], [0.3, 0.9, 1.75], [0.15, 1.75, 2.6]]
	var im := 0
	for mc: Array in marches:
		var top: float = mc[0]
		var z0: float = mc[1]
		var z1: float = mc[2]
		var xs := -1.9
		while xs < 1.9:
			var w := minf(rng.randf_range(0.8, 1.3), 1.9 - xs)
			var b := BatiGeo.bloc(Vector3(w - 0.03, top + 0.6, z1 - z0 - 0.03), 7900 + im, 0.08, 0.02, 0.0, 0.5)
			_ajoute(pierre, b, Transform3D(Basis(), Vector3(xs + w * 0.5, top - (top + 0.6) * 0.5, (z0 + z1) * 0.5)))
			xs += w
			im += 1
		_collision(corps, Vector3(3.8, top + 0.6, z1 - z0), Vector3(0, top - (top + 0.6) * 0.5, (z0 + z1) * 0.5))
	# 9) ALLÉE de pierres levées gravées (trois paires), enterrées de 0,8 m ; collisions ajoutées
	var i := 0
	for zs: float in [3.6, 6.0]:          # pas plus loin : le cercle runique commence à ~7,5 m de la porte
		for sx: float in [-1.0, 1.0]:
			var hs := 3.0 if zs < 5.0 else 2.3
			var b := BatiGeo.bloc(Vector3(0.85, hs + 0.8, 0.55), 7950 + i, 0.12, 0.04, 1.0)
			var pos := Vector3(sx * (2.7 + 0.35 * float(i / 2)), (hs + 0.8) * 0.5 - 0.8, zs)
			var xf := Transform3D(Basis(Vector3.UP, sx * 0.2 + rng.randf_range(-0.05, 0.05)), pos)
			_ajoute(pierre, b, xf)
			_panneau(panneaux, xf * Vector3(0, 0.3 + hs * 0.06, 0.287), xf.basis * Vector3(0, 0, 1), 0.66, minf(hs * 0.62, 1.6))
			_collision(corps, Vector3(0.85, hs + 0.8, 0.55), pos)
			i += 1
	# maillages
	_mesh(parent, pierre, Vector3.ZERO, m_facade)
	_mesh(parent, roc, Vector3.ZERO, TexturesPetites.m_roche_e(Color(0.72, 0.72, 0.78)))
	_mesh(parent, tunnel, Vector3.ZERO, TexturesPetites.m_roche_e(Color(0.2, 0.21, 0.27)))
	var img: Image = ResourceLoader.load("res://assets/crypte/entrelacs.res") if ResourceLoader.exists("res://assets/crypte/entrelacs.res") else null
	if img:
		var m_ent := Palette.materiau(ImageTexture.create_from_image(img) if img.has_mipmaps() else CrypteTextures._mips(img), Vector2.ONE, Color(0.8, 0.82, 0.88))
		_mesh(parent, panneaux, Vector3.ZERO, m_ent)
	var m_glace := Palette.materiau(Palette.tex("glacons_tertre2", ["#34404f", "#4f6578", "#7891a3", "#a9bfcc", "#cfdde3"], 2, 0.3), Vector2.ONE, Color(0.9, 0.94, 1.0))
	_mesh(parent, glace, Vector3.ZERO, m_glace)
	# sceau cyan et porte-lueur au fond du couloir
	var fond := BatiGeo.Maillage.new()
	var zc := zt + 0.07
	fond.quad(Vector3(-0.7, 0.0, zc), Vector3(0.7, 0.0, zc), Vector3(0.7, 2.2, zc), Vector3(-0.7, 2.2, zc), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector3(0, 1.1, zc - 1.0))
	_mesh(parent, fond, Vector3.ZERO, Palette.lueur(Color(0.07, 0.2, 0.3)))
	var sceau := BatiGeo.Maillage.new()
	zc += 0.02
	for rr: float in [0.5, 0.28]:
		for kq in 4:
			var a0 := PI * 0.5 * kq
			var a1 := PI * 0.5 * (kq + 1)
			var q0 := Vector3(cos(a0) * rr, 1.25 + sin(a0) * rr, zc)
			var q1 := Vector3(cos(a1) * rr, 1.25 + sin(a1) * rr, zc)
			var dd := (q1 - q0).normalized()
			var e := Vector3(-dd.y, dd.x, 0) * 0.03
			sceau.quad(q0 - e, q1 - e, q1 + e, q0 + e, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector3(0, 1.25, zc - 1.0))
	sceau.quad(Vector3(-0.03, 0.6, zc), Vector3(0.03, 0.6, zc), Vector3(0.03, 1.9, zc), Vector3(-0.03, 1.9, zc), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector3(0, 1.25, zc - 1.0))
	_mesh(parent, sceau, Vector3.ZERO, Palette.lueur(RUNE_CYAN))
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.35, 0.8, 1.0)
	lueur.light_energy = 1.6
	lueur.omni_range = 5.0
	lueur.omni_attenuation = 1.2
	lueur.position = Vector3(0, 1.3, zt + 1.4)
	parent.add_child(lueur)
