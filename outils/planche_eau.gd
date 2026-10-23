extends SceneTree
## Planches « RÉFÉRENCE | APRÈS » de l'eau : à gauche la vue de la planche de référence, à droite la capture de la scène de démo.
##   godot --headless --path . --script res://outils/planche_eau.gd -- --captures=<dossier des PNG> --sortie=<dossier> [--heure=jour]
## Références : exterieurs_v2_planche.png (vues 2, 3, 6) et crypte_v2_planche.png (vue 4 et détails de l'eau) dans C:/Users/lopezk19/Jeux/references.
const REF := "C:/Users/lopezk19/Jeux/references/"
const EXT := "exterieurs_v2_planche.png"
const CRY := "crypte_v2_planche.png"
## [vue capturée, planche, rectangle de la référence, légende]
const PAIRES := [
	["gue", EXT, Rect2i(521, 0, 492, 315), "ext2_riviere"],
	["gue_face", EXT, Rect2i(521, 0, 492, 315), "ext2_riviere"],
	["aval", EXT, Rect2i(521, 0, 492, 315), "ext2_riviere"],
	["lac", EXT, Rect2i(1030, 0, 506, 315), "ext3_lac"],
	["panorama", EXT, Rect2i(1030, 367, 506, 263), "ext6_panorama"],
	["bassin", CRY, Rect2i(14, 377, 486, 276), "cry4_inondee"],
	["regard_bas_pool", CRY, Rect2i(14, 377, 486, 276), "cry4_inondee"],
	["cascade", CRY, Rect2i(492, 875, 90, 90), "cry_petite_cascade"],
	["cascade_pres", CRY, Rect2i(492, 875, 90, 90), "cry_petite_cascade"],
	["approche_c", CRY, Rect2i(204, 875, 90, 90), "cry_eau_peu_profonde"],
	["regard_bas", CRY, Rect2i(300, 875, 90, 90), "cry_pierres_immergees"],
	["approche_b", CRY, Rect2i(396, 875, 90, 90), "cry_courant"],
]

func _init() -> void:
	var captures := ""
	var sortie := ""
	var heure := "jour"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			captures = a.substr(11)
		elif a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--heure="):
			heure = a.substr(8)
	DirAccess.make_dir_recursive_absolute(sortie)
	var planches := {}
	var n := 0
	for p in PAIRES:
		var f: String = "%s/%s_%s.png" % [captures, p[0], heure]
		if not FileAccess.file_exists(f):
			continue
		if not planches.has(p[1]):
			planches[p[1]] = Image.load_from_file(REF + p[1])
		var apres := Image.load_from_file(f)
		var ref: Image = (planches[p[1]] as Image).get_region(p[2])
		var h := apres.get_height()
		var w_ref := int(round(ref.get_width() * float(h) / ref.get_height()))
		ref.resize(w_ref, h, Image.INTERPOLATE_LANCZOS)
		var sortie_img := Image.create(w_ref + 8 + apres.get_width(), h, false, Image.FORMAT_RGB8)
		sortie_img.fill(Color(0.05, 0.07, 0.1))
		ref.convert(Image.FORMAT_RGB8)
		apres.convert(Image.FORMAT_RGB8)
		sortie_img.blit_rect(ref, Rect2i(0, 0, w_ref, h), Vector2i(0, 0))
		sortie_img.blit_rect(apres, Rect2i(0, 0, apres.get_width(), h), Vector2i(w_ref + 8, 0))
		sortie_img.save_png("%s/planche_%s_%s_%s.png" % [sortie, p[0], p[3], heure])
		n += 1
	print("planche_eau : %d planches RÉFÉRENCE | APRÈS écrites dans %s" % [n, sortie])
	quit()
