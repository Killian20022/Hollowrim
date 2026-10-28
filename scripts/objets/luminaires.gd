class_name ObjLuminaires
## Luminaires et accroches crypte + grotte (lot L8) : appliques, chaînes, lustres, candélabres, lanternes, braseros.
## Retouche des versions procédurales : géométrie en modules Blender (sources_blender/scripts/luminaires.py → luminaires.dat, lu en
## FileAccess, sûr dans le fil de construction), MÊMES lumières (positions, couleurs, portées), mêmes flammes (nombre d'appels à
## flamme() inchangé : le tirage `rng` du décor ne bouge pas), mêmes emprises et mêmes collisions. Les modules sont versés dans les
## tables de CrypteDecor (après son propre chargement) puis posés par CrypteDecor.modele() ; l'emprise automatique de modele() est
## retirée (les appliques, chaînes et lanternes n'en avaient pas ; brasero et candélabre gardent la leur, à l'identique).
## Chaque fonction reçoit le décor `dcr` (CrypteDecor ou GrotteDecor) ; CrypteDecor / GrotteDecor gardent une fonction d'une ligne.

const DAT := "res://assets/crypte/modules/luminaires.dat"
const PAS_MAILLON := 0.1
static var _charge := false

## Verse les modules de luminaires.dat dans CrypteDecor._modeles / _modeles_de (une fois, sous le verrou des modules).
static func charger() -> void:
	CrypteDecor._charger_modeles()
	CrypteDecor._modeles_verrou.lock()
	if not _charge:
		_charge = true
		var f := FileAccess.open(DAT, FileAccess.READ)
		if f != null:
			var n := f.get_32()
			for _k in n:
				var nom := f.get_buffer(f.get_8()).get_string_from_utf8()
				var nb := f.get_32()
				var fl := f.get_buffer(nb * 28).to_float32_array()
				var v := PackedVector3Array()
				var c := PackedColorArray()
				v.resize(nb)
				c.resize(nb)
				for q in nb:
					var o := q * 7
					v[q] = Vector3(fl[o], fl[o + 1], fl[o + 2])
					c[q] = Color(fl[o + 3], fl[o + 4], fl[o + 5], 1.0)
				CrypteDecor._modeles[nom] = {"v": v, "c": c}
				var parts := nom.split("__")
				if not CrypteDecor._modeles_de.has(parts[0]):
					CrypteDecor._modeles_de[parts[0]] = []
				if not parts[1] in (CrypteDecor._modeles_de[parts[0]] as Array):
					(CrypteDecor._modeles_de[parts[0]] as Array).append(parts[1])
	CrypteDecor._modeles_verrou.unlock()

static func existe(nom: String) -> bool:
	charger()
	return CrypteDecor._modeles_de.has(nom)

## Pose un module SANS emprise propre (l'objet qui le pose décide de la sienne) ; ses sommets comptent dans l'objet d'audit ouvert.
## Rend les points de flamme du module (vides si le décor est muet, comme modele()).
static func poser(dcr: CrypteDecor, nom: String, pos: Vector3, lacet := 0.0, ech := Vector3.ONE, mats := {}) -> Array:
	charger()
	var n := dcr.emprises.size()
	var pts := dcr.modele(nom, pos, lacet, ech, mats)
	if dcr.emprises.size() > n:
		dcr.emprises.resize(n)
	if dcr._obj_n > 0 and not dcr.muet:      # registre d'audit (audit_interpenetrations --lieu=grotte)
		var T := dcr.xf * Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(ech), pos)
		for m: String in CrypteDecor._modeles_de.get(nom, []):
			if m != "pts":
				dcr._obj_v.append_array(T * ((CrypteDecor._modeles["%s__%s" % [nom, m]] as Dictionary)["v"] as PackedVector3Array))
	return pts

## Points de flamme d'un module (repère du module), lus même quand le décor est muet.
static func points(nom: String) -> Array:
	charger()
	var r: Array = []
	var d: Dictionary = CrypteDecor._modeles.get("%s__pts" % nom, {})
	if not d.is_empty():
		var v: PackedVector3Array = d["v"]
		for q in range(0, v.size(), 3):
			r.append(v[q])
	return r

# ------------------------------------------------------------------ chaîne
## Chaîne du point `haut` au point `bas` : maillons ovales ouverts (le fond passe dans l'anneau), un sur deux tourné de 90°.
static func chaine(dcr: CrypteDecor, haut: Vector3, bas: Vector3) -> void:
	dcr.j0("chaine")
	var l := haut.distance_to(bas)
	var nb := maxi(2, int(l / PAS_MAILLON))
	var e := minf(1.0, l / (nb * PAS_MAILLON))      # chaîne très courte : maillons tassés (comme les anciens maillons-boîtes)
	for i in nb:
		poser(dcr, "maillon", haut.lerp(bas, (i + 0.5) / nb), PI * 0.5 * (i % 2), Vector3(1.0, e, 1.0))
	dcr.j1()

# ------------------------------------------------------------------ applique
## Applique murale : platine à fleurons et rivets, bras et console en volute, bague à griffes, torche goudronnée ; flamme, halo, lumière
## inchangés (mêmes positions, couleurs, portées que la version procédurale).
static func applique(dcr: CrypteDecor, plan_mur: Vector3, vers: Vector3, haut := 2.1, portee := 5.0, energie := 1.9, avec_lumiere := true) -> void:
	dcr.j0("applique", atan2(vers.x, vers.z))
	var d := vers.normalized()
	var lacet := atan2(d.x, d.z)
	var p := Vector3(plan_mur.x, haut, plan_mur.z)
	poser(dcr, "applique_fer", p, lacet)
	dcr.flamme(p + d * 0.32 + Vector3(0, 0.2, 0), 1.6)
	dcr.carte("halo", p + d * 0.13 + Vector3(0, 0.3, 0), d, 1.4, 1.4)
	if avec_lumiere:
		dcr.lumiere(p + d * 0.5 + Vector3(0, 0.45, 0), CrypteDecor.FEU_CRYPTE if dcr.est_crypte else CrypteDecor.FEU, energie, portee, 1.5 if dcr.est_crypte else 1.8)
	dcr.j1()

# ------------------------------------------------------------------ lustres
## Lustre v1 (DonjonKit) : couronne à 6 cierges mise à l'échelle du rayon demandé, chaîne, flammes, halo, lumière courte si demandé.
static func lustre(dcr: CrypteDecor, plafond: Vector3, chute := 1.2, rayon := 0.55, avec_lumiere := true) -> void:
	dcr.j0("lustre")
	var c := plafond - Vector3(0, chute, 0)
	dcr.chaine(plafond, c + Vector3(0, 0.55, 0))
	var k := rayon / 0.6
	var ech := Vector3(k, 1.0, k)
	poser(dcr, "lustre_l8_6", c, 0.0, ech)
	for fp: Vector3 in points("lustre_l8_6"):     # 6 flammes, même en décor muet (comme avant)
		dcr.flamme(c + Basis.from_scale(ech) * fp, 0.55)
	dcr.carte("halo", c + Vector3(0, 0.15, 0), Vector3.UP, 1.8, 1.8)
	if avec_lumiere:
		dcr.lumiere(c + Vector3(0, 0.3, 0), CrypteDecor.FEU_BOUGIE, 1.3, 6.0, 1.7)
	dcr.j1()

## Lustre v2 (CrypteV2) : chaîne, couronne à 8 cierges, flammes aux points du module, halo.
static func lustre_v2(dcr: CrypteDecor, plafond: Vector3, chute: float) -> void:
	dcr.j0("lustre_v2")
	var c := plafond - Vector3(0, chute, 0)
	dcr.chaine(plafond, c + Vector3(0, 0.55, 0))
	for fp: Vector3 in poser(dcr, "lustre_l8", c):
		dcr.flamme(fp, 0.55)
	dcr.carte("halo", c + Vector3(0, 0.15, 0), Vector3.UP, 1.8, 1.8)
	dcr.j1()

# ------------------------------------------------------------------ candélabre
## Candélabre à pied (CrypteV2) : rend les points de flamme ; emprise IDENTIQUE à celle de l'ancien module « candelabre »
## (bornes mesurées dans crypte_v2.dat : x -0,174..0,218, z -0,212..0,178, haut 1,614).
static func candelabre(dcr: CrypteDecor, pos: Vector3, lacet := 0.0) -> Array:
	if dcr.muet:
		return []
	dcr.j0("candelabre", lacet)
	var pts := poser(dcr, "candelabre_l8", pos, lacet)
	dcr.emprise("candelabre", pos + Basis(Vector3.UP, lacet) * Vector3(0.022, 0.0, -0.017), Vector2(0.196, 0.195), lacet, 1.614)
	dcr.j1()
	return pts

# ------------------------------------------------------------------ brasero (crypte)
## Brasero de la crypte : corps = module « brasero_v2 » de la fusion E (plinthe, fût octogonal, vasque de fer à griffes, comme les
## braseros de la citerne). Emprise, flamme, halo et lumière à l'identique ; braises et flamme remontées au niveau de la vasque.
static func brasero(dcr: CrypteDecor, pos: Vector3, froid := false) -> void:
	dcr.j0("brasero")
	pos = dcr._ecarter(pos, Vector2(0.47, 0.47))
	dcr.emprise("brasero", pos, Vector2(0.47, 0.47), 0.0, 0.92)
	if CrypteDecor.modele_existe("brasero_v2"):
		poser(dcr, "brasero_v2", pos)
		dcr.tour("braise", pos + Vector3(0, 1.08, 0), [Vector2(0.36, 0.0), Vector2(0.36, 0.0)], 8, PI / 8.0, true)
		dcr.flamme(pos + Vector3(0, 1.12, 0), 1.7)
	else:
		var prof := [Vector2(0.36, 0.0), Vector2(0.32, 0.1), Vector2(0.24, 0.36), Vector2(0.26, 0.66), Vector2(0.44, 0.74), Vector2(0.5, 0.9), Vector2(0.42, 0.92)]
		dcr.tour("mur0", pos, prof, 8, PI / 8.0, false)
		dcr.tour("fer", pos, [Vector2(0.505, 0.78), Vector2(0.505, 0.9)], 8, PI / 8.0, false)
		dcr.tour("braise", pos + Vector3(0, 0.84, 0), [Vector2(0.4, 0.0), Vector2(0.4, 0.0)], 8, PI / 8.0, true)
		dcr.flamme(pos + Vector3(0, 0.9, 0), 1.7)
	dcr.carte("halo", pos + Vector3(0, 0.02, 0), Vector3.UP, 3.4, 3.4)
	dcr.lumiere(pos + Vector3(0, 1.4, 0), Color(0.45, 0.75, 1.0) if froid else (CrypteDecor.FEU_BRASERO if dcr.est_crypte else CrypteDecor.FEU), 2.4, 5.8, 1.7 if not dcr.est_crypte else 1.4)
	dcr.j1()

# ------------------------------------------------------------------ grotte
## Lanterne de fer suspendue (crochet en `haut`) : chaînette, anneau, chapeau à 6 pans, cadre, vitres de corne (cartes additives :
## la flamme se voit à travers), plateau et bougie ; flamme et halos comme avant. Rend le centre de la flamme (inchangé).
static func lanterne(dcr: CrypteDecor, haut: Vector3, chaine_l := 0.18) -> Vector3:
	var c := haut - Vector3(0, chaine_l, 0)
	if chaine_l > 0.02:
		dcr.chaine(haut, c)
	poser(dcr, "lanterne_fer", c)
	var bas := c - Vector3(0, 0.36, 0)
	var f := bas + Vector3(0, 0.06, 0)
	dcr.flamme(f, 0.68)              # flamme tenue dans la cage haute de 0,2 m (0,75 dépassait du chapeau une fois la lanterne fermée)
	for k in 6:                      # vitres de corne entre les montants (hexagone de 0,113 m) : deux couches additives (lueur lisible de loin)
		var a := TAU * (k + 0.5) / 6.0
		var n := Vector3(cos(a), 0.0, sin(a))
		dcr.carte("halo", c + Vector3(0, -0.242, 0) + n * 0.095, n, 0.112, 0.19)
		dcr.carte("halo", c + Vector3(0, -0.255, 0) + n * 0.09, n, 0.085, 0.14)
	dcr.carte("halo", f + Vector3(0, 0.1, 0), Vector3(0, 0, 1), 0.9, 0.9)
	dcr.carte("halo", f + Vector3(0, 0.1, 0), Vector3(1, 0, 0), 0.9, 0.9)
	return f + Vector3(0, 0.12, 0)

## Brasero de fer forgé de la grotte (corps seulement) : trépied à pieds enroulés et cerclage, vasque rivetée à oreilles.
static func brasero_fer(dcr: CrypteDecor, pos: Vector3) -> void:
	poser(dcr, "brasero_trepied", pos)

# ------------------------------------------------------------------ grappes de bougies (lot C6, 2026-10-28)
## Une bougie posée dans la CRYPTE sur deux (tirée de la position, sans toucher à dcr.rng) devient une grappe de 3, 5 ou 9 bougies sur
## sa flaque de cire (modules « bougies_grappe_N » de luminaires.py), la plus grande qui tient (meuble porteur, objets voisins,
## garnitures) ; les bougies des trios (crypte_v2, tombeau) posées juste après, à moins de RAYON_TRIO, sont absorbées par la grappe.
## AUCUNE lumière de plus : seule la bougie qui en avait une la garde (mêmes position, couleur, portée) ; MÊMES emprises ; MÊMES tirages
## de dcr.rng (un par bougie d'origine : flamme() ou rng.randf()) — les flammes en plus sont versées directement dans _flammes_def
## (phase tirée de la position). Une bougie posée sur un objet d'une garniture (ObjGarnitures) s'en écarte. Grotte, intérieurs : inchangés.
const RAYON_TRIO := 0.2
const RAYON_GRAPPE := {3: 0.115, 5: 0.15, 9: 0.2}      # rayon de la flaque (lobes compris), relevé sur les modules
static func grappe_ici(dcr: CrypteDecor, pos: Vector3) -> int:
	var w := dcr.xf * pos
	var h := absi(floori(w.x * 5.3) * 73856093 ^ floori(w.z * 5.3) * 19349663 ^ floori(w.y * 3.0) * 83492791)
	if h % 2 == 1:
		return 0
	return [3, 5, 9, 5][(h / 2) % 4]

## Un disque de rayon r en `pos` tient-il : dans le dessus du meuble qui le porte (s'il y en a un), hors des autres emprises et des
## objets des garnitures ?
static func _tient(dcr: CrypteDecor, pos: Vector3, r: float) -> bool:
	for e: Array in dcr.emprises:      # bougies seules comprises : pas de grappe collée à une bougie déjà posée
		var c: Vector3 = e[0]
		var dessus := c.y + float(e[3])
		if pos.y >= dessus - 0.08 and pos.y <= dessus + 0.3:       # posé DESSUS : la flaque reste sur le meuble
			var dm: Vector2 = e[1]
			var q := Basis(Vector3.UP, -float(e[2])) * Vector3(pos.x - c.x, 0.0, pos.z - c.z)
			if absf(q.x) <= dm.x and absf(q.z) <= dm.y and (dm.x - absf(q.x) < r or dm.y - absf(q.z) < r):
				return false
		elif pos.y < dessus and pos.y + 0.22 > c.y and CrypteDecor.dist_emprise(e, pos) < r:
			return false
	for d: Array in dcr.get_meta("c6_disques", []):
		var dc: Vector3 = d[0]
		if is_same(d[2], dcr.emprises) and pos.y - dc.y > -0.1 and pos.y - dc.y < 1.3 and Vector2(dc.x - pos.x, dc.z - pos.z).length() < r + float(d[1]):
			return false
	return true

## Bougie posée sur un objet de garniture : écartée juste assez (au plus 3 passes), sur le même meuble.
static func _hors_garnitures(dcr: CrypteDecor, pos: Vector3) -> Vector3:
	for _passe in 3:
		var bouge := false
		for d: Array in dcr.get_meta("c6_disques", []):
			var dc: Vector3 = d[0]
			if not is_same(d[2], dcr.emprises) or pos.y - dc.y < -0.1 or pos.y - dc.y > 1.3:
				continue
			var v := Vector2(pos.x - dc.x, pos.z - dc.z)
			var mini := float(d[1]) + 0.045
			if v.length() < mini:
				var u := v.normalized() if v.length() > 0.005 else Vector2(1, 0)
				var q := Vector2(dc.x, dc.z) + u * (mini + 0.005)
				pos = Vector3(q.x, pos.y, q.y)
				bouge = true
		if not bouge:
			break
	return pos

## Remplace ObjPetitMobilier.bougie dans la crypte : rend vrai si la bougie a été posée ici (grappe, absorbée ou écartée), faux sinon.
static func bougie_c6(dcr: CrypteDecor, pos: Vector3, avec_lumiere: bool) -> bool:
	if not dcr.est_crypte or dcr.muet or not existe("bougies_grappe_5"):
		return false          # décor muet : la bougie simple tire les mêmes nombres (un flamme(), une lumière éventuelle)
	pos = dcr._suivre(pos)
	var grappes: Array = dcr.get_meta("c6_grappes", [])
	for g: Array in grappes:      # bougie d'un trio : absorbée par la grappe posée juste avant (même emprise, même tirage)
		var c: Vector3 = g[0]
		if is_same(g[1], dcr.emprises) and absf(c.y - pos.y) < 0.05 and Vector2(c.x - pos.x, c.z - pos.z).length() < RAYON_TRIO:
			dcr.emprise("bougie", pos, Vector2(0.06, 0.06), 0.0, 0.14)
			dcr.rng.randf()
			if avec_lumiere:
				dcr.lumiere(pos + Vector3(0, 0.4, 0), CrypteDecor.FEU, 0.9, 4.0, 1.8)
			return true
	var p0 := pos
	pos = _hors_garnitures(dcr, pos)
	var n := grappe_ici(dcr, p0)
	while n > 0 and not _tient(dcr, pos, RAYON_GRAPPE[n]):
		n = {9: 5, 5: 3, 3: 0}[n]
	if n == 0:
		if pos.is_equal_approx(p0):
			return false
		# écartée d'une garniture : bougie simple (même corps que ObjPetitMobilier.bougie, position déjà suivie)
		dcr.j0("bougie")
		dcr.emprise("bougie", pos, Vector2(0.06, 0.06), 0.0, 0.14)
		dcr.tour("os", pos, [Vector2(0.03, 0.0), Vector2(0.026, 0.14)], 6, 0.0, true)
		dcr.tour("fer", pos, [Vector2(0.06, 0.0), Vector2(0.06, 0.012)], 6, 0.0, true)
		dcr.flamme(pos + Vector3(0, 0.14, 0), 0.4)
		if avec_lumiere:
			dcr.lumiere(pos + Vector3(0, 0.4, 0), CrypteDecor.FEU, 0.9, 4.0, 1.8)
		dcr.j1()
		return true
	bougies_grappe(dcr, pos, n, avec_lumiere)
	grappes.append([pos, dcr.emprises])
	dcr.set_meta("c6_grappes", grappes)
	return true

## Grappe de n bougies au point `pos` (flaque au sol ou sur un meuble) : module, flammes des bougies allumées, lumière si demandée.
## Journal d'audit : type « bougie » (petit objet, posé sur les meubles comme les bougies seules).
static func bougies_grappe(dcr: CrypteDecor, pos: Vector3, n := 5, avec_lumiere := false) -> void:
	dcr.j0("bougie")
	dcr.emprise("bougie", pos, Vector2(0.06, 0.06), 0.0, 0.14)      # même emprise que la bougie remplacée (le décor tiré après ne bouge pas)
	var nom := "bougies_grappe_%d" % n
	var lacet := ObjPetitMobilier.lacet_pos(dcr, pos)
	var pts := poser(dcr, nom, pos, lacet)
	for i in pts.size():
		var p: Vector3 = pts[i]
		if i == 0:
			dcr.flamme(p, 0.36)      # le tirage de la bougie d'origine
		else:
			var w := dcr.xf * p
			dcr._flammes_def.append([w, 0.3 + 0.06 * float(i % 2), fposmod(w.x * 7.1 + w.z * 3.3 + float(i), 4.0)])
	if avec_lumiere:
		dcr.lumiere(pos + Vector3(0, 0.4, 0), CrypteDecor.FEU, 0.9, 4.0, 1.8)
	dcr.j1()
