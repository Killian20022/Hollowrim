class_name CrypteDonjon
extends RefCounted
## Agrandissement de la crypte (donjon) : ailes, ossuaire, galeries gelées, étage inférieur, passage secret, arène.
## Construit dans un fil d'exécution, hors de l'arbre (aucun accès au monde, aucun joueur) : ne produit que des maillages,
## collisions, lumières et des listes de données (interactions, gardiens, zones) que `tertre.gd` instancie ensuite.
## Repère : celui de la crypte (x est, z sud ; l'entrée est en z = +4, on s'enfonce vers -Z). Étage inférieur : y = -6.

const BAS := -6.0
var d: CrypteDecor
var interactions: Array = []     # {id, pos, nom, verbe, genre, ...}
var gardiens: Array = []         # {zone, type, pos, lacet, dort, debout, ident}
var zones: Array = []            # {nom, rect (Rect2 en x,z), y}
var portes: Dictionary = {}      # id -> Node3D mobile (porte coulissante, pivot)
var _n_gardien := 0

func _init(decor: CrypteDecor) -> void:
	d = decor

# ------------------------------------------------------------------ outils
func zone(nom: String, x0: float, x1: float, z0: float, z1: float, y := 0.0) -> void:
	zones.append({"nom": nom, "rect": Rect2(x0, z0, x1 - x0, z1 - z0), "y": y})

func gardien(zone_: String, type: String, pos: Vector3, lacet: float, dort := true, debout := false) -> void:
	_n_gardien += 1
	gardiens.append({"zone": zone_, "type": type, "pos": pos, "lacet": lacet, "dort": dort, "debout": debout, "ident": "cr_%s_%d" % [zone_, _n_gardien]})

func interaction(id: String, pos: Vector3, nom: String, verbe: String, genre: String, extra := {}) -> void:
	var it := {"id": id, "pos": pos, "nom": nom, "verbe": verbe, "genre": genre}
	it.merge(extra)
	interactions.append(it)

## Point du repère de la crypte pour un couloir d'axe "x" (u le long de x) ou "z".
func _p(axe: String, u: float, v: float, y := 0.0) -> Vector3:
	return Vector3(u, y, v) if axe == "x" else Vector3(v, y, u)

func _mur_vers(axe: String, s: float) -> Vector3:
	return Vector3(0, 0, s) if axe == "x" else Vector3(s, 0, 0)

func _vide() -> void:
	d.theme = {}

func _theme_givre() -> void:
	d.theme = {"mur0": "mur3", "mur1": "mur3", "mur2": "mur3", "dalle0": "dalle3", "voute": "mur3"}

func _theme_glace() -> void:
	d.theme = {"mur0": "mur4", "mur1": "mur3", "mur2": "mur4", "dalle0": "dalle4", "voute": "mur3"}

func _niveau(y: float) -> void:
	d.niveau_a = 1.0 + y / 20.0

# ------------------------------------------------------------------ escalier le long de Z
## Escalier droit entre z_haut (y_haut) et z_bas (y_bas), largeur x0..x1 ; plafond parallèle à 3 m ; marches de 0,25 m.
## Les parois sont des parallélogrammes (alpha de sommet = sol local pour la crasse de pied) ; sol = rampe de collision.
func escalier(x0: float, x1: float, z_haut: float, z_bas: float, y_haut: float, y_bas: float, mur := "mur1") -> void:
	var sens := signf(z_bas - z_haut)                        # +1 : on descend vers +Z
	# le sol plat des salles voisines déborde de 0,3 m dans la cage (demi-épaisseur du mur) : la volée va de l'un à l'autre
	var z1 := z_haut + sens * 0.3
	var z2 := z_bas - sens * 0.3
	var longueur := absf(z2 - z1)
	var n := int(round(absf(y_haut - y_bas) / 0.25))
	var pas := longueur / n
	var xa := x0 + 0.3
	var xb := x1 - 0.3
	var sol := func(z: float) -> float:
		return lerpf(y_haut, y_bas, clampf(absf(z - z1) / longueur * (1.0 if (z - z1) * sens >= 0.0 else 0.0), 0.0, 1.0))
	var alpha := func(z: float) -> float:
		return 1.0 + (sol.call(z) as float) / 20.0
	# marches (visuelles)
	d.niveau_a = 1.0
	for i in n:
		var zc := z1 + sens * (i + 0.5) * pas
		var yt: float = lerpf(y_haut, y_bas, (i + 1.0) / n)
		var ybas_m: float = yt - 0.25 - 0.1
		d.boite("dalle0", Vector3((xa + xb) * 0.5, (yt + ybas_m) * 0.5, zc), Vector3(xb - xa, yt - ybas_m, pas))
	# parois et plafond
	var seg := 6
	var long_tot := absf(z_bas - z_haut)
	for s in seg:
		var za: float = z_haut + sens * long_tot * s / seg
		var zb: float = z_haut + sens * long_tot * (s + 1) / seg
		var ya: float = sol.call(za)
		var yb: float = sol.call(zb)
		var aa: float = alpha.call(za)
		var ab: float = alpha.call(zb)
		var ca := Color(0.8, 0.8, 0.85, aa)
		var cb := Color(0.8, 0.8, 0.85, ab)
		var haut_a := Color(0.5, 0.5, 0.55, aa)
		var haut_b := Color(0.5, 0.5, 0.55, ab)
		d.quad(mur, Vector3(xa, ya, za), Vector3(xa, yb, zb), Vector3(xa, yb + 3.0, zb), Vector3(xa, ya + 3.0, za), Vector3(1, 0, 0), [], [], [ca, cb, haut_b, haut_a])
		d.quad(mur, Vector3(xb, ya, za), Vector3(xb, yb, zb), Vector3(xb, yb + 3.0, zb), Vector3(xb, ya + 3.0, za), Vector3(-1, 0, 0), [], [], [ca, cb, haut_b, haut_a])
		d.quad("voute", Vector3(xa, ya + 3.0, za), Vector3(xb, ya + 3.0, za), Vector3(xb, yb + 3.0, zb), Vector3(xa, yb + 3.0, zb), Vector3(0, -1, 0), [], [], [Color(0.6, 0.6, 0.65, aa), Color(0.6, 0.6, 0.65, aa), Color(0.6, 0.6, 0.65, ab), Color(0.6, 0.6, 0.65, ab)])
	# arcs tous les 4 m (le long de la pente)
	var k := 2.0
	while k < longueur - 1.0:
		var z := z1 + sens * k
		d.niveau_a = 1.0 + (sol.call(z) as float) / 20.0
		d.arc("mur0", "x", (x0 + x1) * 0.5, z, x1 - x0 - 0.6, sol.call(z) + 1.4, 1.3, 0.3, 0.4)
		k += 4.0
	d.niveau_a = 1.0
	# collisions : rampe (sa surface passe juste sous le nez des marches) et deux parois
	var dy := y_bas - y_haut
	var long_pente := sqrt(longueur * longueur + dy * dy)
	var centre := Vector3((x0 + x1) * 0.5, (y_haut + y_bas) * 0.5 - 0.2 - 0.05, (z1 + z2) * 0.5)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(x1 - x0, 0.4, long_pente)
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.RIGHT, -atan2(dy, z2 - z1)), centre)
	d.corps.add_child(cs)
	var ymin := minf(y_haut, y_bas) - 0.4
	var ymax := maxf(y_haut, y_bas) + 3.4
	for x in [x0, x1]:
		d.solide(Vector3(x, (ymin + ymax) * 0.5, (z_haut + z_bas) * 0.5), Vector3(0.6, ymax - ymin, long_tot))
	d.solide(Vector3((x0 + x1) * 0.5, maxf(y_haut, y_bas) + 3.2, (z_haut + z_bas) * 0.5), Vector3(x1 - x0, 0.4, long_tot))

# ------------------------------------------------------------------ portes mobiles
## Porte de bois ferrée qui coulisse vers le haut dans l'épaisseur du mur (comme la herse) ; renvoie le Node3D à animer.
## axe "x" : la porte barre un passage le long de X (plan x = pos.x) ; "z" : le long de Z.
func porte_coulissante(id: String, pos: Vector3, axe_passage: String, largeur := 2.6) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(pos.x, 0.0, pos.z)
	d.racine.add_child(n)
	var sb := StaticBody3D.new()
	n.add_child(sb)
	var vers_x := axe_passage == "x"       # on traverse en suivant X : la dalle est mince en X
	var ep := 0.3
	var taille := Vector3(ep, 3.0, largeur) if vers_x else Vector3(largeur, 3.0, ep)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille + (Vector3(0, 0, 0.6) if vers_x else Vector3(0.6, 0, 0))
	cs.shape = bs
	cs.position = Vector3(0, pos.y + 1.5, 0)
	sb.add_child(cs)
	var m := d.instance_boite(n, "bois", taille, Vector3(0, pos.y + 1.5, 0))
	for yy in [0.5, 1.5, 2.5]:
		d.instance_boite(n, "fer", taille + (Vector3(0.06, -2.85, 0.0) if vers_x else Vector3(0.0, -2.85, 0.06)), Vector3(0, pos.y + yy, 0))
	for sg in [-1.0, 1.0]:
		var dec := Vector3(0.03 * sg, 0, 0) if vers_x else Vector3(0, 0, 0.03 * sg)
		d.instance_boite(n, "fer", Vector3(0.08, 3.0, 0.08) if vers_x else Vector3(0.08, 3.0, 0.08), Vector3(0, pos.y + 1.5, largeur * 0.3 * sg if vers_x else 0) + dec)
	portes[id] = n
	return n

# ------------------------------------------------------------------ atmosphère
## Souffle froid : bruine de petits carrés pâles qui dérive le long d'un couloir.
func souffle(centre: Vector3, ext: Vector3, dir: Vector3, nombre := 36) -> void:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = 5.0
	p.position = centre
	p.visibility_aabb = AABB(-ext - Vector3(3, 3, 3), ext * 2.0 + Vector3(6, 6, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = dir.normalized()
	pm.spread = 25.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, -0.02, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.albedo_color = Color(0.75, 0.88, 1.0, 0.55)
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.racine.add_child(p)

## Stalactite de glace : cône pointant vers le bas depuis le plafond.
func glacon(pos_plafond: Vector3, longueur := 0.8, r := 0.12) -> void:
	d.tour("mur4", pos_plafond + Vector3(0, -longueur, 0), [Vector2(0.0, 0.0), Vector2(r * 0.5, longueur * 0.4), Vector2(r * 0.85, longueur * 0.8), Vector2(r, longueur)], 6, 0.3, false)

## Congère de neige soufflée dans un coin ou contre un mur (monticule irrégulier de 3 à 5 lobes).
func congere(pos: Vector3, r := 1.8, h := 0.7) -> void:
	d.tour("neige", pos, [Vector2(r, 0.0), Vector2(r * 0.82, h * 0.45), Vector2(r * 0.45, h * 0.85), Vector2(r * 0.12, h)], 7, 0.2, true)
	for k in 3:
		var a := d.rng.randf() * TAU
		var rr := r * d.rng.randf_range(0.6, 0.9)
		var rs := r * d.rng.randf_range(0.35, 0.55)
		d.tour("neige", pos + Vector3(cos(a) * rr, 0, sin(a) * rr), [Vector2(rs, 0.0), Vector2(rs * 0.7, h * 0.4), Vector2(rs * 0.2, h * 0.65)], 6, 0.3, true)

func stalagmite(pos: Vector3, haut := 0.7, r := 0.16) -> void:
	d.tour("mur4", pos, [Vector2(r, 0.0), Vector2(r * 0.55, haut * 0.55), Vector2(0.0, haut)], 5, 0.3, false)

## Amas d'os : monticule de crânes et d'os longs.
func os_monticule(pos: Vector3, r := 0.9, h := 0.6) -> void:
	d.tour("os", pos, [Vector2(r, 0.0), Vector2(r * 0.85, h * 0.4), Vector2(r * 0.5, h * 0.8), Vector2(r * 0.18, h)], 8, 0.2, true)
	for k in 7:
		var a := d.rng.randf() * TAU
		var rr := d.rng.randf() * r * 0.8
		d.crane(pos + Vector3(cos(a) * rr, h * (1.0 - rr / r) * 0.75, sin(a) * rr), d.rng.randf() * TAU)
	d.os_tas(pos + Vector3(r * 0.9, 0, 0.2), 4, 0.3)

## Panneau d'ossuaire (texture de niches) plaqué sur un mur, avec cadre ; axe "x" : mur le long de X (z fixe), "z" : le long de Z.
func panneau_os(axe: String, fixe: float, a0: float, a1: float, y0: float, y1: float, signe: float) -> void:
	var f := fixe + signe * 0.11
	var pts := d._pas(a0, a1, 4.0)
	for i in pts.size() - 1:
		var u0: float = pts[i]
		var u1: float = pts[i + 1]
		if axe == "x":
			d.quad("ossuaire", Vector3(u0, y0, f), Vector3(u1, y0, f), Vector3(u1, y1, f), Vector3(u0, y1, f), Vector3(0, 0, signe))
		else:
			d.quad("ossuaire", Vector3(f, y0, u0), Vector3(f, y0, u1), Vector3(f, y1, u1), Vector3(f, y1, u0), Vector3(signe, 0, 0))
	var ep := 0.2
	var fc := fixe + signe * ep * 0.5
	if axe == "x":
		d.boite("mur0", Vector3((a0 + a1) * 0.5, y1 + 0.15, fc), Vector3(a1 - a0 + 0.4, 0.3, ep))
		d.boite("mur0", Vector3((a0 + a1) * 0.5, y0 - 0.1, fc), Vector3(a1 - a0 + 0.4, 0.2, ep))
		for u in [a0 - 0.1, a1 + 0.1]:
			d.boite("mur0", Vector3(u, (y0 + y1) * 0.5, fc), Vector3(0.2, y1 - y0 + 0.4, ep))
	else:
		d.boite("mur0", Vector3(fc, y1 + 0.15, (a0 + a1) * 0.5), Vector3(ep, 0.3, a1 - a0 + 0.4))
		d.boite("mur0", Vector3(fc, y0 - 0.1, (a0 + a1) * 0.5), Vector3(ep, 0.2, a1 - a0 + 0.4))
		for u in [a0 - 0.1, a1 + 0.1]:
			d.boite("mur0", Vector3(fc, (y0 + y1) * 0.5, u), Vector3(ep, y1 - y0 + 0.4, 0.2))

## Couloir : arcs tous les 4 m sur pilastres, appliques alternées, détritus ; u de a0 à a1 le long de `axe`, centre transversal c.
func couloir_decor(axe: String, a0: float, a1: float, c: float, h := 3.0, y := 0.0, lumieres := 2.0, os := true) -> void:
	var u := a0 + 2.0
	while u < a1 - 1.5:
		if axe == "x":
			d.arc("mur0", "z", u, c, 2.6, y + 2.6, 1.3, 0.32, 0.45)
			for s in [-1.0, 1.0]:
				d.boite("mur0", Vector3(u, y + 1.3, c + s * 1.15), Vector3(0.45, 2.6, 0.3))
		else:
			d.arc("mur0", "x", c, u, 2.6, y + 2.6, 1.3, 0.32, 0.45)
			for s in [-1.0, 1.0]:
				d.boite("mur0", Vector3(c + s * 1.15, y + 1.3, u), Vector3(0.3, 2.6, 0.45))
		u += 4.0
	var sg := 1.0
	u = a0 + 6.0
	while u < a1 - 2.0 and lumieres > 0.0:
		var pl := _p(axe, u, c + sg * 1.3, y)
		d.applique(pl, _mur_vers(axe, -sg), y + 2.0, 4.8, 1.6)
		sg = -sg
		u += 8.0
	if os:
		var t := a0 + 3.0
		while t < a1 - 2.0:
			var v := c + d.rng.randf_range(-0.9, 0.9)
			match d.rng.randi_range(0, 3):
				0: d.os_tas(_p(axe, t, v, y), 3, 0.3)
				1: d.arme(_p(axe, t, v, y), d.rng.randf() * TAU)
				2: d.urne(_p(axe, t, c + (1.0 if d.rng.randf() < 0.5 else -1.0), y), 0.9)
				_: d.crane(_p(axe, t, v, y), d.rng.randf() * TAU)
			t += 5.0

func _toiles(coins: Array, haut: float, y := 0.0) -> void:
	for c in coins:
		d.toile(Vector3(c[0], y + haut, c[1]), Vector3(c[2], 0, 0), Vector3(0, 0, c[3]))

func or_tas(pos: Vector3, r := 0.6, h := 0.3) -> void:
	# tas irrégulier : un monticule principal et des petits à son pied, quelques pièces au sol
	d.tour("or", pos, [Vector2(r, 0.0), Vector2(r * 0.75, h * 0.55), Vector2(r * 0.4, h * 0.92), Vector2(r * 0.12, h)], 7, 0.1, true)
	for k in 4:
		var a := d.rng.randf() * TAU
		var rr := r * d.rng.randf_range(0.7, 1.1)
		var rs := r * d.rng.randf_range(0.3, 0.5)
		d.tour("or", pos + Vector3(cos(a) * rr, 0, sin(a) * rr), [Vector2(rs, 0.0), Vector2(rs * 0.6, h * 0.5), Vector2(rs * 0.15, h * 0.7)], 5, 0.4, true)
	for k in 6:
		var a := d.rng.randf() * TAU
		d.boite("or", pos + Vector3(cos(a), 0.012, sin(a)) * r * d.rng.randf_range(1.0, 1.6), Vector3(0.07, 0.02, 0.07), d.rng.randf() * TAU)

func _froid(pos: Vector3, e := 1.3, portee := 6.0) -> void:
	d.lumiere(pos, Color(0.45, 0.72, 1.0), e, portee, 1.6, false)

## Flaque lumineuse froide au sol + lumière : lampe de glace.
func lampe_glace(pos: Vector3, e := 1.3) -> void:
	d.flaque_froide(Vector3(pos.x, pos.y, pos.z), 3.2)
	_froid(pos + Vector3(0, 1.4, 0), e)
	stalagmite(pos + Vector3(0.0, 0.0, 0.0), 0.9, 0.2)

func piliers(xs: Array, zs: Array, h: float, largeur := 0.9, y := 0.0, arcs := true) -> void:
	for x: float in xs:
		for z: float in zs:
			d.pilier(x, z, h, largeur, y)
	if not arcs:
		return
	var ys := y + h * 0.78
	for z: float in zs:
		for i in xs.size() - 1:
			var w: float = xs[i + 1] - xs[i] - largeur
			d.arc("mur0", "x", (xs[i] + xs[i + 1]) * 0.5, z, w, ys, minf(w * 0.5, 1.2), 0.35, 0.5)
	for x: float in xs:
		for i in zs.size() - 1:
			var w: float = zs[i + 1] - zs[i] - largeur
			d.arc("mur0", "z", x, (zs[i] + zs[i + 1]) * 0.5, w, ys, minf(w * 0.5, 1.2), 0.35, 0.5)

# ------------------------------------------------------------------ construction
func construire() -> void:
	_aile_ouest()
	_aile_est()
	_niveau_bas()
	_arene()
	# portée de dessin : au-delà, rien n'est dessiné (le brouillard noie déjà tout)
	for n in d.racine.get_children():
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).visibility_range_end = 70.0
			(n as GeometryInstance3D).visibility_range_end_margin = 4.0

# ---------------------------------------------------------------- aile ouest : ossuaire, reliquaires, trésor
func _aile_ouest() -> void:
	# W1 : couloir de la salle des piliers à l'ossuaire
	zone("w1", -24, -7, -21.4, -18.2)
	d.salle(-24, -7, -21.4, -18.2, 3.0, [["est", -19.8, 3.2], ["ouest", -19.8, 3.2]], 0.0, "mur1")
	couloir_decor("x", -24, -7, -19.8, 3.0)
	_toiles([[-23.7, -18.5, 1, 1], [-7.3, -21.1, -1, -1]], 3.0)
	# S1 : retour vers le couloir des niches (porte barrée côté entrée)
	zone("s1", -24, -1.6, -10.6, -7.4)
	d.salle(-24, -1.6, -10.6, -7.4, 3.0, [["ouest", -9.0, 3.2], ["est", -9.0, 3.2]], 0.0, "mur1")
	couloir_decor("x", -24, -1.6, -9.0, 3.0, 0.0, 2.0, true)
	porte_coulissante("s1", Vector3(-1.6, 0, -9.0), "x")
	interaction("s1_barree", Vector3(-0.7, 1.2, -9.0), "Porte barrée", "Pousser la porte", "texte", {"texte": ["La porte est barrée de l’autre côté. Il doit y avoir une barre que l’on soulève."], "condition_non": "s1"})
	interaction("s1", Vector3(-3.0, 1.2, -9.0), "Barre de la porte", "Soulever la barre", "porte", {"condition_non": "s1"})
	_ossuaire()
	_reliquaires()
	_tresor()

func _ossuaire() -> void:
	zone("ossuaire", -46, -24, -34, -8)
	d.salle(-46, -24, -34, -8, 5.0, [["est", -19.8, 3.2], ["est", -9.0, 3.2], ["nord", -38.0, 3.2], ["nord", -29.2, 3.2]], 0.0, "mur1")
	piliers([-41.0, -29.0], [-27.0, -15.0], 5.0, 1.0)
	# macro : niches d'ossuaire sur le mur ouest, le mur sud et une partie de l'est
	panneau_os("z", -45.7, -31.0, -11.0, 0.8, 2.8, 1.0)
	panneau_os("x", -8.3, -44.0, -28.0, 0.8, 2.8, -1.0)
	panneau_os("z", -24.3, -17.4, -11.6, 0.8, 2.8, -1.0)
	panneau_os("x", -33.7, -45.0, -40.6, 0.8, 2.8, 1.0)
	# méso : autel d'os central, sarcophages, tas d'os, urnes
	d.tour("dalle0", Vector3(-35, 0, -21), [Vector2(2.6, 0.0), Vector2(2.6, 0.25), Vector2(2.0, 0.25), Vector2(2.0, 0.5)], 8, PI / 8.0, true)
	os_monticule(Vector3(-35, 0.5, -21), 1.5, 1.1)
	d.crane(Vector3(-35, 1.6, -21), 0.3)
	for x in [-43.5, -39.5, -35.5]:
		d.sarcophage(Vector3(x, 0, -9.3), Vector3(2.2, 0.7, 0.9), 0.0)
	os_monticule(Vector3(-43.0, 0, -31.5), 1.0, 0.8)
	os_monticule(Vector3(-26.5, 0, -32.0), 0.9, 0.7)
	d.urne(Vector3(-44.8, 0, -13.0), 1.1)
	d.urne(Vector3(-44.8, 0, -32.8), 1.0)
	d.etagere(Vector3(-24.8, 0, -25.5), PI * 0.5, 1.8, 2.0)
	d.coffre(Vector3(-25.2, 0, -30.8), -PI * 0.5)
	# micro
	for k in 8:
		d.crane(Vector3(d.rng.randf_range(-44.0, -26.0), 0.0, d.rng.randf_range(-31.0, -10.0)), d.rng.randf() * TAU)
	d.os_tas(Vector3(-30.0, 0, -19.0), 5, 0.6)
	d.os_tas(Vector3(-40.5, 0, -23.0), 5, 0.6)
	d.arme(Vector3(-33.0, 0, -13.0), 1.0)
	d.arme(Vector3(-38.0, 0, -29.0), 4.2)
	d.bougie(Vector3(-35.4, 0.5, -24.0))
	# éclairage (6)
	d.brasero(Vector3(-38.8, 0, -17.5))
	d.brasero(Vector3(-31.2, 0, -24.5))
	d.applique(Vector3(-45.7, 0, -12.5), Vector3(1, 0, 0), 3.2, 5.0, 1.6)
	d.applique(Vector3(-45.7, 0, -30.0), Vector3(1, 0, 0), 3.2, 5.0, 1.6)
	d.applique(Vector3(-24.3, 0, -14.5), Vector3(-1, 0, 0), 3.2, 5.0, 1.5, false)
	d.applique(Vector3(-31.0, 0, -8.3), Vector3(0, 0, -1), 3.2, 5.0, 1.6)
	d.oculus(Vector3(-35, 5.0, -21), 1.4)
	d.rai(Vector3(-35, 0.0, -21), 4.95, 1.4)
	d.poussiere(Vector3(-35, 2.5, -21), Vector3(0.7, 2.4, 0.7), 20)
	_toiles([[-45.7, -33.7, 1, 1], [-24.3, -33.7, -1, 1], [-45.7, -8.3, 1, -1], [-24.3, -8.3, -1, -1]], 5.0)
	gardien("ossuaire", "sbire", Vector3(-43.0, 0, -28.0), 0.8)
	gardien("ossuaire", "guerrier", Vector3(-27.0, 0, -13.0), -1.2, true, true)
	gardien("ossuaire", "sbire", Vector3(-33.0, 0, -11.0), PI)
	interaction("cof_ossuaire", Vector3(-25.2, 0.7, -30.8), "Coffre ferré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 34, "os_draugr": 2, "poussiere_tombe": 1}, "coffre": Vector3(-25.2, 0, -30.8)})
	interaction("urne_ossuaire", Vector3(-44.8, 0.5, -13.0), "Urne funéraire", "Fouiller l’urne", "coffre", {"butin": {"pieces": 9}, "coffre": Vector3(-44.8, 0, -13.0)})
	# couloir vers les reliquaires et escalier vers l'étage inférieur
	zone("w3", -39.6, -36.4, -50, -34)
	d.salle(-39.6, -36.4, -50, -34, 3.0, [["sud", -38.0, 3.2], ["nord", -38.0, 3.2]], 0.0, "mur1")
	couloir_decor("z", -50, -34, -38.0, 3.0)
	gardien("w3", "sbire", Vector3(-38.0, 0, -44.0), 0.0, true, true)
	_toiles([[-39.3, -34.3, 1, -1], [-36.7, -49.7, -1, 1]], 3.0)
	zone("u1", -30.8, -27.6, -46, -34)
	escalier(-30.8, -27.6, -34.0, -46.0, 0.0, BAS, "mur1")
	d.applique(Vector3(-30.5, 0, -38.0), Vector3(1, 0, 0), -0.1, 4.6, 1.5)
	d.applique(Vector3(-30.5, 0, -43.5), Vector3(1, 0, 0), -2.85, 4.6, 1.5)

func _reliquaires() -> void:
	zone("reliquaires", -48, -24, -68, -50)
	d.salle(-48, -24, -68, -50, 4.6, [["sud", -38.0, 3.2], ["est", -66.0, 3.2], ["ouest", -59.0, 3.2, true]], 0.0, "mur0")
	piliers([-42.0, -30.0], [-63.0, -55.0], 4.6, 0.9)
	d.contrefort(-24.55, -59.0, 4.6, -1.0, 0.0, 0.7, 0.5)
	for x in [-44.0, -38.0, -32.0]:
		d.sarcophage(Vector3(x, 0, -67.1), Vector3(2.2, 0.7, 0.9), 0.0)
	# autel des reliquaires
	d.boite_pleine("mur1", Vector3(-28.5, 0.45, -59.0), Vector3(1.0, 0.9, 2.4))
	d.boite("gravure", Vector3(-28.5, 0.95, -59.0), Vector3(1.2, 0.1, 2.6))
	d.crane(Vector3(-28.5, 1.0, -58.2), -1.0)
	d.crane(Vector3(-28.5, 1.0, -59.8), 1.2)
	d.bougie(Vector3(-28.6, 1.0, -59.0))
	d.etagere(Vector3(-24.9, 0, -52.5), PI * 0.5, 1.8, 2.0)
	d.coffre(Vector3(-46.8, 0, -52.8), 0.0)
	d.coffre(Vector3(-46.8, 0, -64.2), 0.0)
	d.table(Vector3(-36.0, 0, -52.6), 0.0)
	# le crâne descellé (levier caché) sur un socle, près du mur ouest ; courant d'air au pied du mur pivotant
	d.boite_pleine("mur1", Vector3(-47.0, 0.55, -62.6), Vector3(0.7, 1.1, 0.7))
	d.crane(Vector3(-47.0, 1.1, -62.6), -PI * 0.5)
	souffle(Vector3(-47.4, 0.25, -59.0), Vector3(0.1, 0.15, 1.2), Vector3(1, 0, 0), 14)
	# mobilier léger et détritus
	os_monticule(Vector3(-41.0, 0, -52.5), 0.8, 0.6)
	d.os_tas(Vector3(-34.0, 0, -62.0), 5, 0.6)
	d.os_tas(Vector3(-45.5, 0, -57.0), 3, 0.4)
	d.urne(Vector3(-24.9, 0, -65.0), 1.0)
	d.arme(Vector3(-39.0, 0, -58.5), 0.6)
	d.arme(Vector3(-33.0, 0, -52.0), 3.1)
	for k in 5:
		d.crane(Vector3(d.rng.randf_range(-45.0, -26.0), 0.0, d.rng.randf_range(-66.0, -52.0)), d.rng.randf() * TAU)
	# éclairage (6)
	d.brasero(Vector3(-34.0, 0, -57.2))
	d.brasero(Vector3(-45.0, 0, -55.5))
	d.applique(Vector3(-47.7, 0, -52.0), Vector3(1, 0, 0), 2.5, 5.2, 1.6)
	d.applique(Vector3(-24.3, 0, -62.0), Vector3(-1, 0, 0), 2.5, 5.2, 1.6)
	d.applique(Vector3(-36.0, 0, -67.7), Vector3(0, 0, 1), 2.6, 5.2, 1.6)
	d.applique(Vector3(-40.0, 0, -50.3), Vector3(0, 0, 1), 2.6, 5.2, 1.5, false)
	_toiles([[-47.7, -50.3, 1, 1], [-24.3, -50.3, -1, 1], [-47.7, -67.7, 1, -1], [-24.3, -67.7, -1, -1]], 4.6)
	gardien("reliquaires", "guerrier", Vector3(-28.0, 0, -63.5), PI * 0.5, true, true)
	gardien("reliquaires", "sbire", Vector3(-43.0, 0, -60.0), 1.2)
	gardien("reliquaires", "sbire", Vector3(-36.0, 0, -55.0), 0.0)
	interaction("secret", Vector3(-46.6, 1.35, -62.6), "Crâne descellé", "Pousser le crâne", "secret")
	interaction("cof_reliq1", Vector3(-46.8, 0.7, -52.8), "Coffre ferré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 42, "lame_antique": 1}, "coffre": Vector3(-46.8, 0, -52.8)})
	interaction("cof_reliq2", Vector3(-46.8, 0.7, -64.2), "Coffre ferré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 26, "poussiere_tombe": 2}, "coffre": Vector3(-46.8, 0, -64.2)})
	interaction("urne_reliq", Vector3(-24.9, 0.5, -65.0), "Urne funéraire", "Fouiller l’urne", "coffre", {"butin": {"pieces": 12, "os_draugr": 1}, "coffre": Vector3(-24.9, 0, -65.0)})
	# passage S3 vers l'arène : porte barrée côté reliquaires
	zone("s3", -24, -14, -67.6, -64.4)
	d.salle(-24, -14, -67.6, -64.4, 3.0, [["ouest", -66.0, 3.2], ["est", -66.0, 3.2]], 0.0, "mur1")
	couloir_decor("x", -24, -14, -66.0, 3.0, 0.0, 1.0, false)
	porte_coulissante("s3", Vector3(-24.0, 0, -66.0), "x")
	interaction("s3_barree", Vector3(-25.3, 1.2, -66.0), "Porte barrée", "Pousser la porte", "texte", {"texte": ["Une lourde porte, barrée de l’autre côté. Elle ne cédera pas d’ici."], "condition_non": "s3"})
	interaction("s3", Vector3(-22.7, 1.2, -66.0), "Barre de la porte", "Soulever la barre", "porte", {"condition_non": "s3"})

func _tresor() -> void:
	zone("tresor", -60, -48, -64, -54)
	d.salle(-60, -48, -64, -54, 4.0, [["est", -59.0, 3.2, true]], 0.0, "mur2")
	# pivot du mur secret : charnière au nord de l'ouverture, bat vers l'ouest dans la chambre
	var pv := Node3D.new()
	pv.position = Vector3(-48.0, 0.0, -60.3)
	d.racine.add_child(pv)
	var sb := StaticBody3D.new()
	pv.add_child(sb)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 3.0, 3.2)
	cs.shape = bs
	cs.position = Vector3(0, 1.5, 1.6 - 0.3)
	sb.add_child(cs)
	var pan := d.instance_boite(pv, "mur0", Vector3(0.56, 3.0, 2.6), Vector3(-0.02, 1.5, 1.3))
	pan.name = "PanneauSecret"
	d.instance_boite(pv, "mur1", Vector3(0.62, 0.3, 2.6), Vector3(0.03, 0.15, 1.3))
	portes["secret"] = pv
	# butin : or, coffres, râteliers, trône
	or_tas(Vector3(-55.0, 0, -56.0), 0.9, 0.5)
	or_tas(Vector3(-53.0, 0, -62.0), 0.7, 0.4)
	or_tas(Vector3(-58.0, 0, -59.0), 1.1, 0.6)
	d.coffre(Vector3(-58.8, 0, -55.0), PI * 0.5)
	d.coffre(Vector3(-58.8, 0, -63.0), PI * 0.5)
	d.coffre(Vector3(-56.0, 0, -59.0), PI * 0.5)
	d.table(Vector3(-52.0, 0, -55.0), 0.0)
	d.boite("bois", Vector3(-59.0, 0.5, -59.0), Vector3(0.7, 1.0, 1.0))
	for k in 4:
		d.arme(Vector3(-52.5 + k * 0.5, 0, -63.4), 1.6)
	d.urne(Vector3(-50.0, 0, -62.8), 1.2)
	d.urne(Vector3(-50.0, 0, -55.2), 1.0)
	d.urne(Vector3(-58.9, 0, -57.0), 0.9)
	d.crane(Vector3(-53.5, 0.0, -58.5), 0.5)
	d.os_tas(Vector3(-54.0, 0, -60.0), 3, 0.5)
	d.brasero(Vector3(-50.0, 0, -58.0))
	d.brasero(Vector3(-57.0, 0, -62.5))
	d.applique(Vector3(-59.7, 0, -56.5), Vector3(1, 0, 0), 2.4, 5.0, 1.5)
	d.applique(Vector3(-54.0, 0, -63.7), Vector3(0, 0, 1), 2.4, 5.0, 1.5)
	d.applique(Vector3(-54.0, 0, -54.3), Vector3(0, 0, -1), 2.4, 5.0, 1.5, false)
	d.lumiere(Vector3(-55.5, 1.0, -59.0), Color(1.0, 0.8, 0.4), 0.8, 4.5, 1.6, false)       # reflet de l'or
	_toiles([[-59.7, -54.3, 1, -1], [-48.3, -63.7, -1, 1]], 4.0)
	gardien("tresor", "guerrier", Vector3(-58.5, 0, -61.0), 0.0, true, true)
	interaction("cof_tresor1", Vector3(-58.8, 0.7, -55.0), "Coffre du jarl", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 120, "lame_antique": 1}, "coffre": Vector3(-58.8, 0, -55.0)})
	interaction("cof_tresor2", Vector3(-58.8, 0.7, -63.0), "Coffre du jarl", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 90, "poussiere_tombe": 3}, "coffre": Vector3(-58.8, 0, -63.0)})
	interaction("cof_tresor3", Vector3(-56.0, 0.7, -59.0), "Grand coffre", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 160, "lame_antique": 2, "os_draugr": 3}, "coffre": Vector3(-56.0, 0, -59.0)})

# ---------------------------------------------------------------- aile est : galeries gelées
func _aile_est() -> void:
	# G0 : de la salle des piliers vers la salle des glaces (givre qui s'installe, souffle froid)
	zone("g0", 7, 24, -31.3, -28.1)
	_theme_givre()
	d.salle(7, 24, -31.3, -28.1, 3.2, [["ouest", -29.7, 3.2], ["est", -29.7, 3.2]], 0.0, "mur0")
	couloir_decor("x", 7, 24, -29.7, 3.2, 0.0, 2.0, true)
	for x in [13.0, 17.0, 21.0]:
		glacon(Vector3(x, 3.2, -29.7 + d.rng.randf_range(-0.8, 0.8)), 0.5 + d.rng.randf() * 0.4)
	souffle(Vector3(15.5, 1.2, -29.7), Vector3(8.0, 0.9, 1.0), Vector3(-1, 0, 0), 30)
	_toiles([[7.3, -30.9, 1, 1], [23.7, -28.5, -1, -1]], 3.2)
	# G1 : la salle des glaces
	zone("g1", 24, 46, -40, -18)
	_theme_glace()
	d.salle(24, 46, -40, -18, 5.2, [["ouest", -29.7, 3.2], ["est", -30.0, 3.2], ["sud", 34.0, 3.2], ["nord", 34.0, 3.2]], 0.0, "mur0")
	piliers([29.5, 40.5], [-35.0, -23.0], 5.2, 1.0)
	d.tour("dalle4", Vector3(35, 0, -29), [Vector2(3.0, 0.0), Vector2(3.0, 0.2), Vector2(2.4, 0.3), Vector2(1.2, 0.4)], 8, PI / 8.0, true)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		stalagmite(Vector3(35 + cos(a) * 1.7, 0.3, -29 + sin(a) * 1.7), 0.7 + d.rng.randf() * 0.7, 0.16)
	for k in 14:
		glacon(Vector3(d.rng.randf_range(25.0, 45.0), 5.2, d.rng.randf_range(-39.0, -19.0)), 0.5 + d.rng.randf() * 0.9, 0.12)
	congere(Vector3(25.2, 0, -39.0), 1.7, 0.7)
	congere(Vector3(45.0, 0, -39.0), 1.7, 0.7)
	congere(Vector3(45.0, 0, -19.0), 1.4, 0.6)
	d.urne(Vector3(25.0, 0, -35.5), 1.0)
	d.os_tas(Vector3(44.0, 0, -37.0), 4, 0.5)
	d.arme(Vector3(31.0, 0, -21.0), 0.8)
	d.crane(Vector3(37.5, 0.0, -33.0), 0.9)
	d.coffre(Vector3(45.0, 0, -21.0), -PI * 0.5)
	# lumière : deux braziers chauds contre l'ensemble bleu, trois lampes de glace
	d.brasero(Vector3(26.0, 0, -33.0))
	d.brasero(Vector3(26.0, 0, -26.0))
	lampe_glace(Vector3(35.0, 0.4, -29.0), 1.4)
	lampe_glace(Vector3(43.5, 0.0, -36.5), 1.1)
	lampe_glace(Vector3(43.5, 0.0, -21.5), 1.1)
	d.oculus(Vector3(35, 5.2, -29), 1.6)
	d.rai(Vector3(35, 0.4, -29), 4.8, 1.6)
	d.poussiere(Vector3(35, 2.6, -29), Vector3(0.8, 2.4, 0.8), 24)
	souffle(Vector3(35.0, 1.0, -29.0), Vector3(8.0, 0.8, 8.0), Vector3(0, 0, 1), 40)
	_toiles([[24.3, -39.7, 1, 1], [45.7, -39.7, -1, 1], [24.3, -18.3, 1, -1], [45.7, -18.3, -1, -1]], 5.2)
	gardien("g1", "guerrier", Vector3(31.0, 0, -37.0), 0.4, true, true)
	gardien("g1", "sbire", Vector3(41.0, 0, -22.0), 3.5)
	interaction("cof_g1", Vector3(45.0, 0.7, -21.0), "Coffre givré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 38, "poussiere_tombe": 1}, "coffre": Vector3(45.0, 0, -21.0)})
	# G2 : galerie sud, vers l'entrée (S2) et vers la boucle (G6)
	zone("g2", 32.4, 35.6, -18, -0.4)
	_theme_givre()
	d.salle(32.4, 35.6, -18, -0.4, 3.2, [["nord", 34.0, 3.2], ["ouest", -2.0, 3.2], ["est", -9.6, 3.2]], 0.0, "mur0")
	couloir_decor("z", -18, -0.4, 34.0, 3.2, 0.0, 2.0, true)
	for z in [-14.0, -6.0]:
		glacon(Vector3(34.0 + d.rng.randf_range(-0.7, 0.7), 3.2, z), 0.7, 0.12)
	d.coffre(Vector3(33.0, 0, -4.5), PI)
	interaction("cof_g2", Vector3(33.0, 0.7, -4.5), "Coffre givré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 18}, "coffre": Vector3(33.0, 0, -4.5)})
	# S2 : retour vers l'entrée (porte barrée côté entrée)
	zone("s2", 3, 32.4, -3.6, -0.4)
	_theme_givre()
	d.salle(3, 32.4, -3.6, -0.4, 3.0, [["ouest", -2.0, 3.2], ["est", -2.0, 3.2]], 0.0, "mur1")
	couloir_decor("x", 3, 32.4, -2.0, 3.0, 0.0, 2.0, true)
	for x in [20.0, 26.0, 30.0]:
		glacon(Vector3(x, 3.0, -2.0 + d.rng.randf_range(-0.7, 0.7)), 0.6, 0.12)
	porte_coulissante("s2", Vector3(3.0, 0, -2.0), "x")
	interaction("s2_barree", Vector3(2.0, 1.2, -2.0), "Porte barrée", "Pousser la porte", "texte", {"texte": ["La porte est barrée de l’autre côté. La barre est hors de portée d’ici."], "condition_non": "s2"})
	interaction("s2", Vector3(4.4, 1.2, -2.0), "Barre de la porte", "Soulever la barre", "porte", {"condition_non": "s2"})
	gardien("s2", "sbire", Vector3(18.0, 0, -2.0), PI * 0.5, true, true)
	# G3 : corridor vers la seconde salle
	zone("g3", 46, 60, -31.6, -28.4)
	_theme_glace()
	d.salle(46, 60, -31.6, -28.4, 3.2, [["ouest", -30.0, 3.2], ["est", -30.0, 3.2]], 0.0, "mur0")
	couloir_decor("x", 46, 60, -30.0, 3.2, 0.0, 1.0, false)
	for x in [49.0, 53.0, 57.0]:
		glacon(Vector3(x, 3.2, -30.0 + d.rng.randf_range(-0.7, 0.7)), 0.8, 0.13)
		stalagmite(Vector3(x + 1.5, 0, -30.0 + d.rng.randf_range(-0.8, 0.8)), 0.5, 0.13)
	souffle(Vector3(53.0, 1.0, -30.0), Vector3(6.0, 0.8, 1.0), Vector3(-1, 0, 0), 24)
	# G4 : trône de glace
	zone("g4", 60, 78, -40, -20)
	_theme_glace()
	d.salle(60, 78, -40, -20, 4.6, [["ouest", -30.0, 3.2], ["sud", 70.0, 3.2]], 0.0, "mur0")
	piliers([65.0, 73.0], [-35.0, -25.0], 4.6, 0.9)
	d.boite_pleine("mur4", Vector3(76.0, 0.2, -30.0), Vector3(3.2, 0.4, 5.0))
	d.boite_pleine("mur4", Vector3(77.0, 0.6, -30.0), Vector3(1.4, 0.8, 2.6))
	d.boite("mur4", Vector3(77.4, 1.5, -30.0), Vector3(0.5, 1.4, 2.4))
	d.crane(Vector3(76.6, 0.8, -29.0), 3.0)
	for k in 10:
		glacon(Vector3(d.rng.randf_range(61.0, 77.0), 4.6, d.rng.randf_range(-39.0, -21.0)), 0.5 + d.rng.randf() * 0.8, 0.12)
	d.sarcophage(Vector3(62.2, 0, -37.5), Vector3(0.9, 0.7, 2.2), 0.0)
	d.sarcophage(Vector3(62.2, 0, -22.5), Vector3(0.9, 0.7, 2.2), 0.0)
	d.coffre(Vector3(77.0, 0, -38.5), PI * 0.5)
	d.coffre(Vector3(77.0, 0, -21.5), PI * 0.5)
	d.os_tas(Vector3(68.0, 0, -29.0), 5, 0.6)
	d.arme(Vector3(70.0, 0, -33.0), 2.0)
	d.urne(Vector3(61.5, 0, -30.0), 1.0)
	d.brasero(Vector3(62.5, 0, -33.5))
	d.brasero(Vector3(62.5, 0, -26.5))
	lampe_glace(Vector3(76.0, 0.0, -34.5), 1.2)
	lampe_glace(Vector3(76.0, 0.0, -25.5), 1.2)
	d.applique(Vector3(70.0, 0, -39.7), Vector3(0, 0, 1), 2.5, 5.2, 1.4)
	_toiles([[60.3, -39.7, 1, 1], [77.7, -39.7, -1, 1], [60.3, -20.3, 1, -1], [77.7, -20.3, -1, -1]], 4.6)
	gardien("g4", "guerrier", Vector3(75.0, 0, -36.0), PI * 0.5, true, true)
	gardien("g4", "guerrier", Vector3(75.0, 0, -24.0), PI * 0.5, true, true)
	interaction("cof_g4a", Vector3(77.0, 0.7, -38.5), "Coffre givré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 58, "lame_antique": 1}, "coffre": Vector3(77.0, 0, -38.5)})
	interaction("cof_g4b", Vector3(77.0, 0.7, -21.5), "Coffre givré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 44, "os_draugr": 2}, "coffre": Vector3(77.0, 0, -21.5)})
	# G5 / G6 : boucle de retour vers la galerie sud
	zone("g5", 68.4, 71.6, -20, -8)
	_theme_glace()
	d.salle(68.4, 71.6, -20, -8, 3.2, [["nord", 70.0, 3.2], ["ouest", -9.6, 3.2]], 0.0, "mur0")
	couloir_decor("z", -20, -8, 70.0, 3.2, 0.0, 1.0, false)
	for z in [-17.0, -12.0]:
		glacon(Vector3(70.0 + d.rng.randf_range(-0.6, 0.6), 3.2, z), 0.8, 0.13)
	zone("g6", 35.6, 68.4, -11.2, -8)
	_theme_givre()
	d.salle(35.6, 68.4, -11.2, -8, 3.2, [["ouest", -9.6, 3.2], ["est", -9.6, 3.2]], 0.0, "mur0")
	couloir_decor("x", 35.6, 68.4, -9.6, 3.2, 0.0, 2.0, true)
	for x in [42.0, 50.0, 58.0, 64.0]:
		glacon(Vector3(x, 3.2, -9.6 + d.rng.randf_range(-0.6, 0.6)), 0.7, 0.12)
	souffle(Vector3(52.0, 1.0, -9.6), Vector3(14.0, 0.8, 1.0), Vector3(-1, 0, 0), 32)
	gardien("g6", "sbire", Vector3(52.0, 0, -9.6), -PI * 0.5, true, true)
	_vide()
	# escalier vers l'étage inférieur
	zone("d1", 32.4, 35.6, -52, -40)
	_theme_givre()
	escalier(32.4, 35.6, -40.0, -52.0, 0.0, BAS, "mur1")
	d.applique(Vector3(32.7, 0, -43.5), Vector3(1, 0, 0), -0.4, 4.6, 1.4)
	d.applique(Vector3(32.7, 0, -48.5), Vector3(1, 0, 0), -3.4, 4.6, 1.4)
	_vide()

# ---------------------------------------------------------------- étage inférieur (y = -6)
func _niveau_bas() -> void:
	_niveau(BAS)
	# LB1 : salle à piliers octogonaux
	zone("lb1", 24, 44, -74, -52, BAS)
	d.salle(24, 44, -74, -52, 5.0, [["sud", 34.0, 3.2], ["ouest", -66.0, 3.2]], BAS, "mur2")
	piliers([29.0, 39.0], [-58.0, -63.0, -68.0], 5.0, 1.0, BAS, false)
	for z in [-58.0, -63.0, -68.0]:
		d.arc("mur0", "x", 34.0, z, 9.0, BAS + 3.8, 1.0, 0.35, 0.5)
	for x in [29.0, 39.0]:
		for z in [-60.5, -65.5]:
			d.arc("mur0", "z", x, z, 4.0, BAS + 3.8, 0.8, 0.35, 0.5)
	for k in 3:
		d.tonneau(Vector3(42.8, BAS, -55.5 - k * 1.0), 1.0)
	d.tonneau(Vector3(42.8, BAS + 1.0, -56.0), 1.0)
	d.coffre(Vector3(43.0, BAS, -72.5), PI * 0.5)
	d.sarcophage(Vector3(26.0, BAS, -72.5), Vector3(2.2, 0.7, 0.9), 0.0)
	d.os_tas(Vector3(32.0, BAS, -71.0), 5, 0.6)
	d.arme(Vector3(36.0, BAS, -61.0), 0.4)
	d.urne(Vector3(25.0, BAS, -54.5), 1.0)
	d.crane(Vector3(41.0, BAS, -65.0), 1.1)
	d.brasero(Vector3(34.0, BAS, -53.8))
	d.brasero(Vector3(42.0, BAS, -64.0))
	d.brasero(Vector3(26.5, BAS, -70.0))
	d.applique(Vector3(43.7, 0, -58.5), Vector3(-1, 0, 0), BAS + 2.4, 5.2, 1.5)
	d.applique(Vector3(34.0, 0, -73.7), Vector3(0, 0, 1), BAS + 2.4, 5.2, 1.6)
	_toiles([[24.3, -73.7, 1, 1], [43.7, -73.7, -1, 1], [43.7, -52.3, -1, -1]], 5.0, BAS)
	gardien("lb1", "guerrier", Vector3(41.0, BAS, -70.0), 3.0, true, true)
	gardien("lb1", "sbire", Vector3(27.0, BAS, -64.0), 1.5)
	interaction("cof_lb1", Vector3(43.0, BAS + 0.7, -72.5), "Coffre ferré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 52, "lame_antique": 1}, "coffre": Vector3(43.0, BAS, -72.5)})
	# LB2 : longue galerie funéraire vers la cisterne
	zone("lb2", -20, 24, -67.6, -64.4, BAS)
	d.salle(-20, 24, -67.6, -64.4, 3.2, [["est", -66.0, 3.2], ["ouest", -66.0, 3.2], ["nord", 4.0, 3.2]], BAS, "mur1")
	couloir_decor("x", -20, 24, -66.0, 3.2, BAS, 2.0, true)
	gardien("lb2", "sbire", Vector3(-8.0, BAS, -66.0), PI * 0.5, true, true)
	zone("lb2a", 0, 8, -76, -67.6, BAS)
	d.salle(0, 8, -76, -67.6, 3.4, [["sud", 4.0, 3.2]], BAS, "mur2")
	d.sarcophage(Vector3(4.0, BAS, -74.5), Vector3(2.2, 0.7, 0.9), 0.0)
	d.coffre(Vector3(1.4, BAS, -72.0), PI * 0.5)
	d.os_tas(Vector3(5.5, BAS, -72.0), 4, 0.5)
	d.urne(Vector3(6.6, BAS, -69.0), 1.0)
	d.brasero(Vector3(6.5, BAS, -74.0))
	d.applique(Vector3(0.3, 0, -71.0), Vector3(1, 0, 0), BAS + 2.2, 4.6, 1.4)
	_toiles([[0.3, -75.7, 1, 1], [7.7, -75.7, -1, 1]], 3.4, BAS)
	interaction("cof_lb2a", Vector3(1.4, BAS + 0.7, -72.0), "Coffre ferré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 31, "poussiere_tombe": 1}, "coffre": Vector3(1.4, BAS, -72.0)})
	# LB3 : cisterne et cuves
	zone("lb3", -40, -20, -70, -46, BAS)
	d.salle(-40, -20, -70, -46, 5.0, [["est", -66.0, 3.2], ["sud", -29.2, 3.2]], BAS, "mur1")
	piliers([-34.0, -26.0], [-60.0, -52.0], 5.0, 1.0, BAS, true)
	for k in 5:
		d.tonneau(Vector3(-38.8, BAS, -68.5 + k * 1.2), 1.1)
	d.tonneau(Vector3(-38.8, BAS + 1.1, -67.9), 1.1)
	d.tonneau(Vector3(-38.8, BAS + 1.1, -65.5), 1.1)
	d.tour("dalle0", Vector3(-30, BAS, -56), [Vector2(2.4, 0.0), Vector2(2.4, 0.4), Vector2(1.9, 0.4), Vector2(1.9, 0.7)], 8, PI / 8.0, true)
	d.coffre(Vector3(-21.0, BAS, -48.5), -PI * 0.5)
	d.os_tas(Vector3(-24.0, BAS, -62.0), 4, 0.6)
	d.arme(Vector3(-36.0, BAS, -49.0), 2.0)
	d.crane(Vector3(-30.0, BAS + 0.7, -56.0), 0.0)
	d.brasero(Vector3(-23.0, BAS, -56.0))
	d.brasero(Vector3(-37.0, BAS, -56.0))
	d.applique(Vector3(-30.0, 0, -69.7), Vector3(0, 0, 1), BAS + 2.4, 5.2, 1.6)
	d.applique(Vector3(-39.7, 0, -50.0), Vector3(1, 0, 0), BAS + 2.4, 5.2, 1.5)
	_toiles([[-39.7, -69.7, 1, 1], [-20.3, -69.7, -1, 1], [-39.7, -46.3, 1, -1]], 5.0, BAS)
	gardien("lb3", "guerrier", Vector3(-24.0, BAS, -60.0), PI * 0.5, true, true)
	gardien("lb3", "sbire", Vector3(-36.0, BAS, -58.0), 0.0)
	interaction("cof_lb3", Vector3(-21.0, BAS + 0.7, -48.5), "Coffre ferré", "Ouvrir le coffre", "coffre", {"butin": {"pieces": 47, "lame_antique": 1, "os_draugr": 2}, "coffre": Vector3(-21.0, BAS, -48.5)})
	_niveau(0.0)
	_vide()

# ---------------------------------------------------------------- arène de Svanhild
func _arene() -> void:
	zone("arene", -14, 14, -80, -58)
	d.theme = {"mur0": "mur3", "mur1": "mur3", "mur2": "mur3", "dalle0": "dalle3", "voute": "mur3"}
	d.salle(-14, 14, -80, -58, 8.0, [["sud", 0.0, 4.0], ["ouest", -66.0, 3.2]], 0.0, "mur0")
	for x in [-9.0, 9.0]:
		for z in [-63.0, -71.0, -77.0]:
			d.pilier(x, z, 8.0, 1.2)
	for z in [-63.0, -71.0, -77.0]:
		d.arc("mur0", "x", 0.0, z, 17.0, 6.2, 1.4, 0.4, 0.6, 12)
	for x in [-9.0, 9.0]:
		for z in [-67.0, -74.0]:
			d.arc("mur0", "z", x, z, 5.8, 6.2, 1.2, 0.4, 0.6)
	# estrade à trois degrés de 0,2 m, sarcophage au centre (le monde de la quête est dans tertre.gd)
	d.boite_pleine("dalle0", Vector3(0, 0.1, -72.0), Vector3(11.0, 0.2, 9.0))
	d.boite_pleine("dalle0", Vector3(0, 0.3, -72.0), Vector3(8.0, 0.2, 7.0))
	d.boite_pleine("dalle0", Vector3(0, 0.5, -72.0), Vector3(5.4, 0.2, 5.6))
	for k in 12:
		var a := TAU * k / 12.0
		stalagmite(Vector3(cos(a) * 6.8, 0.0, -72.0 + sin(a) * 5.6), 0.5 + d.rng.randf() * 0.6, 0.14)
	for k in 16:
		glacon(Vector3(d.rng.randf_range(-12.0, 12.0), 8.0, d.rng.randf_range(-78.0, -60.0)), 0.7 + d.rng.randf() * 1.1, 0.14)
	for c in [Vector2(-13.0, -79.0), Vector2(13.0, -79.0), Vector2(-13.0, -59.0), Vector2(13.0, -59.0)]:
		congere(Vector3(c.x, 0, c.y), d.rng.randf_range(1.6, 2.3), d.rng.randf_range(0.6, 0.9))
	congere(Vector3(-6.0, 0, -79.0), 1.2, 0.45)
	congere(Vector3(7.5, 0, -79.0), 1.4, 0.5)
	d.urne(Vector3(-13.0, 0, -61.0), 1.2)
	d.urne(Vector3(13.0, 0, -61.0), 1.2)
	d.os_tas(Vector3(-5.0, 0, -62.0), 5, 0.6)
	d.os_tas(Vector3(6.0, 0, -77.0), 4, 0.6)
	d.arme(Vector3(3.0, 0, -62.5), 0.4)
	d.arme(Vector3(-7.0, 0, -76.0), 2.2)
	d.crane(Vector3(-3.0, 0.0, -66.0), 0.5)
	d.crane(Vector3(4.0, 0.0, -66.5), 2.0)
	# lumière : braziers chauds aux coins de l'entrée, lampes froides à l'estrade
	d.brasero(Vector3(-12.5, 0, -59.5))
	d.brasero(Vector3(12.5, 0, -59.5))
	d.brasero(Vector3(-5.6, 0, -66.2))
	d.brasero(Vector3(5.6, 0, -66.2))
	d.applique(Vector3(-13.7, 0, -70.0), Vector3(1, 0, 0), 3.0, 6.0, 1.8, false)
	d.applique(Vector3(13.7, 0, -70.0), Vector3(-1, 0, 0), 3.0, 6.0, 1.8, false)
	d.applique(Vector3(-13.7, 0, -77.5), Vector3(1, 0, 0), 3.0, 6.0, 1.6, false)
	d.applique(Vector3(13.7, 0, -77.5), Vector3(-1, 0, 0), 3.0, 6.0, 1.6, false)
	d.applique(Vector3(0, 0, -79.7), Vector3(0, 0, 1), 3.0, 6.0, 1.6)
	d.oculus(Vector3(0, 8.0, -72.0), 2.0)
	d.rai(Vector3(0, 0.7, -72.0), 7.2, 2.0)
	d.flaque_froide(Vector3(0, 0.62, -72.0), 6.0)
	d.poussiere(Vector3(0, 4.0, -72.0), Vector3(1.0, 3.0, 1.4), 34)
	souffle(Vector3(0, 0.8, -70.0), Vector3(5.0, 0.5, 4.0), Vector3(0, 0.3, -1), 36)
	_toiles([[-13.7, -79.7, 1, 1], [13.7, -79.7, -1, 1], [-13.7, -58.3, 1, -1], [13.7, -58.3, -1, -1]], 8.0)
	gardien("arene", "guerrier", Vector3(-10.0, 0, -64.5), PI * 0.5, true, true)
	gardien("arene", "guerrier", Vector3(10.0, 0, -64.5), -PI * 0.5, true, true)
	_vide()
