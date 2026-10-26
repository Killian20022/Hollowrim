extends SceneTree
## Test sans fenêtre du menu principal (scripts/ecran_titre.gd, mode_test : ni relance ni monde) :
## - Continuer grisé et hors du parcours sans sauvegarde, et avec une sauvegarde illisible ; actif (et focus initial) avec une valide ;
## - parcours au clavier (EcranTitre.verifier_clavier : Bas/Haut en boucle, Échap → Quitter, Entrée sur Options, Échap retour).
## Ne touche qu'à la sauvegarde de TEST de ce worktree (Monde.fichier_test), remise à la fin.
##   godot --headless --path . --script res://outils/test_menu_titre.gd -- --nouvelle

var echecs := 0

func ok(c: bool, texte: String) -> void:
	print(("OK     " if c else "ÉCHEC  ") + texte)
	if not c:
		echecs += 1

func _init() -> void:
	_tester.call_deferred()

func _tester() -> void:
	var f: String = load("res://scripts/monde.gd").fichier_sauvegarde()
	ok(f.contains("sauvegarde_test_"), "sauvegarde de test utilisée (%s)" % f)
	var garde := FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else PackedByteArray()
	var titre: Control = (load("res://scenes/ecran_titre.tscn") as PackedScene).instantiate()
	titre.mode_test = true
	root.add_child(titre)
	for i in 5:
		await process_frame
	# sauvegarde valide
	_ecrire(f, '{"version": 1, "joueur": {"position": [1, 2, 3], "vie": 50}, "heure": 21.5, "inventaire": {"pieces": 7}}')
	titre._menu_principal()
	for i in 3:
		await process_frame
	ok(not titre._b_continuer.disabled, "sauvegarde valide : Continuer actif")
	ok(root.gui_get_focus_owner() == titre._b_continuer, "sauvegarde valide : focus initial sur Continuer")
	var r: Dictionary = Jeu.resume_sauvegarde()
	ok(r.get("pieces", -1) == 7 and absf(float(r.get("heure", 0)) - 21.5) < 0.01, "résumé de la sauvegarde pour Charger %s" % [r])
	# sauvegarde illisible
	_ecrire(f, "{ corrompue")
	titre._menu_principal()
	for i in 3:
		await process_frame
	ok(titre._b_continuer.disabled and titre._b_continuer.focus_mode == Control.FOCUS_NONE, "sauvegarde illisible : Continuer grisé, non sélectionnable")
	ok(root.gui_get_focus_owner() == titre._b_nouvelle, "sauvegarde illisible : focus initial sur Nouvelle partie")
	# sans sauvegarde + parcours clavier (verifier_clavier met la sauvegarde de côté et la remet)
	ok(await titre.verifier_clavier(), "parcours au clavier sans sauvegarde")
	ok(titre._decor != null, "décor animé chargé (scenes/menu_decor/menu_decor.tscn)")
	# mise en page : rectangle de l'image pour quelques écrans (boutons et logo toujours visibles), cadrage du décor
	for v: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440), Vector2(1920, 1200), Vector2(2560, 1080), Vector2(3440, 1440)]:
		var rect: Rect2 = titre.rect_image_decor(v)
		var s: float = rect.size.x / titre.IMG.x
		var g: float = rect.position.x + (titre.RAIL_X - 20.0) * s
		var bas: float = rect.position.y + (titre.BOUTON_POS.y + titre.PAS * 4 + titre.BOUTON_TAILLE.y) * s
		var haut_logo: float = rect.position.y + 90.0 * s   # haut des lettres du logo (la pointe au-dessus peut être rognée en 21:9)
		ok(g >= 0.0 and bas <= v.y and haut_logo >= 0.0 and titre.BOUTON_TAILLE.y * s >= 40.0,
			"écran %dx%d : colonne et logo visibles (gauche %.0f px, bas %.0f/%d, bouton %.0f px de haut)" % [v.x, v.y, g, bas, v.y, titre.BOUTON_TAILLE.y * s])
	titre.queue_free()
	await process_frame
	if garde.size() > 0:
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_buffer(garde)
		fa.close()
	elif FileAccess.file_exists(f):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("TOUT OK" if echecs == 0 else "ECHECS : %d" % echecs)
	quit(0 if echecs == 0 else 1)

func _ecrire(chemin: String, texte: String) -> void:
	var fa := FileAccess.open(chemin, FileAccess.WRITE)
	fa.store_string(texte)
	fa.close()
