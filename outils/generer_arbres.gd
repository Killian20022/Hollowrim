extends SceneTree
## Précalcule les atlas de rameaux (épicéa 256², pin, bouleau : mipmaps pixel art comprises) dans assets/arbres/<nom>.res.
## TexturesArbres les charge si la VERSION correspond, sinon il les recalcule (~0,4 s pour l'épicéa).
## À relancer après toute modif de textures_arbres.gd (et incrémenter VERSION) :
##   godot --headless --path . --script res://outils/generer_arbres.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	if OS.get_cmdline_user_args().has("--verifier"):
		var diff := 0
		for nom: String in TexturesArbres.PRECALCULES:
			var calc := TexturesArbres.image_precalculee(nom)
			var f := ResourceLoader.load("%s/%s.res" % [TexturesArbres.DOSSIER, nom]) as Image
			var ok: bool = f != null and f.get_data() == calc.get_data() and f.get_meta("version", -1) == TexturesArbres.VERSION
			print("%-14s %s" % [nom, "identique" if ok else "DIFFÉRENT"])
			diff += 0 if ok else 1
		quit(diff)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TexturesArbres.DOSSIER))
	for nom: String in TexturesArbres.PRECALCULES:
		var img := TexturesArbres.image_precalculee(nom)
		img.set_meta("version", TexturesArbres.VERSION)
		var chemin := "%s/%s.res" % [TexturesArbres.DOSSIER, nom]
		var err := ResourceSaver.save(img, chemin, ResourceSaver.FLAG_COMPRESS)
		print("%-14s %dx%d  %7d octets  %s" % [nom, img.get_width(), img.get_height(), FileAccess.get_file_as_bytes(chemin).size(), "OK" if err == OK else "ERREUR %d" % err])
	print("atlas d'arbres précalculés en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
