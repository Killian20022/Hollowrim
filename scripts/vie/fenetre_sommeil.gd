class_name FenetreSommeil
extends CanvasLayer
## Fenêtre « Dormir » / « Attendre » (lot sommeil) : page de vélin dans un cadre de cuir à filet d'or, comme le menu pause
## (StyleParchemin : encre brune, rubrique vermillon, titre gothique). Choix de 1 à 24 h, heure du réveil affichée.
##   gauche / droite (Q / D, flèches, molette) : -1 / +1 h ; haut / bas : +-4 h ; Entrée, Espace, E : valider ; Échap, clic droit : annuler.
## Jeu en PAUSE tant qu'elle est ouverte. Ouverte par Sommeil.demander().

signal choisi(heures: int, mode: String, lit: Lit)
signal annule

var ouvert := false
var mode := "dormir"
var heures := 8
var heure := 12.0
var lit: Lit = null
var _racine: Control
var _titre: Label
var _sous: Label
var _valeur: Label
var _reveil: Label
var _curseur: HSlider
var _ok: Button
var _souris := Input.MOUSE_MODE_CAPTURED
var _boutons: Array = []

func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	_racine = Control.new()
	_racine.theme = StyleParchemin.theme_encre()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.visible = false
	add_child(_racine)
	var voile := ColorRect.new()
	voile.color = Color(MenuStyle.FOND, 0.45)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(centre)
	var page := StyleParchemin.page()
	var cadre: PanelContainer = page[0]
	cadre.custom_minimum_size = Vector2(250, 0)
	centre.add_child(cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	(page[1] as PanelContainer).add_child(v)
	_titre = MenuStyle.etiquette("Dormir", Parchemin.RUBRIQUE)
	_titre.add_theme_font_override("font", MenuStyle.police_gothique(true))
	_titre.add_theme_font_size_override("font_size", Parchemin.TITRE)
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_titre)
	_sous = MenuStyle.etiquette("", Parchemin.PALE)
	_sous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sous)
	var filet := ColorRect.new()
	filet.color = Color(Parchemin.OR_TERNI, 0.8)
	filet.custom_minimum_size = Vector2(0, 1)
	v.add_child(filet)
	var q := MenuStyle.etiquette("Combien de temps ?", Parchemin.ENCRE)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(q)
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", 6)
	v.add_child(ligne)
	var moins := MenuStyle.bouton("<", func() -> void: regler(heures - 1))
	var plus := MenuStyle.bouton(">", func() -> void: regler(heures + 1))
	_valeur = MenuStyle.etiquette("8 heures", Parchemin.RUBRIQUE)
	_valeur.add_theme_font_override("font", MenuStyle.police_gothique(true))
	_valeur.add_theme_font_size_override("font_size", Parchemin.TITRE)
	_valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_valeur.custom_minimum_size = Vector2(120, 0)
	ligne.add_child(moins)
	ligne.add_child(_valeur)
	ligne.add_child(plus)
	_curseur = HSlider.new()
	_curseur.min_value = 1
	_curseur.max_value = 24
	_curseur.step = 1
	_curseur.value = 8
	_curseur.custom_minimum_size = Vector2(200, 12)
	_curseur.focus_mode = Control.FOCUS_NONE
	_curseur.value_changed.connect(func(x: float) -> void: regler(int(x)))
	v.add_child(_curseur)
	_reveil = MenuStyle.etiquette("", Parchemin.PALE)
	_reveil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_reveil)
	var filet2 := ColorRect.new()
	filet2.color = Color(Parchemin.OR_TERNI, 0.5)
	filet2.custom_minimum_size = Vector2(0, 1)
	v.add_child(filet2)
	_ok = MenuStyle.bouton("Dormir", valider)
	var non := MenuStyle.bouton("Annuler", fermer)
	_boutons = [_ok, non]
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 14)
	bas.add_child(_ok)
	bas.add_child(non)
	v.add_child(bas)
	MenuStyle.chainer(_boutons)

func ouvrir(mode_: String, sous_titre: String, heure_: float, defaut: int, lit_: Lit = null) -> void:
	if ouvert:
		return
	mode = mode_
	heure = heure_
	lit = lit_
	_titre.text = "Dormir" if mode == "dormir" else "Attendre"
	_ok.text = "Dormir" if mode == "dormir" else "Attendre"
	_sous.text = sous_titre
	ouvert = true
	_racine.visible = true
	regler(defaut)
	get_tree().paused = true
	_souris = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ok.grab_focus.call_deferred()
	Sons.jouer(self, ["cloth1"], -14.0)

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_racine.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	annule.emit()

func valider() -> void:
	if not ouvert:
		return
	ouvert = false
	_racine.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	choisi.emit(heures, mode, lit)

func regler(h: int) -> void:
	heures = clampi(h, 1, 24)
	if int(_curseur.value) != heures:
		_curseur.set_value_no_signal(heures)
	_valeur.text = "1 heure" if heures == 1 else "%d heures" % heures
	var fin := fposmod(heure + heures, 24.0)
	var jour := "" if heure + heures < 24.0 else " (demain)"
	_reveil.text = "%s vers %d h %02d%s" % ["Réveil" if mode == "dormir" else "Jusqu'à", int(fin), int(fmod(fin, 1.0) * 60.0), jour]

func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	if e is InputEventMouseButton and e.pressed:
		var b := (e as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			regler(heures + 1)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			regler(heures - 1)
		elif b == MOUSE_BUTTON_RIGHT:
			fermer()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not (e is InputEventKey) or not e.pressed:
		return
	var k := (e as InputEventKey).physical_keycode
	match k:
		KEY_LEFT, KEY_A:
			regler(heures - 1)
		KEY_RIGHT, KEY_D:
			regler(heures + 1)
		KEY_UP, KEY_W:
			regler(heures + 4)
		KEY_DOWN, KEY_S:
			regler(heures - 4)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			if not e.echo:
				if _boutons[1].has_focus():
					fermer()
				else:
					valider()
		KEY_ESCAPE:
			fermer()
		KEY_T:
			if not e.echo and mode == "attendre":
				fermer()
		_:
			return
	get_viewport().set_input_as_handled()
