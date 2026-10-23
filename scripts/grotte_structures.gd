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
	d.objet_debut("caisse")
	var pz := d.pose_objet(pos, t.x * 0.5, t.z * 0.5, lacet, t.y, GrotteDecor.INCLINE)      # lot D : collée au sol, inclinée, hors paroi
	pos = pz["p"]
	var x0 := d._incliner(pz)
	d.boite("planches", pos + Vector3(0, t.y * 0.5, 0), t, lacet)
	var b := Basis(Vector3.UP, lacet)
	for dx: float in [-0.5, 0.5]:
		for dz: float in [-0.5, 0.5]:
			d.boite("bois", pos + b * Vector3(dx * (t.x - 0.04), t.y * 0.5, dz * (t.z - 0.04)), Vector3(0.06, t.y + 0.02, 0.06), lacet)
	d.boite("fer", pos + Vector3(0, t.y - 0.04, 0), Vector3(t.x + 0.02, 0.03, t.z + 0.02), lacet)
	d.xf = x0
	d._empreinte(pos, (t.x + t.z) * 0.25, t.y)
	d.objet_fin()

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
	k.g.decor.objet_debut("portique")
	var g: Grotte = k.g
	var d: GrotteDecor = g.decor
	var id: String = z["branche"]
	var s := minf(float(z["s"][1]) - 4.5, 9.6)
	if not g.hors_jonction(id, s):
		k.g.decor.objet_fin()
		return
	var dl := g.demi_l(id, s)
	var la := -(dl.x - 0.55)
	var lb := dl.y - 0.55
	var pa := g.sol_en(id, s, la)
	var pb := g.sol_en(id, s, lb)
	var plaf := minf(g.plafond_en(id, s, la).y, g.plafond_en(id, s, lb).y)
	var haut := minf(minf(pa.y, pb.y) + 3.4, plaf - 0.3)
	if haut - maxf(pa.y, pb.y) < 2.5:
		k.g.decor.objet_fin()
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
	k.g.decor.objet_fin()

# ------------------------------------------------------------------ pont de la salle principale (vue 3)
static func _pont(k: GrotteKit, z: Dictionary, lanternes: Array) -> void:
	k.g.decor.objet_debut("pont")
	var g: Grotte = k.g
	var d: GrotteDecor = g.decor
	var id: String = z["branche"]
	var s := float(z["s"][0]) + 6.8
	if s > float(z["s"][1]) - 4.0:
		k.g.decor.objet_fin()
		return
	var o := g.sol_en(id, s, 0.0)
	var h := ECHELLE_PONT
	var mr := k._mur(id, s, 1.0, h)
	var ml := k._mur(id, s, -1.0, h)
	if mr.is_empty() or ml.is_empty():
		k.g.decor.objet_fin()
		return
	var dR: float = float(mr["lat"]) + 0.35         # le tablier entre un peu dans la roche aux deux bouts
	var dL: float = float(ml["lat"]) + 0.35
	if dR + dL < 6.0 or dR + dL > 40.0:
		k.g.decor.objet_fin()
		return
	var R := g.droite(id, s)
	R.y = 0.0
	R = R.normalized()
	var T := g.tang(id, s)
	T.y = 0.0
	T = T.normalized()
	var yd := o.y + h
	var P := func(u: float, t: float, y: float) -> Vector3:
		k.g.decor.objet_fin()
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
	# lanternes aux garde-corps (côté amont), bannière pendue au milieu
	for fu: float in [u0 + span * 0.22, u0 + span * 0.68]:
		var hook: Vector3 = P.call(fu, 0.98, yd + 1.05)
		d.prisme("bois", hook, hook + Vector3(0, 0.3, 0) + T * 0.0, 0.04, 4)
		var bras: Vector3 = hook + Vector3(0, 0.3, 0) - T * 0.55
		d.prisme("bois", hook + Vector3(0, 0.3, 0), bras, 0.035, 4)
		lanternes.append(d.lanterne(bras, 0.3))
	# finitions : mât planté au milieu du tablier, traverse haute, bannière rouge sombre déchirée (deux faces) comme la planche
	var ub := u0 + span * 0.45
	var plaf := g.plafond_en(id, s, ub)
	var yb := minf(plaf.y - 1.2, yd + 6.2)
	var long_b := clampf(yb - yd - 1.0, 1.6, 3.6)
	if yb - yd > 2.6:
		var foot: Vector3 = P.call(ub, 0.0, yd)
		d.prisme("bois", foot, Vector3(foot.x, yb + 0.35, foot.z), 0.11, 6, 0.08)
		for sg: float in [-1.0, 1.0]:
			d.prisme("bois", Vector3(foot.x, yd + 1.6, foot.z) + T * sg * 0.05, Vector3(foot.x, yd + 0.2, foot.z) + T * sg * 0.9, 0.05, 4)   # jambes de force
		d.boite("fer", Vector3(foot.x, yb + 0.35, foot.z), Vector3(0.2, 0.06, 0.2))
		for sg: float in [-1.0, 1.0]:
			d.banniere(Vector3(foot.x, yb, foot.z) + T * 0.0, T * sg, long_b, 1.05, Color(0.5, 0.15, 0.13), "", 1)
	# voûte lisible : stalactites en frange au-dessus du pont (jamais dans le gabarit du tablier ni du mât), ouverture claire en hauteur
	var rs := RandomNumberGenerator.new()
	rs.seed = 5521
	for q in 16:
		var sq := s + (rs.randf_range(1.8, 7.5) * (1.0 if rs.randf() < 0.5 else -1.0))
		var lq := rs.randf_range(-dL * 0.9, dR * 0.9)
		k._stalactite(id, sq, lq, rs.randf_range(1.2, 3.0), false)
	var so := s + 3.2
	var po := g.plafond_en(id, so, 0.0)
	if po.y - yd > 7.0:
		var o1 := po - Vector3(0, 0.25, 0)
		d.quad("ciel", o1 + Vector3(-1.2, 0, -1.2), o1 + Vector3(1.2, 0, -1.2), o1 + Vector3(1.2, 0, 1.2), o1 + Vector3(-1.2, 0, 1.2), Vector3.DOWN,
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		d.rai_oblique(o1, Vector3(o1.x + 1.2, yd - 3.2, o1.z - 1.0), 2.4, 4.0)
		g.set_meta("v2_ouverture", o1)
	print("grotte v2 : pont de %.1f m à s=%.1f, tablier à %.1f m" % [span, s, h])
	k.g.decor.objet_fin()

# ------------------------------------------------------------------ arène : pieux et autel (vue 6)
static func _pieu(d: GrotteDecor, p: Vector3, h: float, pen: Vector3, r: float) -> Vector3:
	d.objet_debut("pieu")
	var tete := p + pen + Vector3(0, h, 0)
	d.prisme("bois", p - Vector3(0, 0.25, 0), tete, r, 5, 0.012)
	d.boite("paille", p + pen * 0.55 + Vector3(0, h * 0.55, 0), Vector3(r * 2.3, 0.07, r * 2.3), 0.3)
	d.objet_fin()
	return tete

static func _arene(k: GrotteKit, z: Dictionary) -> void:
	var g: Grotte = k.g
	var d: GrotteDecor = g.decor
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var rp := RandomNumberGenerator.new()
	rp.seed = 7351
	# 2. autel de pierre en ruine, adossé à la paroi de gauche, bougies éteintes sans lumière
	var sa := (s0 + s1) * 0.5
	var place := false
	var ps := Vector3.ZERO
	var lat_a := 0.0
	var s_a := sa
	# finitions : grand autel au fond gauche de l'arène, au milieu des pieux (le mobilier qui le masquait est écarté dans GrotteModules._repaire)
	for c: Array in [[11.2, -4.1], [11.8, -4.1], [10.6, -4.2], [12.4, -4.1]]:
		if g.libre(id, float(c[0]), float(c[1]), 1.7) and d.place_libre(g.sol_en(id, float(c[0]), float(c[1])), 2.4, 1.5):    # lot D : ni mobilier ni apparition sous l'estrade
			place = true
			s_a = float(c[0])
			lat_a = float(c[1])
			break
	var e_a := 1.2
	if g.has_meta("autel_place"):                     # lot D : place réservée avant le mobilier du camp (Grotte._decorer)
		var ap: Array = g.get_meta("autel_place")
		place = true
		s_a = float(ap[0])
		lat_a = float(ap[1])
		e_a = float(ap[2])
		g.set_meta("autel_y", float(ap[3]))
	elif d.regles_pose:          # lot D : l'estrade entière (rectangle) sur une place libre : ni mobilier, ni coffre, ni apparition, ni paroi
		place = false
		for e: float in [1.2, 1.05, 0.9, 0.78]:
			for cote: float in [-1.0, 1.0]:
				var ss := s0 + 3.0
				while ss < s1 - 2.5 and not place:
					var m := k._mur(id, ss, cote, 0.6)
					if not m.is_empty():
						var la := cote * (float(m["lat"]) - 1.6 * e - 0.25)
						if g.libre(id, ss, la, 1.0) and _autel_libre(g, id, ss, la, e):
							place = true
							s_a = ss
							lat_a = la
							e_a = e
					ss += 0.5
				if place:
					break
			if place:
				break
	if not place and not d.regles_pose:
		for ss: float in [s1 - 3.6, s1 - 4.4, s1 - 2.8, s1 - 5.2, sa, sa + 1.0, sa - 1.0]:      # repli : le long de la paroi gauche
			var m := k._mur(id, ss, -1.0, 0.6)
			if m.is_empty():
				continue
			var la := -(float(m["lat"]) - 1.15)
			if k.libre(id, ss, la, 1.0, 0.6) and d.place_libre(g.sol_en(id, ss, la), 2.4, 1.5):
				place = true
				s_a = ss
				lat_a = la
				break
	if place:
		_autel(k, id, s_a, lat_a, e_a)
	else:
		push_warning("grotte v2 : pas de place libre pour l'autel de l'arène")
	# 1. enceinte : rangées de pieux inégaux près des parois, reliés par une lisse
	for cote: float in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		var s := s0 + 2.2
		while s < s1 - 3.0:
			var dl := g.demi_l(id, s)
			var w := dl.y if cote > 0.0 else dl.x
			var lat := cote * (w - rp.randf_range(0.85, 1.25))
			if k.libre(id, s, lat, 0.3, 0.6) and g.libre(id, s, lat, 0.3) and d.place_libre(g.sol_en(id, s, lat), 0.15, 2.0):
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

## Lot D : place de l'autel de l'arène choisie AVANT le mobilier et les roches du camp (sinon les roches contre la paroi et le mobilier
## ne lui laissent aucune place sans chevauchement) : contre une paroi, hors des apparitions et des coffres, sol plat sous toute l'estrade.
## Réservée par une empreinte (le mobilier, les roches et le kit la contournent) et rangée dans la méta `autel_place` [s, lat, échelle].
static func reserver_autel(g: Grotte) -> void:
	if not g.decor.regles_pose:
		return
	for z: Dictionary in g.def.get("zones", []):
		if String(z.get("theme", "")) != "repaire" or String(z.get("role", "")) != "combat":
			continue
		var id: String = z["branche"]
		var s0: float = z["s"][0]
		var s1: float = z["s"][1]
		var coffres: Array = []
		for cle in ["coffres", "ressources", "interactions"]:
			for c: Dictionary in z.get(cle, []):
				coffres.append(g.sol_en(id, float(c["s"]), float(c["lat"])))
		for ss0: float in [11.5, 11.0, 12.0, 10.5, 12.5, 10.0, 13.0, 9.5, 8.5, 7.5, 6.5, 5.5, 4.5]:     # la place d'origine d'abord, plus petit au besoin
			for cote: float in [-1.0, 1.0]:
				for e: float in [1.05, 0.9, 0.78]:
					var ss := s0 + ss0
					if ss > s1 - 2.5:
						continue
					var dmin := 99.0
					for hh: float in [0.6, 1.5, 2.4 * e + 0.3]:          # paroi la plus proche sur toute la hauteur du dossier
						var hit := g.rayon(g.sol_en(id, ss, 0.0) + Vector3(0, hh, 0), g.droite(id, ss) * cote, 15.0)
						if not hit.is_empty():
							dmin = minf(dmin, float(hit["d"]))
					if dmin > 90.0:
						continue
					var la := cote * (dmin - 1.6 * e - 0.6)
					if absf(la) < 1.6 or not g.libre(id, ss, la, 1.0) or not _autel_libre(g, id, ss, la, e):
						continue
					var ps := g.sol_en(id, ss, la)
					var loin := true
					for c: Vector3 in coffres:
						if Vector2(c.x - ps.x, c.z - ps.z).length() < 2.4 * e + 0.8:
							loin = false
					if not loin:
						continue
					var face := g.droite(id, ss)
					face.y = 0.0
					face = face.normalized() * (1.0 if la < 0.0 else -1.0)
					var bz := Basis(Vector3.UP, atan2(-face.x, -face.z))
					var ymax := -1e9
					var xx := -2.8 * e
					while xx <= 2.8 * e + 0.01:
						var zz := -2.5 * e                                    # éboulis devant compris
						while zz <= 1.9 * e + 0.01:
							var q := ps + bz * Vector3(xx, 0, zz)
							ymax = maxf(ymax, g.sol_objet(q.x, q.z, ps.y + 0.8))
							zz += 0.25
						xx += 0.25
					g.set_meta("autel_place", [ss, la, e, ymax - 0.05])           # pied : point le plus haut du sol - 5 cm (rien d'enfoui)
					for xr: float in [-1.6, 0.0, 1.6]:                              # trois cercles couvrent le rectangle de l'estrade
						g.decor._empreinte(ps + bz * Vector3(xr * e, 0, 0), 1.75 * e, 2.6 * e)
					return

## Lot D : vrai si l'estrade de l'autel (échelle e) tient en (s, lat) : sol de la galerie sous tout le rectangle, 3 m libres au-dessus, aucun
## objet posé, aucune roche du kit, aucun point d'apparition (grille de points tous les 0,5 m).
static func _autel_libre(g: Grotte, id: String, s_a: float, lat_a: float, e: float) -> bool:
	var d := g.decor
	var ps := g.sol_en(id, s_a, lat_a)
	var face := g.droite(id, s_a)
	face.y = 0.0
	face = face.normalized() * (1.0 if lat_a < 0.0 else -1.0)
	var bz := Basis(Vector3.UP, atan2(-face.x, -face.z))
	var hx := 2.4 * e
	var hz := 1.9 * e
	var x := -hx
	while x <= hx + 0.01:
		var z := -hz
		while z <= hz + 0.01:
			var q := ps + bz * Vector3(x, 0, z)
			var sp := g.sol_et_plafond(q.x, q.z, ps.y + 0.8)
			if sp.x < -1e8 or absf(sp.x - ps.y) > 0.3 or sp.y - sp.x < 3.0:
				return false
			q.y = sp.x
			if d._chevauche(q, 0.3, 1.5, false) > 0.02 or (z >= -1.6 * e and d.pres_apparition(q, 0.45)):     # un ennemi peut se tenir au pied des gradins
				return false
			z += 0.5
		x += 0.5
	return true

static func _autel(k: GrotteKit, id: String, s_a: float, lat_a: float, e := 1.2) -> void:
	k.g.decor.objet_debut("autel")
	var g: Grotte = k.g
	var d: GrotteDecor = g.decor
	var ps := g.sol_en(id, s_a, lat_a)
	if g.has_meta("autel_y"):
		ps.y = float(g.get_meta("autel_y"))
	var lac := atan2(g.tang(id, s_a).x, g.tang(id, s_a).z)
	var face := g.droite(id, s_a)                                  # l'autel regarde vers l'axe de l'arène (côté opposé à la paroi)
	face.y = 0.0
	face = face.normalized() * (1.0 if lat_a < 0.0 else -1.0)
	var yaw := atan2(-face.x, -face.z)                               # +z local = vers la paroi, -z local = vers la salle
	var bz := Basis(Vector3.UP, yaw)
	# estrade de pierre en ruine : deux gradins, massif en fer à cheval ouvert côté salle (planche vue 6), blocs éboulés ; boîtes
	# légèrement désaxées (silhouette anguleuse, faces plates), matière roche de la grotte. DÉCOR SEUL.
	var rs := RandomNumberGenerator.new()
	rs.seed = 7353
	var blocs: Array = [
		[Vector3(0, 0.28, 0), Vector3(4.8, 0.56, 3.2), 0.03],                    # gradin bas
		[Vector3(0, 0.84, 0.25), Vector3(3.7, 0.56, 2.4), -0.05],                # gradin haut
		[Vector3(0, 1.85, 0.85), Vector3(2.9, 1.45, 0.75), 0.02],                # dossier
		[Vector3(-1.45, 1.75, 0.2), Vector3(0.8, 1.25, 1.1), 0.1],               # flanc gauche
		[Vector3(1.45, 1.6, 0.2), Vector3(0.8, 0.95, 1.1), -0.12],               # flanc droit (plus bas, brisé)
		[Vector3(-1.45, 2.55, 0.25), Vector3(0.6, 0.45, 0.8), 0.35],             # chapiteau tombé
		[Vector3(0.2, 2.75, 0.9), Vector3(1.3, 0.4, 0.6), -0.2],                 # linteau brisé
		[Vector3(0.0, 1.25, -0.2), Vector3(1.5, 0.35, 0.9), 0.0],                # table d'offrande
		[Vector3(-2.2, 0.2, -1.5), Vector3(0.9, 0.4, 0.7), 0.5],                 # éboulis devant
		[Vector3(2.1, 0.17, -1.6), Vector3(0.7, 0.34, 0.6), -0.4],
		[Vector3(0.9, 0.12, -2.0), Vector3(0.5, 0.24, 0.45), 0.9],
	]
	for bl: Array in blocs:
		var sz: Vector3 = bl[1]
		d.boite_b("c_strate_mousse", ps + bz * (bl[0] as Vector3) * e, sz * e, bz * Basis(Vector3.UP, float(bl[2])))
	var f := e / 1.2
	var top := ps + bz * Vector3(0, 1.74, -0.24) * f
	var bas1 := ps + bz * Vector3(0, 1.34, -0.84) * f
	var bas0 := ps + bz * Vector3(0, 0.67, -1.56) * f
	for q: Array in [[-0.5, 0.0], [0.45, 0.1], [0.0, -0.25]]:
		d.bougie(top + bz * Vector3(float(q[0]), 0, float(q[1])) * f, false)
	for q: Array in [[-1.2, 0.0], [1.2, 0.0], [-0.7, -0.35], [0.8, -0.4]]:
		d.bougie(bas1 + bz * Vector3(float(q[0]), 0, float(q[1])) * f, false)
	for q: Array in [[-2.0, -0.2], [-1.3, -0.5], [1.4, -0.5], [2.0, -0.2], [0.0, -0.7]]:
		d.bougie(bas0 + bz * Vector3(float(q[0]), 0, float(q[1])) * f, false)
	d._prof_pose += 1
	d.crane(top + bz * Vector3(-0.1, 0.0, 0.1) * f, yaw + 2.5)
	d._prof_pose -= 1
	g.set_meta("v2_autel", bas1 + bz * Vector3(0.0, 0.8, -0.3))      # centre des bougies : sa lumière est posée par Grotte._lumieres_structures
	k._occuper_fixe(id, s_a, lat_a, 2.2 * f)
	d._empreinte(ps, 2.0 * e, 2.6 * e)
	k.g.decor.objet_fin()                                   # l'estrade est un objet ; les pieux (plantés) en sont d'autres
	k.g.decor.objet_debut("pieux")
	# demi-cercle de pieux devant l'autel (côté salle), reliés par une lisse
	var rq := RandomNumberGenerator.new()
	rq.seed = 7352
	var prev := Vector3.ZERO
	for a_deg: float in [-75.0, -45.0, -15.0, 15.0, 45.0, 75.0]:
		var a := deg_to_rad(a_deg)
		var sq := s_a + sin(a) * 2.0
		var lq := lat_a + cos(a) * 2.0
		if lat_a < -3.0 or e != 1.2:                           # grand autel : arc de pieux côté arène, autour du gradin
			var sg := 1.0 if lat_a < 0.0 else -1.0
			sq = s_a - sin(a) * 3.3 * f
			lq = lat_a + sg * cos(a) * 3.3 * f
		if not (k.libre(id, sq, lq, 0.3, 0.6) and g.libre(id, sq, lq, 0.3) and d.place_libre(g.sol_en(id, sq, lq), 0.15, 2.0)):
			prev = Vector3.ZERO
			continue
		var pq := g.sol_en(id, sq, lq)
		var hq := rq.randf_range(1.5, 2.3)
		_pieu(d, pq, hq, Vector3(rq.randf_range(-0.1, 0.1), 0.0, rq.randf_range(-0.1, 0.1)) * hq, rq.randf_range(0.1, 0.14))
		k._occuper_fixe(id, sq, lq, 0.4)
		if prev != Vector3.ZERO:
			_poutre(d, prev + Vector3(0, 0.9, 0), pq + Vector3(0, 0.9, 0), 0.07, 0.07)
		prev = pq
	print("grotte v2 : autel de l'arène à s=%.1f lat=%.1f" % [s_a, lat_a])
	k.g.decor.objet_fin()
