class_name Projectile
extends Node3D
## Flèche d'archer (bandit, squelette) : vol balistique léger, visible, arrêtée par le monde.
## Le joueur est touché via joueur.recevoir_coup(degats, origine) : garde et parade s'appliquent comme pour un coup d'épée
## (l'origine est prise sur la trajectoire, derrière la flèche, pour que « de face » soit juste).
##
##   Projectile.tirer(parent, depart, direction, tireur, degats) -> Projectile   (vitesse VITESSE m/s, chute GRAVITE m/s²)
##   Projectile.cap_visee(depart, cible, vitesse) -> Vector3  : direction qui compense la chute jusqu'à `cible`.
## Signaux : touche(resultat) avec "touche" | "bloque" | "parade" ; plante(position) quand elle se fiche dans le décor.

signal touche(resultat: String)
signal plante(position_: Vector3)

const VITESSE := 21.0
const GRAVITE := 5.0
const VIE_VOL := 4.0     # s : au-delà, la flèche disparaît
const VIE_PLANTEE := 4.0 # s : une flèche fichée reste visible un moment

var vitesse := Vector3.ZERO
var degats := 10.0
var tireur: CollisionObject3D
var joueur: Node
var plantee := false
var resultat := ""       # "", "touche", "bloque", "parade", "mur"
var _t := 0.0
var _ex: Array[RID] = []

static func tirer(parent: Node, depart: Vector3, direction: Vector3, tireur_: CollisionObject3D, degats_ := 10.0, joueur_: Node = null) -> Projectile:
	var p := Projectile.new()
	p.degats = degats_
	p.tireur = tireur_
	p.joueur = joueur_
	p.vitesse = direction.normalized() * VITESSE
	parent.add_child(p)
	p.global_position = depart
	p._orienter()
	return p

## Direction de tir qui compense la chute sur la durée du vol (vol quasi tendu : on remonte la visée de ½·g·t²).
static func cap_visee(depart: Vector3, cible: Vector3, vitesse_ := VITESSE) -> Vector3:
	var d := cible - depart
	var t := Vector2(d.x, d.z).length() / vitesse_
	d.y += 0.5 * GRAVITE * t * t
	return d.normalized()

func _ready() -> void:
	var fut := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.035, 0.035, 0.85)
	fut.mesh = b
	fut.material_override = _materiau(Color(0.46, 0.34, 0.2), 0.0)
	add_child(fut)
	var pointe := MeshInstance3D.new()
	var c := BoxMesh.new()
	c.size = Vector3(0.07, 0.07, 0.13)
	pointe.mesh = c
	pointe.position.z = 0.46
	pointe.material_override = _materiau(Color(0.8, 0.85, 0.95), 0.9)
	add_child(pointe)
	var plumes := MeshInstance3D.new()
	var e := BoxMesh.new()
	e.size = Vector3(0.12, 0.012, 0.16)
	plumes.mesh = e
	plumes.position.z = -0.36
	plumes.material_override = _materiau(Color(0.85, 0.82, 0.75), 0.3)
	add_child(plumes)
	if tireur != null:
		_ex.append(tireur.get_rid())

static func _materiau(couleur: Color, lueur: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = couleur.lerp(Color.WHITE, lueur * 0.35)
	return m

func _orienter() -> void:
	if vitesse.length() > 0.01:
		var haut := Vector3.UP if absf(vitesse.normalized().y) < 0.98 else Vector3.RIGHT
		look_at(global_position + vitesse, haut)

func _physics_process(dt: float) -> void:
	_t += dt
	if plantee:
		if _t > VIE_PLANTEE:
			queue_free()
		return
	if _t > VIE_VOL:
		queue_free()
		return
	vitesse.y -= GRAVITE * dt
	var de := global_position
	var vers := de + vitesse * dt
	var q := PhysicsRayQueryParameters3D.create(de, vers + vitesse.normalized() * 0.4)
	var ex := _ex.duplicate()
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is CollisionObject3D:
			ex.append((e as CollisionObject3D).get_rid())
	q.exclude = ex
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		global_position = vers
		_orienter()
		return
	global_position = r["position"] - vitesse.normalized() * 0.3
	var cible: Object = r["collider"]
	if cible != null and cible.has_method("recevoir_coup") and cible is CharacterBody3D:
		var origine: Vector3 = global_position - vitesse.normalized() * 2.0
		resultat = cible.recevoir_coup(degats, origine)
		if resultat == "":
			resultat = "touche"
		touche.emit(resultat)
		if resultat == "touche":
			Effets.eclats(self, global_position, Color(0.8, 0.1, 0.1), 8, 2.0)
		queue_free()
		return
	resultat = "mur"
	plantee = true
	_t = 0.0
	set_physics_process(true)
	plante.emit(global_position)
	Sons.jouer_a(self, ["knifeSlice2"], global_position, -8.0, 0.2)
