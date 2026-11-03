class_name VillageBatiQ
## ESSAI (essai/bati_quaternius, 2026-11-03) : façades du village bâties avec les pièces modulaires du Medieval Village MegaKit (Quaternius,
## CC0), assemblées et passées à la chaîne PS1 par sources_blender/scripts/assembler_bati_quaternius.py -> assets/modeles/bati_quaternius.dat
## (+ .json : cotes utiles). Actif SEULEMENT avec `-- --bati-quaternius` ; sans l'option, VillageBati.maison() ne change pas d'un octet.
## Remplace le corps de la maison (murs, portes, fenêtres, pignons, toit, cheminée) ; garde du bâtiment d'origine : le sol / le socle de pente,
## la boîte de collision, l'emprise, la fumée, la torche et l'enseigne. La neige des toits reste celle du village (dalle épaisse + rouleau
## de faîte + glaçons : BatiGeo.dalle_neige_epaisse, village.m_toit alpha 0 = neige) posée sur le plan du toit Quaternius.

static var actif := "--bati-quaternius" in OS.get_cmdline_user_args()

## Position monde (x, z) arrondie -> modèle du .dat (une entrée par bâtiment remplacé).
const MODELES := {"36,53": "b_h1", "54,55.5": "b_h2", "54,77": "b_h4"}

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
	var p: Node3D = v.pivot_monde(x, z, lacet, y, g)
	p.name = "BatiQ_%s_%d_%d" % [nom, roundi(x), roundi(z)]
	var socle := hmin - y
	if socle < -0.15:      # pente : socle de pierre jusqu'au point bas (comme VillageBati.maison)
		v._boite(p, Vector3(L + 0.55, 0.75 - socle, W + 0.55), Transform3D(Basis(), Vector3(0, (socle - 0.35 + 0.4) * 0.5, 0)), v.m_soubassement)
	var y_sol := 0.4
	v._soubassement(p, L, W, graine)
	# le modèle : posé sur le soubassement (y_sol), un lot par matière (fondu dans les lots du groupe comme le bâti d'origine)
	var mats := _mats(v)
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
	var roul := BatiGeo.rondin(Lx - 0.2, 0.3, graine + 11, 0.05, 0, 0.0, 1.0)
	v._ajouter(p, (roul[0] as BatiGeo.Maillage).arrays(), Transform3D(Basis(), Rp + Vector3(0, 0.38, 0)), v.m_neige)
	# fumée, torche, enseigne : comme le bâtiment d'origine
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
	# collision et emprise : celles du bâtiment d'origine (même boîte : accès, PNJ, tests inchangés)
	var Wt: float = W + (0.9 if style == "colombage" else 0.0)
	var bas_c := minf(socle, 0.0) - 0.3
	var haut_c := y0 + (float(m["faite"]) - float(m["ztop"])) * 0.6
	v._collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (bas_c + haut_c) * 0.5, 0)), Vector3(L + 0.45, haut_c - bas_c, Wt + 0.45))
	v._emprise(p, Vector2(L * 0.5 + 0.5, Wt * 0.5 + 0.5))
	return p
