extends SceneTree
## Ecrit les atlas des personnages en PNG (index -> couleurs d'un PNJ moyen) pour revue : godot --headless --script res://outils/dump_atlas.gd -- --sortie=res://captures/persos/atlas
func _init() -> void:
	var sortie := "res://captures/persos/atlas"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	for sexe in ["homme", "femme"]:
		var img := PersoAtlas.peindre(sexe)
		img.save_png(ProjectSettings.globalize_path("%s/index_%s.png" % [sortie, sexe]))
		# rendu en couleurs (memes rampes que le shader) pour lire l'image
		var coul := {0: Color("#e8c9ae"), 1: Color("#9b8a6c"), 2: Color("#5d4a38"), 3: Color("#6a4426"), 4: Color("#7a2a30"), 5: Color("#5a3a20"), 6: Color("#aeb4c0"), 7: Color("#4a6a8a")}
		var fixes := [Color("#222630"), Color("#3a4458"), Color("#566277"), Color("#8a96ad"), Color("#b9c3d6"), Color("#806124"), Color("#b8943d"), Color("#e0c266"), Color("#cccbc7"), Color("#ede9e0"), Color("#1a1210"), Color("#0a0808"), Color("#6b231f"), Color("#9e382e"), Color("#2e1f14"), Color.MAGENTA]
		var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				var reg := int(round(p.g * 255.0)) / 16
				var c: Color
				if reg == 8:
					c = fixes[int(round(p.r * 255.0)) / 16]
				else:
					c = PersonnagesTextures.rampe(coul[reg])[int(round(p.r * 255.0)) / 32]
				c.a = 1.0 if p.a > 0.5 else 0.0
				out.set_pixel(x, y, c)
		out.save_png(ProjectSettings.globalize_path("%s/couleurs_%s.png" % [sortie, sexe]))
		print("atlas ", sexe, " ", img.get_size())
	quit()
