extends PanelContainer
## Panneau Options (écran titre et menu pause) : affichage, son, commandes, rappel des touches.
## Chaque changement est appliqué et enregistré aussitôt dans user://options.cfg (Jeu.regler).
## `joueur` (facultatif, en partie) : reçoit le nouveau champ de vision tout de suite.

signal ferme

var joueur: Node = null
## Écran titre (menu principal en haute définition) : thème runique (MenuStyle.theme_titre) et tailles fixes multipliées par
## `echelle` (pixels de l'image de référence au lieu de l'écran logique 640x360). Par défaut (menu pause) : thème pixel, ×1.
var theme_impose: Theme = null
var echelle := 1.0
var _premier: Control
var _touches: Control
var _reglages: Control
var _case_plein: CheckButton
var _secours: Label
var _reglages_bas: Control
var _dialogue: FileDialog

const TOUCHES := [
	["ZQSD / flèches", "se déplacer"],
	["Souris", "regarder"],
	["Maj", "courir"],
	["Espace", "sauter"],
	["Clic gauche", "frapper (maintenir : coup puissant)"],
	["Clic droit", "parer"],
	["E", "parler, ouvrir, ramasser"],
	["Tab", "inventaire et quêtes"],
	["T", "torche"],
	["V", "vue 1re / 3e personne"],
	["F5 / F9", "sauvegarder / charger"],
	["F11, Alt+Entrée", "plein écran"],
	["Échap", "menu pause"],
]

func _ready() -> void:
	theme = theme_impose if theme_impose != null else MenuStyle.theme()
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
	pile.add_child(g)
	_case_plein = _case(g, "Plein écran", Jeu.option("affichage", "plein_ecran"), func(v: bool) -> void:
		var f := _fenetre()
		if f != null:
			f.regler_plein_ecran(v))
	_premier = _case_plein
	_curseur(g, "Champ de vision", 60, 90, 1, Jeu.option("affichage", "champ_vision"), "%d°", func(v: float) -> void:
		Jeu.regler("affichage", "champ_vision", v)
		Jeu.appliquer_camera(joueur))
	_case(g, "Réduire les mouvements", Jeu.option("affichage", "reduire_mouvements"), func(v: bool) -> void:
		Jeu.regler("affichage", "reduire_mouvements", v))
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
	_secours.clip_text = true
	_secours.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_secours.custom_minimum_size = Vector2(360, 0) * echelle
	_reglages_bas = _secours
	pile.add_child(_secours)
	_maj_secours()

	# rappel des touches (remplace la grille tant qu'il est ouvert)
	var t := GridContainer.new()
	t.columns = 2
	t.add_theme_constant_override("h_separation", roundi(12 * echelle))
	t.add_theme_constant_override("v_separation", -2 if theme_impose == null else 0)
	for l: Array in TOUCHES:
		t.add_child(MenuStyle.etiquette(l[0], MenuStyle.OR if theme_impose == null else MenuStyle.LUEUR.lerp(MenuStyle.GIVRE, 0.35)))
		t.add_child(MenuStyle.etiquette(l[1]))
	t.visible = false
	_touches = t
	pile.add_child(t)

	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", roundi(16 * echelle))
	pile.add_child(bas)
	var b_touches := MenuStyle.bouton("Touches", func() -> void: _basculer_touches())
	var b_retour := MenuStyle.bouton("Retour", func() -> void: fermer())
	bas.add_child(b_touches)
	bas.add_child(b_retour)
	if _fenetre() != null:
		_fenetre().plein_ecran_change.connect(func(v: bool) -> void: _case_plein.set_pressed_no_signal(v))

## Autoload Fenetre (scripts/fenetre.gd) cherché à l'exécution : son nom global n'existe pas encore quand un test
## (--script) compile le monde, qui précharge ce script via le menu pause.
func _fenetre() -> Node:
	return get_node_or_null("/root/Fenetre")

func ouvrir() -> void:
	visible = true
	_touches.visible = false
	_reglages.visible = true
	_reglages_bas.visible = true
	_maj_secours()
	_case_plein.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_premier.grab_focus.call_deferred()

func fermer() -> void:
	visible = false
	ferme.emit()

func _basculer_touches() -> void:
	_touches.visible = not _touches.visible
	_reglages.visible = not _touches.visible
	_reglages_bas.visible = _reglages.visible
	if _reglages.visible:
		_premier.grab_focus.call_deferred()

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
