class_name InterieurForge
## Forge de Brodd le Large, forgeron de Skarnholt (appentis fermé de ~4,2 × 3,4 m ; fond = foyer au Nord local -Z, façade
## et double porte au Sud +Z ; sol de terre battue et de dalles, au niveau du village).
##
## Macro : toit à une pente lambrissé, murs de pierre sèche, hotte de pierre sur un foyer surélevé.
## Méso  : enclume sur son billot, soufflet de cuir, bac de trempe, réserve de charbon, établi, meule, tonneau d'eau.
## Micro : tenailles, marteaux, limes, fers à cheval, lames en cours, lingots, braise sur l'enclume, cendres.

const Y := 0.04       # dessus du sol
## L9 : râtelier de l'Épée de Skarnholt (mur est, face à l'ouest) ; l'épée elle-même est un ObjetUnique posé par le monde
## (Monde._uniques_village) quand Brodd l'a forgée (étape « epee » de la quête lames_brodd).
const RATELIER_UNIQUE := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(2.06, 1.45, -0.3))
const EPEE_COUCHEE := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))

static func construire(b: Interieurs) -> void:
	# --- sol : terre battue, dalles autour du foyer et de l'enclume
	b.bx(Vector3(0, Y * 0.5, 0), Vector3(4.3, Y, 3.4), "terre")
	b.dallage(Rect2(-1.95, -1.65, 2.45, 2.15), "pierre_sombre", 0.07, 0.0)
	b.dallage(Rect2(-0.95, -0.5, 1.2, 1.1), "pierre_sombre", 0.065, 0.0)
	_plafond(b)
	_foyer(b)
	_enclume(b, Vector3(-0.35, 0, 0.05))
	_soufflet(b, Vector3(0.62, 0, -1.4))
	_bac_trempe(b, Vector3(-1.8, 0, 0.55))
	_charbon(b, Vector3(1.55, 0, -1.2))
	_etabli(b, Vector3(-1.1, 0, 1.4))
	_meule(b, Vector3(-1.86, 0, -0.42))
	b.tonneau(Vector3(1.85, 0, 0.6), 0.9, 0.33)
	# --- mur ouest : râtelier d'outils ; mur du fond (est) : lames et fers
	_outils(b, Vector3(-2.08, 1.45, -0.6), PI * 0.5)
	_lames(b, Vector3(1.55, 1.5, -1.62), 0.0)
	for k in 3:
		b.bx(Vector3(1.0 + k * 0.5, 1.9, -1.6), Vector3(0.3, 0.12, 0.12), "fer", 0.2 * k)
	# --- suspendus : fers à cheval, chaînes, barres de fer
	for k in 5:
		_fer_cheval(b, Vector3(-0.7 + k * 0.28, 2.0 - (k % 2) * 0.08, 0.7))
	for k in 3:
		b.cyl(Vector3(0.2 + k * 0.07, 2.0, 1.3), 0.012, 0.5, "fer_noir", 4)
	# --- applique et lumières
	b.applique(Vector3(-2.07, 1.65, 1.0), PI * 0.5, 1.2, 5.0, true)
	b.sac(Vector3(-1.85, 0.04, -0.55), 5.5, 0.4)
	# --- petits tas de cendre et bouts de fer par terre
	for k in 6:
		var x := b.rng.randf_range(-1.6, 1.8)
		var z := b.rng.randf_range(-0.5, 1.2)
		b.bx(Vector3(x, 0.05, z), Vector3(0.18 + b.rng.randf() * 0.12, 0.02, 0.1), "cendre" if k % 2 == 0 else "fer_noir", b.rng.randf() * 3.0)
	_ratelier_unique(b)       # L9 : après les tirages (aucun tirage ici : le reste de la forge ne bouge pas)

## Repère (dans l'intérieur) de l'Épée de Skarnholt posée sur son râtelier.
static func xf_epee_unique() -> Transform3D:
	return RATELIER_UNIQUE * Transform3D(EPEE_COUCHEE, Vector3(-0.42, 0.03, 0.075))

## L9 : râtelier à une arme (même dessin que le module « presentoir_ratelier » de la crypte) : planche de chêne sombre et cadre, deux
## crochets de fer en fourche à ±0,26 m, clous ; repère RATELIER_UNIQUE (dos au mur, face +z).
static func _ratelier_unique(b: Interieurs) -> void:
	var t := RATELIER_UNIQUE
	var l := -PI * 0.5
	# finition (2026-10-29, INSPIRATION_IGNITE §3 : arête claire +1 ton, pied sombre) : le râtelier se perdait dans la pierre brune
	b.bx(t * Vector3(0, 0, 0.016), Vector3(0.95, 0.3, 0.03), "bois_clair", l)
	b.bx(t * Vector3(0, -0.115, 0.027), Vector3(0.95, 0.05, 0.02), "bois_suie", l)       # pied sombre (ombre portée de la lame)
	for yy in [-0.165, 0.165]:
		b.bx(t * Vector3(0, yy, 0.024), Vector3(1.02, 0.045, 0.045), "rondin", l)     # traverses : arête claire
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.26
		b.bx(t * Vector3(x, -0.02, 0.055), Vector3(0.022, 0.022, 0.08), "fer_noir", l)
		b.bx(t * Vector3(x, 0.0, 0.098), Vector3(0.022, 0.06, 0.016), "fer_noir", l)
		b.bx(t * Vector3(x, -0.02, 0.034), Vector3(0.05, 0.07, 0.006), "fer", l)
		for yy in [-0.165, 0.165]:
			b.bx(t * Vector3(sx * 0.44, yy, 0.049), Vector3(0.014, 0.014, 0.006), "fer", l)

## Plafond sous la pente du toit : lambris de planches sombres sous les chevrons, nervures et un linteau de poutre.
static func _plafond(b: Interieurs) -> void:
	var rp := Vector3(0, 2.72, -2.3)
	var d := Vector3(0, -0.63, 4.55)
	var t := d.normalized()
	var nrm := Vector3(0, t.z, -t.y)
	var off := 0.25
	var pt := func(x: float, z: float, decal: float) -> Vector3:
		var s := (z - rp.z + nrm.z * decal) / t.z
		return Vector3(x, rp.y + t.y * s - nrm.y * decal, z)
	var xa := -2.15
	var xb := 2.15
	var z0 := -1.7
	var z1 := 1.74
	b.quad("bois_sombre", pt.call(xa, z0, off), pt.call(xb, z0, off), pt.call(xb, z1, off), pt.call(xa, z1, off), -nrm)
	var base := Basis(Vector3.RIGHT, nrm, t)
	var x := -1.8
	while x < 1.9:
		var c: Vector3 = ((pt.call(x, z0, off + 0.05) as Vector3) + (pt.call(x, z1, off + 0.05) as Vector3)) * 0.5
		b.v._boite(b.ip.racine, Vector3(0.1, 0.09, (z1 - z0) / t.z), Transform3D(base, c), b.M["bois_sombre"])
		x += 0.9
	# poutre transversale au-dessus de la façade
	b.rondin(Vector3(0, (pt.call(0.0, 1.45, off + 0.08) as Vector3).y, 1.45), 0.0, 4.3, 0.1, 401, "rondin_sombre")
	b.rondin(Vector3(0, (pt.call(0.0, -0.2, off + 0.08) as Vector3).y, -0.2), 0.0, 4.3, 0.1, 402, "rondin_sombre")

static func _foyer(b: Interieurs) -> void:
	var xh := -0.8
	var zh := -1.2
	b.pile(Vector3(xh, 0.45, zh), Vector3(1.8, 0.9, 1.2), 4320, "pierre", true)
	b.bx(Vector3(xh, 0.94, zh), Vector3(1.9, 0.1, 1.3), "brute")          # table du foyer
	b.bx(Vector3(xh, 0.99, zh), Vector3(1.4, 0.06, 0.8), "cendre")
	for k in 7:
		b.bx(Vector3(xh - 0.6 + k * 0.2, 1.03, zh + b.rng.randf_range(-0.2, 0.2)), Vector3(0.28, 0.02, 0.26), "braises", b.rng.randf() * 3.0)
	for k in 4:
		b.rondin(Vector3(xh - 0.45 + k * 0.3, 1.06, zh + b.rng.randf_range(-0.1, 0.1)), PI * 0.5 + b.rng.randf_range(-0.2, 0.2), 0.6, 0.05, 410 + k, "rondin_sombre")
	# piliers de la hotte, hotte étagée et gaine
	for sx in [-1.0, 1.0]:
		b.pile(Vector3(xh + sx * 0.82, 1.25, zh + 0.45), Vector3(0.24, 0.7, 0.24), 4330 + int(sx + 1.0), "pierre", true)
	b.pile(Vector3(xh, 1.75, zh - 0.06), Vector3(1.9, 0.36, 1.05), 4321, "pierre")
	b.pile(Vector3(xh, 2.1, zh - 0.15), Vector3(1.3, 0.36, 0.85), 4323, "pierre")
	b.pile(Vector3(xh, 2.45, zh - 0.3), Vector3(0.7, 0.4, 0.7), 4325, "pierre")
	b.bx(Vector3(xh, 1.5, zh + 0.45), Vector3(1.7, 0.1, 0.12), "bois_sombre")                        # sablière de la hotte
	b.flamme(Vector3(xh - 0.45, 1.08, zh), 2.1)
	b.flamme(Vector3(xh + 0.05, 1.08, zh + 0.05), 2.4)
	b.flamme(Vector3(xh + 0.5, 1.08, zh - 0.05), 1.9)
	b.halo(Vector3(xh, 0.075, zh + 1.0), Vector3.UP, 4.2, 3.2, Color(1, 0.88, 0.75, 1))
	b.lumiere(Vector3(xh, 1.5, zh + 0.9), 3.2, 8.0)
	# outils du foyer : tisonnier et pelle contre la hotte, panier de bûches
	b.bx(Vector3(xh - 1.0, 0.55, zh + 0.65), Vector3(0.03, 1.1, 0.03), "fer_noir", 0.0, false, Vector3(0, 0, 0.12))
	b.bx(Vector3(xh - 0.9, 0.5, zh + 0.68), Vector3(0.18, 0.22, 0.03), "fer_noir", 0.0, false, Vector3(0, 0, 0.12))
	b.solide(Vector3(xh, 1.0, zh + 0.1), Vector3(1.9, 2.0, 1.2))

## Billot cerclé et enclume à bigorne (module L6 « enclume ») ; collisions inchangées.
static func _enclume(b: Interieurs, pos: Vector3) -> void:
	b.solide_cyl(pos + Vector3(0, 0.3, 0), 0.28, 0.6)
	b.modele("enclume", pos)
	b.bx(pos + Vector3(0.4, 0.06, 0.15), Vector3(0.05, 0.04, 0.5), "bois", 0.3)        # marteau au pied du billot
	b.bx(pos + Vector3(0.4, 0.07, 0.38), Vector3(0.09, 0.09, 0.14), "fer", 0.3)
	b.solide(pos + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.8))

## Soufflet sur tréteau : planches en poire, cuir plissé, buse vers le foyer (-x) (module L6 « soufflet »).
static func _soufflet(b: Interieurs, pos: Vector3) -> void:
	b.solide(pos + Vector3(0.0, 0.3, 0), Vector3(0.7, 0.6, 0.12))
	b.modele("soufflet", pos)

## Bac de trempe de planches cerclé, eau noire, tenailles (module L6 « bac_trempe ») ; seau à côté.
static func _bac_trempe(b: Interieurs, pos: Vector3) -> void:
	b.solide(pos + Vector3(0, 0.22, 0), Vector3(0.55, 0.44, 1.1))
	b.modele("bac_trempe", pos)
	b.cyl(pos + Vector3(0.0, 0.47, -0.5), 0.07, 0.1, "bois", 8, false, 0.06)      # seau

static func _charbon(b: Interieurs, pos: Vector3) -> void:
	for sz in [-1.0, 1.0]:
		b.bx(pos + Vector3(0, 0.3, sz * 0.45), Vector3(0.9, 0.6, 0.06), "bois_v")
	b.bx(pos + Vector3(0.45, 0.3, 0), Vector3(0.06, 0.6, 0.9), "bois_v")
	b.bx(pos + Vector3(-0.05, 0.25, 0), Vector3(0.8, 0.5, 0.82), "charbon", 0.0, true)
	b.bx(pos + Vector3(-0.05, 0.42, 0), Vector3(0.6, 0.12, 0.6), "charbon", 0.4)
	for k in 5:
		b.bloc(Vector3(0.12, 0.1, 0.1), 4500 + k, pos + Vector3(-0.3 + k * 0.14, 0.52, b.rng.randf_range(-0.25, 0.25)), "charbon", k)
	b.bx(pos + Vector3(-0.7, 0.04, 0.4), Vector3(0.35, 0.05, 0.25), "charbon", 0.4)
	b.bx(pos + Vector3(-0.55, 0.15, 0.5), Vector3(0.05, 0.3, 0.05), "bois", 0.0, false, Vector3(0.0, 0, 0.3))     # pelle

static func _etabli(b: Interieurs, pos: Vector3) -> void:
	b.table(pos, 1.6, 0.62, 0.0, 0.86)
	var y := 0.04 + 0.86
	b.bx(pos + Vector3(0.55, y + 0.1, 0.08), Vector3(0.12, 0.2, 0.18), "fer_noir")                     # étau
	b.bx(pos + Vector3(0.55, y + 0.12, 0.2), Vector3(0.025, 0.025, 0.2), "fer", 0.0)
	for k in 3:
		b.bx(pos + Vector3(-0.5 + k * 0.1, y + 0.02, -0.1 + 0.05 * k), Vector3(0.025, 0.02, 0.3), "etain", 0.3 * k)      # limes
	b.bx(pos + Vector3(-0.1, y + 0.02, 0.0), Vector3(0.6, 0.015, 0.06), "etain", 0.2)                # lame brute
	b.bx(pos + Vector3(-0.1, y + 0.025, 0.0), Vector3(0.12, 0.015, 0.025), "fer_noir", 0.2)          # garde
	for k in 6:
		b.bx(pos + Vector3(0.1 + (k % 3) * 0.08, y + 0.02, 0.15 + int(k / 3) * 0.06), Vector3(0.05, 0.015, 0.02), "fer", k)    # clous
	b.cyl(pos + Vector3(0.3, y + 0.07, -0.1), 0.06, 0.14, "terre", 8, false, 0.05)                     # pot de clous
	b.bougie(pos + Vector3(-0.7, y, 0.05), 0.12)
	b.tabouret(pos + Vector3(-0.1, 0, 0.75))

## Meule de grès sur bâti, manivelle, auge (module L6 « meule ») ; collisions inchangées.
static func _meule(b: Interieurs, pos: Vector3) -> void:
	var f := CylinderShape3D.new()
	f.radius = 0.31
	f.height = 0.12
	b.v._collision(b.ip.racine, f, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, PI * 0.5), pos + Vector3(0, 0.62, 0)), Vector3.ZERO)
	b.modele("meule", pos)
	b.solide(pos + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.7))

static func _outils(b: Interieurs, pos: Vector3, lacet: float) -> void:
	var d := Basis(Vector3.UP, lacet) * Vector3.BACK
	var dr := Basis(Vector3.UP, lacet) * Vector3.RIGHT
	b.bx(pos + d * 0.04, Vector3(1.4, 0.1, 0.06), "bois_sombre", lacet)
	b.bx(pos + d * 0.04 - Vector3(0, 0.6, 0), Vector3(1.4, 0.1, 0.06), "bois_sombre", lacet)
	for k in 6:
		var x := -0.55 + k * 0.22
		match k % 3:
			0:   # tenailles
				b.bx(pos + dr * x + d * 0.1 - Vector3(0, 0.25, 0), Vector3(0.03, 0.55, 0.02), "fer_noir", lacet, false, Vector3(0, 0, 0.08))
				b.bx(pos + dr * (x + 0.04) + d * 0.1 - Vector3(0, 0.25, 0), Vector3(0.03, 0.55, 0.02), "fer_noir", lacet, false, Vector3(0, 0, -0.08))
			1:   # marteau
				b.bx(pos + dr * x + d * 0.1 - Vector3(0, 0.2, 0), Vector3(0.04, 0.5, 0.04), "bois", lacet)
				b.bx(pos + dr * x + d * 0.1 + Vector3(0, 0.07, 0), Vector3(0.16, 0.08, 0.08), "fer", lacet)
			_:   # ciseau et poinçon
				b.bx(pos + dr * x + d * 0.1 - Vector3(0, 0.2, 0), Vector3(0.025, 0.42, 0.025), "etain", lacet)

static func _lames(b: Interieurs, pos: Vector3, lacet: float) -> void:
	var d := Basis(Vector3.UP, lacet) * Vector3.BACK
	var dr := Basis(Vector3.UP, lacet) * Vector3.RIGHT
	b.bx(pos + d * 0.04, Vector3(1.0, 0.06, 0.06), "bois_sombre", lacet)
	b.bx(pos + d * 0.04 - Vector3(0, 0.7, 0), Vector3(1.0, 0.06, 0.06), "bois_sombre", lacet)
	for k in 3:
		b.epee(pos + dr * (-0.3 + k * 0.3) + d * 0.1 - Vector3(0, 0.3, 0), lacet, 0.0, 1.0)
	b.hache(pos + dr * 0.45 + d * 0.1 - Vector3(0, 0.3, 0), lacet, 0.0, 0.9)
	b.bouclier(pos + Vector3(-0.1, -1.0, 0.0), lacet, 0.28, "bouclier_n")

static func _fer_cheval(b: Interieurs, pos: Vector3) -> void:
	b.cyl(pos + Vector3(0, 0.1, 0), 0.006, 0.2, "fer_noir", 4)
	b.bx(pos + Vector3(0, -0.02, 0), Vector3(0.1, 0.02, 0.02), "fer_noir")
	for sx in [-1.0, 1.0]:
		b.bx(pos + Vector3(sx * 0.045, -0.06, 0), Vector3(0.02, 0.1, 0.02), "fer_noir")
