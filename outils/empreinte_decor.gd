extends SceneTree
## Empreinte des maillages fusionnés du décor (crypte, donjon, grotte, entrée de la grotte) : nombre de sommets et sommes de contrôle
## séparées pour positions+normales, UV, couleurs ; par matière. Sert à prouver qu'une réorganisation du code ne change pas le rendu
## (empreintes identiques) ou qu'un correctif ne touche que les UV. Fenêtre nécessaire (le serveur factice de --headless ne rend pas les tableaux).
##   godot --path . --script res://outils/empreinte_decor.gd -- --nouvelle --paisible [--sortie=C:/chemin/empreinte.txt]
var m: Node3D

func _init() -> void:
	_go.call_deferred()

func _arg(n: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return defaut

func _go() -> void:
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	m.tertre.attendre_donjon()
	m.grotte_acces.obtenir()
	for k in 10:
		await process_frame
	var par_mat := {}
	var lignes: PackedStringArray = []
	var groupes := {}
	for racine: Node in [m]:
		for n: Node in racine.find_children("Decor_*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var arr := mi.mesh.surface_get_arrays(0)
			var mat := String(mi.name).get_slice("_", String(mi.name).get_slice_count("_") - 1)
			var chemin := String(m.get_path_to(mi))
			var cle := chemin
			var g := chemin.get_slice("/", 0)
			groupes[g] = int(groupes.get(g, 0)) + 1
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uu: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var cc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			lignes.append("%s %d geo=%s uv=%s col=%s" % [cle, v.size(), (v.to_byte_array() + nn.to_byte_array()).hex_encode().md5_text(), uu.to_byte_array().hex_encode().md5_text(), cc.to_byte_array().hex_encode().md5_text()])
			var e: Array = par_mat.get(mat, [0, 0])
			e[0] += 1
			e[1] += v.size()
			par_mat[mat] = e
	lignes.sort()
	var txt := "\n".join(lignes)
	print("EMPREINTE maillages=%d total_md5=%s" % [lignes.size(), txt.md5_text()])
	for k in groupes:
		print("EMPREINTE groupe %s maillages=%d" % [k, groupes[k]])
	for k in par_mat:
		print("EMPREINTE matiere %s maillages=%d sommets=%d" % [k, par_mat[k][0], par_mat[k][1]])
	var sortie := _arg("sortie")
	if sortie != "":
		var f := FileAccess.open(sortie, FileAccess.WRITE)
		f.store_string(txt + "\n")
		f.close()
	quit(0)
