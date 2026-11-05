class_name VillageBatiQ
## BÂTI HYBRIDE (bati/hybride, 2026-11-04 ; essai d'origine : essai/bati_quaternius) : façades du village bâties avec les pièces
## modulaires du Medieval Village MegaKit (Quaternius, CC0), assemblées et passées à la chaîne PS1 par
## sources_blender/scripts/assembler_bati_quaternius.py -> assets/modeles/bati_quaternius.dat (+ .json : cotes utiles).
## MODE PAR DÉFAUT. `-- --bati-ancien` rend le bâti d'avant (captures avant/après, mesures) : VillageBati.maison() et
## Village._maison() reprennent alors leur code d'origine sans changer d'un octet. Voir docs/BATI_HYBRIDE.md.
## Hybride : les maisons de pierre / planches / colombage passent en pièces Quaternius ; les rondins (halle, Sigrun, chasseurs,
## Grima, H5, ferme A), le grenier, les granges et la tour restent faits maison, avec des détails Quaternius (cheminées, cadres
## de porte) ; les têtes de dragon des pignons sont reposées sur les maisons Quaternius qui en avaient.
## Remplace le corps de la maison (murs, portes, fenêtres, pignons, toit, cheminée) ; garde du bâtiment d'origine : le sol / le socle de pente,
## la boîte de collision, l'emprise, la fumée, la torche et l'enseigne. La neige des toits reste celle du village (dalle épaisse + rouleau
## de faîte + glaçons : BatiGeo.dalle_neige_epaisse, village.m_toit alpha 0 = neige) posée sur le plan du toit Quaternius.

static var actif := not ("--bati-ancien" in OS.get_cmdline_user_args())

## Position monde (x, z) arrondie -> modèle du .dat (une entrée par bâtiment remplacé).
const MODELES := {"36,53": "b_h1", "54,55.5": "b_h2", "54,77": "b_h4", "35.5,71": "b_h3", "25.5,55.5": "b_moulin", "61,3.5": "b_ferme_b"}
# Granges A (87.5, 24.5) et B (67.5, 6) : assemblées en bardage du kit (`b_grange_a/_b` du .dat) mais REJETÉES après
# comparaison (planches horizontales moins naturelles que les planches verticales d'avant) : elles restent faites maison.

## Détails Quaternius sur les maisons restées en rondins (hybride) : vrai si la pièce isolée est chargée.
static func detail(nom: String) -> bool:
	return actif and PropsQuaternius.existe(nom)

## Fenêtre dans une baie du kit : la fenêtre des maisons d'avant (VillageBati.fenetre : vitrage du lot `_vitres` à 4 carreaux,
## même cadre, linteau, appui, jambages et meneau en bois sombre que les autres fenêtres), un panneau de planches sombres
## fermant le reste de la baie, et deux volets de planches sombres entrouverts (comme les fenêtres faites maison).
## `c` = milieu de la baie sur le nu extérieur, `ouv` = taille de la baie, `lacet` = orientation de la façade (0 : face +Z).
static func fenetre(v, p: Node3D, c: Vector3, ouv: Vector2, lacet: float, ouverte := false) -> void:
	var n := Basis(Vector3.UP, lacet) * Vector3.BACK
	var larg := minf(ouv.x - 0.36, 0.78)
	var haut := minf(ouv.y - 0.36, 0.64)
	var f := VillageBati._face(c, n)
	if ouverte:
		# bâtiment ouvert (retours exe 5) : le panneau est percé au droit du vitrage (on voit le dehors depuis la pièce)
		var bw := (ouv.x - 0.04 - larg) * 0.5
		var bh := (ouv.y - 0.04 - haut) * 0.5
		for sx in [-1.0, 1.0]:
			v._boite(p, Vector3(bw, ouv.y - 0.04, 0.06), f * Transform3D(Basis(), Vector3(sx * (larg + bw) * 0.5, 0, -0.06)), v.m_poutres)
			v._boite(p, Vector3(larg, bh, 0.06), f * Transform3D(Basis(), Vector3(0, sx * (haut + bh) * 0.5, -0.06)), v.m_poutres)
	else:
		v._boite(p, Vector3(ouv.x - 0.04, ouv.y - 0.04, 0.06), f * Transform3D(Basis(), Vector3(0, 0, -0.06)), v.m_poutres)
	VillageBati.fenetre(v, p, c, n, larg, haut, false, false)
	for sx in [-1.0, 1.0]:
		v._boite(p, Vector3(larg * 0.5, haut + 0.02, 0.04), f * Transform3D(Basis(Vector3.UP, sx * 1.15), Vector3(sx * (larg * 0.5 + 0.12 + larg * 0.18), 0, 0.12 + larg * 0.2)), v.m_poutres)

## Colombage de bois sombre sur un pignon du kit (pierre unie sinon) : entrait au pied, poinçon jusqu'au faîte et croix de
## Saint-André, comme les pignons à colombage du village. `xg` = nu extérieur du pignon (côté +X ; `cx` = ±1), pied à `y0`.
static func colombage_pignon(v, p: Node3D, cx: float, xg: float, y0: float, faite_y: float, egout_y: float, demi: float) -> void:
	var nrm := Vector3(cx, 0, 0)
	var x := cx * (xg + 0.03)
	var hw := func(y: float) -> float: return demi * (faite_y - y) / (faite_y - egout_y)
	var y1 := y0 + 0.12
	var w1: float = hw.call(y1) - 0.35
	VillageBati.piece(v, p, Vector3(x, y1, -w1), Vector3(x, y1, w1), Vector2(0.2, 0.1), nrm, v.m_colombage)
	VillageBati.piece(v, p, Vector3(x, y1, 0), Vector3(x, faite_y - 0.35, 0), Vector2(0.18, 0.1), nrm, v.m_colombage)
	var y2 := y0 + (faite_y - y0) * 0.55
	var w2: float = hw.call(y2) - 0.3
	VillageBati.piece(v, p, Vector3(x, y1 + 0.08, -w1 + 0.1), Vector3(x, y2, w2), Vector2(0.15, 0.09), nrm, v.m_colombage)
	VillageBati.piece(v, p, Vector3(x, y1 + 0.08, w1 - 0.1), Vector3(x, y2, -w2), Vector2(0.15, 0.09), nrm, v.m_colombage)
	VillageBati.piece(v, p, Vector3(x, y2, -w2), Vector3(x, y2, w2), Vector2(0.15, 0.09), nrm, v.m_colombage)

## Cheminée Quaternius (Prop_Chimney2) à la place de la souche de pierre faite maison : même pied (`y_base`), même hauteur (`h_ch`).
static func cheminee(v, p: Node3D, xch: float, y_base: float, h_ch: float) -> void:
	var nom := "bq_cheminee_2"
	var b := PropsQuaternius.boite(nom)
	var xf := Transform3D(Basis.from_scale(Vector3(0.9, h_ch / maxf(0.1, b.size.y), 0.9)), Vector3(xch, y_base, 0))
	var mats := _mats(v)
	for mc: Array in PropsQuaternius.morceaux(nom):
		v._ajouter(p, mc[1], xf, mats.get(mc[0], v.m_roche))

## Cadre de porte Quaternius (DoorFrame_Flat_WoodDark) autour du vantail sur charnière : ouverture ~1,12 x 2,15 m -> `larg` x `haut`.
## `c` = milieu du seuil sur le nu du mur, `lacet` = orientation de la façade (0 : face +Z).
static func cadre_porte(v, p: Node3D, c: Vector3, larg: float, haut: float, lacet := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(Vector3(larg / 1.12, haut / 2.15, 1.0)), c)
	for mc: Array in PropsQuaternius.morceaux("bq_cadre_porte"):
		v._ajouter(p, mc[1], xf, v.m_poutres_h)

## Têtes de dragon croisées au faîte (comme Village._pignon_decor) sur un toit Quaternius : faîte à `faite_y`, égout à `egout_y`,
## demi-portée `demi`, bout du toit en x = ±`xr`.
static func dragons(v, p: Node3D, xr: float, faite_y: float, egout_y: float, demi: float, graine: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var phi := atan2(faite_y - egout_y, demi)
	var Rf := Vector3(xr, faite_y + 0.3, 0)
	for c in [-1.0, 1.0]:
		var d := Vector3(0, sin(phi), -c * cos(phi))
		var b := Rf + d * 0.85
		v._piece(p, Rf - d * 0.15, b, Vector2(0.14, 0.22), v.m_colombage)
		v._dragon(p, b, phi, -c, r)

## Pièce isolée du kit (lot bâti restant : tour, moulin à vent, granges, forge) fondue dans les lots du village : matières du
## village (bois -> `bois`, défaut bois clair des poutres ; pierre -> `pierre`, défaut roche ; fer -> fer).
static func kit(v, p: Node3D, nom: String, xf: Transform3D, bois: Material = null, pierre: Material = null) -> void:
	var mats := _mats(v)
	for mc: Array in PropsQuaternius.morceaux(nom):
		var m: Material = mats.get(mc[0], v.m_poutres_h)
		if mc[0] == "bois" and bois != null:
			m = bois
		elif mc[0] == "pierre" and pierre != null:
			m = pierre
		v._ajouter(p, mc[1], xf, m)

static var _vantaux := {}
## Vantail de planches des props validés (q_porte_*) en BOIS SOMBRE : les couleurs de sommet du prop (ton + teinte mousse, qui
## sortait verdâtre sur les portes) sont ramenées à leur seule luminance, sur la matière sombre des volets et des colombages.
static func vantail(v, p: Node3D, nom: String, xf: Transform3D) -> void:
	if not _vantaux.has(nom):
		var l := []
		for mc: Array in PropsQuaternius.morceaux(nom):
			var a: Array = (mc[1] as Array).duplicate()
			var cs: PackedColorArray = (a[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
			for i in cs.size():
				var c := cs[i]
				var lum := minf(1.0, (c.r * 0.3 + c.g * 0.59 + c.b * 0.11) * 1.1)
				cs[i] = Color(lum, lum * 0.94, lum * 0.86, c.a)
			a[Mesh.ARRAY_COLOR] = cs
			l.append([mc[0], a])
		_vantaux[nom] = l
	for e: Array in _vantaux[nom]:
		v._ajouter(p, e[1], xf, v.m_fer if e[0] in ["fer", "noir"] else v.m_poutres)

## Grandes portes de grange en kitbash (remplace VillageBati._portes_grange en mode hybride) : cadre DoorFrame_Flat_WoodDark du
## kit étiré à 2,9 x 2,6 m, deux vantaux de planches du kit (Floor_WoodDark debout) en bois sombre, traverses et écharpes en Z
## comme avant, seuil de pierre. `c` = milieu du seuil sur le nu du mur, `n` = normale sortante.
static func portes_grange(v, p: Node3D, c: Vector3, n: Vector3, graine: int) -> void:
	var f := VillageBati._face(c, n)
	v._boite(p, Vector3(2.7, 2.5, 0.06), f * Transform3D(Basis(), Vector3(0, 1.25, -0.04)), v.m_ame)   # fond : pas de jour entre les vantaux
	kit(v, p, "bq_cadre_porte", f * Transform3D(Basis.from_scale(Vector3(2.95 / 1.58, 2.62 / 2.31, 1.3)), Vector3(0, 0, 0.04)), v.m_poutres_h)
	for sx in [-1.0, 1.0]:
		# planches du kit (2 x 2 m, à plat) dressées : 1,28 x 2,5 m
		kit(v, p, "bq_planches", f * Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.64, 1.0, 1.25)), Vector3(sx * 0.65, 1.25, 0.03)), v.m_poutres)
		for by in [0.3, 2.2]:
			v._boite(p, Vector3(1.2, 0.14, 0.05), f * Transform3D(Basis(), Vector3(sx * 0.65, by, 0.07)), v.m_poutres_h)
		VillageBati.piece(v, p, f * Vector3(sx * 0.1, 0.35, 0.08), f * Vector3(sx * 1.2, 2.15, 0.08), Vector2(0.13, 0.05), n, v.m_poutres_h)
		v._boite(p, Vector3(0.1, 0.22, 0.05), f * Transform3D(Basis(), Vector3(sx * 0.12, 1.25, 0.1)), v.m_fer)   # poignées
	v._bloc(p, Vector3(3.2, 0.16, 0.9), graine + 2, f * Vector3(0, -0.32, 0.5), v.m_brute, atan2(n.x, n.z), 0.6, 0.2, 0.04)

static var _meta := {}

static func modele_de(x: float, z: float) -> String:
	if not actif:
		return ""
	var q: String = MODELES.get("%s,%s" % [_n(x), _n(z)], "")
	return q if q != "" and PropsQuaternius.existe(q) else ""

static func _n(f: float) -> String:
	return str(snappedf(f, 0.1)).trim_suffix(".0")

static func meta(nom: String) -> Dictionary:
	if _meta.is_empty():
		var t := FileAccess.get_file_as_string("res://assets/modeles/bati_quaternius.json")
		var j: Variant = JSON.parse_string(t)
		_meta = j if j is Dictionary else {"_": true}
	return _meta.get(nom, {})

## Matières du dat -> matières du village (les couleurs de sommet portent le ton ; pas d'UV : projection en mètres des matières `_e`).
static func _mats(v) -> Dictionary:
	return {"lin": VillageBati.m_torchis, "pierre": v.m_roche, "bois": v.m_poutres_h, "fer": v.m_fer, "noir": v.m_fer}

static func maison(v, g: Node3D, x: float, z: float, lacet: float, o: Dictionary, nom: String) -> Node3D:
	var m := meta(nom)
	var L: float = m["L"]
	var W: float = m["W"]
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
		y = o["y"]   # fermes hors enceinte posées sur leur terrasse (monde._terrasses_fermes), comme VillageBati.maison
	if BatimentsOuverts.actif and o.has("id"):
		y = maxf(y, hmax + 0.05 - 0.4)      # bâtiment ouvert : le terrain ne perce pas le plancher (VillageBati.maison)
	var p: Node3D = v.pivot_monde(x, z, lacet, y, g)
	p.name = "BatiQ_%s_%d_%d" % [nom, roundi(x), roundi(z)]
	var ouvert := BatimentsOuverts.actif and o.has("id")      # retours exe 5 : enterable
	var socle := hmin - y
	if socle < -0.15:      # pente : socle de pierre jusqu'au point bas (comme VillageBati.maison)
		v._boite(p, Vector3(L + 0.55, 0.75 - socle, W + 0.55), Transform3D(Basis(), Vector3(0, (socle - 0.35 + 0.4) * 0.5, 0)), v.m_soubassement)
	var y_sol := 0.4
	v._soubassement(p, L, W, graine)
	# le modèle : posé sur le soubassement (y_sol), un lot par matière (fondu dans les lots du groupe comme le bâti d'origine)
	var mats := _mats(v)
	if style == "grange":      # gen/bati2 : bardage, pignons et sous-face des granges en planches debout du village (comme avant)
		mats["bois"] = v.m_planches
	for mc: Array in PropsQuaternius.morceaux(nom):
		var mat: Material = mats.get(mc[0], v.m_poutres_h)
		v._ajouter(p, mc[1], Transform3D(Basis(), Vector3(0, y_sol, 0)), mat)
	# toit : neige du village sur le plan du toit Quaternius (faîte -> égout)
	var y0: float = y_sol + float(m["ztop"])
	var faite_y: float = y_sol + float(m["faite"]) - 0.1
	var egout_y: float = y_sol + float(m["egout"]) - 0.02
	var demi: float = m["demi_toit"]
	var Lx: float = float(m["long_toit"])
	var Rp := Vector3(0, faite_y, 0)
	for cote in [-1.0, 1.0]:
		var d := Vector3(0, egout_y - faite_y, cote * demi)
		var Sl := d.length()
		var t := d / Sl
		var nrm := Vector3(0, t.z, -t.y)
		if nrm.y < 0.0:
			nrm = -nrm
		var bx := Vector3.RIGHT * (1.0 if d.z > 0.0 else -1.0)
		var xf := Transform3D(Basis(bx, nrm, t), Rp)
		v._ajouter(p, BatiGeo.dalle_neige_epaisse(Lx, Sl, graine * 7 + int(cote) + 3, v.EPAISSEUR_NEIGE, 0.26, 0.2, Vector2.ZERO).surface_get_arrays(0), xf, v.m_toit)
		var bord := xf * Vector3(0, -0.02, Sl + 0.16)
		v._stalactites(p, -Lx * 0.5 + 0.3, Lx * 0.5 - 0.3, bord.y, bord.z, graine * 31 + int(cote))
	# planches de rive sombres aux deux pignons (comme les toits du village) : ferment le jour entre la neige et les tuiles du kit
	for cx in [-1.0, 1.0]:
		var xr: float = cx * (Lx * 0.5 - 0.04)
		for cz in [-1.0, 1.0]:
			VillageBati.piece(v, p, Vector3(xr, faite_y + 0.12, 0), Vector3(xr, egout_y - 0.04, cz * (demi + 0.12)), Vector2(0.28, 0.1), Vector3(cx, 0, 0), v.m_colombage)
			# gen/bati2 : sous-face de planches sombres le long de la rive, dans le plan du toit (les tuiles du kit, vues d'en
			# dessous, laissaient passer le ciel : fils blancs le long des rives de pignon)
			var nr := Vector3(0, demi, cz * (faite_y - egout_y)).normalized()
			var xi: float = cx * (Lx * 0.5 - 0.6)
			VillageBati.piece(v, p, Vector3(xi, faite_y - 0.16, 0), Vector3(xi, egout_y - 0.14, cz * (demi + 0.1)), Vector2(1.15, 0.06), nr, v.m_poutres)
	var roul := BatiGeo.rondin(Lx - 0.2, 0.3, graine + 11, 0.05, 0, 0.0, 1.0)
	v._ajouter(p, (roul[0] as BatiGeo.Maillage).arrays(), Transform3D(Basis(), Rp + Vector3(0, 0.38, 0)), v.m_neige)
	# fenêtres : celles des maisons d'avant (4 carreaux, cadre et volets de bois sombre, lueur chaude la nuit) dans les baies du kit
	var plat := y_sol + 2.75 if float(m["ztop"]) > 3.2 else NAN      # maison à étage (H2) : plafond plat au-dessus du rez
	for w: Array in m.get("fenetres", []):
		fenetre(v, p, Vector3(w[0], y_sol + float(w[1]), w[2]), Vector2(w[3], w[4]), w[5], ouvert and float(w[3]) >= 0.9 and (is_nan(plat) or y_sol + float(w[1]) < plat - 0.4))
	# âme sombre : l'intérieur de la façade est vide ; sans elle, de près, on voyait à travers les vitrages translucides (bâtiment
	# ouvert : dans son propre nœud, masquée quand l'intérieur est chargé)
	var p_ame: Node3D = p
	if ouvert:
		p_ame = Node3D.new()
		p_ame.name = "Ame"
		p.add_child(p_ame)
	v._boite(p_ame, Vector3(L - 0.3, y0 - y_sol - 0.1, W - 0.3), Transform3D(Basis(), Vector3(0, (y0 + y_sol) * 0.5, 0)), v.m_poutres)
	# têtes de dragon (identité nordique gardée) sur les pignons des maisons qui en avaient
	if o.get("dragons", false):
		for cote in [-1.0, 1.0]:
			dragons(v, p, cote * (Lx * 0.5 - 0.1), faite_y + 0.1, egout_y, demi, graine + int(cote) * 17)
	# vantaux : planches et ferrures des portes de props validées (q_porte_*, celles des maisons closes d'avant), dans l'ouverture du kit
	var k := 0
	var porte_ouverte := {}
	for d: Array in m.get("portes", []):
		var vq: String = (["q_porte_1_%s", "q_porte_4_%s", "q_porte_8_%s", "q_porte_2_%s"][(graine + k) % 4] as String) % ("ronde" if d[6] else "plate")
		k += 1
		if not PropsQuaternius.existe(vq):
			continue
		var bq := PropsQuaternius.boite(vq)
		var nd0 := Basis(Vector3.UP, d[5]) * Vector3.BACK
		if ouvert and porte_ouverte.is_empty():
			porte_ouverte = {"c": Vector3(d[0], y_sol + float(d[1]), d[2]), "n": nd0, "larg": float(d[3]), "haut": float(d[4]), "q": vq}
		else:
			vantail(v, p, vq, Transform3D(Basis(Vector3.UP, d[5]) * Basis.from_scale(Vector3(d[3] / bq.size.x, d[4] / bq.size.y, 1.0)), Vector3(d[0], y_sol + float(d[1]), d[2])))
		# deux marches de pierre devant le seuil (comme VillageBati.porte) : le seuil est au-dessus du soubassement
		var nd := Basis(Vector3.UP, d[5]) * Vector3.BACK
		var fd := Transform3D(Basis(Vector3.UP, d[5]), Vector3(d[0], y_sol, d[2]) + nd * 0.17)
		var rd := RandomNumberGenerator.new()
		rd.seed = graine + k * 7
		v._bloc(p, Vector3(float(d[3]) + 0.85, 0.2, 0.62), rd.randi(), fd * Vector3(0, -0.3, 0.42), v.m_brute, d[5], 0.5, 0.2, 0.05)
		v._bloc(p, Vector3(float(d[3]) + 0.55, 0.2, 0.42), rd.randi(), fd * Vector3(0, -0.1, 0.24), v.m_brute, d[5], 0.5, 0.2, 0.05)
	# colombage en croix (identité de l'H2 d'avant) sur les pans pleins de l'étage : poteaux, lisses et croix de Saint-André sombres
	for pn: Array in m.get("pans", []):
		var bp := Basis(Vector3.UP, pn[5])
		var nrm := bp * Vector3.BACK
		var tg := bp * Vector3.RIGHT
		var o0 := Vector3(pn[0], y_sol + float(pn[1]), pn[2]) + nrm * 0.09
		var lg: float = float(pn[3]) * 0.5 - 0.06
		var hh: float = minf(pn[4], egout_y - 0.08 - (y_sol + float(pn[1])))   # le haut du pan sous l'égout ne se voit pas
		var A := o0 - tg * lg + Vector3(0, 0.06, 0)
		var B := o0 + tg * lg + Vector3(0, 0.06, 0)
		var C := o0 + tg * lg + Vector3(0, hh - 0.08, 0)
		var D := o0 - tg * lg + Vector3(0, hh - 0.08, 0)
		for ab: Array in [[A, D], [B, C], [A, B], [D, C]]:
			VillageBati.piece(v, p, ab[0], ab[1], Vector2(0.2, 0.12), nrm, v.m_colombage)
		VillageBati.piece(v, p, A, C, Vector2(0.18, 0.11), nrm, v.m_colombage)
		VillageBati.piece(v, p, B, D, Vector2(0.18, 0.11), nrm, v.m_colombage)
	# pignons du kit (pierre unie) : colombage de bois sombre, comme les pignons du village
	if m.has("pignon_ext"):
		for cx in [-1.0, 1.0]:
			colombage_pignon(v, p, cx, float(m["pignon_ext"]), y0 + float(m.get("toit_dz", 0.0)), faite_y, egout_y, demi)
	# toit relevé (H2) : sablière haute de bois sombre entre le haut de l'étage et le toit (ferme le jour sous l'égout et aux pignons)
	var dz: float = m.get("toit_dz", 0.0)
	if dz > 0.0:
		var lp: float = m["larg_pignon"]
		v._boite(p, Vector3(L + lp - W + 0.04, dz + 0.15, lp + 0.04), Transform3D(Basis(), Vector3(0, y0 + dz * 0.5 - 0.05, 0)), v.m_poutres_h)
	# fumée, torche, enseigne, appentis, tas de bois : comme le bâtiment d'origine
	if m.has("cheminee") and o.get("fumee", false):
		var c: Array = m["cheminee"]
		v._fumee(p, Vector3(c[0], y_sol + float(c[1]) + 0.2, c[2]))
	var cote_porte: String = o.get("porte", "+Z")
	var nporte := VillageBati._normale(cote_porte)
	if o.get("torche", false):
		v._torche_murale(p, Vector3(1.25, y_sol + 1.45, W * 0.5 + 0.35), 1.0, false)
	if o.has("enseigne"):
		var cporte := Vector3(nporte.x * (L * 0.5 + 0.2), y_sol, nporte.z * (W * 0.5 + 0.2))
		var pe := cporte + Vector3(0, 2.0, 0) + (Vector3(1.0, 0, 0) if absf(nporte.z) > 0.5 else Vector3(0, 0, 1.0))
		VillageBati.enseigne(v, p, pe, nporte, o["enseigne"])
	if style == "grange":      # gen/bati2 : grandes portes en kitbash sur le côté de la porte d'origine
		portes_grange(v, p, Vector3(nporte.x * (L * 0.5 + 0.22), y_sol, nporte.z * (W * 0.5 + 0.22)), nporte, graine)
		# lucarne de fenil (émissive le soir) sur le pignon +X, comme les granges d'avant
		var xg: float = float(m["pignon_ext"]) + 0.1
		var yl := y0 + (faite_y - y0) * 0.36
		v._quad_x(p, Vector3(xg + 0.02, yl, 0), 0.42, 0.36, 1.0, v.m_fen_pignon)
		for sz in [-1.0, 1.0]:
			v._boite(p, Vector3(0.1, 0.46, 0.08), Transform3D(Basis(), Vector3(xg, yl, sz * 0.25)), v.m_colombage)
		v._boite(p, Vector3(0.12, 0.08, 0.6), Transform3D(Basis(), Vector3(xg, yl + 0.23, 0)), v.m_colombage)
		v._boite(p, Vector3(0.18, 0.07, 0.64), Transform3D(Basis(), Vector3(xg + 0.03, yl - 0.22, 0)), v.m_colombage)
	if o.get("appentis", false):
		VillageBati._appentis(v, p, g, L, W, graine)
	if o.get("bois", false):
		# ferme B : porte du kit au milieu du pignon ouest ; le tas d'avant (z -2,1..0,1) la bouchait -> poussé vers l'angle sud-ouest
		if nom == "b_ferme_b":
			VillageBati.tas_de_bois(v, p, Vector3(-4.6, 0, -1.85), PI * 0.5, 1.4)
		else:
			VillageBati.tas_de_bois(v, p, o.get("bois_pos", Vector3(L * 0.5 + 0.55, 0, -0.6)), PI * 0.5, 2.2)
	# collision et emprise : celles du bâtiment d'origine (même boîte : accès, PNJ, tests inchangés)
	var Wt: float = W + (0.9 if style == "colombage" else 0.0)
	var bas_c := minf(socle, 0.0) - 0.3
	var haut_c := y0 + (float(m["faite"]) - float(m["ztop"])) * 0.6
	if ouvert and not porte_ouverte.is_empty():
		var nd: Vector3 = porte_ouverte["n"]
		porte_ouverte["cote"] = ("+X" if nd.x > 0.0 else "-X") if absf(nd.x) > 0.5 else ("+Z" if nd.z > 0.0 else "-Z")
		var sp := {"id": o["id"], "style": {"rondins": "rondins", "pierre": "pierre"}.get(style, "kit"),
			"int": Vector2(L * 0.5 - 0.03, W * 0.5 - 0.03), "ext": Vector2(L * 0.5 + 0.25, W * 0.5 + 0.25), "y_sol": y_sol, "y_mur": y0,
			"porte": porte_ouverte, "bas": bas_c, "haut": haut_c, "masque": p_ame, "fenetres": []}
		if is_nan(plat):
			sp["toit"] = {"faite": faite_y, "pente": (faite_y - egout_y) / demi}
		else:
			sp["plat"] = plat
		for w: Array in m.get("fenetres", []):
			if is_nan(plat) or y_sol + float(w[1]) < plat - 0.4:      # baie étroite (pignon, 0,5 m) : volets clos dedans, le vitrage du dehors reste plaqué
				sp["fenetres"].append([Vector3(w[0], y_sol + float(w[1]), w[2]), Vector2(minf(w[3], 0.62) if float(w[3]) < 0.9 else w[3], minf(w[4], 0.7) if float(w[3]) < 0.9 else w[4]), float(w[3]) >= 0.9])
		if m.has("cheminee"):
			sp["foyer"] = Vector2(float(m["cheminee"][0]), float(m["cheminee"][2]))
		var ip := BatimentsOuverts.ouvrir(v, p, sp)
		v._emprise(p, Vector2(L * 0.5 + 0.5, Wt * 0.5 + 0.5), Vector2.ZERO, ip)
		return p
	v._collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (bas_c + haut_c) * 0.5, 0)), Vector3(L + 0.45, haut_c - bas_c, Wt + 0.45))
	v._emprise(p, Vector2(L * 0.5 + 0.5, Wt * 0.5 + 0.5))
	return p
