class_name ObjPetitMobilier
## Petit mobilier commun crypte + grotte (lot L2) : coffres, bougies, urnes, tonneaux, tables, crânes, os, armes, gravats, sacs, parchemins.
## Corps des objets sortis de CrypteDecor (scripts/crypte_decor.gd) sans changer le rendu : chaque fonction reçoit le décor `dcr`
## (CrypteDecor ou GrotteDecor) et l'appelle comme avant (dcr.boite, dcr.solide, dcr.rng…) ; CrypteDecor garde une fonction d'une ligne
## du même nom (mêmes paramètres), que GrotteDecor peut toujours surcharger. Ne pas appeler ces fonctions directement : passer par le décor.

## Lot L2 (2026-10-26) : coffres, tonneaux, tables, urnes, crânes, os, armes, gravats et sacs sont des modules Blender
## (sources_blender/scripts/objets_donjon.py → assets/crypte/modules/objets_donjon.dat, lu en FileAccess : sûr dans le fil) posés par
## dcr.modele(), 2 ou 3 variantes tirées de la position (graine = case de 27 cm du point de pose dans le repère du lieu). Emprises,
## écarts au mur, collisions et tirages de dcr.rng IDENTIQUES à l'ancienne version (le décor tiré après ne bouge pas).

## Variante d'un module (« a », « b », « c ») tirée de la position du point de pose (repère du lieu : deux salles du kit diffèrent).
static func variante(dcr: CrypteDecor, pos: Vector3, n := 3, decal := 0) -> String:
	var w := dcr.xf * pos
	var h := absi(floori(w.x * 3.7) * 73856093 ^ floori(w.z * 3.7) * 19349663 ^ floori(w.y * 2.0) * 83492791) + decal
	return "abc"[h % n]

## Lacet « au hasard » stable (objets ronds : tonneaux, urnes, gravats) tiré de la position, sans toucher à dcr.rng.
static func lacet_pos(dcr: CrypteDecor, pos: Vector3) -> float:
	var w := dcr.xf * pos
	return fposmod(w.x * 2.39 + w.z * 3.17, TAU)

## Lot L1 : `deux_pieces` = coffre qui s'OUVRE (coffres interactifs de la crypte et de la grotte) : la cuve « coffre_cuve_x » (avec son or)
## est fondue dans les tampons comme avant, le couvercle « coffre_couvercle_x » est rendu à part (CoffreCouvercle) : renvoie
## {"modele", "xf" (charnière, repère du décor), "lueur" (intérieur de la cuve, repère du décor), "angle"} ; {} sinon (ou décor muet).
## Même variante, mêmes emprise, écart au mur, collision et tirages qu'un coffre d'une pièce.
static func coffre(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, collision := true, deux_pieces := false) -> Dictionary:
	dcr.j0("coffre", lacet)
	pos = dcr._ecarter(pos, Vector2(0.47, 0.3), lacet)
	dcr.emprise("coffre", pos, Vector2(0.47, 0.3), lacet, 0.64)
	var b := Basis(Vector3.UP, lacet)
	var v := variante(dcr, pos)
	var info := {}
	if deux_pieces:
		dcr.modele("coffre_cuve_" + v, pos, lacet, Vector3.ONE, {}, false)
		info = _couvercle(dcr, "coffre_couvercle_" + v, pos, lacet, CHARNIERE[v], 0.42)
		if not info.is_empty():
			info["or"] = "coffre_or_" + v      # L3 : or de la cuve à part (CoffreCouvercle : il disparaît quand le coffre est pillé)
	else:
		dcr.modele("coffre_" + v, pos, lacet, Vector3.ONE, {}, false)
	if collision:
		var s := b * Vector3(0.9, 0, 0.56)
		dcr.solide(pos + Vector3(0, 0.3, 0), Vector3(absf(s.x), 0.6, absf(s.z)))
	dcr.j1()
	return info

## Lot L1 : GRAND COFFRE ROYAL (1,2 x 0,7 m, 0,86 m couvercle compris), toujours en deux pièces (trésor du jarl, salle du trône).
static func coffre_royal(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> Dictionary:
	dcr.j0("coffre", lacet)
	pos = dcr._ecarter(pos, Vector2(0.62, 0.38), lacet)
	dcr.emprise("coffre", pos, Vector2(0.62, 0.38), lacet, 0.86)
	var b := Basis(Vector3.UP, lacet)
	dcr.modele("coffre_royal_cuve", pos, lacet, Vector3.ONE, {}, false)
	var info := _couvercle(dcr, "coffre_royal_couvercle", pos, lacet, CHARNIERE["royal"], 0.56)
	if not info.is_empty():
		info["or"] = "coffre_royal_or"
	var s := b * Vector3(1.22, 0, 0.74)
	dcr.solide(pos + Vector3(0, 0.36, 0), Vector3(absf(s.x), 0.72, absf(s.z)))
	dcr.j1()
	return info

## Charnière (y, z) de chaque couvercle : mêmes valeurs que CHARNIERE de sources_blender/scripts/objets_donjon.py.
const CHARNIERE := {"a": Vector2(0.445, -0.29), "b": Vector2(0.44, -0.29), "c": Vector2(0.44, -0.30), "royal": Vector2(0.56, -0.36)}

## Repère du couvercle (charnière) dans le repère du décor ; le couvercle OUVERT entre au registre d'audit de l'objet en cours
## (outils/audit_interpenetrations : un couvercle levé ne doit entrer ni dans le mur ni dans un voisin).
static func _couvercle(dcr: CrypteDecor, nom: String, pos: Vector3, lacet: float, ch: Vector2, y_lueur: float) -> Dictionary:
	if dcr.muet:
		return {}
	var b := Basis(Vector3.UP, lacet)
	var xf_c: Transform3D = dcr.xf * Transform3D(b, pos + b * Vector3(0, ch.x, ch.y))
	var info := {"modele": nom, "xf": xf_c, "lueur": dcr.xf * (pos + Vector3(0, y_lueur, 0)), "angle": CoffreCouvercle.ANGLE, "charniere": Vector3(0, ch.x, ch.y)}
	if dcr._obj_n > 0:
		var ouvert := xf_c * Transform3D(Basis(Vector3.RIGHT, -CoffreCouvercle.ANGLE), Vector3.ZERO)
		dcr._obj_v.append_array(ouvert * dcr.sommets_modele(nom))
	return info

static func bougie(dcr: CrypteDecor, pos: Vector3, avec_lumiere := true) -> void:
	if ObjLuminaires.bougie_c6(dcr, pos, avec_lumiere):      # C6 : une bougie sur deux de la crypte devient une grappe
		return
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
	# bandeau d'entrelacs gravé sur la panse : crypte seulement (texture non peinte dans la grotte), pas sur les petites urnes
	var mats := {} if dcr.est_crypte and e >= 0.45 else {"entrelacs": "argile"}
	dcr.cassable_debut("urne", pos, e)      # L5 : brisable (scripts/cassable.gd), maillage à part
	dcr.modele("urne_" + variante(dcr, pos), pos, lacet_pos(dcr, pos), Vector3(e, e, e), mats, false)
	dcr.cassable_fin()
	dcr.j1()

static func tonneau(dcr: CrypteDecor, pos: Vector3, e := 1.0) -> void:
	dcr.j0("tonneau")
	pos = dcr._ecarter(pos, Vector2(0.4, 0.4) * e)
	dcr.emprise("tonneau", pos, Vector2(0.4, 0.4) * e, 0.0, e)
	dcr.cassable_debut("tonneau", pos, e)
	dcr.modele("tonneau_" + variante(dcr, pos), pos, lacet_pos(dcr, pos), Vector3(e, e, e), {}, false)
	dcr.cassable_fin()
	dcr.j1()

static func table(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("table", lacet)
	pos = dcr._ecarter(pos, Vector2(0.55, 0.33), lacet)
	dcr.emprise("table", pos, Vector2(0.55, 0.33), lacet, 0.8)
	dcr.modele("table_" + variante(dcr, pos), pos, lacet, Vector3.ONE, {}, false)
	dcr.j1()
	ObjGarnitures.table(dcr, pos, lacet)      # C6 : livres, bols, crâne… posés dessus (crypte ; petits objets à part)

static func crane(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("crane", lacet)
	pos = dcr._suivre(pos)
	dcr.emprise("crane", pos, Vector2(0.1, 0.1), 0.0, 0.22)
	dcr.modele("crane_" + variante(dcr, pos, 2), pos, lacet, Vector3.ONE, {}, false)
	dcr.j1()

static func os_tas(dcr: CrypteDecor, pos: Vector3, n := 4, rayon := 0.4) -> void:
	dcr.j0("os_tas")
	dcr.emprise("os_tas", pos, Vector2(rayon + 0.15, rayon + 0.15), 0.0, 0.2)
	var v0 := variante(dcr, pos)
	for k in n:       # mêmes tirages que l'ancienne version (5 par os)
		var a := dcr.rng.randf() * TAU
		var d := dcr.rng.randf() * rayon
		var l := dcr.rng.randf_range(0.2, 0.36)
		var p := pos + Vector3(cos(a) * d, 0.012 * (k % 2), sin(a) * d)
		dcr.modele("os_long_" + "abc"[(v0.unicode_at(0) - 97 + k) % 3], p, dcr.rng.randf() * TAU, Vector3(l / 0.3, 1.0, 1.0), {}, false)
		dcr.modele("os_court_" + "ab"[(k + v0.unicode_at(0)) % 2], pos + Vector3(cos(a) * d, 0.0, sin(a) * d), dcr.rng.randf() * TAU, Vector3.ONE, {}, false)
	dcr.crane(pos + Vector3(dcr.rng.randf_range(-0.1, 0.1), 0.0, dcr.rng.randf_range(-0.1, 0.1)), dcr.rng.randf() * TAU)
	dcr.j1()

static func arme(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("arme", lacet)
	dcr.emprise("arme", pos, Vector2(0.5, 0.12), lacet, 0.04)
	dcr.modele("arme_" + variante(dcr, pos), pos, lacet, Vector3.ONE, {}, false)
	dcr.j1()

## Tas de gravats (roche effondrée) : cône irrégulier et blocs ; collision facultative.
static func gravats(dcr: CrypteDecor, pos: Vector3, r := 1.0, h := 0.7, avec_collision := true, mat := "mur2") -> void:
	dcr.j0("gravats")
	dcr.emprise("gravats", pos, Vector2(r, r), 0.0, h)
	for k in 5:       # tirages de l'ancienne version (blocs), gardés pour ne pas déplacer le décor tiré après
		dcr.rng.randf()
		dcr.rng.randf_range(0.55, 1.05)
		dcr.rng.randf_range(0.18, 0.4)
		dcr.rng.randf()
	# C5 : gravats v2 en blocs taillés — échelle verticale bornée (0,7 à 1,3 fois l'horizontale) : les blocs ne s'écrasent ni ne s'étirent
	# pierre : en crypte v2, celle des murs et du dallage (pierre_v2 / pierre_sol, plus claires que les vieux « mur* ») — sauf la glace (mur4)
	var mats := {"pierre": mat, "pierre2": "mur1" if mat != "mur1" else "mur0"}
	if dcr.v2 and mat != "mur4":
		mats = {"pierre": "pierre_v2", "pierre2": "mur1"}      # blocs clairs + éclats sombres : le tas garde sa silhouette sur le dallage
	dcr.modele("gravats_" + variante(dcr, pos), pos, lacet_pos(dcr, pos), Vector3(r, clampf(h / 0.7, r * 0.7, r * 1.3), r), mats, false)
	if avec_collision:
		dcr.solide(pos + Vector3(0, h * 0.4, 0), Vector3(r * 1.5, h * 0.8, r * 1.5))
	dcr.j1()

## Sac de pillard éventré (étoffe, pièces, os) et coffre forcé (couvercle dressé derrière, serrure arrachée).
static func sac_dechire(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> void:
	dcr.j0("sac_dechire")
	dcr.emprise("sac_dechire", pos, Vector2(0.45, 0.35), 0.0, 0.2)
	dcr.modele("sac_" + variante(dcr, pos, 2), pos, lacet + 0.3, Vector3.ONE, {}, false)
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
