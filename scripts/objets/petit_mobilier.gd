class_name ObjPetitMobilier
## Petit mobilier commun crypte + grotte (lot L2) : coffres, bougies, urnes, tonneaux, tables, crânes, os, armes, gravats, sacs, parchemins.
## Corps des objets sortis de CrypteDecor (scripts/crypte_decor.gd) sans changer le rendu : chaque fonction reçoit le décor `dcr`
## (CrypteDecor ou GrotteDecor) et l'appelle comme avant (dcr.boite, dcr.solide, dcr.rng…) ; CrypteDecor garde une fonction d'une ligne
## du même nom (mêmes paramètres), que GrotteDecor peut toujours surcharger. Ne pas appeler ces fonctions directement : passer par le décor.

static func coffre(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, collision := true) -> void:
	dcr.j0("coffre", lacet)
	pos = dcr._ecarter(pos, Vector2(0.47, 0.3), lacet)
	dcr.emprise("coffre", pos, Vector2(0.47, 0.3), lacet, 0.64)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("bois", pos + Vector3(0, 0.22, 0), Vector3(0.9, 0.44, 0.56), lacet)
	dcr.boite("bois", pos + Vector3(0, 0.5, 0), Vector3(0.9, 0.12, 0.5), lacet)
	dcr.boite("bois", pos + Vector3(0, 0.58, 0), Vector3(0.9, 0.06, 0.38), lacet)
	for dx in [-0.3, 0.3]:
		dcr.boite("fer", pos + b * Vector3(dx, 0.31, 0), Vector3(0.09, 0.64, 0.6), lacet)
	dcr.boite("fer", pos + b * Vector3(0, 0.44, 0.285), Vector3(0.12, 0.14, 0.03), lacet)
	dcr.boite("fer", pos + Vector3(0, 0.02, 0), Vector3(0.94, 0.05, 0.6), lacet)
	if collision:
		var s := b * Vector3(0.9, 0, 0.56)
		dcr.solide(pos + Vector3(0, 0.3, 0), Vector3(absf(s.x), 0.6, absf(s.z)))
	dcr.j1()

static func bougie(dcr: CrypteDecor, pos: Vector3, avec_lumiere := true) -> void:
	dcr.j0("bougie")
	pos = dcr._suivre(pos)
	dcr.emprise("bougie", pos, Vector2(0.06, 0.06), 0.0, 0.14)
	dcr.tour("os", pos, [Vector2(0.03, 0.0), Vector2(0.026, 0.14)], 6, 0.0, true)
	dcr.tour("fer", pos, [Vector2(0.06, 0.0), Vector2(0.06, 0.012)], 6, 0.0, true)
	dcr.flamme(pos + Vector3(0, 0.14, 0), 0.4)
	if avec_lumiere:
		dcr.lumiere(pos + Vector3(0, 0.4, 0), CrypteDecor.FEU, 0.9, 4.0, 1.8)
	dcr.j1()

static func urne(dcr: CrypteDecor, pos: Vector3, e := 1.0, cotes := 8) -> void:
	dcr.j0("urne")
	pos = dcr._suivre(pos)
	pos = dcr._ecarter(pos, Vector2(0.26, 0.26) * e)
	dcr.emprise("urne", pos, Vector2(0.26, 0.26) * e, 0.0, 0.56 * e)
	var prof := [Vector2(0.13, 0.0), Vector2(0.2, 0.08), Vector2(0.25, 0.22), Vector2(0.21, 0.4), Vector2(0.12, 0.5), Vector2(0.14, 0.56), Vector2(0.09, 0.56)]
	var pe: Array = []
	for p: Vector2 in prof:
		pe.append(p * e)
	dcr.tour("argile", pos, pe, cotes, 0.0, false)
	if dcr.est_crypte and e >= 0.45:      # 4e passe : bandeau d'entrelacs gravé sur la panse (références : urnes ornées des niches)
		dcr.tour("entrelacs", pos + Vector3(0, 0.15 * e, 0), [Vector2(0.244 * e, 0.0), Vector2(0.256 * e, 0.07 * e), Vector2(0.244 * e, 0.14 * e)], cotes, 0.0, false)
	dcr.j1()

static func tonneau(dcr: CrypteDecor, pos: Vector3, e := 1.0) -> void:
	dcr.j0("tonneau")
	pos = dcr._ecarter(pos, Vector2(0.4, 0.4) * e)
	dcr.emprise("tonneau", pos, Vector2(0.4, 0.4) * e, 0.0, e)
	var prof := [Vector2(0.3, 0.0), Vector2(0.37, 0.25), Vector2(0.4, 0.5), Vector2(0.37, 0.75), Vector2(0.3, 1.0)]
	var pe: Array = []
	for p: Vector2 in prof:
		pe.append(p * e)
	dcr.tour("bois", pos, pe, 8, 0.0, true)
	for y in [0.16, 0.84]:
		var r: float = (0.34 if y < 0.5 else 0.34) * e + 0.012
		dcr.tour("fer", pos + Vector3(0, y * e, 0), [Vector2(r, -0.03 * e), Vector2(r, 0.03 * e)], 8, 0.0, false)
	dcr.j1()

static func table(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("table", lacet)
	pos = dcr._ecarter(pos, Vector2(0.55, 0.33), lacet)
	dcr.emprise("table", pos, Vector2(0.55, 0.33), lacet, 0.8)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("bois", pos + Vector3(0, 0.76, 0), Vector3(1.1, 0.07, 0.65), lacet)
	for sx in [-0.5, 0.5]:
		for sz in [-0.27, 0.27]:
			dcr.boite("bois", pos + b * Vector3(sx, 0.36, sz), Vector3(0.07, 0.72, 0.07), lacet)
	dcr.boite("bois", pos + Vector3(0, 0.22, 0), Vector3(0.95, 0.05, 0.05), lacet)
	dcr.boite("parchemin", pos + b * Vector3(-0.25, 0.8, 0.05), Vector3(0.3, 0.012, 0.22), lacet + 0.2)
	dcr.tour("fer", pos + b * Vector3(0.28, 0.795, -0.08), [Vector2(0.1, 0.0), Vector2(0.12, 0.012), Vector2(0.07, 0.02)], 8, 0.0, false)
	dcr.tour("fer", pos + b * Vector3(0.36, 0.795, 0.14), [Vector2(0.07, 0.0), Vector2(0.085, 0.01), Vector2(0.05, 0.016)], 8, 0.0, false)
	dcr.j1()

static func crane(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("crane", lacet)
	pos = dcr._suivre(pos)
	dcr.emprise("crane", pos, Vector2(0.1, 0.1), 0.0, 0.22)
	var b := Basis(Vector3.UP, lacet)
	var prof := [Vector2(0.055, 0.0), Vector2(0.085, 0.05), Vector2(0.095, 0.11), Vector2(0.07, 0.17), Vector2(0.0, 0.19)]
	dcr.tour("os", pos + Vector3(0, 0.035, 0), prof, 6, 0.0, true)
	dcr.boite("os", pos + b * Vector3(0, 0.03, 0.05), Vector3(0.09, 0.05, 0.08), lacet)
	if dcr.est_crypte:       # crypte (crânes par dizaines sur les étagères) : orbites et nez en simples faces avant
		var av := b * Vector3(0, 0, 1)
		var dx := b * Vector3(1, 0, 0)
		for e: Array in [[-0.03, 0.11, 0.018, 0.02], [0.03, 0.11, 0.018, 0.02], [0.0, 0.075, 0.01, 0.015]]:
			var c: Vector3 = pos + b * Vector3(float(e[0]), float(e[1]), 0.097)
			var hx: float = e[2]
			var hy: float = e[3]
			dcr.quad("noir", c - dx * hx - Vector3(0, hy, 0), c + dx * hx - Vector3(0, hy, 0), c + dx * hx + Vector3(0, hy, 0), c - dx * hx + Vector3(0, hy, 0), av)
		dcr.j1()
		return
	for sx in [-0.03, 0.03]:
		dcr.boite("noir", pos + b * Vector3(sx, 0.11, 0.085), Vector3(0.036, 0.04, 0.02), lacet)
	dcr.boite("noir", pos + b * Vector3(0, 0.075, 0.09), Vector3(0.02, 0.03, 0.02), lacet)
	dcr.j1()

static func os_tas(dcr: CrypteDecor, pos: Vector3, n := 4, rayon := 0.4) -> void:
	dcr.j0("os_tas")
	dcr.emprise("os_tas", pos, Vector2(rayon + 0.15, rayon + 0.15), 0.0, 0.2)
	for k in n:
		var a := dcr.rng.randf() * TAU
		var d := dcr.rng.randf() * rayon
		var l := dcr.rng.randf_range(0.2, 0.36)
		dcr.boite("os", pos + Vector3(cos(a) * d, 0.02 + 0.02 * (k % 2), sin(a) * d), Vector3(l, 0.04, 0.04), dcr.rng.randf() * TAU)
		dcr.boite("os", pos + Vector3(cos(a) * d, 0.03, sin(a) * d), Vector3(0.07, 0.05, 0.07), dcr.rng.randf() * TAU)
	dcr.crane(pos + Vector3(dcr.rng.randf_range(-0.1, 0.1), 0.0, dcr.rng.randf_range(-0.1, 0.1)), dcr.rng.randf() * TAU)
	dcr.j1()

static func arme(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("arme", lacet)
	dcr.emprise("arme", pos, Vector2(0.5, 0.12), lacet, 0.04)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("lame", pos + Vector3(0, 0.013, 0) + b * Vector3(0.45, 0, 0), Vector3(0.82, 0.014, 0.075), lacet)
	dcr.boite("fer", pos + Vector3(0, 0.018, 0) + b * Vector3(0.03, 0, 0), Vector3(0.05, 0.03, 0.24), lacet)
	dcr.boite("bois", pos + Vector3(0, 0.014, 0) - b * Vector3(0.1, 0, 0), Vector3(0.18, 0.03, 0.03), lacet)
	dcr.boite("fer", pos + Vector3(0, 0.02, 0) - b * Vector3(0.21, 0, 0), Vector3(0.05, 0.04, 0.05), lacet)
	dcr.j1()

## Tas de gravats (roche effondrée) : cône irrégulier et blocs ; collision facultative.
static func gravats(dcr: CrypteDecor, pos: Vector3, r := 1.0, h := 0.7, avec_collision := true, mat := "mur2") -> void:
	dcr.j0("gravats")
	dcr.emprise("gravats", pos, Vector2(r, r), 0.0, h)
	dcr.tour(mat, pos, [Vector2(r, 0.0), Vector2(r * 0.8, h * 0.45), Vector2(r * 0.42, h * 0.85), Vector2(r * 0.12, h)], 7, 0.3, true)
	for k in 5:
		var a := dcr.rng.randf() * TAU
		var rr := r * dcr.rng.randf_range(0.55, 1.05)
		var t := dcr.rng.randf_range(0.18, 0.4)
		dcr.boite(mat if k % 2 == 0 else "mur1", pos + Vector3(cos(a) * rr, t * 0.4, sin(a) * rr), Vector3(t * 1.4, t * 0.8, t), dcr.rng.randf() * TAU)
	if avec_collision:
		dcr.solide(pos + Vector3(0, h * 0.4, 0), Vector3(r * 1.5, h * 0.8, r * 1.5))
	dcr.j1()

## Sac de pillard éventré (étoffe, pièces, os) et coffre forcé (couvercle dressé derrière, serrure arrachée).
static func sac_dechire(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("sac_dechire")
	dcr.emprise("sac_dechire", pos, Vector2(0.45, 0.35), 0.0, 0.2)
	dcr.boite("jute", pos + Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.34), lacet + 0.3, false, Vector3.ZERO)
	dcr.boite("jute", pos + Vector3(0.18, 0.025, 0.2), Vector3(0.45, 0.02, 0.3), lacet - 0.5)
	for k in 7:
		dcr.boite("or", pos + Vector3(dcr.rng.randf_range(-0.4, 0.5), 0.012, dcr.rng.randf_range(-0.3, 0.5)), Vector3(0.05, 0.015, 0.05), dcr.rng.randf() * TAU)
	dcr.boite("fer", pos + Vector3(0.5, 0.02, -0.1), Vector3(0.12, 0.04, 0.12), dcr.rng.randf() * TAU)
	dcr.j1()

static func coffre_force(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("coffre_force", lacet)
	pos = dcr._ecarter(pos, Vector2(0.47, 0.3), lacet)
	dcr.emprise("coffre_force", pos, Vector2(0.47, 0.3), lacet, 0.9)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("bois", pos + Vector3(0, 0.22, 0), Vector3(0.9, 0.44, 0.56), lacet)
	dcr.boite("noir", pos + Vector3(0, 0.445, 0), Vector3(0.78, 0.01, 0.44), lacet)
	dcr.boite("bois", pos + b * Vector3(0, 0.62, -0.3), Vector3(0.9, 0.5, 0.06), lacet + 0.12)
	for dx in [-0.3, 0.3]:
		dcr.boite("fer", pos + b * Vector3(dx, 0.31, 0), Vector3(0.09, 0.64, 0.6), lacet)
	dcr.solide(pos + Vector3(0, 0.3, 0), (b * Vector3(0.9, 0.6, 0.56)).abs())
	for k in 5:
		dcr.boite("or", pos + b * Vector3(dcr.rng.randf_range(-0.5, 0.5), 0.012, dcr.rng.randf_range(0.35, 0.8)), Vector3(0.05, 0.015, 0.05), dcr.rng.randf() * TAU)
	dcr.j1()

## Parchemins, feuillets et livres éparpillés au sol (archives pillées).
static func parchemins_epars(dcr: CrypteDecor, centre: Vector3, rayon: float, n := 12) -> void:
	dcr.j0("parchemins_epars")
	for k in n:
		var a := dcr.rng.randf() * TAU
		var r := sqrt(dcr.rng.randf()) * rayon
		var p := centre + Vector3(cos(a) * r, 0.01 + 0.004 * (k % 3), sin(a) * r)
		if k % 4 == 0:
			dcr.boite("bois", p + Vector3(0, 0.03, 0), Vector3(0.2, 0.06, 0.28), dcr.rng.randf() * TAU)
		else:
			dcr.boite("parchemin", p, Vector3(dcr.rng.randf_range(0.2, 0.34), 0.01, dcr.rng.randf_range(0.14, 0.24)), dcr.rng.randf() * TAU)
	dcr.j1()
