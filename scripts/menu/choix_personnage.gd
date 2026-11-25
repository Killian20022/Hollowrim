class_name ChoixPersonnage
extends PanelContainer
## CHOIX DU PERSONNAGE au début d'une NOUVELLE partie (écran titre, chantier joueur_base) : homme ou femme (JoueurBase), aperçu 3D qui
## tourne (SubViewport à monde propre : sol de pierre, lumière de torche chaude + appoint froid, rendu PS1 des personnages), valider.
## Style des panneaux du titre (thème MenuStyle.theme_titre() hérité de l'écran titre).
##   signal valide(sexe)  /  signal retour
## Clavier / manette : Gauche / Droite change de personnage, Entrée valide (focus sur « Commencer »), Échap revient au menu.

signal valide(sexe: String)
signal retour
signal son(nom: String)

const TAILLE := Vector2i(300, 420)     # pixels du rendu (affiché x1,6 en plus-proche-voisin : gros pixels comme le jeu)
const TOUR := 0.45                     # rad / s

var sexe := JoueurBase.DEFAUT
var _vue: SubViewport
var _ecran: TextureRect
var _pivot: Node3D
var _modele: Node3D
var _b_homme: Button
var _b_femme: Button
var _b_go: Button
var _nom: Label

func _ready() -> void:
	name = "PanneauChoixPersonnage"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var t := Label.new()
	t.text = "VOTRE PERSONNAGE"
	t.add_theme_font_override("font", MenuStyle.police_capitales(600))
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", MenuStyle.GIVRE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 34)
	v.add_child(h)
	# aperçu
	_vue = SubViewport.new()
	_vue.size = TAILLE
	_vue.own_world_3d = true
	_vue.transparent_bg = false
	_vue.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vue.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vue)
	_studio()
	_ecran = TextureRect.new()
	_ecran.name = "Apercu"
	_ecran.texture = _vue.get_texture()
	_ecran.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ecran.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ecran.stretch_mode = TextureRect.STRETCH_SCALE
	_ecran.custom_minimum_size = Vector2(TAILLE) * 1.25
	h.add_child(_ecran)
	# colonne de droite : choix + valider
	var c := VBoxContainer.new()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 18)
	c.custom_minimum_size = Vector2(320, 0)
	h.add_child(c)
	_nom = Label.new()
	_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nom.custom_minimum_size = Vector2(320, 0)
	c.add_child(_nom)
	_b_homme = _bouton("Homme", func() -> void: choisir("homme"), "BoutonHomme")
	_b_femme = _bouton("Femme", func() -> void: choisir("femme"), "BoutonFemme")
	c.add_child(_b_homme)
	c.add_child(_b_femme)
	var sep := HSeparator.new()
	c.add_child(sep)
	_b_go = _bouton("Commencer", func() -> void: valide.emit(sexe), "BoutonCommencer")
	c.add_child(_b_go)
	c.add_child(_bouton("Retour", func() -> void: retour.emit(), "BoutonRetour"))
	_b_homme.toggle_mode = true
	_b_femme.toggle_mode = true
	choisir(sexe, false)

func _bouton(texte: String, action: Callable, nom: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.name = nom
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: son.emit("survol"))
	b.pressed.connect(func() -> void:
		son.emit("validation")
		action.call())
	return b

## Ouvre le panneau (homme par défaut, ou le dernier choix) ; focus sur « Commencer ».
func ouvrir() -> void:
	choisir(sexe, false)
	_b_go.grab_focus.call_deferred()

func choisir(s: String, avec_son := true) -> void:
	s = JoueurBase.valide(s)
	var change := s != sexe or _modele == null
	sexe = s
	_b_homme.set_pressed_no_signal(s == "homme")
	_b_femme.set_pressed_no_signal(s == "femme")
	_nom.text = "Un homme du Nord" if s == "homme" else "Une femme du Nord"
	if change:
		if _modele != null:
			_modele.queue_free()
		_modele = JoueurBase.creer(s)
		_modele.rotation.y = 0.0
		_pivot.add_child(_modele)
		var ap := _modele.get_node("Animations") as AnimationPlayer
		ap.play("Idle")
		if avec_son:
			son.emit("survol")

func _studio() -> void:
	var monde := Node3D.new()
	_vue.add_child(monde)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.46, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.08, 0.12)
	env.fog_density = 0.035
	var we := WorldEnvironment.new()
	we.environment = env
	monde.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 1.05, 4.3)
	cam.look_at_from_position(cam.position, Vector3(0, 0.9, 0), Vector3.UP)
	cam.current = true
	monde.add_child(cam)
	var cle := DirectionalLight3D.new()       # lune froide de 3/4 haut
	cle.light_color = Color(0.70, 0.78, 1.0)
	cle.light_energy = 0.75
	cle.rotation = Vector3(deg_to_rad(-40), deg_to_rad(35), 0)
	monde.add_child(cle)
	var feu := OmniLight3D.new()              # torche chaude, devant à gauche
	feu.light_color = Color(1.0, 0.62, 0.32)
	feu.light_energy = 2.2
	feu.omni_range = 5.0
	feu.position = Vector3(-1.3, 1.5, 1.6)
	monde.add_child(feu)
	var sol := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = 1.1
	d.bottom_radius = 1.2
	d.height = 0.08
	d.radial_segments = 10
	sol.mesh = d
	sol.position.y = -0.04
	sol.material_override = Palette.materiau(Palette.tex("roche", Palette.ROCHE, 4, 0.4), Vector2(3, 3))
	monde.add_child(sol)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	monde.add_child(_pivot)

func _process(dt: float) -> void:
	if _pivot != null and is_visible_in_tree():
		_pivot.rotation.y = wrapf(_pivot.rotation.y + TOUR * dt, 0.0, TAU)

func _unhandled_input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
		var f := get_viewport().gui_get_focus_owner()
		if f == _b_homme or f == _b_femme or f == _b_go:
			get_viewport().set_input_as_handled()
			choisir("femme" if sexe == "homme" else "homme")
	elif e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		retour.emit()
