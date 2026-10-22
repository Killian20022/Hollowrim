class_name CrypteV2
extends RefCounted
## Crypte v2 (2026-10-22) : habillage GRAPHIQUE d'une salle ou d'un couloir du kit de donjon à partir des modules Blender
## (sources_blender/scripts/crypte_modules_v2.py -> assets/crypte/modules/crypte_v2.dat) et de la table `v2` du module.
## Référence : references/crypte_v2_planche.png (vues 2 « salle principale », 3 « couloir », 6 « salle de tombeau »).
## Rien ne touche au gameplay : ni salle, ni ouverture, ni accroche (ennemis, coffres, interactions, mécanismes) ; seules quelques pièces
## posées contre un mur ou au centre ont une collision (sarcophage), et seulement là où `libre()` l'autorise.
##
## ACTIVATION : ajouter au dictionnaire d'un module de CrypteDonjon.plan() une clé `"v2": {...}` (voir DEFAUTS ci-dessous pour les champs).
## Le module reçoit alors : sol en dalles irrégulières, panneaux de maçonnerie en relief sur les murs, piliers + arches en voussoirs,
## éboulis, dalles soulevées, givre en décalques, lustres de fer, et (selon la table) statues, sarcophages, candélabres, bannières, flaques.

## Matières remplacées dans tout le module (voir CrypteDecor.theme).
const THEME := {"dalle0": "dalle_v2"}

## Valeurs par défaut des champs de `v2` ; chaque module en surcharge ce qu'il veut. Positions : repère de la CRYPTE (comme les accroches),
## converties en repère local ici.
const DEFAUTS := {
	"piliers": [],                 # abscisses locales des piliers/arches le long des murs longs (salle) ; couloir : calculé (toutes les 4 m)
	"pilier": "pilier_mur_3p2",    # module Blender du pilier
	"naissance": 3.2,              # hauteur de la naissance des arches (= hauteur du pilier)
	"arche": "arche_10p7",         # module Blender de l'arche (portée = distance entre les faces des piliers)
	"panneaux": true,              # panneaux de maçonnerie en relief sur les murs
	"haut_panneau": 3.0,
	"lustres": true,
	"statues": [],                 # [{"pos": Vector3, "lacet": float}]
	"sarcophages": [],             # [{"pos": Vector3, "lacet": float, "collision": bool}]
	"candelabres": [],             # [{"pos": Vector3}]
	"bannieres": [],               # [{"pos": Vector3 (point haut sur le mur), "vers": Vector3, "long": float}]
	"eboulis": [],                 # [{"pos": Vector3, "mod": "eboulis_a", "lacet": float}]
	"dalles": [],                  # [{"pos": Vector3, "mod": "dalles_a", "lacet": float}]
	"flaques": [],                 # [{"pos": Vector3, "r": float}] : PLACEHOLDER, l'eau stylisée du système d'eau les remplacera
	"bougies": [],                 # [Vector3] : grappes de 3 bougies de suif posées au sol (flammes sans lumière)
	"givre": 6,                    # nombre de décalques de givre au sol (hors pied des murs)
}

static func reglages(m: Dictionary) -> Dictionary:
	var r: Dictionary = DEFAUTS.duplicate(true)
	r.merge(m.get("v2", {}), true)
	return r

## Actif si le module porte une table `v2` — sauf avec l'option `-- --crypte-v1` (captures « avant » à code identique).
static func actif(m: Dictionary) -> bool:
	return m.has("v2") and not OS.get_cmdline_user_args().has("--crypte-v1")

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

# ------------------------------------------------------------------ SALLE
static func salle(k: DonjonKit, m: Dictionary) -> void:
	var d := k.d
	var v2 := reglages(m)
	var dim: Vector2 = m["dim"]
	var h := float(m.get("h", 3.0))
	var y := float(m.get("y", 0.0))
	var r := d.rng_deco
	var long_x := dim.x >= dim.y
	var murs_long: Array = ["N", "S"] if long_x else ["O", "E"]
	var obstacles: Dictionary = {"N": [], "S": [], "O": [], "E": []}
	var pil_h: float = v2["naissance"]
	# --- piliers + arches en voussoirs (nervures en travers de la salle)
	for a: float in v2["piliers"]:
		var ok := true
		var pos_m: Array = []
		for c: String in murs_long:
			for ou: Array in m.get("ouv", []):
				if ou[0] == c and absf(a - float(ou[1])) < float(ou[2]) * 0.5 + 0.55:
					ok = false
			for oc: Array in k._occ_mur:
				if oc[0] == c and absf(float(oc[1]) - a) < float(oc[2]) + 0.4:
					ok = false
		if not ok:
			continue
		for c: String in murs_long:
			var pl := _mur(k, m, c, a, y)
			d.modele(v2["pilier"], pl[0], pl[1])
			(obstacles[c] as Array).append([a, 0.42])
			pos_m.append(pl[0])
		var f_dim: float = (dim.y if long_x else dim.x)
		var cx := Vector3(a, y + pil_h, 0.0) if long_x else Vector3(0.0, y + pil_h, a)
		d.modele(v2["arche"], cx, PI * 0.5 if long_x else 0.0)
	# --- panneaux de maçonnerie sur tous les murs
	if v2["panneaux"]:
		for c: String in ["N", "S", "O", "E"]:
			for s: Array in _libres_mur(k, m, c, obstacles[c]):
				if s[1] - s[0] > 0.9:
					_panneaux(k, m, c, s[0], s[1], y, float(v2["haut_panneau"]))
	# --- lustres de fer (Blender) : même nombre que le décor de base, sans lumière (les flammes et les halos suffisent)
	if v2["lustres"] and h >= 3.6 and dim.x * dim.y >= 36.0:
		var centres: Array = [Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))]
		if dim.x * dim.y >= 110.0:
			for sx: float in [-1.0, 1.0]:
				centres.append(Vector3(sx * dim.x * 0.27, 0, r.randf_range(-dim.y * 0.18, dim.y * 0.18)))
		for c3: Vector3 in centres:
			lustre(d, Vector3(c3.x, y + h, c3.z), clampf(h - 3.0, 0.8, 3.2))
	# --- données de la table
	for s: Dictionary in v2["statues"]:
		var p := k.lw(s["pos"])
		d.modele("statue_capuche", Vector3(p.x, y, p.z), k.lw_lacet(s.get("lacet", 0.0)))
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
		d.lumiere(Vector3(p.x, y + 1.7, p.z), CrypteDecor.FEU_BOUGIE, 0.9, 5.0, 1.6)
	for s: Dictionary in v2["bannieres"]:
		var p := k.lw(s["pos"])
		var vr: Vector3 = d.xf.basis.inverse() * (s["vers"] as Vector3)
		d.banniere(Vector3(p.x, y + p.y, p.z) + vr * 0.27, vr, s.get("long", 2.4), s.get("larg", 0.95), s.get("couleur", Color(0.5, 0.07, 0.09)), "croix", s.get("usure", 1), Color(1.0, 0.78, 0.3))
	for bp: Vector3 in v2["bougies"]:
		var p := k.lw(bp)
		for off: Vector3 in [Vector3(0, 0, 0), Vector3(0.14, 0, 0.09), Vector3(-0.1, 0, 0.13)]:
			d.bougie(Vector3(p.x, y, p.z) + off, false)
	_sol(k, m, v2, y)
	d.poussiere(Vector3(0, y + h * 0.4, 0), Vector3(dim.x * 0.4, h * 0.35, dim.y * 0.4), 26)

## Éboulis, dalles soulevées, givre en décalques, flaques (placeholder).
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
	var c := plafond - Vector3(0, chute, 0)
	d.chaine(plafond, c + Vector3(0, 0.55, 0))
	for fp: Vector3 in d.modele("lustre_fer", c):
		d.flamme(fp, 0.55)
	d.carte("halo", c + Vector3(0, 0.15, 0), Vector3.UP, 1.8, 1.8)

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
	k._lanes = [[Vector2(0, -L * 0.5), Vector2(0, L * 0.5)]]
	var nais := float(v2.get("naissance", 1.6))
	var obst: Dictionary = {"O": [], "E": []}
	var z := -L * 0.5 + 2.0
	while z < L * 0.5 - 1.5:
		var libre_ := true
		for c: String in ["O", "E"]:
			for ou: Array in m.get("ouv", []):
				if ou[0] == c and absf(z - float(ou[1])) < float(ou[2]) * 0.5 + 0.7:
					libre_ = false
		if libre_:
			d.modele(v2["arche"], Vector3(0, y + nais, z), 0.0)
			for c: String in ["O", "E"]:
				var pm := k.plan_mur(m, c)
				var vv: Vector3 = pm["vers"]
				d.modele(v2["pilier"], Vector3(pm["plan"], y, z), atan2(vv.x, vv.z))
				(obst[c] as Array).append([z, 0.4])
		z += 4.0
	# panneaux de maçonnerie entre les piliers
	for c: String in ["O", "E"]:
		for s: Array in _libres_mur(k, m, c, obst[c], 0.2):
			if s[1] - s[0] > 0.9:
				_panneaux(k, m, c, s[0], s[1], y, h)
	# appliques : au milieu des travées, jamais dans une ouverture
	var nb: int = m.get("lum", {}).get("appliques", maxi(1, int((L - 2.0) / 8.0) + (1 if L > 7.0 else 0)))
	var sg := 1.0 if d.rng.randf() < 0.5 else -1.0
	var th: String = m.get("theme", "tombeau")
	for i in nb:
		var zz := lerpf(-L * 0.5 + 2.5, L * 0.5 - 2.5, (i + 0.5) / nb) if nb > 1 else 0.0
		var cote := "E" if sg > 0.0 else "O"
		for ou: Array in m.get("ouv", []):
			if ou[0] == cote and absf(zz - float(ou[1])) < float(ou[2]) * 0.5 + 0.5:
				cote = "O" if cote == "E" else "E"
		var pm := k.plan_mur(m, cote)
		d.applique(Vector3(pm["plan"], y, zz) + (pm["vers"] as Vector3) * 0.2, pm["vers"], y + 2.0, 4.8, 1.6, true)
		k._jitter_derniere_lumiere(th == "glace")
		sg = -sg
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
	while zg < L * 0.5 - 1.0:
		for s: float in [-1.0, 1.0]:
			if r.randf() < 0.6:
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
			d.os_tas(Vector3(k.alea(-0.9, 0.9), y, t), 3, 0.3)
			t += 4.0
