extends SceneTree
## Poses de capture dégagées vers une liste de cibles (passe D) :
##   godot --headless --path . --script res://outils/poses_vers_cibles.gd -- <cibles.txt> <poses.txt>
## cibles.txt : `nom x z [distance]` par ligne (y = sol) ; poses.txt : vues « monde » de jour (heure=12), format --captures.
const SURFACE := preload("res://outils/audit_surface.gd")
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var m: Node3D = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await physics_frame
	var f := FileAccess.open(a[1], FileAccess.WRITE)
	for l in FileAccess.get_file_as_string(a[0]).split("\n"):
		var t := l.strip_edges()
		if t == "" or t.begins_with("#"):
			continue
		var c := t.split(" ", false)
		var x := float(c[1])
		var z := float(c[2])
		var p := Vector3(x, DetailsSol.hauteur_maillage(m, x, z), z)
		f.store_line("%s monde %s heure=12" % [c[0], SURFACE.vue_vers(m, p, float(c[3]) if c.size() > 3 else 3.5)])
	f.close()
	quit()
