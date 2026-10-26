class_name VillageBati
## Village v2, lot C7b (plan docs/PLAN_VILLAGE_V2.md, référence references/village_v2_planche.png) : bâtiments sans
## intérieur posés en coordonnées MONDE (x est, z sud) avec les briques du village (`village.gd` : rondins, moellons,
## toits à neige épaisse, pignons, fenêtres, cheminées, fumées) : 6 façades H1–H6 toutes différentes, forge ouverte (auvent,
## enseigne, poste de travail dehors), tour-clocher (~31 m), maison du moulin à eau (la roue et l'arbre : C7c), 2 fermes +
## 2 granges et le moulin à vent animé (hors enceinte). Toutes les pièces d'un même groupe sont fusionnées par matière
## (`village.pivot_monde(..., fusion)`) : quelques appels de dessin par groupe, pas par bâtiment.
## `v` = le nœud du village (non typé : les briques sont des méthodes de village.gd).

## Bâtiments hors enceinte : [x, z, longueur (axe local X), largeur (axe local Z), lacet°] — arbres, buissons et rochers
## dégagés de l'emprise + 2,5 m (`exclu`, appelé par ReliefVillage.exclu au moment des tirages).
const EXTERIEURS := [
	[79.5, 24.5, 9.0, 6.0, 0.0],      # ferme A (longue maison de rondins)
	[87.5, 24.5, 7.0, 5.0, -90.0],    # grange A (axe nord-sud, portes à l'ouest, sur la cour)
	[61.0, 3.5, 8.0, 5.0, 0.0],       # ferme B (pierre et planches, le long du chemin de la grotte)
	[67.5, 6.0, 6.0, 5.0, 90.0],      # grange B
	[95.5, 13.0, 7.5, 13.5, 0.0],     # moulin à vent sur la butte nord-est (tour + disque des ailes)
]
const PENTE := 53.0
const RELEVE := 0.3

## Champs enneigés du plan (F1, F2 à l'est, F3 au nord ; sillons et clôtures : lot C7a) : dégagés d'arbres (+1 m) pour que la
## vue 6 (fermes, moulin à vent) se lise comme sur la planche, au lieu d'une forêt.
const CHAMPS := [Rect2(76.0, 27.0, 15.0, 13.5), Rect2(75.0, 40.5, 12.0, 10.5), Rect2(56.0, -12.0, 15.0, 10.0)]

static func exclu(x: float, z: float) -> bool:
	for c: Rect2 in CHAMPS:
		if c.has_point(Vector2(x, z)):
			return true
	for e in EXTERIEURS:
		var l := Vector2(x - float(e[0]), z - float(e[1])).rotated(deg_to_rad(float(e[4])))
		if absf(l.x) < float(e[2]) * 0.5 + 2.5 and absf(l.y) < float(e[3]) * 0.5 + 2.5:
			return true
	return false

static var m_torchis: ShaderMaterial    # remplissage clair des colombages (pierre fine chaulée)
static var m_toile: ShaderMaterial      # toile des ailes du moulin à vent

static func construire(v) -> void:
	m_torchis = TexturesBati.m_pierre_fine_e(Color(1.62, 1.56, 1.46))
	m_toile = TexturesBati.m_cuir_e(Color(1.75, 1.62, 1.42))
	var bas: Node3D = v.groupe_fusion("BatiV2_bas")
	var haut: Node3D = v.groupe_fusion("BatiV2_haut")
	var ext: Node3D = v.groupe_fusion("BatiV2_fermes")
	# H1 : maison de rondins au bord de la place (porte au nord), pignons à têtes de dragon, cheminée qui fume
	maison(v, bas, 36.0, 53.0, PI, {"L": 7.0, "W": 5.0, "h": 2.3, "style": "rondins", "dragons": true, "cheminee": 1.2, "fumee": true, "torche": true})
	# H2 : rez de pierre, étage à colombages en encorbellement (vue « bâtiments modules » n° 2), porte au nord
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, bas, 54.0, 55.5, PI, {"L": 6.0, "W": 4.5, "h": 2.0, "style": "colombage", "pente": 56.0, "cheminee": -1.6, "fumee": false, "enseigne": "chope"})
	# H6 : grenier sur pierres levées (stabbur), étage en surplomb, escalier détaché
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, bas, 60.0, 20.5, deg_to_rad(-30.0), {"L": 6.0, "W": 4.2, "h": 1.8, "style": "grenier", "pente": 58.0})
	# maison du moulin à eau (porte à l'est ; mur sud plein sur la berge : l'arbre de la roue y entre, lot C7c)
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, bas, 25.5, 55.5, PI * 0.5, {"L": 6.0, "W": 6.0, "h": 2.6, "style": "pierre", "pente": 50.0, "fenetres": [["+Z", 1.6], ["+X", 0.0], ["-Z", 0.8]], "enseigne": "roue", "cheminee": 1.8, "fumee": false})
	# haute rue : H3 (T1, planches, porte sur le pignon est vers l'escalier, appentis à bois), H4 (T2, pierre, porte ouest),
	# H5 (T3, rondins, porche, porte au nord vers la vue)
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, haut, 35.5, 71.0, 0.0, {"L": 6.0, "W": 5.0, "h": 2.2, "style": "planches", "porte": "+X", "pente": 48.0, "appentis": true, "fenetres": [["-Z", -1.2], ["-Z", 1.3], ["+Z", 0.0]]})
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, haut, 54.0, 77.0, 0.0, {"L": 6.0, "W": 5.0, "h": 2.5, "style": "pierre", "porte": "-X", "pente": 45.0, "cheminee": 2.2, "fumee": true, "fenetres": [["-Z", -1.0], ["-Z", 1.2], ["+Z", 0.5]]})
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, haut, 36.0, 85.0, PI, {"L": 6.0, "W": 5.0, "h": 2.3, "style": "rondins", "porche": true, "pente": 58.0, "cheminee": -1.0, "fumee": false})
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	tour(v, haut, 45.0, 87.0)
	# fermes et granges (hors enceinte, sur la pente : socle de pierre côté bas)
	var e: Array = EXTERIEURS
	var cib: PackedFloat32Array = v._monde._cibles_fermes if v._monde != null and "_cibles_fermes" in v._monde else PackedFloat32Array()
	var ty := func(k: int) -> Dictionary: return {"y": cib[k]} if k < cib.size() and not is_nan(cib[k]) else {}
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, ext, e[0][0], e[0][1], deg_to_rad(e[0][4]), ty.call(0).merged({"L": 9.0, "W": 6.0, "h": 2.0, "style": "rondins", "pente": 42.0, "dragons": true, "cheminee": 2.2, "fumee": true, "bois": true,
		"bois_pos": Vector3(-5.05, 0, -0.6)}))   # passe D : tas de bois côté ouest (à l'est il tombait dans le talus de la grange A)
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, ext, e[1][0], e[1][1], deg_to_rad(e[1][4]), ty.call(1).merged({"L": 7.0, "W": 5.0, "h": 2.7, "style": "grange", "pente": 50.0}))
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, ext, e[2][0], e[2][1], deg_to_rad(e[2][4]), ty.call(2).merged({"L": 8.0, "W": 5.0, "h": 2.2, "style": "pierre", "porte": "-X", "pente": 47.0, "cheminee": 2.6, "fumee": true, "fenetres": [["+Z", -1.5], ["+Z", 1.5], ["-Z", 0.0]], "bois": true,
		"bois_pos": Vector3(-4.55, 0, -1.0)}))   # passe D : tas de bois côté ouest (à l'est il traversait la grange B)
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	maison(v, ext, e[3][0], e[3][1], deg_to_rad(e[3][4]), ty.call(3).merged({"L": 6.0, "W": 5.0, "h": 2.4, "style": "grange", "porte": "+X", "pente": 54.0}))
	await v._souffle()   # chargement étalé : une image entre deux bâtiments
	moulin_vent(v, ext, e[4][0], e[4][1])

# --- repères et petites pièces ------------------------------------------------------------------------------

## Repère d'une façade : origine `c` (repère du pivot), +Z = normale sortante `n` (±X ou ±Z), X le long du mur.
static func _face(c: Vector3, n: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), c)

static func _normale(cote: String) -> Vector3:
	match cote:
		"+X": return Vector3.RIGHT
		"-X": return Vector3.LEFT
		"-Z": return Vector3.FORWARD
	return Vector3.BACK

## Pièce de bois droite de `a` à `b`, section `ep` (largeur, épaisseur), l'épaisseur selon `nrm` (perpendiculaire à b - a).
static func piece(v, p: Node3D, a: Vector3, b: Vector3, ep: Vector2, nrm: Vector3, mat: Material) -> void:
	var d := b - a
	var lg := d.length()
	if lg < 0.01:
		return
	var zz := d / lg
	var xx := nrm.cross(zz).normalized()
	var yy := zz.cross(xx)
	v._boite(p, Vector3(ep.x, ep.y, lg), Transform3D(Basis(xx, yy, zz), (a + b) * 0.5), mat)

## Pignon triangulaire plein (plan x = `x`), matière au choix (pierre pour les maisons de pierre).
static func pignon(v, p: Node3D, x: float, y0: float, demi: float, h: float, mat: Material) -> void:
	var a := Vector3(x, y0, -demi)
	var b := Vector3(x, y0, demi)
	var c := Vector3(x, y0 + h, 0)
	var m := BatiGeo.Maillage.new()
	var w := Color.WHITE
	m.tri(a, b, c, w, w, w, Vector3(x - 1.0, y0 + h * 0.3, 0))
	m.tri(a, b, c, w, w, w, Vector3(x + 1.0, y0 + h * 0.3, 0))
	v._ajouter(p, m.arrays(), Transform3D(), mat)

## Porte close : cadre épais, vantail de planches debout à deux bandes de fer cloutées, anneau, deux marches de pierre.
## `c` = milieu du seuil sur le nu du mur (y = dessus du soubassement), `n` = normale sortante.
static func porte(v, p: Node3D, c: Vector3, n: Vector3, larg := 1.1, haut := 1.95, graine := 1, marches := true) -> void:
	var f := _face(c, n)
	for sx in [-1.0, 1.0]:
		v._boite(p, Vector3(0.18, haut + 0.12, 0.3), f * Transform3D(Basis(), Vector3(sx * (larg * 0.5 + 0.09), (haut + 0.12) * 0.5, 0.04)), v.m_poutres_h)
	v._boite(p, Vector3(larg + 0.56, 0.2, 0.34), f * Transform3D(Basis(), Vector3(0, haut + 0.16, 0.05)), v.m_poutres_h)
	v._boite(p, Vector3(larg, haut, 0.08), f * Transform3D(Basis(), Vector3(0, haut * 0.5, 0.0)), v.m_poutres)
	for by in [0.28, haut * 0.74]:
		v._boite(p, Vector3(larg - 0.04, 0.12, 0.03), f * Transform3D(Basis(), Vector3(0, by, 0.05)), v.m_fer)
	v._boite(p, Vector3(0.08, 0.2, 0.05), f * Transform3D(Basis(), Vector3(larg * 0.3, haut * 0.5, 0.07)), v.m_fer)
	if marches:
		var r := RandomNumberGenerator.new()
		r.seed = graine
		v._bloc(p, Vector3(larg + 0.85, 0.2, 0.62), r.randi(), (f * Vector3(0, -0.3, 0.42)), v.m_brute, atan2(n.x, n.z), 0.5, 0.2, 0.05)
		v._bloc(p, Vector3(larg + 0.55, 0.2, 0.42), r.randi(), (f * Vector3(0, -0.1, 0.24)), v.m_brute, atan2(n.x, n.z), 0.5, 0.2, 0.05)

## Fenêtre plaquée sur un mur plein (pierre, planches, colombage) : vitrage du lot des vitres (lueur la nuit), cadre,
## appui en saillie, volets ouverts (bois) ou linteau et appui de pierre (`pierre`).
static func fenetre(v, p: Node3D, c: Vector3, n: Vector3, larg := 0.62, haut := 0.55, pierre := false, volets := true) -> void:
	var f := _face(c, n)
	v._vitre(p, f * Vector3(0, 0, 0.03), Vector2(larg, haut), atan2(n.x, n.z))
	var bois: Material = v.m_poutres_h
	if pierre:
		v._bloc(p, Vector3(larg + 0.5, 0.24, 0.3), int(c.x * 31.0 + c.z * 17.0), f * Vector3(0, haut * 0.5 + 0.14, 0.06), v.m_brute, atan2(n.x, n.z), 0.8, 0.16, 0.05)
		v._bloc(p, Vector3(larg + 0.36, 0.14, 0.34), int(c.x * 37.0 + c.z * 11.0), f * Vector3(0, -haut * 0.5 - 0.08, 0.1), v.m_brute, atan2(n.x, n.z), 1.0, 0.16, 0.05)
	else:
		v._boite(p, Vector3(larg + 0.24, 0.1, 0.14), f * Transform3D(Basis(), Vector3(0, haut * 0.5 + 0.05, 0.06)), bois)
		v._boite(p, Vector3(larg + 0.3, 0.08, 0.24), f * Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -haut * 0.5 - 0.04, 0.1)), bois)
	for sx in [-1.0, 1.0]:
		v._boite(p, Vector3(0.09, haut + 0.1, 0.12), f * Transform3D(Basis(), Vector3(sx * (larg * 0.5 + 0.045), 0, 0.05)), bois)
		if volets:
			v._boite(p, Vector3(larg * 0.5, haut + 0.02, 0.04), f * Transform3D(Basis(Vector3.UP, sx * 1.15), Vector3(sx * (larg * 0.5 + 0.12 + larg * 0.18), 0, 0.12 + larg * 0.2)), v.m_poutres)
	v._boite(p, Vector3(0.04, haut, 0.05), f * Transform3D(Basis(), Vector3(0, 0, 0.05)), bois)   # meneau

## Lanterne pendue (émissive : réglée par l'heure avec les fenêtres de pignon ; pas de lumière dynamique).
static func lanterne(v, p: Node3D, pos: Vector3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	v._boite(p, Vector3(0.03, 0.26, 0.03), Transform3D(b, pos + Vector3(0, -0.13, 0)), v.m_fer)
	v._boite(p, Vector3(0.28, 0.06, 0.28), Transform3D(b, pos + Vector3(0, -0.29, 0)), v.m_fer)
	v._boite(p, Vector3(0.2, 0.26, 0.2), Transform3D(b, pos + Vector3(0, -0.45, 0)), v.m_fen_pignon)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			v._boite(p, Vector3(0.03, 0.3, 0.03), Transform3D(b, pos + b * Vector3(sx * 0.11, -0.45, sz * 0.11)), v.m_fer)
	v._boite(p, Vector3(0.24, 0.04, 0.24), Transform3D(b, pos + Vector3(0, -0.6, 0)), v.m_fer)

## Enseigne pendante : potence de bois, deux chaînettes, planche coiffée de neige, motif de fer sur les deux faces.
## `pos` = pied de la potence contre le mur, `n` = direction de la potence (vers la rue).
static func enseigne(v, p: Node3D, pos: Vector3, n: Vector3, motif: String) -> void:
	var f := _face(pos, n)
	v._boite(p, Vector3(0.1, 0.1, 1.0), f * Transform3D(Basis(), Vector3(0, 0, 0.5)), v.m_poutres_h)
	piece(v, p, f * Vector3(0, -0.55, 0.03), f * Vector3(0, -0.02, 0.45), Vector2(0.07, 0.07), f.basis * Vector3.RIGHT, v.m_poutres_h)
	for dz in [0.42, 0.88]:
		v._boite(p, Vector3(0.02, 0.2, 0.02), f * Transform3D(Basis(), Vector3(0, -0.13, dz)), v.m_fer)
	v._boite(p, Vector3(0.05, 0.5, 0.62), f * Transform3D(Basis(), Vector3(0, -0.48, 0.65)), v.m_poutres_h)
	v._boite(p, Vector3(0.09, 0.05, 0.66), f * Transform3D(Basis(), Vector3(0, -0.2, 0.65)), v.m_neige)
	for sx in [-1.0, 1.0]:
		var o := Vector3(sx * 0.035, -0.5, 0.65)
		match motif:
			"enclume":
				v._boite(p, Vector3(0.02, 0.08, 0.36), f * Transform3D(Basis(), o + Vector3(0, 0.08, 0)), v.m_fer)
				v._boite(p, Vector3(0.02, 0.1, 0.14), f * Transform3D(Basis(), o + Vector3(0, -0.01, 0)), v.m_fer)
				v._boite(p, Vector3(0.02, 0.05, 0.26), f * Transform3D(Basis(), o + Vector3(0, -0.09, 0)), v.m_fer)
				v._boite(p, Vector3(0.02, 0.05, 0.1), f * Transform3D(Basis(), o + Vector3(0, 0.1, -0.2)), v.m_fer)
			"roue":
				v._cylindre(p, 0.17, 0.17, 0.02, f * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), o), v.m_fer, 10)
				v._cylindre(p, 0.11, 0.11, 0.03, f * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), o), v.m_poutres_h, 10)
			_:
				v._cylindre(p, 0.08, 0.07, 0.2, f * Transform3D(Basis(), o + Vector3(0, -0.02, -0.03)), v.m_fer, 8)
				v._boite(p, Vector3(0.02, 0.12, 0.05), f * Transform3D(Basis(), o + Vector3(0, -0.01, 0.1)), v.m_fer)

## Tas de bûches sous un petit toit, contre un mur (repère du pivot).
static func tas_de_bois(v, p: Node3D, c: Vector3, lacet: float, longueur := 2.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	for rang in 4:
		var k := 0
		var x := -longueur * 0.5 + 0.14 + (rang % 2) * 0.13
		while x < longueur * 0.5 - 0.1:
			v._cylindre(p, 0.12, 0.12, 0.62, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), c + b * Vector3(x, 0.13 + rang * 0.24, 0)), v.m_ecorce, 6)
			x += 0.26
			k += 1
	v._collision(p, BoxShape3D.new(), Transform3D(b, c + Vector3(0, 0.5, 0)), Vector3(longueur, 1.0, 0.7))

# --- maisons closes ---------------------------------------------------------------------------------------------

## Maison close (façade seule, non visitable) posée au sol réel ; sur une pente, le pivot est au milieu de l'écart et un socle
## de pierre descend jusqu'au point bas. Options (o) : L, W, h (murs), style (rondins | pierre | planches | colombage |
## grenier | grange), pente (°), porte (+Z | -Z | +X | -X), fenetres [[côté, abscisse]], dragons, cheminee (x local),
## fumee, torche, porche, appentis, enseigne, bois. Collision : une boîte (corps du bâtiment).
static func maison(v, g: Node3D, x: float, z: float, lacet: float, o: Dictionary) -> Node3D:
	var L: float = o.get("L", 6.0)
	var W: float = o.get("W", 5.0)
	var h: float = o.get("h", 2.3)
	var style: String = o.get("style", "rondins")
	var graine := int(absf(x) * 13.0 + absf(z) * 7.0) + 5
	var bas := Basis(Vector3.UP, lacet)
	var hmin := INF
	var hmax := -INF
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 0.0, 1.0]:
			var c := Vector3(x, 0, z) + bas * Vector3(sx * (L * 0.5 + 0.3), 0, sz * (W * 0.5 + 0.3))
			var hc: float = v.h_sol(c.x, c.z)
			hmin = minf(hmin, hc)
			hmax = maxf(hmax, hc)
	var y: float = v.h_sol(x, z) if hmax - hmin < 0.3 else (hmin + hmax) * 0.5 + 0.1
	if o.has("y"):
		y = o["y"]   # passe D : fermes hors enceinte posées sur leur terrasse (monde._terrasses_fermes)
	var p: Node3D = v.pivot_monde(x, z, lacet, y, g)
	p.name = "Bati_%s_%d_%d" % [style, roundi(x), roundi(z)]
	var socle := hmin - y
	if socle < -0.15:
		v._boite(p, Vector3(L + 0.55, 0.75 - socle, W + 0.55), Transform3D(Basis(), Vector3(0, (socle - 0.35 + 0.4) * 0.5, 0)), v.m_soubassement)
		var r := RandomNumberGenerator.new()
		r.seed = graine + 3
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				v._bloc(p, Vector3(0.8, 0.75 - socle, 0.8), r.randi(), Vector3(sx * (L * 0.5 + 0.2), (socle - 0.35 + 0.4) * 0.5, sz * (W * 0.5 + 0.2)), v.m_brute, 0.0, 0.6, 0.18, 0.06)
	var y_sol := 0.4                     # dessus du soubassement (seuil des portes)
	var Wt := W                          # largeur sous le toit
	var y0 := y_sol + h                  # haut des murs (égout)
	if style == "grenier":
		y_sol = 1.0
		Wt = W + 0.6
		y0 = y_sol + h + 1.3
	elif style == "colombage":
		Wt = W + 0.9
		y0 = y_sol + h + 1.9
	var pente: float = o.get("pente", PENTE)
	var faite := (Wt * 0.5 + 0.78) * tan(deg_to_rad(pente)) - RELEVE
	var cote_porte: String = o.get("porte", "+Z")
	var e_mur: float = {"pierre": 0.25, "colombage": 0.25, "planches": 0.11, "grange": 0.11, "grenier": 0.11}.get(style, 0.02)   # nu du mur
	var e_pignon: float = {"pierre": 0.22, "colombage": 0.15, "planches": 0.1, "grange": 0.1, "grenier": 0.1}.get(style, 0.0)
	var fen: Array = v._fenetres_de(L)
	if style != "grenier":
		v._soubassement(p, L, W, graine)
	match style:
		"rondins":
			v._ame(p, L, W, h, fen)
			v._murs_rondins(p, null, L, W, h, graine, fen)
		"pierre":
			_murs_pierre(v, p, L, W, y_sol, h, graine)
		"planches", "grange":
			_murs_planches(v, p, L, W, y_sol, h, graine)
		"colombage":
			_murs_pierre(v, p, L, W, y_sol, h, graine)
			_etage_colombage(v, p, L, W, y_sol + h, 1.9, graine)
		"grenier":
			_grenier(v, p, L, W, h, graine)
	# pignons : planches debout (pierre : pierre jusqu'à la moitié, planches au-dessus), décor à dragons sur certaines
	for cote in [-1.0, 1.0]:
		if style == "rondins":
			v._pignon(p, cote * L * 0.5, y0, Wt * 0.5 + 0.1, faite)
		else:
			pignon(v, p, cote * (L * 0.5 + e_pignon), y0, Wt * 0.5 + 0.1, faite, v.m_poutres)
		if o.get("dragons", false):
			v._pignon_decor(p, cote, L, Wt, y0, faite, RELEVE, graine + int(cote) * 17)
		else:
			# petite lucarne de pignon (émissive le soir) sous une planche de rive
			var yl := y0 + faite * 0.32
			var xg: float = cote * (L * 0.5 + e_pignon + 0.07)
			if style != "grange" or cote > 0.0:
				v._quad_x(p, Vector3(xg + cote * 0.02, yl, 0), 0.42, 0.36, cote, v.m_fen_pignon)
				for sz in [-1.0, 1.0]:
					v._boite(p, Vector3(0.1, 0.46, 0.08), Transform3D(Basis(), Vector3(xg, yl, sz * 0.25)), v.m_colombage)
				v._boite(p, Vector3(0.12, 0.08, 0.6), Transform3D(Basis(), Vector3(xg, yl + 0.23, 0)), v.m_colombage)
				v._boite(p, Vector3(0.18, 0.07, 0.64), Transform3D(Basis(), Vector3(xg + cote * 0.03, yl - 0.22, 0)), v.m_colombage)
			# poinçon et entrait sombres
			v._boite(p, Vector3(0.12, 0.2, Wt + 0.3), Transform3D(Basis(), Vector3(xg, y0 + 0.08, 0)), v.m_colombage)
			piece(v, p, Vector3(xg, yl + 0.28, 0), Vector3(xg, y0 + faite - 0.25, 0), Vector2(0.14, 0.11), Vector3(cote, 0, 0), v.m_colombage)
	v._toit(p, L, Wt, y0, faite, graine, Vector2.ZERO, RELEVE)
	# porte
	var nporte := _normale(cote_porte)
	var cporte := Vector3(nporte.x * (L * 0.5 + e_mur), y_sol, nporte.z * (W * 0.5 + e_mur))   # sur le nu du mur (rondins : dans l'ouverture)
	if style == "grange":
		_portes_grange(v, p, cporte, nporte, graine)
	elif style != "grenier":
		porte(v, p, cporte, nporte, 1.1, 1.95, graine)
	# fenêtres
	var yf := y_sol + minf(1.45, h * 0.62)
	if style == "rondins":
		yf = (v._y_lit(4, h) + v._y_lit(5, h)) * 0.5   # lits LITS_FENETRE de village.gd
		for xw in fen:
			for face in [1.0, -1.0]:
				v._fenetre_cadre(p, xw, yf, face * (W * 0.5 + 0.17), face)
		if v.avec_habillage:
			v._habiller_maison(p, L, W, y0, faite, fen, yf)
	elif style != "grenier" and style != "grange":
		for fw in o.get("fenetres", [["+Z", -L * 0.26], ["+Z", L * 0.26], ["-Z", 0.0]]):
			var nf := _normale(fw[0])
			var ab: float = fw[1]
			var surf := Vector3(ab, yf, nf.z * (W * 0.5 + e_mur)) if absf(nf.z) > 0.5 else Vector3(nf.x * (L * 0.5 + e_mur), yf, ab)
			fenetre(v, p, surf, nf, 0.62, 0.55, style == "pierre")
		if style == "colombage":
			for fw in [[-L * 0.25, 1.0], [L * 0.25, 1.0], [0.0, -1.0]]:
				fenetre(v, p, Vector3(fw[0], y_sol + h + 0.95, fw[1] * (Wt * 0.5 + 0.08)), Vector3(0, 0, fw[1]), 0.56, 0.5, false, false)
	# cheminée + fumée
	if o.has("cheminee"):
		var xch: float = o["cheminee"]
		var h_ch := faite + 0.95
		v._cheminee(p, xch, y0 - 0.2, h_ch, graine + 5)
		if o.get("fumee", false):
			v._fumee(p, Vector3(xch, y0 + h_ch + 0.2, 0))
	if o.get("torche", false):
		v._torche_murale(p, Vector3(1.25, y_sol + 1.45, W * 0.5 + 0.2), 1.0, false)
	if o.get("porche", false):
		_porche(v, p, W, y_sol, graine)
	if o.get("appentis", false):
		_appentis(v, p, g, L, W, graine)
	if o.has("enseigne"):
		var pe := cporte + nporte * 0.0 + Vector3(0, 2.2, 0) + (Vector3(1.0, 0, 0) if absf(nporte.z) > 0.5 else Vector3(0, 0, 1.0))
		enseigne(v, p, pe, nporte, o["enseigne"])
	if o.get("bois", false):
		tas_de_bois(v, p, o.get("bois_pos", Vector3(L * 0.5 + 0.55, 0, -0.6)), PI * 0.5, 2.2)
	# collision : le corps du bâtiment (socle compris)
	var bas_c := minf(socle, 0.0) - 0.3
	var haut_c := y0 + faite * 0.6
	v._collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (bas_c + haut_c) * 0.5, 0)), Vector3(L + 0.45, haut_c - bas_c, Wt + 0.45))
	v._emprise(p, Vector2(L * 0.5 + 0.5, Wt * 0.5 + 0.5))
	return p

## Murs de pierre sèche (pierre plate à joints, projetée en mètres) avec chaînages d'angle en gros blocs alternés.
static func _murs_pierre(v, p: Node3D, L: float, W: float, y_sol: float, h: float, graine: int) -> void:
	var yc := y_sol + h * 0.5 - 0.1
	v._boite(p, Vector3(L + 0.5, h + 0.2, 0.5), Transform3D(Basis(), Vector3(0, yc, W * 0.5)), v.m_roche)
	v._boite(p, Vector3(L + 0.5, h + 0.2, 0.5), Transform3D(Basis(), Vector3(0, yc, -W * 0.5)), v.m_roche)
	v._boite(p, Vector3(0.5, h + 0.2, W - 0.5), Transform3D(Basis(), Vector3(L * 0.5, yc, 0)), v.m_roche)
	v._boite(p, Vector3(0.5, h + 0.2, W - 0.5), Transform3D(Basis(), Vector3(-L * 0.5, yc, 0)), v.m_roche)
	var r := RandomNumberGenerator.new()
	r.seed = graine * 3 + 1
	var n := int(h / 0.42)
	for i in n:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var long_x := (i + (0 if sx * sz > 0.0 else 1)) % 2 == 0
				var t := Vector3(0.78 if long_x else 0.56, 0.4, 0.56 if long_x else 0.78)
				var c := Vector3(sx * (L * 0.5 + 0.03 - t.x * 0.5 + 0.25), y_sol + 0.21 + i * 0.42, sz * (W * 0.5 + 0.03 - t.z * 0.5 + 0.25))
				v._bloc(p, t, r.randi(), c, v.m_brute, r.randf_range(-0.03, 0.03), 0.4 if i == n - 1 else 0.0, 0.16, 0.05)

## Murs de planches debout sur lisse basse, poteaux d'angle et sablière sombres.
static func _murs_planches(v, p: Node3D, L: float, W: float, y_sol: float, h: float, _graine: int) -> void:
	var yc := y_sol + h * 0.5
	v._boite(p, Vector3(L, h, 0.22), Transform3D(Basis(), Vector3(0, yc, W * 0.5)), v.m_poutres)
	v._boite(p, Vector3(L, h, 0.22), Transform3D(Basis(), Vector3(0, yc, -W * 0.5)), v.m_poutres)
	v._boite(p, Vector3(0.22, h, W), Transform3D(Basis(), Vector3(L * 0.5, yc, 0)), v.m_poutres)
	v._boite(p, Vector3(0.22, h, W), Transform3D(Basis(), Vector3(-L * 0.5, yc, 0)), v.m_poutres)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			v._boite(p, Vector3(0.3, h + 0.1, 0.3), Transform3D(Basis(), Vector3(sx * L * 0.5, yc + 0.05, sz * W * 0.5)), v.m_colombage)
	for yy in [y_sol + 0.08, y_sol + h - 0.08]:
		v._boite(p, Vector3(L + 0.1, 0.16, 0.3), Transform3D(Basis(), Vector3(0, yy, W * 0.5 + 0.03)), v.m_colombage)
		v._boite(p, Vector3(L + 0.1, 0.16, 0.3), Transform3D(Basis(), Vector3(0, yy, -W * 0.5 - 0.03)), v.m_colombage)
		v._boite(p, Vector3(0.3, 0.16, W + 0.1), Transform3D(Basis(), Vector3(L * 0.5 + 0.03, yy, 0)), v.m_colombage)
		v._boite(p, Vector3(0.3, 0.16, W + 0.1), Transform3D(Basis(), Vector3(-L * 0.5 - 0.03, yy, 0)), v.m_colombage)

## Étage à colombages en encorbellement (0,25 m) : remplissage clair, poteaux, lisses, croix de Saint-André, abouts de solives.
static func _etage_colombage(v, p: Node3D, L: float, W: float, y_bas: float, h: float, _graine: int) -> void:
	var We := W + 0.9
	v._boite(p, Vector3(L + 0.3, h, We), Transform3D(Basis(), Vector3(0, y_bas + h * 0.5, 0)), m_torchis)
	# abouts de solives sous l'encorbellement
	var x := -L * 0.5 + 0.3
	while x < L * 0.5:
		for sz in [-1.0, 1.0]:
			v._boite(p, Vector3(0.14, 0.16, 0.5), Transform3D(Basis(), Vector3(x, y_bas - 0.06, sz * (W * 0.5 + 0.35))), v.m_colombage)
		x += 0.62
	var ep := Vector2(0.15, 0.08)
	for face in [[Vector3.BACK, We * 0.5 + 0.03, L], [Vector3.FORWARD, We * 0.5 + 0.03, L], [Vector3.RIGHT, L * 0.5 + 0.18, We], [Vector3.LEFT, L * 0.5 + 0.18, We]]:
		var nrm: Vector3 = face[0]
		var off: float = face[1]
		var lg: float = face[2]
		var tang := Vector3(nrm.z, 0, -nrm.x)   # le long du mur
		var o := nrm * off
		# lisses basse et haute
		for yy in [y_bas + 0.08, y_bas + h - 0.08]:
			piece(v, p, o + tang * (-lg * 0.5) + Vector3(0, yy, 0), o + tang * (lg * 0.5) + Vector3(0, yy, 0), Vector2(0.16, 0.09), nrm, v.m_colombage)
		# poteaux tous les ~1,2 m et croix dans un panneau sur deux
		var nb := maxi(2, roundi(lg / 1.2))
		for k in nb + 1:
			var t := -lg * 0.5 + lg * k / nb
			piece(v, p, o + tang * t + Vector3(0, y_bas, 0), o + tang * t + Vector3(0, y_bas + h, 0), ep, nrm, v.m_colombage)
			if k < nb and k % 2 == 0:
				var t2 := -lg * 0.5 + lg * (k + 1) / nb
				piece(v, p, o + tang * t + Vector3(0, y_bas + 0.1, 0), o + tang * t2 + Vector3(0, y_bas + h - 0.1, 0), Vector2(0.12, 0.07), nrm, v.m_colombage)
				piece(v, p, o + tang * t2 + Vector3(0, y_bas + 0.1, 0), o + tang * t + Vector3(0, y_bas + h - 0.1, 0), Vector2(0.12, 0.07), nrm, v.m_colombage)

## Grenier sur pierres levées (stabbur) : 6 pierres plates + billots, plancher à 1 m, rez en planches debout, étage en surplomb
## (0,3 m) de planches horizontales, escalier détaché de 4 marches devant la porte (+Z).
static func _grenier(v, p: Node3D, L: float, W: float, h: float, graine: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * (L * 0.5 - 0.3), 0, sz * (W * 0.5 - 0.3))
			v._bloc(p, Vector3(0.62, 0.5, 0.62), r.randi(), c + Vector3(0, 0.18, 0), v.m_brute, r.randf() * 0.4, 0.6, 0.22, 0.08)
			v._boite(p, Vector3(0.26, 0.5, 0.26), Transform3D(Basis(), c + Vector3(0, 0.66, 0)), v.m_colombage)
	v._boite(p, Vector3(L + 0.1, 0.12, W + 0.1), Transform3D(Basis(), Vector3(0, 0.94, 0)), v.m_poutres_h)
	_murs_planches(v, p, L, W, 1.0, h, graine)
	var yh := 1.0 + h
	v._boite(p, Vector3(L + 0.2, 1.3, W + 0.6), Transform3D(Basis(), Vector3(0, yh + 0.65, 0)), v.m_planches)
	for sz in [-1.0, 1.0]:
		v._boite(p, Vector3(L + 0.3, 0.16, 0.2), Transform3D(Basis(), Vector3(0, yh + 0.04, sz * (W * 0.5 + 0.22))), v.m_colombage)
		for sx in [-1.0, 1.0]:
			piece(v, p, Vector3(sx * (L * 0.5 - 0.3), yh - 0.55, sz * (W * 0.5 + 0.1)), Vector3(sx * (L * 0.5 - 0.7), yh, sz * (W * 0.5 + 0.22)), Vector2(0.1, 0.1), Vector3(0, 0, sz), v.m_colombage)
	porte(v, p, Vector3(0, 1.0, W * 0.5 + 0.12), Vector3.BACK, 0.9, 1.7, graine, false)
	for k in 4:
		v._boite(p, Vector3(1.0, 0.08, 0.3), Transform3D(Basis(), Vector3(0, 0.2 + k * 0.22, W * 0.5 + 1.4 - k * 0.3)), v.m_poutres_h)
	for sx in [-1.0, 1.0]:
		piece(v, p, Vector3(sx * 0.55, 0.0, W * 0.5 + 1.6), Vector3(sx * 0.55, 0.95, W * 0.5 + 0.35), Vector2(0.1, 0.16), Vector3(sx, 0, 0), v.m_poutres)

## Grandes portes de grange (2 vantaux de 1,3 × 2,5 m, planches debout, écharpes en Z) et porte de fenil au-dessus.
static func _portes_grange(v, p: Node3D, c: Vector3, n: Vector3, graine: int) -> void:
	var f := _face(c, n)
	v._boite(p, Vector3(2.9, 0.22, 0.32), f * Transform3D(Basis(), Vector3(0, 2.62, 0.06)), v.m_colombage)
	for sx in [-1.0, 1.0]:
		v._boite(p, Vector3(0.2, 2.6, 0.32), f * Transform3D(Basis(), Vector3(sx * 1.4, 1.3, 0.06)), v.m_colombage)
		v._boite(p, Vector3(1.28, 2.5, 0.08), f * Transform3D(Basis(), Vector3(sx * 0.65, 1.25, 0.02)), v.m_poutres)
		for by in [0.3, 2.2]:
			v._boite(p, Vector3(1.2, 0.14, 0.05), f * Transform3D(Basis(), Vector3(sx * 0.65, by, 0.07)), v.m_poutres_h)
		piece(v, p, f * Vector3(sx * 0.1, 0.35, 0.08), f * Vector3(sx * 1.2, 2.15, 0.08), Vector2(0.13, 0.05), n, v.m_poutres_h)
	v._bloc(p, Vector3(3.2, 0.16, 0.9), graine + 2, f * Vector3(0, -0.32, 0.5), v.m_brute, atan2(n.x, n.z), 0.6, 0.2, 0.04)

## Porche devant la porte (+Z) : deux poteaux, petit toit à un pan enneigé, banc.
static func _porche(v, p: Node3D, W: float, y_sol: float, graine: int) -> void:
	var z1 := W * 0.5 + 1.5
	for sx in [-1.0, 1.0]:
		v._poteau(p, Vector3(sx * 1.3, 0, z1), 0.1, y_sol + 2.25, v.m_poutres, true)
	v._boite(p, Vector3(2.9, 0.18, 0.2), Transform3D(Basis(), Vector3(0, y_sol + 2.25, z1)), v.m_poutres_h)
	v._pan(p, Vector3(0, y_sol + 2.75, W * 0.5 + 0.2), Vector3(0, -0.45, 1.6), 3.3, graine + 900, 2.8, false)
	v._banc(p, Vector3(-1.9, 0, W * 0.5 + 0.55), 1.2)
	lanterne(v, p, Vector3(0.9, y_sol + 2.16, z1), 0.0)

## Appentis à bois contre le pignon -X : deux poteaux, toit à un pan, bûches empilées. Le pan (`_pan` descend vers +Z) est
## posé dans un pivot frère tourné de -90° (même groupe fusionné) : il descend vers -X de la maison.
static func _appentis(v, p: Node3D, g: Node3D, L: float, W: float, graine: int) -> void:
	var x1 := -L * 0.5 - 1.3
	for sz in [-1.0, 1.0]:
		v._poteau(p, Vector3(x1, 0, sz * (W * 0.5 - 0.4)), 0.09, 1.95, v.m_poutres, true)
	v._boite(p, Vector3(0.16, 0.16, W - 0.6), Transform3D(Basis(), Vector3(x1, 1.95, 0)), v.m_poutres_h)
	var o := p.global_transform * Vector3(-L * 0.5 - 0.15, 0, 0)
	var q: Node3D = v.pivot_monde(o.x, o.z, p.global_rotation.y - PI * 0.5, o.y, g)
	v._pan(q, Vector3(0, 2.5, 0), Vector3(0, -0.5, 1.45), W - 0.2, graine + 950, W - 0.4, false)
	tas_de_bois(v, p, Vector3(-L * 0.5 - 0.65, 0, 0), PI * 0.5, W - 1.2)

# --- forge ouverte ----------------------------------------------------------------------------------------------

## Forge de Brodd (repère de la forge : +Z = façade, sol y 0) : grand auvent sur 4 poteaux devant la façade, au-dessus de
## l'égout du toit, enseigne à l'enclume vers la rue, poste de travail dehors (enclume sur billot, meule, bac, braises).
static func forge_ouverte(v, p: Node3D) -> void:
	var zf := 4.35
	for sx in [-1.0, 1.0]:
		v._poteau(p, Vector3(sx * 2.75, 0, 1.95), 0.12, 2.95, v.m_poutres, true)
		v._poteau(p, Vector3(sx * 2.75, 0, zf), 0.13, 2.5, v.m_poutres, true)
		v._bloc(p, Vector3(0.5, 0.22, 0.5), 4700 + int(sx * 3.0), Vector3(sx * 2.75, 0.06, zf), v.m_brute, 0.2, 0.6, 0.2, 0.06)
		piece(v, p, Vector3(sx * 2.75, 2.0, zf), Vector3(sx * 2.75, 2.48, zf - 0.55), Vector2(0.1, 0.1), Vector3(sx, 0, 0), v.m_poutres)
	v._boite(p, Vector3(5.9, 0.2, 0.24), Transform3D(Basis(), Vector3(0, 2.5, zf)), v.m_poutres_h)
	v._boite(p, Vector3(5.9, 0.2, 0.24), Transform3D(Basis(), Vector3(0, 2.94, 1.95)), v.m_poutres_h)
	v._pan(p, Vector3(0, 3.12, 1.55), Vector3(0, -0.5, 3.1), 6.4, 4790, 5.8, true, Vector2.ZERO, true)
	enseigne(v, p, Vector3(2.75, 2.35, zf + 0.1), Vector3.BACK, "enclume")
	# poste de travail dehors, côté gauche (la porte est à droite : x 0,55 .. 2,15). Lot L7 : modules Blender (mobilier_village.py :
	# forge_billot, forge_foyer, forge_meule, tonneau_c) fondus avec le bâti (MobilierVillage.poser_dans) ; collisions d'avant inchangées.
	MobilierVillage.poser_dans(v, p, "forge_billot", Transform3D(Basis(Vector3.UP, 0.3), Vector3(-1.5, 0, 3.2)))
	var billot := CylinderShape3D.new()
	billot.radius = 0.34
	billot.height = 0.62
	v._collision(p, billot, Transform3D(Basis(), Vector3(-1.5, 0.31, 3.2)), Vector3.ZERO)
	# foyer de plein air : murets de moellons, braises, flamme (sans lumière dynamique)
	MobilierVillage.poser_dans(v, p, "forge_foyer", Transform3D(Basis(), Vector3(-2.15, 0, 2.4)))
	v._collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(-2.15, 0.35, 2.4)), Vector3(1.0, 0.7, 0.9))
	Torche.flamme_fixe(p, Vector3(-2.15, 0.82, 2.4), 1.6, 2.0)
	v._tonneau(p, Vector3(-0.6, 0, 3.75))
	# meule à aiguiser sur ses chevalets
	MobilierVillage.poser_dans(v, p, "forge_meule", Transform3D(Basis(), Vector3(-2.2, 0, 3.75)))
	v._collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(-2.2, 0.55, 3.75)), Vector3(0.9, 1.1, 0.6))

# --- tour-clocher ----------------------------------------------------------------------------------------------

## Tour-clocher de pierre sur T3 (non visitable) : socle, fût en deux étages à cordons, chaînages d'angle, porte au nord,
## meurtrières (deux éclairées le soir), beffroi ouvert sur 4 côtés avec la cloche, flèche raide d'essentes sombres à arêtes
## enneigées, épi de fer. Sommet ≈ 33,6 m (T3 à 12 m).
static func tour(v, g: Node3D, x: float, z: float) -> void:
	var p: Node3D = v.pivot_monde(x, z, PI, NAN, g)   # +Z local = nord (la porte regarde la haute rue)
	p.name = "TourClocher"
	var S := 5.0
	var r := RandomNumberGenerator.new()
	r.seed = 8800
	# socle de gros blocs
	for cote in 4:
		var bb := Basis(Vector3.UP, cote * PI * 0.5)
		var u := -S * 0.5 - 0.3
		while u < S * 0.5 + 0.2:
			var lg := r.randf_range(0.7, 1.1)
			v._bloc(p, Vector3(lg, 0.75, 0.6), r.randi(), bb * Vector3(u + lg * 0.5, 0.3, S * 0.5 + 0.12), v.m_brute, cote * PI * 0.5, 0.7, 0.2, 0.06)
			u += lg * 0.97
	v._boite(p, Vector3(S + 0.1, 0.8, S + 0.1), Transform3D(Basis(), Vector3(0, 0.3, 0)), v.m_pierre_fine)
	# fût : étage bas (S) puis étage haut (S - 0,3), cordons enneigés
	var etages := [[0.65, 6.2, S], [6.45, 11.4, S - 0.3]]
	for e in etages:
		var y0: float = e[0]
		var y1: float = e[1]
		var s: float = e[2]
		v._boite(p, Vector3(s, y1 - y0, s), Transform3D(Basis(), Vector3(0, (y0 + y1) * 0.5, 0)), v.m_roche)
		var n := int((y1 - y0) / 0.45)
		for i in n:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var lx := (i + (0 if sx * sz > 0.0 else 1)) % 2 == 0
					var tb := Vector3(0.8 if lx else 0.55, 0.43, 0.55 if lx else 0.8)
					v._bloc(p, tb, r.randi(), Vector3(sx * (s * 0.5 + 0.04 - tb.x * 0.5), y0 + 0.22 + i * 0.45, sz * (s * 0.5 + 0.04 - tb.z * 0.5)), v.m_brute, 0.0, 0.0, 0.15, 0.04)
		v._boite(p, Vector3(s + 0.34, 0.24, s + 0.34), Transform3D(Basis(), Vector3(0, y1 + 0.1, 0)), v.m_brute)
	# porte au nord (+Z) : arc approché par deux claveaux, vantail, marches
	var zp := S * 0.5
	porte(v, p, Vector3(0, 0.7, zp + 0.06), Vector3.BACK, 1.25, 2.25, 8801)
	for sx in [-1.0, 1.0]:
		v._bloc(p, Vector3(0.55, 0.32, 0.36), r.randi(), Vector3(sx * 0.42, 3.25, zp + 0.1), v.m_brute, sx * 0.35, 0.5, 0.16, 0.04)
	v._bloc(p, Vector3(0.42, 0.38, 0.38), r.randi(), Vector3(0, 3.42, zp + 0.12), v.m_brute, 0.0, 0.7, 0.16, 0.04)
	# meurtrières : deux éclairées (nord), les autres sombres
	for m in [[Vector3(0, 5.0, zp + 0.01), 1.0, true], [Vector3(0, 9.3, zp - 0.14), 1.0, true], [Vector3(1.2, 8.6, -zp + 0.14), -1.0, false]]:
		var c: Vector3 = m[0]
		if m[2]:
			v._quad_z(p, c, 0.3, 0.9, m[1], v.m_fen_pignon)
		else:
			v._boite(p, Vector3(0.3, 0.9, 0.04), Transform3D(Basis(), c), v.m_ame)
		v._bloc(p, Vector3(0.6, 0.18, 0.2), r.randi(), c + Vector3(0, 0.55, 0.06 * m[1]), v.m_brute, 0.0, 0.8, 0.15, 0.04)
		v._bloc(p, Vector3(0.6, 0.14, 0.24), r.randi(), c + Vector3(0, -0.53, 0.08 * m[1]), v.m_brute, 0.0, 1.0, 0.15, 0.04)
	for m in [Vector3(zp - 0.14, 7.8, 0.6), Vector3(-zp + 0.14, 4.2, -0.4)]:
		v._boite(p, Vector3(0.04, 0.85, 0.28), Transform3D(Basis(), m + Vector3(signf(m.x) * 0.02, 0, 0)), v.m_ame)
	# beffroi : 4 piles d'angle, garde-corps, plancher, linteaux ; cloche sur son mouton
	var yb := 11.55
	var hb := 3.4
	var sb := S - 0.4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			v._boite(p, Vector3(0.95, hb, 0.95), Transform3D(Basis(), Vector3(sx * (sb * 0.5 - 0.47), yb + hb * 0.5, sz * (sb * 0.5 - 0.47))), v.m_roche)
	for cote in 4:
		var bb := Basis(Vector3.UP, cote * PI * 0.5)
		v._boite(p, Vector3(sb - 1.9, 0.75, 0.4), Transform3D(bb, bb * Vector3(0, yb + 0.37, sb * 0.5 - 0.2)), v.m_roche)
		v._boite(p, Vector3(sb - 1.9, 0.12, 0.5), Transform3D(bb, bb * Vector3(0, yb + 0.8, sb * 0.5 - 0.2)), v.m_brute)
		v._boite(p, Vector3(sb, 0.55, 0.45), Transform3D(bb, bb * Vector3(0, yb + hb - 0.27, sb * 0.5 - 0.22)), v.m_roche)
	v._boite(p, Vector3(sb - 0.4, 0.15, sb - 0.4), Transform3D(Basis(), Vector3(0, yb + 0.05, 0)), v.m_poutres_h)
	v._boite(p, Vector3(sb - 0.3, 0.22, 0.24), Transform3D(Basis(), Vector3(0, yb + 2.7, 0)), v.m_poutres_h)
	v._cylindre(p, 0.3, 0.58, 0.8, Transform3D(Basis(), Vector3(0, yb + 2.12, 0)), v.m_fer, 10)
	v._cylindre(p, 0.12, 0.3, 0.16, Transform3D(Basis(), Vector3(0, yb + 2.6, 0)), v.m_fer, 10)
	v._cylindre(p, 0.62, 0.62, 0.07, Transform3D(Basis(), Vector3(0, yb + 1.73, 0)), v.m_fer, 10)
	v._boite(p, Vector3(sb + 0.4, 0.26, sb + 0.4), Transform3D(Basis(), Vector3(0, yb + hb + 0.1, 0)), v.m_brute)
	# flèche : pyramide d'essentes (bois sombre), arêtes et pied enneigés, épi de fer
	var y_f := yb + hb + 0.22
	var hf := 6.4   # flèche élancée comme sur la planche (vue d'en bas, 4,6 m paraissait plate)
	_fleche(v, p, sb + 0.5, y_f, hf)
	v._cylindre(p, 0.03, 0.04, 1.1, Transform3D(Basis(), Vector3(0, y_f + hf + 0.85, 0)), v.m_fer, 6)
	v._boite(p, Vector3(0.5, 0.05, 0.05), Transform3D(Basis(), Vector3(0, y_f + hf + 1.0, 0)), v.m_fer)
	v._cylindre(p, 0.09, 0.09, 0.12, Transform3D(Basis(), Vector3(0, y_f + hf + 0.4, 0)), v.m_fer, 8)
	v._collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (yb + hb) * 0.5, 0)), Vector3(S + 0.4, yb + hb, S + 0.4))
	v._emprise(p, Vector2(S * 0.5 + 0.6, S * 0.5 + 0.6))

## Flèche pyramidale de base `b`, du haut du beffroi `y0`, hauteur `h` : 4 pans à coyau (base évasée), arêtiers enneigés.
static func _fleche(v, p: Node3D, b: float, y0: float, h: float) -> void:
	var m := BatiGeo.Maillage.new()
	var sombre := Color(1, 1, 1, 1)
	var neige := Color(1, 1, 1, 0)
	var apex := Vector3(0, y0 + h, 0)
	var c := Vector3(0, y0 + h * 0.3, 0)
	var hb := b * 0.5 + 0.25
	var hk := b * 0.5 - 0.15
	var yk := y0 + 0.55
	var coins_bas := [Vector3(-hb, y0, -hb), Vector3(hb, y0, -hb), Vector3(hb, y0, hb), Vector3(-hb, y0, hb)]
	var coins_k := [Vector3(-hk, yk, -hk), Vector3(hk, yk, -hk), Vector3(hk, yk, hk), Vector3(-hk, yk, hk)]
	for i in 4:
		var j := (i + 1) % 4
		# coyau (pied évasé, neige posée sur le bas) puis pan raide
		m.quad(coins_bas[i], coins_bas[j], coins_k[j], coins_k[i], neige, neige, sombre, sombre, c - Vector3(0, 0.5, 0))
		m.tri(coins_k[i], coins_k[j], apex, sombre, sombre, sombre, c)
	v._ajouter(p, m.arrays(), Transform3D(), v.m_colombage)   # essentes de bois sombre ; alpha 0 (coyau) = neige
	for i in 4:
		var a: Vector3 = coins_k[i]
		piece(v, p, a + (apex - a) * 0.02 + Vector3(0, 0.04, 0), apex + Vector3(0, -0.15, 0), Vector2(0.14, 0.1), Vector3(a.x, 0, a.z).normalized() + Vector3(0, 0.6, 0), v.m_neige)

# --- moulin à vent -------------------------------------------------------------------------------------------

## Moulin à vent (hors enceinte, butte nord-est) : socle de pierre qui rattrape la pente, tour de pierre tronconique à
## 10 pans, cordon, porte au sud, deux fenêtres chaudes, calotte de bois enneigée, arbre et 4 ailes à claires-voies et toile,
## tournées vers le village (ouest), qui TOURNENT (village._process : `ailes_moulin`).
static func moulin_vent(v, g: Node3D, x: float, z: float) -> void:
	var hmin := INF
	var hmax := -INF
	for k in 10:
		var a := TAU * k / 10.0
		var hc: float = v.h_sol(x + cos(a) * 3.3, z + sin(a) * 3.3)
		hmin = minf(hmin, hc)
		hmax = maxf(hmax, hc)
	var y := (hmin + hmax) * 0.5
	var p: Node3D = v.pivot_monde(x, z, -PI * 0.5, y, g)   # +Z local = ouest (les ailes regardent le village)
	p.name = "MoulinVent"
	var socle := hmin - y
	var r := RandomNumberGenerator.new()
	r.seed = 9300
	v._cylindre(p, 3.0, 3.35, 0.95 - socle, Transform3D(Basis(), Vector3(0, (socle - 0.35 + 0.6) * 0.5, 0)), v.m_roche, 12, true)
	for k in 14:
		var a := TAU * k / 14.0 + r.randf_range(-0.05, 0.05)
		var hb := 0.95 - socle
		v._bloc(p, Vector3(1.0, hb * 0.9, 0.6), r.randi(), Vector3(sin(a) * 3.2, socle - 0.35 + hb * 0.45, cos(a) * 3.2), v.m_brute, a, 0.7, 0.2, 0.07)
	var ht := 8.6
	v._cylindre(p, 2.05, 2.6, ht, Transform3D(Basis(), Vector3(0, 0.6 + ht * 0.5, 0)), v.m_roche, 10, true)
	v._cylindre(p, 2.42, 2.42, 0.2, Transform3D(Basis(), Vector3(0, 4.6, 0)), v.m_brute, 10)
	v._cylindre(p, 2.25, 2.25, 0.28, Transform3D(Basis(), Vector3(0, 0.6 + ht, 0)), v.m_colombage, 10)
	# porte au sud (local -X), fenêtres
	var rp := 2.55
	porte(v, p, Vector3(-rp - 0.02, 0.62, 0), Vector3.LEFT, 1.0, 1.9, 9301)
	v._quad_x(p, Vector3(-(2.3 + 0.12), 3.4, 0.0), 0.4, 0.5, -1.0, v.m_fen_pignon)
	v._quad_z(p, Vector3(0.0, 6.6, -(2.2 + 0.08)), 0.38, 0.48, -1.0, v.m_fen_pignon)
	# calotte de bois (cône à 10 pans) coiffée de neige
	var yc := 0.6 + ht + 0.14
	v._cylindre(p, 0.5, 2.45, 2.0, Transform3D(Basis(), Vector3(0, yc + 1.0, 0)), v.m_poutres_h, 10)
	v._cylindre(p, 0.08, 0.6, 0.5, Transform3D(Basis(), Vector3(0, yc + 2.24, 0)), v.m_neige, 10)
	v._cylindre(p, 1.5, 2.1, 0.45, Transform3D(Basis(), Vector3(0, yc + 0.9, 0)), v.m_neige, 10)
	# arbre des ailes (vers +Z) et ailes animées
	var hub := Vector3(0, yc + 0.85, 2.6)
	v._cylindre(p, 0.2, 0.24, 2.2, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hub + Vector3(0, 0, -0.95)), v.m_poutres, 8)
	var ailes := Node3D.new()
	ailes.name = "Ailes"
	ailes.position = hub + Vector3(0, 0, 0.2)
	p.add_child(ailes)
	v._boite(ailes, Vector3(0.5, 0.5, 0.36), Transform3D(), v.m_poutres_h)
	for k in 4:
		var b := Basis(Vector3.BACK, k * PI * 0.5 + 0.35)
		# vergue : de l'axe au bout (6,2 m), claires-voies d'un côté, toile tendue
		v._boite(ailes, Vector3(0.16, 6.1, 0.14), Transform3D(b, b * Vector3(0, 3.15, 0)), v.m_poutres)
		var yy := 1.5
		while yy <= 6.05:
			v._boite(ailes, Vector3(1.35, 0.05, 0.05), Transform3D(b, b * Vector3(0.72, yy, 0.05)), v.m_poutres_h)
			yy += 0.5
		v._boite(ailes, Vector3(0.06, 4.6, 0.06), Transform3D(b, b * Vector3(1.38, 3.75, 0.05)), v.m_poutres_h)
		v._boite(ailes, Vector3(1.2, 4.4, 0.02), Transform3D(b, b * Vector3(0.74, 3.8, 0.02)), m_toile)
		v._boite(ailes, Vector3(0.14, 1.0, 0.04), Transform3D(b, b * Vector3(0, 6.0, 0.09)), v.m_neige)
	v.ailes_moulin = ailes
	v._emprise(p, Vector2(3.4, 3.4))
