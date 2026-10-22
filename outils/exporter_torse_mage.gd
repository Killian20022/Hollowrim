extends SceneTree
## Exporte la tunique et la pèlerine du mage (repos) en OBJ pour le script Blender sources_blender/scripts/mage_pieces.py
## (lancer de rayons sur la surface réelle du torse). Écrit sources_blender/mage_<pièce>.obj ; repère Godot (Y haut, Z devant).
##   godot --headless --path . --script res://outils/exporter_torse_mage.gd [-- --femme]   (blender:false : pièces sans les écailles)
func _init() -> void:
	var femme := OS.get_cmdline_user_args().has("--femme")
	var g := MageNordique.creer({"corps": "femme" if femme else "homme", "blender": false})
	root.add_child(g)
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	for nom in ["tunique", "mante", "jupe"]:
		var mi := sq.get_node_or_null(nom) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var s := ""
		for p in v:
			s += "v %.4f %.4f %.4f\n" % [p.x, p.y, p.z]
		for t in range(0, idx.size(), 3):
			s += "f %d %d %d\n" % [idx[t] + 1, idx[t + 1] + 1, idx[t + 2] + 1]
		var f := FileAccess.open(ProjectSettings.globalize_path("res://sources_blender/mage_%s%s.obj" % [nom, "_femme" if femme else ""]), FileAccess.WRITE)
		f.store_string(s)
		f.close()
	print("torse exporté")
	g.free()
	quit()
