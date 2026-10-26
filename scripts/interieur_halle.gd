class_name InterieurHalle
## Halle de Gunnhild Aldrsdotir, cheffe de Skarnholt (longue maison 14 × 7 m, repère local : X grand axe, porte côté +Z).
##
## Macro : nef de rondins entre deux files de poteaux octogonaux, foyer long au centre sous le trou à fumée, estrade du
##   trône face à la porte, plafond sous charpente.
## Méso  : longues tables sur tréteaux et bancs, trône sculpté, coffres ferrés, tonneaux, râteliers d'armes, lit clos.
## Micro : étain, chopes, pain, os rongés, cornes à boire, parchemins, viandes pendues, peaux au sol, paille.

static func construire(b: Interieurs) -> void:
	var F := Interieurs.F
	var xh := (b.trou3.x + b.trou3.y) * 0.5          # axe du foyer = axe du trou à fumée
	# --- sol : dalles autour du foyer, peaux, paille
	b.dallage(Rect2(xh - 3.2, -1.3, 6.4, 2.6))
	b.peau_sol(Vector3(-4.2, 0, 0.4), Vector2(1.5, 1.1), 0.3, "peau_sombre")
	b.peau_sol(Vector3(3.6, 0, 0.1), Vector2(1.3, 0.9), -0.4, "peau_claire")
	b.paille(Vector3(-6.0, 0, -2.6), Vector2(1.6, 1.0))
	b.paille(Vector3(5.8, 0, 2.7), Vector2(1.2, 0.9))

	# --- foyer long : cadre de pierre, cendres et braises, bûches, flammes, rai de lumière par le trou à fumée
	_foyer(b, xh)

	# --- estrade et trône (face à la porte, contre le long pan -Z)
	_estrade(b)

	# --- tables, bancs
	for sx in [-1.0, 1.0]:
		b.table(Vector3(sx * 3.9, 0, -1.75), 4.3, 0.8, 0.0)
		_couvert(b, sx * 3.9, -1.75, 4.3)
		b.banc(Vector3(sx * 3.9, 0, -2.55), 4.2, 0.0)
	b.table(Vector3(-3.7, 0, 1.75), 4.8, 0.8, 0.0)
	_couvert(b, -3.7, 1.75, 4.8)
	b.banc(Vector3(-3.7, 0, 2.55), 4.6, 0.0)
	b.table(Vector3(3.9, 0, 1.75), 4.2, 0.8, 0.0)
	_couvert(b, 3.9, 1.75, 4.2)
	b.banc(Vector3(3.9, 0, 2.55), 4.0, 0.0)
	# bancs côté foyer, tabourets
	b.banc(Vector3(-3.7, 0, 1.12), 3.4, 0.0, 0.44, 0.3)
	b.banc(Vector3(xh - 0.5, 0, -1.1), 3.0, 0.0, 0.44, 0.3)
	b.tabouret(Vector3(xh + 2.25, 0, 0.4))
	b.tabouret(Vector3(xh - 3.6, 0, -0.3))

	# --- poteaux sous les entraits (deux files le long des longs pans)
	for x in Interieurs.FERMES["halle"]:
		for sz in [-1.0, 1.0]:
			b.poteau(Vector3(x, 0, sz * 3.08), 0.16, b.y0 - 0.3)
			# écus de pierre à la base, chevilles de fer
			b.bx(Vector3(x, 1.45, sz * 3.08 - sz * 0.0), Vector3(0.38, 0.06, 0.38), "fer_noir", 0.39)

	# --- long pan arrière (z = -3.31, lacet 0) : tentures, boucliers, ramures, appliques
	var zb := -3.3
	b.tenture(Vector3(0, 1.62, zb), 0.0, 1.5, 2.0, "tenture_r")
	b.tenture(Vector3(-2.75, 1.62, zb), 0.0, 1.5, 2.0, "tenture_b")
	b.tenture(Vector3(2.75, 1.62, zb), 0.0, 1.5, 2.0, "tenture_v")
	b.ramure(Vector3(-1.55, 2.0, zb), 0.0, 1.0)
	b.ramure(Vector3(1.55, 2.0, zb), 0.0, 1.0)
	var mats := ["bouclier_r", "bouclier_b", "bouclier_j", "bouclier_n", "bouclier_r", "bouclier_b"]
	for k in 6:
		var sgn := -1.0 if k < 3 else 1.0
		var x := sgn * (4.2 + (k % 3) * 0.95)
		b.bouclier(Vector3(x, 1.75, zb), 0.0, 0.36, mats[k])
	b.applique(Vector3(-1.2, 1.8, zb), 0.0, 1.5, 5.5)
	b.applique(Vector3(1.2, 1.8, zb), 0.0, 1.5, 5.5)
	b.bx(Vector3(-5.9, 0.9, -3.0), Vector3(0.9, 1.0, 0.5), "bois_v", 0.0, true)       # dressoir d'angle
	_dressoir_garni(b, Vector3(-5.9, 0.9 + 0.5, -3.0))

	# --- long pan avant (z = +3.31, lacet PI) : râteliers, tentures, barils
	var zf := 3.3
	_rateau_armes(b, Vector3(-1.95, 1.55, zf), PI, "lances")
	_rateau_armes(b, Vector3(1.95, 1.55, zf), PI, "haches")
	b.tenture(Vector3(-5.6, 1.7, zf), PI, 1.5, 2.0, "tenture_v")
	b.tenture(Vector3(5.6, 1.7, zf), PI, 1.5, 2.0, "tenture_b")
	b.applique(Vector3(-0.95, 1.9, zf - 0.02), PI, 1.5, 5.5, false)
	b.applique(Vector3(0.95, 1.9, zf - 0.02), PI, 1.5, 5.5, false)

	# --- bout ouest (x = -6.85, lacet PI/2) : réserve de bière et de grain
	var xw := -6.8
	for k in 3:
		b.tonneau(Vector3(xw + 0.4, 0, -2.2 + k * 0.78))
	b.tonneau(Vector3(xw + 0.42, 0.9, -1.8), 0.9)
	b.tonneau(Vector3(xw + 1.25, 0, -2.55), 0.85)
	b.coffre(Vector3(xw + 0.4, F, 0.6), PI * 0.5, Vector3(0.95, 0.5, 0.58))
	b.coffre(Vector3(xw + 0.38, F, 1.5), PI * 0.5, Vector3(0.95, 0.5, 0.58))
	b.coffre(Vector3(xw + 0.4, F + 0.52, 0.6), PI * 0.5, Vector3(0.8, 0.42, 0.5))
	b.etagere(Vector3(xw + 0.17, F, 2.55), PI * 0.5, 1.4, 1.9, 4, 0.32)
	for k in 4:
		b.cruche(Vector3(xw + 0.2, F + 0.52 + 0.46 * (k % 3), 2.2 + 0.28 * (k % 2) + int(k / 3) * 0.2))
	for k in 3:
		b.sac(Vector3(xw + 0.55 + k * 0.5, F, 2.9), 0.3 + k * 0.7)
	b.tenture(Vector3(xw + 0.04, 1.7, -0.3), PI * 0.5, 1.5, 2.0, "tenture_r")

	# --- bout est (x = +6.85, lacet -PI/2) : lit clos de la cheffe, coffre, trophées
	var xe := 6.8
	_lit_clos(b, xe)
	b.coffre(Vector3(xe - 0.38, F, 1.2), -PI * 0.5, Vector3(1.0, 0.55, 0.6))
	b.coffre(Vector3(xe - 0.38, F, 2.2), -PI * 0.5, Vector3(0.9, 0.5, 0.56))
	b.peau_murale(Vector3(xe - 0.06, 1.7, 0.0), -PI * 0.5, 1.1, 1.5, "peau_sombre")
	b.ramure(Vector3(xe - 0.06, 2.1, 1.7), -PI * 0.5, 1.1)
	b.applique(Vector3(xe - 0.04, 1.8, 0.95), -PI * 0.5, 1.4, 5.0, true)
	b.crane(Vector3(xe - 0.5, F + 0.55 + 0.46, 1.2), -PI * 0.5, 1.4)

	# --- objets suspendus aux entraits : viandes, poissons, herbes, lanterne
	for x in [-5.2, -2.6, 3.0, 5.2]:
		b.viande_seche(Vector3(x, b.y0 - 0.3, -2.0), 3, 0.0)
		b.herbes(Vector3(x + 0.5, b.y0 - 0.3, 2.1), 0.3)
	b.viande_seche(Vector3(1.4, b.y0 - 0.3, 1.9), 4, 0.0)
	_lanterne(b, Vector3(-2.6, b.y0 - 0.32, 0.0))

	# --- Micro au sol
	for k in 7:
		var x := b.rng.randf_range(-5.8, 5.8)
		var z := b.rng.randf_range(-1.0, 1.0)
		if absf(z) < 0.7 and x > xh - 2.3 and x < xh + 2.3:
			continue
		b.os_sol(Vector3(x, F, z), b.rng.randf() * TAU)
	b.buches(Vector3(xh + 2.6, F, -2.45))
	b.buches(Vector3(xh - 3.0, F, 2.0), PI * 0.5)

	b.solide(Vector3(0, F + 0.5, -3.34), Vector3(13.6, 1.0, 0.1))   # (sécurité contre les arêtes de rondins)

static func _foyer(b: Interieurs, xh: float) -> void:
	var F := Interieurs.F
	var lg := 4.4
	var lz := 1.3
	# cadre de pierre
	for sz in [-1.0, 1.0]:
		b.pile(Vector3(xh, F + 0.1, sz * (lz * 0.5 + 0.08)), Vector3(lg + 0.3, 0.26, 0.26), 7100 + int(sz), "brute", false, 0.0)
	for sx in [-1.0, 1.0]:
		b.pile(Vector3(xh + sx * (lg * 0.5 + 0.08), F + 0.1, 0), Vector3(0.26, 0.26, lz + 0.3), 7110 + int(sx), "brute", false, 0.0)
	b.solide(Vector3(xh, F + 0.15, 0), Vector3(lg + 0.4, 0.3, lz + 0.4))
	# lit de cendre et de braises
	b.bx(Vector3(xh, F + 0.06, 0), Vector3(lg - 0.1, 0.12, lz - 0.1), "cendre")
	for k in 9:
		var x := xh - lg * 0.5 + 0.35 + k * (lg - 0.7) / 8.0
		b.bx(Vector3(x, F + 0.125, b.rng.randf_range(-0.3, 0.3)), Vector3(0.5, 0.02, 0.4), "braises", b.rng.randf() * 3.0)
	# bûches posées en travers
	for k in 6:
		var x := xh - lg * 0.5 + 0.45 + k * (lg - 0.9) / 5.0
		b.rondin(Vector3(x, F + 0.2, b.rng.randf_range(-0.12, 0.12)), PI * 0.5 + b.rng.randf_range(-0.25, 0.25), 1.0 + b.rng.randf() * 0.15, 0.08, 320 + k, "rondin_sombre", b.rng.randf_range(-0.1, 0.1))
	# flammes
	for k in 4:
		b.flamme(Vector3(xh - 1.6 + k * 1.07, F + 0.16, b.rng.randf_range(-0.12, 0.12)), 2.3 - 0.25 * (k % 2))
	b.halo(Vector3(xh, F + 0.04, 0), Vector3.UP, 6.4, 3.4, Color(1, 0.9, 0.8, 1))
	b.halo(Vector3(xh, F + 0.04, 0), Vector3.UP, 4.4, 2.2, Color(1, 0.85, 0.7, 1))
	b.lumiere(Vector3(xh - 1.3, F + 1.0, 0), 2.6, 8.5)
	b.lumiere(Vector3(xh + 1.3, F + 1.0, 0), 2.6, 8.5)
	# rai de lumière du trou à fumée jusqu'au foyer (quatre plans croisés, volume : shader ps1_rai)
	var haut := b.y0 + b.faite - F - 0.1
	b.halo(Vector3(xh, F + haut * 0.5, 0), Vector3.BACK, 1.5, haut, Color(1.3, 1.25, 1.1, 1), "rai")
	# crémaillère et marmite au-dessus du foyer (côté est)
	b.cyl(Vector3(xh + 1.2, b.y0 + 0.6, 0), 0.02, 2.4, "fer_noir", 4)
	b.chaudron(Vector3(xh + 1.2, F + 0.62, 0), 0.28)

## Estrade de planches à deux marches et haut-siège sculpté de la cheffe (modules Blender L6 : estrade_halle, trone_halle) ;
## collisions inchangées (marches, assise, bloc du dossier).
static func _estrade(b: Interieurs) -> void:
	var F := Interieurs.F
	b.solide(Vector3(0, F + 0.11, -2.65), Vector3(3.1, 0.22, 1.3))
	b.solide(Vector3(0, F + 0.05, -1.85), Vector3(3.1, 0.1, 0.34))
	b.modele("estrade_halle", Vector3(0, F, -2.65))
	# peau d'ours devant le trône
	b.peau_sol(Vector3(0, F + 0.23, -2.45), Vector2(1.5, 1.1), 0.0, "peau_sombre")
	var y := F + 0.22
	b.solide(Vector3(0, y + 0.45, -2.95), Vector3(0.78, 0.1, 0.66))
	b.modele("trone_halle", Vector3(0, y, -2.95))
	b.solide(Vector3(0, y + 1.2, -3.1), Vector3(1.0, 2.4, 0.5))

static func _couvert(b: Interieurs, cx: float, cz: float, long: float) -> void:
	var F := Interieurs.F
	var y := F + 0.78
	var n := int(long / 0.7)
	for k in n:
		var x := cx - long * 0.5 + 0.45 + k * (long - 0.9) / maxi(n - 1, 1)
		var z := cz + b.rng.randf_range(-0.22, 0.22)
		match b.rng.randi() % 5:
			0:
				b.assiette(Vector3(x, y, z))
				b.bx(Vector3(x, y + 0.04, z), Vector3(0.12, 0.05, 0.1), "cuir", b.rng.randf() * 3.0)      # pain / viande
			1:
				b.chope(Vector3(x, y, z))
				b.chope(Vector3(x + 0.18, y, z + 0.1), "etain")
			2:
				b.assiette(Vector3(x, y, z), "bois_clair")
				b.bx(Vector3(x + 0.04, y + 0.04, z), Vector3(0.18, 0.04, 0.05), "os", b.rng.randf() * 3.0)
			3:
				b.cruche(Vector3(x, y, z), 0.28)
			_:
				b.parchemin(Vector3(x, y, z), b.rng.randf() * 3.0)
	b.bougie(Vector3(cx - long * 0.25, y, cz), 0.15)
	b.bougie(Vector3(cx + long * 0.2, y, cz - 0.1), 0.12)

static func _rateau_armes(b: Interieurs, pos: Vector3, lacet: float, quoi: String) -> void:
	var d := Basis(Vector3.UP, lacet) * Vector3.BACK
	var dr := Basis(Vector3.UP, lacet) * Vector3.RIGHT
	b.bx(pos + d * 0.07, Vector3(1.3, 0.1, 0.07), "bois_sombre", lacet)
	b.bx(pos + d * 0.07 - Vector3(0, 0.5, 0), Vector3(1.3, 0.1, 0.07), "bois_sombre", lacet)
	for k in 5:
		var x := -0.5 + k * 0.25
		if quoi == "lances":
			b.lance(pos + dr * x + d * 0.15 - Vector3(0, 0.1, 0), lacet, 0.04 * (k - 2), 2.0)
		else:
			b.hache(pos + dr * x + d * 0.15 - Vector3(0, 0.3, 0), lacet, 0.05 * (k - 2), 1.0)
	if quoi == "haches":
		b.bouclier(pos + dr * 0.0 + Vector3(0, -0.95, 0), lacet, 0.3, "bouclier_n")

static func _dressoir_garni(b: Interieurs, pos: Vector3) -> void:
	b.assiette(pos + Vector3(-0.2, 0, 0.0))
	b.assiette(pos + Vector3(0.1, 0, 0.0))
	b.chope(pos + Vector3(0.3, 0, 0.1))
	b.cruche(pos + Vector3(-0.35, 0, 0.1), 0.3)
	b.bougie(pos + Vector3(0.0, 0, 0.12), 0.1)

static func _lit_clos(b: Interieurs, xe: float) -> void:
	var F := Interieurs.F
	# alcôve de planches : cloison à claire-voie, ciel de lit, lit large et peaux
	b.bx(Vector3(xe - 0.35, 1.0, -2.0), Vector3(1.1, 1.0, 1.9), "bois_sombre", 0.0, true)     # coffre-banquette sous la couche
	b.lit(Vector3(xe - 1.05, F, -2.15), PI * 0.5, 2.0, 1.4, "peau_claire")
	b.bx(Vector3(xe - 1.9, 0.95 + F * 0.0, -2.15), Vector3(0.08, 1.0, 1.5), "bois_v")
	b.bx(Vector3(xe - 0.45, 1.8, -2.15), Vector3(1.9, 0.07, 1.6), "bois_sombre", PI * 0.5)
	for sz in [-1.0, 1.0]:
		b.poteau(Vector3(xe - 1.78, 0, -2.15 + sz * 0.78), 0.07, 1.8, "bois_sombre", true)
	b.tenture(Vector3(xe - 0.04, 1.2, -2.7), -PI * 0.5, 1.2, 1.6, "tenture_r")

static func _lanterne(b: Interieurs, pos: Vector3) -> void:
	b.cyl(pos + Vector3(0, 0.5, 0), 0.008, 1.0, "fer_noir", 4)
	b.cyl(pos + Vector3(0, -0.04, 0), 0.1, 0.22, "fer_noir", 6, false, 0.07)
	b.cyl(pos + Vector3(0, 0.1, 0), 0.115, 0.04, "fer_noir", 6)
	b.flamme(pos + Vector3(0, -0.12, 0), 0.7)
	b.halo(pos, Vector3.UP, 0.9, 0.9)
