extends SceneTree
## Test headless de la grotte vitrine : une capsule (r 0,35 ; h 1,8, comme le joueur) marche de l'entrée au fond ;
## aucune fuite (rayons depuis chaque anneau, tous doivent toucher la coque), sol sous chaque point du chemin, pente max,
## inventaire des collisions du décor.
##   godot --headless --path . --script outils/test_grotte.gd
const VITESSE := 4.0

var g: Grotte
var _echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

## Écart horizontal entre un point (repère local) et l'obstacle solide le plus proche (cylindres et boîtes du décor).
func _degagement(p: Vector3) -> float:
	var mini := 99.0
	for n in g.corps.get_children():
		var cs := n as CollisionShape3D
		if cs == null:
			continue
		var r := 0.0
		if cs.shape is CylinderShape3D:
			r = (cs.shape as CylinderShape3D).radius
		elif cs.shape is BoxShape3D:
			var b := (cs.shape as BoxShape3D).size
			r = maxf(b.x, b.z) * 0.5
		else:
			continue
		if absf(cs.position.y - p.y) > 3.0:
			continue
		mini = minf(mini, Vector2(cs.position.x - p.x, cs.position.z - p.z).length() - r)
	return mini

func _lancer() -> void:
	var t0 := Time.get_ticks_msec()
	var pere := Node3D.new()
	root.add_child(pere)
	g = Grotte.creer(pere)
	print("grotte construite en %d ms (%s), %d lumières, %d facettes, %d anneaux" % [Time.get_ticks_msec() - t0, g.etapes, g.nb_lumieres, g.decor.nb_facettes, g._anneaux.size()])
	for i in 6:
		await physics_frame
	var ss := g.get_world_3d().direct_space_state
	# 1. étanchéité : depuis chaque anneau, 40 rayons en tous sens doivent toucher la coque (pas de trou, pas de fuite de ciel)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var manques := 0
	var tirs := 0
	for r: Dictionary in g._anneaux:
		var o: Vector3 = g.to_global((r["P"] as Vector3) + Vector3(0, 0.45 * float(r["h"]), 0))
		for k in 40:
			var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var q := PhysicsRayQueryParameters3D.create(o, o + d * 70.0)
			tirs += 1
			if ss.intersect_ray(q).is_empty():
				manques += 1
				if manques < 6:
					print("   rayon sans impact depuis s=%.1f dir %s" % [r["s"], d])
	_verif(manques == 0, "étanchéité : %d rayons depuis %d anneaux, %d sans impact" % [tirs, g._anneaux.size(), manques])
	# 2. chemin : points du sol tous les 1 m, avec décalage latéral qui contourne le mobilier
	var route: Array[Vector3] = []
	var nb_decalage := 0
	var s := 1.0
	var lat_prec := 0.0
	var deniv_max := 0.0
	var y_prec := 0.0
	while s <= 122.5:
		var best_lat := 0.0
		var best_d := -99.0
		for lat in [0.0, lat_prec, 1.0, -1.0, 1.8, -1.8, 2.6, -2.6, 0.5, -0.5]:
			var p := g.sol_en(s, lat)
			var d := _degagement(p)
			if d > 0.8:
				best_lat = lat
				best_d = d
				break
			if d > best_d:
				best_d = d
				best_lat = lat
		if absf(best_lat) > 0.01:
			nb_decalage += 1
		lat_prec = best_lat
		var pt := g.sol_en(s, best_lat)
		route.append(g.to_global(pt) + Vector3(0, 0.1, 0))
		if s > 1.0:
			deniv_max = maxf(deniv_max, absf(pt.y - y_prec))
		y_prec = pt.y
		if best_d < 0.55:
			print("   passage serré à s=%.0f (dégagement %.2f m)" % [s, best_d])
		s += 1.0
	print("   chemin : %d points, %d avec décalage latéral, dénivelé max entre deux points %.2f m" % [route.size(), nb_decalage, deniv_max])
	# 3. sol sous chaque point
	var sans_sol := 0
	for p: Vector3 in route:
		var r := ss.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p - Vector3(0, 2.0, 0)))
		if r.is_empty() or absf(float(r["position"].y) - (p.y - 0.1)) > 0.4:
			sans_sol += 1
	_verif(sans_sol == 0, "sol sous chacun des %d points du chemin (%d sans sol)" % [route.size(), sans_sol])
	# 4. la capsule marche de l'entrée au fond
	var capsule := CharacterBody3D.new()
	var cs2 := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs2.shape = cap
	cs2.position.y = 0.9
	capsule.add_child(cs2)
	capsule.floor_snap_length = 0.4
	pere.add_child(capsule)
	capsule.global_position = route[0]
	for i in 10:
		await physics_frame
	var t := 0.0
	var cible := 1
	var depuis := 0.0
	var pos_ref := capsule.global_position
	var ok := true
	var pente_max := 0.0
	var y_min := 1e9
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	while cible < route.size() and t < 120.0:
		var p := capsule.global_position
		if Vector2(p.x - route[cible].x, p.z - route[cible].z).length() < 0.6:
			cible += 1
			continue
		var dir := Vector3(route[cible].x - p.x, 0, route[cible].z - p.z).normalized()
		capsule.velocity.x = dir.x * VITESSE
		capsule.velocity.z = dir.z * VITESSE
		capsule.velocity.y -= 20.0 * dt
		capsule.move_and_slide()
		if capsule.is_on_floor():
			pente_max = maxf(pente_max, rad_to_deg(capsule.get_floor_angle()))
		y_min = minf(y_min, capsule.global_position.y)
		await physics_frame
		t += dt
		depuis += dt
		if depuis >= 2.0:
			if capsule.global_position.distance_to(pos_ref) < 0.5:
				print("   bloqué près de ", g.to_local(capsule.global_position), " (point ", cible, "/", route.size(), " s≈", cible + 1, ")")
				ok = false
				break
			pos_ref = capsule.global_position
			depuis = 0.0
	_verif(ok and cible >= route.size(), "capsule : arrivée au fond en %.1f s (point %d/%d, pente max %.1f°)" % [t, cible, route.size(), pente_max])
	var bas := g.to_local(capsule.global_position).y
	_verif(bas > -12.0, "la capsule n'est pas tombée sous la grotte (y local final %.2f)" % bas)
	var nb_cs := 0
	for n in g.corps.get_children():
		if n is CollisionShape3D:
			nb_cs += 1
	print("collisions : %d formes (dont la coque trimesh de %d triangles)" % [nb_cs, g.decor.coll.size() / 3])
	print("TOUT OK" if _echecs == 0 else "ECHECS : %d" % _echecs)
	quit(_echecs)
