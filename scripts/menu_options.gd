extends PanelContainer
## Panneau Options (écran titre et menu pause) : affichage, graphismes, son, commandes, remappage des touches.
## Chaque changement est appliqué et enregistré aussitôt dans user://options.cfg (Jeu.regler).
## `joueur` (facultatif, en partie) : reçoit le nouveau champ de vision tout de suite.

signal ferme

var joueur: Node = null
## Écran titre (menu principal en haute définition) : thème runique (MenuStyle.theme_titre) et tailles fixes multipliées par
## `echelle` (pixels de l'image de référence au lieu de l'écran logique 640x360). Par défaut (menu pause) : thème pixel, ×1.
var theme_impose: Theme = null
var echelle := 1.0
## En partie (menu pause) : panneau de cuir à filet d'or (StyleParchemin.theme_cuir) au lieu du cadre ornementé gris-bleu.
var cuir := false
var _premier: Control
var _touches: Control
## Remappage : boutons (id, rang) -> Button ; commande en attente d'une touche ([id, rang]) ; ligne de retour d'information.
var _boutons_touches := {}
var _attente_touche: Array = []
var _message_touches: Label
## Sous-panneau « Caméra » (balancement de l'arme, mouvement de tête, secousses) : remplace la grille tant qu'il est ouvert
## (trois lignes de plus débordaient du panneau de l'écran titre).
var _camera: Control
var _premier_camera: Control
var _reglages: Control
var _case_plein: CheckButton
var _secours: Label
var _reglages_bas: Control
var _dialogue: FileDialog
## Hauteur maximale du panneau (pixels du panneau, avant l'échelle du parent) ; 0 = hauteur de la fenêtre moins une marge.
## Au-delà, les réglages défilent (molette, barre, focus clavier) ; titre, ligne de la copie de secours et boutons du bas
## restent toujours visibles (le panneau de l'écran titre débordait en 1280x720 : Touches / Retour / Caméra coupés).
var hauteur_max := 0.0:
	set(v):
		hauteur_max = v
		if is_node_ready():
			_ajuster()
var _defile: ScrollContainer
var _contenu: VBoxContainer

func _ready() -> void:
	theme = theme_impose if theme_impose != null else (StyleParchemin.theme_cuir() if cuir else MenuStyle.theme())
	custom_minimum_size = Vector2(380, 0) * echelle
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", roundi(2 * echelle))
	add_child(pile)
	var titre := MenuStyle.etiquette("Options", MenuStyle.OR)
	if theme_impose != null:   # titre de panneau du menu principal : capitales gravées, givre
		titre.text = "OPTIONS"
		titre.add_theme_font_override("font", MenuStyle.police_capitales(600))
		titre.add_theme_font_size_override("font_size", 34)
		titre.add_theme_color_override("font_color", MenuStyle.GIVRE)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(titre)

	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", roundi(8 * echelle))
	g.add_theme_constant_override("v_separation", roundi(1 * echelle))
	_reglages = g
	# réglages, sous-panneau Caméra et rappel des touches : dans une zone qui défile si le panneau ne tient pas en hauteur
	_defile = ScrollContainer.new()
	_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defile.follow_focus = true
	_defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pile.add_child(_defile)
	_contenu = VBoxContainer.new()
	_contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenu.add_theme_constant_override("separation", 0)
	_defile.add_child(_contenu)
	_contenu.add_child(g)
	_case_plein = _case(g, "Plein écran", Jeu.option("affichage", "plein_ecran"), func(v: bool) -> void:
		var f := _fenetre()
		if f != null:
			f.regler_plein_ecran(v))
	_premier = _case_plein
	# options graphiques (Graphismes) : taille de la fenêtre (sans effet en plein écran), vsync, limite d'images, portée des ombres
	_choix(g, "Taille de la fenêtre", Graphismes.noms_resolutions(), int(Jeu.option("affichage", "resolution")), func(v: int) -> void:
		Jeu.regler("affichage", "resolution", v)
		Graphismes.appliquer_resolution())
	_case(g, "Synchronisation verticale", Jeu.option("affichage", "vsync"), func(v: bool) -> void:
		Jeu.regler("affichage", "vsync", v)
		Graphismes.appliquer())
	_choix(g, "Limite d'images / s", Graphismes.noms_limites(), clampi(int(Jeu.option("affichage", "limite_ips")), 0, Graphismes.LIMITES_IPS.size() - 1), func(v: int) -> void:
		Jeu.regler("affichage", "limite_ips", v)
		Graphismes.appliquer())
	_choix(g, "Ombres", Graphismes.OMBRES, int(Jeu.option("affichage", "ombres")), func(v: int) -> void:
		Jeu.regler("affichage", "ombres", v)
		Graphismes.appliquer_ombres(get_tree(), v))
	_curseur(g, "Champ de vision", 60, 90, 1, Jeu.option("affichage", "champ_vision"), "%d°", func(v: float) -> void:
		Jeu.regler("affichage", "champ_vision", v)
		Jeu.appliquer_camera(joueur))
	_case(g, "Réduire les mouvements", Jeu.option("affichage", "reduire_mouvements"), func(v: bool) -> void:
		Jeu.regler("affichage", "reduire_mouvements", v))
	# détail des sorts : couche fine de la magie (pixels plus petits que le monde) ; Rétro = tout en 640x360 comme avant
	_choix(g, "Détail des sorts", ["Rétro", "Moyen", "Élevé"], int(Jeu.option("affichage", "detail_sorts")), func(v: int) -> void:
		Jeu.regler("affichage", "detail_sorts", v)
		GestionMagie.regler_detail(v))
	_curseur(g, "Volume général", 0, 100, 5, Jeu.option("son", "general") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("son", "general", v / 100.0))
	_curseur(g, "Musique", 0, 100, 5, Jeu.option("son", "musique") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("son", "musique", v / 100.0))
	_curseur(g, "Effets", 0, 100, 5, Jeu.option("son", "effets") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("son", "effets", v / 100.0))
	_curseur(g, "Sensibilité souris", 20, 300, 10, Jeu.option("commandes", "sensibilite") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("commandes", "sensibilite", v / 100.0))
	_case(g, "Inverser l'axe Y", Jeu.option("commandes", "inverser_y"), func(v: bool) -> void:
		Jeu.regler("commandes", "inverser_y", v))
	# sang et démembrement du combat (membres tranchés, plaies, jets, flaques) : complet par défaut ; réduit = moitié moins de
	# membres coupés, pas de coupe en deux, moins de sang
	_choix(g, "Sang et démembrement", ["Désactivé", "Réduit", "Complet"], int(Jeu.option("combat", "gore")), func(v: int) -> void:
		Jeu.regler("combat", "gore", v))
	# arrêt sur image / ralenti des coups qui portent : bref par défaut (l'arrêt appuyé se lisait comme des saccades)
	_choix(g, "Arrêt sur image", ["Désactivé", "Bref", "Appuyé"], int(Jeu.option("combat", "arret_image")), func(v: int) -> void:
		Jeu.regler("combat", "arret_image", v))
	# chiffres de dégâts flottants au-dessus des ennemis touchés (ChiffresDegats) : désactivés par défaut (esprit Skyrim)
	_case(g, "Chiffres de dégâts", Jeu.option("combat", "chiffres_degats"), func(v: bool) -> void:
		Jeu.regler("combat", "chiffres_degats", v))
	# bulles d'aide contextuelles (premier ennemi, sort, coffre, menu) : une seule fois chacune, désactivables ici
	_case(g, "Bulles d'aide", Jeu.option("jeu", "aides"), func(v: bool) -> void:
		Jeu.regler("jeu", "aides", v))
	# copie de secours de la sauvegarde dans un dossier choisi (Google Drive, OneDrive…)
	g.add_child(MenuStyle.etiquette("Copie de secours"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	var b_choisir := MenuStyle.bouton("Choisir…", _choisir_dossier)
	var b_couper := MenuStyle.bouton("Désactiver", func() -> void:
		Jeu.regler("sauvegarde", "dossier_secours", "")
		_maj_secours())
	h.add_child(b_choisir)
	h.add_child(b_couper)
	g.add_child(h)
	g.add_child(Control.new())
	_secours = MenuStyle.etiquette("", MenuStyle.GRIS)
	_secours.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # le chemin d'un dossier long passe à la ligne au lieu d'être coupé
	_secours.custom_minimum_size = Vector2(360, 0) * echelle
	_reglages_bas = _secours
	pile.add_child(_secours)
	_maj_secours()

	# caméra / corps (CameraCorps, MouvementsPassifs) : 100 % par défaut ; « Réduire les mouvements » les plafonne
	var gc := GridContainer.new()
	gc.columns = 3
	gc.add_theme_constant_override("h_separation", roundi(8 * echelle))
	gc.add_theme_constant_override("v_separation", roundi(1 * echelle))
	_premier_camera = _curseur(gc, "Balancement de l'arme", 0, 100, 5, Jeu.option("affichage", "balancement_arme") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("affichage", "balancement_arme", v / 100.0))
	_curseur(gc, "Mouvement de tête", 0, 100, 5, Jeu.option("affichage", "mouvement_tete") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("affichage", "mouvement_tete", v / 100.0))
	_curseur(gc, "Secousses", 0, 100, 5, Jeu.option("affichage", "secousses") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("affichage", "secousses", v / 100.0))
	_curseur(gc, "Caméra des coups", 0, 100, 5, Jeu.option("affichage", "camera_coups") * 100.0, "%d %%", func(v: float) -> void:
		Jeu.regler("affichage", "camera_coups", v / 100.0))   # la vue suit la lame (AccompagnementCoup) ; 0 = coupée
	var note := MenuStyle.etiquette("« Réduire les mouvements » les plafonne tous.", MenuStyle.GRIS)
	var pc := VBoxContainer.new()
	pc.add_child(gc)
	pc.add_child(note)
	pc.visible = false
	_camera = pc
	_contenu.add_child(pc)

	# touches : écran de remappage (remplace la grille tant qu'il est ouvert)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	var gt := GridContainer.new()
	gt.columns = 3
	gt.add_theme_constant_override("h_separation", roundi(8 * echelle))
	gt.add_theme_constant_override("v_separation", 0)
	gt.add_child(MenuStyle.etiquette("Commande", MenuStyle.GRIS))
	gt.add_child(MenuStyle.etiquette("Touche", MenuStyle.GRIS))
	gt.add_child(MenuStyle.etiquette("Autre touche", MenuStyle.GRIS))
	for a: Dictionary in Touches.ACTIONS:
		var id: String = a["id"]
		gt.add_child(MenuStyle.etiquette(a["nom"]))
		for rang in 2:
			var bt := MenuStyle.bouton("", func() -> void: _attendre(id, rang))
			bt.alignment = HORIZONTAL_ALIGNMENT_CENTER
			bt.custom_minimum_size = Vector2(70, 0) * echelle
			bt.tooltip_text = "Cliquer, puis appuyer sur la nouvelle touche (Échap annule%s)." % ("" if rang == 0 else ", Retour arrière efface")
			_boutons_touches[[id, rang]] = bt
			gt.add_child(bt)
	t.add_child(gt)
	_message_touches = MenuStyle.etiquette("", MenuStyle.RUNE)
	_message_touches.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_touches.custom_minimum_size = Vector2(360, 0) * echelle
	t.add_child(_message_touches)
	var fixes := MenuStyle.etiquette("Fixes : souris (clic gauche frapper, clic droit parer), 1 - 0 raccourcis, Échap pause, F11 plein écran.", MenuStyle.GRIS)
	fixes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fixes.custom_minimum_size = Vector2(360, 0) * echelle
	t.add_child(fixes)
	t.add_child(MenuStyle.bouton("Rétablir les touches d'origine", func() -> void:
		Touches.retablir()
		_maj_touches("Touches d'origine rétablies.")))
	t.visible = false
	_touches = t
	_contenu.add_child(t)
	_maj_touches()

	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", roundi(16 * echelle))
	pile.add_child(bas)
	var b_camera := MenuStyle.bouton("Caméra", func() -> void: _basculer_camera())
	var b_touches := MenuStyle.bouton("Touches", func() -> void: _basculer_touches())
	var b_retour := MenuStyle.bouton("Retour", func() -> void: fermer())
	bas.add_child(b_camera)
	bas.add_child(b_touches)
	bas.add_child(b_retour)
	if _fenetre() != null:
		_fenetre().plein_ecran_change.connect(func(v: bool) -> void: _case_plein.set_pressed_no_signal(v))
	get_viewport().size_changed.connect(func() -> void: _ajuster.call_deferred())
	_ajuster.call_deferred()

## Hauteur disponible (pixels du panneau) : hauteur_max, sinon la fenêtre (à l'échelle du parent) moins une marge.
func _hauteur_dispo() -> float:
	if hauteur_max > 0.0:
		return hauteur_max
	var e := get_global_transform().get_scale().y
	return get_viewport_rect().size.y / maxf(e, 0.01) - 8.0 * echelle

## Zone des réglages : sa hauteur suit le contenu affiché (grille, Caméra ou Touches), plafonnée pour que le panneau entier
## tienne dans _hauteur_dispo() ; au-delà, elle défile.
func _ajuster() -> void:
	if _defile == null:
		return
	var contenu := _contenu.get_combined_minimum_size().y
	# hauteur du reste du panneau (titre, copie de secours, boutons, marges), calculée enfant par enfant : le cache de taille
	# minimale du panneau n'est pas encore à jour quand on vient de changer celle de la zone qui défile
	var pile := _defile.get_parent() as BoxContainer
	var autres := get_theme_stylebox("panel").get_minimum_size().y if has_theme_stylebox("panel") else 0.0
	var n := 0
	for c in pile.get_children():
		if c is Control and (c as Control).visible:
			n += 1
			if c != _defile:
				autres += (c as Control).get_combined_minimum_size().y
	autres += pile.get_theme_constant("separation") * maxi(n - 1, 0)
	var dispo := _hauteur_dispo() - autres
	_defile.custom_minimum_size.y = minf(contenu, maxf(dispo, 60.0 * echelle))
	_defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if contenu > _defile.custom_minimum_size.y + 0.5 else ScrollContainer.SCROLL_MODE_DISABLED
	reset_size()

## Autoload Fenetre (scripts/fenetre.gd) cherché à l'exécution : son nom global n'existe pas encore quand un test
## (--script) compile le monde, qui précharge ce script via le menu pause.
func _fenetre() -> Node:
	return get_node_or_null("/root/Fenetre")

func ouvrir() -> void:
	visible = true
	_touches.visible = false
	_attente_touche = []
	_camera.visible = false
	_reglages.visible = true
	_reglages_bas.visible = true
	_maj_secours()
	_case_plein.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_defile.scroll_vertical = 0
	_ajuster()
	_premier.grab_focus.call_deferred()

func fermer() -> void:
	visible = false
	ferme.emit()

func _basculer_camera() -> void:
	_camera.visible = not _camera.visible
	_touches.visible = false
	_reglages.visible = not _camera.visible
	_reglages_bas.visible = _reglages.visible
	_defile.scroll_vertical = 0
	_ajuster()
	if _camera.visible:
		_premier_camera.grab_focus.call_deferred()
	else:
		_premier.grab_focus.call_deferred()

func _basculer_touches() -> void:
	_attente_touche = []
	_touches.visible = not _touches.visible
	_camera.visible = false
	_reglages.visible = not _touches.visible
	_reglages_bas.visible = _reglages.visible
	_defile.scroll_vertical = 0
	_ajuster()
	if _reglages.visible:
		_premier.grab_focus.call_deferred()
	else:
		_maj_touches()
		(_boutons_touches[["avant", 0]] as Button).grab_focus.call_deferred()

## Texte des boutons de touche (celle qu'on est en train de régler : « Appuyez… »).
func _maj_touches(message := "") -> void:
	for id_rang: Array in _boutons_touches:
		var bt: Button = _boutons_touches[id_rang]
		var k: int = int(Touches.touches_de(id_rang[0])[id_rang[1]])
		bt.text = "Appuyez…" if _attente_touche == id_rang else Touches.nom_touche(k)
	if _message_touches != null:
		_message_touches.text = message
	_ajuster.call_deferred()

func _attendre(id: String, rang: int) -> void:
	_attente_touche = [id, rang]
	_maj_touches("Appuyez sur la nouvelle touche (Échap : annuler).")

## Attribue une touche à la commande en attente (appelé par la saisie ; direct dans les tests). Renvoie la commande échangée ("" si aucune).
func attribuer(id: String, rang: int, k: int) -> String:
	var autre := Touches.lier(id, rang, k)
	_attente_touche = []
	var msg := "Touche enregistrée."
	if autre != "":
		for a: Dictionary in Touches.ACTIONS:
			if a["id"] == autre:
				msg = "%s utilisait déjà cette touche : elle a pris l'ancienne." % a["nom"]
	_maj_touches(msg)
	return autre

## Saisie de la nouvelle touche (avant tout le reste : Échap annule la saisie au lieu de fermer le panneau).
func _input(e: InputEvent) -> void:
	if _attente_touche.is_empty() or not visible:
		return
	if e is InputEventMouseButton and e.pressed:
		_attente_touche = []   # un clic ailleurs annule la saisie ; le clic sur un bouton la relance de lui-même
		_maj_touches()
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	get_viewport().set_input_as_handled()
	var k: int = (e as InputEventKey).physical_keycode
	if k == KEY_ESCAPE:
		_attente_touche = []
		_maj_touches()
	elif k == KEY_BACKSPACE or k == KEY_DELETE:
		attribuer(_attente_touche[0], _attente_touche[1], KEY_NONE)
	elif Touches.attribuable(k):
		attribuer(_attente_touche[0], _attente_touche[1], k)
	else:
		_maj_touches("Cette touche est réservée (menus, plein écran).")

func _maj_secours() -> void:
	var d: String = Jeu.dossier_secours()
	_secours.text = ("Copies dans : " + d) if d != "" else "Copie de secours désactivée (ex. un dossier Google Drive ou OneDrive)"
	_secours.tooltip_text = d

## Sélecteur de dossier natif de Windows (repli : sélecteur de Godot) ; le choix est enregistré dans options.cfg et
## une première copie est faite tout de suite s'il existe déjà une partie.
func _choisir_dossier() -> void:
	if _dialogue == null:
		_dialogue = FileDialog.new()
		_dialogue.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialogue.access = FileDialog.ACCESS_FILESYSTEM
		_dialogue.use_native_dialog = true
		_dialogue.title = "Dossier des copies de secours"
		_dialogue.process_mode = Node.PROCESS_MODE_ALWAYS
		_dialogue.dir_selected.connect(func(d: String) -> void:
			Jeu.regler("sauvegarde", "dossier_secours", d)
			var f: String = load("res://scripts/monde.gd").fichier_sauvegarde()
			if FileAccess.file_exists(f):
				Jeu.copie_secours(f)
			_maj_secours()
			if Jeu.avertissement_secours != "":
				_secours.text = "Copie impossible : " + Jeu.avertissement_secours)
		add_child(_dialogue)
	var actuel: String = Jeu.dossier_secours()
	if actuel != "":
		_dialogue.current_dir = actuel
	_dialogue.popup_centered(Vector2i(560, 320))

func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("ui_cancel") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE)):
		get_viewport().set_input_as_handled()
		if _touches.visible:
			_basculer_touches()
		elif _camera.visible:
			_basculer_camera()
		else:
			fermer()

func _case(g: GridContainer, texte: String, valeur: bool, quand: Callable) -> CheckButton:
	g.add_child(MenuStyle.etiquette(texte))
	var c := CheckButton.new()
	c.button_pressed = valeur
	c.focus_mode = Control.FOCUS_ALL
	c.mouse_entered.connect(func() -> void: c.grab_focus())
	c.toggled.connect(func(v: bool) -> void: quand.call(v))
	g.add_child(c)
	g.add_child(Control.new())
	return c

## Liste déroulante (valeur = indice de l'élément).
func _choix(g: GridContainer, texte: String, elements: Array, valeur: int, quand: Callable) -> OptionButton:
	g.add_child(MenuStyle.etiquette(texte))
	var o := OptionButton.new()
	for e: String in elements:
		o.add_item(e)
	o.select(clampi(valeur, 0, elements.size() - 1))
	o.focus_mode = Control.FOCUS_ALL
	o.mouse_entered.connect(func() -> void: o.grab_focus())
	o.item_selected.connect(func(i: int) -> void: quand.call(i))
	g.add_child(o)
	g.add_child(Control.new())
	return o

func _curseur(g: GridContainer, texte: String, mini: float, maxi: float, pas: float, valeur: float, format: String, quand: Callable) -> HSlider:
	g.add_child(MenuStyle.etiquette(texte))
	var s := HSlider.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = pas
	s.value = valeur
	s.custom_minimum_size = Vector2(140, 14) * echelle
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.mouse_entered.connect(func() -> void: s.grab_focus())
	var l := MenuStyle.etiquette(format % roundi(valeur), MenuStyle.RUNE)
	l.custom_minimum_size = Vector2(44, 0) * echelle
	s.value_changed.connect(func(v: float) -> void:
		l.text = format % roundi(v)
		quand.call(v))
	g.add_child(s)
	g.add_child(l)
	return s
