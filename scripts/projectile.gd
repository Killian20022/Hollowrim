class_name Projectile
extends Node3D
## Flèche d'archer (bandit, squelette) : vol balistique léger, visible, arrêtée par le monde.
## Le joueur est touché via joueur.recevoir_coup(degats, origine) : garde et parade s'appliquent comme pour un coup d'épée
## (l'origine est prise sur la trajectoire, derrière la flèche, pour que « de face » soit juste).
##
##   Projectile.tirer(parent, depart, direction, tireur, degats) -> Projectile   (vitesse VITESSE m/s, chute GRAVITE m/s²)
##   Projectile.cap_visee(depart, cible, vitesse) -> Vector3  : direction qui compense la chute jusqu'à `cible`.
## Signaux : touche(resultat) avec "touche" | "bloque" | "parade" ; plante(position) quand elle se fiche dans le décor.
## Trait de GIVRE (mage nordique) : Projectile.tirer_givre(parent, depart, direction, tireur, degats, joueur) -> Projectile : éclat de
## glace lumineux, vol tendu (sans chute) et lent (VITESSE_GIVRE : on l'esquive d'un pas de côté), traînée de givre, petite lueur
## bleue ; au joueur : dégâts de glace + ralentissement bref (options de joueur.recevoir_coup) ; il se brise sur le décor.

signal touche(resultat: String)
signal plante(position_: Vector3)

const VITESSE := 21.0
const GRAVITE := 5.0
const VIE_VOL := 4.0     # s : au-delà, la flèche disparaît
const VIE_PLANTEE := 4.0 # s : une flèche fichée reste visible un moment
const VITESSE_GIVRE := 11.0
## Ralentissement infligé par un trait de givre qui touche : (durée s, facteur de vitesse).
const RALENTI_GIVRE := Vector2(1.8, 0.55)
const COULEUR_GIVRE := Color(0.62, 0.9, 1.6)

var vitesse := Vector3.ZERO
var degats := 10.0
var tireur: CollisionObject3D
var joueur: Node
var plantee := false
var resultat := ""       # "", "touche", "bloque", "parade", "mur"
## "fleche" ou "givre" ; chute appliquée (m/s²) ; options passées à joueur.recevoir_coup (seulement au joueur).
var genre := "fleche"
var gravite := GRAVITE
var options_coup := {}
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

## Trait de givre du mage nordique (voir l'en-tête).
static func tirer_givre(parent: Node, depart: Vector3, direction: Vector3, tireur_: CollisionObject3D, degats_ := 14.0, joueur_: Node = null, vitesse_ := VITESSE_GIVRE) -> Projectile:
	var p := Projectile.new()
	p.genre = "givre"
	p.gravite = 0.0
	p.degats = degats_
	p.tireur = tireur_
	p.joueur = joueur_
	p.options_coup = {"ralenti": RALENTI_GIVRE, "type": "glace", "recul": 2.5}
	p.vitesse = direction.normalized() * vitesse_
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
	if genre == "givre":
		_construire_givre()
		if tireur != null:
			_ex.append(tireur.get_rid())
		return
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

## Éclat de glace : losange allongé (deux pyramides) lumineux, cœur blanc, traînée de cristaux, lueur bleue de 3 m.
func _construire_givre() -> void:
	var m := Palette.lueur(COULEUR_GIVRE)
	for k in 2:
		var pr := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.09
		c.height = 0.34 if k == 0 else 0.2
		c.radial_segments = 4
		c.rings = 1
		pr.mesh = c
		pr.material_override = m
		pr.rotation.x = -PI * 0.5 if k == 0 else PI * 0.5   # pointe vers l'avant (+z après look_at : -z), queue courte
		pr.position.z = -0.17 if k == 0 else 0.1
		add_child(pr)
	var coeur := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.05, 0.3)
	coeur.mesh = b
	coeur.material_override = Palette.lueur(Color(1.6, 1.8, 2.0))
	add_child(coeur)
	var trainee := GPUParticles3D.new()
	trainee.amount = 24
	trainee.lifetime = 0.45
	trainee.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	trainee.process_material = pm
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.04
	cube.material = Palette.lueur(COULEUR_GIVRE * 0.8)
	trainee.draw_pass_1 = cube
	add_child(trainee)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.8, 1.0)
	l.light_energy = 1.4
	l.omni_range = 3.0
	l.shadow_enabled = false
	add_child(l)

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
	vitesse.y -= gravite * dt
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
		if not options_coup.is_empty() and joueur != null and cible == joueur:
			resultat = cible.recevoir_coup(degats, origine, options_coup)
		else:
			resultat = cible.recevoir_coup(degats, origine)
		if resultat == "":
			resultat = "touche"
		touche.emit(resultat)
		if genre == "givre":
			_briser(resultat == "touche")
		elif resultat == "touche":
			GerbePixels.emettre(self, global_position, (-vitesse.normalized() + Vector3.UP * 0.4).normalized(), "sang", 0.8)
		queue_free()
		return
	if genre == "givre":
		# la glace se brise sur le décor (pas de trait fiché)
		resultat = "mur"
		plante.emit(global_position)
		_briser(false)
		queue_free()
		return
	resultat = "mur"
	plantee = true
	_t = 0.0
	set_physics_process(true)
	plante.emit(global_position)
	Sons.jouer_a(self, ["knifeSlice2"], global_position, -8.0, 0.2)

## Éclatement du trait de givre : éclats de glace, buée, tintement.
func _briser(sur_joueur: bool) -> void:
	var d_g := (-vitesse.normalized() + Vector3.UP * 0.5).normalized() if vitesse.length() > 0.01 else Vector3.UP
	GerbePixels.emettre(self, global_position, d_g, "givre", 1.1 if sur_joueur else 0.9)
	GerbePixels.emettre(self, global_position, d_g, "givre_lueur", 0.7)
	Sons.jouer_a(get_parent() if get_parent() else self, ["impactPlate_medium_000", "impactPlate_medium_001"], global_position, -4.0, 0.15)
