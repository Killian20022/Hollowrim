class_name CrypteV2
extends RefCounted
## Crypte v2 (2026-10-22, généralisée le 2026-10-23 : lot C4) : habillage GRAPHIQUE d'une salle, d'un couloir ou d'un escalier du kit
## de donjon à partir des modules Blender (sources_blender/scripts/crypte_modules_v2.py -> assets/crypte/modules/crypte_v2.dat) et de la
## table `v2` du module. Référence : references/crypte_v2_planche.png (vues 2 « salle principale », 3 « couloir », 5 « escalier », 6 « tombeau »).
## Rien ne touche au gameplay : ni salle, ni ouverture, ni accroche (ennemis, coffres, interactions, mécanismes), ni collision existante
## (piliers, sarcophages, estrades : même boîte qu'avant ; seul le sarcophage du rituel, posé par la table pilote, en a une nouvelle).
##
## ACTIVATION : toute la crypte est en v2 (CrypteDonjon.plan() ajoute `"v2": {}` aux modules qui n'ont pas de table). Champs : DEFAUTS.
## Deux modes :
##  - `auto: false` (pilotes validés le 2026-10-22 : salle rituelle, couloir des niches) : seul ce que la table décrit est posé ;
##  - `auto: true` (toutes les autres) : piliers + arches, statues, candélabres, bannières, éboulis, flaques… sont placés d'après la
##    forme de la salle, ses ouvertures et ses accroches ; panneaux et piliers sont posés EN DERNIER (`finir`, après le récit de la salle)
##    pour contourner ce que le récit a plaqué au mur (râteliers, étagères, panneaux d'os : CrypteDecor.occupations).

## Matières remplacées dans tout le module (voir CrypteDecor.theme).
const THEME := {"dalle0": "dalle_v2"}
const STATUE := {"pierre": "statue_v2"}      # statues : pierre un peu plus claire (CrypteDecor.AMBIANT_STATUE), sans lumière de plus

## Valeurs par défaut des champs de `v2` ; chaque module en surcharge ce qu'il veut. Positions : repère de la CRYPTE (comme les accroches),
## converties en repère local ici.
const DEFAUTS := {
	"auto": true,                  # placement automatique (voir en tête) ; false = pilotes : seule la table compte
	"piliers": [],                 # abscisses locales des piliers/arches le long des murs longs (salle) ; auto : calculées ; couloir : toutes les 4 m
	"pilier": "pilier_mur_3p2",    # module Blender du pilier
	"naissance": 3.2,              # hauteur de la naissance des arches (= hauteur du pilier)
	"arche": "arche_10p7",         # module Blender de l'arche (portée = distance entre les faces des piliers)
	"panneaux": true,              # panneaux de maçonnerie en relief sur les murs
	"haut_panneau": 3.0,
	"lustres": true,
	"statues": [],                 # [{"pos": Vector3, "lacet": float}]
	"sarcophages": [],             # [{"pos": Vector3, "lacet": float, "collision": bool}]
	"candelabres": [],             # [{"pos": Vector3, "lumiere": bool}]
	"bannieres": [],               # [{"pos": Vector3 (point haut sur le mur), "vers": Vector3, "long": float}]
	"eboulis": [],                 # [{"pos": Vector3, "mod": "eboulis_a", "lacet": float}]
	"dalles": [],                  # [{"pos": Vector3, "mod": "dalles_a", "lacet": float}]
	"flaques": [],                 # [{"pos": Vector3, "r": float}] : emplacements d'eau (CrypteDecor.eau_slots) + placeholder sombre
	"bougies": [],                 # [Vector3] : grappes de 3 bougies de suif posées au sol (flammes sans lumière)
	"givre": 6,                    # nombre de décalques de givre au sol (hors pied des murs)
	"reserves": [],                # [[Vector3 (crypte), demi-largeur]] : morceaux de mur à laisser nus (gravures, objets plaqués)
	"statues_auto": -1,            # auto : nombre de statues (-1 = selon la surface)
	"bannieres_auto": true,        # auto : bannières rouges à croix si le récit de la salle n'en pose aucune
}

static func reglages(m: Dictionary) -> Dictionary:
	var r: Dictionary = DEFAUTS.duplicate(true)
	r.merge(m.get("v2", {}), true)
	return r

## Actif si le module porte une table `v2` — sauf avec l'option `-- --crypte-v1` (captures « avant » à code identique).
static func actif(m: Dictionary) -> bool:
	return m.has("v2") and not OS.get_cmdline_user_args().has("--crypte-v1")

static func auto(m: Dictionary) -> bool:
	return actif(m) and bool((m.get("v2", {}) as Dictionary).get("auto", true))

# ------------------------------------------------------------------ outils
## Position et lacet d'un module posé contre le mur `c` à l'abscisse `a` (repère local), retrait `ret` vers la pièce.
static func _mur(k: DonjonKit, m: Dictionary, c: String, a: float, y: float, ret := 0.0) -> Array:
	var pm := k.plan_mur(m, c)
	var v: Vector3 = pm["vers"]
	return [k.pt_mur(m, c, a, y, ret), atan2(v.x, v.z)]

## Intervalles d'un mur [a0, a1] qui ne croisent ni ouverture ni obstacle (liste de [centre, demi-largeur]).
static func _libres_mur(k: DonjonKit, m: Dictionary, c: String, obstacles: Array, marge_ouv := 0.28) -> Array:
	var dim: Vector2 = m["dim"]
	var horiz := c == "N" or c == "S"
	var Lw := dim.x if horiz else dim.y
	var res: Array = [[-Lw * 0.5 + 0.3, Lw * 0.5 - 0.3]]
	var coupes: Array = []
	for ou: Array in m.get("ouv", []):
		if ou[0] == c:
			coupes.append([float(ou[1]) - float(ou[2]) * 0.5 - marge_ouv, float(ou[1]) + float(ou[2]) * 0.5 + marge_ouv])
	for ob: Array in obstacles:
		coupes.append([float(ob[0]) - float(ob[1]), float(ob[0]) + float(ob[1])])
	for cp: Array in coupes:
		var nv: Array = []
		for s: Array in res:
			if cp[1] <= s[0] or cp[0] >= s[1]:
				nv.append(s)
			else:
				if cp[0] > s[0]:
					nv.append([s[0], cp[0]])
				if cp[1] < s[1]:
					nv.append([cp[1], s[1]])
		res = nv
	return res

## Mur le plus proche d'un point local (à moins de `tol` de son plan) : [côté, abscisse, distance au plan] ou [] si aucun.
static func _mur_de(k: DonjonKit, m: Dictionary, p: Vector3, tol := 0.9) -> Array:
	var best: Array = []
	for c: String in ["N", "S", "O", "E"]:
		var pm := k.plan_mur(m, c)
		var v: Vector3 = pm["vers"]
		var dist: float = (p.z - float(pm["plan"])) * v.z if pm["horiz"] else (p.x - float(pm["plan"])) * v.x
		if dist > -0.4 and dist < tol and (best.is_empty() or dist < float(best[2])):
			best = [c, p.x if pm["horiz"] else p.z, dist]
	return best

## Obstacles des murs (abscisse, demi-largeur) venus des accroches et de la table : mécanismes plaqués au mur (murs fragiles, bouches
## de souffle et de fléchettes), réserves de la table, objets plaqués par le récit (CrypteDecor.occupations), statues auto.
static func _obstacles(k: DonjonKit, m: Dictionary, v2: Dictionary) -> Dictionary:
	var ob: Dictionary = {"N": [], "S": [], "O": [], "E": []}
	for dm: Dictionary in m.get("meca", []):
		var demi := 1.5 if dm.get("genre", "") == "mur_fragile" else 0.6
		for cle in ["pos", "pos_bouche"]:
			if dm.has(cle):
				var w := _mur_de(k, m, k.lw(dm[cle]), 0.8)
				if not w.is_empty():
					(ob[w[0]] as Array).append([w[1], demi])
	for rs: Array in v2["reserves"]:
		var w := _mur_de(k, m, k.lw(rs[0]), 1.2)
		if not w.is_empty():
			(ob[w[0]] as Array).append([w[1], float(rs[1])])
	for oc: Array in k.d.occupations:
		var w := _mur_de(k, m, oc[0], 0.8)
		if not w.is_empty():
			(ob[w[0]] as Array).append([w[1], float(oc[1])])
	for c: String in k._v2_obst:
		(ob[c] as Array).append_array(k._v2_obst[c])
	# audit des interpénétrations : meubles et objets adossés au mur (coffres, lits, tonneaux, sarcophages…) — ni panneau ni pilier
	# engagé derrière eux (ils s'y enfonçaient de 10 à 70 cm)
	for e: Array in k.d.emprises:
		if e[4] in SANS_OBSTACLE:
			continue
		var pe: Vector3 = e[0]
		var dm: Vector2 = e[1]
		var bs := Basis(Vector3.UP, float(e[2]))
		var ax: Vector3 = bs * Vector3.RIGHT
		var az: Vector3 = bs * Vector3.BACK
		for c: String in ["N", "S", "O", "E"]:
			var pm := k.plan_mur(m, c)
			var v: Vector3 = pm["vers"]
			var dist: float = ((pe.z if pm["horiz"] else pe.x) - float(pm["plan"])) * (v.z if pm["horiz"] else v.x)
			var hn := absf(v.dot(ax)) * dm.x + absf(v.dot(az)) * dm.y
			if dist - hn < 0.6 and dist > -0.5:      # pilier engagé : 0,54 m de saillie à la base
				var dr := Vector3(1, 0, 0) if pm["horiz"] else Vector3(0, 0, 1)
				var hl := absf(dr.dot(ax)) * dm.x + absf(dr.dot(az)) * dm.y
				(ob[c] as Array).append([pe.x if pm["horiz"] else pe.z, hl + 0.08])
	return ob

const SANS_OBSTACLE := ["bougie", "crane", "flaque", "os_tas", "crane_os", "arme", "eboulis_a", "eboulis_b", "eboulis_c", "dalles_a", "dalles_b", "dalles_c", "congere", "gravats", "parchemins_epars"]

## Décalage des objets accrochés au mur (bannières, boucliers, gravures, fissures) : devant les panneaux, sauf dans une ouverture.
## Appelé par CrypteDecor._saillie (lié au module : saillie.bind(k, m)).
static func saillie(p: Vector3, n: Vector3, avance: float, k: DonjonKit, m: Dictionary) -> Vector3:
	var w := _mur_de(k, m, p, 0.45)
	if w.is_empty():
		return Vector3.ZERO
	var v: Vector3 = k.plan_mur(m, w[0])["vers"]
	if v.dot(n) < 0.7:
		return Vector3.ZERO
	for ou: Array in m.get("ouv", []):
		if ou[0] == w[0] and absf(float(w[1]) - float(ou[1])) < float(ou[2]) * 0.5 + 0.3:
			return Vector3.ZERO
	return v * maxf(0.0, avance - float(w[2]))

## Garnit un intervalle de mur de panneaux de maçonnerie (largeurs de gabarit 1,8 / 2,6 / 3,4, étirés de +-22 % au plus).
static func _panneaux(k: DonjonKit, m: Dictionary, c: String, a0: float, a1: float, y: float, hp: float) -> void:
	var d := k.d
	var r := d.rng_deco
	var gabarits := [3.4, 2.6, 1.8]
	var noms := {3.4: "pan_mur_c", 2.6: "pan_mur_b", 1.8: "pan_mur_a"}
	var a := a0
	var reste := a1 - a0
	while reste > 0.85:
		var g: float = 1.8
		var cands: Array = []
		for w: float in gabarits:
			if w * 0.78 <= reste + 0.001:
				cands.append(w)
		if cands.is_empty():
			break
		g = cands[r.randi_range(0, cands.size() - 1)]
		var w := minf(g * 1.22, reste)
		# si le reste après ce panneau est trop petit pour un autre, on prend tout
		if reste - w < 0.85:
			w = reste
		var ech := w / g
		if ech < 0.78 or ech > 1.22:
			# repli : gabarit le plus proche de w
			var best: float = gabarits[0]
			for q: float in gabarits:
				if absf(q - w) < absf(best - w):
					best = q
			g = best
			ech = w / g
		var pl := _mur(k, m, c, a + w * 0.5, y, 0.0)
		d.modele(noms[g], pl[0], pl[1], Vector3(ech, hp / 3.0, 1.0))
		a += w
		reste -= w
	# corniche au sommet de la bande d'intervalle entier
	if a1 - a0 > 0.5:
		var pc := _mur(k, m, c, (a0 + a1) * 0.5, y + hp + 0.04, 0.12)
		var v: Vector3 = k.plan_mur(m, c)["vers"]
		var horiz: bool = absf(v.z) > 0.5
		d.boite("pierre_v2", pc[0], Vector3(a1 - a0, 0.1, 0.24) if horiz else Vector3(0.24, 0.1, a1 - a0))

## Statue encapuchonnée (module Blender) : pierre « statue_v2 », un peu plus claire que les murs.
static func statue(d: CrypteDecor, p: Vector3, lacet: float) -> void:
	d.modele("statue_capuche", p, lacet, Vector3.ONE, STATUE)

# ------------------------------------------------------------------ SALLE
static func salle(k: DonjonKit, m: Dictionary) -> void:
	var d := k.d
	var v2 := reglages(m)
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var r := d.rng_deco
	if not v2["auto"]:
		_piliers_panneaux(k, m, v2, {"N": [], "S": [], "O": [], "E": []})
	# --- lustres de fer (Blender) : même nombre que le décor de base, sans lumière (les flammes et les halos suffisent)
	if v2["lustres"] and h >= 3.6 and dim.x * dim.y >= 36.0:
		var centres: Array = [Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))]
		if dim.x * dim.y >= 110.0:
			for sx: float in [-1.0, 1.0]:
				centres.append(Vector3(sx * dim.x * 0.27, 0, r.randf_range(-dim.y * 0.18, dim.y * 0.18)))
		var oculi: Array = []
		for g: Array in m.get("garnitures", []):
			if g[0] == "oculus":
				oculi.append((g[1] as Dictionary).get("pos", k.mw(Vector3.ZERO)))
		oculi.append_array(v2.get("eviter_lustre", []))
		for pw: Vector3 in oculi:      # jamais sous un oculus (la chaîne traversait le cadre du jour)
			var po := k.lw(pw)
			for i in centres.size():
				var c4: Vector3 = centres[i]
				if Vector2(c4.x - po.x, c4.z - po.z).length() < 1.6:
					centres[i] = c4 + Vector3(2.0 if c4.x >= po.x else -2.0, 0, 0)
		for c3: Vector3 in centres:
			lustre(d, Vector3(c3.x, y + h, c3.z), clampf(h - 3.0, 0.8, 3.2))
	if not v2["auto"]:
		_donnees(k, m, v2, y)      # pilotes : tout de suite ; mode auto : dans finir(), après le récit de la salle
	d.poussiere(Vector3(0, y + h * 0.4, 0), Vector3(dim.x * 0.4, h * 0.35, dim.y * 0.4), 26)

## Données de la table (statues, sarcophages, candélabres, bannières, bougies) puis sol (éboulis, dalles, flaques, givre).
static func _donnees(k: DonjonKit, m: Dictionary, v2: Dictionary, y: float) -> void:
	var d := k.d
	# --- données de la table
	for s: Dictionary in v2["statues"]:
		var p := k.lw(s["pos"])
		var lacs := k.lw_lacet(s.get("lacet", 0.0))
		statue(d, Vector3(p.x, y, p.z), lacs)
		if s.get("collision", false):
			d.solide(Vector3(p.x, y + 1.2, p.z), Vector3(0.9, 2.4, 0.9))
	for s: Dictionary in v2["sarcophages"]:
		var p := k.lw(s["pos"])
		var lac := k.lw_lacet(s.get("lacet", 0.0))
		d.modele("sarcophage", Vector3(p.x, y, p.z), lac)
		if s.get("collision", true):
			var b := Basis(Vector3.UP, lac) * Vector3(2.0, 0, 0.9)
			d.solide(Vector3(p.x, y + 0.5, p.z), Vector3(absf(b.x) + 0.2, 1.0, absf(b.z) + 0.2))
	for s: Dictionary in v2["candelabres"]:
		var p := k.lw(s["pos"])
		for fp: Vector3 in d.modele("candelabre", Vector3(p.x, y, p.z), s.get("lacet", 0.0)):
			d.flamme(fp, 0.5)
		d.carte("halo", Vector3(p.x, y + 1.55, p.z), Vector3.UP, 1.1, 1.1)
		if s.get("lumiere", false):  # budget : 7 lumières par salle, seuls les candélabres marqués éclairent
			d.lumiere(Vector3(p.x, y + 1.7, p.z), CrypteDecor.FEU_BOUGIE, 0.9, 5.0, 1.6)
	for s: Dictionary in v2["bannieres"]:
		var p := k.lw(s["pos"])
		var vr: Vector3 = d.xf.basis.inverse() * (s["vers"] as Vector3)
		d.banniere(Vector3(p.x, y + p.y, p.z) + vr * 0.34, vr, s.get("long", 2.4), s.get("larg", 0.95), s.get("couleur", Color(0.5, 0.07, 0.09)), "croix", s.get("usure", 1), s.get("teinte", Color(1.0, 0.78, 0.3)))
	for bp: Vector3 in v2["bougies"]:
		var p := k.lw(bp)
		for off: Vector3 in [Vector3(0, 0, 0), Vector3(0.14, 0, 0.09), Vector3(-0.1, 0, 0.13)]:
			d.bougie(Vector3(p.x, y, p.z) + off, false)
	_sol(k, m, v2, y)

## Piliers engagés + arches en voussoirs sur les murs longs, puis panneaux de maçonnerie sur tous les murs libres.
static func _piliers_panneaux(k: DonjonKit, m: Dictionary, v2: Dictionary, obstacles: Dictionary) -> void:
	var d := k.d
	var dim: Vector2 = m["dim"]
	var y := float(m.get("y", 0.0))
	var long_x := dim.x >= dim.y
	var murs_long: Array = ["N", "S"] if long_x else ["O", "E"]
	var pil_h: float = v2["naissance"]
	var ech_pil: Vector3 = v2.get("ech_pilier", Vector3.ONE)
	var ech_arche: Vector3 = v2.get("ech_arche", Vector3.ONE)
	for a: float in v2["piliers"]:
		var ok := true
		for c: String in murs_long:
			for ou: Array in m.get("ouv", []):
				if ou[0] == c and absf(a - float(ou[1])) < float(ou[2]) * 0.5 + 0.55:
					ok = false
			for oc: Array in k._occ_mur:
				if oc[0] == c and absf(float(oc[1]) - a) < float(oc[2]) + 0.4:
					ok = false
			for ob: Array in obstacles[c]:
				if absf(float(ob[0]) - a) < float(ob[1]) + 0.4:
					ok = false
		if not ok:
			continue
		for c: String in murs_long:
			var pl := _mur(k, m, c, a, y)
			d.modele(v2["pilier"], pl[0], pl[1], ech_pil)
			(obstacles[c] as Array).append([a, 0.42])
		if String(v2["arche"]) != "":
			var cx := Vector3(a, y + pil_h, 0.0) if long_x else Vector3(0.0, y + pil_h, a)
			d.modele(v2["arche"], cx, PI * 0.5 if long_x else 0.0, ech_arche)
	if v2["panneaux"]:
		for c: String in ["N", "S", "O", "E"]:
			for s: Array in _libres_mur(k, m, c, obstacles[c]):
				if s[1] - s[0] > 0.9:
					_panneaux(k, m, c, s[0], s[1], y, float(v2["haut_panneau"]))

## Mode auto, 1re passe (avant le récit de la salle) : statues, candélabres, éboulis, dalles soulevées, flaques (emplacements d'eau),
## urnes et crânes, givre. Tout est tiré par rng_deco et vérifié par `libre()` (jamais sur un passage, une accroche, un ennemi).
static func _auto_contenu(k: DonjonKit, m: Dictionary, v2: Dictionary) -> void:
	var d := k.d
	var r := d.rng_deco
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var aire := dim.x * dim.y
	var th: String = m.get("theme", "tombeau")
	var froid := th == "glace" or th == "givre"
	var obst := _obstacles(k, m, v2)
	for c: String in obst:
		for ob: Array in k._occ_mur:
			if ob[0] == c:
				(obst[c] as Array).append([ob[1], ob[2]])
	# --- statues encapuchonnées contre les murs, chacune avec un candélabre (lumière seulement si le budget le permet)
	var quota: int = v2["statues_auto"]
	if quota < 0:
		quota = 0 if aire < 30.0 or h < 3.0 else (1 if aire < 70.0 else (2 if aire < 150.0 else 3))
	var cands: Array = []
	for c: String in ["N", "S", "O", "E"]:
		for s: Array in _libres_mur(k, m, c, obst[c], 0.6):
			if s[1] - s[0] >= 2.0:
				cands.append([c, (s[0] + s[1]) * 0.5 + r.randf_range(-0.2, 0.2) * (s[1] - s[0] - 2.0), s[1] - s[0]])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	var faites := 0
	for cd: Array in cands:
		if faites >= quota:
			break
		var c: String = cd[0]
		var a: float = cd[1]
		var pm := k.plan_mur(m, c)
		var vv: Vector3 = pm["vers"]
		var p := k.pt_mur(m, c, a, y, 0.72)      # dos de la statue (0,45 m) devant le soubassement (0,2 m)
		if not _libre(k, m, p, 0.45, -1.2):
			continue
		var dr: Vector3 = Vector3.UP.cross(vv).normalized()
		var cote := 1.0 if r.randf() < 0.5 else -1.0
		var pc := p + dr * cote * 0.85 - vv * 0.1
		if not _libre(k, m, pc, 0.25, -1.2):
			cote = -cote
			pc = p + dr * cote * 0.85 - vv * 0.1
		faites += 1
		v2["statues"].append({"pos": k.mw(p), "lacet": k.mlacet(atan2(vv.x, vv.z))})
		_ajoute_obst(k, c, a, 0.55)
		if _libre(k, m, pc, 0.25, -1.2):
			v2["candelabres"].append({"pos": k.mw(pc)})
			k._reserves.append([Vector2(pc.x, pc.z), 0.4])
		k._reserves.append([Vector2(p.x, p.z), 0.8])
		v2["bougies"].append(k.mw(p + vv * 0.62 - dr * cote * 0.3))
		# lumière de la statue (si le budget le permet, voir finir) : basse, devant le socle, comme les bougies de la planche (vue 6) ;
		# à 0,5 m du sol elle reste à plus de 5,5 m de l'autre étage (test_crypte compte les lumières par salle sur ±5,5 m)
		k._v2_lum.append(p + vv * 0.75 + Vector3(0, 0.5, 0))
	# --- éboulis et dalles soulevées près des murs, flaques (emplacements d'eau) dans la pièce
	var n_eb := clampi(int(m.get("usure", 0)) + (1 if aire > 60.0 else 0) + (1 if aire > 160.0 else 0), 0, 3)
	var n_da := clampi(1 + int(aire / 70.0), 1, 4)
	var n_fl := clampi(1 + int(aire / 90.0), 1, 3) + (2 if th == "eau" else 0)
	for i in n_eb + n_da:
		for essai in 8:
			var c: String = ["N", "S", "O", "E"][r.randi_range(0, 3)]
			var pm := k.plan_mur(m, c)
			var Lw := dim.x if pm["horiz"] else dim.y
			var eb := i < n_eb
			var p := k.pt_mur(m, c, r.randf_range(-Lw * 0.5 + 1.0, Lw * 0.5 - 1.0), y, r.randf_range(0.7, 1.1) if eb else r.randf_range(0.9, 1.8))
			if _libre(k, m, p, 1.0 if eb else 0.8, -1.3):      # rayon réel des modules (éboulis 0,9 à 1 m, dalles 0,8 m)
				var liste: Array = v2["eboulis"] if eb else v2["dalles"]
				liste.append({"pos": k.mw(p), "mod": (["eboulis_a", "eboulis_b", "eboulis_c"] if eb else ["dalles_a", "dalles_b", "dalles_c"])[r.randi_range(0, 2)], "lacet": r.randf() * TAU})
				k._reserves.append([Vector2(p.x, p.z), 0.9 if eb else 0.5])
				break
	for i in n_fl:
		for essai in 10:
			var p := Vector3(r.randf_range(-dim.x * 0.5 + 1.2, dim.x * 0.5 - 1.2), y, r.randf_range(-dim.y * 0.5 + 1.2, dim.y * 0.5 - 1.2))
			var rf := r.randf_range(0.55, 0.95) * (1.25 if th == "eau" else 1.0)
			if _libre(k, m, p, rf * 1.05, -0.4):      # rayon réel de la flaque (elle passait sous socles et meubles)
				v2["flaques"].append({"pos": k.mw(p), "r": rf, "graine": r.randi_range(1, 99)})
				k._reserves.append([Vector2(p.x, p.z), rf])
				break
	# --- urnes, crânes et bougies au pied des murs (densité au sol de la planche), sans les plaques de neige de la v1
	var nd := clampi(int((dim.x + dim.y) / 4.0), 2, 8)
	for i in nd:
		var c: String = ["N", "S", "E", "O"][r.randi_range(0, 3)]
		var pm := k.plan_mur(m, c)
		var Lw := dim.x if pm["horiz"] else dim.y
		var p := k.pt_mur(m, c, r.randf_range(-Lw * 0.5 + 0.8, Lw * 0.5 - 0.8), y, r.randf_range(0.4, 0.62) + 0.22)      # devant les panneaux (0,3 m)
		if not _libre(k, m, p, 0.3, -1.0):
			continue
		var t := r.randf()
		if t < 0.4:
			d.urne(p, r.randf_range(0.7, 1.05))
			if r.randf() < 0.5:
				var ou := Vector3(r.randf_range(-0.4, 0.4), 0, r.randf_range(-0.4, 0.4))
				var dr2 := Vector3.UP.cross(pm["vers"] as Vector3)
				ou = dr2 * (0.5 if ou.dot(dr2) >= 0.0 else -0.5)      # la petite urne À CÔTÉ de la grande, le long du mur (se chevauchaient)
				d.urne(p + ou, r.randf_range(0.5, 0.8))
		elif t < 0.75:
			d.j0("crane_os")
			d.crane(p, r.randf() * TAU)
			for q in 3:
				d.boite("os", p + Vector3(r.randf_range(-0.25, 0.25), 0.02, r.randf_range(-0.25, 0.25)), Vector3(0.3, 0.04, 0.04), r.randf() * TAU)
			d.j1()
		else:
			for off: Vector3 in [Vector3(0, 0, 0), Vector3(0.13, 0, 0.08), Vector3(-0.09, 0, 0.12)]:
				d.bougie(p + off, false)
	v2["givre"] = int(v2["givre"]) + int(aire / 40.0) + (8 if froid else 0)
	k.v2_stats[m["id"]] = {"statues": faites, "quota": quota, "candidats": cands.size(), "candelabres": k._v2_lum.size(), "flaques": (v2["flaques"] as Array).size()}

## Boîtes de collision posées dans la pièce depuis le début du module (hors murs, sols, plafonds et grandes estrades), en repère local.
static func _boites_sol(k: DonjonKit, m: Dictionary) -> Array:
	var d := k.d
	var dim: Vector2 = m["dim"]
	var y := float(m.get("y", 0.0))
	var res: Array = []
	var enfants := d.corps.get_children()
	for i in range(k._n_corps0, enfants.size()):
		var cs := enfants[i] as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var t: Vector3 = (d.xf.basis.inverse() * (cs.shape as BoxShape3D).size).abs()
		var c := k.lw(cs.position)
		if c.y - t.y * 0.5 > y + 2.5 or c.y + t.y * 0.5 <= y + 0.02:
			continue      # plafonds et sols ; les grandes estrades (degrés de l'arène) comptent (audit 2026-10-23)
		if absf(c.x) > dim.x * 0.5 - 0.3 or absf(c.z) > dim.y * 0.5 - 0.3:
			continue
		res.append(Rect2(c.x - t.x * 0.5, c.z - t.z * 0.5, t.x, t.z))
	return res

## libre() du kit + aucune boîte de collision du récit sous l'objet (rayon r).
static func _libre(k: DonjonKit, m: Dictionary, p: Vector3, r: float, marge: float) -> bool:
	if not k.libre(m, p, r, marge):
		return false
	if not k.d.emprise_libre(p, r, 0.05):      # rien DANS un objet déjà posé (récit, détritus, congères)
		return false
	for b: Rect2 in k._v2_boites:
		if b.grow(r + 0.12).has_point(Vector2(p.x, p.z)):
			return false
	return true

static func _ajoute_obst(k: DonjonKit, c: String, a: float, demi: float) -> void:
	if not k._v2_obst.has(c):
		k._v2_obst[c] = []
	(k._v2_obst[c] as Array).append([a, demi])

## Mode auto, 2e passe (après le récit et les garnitures) : piliers + arches sur les murs longs (sauf salle à piliers isolés),
## panneaux de maçonnerie autour de tout ce qui est plaqué au mur, bannières si la salle n'en a pas, lumières des candélabres de statue
## si le budget de la salle le permet (au plus 6 lumières par salle : test_crypte en tolère 7, une reste libre).
static func finir(k: DonjonKit, m: Dictionary) -> void:
	if m.get("type", "salle") != "salle" or not auto(m):
		return
	var d := k.d
	var v2 := reglages(m)
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var r := d.rng_deco
	k._v2_boites = _boites_sol(k, m)      # obstacles posés par le récit (tables, lits, râteliers, statues…) : rien ne s'y pose
	_auto_contenu(k, m, v2)
	_donnees(k, m, v2, y)
	var long_x := dim.x >= dim.y
	var Ll := dim.x if long_x else dim.y
	var court := dim.y if long_x else dim.x
	var obst := _obstacles(k, m, v2)
	# --- piliers et arches (gabarits mis à l'échelle de la salle)
	var a_piliers := false
	for g: Array in m.get("garnitures", []):
		if g[0] == "piliers":
			a_piliers = true
	if (v2["piliers"] as Array).is_empty() and not a_piliers and h >= 2.8 and court <= 16.5:
		var portee := court - 0.6 - 0.68
		var gab: Array = ["arche_2p0", 2.0, 1.0, 0.3] if portee <= 3.0 else (["arche_4p0", 4.0, 2.2, 0.36] if portee <= 7.0 else ["arche_10p7", 10.7, 2.3, 0.44])
		var sx: float = portee / float(gab[1])
		var montee: float = float(gab[2]) * (sx if float(gab[1]) < 10.0 else minf(sx, 1.15))
		var nais := clampf(h - montee - float(gab[3]) - 0.25, 1.6, 3.4)
		if nais + montee + float(gab[3]) > h - 0.1:
			montee = h - 0.1 - float(gab[3]) - nais
		var avec_arche := montee >= 0.6
		var nb := maxi(0, int((Ll - 2.0) / 3.4))
		var pas := (Ll - 2.6) / maxf(1.0, nb - 1.0) if nb > 1 else 0.0
		var pts: Array = []
		for i in nb:
			pts.append(-pas * (nb - 1) * 0.5 + pas * i)
		v2["piliers"] = pts
		var base_pil := "pilier_mur_1p6" if nais < 2.4 else "pilier_mur_3p2"
		var h_pil := 1.62 if nais < 2.4 else 3.2
		v2["pilier"] = base_pil
		v2["ech_pilier"] = Vector3(1, (nais if avec_arche else h) / h_pil, 1)
		v2["naissance"] = nais
		v2["arche"] = gab[0] if avec_arche else ""
		v2["ech_arche"] = Vector3(sx, montee / float(gab[2]), 1.0)
	v2["haut_panneau"] = minf(float(v2["haut_panneau"]), h - 0.35)
	_piliers_panneaux(k, m, v2, obst)
	# --- bannières rouges à croix (vues 2 et 6) si le récit n'en a posé aucune
	if v2["bannieres_auto"] and d.nb_bannieres == k._v2_ban0 and h >= 3.5:
		var th: String = m.get("theme", "tombeau")
		var froid := th == "glace" or th == "givre"
		var murs: Array = ["N", "S"] if long_x else ["O", "E"]
		var nb_b := 0
		for c: String in murs:
			var obs_b: Array = (obst[c] as Array).duplicate()
			for oc: Array in k._occ_mur:      # pas de bannière sur une applique
				if oc[0] == c:
					obs_b.append([oc[1], float(oc[2]) + 0.35])
			var libres := _libres_mur(k, m, c, obs_b, 0.5)
			libres.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] - a[0]) > (b[1] - b[0]))
			if libres.is_empty() or libres[0][1] - libres[0][0] < 1.4:
				continue
			var s: Array = libres[0]
			var a: float = (s[0] + s[1]) * 0.5 + r.randf_range(-0.25, 0.25) * (s[1] - s[0] - 1.4)
			var pm := k.plan_mur(m, c)
			var haut := y + minf(h - 0.45, 4.8)
			var lon := clampf(haut - y - 1.5, 1.4, 2.6)
			d.banniere(k.pt_mur(m, c, a, haut, 0.0), pm["vers"], lon, 0.9, Color(0.2, 0.27, 0.46) if froid else Color(0.5, 0.07, 0.09), "croix", r.randi_range(0, 2), Color(0.82, 0.86, 0.95) if froid else Color(1.0, 0.78, 0.3))
			nb_b += 1
			if nb_b >= 2:
				break
	# --- lumières des candélabres de statue, dans le budget de la salle
	var allumees := 0
	for lp: Vector3 in k._v2_lum:
		if d.toutes.size() - k._n_lum0 >= 6:
			break
		# limite du rendu mobile : 8 lumières par maillage ; un maillage à moins de ~5 m de cette lumière ne doit pas déjà en voir 7
		var lw_ := d.xf * lp
		var voisines := 0
		for l: OmniLight3D in d.toutes:
			if l.position.distance_to(lw_) < l.omni_range + 5.0:
				voisines += 1
		if voisines >= 6:
			continue
		d.lumiere(lp, CrypteDecor.FEU_BOUGIE, 0.7, 3.8, 1.5)
		allumees += 1
	var st: Dictionary = k.v2_stats.get(m["id"], {})
	st["lumieres_statue"] = allumees
	st["lumieres_salle"] = d.toutes.size() - k._n_lum0
	st["piliers"] = (v2["piliers"] as Array).size()
	st["arche"] = v2["arche"]
	st["bannieres"] = d.nb_bannieres - k._v2_ban0
	k.v2_stats[m["id"]] = st

## Éboulis, dalles soulevées, givre en décalques, flaques (emplacements d'eau + placeholder).
static func _sol(k: DonjonKit, m: Dictionary, v2: Dictionary, y: float) -> void:
	var d := k.d
	var r := d.rng_deco
	var dim: Vector2 = m["dim"]
	for s: Dictionary in v2["eboulis"]:
		var p := k.lw(s["pos"])
		d.modele(s.get("mod", "eboulis_a"), Vector3(p.x, y, p.z), s.get("lacet", r.randf() * TAU))
	for s: Dictionary in v2["dalles"]:
		var p := k.lw(s["pos"])
		d.modele(s.get("mod", "dalles_a"), Vector3(p.x, y, p.z), s.get("lacet", r.randf() * TAU))
	for s: Dictionary in v2["flaques"]:
		var p := k.lw(s["pos"])
		d.flaque(Vector3(p.x, y, p.z), float(s.get("r", 0.8)), int(s.get("graine", 1)))
	# givre : un liseré irrégulier au pied de chaque mur, quelques plaques dans les angles et au sol (jamais sur les passages d'ouverture)
	var cx := dim.x * 0.5 - 0.3
	var cz := dim.y * 0.5 - 0.3
	for cn: Array in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		d.givre_decal(Vector3(cn[0] * (cx - r.randf_range(0.3, 0.7)), y, cn[1] * (cz - r.randf_range(0.3, 0.7))), Vector2(r.randf_range(1.0, 1.6), r.randf_range(1.0, 1.6)), r.randf() * TAU)
	for i in int(v2["givre"]):
		var c: String = ["N", "S", "E", "O"][r.randi_range(0, 3)]
		var pm := k.plan_mur(m, c)
		var Lw := dim.x if pm["horiz"] else dim.y
		var p := k.pt_mur(m, c, r.randf_range(-Lw * 0.5 + 1.2, Lw * 0.5 - 1.2), y, r.randf_range(0.5, 0.9))
		d.givre_decal(p, Vector2(r.randf_range(0.8, 1.5), r.randf_range(0.6, 1.1)), r.randf() * TAU)

## Lustre de fer posé à la voûte : chaîne, cercle à bougies (module Blender), flammes, halo.
static func lustre(d: CrypteDecor, plafond: Vector3, chute: float) -> void:
	d.j0("lustre_v2")
	var c := plafond - Vector3(0, chute, 0)
	d.chaine(plafond, c + Vector3(0, 0.55, 0))
	for fp: Vector3 in d.modele("lustre_fer", c):
		d.flamme(fp, 0.55)
	d.carte("halo", c + Vector3(0, 0.15, 0), Vector3.UP, 1.8, 1.8)
	d.j1()

# ------------------------------------------------------------------ COULOIR
## Couloir (axe long = z local, 3,2 m de large, plafond 3 m) : arches en voussoirs sur piliers engagés tous les 4 m, panneaux de
## maçonnerie entre eux, appliques décalées des ouvertures, éboulis et dalles soulevées sur les bords, givre en décalques, chaînes.
static func couloir(k: DonjonKit, m: Dictionary) -> void:
	var d := k.d
	var v2 := reglages(m)
	var dim: Vector2 = m["dim"]
	var L := dim.y
	var y := float(m.get("y", 0.0))
	var h := float(m.get("h", 3.0))
	var r := d.rng_deco
	var th: String = m.get("theme", "tombeau")
	k._lanes = [[Vector2(0, -L * 0.5), Vector2(0, L * 0.5)]]
	if v2["auto"] and not (m.get("v2", {}) as Dictionary).has("arche"):      # couloir de 3,2 m : petites arches sur piliers de 1,6 m
		v2["arche"] = "arche_2p0"
		v2["pilier"] = "pilier_mur_1p6"
		v2["naissance"] = 1.6
	var nais := float(v2.get("naissance", 1.6))
	var obst: Dictionary = {"O": [], "E": []}
	var obst_auto: Dictionary = _obstacles(k, m, v2) if v2["auto"] else {"N": [], "S": [], "O": [], "E": []}
	var z := -L * 0.5 + 2.0
	while z < L * 0.5 - 1.5:
		var libre_ := true
		for c: String in ["O", "E"]:
			for ou: Array in m.get("ouv", []):
				if ou[0] == c and absf(z - float(ou[1])) < float(ou[2]) * 0.5 + 0.7:
					libre_ = false
			for ob: Array in obst_auto[c]:
				if absf(z - float(ob[0])) < float(ob[1]) + 0.45:
					libre_ = false
		if libre_:
			d.modele(v2["arche"], Vector3(0, y + nais, z), 0.0, Vector3((dim.x - 0.6 - 0.64) / 2.0, 1.0, 1.0) if v2["auto"] else Vector3.ONE)
			for c: String in ["O", "E"]:
				var pm := k.plan_mur(m, c)
				var vv: Vector3 = pm["vers"]
				d.modele(v2["pilier"], Vector3(pm["plan"], y, z), atan2(vv.x, vv.z))
				(obst[c] as Array).append([z, 0.4])
		z += 4.0
	for c: String in ["O", "E"]:
		(obst[c] as Array).append_array(obst_auto[c])
	# panneaux de maçonnerie entre les piliers
	for c: String in ["O", "E"]:
		for s: Array in _libres_mur(k, m, c, obst[c], 0.2):
			if s[1] - s[0] > 0.9:
				_panneaux(k, m, c, s[0], s[1], y, h)
	# appliques : au milieu des travées, jamais dans une ouverture
	var nb: int = m.get("lum", {}).get("appliques", maxi(1, int((L - 2.0) / 8.0) + (1 if L > 7.0 else 0)))
	var imposees: Array = v2.get("appliques", [])      # table : [{cote, z (repère crypte)}] (couloir des niches : hors des niches)
	if not imposees.is_empty():
		nb = imposees.size()
	var sg := 1.0 if d.rng.randf() < 0.5 else -1.0
	for i in nb:
		var zz := lerpf(-L * 0.5 + 2.5, L * 0.5 - 2.5, (i + 0.5) / nb) if nb > 1 else 0.0
		var cote := "E" if sg > 0.0 else "O"
		for ou: Array in m.get("ouv", []):
			if ou[0] == cote and absf(zz - float(ou[1])) < float(ou[2]) * 0.5 + 0.5:
				cote = "O" if cote == "E" else "E"
		if not imposees.is_empty():
			cote = imposees[i]["cote"]
			zz = k.lw(Vector3(0, 0, float(imposees[i]["z"]))).z
		var pm := k.plan_mur(m, cote)
		d.applique(Vector3(pm["plan"], y, zz) + (pm["vers"] as Vector3) * 0.3, pm["vers"], y + 2.0, 4.8, 1.6, true)      # sur les blocs du panneau
		k._jitter_derniere_lumiere(th == "glace")
		sg = -sg
	# auto : éboulis / dalles soulevées au bord, une flaque (emplacement d'eau) si le couloir est assez long
	if v2["auto"]:
		var zs: Array = []
		var zq := -L * 0.5 + 1.6
		while zq < L * 0.5 - 1.4:
			zs.append(zq)
			zq += 2.3
		for zz: float in zs:
			var t := r.randf()
			var sx := 1.0 if r.randf() < 0.5 else -1.0
			var p := Vector3(sx * (dim.x * 0.5 - 0.75), y, zz + r.randf_range(-0.5, 0.5))
			var lac := r.randf() * TAU if t < 0.22 else 0.0
			var md: String = ["dalles_a", "dalles_b", "dalles_c"][r.randi_range(0, 2)] if (t >= 0.22 and t < 0.5) else ""
			# audit : ni contre un pilier engagé ou une niche, ni sur une accroche (gardien, coffre), ni dans un objet du récit
			var place := true
			for ob: Array in obst["E" if sx > 0.0 else "O"]:
				if absf(float(ob[0]) - p.z) < float(ob[1]) + 0.75:
					place = false
			for rv: Array in k._reserves:
				if Vector2(p.x, p.z).distance_to(rv[0]) < 0.7 + float(rv[1]) * 0.6:
					place = false
			if not d.emprise_libre(p, 0.7, 0.05):
				place = false
			if not place:
				continue
			if t < 0.22:
				v2["eboulis"].append({"pos": k.mw(p), "mod": "eboulis_c", "lacet": lac})
			elif t < 0.5:
				v2["dalles"].append({"pos": k.mw(p + Vector3(-sx * 0.4, 0, 0)), "mod": md})
		if L >= 7.0:
			var fx := r.randf_range(-0.4, 0.4) * 0.0      # dans l'axe : à ±0,4 m elle passait sous les piliers engagés
			var pf := Vector3(fx, y, r.randf_range(-L * 0.3, L * 0.3))
			var rf := r.randf_range(0.45, 0.6)
			var gf := r.randi_range(1, 99)
			if d.emprise_libre(pf, rf, 0.05):      # ni sous un coffre ni sous un objet du récit
				v2["flaques"].append({"pos": k.mw(pf), "r": rf, "graine": gf})
		if th == "givre" or th == "glace":
			v2["givre"] = 12
	# éboulis et dalles soulevées au pied des murs, givre, flaque (placeholder), toiles, chaînes
	for s: Dictionary in v2["eboulis"]:
		var p := k.lw(s["pos"])
		d.modele(s.get("mod", "eboulis_c"), Vector3(p.x, y, p.z), s.get("lacet", r.randf() * TAU))
	for s: Dictionary in v2["dalles"]:
		var p := k.lw(s["pos"])
		d.modele(s.get("mod", "dalles_a"), Vector3(p.x, y, p.z), s.get("lacet", r.randf() * TAU))
	for s: Dictionary in v2["flaques"]:
		var p := k.lw(s["pos"])
		d.flaque(Vector3(p.x, y, p.z), float(s.get("r", 0.6)), int(s.get("graine", 1)))
	var zg := -L * 0.5 + 1.2
	var p_givre := 0.6 if int(v2["givre"]) <= 6 else 0.9
	while zg < L * 0.5 - 1.0:
		for s: float in [-1.0, 1.0]:
			if r.randf() < p_givre:
				d.givre_decal(Vector3(s * (dim.x * 0.5 - 0.75), y, zg + r.randf_range(-0.4, 0.4)), Vector2(r.randf_range(0.5, 0.8), r.randf_range(0.8, 1.4)), r.randf_range(-0.3, 0.3))
		zg += 1.4
	d.poussiere(Vector3(0, y + h * 0.45, 0), Vector3(1.0, h * 0.4, L * 0.4), 18)
	var zc := -L * 0.5 + 4.0
	while zc < L * 0.5 - 1.5:
		var hx := r.randf_range(-0.4, 0.4)
		d.chaine(Vector3(hx, y + h, zc), Vector3(hx, y + h - r.randf_range(0.5, 0.9), zc))
		zc += 4.0
	for cn: Array in [[-1, -1], [1, 1]]:
		if d.rng.randf() < 0.7:
			d.toile(Vector3(cn[0] * (dim.x * 0.5 - 0.3), y + h, cn[1] * (L * 0.5 - 0.3)), Vector3(-cn[0], 0, 0), Vector3(0, 0, -cn[1]))
	if m.get("detritus", true):
		var t := -L * 0.5 + 2.5
		while t < L * 0.5 - 1.5:
			var po := Vector3(k.alea(-0.9, 0.9) * 0.45, y, t)      # au milieu : plus dans les piliers engagés
			var libre_os := d.emprise_libre(po, 0.45, 0.05)
			for rv: Array in k._reserves:
				if Vector2(po.x, po.z).distance_to(rv[0]) < 0.45 + float(rv[1]) * 0.6:
					libre_os = false
			d.muet = not libre_os      # occupé (indice de dalle, os du récit) : tirages faits, rien posé
			d.os_tas(po, 3, 0.3)
			d.muet = false
			t += 4.0
	if th == "givre" or th == "glace":
		var kk := maxi(1, int(L / 4.0))
		for i in kk:
			k.glacon(Vector3(k.alea(-0.7, 0.7), y + h, lerpf(-L * 0.5 + 1.5, L * 0.5 - 1.5, (i + 0.5) / kk)), k.alea(0.5, 0.9), 0.12)
		k.souffle(Vector3(0, y + 1.0, 0), Vector3(0.9, 0.8, L * 0.5 - 1.0), Vector3(0, 0, -1), clampi(int(L * 2.5), 10, 30))

# ------------------------------------------------------------------ PIÈCES DU TERTRE (C4b)
## Vestibule, alcôve d'Eirik et couloir de la herse : pièces uniques bâties par tertre.gd (hors kit). C4b (2026-10-23) les passe en v2
## avec le mode « pilote » (table explicite, `auto: false`) : rien n'est tiré au hasard près des interactions (fresque, corps d'Eirik,
## levier, herse). Collisions, interactions et lumières de tertre.gd INCHANGÉES ; seul l'habillage s'ajoute.
## Usage (tertre.gd) : `CrypteV2.tertre_debut(d)` avant `d.salle(...)` (dalles irrégulières), puis le récit de la pièce, puis
## `CrypteV2.piece_tertre(d, id, x0, x1, z0, z1, h, ouvertures, table)` (mêmes arguments que d.salle + table v2), qui remet tout à zéro.

static func tertre_actif() -> bool:
	return not OS.get_cmdline_user_args().has("--crypte-v1")

static func tertre_debut(d: CrypteDecor) -> void:
	if tertre_actif():
		d.theme = THEME
		d.v2 = true

## Gabarit d'arche (module, portée, flèche, épaisseur) et hauteur de naissance pour une pièce de largeur `court` et de hauteur `h`
## (même calcul que le mode auto de finir()).
static func _gabarit(court: float, h: float) -> Dictionary:
	var portee := court - 0.6 - 0.68
	var gab: Array = ["arche_2p0", 2.0, 1.0, 0.3] if portee <= 3.0 else (["arche_4p0", 4.0, 2.2, 0.36] if portee <= 7.0 else ["arche_10p7", 10.7, 2.3, 0.44])
	var sx: float = portee / float(gab[1])
	var montee: float = float(gab[2]) * (sx if float(gab[1]) < 10.0 else minf(sx, 1.15))
	var nais := clampf(h - montee - float(gab[3]) - 0.25, 1.6, 3.4)
	if nais + montee + float(gab[3]) > h - 0.1:
		montee = h - 0.1 - float(gab[3]) - nais
	var h_pil := 1.62 if nais < 2.4 else 3.2
	return {"pilier": "pilier_mur_1p6" if nais < 2.4 else "pilier_mur_3p2", "ech_pilier": Vector3(1, nais / h_pil, 1), "naissance": nais,
		"arche": gab[0] if montee >= 0.6 else "", "ech_arche": Vector3(sx, montee / float(gab[2]), 1.0)}

static func piece_tertre(d: CrypteDecor, id: String, x0: float, x1: float, z0: float, z1: float, h: float, ouvertures: Array, table: Dictionary) -> void:
	if not tertre_actif():
		return
	var centre := Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	var dim := Vector2(absf(x1 - x0), absf(z1 - z0))
	var cotes := {"nord": "N", "sud": "S", "ouest": "O", "est": "E"}
	var ouv: Array = []
	for o: Array in ouvertures:
		var c: String = cotes[o[0]]
		ouv.append([c, float(o[1]) - (centre.x if c == "N" or c == "S" else centre.z), float(o[2])])
	var t := table.duplicate(true)
	t["auto"] = false
	if t.get("arches", false):
		t.merge(_gabarit(minf(dim.x, dim.y), h), false)
	var m := {"id": id, "type": "salle", "dim": dim, "h": h, "y": 0.0, "ouv": ouv, "theme": "tombeau", "v2": t}
	var k := DonjonKit.new(d)
	d.xf = Transform3D(Basis(), centre)
	d.theme = THEME
	d.v2 = true
	d.module_id = id
	var occ: Array = []
	for oc: Array in d.occupations:      # objets plaqués au mur par tertre.gd (repère de la crypte) -> repère local
		occ.append([(oc[0] as Vector3) - centre, oc[1]])
	d.occupations = occ
	var emp_tertre := d.emprises
	d.emprises = []
	for e: Array in emp_tertre:      # emprises de tertre.gd (repère de la crypte) -> repère local de la pièce
		var e2 := e.duplicate()
		e2[0] = (e[0] as Vector3) - centre
		d.emprises.append(e2)
	var v2 := reglages(m)
	if t.get("arches", false) or not (v2["piliers"] as Array).is_empty() or v2["panneaux"]:
		v2["haut_panneau"] = minf(float(v2["haut_panneau"]), h - 0.35)
		_piliers_panneaux(k, m, v2, _obstacles(k, m, v2))      # contourne ouvertures, réserves (fresque, appliques) et objets plaqués
	if v2["lustres"] and h >= 3.6 and dim.x * dim.y >= 36.0:
		lustre(d, Vector3(0, h, 0), clampf(h - 3.0, 0.8, 3.2))
	_donnees(k, m, v2, 0.0)
	d.poussiere(Vector3(0, h * 0.4, 0), Vector3(dim.x * 0.4, h * 0.35, dim.y * 0.4), 18)
	d.occupations = []
	for i in range(emp_tertre.size(), d.emprises.size()):      # ce que la table de la pièce a posé rejoint les emprises du tertre
		var e3: Array = d.emprises[i]
		e3[0] = (e3[0] as Vector3) + centre
		emp_tertre.append(e3)
	d.emprises = emp_tertre
	if t.get("chaines", false):
		var r := d.rng_deco
		var long_x := dim.x >= dim.y
		var L := dim.x if long_x else dim.y
		var zc := -L * 0.5 + 2.0
		while zc < L * 0.5 - 1.5:
			var hx := r.randf_range(-0.4, 0.4)
			var p := Vector3(zc, 0, hx) if long_x else Vector3(hx, 0, zc)
			d.chaine(p + Vector3(0, h, 0), p + Vector3(0, h - r.randf_range(0.5, 0.9), 0))
			zc += 3.0
	d.xf = Transform3D.IDENTITY
	d.theme = {}
	d.v2 = false
	d.module_id = ""
