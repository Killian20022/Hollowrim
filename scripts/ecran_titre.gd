extends Control
## Écran titre (scène principale) : fond (vue du monde précalculée, assets/ui/titre_fond.png), neige qui tombe,
## titre, menu Nouvelle partie / Continuer / Options / Crédits / Quitter (souris, clavier, manette).
## Le monde (Jeu.SCENE_JEU) est chargé dans CE processus une seule fois : revenir au titre ou recommencer depuis une partie
## passe par Jeu.relancer() (relance du processus, comme F9).
## Mode outil (tests, captures, arguments d'agents : Jeu.mode_outil) : on passe tout droit au monde, sans rien afficher.
## Test des menus : --test-titre=nouvelle|continuer|captures:<dossier> (outils/test_menus.sh).

const FOND := preload("res://assets/ui/titre_fond.png")
const OPTIONS := preload("res://scripts/menu_options.gd")

## Auteur affiché dans les crédits (à changer ici).
const AUTEUR := "lopezk19"

var _menu: VBoxContainer
var _boutons: Array = []
var _b_continuer: Button
var _b_restaurer: Button
var _options: PanelContainer
var _credits: PanelContainer
var _confirmation: PanelContainer
var _chargement: Label
var _fond: TextureRect
var _t := 0.0
var _demarre := false

func _ready() -> void:
	if Jeu.mode_outil():
		get_tree().change_scene_to_file.call_deferred(Jeu.SCENE_JEU)
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = MenuStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_construire()
	# F9 ou « Charger » d'une partie précédente : relancé pour charger aussitôt
	if Jeu.lire_relance() == "continuer" and Jeu.sauvegarde_valide():
		_lancer(false)
		return
	_menu_principal()
	var test := Jeu.test_titre()
	if test != "":
		_test.call_deferred(test)

func _construire() -> void:
	var noir := ColorRect.new()
	noir.color = MenuStyle.FOND
	noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(noir)
	_fond = TextureRect.new()
	_fond.texture = FOND
	_fond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fond)
	# voile sombre à gauche, derrière le menu (lisibilité)
	var voile := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(MenuStyle.FOND, 0.82))
	grad.set_color(1, Color(MenuStyle.FOND, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 64
	gt.height = 4
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(1.0, 0.0)
	voile.texture = gt
	voile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	voile.stretch_mode = TextureRect.STRETCH_SCALE
	voile.anchor_bottom = 1.0
	voile.offset_right = 330
	add_child(voile)
	_neige()

	var titre := MenuStyle.etiquette(Jeu.nom().to_upper(), MenuStyle.PARCHEMIN, 3)
	titre.position = Vector2(40, 34)
	add_child(titre)
	var sous := MenuStyle.etiquette("Démo %s  ·  tranche verticale" % Jeu.version(), MenuStyle.RUNE)
	sous.position = Vector2(44, 86)
	add_child(sous)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(36, 140)
	_menu.add_theme_constant_override("separation", 2)
	add_child(_menu)
	_boutons = [
		MenuStyle.bouton("Nouvelle partie", _nouvelle),
		MenuStyle.bouton("Continuer", func() -> void: _lancer(false)),
		MenuStyle.bouton("Restaurer la copie de secours", _restaurer),
		MenuStyle.bouton("Options", _ouvrir_options),
		MenuStyle.bouton("Crédits", _ouvrir_credits),
		MenuStyle.bouton("Quitter", func() -> void: get_tree().quit()),
	]
	_b_continuer = _boutons[1]
	_b_restaurer = _boutons[2]
	for b: Button in _boutons:
		b.custom_minimum_size = Vector2(170, 0)
		_menu.add_child(b)

	var pied := MenuStyle.etiquette("v%s   Souris, clavier ou manette   F11 : plein écran" % Jeu.version(), MenuStyle.GRIS)
	pied.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pied.position = Vector2(8, 360 - 22)
	pied.anchor_top = 1.0
	pied.anchor_bottom = 1.0
	pied.offset_top = -20
	pied.offset_left = 8
	add_child(pied)

	_options = PanelContainer.new()
	_options.set_script(OPTIONS)
	_options.visible = false
	_options.ferme.connect(_menu_principal)
	add_child(_options)
	_centrer(_options)

	_credits = _panneau_credits()
	add_child(_credits)
	_centrer(_credits)
	_confirmation = _panneau_confirmation()
	add_child(_confirmation)
	_centrer(_confirmation)

	_chargement = MenuStyle.etiquette("Chargement…", MenuStyle.PARCHEMIN, 2)
	_chargement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chargement.visible = false
	add_child(_chargement)
	_centrer(_chargement)

## Centre un panneau déjà ajouté : il passe dans un CenterContainer plein écran (suit sa taille quand son contenu change).
func _centrer(c: Control) -> void:
	var parent := c.get_parent()
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(centre)
	parent.move_child(centre, c.get_index())
	c.reparent(centre, false)

## Flocons 2D (même teinte que la neige du monde), légers : 120 particules CPU.
func _neige() -> void:
	var p := CPUParticles2D.new()
	p.amount = 120
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(380, 4)
	p.position = Vector2(320, -8)
	p.direction = Vector2(0.15, 1.0)
	p.spread = 12.0
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 34.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.85, 0.9, 1.0, 0.75)
	add_child(p)

func _process(dt: float) -> void:
	_t += dt
	if _fond != null:
		# très lente respiration du fond (2 px), au pixel près
		_fond.position = Vector2(roundf(sin(_t * 0.07) * 2.0), 0.0)

func _menu_principal() -> void:
	_options.visible = false
	_credits.visible = false
	_confirmation.visible = false
	_menu.visible = true
	_b_continuer.disabled = not Jeu.sauvegarde_valide()
	_b_continuer.focus_mode = Control.FOCUS_NONE if _b_continuer.disabled else Control.FOCUS_ALL
	# sauvegarde locale absente ou illisible alors qu'une copie de secours existe : on propose de la restaurer
	_b_restaurer.visible = _b_continuer.disabled and not Jeu.copies_secours().is_empty()
	MenuStyle.chainer(_boutons)
	(_boutons[0] if _b_continuer.disabled else _b_continuer).grab_focus.call_deferred()

func _restaurer() -> void:
	if Jeu.restaurer_secours():
		_menu_principal()
	else:
		_b_restaurer.text = "Aucune copie lisible"
		_b_restaurer.disabled = true

func _nouvelle() -> void:
	if Jeu.sauvegarde_valide():
		_menu.visible = false
		_confirmation.visible = true
		_confirmation.get_meta("non").grab_focus.call_deferred()
	else:
		_lancer(true)

func _ouvrir_options() -> void:
	_menu.visible = false
	_options.ouvrir()

func _ouvrir_credits() -> void:
	_menu.visible = false
	_credits.visible = true
	_credits.get_meta("retour").grab_focus.call_deferred()

## Charge le monde (une seule fois par processus). `nouvelle` : ne lit pas la sauvegarde.
func _lancer(nouvelle: bool) -> void:
	if _demarre:
		return
	_demarre = true
	Jeu.nouvelle_partie = nouvelle
	for c in [_menu, _options, _credits, _confirmation]:
		c.visible = false
	_chargement.visible = true
	# deux images pour que « Chargement… » soit affiché avant le gros chargement (bloquant)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(Jeu.SCENE_JEU)

func _unhandled_input(e: InputEvent) -> void:
	if (_credits.visible or _confirmation.visible) and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_menu_principal()

func _panneau_confirmation() -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var l := MenuStyle.etiquette("Une partie existe déjà.\nLa remplacer par une nouvelle ?")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var oui := MenuStyle.bouton("Oui, recommencer", func() -> void: _lancer(true))
	var non := MenuStyle.bouton("Non", _menu_principal)
	h.add_child(oui)
	h.add_child(non)
	p.set_meta("non", non)
	return p

func _panneau_credits() -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	p.custom_minimum_size = Vector2(420, 260)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var t := MenuStyle.etiquette("Crédits", MenuStyle.OR)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(defil)
	var texte := MenuStyle.etiquette(credits_texte())
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.custom_minimum_size = Vector2(380, 0)
	texte.add_theme_constant_override("line_spacing", -3)
	defil.add_child(texte)
	var retour := MenuStyle.bouton("Retour", _menu_principal)
	retour.alignment = HORIZONTAL_ALIGNMENT_CENTER
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(retour)
	p.set_meta("retour", retour)
	# défilement au clavier / à la manette pendant que « Retour » a le focus
	retour.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_down"):
			defil.scroll_vertical += 24
			retour.accept_event()
		elif e.is_action_pressed("ui_up"):
			defil.scroll_vertical -= 24
			retour.accept_event())
	return p

static func credits_texte() -> String:
	return "\n".join([
		"%s — démo %s" % [Jeu.nom(), Jeu.version()],
		"Conception, code et graphismes : %s" % AUTEUR,
		"Moteur : Godot Engine (godotengine.org), licence MIT.",
		"",
		"Ressources externes, toutes en CC0 (domaine public) :",
		"· Personnages et animations : Quaternius (quaternius.com), Kay Lousberg / KayKit (kaylousberg.com)",
		"· Police pixel : Kenney Fonts (kenney.nl), adaptée aux accents",
		"· Bruitages : Kenney (Impact Sounds, RPG Audio), artisticdude (RPG Sound Pack), rubberduck (80 CC0 creature SFX), SketchMan3, zeroisnotnull — OpenGameArt",
		"· Musiques : congusbongus (Cathedral in the forest, Ancient caverns), Kaiser (Frost in the Northern Winter), RandomMind (Medieval: Battle, The Old Tower Inn) — OpenGameArt",
		"",
		"Le reste (terrain, végétation, bâtiments, crypte, grotte, textures, shaders PS1) est généré par le code du jeu.",
		"Détail complet : CREDITS.txt, livré avec le jeu.",
		"",
		"Merci d'avoir joué !",
	])

# --- test automatique (outils/test_menus.sh) ---------------------------------------------

func _test(etape: String) -> void:
	await get_tree().create_timer(1.0).timeout
	print("TEST MENUS : titre affiché, continuer %s" % ("actif" if not _b_continuer.disabled else "grisé"))
	if etape.begins_with("captures:"):
		var dossier := etape.substr(9)
		await _capture(dossier.path_join("titre.png"))
		_ouvrir_options()
		await get_tree().create_timer(0.5).timeout
		await _capture(dossier.path_join("options_titre.png"))
		_options.fermer()
		_ouvrir_credits()
		await get_tree().create_timer(0.5).timeout
		await _capture(dossier.path_join("credits.png"))
		_menu_principal()
		get_tree().quit()
	elif etape == "nouvelle":
		_lancer(true)
	elif etape == "relance":
		# 1er passage : on entre en partie (le menu pause demandera « Retour au titre ») ; 2e passage (processus relancé) : verdict
		if FileAccess.file_exists("user://test_relance.tmp"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_relance.tmp"))
			print("TEST MENUS : relance OK (écran titre revenu dans un nouveau processus)")
			FileAccess.open("user://test_relance.ok", FileAccess.WRITE).store_string("relance OK")   # lu par test_menus.sh
			get_tree().quit()
		else:
			_lancer(false)
	elif etape == "continuer":
		if _b_continuer.disabled:
			print("TEST MENUS : ÉCHEC (Continuer grisé alors qu'une sauvegarde est attendue)")
			get_tree().quit(1)
			return
		_b_continuer.pressed.emit()
	elif etape == "restaurer":
		# sauvegarde locale rendue illisible : « Restaurer » doit apparaître, remettre la copie, puis « Continuer »
		var f: String = load("res://scripts/monde.gd").fichier_sauvegarde()
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_string("{ corrompue")
		fa.close()
		_menu_principal()
		print("TEST MENUS : sauvegarde corrompue, continuer %s, restaurer %s" % ["grisé" if _b_continuer.disabled else "ACTIF", "visible" if _b_restaurer.visible else "ABSENT"])
		if not _b_restaurer.visible or not _b_continuer.disabled:
			print("TEST MENUS : ÉCHEC (restauration non proposée)")
			get_tree().quit(1)
			return
		_b_restaurer.pressed.emit()
		print("TEST MENUS : restaurer %s" % ("OK" if not _b_continuer.disabled else "ÉCHEC"))
		if _b_continuer.disabled:
			get_tree().quit(1)
			return
		_b_continuer.pressed.emit()

func _capture(chemin: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	img.save_png(chemin)
	print("TEST MENUS : capture ", chemin)
