class_name CasseObjets
extends Node
## CASSE GÉNÉRALE des objets du monde (chantier « cassables partout », 2026-11-23) : matières, seuils d'énergie, découpe du modèle en
## VRAIS morceaux, éclats physiques limités, effets (gerbe de gros pixels, poussière, son par matière, liquide renversé).
## Utilisé par ObjetVivant (petits objets fragiles, mobilier léger) ; Cassable (urnes, tonneaux, caisses de la crypte et de la grotte)
## garde ses éclats animés à la main mais prend les seuils de matière d'ici (recevoir_choc).
##
## ÉNERGIE d'un choc = ½ · masse · vitesse² (J), comparée au seuil de la matière (MATIERES) : poterie / verre fragiles, bois moyen,
## tonneau cerclé solide, fer et tissu incassables (ils rebondissent, cabossent). Un coup d'épée vaut COUP_LEGER / COUP_PUISSANT J.
## DÉCOUPE (une fois par modèle, en cache) : composantes connexes du maillage (pieds, assise, dossier d'une chaise ; cerclages d'un
## tonneau), puis les grosses composantes sont tranchées selon la matière (douelles : secteurs verticaux ; tessons : secteurs × étages),
## enfin les plus petites sont fusionnées jusqu'à MAX morceaux. Chaque morceau garde les matériaux et UV du modèle.
## ÉCLATS : RigidBody3D simples (boîte), calque 0 / masque 1 (le décor seulement : ni le joueur ni les autres éclats), gelés dès qu'ils
## sont posés (aucun coût physique), effacés après VIE s ; jamais plus de MAX_ECLATS dans le monde (les plus anciens partent d'abord).
## `--sans-cassables-partout` : rien de tout ça (ObjetsVivants ne capte pas le mobilier, les objets fragiles ne cassent pas).

static var actif := not ("--sans-cassables-partout" in OS.get_cmdline_user_args())

const COUP_LEGER := 60.0
const COUP_PUISSANT := 160.0
const MAX_ECLATS := 64
const VIE := 40.0
const GEL_APRES := 2.5        ## s : un éclat immobile depuis ce délai est gelé (corps statique)
const PORTEE_ECLATS := 30.0   ## au-delà de la caméra : gelé sur place

## matière -> seuil (J), profil de gerbe, sons, découpe (« douelles » / « tessons » / « planches »), morceaux max, poussière
const MATIERES := {
	"verre": {"seuil": 4.0, "gerbe": "verre", "sons": ["casse_glass_breaking_01", "casse_glass_breaking_02", "casse_glass_breaking_03"], "decoupe": "tessons", "max": 8},
	"oeuf": {"seuil": 1.2, "gerbe": "oeuf", "sons": ["casse_pot_02"], "decoupe": "tessons", "max": 3},
	"poterie": {"seuil": 14.0, "gerbe": "poterie", "sons": ["casse_pot_01", "casse_pot_02", "casse_rock_breaking_01"], "decoupe": "tessons", "max": 7, "poussiere": true},
	"bois_leger": {"seuil": 80.0, "gerbe": "bois", "sons": ["casse_wood_breaking_02", "casse_wood_breaking_04"], "decoupe": "planches", "max": 7, "poussiere": true},
	"bois": {"seuil": 200.0, "gerbe": "bois", "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "planches", "max": 8, "poussiere": true},
	"bois_ferre": {"seuil": 350.0, "gerbe": "bois", "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "planches", "max": 9, "poussiere": true},
	"tonneau": {"seuil": 300.0, "gerbe": "bois", "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "douelles", "max": 11, "poussiere": true},
	"fer": {"seuil": INF, "sons_choc": ["casse_metal_hit_01", "casse_metal_hit_02", "casse_metal_hit_03"]},
	# casse RÉALISTE (2026-11-24) : chaque matière a sa MANIÈRE de casser (« decoupe ») : fendre (bûche : un plan dans le fil du bois, 2 moitiés),
	# jointures (meuble assemblé : il se démonte par pièces, `min` / `max` morceaux), trancher (cassé net en `n` morceaux au travers :
	# manche, fruit, tissu qui se déchire ; `frac` = où passe la cassure). Seuils réglés : une bûche lancée doucement rebondit, il faut
	# un vrai choc (≥ ~8 m/s pour 4 kg) ou un coup puissant ; les bois fins cassent plus facilement.
	"buche": {"seuil": 150.0, "gerbe": "bois", "gerbe_k": 0.55, "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "fendre", "max": 2},
	"rondin": {"seuil": 260.0, "gerbe": "bois", "gerbe_k": 0.6, "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "fendre", "max": 2},
	"tronc": {"seuil": 420.0, "gerbe": "bois", "gerbe_k": 0.7, "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "fendre", "max": 2},
	"bucher": {"seuil": 200.0, "gerbe": "bois", "gerbe_k": 0.7, "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "jointures", "min": 2, "max": 5},
	"meuble_leger": {"seuil": 80.0, "gerbe": "bois", "sons": ["casse_wood_breaking_02", "casse_wood_breaking_04"], "decoupe": "jointures", "min": 3, "max": 6},
	"meuble": {"seuil": 200.0, "gerbe": "bois", "sons": ["casse_wood_breaking_01", "casse_wood_breaking_03"], "decoupe": "jointures", "min": 3, "max": 6},
	"cageot": {"seuil": 80.0, "gerbe": "bois", "sons": ["casse_wood_breaking_02", "casse_wood_breaking_04"], "decoupe": "jointures", "min": 3, "max": 6},
	"bouclier": {"seuil": 100.0, "gerbe": "bois", "sons": ["casse_wood_breaking_02", "casse_wood_breaking_04"], "decoupe": "jointures", "min": 2, "max": 3},
	"bois_outil": {"seuil": 60.0, "gerbe": "bois", "gerbe_k": 0.6, "sons": ["casse_wood_breaking_02", "casse_wood_breaking_04"], "decoupe": "trancher", "n": 2, "frac": 0.45},
	"bois_fin": {"seuil": 20.0, "gerbe": "bois", "gerbe_k": 0.6, "sons": ["casse_wood_breaking_02", "casse_wood_breaking_04"], "decoupe": "trancher", "n": 2, "frac": 0.5},
	# tissu : il ne se brise pas, il se DÉCHIRE (2 morceaux) et répand son contenu (poussière / grain) ; seuils élevés
	"tissu": {"seuil": 450.0, "gerbe": "poussiere", "sons": ["cloth1", "cloth2"], "sons_choc": ["cloth1", "cloth2"], "decoupe": "trancher", "n": 2, "frac": 0.5, "poussiere": true},
	"tissu_leger": {"seuil": 220.0, "gerbe": "poussiere", "sons": ["cloth1", "cloth2"], "sons_choc": ["cloth1", "cloth2"], "decoupe": "trancher", "n": 2, "frac": 0.5, "poussiere": true},
	"tissu_fin": {"seuil": 40.0, "gerbe": "poussiere", "sons": ["cloth1", "cloth2"], "sons_choc": ["cloth1", "cloth2"], "decoupe": "trancher", "n": 2, "frac": 0.5},
	# nourriture : s'écrase / éclate en 2 (3 pour une citrouille)
	"nourriture": {"seuil": 10.0, "gerbe": "nourriture", "sons": ["casse_pot_02", "cloth2"], "sons_choc": ["cloth1", "cloth2"], "decoupe": "trancher", "n": 2, "frac": 0.5},
	"citrouille": {"seuil": 40.0, "gerbe": "nourriture", "sons": ["casse_pot_02", "cloth2"], "sons_choc": ["cloth1", "cloth2"], "decoupe": "trancher", "n": 3},
	# papier, livres : incassables au lancer (ils rebondissent, bruit de livre)
	"papier": {"seuil": INF, "sons_choc": ["cloth1", "cloth2"]},
	"os": {"seuil": 20.0, "gerbe": "os", "sons": ["casse_rock_breaking_01", "casse_pot_01"], "decoupe": "tessons", "max": 4},
}
## Sons de choc sans casse (bois qui cogne) par matière ; défaut : vaisselle.
const SONS_CHOC := {"bois_leger": ["casse_wood_hit_01", "casse_wood_hit_02"], "bois": ["casse_wood_hit_01", "casse_wood_hit_03"],
	"tonneau": ["casse_wood_hit_03", "impactWood_heavy_000"], "buche": ["casse_wood_hit_03", "impactWood_heavy_000"],
	"rondin": ["casse_wood_hit_03", "impactWood_heavy_000"], "tronc": ["casse_wood_hit_03", "impactWood_heavy_000"], "bucher": ["casse_wood_hit_01", "casse_wood_hit_03"],
	"meuble_leger": ["casse_wood_hit_01", "casse_wood_hit_02"], "meuble": ["casse_wood_hit_01", "casse_wood_hit_03"], "cageot": ["casse_wood_hit_01", "casse_wood_hit_02"],
	"bouclier": ["casse_wood_hit_01", "casse_wood_hit_02"], "bois_outil": ["casse_wood_hit_01", "casse_wood_hit_02"], "bois_fin": ["casse_wood_hit_01", "casse_wood_hit_02"], "bois_ferre": ["casse_wood_hit_03", "impactWood_heavy_000"], "poterie": ["casse_dishes_01", "casse_dishes_02"], "verre": ["casse_dishes_02"]}

static func seuil(matiere: String) -> float:
	return float((MATIERES.get(matiere, {}) as Dictionary).get("seuil", INF))

static func fragile(matiere: String) -> bool:
	return seuil(matiere) < INF

static func energie(vitesse: Vector3, masse: float) -> float:
	return 0.5 * maxf(masse, 0.0) * vitesse.length_squared()

## Son d'un choc qui ne casse pas (rebond, cabosse) : volume selon l'énergie.
static func son_choc(n: Node, matiere: String, point: Vector3, e: float) -> void:
	var sons: Array = (MATIERES.get(matiere, {}) as Dictionary).get("sons_choc", SONS_CHOC.get(matiere, ["impactPlate_medium_000", "impactPlate_medium_001"]))
	if n != null and n.is_inside_tree():
		Sons.jouer_a(n, sons, point, clampf(-22.0 + 3.0 * log(maxf(e, 1.0)), -22.0, -4.0), 0.12)

# ------------------------------------------------------------------------------------------------ découpe (cache par modèle)

static var _decoupes := {}     ## "<id maillage>|<matière>" -> [{"m": ArrayMesh, "c": Vector3, "t": Vector3 (taille), "part": float}]
static var _donnees := {}      ## même clé -> découpe en données pures (préparée dans un fil de fond) : [{"s": [[V, N, UV, C, Material]], "c", "t", "part"}]
static var _verrou := Mutex.new()
static var _taches := {}       ## clé -> id de tâche WorkerThreadPool en cours

## Prépare la découpe d'un modèle dans un FIL DE FOND (données seules : aucun appel au moteur de rendu), dès la pose du mobilier :
## à la première casse il ne reste qu'à créer les maillages des morceaux. `morceaux_` = [[arrays, Material]] (repère du prop).
static func preparer(mesh: Mesh, morceaux_: Array, matiere: String) -> void:
	if mesh == null or not fragile(matiere):
		return
	var cle := "%d|%s" % [mesh.get_instance_id(), matiere]
	_ranger_taches()
	_verrou.lock()
	var deja := _donnees.has(cle) or _taches.has(cle)
	if not deja:
		_taches[cle] = -1
	_verrou.unlock()
	if deja:
		return
	var copie := morceaux_.duplicate()
	var id := WorkerThreadPool.add_task(func() -> void:
		var d := _decouper_donnees(copie, matiere)
		_verrou.lock()
		_donnees[cle] = d
		_verrou.unlock(), false, "decoupe " + cle)
	_verrou.lock()
	_taches[cle] = id
	_verrou.unlock()
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre != null:
		_assurer_gestion(arbre)      # le nœud de gestion attend les tâches finies (et toutes à la sortie)

## Tâches de découpe finies : attendues (sans attente réelle) et oubliées.
static func _ranger_taches() -> void:
	_verrou.lock()
	var finies := []
	for cle in _taches:
		var id: int = _taches[cle]
		if id >= 0 and WorkerThreadPool.is_task_completed(id):
			finies.append(cle)
	_verrou.unlock()
	for cle in finies:
		WorkerThreadPool.wait_for_task_completion(int(_taches[cle]))
		_verrou.lock()
		_taches.erase(cle)
		_verrou.unlock()

## Morceaux d'un maillage (repère du prop) pour une matière, maillages compris (fil principal). Préparés d'avance (preparer) : quelques
## dixièmes de ms ; sinon la découpe est faite sur place (première casse d'un modèle non préparé).
static func morceaux(mesh: Mesh, matiere: String) -> Array:
	if mesh == null:
		return []
	var cle := "%d|%s" % [mesh.get_instance_id(), matiere]
	if _decoupes.has(cle):
		return _decoupes[cle]
	_verrou.lock()
	var tache: int = _taches.get(cle, -2)
	_verrou.unlock()
	if tache >= 0:      # en cours : on l'attend (au pire quelques ms)
		WorkerThreadPool.wait_for_task_completion(tache)
		_verrou.lock()
		_taches.erase(cle)
		_verrou.unlock()
	_verrou.lock()
	var d: Array = _donnees.get(cle, [])
	_verrou.unlock()
	if d.is_empty():
		var src := []
		for k in mesh.get_surface_count():
			src.append([mesh.surface_get_arrays(k), mesh.surface_get_material(k)])
		d = _decouper_donnees(src, matiere)
	var res := []
	for m: Dictionary in d:
		var am := ArrayMesh.new()
		for e: Array in m["s"]:
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = e[0]
			if not (e[1] as PackedVector3Array).is_empty():
				arr[Mesh.ARRAY_NORMAL] = e[1]
			if not (e[2] as PackedVector2Array).is_empty():
				arr[Mesh.ARRAY_TEX_UV] = e[2]
			if not (e[3] as PackedColorArray).is_empty():
				arr[Mesh.ARRAY_COLOR] = e[3]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, e[4])
		res.append({"m": am, "c": m["c"], "t": m["t"], "part": m["part"]})
	_decoupes[cle] = res
	return res

## Découpe en DONNÉES (sûr dans un fil de fond) : `src` = [[arrays, Material]] ; renvoie [{"s": [[V, N, UV, C, Material]], "c", "t", "part"}].
static func _decouper_donnees(src: Array, matiere: String) -> Array:
	var prof: Dictionary = MATIERES.get(matiere, MATIERES["bois"])
	var maxi_n := int(prof.get("max", 8))
	var decoupe := String(prof.get("decoupe", "planches"))
	# 1. triangles de toutes les surfaces
	var surfs := []         # [arrays, Material]
	var tris := []          # PackedInt32Array par surface, 3 indices par triangle
	var bb := AABB()
	var premier := true
	for e: Array in src:
		var a: Array = e[0]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a.size() > Mesh.ARRAY_INDEX and a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if ii.is_empty():
			ii.resize(v.size())
			for k in v.size():
				ii[k] = k
		surfs.append([a, e[1]])
		tris.append(ii)
		for p in v:
			if premier:
				bb = AABB(p, Vector3.ZERO)
				premier = false
			else:
				bb = bb.expand(p)
	if premier:
		return []
	var centre := bb.get_center()
	var diag := maxf(bb.size.length(), 0.01)
	if decoupe == "fendre" or decoupe == "trancher":      # plan de coupe (vraie coupe des triangles, face de coupe refermée)
		return _decouper_plan(surfs, tris, prof, bb)
	# 2. composantes connexes (sommets confondus à 1 mm près), toutes surfaces confondues ; centre et boîte de chaque triangle
	var parent := PackedInt32Array()
	var t_s := PackedInt32Array()      # surface du triangle
	var t_i := PackedInt32Array()      # rang du 1er indice
	var t_c := PackedVector3Array()    # centre
	var vus := {}
	for s in surfs.size():
		var v: PackedVector3Array = (surfs[s][0] as Array)[Mesh.ARRAY_VERTEX]
		var ii: PackedInt32Array = tris[s]
		for t in range(0, ii.size() - 2, 3):
			var id := t_s.size()
			t_s.append(s)
			t_i.append(t)
			t_c.append((v[ii[t]] + v[ii[t + 1]] + v[ii[t + 2]]) / 3.0)
			parent.append(id)
			for j in 3:
				var q := v[ii[t + j]]
				var k := Vector3i(roundi(q.x * 1000.0), roundi(q.y * 1000.0), roundi(q.z * 1000.0))
				var autre: int = vus.get(k, -1)
				if autre >= 0:
					_unir(parent, id, autre)
				else:
					vus[k] = id
	var groupes := {}
	for id in t_s.size():
		var r := _racine(parent, id)
		if not groupes.has(r):
			groupes[r] = []
		(groupes[r] as Array).append(id)
	# 3. grosses composantes tranchées selon la découpe de la matière (le fer n'est jamais tranché : cerclage entier)
	var lots := []          # [triangles] (Array d'entiers)
	for r in groupes:
		var liste: Array = groupes[r]
		var gb := _boite_c(liste, t_c)
		var gros := gb.size.length() > diag * (0.5 if decoupe == "planches" else 0.35)
		var fer := est_fer(surfs[t_s[liste[0]]][1])
		if not gros or fer or liste.size() < 6:
			lots.append(liste)
			continue
		var secteurs := 3
		var etages := 2
		match decoupe:
			"douelles":
				secteurs = 8
				etages = 1
			"tessons":
				secteurs = 4
				etages = 2
			_:
				secteurs = 3 if gb.size.length() < diag * 0.8 else 4
				etages = 2
		var parts := {}
		for id: int in liste:
			var c := t_c[id] - centre
			var sct := clampi(int((atan2(c.z, c.x) + PI) / TAU * secteurs), 0, secteurs - 1)
			var et := clampi(int((c.y + bb.size.y * 0.5) / maxf(bb.size.y, 0.001) * etages), 0, etages - 1)
			var cle := sct * 8 + et
			if not parts.has(cle):
				parts[cle] = []
			(parts[cle] as Array).append(id)
		for cle in parts:
			lots.append(parts[cle])
	# 4. fusion des plus petits (clous, chevilles, éclats d'un seul triangle) jusqu'à maxi_n morceaux ; boîtes fusionnées sans recalcul
	var boites := []
	for l: Array in lots:
		boites.append(_boite_c(l, t_c))
	while lots.size() > 1 and (lots.size() > maxi_n or _a_minuscule(lots)):
		var ip := 0
		for i in lots.size():
			if (lots[i] as Array).size() < (lots[ip] as Array).size():
				ip = i
		var proche := -1
		var dmin := INF
		var cp: Vector3 = (boites[ip] as AABB).get_center()
		for i in lots.size():
			if i == ip:
				continue
			var d: float = (boites[i] as AABB).get_center().distance_to(cp)
			if d < dmin:
				dmin = d
				proche = i
		(lots[proche] as Array).append_array(lots[ip])
		boites[proche] = (boites[proche] as AABB).merge(boites[ip])
		lots.remove_at(ip)
		boites.remove_at(ip)
	# 5. sommets de chaque morceau (une entrée par surface source), recentrés sur le centre du morceau
	var total := float(t_s.size())
	var res := []
	for l: Array in lots:
		var par_s := {}
		var mb := AABB()
		var pr := true
		for id: int in l:
			var s := t_s[id]
			if not par_s.has(s):
				par_s[s] = []
			(par_s[s] as Array).append(t_i[id])
			var v: PackedVector3Array = (surfs[s][0] as Array)[Mesh.ARRAY_VERTEX]
			var ii: PackedInt32Array = tris[s]
			for j in 3:
				if pr:
					mb = AABB(v[ii[t_i[id] + j]], Vector3.ZERO)
					pr = false
				else:
					mb = mb.expand(v[ii[t_i[id] + j]])
		var cm := mb.get_center()
		var ent := []
		for s: int in par_s:
			var a: Array = surfs[s][0]
			var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var su: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var sc: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var ii: PackedInt32Array = tris[s]
			var idx := PackedInt32Array()
			for t: int in par_s[s]:
				idx.append(ii[t])
				idx.append(ii[t + 1])
				idx.append(ii[t + 2])
			var n := idx.size()
			var dv := PackedVector3Array()
			dv.resize(n)
			var dn := PackedVector3Array()
			var du := PackedVector2Array()
			var dc := PackedColorArray()
			if not sn.is_empty():
				dn.resize(n)
			if not su.is_empty():
				du.resize(n)
			if not sc.is_empty():
				dc.resize(n)
			for k in n:
				var q := idx[k]
				dv[k] = sv[q] - cm
				if not sn.is_empty():
					dn[k] = sn[q]
				if not su.is_empty():
					du[k] = su[q]
				if not sc.is_empty():
					dc[k] = sc[q]
			ent.append([dv, dn, du, dc, surfs[s][1]])
		res.append({"s": ent, "c": cm, "t": mb.size, "part": float(l.size()) / maxf(total, 1.0)})
	# jointures : pas assez de pièces séparées (meuble soudé d'un bloc) -> on tranche la plus grosse en 2, au plus 4 fois
	var mn := int(prof.get("min", 1))
	var essais := 0
	while res.size() < mn and essais < 4:
		essais += 1
		var ig := 0
		for i in res.size():
			if float((res[i] as Dictionary)["part"]) > float((res[ig] as Dictionary)["part"]):
				ig = i
		var gros_m: Dictionary = res[ig]
		var soupe := []
		for e: Array in gros_m["s"]:
			var dv: PackedVector3Array = (e[0] as PackedVector3Array).duplicate()
			for k in dv.size():
				dv[k] += gros_m["c"]
			soupe.append([dv, e[1], e[2], e[3], e[4]])
		var tg: Vector3 = gros_m["t"]
		var ia := 0
		for i in 3:
			if tg[i] > tg[ia]:
				ia = i
		var axe := Vector3.ZERO
		axe[ia] = 1.0
		var cg: Vector3 = gros_m["c"]
		var deux := _couper_soupe(soupe, axe, cg[ia], true)
		var pa := _piece(deux[0], float(gros_m["part"]) * 0.5)
		var pb := _piece(deux[1], float(gros_m["part"]) * 0.5)
		if pa.is_empty() or pb.is_empty():
			break
		res.remove_at(ig)
		res.append(pa)
		res.append(pb)
	return res

# ------------------------------------------------------------------------------------------------ coupe par un plan (fendre, trancher)

## « fendre » (bûche : plan par l'axe LONG, dans le fil du bois : 2 moitiés) et « trancher » (cassé net AU TRAVERS de l'axe long, ou de
## l'axe vertical si le volume est ramassé, `n` morceaux ; `frac` = position de la cassure pour n = 2). Les triangles traversés sont
## vraiment coupés, la face de coupe est refermée (enveloppe convexe des points de coupe) : chaque morceau est plein et crédible.
static func _decouper_plan(surfs: Array, tris: Array, prof: Dictionary, bb: AABB) -> Array:
	var soupe := _soupe_depuis(surfs, tris)
	var t := bb.size
	var ia := 0
	for i in 3:
		if t[i] > t[ia]:
			ia = i
	var axe_i := ia
	if String(prof.get("decoupe", "")) == "fendre":
		var autres := [0, 1, 2]
		autres.erase(ia)
		axe_i = int(autres[0]) if t[int(autres[0])] >= t[int(autres[1])] else int(autres[1])
	elif t.y >= t[ia] * 0.85:
		axe_i = 1
	var axe := Vector3.ZERO
	axe[axe_i] = 1.0
	var n := maxi(int(prof.get("n", 2)), 2)
	var fracs := []
	if n == 2:
		fracs = [clampf(float(prof.get("frac", 0.5)), 0.2, 0.8)]
	else:
		for k in range(1, n):
			fracs.append(float(k) / n)
	var res := []
	var reste := soupe
	var avant := 0.0
	for f: float in fracs:
		var d := _couper_soupe(reste, axe, bb.position[axe_i] + f * t[axe_i], true)
		var p := _piece(d[0], f - avant)
		if not p.is_empty():
			res.append(p)
		reste = d[1]
		avant = f
	var dernier := _piece(reste, 1.0 - avant)
	if not dernier.is_empty():
		res.append(dernier)
	if res.size() < 2:      # la coupe a raté (volume vide d'un côté) : le modèle entier, comme avant
		return [_piece(soupe, 1.0)]
	return res

## Triangles NON indexés de toutes les surfaces : [[V, N, UV, C, Material]].
static func _soupe_depuis(surfs: Array, tris: Array) -> Array:
	var res := []
	for s in surfs.size():
		var a: Array = (surfs[s] as Array)[0]
		var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var su: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var sc: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var ii: PackedInt32Array = tris[s]
		var n := ii.size() - ii.size() % 3
		var dv := PackedVector3Array()
		var dn := PackedVector3Array()
		var du := PackedVector2Array()
		var dc := PackedColorArray()
		dv.resize(n)
		if not sn.is_empty():
			dn.resize(n)
		if not su.is_empty():
			du.resize(n)
		if not sc.is_empty():
			dc.resize(n)
		for k in n:
			var q := ii[k]
			dv[k] = sv[q]
			if not sn.is_empty():
				dn[k] = sn[q]
			if not su.is_empty():
				du[k] = su[q]
			if not sc.is_empty():
				dc[k] = sc[q]
		res.append([dv, dn, du, dc, (surfs[s] as Array)[1]])
	return res

## Morceau recentré depuis une soupe de triangles ; {} si elle est vide. `part` : part de la masse d'origine.
static func _piece(soupe: Array, part: float) -> Dictionary:
	var mb := AABB()
	var pr := true
	for e: Array in soupe:
		for p: Vector3 in (e[0] as PackedVector3Array):
			if pr:
				mb = AABB(p, Vector3.ZERO)
				pr = false
			else:
				mb = mb.expand(p)
	if pr:
		return {}
	var cm := mb.get_center()
	var ent := []
	for e: Array in soupe:
		var dv: PackedVector3Array = (e[0] as PackedVector3Array).duplicate()
		if dv.is_empty():
			continue
		for k in dv.size():
			dv[k] -= cm
		ent.append([dv, e[1], e[2], e[3], e[4]])
	return {"s": ent, "c": cm, "t": mb.size, "part": part}

## Coupe la soupe par le plan axe·p = pos ; renvoie [côté négatif, côté positif] (soupes) ; `cap` : refermer la face de coupe.
static func _couper_soupe(soupe: Array, axe: Vector3, pos: float, cap: bool) -> Array:
	var neg := []
	var plus := []
	var pts := []      # points de coupe : [Vector3, UV, Color, indice d'entrée]
	for ie in soupe.size():
		var e: Array = soupe[ie]
		var dv: PackedVector3Array = e[0]
		var a_n := not (e[1] as PackedVector3Array).is_empty()
		var a_u := not (e[2] as PackedVector2Array).is_empty()
		var a_c := not (e[3] as PackedColorArray).is_empty()
		var en := Sac.new()
		var ep := Sac.new()
		en.mat = e[4]
		ep.mat = e[4]
		for t in range(0, dv.size() - 2, 3):
			var d0 := axe.dot(dv[t]) - pos
			var d1 := axe.dot(dv[t + 1]) - pos
			var d2 := axe.dot(dv[t + 2]) - pos
			if d0 >= -1e-5 and d1 >= -1e-5 and d2 >= -1e-5:
				_ajouter_tri(ep, e, t, t + 1, t + 2)
				continue
			if d0 <= 1e-5 and d1 <= 1e-5 and d2 <= 1e-5:
				_ajouter_tri(en, e, t, t + 1, t + 2)
				continue
			var ds := [d0, d1, d2]
			var poly_n := []
			var poly_p := []
			for k in 3:
				var k2 := (k + 1) % 3
				var dc_: float = ds[k]
				var dn_: float = ds[k2]
				var vk := _sommet(e, t + k)
				if dc_ >= 0.0:
					poly_p.append(vk)
				if dc_ <= 0.0:
					poly_n.append(vk)
				if (dc_ > 0.0 and dn_ < 0.0) or (dc_ < 0.0 and dn_ > 0.0):
					var u := dc_ / (dc_ - dn_)
					var vn := _sommet(e, t + k2)
					var vi := [(vk[0] as Vector3).lerp(vn[0], u), ((vk[1] as Vector3).lerp(vn[1], u)).normalized() if a_n else Vector3.ZERO,
						(vk[2] as Vector2).lerp(vn[2], u), (vk[3] as Color).lerp(vn[3], u)]
					poly_p.append(vi)
					poly_n.append(vi)
					pts.append([vi[0], vi[2], vi[3], ie])
			_ajouter_poly(ep, poly_p, a_n, a_u, a_c)
			_ajouter_poly(en, poly_n, a_n, a_u, a_c)
		neg.append(en)
		plus.append(ep)
	if cap and pts.size() >= 3:
		_refermer(neg, plus, pts, axe, soupe)
	return [neg.map(func(x: Sac) -> Array: return x.vers_entree()), plus.map(func(x: Sac) -> Array: return x.vers_entree())]

## Sac de triangles d'un côté de la coupe (objet : les tableaux sont modifiés en place).
class Sac extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var u := PackedVector2Array()
	var c := PackedColorArray()
	var mat: Material
	func vers_entree() -> Array:
		return [v, n, u, c, mat]

static func _sommet(e: Array, i: int) -> Array:
	var sn: PackedVector3Array = e[1]
	var su: PackedVector2Array = e[2]
	var sc: PackedColorArray = e[3]
	return [(e[0] as PackedVector3Array)[i], sn[i] if not sn.is_empty() else Vector3.ZERO, su[i] if not su.is_empty() else Vector2.ZERO,
		sc[i] if not sc.is_empty() else Color.WHITE]

static func _ajouter_tri(dst: Sac, e: Array, a: int, b: int, c: int) -> void:
	for i: int in [a, b, c]:
		dst.v.append((e[0] as PackedVector3Array)[i])
		if not (e[1] as PackedVector3Array).is_empty():
			dst.n.append((e[1] as PackedVector3Array)[i])
		if not (e[2] as PackedVector2Array).is_empty():
			dst.u.append((e[2] as PackedVector2Array)[i])
		if not (e[3] as PackedColorArray).is_empty():
			dst.c.append((e[3] as PackedColorArray)[i])

## Polygone (3 ou 4 sommets [P, N, UV, C], même sens que le triangle d'origine) en éventail.
static func _ajouter_poly(dst: Sac, poly: Array, a_n: bool, a_u: bool, a_c: bool) -> void:
	for k in range(1, poly.size() - 1):
		for v: Array in [poly[0], poly[k], poly[k + 1]]:
			dst.v.append(v[0])
			if a_n:
				dst.n.append(v[1])
			if a_u:
				dst.u.append(v[2])
			if a_c:
				dst.c.append(v[3])

## Face de coupe : enveloppe convexe des points de coupe (dans le plan), en éventail ; une face par morceau, normale vers le vide.
static func _refermer(neg: Array, plus: Array, pts: Array, axe: Vector3, soupe: Array) -> void:
	var ia := 0
	for i in 3:
		if absf(axe[i]) > 0.5:
			ia = i
	var iu := (ia + 1) % 3
	var iv := (ia + 2) % 3
	var ordre := range(pts.size())
	ordre.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector3 = pts[a][0]
		var pb: Vector3 = pts[b][0]
		return pa[iu] < pb[iu] or (pa[iu] == pb[iu] and pa[iv] < pb[iv]))
	var hull := []
	for passe in 2:
		var debut := hull.size()
		for i in (ordre if passe == 0 else range(ordre.size() - 1, -1, -1)):
			var p: Vector3 = pts[i][0]
			while hull.size() >= debut + 2 and _croix(pts[hull[hull.size() - 2]][0], pts[hull[hull.size() - 1]][0], p, iu, iv) <= 1e-9:
				hull.pop_back()
			hull.append(i)
		hull.pop_back()
	if hull.size() < 3:
		return
	var c := Vector3.ZERO
	var uv := Vector2.ZERO
	var col := Color(0, 0, 0, 0)
	var comptes := {}
	for i: int in hull:
		c += pts[i][0] as Vector3
		uv += pts[i][1] as Vector2
		col += pts[i][2] as Color
		comptes[pts[i][3]] = int(comptes.get(pts[i][3], 0)) + 1
	var nh := float(hull.size())
	c /= nh
	uv /= nh
	col = Color(col.r / nh, col.g / nh, col.b / nh, col.a / nh)
	var ie := 0
	for k in comptes:
		if int(comptes[k]) > int(comptes.get(ie, 0)):
			ie = k
	for cote in 2:
		var dst: Sac = (neg if cote == 0 else plus)[ie]
		var normale := axe if cote == 0 else -axe      # le morceau négatif regarde vers +axe
		var a_n := not (soupe[ie][1] as PackedVector3Array).is_empty()
		var a_u := not (soupe[ie][2] as PackedVector2Array).is_empty()
		var a_c := not (soupe[ie][3] as PackedColorArray).is_empty()
		for k in hull.size():
			var p1: Vector3 = pts[hull[k]][0]
			var p2: Vector3 = pts[hull[(k + 1) % hull.size()]][0]
			var sommets := [c, p1, p2]
			if (p1 - c).cross(p2 - c).dot(normale) > 0.0:      # face avant = sens horaire (Godot)
				sommets = [c, p2, p1]
			for p: Vector3 in sommets:
				dst.v.append(p)
				if a_n:
					dst.n.append(normale)
				if a_u:
					dst.u.append(uv)
				if a_c:
					dst.c.append(col)

static func _croix(o: Vector3, a: Vector3, b: Vector3, iu: int, iv: int) -> float:
	return (a[iu] - o[iu]) * (b[iv] - o[iv]) - (a[iv] - o[iv]) * (b[iu] - o[iu])

static func _boite_c(liste: Array, t_c: PackedVector3Array) -> AABB:
	var b := AABB(t_c[liste[0]], Vector3.ZERO)
	for id: int in liste:
		b = b.expand(t_c[id])
	return b

## Matériaux de FER des modèles (cerclages, ferrures) : notés par les fabriques (atlas « pq_fer », fer du village / des intérieurs) ;
## un morceau de fer n'est pas tranché (un cerclage part entier).
static var _fers := {}
static func noter_fer(m: Material) -> void:
	if m != null:
		_fers[m.get_instance_id()] = true

static func est_fer(m: Material) -> bool:
	return m != null and _fers.has(m.get_instance_id())

static func _a_minuscule(m: Array) -> bool:
	for l: Array in m:
		if l.size() < 4:
			return true
	return false

static func _racine(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i

static func _unir(p: PackedInt32Array, a: int, b: int) -> void:
	var ra := _racine(p, a)
	var rb := _racine(p, b)
	if ra != rb:
		p[ra] = rb

# ------------------------------------------------------------------------------------------------ éclats physiques

static var derniere_mesure := {}
static var derniere_decoupe_ms := 0.0     ## coût de la dernière casse (ms : éclats, effets, butin), pour les tests et mesures
static var _eclats: Array = []      ## [{"b": RigidBody3D, "t": temps de création, "immobile": s}]
static var _gestion: CasseObjets

## Projette les morceaux de `mesh` (repère du prop) posé en `xf` (repère MONDE, échelle comprise) sous `parent`.
## `v_objet` : vitesse de l'objet au moment de la casse ; `point` : impact ; `masse` : masse de l'objet entier.
static func eclater(parent: Node3D, mesh: Mesh, xf: Transform3D, matiere: String, masse: float, point: Vector3, v_objet := Vector3.ZERO, graine := 0) -> Array:
	var res := []
	if parent == null or not parent.is_inside_tree():
		return res
	var tm := Time.get_ticks_usec()
	var mors := morceaux(mesh, matiere)
	derniere_decoupe_ms = (Time.get_ticks_usec() - tm) / 1000.0
	if mors.is_empty():
		return res
	_assurer_gestion(parent.get_tree())
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var r := xf.basis.orthonormalized()
	var sc := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
	var centre := xf * Vector3.ZERO
	var bb_c := Vector3.ZERO
	for m: Dictionary in mors:
		bb_c += (m["c"] as Vector3) * float(m["part"])
	centre = xf * bb_c
	var choc := v_objet
	var dir_choc := (centre - point)
	dir_choc = dir_choc.normalized() if dir_choc.length() > 0.01 else Vector3.ZERO
	for m: Dictionary in mors:
		var b := RigidBody3D.new()
		b.name = "Eclat"
		b.collision_layer = 0
		b.collision_mask = 1
		b.mass = maxf(masse * float(m["part"]), 0.04)
		b.linear_damp = 0.25
		b.angular_damp = 1.2
		b.can_sleep = true
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		var pm := PhysicsMaterial.new()
		pm.friction = 0.9
		pm.bounce = 0.1
		b.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		var t: Vector3 = (m["t"] as Vector3) * sc
		bx.size = Vector3(maxf(t.x, 0.02), maxf(t.y, 0.02), maxf(t.z, 0.02))
		cs.shape = bx
		b.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = m["m"]
		mi.basis = Basis.from_scale(sc)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(mi)
		parent.add_child(b)
		b.global_transform = Transform3D(r, xf * (m["c"] as Vector3))
		var hors := b.global_position - centre
		hors.y = 0.0
		hors = hors.normalized() if hors.length() > 0.01 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var legere := clampf(1.0 / sqrt(maxf(b.mass, 0.05)), 0.5, 1.6)
		b.linear_velocity = choc * 0.45 + dir_choc * minf(choc.length() * 0.2, 2.5) + hors * rng.randf_range(0.8, 2.2) * legere + Vector3.UP * rng.randf_range(0.8, 2.4) * legere
		b.angular_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8)) * legere
		_eclats.append({"b": b, "t": Time.get_ticks_msec() / 1000.0, "immobile": 0.0})
		res.append(b)
	while _eclats.size() > MAX_ECLATS:      # les plus anciens partent
		var e: Dictionary = _eclats.pop_front()
		if is_instance_valid(e["b"]):
			(e["b"] as Node).queue_free()
	_gestion.set_physics_process(true)
	return res

static func nb_eclats() -> int:
	var n := 0
	for e: Dictionary in _eclats:
		if is_instance_valid(e["b"]):
			n += 1
	return n

static func nb_eclats_eveilles() -> int:
	var n := 0
	for e: Dictionary in _eclats:
		if is_instance_valid(e["b"]) and not (e["b"] as RigidBody3D).freeze:
			n += 1
	return n

static func _assurer_gestion(arbre: SceneTree) -> void:
	if is_instance_valid(_gestion) and (_gestion.is_inside_tree() or _gestion.is_queued_for_deletion() == false and _gestion.get_parent() == null):
		return      # (déjà là, ou en route : ajouté à l'image suivante)
	_gestion = CasseObjets.new()
	_gestion.name = "GestionEclats"
	arbre.root.add_child.call_deferred(_gestion)

func _ready() -> void:
	set_physics_process(not _eclats.is_empty())
	_veiller_taches()

## Tâches de découpe finies : rangées toutes les 2 s tant qu'il en reste (aucune tâche laissée sans attente).
func _veiller_taches() -> void:
	_ranger_taches()
	_verrou.lock()
	var reste := not _taches.is_empty()
	_verrou.unlock()
	if reste and is_inside_tree():
		get_tree().create_timer(2.0).timeout.connect(_veiller_taches)

## Sortie du jeu (ou du test) : toutes les découpes en cours sont attendues avant que le moteur ne s'arrête.
func _exit_tree() -> void:
	_verrou.lock()
	var ids: Array = _taches.values()
	_taches.clear()
	_verrou.unlock()
	for id: int in ids:
		if id >= 0:
			WorkerThreadPool.wait_for_task_completion(id)

## Éclats : gelés posés ou loin, effacés (rétrécis) après VIE s. Plus rien à suivre : _physics_process coupé.
func _physics_process(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var oeil := cam.global_position if cam != null else Vector3(1e5, 0, 1e5)
	var maintenant := Time.get_ticks_msec() / 1000.0
	var i := _eclats.size() - 1
	var actifs := 0
	while i >= 0:
		var e: Dictionary = _eclats[i]
		var b: RigidBody3D = e["b"] if is_instance_valid(e["b"]) else null
		if b == null or not b.is_inside_tree():
			_eclats.remove_at(i)
			i -= 1
			continue
		var age := maintenant - float(e["t"])
		if age > VIE:      # fin de vie : rétréci puis effacé
			var k := 1.0 - (age - VIE)
			if k <= 0.0:
				b.queue_free()
				_eclats.remove_at(i)
			else:
				for c in b.get_children():
					if c is MeshInstance3D:
						(c as MeshInstance3D).scale = (c as MeshInstance3D).scale.normalized() * maxf(k, 0.01) * (c as MeshInstance3D).scale.length()
				actifs += 1
			i -= 1
			continue
		if not b.freeze:
			actifs += 1
			if b.sleeping or b.linear_velocity.length() < 0.06 and b.angular_velocity.length() < 0.3:
				e["immobile"] = float(e["immobile"]) + dt
			else:
				e["immobile"] = 0.0
			if float(e["immobile"]) > GEL_APRES or b.global_position.distance_to(oeil) > PORTEE_ECLATS or age > 12.0:
				b.freeze = true
			elif b.global_position.y < -200.0:
				b.queue_free()
		else:
			actifs += 1 if age > VIE - 1.0 else 0
		i -= 1
	# rien d'éveillé ni de mourant : plus de passage par image (réarmé par eclater) ; une minuterie vérifie la fin de vie
	if actifs == 0:
		set_physics_process(false)
		if not _eclats.is_empty():
			get_tree().create_timer(4.0).timeout.connect(func() -> void: set_physics_process(true))

# ------------------------------------------------------------------------------------------------ effets

## Gerbe de la matière, poussière, son ; `liquide` : le contenu (bière, saumure) gicle et une flaque s'étale.
## LIQUIDES (docs/LIQUIDES.md) : `sorte` / `litres` (Liquides.contenu) et `vitesse` de l'objet : le contenu est versé par Liquides.
static func effets(n: Node3D, centre: Vector3, pied: Vector3, origine: Vector3, matiere: String, taille: float, liquide := false,
		sorte := "", litres := -1.0, vitesse := Vector3.ZERO) -> void:
	if n == null or not n.is_inside_tree():
		return
	var prof: Dictionary = MATIERES.get(matiere, {})
	var dir := centre - origine
	dir.y = 0.0
	dir = (dir.normalized() if dir.length() > 0.01 else Vector3.UP) * 0.6 + Vector3.UP
	var force := clampf(0.7 + taille * 1.1, 0.6, 1.8) * float(prof.get("gerbe_k", 1.0))
	GerbePixels.emettre(n, centre, dir.normalized(), String(prof.get("gerbe", "bois")), force)
	if bool(prof.get("poussiere", false)):
		GerbePixels.emettre(n, pied + Vector3(0, 0.08, 0), Vector3.UP, "poussiere", clampf(taille * 1.2, 0.5, 1.1))
	if liquide:
		verser_liquide(n, centre, dir.normalized(), clampf(taille * 1.4, 0.5, 1.3), sorte, litres, vitesse, taille)
	var sons: Array = prof.get("sons", ["impactWood_heavy_000"])
	Sons.jouer_a(n, sons, centre, clampf(-8.0 + taille * 4.0, -10.0, 0.0), 0.1)

## VERSEMENT DU LIQUIDE d'un contenant brisé (tonneau, jarre) — fonction isolée, à remplacer par le chantier « liquides réalistes ».
## Minimal : le liquide gicle en gouttes (GerbePixels « liquide ») ; la flaque se pose là où il atterrit, sur la PREMIÈRE surface du
## décor (calque 1) sous le point de casse, à moins de PORTEE_LIQUIDE m (sinon aucune flaque : objet brisé en vol au-dessus du vide) ;
## orientée selon la normale ; son rayon est réduit jusqu'à ce qu'elle ne déborde pas dans le vide (bord d'étagère, de table). Surface
## surélevée (étagère, table : sol plus bas de > 0,3 m) : les gouttes qui coulent finissent en petite flaque au sol, un peu plus tard.
const PORTEE_LIQUIDE := 3.0

## LIQUIDES (2026-11-23) : remplacée par Liquides.verser_contenant (vraies gouttes qui retombent, flaque selon le volume, coulures,
## égouttement d'une étagère vers le sol) ; l'ancien comportement reste avec `--sans-liquides`. `sorte` vide : saumure (ancien défaut).
static func verser_liquide(n: Node3D, centre: Vector3, dir: Vector3, rayon: float, sorte := "", litres := -1.0, vitesse := Vector3.ZERO, taille := 0.6) -> void:
	if Liquides.actif:
		if n == null or not n.is_inside_tree():
			return
		var l := litres if litres > 0.0 else rayon * rayon * 12.0
		Liquides.verser_contenant(n, centre, vitesse + dir * 0.3, sorte if sorte != "" else "saumure", l, taille)
		return
	GerbePixels.emettre(n, centre, Vector3.UP, "liquide", 1.6)
	GerbePixels.emettre(n, centre, dir, "liquide", 1.2)
	var espace := n.get_world_3d().direct_space_state
	var r := _rayon_bas(espace, centre + Vector3(0, 0.05, 0), PORTEE_LIQUIDE)
	if r.is_empty():
		return
	var p: Vector3 = r["position"]
	var nrm: Vector3 = r["normal"]
	if nrm.y < 0.6:
		return      # surface trop pentue : rien ne tient
	var rr := _rayon_sans_vide(espace, p, nrm, rayon)
	var arbre := n.get_tree()
	var chute := sqrt(2.0 * maxf(centre.y - p.y, 0.0) / 9.8)      # le temps que le liquide atteigne la surface
	if rr >= 0.12:
		arbre.create_timer(chute).timeout.connect(func() -> void:
			if is_instance_valid(n) and n.is_inside_tree():
				Flaque.poser(n, p, rr, nrm))
	var dessous := _rayon_bas(espace, p - Vector3(0, 0.04, 0), PORTEE_LIQUIDE)      # ce qui déborde coule plus bas
	if not dessous.is_empty() and p.y - float((dessous["position"] as Vector3).y) > 0.3 and (dessous["normal"] as Vector3).y > 0.6:
		var q: Vector3 = dessous["position"]
		var rq := _rayon_sans_vide(espace, q, dessous["normal"], clampf(rayon * 0.45, 0.15, 0.5))
		var t2 := chute + sqrt(2.0 * (p.y - q.y) / 9.8) + 0.5
		arbre.create_timer(t2).timeout.connect(func() -> void:
			if is_instance_valid(n) and n.is_inside_tree():
				GerbePixels.emettre(n, q + Vector3(0, 0.3, 0), Vector3.DOWN, "goutte", 1.0)
				if rq >= 0.1:
					Flaque.poser(n, q, rq, dessous["normal"]))

static func _rayon_bas(espace: PhysicsDirectSpaceState3D, de: Vector3, portee: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, de - Vector3(0, portee, 0), 1)
	return espace.intersect_ray(q)

## Plus grand rayon (≤ `rayon`) dont 8 points du bord retrouvent la même surface (± 4 cm) : la flaque ne déborde pas dans le vide.
static func _rayon_sans_vide(espace: PhysicsDirectSpaceState3D, p: Vector3, nrm: Vector3, rayon: float) -> float:
	var rr := rayon
	while rr >= 0.1:
		var ok := true
		for k in 8:
			var a := TAU * k / 8.0
			var b := p + Vector3(cos(a), 0, sin(a)) * rr * 0.9
			b.y = p.y - (nrm.x * (b.x - p.x) + nrm.z * (b.z - p.z)) / maxf(nrm.y, 0.3)      # sur le plan de la surface
			var h := _rayon_bas(espace, b + Vector3(0, 0.12, 0), 0.2)
			if h.is_empty() or absf(float((h["position"] as Vector3).y) - b.y) > 0.04:
				ok = false
				break
		if ok:
			return rr
		rr *= 0.7
	return 0.0

## Contenu d'un contenant brisé (caisse, tonneau, sac, jarre) : petite bourse tirée à graine fixe (même tirage que les cassables de la
## crypte : ButinTables.tirer_pour), « premier arrivé » en coop (ReseauLieux.reclamer). Rien si l'objet a déjà été pillé.
static func verser_butin(n: Node3D, ident: String, table_genre: String, position: Vector3) -> void:
	if table_genre == "" or ident == "" or ButinTables.est_pille(ident) or not n.is_inside_tree():
		return
	ReseauLieux.reclamer(ident, func() -> void:
		ButinTables.piller(ident)
		_bourse(n, ident, table_genre, position), Callable(), "contenant")

static func _bourse(n: Node3D, ident: String, table_genre: String, position: Vector3) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var arbre := n.get_tree()
	var scene := arbre.current_scene
	if scene == null or scene.get("joueur") == null:
		scene = null
		for c in arbre.root.get_children():
			if c.get("joueur") != null and c.get("hud") != null:
				scene = c
				break
	if scene == null or scene.get("joueur") == null or scene.get("hud") == null:
		return
	var zone := ident.get_slice(":", 0)
	var liste := ButinTables.tirer_pour(ident, ButinTables.table_pour(table_genre, zone), zone)
	var contenu := ButinTables.contenu(liste)
	if contenu.is_empty():
		return
	var b := Node3D.new()
	b.set_script(preload("res://scripts/butin.gd"))
	b.joueur = scene.get("joueur")
	b.hud = scene.get("hud")
	b.contenu = contenu
	(n.get_parent() if n.get_parent() != null else n).add_child(b)
	b.global_position = position + Vector3(0, 0.2, 0)

## Flaque laissée par un tonneau ou une jarre brisés : disque sombre et luisant (shader ps1 du jeu, texture de bière/saumure bruitée,
## jamais de tramage) posé au sol, qui s'étale puis sèche (rétrécit et s'efface) en ~14 s.
class Flaque extends MeshInstance3D:
	const DUREE := 14.0
	var _t := 0.0
	var _r := 1.0
	static var _mat: Material
	static var _disque: ArrayMesh

	static func poser(n: Node3D, pied: Vector3, rayon: float, normale := Vector3.UP) -> void:
		if _mat == null:
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			var rng := RandomNumberGenerator.new()
			rng.seed = 771
			for y in 16:
				for x in 16:
					var k := rng.randf()
					var c := Color(0.20, 0.11, 0.05).lerp(Color(0.42, 0.25, 0.09), k * k) if k < 0.93 else Color(0.62, 0.48, 0.26)      # quelques reflets
					img.set_pixel(x, y, c)
			_mat = Palette.materiau(ImageTexture.create_from_image(img), Vector2(3, 3), Color.WHITE, true)
		if _disque == null:      # disque irrégulier (12 pans, rayon bruité)
			var v := PackedVector3Array()
			var c := PackedColorArray()
			var u := PackedVector2Array()
			var nn := PackedVector3Array()
			var rr := [1.0, 0.82, 0.95, 0.74, 1.05, 0.88, 0.7, 0.97, 0.8, 1.02, 0.76, 0.9]
			for k in 12:
				var a0 := TAU * k / 12.0
				var a1 := TAU * (k + 1) / 12.0
				var p1 := Vector3(cos(a1), 0, sin(a1)) * float(rr[(k + 1) % 12])
				var p0 := Vector3(cos(a0), 0, sin(a0)) * float(rr[k])
				for p in [Vector3.ZERO, p1, p0]:
					v.append(p)
					u.append(Vector2(p.x, p.z) * 0.5 + Vector2(0.5, 0.5))
					c.append(Color(1, 1, 1, 1))      # alpha 1 : matière de base (0 = neige)
					nn.append(Vector3.UP)
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_NORMAL] = nn
			arr[Mesh.ARRAY_TEX_UV] = u
			arr[Mesh.ARRAY_COLOR] = c
			_disque = ArrayMesh.new()
			_disque.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var f := Flaque.new()
		f.mesh = _disque
		f.material_override = _mat
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f._r = rayon
		f.add_to_group("flaques")
		var hote: Node = n.get_tree().current_scene if n.get_tree().current_scene != null else n.get_parent()
		hote.add_child(f)
		var y := normale.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		f.global_transform = Transform3D(Basis(x, y, x.cross(y)) * Basis(Vector3.UP, randf() * TAU), pied + y * 0.015)
		f.scale = Vector3.ONE * 0.05

	func _process(dt: float) -> void:
		_t += dt
		var k := clampf(_t / 1.2, 0.0, 1.0)      # s'étale en 1,2 s
		var r := _r * (1.0 - pow(1.0 - k, 3.0))
		if _t > DUREE * 0.55:      # sèche : rétrécit jusqu'à disparaître
			r *= 1.0 - clampf((_t - DUREE * 0.55) / (DUREE * 0.45), 0.0, 1.0)
		scale = Vector3(maxf(r, 0.01), 1.0, maxf(r, 0.01))
		if _t >= DUREE:
			queue_free()
