extends RefCounted
## Audit des interpénétrations, lieu CRYPTE (appelé par outils/audit_interpenetrations.gd --lieu=crypte, même interface :
## --max, --poses, --vues ; code de sortie = nombre de cas graves). Options propres : --zone=<id>, --tailles, --tout.
##   godot --headless --path . --script res://outils/audit_interpenetrations.gd -- --nouvelle --paisible --lieu=crypte [--poses=f --vues=15]
## Planche : ... audit_interpenetrations.gd -- --planche=<dossier> [--titre=TEXTE] (cas.txt « nom|libellé » + <nom>.png -> planche.png).
##
## Le décor de la crypte est fusionné par matière : il n'y a pas de nœud par objet. On active donc CrypteDecor.journal_actif AVANT de
## bâtir le monde : chaque objet de haut niveau (sarcophage, urne, statue, module Blender…) note ses bornes réelles (sommets émis) dans un
## repère tourné de son lacet, et les collisions qu'il a créées. Contrôles :
##  1. ENFONCEMENT / CHEVAUCHEMENT avec les collisions (murs, sols, plafonds, piliers, estrades, mécanismes) : profondeur d'interpénétration
##     3D (axes séparateurs, boîtes orientées en lacet), sans les collisions de l'objet lui-même ;
##  2. CHEVAUCHEMENT avec la structure visible sans collision (soubassement des murs, panneaux de maçonnerie v2, piliers engagés) ;
##  3. CHEVAUCHEMENT ENTRE OBJETS, et DOUBLONS (même type au même endroit) ;
##  4. OBJETS FLOTTANTS (> 5 cm au-dessus de leur appui : collision ou objet dessous) ;
##  5. FLAQUES (emplacements d'eau) qui passent sous un mur, un pilier ou un objet ;
##  6. GARDIENS à l'apparition dans un solide ou dans le décor ; INTERACTIFS recouverts / encombrés par le décor ou dans un solide.
## Gravité : GRAVE (profondeur >= 10 cm, flottant > 5 cm, doublon, gardien ou interactif touché), MOYEN (4 à 10 cm), sinon ignoré.
## Sortie : une ligne par cas, classée par gravité puis par score ; `--poses=` écrit un fichier de poses (`--captures`) qui cadre les pires cas.
##
## Planche : godot --headless --path . --script res://outils/audit_interpenetrations.gd -- --planche=<dossier> [--titre=AVANT]
##   lit <dossier>/cas.txt (« nom|libellé » par ligne) et <dossier>/<nom>.png, écrit <dossier>/planche.png (3 colonnes, libellés).

const SEUIL_GRAVE := 0.10
const SEUIL_MOYEN := 0.04
const FLOTTE := 0.05

## Catégories des types du journal (nom de primitive ou de module Blender).
const STRUCTURE := ["relief_mur", "pilier", "pilastre_mur", "contrefort", "poutre", "arc", "oculus", "niche", "niche_os", "panneau_os"]
const STRUCT_PREFIXES := ["pilier_", "colonne_", "arche_", "pan_mur", "estrade_", "degres_", "marches_"]
const MURAL := ["applique", "banniere", "embleme", "frise", "bouclier_mural", "sceau"]
const PLAFOND := ["lustre", "lustre_v2", "lustre_fer", "chaine", "toile", "glacon"]
const DECAL := ["flaque", "givre_decal", "tapis", "parchemins_epars"]
const EPARS := ["os_tas", "parchemins_epars", "sac_dechire", "or_tas", "crane_os"]     # tas épars : boîte englobante lâche, seuil plus haut
const HOTES := ["coffre", "coffre_force", "sarcophage", "sarcophage_pille", "sarcophage_svanhild", "socle", "socle_v2", "autel", "autel_octo", "table",
	"table_embaumement", "statue", "statue_capuche", "vasque_rituel", "bassin", "trone", "ratelier_armes", "etagere", "lit", "brasero", "candelabre", "barricade",
	"os_monticule", "or_tas"]
const AMAS := ["congere", "eboulis_a", "eboulis_b", "eboulis_c", "dalles_a", "dalles_b", "dalles_c", "gravats", "os_monticule", "or_tas"]   # amas posés CONTRE les murs : le contact avec le mur est voulu
const PETITS := ["bougie", "crane", "crane_os", "os_tas", "urne", "eboulis_a", "eboulis_b", "eboulis_c", "dalles_a", "dalles_b", "dalles_c", "gravats",
	"parchemins_epars", "sac_dechire", "tonneau", "arme", "candelabre"]

var _flotte_vu := {}
var cas: Array = []          # {grav, score, zone, quoi, pos, detail, cible (Vector3), taille}
var objets: Array = []       # {t, cat, c, a, h (demi-tailles x,y,z), ymin, ymax, cs (Dictionary de collisions propres), mod}
var boites: Array = []       # {c, h, ymin, ymax, genre ("mur"|"sol"|"plafond"|"solide"|"meca"), n (CollisionShape3D)}
var zones: Array = []
var _own_g := {}            # groupe (objet découpé en cases) -> collisions propres partagées
var _grille := {}            # cellule 2 m -> [indices d'objets]
var _grille_b := {}          # cellule 2 m -> [indices de boîtes]

var _args := {}

func _arg(nom: String, defaut := "") -> String:
	if _args.has(nom):
		return "1" if String(_args[nom]) == "" else String(_args[nom])
	return defaut

## À appeler AVANT d'instancier le monde (le journal se remplit pendant la construction).
static func preparer() -> void:
	CrypteDecor.journal_actif = true

## Audit de la crypte d'un monde déjà instancié ; renvoie le nombre de cas graves.
func lancer(tree: SceneTree, m: Node3D, args: Dictionary) -> int:
	_args = args
	m.tertre.attendre_donjon()
	for i in 3:
		await tree.physics_frame
	var t0 := Time.get_ticks_msec()
	_collecter(m.tertre)
	if m.tertre.d2 == null or m.tertre.d2.journal.is_empty():
		push_error("audit crypte : donjon non bâti (erreur de script ?) — audit impossible")
		return 999
	if _arg("tailles") != "":
		var vu := {}
		for o: Dictionary in objets:
			if not vu.has(o["t"]) and not o["partie"]:
				vu[o["t"]] = true
				print("TAILLE %-20s demi=%s ymin-ymax=%.2f" % [o["t"], str(o["h"]), float(o["ymax"]) - float(o["ymin"])])
	_controler(m.tertre)
	var ng := _rapport(m.tertre, int(_arg("vues", _arg("max", "15"))))
	print("AUDIT : %d objets, %d collisions, calcul %d ms" % [objets.size(), boites.size(), Time.get_ticks_msec() - t0])
	CrypteDecor.journal_actif = false
	return ng

# ------------------------------------------------------------------ collecte
static func categorie(t: String) -> String:
	if t in STRUCTURE:
		return "structure"
	for p: String in STRUCT_PREFIXES:
		if t.begins_with(p):
			return "structure"
	if t in MURAL:
		return "mural"
	if t in PLAFOND:
		return "plafond"
	if t in DECAL:
		return "decal"
	return "sol"

func _collecter(tr: Node) -> void:
	var crypte: Node3D = tr.crypte
	for dec: CrypteDecor in [tr.d, tr.d2]:
		var base: Transform3D = crypte.global_transform.affine_inverse() * dec.racine.global_transform
		if not base.is_equal_approx(Transform3D.IDENTITY):
			push_warning("audit : repère du décor décalé de la crypte (%s)" % str(base.origin))
		for e: Dictionary in dec.journal:
			var mn: Vector3 = e["min"]
			var mx: Vector3 = e["max"]
			var a: float = e["lacet"]
			var cl := (mn + mx) * 0.5
			var c := Basis(Vector3.UP, a) * cl
			var own := {}
			for n in e["cs"]:
				own[n] = true
			var gmn: Vector3 = e.get("gmin", mn)
			var gmx: Vector3 = e.get("gmax", mx)
			var gc := Basis(Vector3.UP, a) * ((gmn + gmx) * 0.5)
			var gid := "%d/%d" % [0 if dec == tr.d else 1, int(e["gid"])]
			if not _own_g.has(gid):
				_own_g[gid] = own
			own = _own_g[gid]
			objets.append({"partie": e.get("partie", false), "gid": gid, "g": {"c": base * gc, "a": a, "h": (gmx - gmn) * 0.5, "ymin": gmn.y + base.origin.y, "ymax": gmx.y + base.origin.y}, "t": e["t"], "cat": categorie(e["t"]), "c": base * c, "a": a, "h": (mx - mn) * 0.5, "ymin": mn.y + base.origin.y, "ymax": mx.y + base.origin.y,
				"cs": own, "mod": e["mod"]})
	# collisions : décor (corps des deux décors) + mécanismes et pièces mobiles posés dans la crypte ; pas les personnages
	var deco := {}
	for dec: CrypteDecor in [tr.d, tr.d2]:
		for n in dec.corps.get_children():
			deco[n] = true
	for n in crypte.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.disabled or cs.shape == null or _sous_perso(cs):
			continue
		var t := crypte.global_transform.affine_inverse() * cs.global_transform
		var bx := t.basis.x.normalized()
		if absf(bx.y) > 0.05 or absf(t.basis.y.normalized().y) < 0.95:
			continue      # rampe inclinée (escaliers, estrades) : sa boîte alignée engloberait toute la cage
		var h := Vector3.ZERO
		if cs.shape is BoxShape3D:
			h = (cs.shape as BoxShape3D).size * 0.5
		elif cs.shape is CylinderShape3D:
			var cy := cs.shape as CylinderShape3D
			h = Vector3(cy.radius, cy.height * 0.5, cy.radius)
		elif cs.shape is CapsuleShape3D:
			var ca := cs.shape as CapsuleShape3D
			h = Vector3(ca.radius, ca.height * 0.5, ca.radius)
		elif cs.shape is SphereShape3D:
			var r := (cs.shape as SphereShape3D).radius
			h = Vector3(r, r, r)
		else:
			continue
		# boîte englobante alignée sur les axes de la crypte (les collisions du décor le sont toutes)
		var ab := t * AABB(-h, h * 2.0)
		var hh := ab.size * 0.5
		var genre := "solide"
		if not deco.has(cs):
			genre = "meca"
		elif ab.size.y >= 1.9 and minf(ab.size.x, ab.size.z) <= 0.75 and maxf(ab.size.x, ab.size.z) >= 0.9:
			genre = "mur"
		elif ab.size.y <= 0.45 and maxf(ab.size.x, ab.size.z) >= 2.5:
			genre = "dalle"      # sol ou plafond : décidé par rapport à l'objet
		boites.append({"c": ab.get_center(), "h": hh, "ymin": ab.position.y, "ymax": ab.end.y, "genre": genre, "n": cs, "a": 0.0})
	zones = tr.donjon.zones.duplicate()
	# pièces du tertre (hors kit) : vestibule, alcôve d'Eirik, couloir de la herse — rectangles approchés pour nommer les cas
	for i in objets.size():
		_ranger(_grille, objets[i], i)
	for i in boites.size():
		_ranger(_grille_b, boites[i], i)
	# collision posée À CÔTÉ de l'objet (solide() appelé hors de j0/j1, ex. sarcophage du rituel, statues de table) : une boîte
	# entièrement contenue dans l'objet (à 0,3 m près) est la sienne
	var faits := {}
	for o0: Dictionary in objets:
		if o0["cat"] == "structure" or faits.has(o0["gid"]):
			continue
		faits[o0["gid"]] = true
		var o: Dictionary = o0["g"]
		o["cs"] = o0["cs"]
		for j in _voisins(_grille_b, o, 0.3):
			var b: Dictionary = boites[j]
			if b["genre"] in ["mur", "dalle"]:
				continue
			var c: Vector3 = b["c"]
			var h: Vector3 = b["h"]
			var dedans := float(b["ymin"]) >= float(o["ymin"]) - 0.3 and float(b["ymax"]) <= float(o["ymax"]) + 0.3
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					if not contient_xz(o, c + Vector3(sx * h.x, 0, sz * h.z), 0.3):
						dedans = false
			if dedans:
				(o["cs"] as Dictionary)[b["n"]] = true

func _sous_perso(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is CharacterBody3D or p is RigidBody3D:
			return true
		p = p.get_parent()
	return false

func _rayon_xz(o: Dictionary) -> float:
	var h: Vector3 = o["h"]
	return sqrt(h.x * h.x + h.z * h.z)

func _ranger(g: Dictionary, o: Dictionary, i: int) -> void:
	var c: Vector3 = o["c"]
	var r := _rayon_xz(o)
	for x in range(floori((c.x - r) / 2.0), floori((c.x + r) / 2.0) + 1):
		for z in range(floori((c.z - r) / 2.0), floori((c.z + r) / 2.0) + 1):
			var k := Vector3i(x, z, 1 if c.y < -3.0 else 0)
			if not g.has(k):
				g[k] = []
			(g[k] as Array).append(i)

func _voisins(g: Dictionary, o: Dictionary, marge := 0.0) -> Array:
	var c: Vector3 = o["c"]
	var r := _rayon_xz(o) + marge
	var vu := {}
	var res: Array = []
	for et in [0, 1]:
		if (et == 1) != (c.y < -3.0) and not (o["ymin"] < -3.0 and o["ymax"] > -3.0):
			continue
		for x in range(floori((c.x - r) / 2.0), floori((c.x + r) / 2.0) + 1):
			for z in range(floori((c.z - r) / 2.0), floori((c.z + r) / 2.0) + 1):
				for i in g.get(Vector3i(x, z, et), []):
					if not vu.has(i):
						vu[i] = true
						res.append(i)
	return res

# ------------------------------------------------------------------ géométrie : boîtes orientées en lacet
static func _axes(a: float) -> Array:
	return [Vector2(cos(a), -sin(a)), Vector2(sin(a), cos(a))]

## Profondeur d'interpénétration (0 si séparés) : [profondeur 3D, profondeur au sol (xz), recouvrement vertical].
static func penetration(A: Dictionary, B: Dictionary, grow_a := 0.0) -> Array:
	var oy := minf(A["ymax"], B["ymax"]) - maxf(A["ymin"], B["ymin"])
	if oy <= 0.0:
		return [0.0, 0.0, oy]
	var aa := _axes(A["a"])
	var ab := _axes(B["a"])
	var ha: Vector3 = A["h"] + Vector3(grow_a, 0, grow_a)
	var hb: Vector3 = B["h"]
	var ca: Vector3 = A["c"]
	var cb: Vector3 = B["c"]
	var d := Vector2(cb.x - ca.x, cb.z - ca.z)
	var pmin := INF
	for n: Vector2 in [aa[0], aa[1], ab[0], ab[1]]:
		var ra := absf((aa[0] as Vector2).dot(n)) * ha.x + absf((aa[1] as Vector2).dot(n)) * ha.z
		var rb := absf((ab[0] as Vector2).dot(n)) * hb.x + absf((ab[1] as Vector2).dot(n)) * hb.z
		var o := ra + rb - absf(d.dot(n))
		if o <= 0.0:
			return [0.0, 0.0, oy]
		pmin = minf(pmin, o)
	return [minf(pmin, oy), pmin, oy]

static func contient_xz(B: Dictionary, p: Vector3, marge := 0.0) -> bool:
	var ab := _axes(B["a"])
	var c: Vector3 = B["c"]
	var d := Vector2(p.x - c.x, p.z - c.z)
	var h: Vector3 = B["h"]
	return absf(d.dot(ab[0])) <= h.x + marge and absf(d.dot(ab[1])) <= h.z + marge

## Distance horizontale d'un point au bord d'une boîte (0 si dedans).
static func dist_xz(B: Dictionary, p: Vector3) -> float:
	var ab := _axes(B["a"])
	var c: Vector3 = B["c"]
	var d := Vector2(p.x - c.x, p.z - c.z)
	var h: Vector3 = B["h"]
	var qx := maxf(0.0, absf(d.dot(ab[0])) - h.x)
	var qz := maxf(0.0, absf(d.dot(ab[1])) - h.z)
	return sqrt(qx * qx + qz * qz)

# ------------------------------------------------------------------ contrôles
func _zone_de(p: Vector3, mod := "") -> String:
	if mod != "":
		return mod
	for z: Dictionary in zones:
		if (z["rect"] as Rect2).grow(0.31).has_point(Vector2(p.x, p.z)) and absf(p.y - float(z["y"])) < 4.0:
			return z["nom"]
	return "tertre"

func _ajoute(grav: String, score: float, o: Dictionary, quoi: String, detail: String, taille := 1.5) -> void:
	var c: Vector3 = o["c"] if o.has("c") else o["pos"]
	cas.append({"grav": grav, "score": score, "zone": _zone_de(c, String(o.get("mod", ""))), "quoi": quoi, "pos": c, "detail": detail,
		"cible": Vector3(c.x, (float(o.get("ymin", c.y)) + float(o.get("ymax", c.y))) * 0.5, c.z), "taille": taille, "sol": float(o.get("ymin", c.y))})

static func _grav(p: float, seuil_g := SEUIL_GRAVE, seuil_m := SEUIL_MOYEN) -> String:
	return "GRAVE" if p >= seuil_g else ("MOYEN" if p >= seuil_m else "")

func _controler(tr: Node) -> void:
	var zq := _arg("zone")
	for i in objets.size():
		var o: Dictionary = objets[i]
		if zq != "" and _zone_de(o["c"], o["mod"]) != zq:
			continue
		var cat: String = o["cat"]
		var t: String = o["t"]
		if cat == "structure" or t == "givre_decal" or t == "toile" or t == "chaine" or t == "tapis":
			continue
		var ep := t in EPARS
		# 1. collisions
		for j in _voisins(_grille_b, o, 0.1):
			var b: Dictionary = boites[j]
			if (o["cs"] as Dictionary).has(b["n"]):
				continue
			var pe := penetration(o, b)
			if pe[0] <= 0.0:
				continue
			var genre: String = b["genre"]
			if genre == "dalle":
				genre = "sol" if float(b["c"].y) < float(o["c"].y) else "plafond"
			if cat == "decal":
				if t == "flaque" and genre in ["mur", "solide", "meca"]:
					var g := _grav(pe[1], 0.12, 0.05)
					if g != "":
						_ajoute(g, pe[1], o, "flaque", "passe sous %s de %.2f m" % [_nom_boite(genre), pe[1]])
				continue
			if cat == "mural" or cat == "plafond":
				if genre in ["solide", "meca"] or (genre == "mur" and pe[0] > 0.15):
					var g := _grav(pe[0])
					if g != "":
						var info2 := (" [boîte %s ±%s / objet %s ±%s]" % [str(b["c"]), str(b["h"]), str(o["c"]), str(o["h"])]) if _arg("detail") != "" else ""
						_ajoute(g, pe[0], o, t, "dans %s de %.2f m" % [_nom_boite(genre), pe[0]] + info2)
				continue
			if genre == "plafond" or (t in AMAS and genre in ["mur", "sol"]):
				continue
			var p: float = pe[0] if genre != "sol" else pe[2]
			if genre == "sol" and pe[1] < 0.05:
				continue
			var g := _grav(p, SEUIL_GRAVE * (1.5 if ep else 1.0))
			if g != "":
				var info := (" [boîte %s ±%s]" % [str(b["c"]), str(b["h"])]) if _arg("detail") != "" else ""
				_ajoute(g, p * (1.5 if genre == "mur" else 1.0), o, t, (("enfoncé de %.2f m dans le sol" % p) if genre == "sol" else ("dans %s de %.2f m" % [_nom_boite(genre), p])) + info)
		if cat == "decal":
			# flaque sous un objet ou une structure visible
			if t == "flaque":
				for j in _voisins(_grille, o):
					if j == i:
						continue
					var q: Dictionary = objets[j]
					if q["cat"] in ["decal", "plafond", "mural"] or q["t"] in ["toile", "chaine"]:
						continue
					var pe := penetration(o, q)
					var g := _grav(pe[1], 0.15, 0.06)
					if g != "" and float(q["ymin"]) < float(o["ymax"]) + 0.05:
						if q["cat"] != "structure" and g == "GRAVE":
							g = "MOYEN"
						_ajoute(g, pe[1], o, "flaque", "sous %s (%.2f m)" % [q["t"], pe[1]])
			continue
		# 2-3. structure visible et autres objets
		for j in _voisins(_grille, o):
			if j == i or objets[j]["gid"] == o["gid"]:
				continue
			var q: Dictionary = objets[j]
			var qc: String = q["cat"]
			var qt: String = q["t"]
			if qc == "decal" or qt in ["toile", "chaine"] or qt.begins_with("arche_") or qt == "arc":
				continue
			if qc != "structure" and j < i and objets[j]["cat"] == cat and not (cat in ["mural", "plafond"]):
				continue        # paire déjà vue
			if cat in ["mural", "plafond"] and not (qc in ["structure", "mural"] if cat == "mural" else qc == "structure"):
				continue
			if cat == "sol" and qc in ["mural", "plafond"]:
				continue
			if cat == "mural" and qc == "mural" and j < i:
				continue
			var pe := penetration(o, q)
			if pe[0] <= 0.0:
				# doublon parfait : même type, presque même centre
				continue
			if qt == t and (o["c"] as Vector3).distance_to(q["c"]) < 0.12 and not ep and not o["partie"]:
				_ajoute("GRAVE", 1.0, o, t, "DOUBLON (même objet au même endroit)")
				continue
			var ep2 := ep or qt in EPARS
			if (t in PETITS and qt in HOTES and float(o["ymin"]) > float(q["ymin"]) + 0.3) or (qt in PETITS and t in HOTES and float(q["ymin"]) > float(o["ymin"]) + 0.3):
				continue      # petit objet posé SUR un meuble (bougie sur l'autel, crâne sur le socle)
			var p: float = pe[0]
			if qc == "structure" and qt == "relief_mur" and float(o["ymin"]) > float(q["ymax"]) - 0.02:
				continue
			if qc == "structure" and t in AMAS and (qt == "relief_mur" or qt == "panneau_os" or qt.begins_with("pan_mur") or qt.begins_with("pilier_mur")):
				continue
			var g := _grav(p, SEUIL_GRAVE * (1.6 if ep2 else 1.0), SEUIL_MOYEN * (1.5 if ep2 else 1.0))
			if cat == "mural":
				g = _grav(p, 0.05, 0.025)
			if g != "":
				_ajoute(g, p * (1.2 if qc == "structure" else 1.0), o, t, "%s %s de %.2f m" % ["dans" if qc == "structure" else "chevauche", qt, p])
		# 4. flottant
		if cat == "sol" and (not o["partie"] or not _flotte_vu.has(o["gid"])):
			_flotte_vu[o["gid"]] = true
			var og: Dictionary = o["g"].duplicate()
			og["cs"] = o["cs"]
			og["gid"] = o["gid"]
			var f := _flottement(og)
			if f > FLOTTE:
				_ajoute("GRAVE" if f > FLOTTE else "MOYEN", f * 2.0, o, t, "flotte à %.2f m au-dessus de son appui" % f if f < 5.0 else "sans appui dessous (vide)")
	_gardiens(tr)
	_interactifs(tr)

func _nom_boite(genre: String) -> String:
	return {"mur": "le mur", "sol": "le sol", "plafond": "le plafond", "solide": "une collision (pilier, estrade, meuble…)", "meca": "un mécanisme"}.get(genre, genre)

## Hauteur entre la base de l'objet et son appui (collision ou objet dessous qui contient le centre).
func _flottement(o: Dictionary) -> float:
	var base: float = o["ymin"]
	var c: Vector3 = o["c"]
	var appui := -INF
	for j in _voisins(_grille_b, o, 0.0):
		var b: Dictionary = boites[j]
		if (o["cs"] as Dictionary).has(b["n"]):
			continue
		var top: float = b["ymax"]
		if top <= base + 0.3 and top >= base - 1.5 and contient_xz(b, c):
			appui = maxf(appui, top)
	for j in _voisins(_grille, o):
		var q: Dictionary = objets[j]
		if q["gid"] == o["gid"] or not (q["cat"] in ["sol", "structure"]):
			continue
		var top: float = q["ymax"]
		if top <= base + 0.03 and top >= base - 1.5 and contient_xz(q, c, -0.02):
			appui = maxf(appui, top)
	if appui > base:
		return 0.0
	if appui == -INF:
		return 99.0
	return base - appui

func _gardiens(tr: Node) -> void:
	var gs: Array = tr.donjon.gardiens
	for gi in gs.size():
		var g: Dictionary = gs[gi]
		var p: Vector3 = g["pos"]
		var G := {"c": p + Vector3(0, 0.95, 0), "a": float(g["lacet"]), "h": Vector3(0.3, 0.85, 0.3), "ymin": p.y + 0.1, "ymax": p.y + 1.8, "mod": g["zone"], "cs": {}}
		for j in _voisins(_grille_b, G, 0.2):
			var b: Dictionary = boites[j]
			var pe := penetration(G, b)
			if pe[0] > 0.0:
				var gr := _grav(pe[0], 0.12, 0.05)
				if gr != "":
					_ajoute("GRAVE" if gr == "GRAVE" else "MOYEN", pe[0] * 2.0, G, "gardien %s" % g["ident"], "apparaît dans %s (%.2f m)" % [_nom_boite(b["genre"] if b["genre"] != "dalle" else "sol"), pe[0]], 2.4)
		for j in _voisins(_grille, G, 0.2):
			var q: Dictionary = objets[j]
			if q["cat"] in ["decal", "plafond", "mural"] or q["t"] in ["chaine", "toile", "niche", "niche_os"] or q["t"].begins_with("arche_"):
				continue
			var pe := penetration(G, q)
			var gr := _grav(pe[0], 0.12, 0.05)
			if gr != "" and not (q["t"] in ["crane", "crane_os", "os_tas", "bougie"] and pe[0] < 0.2):
				_ajoute(gr, pe[0] * 2.0, G, "gardien %s" % g["ident"], "apparaît dans %s (%.2f m)" % [q["t"], pe[0]], 2.4)
		for gj in range(gi + 1, gs.size()):
			var p2: Vector3 = gs[gj]["pos"]
			if absf(p2.y - p.y) < 1.0 and Vector2(p2.x - p.x, p2.z - p.z).length() < 0.7:
				_ajoute("GRAVE", 1.0, G, "gardien %s" % g["ident"], "même point d'apparition que %s" % gs[gj]["ident"], 2.4)

func _interactifs(tr: Node) -> void:
	var crypte: Node3D = tr.crypte
	var scr := load("res://scripts/interactif.gd")
	for n in crypte.find_children("*", "Node3D", true, false):
		if n.get_script() != scr:
			continue
		var p: Vector3 = crypte.to_local((n as Node3D).global_position)
		var nom: String = String(n.get("nom"))
		var I := {"c": p, "a": 0.0, "h": Vector3(0.05, 0.05, 0.05), "ymin": p.y - 0.05, "ymax": p.y + 0.05, "mod": "", "cs": {}}
		var sol_y: float = -6.0 if p.y < -3.0 else 0.0
		for j in _voisins(_grille, I, 0.8):
			var q: Dictionary = objets[j]
			var qt: String = q["t"]
			if q["cat"] in ["decal", "plafond", "structure"] or qt in ["chaine", "toile"]:
				continue
			var cq: Vector3 = q["c"]
			var hote := (qt in HOTES and contient_xz(q, p, 0.45)) or Vector2(cq.x - p.x, cq.z - p.z).length() < 0.2 \
				or (qt in ["os_tas", "crane", "crane_os", "sac_dechire"] and contient_xz(q, p, 0.1))      # restes du corps fouillé = l'interactif lui-même
			if hote:
				continue
			var dxz := dist_xz(q, p)
			if q["cat"] == "mural":
				if dxz < 0.05 and float(q["ymin"]) - 0.05 <= p.y and float(q["ymax"]) + 0.05 >= p.y:
					_ajoute("GRAVE", 0.8, I, "interactif « %s »" % nom, "recouvert par %s" % qt, 1.6)
				continue
			var haut_ok := float(q["ymax"]) >= p.y - 0.5      # objet qui monte à hauteur du point d'interaction
			if dxz < 0.08 and haut_ok:
				_ajoute("GRAVE", 0.9, I, "interactif « %s »" % nom, "recouvert par %s" % qt, 1.6)
			elif not (float(q["ymax"]) >= p.y - 0.8) or float(q["ymin"]) > sol_y + 0.15:
				continue      # seul le fouillis AU SOL encombre (une bougie posée sur la même table est un accessoire)
			elif dxz < 0.35 and qt in PETITS:
				_ajoute("GRAVE", 0.5, I, "interactif « %s »" % nom, "encombré par %s à %.2f m" % [qt, dxz], 1.6)
			elif dxz < 0.6 and qt in PETITS:
				_ajoute("MOYEN", 0.3, I, "interactif « %s »" % nom, "%s collé à %.2f m" % [qt, dxz], 1.6)
		for j in _voisins(_grille_b, I, 0.1):
			var b: Dictionary = boites[j]
			if b["genre"] in ["mur", "dalle"] and contient_xz(b, p, -0.25) and p.y < float(b["ymax"]) - 0.1 and p.y > float(b["ymin"]) + 0.1:
				_ajoute("GRAVE", 1.0, I, "interactif « %s »" % nom, "dans %s : inatteignable" % _nom_boite(b["genre"]), 1.6)
		I["ymin"] = sol_y

# ------------------------------------------------------------------ rapport et poses de capture
func _rapport(tr: Node, nmax: int) -> int:
	# regroupe les doublons de cas (même objet, même défaut)
	var vus := {}
	var uniques: Array = []
	for c: Dictionary in cas:
		var k := "%s|%s|%.1f,%.1f,%.1f|%s" % [c["grav"], c["quoi"], c["pos"].x, c["pos"].y, c["pos"].z, String(c["detail"]).get_slice(" de ", 0)]
		if vus.has(k):
			continue
		vus[k] = true
		uniques.append(c)
	uniques.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["grav"] != b["grav"]:
			return a["grav"] == "GRAVE"
		return float(a["score"]) > float(b["score"]))
	var ng := 0
	var nm := 0
	var par_zone := {}
	var par_quoi := {}
	for c: Dictionary in uniques:
		if c["grav"] == "GRAVE":
			ng += 1
			par_zone[c["zone"]] = int(par_zone.get(c["zone"], 0)) + 1
			var q: String = String(c["quoi"]).get_slice(" ", 0)
			par_quoi[q] = int(par_quoi.get(q, 0)) + 1
		else:
			nm += 1
	var tout := _arg("tout") != ""
	var k := 0
	for c: Dictionary in uniques:
		if not tout and c["grav"] != "GRAVE" and k >= 60:
			break
		var p: Vector3 = c["pos"]
		print("CAS %-5s %5.2f  %-14s %-28s (%.2f, %.2f, %.2f)  %s" % [c["grav"], c["score"], c["zone"], c["quoi"], p.x, p.y, p.z, c["detail"]])
		k += 1
	print("PAR ZONE (graves) : ", par_zone)
	print("PAR TYPE (graves) : ", par_quoi)
	print("BILAN : %d GRAVES, %d MOYENS (lieu crypte)" % [ng, nm])
	var fp := _arg("poses")
	if fp != "":
		_poses(uniques, fp, nmax)
	return ng

## Fichier de poses (`--captures`) : un cadrage par cas (caméra à ~2 m, côté pièce, regard sur l'objet).
func _poses(liste: Array, chemin: String, nmax: int) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		push_error("audit : impossible d'écrire " + chemin)
		return
	var f_cas := FileAccess.open(chemin.get_base_dir().path_join("cas.txt"), FileAccess.WRITE)
	f.store_line("# audit_interpenetrations : pires cas (repère de la crypte) — x,z,lacet,tangage,y")
	var n := 0
	var deja: Array = []
	var par_quoi := {}
	for c: Dictionary in liste:
		if n >= nmax:
			break
		var kq: String = String(c["quoi"]).get_slice(" ", 0)
		if int(par_quoi.get(kq, 0)) >= 2 or c["grav"] != "GRAVE":      # planche variée : 2 cas au plus par type d'objet
			continue
		var cible: Vector3 = c["cible"]
		var proche := false
		for d: Vector3 in deja:
			if d.distance_to(cible) < 1.2:
				proche = true
		if proche:
			continue
		deja.append(cible)
		par_quoi[kq] = int(par_quoi.get(kq, 0)) + 1
		var sol: float = -6.0 if cible.y < -3.0 else 0.0
		var cam := _cam(cible, sol, float(c["taille"]))
		var dir := cible - (cam + Vector3(0, 1.6, 0))
		var lacet := rad_to_deg(atan2(-dir.x, -dir.z))
		var dh := Vector2(dir.x, dir.z).length()
		var tang := rad_to_deg(atan2(dir.y, dh))
		n += 1
		var nom := "cas%02d" % n
		f.store_line("%s crypte %.2f,%.2f,%.1f,%.1f,%.1f ouvre=s1,s2,s3,secret,herse sans-mains" % [nom, cam.x, cam.z, lacet, tang, sol])
		if f_cas:
			f_cas.store_line("%s|%s %s - %s : %s" % [nom, nom.to_upper(), c["zone"], c["quoi"], c["detail"]])
	print("POSES : %d vues -> %s" % [n, chemin])

## Caméra : à `dist` de la cible, du côté le plus dégagé (vers le centre de la salle), dans la salle.
func _cam(cible: Vector3, sol: float, taille: float) -> Vector3:
	var r := Rect2(cible.x - 3, cible.z - 3, 6, 6)
	for z: Dictionary in zones:
		var zr: Rect2 = z["rect"]
		if zr.grow(0.31).has_point(Vector2(cible.x, cible.z)) and absf(float(z["y"]) - sol) < 1.0:
			r = zr
			break
	var centre := r.get_center()
	var v := Vector2(centre.x - cible.x, centre.y - cible.z)
	if v.length() < 0.3:
		v = Vector2(0, 1)
	v = v.normalized()
	var dist := clampf(taille * 1.4, 1.6, 2.6)
	var p := Vector2(cible.x, cible.z) + v * dist
	var rr := r.grow(-0.55)
	if rr.size.x > 0 and rr.size.y > 0:
		p = Vector2(clampf(p.x, rr.position.x, rr.end.x), clampf(p.y, rr.position.y, rr.end.y))
	return Vector3(p.x, sol, p.y)

# ------------------------------------------------------------------ planche
const G5 := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14], "D": [30, 17, 17, 17, 17, 17, 30],
	"E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16], "G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17],
	"I": [14, 4, 4, 4, 4, 4, 14], "J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 25, 21, 19, 17, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14], "P": [30, 17, 17, 30, 16, 16, 16],
	"Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17], "S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4],
	"U": [17, 17, 17, 17, 17, 17, 14], "V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31], "3": [30, 1, 1, 14, 1, 1, 30],
	"4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14], "6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8],
	"8": [14, 17, 17, 14, 17, 17, 14], "9": [14, 17, 17, 15, 1, 2, 12], "-": [0, 0, 0, 31, 0, 0, 0], " ": [0, 0, 0, 0, 0, 0, 0],
	".": [0, 0, 0, 0, 0, 12, 12], ",": [0, 0, 0, 0, 12, 4, 8], ":": [0, 12, 12, 0, 12, 12, 0], "(": [2, 4, 8, 8, 8, 4, 2], ")": [8, 4, 2, 2, 2, 4, 8],
	"/": [1, 1, 2, 4, 8, 16, 16], "_": [0, 0, 0, 0, 0, 0, 31], "'": [4, 4, 8, 0, 0, 0, 0], "%": [24, 25, 2, 4, 8, 19, 3],
}
const ACCENTS := {"É": "E", "È": "E", "Ê": "E", "À": "A", "Â": "A", "Ô": "O", "Î": "I", "Ï": "I", "Û": "U", "Ù": "U", "Ç": "C", "«": "'", "»": "'", "…": "."}

static func _texte(img: Image, x: int, y: int, s: String, ech: int, col: Color) -> void:
	var cx := x
	for ch in s.to_upper():
		var c: String = ACCENTS.get(ch, ch)
		var gl: Array = G5.get(c, G5[" "])
		for ry in 7:
			for rx in 5:
				if (int(gl[ry]) >> (4 - rx)) & 1:
					img.fill_rect(Rect2i(cx + rx * ech, y + ry * ech, ech, ech), col)
		cx += 6 * ech

static func planche(dossier: String, titre: String, cols := 3, lc := 640) -> void:
	var f := FileAccess.open(dossier.path_join("cas.txt"), FileAccess.READ)
	if f == null:
		push_error("planche : cas.txt introuvable dans " + dossier)
		return
	var vues: Array = []
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "" or not l.contains("|"):
			continue
		var im := Image.load_from_file(dossier.path_join(l.get_slice("|", 0) + ".png"))
		if im == null:
			continue
		im.convert(Image.FORMAT_RGBA8)
		vues.append([im, l.get_slice("|", 1)])
	if vues.is_empty():
		return
	var hb := 34
	var im0: Image = vues[0][0]
	var hc := int(float(im0.get_height()) * lc / im0.get_width())
	var ht := 40 if titre != "" else 0
	var rows := ceili(float(vues.size()) / cols)
	var out := Image.create(cols * lc, ht + rows * (hc + hb), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.07, 0.07, 0.09))
	if titre != "":
		_texte(out, 10, 8, titre, 3, Color(0.95, 0.85, 0.55))
	for i in vues.size():
		var im: Image = vues[i][0]
		im.resize(lc, hc, Image.INTERPOLATE_LANCZOS if lc < im.get_width() else Image.INTERPOLATE_NEAREST)
		var x := (i % cols) * lc
		var y := ht + (i / cols) * (hc + hb)
		out.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y + hb))
		var lib: String = vues[i][1]
		var nc := maxi(10, (lc - 12) / 12)      # caractères par ligne (police 5x7 x2)
		_texte(out, x + 6, y + 4, lib.substr(0, nc), 2, Color(0.95, 0.85, 0.55))
		if lib.length() > nc:
			_texte(out, x + 6, y + 19, lib.substr(nc, nc), 2, Color(0.85, 0.85, 0.85))
	out.save_png(dossier.path_join("planche.png"))
	print("PLANCHE : %s (%d vues)" % [dossier.path_join("planche.png"), vues.size()])
