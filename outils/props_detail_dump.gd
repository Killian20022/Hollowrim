extends SceneTree
## props/detail_v5 : exporte en PNG (hors dépôt) les textures du jeu qui servent de matière aux atlas détaillés des pq_*
## (bois du bâti, fer, cuir, lin, jute, pierre...) : entrée de sources_blender/scripts/props_detail_atlas.py.
##   godot --headless --path <worktree> --script res://outils/props_detail_dump.gd -- --sortie=C:/.../dossier
func _init() -> void:
	var sortie := "C:/Users/lopezk19/Jeux/rendus/props_v5/detail_src"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--sortie="):
			sortie = String(a).get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(sortie)
	var noms := {}
	for f in DirAccess.get_files_at("res://assets/bati"):
		if f.ends_with(".res"):
			noms["bati_" + f.get_basename()] = "res://assets/bati/" + f
	for f in DirAccess.get_files_at("res://assets/crypte"):
		if f.ends_with(".res") and not f.ends_with("_nm.res"):
			noms["crypte_" + f.get_basename()] = "res://assets/crypte/" + f
	for k: String in noms:
		var r: Resource = load(noms[k])
		var img: Image = null
		if r is Image:
			img = r
		elif r is Texture2D:
			img = (r as Texture2D).get_image()
		if img == null:
			print("ignore ", k)
			continue
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(sortie + "/" + k + ".png")
		print("PNG ", k, " ", img.get_size())
	quit(0)
