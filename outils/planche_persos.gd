extends SceneTree
## Planches avant / apres des personnages vivants : pour chaque personnage, jour 2 m, nuit 2 m, jour 8 m (zoom x2) ; ligne « avant » (Humain, base 8b6c2a6)
## puis ligne « apres » (Personnage). Lit captures/persos/avant/<nom>.png et captures/persos/apres/<nom>_Idle.png (galeries galerie_persos.gd / galerie_base.gd).
##   godot --headless --script res://outils/planche_persos.gd
func _init() -> void:
	var dossier := ProjectSettings.globalize_path("res://captures/persos")
	DirAccess.make_dir_recursive_absolute(dossier + "/planches")
	for nom in ["pnj_chef", "pnj_forgeron", "pnj_chasseuse", "pnj_volva", "pnj_garde", "pnj_ancienne", "joueur", "bandit_0", "bandit_1", "bandit_2", "bandit_3"]:
		var av := Image.load_from_file("%s/avant/%s.png" % [dossier, nom])
		var ap := Image.load_from_file("%s/apres/%s_Idle.png" % [dossier, nom])
		var avz := Image.load_from_file("%s/avant/%s_zoom8m.png" % [dossier, nom])
		var apz := Image.load_from_file("%s/apres/%s_Idle_zoom8m.png" % [dossier, nom])
		if av == null or ap == null:
			print("manque ", nom)
			continue
		var w := av.get_width()
		var c := 270
		var out := Image.create(w, c * 6, false, Image.FORMAT_RGBA8)
		out.blit_rect(av, Rect2i(0, 0, w, c), Vector2i(0, 0))                  # avant j2
		out.blit_rect(ap, Rect2i(0, 0, w, c), Vector2i(0, c))                  # apres j2
		out.blit_rect(av, Rect2i(0, c * 2, w, c), Vector2i(0, c * 2))          # avant n2
		out.blit_rect(ap, Rect2i(0, c * 2, w, c), Vector2i(0, c * 3))          # apres n2
		out.blit_rect(avz, Rect2i(0, c, w, c), Vector2i(0, c * 4))             # avant j8 zoom
		out.blit_rect(apz, Rect2i(0, c, w, c), Vector2i(0, c * 5))             # apres j8 zoom
		out.save_png("%s/planches/avant_apres_%s.png" % [dossier, nom])
		print("planche ", nom)
	quit()
