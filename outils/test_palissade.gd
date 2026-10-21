extends SceneTree
## Palissade du village (refonte passe 3 : visuel abaissé à ~1,5 m) — la COLLISION doit rester celle d'avant :
## un CylinderShape3D (rayon 0,22, hauteur 3,6, centre à 1,8 m) par pieu sur le cercle de 22 m, porte exceptée ;
## aucun rayon horizontal ne traverse le mur entre 0,3 et 3,4 m ; un marcheur qui pousse vers l'intérieur en sautant
## (saut et gravité du joueur) reste dehors. Vérifie aussi que le visuel est bien bas (< 2 m).
##   godot --headless --path . --script outils/test_palissade.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const VILLAGE_GD := preload("res://scripts/village.gd")
const JOUEUR_GD := preload("res://scripts/joueur.gd")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await physics_frame
	var v: Node3D = m.village
	var R: float = VILLAGE_GD.RAYON
	var ouverture := asin(VILLAGE_GD.DEMI_PORTE / R)
	var attendu := 0
	var nombre := int(TAU * R / 0.42)
	for i in nombre:
		if absf(wrapf(TAU * i / nombre, -PI, PI)) >= ouverture:
			attendu += 1

	# 1. formes de collision : mêmes nombre, rayon, hauteur et position qu'avant la refonte
	var n_cyl := 0
	var n_bons := 0
	for cs in (v.corps as StaticBody3D).get_children():
		if cs is CollisionShape3D and cs.shape is CylinderShape3D:
			var s: CylinderShape3D = cs.shape
			var p: Vector3 = cs.position
			if absf(Vector2(p.x, p.z).length() - R) < 0.01:
				n_cyl += 1
				if is_equal_approx(s.radius, 0.22) and is_equal_approx(s.height, 3.6) and is_equal_approx(p.y, 1.8):
					n_bons += 1
	_verif(n_cyl == attendu, "pieux de collision sur le cercle : %d (attendu %d)" % [n_cyl, attendu])
	_verif(n_bons == attendu, "tous en cylindre r 0,22 × h 3,6 centré à 1,8 m : %d / %d" % [n_bons, attendu])

	# 2. rayons horizontaux de l'extérieur vers l'intérieur, à 36 angles hors porte et 5 hauteurs
	var esp := m.get_world_3d().direct_space_state
	var n_r := 0
	var n_tou := 0
	for k in 36:
		var a := TAU * (k + 0.37) / 36.0
		if absf(wrapf(a, -PI, PI)) < ouverture + 0.05:
			continue
		var d := Vector3(sin(a), 0, cos(a))
		for hy in [0.3, 1.0, 1.8, 2.6, 3.4]:
			var q := PhysicsRayQueryParameters3D.create(v.to_global(d * (R + 1.0) + Vector3(0, hy, 0)), v.to_global(d * (R - 1.0) + Vector3(0, hy, 0)))
			q.collide_with_areas = false
			var h := esp.intersect_ray(q)
			n_r += 1
			if not h.is_empty() and h["collider"] == v.corps:
				n_tou += 1
	_verif(n_tou == n_r, "rayons horizontaux arrêtés par la palissade (0,3 à 3,4 m) : %d / %d" % [n_tou, n_r])

	# 3. marcheur (capsule du joueur) qui fonce vers l'intérieur en sautant sans arrêt, à 12 angles
	var w := CharacterBody3D.new()
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	cap.shape = capsule
	cap.position.y = 0.9
	w.add_child(cap)
	root.add_child(w)
	var passes := 0
	var essais := 0
	var pire := INF
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		if absf(wrapf(a, -PI, PI)) < ouverture + 0.3:
			continue
		essais += 1
		var d := Vector3(sin(a), 0, cos(a))
		var dep := v.to_global(d * (R + 1.6))
		w.global_position = Vector3(dep.x, m.hauteur(dep.x, dep.z) + 0.5, dep.z)
		w.velocity = Vector3.ZERO
		var dir := (v.to_global(Vector3.ZERO) - w.global_position) * Vector3(1, 0, 1)
		dir = dir.normalized()
		var r_min := INF
		for i in 240:
			w.velocity.x = dir.x * 7.0
			w.velocity.z = dir.z * 7.0
			w.velocity.y -= JOUEUR_GD.GRAVITE / 60.0
			if w.is_on_floor():
				w.velocity.y = JOUEUR_GD.SAUT
			w.move_and_slide()
			var loc := v.to_local(w.global_position)
			r_min = minf(r_min, Vector2(loc.x, loc.z).length())
			await physics_frame
		pire = minf(pire, r_min)
		if r_min < R - 0.3:
			passes += 1
	_verif(essais >= 10 and passes == 0, "marcheur sautant (saut %.1f, gravité %.0f) : %d / %d passages ; plus près du centre : %.2f m (mur à %.0f m)" % [JOUEUR_GD.SAUT, JOUEUR_GD.GRAVITE, passes, essais, pire, R])
	w.queue_free()

	# 4. visuel : les pieux bas dépassent de moins de 2 m (le village se voit par-dessus)
	var haut := 0.0
	var n_mm := 0
	for c in v.get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("PieuxBas"):
			n_mm += 1
			var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
			var bb := mm.mesh.get_aabb()
			for i in mm.instance_count:
				haut = maxf(haut, (mm.get_instance_transform(i) * bb).end.y)
	_verif(n_mm > 0 and haut < 2.0, "pieux visibles bas : %d lots, sommet %.2f m (< 2 m)" % [n_mm, haut])

	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
