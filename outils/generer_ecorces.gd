extends SceneTree
## Précalcule les tuiles d'écorce (avec mipmaps) : godot --headless --path . --script res://outils/generer_ecorces.gd
## À relancer après toute modification de scripts/ecorces.gd (sinon la génération au lancement coûte ~1 s).
func _init() -> void:
	if OS.get_cmdline_user_args().has("--verifier"):
		var diff := 0
		for nom in Ecorces.NOMS:
			var calc := Ecorces.mips_image(Ecorces.image(nom))
			var f := ResourceLoader.load("%s/%s.res" % [Ecorces.DOSSIER, nom]) as Image
			var ok: bool = f != null and f.get_data() == calc.get_data() and f.get_meta("version", -1) == Ecorces.VERSION
			print("%-14s %s" % [nom, "identique" if ok else "DIFFÉRENT"])
			diff += 0 if ok else 1
		quit(diff)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Ecorces.DOSSIER))
	for nom in Ecorces.NOMS:
		var img := Ecorces.mips_image(Ecorces.image(nom))
		img.set_meta("version", Ecorces.VERSION)
		var err := ResourceSaver.save(img, "%s/%s.res" % [Ecorces.DOSSIER, nom])
		print(nom, " ", err)
	quit()
