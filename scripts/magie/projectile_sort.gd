class_name ProjectileSort
extends Projectile
## Projectile de SORT (boule de feu, éclat et lance de glace, trait d'ombre ; aussi les sorts du mage ennemi) : étend
## projectile.gd. Vol tendu, visuel fourni par EffetsMagie.projectile_visuel, arrêté par le décor ; touche les cibles du
## camp adverse par proximité (rayon RAYON_TOUCHE autour de la trajectoire : plus fiable qu'un rayon fin sur des corps
## animés). Peut traverser `traverse` cibles (lance). À chaque touche : rappel.call(cible, point, normale) — cible
## null = décor (fin du vol). Les dégâts sont faits par le rappel (LanceurSorts), pas ici.

const RAYON_TOUCHE := 0.4
const VIE_SORT := 3.0

var rappel: Callable
var traverse := 0
## Camp visé : "ennemis" (sort du joueur) ou "joueur" (sort d'un ennemi).
var vise := "ennemis"
var cible_joueur: Node3D
var _touches: Array = []
var _exclus: Array[RID] = []

static func tirer_sort(parent: Node, depart: Vector3, direction: Vector3, vitesse_: float, visuel: Node3D, rappel_: Callable, exclus: Array = [], traverse_ := 0) -> ProjectileSort:
	var p := ProjectileSort.new()
	p.genre = "sort"
	p.gravite = 0.0
	p.rappel = rappel_
	p.traverse = traverse_
	p.vitesse = direction.normalized() * vitesse_
	for e in exclus:
		if e is CollisionObject3D:
			p._exclus.append((e as CollisionObject3D).get_rid())
	if visuel != null:
		p.add_child(visuel)
	parent.add_child(p)
	p.global_position = depart
	p._orienter()
	return p

func _ready() -> void:
	pass   # pas de flèche : le visuel est fourni (EffetsMagie)

func _physics_process(dt: float) -> void:
	_t += dt
	if _t > VIE_SORT:
		queue_free()
		return
	var de := global_position
	var vers := de + vitesse * dt
	# cibles touchées sur le segment parcouru
	for c in _candidats():
		if _touches.has(c):
			continue
		var centre: Vector3 = Elements._centre(c) if vise == "ennemis" else c.global_position + Vector3(0, 1.1, 0)
		var proche := Geometry3D.get_closest_point_to_segment(centre, de, vers)
		var rayon := RAYON_TOUCHE + (0.15 if vise == "ennemis" else 0.0)
		if proche.distance_to(centre) <= rayon or _dans_hauteur(c, proche):
			if _mur_entre(de, proche):
				break
			_touches.append(c)
			resultat = "touche"
			if rappel.is_valid():
				rappel.call(c, proche, -vitesse.normalized())
			touche.emit("touche")
			if _touches.size() > traverse:
				queue_free()
				return
	# décor
	var q := PhysicsRayQueryParameters3D.create(de, vers)
	var ex := _exclus.duplicate()
	for g in ["ennemis", "cibles_combat"]:
		for e in get_tree().get_nodes_in_group(g):
			if e is CollisionObject3D:
				ex.append((e as CollisionObject3D).get_rid())
	if cible_joueur is CollisionObject3D:
		ex.append((cible_joueur as CollisionObject3D).get_rid())
	q.exclude = ex
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		global_position = r["position"]
		resultat = "mur"
		if r["collider"] is Cassable:      # L5 : urne, tonneau… brisés par le sort
			(r["collider"] as Cassable).briser_sort(r["position"])
		if rappel.is_valid():
			rappel.call(null, r["position"], r["normal"])
		plante.emit(r["position"])
		queue_free()
		return
	global_position = vers
	_orienter()

## Corps vertical (capsule d'ennemi) : le point est-il dans la colonne de la cible (rayon 0,45 m, du sol à 2 m) ?
func _dans_hauteur(c: Node3D, p: Vector3) -> bool:
	var b := c.global_position
	var h := p.y - b.y
	return h > 0.0 and h < 2.0 * float(c.get("echelle") if c.get("echelle") != null else 1.0) and Vector2(p.x - b.x, p.z - b.z).length() < 0.45

func _candidats() -> Array:
	if vise == "joueur":
		return [cible_joueur] if cible_joueur != null and is_instance_valid(cible_joueur) and not bool(cible_joueur.get("mort")) else []
	var res := []
	for g in ["ennemis", "cibles_combat"]:
		for e in get_tree().get_nodes_in_group(g):
			if e is Node3D and is_instance_valid(e) and not res.has(e) and e.get("est_mort") != true and (not e.has_method("vivant") or e.vivant()):
				res.append(e)
	return res

func _mur_entre(a: Vector3, b: Vector3) -> bool:
	if a.distance_to(b) < 0.05:
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b)
	var ex := _exclus.duplicate()
	for g in ["ennemis", "cibles_combat"]:
		for e in get_tree().get_nodes_in_group(g):
			if e is CollisionObject3D:
				ex.append((e as CollisionObject3D).get_rid())
	if cible_joueur is CollisionObject3D:
		ex.append((cible_joueur as CollisionObject3D).get_rid())
	q.exclude = ex
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
