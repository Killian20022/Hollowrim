extends SceneTree
## Compte les triangles des maillages des deux décors de la crypte (lot C4, chantier « anti pâte à modeler ») : sert au budget
## avant / après d'un lot de modules Blender. Ne modifie pas le jeu.
##   godot --headless --path . --script res://outils/compter_triangles_crypte.gd -- --nouvelle --paisible
## Sortie : « TRIANGLES crypte=… maillages=… » (et une ligne par décor).
const SCENE := "res://scenes/foret_test.tscn"

func _init() -> void:
	_go.call_deferred()

func _tris(n: Node) -> Vector2i:
	var t := 0
	var nb := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var me: Mesh = (n as MeshInstance3D).mesh
		nb += 1
		for s in me.get_surface_count():
			var a := me.surface_get_arrays(s)
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			t += (idx.size() if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for c in n.get_children():
		var r := _tris(c)
		t += r.x
		nb += r.y
	return Vector2i(t, nb)

func _go() -> void:
	var m: Node3D = (load(SCENE) as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 60:
		await physics_frame
	m.tertre.attendre_donjon()
	for i in 3:
		await physics_frame
	var tot := Vector2i.ZERO
	var k := 0
	for dec: CrypteDecor in [m.tertre.d, m.tertre.d2]:
		var r := _tris(dec.racine)
		print("DECOR %d triangles=%d maillages=%d" % [k, r.x, r.y])
		tot += r
		k += 1
	print("TRIANGLES crypte=%d maillages=%d" % [tot.x, tot.y])
	quit(0)
