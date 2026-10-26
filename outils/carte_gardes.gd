extends SceneTree
## Carte des gardes du village (vue de dessus, nord en haut) : obstacles réels (sondes de collision), palissade, eau, terrasses,
## postes fixes, vigie et rondes de data/gardes.json ; contrôle aussi que chaque segment de ronde est libre (capsule tous les 0,4 m).
##   godot --headless --path . --script res://outils/carte_gardes.gd -- --nouvelle --paisible [--sortie=C:/…/carte.png] [--pas=0.5]
## Sortie : PNG (défaut captures/gardes/carte_gardes.png) + lignes « SEGMENT … bloqué » pour les segments qui touchent un obstacle.
const SCENE := preload("res://scenes/foret_test.tscn")
const X0 := 12.0
const X1 := 80.0
const Z0 := 8.0
const Z1 := 96.0
const ECH := 8   # pixels par mètre

var m: Node3D
var _capsule := CapsuleShape3D.new()

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

## Vrai si une capsule de 0,3 m de rayon, de 0,45 à 1,85 m au-dessus du sol, ne touche aucun obstacle (terrain, rampes et corps vivants exclus).
func libre(x: float, z: float) -> bool:
	var y: float = m.hauteur(x, z)
	if absf(x - 44.0) < 1.6 and z > 56.5 and z < 66.5:   # pont : sol = tablier (rayon vers le bas)
		var rq := PhysicsRayQueryParameters3D.create(Vector3(x, y + 6.0, z), Vector3(x, y - 1.0, z))
		var hit := m.get_world_3d().direct_space_state.intersect_ray(rq)
		if not hit.is_empty():
			y = maxf(y, (hit["position"] as Vector3).y)
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = _capsule
	qs.transform = Transform3D(Basis(), Vector3(x, y + 1.15, z))
	for h in m.get_world_3d().direct_space_state.intersect_shape(qs, 8):
		var c: Node = h["collider"]
		if c is CharacterBody3D or (c.get_parent() == m and c.get_child_count() > 8):
			continue
		return false
	return true

## Eau, sauf sous le tablier du pont de pierre (x 42,4..45,6, z 57..66).
func _eau(x: float, z: float) -> bool:
	if absf(x - 44.0) < 1.6 and z > 56.5 and z < 66.5:
		return false
	return not is_nan(ReliefVillage.niveau_eau(x, z))

func _px(x: float, z: float) -> Vector2i:
	return Vector2i(int((x - X0) * ECH), int((z - Z0) * ECH))

func _ligne(img: Image, a: Vector2, b: Vector2, c: Color, ep := 1) -> void:
	var n := int(a.distance_to(b) * ECH) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var q := _px(p.x, p.y)
		for dx in range(-ep, ep + 1):
			for dy in range(-ep, ep + 1):
				var r := q + Vector2i(dx, dy)
				if r.x >= 0 and r.y >= 0 and r.x < img.get_width() and r.y < img.get_height():
					img.set_pixelv(r, c)

func _disque(img: Image, c0: Vector2, r: float, c: Color) -> void:
	var q := _px(c0.x, c0.y)
	var rp := int(r * ECH)
	for dx in range(-rp, rp + 1):
		for dy in range(-rp, rp + 1):
			if dx * dx + dy * dy <= rp * rp:
				var p := q + Vector2i(dx, dy)
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(p, c)

func _lancer() -> void:
	_capsule.radius = 0.3
	_capsule.height = 1.4
	m = SCENE.instantiate()
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	for i in 10:
		await physics_frame
	var pas := float(_arg("pas", "0.5"))
	var img := Image.create(int((X1 - X0) * ECH), int((Z1 - Z0) * ECH), false, Image.FORMAT_RGB8)
	var h0: float = m.h_village
	var couleurs := {"plateau": Color(0.86, 0.86, 0.84), "T1": Color(0.80, 0.82, 0.86), "T2": Color(0.74, 0.77, 0.83),
		"T3": Color(0.68, 0.72, 0.80), "escalier": Color(0.9, 0.8, 0.55), "mur": Color(0.5, 0.48, 0.45), "": Color(0.62, 0.66, 0.6)}
	var z := Z0
	while z < Z1:
		var x := X0
		while x < X1:
			var c: Color = couleurs.get(ReliefVillage.terrasse(x, z, h0), Color.GRAY)
			if _eau(x, z):
				c = Color(0.35, 0.55, 0.85)
			elif not libre(x, z):
				c = Color(0.25, 0.2, 0.18)
			img.fill_rect(Rect2i(_px(x, z), Vector2i(int(pas * ECH), int(pas * ECH))), c)
			x += pas
		z += pas
	# quadrillage : 5 m (clair), 10 m (foncé)
	for gx in range(int(X0), int(X1) + 1, 5):
		_ligne(img, Vector2(gx, Z0), Vector2(gx, Z1), Color(0.5, 0.5, 0.5) if gx % 10 else Color(0.3, 0.3, 0.3), 0)
	for gz in range(int(Z0), int(Z1) + 1, 5):
		_ligne(img, Vector2(X0, gz), Vector2(X1, gz), Color(0.5, 0.5, 0.5) if gz % 10 else Color(0.3, 0.3, 0.3), 0)
	if _arg("ascii") != "":
		# grille texte au pas --ascii (m) : # obstacle, ~ eau, . libre (enceinte), , dehors, = escalier
		var pa := float(_arg("ascii"))
		print("ASCII x0=%.2f z0=%.2f pas=%.2f" % [X0, Z0, pa])
		for zi in int((Z1 - Z0) / pa):
			var lig := "Z%6.2f " % (Z0 + zi * pa)
			for xi in int((X1 - X0) / pa):
				var cx := X0 + (xi + 0.5) * pa
				var cz := Z0 + (zi + 0.5) * pa
				var t := ReliefVillage.terrasse(cx, cz, h0)
				lig += "~" if _eau(cx, cz) else ("#" if not libre(cx, cz) else ("=" if t == "escalier" else ("m" if t == "mur" else ("." if t != "" else ","))))
			print(lig)
	# palissade
	var P: Array = ReliefVillage.PALISSADE
	for i in P.size():
		_ligne(img, P[i], P[(i + 1) % P.size()], Color(0.45, 0.25, 0.1), 1)
	# gardes
	var donnees: Dictionary = GardesVillage.donnees()
	var bloques := 0
	var teintes := [Color(0.85, 0.1, 0.1), Color(0.1, 0.45, 0.95), Color(0.1, 0.7, 0.2), Color(0.85, 0.45, 0.0), Color(0.6, 0.1, 0.75), Color(0.0, 0.65, 0.65), Color(0.6, 0.5, 0.0)]
	var k := 0
	for g: Dictionary in donnees.get("gardes", []):
		var route: Array = GardesVillage.route_de(g)
		if route.size() > 1:
			var tc: Color = teintes[k % teintes.size()]
			k += 1
			for i in route.size():
				var a: Vector2 = route[i]
				var b: Vector2 = route[(i + 1) % route.size()] if g.get("boucle", true) else route[mini(i + 1, route.size() - 1)]
				_ligne(img, a, b, tc, 1)
				var n := int(a.distance_to(b) / 0.4) + 1
				var rates := 0
				for s in n + 1:
					var p := a.lerp(b, float(s) / n)
					if not libre(p.x, p.y) or _eau(p.x, p.y):
						rates += 1
				if rates > 0:
					bloques += 1
					print("SEGMENT %s %d (%.1f;%.1f)->(%.1f;%.1f) bloqué : %d/%d sondes" % [g["id"], i, a.x, a.y, b.x, b.y, rates, n + 1])
			for p: Vector2 in route:
				_disque(img, p, 0.35, tc)
		var poste: Vector2 = route[0] if not route.is_empty() else Vector2.ZERO
		var couleur := Color(0.9, 0.05, 0.05) if g.get("type", "poste") == "poste" else (Color(1, 0.85, 0) if g.get("type") == "vigie" else Color.BLACK)
		_disque(img, poste, 0.8, couleur)
	var haldor: Vector3 = m.village.lieux.get("porte", Vector3.ZERO)
	_disque(img, Vector2(haldor.x, haldor.z), 0.9, Color(1, 1, 1))
	_disque(img, Vector2(haldor.x, haldor.z), 0.6, Color(0.9, 0.05, 0.05))
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/gardes/carte_gardes.png"))
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	img.save_png(sortie)
	print("CARTE %s (%dx%d) segments bloqués : %d" % [sortie, img.get_width(), img.get_height(), bloques])
	m.queue_free()
	await process_frame
	quit(0)
