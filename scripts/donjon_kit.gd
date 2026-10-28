class_name DonjonKit
extends RefCounted
## Kit de donjon : modules de salles réutilisables (crypte aujourd'hui, autres donjons demain).
##
## Un MODULE est un dictionnaire de données (voir docs/DONJONS.md, section « Kit ») :
##   id        identifiant de zone (fixe : sauvegardes, tests)           type   "salle" | "couloir" | "escalier"
##   o         Vector2, centre du module dans le repère de la crypte      y      hauteur du sol (0 ou BAS)
##   dim       Vector2 (largeur x profondeur) en repère LOCAL ; couloir : (largeur, longueur)   h  hauteur sous plafond
##   rot       quarts de tour (0..3)       miroir  bool (symétrie gauche/droite)    graine  entier : RNG propre au module
##   theme     "tombeau" | "ossuaire" | "givre" | "glace" | "eau"       role   "combat" | "enigme" | "repos" | "tresor" | "piege" | "recit"
##   usure     0 intact, 1 fissuré, 2 effondré en partie
##   ouv       [[côté local "N"|"S"|"E"|"O", décalage le long du mur, largeur, secret?, id du module relié]]
##   garnitures  [[nom, {args}]] : décors génériques (piliers, panneaux d'os, estrade, couverts…) ; extra : méthode de sous-classe (récit propre à la salle)
##   ennemis / coffres / meca : points d'accroche gameplay (identifiants FIXES fournis par la table)
## Tout est écrit en repère LOCAL (centre de la salle, +x est, +z sud, y absolu) : `CrypteDecor.xf` pose le module (translation, quarts de tour,
## miroir) et tous les accroches sont convertis par `mw()`. Construit dans un fil d'exécution (aucun accès à l'arbre de scène).

const BAS := -6.0
const THEMES := {
	"tombeau": {"mur": "mur0", "theme": {}},
	"ossuaire": {"mur": "mur1", "theme": {}},
	"eau": {"mur": "mur2", "theme": {}},
	"tresor": {"mur": "mur2", "theme": {}},
	"garde": {"mur": "mur2", "theme": {}},
	"givre": {"mur": "mur0", "theme": {"mur0": "mur3", "mur1": "mur3", "mur2": "mur3", "dalle0": "dalle3", "voute": "mur3"}},
	"glace": {"mur": "mur0", "theme": {"mur0": "mur4", "mur1": "mur3", "mur2": "mur4", "dalle0": "dalle4", "voute": "mur3"}},
}
const COTES := {"N": "nord", "S": "sud", "E": "est", "O": "ouest"}

var d: CrypteDecor
var interactions: Array = []     # {id, pos, nom, verbe, genre, ...} (repère de la crypte)
var gardiens: Array = []         # {zone, type, pos, lacet, dort, debout, ident, extra}
var zones: Array = []            # {nom, rect (Rect2 en x,z), y}
var portes: Dictionary = {}      # id -> Node3D mobile
var meca: Array = []             # demandes de pièges / mécanismes : {genre, id, ...} ; posées par tertre (API Piege / Mecanisme)
var modules: Dictionary = {}     # id -> {centre, rect, y, h, ouv: [{cote, pos, largeur, vers}], chemin: [Vector3], cibles: [{id, pos}]}
var problemes: Array = []        # incohérences détectées (liaisons, accroches hors salle…)
var _m: Dictionary = {}          # module en cours
var _lanes: Array = []           # segments [a, b] (repère local) qui doivent rester libres
var _reserves: Array = []        # points locaux (rayon) à ne pas encombrer
var _occ_mur: Array = []         # refonte matière : [côté, position le long du mur, demi-largeur] déjà pris (appliques, sceaux)
# crypte v2, mode auto (scripts/crypte_v2.gd) : état du module en cours entre la 1re passe (CrypteV2.salle) et la 2e (CrypteV2.finir)
var _v2_obst: Dictionary = {}    # côté -> [[abscisse, demi-largeur]] : statues auto (les panneaux et piliers les contournent)
var _v2_lum: Array = []          # lumières de candélabre à allumer si le budget de la salle le permet
var _v2_reglages: Dictionary = {}
var _v2_ban0 := 0                # bannières déjà posées au début du module
var _n_lum0 := 0                 # lumières déjà posées au début du module
var _n_res_accroches := 0        # réserves des accroches (ennemis, coffres, interactions, mécanismes) en tête de _reserves (C5)
var _n_corps0 := 0               # collisions déjà posées au début du module (CrypteV2._boites_sol)
var _v2_boites: Array = []       # boîtes de collision du module en cours (repère local, Rect2 en x,z)
var _p0 := Vector2.ZERO
var _differes: Array = []       # décor tiré AVANT le récit (détritus, congères, glaçons) : émis après lui, là où la place est libre
var v2_stats: Dictionary = {}    # id -> {statues, candelabres, lumieres_statue, piliers, bannieres, flaques} (outils/sonde_crypte_v2.gd)

func _init(decor: CrypteDecor) -> void:
	d = decor

# ------------------------------------------------------------------ décor différé (audit des interpénétrations, 2026-10-23)
## Diffère un décor tiré au hasard avant le récit de la salle : `fn(decalage: Vector3, echelle: float)` est appelé une première fois
## EN SILENCE (d.muet) pour consommer ses tirages aléatoires ICI (la suite du module, gravats et collisions compris, ne bouge pas),
## puis pour de bon après le récit (_emettre_differes), avec les mêmes tirages, déplacé ou réduit si sa place est prise.
## genre : "sol" (détritus : déplacé de proche en proche, sinon omis), "amas" (congère d'angle : réduite sur place, sinon omise),
## "plafond" (glaçon : omis s'il tombe dans un pilier).
func differer(pos: Vector3, r: float, fn: Callable, genre := "sol") -> void:
	var st := d.rng.state
	var st2 := d.rng_deco.state
	d.muet = true
	fn.call(Vector3.ZERO, 1.0)
	d.muet = false
	_differes.append([pos, r, fn, st, st2, genre])

func _emettre_differes(m: Dictionary) -> void:
	if _differes.is_empty():
		return
	var boites := CrypteV2._boites_sol(self, m)
	var liste := _differes
	_differes = []
	for e: Array in liste:
		var p: Vector3 = e[0]
		var r: float = e[1]
		var genre: String = e[5]
		var dp := Vector3.ZERO
		var ech := 1.0
		_p0 = Vector2(p.x, p.z)
		var ok := _place_differee(m, p, r, boites, genre)
		if not ok and genre in ["sol", "brasero", "gravats"]:
			for k in 64:
				var ang := k * 2.39996
				var q := p + Vector3(cos(ang), 0.0, sin(ang)) * (r + 0.3 + 0.1 * (k / 3))
				if _place_differee(m, q, r, boites, genre):
					dp = q - p
					ok = true
					break
		if not ok and genre == "brasero":      # dernier recours : la place libre la plus proche sur une grille de 25 cm (2,5 m autour)
			var best := INF
			for ix in range(-10, 11):
				for iz in range(-10, 11):
					var q := p + Vector3(ix * 0.25, 0.0, iz * 0.25)
					var dq := Vector2(ix, iz).length()
					if dq < best and _place_differee(m, q, r, boites, genre):
						best = dq
						dp = q - p
						ok = true
		elif not ok and genre == "fissure":
			ech = 0.0      # gravats au pied de la fissure omis (place prise) ; la fissure reste
			ok = true
		elif not ok and genre == "amas":
			for f: float in [0.7, 0.5]:
				if _place_differee(m, p, r * f, boites, genre):
					ech = f
					ok = true
					break
		if OS.get_cmdline_user_args().has("--debug-differes") and genre == "brasero":
			print("DIFFERE %s %s p=%s ok=%s dp=%s boites=%d emprises=%d" % [m.get("id", ""), genre, str(p), ok, str(dp), boites.size(), d.emprises.size()])
		if not ok and genre != "brasero":
			continue      # (un brasero porte une lumière : jamais omis, laissé à sa place s'il n'y en a pas d'autre)
		var sv := d.rng.state
		var sv2 := d.rng_deco.state
		d.rng.state = e[3]
		d.rng_deco.state = e[4]
		(e[2] as Callable).call(dp, ech)
		d.rng.state = sv
		d.rng_deco.state = sv2
		if genre != "plafond":
			_reserves.append([Vector2(p.x + dp.x, p.z + dp.z), r * ech])

func _place_differee(m: Dictionary, p: Vector3, r: float, boites: Array, genre: String) -> bool:
	var dim: Vector2 = m["dim"]
	var q := Vector2(p.x, p.z)
	var rr := r * (1.3 if genre == "gravats" else 1.0)      # gravats : les blocs roulent jusqu'à 1,3 rayon
	for b: Rect2 in boites:
		if b.grow(rr + 0.05).has_point(q):
			return false
	if genre == "plafond":
		return true
	if genre != "amas" and genre != "fissure" and (absf(p.x) > dim.x * 0.5 - 0.3 - 0.32 - r or absf(p.z) > dim.y * 0.5 - 0.3 - 0.32 - r):
		return false      # hors du soubassement et des panneaux de maçonnerie (saillie <= 0,32 m)
	if genre == "gravats" and not libre(m, p, r, 0.4):
		return false      # gravats à collision : jamais sur un passage
	for rv: Array in _reserves:
		if (rv[0] as Vector2).distance_to(_p0) < 0.01:
			continue      # sa propre réserve (posée au tirage)
		if q.distance_to(rv[0]) < rr + float(rv[1]) * 0.6:
			return false
	return d.emprise_libre(p, rr, 0.05)

# ------------------------------------------------------------------ repères
func mw(v: Vector3) -> Vector3:
	return d.xf * v

func mdir(v: Vector3) -> Vector3:
	return d.xf.basis * v

## Repère de la crypte -> repère local du module en cours.
func lw(p: Vector3) -> Vector3:
	return d.xf.affine_inverse() * p

func lw_lacet(l: float) -> float:
	var f := d.xf.basis.inverse() * Vector3(sin(l), 0.0, cos(l))
	return atan2(f.x, f.z)

func mlacet(l: float) -> float:
	var f := d.xf.basis * Vector3(sin(l), 0.0, cos(l))
	return atan2(f.x, f.z)

## Décalage aléatoire du module (RNG propre : même graine = même salle).
func alea(a: float, b: float) -> float:
	return d.rng.randf_range(a, b)

# ------------------------------------------------------------------ enregistrement des accroches
func zone(nom: String, p0: Vector3, p1: Vector3, y := 0.0) -> void:
	var a := mw(p0)
	var b := mw(p1)
	var r := Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))
	zones.append({"nom": nom, "rect": r, "y": y})

## Gardien : identifiant FIXE obligatoire (sauvegardes). `extra` : options pour monde.creer_draugr (archer, patrouille en repère LOCAL, boss, reveil_evt…).
func gardien(zone_: String, type: String, pos: Vector3, lacet: float, ident_: String, dort := true, debout := false, extra := {}) -> void:
	var ex := extra.duplicate()
	if ex.has("patrouille"):
		var pts: Array = []
		for p: Vector3 in ex["patrouille"]:
			pts.append(mw(p))
		ex["patrouille"] = pts
	gardiens.append({"zone": zone_, "type": type, "pos": mw(pos), "lacet": mlacet(lacet), "dort": dort, "debout": debout, "ident": ident_, "extra": ex})
	_reserves.append([Vector2(pos.x, pos.z), 1.0])
	if _m.has("id") and modules.has(_m["id"]):
		(modules[_m["id"]]["ennemis"] as Array).append({"id": ident_, "pos": mw(pos)})

func interaction(id: String, pos: Vector3, nom: String, verbe: String, genre: String, extra := {}) -> void:
	var it := {"id": id, "pos": mw(pos), "nom": nom, "verbe": verbe, "genre": genre}
	for k in extra:
		var v: Variant = extra[k]
		it[k] = mw(v) if (k == "coffre" and v is Vector3) else v
	interactions.append(it)
	if _m.has("id") and modules.has(_m["id"]):
		(modules[_m["id"]]["cibles"] as Array).append({"id": id, "pos": mw(pos)})
	_reserves.append([Vector2(pos.x, pos.z), 0.9])

## Coffre : décor + interaction (genre « coffre », identifiant fixe, butin fixe). style : « normal » | « force » (couvercle arraché, pillé).
func coffre(id: String, pos: Vector3, lacet: float, butin: Dictionary, nom := "Coffre ferré", style := "normal") -> void:
	pos = d._ecarter(pos, Vector2(0.47, 0.3), lacet)      # devant le soubassement (l'interaction suit le coffre)
	if style == "force":
		d.coffre_force(pos, lacet)
	else:
		d.coffre(pos, lacet)
	interaction(id, pos + Vector3(0, 0.7, 0), nom, "Ouvrir le coffre", "coffre", {"butin": butin, "coffre": pos})

## Demande de piège / mécanisme (exécutée par tertre, qui possède le parent, le joueur et les quêtes). Les positions sont converties en repère crypte.
func demande_meca(genre: String, id: String, args: Dictionary) -> void:
	var a := {"genre": genre, "id": id}
	for k in args:
		var v: Variant = args[k]
		if k == "dir":
			a[k] = mdir(v)
		elif k == "taille":
			a[k] = (d.xf.basis * (v as Vector3)).abs()
		elif k == "lacet":
			a[k] = mlacet(float(v))
		elif v is Vector3:
			a[k] = mw(v)
		elif v is Array and not (v as Array).is_empty() and (v as Array)[0] is Vector3:
			var l: Array = []
			for p: Vector3 in v:
				l.append(mw(p))
			a[k] = l
		else:
			a[k] = v
	meca.append(a)
	if _m.has("id") and modules.has(_m["id"]):
		for k in ["pos", "pos_dalle"]:
			if a.has(k):
				(modules[_m["id"]]["cibles"] as Array).append({"id": id, "pos": a[k]})
		if a.has("positions"):
			for p: Vector3 in a["positions"]:
				(modules[_m["id"]]["cibles"] as Array).append({"id": id, "pos": p})

# ------------------------------------------------------------------ construction d'un module
func module(m: Dictionary) -> void:
	_m = m
	var id: String = m["id"]
	var type: String = m.get("type", "salle")
	var th: Dictionary = THEMES[m.get("theme", "tombeau")]
	d.rng.seed = int(m.get("graine", 1)) * 100003 + (id.hash() % 100000)
	d.rng_deco.seed = int(m.get("graine", 1)) * 7919 + (id.hash() % 77777) + 1
	var b := Basis(Vector3.UP, int(m.get("rot", 0)) * PI * 0.5)
	if m.get("miroir", false):
		b = b * Basis.from_scale(Vector3(-1, 1, 1))
	var o: Vector2 = m["o"]
	d.xf = Transform3D(b, Vector3(o.x, 0.0, o.y))
	var v2_actif := CrypteV2.actif(m)
	d.theme = (th["theme"] as Dictionary).merged(CrypteV2.THEME, true) if v2_actif else th["theme"]     # crypte v2 : dalles irrégulières
	d.v2 = v2_actif
	d.module_id = id
	d.occupations = []
	d.emprises = []
	d._poussees = []
	_v2_obst = {}
	_v2_lum = []
	_v2_reglages = {}
	_v2_ban0 = d.nb_bannieres
	_n_lum0 = d.toutes.size()
	_n_corps0 = d.corps.get_child_count()
	_v2_boites = []
	_occ_mur = []
	_differes = []
	if CrypteV2.auto(m) and type != "escalier":
		d.saillie_cb = CrypteV2.saillie.bind(self, m)
	if type != "escalier":
		d.murs_cb = _ecart_murs.bind(m)
	for c: Dictionary in m.get("coffres", []):      # emprise des coffres de la table (posés en fin de module) : piliers et panneaux les contournent
		var lc := lw_lacet(c.get("lacet", 0.0))
		d.emprise("coffre", d._ecarter(lw(c["pos"]), Vector2(0.47, 0.3), lc), Vector2(0.47, 0.3), lc, 0.64)
	d._poussees = []      # bannières, boucliers, gravures : devant les panneaux de maçonnerie
	var y := float(m.get("y", 0.0))
	d.niveau_a = 1.0 + y / 20.0
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	_lanes = []
	_reserves = []
	# les accroches de la table réservent leur place : aucun décor aléatoire (couverts, gravats) ne s'y pose
	for e: Dictionary in m.get("ennemis", []):
		var q := lw(e["pos"])
		_reserves.append([Vector2(q.x, q.z), 1.1])
	for c: Dictionary in m.get("coffres", []):
		var q := lw(c["pos"])
		_reserves.append([Vector2(q.x, q.z), 1.1])
	for it: Dictionary in m.get("interactions", []):
		var q := lw(it["pos"])
		_reserves.append([Vector2(q.x, q.z), 0.9])
	for dm: Dictionary in m.get("meca", []):
		var pts: Array = dm.get("positions", [])
		for k in ["pos", "pos_dalle"]:
			if dm.has(k):
				pts.append(dm[k])
		for q0: Vector3 in pts:
			var q := lw(q0)
			_reserves.append([Vector2(q.x, q.z), 1.4])
	_n_res_accroches = _reserves.size()      # C5 : les premières réserves sont celles des accroches (CrypteV2.semis les respecte en entier)
	modules[id] = {"centre": mw(Vector3(0, y, 0)), "y": y, "h": h, "ouv": [], "cibles": [], "ennemis": [], "dim": dim, "rot": int(m.get("rot", 0)), "role": m.get("role", ""), "theme": m.get("theme", "tombeau")}
	if type == "escalier":
		_escalier(m)
	else:
		var ouv_l: Array = []
		for ou: Array in m.get("ouv", []):
			var c: String = ou[0]
			var e: Array = [COTES[c], float(ou[1]), float(ou[2])]
			if ou.size() > 3 and ou[3]:
				e.append(true)
			ouv_l.append(e)
			var pos_l := _centre_porte(c, float(ou[1]), dim, y)
			(modules[id]["ouv"] as Array).append({"cote": c, "pos": mw(pos_l), "largeur": float(ou[2]), "vers": ou[4] if ou.size() > 4 else "", "secret": ou.size() > 3 and ou[3], "local": pos_l})
			_lanes.append([Vector2(pos_l.x, pos_l.z), Vector2.ZERO])
		d.salle(-dim.x * 0.5, dim.x * 0.5, -dim.y * 0.5, dim.y * 0.5, h, ouv_l, y, th["mur"])
		zone(id, Vector3(-dim.x * 0.5, 0, -dim.y * 0.5), Vector3(dim.x * 0.5, 0, dim.y * 0.5), y)
		if type == "couloir":
			if CrypteV2.actif(m):
				CrypteV2.couloir(self, m)
			else:
				_couloir(m)
		else:
			_ambiance(m)
		for g: Array in m.get("garnitures", []):
			call("_g_" + String(g[0]), m, _args_locaux(g[1] if g.size() > 1 else {}))
		if int(m.get("usure", 0)) > 0:
			_usure(m)
		if m.has("extra"):
			call(m["extra"], m)
		_emettre_differes(m)
		if v2_actif:
			CrypteV2.finir(self, m)      # mode auto : piliers, panneaux, bannières, lumières de statue (après le récit de la salle)
	# accroches de la table : écrites en repère de la CRYPTE (monde), converties ici en repère local (donc suivent rotation et miroir)
	for e: Dictionary in m.get("ennemis", []):
		_ennemi(m, e)
	for c: Dictionary in m.get("coffres", []):
		coffre(c["id"], lw(c["pos"]), lw_lacet(c.get("lacet", 0.0)), c["butin"], c.get("nom", "Coffre ferré"), c.get("style", "normal"))
	for it: Dictionary in m.get("interactions", []):
		var ex := it.duplicate()
		for k in ["id", "pos", "nom", "verbe", "genre"]:
			ex.erase(k)
		interaction(it["id"], lw(it["pos"]), it["nom"], it["verbe"], it["genre"], ex)
	for dm: Dictionary in m.get("meca", []):
		var args := dm.duplicate()
		args.erase("genre")
		args.erase("id")
		for k in args.keys():
			var v: Variant = args[k]
			if k == "dir":
				args[k] = d.xf.basis.inverse() * (v as Vector3)
			elif k == "taille":
				args[k] = (d.xf.basis.inverse() * (v as Vector3)).abs()
			elif k == "lacet":
				args[k] = lw_lacet(float(v))
			elif v is Vector3:
				args[k] = lw(v)
			elif v is Array and not (v as Array).is_empty() and (v as Array)[0] is Vector3:
				var l: Array = []
				for q: Vector3 in v:
					l.append(lw(q))
				args[k] = l
		demande_meca(dm["genre"], dm["id"], args)
	d.xf = Transform3D.IDENTITY
	d.theme = {}
	d.niveau_a = 1.0
	d.v2 = false
	d.module_id = ""
	d.saillie_cb = Callable()
	d.murs_cb = Callable()
	d.occupations = []
	d.emprises = []
	_m = {}

## Arguments de garniture : les positions (clés « pos » et « pts », écrites en repère de la crypte) passent en repère local ; le reste (tailles, nombres) est inchangé.
func _args_locaux(a: Dictionary) -> Dictionary:
	var r := a.duplicate()
	if a.has("pos") and a["pos"] is Vector3:
		r["pos"] = lw(a["pos"])
	if a.has("pts"):
		var l: Array = []
		for q: Vector3 in a["pts"]:
			l.append(lw(q))
		r["pts"] = l
	return r

func _ennemi(m: Dictionary, e: Dictionary) -> void:
	var extra: Dictionary = e.get("extra", {}).duplicate()
	if extra.has("patrouille"):
		var pts: Array = []
		for p: Vector3 in extra["patrouille"]:
			pts.append(lw(p))
		extra["patrouille"] = pts
	gardien(m["id"], e["type"], lw(e["pos"]), lw_lacet(e.get("lacet", 0.0)), e["id"], e.get("dort", true), e.get("debout", false), extra)

func _centre_porte(c: String, off: float, dim: Vector2, y: float) -> Vector3:
	match c:
		"N": return Vector3(off, y, -dim.y * 0.5)
		"S": return Vector3(off, y, dim.y * 0.5)
		"E": return Vector3(dim.x * 0.5, y, off)
		_: return Vector3(-dim.x * 0.5, y, off)

# ------------------------------------------------------------------ murs : intervalles libres, positions
## Intervalles libres le long d'un mur (hors ouvertures, avec marge), en coordonnée locale le long du mur.
func murs_libres(m: Dictionary, c: String, marge := 0.9) -> Array:
	var dim: Vector2 = m["dim"]
	var horiz := c == "N" or c == "S"
	var a0 := (-dim.x if horiz else -dim.y) * 0.5 + 0.9
	var a1 := (dim.x if horiz else dim.y) * 0.5 - 0.9
	var libres := [[a0, a1]]
	for ou: Array in m.get("ouv", []):
		if ou[0] != c:
			continue
		var ca: float = float(ou[1]) - float(ou[2]) * 0.5 - marge
		var cb: float = float(ou[1]) + float(ou[2]) * 0.5 + marge
		var nv: Array = []
		for s: Array in libres:
			if cb <= s[0] or ca >= s[1]:
				nv.append(s)
			else:
				if ca > s[0]:
					nv.append([s[0], ca])
				if cb < s[1]:
					nv.append([cb, s[1]])
		libres = nv
	return libres

## Plan intérieur d'un mur : {plan, vers (normale vers la pièce), horiz}
func plan_mur(m: Dictionary, c: String) -> Dictionary:
	var dim: Vector2 = m["dim"]
	match c:
		"N": return {"plan": -dim.y * 0.5 + 0.3, "vers": Vector3(0, 0, 1), "horiz": true}
		"S": return {"plan": dim.y * 0.5 - 0.3, "vers": Vector3(0, 0, -1), "horiz": true}
		"O": return {"plan": -dim.x * 0.5 + 0.3, "vers": Vector3(1, 0, 0), "horiz": false}
		_: return {"plan": dim.x * 0.5 - 0.3, "vers": Vector3(-1, 0, 0), "horiz": false}

func pt_mur(m: Dictionary, c: String, a: float, y := 0.0, retrait := 0.0) -> Vector3:
	var pm := plan_mur(m, c)
	var v: Vector3 = pm["vers"]
	var p: float = pm["plan"]
	var base := Vector3(a, y, p) if pm["horiz"] else Vector3(p, y, a)
	return base + v * retrait

## Décalage qui écarte un meuble (boîte demi-tailles `dm`, lacet) des murs : dos à 0,22 m au moins du plan du mur (soubassement
## de 0,10 à 0,20 m), sauf devant une ouverture. Audit des interpénétrations (2026-10-23).
const ECART_MUR := 0.22
func _ecart_murs(p: Vector3, dm: Vector2, lacet: float, m: Dictionary) -> Vector3:
	var bs := Basis(Vector3.UP, lacet)
	var ax: Vector3 = bs * Vector3.RIGHT
	var az: Vector3 = bs * Vector3.BACK
	var dec := Vector3.ZERO
	for c: String in ["N", "S", "O", "E"]:
		var pm := plan_mur(m, c)
		var v: Vector3 = pm["vers"]
		var dist: float = ((p.z if pm["horiz"] else p.x) - float(pm["plan"])) * (v.z if pm["horiz"] else v.x)
		var hn := absf(v.dot(ax)) * dm.x + absf(v.dot(az)) * dm.y
		var ecart := dist - hn
		if ecart >= ECART_MUR or ecart < -0.8:
			continue
		var a: float = p.x if pm["horiz"] else p.z
		var hl := absf((Vector3(1, 0, 0) if pm["horiz"] else Vector3(0, 0, 1)).dot(ax)) * dm.x + absf((Vector3(1, 0, 0) if pm["horiz"] else Vector3(0, 0, 1)).dot(az)) * dm.y
		var devant_ouv := false
		for ou: Array in m.get("ouv", []):
			if ou[0] == c and absf(a - float(ou[1])) + hl < float(ou[2]) * 0.5:
				devant_ouv = true
		if not devant_ouv:
			dec += v * (ECART_MUR - ecart)
	return dec

## Libre ? (hors couloirs de passage, hors points réservés, dans la salle avec marge)
func libre(m: Dictionary, p: Vector3, r := 0.6, marge := 0.6) -> bool:
	var dim: Vector2 = m["dim"]
	if absf(p.x) > dim.x * 0.5 - 0.3 - r - marge or absf(p.z) > dim.y * 0.5 - 0.3 - r - marge:
		return false
	var q := Vector2(p.x, p.z)
	for l: Array in _lanes:
		var a: Vector2 = l[0]
		var bb: Vector2 = l[1]
		var seg := bb - a
		var t := clampf((q - a).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		if q.distance_to(a + seg * t) < r + 1.0:
			return false
	for rv: Array in _reserves:
		if q.distance_to(rv[0]) < r + float(rv[1]):
			return false
	return true

func _jitter_derniere_lumiere(froid := false) -> void:
	if d.muet:      # décor différé (tirage à blanc) : mêmes tirages, aucune lumière touchée
		alea(0.9, 1.12)
		if not froid:
			alea(0.0, 0.45)
		return
	if d.toutes.is_empty():
		return
	var l: OmniLight3D = d.toutes[d.toutes.size() - 1]
	var k := alea(0.9, 1.12)
	if not froid:
		alea(0.0, 0.45)      # tirage conservé (même suite aléatoire) ; couleur : préréglage commun (DIRECTION_ARTISTIQUE §6), plus de teinte au hasard
	l.light_energy *= k
	for e: Array in d.lumieres:
		if e[0] == l:
			e[1] = float(e[1]) * k

# ------------------------------------------------------------------ ambiance générique (4 à 6 lumières, toiles, détritus)
func _ambiance(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var th: String = m.get("theme", "tombeau")
	var froid := th == "glace" or th == "givre"
	# lanes : de chaque porte au centre
	for l: Array in _lanes:
		l[1] = Vector2.ZERO
	var nb_lum0 := d.toutes.size()
	_occ_mur = []
	var lum: Dictionary = m.get("lum", {})
	var nb_br: int = lum.get("braseros", 2)
	var nb_ap: int = lum.get("appliques", 2)
	# braseros : aux coins, côté choisi par la graine
	if nb_br > 0 and not m.get("sans_braseros", false):
		var coins := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]
		for i in range(coins.size() - 1, 0, -1):
			var j := d.rng.randi_range(0, i)
			var tmp: Vector3 = coins[i]
			coins[i] = coins[j]
			coins[j] = tmp
		var n := 0
		for cn: Vector3 in coins:
			var p := Vector3(cn.x * (dim.x * 0.5 - 1.3), y, cn.z * (dim.y * 0.5 - 1.3))
			if n < nb_br and libre(m, p, 0.5, 0.0):
				# différé : posé après le récit, déplacé si une statue, une urne ou un trésor du récit occupe l'angle
				differer(p, 0.5, func(dp: Vector3, _e: float) -> void:
					d.brasero(p + dp)
					_jitter_derniere_lumiere(false), "brasero")
				_reserves.append([Vector2(p.x, p.z), 0.7])
				n += 1
	# appliques : sur les plus longs intervalles libres des murs
	var cands: Array = []
	for c in ["N", "S", "E", "O"]:
		for s: Array in murs_libres(m, c, 0.5):
			if s[1] - s[0] > 1.2:
				cands.append([s[1] - s[0], c, (s[0] + s[1]) * 0.5 + alea(-0.4, 0.4)])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var k := 0
	for cd: Array in cands:
		if k >= nb_ap:
			break
		if cd[1] in m.get("sans_appliques", []):
			continue      # mur réservé au récit (frise, bannière)
		var pm := plan_mur(m, cd[1])
		var base: Vector3 = pt_mur(m, cd[1], cd[2], 0.0)
		var ret_v2: Vector3 = (pm["vers"] as Vector3) * 0.3 if CrypteV2.actif(m) else Vector3.ZERO      # crypte v2 : sur les blocs du panneau de maçonnerie (saillie <= 0,3 m)
		d.applique(Vector3(base.x, y, base.z) + ret_v2, pm["vers"], y + minf(h - 1.2, 2.4), 5.0 + alea(-0.3, 0.8), 1.6 + alea(-0.15, 0.25), true)
		_jitter_derniere_lumiere(false)
		_occ_mur.append([cd[1], float(cd[2]), 0.45])
		k += 1
	# toiles dans les coins (graine) et détritus
	var cx := dim.x * 0.5 - 0.3
	var cz := dim.y * 0.5 - 0.3
	for cn: Array in [[-cx, -cz, 1, 1], [cx, -cz, -1, 1], [-cx, cz, 1, -1], [cx, cz, -1, -1]]:
		if d.rng.randf() < 0.7:
			d.toile(Vector3(cn[0], y + h, cn[1]), Vector3(cn[2], 0, 0), Vector3(0, 0, cn[3]), alea(0.9, 1.4))
	var aire := dim.x * dim.y
	var nbm := clampi(int(aire / 60.0), 2, 7)
	for i in nbm:
		var p := Vector3(alea(-dim.x * 0.5 + 1.0, dim.x * 0.5 - 1.0), y, alea(-dim.y * 0.5 + 1.0, dim.y * 0.5 - 1.0))
		var choix := d.rng.randi_range(0, 4)
		# audit des interpénétrations : posés au hasard AVANT le récit, ils tombaient dans les meubles, les statues, les coffres → différés
		differer(p, [0.45, 0.55, 0.3, 0.12, 0.55][choix], _detritus.bind(choix, p))
	if froid:
		_deco_froid(m)
	_ambiance_matiere(m, nb_lum0)

func _detritus(dp: Vector3, _e: float, choix: int, p: Vector3) -> void:
	match choix:
		0: d.os_tas(p + dp, 3, 0.3)
		1: d.arme(p + dp, d.rng.randf() * TAU)
		2: d.urne(p + dp, alea(0.8, 1.1))
		3: d.crane(p + dp, d.rng.randf() * TAU)
		_: d.os_tas(p + dp, 4, 0.4)

## Refonte matière (références grottes_cryptes_2/3) : lustre de fer à bougies, statues encapuchonnées, sceau bleu, brume au sol.
## RNG séparé (rng_deco) ; budget : 6 lumières au plus par salle (le lustre et le sceau n'ont de lumière que s'il en reste).
func _ambiance_matiere(m: Dictionary, _nb_lum0: int) -> void:
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var aire := dim.x * dim.y
	var role: String = m.get("role", "")
	var r := d.rng_deco
	if CrypteV2.actif(m):
		CrypteV2.salle(self, m)       # piliers, arches, panneaux, lustres de fer, sol : voir scripts/crypte_v2.gd
		d.brume(Vector3(0, y, 0), Vector2(dim.x * 0.3, dim.y * 0.3), clampi(int(aire / 14.0), 3, 10))
		return
	if h >= 3.6 and aire >= 36.0 and role != "arene":
		var p := Vector3(r.randf_range(-0.6, 0.6), y + h, r.randf_range(-0.6, 0.6))
		d.lustre(p, clampf(h - 2.9, 0.7, 4.0), 0.55 if aire < 90.0 else 0.75, false)   # budget : 7 lumières par salle (test_crypte)
		if aire >= 110.0:
			for sx: float in [-1.0, 1.0]:
				var q := Vector3(sx * dim.x * 0.26, y + h, r.randf_range(-dim.y * 0.2, dim.y * 0.2))
				d.lustre(q, clampf(h - 3.2, 0.6, 4.0), 0.5, false)
	# arène : pôle froid franc (audit : « tout bleu nuit ») — grands sceaux sur les murs latéraux et au fond, en contrepoint
	# des braseros chauds ; un seul éclairé (budget : 8 lumières par maillage)
	if m.get("id", "") == "arene":
		for c: String in ["E", "O", "N"]:
			var lib := murs_libres(m, c, 0.6)
			if lib.is_empty():
				continue
			var best: Array = lib[0]
			for sgm: Array in lib:
				if sgm[1] - sgm[0] > best[1] - best[0]:
					best = sgm
			if best[1] - best[0] < 1.4:
				continue
			var pm := plan_mur(m, c)
			var am: float = (best[0] + best[1]) * 0.5
			var p := pt_mur(m, c, am, y + minf(h - 1.2, 2.4), 0.0)
			d.sceau(p, pm["vers"], 0.9, c == "N", 4.0)
			_occ_mur.append([c, am, 0.7])
	# 2e passe : murs en TRAVÉES (pilastres, étagères funéraires, arcatures, statues, sceau), nervures de voûte, densité
	_travees(m)
	_densite_sol(m)
	_fers_pendants(m)
	# brume au ras du sol
	d.brume(Vector3(0, y, 0), Vector2(dim.x * 0.36, dim.y * 0.36), clampi(int(aire / 9.0), 4, 16))

## 2e passe (références grottes_cryptes_2/3 : presque aucun mur plat) : chaque mur d'une salle est rythmé par des PILASTRES
## tous les 2,2 à 2,9 m (fût à panneau d'entrelacs, base et chapiteau givrés, glaçons) ; entre eux, des travées : étagères
## funéraires (urnes, crânes, ossements, toiles), arcatures-niches, statue encapuchonnée en niche, sceau. Les murs longs
## partagent la même trame : une nervure de voûte (arc brisé ou doubleau plat) relie chaque paire de pilastres, une lierne
## court au faîte. Saillies ≤ 0,3 m, sans collision (le plan marchable et les collisions ne bougent pas). RNG : rng_deco.
func _travees(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	if h < 2.8:
		return
	var r := d.rng_deco
	var aire := dim.x * dim.y
	var long_x := dim.x >= dim.y          # murs longs = N et S (le long de x)
	var w_trav := dim.y - 0.6 if long_x else dim.x - 0.6       # portée des nervures
	# nervures : arc brisé si la salle est assez haute, sinon doubleau plat sous la voûte
	var f := clampf(w_trav * 0.28, 0.6, 2.4)
	var hp_long := h - f - 0.4
	var avec_arcs := hp_long >= 2.4
	if not avec_arcs:
		f = 0.0
		hp_long = h - 0.6
	var statues := 0
	var quota_st := 3 if aire >= 150.0 else (2 if aire >= 90.0 else (1 if aire >= 40.0 else 0))
	var sceau_fait: bool = m.get("id", "") == "arene" or r.randf() < 0.5
	for c: String in ["N", "S", "O", "E"]:
		var horiz := c == "N" or c == "S"
		var Lw := dim.x if horiz else dim.y
		var est_long := horiz == long_x
		var hp := hp_long if est_long else h - 0.6
		var a0 := -Lw * 0.5 + 0.3
		var a1 := Lw * 0.5 - 0.3
		var n := maxi(1, roundi((a1 - a0) / 2.6))
		var grille: Array = []
		for k in n + 1:
			grille.append(lerpf(a0, a1, float(k) / n))
		var lib := murs_libres(m, c, 0.35)
		var dans := func(a: float, b: float) -> bool:
			for sg: Array in lib:
				if a >= float(sg[0]) - 0.95 and b <= float(sg[1]) + 0.95:
					return true
			return false
		var occupe := func(a: float, b: float) -> bool:
			for o: Array in _occ_mur:
				if o[0] == c and float(o[1]) + float(o[2]) > a and float(o[1]) - float(o[2]) < b:
					return true
			return false
		# pilastres (intérieurs à la trame)
		for k in range(1, n):
			var a: float = grille[k]
			if dans.call(a - 0.3, a + 0.3) and not occupe.call(a - 0.3, a + 0.3):
				_pilastre(m, c, a, y, hp)
		# nervures (une fois par paire, depuis le premier mur long)
		if est_long and c == ("N" if long_x else "O"):
			for k in range(1, n):
				var a: float = grille[k]
				if avec_arcs:
					d.arc("mur0", "z" if long_x else "x", a if long_x else 0.0, 0.0 if long_x else a, w_trav, y + hp, f, 0.3, 0.42, 10)
				else:
					_poutre_tronc(Vector3(a, y + h - 0.14, -w_trav * 0.5) if long_x else Vector3(-w_trav * 0.5, y + h - 0.14, a), Vector3(0, 0, 1) if long_x else Vector3(1, 0, 0), w_trav, Vector2(0.36, 0.28))
			# lierne au faîte (en tronçons : un maillage par cellule de 8 m reste compact pour le budget de lumières)
			var ll := dim.x - 0.6 if long_x else dim.y - 0.6
			_poutre_tronc(Vector3(-ll * 0.5, y + h - 0.1, 0) if long_x else Vector3(0, y + h - 0.1, -ll * 0.5), Vector3(1, 0, 0) if long_x else Vector3(0, 0, 1), ll, Vector2(0.28, 0.2))
		# travées
		for k in n:
			var b0: float = grille[k] + (0.25 if k > 0 else 0.0)
			var b1: float = grille[k + 1] - (0.25 if k < n - 1 else 0.0)
			var wb := b1 - b0
			if wb < 1.0 or not dans.call(b0, b1):
				continue
			var am := (b0 + b1) * 0.5
			if occupe.call(b0, b1):
				continue
			var t := r.randf()
			var pm := plan_mur(m, c)
			var v: Vector3 = pm["vers"]
			if not sceau_fait and wb >= 1.2:
				sceau_fait = true
				d.sceau(pt_mur(m, c, am, y + minf(h - 1.0, 2.1), 0.0), v, 0.6, false)
				_arcature_vide(m, c, am, y, wb, minf(h - 0.9, 3.0))
			elif statues < quota_st and wb >= 1.5 and t < 0.45 and libre(m, pt_mur(m, c, am, y, 0.45), 0.4, -0.9):
				statues += 1
				_arcature_vide(m, c, am, y, wb, minf(h - 0.6, 3.4))
				var p := pt_mur(m, c, am, y, 0.42)
				d.statue(p, atan2(v.x, v.z), 1.05, "capuche", false, "mur1")
				_reserves.append([Vector2(p.x, p.z), 0.8])
			elif t < 0.55 and h >= 2.9:
				_etageres(m, c, am, y, wb, h)
			elif t < 0.85 and wb >= 1.3:
				niche_os(m, c, am, y, minf(wb - 0.45, 1.7))
			else:
				_arcature_vide(m, c, am, y, wb, minf(h - 0.9, 2.8))

## Poutre de pierre découpée en tronçons de 3 m au plus (départ, direction, longueur, section largeur x hauteur).
func _poutre_tronc(dep: Vector3, dir: Vector3, lon: float, sec: Vector2) -> void:
	var n := maxi(1, ceili(lon / 3.0))
	var lt := lon / n
	for i in n:
		var c := dep + dir * (lt * (i + 0.5))
		d.boite("mur0", c, Vector3(lt - 0.01, sec.y, sec.x) if absf(dir.x) > 0.5 else Vector3(sec.x, sec.y, lt - 0.01))

## Pilastre engagé : base moulurée, fût (0,5 x 0,2) à panneau d'entrelacs, chapiteau à ressauts ; givre et glaçons.
func _pilastre(m: Dictionary, c: String, a: float, y: float, hp: float) -> void:
	var pm := plan_mur(m, c)
	var v: Vector3 = pm["vers"]
	var horiz: bool = pm["horiz"]
	var D := func(l: float, hh: float, ep: float) -> Vector3:
		return Vector3(l, hh, ep) if horiz else Vector3(ep, hh, l)
	var P := func(u: float, yy: float, ret: float) -> Vector3:
		return pt_mur(m, c, a + u, yy, ret)
	d.boite("mur1", P.call(0.0, y + hp * 0.5, 0.1), D.call(0.5, hp, 0.2), 0.0, true)
	d.boite("mur0", P.call(0.0, y + 0.22, 0.14), D.call(0.68, 0.44, 0.28), 0.0, true)
	d.boite("mur1", P.call(0.0, y + 0.5, 0.12), D.call(0.6, 0.12, 0.24), 0.0, true)
	d.givre_dessus(P.call(0.0, y + 0.44, 0.24), Vector2(0.6, 0.06) if horiz else Vector2(0.06, 0.6), 0.02)
	d.boite("mur1", P.call(0.0, y + hp - 0.3, 0.13), D.call(0.6, 0.14, 0.26), 0.0, false)
	d.boite("mur0", P.call(0.0, y + hp - 0.11, 0.16), D.call(0.72, 0.22, 0.32), 0.0, false)
	d.givre_dessus(P.call(0.0, y + hp, 0.16), Vector2(0.72, 0.3) if horiz else Vector2(0.3, 0.72), 0.04)
	d.glacons_arete(P.call(-0.32, y + hp - 0.22, 0.31), P.call(0.32, y + hp - 0.22, 0.31), 1.6, 0.45)
	# panneau d'entrelacs sur la face avant du fût
	var dr := Vector3(1, 0, 0) if horiz else Vector3(0, 0, 1)
	var hpan := minf(1.5, hp - 1.4)
	if hpan > 0.5:
		var yc := y + 0.75 + hpan * 0.5
		var cc: Vector3 = P.call(0.0, yc, 0.205)
		var q0 := cc - dr * 0.18 - Vector3(0, hpan * 0.5, 0)
		var q1 := cc + dr * 0.18 - Vector3(0, hpan * 0.5, 0)
		var q2 := cc + dr * 0.18 + Vector3(0, hpan * 0.5, 0)
		var q3 := cc - dr * 0.18 + Vector3(0, hpan * 0.5, 0)
		d.quad("entrelacs", q0, q1, q2, q3, v, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])

## Fond de travée assombri (profondeur simulée) sous un arc brisé en saillie, appui de pierre.
func _arcature_vide(m: Dictionary, c: String, am: float, y: float, wb: float, haut: float) -> void:
	var pm := plan_mur(m, c)
	var v: Vector3 = pm["vers"]
	var horiz: bool = pm["horiz"]
	var w := wb - 0.2
	var f := clampf(w * 0.5, 0.4, 1.1)
	var ys := y + maxf(haut - f, 1.6)
	var sombre := [Color(0.42, 0.4, 0.4), Color(0.42, 0.4, 0.4), Color(0.3, 0.3, 0.32), Color(0.3, 0.3, 0.32)]
	var P := func(u: float, yy: float, ret: float) -> Vector3:
		return pt_mur(m, c, am + u, yy, ret)
	d.quad("mur2", P.call(-w * 0.5, y + 0.45, 0.012), P.call(w * 0.5, y + 0.45, 0.012), P.call(w * 0.5, ys, 0.012), P.call(-w * 0.5, ys, 0.012), v, [], [], sombre)
	var ca: Vector3 = P.call(0.0, 0.0, 0.1)
	d.arc("mur0", "x" if horiz else "z", ca.x, ca.z, w, ys, f, 0.2, 0.2, 7)
	d.boite("mur1", P.call(0.0, y + 0.4, 0.12), Vector3(w + 0.1, 0.1, 0.24) if horiz else Vector3(0.24, 0.1, w + 0.1))

## Étagères funéraires (2 ou 3 tablettes) : urnes, crânes, ossements, givre, glaçons, toiles ; fond assombri.
func _etageres(m: Dictionary, c: String, am: float, y: float, wb: float, h: float) -> void:
	var pm := plan_mur(m, c)
	var v: Vector3 = pm["vers"]
	var horiz: bool = pm["horiz"]
	var r := d.rng_deco
	var w := wb - 0.1
	var P := func(u: float, yy: float, ret: float) -> Vector3:
		return pt_mur(m, c, am + u, yy, ret)
	var D := func(l: float, hh: float, ep: float) -> Vector3:
		return Vector3(l, hh, ep) if horiz else Vector3(ep, hh, l)
	var haut := minf(h - 1.0, 2.5)
	var sombre := [Color(0.38, 0.36, 0.36), Color(0.38, 0.36, 0.36), Color(0.26, 0.26, 0.28), Color(0.26, 0.26, 0.28)]
	d.quad("mur2", P.call(-w * 0.5, y + 0.45, 0.012), P.call(w * 0.5, y + 0.45, 0.012), P.call(w * 0.5, y + haut, 0.012), P.call(-w * 0.5, y + haut, 0.012), v, [], [], sombre)
	d.boite("mur0", P.call(0.0, y + haut + 0.1, 0.13), D.call(w + 0.1, 0.2, 0.26))       # linteau de la travée
	var lac := atan2(v.x, v.z)
	var dr := Vector3(1, 0, 0) if horiz else Vector3(0, 0, 1)
	var yy := 0.5
	var etages := 0
	while yy < haut - 0.45 and etages < 2:
		etages += 1
		d.boite("mur1", P.call(0.0, y + yy, 0.14), D.call(w, 0.07, 0.28))
		if r.randf() < 0.45:
			d.givre_dessus(P.call(0.0, y + yy + 0.035, 0.15), Vector2(w, 0.26) if horiz else Vector2(0.26, w), 0.02)
		if r.randf() < 0.4:
			d.glacons_arete(P.call(-w * 0.5 + 0.1, y + yy - 0.04, 0.27), P.call(w * 0.5 - 0.1, y + yy - 0.04, 0.27), 1.3, 0.28)
		var u := -w * 0.5 + 0.18
		while u < w * 0.5 - 0.15:
			var q: Vector3 = P.call(u, y + yy + 0.035, 0.13)
			var t := r.randf()
			if t < 0.38:
				d.urne(q, r.randf_range(0.42, 0.62), 6)
				u += 0.42
			elif t < 0.62:
				d.crane(q, lac + r.randf_range(-0.5, 0.5))
				u += 0.32
			elif t < 0.85:
				for k in 3:
					d.boite("os", q + dr * r.randf_range(-0.08, 0.08) + Vector3(0, 0.02 + 0.03 * k, 0), Vector3(0.3, 0.035, 0.035) if horiz else Vector3(0.035, 0.035, 0.3), r.randf_range(-0.25, 0.25))
				u += 0.44
			else:
				u += 0.3
		yy += 0.8 + r.randf_range(-0.04, 0.06)
	if r.randf() < 0.7:
		var s := 1.0 if r.randf() < 0.5 else -1.0
		d.toile(P.call(s * w * 0.5, y + haut, 0.02), dr * -s, v, r.randf_range(0.45, 0.7))

## Fers qui pendent (4e passe) : un ou deux lustres éteints sur chaînes et des chaînes isolées le long des murs, toujours au-dessus
## de 2,3 m (aucune gêne, aucune collision). RNG : rng_deco.
func _fers_pendants(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var r := d.rng_deco
	if dim.x * dim.y < 60.0 or h < 3.6:
		return
	var nl := 2 if dim.x * dim.y >= 150.0 else 1
	for i in nl:
		var px := (dim.x * 0.25) * (1.0 if i == 0 else -1.0) * r.randf_range(0.6, 1.0)
		var pz := r.randf_range(-dim.y * 0.25, dim.y * 0.25)
		d.lustre(Vector3(px, y + h, pz), minf(h - 2.5, 1.4), 0.5, false)
	var nc := clampi(int((dim.x + dim.y) / 4.0), 3, 8)
	for i in nc:
		var c: String = ["N", "S", "E", "O"][r.randi_range(0, 3)]
		var pm := plan_mur(m, c)
		var Lw := dim.x if pm["horiz"] else dim.y
		var p := pt_mur(m, c, r.randf_range(-Lw * 0.5 + 0.8, Lw * 0.5 - 0.8), y + h, r.randf_range(0.4, 1.1))
		var lo := r.randf_range(0.5, minf(h - 2.4, 1.6))
		d.chaine(p, p - Vector3(0, lo, 0))
		if r.randf() < 0.4:      # crochet ou anneau au bout
			d.boite("fer", p - Vector3(0, lo + 0.06, 0), Vector3(0.12, 0.04, 0.12))

## Densité au sol : givre dans les angles et au pied des murs, urnes et ossements contre les murs (hors passages).
func _densite_sol(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var y := float(m.get("y", 0.0))
	var r := d.rng_deco
	var gele: bool = m.get("theme", "tombeau") in ["givre", "glace"]
	var cx := dim.x * 0.5 - 0.3
	var cz := dim.y * 0.5 - 0.3
	for cn: Array in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		for k in (5 if gele else 3):
			var p := Vector3(cn[0] * (cx - r.randf_range(0.1, 0.9)), y + 0.005, cn[1] * (cz - r.randf_range(0.1, 0.9)))
			d.givre_dessus(p, Vector2(r.randf_range(0.3, 0.8), r.randf_range(0.3, 0.8)), 0.012, r.randf() * TAU)
	var n := clampi(int((dim.x + dim.y) / 3.0), 3, 12)
	for i in n:
		var c: String = ["N", "S", "E", "O"][r.randi_range(0, 3)]
		var pm := plan_mur(m, c)
		var Lw := dim.x if pm["horiz"] else dim.y
		var p := pt_mur(m, c, r.randf_range(-Lw * 0.5 + 0.8, Lw * 0.5 - 0.8), y, r.randf_range(0.35, 0.6))
		if not libre(m, p, 0.25, -0.75):
			continue
		var t := r.randf()
		if t < 0.4:
			d.urne(p, r.randf_range(0.7, 1.05))
			if r.randf() < 0.5:
				d.urne(p + Vector3(r.randf_range(-0.4, 0.4), 0, r.randf_range(-0.4, 0.4)) * Vector3(1, 0, 1), r.randf_range(0.5, 0.8))
		elif t < 0.75:
			d.j0("crane_os")
			d.crane(p, r.randf() * TAU)
			for k in 3:
				d.boite("os", p + Vector3(r.randf_range(-0.25, 0.25), 0.02, r.randf_range(-0.25, 0.25)), Vector3(0.3, 0.04, 0.04), r.randf() * TAU)
			d.j1()
		else:
			d.givre_dessus(p, Vector2(0.9, 0.5), 0.015, r.randf() * TAU)

## Niche funéraire dans un mur (références : squelettes, crânes, urnes) : jambages, arc brisé, fond noir, tablette givrée.
## `a` = position le long du mur (repère local), y = sol. Pas de collision (saillie ≤ 0,3 m, contre le mur).
func niche_os(m: Dictionary, c: String, a: float, y: float, lw_ := 0.95) -> void:
	d.j0("niche_os")
	var pm := plan_mur(m, c)
	var v: Vector3 = pm["vers"]
	var horiz: bool = pm["horiz"]
	var r := d.rng_deco
	var P := func(u: float, yy: float, ret: float) -> Vector3:
		return pt_mur(m, c, a + u, yy, ret)
	var y0 := y + 0.62
	var ys := y + 1.55
	var f := clampf(lw_ * 0.58, 0.55, 1.0)
	# fond noir (profondeur simulée), puis jambages et arc brisé en saillie
	var b0: Vector3 = P.call(-lw_ * 0.5, y0, 0.012)
	var b1: Vector3 = P.call(lw_ * 0.5, y0, 0.012)
	var t1: Vector3 = P.call(lw_ * 0.5, ys, 0.012)
	var t0: Vector3 = P.call(-lw_ * 0.5, ys, 0.012)
	d.quad("noir", b0, b1, t1, t0, v)
	d.quad("noir", t0, t1, P.call(0.0, ys + f, 0.012), P.call(0.0, ys + f, 0.012), v)
	var dimj := Vector3(0.2, ys - y0 + 0.1, 0.16) if horiz else Vector3(0.16, ys - y0 + 0.1, 0.2)
	for sx: float in [-1.0, 1.0]:
		d.boite("mur1", P.call(sx * (lw_ * 0.5 + 0.1), (y0 + ys) * 0.5 - 0.05, 0.08), dimj)
	var ca: Vector3 = P.call(0.0, 0.0, 0.08)
	d.arc("mur0", "x" if horiz else "z", ca.x, ca.z, lw_, ys, f, 0.18, 0.16, 6)
	# tablette en saillie, givre dessus, gravats d'os dessous
	var dt := Vector3(lw_ + 0.5, 0.12, 0.3) if horiz else Vector3(0.3, 0.12, lw_ + 0.5)
	d.boite("mur1", P.call(0.0, y0 - 0.06, 0.15), dt)
	d.givre_dessus(P.call(0.0, y0, 0.16), Vector2(dt.x, dt.z), 0.03)
	d.glacons_arete(P.call(-lw_ * 0.5 - 0.2, y0 - 0.12, 0.29), P.call(lw_ * 0.5 + 0.2, y0 - 0.12, 0.29), 1.2, 0.3)
	var lac := atan2(v.x, v.z)
	match r.randi_range(0, 2):
		0:      # squelette couché : crâne + côtes + os longs
			d.crane(P.call(-0.3, y0, 0.12), lac + r.randf_range(-0.6, 0.6))
			for k in 4:
				d.boite("os", P.call(-0.12 + k * 0.07, y0 + 0.02, 0.12), Vector3(0.025, 0.035, 0.16) if horiz else Vector3(0.16, 0.035, 0.025))
			d.boite("os", P.call(0.22, y0 + 0.02, 0.1), Vector3(0.34, 0.035, 0.035) if horiz else Vector3(0.035, 0.035, 0.34))
			d.boite("os", P.call(0.26, y0 + 0.02, 0.17), Vector3(0.3, 0.035, 0.035) if horiz else Vector3(0.035, 0.035, 0.3))
		1:      # crâne et urne
			d.crane(P.call(-0.22, y0, 0.12), lac + r.randf_range(-0.4, 0.4))
			d.urne(P.call(0.22, y0, 0.12), 0.75)
		_:      # deux urnes et un crâne
			d.urne(P.call(-0.25, y0, 0.12), 0.7)
			d.urne(P.call(0.25, y0, 0.12), 0.6)
			d.crane(P.call(0.0, y0, 0.16), lac)
	if r.randf() < 0.5:
		d.toile(P.call(-lw_ * 0.5, ys + 0.2, 0.0), Vector3(1, 0, 0) if horiz else Vector3(0, 0, 1), v, 0.45)
	d.j1()

func _deco_froid(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var n := clampi(int(dim.x * dim.y / 18.0), 2, 14)
	for i in n:
		var pg := Vector3(alea(-dim.x * 0.5 + 0.8, dim.x * 0.5 - 0.8), y + h, alea(-dim.y * 0.5 + 0.8, dim.y * 0.5 - 0.8))
		var lg := alea(0.45, 1.2)
		var rg := alea(0.1, 0.14)
		differer(Vector3(pg.x, y, pg.z), rg + 0.05, func(dp: Vector3, _e: float) -> void: glacon(pg + dp, lg, rg), "plafond")      # pas dans un pilier
	if dim.x > 6.0 and dim.y > 6.0:
		for cn: Array in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			if d.rng.randf() < 0.6:
				var pc := Vector3(cn[0] * (dim.x * 0.5 - 1.0), y, cn[1] * (dim.y * 0.5 - 1.0))
				var rc := alea(1.2, 1.8)
				var hc := alea(0.5, 0.75)
				# congère adossée à l'angle : jamais sur un coffre, un brasero, une statue, une accroche (réduite, sinon omise)
				differer(pc, rc, func(dp: Vector3, e: float) -> void: congere(pc + dp, rc * e, hc * maxf(e, 0.7)), "amas")

## Couloir : arcs sur pilastres tous les 4 m, appliques alternées, détritus ; axe long = z local.
func _couloir(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var L := dim.y
	var y := float(m.get("y", 0.0))
	var h := float(m.get("h", 3.0))
	var th: String = m.get("theme", "tombeau")
	_lanes = [[Vector2(0, -L * 0.5), Vector2(0, L * 0.5)]]
	var z := -L * 0.5 + 2.0
	while z < L * 0.5 - 1.5:
		d.arc("mur0", "x", 0.0, z, dim.x - 0.6, y + 2.6, 1.3, 0.32, 0.45)
		for s in [-1.0, 1.0]:
			if d.est_crypte:      # 3e passe : pilastre sculpté (base givrée, entrelacs, chapiteau, glaçons) sous chaque arc
				d.pilastre_mur(Vector3(s * (dim.x * 0.5 - 0.3), y, z), Vector3(-s, 0, 0), 2.6)
			else:
				d.boite("mur0", Vector3(s * (dim.x * 0.5 - 0.45), y + 1.3, z), Vector3(0.3, 2.6, 0.45))
		z += 4.0
	# givre au pied des murs, entre les pilastres (rng_deco : le décor tiré par rng ne bouge pas)
	if d.est_crypte:
		var zg := -L * 0.5 + 1.0
		while zg < L * 0.5 - 1.0:
			for s: float in [-1.0, 1.0]:
				if d.rng_deco.randf() < 0.55:
					d.givre_dessus(Vector3(s * (dim.x * 0.5 - 0.42), y + 0.005, zg + d.rng_deco.randf_range(-0.4, 0.4)), Vector2(0.24, d.rng_deco.randf_range(0.5, 1.1)), 0.01)
			zg += 1.6
	var nb: int = m.get("lum", {}).get("appliques", maxi(1, int((L - 2.0) / 8.0) + (1 if L > 7.0 else 0)))
	var sg := 1.0 if d.rng.randf() < 0.5 else -1.0
	for i in nb:
		var zz := lerpf(-L * 0.5 + 2.5, L * 0.5 - 2.5, (i + 0.5) / nb) if nb > 1 else 0.0
		var cote := "E" if sg > 0.0 else "O"
		var pm := plan_mur(m, cote)
		d.applique(Vector3(pm["plan"], y, zz), pm["vers"], y + 2.0, 4.8, 1.6, true)
		_jitter_derniere_lumiere(th == "glace")
		sg = -sg
	# refonte matière : niches funéraires entre les pilastres (squelettes, crânes, urnes), côté opposé à l'applique la plus proche
	var zap: Array = []
	var sg2 := sg if nb % 2 == 0 else -sg
	for i in nb:
		zap.append([lerpf(-L * 0.5 + 2.5, L * 0.5 - 2.5, (i + 0.5) / nb) if nb > 1 else 0.0, sg2])
		sg2 = -sg2
	var zn := -L * 0.5 + 4.0
	while zn < L * 0.5 - 1.8:
		for s: float in [-1.0, 1.0]:
			var gene := false
			for ap: Array in zap:
				if absf(float(ap[0]) - zn) < 1.3 and float(ap[1]) == s:
					gene = true
			if not gene:
				niche_os(m, "E" if s > 0.0 else "O", zn, y)
		zn += 4.0
	z = -L * 0.5 + 2.0
	while z < L * 0.5 - 1.5:
		for s: float in [-1.0, 1.0]:
			if d.rng_deco.randf() < 0.3:
				var x0 := s * (dim.x * 0.5 - 0.6)
				d.toile(Vector3(x0, y + h - 0.05, z + 0.25), Vector3(-s, 0, 0), Vector3(0, 0, 1), d.rng_deco.randf_range(0.5, 0.8))
		z += 4.0
	if m.get("detritus", true):
		var t := -L * 0.5 + 2.5
		while t < L * 0.5 - 1.5:
			var v := alea(-0.9, 0.9)
			match d.rng.randi_range(0, 3):
				0: d.os_tas(Vector3(v, y, t), 3, 0.3)
				1: d.arme(Vector3(v, y, t), d.rng.randf() * TAU)
				2: d.urne(Vector3(1.0 if d.rng.randf() < 0.5 else -1.0, y, t), 0.9)
				_: d.crane(Vector3(v, y, t), d.rng.randf() * TAU)
			t += 4.0
	for cn: Array in [[-1, -1], [1, 1]]:
		if d.rng.randf() < 0.7:
			d.toile(Vector3(cn[0] * (dim.x * 0.5 - 0.3), y + h, cn[1] * (L * 0.5 - 0.3)), Vector3(-cn[0], 0, 0), Vector3(0, 0, -cn[1]))
	if th == "givre" or th == "glace":
		var k := maxi(1, int(L / 4.0))
		for i in k:
			glacon(Vector3(alea(-0.7, 0.7), y + h, lerpf(-L * 0.5 + 1.5, L * 0.5 - 1.5, (i + 0.5) / k)), alea(0.5, 0.9), 0.12)
		souffle(Vector3(0, y + 1.0, 0), Vector3(0.9, 0.8, L * 0.5 - 1.0), Vector3(0, 0, -1), clampi(int(L * 2.5), 10, 30))

# ------------------------------------------------------------------ usure : fissures, gravats, poutre tombée (jamais sur un passage)
func _usure(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var y := float(m.get("y", 0.0))
	var u := int(m.get("usure", 0))
	var n := 2 * u
	var essais := 0
	var faits := 0
	while faits < n and essais < 40:
		essais += 1
		var p := Vector3(alea(-dim.x * 0.5 + 1.2, dim.x * 0.5 - 1.2), y, alea(-dim.y * 0.5 + 1.2, dim.y * 0.5 - 1.2))
		if libre(m, p, 0.9, 0.4):
			var rg := alea(0.6, 1.1)
			var hg := alea(0.4, 0.8)
			# différé : jamais sur un tonneau, une statue, un bassin, un socle du récit ni sur un point d'apparition
			differer(p, rg, func(dp: Vector3, _e: float) -> void: d.gravats(p + dp, rg, hg, true), "gravats")
			_reserves.append([Vector2(p.x, p.z), 1.0])
			faits += 1
	for c in ["N", "S", "E", "O"]:
		if d.rng.randf() < 0.5:
			var lib := murs_libres(m, c, 0.4)
			if lib.is_empty():
				continue
			var s: Array = lib[d.rng.randi_range(0, lib.size() - 1)]
			var pm := plan_mur(m, c)
			var base := pt_mur(m, c, (s[0] + s[1]) * 0.5, 0.0)
			var vf: Vector3 = pm["vers"]
			var bf := Vector3(base.x, y + 1.3, base.z)
			# différée : ses gravats (au pied du mur) ne tombent plus dans un sarcophage, un trône, des tonneaux ou sur un gardien
			differer(Vector3(base.x, y, base.z) + vf * 0.5, 0.4, func(_dp: Vector3, e: float) -> void: d.fissures(bf, vf, 1.8, 2.4, 2, y, e > 0.0), "fissure")

# ------------------------------------------------------------------ garnitures génériques (appelées par la table)
## Piliers {pts: [positions]} (grille régulière : les arcs relient les voisins) ; `saute` : indices omis (variation de la graine).
func _g_piliers(m: Dictionary, a: Dictionary) -> void:
	var pts: Array = a["pts"]
	var h: float = a.get("h", float(m.get("h", 4.0)))
	var y := float(m.get("y", 0.0))
	var w: float = a.get("largeur", 1.0)
	var saute: Array = a.get("saute", [])
	var xs: Array = []
	var zs: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		if not xs.any(func(v: float) -> bool: return absf(v - p.x) < 0.05):
			xs.append(p.x)
		if not zs.any(func(v: float) -> bool: return absf(v - p.z) < 0.05):
			zs.append(p.z)
		if not saute.has(i):
			d.pilier(p.x, p.z, h, w, y)
			_reserves.append([Vector2(p.x, p.z), w * 0.7])
	xs.sort()
	zs.sort()
	if a.get("arcs", true):
		var ys := y + h * 0.78
		for z: float in zs:
			for k in xs.size() - 1:
				var ww: float = xs[k + 1] - xs[k] - w
				if ww > 0.5:
					d.arc("mur0", "x", (xs[k] + xs[k + 1]) * 0.5, z, ww, ys, _fleche(ww, ys, y + h), 0.35, 0.5, 10)
		for x: float in xs:
			for k in zs.size() - 1:
				var ww: float = zs[k + 1] - zs[k] - w
				if ww > 0.5:
					d.arc("mur0", "z", x, (zs[k] + zs[k + 1]) * 0.5, ww, ys, _fleche(ww, ys, y + h), 0.35, 0.5, 10)

## Flèche d'un arc entre piliers : ARC BRISÉ (références) dès que la hauteur le permet (flèche 0,62 x portée), sinon la plus
## grande flèche qui tient sous le plafond.
func _fleche(ww: float, ys: float, plafond: float) -> float:
	return clampf(minf(ww * 0.62, plafond - ys - 0.4), 0.3, 2.4)

## Panneaux d'ossuaire sur les parties libres des murs choisis {murs: ["O","S"], y0, y1}
func _g_panneaux_os(m: Dictionary, a: Dictionary) -> void:
	var y := float(m.get("y", 0.0))
	for c: String in a.get("murs", ["O", "S"]):
		var lib := murs_libres(m, c, 0.2)
		lib.sort_custom(func(p: Array, q: Array) -> bool: return (p[1] - p[0]) > (q[1] - q[0]))
		var pm := plan_mur(m, c)
		var sg: float = (pm["vers"] as Vector3).x + (pm["vers"] as Vector3).z
		for s: Array in lib.slice(0, a.get("max", 2)):
			if s[1] - s[0] < 2.0:
				continue
			var a0: float = s[0] + 0.3
			var a1: float = minf(s[1] - 0.3, a0 + a.get("long", 9.0))
			d.occupations.append([pt_mur(m, c, (a0 + a1) * 0.5, y), (a1 - a0) * 0.5 + 0.35])      # crypte v2 : pas de panneau de maçonnerie dessus
			panneau_os("x" if pm["horiz"] else "z", float(pm["plan"]) - sg * 0.0, a0, a1, y + 0.8, y + 2.8, sg)

## Rangée de sarcophages contre un mur {cote, n, taille, pille: [indices]}
func _g_sarcophages(m: Dictionary, a: Dictionary) -> void:
	var c: String = a.get("cote", "S")
	var n: int = a.get("n", 3)
	var y := float(m.get("y", 0.0))
	var lib := murs_libres(m, c, 0.3)
	if lib.is_empty():
		return
	lib.sort_custom(func(p: Array, q: Array) -> bool: return (p[1] - p[0]) > (q[1] - q[0]))
	var s: Array = lib[0]
	var pm := plan_mur(m, c)
	var taille: Vector3 = a.get("taille", Vector3(2.2, 0.7, 0.9))
	var pas: float = (s[1] - s[0]) / n
	var pille: Array = a.get("pille", [])
	for i in n:
		var u: float = s[0] + pas * (i + 0.5)
		var base := pt_mur(m, c, u, y, taille.z * 0.5 + 0.02)
		var lacet := 0.0 if pm["horiz"] else PI * 0.5
		if pille.has(i):
			d.sarcophage_pille(base, taille, lacet)
		else:
			d.sarcophage(base, taille, lacet)
		_reserves.append([Vector2(base.x, base.z), 1.1])

## Estrade {pos (sol, centre), taille (largeur, hauteur, profondeur), rampe: "N"|"S"|"E"|"O"} : plate-forme pleine et RAMPE d'accès (collision inclinée).
func _g_estrade(m: Dictionary, a: Dictionary) -> void:
	var p: Vector3 = a["pos"]
	var t: Vector3 = a["taille"]
	var mat: String = a.get("mat", "mur1")
	if d.v2:      # crypte v2 : massif en blocs taillés (module Blender « estrade_3x4 » mis à la taille), MÊME collision
		d.solide(Vector3(p.x, p.y + t.y * 0.5, p.z), t)
		d.modele("estrade_3x4", p, 0.0, Vector3(t.x / 3.2, t.y / 0.9, t.z / 4.0))
	else:
		d.boite_pleine(mat, Vector3(p.x, p.y + t.y * 0.5, p.z), t)
		d.boite("mur0", Vector3(p.x, p.y + t.y + 0.03, p.z), Vector3(t.x + 0.1, 0.06, t.z + 0.1))
	var cote: String = a.get("rampe", "E")
	var dir := Vector3(1, 0, 0)
	var larg := t.z
	var dbord := t.x * 0.5
	match cote:
		"O": dir = Vector3(-1, 0, 0)
		"S": dir = Vector3(0, 0, 1); larg = t.x; dbord = t.z * 0.5
		"N": dir = Vector3(0, 0, -1); larg = t.x; dbord = t.z * 0.5
	var lon: float = t.y * 2.8
	rampe(p + dir * (dbord + lon) + Vector3(0, 0, 0), -dir, lon, larg - 0.2, t.y, mat)
	_reserves.append([Vector2(p.x, p.z), maxf(t.x, t.z) * 0.6 + 0.6])
	_reserves.append([Vector2(p.x + dir.x * (dbord + lon * 0.5), p.z + dir.z * (dbord + lon * 0.5)), lon * 0.5 + 0.8])

## Rampe : bas en `bas` (sol), elle monte vers `dir` (horizontal, unitaire) sur `longueur` jusqu'à +`hauteur` ; visuel en dalle, collision inclinée.
func rampe(bas: Vector3, dir: Vector3, longueur: float, largeur: float, hauteur: float, mat := "mur1") -> void:
	var haut := bas + dir * longueur + Vector3(0, hauteur, 0)
	var dr := Vector3.UP.cross(dir).normalized() * largeur * 0.5
	var n := (haut - bas).cross(dr).normalized()
	if n.y < 0.0:
		n = -n
	d.quad("dalle0", bas - dr, bas + dr, haut + dr, haut - dr, n)
	for sg in [-1.0, 1.0]:      # flancs pleins
		var e: Vector3 = dr * sg
		d.quad(mat, bas + e, bas + e, haut + e, haut + e - Vector3(0, hauteur, 0), e.normalized())
	var lp := Vector3(longueur, hauteur, 0).length()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(largeur, 0.3, lp)
	cs.shape = bs
	var fwd := (haut - bas).normalized()
	var droite := fwd.cross(Vector3.UP).normalized()
	var haut_n := droite.cross(fwd).normalized()
	if haut_n.y < 0.0:
		haut_n = -haut_n
		droite = -droite
	var bz := Basis(droite, haut_n, -fwd)
	cs.transform = d.xf * Transform3D(bz, (bas + haut) * 0.5 - haut_n * 0.15)
	d.corps.add_child(cs)

## Couverts : piliers ou blocs posés dans la salle hors des passages {n, mat} ; la graine décide des emplacements.
func _g_couverts(m: Dictionary, a: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var y := float(m.get("y", 0.0))
	var n: int = a.get("n", 3)
	var faits := 0
	var essais := 0
	while faits < n and essais < 60:
		essais += 1
		var p := Vector3(alea(-dim.x * 0.5 + 1.8, dim.x * 0.5 - 1.8), y, alea(-dim.y * 0.5 + 1.8, dim.y * 0.5 - 1.8))
		if libre(m, p, 0.7, 0.8):
			if d.rng.randf() < 0.5:
				d.pilier(p.x, p.z, float(m.get("h", 4.0)), 0.9, y)
			else:
				d.boite_pleine("mur0", Vector3(p.x, y + 0.5, p.z), Vector3(1.4, 1.0, 0.9))
				d.boite("mur1", Vector3(p.x, y + 1.04, p.z), Vector3(1.5, 0.08, 1.0))
			_reserves.append([Vector2(p.x, p.z), 1.0])
			faits += 1

## Rayon de lumière froide d'un oculus {pos}
func _g_oculus(m: Dictionary, a: Dictionary) -> void:
	var p: Vector3 = a.get("pos", Vector3(0, 0, 0))
	var y := float(m.get("y", 0.0))
	var h := float(m.get("h", 4.0))
	d.oculus(Vector3(p.x, y + h, p.z), a.get("cote", 1.4))
	d.rai(Vector3(p.x, y + a.get("sol", 0.0), p.z), h - 0.05 - a.get("sol", 0.0), a.get("cote", 1.4))
	d.poussiere(Vector3(p.x, y + h * 0.5, p.z), Vector3(0.7, h * 0.45, 0.7), 22)
	if a.get("flaque", true):
		d.flaque_froide(Vector3(p.x, y + a.get("sol", 0.0), p.z), 3.2)
	if a.get("lumiere", true):
		d.lumiere(Vector3(p.x, y + 1.3, p.z), Color(0.55, 0.75, 1.0), 0.7, 4.5, 1.8, false)

# ------------------------------------------------------------------ escalier (module)
## `o` = centre de l'emprise, dim = (largeur, longueur) ; en repère local le HAUT est à -z (z = -longueur/2), le BAS à +z. y_haut / y_bas absolus.
func _escalier(m: Dictionary) -> void:
	var dim: Vector2 = m["dim"]
	var yh: float = m.get("y_haut", 0.0)
	var yb: float = m.get("y_bas", BAS)
	var th: Dictionary = THEMES[m.get("theme", "tombeau")]
	escalier(-dim.x * 0.5, dim.x * 0.5, -dim.y * 0.5, dim.y * 0.5, yh, yb, th["mur"])
	zone(m["id"], Vector3(-dim.x * 0.5, 0, -dim.y * 0.5), Vector3(dim.x * 0.5, 0, dim.y * 0.5), minf(yh, yb))
	# lumières : deux appliques le long de la cage (hauteur suivant la pente)
	var pm := plan_mur(m, "O")
	for k in 2:
		var zz := lerpf(-dim.y * 0.5 + 3.0, dim.y * 0.5 - 2.0, float(k))
		var sol := lerpf(yh, yb, (zz + dim.y * 0.5) / dim.y)
		d.niveau_a = 1.0 + sol / 20.0
		d.applique(Vector3(pm["plan"], 0.0, zz), Vector3(1, 0, 0), sol + 2.1, 4.6, 1.5, true)
	var ouv: Array = []
	ouv.append({"cote": "N", "pos": mw(Vector3(0, yh, -dim.y * 0.5)), "largeur": dim.x, "vers": m.get("vers_haut", ""), "secret": false, "local": Vector3(0, yh, -dim.y * 0.5)})
	ouv.append({"cote": "S", "pos": mw(Vector3(0, yb, dim.y * 0.5)), "largeur": dim.x, "vers": m.get("vers_bas", ""), "secret": false, "local": Vector3(0, yb, dim.y * 0.5)})
	modules[m["id"]]["ouv"] = ouv
	modules[m["id"]]["escalier"] = true

## Escalier droit entre z_haut (y_haut) et z_bas (y_bas), largeur x0..x1 (repère local) ; plafond parallèle à 3 m ; marches de 0,25 m.
func escalier(x0: float, x1: float, z_haut: float, z_bas: float, y_haut: float, y_bas: float, mur := "mur1") -> void:
	var sens := signf(z_bas - z_haut)
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
	d.niveau_a = 1.0
	for i in n:
		var zc := z1 + sens * (i + 0.5) * pas
		var yt: float = lerpf(y_haut, y_bas, (i + 1.0) / n)
		var ybas_m: float = yt - 0.25 - 0.1
		d.boite("dalle0", Vector3((xa + xb) * 0.5, (yt + ybas_m) * 0.5, zc), Vector3(xb - xa, yt - ybas_m, pas))
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
	var k := 2.0
	while k < longueur - 1.0:
		var z := z1 + sens * k
		d.niveau_a = 1.0 + (sol.call(z) as float) / 20.0
		if d.v2:      # crypte v2 (vue 5 « escalier descendant ») : piliers engagés sous chaque arc
			d.arc("mur0", "x", (x0 + x1) * 0.5, z, x1 - x0 - 0.6 - 0.64, sol.call(z) + 1.4, 1.2, 0.3, 0.4)
			for sx: float in [-1.0, 1.0]:
				d.modele("pilier_mur_1p6", Vector3((xa if sx < 0.0 else xb), sol.call(z), z), PI * 0.5 * -sx, Vector3(1, 1.4 / 1.62, 1))
		else:
			d.arc("mur0", "x", (x0 + x1) * 0.5, z, x1 - x0 - 0.6, sol.call(z) + 1.4, 1.3, 0.3, 0.4)
		k += 4.0
	d.niveau_a = 1.0
	var dy := y_bas - y_haut
	var long_pente := sqrt(longueur * longueur + dy * dy)
	var centre := Vector3((x0 + x1) * 0.5, (y_haut + y_bas) * 0.5 - 0.2 - 0.05, (z1 + z2) * 0.5)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(x1 - x0, 0.4, long_pente)
	cs.shape = bs
	cs.transform = d.xf * Transform3D(Basis(Vector3.RIGHT, -atan2(dy, z2 - z1)), centre)
	d.corps.add_child(cs)
	var ymin := minf(y_haut, y_bas) - 0.4
	var ymax := maxf(y_haut, y_bas) + 3.4
	for x in [x0, x1]:
		d.solide(Vector3(x, (ymin + ymax) * 0.5, (z_haut + z_bas) * 0.5), Vector3(0.6, ymax - ymin, long_tot))
	d.solide(Vector3((x0 + x1) * 0.5, maxf(y_haut, y_bas) + 3.2, (z_haut + z_bas) * 0.5), Vector3(x1 - x0, 0.4, long_tot))

# ------------------------------------------------------------------ portes mobiles
## Porte de bois ferrée qui coulisse vers le haut dans l'épaisseur du mur ; `pos` et `axe_passage` en repère LOCAL.
func porte_coulissante(id: String, pos: Vector3, axe_passage: String, largeur := 2.6) -> Node3D:
	var w := mw(pos)
	var axe := axe_passage
	if int(_m.get("rot", 0)) % 2 == 1:
		axe = "z" if axe_passage == "x" else "x"
	var n := Node3D.new()
	n.position = Vector3(w.x, 0.0, w.z)
	d.racine.add_child(n)
	var sb := StaticBody3D.new()
	n.add_child(sb)
	var vers_x := axe == "x"
	var ep := 0.3
	var taille := Vector3(ep, 3.0, largeur) if vers_x else Vector3(largeur, 3.0, ep)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille + (Vector3(0, 0, 0.6) if vers_x else Vector3(0.6, 0, 0))
	cs.shape = bs
	cs.position = Vector3(0, w.y + 1.5, 0)
	sb.add_child(cs)
	var saved := d.xf
	d.xf = Transform3D.IDENTITY
	if d.est_crypte:      # 4e passe : dalle de pierre (plus de planches orange) : panneau gravé, bandeaux en saillie, clous de fer
		d.instance_boite(n, "mur1", taille, Vector3(0, w.y + 1.5, 0))
		var ep2 := Vector3(0.06, 0, 0) if vers_x else Vector3(0, 0, 0.06)
		var lw := Vector3(0, 0, 1) if vers_x else Vector3(1, 0, 0)
		d.instance_boite(n, "gravure", (Vector3(ep + 0.02, 1.7, largeur * 0.56) if vers_x else Vector3(largeur * 0.56, 1.7, ep + 0.02)), Vector3(0, w.y + 1.45, 0))
		for yy in [0.32, 2.72]:
			d.instance_boite(n, "mur0", taille * Vector3(1, 0, 1) + Vector3(0, 0.26, 0) + ep2, Vector3(0, w.y + yy, 0))
		for sg in [-1.0, 1.0]:
			for yy in [0.32, 2.72]:
				d.instance_boite(n, "fer", Vector3(ep + 0.1, 0.07, 0.07) if vers_x else Vector3(0.07, 0.07, ep + 0.1), Vector3(0, w.y + yy, 0) + lw * largeur * 0.38 * sg)
	else:
		d.instance_boite(n, "bois", taille, Vector3(0, w.y + 1.5, 0))
		for yy in [0.5, 1.5, 2.5]:
			d.instance_boite(n, "fer", taille + (Vector3(0.06, -2.85, 0.0) if vers_x else Vector3(0.0, -2.85, 0.06)), Vector3(0, w.y + yy, 0))
		for sg in [-1.0, 1.0]:
			var dec := Vector3(0.03 * sg, 0, 0) if vers_x else Vector3(0, 0, 0.03 * sg)
			d.instance_boite(n, "fer", Vector3(0.08, 3.0, 0.08), Vector3(0, w.y + 1.5, largeur * 0.3 * sg if vers_x else 0) + dec)
	d.xf = saved
	portes[id] = n
	return n

# ------------------------------------------------------------------ décors thématiques (repère local)
## Souffle froid : bruine de petits carrés pâles qui dérive le long d'un couloir.
func souffle(centre: Vector3, ext: Vector3, dir: Vector3, nombre := 36) -> void:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = 5.0
	p.position = mw(centre)
	var e := (d.xf.basis * ext).abs()
	p.visibility_aabb = AABB(-e - Vector3(3, 3, 3), e * 2.0 + Vector3(6, 6, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = e
	pm.direction = mdir(dir).normalized()
	pm.spread = 25.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, -0.02, 0)
	FilVerrou.sur_fil_principal(p, &"set_process_material", [pm])   # matériaux neufs : compilés sur le fil principal (voir FilVerrou.sur_fil_principal)
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.albedo_color = Color(0.75, 0.88, 1.0, 0.55)
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	FilVerrou.sur_fil_principal(p, &"set_draw_pass_mesh", [0, q])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.racine.add_child(p)

func glacon(pos_plafond: Vector3, longueur := 0.8, r := 0.12) -> void:
	d.j0("glacon")
	d.tour("mur4", pos_plafond + Vector3(0, -longueur, 0), [Vector2(0.0, 0.0), Vector2(r * 0.5, longueur * 0.4), Vector2(r * 0.85, longueur * 0.8), Vector2(r, longueur)], 6, 0.3, false)
	d.j1()

func congere(pos: Vector3, r := 1.8, h := 0.7) -> void:
	d.j0("congere")
	d.emprise("congere", pos, Vector2(r, r), 0.0, h)
	d.tour("neige", pos, [Vector2(r, 0.0), Vector2(r * 0.82, h * 0.45), Vector2(r * 0.45, h * 0.85), Vector2(r * 0.12, h)], 7, 0.2, true)
	for k in 3:
		var a := d.rng.randf() * TAU
		var rr := r * d.rng.randf_range(0.6, 0.9)
		var rs := r * d.rng.randf_range(0.35, 0.55)
		d.tour("neige", pos + Vector3(cos(a) * rr, 0, sin(a) * rr), [Vector2(rs, 0.0), Vector2(rs * 0.7, h * 0.4), Vector2(rs * 0.2, h * 0.65)], 6, 0.3, true)
	d.j1()

func stalagmite(pos: Vector3, haut := 0.7, r := 0.16) -> void:
	d.j0("stalagmite")
	d.emprise("stalagmite", pos, Vector2(r, r), 0.0, haut)
	d.tour("mur4", pos, [Vector2(r, 0.0), Vector2(r * 0.55, haut * 0.55), Vector2(0.0, haut)], 5, 0.3, false)
	d.j1()

func lampe_glace(pos: Vector3, e := 1.3) -> void:
	d.flaque_froide(Vector3(pos.x, pos.y, pos.z), 3.2)
	d.lumiere(pos + Vector3(0, 1.4, 0), Color(0.45, 0.72, 1.0), e, 6.0, 1.6, false)
	stalagmite(pos, 0.9, 0.2)

func os_monticule(pos: Vector3, r := 0.9, h := 0.6) -> void:
	d.j0("os_monticule")
	d.emprise("os_monticule", pos, Vector2(r * 1.1, r * 1.1), 0.0, h)
	d.modele("os_monticule", pos, 0.2, Vector3(r / 0.9, h / 0.6, r / 0.9), {}, false)      # lot L2 : module Blender (os couchés sur un noyau sombre)
	for k in 7:
		var a := d.rng.randf() * TAU
		var rr := d.rng.randf() * r * 0.8
		d.crane(pos + Vector3(cos(a) * rr, h * (1.0 - rr / r) * 0.75, sin(a) * rr), d.rng.randf() * TAU)
	d.os_tas(pos + Vector3(r * 0.9, 0, 0.2), 4, 0.3)
	d.j1()

func or_tas(pos: Vector3, r := 0.6, h := 0.3) -> void:
	d.j0("or_tas")
	d.emprise("or_tas", pos, Vector2(r * 1.4, r * 1.4), 0.0, h)
	# lot L2 : monceau de pièces en module Blender (coupe, couronne ou plat selon la position) ; tirages de l'ancienne version gardés
	d.modele("or_tas_" + ObjPetitMobilier.variante(d, pos), pos, ObjPetitMobilier.lacet_pos(d, pos), Vector3(r / 0.6, h / 0.3, r / 0.6), {}, false)
	for k in 4:
		d.rng.randf()
		d.rng.randf_range(0.7, 1.1)
		d.rng.randf_range(0.3, 0.5)
	for k in 6:
		var a := d.rng.randf() * TAU
		d.boite("or", pos + Vector3(cos(a), 0.012, sin(a)) * r * d.rng.randf_range(1.0, 1.6), Vector3(0.07, 0.02, 0.07), d.rng.randf() * TAU)
	d.j1()

## Panneau d'ossuaire (texture de niches) plaqué sur un mur, avec cadre ; axe "x" : mur le long de X (z fixe), "z" : le long de Z.
func panneau_os(axe: String, fixe: float, a0: float, a1: float, y0: float, y1: float, signe: float) -> void:
	d.j0("panneau_os")
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
			d.boite("mur0", Vector3(fc, (y0 + y1) * 0.5, u), Vector3(ep, y1 - y0 + 0.4, ep))
	d.j1()

## Niche à gardien (encadrement épais, tablette, crâne, urne) sur un mur : x_plan = plan du mur, vers_x = sens vers la pièce.
func niche(x_plan: float, z: float, vers_x: float) -> void:
	d.j0("niche")
	var x := x_plan + vers_x * 0.08
	d.boite("mur0", Vector3(x, 1.1, z - 0.7), Vector3(0.16, 2.2, 0.24))
	d.boite("mur0", Vector3(x, 1.1, z + 0.7), Vector3(0.16, 2.2, 0.24))
	d.boite("mur0", Vector3(x, 2.25, z), Vector3(0.16, 0.3, 1.64))
	d.boite("mur1", Vector3(x_plan + vers_x * 0.13, 0.95, z), Vector3(0.26, 0.1, 1.2))
	d.crane(Vector3(x_plan + vers_x * 0.15, 1.0, z - 0.25), atan2(vers_x, 0.0))
	d.urne(Vector3(x_plan + vers_x * 0.15, 1.0, z + 0.3), 0.7)
	d.os_tas(Vector3(x_plan + vers_x * 0.45, 0.0, z), 2, 0.3)
	d.j1()

# ------------------------------------------------------------------ vérifications (liaisons, accroches dans la salle)
## Chaque ouverture qui nomme un module relié doit coïncider avec celle de ce module (position et largeur).
func verifier() -> Array:
	problemes = []
	for id in modules:
		var md: Dictionary = modules[id]
		for ou: Dictionary in md["ouv"]:
			var vers: String = ou["vers"]
			if vers == "":
				continue
			if not modules.has(vers):
				problemes.append("%s : ouverture vers « %s » inconnue" % [id, vers])
				continue
			var trouve := false
			for ou2: Dictionary in modules[vers]["ouv"]:
				if ou2["vers"] == id and (ou2["pos"] as Vector3).distance_to(ou["pos"]) < 0.06 and absf(float(ou2["largeur"]) - float(ou["largeur"])) < 0.06:
					trouve = true
			if not trouve:
				problemes.append("%s ↔ %s : les ouvertures ne coïncident pas (%s)" % [id, vers, ou["pos"]])
	return problemes
