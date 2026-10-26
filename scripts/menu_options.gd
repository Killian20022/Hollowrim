extends PanelContainer
## Panneau Options (écran titre et menu pause) : affichage, son, commandes, rappel des touches.
## Chaque changement est appliqué et enregistré aussitôt dans user://options.cfg (Jeu.regler).
## `joueur` (facultatif, en partie) : reçoit le nouveau champ de vision tout de suite.

signal ferme

var joueur: Node = null
var _premier: Control
var _touches: Control
var _reglages: Control
var _case_plein: CheckButton

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
	theme = MenuStyle.theme()
	custom_minimum_size = Vector2(380, 0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", 2)
	add_child(pile)
	var titre := MenuStyle.etiquette("Options", MenuStyle.OR)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(titre)

	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 1)
	_reglages = g
	pile.add_child(g)
	_case_plein = _case(g, "Plein écran", Jeu.option("affichage", "plein_ecran"), func(v: bool) -> void:
		Fenetre.regler_plein_ecran(v))
	_premier = _case_plein
	_curseur(g, "Champ de vision", 60, 90, 1, Jeu.option("affichage", "champ_vision"), "%d°", func(v: float) -> void:
		Jeu.regler("affichage", "champ_vision", v)
		Jeu.appliquer_camera(joueur))
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

	# rappel des touches (remplace la grille tant qu'il est ouvert)
	var t := GridContainer.new()
	t.columns = 2
	t.add_theme_constant_override("h_separation", 12)
	t.add_theme_constant_override("v_separation", -2)
	for l: Array in TOUCHES:
		t.add_child(MenuStyle.etiquette(l[0], MenuStyle.OR))
		t.add_child(MenuStyle.etiquette(l[1]))
	t.visible = false
	_touches = t
	pile.add_child(t)

	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 16)
	pile.add_child(bas)
	var b_touches := MenuStyle.bouton("Touches", func() -> void: _basculer_touches())
	var b_retour := MenuStyle.bouton("Retour", func() -> void: fermer())
	bas.add_child(b_touches)
	bas.add_child(b_retour)
	Fenetre.plein_ecran_change.connect(func(v: bool) -> void: _case_plein.set_pressed_no_signal(v))

func ouvrir() -> void:
	visible = true
	_touches.visible = false
	_reglages.visible = true
	_case_plein.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_premier.grab_focus.call_deferred()

func fermer() -> void:
	visible = false
	ferme.emit()

func _basculer_touches() -> void:
	_touches.visible = not _touches.visible
	_reglages.visible = not _touches.visible
	if _reglages.visible:
		_premier.grab_focus.call_deferred()

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
	s.custom_minimum_size = Vector2(140, 14)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.mouse_entered.connect(func() -> void: s.grab_focus())
	var l := MenuStyle.etiquette(format % roundi(valeur), MenuStyle.RUNE)
	l.custom_minimum_size = Vector2(44, 0)
	s.value_changed.connect(func(v: float) -> void:
		l.text = format % roundi(v)
		quand.call(v))
	g.add_child(s)
	g.add_child(l)
	return s
