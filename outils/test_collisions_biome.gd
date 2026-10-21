extends SceneTree
## Test headless des collisions du lot B (tumulus, rochers, arbres de la zone, exclusions) :
##   godot --headless --path . --script outils/test_collisions_biome.gd
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _rayon(x: float, z: float, y0: float, y1: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y0, z), Vector3(x, y1, z))
	return m.get_world_3d().direct_space_state.intersect_ray(q)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame

	# --- tumulus : dôme concave, plus de mur invisible ---
	var t: Node3D = m.tertre
	var ty := t.position.y
	var cx := t.position.x
	var cz := t.position.z - 15.0          # refonte crypte : butte reculée (z -15) et plus haute (échelle 0,6)
	var h := _rayon(cx, cz, ty + 20.0, ty - 5.0)
	var attendu := ty - 0.6 + 7.5 * 0.6
	_verif(not h.is_empty() and absf(h["position"].y - attendu) < 0.15, "rayon vers le bas au centre du tumulus : %.2f (attendu %.2f ± 0,15, soit sol + 3,9)" % [h["position"].y if not h.is_empty() else NAN, attendu])
	_verif(h.has("shape") and (h["collider"] as Node).get_child(h["shape"]).shape is ConcavePolygonShape3D, "la forme touchée est une ConcavePolygonShape3D")
	# l'ancien cylindre de 6,8 m (haut 3 m) aurait arrêté un rayon horizontal à 6,5 m du centre, à 0,5 m de haut
	var hq := PhysicsRayQueryParameters3D.create(Vector3(cx, ty + 4.3, cz + 6.5), Vector3(cx, ty + 4.3, cz - 6.5))
	_verif(m.get_world_3d().direct_space_state.intersect_ray(hq).is_empty(), "rien ne bloque un rayon horizontal à 4,3 m au-dessus du sol (sommet de la butte : 3,9 m) (plus de mur)")
	# marcheur : part du sud, monte sur la butte (x décalé de 3 m pour éviter la façade)
	var w := CharacterBody3D.new()
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	cap.shape = capsule
	cap.position.y = 0.9
	w.add_child(cap)
	root.add_child(w)
	var x := cx + 3.0
	w.global_position = Vector3(x, m.hauteur(x, cz + 11.0) + 0.3, cz + 11.0)
	var passe_68 := false
	var ymax := -INF
	for i in 700:
		w.velocity.x = 0.0
		w.velocity.z = -4.0
		w.velocity.y -= 20.0 * (1.0 / 60.0)
		w.move_and_slide()
		if w.is_on_floor():
			w.velocity.y = 0.0
		if w.global_position.z < cz + 6.4:
			passe_68 = true
		ymax = maxf(ymax, w.global_position.y)
		await physics_frame
	_verif(passe_68, "le marcheur dépasse 6,8 m du centre (z = %.1f, limite %.1f)" % [w.global_position.z, cz + 6.8])
	_verif(ymax > ty + 1.2, "le marcheur gravit la butte (y max %.2f, sol %.2f)" % [ymax, ty])
	# interactif de la porte : portée horizontale 2,3 m ; le sommet est à ~6,8 m
	var d_porte := Vector2(cx - t.position.x, cz - (t.position.z + 0.3)).length()
	_verif(d_porte > 2.3 + 1.0, "sommet à %.1f m de l'interactif de l'entrée (portée 2,3)" % d_porte)
	w.queue_free()

	# --- rochers : formes convexes sans échelle, rayon vers le bas ≈ sommet du maillage ---
	var corps_roc: StaticBody3D = null
	for c in m.get_children():
		if c is StaticBody3D and c.get_child_count() > 0 and (c.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D:
			corps_roc = c
	_verif(corps_roc != null, "StaticBody des rochers trouvé")
	var n_ok := 0
	var n_test := 0
	var pire := 0.0
	var sans_echelle := true
	for cs: CollisionShape3D in corps_roc.get_children():
		if not cs.transform.basis.is_equal_approx(Basis()):
			sans_echelle = false
		if n_test >= 20:
			continue
		var pts: PackedVector3Array = (cs.shape as ConvexPolygonShape3D).points
		var ymaxp := -INF
		for p in pts:
			ymaxp = maxf(ymaxp, p.y)
		# sommet réel : point le plus haut ; le rayon est tiré à l'aplomb de ce point
		var sommet := Vector3.ZERO
		for p in pts:
			if p.y == ymaxp:
				sommet = p
		var pos := cs.global_position + sommet
		var r := _rayon(pos.x, pos.z, pos.y + 5.0, pos.y - 5.0)
		if not r.is_empty():
			var ecart := absf(r["position"].y - pos.y)
			pire = maxf(pire, ecart)
			if ecart < 0.15:
				n_ok += 1
		n_test += 1
	_verif(sans_echelle, "aucune CollisionShape3D de rocher n'a de rotation/échelle (translation seule)")
	_verif(n_test > 0 and n_ok == n_test, "rayons sur %d rochers : %d sous 0,15 m (pire écart %.3f m)" % [n_test, n_ok, pire])

	# --- exclusions des rochers dans la zone ---
	var intrus := 0
	for cs: CollisionShape3D in corps_roc.get_children():
		var p := cs.global_position
		if Rochers.exclu_zone(m, p.x, p.z):
			intrus += 1
	_verif(intrus == 0, "aucun rocher (collision) dans les exclusions de zone (%d)" % intrus)
	_verif(Rochers.exclu_zone(m, -38.0, -34.0) == ZoneBiome.actif and Rochers.exclu_zone(m, -38.0, -54.5) == ZoneBiome.actif, "centres du cercle et du tumulus exclus")
	_verif(not Rochers.exclu_zone(m, 30.0, -30.0), "hors zone : jamais exclu")

	# --- arbres de la zone : cylindre ∝ échelle ---
	var n_zone := 0
	var n_hors := 0
	var ok_hors := true
	for c in m.get_children():
		if c is StaticBody3D and c.get_child_count() > 0 and (c.get_child(0) as CollisionShape3D).shape is CylinderShape3D:
			for cs: CollisionShape3D in c.get_children():
				var cyl := cs.shape as CylinderShape3D
				if ZoneBiome.masque(cs.position.x, cs.position.z) > 0.0:
					n_zone += 1
					if cyl.radius < 0.15 - 0.0001 or cyl.height < 4.0 * 0.3:
						ok_hors = false
				else:
					n_hors += 1
					if not is_equal_approx(cyl.radius, 0.35) or not is_equal_approx(cyl.height, 4.0):
						ok_hors = false
	_verif(ok_hors, "arbres : hors zone 0,35 × 4 inchangé (%d), zone ≥ 0,15 (%d)" % [n_hors, n_zone])
	print("ECHEC total : %d" % _echecs if _echecs > 0 else "TOUT OK")
	quit(1 if _echecs > 0 else 0)
