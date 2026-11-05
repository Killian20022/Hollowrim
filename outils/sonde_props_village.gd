extends SceneTree
## Sonde (diagnostic) des props VERTICAUX du village qui flottent : chaque maillage visible de la boîte du village est découpé en
## pièces connexes (sommets soudés au mm) ; pour chaque pièce haute et fine (poteau, perche, mât, hampe…), le pied (sommets les plus
## bas) est comparé au sol du maillage de terrain, puis à la collision (rayon vers le bas) et aux autres pièces visibles (socle).
## Imprime les pièces dont le bas ne touche rien ; --diag écrit toutes les pièces suspectes dans user://sonde_props_village.json
## (analyse hors ligne). Retours exe 5 : c'est elle qui a trouvé le montant des bannières à 1,2 m du sol. Test : test_props_village.gd.
## Les maillages ne se relisent qu'avec un rendu : fenêtre (hors écran via godot_slot.sh), pas --headless.
##   godot --path . --script outils/sonde_props_village.gd -- --nouvelle --paisible [--tout] [--diag]
const SCENE := preload("res://scenes/foret_test.tscn")
const X0 := -8.0
const X1 := 102.0
const Z0 := 6.0
const Z1 := 100.0
const SEUIL := 0.05

var m: Node3D
var _nv := 0
var _dump = [] if OS.get_cmdline_user_args().has("--diag") else null

func _init() -> void:
	_go.call_deferred()

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
	var res := analyser(m, OS.get_cmdline_user_args().has("--tout"))
	print("SONDE : %d pièces verticales, %d flottantes" % [res["verticales"], (res["flottants"] as Array).size()])
	for f: Dictionary in res["flottants"]:
		print("  FLOTTE %.2f m  %s  pied (%.2f ; %.2f ; %.2f)  h %.2f  larg %.2f" % [f["ecart"], f["noeud"], f["pied"].x, f["pied"].y, f["pied"].z, f["h"], f["l"]])
	if res.has("dump"):
		var f := FileAccess.open("user://sonde_props_village.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(res["dump"]))
		f.close()
		print("SONDE : dump ", ProjectSettings.globalize_path("user://sonde_props_village.json"))
	quit(0)

## Pièces connexes d'un tableau de triangles (monde) : [[PackedVector3Array sommets], …].
static func pieces(v: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var n := v.size()
	var par := PackedInt32Array()
	par.resize(n)
	for i in n:
		par[i] = i
	var soude := {}
	for i in n:
		var k := Vector3i(roundi(v[i].x * 1000.0), roundi(v[i].y * 1000.0), roundi(v[i].z * 1000.0))
		if soude.has(k):
			_unir(par, i, soude[k])
		else:
			soude[k] = i
	var tri := idx
	if tri.is_empty():
		tri = PackedInt32Array(range(n))
	for t in range(0, tri.size() - 2, 3):
		_unir(par, tri[t], tri[t + 1])
		_unir(par, tri[t], tri[t + 2])
	var grp := {}      # racine -> Array d'indices (Array : par référence ; un Packed*Array lu du dictionnaire serait une copie)
	for i in n:
		var r := _racine(par, i)
		if not grp.has(r):
			grp[r] = []
		(grp[r] as Array).append(i)
	var out := []
	for l: Array in grp.values():
		var pv := PackedVector3Array()
		pv.resize(l.size())
		for k in l.size():
			pv[k] = v[l[k]]
		out.append(pv)
	return out

static func _racine(par: PackedInt32Array, i: int) -> int:
	while par[i] != i:
		par[i] = par[par[i]]
		i = par[i]
	return i

static func _unir(par: PackedInt32Array, a: int, b: int) -> void:
	var ra := _racine(par, a)
	var rb := _racine(par, b)
	if ra != rb:
		par[ra] = rb

func _dans_village(p: Vector3) -> bool:
	return p.x > X0 and p.x < X1 and p.z > Z0 and p.z < Z1

## Toutes les pièces des maillages visibles du village : [{noeud, pts, aabb}]
func _collecter(racine: Node) -> Array:
	var out := []
	for gi in racine.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var xf := g.global_transform
		var lots := []   # [mesh, Transform3D]
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			lots.append([(g as MeshInstance3D).mesh, xf])
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			for k in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
				lots.append([mm.mesh, xf * mm.get_instance_transform(k)])
		for l: Array in lots:
			var mesh: Mesh = l[0]
			var t: Transform3D = l[1]
			var ab: AABB = t * mesh.get_aabb()
			if not (_dans_village(ab.get_center()) or _dans_village(ab.position) or _dans_village(ab.end)):
				continue
			if ab.size.x > 60.0 or ab.size.z > 60.0:
				if not (mesh is ArrayMesh):
					continue
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
					continue
				var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				_nv += vv.size()
				if vv.is_empty() or vv.size() > 400000:      # terrain, grandes nappes : pas des props
					continue
				var w := PackedVector3Array()
				w.resize(vv.size())
				for i in vv.size():
					w[i] = t * vv[i]
				var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				for p: PackedVector3Array in pieces(w, ii):
					if p.is_empty():
						continue
					var a := AABB(p[0], Vector3.ZERO)
					for q in p:
						a = a.expand(q)
					if not _dans_village(a.get_center()):
						continue
					out.append({"noeud": str(g.get_path()).trim_prefix(str(m.get_path())), "pts": p, "aabb": a, "fin": g.visibility_range_end, "classe": g.get_class() + ":" + String(g.name) + ":" + ",".join(g.get_meta_list().map(func(k): return "%s=%s" % [k, str(g.get_meta(k)).left(20)])) + ":" + mesh.resource_name})
	return out

## Analyse : {verticales, flottants: [{noeud, ecart, pied, h, l}]}
func analyser(racine: Node, tout := false) -> Dictionary:
	var ps := _collecter(racine)
	print("SONDE : %d géométries, %d sommets, %d pièces" % [racine.find_children("*", "GeometryInstance3D", true, false).size(), _nv, ps.size()])
	var esp := (racine as Node3D).get_world_3d().direct_space_state
	var flott := []
	var nv := 0
	for i in ps.size():
		var e: Dictionary = ps[i]
		var a: AABB = e["aabb"]
		var h := a.size.y
		var l := maxf(a.size.x, a.size.z)
		if not tout and (h < 0.9 or l > 0.55 * h):
			continue
		nv += 1
		var pts: PackedVector3Array = e["pts"]
		var ymin := a.position.y
		var pied := Vector3.ZERO
		var n := 0
		for q in pts:
			if q.y < ymin + 0.03:
				pied += q
				n += 1
		pied /= maxf(n, 1)
		var sol := DetailsSol.hauteur_maillage(m, pied.x, pied.z)
		var ecart := ymin - sol
		if ecart <= SEUIL:
			continue
		# collision juste dessous (plancher, mur, socle solide)
		var rq := PhysicsRayQueryParameters3D.create(pied + Vector3(0, 0.02, 0), pied - Vector3(0, 6.0, 0))
		var hit := esp.intersect_ray(rq)
		var d_coll := 99.0 if hit.is_empty() else pied.y - (hit["position"] as Vector3).y
		if d_coll <= 0.08:
			if _dump != null:
				_dump.append({"noeud": e["noeud"], "classe": e["classe"], "ecart": ecart, "d_coll": d_coll, "pied": [pied.x, pied.y, pied.z], "h": h, "l": l, "supports": [], "fin": e["fin"], "classe2": e["classe"]})
			continue
		# autre pièce visible sous le pied (socle sans collision, poutre qui le porte)
		var porte := false
		var supports := []
		var sonde := AABB(pied - Vector3(0.06, 0.1, 0.06), Vector3(0.12, 0.12, 0.12))
		for j in ps.size():
			if j != i and ((ps[j] as Dictionary)["aabb"] as AABB).intersects(sonde):
				# support réel : un sommet de l'autre pièce à moins de 12 cm sous / autour du pied
				var proche := 9.0
				for q: Vector3 in (ps[j] as Dictionary)["pts"]:
					proche = minf(proche, (q - pied).length())
				supports.append([(ps[j] as Dictionary)["noeud"], proche, ((ps[j] as Dictionary)["aabb"] as AABB).size])
				porte = true
		if _dump != null:
			_dump.append({"noeud": e["noeud"], "classe": e["classe"], "ecart": ecart, "d_coll": d_coll, "pied": [pied.x, pied.y, pied.z], "h": h, "l": l, "aabb": [a.position.x, a.position.y, a.position.z, a.size.x, a.size.y, a.size.z], "supports": supports.map(func(x): return [x[0], x[1], [x[2].x, x[2].y, x[2].z]]), "fin": e["fin"], "classe2": e["classe"]})
		if porte:
			continue
		flott.append({"noeud": e["noeud"], "ecart": minf(ecart, d_coll), "pied": pied, "h": h, "l": l})
	flott.sort_custom(func(x, y): return x["ecart"] > y["ecart"])
	var res := {"verticales": nv, "flottants": flott}
	if _dump != null:
		res["dump"] = _dump
	return res
