class_name BatimentsOuverts
## Retours exe 5 : « pouvoir rentrer dans n'importe quel bâtiment ». Tout bâtiment du bâti v2 (maisons H1-H6, auberge, moulins,
## tour, fermes, granges) devient enterable : une PORTE sur charnière (vantail validé du bâtiment, ouvert vers l'intérieur), une
## COQUE de collisions (plancher, murs creux, linteau, dessus) et un INTÉRIEUR construit à la demande (`Interieur.paresseux`).
##
## L'intérieur est tiré de l'EMPREINTE du bâtiment (dimensions, porte, fenêtres, cheminée, toit) de façon déterministe : doublure
## des murs dans le style du bâtiment (rondins, planches, pierre, torchis ; ouvertures aux vraies fenêtres), plancher, plafond sous
## charpente ou plafond plat, puis le mobilier de sa FONCTION (maison, auberge, grenier, moulin, tour, ferme, grange, étable,
## moulin à vent) posé le long des murs par un petit répartiteur (porte et fenêtres dégagées). Les mêmes briques et matières
## que les intérieurs validés (`Interieurs` : ps1_interieur, 3 bois, feu chaud, lumière froide aux fenêtres).
## Données (nom, foyer, habitants, serrure, lits) : data/batiments.json. Lits : un Marker3D « emplacement_lit » par lit (contrat
## « sommeil » : largeur et longueur en mètres) ; le vrai lit (Lit : couchage, « Dormir », intrusion) y est posé par Sommeil.
##
## Repère de l'intérieur (`Interieur`, enfant du pivot du bâtiment) : tourné pour que sa PORTE soit côté +Z, posé à
## (y_sol - 0,4) pour que son plancher soit à `Interieurs.F` (0,42) comme partout ; le grand axe du toit est X ou Z.

const DONNEES := "res://data/batiments.json"
## `-- --batiments-clos` : le bâti d'avant (bâtiments pleins, sans intérieur) pour les comparaisons et les mesures.
static var actif := not OS.get_cmdline_user_args().has("--batiments-clos")
const EP_DOUBLURE := 0.08          # épaisseur de la doublure des murs
const ECART_TOIT := 0.45           # le lambris pend sous le plan du toit du dehors
const MARGE_PORTE := 1.35          # profondeur dégagée devant la porte (vantail ouvert vers l'intérieur)
const MATS_CAGEOT := {"toile": "jute", "laine": "laine_q"}      # cageot de pommes : pas de toile bleue de tenture

static var _donnees := {}

static func donnees(id: String) -> Dictionary:
	if _donnees.is_empty():
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DONNEES)) if FileAccess.file_exists(DONNEES) else null
		_donnees = (j as Dictionary).get("batiments", {}) if j is Dictionary else {"_": {}}
	return _donnees.get(id, {})

## Identité, foyer et serrure d'un intérieur (aussi pour les 5 intérieurs d'origine).
static func appliquer(ip: Interieur, id: String, village: Node) -> void:
	ip.id = id
	ip.village = village
	var d := donnees(id)
	if d.has("nom"):
		ip.nom = String(d["nom"])
	ip.proprietaire = String(d.get("foyer", ""))
	ip.habitants = (d.get("habitants", []) as Array).duplicate()
	ip.difficulte = int(d.get("verrou", 1))
	ip.regle_verrou = String(d.get("regle", "nuit"))
	ip.set_meta("proprietaire", ip.proprietaire)
	ip.racine.set_meta("proprietaire", ip.proprietaire)
	ip.set_meta("id", id)

## Propriétaire du n-ième lit dessiné d'un intérieur d'origine (data « lits_existants »).
static func proprietaire_lit(id: String, n: int) -> String:
	var l: Array = donnees(id).get("lits_existants", [])
	return String(l[n]) if n < l.size() else ""

# ================================================================================================================ coque

## Rend le bâtiment de pivot `p` enterable. `s` (repère du pivot : X grand axe, Z largeur) :
##   id, style (rondins | planches | pierre | kit | tour | rond), int (Vector2 : demi-emprise de la face INTÉRIEURE des murs du
##   dehors), ext (Vector2 : demi-emprise extérieure), y_sol (seuil = dessus du plancher - 0,02), y_mur (haut des murs dedans),
##   toit ({faite, pente} : plan du toit du dehors, faîte le long de X) ou plat (y du plafond), porte ({cote, c (Vector3 milieu
##   du seuil, sur le plan du vantail), larg, haut, vantaux 1|2, q (vantail Quaternius) ou "", graine}), fenetres ([[Vector3
##   milieu, Vector2 taille, vraie : bool]] ; vraie = on voit le dehors), foyer (Vector2 : pied de la cheminée) facultatif,
##   bas, haut (collision du dehors), masque (Node3D masqué quand l'intérieur est chargé), rayon / rayon_haut (style rond).
static func ouvrir(v, p: Node3D, s: Dictionary) -> Interieur:
	var id: String = s["id"]
	var ip := Interieur.new()
	ip.name = "Interieur"
	var cote: String = s["porte"]["cote"]
	var lacet: float = {"+Z": 0.0, "+X": PI * 0.5, "-Z": PI, "-X": -PI * 0.5}[cote]
	var y_sol: float = s["y_sol"]
	ip.transform = Transform3D(Basis(Vector3.UP, lacet), Vector3(0, y_sol - 0.4, 0))
	var axe_x := absf(sin(lacet)) < 0.5          # le faîte (X du pivot) reste le X de l'intérieur
	var vint: Vector2 = s["int"]
	var vext: Vector2 = s["ext"]
	var a := Vector2(vint.x, vint.y) if axe_x else Vector2(vint.y, vint.x)
	var e := Vector2(vext.x, vext.y) if axe_x else Vector2(vext.y, vext.x)
	var inv := ip.transform.affine_inverse()
	var porte_c: Vector3 = inv * (s["porte"]["c"] as Vector3)
	var ax := a.x - EP_DOUBLURE - 0.06               # face intérieure de la doublure = limite de la pièce
	var az := a.y - EP_DOUBLURE - 0.06
	ip.demi = Vector2(ax, az) if s.get("style", "") != "rond" else Vector2(ax, ax) * 0.78
	ip.porte_locale = Vector3(porte_c.x, 1.4, porte_c.z + 0.05)
	ip.paresseux = true
	ip.construit = false
	p.add_child(ip)
	v.interieurs.append(ip)
	appliquer(ip, id, v)
	if s.has("masque") and s["masque"] != null:
		ip.masques.append(s["masque"])
	var F := Interieurs.F
	var dy := y_sol - 0.4
	var bas: float = float(s.get("bas", -0.5)) - dy
	var y_mur: float = float(s["y_mur"]) - dy
	var haut: float = maxf(float(s.get("haut", y_mur + dy + 2.0)) - dy, y_mur + 0.5)
	var larg: float = s["porte"]["larg"]
	var h_porte: float = maxf(float(s["porte"]["haut"]), 1.95)     # le joueur (1,8 m) passe toujours, même sous une porte du kit de 1,70 m
	var xd := porte_c.x
	# --- collisions de la coque (repère de l'intérieur)
	v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (F + bas) * 0.5, 0)), Vector3(e.x * 2.0 + 0.1, F - bas, e.y * 2.0 + 0.1))
	var hm := haut - (F - 0.1)
	var ym := (haut + F - 0.1) * 0.5
	if s.get("style", "") == "rond":
		_coque_ronde(v, ip, s, ax, F, haut, xd, larg)
	else:
		var ep_x := maxf(e.x - ax, 0.3)
		var ep_z := maxf(e.y - az, 0.3)
		for sx in [-1.0, 1.0]:
			v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(sx * (ax + ep_x * 0.5), ym, 0)), Vector3(ep_x, hm, az * 2.0 + ep_z * 2.0))
		v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, ym, -(az + ep_z * 0.5))), Vector3(ax * 2.0, hm, ep_z))
		# mur de la porte : deux pans et un linteau
		var x0 := xd - larg * 0.5 - 0.02
		var x1 := xd + larg * 0.5 + 0.02
		var zc := az + ep_z * 0.5
		if x0 > -ax + 0.02:
			v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3((-ax + x0) * 0.5, ym, zc)), Vector3(x0 + ax, hm, ep_z))
		if x1 < ax - 0.02:
			v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3((ax + x1) * 0.5, ym, zc)), Vector3(ax - x1, hm, ep_z))
		var y_lin := F + h_porte
		v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(xd, (y_lin + haut) * 0.5, zc)), Vector3(x1 - x0 + 0.1, haut - y_lin, ep_z))
	# dessus : on ne monte pas sur la charpente
	v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (y_mur + 0.15 + haut) * 0.5 + 0.2, 0)), Vector3(e.x * 2.0 + 0.3, maxf(haut - y_mur, 0.4), e.y * 2.0 + 0.3))
	# porte fermée : blocage dans l'embrasure (désactivé à l'ouverture)
	v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(xd, F + h_porte * 0.5, porte_c.z)), Vector3(larg + 0.1, h_porte, 0.3))
	ip.bloc_porte = v.corps.get_child(v.corps.get_child_count() - 1) as CollisionShape3D
	_rampe(v, ip, xd, larg, porte_c.z, float(s.get("bord", e.y)))
	_vantaux(v, p, ip, s["porte"])
	# --- le contenu, à la demande
	var plan := _plan(s, ip, ax, az, y_mur, axe_x)
	ip.set_meta("haut_max", float(plan.get("faite", plan.get("plat", y_mur))) + 0.35)     # tests : rien ne sort du bâtiment
	var mats: Dictionary = v.mats_int
	ip.constructeur = func(t: Interieur) -> Array:
		var ib := Interieurs.new(v, t, mats, ax * 2.0, az * 2.0, y_mur - 0.4, 1.0)
		ib.rng.seed = id.hash()
		amenager(ib, plan)
		ib.finir()
		return ib.vivants      # petits objets vivants (ObjetsVivants), peuplés par le village après les collisions
	return ip

## Rampe de collision du sol du dehors au seuil (les marches de pierre n'ont pas de collision ; le joueur ne monte pas de marche).
## `bord` = distance du centre où finit le dessus plat du seuil (socle du moulin à vent) : la rampe part de là.
## Sol plus bas que le plancher devant la porte : rampe jusqu'au sol (sous les marches de pierre). Sol qui REMONTE vers le dehors
## (grange à rampe, adossée à la pente) : palier au niveau du plancher jusqu'à ce que le terrain le rejoigne.
static func _rampe(v, ip: Interieur, xd: float, larg: float, zp: float, bord: float) -> void:
	var z0 := maxf(zp + 0.12, bord + 0.06)      # au bord du plancher (sa collision dépasse le nu du mur) : pas de marche
	var F := Interieurs.F
	var w := larg * 0.5 + 0.3
	var sol := func(z: float) -> float:
		var q := ip.to_global(Vector3(xd, 0.0, z))
		return (ip.to_local(Vector3(q.x, v.h_sol(q.x, q.z), q.z))).y
	var g0: float = sol.call(z0 + 0.15)
	if F - g0 < 0.06:
		return
	var g_min := g0
	for k in range(1, 11):
		var gk: float = sol.call(z0 + 0.25 * k)
		g_min = minf(g_min, gk)
		if gk >= F - 0.05:      # le terrain remonte au niveau du seuil : palier
			var lz := 0.25 * k + 0.1
			v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(xd, (F + g_min - 0.3) * 0.5, z0 + lz * 0.5)), Vector3(w * 2.0, F - g_min + 0.3, lz))
			return
	var g := g0
	var run := clampf((F - g) * 1.9, 0.9, 2.4)
	var f := ConvexPolygonShape3D.new()
	f.points = PackedVector3Array([Vector3(-w, g - 0.05, z0 + run), Vector3(w, g - 0.05, z0 + run), Vector3(-w, F, z0), Vector3(w, F, z0),
		Vector3(-w, g - 0.3, z0), Vector3(w, g - 0.3, z0)])
	v._collision(ip, f, Transform3D(Basis(), Vector3(xd, 0, 0)), Vector3.ZERO)

## Murs ronds (moulin à vent) : couronne de boîtes, ouverte à la porte.
static func _coque_ronde(v, ip: Interieur, s: Dictionary, r_int: float, F: float, haut: float, xd: float, larg: float) -> void:
	var n := 14
	var ep := 0.6
	var r := r_int + ep * 0.5
	var delta := asin(minf(0.95, (larg * 0.5 + 0.2) / r_int))      # demi-angle de la porte (+Z, xd ~ 0)
	var morceaux: Array = []
	for k in n:
		var kk := k - n if k > n / 2 else k      # angles dans [-PI, PI] : la porte est à 0
		var a0 := TAU * (kk - 0.5) / n
		var a1 := TAU * (kk + 0.5) / n
		for iv: Array in [[a0, a1]] if (a1 <= -delta or a0 >= delta) else [[a0, -delta], [delta, a1]]:
			if iv[1] - iv[0] > 0.02:
				morceaux.append(iv)
	for iv: Array in morceaux:
		var ang: float = (iv[0] + iv[1]) * 0.5
		var corde: float = 2.0 * (r_int + ep) * sin((iv[1] - iv[0]) * 0.5) + 0.04
		v._collision(ip, BoxShape3D.new(), Transform3D(Basis(Vector3.UP, ang), Vector3(sin(ang) * r, (haut + F) * 0.5, cos(ang) * r)), Vector3(corde, haut - F, ep))
	var h_lin := F + 2.0
	v._collision(ip, BoxShape3D.new(), Transform3D(Basis(), Vector3(xd, (h_lin + haut) * 0.5, r)), Vector3(2.0 * (r_int + ep) * sin(delta) + 0.1, haut - h_lin, ep))
	var _s := s

## Vantaux sur charnière (enfants du pivot, hors des lots fusionnés) : le vantail du bâtiment, qui s'ouvre vers l'intérieur.
static func _vantaux(v, p: Node3D, ip: Interieur, d: Dictionary) -> void:
	var n: Vector3 = d["n"]
	var tg := Vector3.UP.cross(n).normalized() * -1.0      # le long du seuil, vers la droite vue du dehors
	var c: Vector3 = d["c"]
	var larg: float = d["larg"]
	var haut: float = d["haut"]
	var nb: int = d.get("vantaux", 1)
	var lacet := atan2(n.x, n.z)
	for k in nb:
		var sg := 1.0 if k == 0 else -1.0
		var lv := larg / nb
		var h := Node3D.new()
		h.name = "Vantail"
		h.position = c - tg * sg * larg * 0.5
		p.add_child(h)
		var dir := tg * sg                                      # de la charnière vers le battant
		var ouvert := dir.signed_angle_to(-n, Vector3.UP) * 0.96
		ip.vantaux.append([h, ouvert])
		var centre := dir * lv * 0.5 - n * 0.02
		var q: String = d.get("q", "")
		if q != "" and PropsQuaternius.existe(q):
			var bq := PropsQuaternius.boite(q)
			VillageBatiQ.vantail(v, h, q, Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(Vector3(lv / bq.size.x, haut / bq.size.y, 1.0)), centre))
		elif d.has("dessin"):
			(d["dessin"] as Callable).call(h, k, Transform3D(Basis(Vector3.UP, lacet), centre))
		else:
			var b := Basis(Vector3.UP, lacet)
			v._boite(h, Vector3(lv - 0.04, haut, 0.08), Transform3D(b, centre + Vector3(0, haut * 0.5, 0)), v.m_poutres)
			for by in [0.25, haut * 0.75]:
				v._boite(h, Vector3(lv - 0.08, 0.12, 0.03), Transform3D(b, centre + Vector3(0, by, 0) + n * 0.05), v.m_fer)

# ================================================================================================================ plan (repère de l'intérieur)

## Traduit l'empreinte du pivot dans le repère de l'intérieur (porte en +Z) : fenêtres par mur, cheminée, toit.
static func _plan(s: Dictionary, ip: Interieur, ax: float, az: float, y_mur: float, axe_x: bool) -> Dictionary:
	var inv := ip.transform.affine_inverse()
	var dy := float(s["y_sol"]) - 0.4
	var fen: Array = []
	for f: Array in s.get("fenetres", []):
		var c: Vector3 = inv * (f[0] as Vector3)
		var mur := ""
		if absf(c.x) / ax > absf(c.z) / az:
			mur = "+X" if c.x > 0.0 else "-X"
		else:
			mur = "+Z" if c.z > 0.0 else "-Z"
		fen.append({"mur": mur, "t": c.z if mur.ends_with("X") else c.x, "y": c.y, "w": (f[1] as Vector2).x, "h": (f[1] as Vector2).y, "vraie": f[2]})
	var pl := {"id": s["id"], "fonction": String(donnees(s["id"]).get("fonction", s.get("fonction", "maison"))), "style": s.get("style", "planches"),
		"ax": ax, "az": az, "y_mur": y_mur, "faite_x": axe_x, "fenetres": fen, "lits": donnees(s["id"]).get("lits", []),
		"xd": (inv * (s["porte"]["c"] as Vector3)).x, "larg_porte": float(s["porte"]["larg"]), "haut_porte": maxf(float(s["porte"]["haut"]), 1.95),
		"rond": s.get("style", "") == "rond", "r_haut": float(s.get("rayon_haut", ax)) }
	if s.has("toit"):
		var t: Dictionary = s["toit"]
		pl["faite"] = float(t["faite"]) - dy - ECART_TOIT
		pl["pente"] = float(t["pente"])
	else:
		pl["plat"] = float(s.get("plat", y_mur + dy)) - dy
	if s.has("foyer"):
		var fo: Vector2 = s["foyer"]
		var c2: Vector3 = inv * Vector3(fo.x, 0, fo.y)
		pl["foyer"] = Vector2(c2.x, c2.z)
	return pl

# ================================================================================================================ aménagement

static func amenager(b: Interieurs, pl: Dictionary) -> void:
	var murs := Murs.new(pl)
	_doublure(b, pl)
	_sol(b, pl)
	_plafond(b, pl)
	match String(pl["fonction"]):
		"maison", "ferme":
			_maison(b, pl, murs, pl["fonction"] == "ferme")
		"auberge":
			_auberge(b, pl, murs)
		"grenier":
			_grenier(b, pl, murs)
		"moulin":
			_moulin(b, pl, murs)
		"tour":
			_tour(b, pl, murs)
		"grange":
			_grange(b, pl, murs, false)
		"etable":
			_grange(b, pl, murs, true)
		"moulin_vent":
			_moulin_vent(b, pl, murs)
		_:
			_maison(b, pl, murs, false)

# --- répartiteur le long des murs ------------------------------------------------------------------------------------

## Les quatre murs de la pièce (repère de l'intérieur) et leurs intervalles libres. Un meuble se pose contre un mur, dos au mur,
## face à la pièce ; `haut` = il monte au-dessus des appuis de fenêtre (étagère, râtelier) : il évite aussi les fenêtres.
class Murs:
	var ax: float
	var az: float
	var libres := {}      # mur -> [[a, b]] (bas) ; « haut » : [[a, b]] sans fenêtres
	var libres_hauts := {}
	var occupes: Array[Rect2] = []     # emprises au sol déjà prises (plan xz de la pièce)
	func occuper(c: Vector3, demi: Vector2) -> void:
		occupes.append(Rect2(c.x - demi.x, c.z - demi.y, demi.x * 2.0, demi.y * 2.0))
	func libre(r: Rect2) -> bool:
		for o in occupes:
			if o.intersects(r):
				return false
		return true
	func _init(pl: Dictionary) -> void:
		ax = pl["ax"]
		az = pl["az"]
		for m in ["-Z", "+X", "-X", "+Z"]:
			var demi: float = ax if m.ends_with("Z") else az
			libres[m] = [[-demi + 0.05, demi - 0.05]]
			libres_hauts[m] = [[-demi + 0.05, demi - 0.05]]
		# la porte et le débattement du vantail ; les murs latéraux près de la porte restent dégagés
		var xd: float = pl["xd"]
		var lp: float = pl["larg_porte"]
		retirer("+Z", xd - lp * 0.5 - 0.35, xd + lp * 0.5 + 0.35, true)
		for m in ["+X", "-X"]:
			if absf((ax if m == "+X" else -ax) - xd) < lp * 0.5 + MARGE_PORTE + 0.4:
				retirer(m, az - MARGE_PORTE, az, true)
		for f: Dictionary in pl["fenetres"]:
			retirer(f["mur"], f["t"] - f["w"] * 0.5 - 0.1, f["t"] + f["w"] * 0.5 + 0.1, false)
	func retirer(m: String, a: float, b: float, partout: bool) -> void:
		for dico in ([libres, libres_hauts] if partout else [libres_hauts]):
			var nouv: Array = []
			for iv: Array in dico[m]:
				if b <= iv[0] or a >= iv[1]:
					nouv.append(iv)
					continue
				if a > iv[0] + 0.05:
					nouv.append([iv[0], a])
				if b < iv[1] - 0.05:
					nouv.append([b, iv[1]])
			dico[m] = nouv
	## Réserve `long` m sur le mur `m` (côté `pref` : -1 début, +1 fin, 0 milieu) ; renvoie {pos (centre au sol), lacet, n} ou {}.
	## La place doit aussi être libre au SOL (`occupes`) : un meuble déjà posé contre le mur voisin occupe le coin, on glisse le
	## long du mur (pas de 5 cm, du côté préféré vers l'autre) jusqu'à la première place qui ne le chevauche pas.
	func poser(m: String, long: float, prof: float, haut := false, pref := 0.0) -> Dictionary:
		var liste: Array = (libres_hauts if haut else libres)[m]
		var choix: Array = []
		var best := INF
		for iv: Array in liste:
			if iv[1] - iv[0] < long:
				continue
			var lo: float = iv[0] + long * 0.5
			var hi: float = iv[1] - long * 0.5
			var t0: float
			if pref < 0.0:
				t0 = lo
			elif pref > 0.0:
				t0 = hi
			else:
				t0 = clampf(0.0, lo, hi)
			var cands: Array = [t0]
			var k := 1
			while t0 - k * 0.05 >= lo - 0.001 or t0 + k * 0.05 <= hi + 0.001:
				for t: float in [t0 + k * 0.05, t0 - k * 0.05]:
					if t >= lo - 0.001 and t <= hi + 0.001:
						cands.append(clampf(t, lo, hi))
				k += 1
			for t: float in cands:
				var e := _emprise(m, t, long, prof)
				if not libre(Rect2(e[0].x - e[1].x, e[0].z - e[1].y, e[1].x * 2.0, e[1].y * 2.0)):
					continue
				var cout := absf(t - pref * 9.0)
				if cout < best:
					best = cout
					choix = [t]
				break
		if choix.is_empty():
			return {}
		var t: float = choix[0]
		retirer(m, t - long * 0.5 - 0.04, t + long * 0.5 + 0.04, true)
		var n := normale(m)
		var e := _emprise(m, t, long, prof)
		occuper(e[0], e[1])
		return {"pos": e[0], "lacet": atan2(n.x, n.z), "n": n, "t": t}
	## Centre au sol et demi-emprise (plan xz) d'un meuble de `long` × `prof` posé contre le mur `m` à l'abscisse `t`.
	func _emprise(m: String, t: float, long: float, prof: float) -> Array:
		var n := normale(m)
		var plan := (az if m.ends_with("Z") else ax)
		var c := Vector3(t, 0, -plan) if m == "-Z" else (Vector3(t, 0, plan) if m == "+Z" else (Vector3(plan, 0, t) if m == "+X" else Vector3(-plan, 0, t)))
		c = Vector3(c.x, 0, c.z) + n * (prof * 0.5 + 0.03)
		var demi := Vector2(long * 0.5, prof * 0.5) if m.ends_with("Z") else Vector2(prof * 0.5, long * 0.5)
		return [c, demi]
	static func normale(m: String) -> Vector3:
		match m:
			"-Z": return Vector3.BACK
			"+Z": return Vector3.FORWARD
			"+X": return Vector3.LEFT
		return Vector3.RIGHT
	## Un mur, puis les autres dans l'ordre donné, jusqu'à trouver de la place.
	func poser_ou(ordre: Array, long: float, prof: float, haut := false, pref := 0.0) -> Dictionary:
		for m in ordre:
			var r := poser(m, long, prof, haut, pref)
			if not r.is_empty():
				return r
		return {}

# --- doublure des murs ----------------------------------------------------------------------------------------------

## Doublure : quatre murs (ou un tronc de cône à pans) dans la matière du style, percés de la porte et des fenêtres, avec
## leurs embrasures ; au-dessus des murs longs, la doublure monte jusqu'au lambris (pignons en triangle).
static func _doublure(b: Interieurs, pl: Dictionary) -> void:
	var F := Interieurs.F
	var style: String = pl["style"]
	if pl["rond"]:
		_doublure_ronde(b, pl)
		return
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	var yk := _y_lambris(pl, ax if not pl["faite_x"] else az) if pl.has("faite") else float(pl["plat"])
	for m in ["-Z", "+Z", "+X", "-X"]:
		var demi: float = az if m.ends_with("X") else ax
		var trous: Array = []
		if m == "+Z":
			trous.append([pl["xd"] - pl["larg_porte"] * 0.5, pl["xd"] + pl["larg_porte"] * 0.5, F - 0.05, F + float(pl["haut_porte"]) - 0.05])
		for f: Dictionary in pl["fenetres"]:
			if f["mur"] == m:
				trous.append([f["t"] - f["w"] * 0.5, f["t"] + f["w"] * 0.5, f["y"] - f["h"] * 0.5, f["y"] + f["h"] * 0.5])
		# hauteur du mur : jusqu'au lambris (murs gouttereaux) ou jusqu'au pied du pignon
		var y_haut := yk
		if pl.has("faite"):
			var gouttereau: bool = (m.ends_with("Z")) == bool(pl["faite_x"])
			y_haut = yk if gouttereau else yk
		_pan_mur(b, m, demi, F - 0.04, y_haut, trous, style, pl)
		if pl.has("faite") and (m.ends_with("Z")) != bool(pl["faite_x"]):
			_pignon_int(b, pl, m, yk)
	# embrasures et cadres
	for f: Dictionary in pl["fenetres"]:
		_fenetre(b, pl, f)
	_cadre_porte(b, pl)

## Hauteur du plafond (lambris ou plafond plat) au-dessus du point `p` de la pièce.
static func _y_plafond_en(pl: Dictionary, p: Vector3) -> float:
	if not pl.has("faite"):
		return float(pl["plat"])
	return _y_lambris(pl, p.z if pl["faite_x"] else p.x)

## Hauteur du lambris à la distance `d` du faîte.
static func _y_lambris(pl: Dictionary, d: float) -> float:
	return float(pl["faite"]) - absf(d) * float(pl["pente"])

## Repère d'un mur : origine sur la face intérieure (y 0), +X le long du mur, +Z vers la pièce.
static func _repere_mur(m: String, pl: Dictionary) -> Transform3D:
	var n := Murs.normale(m)
	var plan: float = pl["az"] if m.ends_with("Z") else pl["ax"]
	return Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), -n * plan)

## Lacet du repère d'un mur (face vers la pièce) ; pas get_euler, ambigu pour un demi-tour.
static func _lacet_mur(m: String) -> float:
	var n := Murs.normale(m)
	return atan2(n.x, n.z)

## Coordonnée le long du mur (repère de la pièce) -> abscisse du repère du mur.
static func _t_mur(m: String, t: float) -> float:
	match m:
		"-Z": return t
		"+Z": return -t
		"+X": return t
	return -t

static func _pan_mur(b: Interieurs, m: String, demi: float, y0: float, y1: float, trous: Array, style: String, pl: Dictionary) -> void:
	var xf := _repere_mur(m, pl)
	var lacet := _lacet_mur(m)
	var tt: Array = []
	for t: Array in trous:
		var u0 := _t_mur(m, t[0])
		var u1 := _t_mur(m, t[1])
		tt.append([minf(u0, u1), maxf(u0, u1), t[2], t[3]])
	var bords := [-demi - EP_DOUBLURE, demi + EP_DOUBLURE]
	for t in tt:
		bords.append(t[0])
		bords.append(t[1])
	bords.sort()
	var mat := _mat_mur(style, m)
	var rondins := style == "rondins"
	for i in bords.size() - 1:
		var u0: float = bords[i]
		var u1: float = bords[i + 1]
		if u1 - u0 < 0.01:
			continue
		var um := (u0 + u1) * 0.5
		var morceaux := [[y0, y1]]
		for t in tt:
			if um > t[0] and um < t[1]:
				var nouv := []
				for mo in morceaux:
					if t[3] <= mo[0] or t[2] >= mo[1]:
						nouv.append(mo)
						continue
					if t[2] > mo[0] + 0.01:
						nouv.append([mo[0], t[2]])
					if t[3] < mo[1] - 0.01:
						nouv.append([t[3], mo[1]])
				morceaux = nouv
		for mo in morceaux:
			var c := xf * Vector3(um, (mo[0] + mo[1]) * 0.5, -EP_DOUBLURE * 0.5)
			if rondins:
				b.bx(c, Vector3(u1 - u0, mo[1] - mo[0], EP_DOUBLURE), "bois_suie", lacet)
				_rondins_mur(b, xf, lacet, u0, u1, mo[0], mo[1], m)
			else:
				b.bx(c, Vector3(u1 - u0, mo[1] - mo[0], EP_DOUBLURE), mat, lacet)
	if (style == "pierre" or style == "tour") and m != "+Z":
		# soubassement de moellons au pied (la pierre unie ne lit pas comme un mur)
		b.pile(xf * Vector3(0, y0 + 0.22, 0.02), Vector3(demi * 2.0 - 0.1, 0.4, 0.14), int(absf(xf.origin.x * 37.0 + xf.origin.z * 11.0)) + 9100, "brute", false, 0.0, lacet)
	# plinthe et lisse haute de bois sombre (les murs ne restent jamais nus)
	if not rondins and style != "pierre" and style != "tour":
		var coupe: Array = []
		for t in tt:
			if t[2] < y0 + 0.2:      # la porte coupe la plinthe
				coupe = [-demi, t[0], t[1], demi]
		if not coupe.is_empty():
			for k in [0, 2]:
				var ua: float = coupe[k]
				var ub: float = coupe[k + 1]
				if ub - ua > 0.05:
					b.bx(xf * Vector3((ua + ub) * 0.5, y0 + 0.08, 0.02), Vector3(ub - ua, 0.12, 0.04), "bois_sombre", lacet)
		else:
			b.bx(xf * Vector3(0, y0 + 0.08, 0.02), Vector3(demi * 2.0, 0.12, 0.04), "bois_sombre", lacet)

## Rondins couchés sur la doublure sombre (rangs de 25 cm), coupés aux ouvertures ; trois bois (graine).
static func _rondins_mur(b: Interieurs, xf: Transform3D, lacet: float, u0: float, u1: float, y0: float, y1: float, m: String) -> void:
	var y := ceilf((y0 - Interieurs.F) / 0.25) * 0.25 + Interieurs.F + 0.13
	var k := 0
	while y + 0.12 <= y1 + 0.02:
		var g: int = int(absf(u0 * 13.0) + y * 31.0) + k + int({"-Z": 1, "+Z": 2, "+X": 3, "-X": 4}[m]) * 1000
		b.rondin(xf * Vector3((u0 + u1) * 0.5, y, 0.04), lacet, u1 - u0 + 0.02, 0.125, g, "rondin", 0.0, 0.006)
		y += 0.25
		k += 1

static func _mat_mur(style: String, m: String) -> String:
	match style:
		"rondins":
			return "bois_suie"
		"pierre", "tour":
			return "pierre_mur"
		"kit":
			return "bois_v" if m.ends_with("Z") else "bois_clair"
		"torchis":
			return "seche"
	return "bois_v"

## Triangle de pignon (doublure) au-dessus du mur `m`, sous les deux pans du lambris.
static func _pignon_int(b: Interieurs, pl: Dictionary, m: String, yk: float) -> void:
	var xf := _repere_mur(m, pl)
	var demi: float = pl["ax"] if m.ends_with("Z") else pl["az"]      # longueur du mur (pas la distance de son plan)
	var yr := float(pl["faite"])
	if yr <= yk + 0.05:
		return
	var n := Murs.normale(m)
	var pts := [xf * Vector3(-demi - EP_DOUBLURE, yk, -0.01), xf * Vector3(demi + EP_DOUBLURE, yk, -0.01), xf * Vector3(0, yr + 0.02, -0.01)]
	b.poly("bois_sombre", pts, n)
	b.bx(xf * Vector3(0, (yk + yr) * 0.5, 0.05), Vector3(0.12, yr - yk, 0.1), "bois_sombre", _lacet_mur(m))     # poinçon de pignon

## Embrasure d'une fenêtre : jambages, linteau, appui ; vraie fenêtre = ouverte sur le vitrage du dehors (lumière froide), sinon
## volets clos de planches (les murs du dehors y sont pleins).
static func _fenetre(b: Interieurs, pl: Dictionary, f: Dictionary) -> void:
	var m: String = f["mur"]
	var xf := _repere_mur(m, pl)
	var lacet := _lacet_mur(m)
	var u := _t_mur(m, f["t"])
	var w: float = f["w"]
	var h: float = f["h"]
	var y: float = f["y"]
	var prof := 0.2
	for sx in [-1.0, 1.0]:
		b.bx(xf * Vector3(u + sx * (w * 0.5 + 0.04), y, -prof * 0.5 + 0.03), Vector3(0.09, h + 0.18, prof + 0.06), "bois_sombre", lacet)
	b.bx(xf * Vector3(u, y + h * 0.5 + 0.05, -prof * 0.5 + 0.03), Vector3(w + 0.16, 0.1, prof + 0.06), "bois_sombre", lacet)
	b.bx(xf * Vector3(u, y - h * 0.5 - 0.035, -prof * 0.5 + 0.07), Vector3(w + 0.24, 0.07, prof + 0.16), "bois", lacet)
	if f["vraie"]:
		if b._froids < Interieurs.MAX_FROIDS:
			b._froids += 1
			b.lumiere(xf * Vector3(u, y - 0.1, 0.75), 1.0, 4.2, Interieurs.FROID, 1.6, false)
	else:
		for sx in [-1.0, 1.0]:
			b.bx(xf * Vector3(u + sx * w * 0.25, y, -0.03), Vector3(w * 0.5 - 0.02, h, 0.04), "bois_v", lacet)
		b.bx(xf * Vector3(u, y + h * 0.18, 0.0), Vector3(w, 0.06, 0.03), "bois_sombre", lacet)
		b.bx(xf * Vector3(u, y - h * 0.22, 0.0), Vector3(w, 0.06, 0.03), "bois_sombre", lacet)
		b.bx(xf * Vector3(u + w * 0.18, y, 0.025), Vector3(0.05, 0.12, 0.03), "fer", lacet)

static func _cadre_porte(b: Interieurs, pl: Dictionary) -> void:
	var F := Interieurs.F
	var xf := _repere_mur("+Z", pl)
	var lacet := _lacet_mur("+Z")
	var u := _t_mur("+Z", pl["xd"])
	var w: float = pl["larg_porte"]
	var h: float = float(pl["haut_porte"]) - 0.05
	for sx in [-1.0, 1.0]:
		b.bx(xf * Vector3(u + sx * (w * 0.5 + 0.05), F + h * 0.5, -0.04), Vector3(0.12, h, 0.2), "bois_sombre", lacet)
	b.bx(xf * Vector3(u, F + h + 0.06, -0.04), Vector3(w + 0.34, 0.14, 0.22), "bois_sombre", lacet)
	b.bx(xf * Vector3(u, F - 0.01, -0.12), Vector3(w + 0.1, 0.05, 0.3), "bois_sombre", lacet)      # seuil

## Doublure ronde (moulin à vent) : pans de pierre en tronc de cône, porte, deux meurtrières.
static func _doublure_ronde(b: Interieurs, pl: Dictionary) -> void:
	var F := Interieurs.F
	var r0: float = pl["ax"] + EP_DOUBLURE * 0.5
	var r1: float = float(pl["r_haut"])
	var y1 := float(pl["plat"])
	var n := 12
	var xd: float = pl["xd"]
	var lp: float = pl["larg_porte"]
	for k in n:
		var ang := TAU * k / n
		var c := Vector3(sin(ang), 0, cos(ang))
		var corde := 2.0 * r0 * tan(PI / n) + 0.06
		var bas := F - 0.04
		if c.z > 0.5 and absf(c.x * r0 - xd) < lp * 0.5 + 0.2:
			bas = F + float(pl["haut_porte"]) - 0.05
		var rm := lerpf(r0, r1, ((bas + y1) * 0.5 - F) / maxf(y1 - F, 0.1))
		var incl := atan2(r0 - r1, y1 - F)
		b.bx(c * (rm + EP_DOUBLURE * 0.5) + Vector3(0, (bas + y1) * 0.5, 0), Vector3(corde, (y1 - bas) / cos(incl), EP_DOUBLURE), "pierre", ang, false, Vector3(-incl, 0, 0))
	var u := Vector3(xd, 0, r0)
	for sx in [-1.0, 1.0]:
		b.bx(u + Vector3(sx * (lp * 0.5 + 0.06), F + 1.0, -0.06), Vector3(0.12, 2.0, 0.18), "bois_sombre")
	b.bx(u + Vector3(0, F + float(pl["haut_porte"]) + 0.02, -0.06), Vector3(lp + 0.34, 0.14, 0.2), "bois_sombre")

# --- sol et plafond ----------------------------------------------------------------------------------------------------

static func _sol(b: Interieurs, pl: Dictionary) -> void:
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	var zone := Rect2(-ax - EP_DOUBLURE, -az - EP_DOUBLURE, (ax + EP_DOUBLURE) * 2.0, (az + EP_DOUBLURE) * 2.0)
	if pl["rond"]:
		b.cyl(Vector3(0, Interieurs.F - 0.04, 0), ax + EP_DOUBLURE, 0.08, "pierre_sombre", 12)
		return
	match String(pl["fonction"]):
		"grange", "etable":
			b.plancher(zone, "terre")
		"tour", "moulin_vent":
			b.dallage(zone, "pierre_sombre", Interieurs.F, Interieurs.F - 0.08)
		_:
			b.plancher(zone, "bois")

static func _plafond(b: Interieurs, pl: Dictionary) -> void:
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	if pl.has("plat"):
		var y := float(pl["plat"])
		var rond: bool = pl["rond"]
		var r := float(pl["r_haut"]) + EP_DOUBLURE
		var sx := r if rond else ax + EP_DOUBLURE
		var sz := r if rond else az + EP_DOUBLURE
		if rond:
			b.cyl(Vector3(0, y + 0.03, 0), r, 0.06, "bois_sombre", 12)
		else:
			b.bx(Vector3(0, y + 0.03, 0), Vector3(sx * 2.0, 0.06, sz * 2.0), "bois_sombre")
		var x := -sx + 0.3
		while x < sx - 0.1:
			var lz := sz * 2.0 if not rond else 2.0 * sqrt(maxf(r * r - x * x, 0.01)) - 0.1
			b.bx(Vector3(x, y - 0.07, 0), Vector3(0.14, 0.14, lz), "bois_sombre")     # solives
			x += 0.7
		b.rondin(Vector3(0, y - 0.24, 0), PI * 0.5, sz * 2.0 - (0.15 if rond else 0.0), 0.15, 7700, "rondin_sombre")   # poutre maîtresse
		return
	# lambris sous charpente : faîte le long de X (ou Z) de la pièce
	var fx: bool = pl["faite_x"]
	var dl: float = (ax if fx else az) + EP_DOUBLURE
	var dp: float = (az if fx else ax) + EP_DOUBLURE
	var yk := _y_lambris(pl, dp)
	var yr := float(pl["faite"])
	var P := func(l: float, pp: float, y: float) -> Vector3: return Vector3(l, y, pp) if fx else Vector3(pp, y, l)
	for cote in [-1.0, 1.0]:
		var a: Vector3 = P.call(-dl, cote * dp, yk)
		var bb: Vector3 = P.call(dl, cote * dp, yk)
		var c: Vector3 = P.call(dl, 0.0, yr)
		var d: Vector3 = P.call(-dl, 0.0, yr)
		var n := (bb - a).cross(c - a).normalized()
		if n.y > 0.0:
			n = -n
		b.quad("bois_sombre", a, bb, c, d, n)
		# nervures
		var l := -dl + 0.3
		while l < dl:
			var p0: Vector3 = P.call(l, cote * (dp - 0.05), yk - 0.04)
			var p1: Vector3 = P.call(l, cote * 0.08, yr - 0.04)
			_piece(b, p0, p1, Vector2(0.07, 0.06), "bois_sombre")
			l += 0.9
	# faîtage, entraits, poinçons
	var dir_l: Vector3 = P.call(1.0, 0.0, 0.0)
	b.rondin(P.call(0.0, 0.0, yr - 0.12), 0.0 if fx else PI * 0.5, dl * 2.0 - 0.1, 0.13, 7701, "rondin_sombre")
	var y_e := minf(maxf(float(pl["y_mur"]) - 0.08, Interieurs.F + 2.3), yk - 0.14)      # entraits au-dessus de la tête
	var nf := maxi(2, roundi(dl * 2.0 / 2.6))
	for i in nf:
		var l := -dl + dl * 2.0 * (i + 0.5) / nf
		b.rondin(P.call(l, 0.0, y_e), PI * 0.5 if fx else 0.0, dp * 2.0 - 0.06, 0.11, 7710 + i, "rondin_sombre")
		b.cyl(P.call(l, 0.0, (y_e + yr - 0.2) * 0.5), 0.07, yr - 0.2 - y_e, "rondin_sombre", 6)
	# sablières hautes
	for cote in [-1.0, 1.0]:
		b.bx(P.call(0.0, cote * (dp - 0.08), yk - 0.05), (Vector3(dl * 2.0, 0.12, 0.14) if fx else Vector3(0.14, 0.12, dl * 2.0)), "bois_sombre")
	var _d := dir_l

## Pièce de bois droite de `a` à `b` (section `ep`).
static func _piece(b: Interieurs, a: Vector3, c: Vector3, ep: Vector2, mat: String) -> void:
	var d := c - a
	var lg := d.length()
	if lg < 0.01:
		return
	var zz := d / lg
	var xx := Vector3.UP.cross(zz)
	if xx.length() < 0.01:
		xx = Vector3.RIGHT
	xx = xx.normalized()
	var yy := zz.cross(xx)
	b.v._boite(b._p(), Vector3(ep.x, ep.y, lg), Transform3D(Basis(xx, yy, zz), (a + c) * 0.5), b.M[mat])

# --- briques de mobilier ----------------------------------------------------------------------------------------------

## Lit prévu par les données (n-ième), contre un mur : un emplacement « emplacement_lit » (le lit est posé par le sommeil).
## Place réservée : celle du lit du système de sommeil (2,1 × 1 m, 1,6 en double) et un peu de jeu ; les lits des habitants
## d'abord (les données les listent en tête), le lit libre seulement s'il reste un pan de mur pour lui.
static func _lits(b: Interieurs, pl: Dictionary, murs: Murs, ordre: Array) -> Array:
	var poses: Array = []
	var i := 0
	for l: Dictionary in pl["lits"]:
		var double := int(l.get("largeur", 1)) >= 2
		var larg := 1.45 if double else 0.95
		var res := 1.68 if double else 1.08
		var r := murs.poser_ou(ordre, 2.2, res, false, -1.0 if i % 2 == 0 else 1.0)
		if r.is_empty():
			r = murs.poser_ou(["-Z", "+X", "-X"], res + 0.05, 2.2, false, 0.0)
			if r.is_empty():
				continue
			# perpendiculaire au mur : tête contre le mur
			var n2: Vector3 = r["n"]
			b.lit(Vector3(r["pos"].x, Interieurs.F, r["pos"].z), atan2(-n2.z, n2.x), 2.0, larg, ["peau", "peau_claire", "peau_sombre"][i % 3], i % 2, String(l.get("proprietaire", "")))
		else:
			var n: Vector3 = r["n"]
			var tg := Vector3(n.z, 0, -n.x)
			b.lit(Vector3(r["pos"].x, Interieurs.F, r["pos"].z), atan2(-tg.z, tg.x), 2.0, larg, ["peau", "peau_claire", "peau_sombre"][i % 3], i % 2, String(l.get("proprietaire", "")))
		poses.append(r)
		i += 1
	return poses

## Foyer-cheminée contre la cheminée du dehors (colonne de pierre, niche, braises, flamme, crémaillère, marmite), ou foyer
## ouvert au milieu de la pièce (cercle de pierres) quand il n'y a pas de cheminée.
static func _foyer(b: Interieurs, pl: Dictionary, murs: Murs) -> Vector3:
	var F := Interieurs.F
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	if pl.has("foyer"):
		var fo: Vector2 = pl["foyer"]
		# colonne collée au mur le plus proche du pied de la cheminée
		var dists := {"-Z": absf(fo.y + az), "+Z": absf(az - fo.y), "+X": absf(ax - fo.x), "-X": absf(fo.x + ax)}
		var m := "-Z"
		for k in dists:
			if k != "+Z" and dists[k] < dists[m]:
				m = k
		var t := fo.y if m.ends_with("X") else fo.x
		var demi_m: float = az if m.ends_with("X") else ax
		t = clampf(t, -demi_m + 0.8, demi_m - 0.8)
		var n := Murs.normale(m)
		murs.retirer(m, t - 0.85, t + 0.85, true)
		var base := Vector3(t, 0, -az) if m == "-Z" else (Vector3(ax, 0, t) if m == "+X" else Vector3(-ax, 0, t))
		var lacet := atan2(n.x, n.z)
		var bz := Basis(Vector3.UP, lacet)
		var h := minf(_y_plafond_en(pl, base), 3.2)
		var g := 8800 + int(absf(t) * 10.0)
		var c := base + n * 0.38
		b.pile(c + Vector3(0, (F + h) * 0.5, 0) - n * 0.2, Vector3(1.3, h - F, 0.42), g, "pierre", false, 0.0, lacet)
		var y_haut := _y_plafond_en(pl, base + n * 0.4)
		if y_haut > h + 0.1:      # gaine jusqu'au lambris (le fût du dehors en sort)
			b.pile(c + Vector3(0, (h + y_haut) * 0.5, 0) - n * 0.05, Vector3(0.85, y_haut - h + 0.1, 0.62), g + 31, "pierre", false, 0.0, lacet)
		for sx in [-1.0, 1.0]:
			b.pile(c + bz * Vector3(sx * 0.5, 0, 0.1) + Vector3(0, (F + 0.95) * 0.5 + 0.02, 0), Vector3(0.3, 0.95 - F + 0.02, 0.5), g + int(sx) + 3, "pierre", false, 0.0, lacet)
		b.pile(c + bz * Vector3(0, 0, 0.1) + Vector3(0, (0.95 + h) * 0.5, 0), Vector3(1.3, h - 0.95, 0.5), g + 7, "pierre", false, 0.0, lacet)
		b.bx(c + bz * Vector3(0, 0, 0.36) + Vector3(0, 0.95, 0), Vector3(1.32, 0.12, 0.12), "bois_sombre", lacet)       # linteau
		b.solide(c + bz * Vector3(0, 0, 0.05) + Vector3(0, (F + h) * 0.5, 0), Vector3(1.3, h - F, 0.75), lacet)
		b.bx(c + bz * Vector3(0, 0, 0.12) + Vector3(0, F + 0.06, 0), Vector3(0.7, 0.1, 0.5), "cendre", lacet)
		b.bx(c + bz * Vector3(0, 0, 0.12) + Vector3(0, F + 0.12, 0), Vector3(0.5, 0.02, 0.36), "braises", lacet)
		b.rondin(c + bz * Vector3(-0.1, 0, 0.12) + Vector3(0, F + 0.2, 0), lacet + PI * 0.5 + 0.2, 0.55, 0.06, g + 21, "rondin_sombre")
		b.rondin(c + bz * Vector3(0.1, 0, 0.1) + Vector3(0, F + 0.2, 0), lacet + PI * 0.5 - 0.25, 0.55, 0.055, g + 22, "rondin_sombre")
		b.flamme(c + bz * Vector3(0, 0, 0.14) + Vector3(0, F + 0.15, 0), 1.4)
		b.lit_braises(c + bz * Vector3(0, 0, 0.12) + Vector3(0, F + 0.14, 0), Vector2(0.55, 0.42))
		var atre := c + n * 0.8
		murs.occuper(base + n * 0.85, Vector2(0.9, 0.9))
		b.dallage(Rect2(atre.x - 0.75, atre.z - 0.55, 1.5, 1.1) if absf(n.z) > 0.5 else Rect2(atre.x - 0.55, atre.z - 0.75, 1.1, 1.5), "pierre_sombre", F + 0.03)
		b.halo(Vector3(atre.x, F + 0.05, atre.z), Vector3.UP, 3.0, 3.0, Color(1, 0.9, 0.8, 1))
		b.lumiere(atre + Vector3(0, F + 1.0, 0), 2.6, 7.0)
		b.chaudron(c + n * 0.5 + bz * Vector3(0.5, 0, 0) + Vector3(0, F, 0), 0.2)
		b.buches(c + bz * Vector3(-1.2, 0, 0.25), lacet)
		return atre
	# foyer ouvert (langeld) : cercle de pierres au centre, braises, flamme basse
	var p := Vector3(0, 0, -az * 0.25)
	for k in 9:
		var a := TAU * k / 9.0
		b.bloc(Vector3(0.24, 0.16, 0.2), 8900 + k, p + Vector3(sin(a) * 0.5, F + 0.07, cos(a) * 0.4), "brute", a)
	b.bx(p + Vector3(0, F + 0.03, 0), Vector3(0.8, 0.04, 0.6), "cendre")
	b.bx(p + Vector3(0, F + 0.06, 0), Vector3(0.55, 0.02, 0.4), "braises")
	b.rondin(p + Vector3(0, F + 0.13, 0), 0.4, 0.6, 0.06, 8911, "rondin_sombre")
	b.flamme(p + Vector3(0, F + 0.1, 0), 1.3)
	b.lit_braises(p + Vector3(0, F + 0.07, 0), Vector2(0.6, 0.45))
	b.halo(p + Vector3(0, F + 0.05, 0), Vector3.UP, 3.0, 3.0, Color(1, 0.9, 0.8, 1))
	b.lumiere(p + Vector3(0, F + 0.9, 0), 2.3, 6.5)
	b.solide(p + Vector3(0, F + 0.2, 0), Vector3(1.1, 0.4, 0.9))
	b.cyl(p + Vector3(0.75, F + 0.55, 0), 0.025, 1.1, "fer_noir", 4)
	murs.occuper(p, Vector2(0.95, 0.85))
	return p + Vector3(0, 0, 0.9)

## Table et bancs au milieu de la pièce (le long du grand axe), couverts, pain, bougie.
static func _table(b: Interieurs, pl: Dictionary, centre: Vector3, long := 1.8, festin := false) -> void:
	var F := Interieurs.F
	var fx: bool = float(pl["ax"]) >= float(pl["az"])
	var lacet := 0.0 if fx else PI * 0.5
	var bz := Basis(Vector3.UP, lacet)
	b.table(centre, long, 0.8, lacet)
	for sz in [-1.0, 1.0]:
		b.banc(centre + bz * Vector3(0, 0, sz * 0.72), long - 0.3, lacet)
	var y := F + 0.78
	b.nappe(Vector3(centre.x, y, centre.z), Vector2(0.9, 0.5) if fx else Vector2(0.5, 0.9), lacet, true)
	b.nq("q_pain", Vector3(centre.x, y + 0.024, centre.z), 0.3)
	b.mets(Vector3(centre.x, y, centre.z) + bz * Vector3(-0.55, 0, 0.18), lacet)
	b.mets(Vector3(centre.x, y, centre.z) + bz * Vector3(0.55, 0, -0.18), lacet + PI, true)
	b.chope(Vector3(centre.x, y, centre.z) + bz * Vector3(0.3, 0, 0.22))
	b.cruche(Vector3(centre.x, y, centre.z) + bz * Vector3(-0.2, 0, -0.2), 0.26)
	b.bougie(Vector3(centre.x, y, centre.z) + bz * Vector3(0.12, 0, -0.05), 0.13)
	if festin:
		b.fromage(Vector3(centre.x, y + 0.024, centre.z) + bz * Vector3(0.25, 0, 0.05))
		b.nq("q_cuisse", Vector3(centre.x, y + 0.024, centre.z) + bz * Vector3(-0.25, 0, 0.02), 0.6)

## Étagère garnie (pots, bols, cruches, nourriture) contre un mur.
static func _etagere(b: Interieurs, r: Dictionary, larg := 1.4, garniture := "cuisine") -> void:
	if r.is_empty():
		return
	var F := Interieurs.F
	var p: Vector3 = r["pos"]
	var lacet: float = r["lacet"]
	var bz := Basis(Vector3.UP, lacet)
	b.etagere(Vector3(p.x, F, p.z), lacet, larg, 1.9, 4, 0.32)
	for i in 3:
		var y := F + b.niv(i) + 0.01
		for k in 3:
			var q := Vector3(p.x, y, p.z) + bz * Vector3((k - 1) * larg * 0.3, 0, 0.02)
			match garniture:
				"cuisine":
					if (i + k) % 3 == 0:
						b.cruche(q, 0.22)
					elif (i + k) % 3 == 1:
						b.bol(q)
					else:
						b.assiette(q, "argile" if k % 2 == 0 else "etain")
				"reserve":
					if (i + k) % 2 == 0:
						b.nq("q_pain", q, k * 0.7)
					else:
						b.nq("q_pomme" if k % 2 == 0 else "q_navet", q, k)
						b.nq("q_pomme_verte" if k % 2 == 0 else "q_carotte", q + bz * Vector3(0.07, 0, 0.04), k + 1)
				"atelier":
					if (i + k) % 2 == 0:
						b.q("q_seau_bois", q, k, 0.7)
					else:
						b.cruche(q, 0.2)

static func _coffre_pres(b: Interieurs, r: Dictionary, decal: float) -> void:
	if r.is_empty():
		return
	var n: Vector3 = r["n"]
	var tg := Vector3(n.z, 0, -n.x)
	var p: Vector3 = r["pos"] + tg * decal
	b.coffre(Vector3(p.x, Interieurs.F, p.z), r["lacet"], Vector3(0.85, 0.46, 0.5))

static func _tonneaux(b: Interieurs, r: Dictionary, n := 2) -> void:
	if r.is_empty():
		return
	var nn: Vector3 = r["n"]
	var tg := Vector3(nn.z, 0, -nn.x)
	for k in n:
		b.tonneau((r["pos"] as Vector3) + tg * (k - (n - 1) * 0.5) * 0.72, 0.85, 0.32)

static func _sacs(b: Interieurs, r: Dictionary, n := 3) -> void:
	if r.is_empty():
		return
	var nn: Vector3 = r["n"]
	var tg := Vector3(nn.z, 0, -nn.x)
	for k in n:
		b.sac((r["pos"] as Vector3) + tg * (k - (n - 1) * 0.5) * 0.45 + Vector3(0, Interieurs.F, 0), float(k) * 0.9 + 0.3, 0.5 + 0.06 * (k % 2))

## Applique murale au-dessus d'un meuble (au plus une lumière par pièce : budget de 8 lumières).
static func _applique(b: Interieurs, pl: Dictionary, m: String, t: float, avec_lumiere := true) -> void:
	var n := Murs.normale(m)
	var plan: float = pl["az"] if m.ends_with("Z") else pl["ax"]
	var p := (Vector3(t, 0, -plan) if m == "-Z" else (Vector3(t, 0, plan) if m == "+Z" else (Vector3(plan, 0, t) if m == "+X" else Vector3(-plan, 0, t))))
	b.applique(p + Vector3(0, 1.75 + Interieurs.F, 0), atan2(n.x, n.z), 1.3, 4.5, avec_lumiere)

## Viande séchée et herbes pendues aux entraits (lambris) ou aux solives (plafond plat).
static func _suspendus(b: Interieurs, pl: Dictionary, n := 3) -> void:
	var y := (minf(float(pl["y_mur"]), _y_lambris(pl, float(pl["az"]))) if pl.has("faite") else float(pl["plat"])) - 0.2
	var ax: float = pl["ax"]
	for k in n:
		var x := -ax * 0.6 + ax * 1.2 * (k + 0.5) / n
		if k % 2 == 0:
			b.viande_seche(Vector3(x, y, -float(pl["az"]) * 0.45), 3)
		else:
			b.herbes(Vector3(x, y, -float(pl["az"]) * 0.45), 0.3 * k)

# --- fonctions -----------------------------------------------------------------------------------------------------

static func _maison(b: Interieurs, pl: Dictionary, murs: Murs, ferme: bool) -> void:
	var F := Interieurs.F
	var atre := _foyer(b, pl, murs)
	var lits := _lits(b, pl, murs, ["-X", "+X", "-Z"])
	for i in lits.size():
		var r: Dictionary = lits[i]
		if r.has("n"):
			_coffre_pres(b, murs.poser_ou([_mur_de(r)], 0.9, 0.5, false, 0.0), 0.0)
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	_etagere(b, murs.poser_ou(["-Z", "+X", "-X"], 1.45, 0.34, true), 1.4, "cuisine")
	_tonneaux(b, murs.poser_ou(["-Z", "+X", "-X", "+Z"], 1.5, 0.7, false, 1.0), 2)
	_sacs(b, murs.poser_ou(["+Z", "-X", "+X"], 1.4, 0.45, false, 1.0), 3 if ferme else 2)
	var rm := murs.poser_ou(["+X", "-X", "-Z"], 1.0, 0.1, true)
	if not rm.is_empty():
		b.peau_murale((rm["pos"] as Vector3) + Vector3(0, 1.65, 0), rm["lacet"], 0.9, 1.1, "peau_claire")
	# table au milieu de ce qui reste, hors du couloir d'entrée (vantail ouvert, premiers pas dans la pièce)
	var lt := clampf(ax * 0.55, 1.4, 2.2)
	var centre := _centre_table(pl, murs, lt)
	if centre.x < INF:
		_table(b, pl, centre, lt)
		b.peau_sol(Vector3(centre.x, 0, centre.z), Vector2(2.2, 1.5), 0.15, "peau")
	_suspendus(b, pl, 3)
	if ferme:
		var ro := murs.poser_ou(["+Z", "-X", "+X"], 1.0, 0.5)
		if not ro.is_empty():
			b.qf("q_cageot_pommes", ro["pos"], ro["lacet"], Vector3(0.7, 0, 0.45), MATS_CAGEOT, true)
		var rf := murs.poser_ou(["-X", "+X", "+Z"], 0.6, 0.4, true)
		if not rf.is_empty():
			b.q("q_seau_bois", rf["pos"], rf["lacet"])
	# une applique (lumière chaude) sur le mur opposé à l'âtre
	_applique(b, pl, "-X" if atre.x > 0.0 else "+X", clampf(-az * 0.3, -az + 0.5, az - 0.5), ax * az > 9.0)

## Centre de la table : à l'écart de l'âtre, en retrait du couloir d'entrée (vantail ouvert et premiers pas dans la pièce).
## Centre de table (avec ses bancs) libre : ni sur un meuble posé, ni dans le couloir d'entrée ; Vector3.INF s'il n'y en a pas.
static func _centre_table(pl: Dictionary, murs: Murs, long: float) -> Vector3:
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	var xd: float = pl["xd"]
	var fx := ax >= az
	var demi := Vector2(long * 0.5 + 0.1, 0.92) if fx else Vector2(0.92, long * 0.5 + 0.1)
	var couloir := Rect2(xd - float(pl["larg_porte"]) * 0.5 - 0.3, az - 2.2, float(pl["larg_porte"]) + 0.6, 2.4)
	var meilleur := Vector3.INF
	var score := -INF
	var z := -az + demi.y + 0.1
	while z <= az - demi.y - 0.1:
		var x := -ax + demi.x + 0.1
		while x <= ax - demi.x - 0.1:
			var r := Rect2(x - demi.x - 0.1, z - demi.y - 0.1, demi.x * 2.0 + 0.2, demi.y * 2.0 + 0.2)
			if not r.intersects(couloir) and murs.libre(r):
				var s := -absf(x) * 0.5 - absf(z) * 0.6
				if s > score:
					score = s
					meilleur = Vector3(x, Interieurs.F, z)
			x += 0.1
		z += 0.1
	if meilleur.x < INF:
		murs.occuper(meilleur, demi)
	return meilleur

static func _mur_de(r: Dictionary) -> String:
	var n: Vector3 = r["n"]
	if n.z > 0.5:
		return "-Z"
	if n.z < -0.5:
		return "+Z"
	return "-X" if n.x > 0.5 else "+X"

## Auberge de la Chope : comptoir et tonneaux au fond, deux tables, un lit à louer, foyer.
static func _auberge(b: Interieurs, pl: Dictionary, murs: Murs) -> void:
	var F := Interieurs.F
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	var atre := _foyer(b, pl, murs)
	var rc := murs.poser_ou(["-Z", "+X", "-X"], minf(ax * 1.1, 2.6), 0.6, false, -1.0)
	if not rc.is_empty():
		var p: Vector3 = rc["pos"] + (rc["n"] as Vector3) * 0.5
		var lc: float = rc["lacet"]
		var bz := Basis(Vector3.UP, lc)
		var lg := minf(ax * 1.1, 2.6)
		b.table(Vector3(p.x, F, p.z), lg, 0.55, lc + PI * 0.5 * 0.0, 1.0)
		for k in 3:
			b.chope(Vector3(p.x, F + 1.0, p.z) + bz * Vector3((k - 1) * 0.45, 0, 0.05), "etain" if k % 2 == 0 else "bois")
		b.cruche(Vector3(p.x, F + 1.0, p.z) + bz * Vector3(lg * 0.4, 0, 0.0), 0.3)
		_tonneaux(b, {"pos": rc["pos"] - (rc["n"] as Vector3) * 0.05, "n": rc["n"]}, 2)
	_lits(b, pl, murs, ["-X", "+X"])
	for k in 2:
		var ct := _centre_table(pl, murs, 1.5 if k == 0 else 1.3)
		if ct.x < INF:
			_table(b, pl, ct, 1.5 if k == 0 else 1.3, k == 0)
	var _a := atre
	_etagere(b, murs.poser_ou(["+X", "-X", "-Z"], 1.4, 0.34, true), 1.3, "cuisine")
	_sacs(b, murs.poser_ou(["+Z", "-X", "+X"], 1.0, 0.45), 2)
	_suspendus(b, pl, 2)
	_applique(b, pl, "-X" if atre.x > 0.0 else "+X", 0.0, true)

## Grenier (réserve de la halle) : sacs, tonneaux, caisses, étagères de vivres, viande séchée ; une lanterne.
static func _grenier(b: Interieurs, pl: Dictionary, murs: Murs) -> void:
	var F := Interieurs.F
	_etagere(b, murs.poser_ou(["-Z", "+X"], 1.4, 0.34, true, -1.0), 1.3, "reserve")
	_etagere(b, murs.poser_ou(["-Z", "-X"], 1.4, 0.34, true, 1.0), 1.3, "reserve")
	_tonneaux(b, murs.poser_ou(["+X", "-X"], 1.5, 0.7), 2)
	_sacs(b, murs.poser_ou(["-X", "+X", "+Z"], 1.4, 0.45), 3)
	var rc := murs.poser_ou(["+X", "-X", "+Z"], 0.9, 0.6)
	if not rc.is_empty():
		b.qf("q_caisse", rc["pos"], rc["lacet"], Vector3(0.8, 0, 0.56), {}, true)
		var hc := 0.6
		if PropsQuaternius.existe("q_caisse"):
			var bc := PropsQuaternius.boite("q_caisse")
			hc = bc.size.y * 0.8 / bc.size.x
		b.q("q_cageot_pommes", (rc["pos"] as Vector3) + Vector3(0, F + hc, 0), float(rc["lacet"]) + 0.2, 1.0, MATS_CAGEOT)
	_suspendus(b, pl, 4)
	_lanterne(b, Vector3(0, minf(float(pl["y_mur"]), _y_plafond_en(pl, Vector3.ZERO)) - 0.6, -0.3), 2.2)

## Lanterne pendue (flamme, halo, lumière chaude courte).
static func _lanterne(b: Interieurs, p: Vector3, energie := 1.4) -> void:
	b.cyl(p + Vector3(0, 0.35, 0), 0.008, 0.5, "fer_noir", 4)
	b.bx(p + Vector3(0, 0.12, 0), Vector3(0.18, 0.04, 0.18), "fer_noir")
	b.bx(p - Vector3(0, 0.12, 0), Vector3(0.18, 0.04, 0.18), "fer_noir")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.bx(p + Vector3(sx * 0.08, 0, sz * 0.08), Vector3(0.02, 0.24, 0.02), "fer_noir")
	b.flamme(p - Vector3(0, 0.06, 0), 0.7)
	b.halo(p, Vector3.FORWARD, 0.9, 0.9)
	b.lumiere(p, energie, 5.5)

## Moulin à eau : paire de meules au centre (trémie, arbre), sacs de farine, coffre, lit du meunier, foyer.
static func _moulin(b: Interieurs, pl: Dictionary, murs: Murs) -> void:
	var F := Interieurs.F
	var atre := _foyer(b, pl, murs)
	var c := Vector3(-signf(atre.x) * 0.6, F, -0.2)
	_meules(b, c)
	murs.occuper(c + Vector3(0.3, 0, 0), Vector2(1.25, 0.85))
	_lits(b, pl, murs, ["-X", "+X", "-Z"])
	_sacs(b, murs.poser_ou(["-Z", "+X", "-X"], 1.8, 0.45), 4)
	_sacs(b, murs.poser_ou(["+Z", "-X", "+X"], 1.4, 0.45), 3)
	_etagere(b, murs.poser_ou(["+X", "-X", "-Z"], 1.4, 0.34, true), 1.3, "atelier")
	_coffre_pres(b, murs.poser_ou(["-X", "+X", "-Z"], 0.9, 0.5), 0.0)
	_applique(b, pl, "-X" if atre.x > 0.0 else "+X", 0.0, true)

static func _meules(b: Interieurs, c: Vector3) -> void:
	var F := Interieurs.F
	c.y = 0.0      # `c` : pied des meules (y compté depuis 0, le sol est à F)
	b.cyl(c + Vector3(0, F + 0.25, 0), 0.75, 0.5, "bois_sombre", 10, true)               # coffre des meules
	b.cyl(c + Vector3(0, F + 0.58, 0), 0.62, 0.16, "brute", 12)                            # meule dormante
	b.cyl(c + Vector3(0, F + 0.74, 0), 0.6, 0.16, "pierre", 12)                            # meule tournante
	b.cyl(c + Vector3(0, F + 1.25, 0), 0.28, 0.5, "bois", 8, false, 0.08)                  # trémie
	b.cyl(c + Vector3(0, F + 1.9, 0), 0.07, 1.3, "rondin_sombre", 6)                       # arbre
	b.bx(c + Vector3(0.62, F + 0.44, 0), Vector3(0.3, 0.12, 0.2), "bois_sombre")         # goulotte
	b.sac(c + Vector3(1.0, F, 0.1), 2.2, 0.45)

## Tour du guet : râtelier d'armes, table, lit de camp, brasero, échelle vers l'étage, coffre, tonneaux.
static func _tour(b: Interieurs, pl: Dictionary, murs: Murs) -> void:
	var F := Interieurs.F
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	var rr := murs.poser_ou(["-X", "+X"], 1.5, 0.45, true)
	if not rr.is_empty():
		b.qf("q_rack_armes", rr["pos"], rr["lacet"], Vector3(1.4, 0, 0.42), {}, true)
	var rw := murs.poser_ou(["-Z"], 1.6, 0.1, true, -1.0)
	if not rw.is_empty():
		var p: Vector3 = rw["pos"]
		b.bouclier(p + Vector3(0, 1.75, 0), rw["lacet"], 0.36, "bouclier_r")
		b.lance(p + Vector3(0, F + 0.9, 0) + (rw["n"] as Vector3) * 0.08, rw["lacet"], 0.12)
	_lits(b, pl, murs, ["+X", "-X", "-Z"])
	# échelle vers la trappe
	var re := murs.poser_ou(["-Z", "+X"], 0.7, 0.3, true, 1.0)
	if not re.is_empty():
		var p: Vector3 = re["pos"]
		var lac: float = re["lacet"]
		var bz := Basis(Vector3.UP, lac)
		var y1 := float(pl["plat"])
		var ym := (F + y1) * 0.5
		var off := (y1 - F) * 0.5 * 0.12      # pied écarté du mur, tête contre le mur (inclinaison de 0,12 rad)
		for sx in [-1.0, 1.0]:
			b.bx(p + bz * Vector3(sx * 0.24, 0, off) + Vector3(0, ym, 0), Vector3(0.07, y1 - F, 0.07), "bois", lac, false, Vector3(-0.12, 0, 0))
		var y := F + 0.3
		while y < y1 - 0.1:
			b.bx(p + bz * Vector3(0, 0, off - (y - ym) * 0.12) + Vector3(0, y, 0), Vector3(0.5, 0.05, 0.05), "bois", lac)
			y += 0.32
		b.bx(p + bz * Vector3(0, 0, 0.3) + Vector3(0, y1 - 0.02, 0), Vector3(0.8, 0.04, 0.8), "bois_suie", lac)      # trappe
	var ct := _centre_table(pl, murs, 1.3)
	if ct.x < INF:
		_table(b, pl, ct, 1.3)
	_coffre_pres(b, murs.poser_ou(["+X", "-X", "+Z"], 0.9, 0.5), 0.0)
	_tonneaux(b, murs.poser_ou(["+Z", "-Z", "+X"], 0.8, 0.7), 1)
	# brasero (place libre la plus proche du centre)
	var pb := Vector3(-ax * 0.4, F, az * 0.3)
	for essai in [Vector3(-ax * 0.4, F, az * 0.3), Vector3(ax * 0.4, F, az * 0.3), Vector3(-ax * 0.4, F, -az * 0.3), Vector3(ax * 0.4, F, -az * 0.3), Vector3(0, F, 0)]:
		if murs.libre(Rect2(essai.x - 0.5, essai.z - 0.5, 1.0, 1.0)) and not Rect2(float(pl["xd"]) - 0.9, az - 1.9, 1.8, 2.0).has_point(Vector2(essai.x, essai.z)):
			pb = essai
			break
	murs.occuper(pb, Vector2(0.45, 0.45))
	b.cyl(pb + Vector3(0, 0.35, 0), 0.05, 0.7, "fer_noir", 6)
	b.cyl(pb + Vector3(0, 0.74, 0), 0.32, 0.14, "fer_noir", 8, false, 0.18)
	b.bx(pb + Vector3(0, 0.8, 0), Vector3(0.36, 0.03, 0.36), "braises")
	b.flamme(pb + Vector3(0, 0.82, 0), 1.2)
	b.halo(pb + Vector3(0, F + 0.05 - pb.y, 0) + Vector3(0, pb.y, 0), Vector3.UP, 2.4, 2.4)
	b.lumiere(pb + Vector3(0, 1.4, 0), 2.2, 6.0)
	b.solide_cyl(pb + Vector3(0, 0.45, 0), 0.34, 0.9)
	b.tenture(Vector3(0, 2.4, -az + 0.06), 0.0, 1.2, 1.7, "tenture_r")

## Grange (foin, outils, charrette) ou étable (stalles, mangeoire, litière).
static func _grange(b: Interieurs, pl: Dictionary, murs: Murs, etable: bool) -> void:
	var F := Interieurs.F
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	if etable:
		# stalles le long du fond : cloisons de planches, mangeoire, litière
		var n := maxi(2, int(ax * 2.0 / 1.7))
		var lg := ax * 2.0 / n
		for k in n + 1:
			var x := -ax + lg * k
			if k > 0 and k < n:
				b.bx(Vector3(x, F + 0.6, -az + 0.95), Vector3(0.08, 1.2, 1.9), "bois_v", 0.0, true)
				b.cyl(Vector3(x, F + 0.75, -az + 1.9), 0.07, 1.5, "rondin_sombre", 6, true)
		for k in n:
			var x := -ax + lg * (k + 0.5)
			b.bx(Vector3(x, F + 0.45, -az + 0.25), Vector3(lg - 0.3, 0.3, 0.4), "bois", 0.0, true)     # mangeoire
			b.bx(Vector3(x, F + 0.62, -az + 0.25), Vector3(lg - 0.4, 0.06, 0.32), "foin")
			b.paille(Vector3(x, 0, -az + 1.1), Vector2(lg - 0.3, 1.4))
		murs.retirer("-Z", -ax, ax, true)
		murs.retirer("+X", -az, -az + 2.0, true)
		murs.retirer("-X", -az, -az + 2.0, true)
		b.bx(Vector3(0, F + 1.05, -az + 1.95), Vector3(ax * 2.0, 0.1, 0.1), "rondin_sombre", 0.0)       # lisse des stalles
		var rs := murs.poser_ou(["+X", "-X", "+Z"], 0.6, 0.4)
		if not rs.is_empty():
			b.q("q_seau_bois", rs["pos"], rs["lacet"])
	else:
		# tas de foin au fond, bottes, échelle du fenil
		for k in 3:
			var x := -ax * 0.55 + ax * 0.55 * k
			b.bloc(Vector3(1.4, 1.0 + 0.3 * (k % 2), 1.2), 9200 + k, Vector3(x, F + 0.5, -az + 0.75), "foin", 0.1 * k)
		b.solide(Vector3(0, F + 0.6, -az + 0.75), Vector3(ax * 1.9, 1.2, 1.3))
		murs.retirer("-Z", -ax, ax, true)
		var rb := murs.poser_ou(["+X", "-X"], 1.4, 0.6)
		if not rb.is_empty():
			for k in 2:
				b.bloc(Vector3(0.9, 0.45, 0.5), 9210 + k, (rb["pos"] as Vector3) + Vector3(0, F + 0.23 + 0.45 * k, 0), "foin", float(rb["lacet"]) + 0.1 * k, 0.1, 0.03, true)
		var rc := murs.poser_ou(["-X", "+X"], 1.8, 1.0)
		if not rc.is_empty() and PropsQuaternius.existe("q_chariot"):
			b.qf("q_chariot", rc["pos"], float(rc["lacet"]) + PI * 0.5, Vector3(1.0, 0, 1.6), {}, true)
		b.paille(Vector3(0, 0, 0), Vector2(ax * 1.2, az))
	var ro := murs.poser_ou(["+X", "-X", "+Z"], 1.0, 0.1, true)
	if not ro.is_empty():
		var p: Vector3 = ro["pos"]
		b.hache(p + Vector3(0, F + 1.4, 0), ro["lacet"], 0.3)
		b.q("q_pioche", p + Vector3(0, F + 1.2, 0) + Basis(Vector3.UP, ro["lacet"]) * Vector3(0.4, 0, 0), ro["lacet"])
	_sacs(b, murs.poser_ou(["+Z", "+X", "-X"], 1.0, 0.45), 2)
	_tonneaux(b, murs.poser_ou(["+Z", "-X", "+X"], 0.8, 0.7), 1)
	_lanterne(b, Vector3(0, minf(float(pl["y_mur"]), _y_lambris(pl, az) if pl.has("faite") else 9.0) - 0.4, 0.2), 1.5)

## Moulin à vent : arbre vertical, rouet, meules, sacs, échelle.
static func _moulin_vent(b: Interieurs, pl: Dictionary, murs: Murs) -> void:
	var F := Interieurs.F
	var y1 := float(pl["plat"])
	_meules(b, Vector3(0, F, -0.3))
	b.cyl(Vector3(0, (F + 1.45 + y1) * 0.5, -0.3), 0.12, y1 - F - 1.45, "rondin_sombre", 8)      # arbre : de la trémie au plafond
	b.cyl(Vector3(0, y1 - 0.45, -0.3), 0.9, 0.12, "bois_sombre", 12)          # rouet
	for k in 8:
		var a := TAU * k / 8.0
		b.bx(Vector3(sin(a) * 0.55, y1 - 0.45, -0.3 + cos(a) * 0.55), Vector3(0.08, 0.06, 0.6), "bois", a)
	var ax: float = pl["ax"]
	for k in 4:
		var a := PI * 0.6 + k * 0.5
		b.sac(Vector3(sin(a) * (ax - 0.2), F, cos(a) * (ax - 0.2) - 0.1), float(k) + 0.4, 0.5)
	for k in 2:
		var a := -PI * 0.55 - k * 0.6
		b.tonneau(Vector3(sin(a) * (ax - 0.25), 0, cos(a) * (ax - 0.25)), 0.85, 0.3)
	_lanterne(b, Vector3(0.9, y1 - 0.5, 0.6), 1.4)
	var _m := murs
