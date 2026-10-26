class_name ObjPierreStatuaire
## Pierre funéraire et statuaire de la crypte (lot L4) : sarcophages, socles, statues, autels, bassin, table d'embaumement, trône.
## Corps des objets sortis de CrypteDecor (scripts/crypte_decor.gd) sans changer le rendu : chaque fonction reçoit le décor `dcr`
## (CrypteDecor ou GrotteDecor) et l'appelle comme avant (dcr.boite, dcr.solide, dcr.rng…) ; CrypteDecor garde une fonction d'une ligne
## du même nom (mêmes paramètres), que GrotteDecor peut toujours surcharger. Ne pas appeler ces fonctions directement : passer par le décor.

static func sarcophage(dcr: CrypteDecor, pos: Vector3, taille: Vector3, lacet := 0.0, collision := true) -> void:
	dcr.j0("sarcophage", lacet)
	pos = dcr._ecarter(pos, Vector2(taille.x * 0.55, taille.z * 0.73) if dcr.v2 else Vector2(taille.x * 0.5 + 0.1, taille.z * 0.5 + 0.1), lacet)      # v2 : module sculpté plus large que la boîte
	dcr.emprise("sarcophage", pos, Vector2(taille.x * 0.5 + 0.1, taille.z * 0.5 + 0.1), lacet, taille.y + 0.3)
	if dcr.v2:      # crypte v2 : sarcophage sculpté (module Blender, 2,18 x 1,1 x 0,92 m) mis à la taille demandée ; MÊME collision
		dcr.modele("sarcophage", pos, lacet, Vector3(taille.x / 2.18, (taille.y + 0.24) / 1.1, taille.z / 0.92))
		if collision:
			var bv := Basis(Vector3.UP, lacet)
			var sv := bv * Vector3(taille.x, 0, taille.z)
			dcr.solide(pos + Vector3(0, taille.y * 0.5, 0), Vector3(absf(sv.x), taille.y, absf(sv.z)))
		dcr.j1()
		return
	dcr.boite("mur0", pos + Vector3(0, taille.y * 0.5, 0), taille, lacet)
	dcr.boite("gravure", pos + Vector3(0, taille.y + 0.07, 0), Vector3(taille.x + 0.1, 0.14, taille.z + 0.1), lacet)
	dcr.boite("gravure", pos + Vector3(0, taille.y + 0.19, 0), Vector3(taille.x - 0.22, 0.1, taille.z - 0.3), lacet)
	dcr.boite("mur1", pos + Vector3(0, 0.07, 0), Vector3(taille.x + 0.14, 0.14, taille.z + 0.14), lacet)
	if collision:
		var b := Basis(Vector3.UP, lacet)
		var s := b * Vector3(taille.x, 0, taille.z)
		dcr.solide(pos + Vector3(0, taille.y * 0.5, 0), Vector3(absf(s.x), taille.y, absf(s.z)))
	dcr.j1()

## Socle de pierre (collision). `taille` = largeur x hauteur x profondeur.
static func socle(dcr: CrypteDecor, pos: Vector3, taille := Vector3(0.9, 0.9, 0.9), lacet := 0.0, mat := "mur1") -> void:
	dcr.j0("socle", lacet)
	dcr.emprise("socle", pos, Vector2(taille.x * 0.5 + 0.06, taille.z * 0.5 + 0.06), lacet, taille.y + 0.1)
	var b := Basis(Vector3.UP, lacet)
	if dcr.v2 and mat in ["mur0", "mur1", "mur2"]:      # C4b : socle en blocs taillés (module « socle_v2 » mis à la taille), MÊME collision
		dcr.modele("socle_v2", pos, lacet, Vector3(taille.x + 0.02, taille.y + 0.08, taille.z + 0.02))
		var s2 := b * Vector3(taille.x + 0.12, 0, taille.z + 0.12)
		dcr.solide(pos + Vector3(0, taille.y * 0.5, 0), Vector3(absf(s2.x), taille.y + 0.08, absf(s2.z)))
		dcr.j1()
		return
	dcr.boite(mat, pos + Vector3(0, taille.y * 0.5, 0), taille, lacet)
	dcr.boite("mur0", pos + Vector3(0, taille.y + 0.04, 0), Vector3(taille.x + 0.12, 0.08, taille.z + 0.12), lacet)
	dcr.boite("mur0", pos + Vector3(0, 0.07, 0), Vector3(taille.x + 0.1, 0.14, taille.z + 0.1), lacet)
	var s := b * Vector3(taille.x + 0.12, 0, taille.z + 0.12)
	dcr.solide(pos + Vector3(0, taille.y * 0.5, 0), Vector3(absf(s.x), taille.y + 0.08, absf(s.z)))
	dcr.j1()

## Statue de pierre sur socle (visage vers +Z local, tourné de `lacet`). type : guerrier (casque, lance, bouclier), jarl (couronne, épée plantée),
## ancetre (capuche, mains jointes), gardienne (voile).
static func statue(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, e := 1.0, type := "guerrier", collision := true, mat := "mur1") -> void:
	dcr.j0("statue", lacet)
	pos = dcr._ecarter(pos, Vector2(0.53, 0.53), lacet)
	dcr.emprise("statue", pos, Vector2(0.53, 0.53), lacet, 2.6)
	if dcr.v2 and mat in ["mur0", "mur1", "mur2"]:
		mat = "statue_v2"       # crypte v2 : statues un peu plus claires que les murs (sans lumière de plus)
		if type in ["ancetre", "capuche", "gardienne"]:
			# C4b : gardiens encapuchonnés / voilés = module sculpté « statue_capuche » (plis, capuche, givre), même hauteur ; MÊME collision
			dcr.modele("statue_capuche", pos, lacet, Vector3.ONE * clampf(e * 0.83, 0.75, 1.2), {"pierre": "statue_v2"})
			if collision:
				dcr.solide(pos + Vector3(0, 1.2, 0), Vector3(1.0, 2.4, 1.0))
			dcr.j1()
			return
	var b := Basis(Vector3.UP, lacet)
	var h0 := 0.5                                          # socle
	dcr.boite(mat, pos + Vector3(0, h0 * 0.5, 0), Vector3(0.95, h0, 0.95), lacet)
	dcr.boite("mur0", pos + Vector3(0, h0 + 0.04, 0), Vector3(1.05, 0.08, 1.05), lacet)
	dcr.boite("mur0", pos + Vector3(0, 0.07, 0), Vector3(1.05, 0.14, 1.05), lacet)
	var base := pos + Vector3(0, h0 + 0.08, 0)
	# robe : fût qui s'évase (profil de révolution), épaules, tête
	dcr.tour(mat, base, [Vector2(0.34 * e, 0.0), Vector2(0.3 * e, 0.5 * e), Vector2(0.24 * e, 1.0 * e), Vector2(0.3 * e, 1.18 * e), Vector2(0.14 * e, 1.28 * e)], 8, 0.0, true)
	dcr.boite(mat, base + b * Vector3(0, 1.16 * e, 0), Vector3(0.74 * e, 0.16 * e, 0.3 * e), lacet)
	dcr.tour(mat, base + Vector3(0, 1.26 * e, 0), [Vector2(0.09 * e, 0.0), Vector2(0.12 * e, 0.1 * e), Vector2(0.115 * e, 0.24 * e), Vector2(0.06 * e, 0.3 * e)], 8, 0.0, true)
	dcr.boite(mat, base + b * Vector3(0, 1.38 * e, 0.12 * e), Vector3(0.04 * e, 0.09 * e, 0.06 * e), lacet)                 # nez : donne le sens du regard
	for sx in [-1.0, 1.0]:
		dcr.boite(mat, base + b * Vector3(sx * 0.36 * e, 0.92 * e, 0.0), Vector3(0.12 * e, 0.5 * e, 0.14 * e), lacet)       # bras
	match type:
		"guerrier":
			dcr.tour("mur0", base + Vector3(0, 1.4 * e, 0), [Vector2(0.135 * e, 0.0), Vector2(0.13 * e, 0.1 * e), Vector2(0.0, 0.2 * e)], 8, 0.0, false)
			dcr.boite("bois", base + b * Vector3(0.4 * e, 1.0 * e, 0.1 * e), Vector3(0.05, 1.9 * e, 0.05), lacet)
			dcr.boite("lame", base + b * Vector3(0.4 * e, 2.02 * e, 0.1 * e), Vector3(0.06, 0.22 * e, 0.015), lacet)
			dcr.boite("mur0", base + b * Vector3(-0.36 * e, 0.95 * e, 0.16 * e), Vector3(0.42 * e, 0.5 * e, 0.07), lacet)
			dcr.boite("fer", base + b * Vector3(-0.36 * e, 0.95 * e, 0.205 * e), Vector3(0.12 * e, 0.12 * e, 0.04), lacet)
		"jarl":
			dcr.tour("or", base + Vector3(0, 1.4 * e, 0), [Vector2(0.125 * e, 0.0), Vector2(0.135 * e, 0.08 * e)], 6, 0.0, false)
			for k in 5:
				var a := TAU * k / 5.0
				dcr.boite("or", base + Vector3(cos(a) * 0.12 * e, 1.52 * e, sin(a) * 0.12 * e), Vector3(0.03, 0.1 * e, 0.03))
			dcr.boite("lame", base + b * Vector3(0, 0.5 * e, 0.3 * e), Vector3(0.06, 1.0 * e, 0.02), lacet)
			dcr.boite("fer", base + b * Vector3(0, 0.98 * e, 0.3 * e), Vector3(0.34 * e, 0.05, 0.06), lacet)
		"capuche":      # refonte matière : gardien encapuchonné (références), visage dans l'ombre, épée pointe en bas, givre aux épaules
			dcr.tour(mat, base + Vector3(0, 1.1 * e, 0), [Vector2(0.27 * e, 0.0), Vector2(0.21 * e, 0.18 * e), Vector2(0.18 * e, 0.34 * e), Vector2(0.11 * e, 0.47 * e), Vector2(0.0, 0.54 * e)], 8, 0.0, false)
			dcr.boite("noir", base + b * Vector3(0, 1.36 * e, 0.19 * e), Vector3(0.15 * e, 0.2 * e, 0.04), lacet)
			dcr.boite("lame", base + b * Vector3(0, 0.52 * e, 0.3 * e), Vector3(0.06, 0.9 * e, 0.02), lacet)
			dcr.boite("fer", base + b * Vector3(0, 0.99 * e, 0.3 * e), Vector3(0.3 * e, 0.05, 0.06), lacet)
			dcr.boite(mat, base + b * Vector3(0, 1.05 * e, 0.28 * e), Vector3(0.22 * e, 0.11 * e, 0.11 * e), lacet)
			if dcr.est_crypte:
				dcr.givre_dessus(base + Vector3(0, 1.24 * e, 0), Vector2(0.7 * e, 0.28 * e), 0.02, lacet)
		"ancetre":
			dcr.boite(mat, base + b * Vector3(0, 1.36 * e, -0.02 * e), Vector3(0.3 * e, 0.3 * e, 0.3 * e), lacet)
			dcr.boite(mat, base + b * Vector3(0, 0.82 * e, 0.2 * e), Vector3(0.22 * e, 0.1 * e, 0.12 * e), lacet)
		_:
			dcr.boite(mat, base + b * Vector3(0, 1.2 * e, -0.02 * e), Vector3(0.34 * e, 0.5 * e, 0.28 * e), lacet)
	if collision:
		dcr.solide(pos + Vector3(0, 1.2, 0), Vector3(1.0, 2.4, 1.0))
	dcr.j1()

## Autel de chapelle : massif de pierre, nappe, dessus gravé, deux bougies sans lumière.
static func autel(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, largeur := 2.0) -> void:
	dcr.j0("autel", lacet)
	pos = dcr._ecarter(pos, Vector2(largeur * 0.5 + 0.08, 0.53), lacet)
	dcr.emprise("autel", pos, Vector2(largeur * 0.5 + 0.08, 0.53), lacet, 1.14)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("mur1", pos + Vector3(0, 0.45, 0), Vector3(largeur, 0.9, 0.9), lacet)
	dcr.boite("mur0", pos + Vector3(0, 0.94, 0), Vector3(largeur + 0.16, 0.1, 1.06), lacet)
	dcr.boite("lin", pos + Vector3(0, 0.995, 0), Vector3(largeur * 0.6, 0.012, 0.9), lacet, false, Vector3.ZERO)      # nappe de lin
	dcr.boite("gravure", pos + b * Vector3(0, 0.45, 0.455), Vector3(largeur * 0.7, 0.5, 0.012), lacet)
	for sx in [-0.7, 0.7]:
		dcr.bougie(pos + b * Vector3(sx * largeur * 0.5, 1.0, 0.0), false)
	var s := b * Vector3(largeur + 0.16, 0, 1.06)
	dcr.solide(pos + Vector3(0, 0.5, 0), Vector3(absf(s.x), 1.0, absf(s.z)))
	dcr.j1()

## Bassin : margelle de pierre (collision, h de haut) et surface noire en retrait.
static func bassin(dcr: CrypteDecor, centre: Vector3, w: float, p: float, h := 0.5) -> void:
	dcr.j0("bassin")
	dcr.emprise("bassin", centre, Vector2(w * 0.5, p * 0.5), 0.0, h)
	var e := 0.4
	dcr.eau_slot(centre + Vector3(0, h - 0.12, 0), minf(w, p) * 0.5 - e, "bassin", Vector2(w - 2.0 * e, p - 2.0 * e))
	dcr.boite_pleine("mur1", centre + Vector3(0, h * 0.5, -(p * 0.5 - e * 0.5)), Vector3(w, h, e))
	dcr.boite_pleine("mur1", centre + Vector3(0, h * 0.5, (p * 0.5 - e * 0.5)), Vector3(w, h, e))
	dcr.boite_pleine("mur1", centre + Vector3(-(w * 0.5 - e * 0.5), h * 0.5, 0), Vector3(e, h, p - 2.0 * e))
	dcr.boite_pleine("mur1", centre + Vector3(w * 0.5 - e * 0.5, h * 0.5, 0), Vector3(e, h, p - 2.0 * e))
	for sg in [-1.0, 1.0]:
		dcr.boite("mur0", centre + Vector3(0, h + 0.03, sg * (p * 0.5 - 0.03)), Vector3(w + 0.1, 0.06, 0.1))
		dcr.boite("mur0", centre + Vector3(sg * (w * 0.5 - 0.03), h + 0.03, 0), Vector3(0.1, 0.06, p + 0.1))
	dcr.quad("noir", centre + Vector3(-w * 0.5 + e, h - 0.12, -p * 0.5 + e), centre + Vector3(w * 0.5 - e, h - 0.12, -p * 0.5 + e), centre + Vector3(w * 0.5 - e, h - 0.12, p * 0.5 - e), centre + Vector3(-w * 0.5 + e, h - 0.12, p * 0.5 - e), Vector3.UP)
	dcr.solide(centre + Vector3(0, h * 0.5, 0), Vector3(w - 0.2, h, p - 0.2))
	dcr.j1()

## Table d'embaumement : dalle de pierre sur deux piliers, rigole, bandelettes, bol d'huiles ; `corps` : dépouille enveloppée dessus.
static func table_embaumement(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, corps := false) -> void:
	dcr.j0("table_embaumement", lacet)
	pos = dcr._ecarter(pos, Vector2(1.2, 0.44), lacet)
	dcr.emprise("table_embaumement", pos, Vector2(1.2, 0.44), lacet, 1.17)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("mur1", pos + Vector3(0, 0.88, 0), Vector3(2.1, 0.14, 0.86), lacet)
	for sx in [-0.7, 0.7]:
		dcr.boite("mur0", pos + b * Vector3(sx, 0.4, 0), Vector3(0.34, 0.8, 0.7), lacet)
	dcr.boite("mur0", pos + Vector3(0, 0.28, 0), Vector3(1.2, 0.12, 0.5), lacet)
	dcr.boite("gravure", pos + Vector3(0, 0.962, 0), Vector3(1.7, 0.012, 0.36), lacet)
	for k in 3:
		dcr.boite("lin", pos + b * Vector3(-0.5 + k * 0.5, 0.55, 0.45), Vector3(0.1, 0.5, 0.012), lacet)      # bandelettes
	dcr.tour("fer", pos + b * Vector3(1.2, 0, 0.1), [Vector2(0.14, 0.0), Vector2(0.16, 0.1), Vector2(0.1, 0.2)], 8, 0.0, false)
	if corps:
		dcr.boite("lin", pos + Vector3(0, 1.06, 0), Vector3(1.55, 0.17, 0.46), lacet, false)      # linceul
		dcr.boite("os", pos + b * Vector3(-0.85, 1.08, 0), Vector3(0.2, 0.18, 0.2), lacet)
	var s := b * Vector3(2.1, 0, 0.86)
	dcr.solide(pos + Vector3(0, 0.5, 0), Vector3(absf(s.x), 1.0, absf(s.z)))
	dcr.j1()

## Sarcophage au couvercle poussé de côté (pillage) : la cuve noire apparaît.
static func sarcophage_pille(dcr: CrypteDecor, pos: Vector3, taille: Vector3, lacet := 0.0) -> void:
	dcr.j0("sarcophage_pille", lacet)
	pos = dcr._ecarter(pos, Vector2(taille.x * 0.5 + 0.3, taille.z * 0.5 + 0.5), lacet)      # couvercle poussé de travers
	dcr.emprise("sarcophage_pille", pos, Vector2(taille.x * 0.5 + 0.3, taille.z * 0.5 + 0.15), lacet, taille.y + 0.2)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("mur0", pos + Vector3(0, taille.y * 0.5, 0), taille, lacet)
	dcr.boite("mur1", pos + Vector3(0, 0.07, 0), Vector3(taille.x + 0.14, 0.14, taille.z + 0.14), lacet)
	dcr.boite("noir", pos + Vector3(0, taille.y + 0.005, 0), Vector3(taille.x - 0.3, 0.01, taille.z - 0.3), lacet)
	dcr.boite("gravure", pos + b * Vector3(taille.x * 0.28, taille.y + 0.14, 0.26), Vector3(taille.x * 0.8, 0.16, taille.z + 0.04), lacet + 0.25)
	dcr.boite("fer", pos + b * Vector3(-taille.x * 0.5 - 0.15, 0.04, 0.5), Vector3(0.7, 0.03, 0.04), lacet + 0.5)       # pied-de-biche
	var s := b * Vector3(taille.x + 0.6, 0, taille.z + 0.3)
	dcr.solide(pos + Vector3(0, taille.y * 0.5, 0), Vector3(absf(s.x), taille.y, absf(s.z)))
	dcr.j1()

## Trône (estrade à deux degrés, siège, haut dossier, accoudoirs) ; collision. `mat` : « mur4 » pour la glace.
static func trone(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, mat := "mur1") -> void:
	dcr.j0("trone", lacet)
	dcr.emprise("trone", pos, Vector2(1.8, 1.5), lacet, 3.1)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite_pleine_l(mat, pos + Vector3(0, 0.15, 0), Vector3(3.6, 0.3, 3.0), lacet)
	dcr.boite_pleine_l(mat, pos + Vector3(0, 0.4, -0.2), Vector3(2.6, 0.2, 2.2), lacet)
	dcr.boite_pleine_l(mat, pos + b * Vector3(0, 0.85, -0.2), Vector3(1.3, 0.7, 1.2), lacet)
	dcr.boite(mat, pos + b * Vector3(0, 1.7, -0.7), Vector3(1.4, 2.0, 0.28), lacet)
	for sx in [-0.75, 0.75]:
		dcr.boite(mat, pos + b * Vector3(sx, 1.35, -0.2), Vector3(0.2, 0.5, 1.1), lacet)
	for k in 3:
		dcr.boite(mat, pos + b * Vector3((k - 1) * 0.45, 2.85, -0.7), Vector3(0.16, 0.5, 0.2), lacet)
	dcr.j1()
