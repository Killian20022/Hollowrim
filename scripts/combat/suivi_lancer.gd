class_name SuiviLancer
extends Node
## Enfant d'un objet LANCÉ (ImpactsLances.suivre) : à chaque image physique, AVANT le pas du moteur, balaie la forme de l'objet le long
## de sa vitesse (cast_motion) et appelle ImpactsLances.objet_touche au premier contact (ennemi, ragdoll, mur, sol, autre objet) :
## rien n'est sauté à grande vitesse, et une lame se fiche avant que le moteur ne la fasse rebondir.
## `stabiliser` : la lame garde le nez dans le vol (arme qui ressort d'un corps traversé), comme une flèche.
## Se retire seul : objet planté, trop lent (< V_MIN) ou au bout de `duree` s.

const V_MIN := 4.0
## Calques balayés : décor et ennemis (1), os des ragdolls et morceaux (16), objets cassables / vivants (64).
const MASQUE := 1 | 16 | 64

var objet: RigidBody3D
var lanceur: Node
var duree := 4.0
var t := 0.0
var stabiliser := false
var _ignores: Array[RID] = []
var _ign_noeuds: Array = []

func ignorer(n: Node) -> void:
	_ign_noeuds.append(weakref(n))
	if n is CollisionObject3D:
		_ignores.append((n as CollisionObject3D).get_rid())

func _ready() -> void:
	process_physics_priority = -10

func _physics_process(dt: float) -> void:
	if not is_instance_valid(objet) or not objet.is_inside_tree() or ImpactsLances.plantee(objet):
		queue_free()
		return
	t += dt
	var v := objet.linear_velocity
	if t > duree or (t > 0.15 and v.length() < V_MIN):
		queue_free()
		return
	if stabiliser and v.length() > 2.0 and objet.has_method("donnees_arme"):
		var ab := ImpactsLances.axe_monde(objet, objet.donnees_arme())
		var axe: Vector3 = (Vector3(ab[1]) - Vector3(ab[0])).normalized()
		var q := Quaternion(axe, v.normalized())
		var c := objet.global_position
		objet.global_basis = Basis(q) * objet.global_basis
		objet.global_position = c
		objet.angular_velocity = Vector3.ZERO
	var formes := objet.find_children("*", "CollisionShape3D", false, false)
	if formes.is_empty():
		return
	var espace := objet.get_world_3d().direct_space_state
	var ex: Array[RID] = [objet.get_rid()]
	ex.append_array(_ignores)
	if lanceur is CollisionObject3D:
		ex.append((lanceur as CollisionObject3D).get_rid())
	for e in objet.get_collision_exceptions():
		ex.append(e.get_rid())
	# os des ragdolls d'un ennemi traversé : ignorés aussi
	for w: WeakRef in _ign_noeuds:
		var n := w.get_ref() as Node
		if n != null:
			for pb in n.find_children("*", "PhysicalBone3D", true, false):
				ex.append((pb as PhysicalBone3D).get_rid())
	var mouvement := v * dt * 1.15
	var meilleur := 2.0
	var info := {}
	for f: CollisionShape3D in formes:
		if f.shape == null or f.disabled:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = f.shape
		q.transform = f.global_transform
		q.motion = mouvement
		q.collision_mask = MASQUE
		q.exclude = ex
		var r := espace.cast_motion(q)
		if r.size() == 2 and r[1] < 1.0 and r[1] < meilleur:
			q.transform.origin += mouvement * r[1]
			q.motion = Vector3.ZERO
			q.margin = 0.02
			var ri := espace.get_rest_info(q)
			if not ri.is_empty():
				meilleur = r[1]
				info = ri
	if info.is_empty():
		return
	var cible := instance_from_id(int(info["collider_id"])) as Node
	ImpactsLances.objet_touche(objet, cible, info["point"], info["normal"], v, lanceur)
