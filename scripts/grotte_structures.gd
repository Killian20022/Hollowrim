class_name GrotteStructures
extends RefCounted
## v2 de la grotte (planche references/grotte_v2_planche.png) : STRUCTURES EN BOIS ET MOBILIER, posées par GrotteKit.habiller() après
## les roches. Décor seul : AUCUNE collision ajoutée, aucun chemin, ennemi ni quête touché (tout est hors de la voie centrale).
##   - portique d'entrée : deux poteaux équarris, linteau, jambes de force, lanterne de fer pendue à une POTENCE (vues 1 et 2)
##   - salle principale (caverne du lac) : pont de bois sur TRÉTEAUX d'une paroi à l'autre, garde-corps, lanternes, bannière (vue 3)
##   - arène (camp) : enceinte de pieux taillés + autel de pierre en ruine, bougies sans lumière (vue 6)
##   - tonneaux et caisses (vues 1, 4, 6)
## Les lanternes ne portent ni lumière ni réglage : leurs positions (centre de flamme) sont rangées dans la méta `v2_lanternes` de la
## Grotte, pour le lot LUMIÈRE.

const ECHELLE_PONT := 4.3        # hauteur du tablier au-dessus du sol de l'axe (m) : 2,5 m libres sous la plus haute corniche

static func poser(k: GrotteKit) -> void:
	var g: Grotte = k.g
	var lanternes: Array = []
	for z: Dictionary in g.def.get("zones", []):
		var th := String(z.get("theme", ""))
		var role := String(z.get("role", ""))
		k._reserver(String(z["branche"]))
		match th:
			"entree":
				_portique(k, z, lanternes)
				_tonneaux(k, z, 11.8, -1.0, 2)
			"lac":
				if role == "combat":
					_pont(k, z, lanternes)
			"repaire":
				if role == "combat":
					_arene(k, z)
					_tonneaux(k, z, 3.0, 1.0, 2)
			"mine":
				if role == "combat" and not (z.get("params", {}) as Dictionary).get("etais", []).is_empty():
					_tonneaux(k, z, float((z["params"]["etais"] as Array)[1]) + 0.9, -1.0, 1)
	g.set_meta("v2_lanternes", lanternes)
	print("grotte v2 : %d lanternes de structure" % lanternes.size())

# ------------------------------------------------------------------ outils
## Poutre à section rectangulaire entre deux points quasi horizontaux (largeur w, épaisseur h).
static func _poutre(d: GrotteDecor, a: Vector3, b: Vector3, w: float, h: float, nom := "bois") -> void:
	var v := b - a
	if v.length() < 0.02:
		return
	var x := v.normalized()
	var z := x.cross(Vector3.UP)
	if z.length() < 0.01:
		return
	z = z.normalized()
	var y := z.cross(x)
	d.boite_b(nom, (a + b) * 0.5, Vector3(v.length(), h, w), Basis(x, y, z))

static func _sol_pied(g: Grotte, p: Vector3) -> float:
	return maxf(p.y, g.lac_y)

static func _caisse(d: GrotteDecor, pos: Vector3, t: Vector3, lacet: float) -> void:
	d.boite("planches", pos + Vector3(0, t.y * 0.5, 0), t, lacet)
	var b := Basis(Vector3.UP, lacet)
	for dx: float in [-0.5, 0.5]:
		for dz: float in [-0.5, 0.5]:
			d.boite("bois", pos + b * Vector3(dx * (t.x - 0.04), t.y * 0.5, dz * (t.z - 0.04)), Vector3(0.06, t.y + 0.02, 0.06), lacet)
	d.boite("fer", pos + Vector3(0, t.y - 0.04, 0), Vector3(t.x + 0.02, 0.03, t.z + 0.02), lacet)

## Tonneaux (et une caisse) au pied de la paroi, hors voie : cherche une place libre autour de `s`.
static func _tonneaux(k: GrotteKit, z: Dictionary, s: float, cote: float, n: int) -> void:
	var g: Grotte = k.g
	var id: String = z["branche"]
	var d: GrotteDecor = g.decor
	var faits := 0
	for dec: float in [0.0, 0.8, -0.8, 1.6, -1.6, 2.4, -2.4]:
		if faits >= n:
			break
		var ss := s + dec
		if ss < float(z["s"][0]) + 0.5 or ss > float(z["s"][1]) - 0.5:
			continue
		var m := k._mur(id, ss, cote, 0.5)
		if m.is_empty():
			continue
		var lat := cote * (float(m["lat"]) - 0.55)
		if not k.libre(id, ss, lat, 0.45, 0.6):
			continue
		var p := g.sol_en(id, ss, lat)
		if faits == 0 and n > 1:
			_caisse(d, p, Vector3(0.7, 0.55, 0.55), atan2(g.tang(id, ss).x, g.tang(id, ss).z) + 0.2)
			_caisse(d, p + Vector3(0.05, 0.55, 0.0), Vector3(0.5, 0.42, 0.45), 0.7)
		else:
			d.tonneau(p, 0.95)
		k._occuper_fixe(id, ss, lat, 0.6)
		faits += 1

# ------------------------------------------------------------------ portique d'entrée (vues 1 et 2)
static func _portique(k: GrotteKit, z: Dictionary, lanternes: Array) -> void:
	var g: Grotte = k.g
	var d: GrotteDecor = g.decor
	var id: String = z["branche"]
	var s := minf(float(z["s"][1]) - 4.5, 9.6)
	if not g.hors_jonction(id, s):
		return
	var dl := g.demi_l(id, s)
	var la := -(dl.x - 0.55)
	var lb := dl.y - 0.55
	var pa := g.sol_en(id, s, la)
	var pb := g.sol_en(id, s, lb)
	var plaf := minf(g.plafond_en(id, s, la).y, g.plafond_en(id, s, lb).y)
	var haut := minf(minf(pa.y, pb.y) + 3.4, plaf - 0.3)
	if haut - maxf(pa.y, pb.y) < 2.5:
		return
	var R := g.droite(id, s)
	R.y = 0.0
	R = R.normalized()
	var ta := Vector3(pa.x, haut, pa.z)
	var tb := Vector3(pb.x, haut, pb.z)
	d.prisme("bois", pa - Vector3(0, 0.2, 0), ta, 0.17, 4)
	d.prisme("bois", pb - Vector3(0, 0.2, 0), tb, 0.19, 4)
	_poutre(d, ta - R * 0.45, tb + R * 0.45, 0.3, 0.3)
	for bout: Array in [[ta, 1.0], [tb, -1.0]]:      # jambes de force sous le linteau
		var t: Vector3 = bout[0]
		var sg: float = bout[1]
		d.prisme("bois", t - Vector3(0, 1.05, 0), t + R * sg * 0.95 - Vector3(0, 0.2, 0), 0.075, 4)
		d.boite("fer", t - Vector3(0, 0.5, 0), Vector3(0.3, 0.06, 0.3))
	d.boite("fer", pa + Vector3(0, 0.55, 0), Vector3(0.3, 0.05, 0.3))
	d.boite("fer", pb + Vector3(0, 0.55, 0), Vector3(0.32, 0.05, 0.32))
	# potence : bras horizontal sorti du poteau de droite, lanterne pendue au bout
	var bras := tb - R * 0.95 - Vector3(0, 0.45, 0)
	d.prisme("bois", tb - Vector3(0, 0.45, 0), bras, 0.06, 4)
	d.prisme("bois", tb - Vector3(0, 1.15, 0), bras + R * 0.2, 0.045, 4)
	d.boite("fer", bras, Vector3(0.07, 0.07, 0.07))
	lanternes.append(d.lanterne(bras, 0.34))
	k._occuper_fixe(id, s, la, 0.5)
	k._occuper_fixe(id, s, lb, 0.5)

# ------------------------------------------------------------------ pont de la salle principale (vue 3)
static func _pont(k: GrotteKit, z: Dictionary, lanternes: Array) -> void:
	var g: Grotte = k.g
	var d: GrotteDecor = g.decor
	var id: String = z["branche"]
	var s := float(z["s"][0]) + 6.8
	if s > float(z["s"][1]) - 4.0:
		return
	var o := g.sol_en(id, s, 0.0)
	var h := ECHELLE_PONT
	var mr := k._mur(id, s, 1.0, h)
	var ml := k._mur(id, s, -1.0, h)
	if mr.is_empty() or ml.is_empty():
		return
	var dR: float = float(mr["lat"]) + 0.35         # le tablier entre un peu dans la roche aux deux bouts
	var dL: float = float(ml["lat"]) + 0.35
	if dR + dL < 6.0 or dR + dL > 40.0:
		return
	var R := g.droite(id, s)
	R.y = 0.0
	R = R.normalized()
	var T := g.tang(id, s)
	T.y = 0.0
	T = T.normalized()
	var yd := o.y + h
	var P := func(u: float, t: float, y: float) -> Vector3:
		return Vector3(o.x, 0.0, o.z) + R * u + T * t + Vector3(0, y, 0)
	var u0 := -dL
	var u1 := dR
	var span := u1 - u0
	# longerons et solives
	for t: float in [-0.8, 0.8]:
		_poutre(d, P.call(u0, t, yd - 0.2), P.call(u1, t, yd - 0.2), 0.2, 0.26)
	var nj := int(span / 1.4)
	for j in nj + 1:
		var u := u0 + span * float(j) / float(nj)
		_poutre(d, P.call(u, -1.0, yd - 0.08), P.call(u, 1.0, yd - 0.08), 0.14, 0.12)
	# planches du tablier (quelques-unes manquantes)
	var rp := RandomNumberGenerator.new()
	rp.seed = 4417
	var npl := int(span / 0.34)
	for q in npl:
		if rp.randf() < 0.06:
			continue
		var u := u0 + (float(q) + 0.5) * span / float(npl)
		d.boite("planches", P.call(u, rp.randf_range(-0.03, 0.03), yd), Vector3(0.31, 0.06, 2.0), atan2(R.x, R.z) + rp.randf_range(-0.03, 0.03))
	# garde-corps : poteaux tous les 1,5 m, deux lisses
	var nposts := int(span / 1.5)
	for t: float in [-0.98, 0.98]:
		for q in nposts + 1:
			var u := u0 + span * float(q) / float(nposts)
			d.prisme("bois", P.call(u, t, yd), P.call(u, t, yd + 1.05), 0.045, 4)
		_poutre(d, P.call(u0, t, yd + 1.0), P.call(u1, t, yd + 1.0), 0.09, 0.07)
		_poutre(d, P.call(u0, t, yd + 0.55), P.call(u1, t, yd + 0.55), 0.07, 0.05)
	# tréteaux : paires de jambes légèrement évasées, croix de Saint-André, chapeau ; jamais dans la voie centrale
	var bents: Array = [-dL * 0.84, -dL * 0.52, -dL * 0.24, dR * 0.55, dR * 0.88]
	for ub: float in bents:
		if absf(ub) < 2.6:
			ub = -2.6
		var pied := []
		var tete := []
		for t: float in [-0.8, 0.8]:
			var top: Vector3 = P.call(ub, t, yd - 0.3)
			var bas: Vector3 = P.call(ub, t * 1.22, 0.0)
			bas.y = _sol_pied(g, g.sol_en(id, s, ub)) - 0.12
			bas.y = minf(bas.y, top.y - 1.0)
			d.prisme("bois", bas, top, 0.13, 4)
			pied.append(bas)
			tete.append(top)
		var a0: Vector3 = pied[0]
		var a1: Vector3 = pied[1]
		var b0: Vector3 = tete[0]
		var b1: Vector3 = tete[1]
		var m0 := a0.lerp(b0, 0.18)
		var m1 := a1.lerp(b1, 0.18)
		var m2 := a0.lerp(b0, 0.78)
		var m3 := a1.lerp(b1, 0.78)
		d.prisme("bois", m0, m3, 0.055, 4)
		d.prisme("bois", m1, m2, 0.055, 4)
		d.prisme("bois", m2, m3, 0.07, 4)
		d.prisme("bois", m0, m1, 0.07, 4)
		_poutre(d, b0 - T * 0.15, b1 + T * 0.15, 0.2, 0.2)
		d.boite("fer", b0, Vector3(0.22, 0.05, 0.22))
		d.boite("fer", b1, Vector3(0.22, 0.05, 0.22))
		if absf(ub) > 2.0 and k.libre(id, s, ub, 0.5, 0.5):
			k._occuper_fixe(id, s, ub, 0.5)
	# lanternes aux garde-corps (côté amont), bannière pendue au milieu
	for fu: float in [u0 + span * 0.22, u0 + span * 0.68]:
		var hook: Vector3 = P.call(fu, 0.98, yd + 1.05)
		d.prisme("bois", hook, hook + Vector3(0, 0.3, 0) + T * 0.0, 0.04, 4)
		var bras: Vector3 = hook + Vector3(0, 0.3, 0) - T * 0.55
		d.prisme("bois", hook + Vector3(0, 0.3, 0), bras, 0.035, 4)
		lanternes.append(d.lanterne(bras, 0.3))
	var bm: Vector3 = P.call(u0 + span * 0.45, 0.0, yd - 0.1)
	_poutre(d, bm + Vector3(0, -1.3, 0) - R * 0.55, bm + Vector3(0, -1.3, 0) + R * 0.55, 0.06, 0.06)
	d.boite("peau", bm + Vector3(0, -2.35, 0), Vector3(0.95, 2.1, 0.035), atan2(R.x, R.z) + PI * 0.5)
	d.boite("peau", bm + Vector3(0, -3.55, 0), Vector3(0.55, 0.3, 0.035), atan2(R.x, R.z) + PI * 0.5)
	print("grotte v2 : pont de %.1f m à s=%.1f, tablier à %.1f m" % [span, s, h])

# ------------------------------------------------------------------ arène : pieux et autel (vue 6)
static func _pieu(d: GrotteDecor, p: Vector3, h: float, pen: Vector3, r: float) -> Vector3:
	var tete := p + pen + Vector3(0, h, 0)
	d.prisme("bois", p - Vector3(0, 0.25, 0), tete, r, 5, 0.012)
	d.boite("paille", p + pen * 0.55 + Vector3(0, h * 0.55, 0), Vector3(r * 2.3, 0.07, r * 2.3), 0.3)
	return tete

static func _arene(k: GrotteKit, z: Dictionary) -> void:
	var g: Grotte = k.g
	var d: GrotteDecor = g.decor
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var rp := RandomNumberGenerator.new()
	rp.seed = 7351
	# 1. enceinte : rangées de pieux inégaux près des parois, reliés par une lisse
	for cote: float in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		var s := s0 + 2.2
		while s < s1 - 3.0:
			var dl := g.demi_l(id, s)
			var w := dl.y if cote > 0.0 else dl.x
			var lat := cote * (w - rp.randf_range(0.85, 1.25))
			if k.libre(id, s, lat, 0.3, 0.6) and g.libre(id, s, lat, 0.3):
				var p := g.sol_en(id, s, lat)
				var h := rp.randf_range(1.5, 2.7)
				var pen := Vector3(rp.randf_range(-0.12, 0.12), 0.0, rp.randf_range(-0.12, 0.12)) * h
				var tete := _pieu(d, p, h, pen, rp.randf_range(0.075, 0.115))
				k._occuper_fixe(id, s, lat, 0.4)
				if prev != Vector3.ZERO and prev.distance_to(p) < 2.2:
					_poutre(d, prev + Vector3(0, 0.95, 0), p + Vector3(0, 0.95, 0), 0.07, 0.07)
				prev = p
			else:
				prev = Vector3.ZERO
			s += rp.randf_range(1.2, 1.9)
	# 2. autel de pierre en ruine, adossé à la paroi de gauche, bougies éteintes sans lumière
	var sa := (s0 + s1) * 0.5
	var place := false
	var ps := Vector3.ZERO
	var lat_a := 0.0
	var s_a := sa
	for dec: float in [0.0, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0]:
		var ss := sa + dec
		var m := k._mur(id, ss, -1.0, 0.6)
		if m.is_empty():
			continue
		var la := -(float(m["lat"]) - 1.15)
		if k.libre(id, ss, la, 1.0, 0.6):
			place = true
			s_a = ss
			lat_a = la
			break
	if not place:
		return
	ps = g.sol_en(id, s_a, lat_a)
	var lac := atan2(g.tang(id, s_a).x, g.tang(id, s_a).z)
	var bz := Basis(Vector3.UP, lac)
	k._add("dalle_0", ps + Vector3(0, -0.05, 0), lac, Vector3(1.5, 1.7, 1.2))
	var h1: float = float(k.gab["dalle_0"]["h"]) * 1.7
	k._add("dalle_1", ps + Vector3(0, h1 - 0.1, 0) + bz * Vector3(0.05, 0, 0), lac + 0.2, Vector3(1.15, 1.5, 0.95))
	var h2: float = float(k.gab["dalle_1"]["h"]) * 1.5
	k._add("bloc_2", ps + bz * Vector3(-1.05, 0, 0.3), lac + 1.0, Vector3(0.55, 0.9, 0.5))
	k._add("bloc_5", ps + bz * Vector3(0.95, 0, -0.35), lac + 2.0, Vector3(0.45, 0.6, 0.45))
	k._add("caillou_1", ps + bz * Vector3(0.4, 0, 1.0), lac, Vector3(0.35, 0.35, 0.35))
	var top := ps + Vector3(0, h1 + h2 - 0.2, 0)
	for q: Array in [[-0.35, 0.1, 0.9], [0.1, -0.15, 1.2], [0.4, 0.2, 0.7]]:
		d.bougie(top + bz * Vector3(float(q[0]), 0, float(q[1])), false)
	d.crane(top + bz * Vector3(-0.05, 0.0, 0.3), lac + 2.5)
	k._occuper_fixe(id, s_a, lat_a, 1.4)
	print("grotte v2 : autel de l'arène à s=%.1f lat=%.1f" % [s_a, lat_a])
