extends SceneTree
## Exporte la tête, le cou, les épaules (peau, barbe, tunique, pèlerine) et l'ancienne capuche du mage AU REPOS, en OBJ, pour le script
## Blender sources_blender/scripts/capuche_mage.py (capuche v3 ajustée au crâne). Écrit sources_blender/capuche/tete_<pièce>[_femme].obj
## + os_[femme].json (origines des os au repos). Repère Godot (Y haut, Z devant).
##   godot --headless --path . --script res://outils/exporter_tete_mage.gd [-- --femme]
func _ecrire(mi: MeshInstance3D, chemin: String, garder: Callable) -> void:
	if mi == null or mi.mesh == null:
		return
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var s := ""
	for p in v:
		s += "v %.4f %.4f %.4f\n" % [p.x, p.y, p.z]
	var nf := 0
	for t in range(0, idx.size(), 3):
		var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		if garder.call(c):
			s += "f %d %d %d\n" % [idx[t] + 1, idx[t + 1] + 1, idx[t + 2] + 1]
			nf += 1
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(s)
	f.close()
	print("  %s : %d triangles" % [chemin.get_file(), nf])

func _init() -> void:
	var femme := OS.get_cmdline_user_args().has("--femme")
	var suf := "_femme" if femme else ""
	var dossier := ProjectSettings.globalize_path("res://sources_blender/capuche")
	DirAccess.make_dir_recursive_absolute(dossier)
	# sans capuche, visage gardé : la peau entière de la tête sert de surface de collision
	var g := MageNordique.creer({"corps": "femme" if femme else "homme", "capuche": false, "visage": true, "baton": false})
	root.add_child(g)
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	var haut := func(c: Vector3) -> bool: return c.y > 1.25
	_ecrire(sq.get_node_or_null("peau"), dossier.path_join("tete_peau%s.obj" % suf), haut)
	_ecrire(sq.get_node_or_null("Hair_Beard"), dossier.path_join("tete_barbe%s.obj" % suf), haut)
	_ecrire(sq.get_node_or_null("tunique"), dossier.path_join("tete_tunique%s.obj" % suf), haut)
	_ecrire(sq.get_node_or_null("mante"), dossier.path_join("tete_mante%s.obj" % suf), haut)
	var os := {}
	for nom in ["Head", "neck_01", "spine_03", "spine_02", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r"]:
		var b := sq.find_bone(nom)
		if b >= 0:
			var o := sq.get_bone_global_rest(b).origin
			os[nom] = [o.x, o.y, o.z]
	var f := FileAccess.open(dossier.path_join("os%s.json" % suf), FileAccess.WRITE)
	f.store_string(JSON.stringify(os, "  "))
	f.close()
	g.free()
	# l'ancienne capuche (référence de forme / taille)
	var g2 := MageNordique.creer({"corps": "femme" if femme else "homme", "visage": femme, "baton": false})
	root.add_child(g2)
	var sq2 := g2.find_child("Skeleton3D", true, false) as Skeleton3D
	_ecrire(sq2.get_node_or_null("capuche"), dossier.path_join("tete_ancienne_capuche%s.obj" % suf), func(c: Vector3) -> bool: return true)
	print("TETE EXPORTEE ", suf, " ", os)
	g2.free()
	quit()
