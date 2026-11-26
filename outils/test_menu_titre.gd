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
	# joueur_base : Nouvelle partie -> choix du personnage (homme / femme, aperçu 3D) -> Commencer lance la partie avec ce corps
	titre._menu_principal()
	await process_frame
	Jeu.regler("personnage", "apparence", "homme", false)   # dernier choix : homme (en mémoire, options.cfg intact)
	titre._nouvelle()
	await process_frame
	ok(titre._choix.visible or titre._confirmation.visible, "Nouvelle partie : choix du personnage (ou confirmation s'il existe des parties)")
	titre._ouvrir_choix()
	for i in 3:
		await process_frame
	var ch: ChoixPersonnage = titre._choix
	ok(ch.visible and ch.sexe == "homme" and ch._modele != null and ch._modele.get_meta("apparence") == "homme", "choix ouvert : homme par défaut, aperçu 3D")
	ok(root.gui_get_focus_owner() == ch._b_go, "choix : focus sur Commencer")
	ch._b_femme.pressed.emit()
	for i in 2:
		await process_frame
	ok(ch.sexe == "femme" and ch._modele.get_meta("apparence") == "femme" and ch._b_femme.button_pressed and not ch._b_homme.button_pressed, "choix : Femme sélectionnée, aperçu changé")
	var r0: float = ch._pivot.rotation.y
	for i in 10:
		await process_frame
	ok(ch._pivot.rotation.y != r0, "choix : l'aperçu tourne")
	# multijoueur : l'hôte qui lance un NOUVEAU monde passe par le même choix (avant de prévenir les invités) ; Retour ramène au salon
	titre._ouvrir_multi()
	var mu: EcranMulti = titre._multi
	mu._role = "hote"
	mu._indice_monde = mu._emplacements.find(EcranMulti.NOUVEAU_MONDE)
	mu._lancer_hote()
	await process_frame
	ok(ch.visible and not mu.visible and titre._choix_suite.is_valid(), "multijoueur hôte, nouveau monde : écran de choix du personnage")
	ch.retour.emit()
	await process_frame
	ok(mu.visible and not ch.visible and not titre._choix_suite.is_valid(), "multijoueur : Retour du choix -> salon de l'hôte")
	var suite_appelee := [false]
	titre._choix_multi(func() -> void: suite_appelee[0] = true)    # suite factice (pas de réseau ouvert dans le test)
	await process_frame
	ch.choisir("femme")
	ch._b_go.pressed.emit()
	await process_frame
	ok(suite_appelee[0] and Jeu.apparence_choisie == "femme" and String(Jeu.option("personnage", "apparence")) == "femme" and not Jeu.nouvelle_partie,
		"multijoueur hôte : Commencer -> corps « femme » retenu, puis lancement de l'hôte (suite)")
	mu._role = ""
	Jeu.regler("personnage", "apparence", "homme", false)
	titre._lancer_multi("invite", false, -1)
	ok(Jeu.apparence_choisie == "homme", "multijoueur invité : reprend le dernier choix (homme)")
	Jeu.regler("personnage", "apparence", "femme", false)
	titre._demarre = false
	titre._ouvrir_choix()
	await process_frame
	ok(ch.sexe == "femme", "choix rouvert sur le dernier choix (femme)")
	ch._b_go.pressed.emit()
	await process_frame
	ok(Jeu.apparence_choisie == "femme" and Jeu.nouvelle_partie, "Commencer : nouvelle partie avec le corps « femme »")
	Jeu.apparence_choisie = "homme"
	Jeu.regler("personnage", "apparence", "homme", false)
	Jeu.nouvelle_partie = false
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
