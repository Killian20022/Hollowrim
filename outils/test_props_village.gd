extends SceneTree
## Retours exe 5 (« des poteaux suspendus dans les airs », « d'un certain angle, des drapeaux suspendus ») : aucun prop du village ne
## flotte, et rien de suspendu ne survit à son support quand on s'éloigne.
## 1. Pied au sol : chaque maillage du mobilier, des abords et des rues (MobilierVillage, AbordsVillage, RuesVillage) est découpé en
##    pièces connexes ; pour chaque pièce verticale (h ≥ 0,9 m, plus haute que large), le pied (sommets les plus bas) doit être à
##    SEUIL du sol du terrain, OU sur une collision (rayon vers le bas, ≤ 8 cm), OU dans la boîte d'une autre pièce (hampe, comptoir,
##    traverse qui le porte). Sinon : ÉCHEC (c'était le montant des 6 bannières, à 1,2 m du sol).
## 2. Portées de dessin : chaque tissu de bannière a un mât à moins de 2,5 m dont la portée est ≥ la sienne (le mât fondu dans le
##    maillage de TOUT le mobilier disparaissait avant le tissu) ; poteaux, potences, cages et verres des lanternes des abords
##    partagent la même boîte de visibilité.
## Les maillages ne se relisent qu'avec un rendu : fenêtre (hors écran via godot_slot.sh), pas --headless.
##   godot --path . --script outils/test_props_village.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
const Sonde := preload("res://outils/sonde_props_village.gd")
const SEUIL := 0.05
const RACINES := ["MobilierVillage", "AbordsVillage", "RuesVillage"]

var m: Node3D
var _echecs := 0

func _init() -> void:
	_go.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await physics_frame
	while not bool(m.get("pret")):
		await process_frame
	for c in root.find_children("*", "CharacterBody3D", true, false):
		(c as CollisionObject3D).collision_layer = 0
	await physics_frame
	var esp := m.get_world_3d().direct_space_state
	var ps := []          # {noeud, pts, aabb}
	var nb_mi := 0
	for nom: String in RACINES:
		var r := m.get_node_or_null(nom)
		_verif(r != null, "nœud %s présent" % nom)
		if r == null:
			continue
		for gi in r.find_children("*", "MeshInstance3D", true, false):
			var mi := gi as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			nb_mi += 1
			var t := mi.global_transform
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
					continue
				var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var w := PackedVector3Array()
				w.resize(vv.size())
				for i in vv.size():
					w[i] = t * vv[i]
				var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				for p: PackedVector3Array in Sonde.pieces(w, ii):
					if p.is_empty():
						continue
					var a := AABB(p[0], Vector3.ZERO)
					for q in p:
						a = a.expand(q)
					ps.append({"noeud": "%s/%s" % [nom, mi.name], "pts": p, "aabb": a})
	print("%d maillages, %d pièces" % [nb_mi, ps.size()])
	_verif(ps.size() > 500, "les maillages du village se relisent (%d pièces ; lancer avec une fenêtre, pas --headless)" % ps.size())
	# 1. pieds au sol
	var verticales := 0
	var flottent := 0
	for i in ps.size():
		var e: Dictionary = ps[i]
		var a: AABB = e["aabb"]
		if a.size.y < 0.9 or maxf(a.size.x, a.size.z) > 0.55 * a.size.y:
			continue
		verticales += 1
		var pied := Vector3.ZERO
		var n := 0
		for q: Vector3 in e["pts"]:
			if q.y < a.position.y + 0.03:
				pied += q
				n += 1
		pied /= maxf(n, 1)
		var ecart := a.position.y - DetailsSol.hauteur_maillage(m, pied.x, pied.z)
		if ecart <= SEUIL:
			continue
		var hit := esp.intersect_ray(PhysicsRayQueryParameters3D.create(pied + Vector3(0, 0.02, 0), pied - Vector3(0, 6.0, 0)))
		if not hit.is_empty() and pied.y - (hit["position"] as Vector3).y <= 0.08:
			continue
		var porte := false
		for j in ps.size():
			if j != i and ((ps[j] as Dictionary)["aabb"] as AABB).grow(0.03).has_point(pied):
				porte = true
				break
		if porte:
			continue
		flottent += 1
		if flottent <= 12:
			print("      flotte de %.2f m : %s, pied (%.2f ; %.2f ; %.2f), h %.2f" % [ecart, e["noeud"], pied.x, pied.y, pied.z, a.size.y])
	_verif(verticales > 50, "pièces verticales examinées (%d)" % verticales)
	_verif(flottent == 0, "aucun poteau, mât ni perche du village en l'air (%d)" % flottent)
	# 2. portées : tissus des bannières et leur mât
	var mob := m.get_node_or_null("MobilierVillage")
	var tissus := 0
	var orphelins := 0
	if mob != null:
		var mats: Array = []
		for c in mob.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("Mat_"):
				mats.append(c)
		for piv in mob.get_children():
			if not String(piv.name).begins_with("Tissu"):
				continue
			for mt in (piv as Node).find_children("*", "MeshInstance3D", true, false):
				tissus += 1
				var ct := (mt as MeshInstance3D).global_transform * (mt as MeshInstance3D).get_aabb().get_center()
				var ok := false
				for ma: MeshInstance3D in mats:
					var cm := ma.global_transform * ma.get_aabb().get_center()
					if Vector2(cm.x - ct.x, cm.z - ct.z).length() < 2.5 and (ma.visibility_range_end == 0.0 or (mt as MeshInstance3D).visibility_range_end > 0.0 and (mt as MeshInstance3D).visibility_range_end <= ma.visibility_range_end):
						ok = true
						break
				if not ok:
					orphelins += 1
	_verif(tissus >= 6, "tissus de bannières trouvés (%d)" % tissus)
	_verif(orphelins == 0, "chaque tissu a son mât à côté, visible au moins aussi loin (%d sans)" % orphelins)
	var ab := m.get_node_or_null("AbordsVillage")
	if ab != null:
		var boites := {}
		for nom: String in ["Bois", "Bouts", "Fer", "Verre"]:
			var mi := ab.get_node_or_null(nom) as MeshInstance3D
			if mi != null and mi.visibility_range_end > 0.0:
				boites[nom] = mi.custom_aabb
		var une := true
		for k: String in boites:
			une = une and boites[k] == boites[boites.keys()[0]] and boites[k].size != Vector3.ZERO
		_verif(boites.size() >= 3 and une, "poteaux et lanternes des abords : une seule boîte de visibilité (%d maillages)" % boites.size())
	print("TEST PROPS VILLAGE : %s (%d échec(s))" % ["OK" if _echecs == 0 else "ECHEC", _echecs])
	quit(_echecs)
