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
var cacher_decor := true
var nb_geles := 0
var _t := PAS
var _dedans := true
var _noeuds := {}                       # instance_id -> {"n": GeometryInstance3D, "s": Array[String]}
var _a_classer: Array = []
var _exclus: Array = []                 # sous-arbres à ignorer (portes mobiles)
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
		sa.salles[id] = {"rect": r, "y0": y0, "y1": y1, "pts": PackedVector3Array(), "voisins": voisins,
			"long": escalier or String(md.get("role", "")) == "passage", "noeuds": []}
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
		if not is_instance_valid(n) or not n.is_inside_tree() or _est_exclu(n):
			continue
		var bb: AABB = (inv * n.global_transform) * n.get_aabb()
		var rn := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
		var liste: Array = []
		for r: Array in rects:
			if (r[1] as Rect2).intersects(rn) and bb.position.y < float(r[3]) and bb.end.y > float(r[2]):
				liste.append(r[0])
		if not liste.is_empty():
			_noeuds[n.get_instance_id()] = {"n": n, "s": liste}
			for id: String in liste:
				(salles[id]["noeuds"] as Array).append(n)
			if cacher_decor and not _visibles.is_empty():
				n.visible = _voulu(n)
		if budget_us > 0 and Time.get_ticks_usec() - debut > budget_us:
			return

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
	for v: String in salles[id]["voisins"]:
		if not salles.has(v):
			continue
		a[v] = true
		if salles[v]["long"]:
			for w: String in salles[v]["voisins"]:
				if salles.has(w):
					a[w] = true
	return a

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

## Recalcule la salle courante, l'ensemble actif, la géométrie cachée et les ennemis gelés.
func rafraichir(dedans := true) -> void:
	if joueur == null or not is_instance_valid(joueur):
		return
	var id := ""
	if dedans:
		id = salle_de(repere.to_local(joueur.global_position), 8.0)
	if dedans != _dedans or id != courante or _force:
		_force = false
		_dedans = dedans
		courante = id
		actives = _calculer_actives(id) if dedans else {}
		_appliquer_decor(actives if dedans else _calculer_actives(""))
	if geler_ennemis:
		_ennemis(dedans)

func _appliquer_decor(neuf: Dictionary) -> void:
	if not cacher_decor:
		return
	var change := {}
	for k: String in salles:
		if neuf.has(k) != _visibles.has(k):
			change[k] = true
	_visibles = neuf.duplicate()
	for k: String in change:
		for n: GeometryInstance3D in salles[k]["noeuds"]:
			if is_instance_valid(n):
				var voulu := _voulu(n)
				if n.visible != voulu:
					n.visible = voulu

## Visible si au moins une des salles que touche le nœud est visible.
func _voulu(n: GeometryInstance3D) -> bool:
	for sid: String in _noeuds[n.get_instance_id()]["s"]:
		if _visibles.has(sid):
			return true
	return false

func _ennemis(dedans: bool) -> void:
	nb_geles = 0
	for e: Node in arbre.get_nodes_in_group("ennemis"):
		if not is_instance_valid(e) or not e.has_method("peut_geler"):
			continue
		var pos: Vector3 = repere.to_local((e as Node3D).global_position)
		# seulement les ennemis de CE donjon (la grotte est à -220 m, la crypte à -26 m : volumes disjoints)
		if not volume.grow(2.0).has_point(pos):
			continue
		var veut_actif := true
		if not dedans:
			veut_actif = false
		elif courante != "":
			var sid := salle_de(pos)
			veut_actif = sid == "" or actives.has(sid)
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
	courante = ""
	_force = true
