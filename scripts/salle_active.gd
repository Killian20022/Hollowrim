class_name SalleActive
extends RefCounted
## Salle active d'un donjon (crypte, grotte) : la salle où est le joueur + ses voisines (graphe des portes). Hors de cet ensemble :
##   - les ennemis au repos (dormeurs, gardes, patrouilleurs) sont GELÉS : process/physique/animation/modificateurs de squelette coupés et
##     corps caché (draugr.gd : geler()). Ils se réveillent d'eux-mêmes quand leur salle redevient active (ou si on les alerte) ;
##     un ennemi qui poursuit, frappe ou se relève n'est jamais gelé ; un mort non plus (butin, quêtes `tue:` inchangés) ;
##   - la géométrie du décor (maillages fusionnés par case de 8 m / MultiMesh) qui ne touche AUCUNE salle active est cachée
##     (la brume sous terre et la portée de dessin masquent la coupure). Ce qui ne touche aucune salle (vestibule…) reste visible.
## Le joueur hors du donjon (surface) : tous les ennemis du volume du donjon sont gelés.
## Les couloirs et escaliers sont « longs » : on voit à travers eux, la voisine de leur voisine reste donc active.
##
##   var sa := SalleActive.depuis_donjon(donjon, crypte, joueur, arbre) / depuis_grotte(g, grotte_node, joueur, arbre)
##   sa.classer(racine_du_decor)      # géométrie à gérer (progressif : voir `pas`)
##   sa.pas(dt, dedans)               # à appeler chaque image ; travaille toutes les PAS secondes

const PAS := 0.25
const MARGE := 1.6              # tolérance autour d'un rectangle de salle (murs, seuils, portes)
const BUDGET_CLASSE_US := 3000  # classement de la géométrie : ≤ 3 ms par appel
const RAYON_POINTS := 22.0      # grotte : distance maximale d'une zone à un point du joueur pour en être « la salle »

var arbre: SceneTree
var repere: Node3D                      # nœud dont le repère local est celui des salles (crypte, grotte)
var joueur: Node3D
## id -> {"rect": Rect2 (x,z local) ou Rect2() , "y0", "y1", "pts": PackedVector3Array (grotte), "voisins": Array, "long": bool, "noeuds": Array}
var salles := {}
var actives := {}                       # id -> true
var courante := ""
var volume := AABB()                    # englobant des salles (repère local)
var geler_ennemis := true
## Coop : positions mondiales (Vector3) des AUTRES joueurs ; vide = ReseauLieux.reseau().registre (avatars des pairs). Remplaçable (tests).
## Simulation (ennemis gelés / dégelés) = UNION des salles de tous les joueurs ; rendu (décor caché) = salle du joueur LOCAL seulement.
var positions_autres := Callable()
var cacher_decor := true
var nb_geles := 0
var _t := PAS
var _dedans := true
var _noeuds := {}                       # instance_id -> {"n": GeometryInstance3D, "s": Array[String]}
var _a_classer: Array = []
var _exclus: Array = []                 # sous-arbres à ignorer (portes mobiles)
var _sig_autres := ""                   # signature des salles des autres joueurs (détecte un changement)
var _autres_dedans := false             # au moins un autre joueur est dans le volume de ce donjon
var _visibles := {}                     # salles dont la géométrie est actuellement visible (au départ : toutes)
var _force := true

# ======================================================================================================== construction
## Salles de la crypte : une par module du donjon (zone rect + y), portes = ouvertures `vers`.
static func depuis_donjon(donjon: Object, repere_: Node3D, joueur_: Node3D, arbre_: SceneTree) -> SalleActive:
	var sa := SalleActive.new()
	sa.arbre = arbre_
	sa.repere = repere_
	sa.joueur = joueur_
	var mods: Dictionary = donjon.modules
	for z: Dictionary in donjon.zones:
		var id: String = z["nom"]
		if not mods.has(id):
			continue
		var md: Dictionary = mods[id]
		var escalier: bool = md.get("escalier", false)
		var zy := float(z["y"])
		var y0 := zy - 0.8
		var y1 := (zy + 9.5) if escalier else (zy + float(md.get("h", 3.0)) + 0.6)
		var voisins: Array = []
		for ou: Dictionary in md["ouv"]:
			var vers: String = ou["vers"]
			if vers != "" and not voisins.has(vers):
				voisins.append(vers)
		var r: Rect2 = z["rect"]
		var portes: Array = []      # [vers, a, b] : l'embrasure en plan, élargie de MARGE_PORTE (_calculer_visibles)
		for ou: Dictionary in md["ouv"]:
			var pp := Vector2((ou["pos"] as Vector3).x, (ou["pos"] as Vector3).z)
			var dl := minf(absf(pp.x - r.position.x), absf(pp.x - r.end.x))
			var dz := minf(absf(pp.y - r.position.y), absf(pp.y - r.end.y))
			var hl := float(ou["largeur"]) * 0.5 + MARGE_PORTE
			var u := Vector2(0, hl) if dl < dz else Vector2(hl, 0)
			portes.append([String(ou["vers"]), pp - u, pp + u])
		sa.salles[id] = {"rect": r, "y0": y0, "y1": y1, "pts": PackedVector3Array(), "voisins": voisins,
			"long": escalier or String(md.get("role", "")) == "passage", "noeuds": [], "portes": portes}
		sa._englober(Vector3(r.position.x, y0, r.position.y), Vector3(r.end.x, y1, r.end.y))
	sa._symetriser()
	sa._visibles = sa._calculer_actives("")
	return sa

## Salles de la grotte : une par zone du kit ; points = ligne médiane de la zone ; voisines = zones dont un point est à moins de 12 m.
static func depuis_grotte(g: Object, repere_: Node3D, joueur_: Node3D, arbre_: SceneTree) -> SalleActive:
	var sa := SalleActive.new()
	sa.arbre = arbre_
	sa.repere = repere_
	sa.joueur = joueur_
	for id: String in g.zones:
		var z: Dictionary = g.zones[id]
		var s0 := float(z["s"][0])
		var s1 := float(z["s"][1])
		var pts := PackedVector3Array()
		var n := maxi(2, int(ceil((s1 - s0) / 5.0)))
		for k in n + 1:
			pts.append(g.sol_en(z["branche"], lerpf(s0, s1, float(k) / n), 0.0))
		sa.salles[id] = {"rect": Rect2(), "y0": -1e9, "y1": 1e9, "pts": pts, "voisins": [], "long": false, "noeuds": []}
		for p in pts:
			sa._englober(p - Vector3(25, 12, 25), p + Vector3(25, 14, 25))
	var ids: Array = sa.salles.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if sa._pts_proches(sa.salles[ids[i]]["pts"], sa.salles[ids[j]]["pts"], 12.0):
				(sa.salles[ids[i]]["voisins"] as Array).append(ids[j])
				(sa.salles[ids[j]]["voisins"] as Array).append(ids[i])
	sa._visibles = sa._calculer_actives("")
	return sa

func _pts_proches(a: PackedVector3Array, b: PackedVector3Array, d: float) -> bool:
	var d2 := d * d
	for p in a:
		for q in b:
			if p.distance_squared_to(q) < d2:
				return true
	return false

func _englober(a: Vector3, b: Vector3) -> void:
	volume = volume.expand(a).expand(b) if volume.size != Vector3.ZERO else AABB(a, b - a)

## Pièce bâtie hors de la table des modules (crypte : vestibule, alcôve d'Eirik, couloir de la herse, bâtis par tertre.gd) : salle à part
## entière, reliée à chaque salle dont le rectangle la touche (les ouvertures « "" » des modules mènent à ces pièces).
## Bug « crypte noire » (2026-11-23) : sans elle, le joueur arrivé au vestibule (0 ; 0,5) était rangé dans la salle la PLUS PROCHE à 8 m
## près, le couloir s2 (à 3 m, sur le côté) plutôt que le couloir des niches (6,5 m, droit devant) : niches et salle de préparation
## étaient cachées, le couloir vu par la porte restait noir jusqu'à ce qu'on avance d'un ou deux mètres (salle courante = niches).
## De même, depuis la salle de préparation, la salle rituelle au bout du couloir de la herse n'était jamais active.
## Joueur DANS la pièce : chaque voisine est active comme si l'on y était (ses voisines et le prolongement des couloirs « longs »).
## `long` : depuis une voisine, on voit à travers la pièce (couloir de la herse) : la voisine d'en face reste active. À appeler AVANT `classer`.
func ajouter_piece(id: String, rect: Rect2, y0: float, y1: float, long := true) -> void:
	var voisins: Array = []
	for k: String in salles:
		var r: Rect2 = salles[k]["rect"]
		if r.size != Vector2.ZERO and r.grow(0.6).intersects(rect) and float(salles[k]["y0"]) < y1 and float(salles[k]["y1"]) > y0:
			voisins.append(k)
			(salles[k]["voisins"] as Array).append(id)
	salles[id] = {"rect": rect, "y0": y0, "y1": y1, "pts": PackedVector3Array(), "voisins": voisins, "long": long, "noeuds": [], "piece": true}
	_englober(Vector3(rect.position.x, y0, rect.position.y), Vector3(rect.end.x, y1, rect.end.y))
	_visibles[id] = true
	_cache_visibles.clear()
	_cache_chaines.clear()
	_cache_permis.clear()
	_force = true

## Les portes sont à double sens : si A cite B, B cite A.
func _symetriser() -> void:
	for id: String in salles:
		for v: String in salles[id]["voisins"]:
			if salles.has(v) and not (salles[v]["voisins"] as Array).has(id):
				(salles[v]["voisins"] as Array).append(id)

## Géométrie à gérer : tous les GeometryInstance3D sous `racine`, sauf sous les nœuds de `exclus` (portes mobiles). Classement progressif.
func classer(racine: Node, exclus: Array = []) -> void:
	_exclus = exclus
	for n in racine.find_children("*", "GeometryInstance3D", true, false):
		_a_classer.append(n)

## Classe tout ce qui reste, tout de suite (entrée dans le donjon, sous l'écran noir).
func classer_tout() -> void:
	_classer_pas(0)

func classement_fini() -> bool:
	return _a_classer.is_empty()

func _classer_pas(budget_us: int) -> void:
	var debut := Time.get_ticks_usec()
	var inv := repere.global_transform.affine_inverse()
	var rects: Array = []
	for id: String in salles:
		var s: Dictionary = salles[id]
		rects.append([id, (s["rect"] as Rect2).grow(0.3), float(s["y0"]), float(s["y1"])])
	while not _a_classer.is_empty():
		var n: GeometryInstance3D = _a_classer.pop_back()
		if not is_instance_valid(n) or not n.is_inside_tree() or _est_exclu(n) or _dans_personnage(n):
			continue
		var bb: AABB = (inv * n.global_transform) * n.get_aabb()
		var rn := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
		var liste: Array = []
		for r: Array in rects:
			if (r[1] as Rect2).intersects(rn) and bb.position.y < float(r[3]) and bb.end.y > float(r[2]):
				liste.append(r[0])
		if not liste.is_empty():
			_noeuds[n.get_instance_id()] = {"n": n, "s": liste, "r": rn.grow(0.5)}
			for id: String in liste:
				(salles[id]["noeuds"] as Array).append(n)
			if cacher_decor and not _visibles.is_empty():
				n.visible = _voulu(n)
		if budget_us > 0 and Time.get_ticks_usec() - debut > budget_us:
			return

## Maillage d'un PERSONNAGE (sous un Skeleton3D : corps de décor comme le compagnon mort de la crypte) : il gère lui-même la visibilité
## de ses pièces (vêtements cachés sous l'armure, coiffes, capes de rechange) ; les remettre visibles au classement (n.visible = voulu)
## habillait le corps de TOUTES ses pièces à la fois (robe, capuche, cape, haillons… « skin dégueulasse »). Jamais caché par salle.
func _dans_personnage(n: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != repere:
		if p is Skeleton3D:
			return true
		p = p.get_parent()
	return false

func _est_exclu(n: Node) -> bool:
	for e in _exclus:
		if is_instance_valid(e) and (e == n or e.is_ancestor_of(n)):
			return true
	return false

# ======================================================================================================== localisation
## Salle contenant le point `p` (repère local) ; à défaut, la plus proche à moins de `marge` m (murs, seuils, vestibule) ; "" si aucune.
func salle_de(p: Vector3, marge := MARGE) -> String:
	var q := Vector2(p.x, p.z)
	var dedans_id := ""
	var dy_min := INF
	var proche_id := ""
	var d_min := marge
	for id: String in salles:
		var s: Dictionary = salles[id]
		var r: Rect2 = s["rect"]
		if r.size != Vector2.ZERO:
			if p.y < float(s["y0"]) - 0.5 or p.y > float(s["y1"]) + 0.5:
				continue
			if r.has_point(q):
				var dy := absf(p.y - (float(s["y0"]) + 0.8))     # étages superposés : la plus proche en hauteur
				if dy < dy_min:
					dy_min = dy
					dedans_id = id
			elif dedans_id == "":
				var dx := maxf(maxf(r.position.x - q.x, q.x - r.end.x), 0.0)
				var dz := maxf(maxf(r.position.y - q.y, q.y - r.end.y), 0.0)
				var dd := sqrt(dx * dx + dz * dz)
				if dd < d_min:
					d_min = dd
					proche_id = id
		else:
			for pt: Vector3 in s["pts"]:
				var dd := pt.distance_to(p)
				if dd < RAYON_POINTS and dd < dy_min:
					dy_min = dd
					dedans_id = id
	return dedans_id if dedans_id != "" else proche_id

func _calculer_actives(id: String) -> Dictionary:
	var a := {}
	if id == "":
		for k: String in salles:
			a[k] = true
		return a
	a[id] = true
	var piece: bool = salles[id].get("piece", false)
	for v: String in salles[id]["voisins"]:
		if not salles.has(v):
			continue
		if piece and not salles[v].get("piece", false):
			# pièce du tertre (vestibule…) : on voit dans chacune de ses voisines comme si l'on y était (un pas plus loin, même décor) ;
			# sinon le couloir des niches est visible mais la salle de préparation, au bout, apparaît au premier pas
			a.merge(_calculer_actives(v))
			continue
		a[v] = true
		if salles[v]["long"]:
			for w: String in salles[v]["voisins"]:
				if salles.has(w):
					a[w] = true
	return a

## Salles dont le DÉCOR reste dessiné depuis `id` (crypte_trous, 2026-11-25) : l'ensemble actif de `_calculer_actives`, plus les salles
## à au plus PROF_DECOR portes, à moins de PORTEE_DECOR m, VRAIMENT VISIBLES par l'enfilade des embrasures depuis un point de `id`.
## Avant, une salle vue par l'enfilade de deux portes (s2 -> quartiers -> armurerie…) n'était pas dessinée : un rectangle de VIDE (le fond,
## couleur de brume) dans l'embrasure, à 10-20 m, là où la brume ne cache encore rien. Première version : toutes les salles à 3 portes /
## 26 m, -20 à -35 % de FPS (300 à 560 objets dessinés au lieu de 30 à 60) ; d'où le test de visibilité, en plan et prudent : une salle
## de plus est dessinée s'il existe, depuis un point de la grille (1 m) de `id`, une demi-droite qui traverse toutes les portes de la
## chaîne (élargies de MARGE_PORTE), portes fermées comprises. Calculé une fois par salle (géométrie fixe). La simulation (ennemis
## gelés) garde l'ensemble actif.
const PROF_DECOR := 3
const PORTEE_DECOR := 26.0
const MARGE_PORTE := 0.3
var _cache_visibles := {}
var _cache_chaines := {}     # id -> {salle de plus -> [chaînes de portes qui y mènent]}
var _cache_permis := {}      # id -> {instance_id -> true} : nœuds des salles « de plus » vus par une chaîne
var _partielles := {}        # salles « de plus » de la salle courante : seuls leurs nœuds permis sont dessinés
var _permis := {}
var dernier_permis_us := 0   # durée du dernier calcul de _calculer_permis (bancs)

func _calculer_visibles(id: String) -> Dictionary:
	var a := _calculer_actives(id)
	if id == "" or not salles.has(id):
		return a
	var r0: Rect2 = salles[id]["rect"]
	if r0.size == Vector2.ZERO:      # grotte (salles en points) : inchangé
		return a
	if not _cache_visibles.has(id):
		var plus := {}
		var pts := _grille(r0)
		_chercher(id, [id], [], a, plus, pts, r0)
		_cache_chaines[id] = plus
		var ens := {}
		for v: String in plus:
			ens[v] = true
		_cache_visibles[id] = ens
	a.merge(_cache_visibles[id])
	return a

## Parcours des chemins simples depuis `chemin[0]` (au plus PROF_DECOR portes) ; `segs` = portes traversées.
func _chercher(s: String, chemin: Array, segs: Array, base: Dictionary, plus: Dictionary, pts: Array, r0: Rect2) -> void:
	if chemin.size() > PROF_DECOR:
		return
	for v: String in salles[s]["voisins"]:
		if chemin.has(v) or not salles.has(v):
			continue
		var r: Rect2 = salles[v]["rect"]
		if r.size == Vector2.ZERO or _dist_rects(r0, r) > PORTEE_DECOR:
			continue
		for seg: Array in _portes_entre(s, v):
			var s2: Array = segs.duplicate()
			s2.append(seg)
			if not _visible_par(pts, s2):
				continue
			if not base.has(v):
				if not plus.has(v):
					plus[v] = []
				(plus[v] as Array).append(s2)
			var c2: Array = chemin.duplicate()
			c2.append(v)
			_chercher(v, c2, s2, base, plus, pts, r0)

## Points de vue de la salle : grille de 1 m, à 0,35 m des murs (le joueur ne s'en approche pas plus).
func _grille(r: Rect2, pas_ := 1.0) -> Array:
	var l: Array = []
	var rr := r.grow(-0.35)
	if rr.size.x <= 0.0 or rr.size.y <= 0.0:
		rr = Rect2(r.get_center(), Vector2.ZERO)
	var nx := maxi(1, int(ceil(rr.size.x / pas_)))
	var nz := maxi(1, int(ceil(rr.size.y / pas_)))
	for i in nx + 1:
		for k in nz + 1:
			l.append(rr.position + Vector2(rr.size.x * i / nx, rr.size.y * k / nz))
	return l

## Portes (segments en plan, élargis) entre deux salles voisines : ouvertures `vers` de l'une ou de l'autre ; vers une pièce bâtie à part
## (vestibule, couloir de la herse : ouvertures « "" »), celles dont le milieu est dans la pièce. Rien de connu : le rectangle commun.
func _portes_entre(s: String, v: String) -> Array:
	var l: Array = []
	for pr: Array in [[s, v], [v, s]]:
		var de: Dictionary = salles[pr[0]]
		var vers_: Dictionary = salles[pr[1]]
		for po: Array in de.get("portes", []):
			if po[0] == pr[1] or (po[0] == "" and vers_.get("piece", false) and (vers_["rect"] as Rect2).grow(1.0).has_point(((po[1] as Vector2) + (po[2] as Vector2)) * 0.5)):
				l.append([po[1], po[2]])
	if l.is_empty():      # pièces entre elles : le recouvrement des deux rectangles, vu comme une porte
		var c: Rect2 = (salles[s]["rect"] as Rect2).grow(0.6).intersection((salles[v]["rect"] as Rect2).grow(0.6))
		if c.size != Vector2.ZERO:
			l.append([c.position, c.end] if c.size.x > c.size.y else [Vector2(c.position.x, c.end.y), Vector2(c.end.x, c.position.y)])
	return l

## Une demi-droite issue d'un des points traverse-t-elle tous les segments ? (angles autour de la direction de la 1re porte)
static func _visible_par(pts: Array, segs: Array) -> bool:
	for p: Vector2 in pts:
		var m0: Vector2 = ((segs[0][0] as Vector2) + (segs[0][1] as Vector2)) * 0.5 - p
		if m0.length_squared() < 1e-6:
			m0 = Vector2(1, 0)
		var lo := -INF
		var hi := INF
		var ok := true
		for sg: Array in segs:
			var ea: Vector2 = (sg[0] as Vector2) - p
			var eb: Vector2 = (sg[1] as Vector2) - p
			var ta := atan2(m0.cross(ea), m0.dot(ea))
			var tb := atan2(m0.cross(eb), m0.dot(eb))
			if absf(ta - tb) > PI:      # le segment passe derrière le point : on ne regarde pas par là
				ok = false
				break
			lo = maxf(lo, minf(ta, tb))
			hi = minf(hi, maxf(ta, tb))
			if lo > hi:
				ok = false
				break
		if ok:
			return true
	return false

static func _dist_rects(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dz := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)

## Nœuds des salles « de plus » de `id` que l'on voit vraiment par l'enfilade (crypte_trous, banc FPS 2026-11-26 : dessiner ces salles
## en entier coûtait jusqu'à -11 % de FPS, d1 : +40 % de primitives pour une tranche de g1 vue par une porte). Un nœud est permis si,
## depuis un point de la grille (2 m) de `id`, le faisceau qui passe toutes les portes de la chaîne touche son emprise en plan
## (élargie de 0,5 m). Calculé une fois par salle, après le classement.
func _calculer_permis(id: String) -> Dictionary:
	if _cache_permis.has(id) and _a_classer.is_empty():
		return _cache_permis[id]
	var t0 := Time.get_ticks_usec()
	var res := {}
	var chaines: Dictionary = _cache_chaines.get(id, {})
	if chaines.is_empty():
		return res
	var pts := _grille(salles[id]["rect"], 2.0)
	for v: String in chaines:
		var fx: Array = []      # faisceaux [p, m0, lo, hi] de toutes les chaînes vers v (calculés une fois, pas par nœud)
		for ch: Array in chaines[v]:
			fx.append_array(_faisceaux(pts, ch))
		for n: GeometryInstance3D in salles[v]["noeuds"]:
			if not is_instance_valid(n):
				continue
			var iid := n.get_instance_id()
			if not res.has(iid) and _rect_vu(fx, _noeuds[iid]["r"]):
				res[iid] = true
	if _a_classer.is_empty():
		_cache_permis[id] = res
	dernier_permis_us = Time.get_ticks_usec() - t0
	return res

## Faisceaux des points qui voient à travers toute la chaîne : [p, m0, lo, hi] (angles autour de m0, direction de la 1re porte).
static func _faisceaux(pts: Array, segs: Array) -> Array:
	var l: Array = []
	for p: Vector2 in pts:
		var m0: Vector2 = ((segs[0][0] as Vector2) + (segs[0][1] as Vector2)) * 0.5 - p
		if m0.length_squared() < 1e-6:
			m0 = Vector2(1, 0)
		var lo := -INF
		var hi := INF
		var ok := true
		for sg: Array in segs:
			var ea: Vector2 = (sg[0] as Vector2) - p
			var eb: Vector2 = (sg[1] as Vector2) - p
			var ta := atan2(m0.cross(ea), m0.dot(ea))
			var tb := atan2(m0.cross(eb), m0.dot(eb))
			if absf(ta - tb) > PI:
				ok = false
				break
			lo = maxf(lo, minf(ta, tb))
			hi = minf(hi, maxf(ta, tb))
			if lo > hi:
				ok = false
				break
		if ok:
			l.append([p, m0, lo, hi])
	return l

## Un des faisceaux touche-t-il le rectangle `rn` ?
static func _rect_vu(fx: Array, rn: Rect2) -> bool:
	var cs: Array = [rn.position, Vector2(rn.end.x, rn.position.y), rn.end, Vector2(rn.position.x, rn.end.y)]
	for f: Array in fx:
		var p: Vector2 = f[0]
		var m0: Vector2 = f[1]
		if rn.has_point(p):
			return true
		var rlo := INF
		var rhi := -INF
		for c: Vector2 in cs:
			var d := c - p
			var t := atan2(m0.cross(d), m0.dot(d))
			rlo = minf(rlo, t)
			rhi = maxf(rhi, t)
		if rhi - rlo > PI:      # le rectangle entoure presque le point : prudence, visible
			return true
		if rlo <= float(f[3]) and rhi >= float(f[2]):
			return true
	return false

func est_active(id: String) -> bool:
	return id == "" or actives.has(id)

# ======================================================================================================== mise à jour
func pas(dt: float, dedans: bool) -> void:
	_t += dt
	if not _a_classer.is_empty():
		_classer_pas(BUDGET_CLASSE_US)
	if _t < PAS:
		return
	_t = 0.0
	rafraichir(dedans)
	# une voisine de la salle courante par pas : son décor « de plus » est préparé avant qu'on y entre (pas d'à-coup à la porte)
	if dedans and cacher_decor and _a_classer.is_empty() and salles.has(courante):
		for v: String in salles[courante]["voisins"]:
			if salles.has(v) and not _cache_permis.has(v) and (salles[v]["rect"] as Rect2).size != Vector2.ZERO:
				_calculer_visibles(v)
				_calculer_permis(v)
				if not _cache_permis.has(v):
					_cache_permis[v] = {}
				break

## Salles (ids, triées) des autres joueurs qui sont dans le volume de ce donjon ("" = dans le volume mais hors de toute salle = tout actif).
func _salles_autres() -> Array:
	var res: Array = []
	var pos: Array = []
	if positions_autres.is_valid():
		pos = positions_autres.call()
	elif ReseauLieux.reseau().est_en_ligne():
		for id: int in ReseauLieux.reseau().joueurs():
			if id == ReseauLieux.reseau().mon_id():
				continue
			var n := ReseauLieux.reseau().registre.noeud(id) as Node3D
			if n != null and n.is_inside_tree():
				pos.append(n.global_position)
	for p: Vector3 in pos:
		var l := repere.to_local(p)
		if volume.grow(2.0).has_point(l):
			res.append(salle_de(l, 8.0))
	res.sort()
	return res

## Recalcule la salle courante, l'ensemble actif, la géométrie cachée et les ennemis gelés.
## `actives` = union des salles actives de tous les joueurs (simulation) ; la géométrie ne suit que le joueur local.
func rafraichir(dedans := true) -> void:
	if joueur == null or not is_instance_valid(joueur):
		return
	var id := ""
	if dedans:
		id = salle_de(repere.to_local(joueur.global_position), 8.0)
	var autres := _salles_autres()
	var sig := ",".join(autres) + ("#" if not autres.is_empty() else "")
	if dedans != _dedans or id != courante or sig != _sig_autres or _force:
		_force = false
		_dedans = dedans
		courante = id
		_sig_autres = sig
		_autres_dedans = not autres.is_empty()
		var local := _calculer_actives(id) if dedans else {}
		actives = local.duplicate()
		for sid: String in autres:
			actives.merge(_calculer_actives(sid))
		var vis := _calculer_visibles(id) if dedans else _calculer_actives("")
		var part := {}
		if dedans and _cache_visibles.has(id):
			var base := _calculer_actives(id)
			for v: String in _cache_visibles[id]:
				if not base.has(v):
					part[v] = true
		_appliquer_decor(vis, part, _calculer_permis(id) if not part.is_empty() else {})
	if geler_ennemis:
		_ennemis()

func _appliquer_decor(neuf: Dictionary, part := {}, permis := {}) -> void:
	if not cacher_decor:
		return
	var change := {}
	for k: String in salles:
		if neuf.has(k) != _visibles.has(k) or part.has(k) or _partielles.has(k):
			change[k] = true
	_visibles = neuf.duplicate()
	_partielles = part
	_permis = permis
	for k: String in change:
		for n: GeometryInstance3D in salles[k]["noeuds"]:
			if is_instance_valid(n):
				var voulu := _voulu(n)
				if n.visible != voulu:
					n.visible = voulu

## Visible si au moins une des salles que touche le nœud est visible.
func _voulu(n: GeometryInstance3D) -> bool:
	var iid := n.get_instance_id()
	for sid: String in _noeuds[iid]["s"]:
		if _visibles.has(sid) and (not _partielles.has(sid) or _permis.has(iid)):
			return true
	return false

func _ennemis() -> void:
	nb_geles = 0
	# Invité en ligne : aucune simulation ici (les ennemis sont des marionnettes de l'hôte) : rien n'est gelé.
	var marionnettes: bool = ReseauLieux.reseau().est_en_ligne() and not ReseauLieux.reseau().est_hote()
	var personne := actives.is_empty()
	for e: Node in arbre.get_nodes_in_group("ennemis"):
		if not is_instance_valid(e) or not e.has_method("peut_geler"):
			continue
		var pos: Vector3 = repere.to_local((e as Node3D).global_position)
		# seulement les ennemis de CE donjon (la grotte est à -220 m, la crypte à -26 m : volumes disjoints)
		if not volume.grow(2.0).has_point(pos):
			continue
		var veut_actif := true
		if personne:
			veut_actif = false
		else:
			var sid := salle_de(pos)
			veut_actif = sid == "" or actives.has(sid)
		if marionnettes:
			veut_actif = true
		if veut_actif or not e.call("peut_geler"):
			if e.call("est_gele"):
				e.call("degeler")
		else:
			e.call("geler")
		if e.call("est_gele"):
			nb_geles += 1

## Tout remettre (sortie du donjon, fin de partie, tests) : géométrie visible, ennemis dégelés.
func tout_reveler() -> void:
	for id: String in salles:
		for n: GeometryInstance3D in salles[id]["noeuds"]:
			if is_instance_valid(n):
				n.visible = true
	for e: Node in arbre.get_nodes_in_group("ennemis"):
		if is_instance_valid(e) and e.has_method("est_gele") and e.call("est_gele"):
			e.call("degeler")
	actives = _calculer_actives("")
	_visibles = actives.duplicate()
	_partielles = {}
	_permis = {}
	courante = ""
	_force = true
