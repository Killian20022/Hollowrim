extends SceneTree
## Précalcule les tuiles du sol (SolTuiles) dans assets/sol/*.res et écrit des planches de contrôle.
##   godot --headless --path . --script res://outils/generer_sol.gd [-- <dossier planches>]
## Planches (défaut res://captures/sol/textures) : chaque tuile ×4, mosaïque 3×3 ×2, détails ×8.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else "res://captures/sol/textures"
	var t0 := Time.get_ticks_msec()
	var res := SolTuiles.calculer()
	print("tuiles calculées en %d ms" % (Time.get_ticks_msec() - t0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SolTuiles.DOSSIER))
	ResourceSaver.save(res["atlas_index"], SolTuiles.DOSSIER + "/sol_index.res", ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(res["atlas_couleur"], SolTuiles.DOSSIER + "/sol_couleur.res", ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(res["image_details"], SolTuiles.DOSSIER + "/sol_details.res", ResourceSaver.FLAG_COMPRESS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var noms := ["neige", "pietinee", "terre", "aiguilles", "mousse", "roche", "glace", "croute"]
	var toiles: Array = res["toiles"]
	# planche : une ligne par matière, variante 0 | variante 1 (×3), puis mosaïque 3×3 de la variante 0 (×1)
	var k := 3
	var n := SolTuiles.N
	var larg := n * k * 2 + n * 3 + 32
	var haut := (n * k + 8) * SolTuiles.NB_MATIERES
	var planche := Image.create(larg, haut, false, Image.FORMAT_RGBA8)
	planche.fill(Color(0.07, 0.07, 0.09))
	for m in SolTuiles.NB_MATIERES:
		var y0 := m * (n * k + 8)
		for v in 2:
			var img := SolTuiles.image_couleur(toiles[m * 2 + v])
			var g := img.duplicate()
			g.resize(n * k, n * k, Image.INTERPOLATE_NEAREST)
			planche.blit_rect(g, Rect2i(0, 0, n * k, n * k), Vector2i(v * (n * k + 8), y0))
			if v == 0:
				g.save_png("%s/tuile_%s_x%d.png" % [dossier, noms[m], k])
		# mosaïque mêlant les deux variantes (comme en jeu : plaques de variantes)
		for j in 3:
			for i in 3:
				var vv := (i + j) % 2
				var img2 := SolTuiles.image_couleur(toiles[m * 2 + vv])
				planche.blit_rect(img2, Rect2i(0, 0, n, n), Vector2i(n * k * 2 + 24 + i * n, y0 + j * n * k / 3))
	planche.save_png("%s/planche_tuiles.png" % dossier)
	var d: SolTuiles.Toile = toiles[toiles.size() - 1]
	var di := SolTuiles.image_couleur(d, Color("#aab8d6"))
	di.resize(SolTuiles.ND * 8, SolTuiles.ND * 8, Image.INTERPOLATE_NEAREST)
	di.save_png("%s/details_x8.png" % dossier)
	print("planches dans ", dossier)
	quit()
