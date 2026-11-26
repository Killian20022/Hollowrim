class_name EvitementActeur
extends RefCounted
## COLLISIONS DES ACTEURS (2026-11-26, bugs/collisions_acteurs ; outils/audit_collisions_acteurs.gd) : briques communes aux PNJ,
## gardes, ennemis et animaux qui se pilotent sans navmesh (direction voulue + évitement par sondes + move_and_slide).
##
## 1. `libre(corps, dir, longueur)` : la sonde d'évitement balaie la CAPSULE du corps (rétrécie de 10 %, décollée du sol de 25 cm
##    pour ignorer les marches) au lieu d'un rayon unique à hauteur de genou. Un rayon passait entre deux obstacles plus serrés que
##    le corps, ou sous une table / au-dessus d'un muret : l'acteur s'y engageait et restait coincé en courant sur place.
##    Masque : celui du corps (calque 1 du décor) + le calque 64 des objets franchissables : ils sont contournés, jamais bloquants.
## 2. `vitesse_reelle(corps)` : vitesse horizontale vraiment parcourue au dernier move_and_slide (get_real_velocity) ; l'animation
##    de marche / course la suit (plus de course sur place contre un mur).
## 3. `vu(p)` : un joueur (local ou distant) voit le point (≤ 45 m et dans le champ de sa caméra, ou ≤ 12 m) : un acteur coincé
##    n'est replacé d'un coup que hors de vue ; sinon il s'arrête au repos et réessaie.

const MARGE_SOL := 0.25
const RETRECI := 0.9

static var _q := PhysicsShapeQueryParameters3D.new()
static var _caps := CapsuleShape3D.new()
static var _exclus_t := -1
static var _exclus: Array[RID] = []

## Corps à ne pas compter comme obstacle : les acteurs (on se contourne au corps à corps par move_and_slide) et les joueurs.
## Recalculé une fois par image de physique pour tous les appels.
static func _exclusions(corps: Node) -> Array[RID]:
	var f := Engine.get_physics_frames()
	if f != _exclus_t:
		_exclus_t = f
		_exclus.clear()
		var arbre := corps.get_tree()
		for g in ["ennemis", "villageois", "gardes_village", "persos_tous", "joueur_local", "faune", "bete_quat"]:
			for n in arbre.get_nodes_in_group(g):
				if n is CharacterBody3D:
					_exclus.append((n as CharacterBody3D).get_rid())
		for n in arbre.get_nodes_in_group("portes"):      # une porte s'ouvre devant le PNJ (Villageois._portes_en_route)
			if n is CollisionObject3D:
				_exclus.append((n as CollisionObject3D).get_rid())
			for c in (n as Node).find_children("*", "CollisionObject3D", true, false):
				_exclus.append((c as CollisionObject3D).get_rid())
		var j = corps.get("joueur")
		if j is CollisionObject3D:
			_exclus.append((j as CollisionObject3D).get_rid())
	var ex := _exclus.duplicate()
	ex.append((corps as CollisionObject3D).get_rid())
	return ex

static func _forme(corps: Node) -> CollisionShape3D:
	for c in corps.get_children():
		if c is CollisionShape3D and not (c as CollisionShape3D).disabled:
			return c
	return null

## Vrai si le corps peut avancer de `longueur` m dans la direction horizontale `dir` sans heurter le décor.
static func libre(corps: CharacterBody3D, dir: Vector3, longueur: float) -> bool:
	if not corps.is_inside_tree():
		return true
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 1e-6:
		return true
	d = d.normalized()
	var cs := _forme(corps)
	var r := 0.35
	var h := 1.7
	var centre := corps.global_position + Vector3(0, 0.9, 0)
	if cs != null:
		centre = cs.global_position
		if cs.shape is CapsuleShape3D:
			r = (cs.shape as CapsuleShape3D).radius
			h = (cs.shape as CapsuleShape3D).height
		elif cs.shape is SphereShape3D:
			r = (cs.shape as SphereShape3D).radius
			h = r * 2.0
		elif cs.shape is BoxShape3D:
			var b := (cs.shape as BoxShape3D).size
			r = minf(b.x, b.z) * 0.5
			h = b.y
	_caps.radius = r * RETRECI
	_caps.height = maxf(h - MARGE_SOL, _caps.radius * 2.0 + 0.01)
	_q.shape = _caps
	_q.transform = Transform3D(Basis(), centre + Vector3(0, MARGE_SOL * 0.5, 0))
	_q.motion = d * longueur
	# masque du corps (décor du calque 1) PLUS le calque 64 des objets franchissables (urnes, tonneaux, chaises : Cassable.CALQUE) :
	# move_and_slide ne bute pas dessus (jamais coincé derrière une chaise), mais la sonde les fait contourner au lieu de les traverser
	_q.collision_mask = (corps.collision_mask if corps.collision_mask != 0 else 1) | Cassable.CALQUE
	_q.exclude = _exclusions(corps)
	var esp := corps.get_world_3d().direct_space_state
	# déjà au contact (frottement le long d'un mur) : on ne le compte pas comme obstacle devant soi
	var res := esp.cast_motion(_q)
	if res.size() < 2 or res[0] >= 0.999:
		return true
	# heurt : pente ou marche praticable (normale tournée vers le haut) ? alors ce n'est pas un obstacle
	var t0 := _q.transform
	_q.transform = Transform3D(Basis(), t0.origin + _q.motion * float(res[1]))
	_q.motion = Vector3.ZERO
	var info := esp.get_rest_info(_q)
	_q.transform = t0
	return not info.is_empty() and (info["normal"] as Vector3).y > 0.6

## Vitesse horizontale réellement parcourue au dernier move_and_slide (m/s).
static func vitesse_reelle(corps: CharacterBody3D) -> float:
	var v := corps.get_real_velocity()
	return Vector2(v.x, v.z).length()

## Un joueur voit-il ce point ? Le joueur le plus proche (coop : ReseauMondeVivant.joueur_proche), sinon le joueur local.
static func vu(corps: Node, p: Vector3) -> bool:
	var local = corps.get("joueur")
	var arbre := corps.get_tree()
	if not (local is Node3D) and arbre != null:
		local = arbre.get_first_node_in_group("joueur_local")
	var j: Node3D = ReseauMondeVivant.joueur_proche(p, local) if local is CharacterBody3D else local
	if j == null or not is_instance_valid(j) or not j.is_inside_tree():
		return false
	var dj := j.global_position.distance_to(p)
	if dj < 12.0:
		return true
	if dj > 45.0:
		return false
	var cam = j.get("camera")
	if cam is Camera3D and (cam as Camera3D).is_inside_tree():
		return (cam as Camera3D).is_position_in_frustum(p + Vector3(0, 1.0, 0))
	return true

## Pilotage d'un PNJ (villageois, garde) vers un point : direction directe si la capsule y passe, sinon la plus proche des
## directions tournées (±30°, ±57°, ±92°) qui passe, côté mémorisé ; réévalué tous les 0,1 s (coût : une sonde par PNJ en marche).
class Pilote:
	var cote := 1.0
	var _tenue := 0.0
	var _dir := Vector3.ZERO
	var _prochain := 0.0
	var _voulu := Vector3.ZERO
	func corriger(corps: CharacterBody3D, dir: Vector3, dt: float) -> Vector3:
		if dir == Vector3.ZERO:
			return dir
		_prochain -= dt
		_tenue -= dt
		if _prochain > 0.0 and _dir != Vector3.ZERO and _voulu.dot(dir) > 0.97:
			return _dir
		_prochain = 0.1
		_voulu = dir
		if _tenue > 0.0 and _dir.dot(dir) > -0.2 and EvitementActeur.libre(corps, _dir, 0.8):
			return _dir
		if EvitementActeur.libre(corps, dir, 1.0):
			_dir = dir
			return dir
		for a in [0.5, 1.0, 1.6]:
			for c in [cote, -cote]:
				var d := dir.rotated(Vector3.UP, c * a)
				if EvitementActeur.libre(corps, d, 0.8):
					cote = c
					_dir = d
					_tenue = 0.6
					return d
		_dir = dir
		return dir      # rien ne passe : move_and_slide glisse le long de l'obstacle, le blocage est traité par l'appelant
	func changer_cote() -> void:
		cote = -cote
		_tenue = 0.0
		_prochain = 0.0
