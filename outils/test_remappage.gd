extends SceneTree
## Test sans fenêtre du remappage des touches (scripts/touches.gd) et des options graphiques (scripts/graphismes.gd) :
##   godot --headless --path . --script res://outils/test_remappage.gd -- --nouvelle
## - toutes les commandes sont des ACTIONS de l'InputMap, avec leurs touches par défaut (ZQSD = touches physiques WASD, flèches…) ;
## - une touche réattribuée déclenche l'action et plus l'ancienne ; une touche déjà prise est ÉCHANGÉE (jamais deux commandes sur
##   la même touche) ; les touches réservées sont refusées ; la secondaire peut être effacée ; la principale, jamais ;
## - l'aide du HUD, les libellés et l'écran Options (boutons de touches) suivent le remappage ;
## - en mode outil rien n'est écrit dans options.cfg ; les options graphiques ont des valeurs par défaut sûres.

var echecs := 0

func ok(c: bool, texte: String) -> void:
	print(("OK     " if c else "ÉCHEC  ") + texte)
	if not c:
		echecs += 1

func _init() -> void:
	_tester.call_deferred()

func _evenement(k: Key, presse := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = presse
	return e

func _tester() -> void:
	var mtime_options := FileAccess.get_modified_time(Jeu.FICHIER_OPTIONS) if FileAccess.file_exists(Jeu.FICHIER_OPTIONS) else -1
	Touches.liaisons = {}
	Touches.installer()
	# --- défauts ---
	for a: Dictionary in Touches.ACTIONS:
		ok(InputMap.has_action(a["id"]), "action « %s » créée" % a["id"])
	ok(_evenement(KEY_W).is_action("avant") and _evenement(KEY_UP).is_action("avant"), "avancer : W (ZQSD en AZERTY) et flèche haut")
	ok(_evenement(KEY_E).is_action("interagir") and _evenement(KEY_H).is_action("torche") and _evenement(KEY_T).is_action("attendre") and _evenement(KEY_V).is_action("vue"), "E interagir, H torche, T attendre, V vue")
	ok(_evenement(KEY_TAB).is_action("menu") and _evenement(KEY_I).is_action("inventaire") and _evenement(KEY_F5).is_action("sauvegarde_rapide"), "Tab menu, I sac, F5 sauvegarde rapide")
	ok(_evenement(KEY_F1).is_action("aide") and _evenement(KEY_M).is_action("carte") and _evenement(KEY_F9).is_action("chargement_rapide"), "F1 aide, M carte, F9 chargement rapide")
	# --- réattribution ---
	var autre := Touches.lier("torche", 0, KEY_G)
	ok(autre == "", "G était libre : aucun échange")
	ok(_evenement(KEY_G).is_action("torche") and not _evenement(KEY_H).is_action("torche"), "la torche est sur G, plus sur H")
	ok(_evenement(KEY_G).is_action_pressed("torche", false), "is_action_pressed suit la touche (les scripts du jeu testent l'action)")
	# --- échange ---
	autre = Touches.lier("vue", 0, KEY_G)
	ok(autre == "torche", "G était à la torche : échange signalé (%s)" % autre)
	ok(_evenement(KEY_G).is_action("vue") and _evenement(KEY_V).is_action("torche"), "vue sur G, la torche récupère V (échange, aucune commande orpheline)")
	var vues := {}
	var doublon := false
	for a: Dictionary in Touches.ACTIONS:
		for k: int in Touches.liaisons[a["id"]]:
			if k != KEY_NONE:
				doublon = doublon or vues.has(k)
				vues[k] = a["id"]
	ok(not doublon, "jamais deux commandes sur la même touche")
	# --- réservées / effacement ---
	ok(Touches.lier("saut", 0, KEY_ESCAPE) == "" and _evenement(KEY_SPACE).is_action("saut"), "Échap est réservée : refusée")
	Touches.lier("avant", 1, KEY_NONE)
	ok(not _evenement(KEY_UP).is_action("avant") and _evenement(KEY_W).is_action("avant"), "la touche secondaire s'efface, la principale reste")
	Touches.lier("avant", 0, KEY_NONE)
	ok(_evenement(KEY_W).is_action("avant"), "la principale ne s'efface pas")
	# même commande, autre rang : déplacée
	Touches.lier("gauche", 1, KEY_A)
	ok(int(Touches.touches_de("gauche")[0]) == KEY_NONE and int(Touches.touches_de("gauche")[1]) == KEY_A, "la même touche sur l'autre rang est déplacée, pas dupliquée")
	# --- libellés et aide ---
	ok(Touches.libelle("saut") == "Espace" and Touches.nom_touche(KEY_SHIFT) == "Maj", "libellés : Espace, Maj")
	Touches.lier("interagir", 0, KEY_F)
	ok(Touches.libelle("interagir") == "F", "libellé de l'interaction : F")
	var aide: Array = load("res://scripts/hud.gd").construire_aide()
	ok(aide.any(func(l: Array) -> bool: return l[0] == "F" and l[1] == "agir"), "l'aide F1 affiche la touche réelle (F) : %s" % [aide.map(func(l: Array) -> String: return l[0])])
	ok(not aide.any(func(l: Array) -> bool: return String(l[0]).contains("RB") or String(l[0]).contains("LT")), "aucun picto manette dans l'aide")
	# --- écran Options ---
	var options := PanelContainer.new()
	options.set_script(load("res://scripts/menu_options.gd"))
	root.add_child(options)
	await process_frame
	var bouton: Button = options._boutons_touches[["interagir", 0]]
	ok(bouton.text == "F", "Options : le bouton de l'interaction affiche F (%s)" % bouton.text)
	options._attendre("saut", 0)
	ok((options._boutons_touches[["saut", 0]] as Button).text == "Appuyez…", "Options : le bouton attend une touche")
	options.attribuer("saut", 0, KEY_X)
	ok(_evenement(KEY_X).is_action("saut") and (options._boutons_touches[["saut", 0]] as Button).text == "X", "Options : touche enregistrée et bouton mis à jour")
	options.attribuer("saut", 0, KEY_F)
	ok(Touches.libelle("interagir") == "X" and options._message_touches.text.contains("Parler"), "Options : échange annoncé au joueur (%s)" % options._message_touches.text)
	# --- rétablir ---
	Touches.retablir()
	ok(_evenement(KEY_E).is_action("interagir") and _evenement(KEY_UP).is_action("avant") and _evenement(KEY_H).is_action("torche") and _evenement(KEY_T).is_action("attendre"), "rétablir : touches d'origine")
	# --- mode outil : options.cfg intact ---
	var mtime2 := FileAccess.get_modified_time(Jeu.FICHIER_OPTIONS) if FileAccess.file_exists(Jeu.FICHIER_OPTIONS) else -1
	ok(Jeu.mode_outil() and mtime2 == mtime_options, "mode outil : le remappage n'écrit pas options.cfg")
	# --- options graphiques ---
	ok(Jeu.option("affichage", "vsync") == true and int(Jeu.option("affichage", "ombres")) == 2 and int(Jeu.option("affichage", "limite_ips")) == 0 and int(Jeu.option("affichage", "resolution")) == 0, "options graphiques par défaut : vsync, ombres normales, i/s illimitées, taille automatique")
	var l := DirectionalLight3D.new()
	l.shadow_enabled = true
	l.directional_shadow_max_distance = 62.0
	root.add_child(l)
	Graphismes.appliquer_ombres(self, 1)
	ok(l.shadow_enabled and absf(l.directional_shadow_max_distance - 62.0 * 0.55) < 0.01, "ombres proches : portée réduite (%.1f m)" % l.directional_shadow_max_distance)
	Graphismes.appliquer_ombres(self, 3)
	ok(absf(l.directional_shadow_max_distance - 62.0 * 1.7) < 0.01, "ombres lointaines : calculées sur la portée d'ORIGINE, sans cumul (%.1f m)" % l.directional_shadow_max_distance)
	Graphismes.appliquer_ombres(self, 0)
	ok(not l.shadow_enabled, "ombres désactivées")
	Graphismes.appliquer_ombres(self, 2)
	ok(l.shadow_enabled and absf(l.directional_shadow_max_distance - 62.0) < 0.01, "ombres normales : retour à l'origine")
	ok(Graphismes.noms_resolutions().size() == Graphismes.RESOLUTIONS.size() and Graphismes.noms_limites().size() == Graphismes.LIMITES_IPS.size(), "listes de choix cohérentes")
	print("TEST REMAPPAGE : ", "OK" if echecs == 0 else "ÉCHEC (%d)" % echecs)
	quit(1 if echecs > 0 else 0)
