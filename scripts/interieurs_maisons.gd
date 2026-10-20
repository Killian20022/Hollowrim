class_name InterieursMaisons
## Trois maisons de Skarnholt (8 × 5,5 m, 8 × 5,5 m, 7 × 5 m ; porte côté +Z, foyer-cheminée central contre une colonne de
## pierre à x = 0,15 L, bouche tournée vers -X).
##
## sigrun    : la voyante Sigrún (herbes, runes, crânes, bougies, plate-forme de transe, lueur bleue de rune).
## chasseurs : la famille d'Ylva Frostmark (peaux tendues, arcs, viande séchée, lit d'Eirik resté défait).
## grima     : Grima Cendrefroide, doyenne (métier à tisser, marmite, étagères de pots, tresses d'oignons).
## Règle : Macro = coque (b.coque) + colonne de foyer ; Méso = lits, tables, coffres, métiers ; Micro = petits objets.

static func construire(b: Interieurs, id: String) -> void:
	var xch := b.L * 0.15
	_colonne_foyer(b, xch)
	match id:
		"sigrun":
			_sigrun(b, xch)
		"chasseurs":
			_chasseurs(b, xch)
		"grima":
			_grima(b, xch)

# ------------------------------------------------------------------------------------------------ foyer central

## Colonne de pierre du sol au toit (elle se prolonge dehors par la cheminée du village), bouche tournée vers -X :
## niche, linteau, dalle d'âtre, braises, flamme, bûches, crémaillère et lumière.
static func _colonne_foyer(b: Interieurs, xch: float) -> void:
	var F := Interieurs.F
	var h_haut := b.y0 - 0.12
	var g := 7200 + int(xch * 10.0)
	# collier de pierre sur la base de la cheminée du dehors, puis gaine jusqu'au lambris (le fût extérieur reste caché)
	b.pile(Vector3(xch, b.y0 - 0.2, 0), Vector3(1.14, 0.56, 1.14), g + 11, "pierre")
	b.pile(Vector3(xch, b.y0 + 0.08 + (b.faite - 0.5) * 0.5, 0), Vector3(0.86, b.faite - 0.5 + 0.2, 0.86), g + 13, "pierre")
	# parois de la niche : fond, joues, linteau
	b.pile(Vector3(xch + 0.33, (F + h_haut) * 0.5, 0), Vector3(0.26, h_haut - F, 0.95), g, "pierre")
	for sz in [-1.0, 1.0]:
		b.pile(Vector3(xch - 0.12, (F + h_haut) * 0.5, sz * 0.4), Vector3(0.72, h_haut - F, 0.15), g + int(sz) + 3, "pierre")
	var y_l := F + 0.68
	b.pile(Vector3(xch - 0.12, (y_l + h_haut) * 0.5, 0), Vector3(0.72, h_haut - y_l, 0.95), g + 7, "pierre")
	b.bx(Vector3(xch - 0.45, y_l - 0.03, 0), Vector3(0.14, 0.12, 0.98), "bois_sombre")           # poutre de linteau
	b.solide(Vector3(xch, (F + h_haut) * 0.5, 0), Vector3(0.98, h_haut - F, 0.98))
	# intérieur de la niche : suie, braises, bûches
	b.bx(Vector3(xch + 0.2, F + 0.35, 0), Vector3(0.04, 0.6, 0.66), "cendre")
	b.bx(Vector3(xch - 0.14, F + 0.07, 0), Vector3(0.66, 0.14, 0.66), "cendre")
	b.bx(Vector3(xch - 0.14, F + 0.145, 0), Vector3(0.5, 0.02, 0.42), "braises")
	b.rondin(Vector3(xch - 0.12, F + 0.22, -0.12), 0.15, 0.62, 0.065, 351, "rondin_sombre")
	b.rondin(Vector3(xch - 0.1, F + 0.22, 0.14), -0.2, 0.62, 0.06, 352, "rondin_sombre")
	b.flamme(Vector3(xch - 0.12, F + 0.17, 0), 1.5)
	# âtre : dalle de pierre devant la bouche, halos, lumière
	b.dallage(Rect2(xch - 1.5, -0.85, 1.1, 1.7), "pierre_sombre", F + 0.03)
	b.halo(Vector3(xch - 0.85, F + 0.05, 0), Vector3.UP, 3.4, 3.4, Color(1, 0.9, 0.8, 1))
	b.lumiere(Vector3(xch - 0.9, F + 1.1, 0), 2.9, 7.5)
	# crémaillère : bras de fer pivotant et marmite
	b.cyl(Vector3(xch - 0.5, F + 1.3, 0.45), 0.025, 1.7, "fer_noir", 4)
	b.cyl_h(Vector3(xch - 0.88, F + 1.7, 0.45), 0.02, 0.8, "fer_noir", PI * 0.5, 4)
	b.chaudron(Vector3(xch - 0.3, F + 0.18, 0.0), 0.2)

# ------------------------------------------------------------------------------------------------ Sigrún

static func _sigrun(b: Interieurs, xch: float) -> void:
	var F := Interieurs.F
	var zb := -2.56          # plan du mur du fond (face intérieure)
	var zf := 2.56
	# --- sol : peaux, plate-forme de transe au centre-gauche, pierres de rune en cercle
	b.peau_sol(Vector3(-2.3, 0, 0.2), Vector2(1.7, 1.3), 0.4, "peau_claire")
	b.peau_sol(Vector3(xch + 1.5, 0, 0.9), Vector2(1.1, 0.8), -0.3, "peau_sombre")
	var cx := -1.55
	var cz := 0.35
	b.cyl(Vector3(cx, F + 0.05, cz), 1.05, 0.1, "bois_sombre", 8, true, 1.1)
	b.cyl(Vector3(cx, F + 0.105, cz), 0.82, 0.02, "bois_clair", 8)
	for k in 8:
		var a := TAU * k / 8.0
		var p := Vector3(cx + sin(a) * 0.65, F + 0.11, cz + cos(a) * 0.65)
		b.bloc(Vector3(0.17, 0.16, 0.13), 7300 + k, p + Vector3(0, 0.04, 0), "brute", a)
		b.bx(p + Vector3(0, 0.125, 0.0), Vector3(0.05, 0.012, 0.11), "rune", a)        # glyphe qui luit
		b.bx(p + Vector3(0.0, 0.126, 0.0), Vector3(0.11, 0.012, 0.035), "rune", a + 0.9)
	b.cyl(Vector3(cx, F + 0.55, cz), 0.03, 1.0, "bois_sombre", 6)                   # bâton de seiðr planté
	b.cyl(Vector3(cx, F + 1.1, cz), 0.06, 0.1, "os", 6, false, 0.035)
	b.halo(Vector3(cx, F + 0.12, cz), Vector3.UP, 2.4, 2.4, Color(0.25, 0.8, 1.0, 1))
	b.lumiere(Vector3(cx, F + 0.9, cz), 0.8, 3.6, Color(0.35, 0.8, 1.0), 1.6, false)
	# --- lit au coin du fond (ouest)
	b.lit(Vector3(-2.75, F, zb + 0.62), 0.0, 2.0, 1.0, "peau_sombre")
	b.peau_murale(Vector3(-2.75, 1.7, zb + 0.04), 0.0, 1.0, 1.2, "peau_claire")
	b.bx(Vector3(-3.6, 1.55, -1.55), Vector3(0.7, 0.04, 0.4), "bois", 0.0)           # petite planchette au chevet
	b.bougie(Vector3(-3.6, 1.57, -1.55), 0.12)
	# --- table de travail au fond, entre le lit et la colonne
	b.table(Vector3(0.1, 0, zb + 0.42), 2.2, 0.7, 0.0)
	var y := F + 0.78
	b.bx(Vector3(0.1, y + 0.003, zb + 0.42), Vector3(1.0, 0.012, 0.5), "parchemin")      # nappe de parchemin
	b.livre(Vector3(-0.55, y, zb + 0.4), 0.3)
	b.cyl(Vector3(0.3, y + 0.05, zb + 0.35), 0.075, 0.1, "brute", 8, false, 0.055)       # mortier
	b.cyl(Vector3(0.3, y + 0.14, zb + 0.35), 0.015, 0.2, "bois_clair", 6, false, 0.015)  # pilon
	b.crane(Vector3(0.75, y, zb + 0.5), -0.6, 1.1)
	b.cruche(Vector3(-0.2, y, zb + 0.55), 0.3)
	b.cruche(Vector3(0.95, y, zb + 0.3), 0.22)
	for k in 4:
		b.bloc(Vector3(0.1, 0.07, 0.08), 7330 + k, Vector3(-0.05 + k * 0.1, y + 0.04, zb + 0.15 + (k % 2) * 0.08), "brute", k * 0.7)
		b.bx(Vector3(-0.05 + k * 0.1, y + 0.078, zb + 0.15 + (k % 2) * 0.08), Vector3(0.025, 0.006, 0.05), "rune", k * 0.7)
	b.bougie(Vector3(0.85, y, zb + 0.7), 0.15)
	b.bougie(Vector3(0.95, y, zb + 0.62), 0.1)
	b.bougie(Vector3(-0.35, y, zb + 0.2), 0.18, true)
	b.balance(Vector3(0.55, y, zb + 0.25))
	b.tabouret(Vector3(0.1, 0, zb + 1.1))
	b.tenture(Vector3(0.1, 1.75, zb + 0.04), 0.0, 1.5, 2.0, "tenture_b")
	# --- étagère aux crânes (mur ouest) et herbier (mur est)
	b.etagere(Vector3(-3.7, F, 0.9), PI * 0.5, 1.5, 2.0, 4, 0.3)
	for k in 5:
		b.crane(Vector3(-3.7, F + 0.52 + 0.43 * (k % 3), 0.35 + 0.3 * k * 0.45), PI * 0.5, 0.9 + 0.1 * (k % 2))
	b.cruche(Vector3(-3.7, F + 0.96, 1.3), 0.26)
	b.ramure(Vector3(-3.78, 2.05, -0.3), PI * 0.5, 0.9)
	b.crane(Vector3(-3.7, 1.3, 1.6), PI * 0.5, 2.0)
	# --- côté est : coffre, tonneaux, sacs, perche d'herbes
	b.coffre(Vector3(3.5, F, -1.9), -PI * 0.5, Vector3(1.0, 0.55, 0.6))
	b.coffre(Vector3(3.55, F, -0.8), -PI * 0.5, Vector3(0.8, 0.5, 0.5))
	b.tonneau(Vector3(3.45, 0, 0.7), 0.85, 0.32)
	b.tonneau(Vector3(3.4, 0, 1.55), 0.8, 0.3)
	b.sac(Vector3(2.7, F, 2.05), 0.8)
	b.cyl_h(Vector3(2.9, F + 1.9, -2.5), 0.025, 2.0, "bois_sombre", 0.0, 6)
	for k in 6:
		b.herbes(Vector3(2.1 + k * 0.32, F + 1.88, -2.5), 0.2 * k, 0.9)
	# --- suspendus aux entraits : bouquets, mobile de runes et d'os
	for x in Interieurs.FERMES["sigrun"]:
		for k in 4:
			b.herbes(Vector3(x + (k - 1.5) * 0.45 + (1.1 if absf(x) < 0.2 else 0.0), b.y0 - 0.3, (k % 2) * 4.0 - 2.0), 0.6 * k, 0.8 + 0.08 * (k % 3))
	_mobile_runes(b, Vector3(-1.55, b.y0 - 0.1, 0.35))
	# --- côté porte : banc, peau, applique
	b.banc(Vector3(-2.5, 0, zf - 0.22), 1.6, 0.0)
	b.peau_murale(Vector3(2.5, 1.65, zf - 0.04), PI, 0.9, 1.1, "peau")
	b.applique(Vector3(-1.1, 1.85, zf - 0.02), PI, 1.4, 5.0, true)

static func _mobile_runes(b: Interieurs, pos: Vector3) -> void:
	b.cyl(pos + Vector3(0, -0.02, 0), 0.22, 0.03, "bois_sombre", 8)
	for k in 6:
		var a := TAU * k / 6.0
		var p := pos + Vector3(sin(a) * 0.17, 0, cos(a) * 0.17)
		b.cyl(p + Vector3(0, -0.2, 0), 0.006, 0.4, "cuir", 4)
		b.bx(p + Vector3(0, -0.42, 0), Vector3(0.05, 0.1, 0.02), "os" if k % 2 == 0 else "rune", a)

# ------------------------------------------------------------------------------------------------ chasseurs

static func _chasseurs(b: Interieurs, xch: float) -> void:
	var F := Interieurs.F
	var zb := -2.56
	var zf := 2.56
	# --- sol : peaux, bottes à sécher devant l'âtre
	b.peau_sol(Vector3(-2.2, 0, 0.0), Vector2(1.8, 1.4), 0.2, "peau_sombre")
	b.peau_sol(Vector3(xch - 1.4, 0, -1.2), Vector2(1.2, 0.9), 0.5, "peau_claire")
	for k in 2:
		b.cyl(Vector3(xch - 1.6 + k * 0.25, F + 0.14, 0.9 + k * 0.1), 0.06, 0.28, "cuir", 6, false, 0.08, Basis(Vector3.BACK, 0.15))
		b.cyl(Vector3(xch - 1.5 + k * 0.25, F + 0.04, 1.06 + k * 0.1), 0.065, 0.1, "cuir", 6, false, 0.07, Basis(Vector3.RIGHT, PI * 0.5))
	# --- lit d'Ylva (au fond, ouest) et lit défait d'Eirik (devant, ouest)
	b.lit(Vector3(-2.75, F, zb + 0.62), 0.0, 2.0, 1.0, "peau")
	b.peau_murale(Vector3(-2.75, 1.7, zb + 0.04), 0.0, 1.1, 1.3, "peau_sombre")
	b.lit(Vector3(-2.9, F, 1.7), 0.0, 1.95, 1.0, "peau_claire", 1)
	b.parchemin(Vector3(-2.6, F + 0.68, 1.62), 0.5)
	b.sac(Vector3(-3.5, F, 0.85), 1.3, 0.55)
	b.carquois(Vector3(-3.45, F + 0.28, 1.2), 0.3)
	# --- mur du fond : arcs, carquois, hache, épée ; table de dépeçage
	var yw := 1.65
	for k in 3:
		b.arc(Vector3(-0.35 + k * 0.5, yw, zb + 0.05), 0.0, 1.0 + 0.05 * k)
	b.carquois(Vector3(1.2, yw - 0.1, zb + 0.08), 0.0)
	b.carquois(Vector3(1.5, yw - 0.1, zb + 0.08), 0.2)
	b.bx(Vector3(0.5, yw + 0.55, zb + 0.04), Vector3(2.0, 0.06, 0.05), "bois_sombre")
	b.hache(Vector3(2.0, yw, zb + 0.08), 0.0, 0.05, 1.0)
	b.epee(Vector3(2.35, yw, zb + 0.08), 0.0, -0.05, 0.8)
	b.table(Vector3(0.6, 0, zb + 0.6), 2.0, 0.8, 0.0)
	var y := F + 0.78
	b.bx(Vector3(0.35, y + 0.03, zb + 0.55), Vector3(0.7, 0.06, 0.4), "peau_claire", 0.2)      # peau en cours de raclage
	b.bx(Vector3(1.0, y + 0.02, zb + 0.7), Vector3(0.22, 0.03, 0.06), "etain", 0.4)            # couteau
	b.bx(Vector3(1.2, y + 0.03, zb + 0.5), Vector3(0.16, 0.05, 0.08), "brute", 0.1)           # pierre à aiguiser
	b.os_sol(Vector3(0.0, y, zb + 0.75), 0.7)
	b.bougie(Vector3(1.5, y, zb + 0.4), 0.14, true)
	b.tabouret(Vector3(0.6, 0, zb + 1.3))
	# --- bout est : deux cadres de peaux tendues, tonneau de viande salée, caisses
	for k in 2:
		_cadre_peau(b, Vector3(3.2, 0, -1.6 + k * 1.5), PI * 0.5 + 0.1 * k)
	b.tonneau(Vector3(3.45, 0, 1.7), 0.9, 0.34)
	b.coffre(Vector3(2.5, F, 2.05), 0.0, Vector3(0.9, 0.5, 0.55))
	b.sac(Vector3(3.2, F, 0.55), 2.1, 0.5)
	b.ramure(Vector3(3.78, 2.0, -0.3), -PI * 0.5, 1.0)
	b.peau_murale(Vector3(3.8, 1.5, 0.6), -PI * 0.5, 0.9, 1.3, "peau_sombre")
	# --- séchoir à viande au-dessus du foyer et viandes pendues aux entraits
	b.bx(Vector3(xch - 0.9, b.y0 - 0.32, -1.75), Vector3(1.9, 0.06, 0.06), "bois_sombre")
	b.bx(Vector3(xch - 0.9, b.y0 - 0.32, -1.05), Vector3(1.9, 0.06, 0.06), "bois_sombre")
	for k in 6:
		b.viande_seche(Vector3(xch - 1.6 + k * 0.32, b.y0 - 0.35, -1.75 if k % 2 == 0 else -1.05), 1, 0.0)
	for x in Interieurs.FERMES["chasseurs"]:
		b.viande_seche(Vector3(x, b.y0 - 0.3, -1.9), 3, 0.0)
		b.viande_seche(Vector3(x + 0.4 + (1.2 if absf(x) < 0.2 else 0.0), b.y0 - 0.3, 2.0), 2, 0.5)
	# --- porte : raquettes, manteau, applique
	_raquette(b, Vector3(-1.5, 1.4, zf - 0.04), PI)
	_raquette(b, Vector3(-1.2, 1.35, zf - 0.04), PI)
	b.peau_murale(Vector3(1.75, 1.6, zf - 0.04), PI, 0.8, 1.1, "peau")
	b.applique(Vector3(-0.95, 1.85, zf - 0.02), PI, 1.4, 5.0, true)
	b.banc(Vector3(1.6, 0, zf - 0.25), 1.4, 0.0)

static func _cadre_peau(b: Interieurs, pos: Vector3, lacet: float) -> void:
	var F := Interieurs.F
	var bs := Basis(Vector3.UP, lacet)
	for sx in [-1.0, 1.0]:
		b.cyl(pos + bs * Vector3(sx * 0.55, 0, 0) + Vector3(0, F + 0.8, 0), 0.04, 1.6, "bois", 6)
	b.bx(pos + Vector3(0, F + 1.55, 0), Vector3(1.2, 0.05, 0.05), "bois", lacet)
	b.bx(pos + Vector3(0, F + 0.2, 0), Vector3(1.2, 0.05, 0.05), "bois", lacet)
	b.bx(pos + Vector3(0, F + 0.88, 0), Vector3(1.0, 1.25, 0.03), "peau_claire", lacet)
	b.solide(pos + Vector3(0, F + 0.8, 0), Vector3(1.2, 1.6, 0.2), lacet)

static func _raquette(b: Interieurs, pos: Vector3, lacet: float) -> void:
	b.bx(pos, Vector3(0.3, 0.7, 0.025), "bois", lacet)
	b.bx(pos + Vector3(0, 0, 0.01), Vector3(0.22, 0.6, 0.012), "cuir", lacet)
	b.bx(pos + Vector3(0, 0, 0.02), Vector3(0.28, 0.025, 0.012), "bois", lacet)

# ------------------------------------------------------------------------------------------------ Grima

static func _grima(b: Interieurs, xch: float) -> void:
	var F := Interieurs.F
	var zb := -b.W * 0.5 + 0.14
	var zf := b.W * 0.5 - 0.14
	var xw := -b.L * 0.5 + 0.14
	var xe := b.L * 0.5 - 0.14
	# --- sol : tapis tressé et siège de la doyenne au coin du feu
	b.peau_sol(Vector3(xch - 1.7, 0, -0.1), Vector2(1.4, 1.2), 0.1, "peau_claire")
	b.tabouret(Vector3(xch - 1.5, 0, 0.9), 0.4)
	b.bx(Vector3(xch - 1.5, F + 0.43, 0.9), Vector3(0.34, 0.03, 0.34), "peau_claire", 0.3)
	b.bx(Vector3(xch - 1.1, F + 0.65, 1.0), Vector3(0.05, 0.9, 0.05), "bois", 0.0, false, Vector3(0, 0, 0.15))   # quenouille
	b.bx(Vector3(xch - 1.07, F + 1.1, 1.0), Vector3(0.09, 0.2, 0.09), "foin", 0.0, false, Vector3(0, 0, 0.15))
	# --- métier à tisser (au fond ouest) : montants, traverse, fils tendus, pesons de pierre, tissu commencé
	var mx := xw + 1.35
	var mz := zb + 0.55
	for sx in [-1.0, 1.0]:
		b.cyl(Vector3(mx + sx * 0.7, F + 1.05, mz), 0.05, 2.1, "bois", 8, true)
	b.cyl_h(Vector3(mx, F + 2.0, mz), 0.045, 1.5, "bois", 0.0, 8)
	b.cyl_h(Vector3(mx, F + 1.55, mz + 0.05), 0.03, 1.4, "bois_clair", 0.0, 6)
	for k in 28:
		b.bx(Vector3(mx - 0.63 + k * 0.047, F + 0.95, mz), Vector3(0.012, 1.0 + (k % 3) * 0.03, 0.012), "foin", 0.0)
	for k in 7:
		b.bloc(Vector3(0.09, 0.12, 0.07), 7400 + k, Vector3(mx - 0.6 + k * 0.2, F + 0.35, mz), "brute", k)
	b.tenture(Vector3(mx, F + 1.82, mz + 0.045), 0.0, 1.26, 0.5, "tenture_r")
	b.bx(Vector3(mx + 0.9, F + 0.18, mz + 0.5), Vector3(0.7, 0.28, 0.45), "foin", 0.2)       # panier de laine
	b.solide(Vector3(mx, F + 1.0, mz), Vector3(1.55, 2.0, 0.35))
	# --- lit modeste (sud-ouest), couverture
	b.lit(Vector3(xw + 1.1, F, zf - 0.6), PI * 0.5, 1.9, 0.95, "peau")
	b.tenture(Vector3(xw + 0.06, 1.65, zf - 0.8), PI * 0.5, 1.2, 1.5, "tenture_v")
	# --- cuisine au fond (est) : étagères de pots, table de pétrissage, tonneaux
	b.etagere(Vector3(xch + 1.3, F, zb + 0.18), 0.0, 1.5, 2.0, 4, 0.3)
	for k in 6:
		b.cruche(Vector3(xch + 0.95 + (k % 3) * 0.4, F + 0.52 + 0.46 * int(k / 3), zb + 0.2), 0.26)
	for k in 3:
		b.bol(Vector3(xch + 0.95 + k * 0.4, F + 1.44, zb + 0.2))
	b.table(Vector3(xch - 0.3, 0, zb + 0.45), 1.8, 0.7, 0.0)
	var y := F + 0.78
	b.bx(Vector3(xch - 0.55, y + 0.04, zb + 0.4), Vector3(0.4, 0.07, 0.3), "foin", 0.2)       # pâte
	b.bol(Vector3(xch, y, zb + 0.5))
	b.bol(Vector3(xch + 0.25, y, zb + 0.35))
	b.cyl_h(Vector3(xch - 0.9, y + 0.025, zb + 0.55), 0.025, 0.4, "bois_clair", 0.2, 6)       # rouleau
	b.bougie(Vector3(xch + 0.4, y, zb + 0.55), 0.13, true)
	b.tonneau(Vector3(xe - 0.35, 0, zb + 0.5), 0.9, 0.32)
	b.tonneau(Vector3(xe - 0.3, 0, -0.4), 0.8, 0.3)
	b.coffre(Vector3(xe - 0.35, F, 0.6), -PI * 0.5, Vector3(0.95, 0.5, 0.56))
	b.sac(Vector3(xe - 0.45, F, 1.35), 3.3, 0.55)
	# --- tresses d'oignons, viandes et herbes aux entraits
	for x in Interieurs.FERMES["grima"]:
		for k in 3:
			var p := Vector3(x + (k - 1) * 0.6 + (1.2 if absf(x) < 0.2 else 0.0), b.y0 - 0.3, -1.65 if k != 1 else (1.65 if absf(x) > 1.0 else -1.2))
			b.cyl(p + Vector3(0, -0.22, 0), 0.012, 0.44, "cuir", 4)
			for j in 4:
				b.cyl(p + Vector3(0.0, -0.18 - j * 0.1, 0.0), 0.06 - j * 0.004, 0.09, "peau_claire" if k != 1 else "foin", 6, false, 0.05)
		b.viande_seche(Vector3(x + 0.1, b.y0 - 0.3, -1.9), 2, 0.2)
	# --- bout est, porte : tenture, peau, applique
	b.tenture(Vector3(xe - 0.01, 1.7, 1.6), -PI * 0.5, 1.2, 1.6, "tenture_b")
	b.applique(Vector3(-1.0, 1.85, zf - 0.02), PI, 1.4, 5.0, true)
	b.peau_murale(Vector3(1.8, 1.55, zf - 0.04), PI, 0.8, 1.0, "peau_sombre")
