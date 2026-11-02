extends SceneTree
## Agent Y (armures lourdes) : exporte le héros (HerosSkarnholt, corps du joueur en 3e personne) en glb AU REPOS, avec son Skeleton3D
## et ses pièces peau d'os, pour les scripts Blender des armures portées (sources_blender/armures/lourdes/*.py) : mêmes noms d'os,
## même pose de repos, poids du corps transférés aux armures. Écrit sources_blender/armures/heros_reference[_casque].glb
## + heros_os.json (origines des os au repos, repère du modèle : Y haut, +Z devant).
##   godot --headless --path . --script res://outils/exporter_heros_armures.gd -- --nouvelle [--anims]
func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var dossier := ProjectSettings.globalize_path("res://sources_blender/armures")
	DirAccess.make_dir_recursive_absolute(dossier)
	var anims := OS.get_cmdline_user_args().has("--anims")
	for casque in [false]:
		var g := HerosSkarnholt.creer({"casque": casque})
		root.add_child(g)
		var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
		sq.reset_bone_poses()
		var ap := g.get_node_or_null("Animations") as AnimationPlayer
		if ap != null and not anims:
			ap.get_parent().remove_child(ap)
			ap.free()
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
			print("PIECE ", mi.name, " visible=", mi.visible, " surfaces=", mi.mesh.get_surface_count() if mi.mesh else 0)
			if not mi.visible:      # pièces cachées retirées (le glTF de Godot les écrit avec KHR_node_visibility, inconnu de Blender 5.2)
				mi.get_parent().remove_child(mi)
				mi.free()
				continue
			# matériaux shader : remplacés par un StandardMaterial3D nommé (le glTF ne connaît pas les ShaderMaterial)
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					var m := StandardMaterial3D.new()
					m.resource_name = String(mi.name)
					mi.set_surface_override_material(s, m)
					mi.mesh.surface_set_material(s, m)
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		var err := doc.append_from_scene(g, st)
		var chemin := dossier.path_join("heros_reference%s.glb" % ("_casque" if casque else ""))
		if err == OK:
			err = doc.write_to_filesystem(st, chemin)
		print("EXPORT ", chemin, " err=", err)
		var os := {}
		for b in sq.get_bone_count():
			var t := sq.get_bone_global_rest(b)
			os[sq.get_bone_name(b)] = {"o": [t.origin.x, t.origin.y, t.origin.z], "parent": sq.get_bone_parent(b)}
		var f := FileAccess.open(dossier.path_join("heros_os.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(os, "  "))
		f.close()
		print("OS ", sq.get_bone_count())
		g.free()
	quit()
