extends Control
## Écran titre (scène principale) : menu principal « cinématographique » aux proportions de ref_menu/reference.png (1672x941).
## - Décor : res://scenes/menu_decor/menu_decor.tscn s'il existe (plans animés : neige, flammes, eau, brume ; API dans
##   scenes/menu_decor/LISEZMOI.md), sinon l'image de référence fixe (assets/ui/titre_reference.jpg) avec une neige légère.
## - Logo : le logo PEINT de l'image (le plus fidèle et le plus net) ; apparition « sortie de la brume » au lancement
##   (shaders/menu_ui/logo_apparition.gdshader) et pulsation du cristal toutes les 6 à 8 s.
## - Boutons dessinés à la main (BoutonRunique) : Continuer, Nouvelle partie, Charger, Options, Quitter ; souris, clavier, manette.
## - Panneaux au style du menu : Charger (partie en cours + copies de secours), Options (menu_options.gd, thème runique),
##   Crédits (lien discret en bas), confirmation de la nouvelle partie.
## - Nouvelle partie / Continuer : son, musique baissée, fondu au noir, écran de chargement animé (EcranChargement).
## Tout est placé en pixels de l'image de référence dans `_plan`, mis à l'échelle de la fenêtre : la fenêtre passe ici en résolution
## native (content_scale DISABLED) et l'écran de chargement rétablit l'échelle du jeu (640x360 agrandi) avant de montrer le monde.
## Le monde (Jeu.SCENE_JEU) n'est chargé qu'une fois par processus : revenir au titre ou recommencer passe par Jeu.relancer().
## Mode outil (tests, captures, arguments d'agents : Jeu.mode_outil) : on passe tout droit au monde, sans rien afficher.
## Test des menus : --test-titre=nouvelle|continuer|restaurer|relance|clavier|captures:<dossier>|options:<dossier> (outils/test_menus.sh).

const OPTIONS := preload("res://scripts/menu_options.gd")
const CHARGEMENT := preload("res://scripts/ecran_chargement.gd")
const AUDIO := preload("res://scripts/menu_audio.gd")
const LOGO_SHADER := preload("res://shaders/menu_ui/logo_apparition.gdshader")
const LOGO_GIVRE := preload("res://shaders/menu_ui/logo_givre.gdshader")
const FOND_REPLI := "res://assets/ui/titre_reference.jpg"
const DECOR := "res://scenes/menu_decor/menu_decor.tscn"
## Décor : peinture de 1920x1080 (nœud « Cadre », mis à l'échelle par le décor) ; logo peint détouré posé en LOGO_DECOR.
const DECOR_TAILLE := Vector2(1920, 1080)
const LOGO_DECOR_TEX := "res://textures/menu_decor/logo_peint.png"
const LOGO_DECOR := Rect2(562, 9, 832, 334)

## Auteur affiché dans les crédits (à changer ici).
const AUTEUR := "lopezk19"

# --- mise en page, en pixels de l'image de référence (1672x941) ---
const IMG := Vector2(1672, 941)
const BOUTON_POS := Vector2(110, 378)     # coin haut-gauche de « Continuer »
const BOUTON_TAILLE := Vector2(392, 58)
const PAS := 69.0                         # d'un bouton au suivant
const RAIL_X := 101.0
const LOGO := Rect2(430, 0, 840, 340)     # recadrage du logo peint (avec marge de brume)
const CRISTAL := Vector2(842, 148)
const ZONE_PANNEAUX := Rect2(560, 300, 1040, 600)
const LIBELLES := ["Continuer", "Nouvelle partie", "Charger", "Options", "Quitter"]

## Mode test (outils/test_menu_titre.gd) : le menu s'affiche même en mode outil, sans relance ni chargement du monde.
var mode_test := false

var _plan: Control
var _decor: Control       # décor animé (MenuDecor), plein écran sous l'interface ; null : repli sur l'image fixe
var _fond_repli: TextureRect
var _fond_bandes: TextureRect
var _logo: TextureRect
var _lueur: TextureRect
var _rail: Control
var _boutons: Array[BoutonRunique] = []
var _b_continuer: BoutonRunique
var _b_nouvelle: BoutonRunique
var _b_charger: BoutonRunique
var _b_options: BoutonRunique
var _b_quitter: BoutonRunique
var _b_credits: Button
var _pied: Label
var _panneaux: Control
var _options: PanelContainer
var _credits: PanelContainer
var _confirmation: PanelContainer
var _charger: PanelContainer
var _liste_copies: VBoxContainer
var _resume: Label
var _b_charger_partie: Button
var _avis_charger: Label
var _noir: ColorRect
var _audio: Node
var _neige: CPUParticles2D
var _echelle_jeu := {}
var _rect := Rect2()
var _t := 0.0
var _prochain_pulse := 4.0
var _demarre := false
var _occupe := false
var _menu_ouvert := true

func _ready() -> void:
	if Jeu.mode_outil() and not mode_test:
		get_tree().change_scene_to_file.call_deferred(Jeu.SCENE_JEU)
		return
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_passer_en_haute_definition()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = MenuStyle.theme_titre()
	_construire()
	get_viewport().size_changed.connect(_placer)
	_placer()
	# F9 ou « Charger » d'une partie précédente : relancé pour charger aussitôt
	if not mode_test and Jeu.lire_relance() == "continuer" and Jeu.sauvegarde_valide():
		_noir.modulate.a = 1.0
		_lancer(false, true)
		return
	_menu_principal()
	_intro()
	var test := Jeu.test_titre()
	if test != "" and not mode_test:
		_test.call_deferred(test)

func _exit_tree() -> void:
	MenuStyle.vider_titre()

## La fenêtre du jeu rend en 640x360 agrandi d'un facteur entier (project.godot) : le menu, lui, est dessiné en résolution native.
## Les réglages du jeu sont gardés pour l'écran de chargement, qui les rétablit avant de montrer le monde.
func _passer_en_haute_definition() -> void:
	var w := get_window()
	_echelle_jeu = {"mode": w.content_scale_mode, "aspect": w.content_scale_aspect, "taille": w.content_scale_size,
		"etirement": w.content_scale_stretch, "facteur": w.content_scale_factor}
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	w.content_scale_factor = 1.0

# --- construction -----------------------------------------------------------------------

func _construire() -> void:
	var noir_fond := ColorRect.new()
	noir_fond.color = Color("#05070b")
	noir_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(noir_fond)
	var fond_tex: Texture2D = load(FOND_REPLI)
	# bandes latérales (écrans plus larges que l'image : ultra-large) : l'image très floutée et assombrie
	_fond_bandes = TextureRect.new()
	var img_flou := fond_tex.get_image()
	MenuStyle.flouter(img_flou)
	_fond_bandes.texture = ImageTexture.create_from_image(img_flou)
	_fond_bandes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fond_bandes.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fond_bandes.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fond_bandes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fond_bandes.modulate = Color(0.42, 0.44, 0.52)
	add_child(_fond_bandes)

	_decor = _creer_decor()
	if _decor != null:
		add_child(_decor)
	_plan = Control.new()
	_plan.size = IMG
	_plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plan)
	if _decor == null:
		_fond_repli = TextureRect.new()
		_fond_repli.name = "FondRepli"
		_fond_repli.texture = fond_tex
		_fond_repli.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fond_repli.stretch_mode = TextureRect.STRETCH_SCALE
		_fond_repli.size = IMG
		_fond_repli.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plan.add_child(_fond_repli)
		_neige = _neige_repli()
		_plan.add_child(_neige)
	_logo = _creer_logo(fond_tex) if _decor == null else _creer_logo_decor()
	_plan.add_child(_logo)
	_lueur = _creer_lueur()
	_plan.add_child(_lueur)

	_rail = Control.new()
	_rail.position = Vector2.ZERO
	_rail.size = IMG
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail.draw.connect(_dessiner_rail)
	_plan.add_child(_rail)
	var actions: Array[Callable] = [func() -> void: _lancer(false), _nouvelle, _ouvrir_charger, _ouvrir_options, _quitter]
	for i in LIBELLES.size():
		var b := BoutonRunique.new()
		b.text = LIBELLES[i]
		b.name = "Bouton" + LIBELLES[i].replace(" ", "")
		b.position = BOUTON_POS + Vector2(0, PAS * i)
		b.size = BOUTON_TAILLE
		b.police = MenuStyle.police_titre(500)
		b.opacite_fond = 0.62 if _decor_anime() else 0.9   # repli : l'image garde ses boutons peints, on les couvre
		var action: Callable = actions[i]
		b.pressed.connect(func() -> void: _valider(b, action))
		b.survole.connect(func() -> void:
			_audio.jouer("survol")
			_rail.queue_redraw())
		b.focus_exited.connect(_rail.queue_redraw)
		_plan.add_child(b)
		_boutons.append(b)
	_b_continuer = _boutons[0]
	_b_nouvelle = _boutons[1]
	_b_charger = _boutons[2]
	_b_options = _boutons[3]
	_b_quitter = _boutons[4]

	# pied : version et lien « Crédits » (discrets, en bas à droite de la partie visible)
	_pied = Label.new()
	_pied.text = "%s  ·  démo %s" % [Jeu.nom(), Jeu.version()]
	_pied.add_theme_font_override("font", MenuStyle.police_titre(400))
	_pied.add_theme_font_size_override("font_size", 19)
	_pied.add_theme_color_override("font_color", Color(MenuStyle.ACIER, 0.75))
	_pied.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pied.size = Vector2(500, 26)
	_plan.add_child(_pied)
	_b_credits = Button.new()
	_b_credits.name = "BoutonCredits"
	_b_credits.text = "Crédits"
	_b_credits.flat = true
	_b_credits.focus_mode = Control.FOCUS_ALL
	_b_credits.add_theme_font_size_override("font_size", 21)
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = 8
	vide.content_margin_right = 8
	var souligne := StyleBoxFlat.new()
	souligne.draw_center = false
	souligne.border_color = MenuStyle.LUEUR
	souligne.border_width_bottom = 2
	souligne.content_margin_left = 8
	souligne.content_margin_right = 8
	for s in ["normal", "pressed", "disabled"]:
		_b_credits.add_theme_stylebox_override(s, vide)
	for s in ["hover", "focus", "hover_pressed"]:
		_b_credits.add_theme_stylebox_override(s, souligne)
	_b_credits.add_theme_color_override("font_color", Color(MenuStyle.ACIER, 0.9))
	_b_credits.mouse_entered.connect(func() -> void: _b_credits.grab_focus())
	_b_credits.focus_entered.connect(func() -> void: _audio.jouer("survol"))
	_b_credits.pressed.connect(func() -> void:
		_audio.jouer("validation")
		_ouvrir_credits())
	_plan.add_child(_b_credits)

	_panneaux = CenterContainer.new()
	_panneaux.position = ZONE_PANNEAUX.position
	_panneaux.size = ZONE_PANNEAUX.size
	_panneaux.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan.add_child(_panneaux)
	_options = PanelContainer.new()
	_options.set_script(OPTIONS)
	_options.theme_impose = MenuStyle.theme_titre()
	_options.echelle = 2.2
	_options.visible = false
	_options.ferme.connect(_menu_principal)
	_panneaux.add_child(_options)
	_charger = _panneau_charger()
	_panneaux.add_child(_charger)
	_credits = _panneau_credits()
	_panneaux.add_child(_credits)
	_confirmation = _panneau_confirmation()
	_panneaux.add_child(_confirmation)

	_noir = ColorRect.new()
	_noir.color = Color.BLACK
	_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_noir)
	_audio = AUDIO.new()
	add_child(_audio)

## Décor animé (scenes/menu_decor, chargé par chemin) : Control plein écran qui cadre lui-même la peinture (« cover ») ;
## l'interface suit son nœud « Cadre » (voir _placer). null si la scène manque : repli sur l'image fixe.
func _creer_decor() -> Control:
	if not ResourceLoader.exists(DECOR):
		return null
	var ps: PackedScene = load(DECOR)
	var d: Node = ps.instantiate() if ps != null else null
	if not (d is Control) or d.get_node_or_null("Cadre") == null:
		if d != null:
			d.free()
		push_warning("Décor du menu inutilisable, repli sur l'image fixe : " + DECOR)
		return null
	# écrans plus étroits que 16:9 (16:10, 4:3) : on rogne surtout à droite, pour garder la colonne de boutons loin du bord gauche
	var anc: Variant = d.get("ancrage")
	if anc is Vector2:
		d.set("ancrage", Vector2(0.28, (anc as Vector2).y))
	(d as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	(d as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d

func _decor_anime() -> bool:
	return _decor != null

## Logo du décor (détouré) pour l'apparition : posé exactement sur celui du décor, qui est masqué le temps de l'apparition.
func _creer_logo_decor() -> TextureRect:
	var k := IMG.x / DECOR_TAILLE.x
	var l := TextureRect.new()
	l.name = "LogoApparition"
	l.texture = load(LOGO_DECOR_TEX) if ResourceLoader.exists(LOGO_DECOR_TEX) else null
	l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # AVANT size : sinon la taille minimale (texture 832x334) l'emporte
	l.stretch_mode = TextureRect.STRETCH_SCALE
	l.position = LOGO_DECOR.position * k
	l.size = LOGO_DECOR.size * k
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = LOGO_GIVRE
	m.set_shader_parameter("centre", (Vector2(964, 172) - LOGO_DECOR.position) / LOGO_DECOR.size)
	m.set_shader_parameter("aspect", LOGO_DECOR.size.x / LOGO_DECOR.size.y)
	m.set_shader_parameter("progres", 0.0)
	l.material = m
	return l

func _neige_repli() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 220
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(IMG.x * 0.62, 4)
	p.position = Vector2(IMG.x * 0.45, -12)
	p.direction = Vector2(0.18, 1.0)
	p.spread = 14.0
	p.gravity = Vector2(0, 2)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.4
	p.color = Color(0.86, 0.91, 1.0, 0.7)
	return p

## Logo peint (recadrage de l'image) au-dessus du décor, le temps de son apparition ; ensuite caché (le décor le montre).
func _creer_logo(fond_tex: Texture2D) -> TextureRect:
	var img := fond_tex.get_image().get_region(Rect2i(LOGO))
	var flou := img.duplicate() as Image
	flou.resize(int(LOGO.size.x / 28.0), int(LOGO.size.y / 28.0), Image.INTERPOLATE_BILINEAR)
	flou.resize(int(LOGO.size.x / 4.0), int(LOGO.size.y / 4.0), Image.INTERPOLATE_CUBIC)
	var l := TextureRect.new()
	l.name = "LogoApparition"
	l.texture = ImageTexture.create_from_image(img)
	l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	l.stretch_mode = TextureRect.STRETCH_SCALE
	l.position = LOGO.position
	l.size = LOGO.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = LOGO_SHADER
	m.set_shader_parameter("flou", ImageTexture.create_from_image(flou))
	m.set_shader_parameter("centre", (CRISTAL - LOGO.position) / LOGO.size)
	m.set_shader_parameter("aspect", LOGO.size.x / LOGO.size.y)
	m.set_shader_parameter("progres", 0.0)
	l.material = m
	return l

## Lueur bleue du cristal (additive), pour la pulsation ; le décor peut fournir la sienne (pulse_cristal()).
func _creer_lueur() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.92, 1.0, 1.0))
	g.add_point(0.18, Color(0.35, 0.72, 1.0, 0.75))
	g.set_color(g.get_point_count() - 1, Color(0.1, 0.4, 1.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var t := TextureRect.new()
	t.name = "LueurCristal"
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(190, 190)
	t.position = CRISTAL - t.size * 0.5
	t.pivot_offset = t.size * 0.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	t.material = mat
	t.modulate.a = 0.0
	return t

# --- mise en page -----------------------------------------------------------------------

## Rectangle de l'image à l'écran : couvre l'écran, mais sans rogner plus de 14 % de la hauteur ni 20 % de la largeur
## (ultra-large : bandes latérales floutées ; 16:10 : rognage surtout à droite, loin des boutons ; haut gardé pour le logo).
## Rectangle de l'image avec le décor animé pour un écran `v` (même calcul que MenuDecor._cadrer : « cover » × marge, ancrage).
func rect_image_decor(v: Vector2) -> Rect2:
	if _decor == null:
		return rect_image(v)
	var marge: float = _decor.get("marge")
	var ancrage: Vector2 = _decor.get("ancrage")
	var sd := maxf(v.x / DECOR_TAILLE.x, v.y / DECOR_TAILLE.y) * marge
	return Rect2((v - DECOR_TAILLE * sd) * ancrage, IMG * sd * DECOR_TAILLE.x / IMG.x)

static func rect_image(v: Vector2) -> Rect2:
	var s := maxf(v.x / IMG.x, v.y / IMG.y)
	s = minf(s, minf(v.y / (IMG.y * 0.86), v.x / (IMG.x * 0.80)))
	s = maxf(s, minf(v.x / IMG.x, v.y / IMG.y))
	var taille := IMG * s
	return Rect2(Vector2((v.x - taille.x) * 0.3, (v.y - taille.y) * 0.15), taille)

func _placer() -> void:
	var v := get_viewport().get_visible_rect().size
	_rect = rect_image(v)
	var cadre := _decor.get_node("Cadre") as Control if _decor != null else null
	if cadre != null:   # l'interface suit le cadrage du décor (peinture 1920x1080 → image de référence 1672x941)
		_rect = Rect2(cadre.position, IMG * cadre.scale.x * DECOR_TAILLE.x / IMG.x)
	var s := _rect.size.x / IMG.x
	_plan.position = _rect.position
	_plan.scale = Vector2(s, s)
	_fond_bandes.visible = _rect.position.x > 0.5 or _rect.position.y > 0.5
	# partie visible de l'image (en pixels de l'image) : le pied s'y cale en bas à droite
	var vis := Rect2(-_rect.position / s, v / s).intersection(Rect2(Vector2.ZERO, IMG))
	_pied.position = vis.end - Vector2(_pied.size.x + 26, 34)
	# zone des panneaux : sous le logo, jusqu'au bas de la partie VISIBLE de l'image (ultra-large : le bas est rogné) ;
	# le panneau Options s'y plafonne (ses réglages défilent au-delà) : titre, Caméra, Touches et Retour toujours visibles
	var haut := ZONE_PANNEAUX.position.y - 10.0
	var bas := minf(vis.end.y - 12.0, IMG.y - 12.0)
	var hauteur := maxf(bas - haut, 200.0)
	_options.hauteur_max = hauteur   # AVANT la taille de la zone : un conteneur ne descend pas sous la taille de son contenu
	_panneaux.position = Vector2(ZONE_PANNEAUX.position.x, haut)
	_panneaux.size = Vector2(ZONE_PANNEAUX.size.x, hauteur)
	_ajuster_zone.call_deferred(hauteur)
	_b_credits.reset_size()
	_b_credits.position = Vector2(vis.end.x - _b_credits.size.x - 18, _pied.position.y - _b_credits.size.y - 2)

## Zone des panneaux recalée après le rétrécissement du panneau Options (sinon elle reste à l'ancienne taille du contenu).
func _ajuster_zone(hauteur: float) -> void:
	await get_tree().process_frame
	_panneaux.size = Vector2(ZONE_PANNEAUX.size.x, hauteur)

func _dessiner_rail() -> void:
	var haut := BOUTON_POS.y - 22.0
	var bas := BOUTON_POS.y + PAS * (LIBELLES.size() - 1) + BOUTON_TAILLE.y + 16.0
	var c := MenuStyle.ACIER_SOMBRE.lerp(MenuStyle.ACIER, 0.5)
	_rail.draw_line(Vector2(RAIL_X, haut), Vector2(RAIL_X, bas), Color(0, 0, 0, 0.5), 5.0, true)
	_rail.draw_line(Vector2(RAIL_X, haut), Vector2(RAIL_X, bas), c, 2.0, true)
	_rail.draw_line(Vector2(RAIL_X - 4, haut + 10), Vector2(RAIL_X - 4, bas - 10), Color(c, 0.45), 1.0, true)
	var choisi := -1
	for i in _boutons.size():
		if _boutons[i].has_focus():
			choisi = i
	# nœud entrelacé en haut (bleu si un bouton est choisi)
	var allume := 1.0 if choisi >= 0 else 0.0
	MenuStyle.dessiner_losange(_rail, Vector2(RAIL_X, haut - 4), 15.0, allume * 0.6)
	for i in _boutons.size():
		var y := BOUTON_POS.y + PAS * i + BOUTON_TAILLE.y * 0.5
		var a := 1.0 if i == choisi else 0.0
		var col := c.lerp(MenuStyle.LUEUR, a)
		if a > 0.0:
			_rail.draw_line(Vector2(RAIL_X, y - PAS * 0.5), Vector2(RAIL_X, y + PAS * 0.5), Color(MenuStyle.LUEUR, 0.25), 6.0, true)
			_rail.draw_line(Vector2(RAIL_X, y - PAS * 0.5), Vector2(RAIL_X, y + PAS * 0.5), MenuStyle.LUEUR, 2.0, true)
		_rail.draw_line(Vector2(RAIL_X, y), Vector2(BOUTON_POS.x + 2, y), col, 1.6, true)
		_rail.draw_colored_polygon(MenuStyle._losange_pts(Vector2(RAIL_X, y), 5.5), Color(0.03, 0.04, 0.06, 0.95))
		_rail.draw_polyline(MenuStyle._losange_pts(Vector2(RAIL_X, y), 5.5, true), col, 1.5, true)
	MenuStyle.dessiner_losange(_rail, Vector2(RAIL_X, bas + 8), 8.0, 0.0)

# --- animation ------------------------------------------------------------------------

## Apparition : le paysage sort du noir, le logo sort de la brume depuis le cristal, les boutons glissent en place.
func _intro() -> void:
	_noir.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_noir, "modulate:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var m := _logo.material as ShaderMaterial
	if _decor != null and _decor.has_method("set_logo_peint") and _logo.texture != null:
		_decor.call("set_logo_peint", false)   # le logo du décor reprend la main à la fin de l'apparition
	var tl := create_tween()
	tl.tween_interval(0.7)
	tl.tween_method(func(v: float) -> void: m.set_shader_parameter("progres", v), 0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tl.tween_callback(func() -> void:
		if _decor != null and _decor.has_method("set_logo_peint"):
			_decor.call("set_logo_peint", true)
		_logo.visible = false
		_pulser())
	for i in _boutons.size():
		var b := _boutons[i]
		b.modulate.a = 0.0
		b.position.x = BOUTON_POS.x - 36.0
		var tb := create_tween().set_parallel(true)
		tb.tween_property(b, "modulate:a", 1.0, 0.6).set_delay(1.1 + 0.09 * i)
		tb.tween_property(b, "position:x", BOUTON_POS.x, 0.7).set_delay(1.1 + 0.09 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rail.modulate.a = 0.0
	create_tween().tween_property(_rail, "modulate:a", 1.0, 0.8).set_delay(1.0)
	_audio.demarrer(2.5)
	_prochain_pulse = 3.4 + randf_range(6.0, 8.0)

## Pulsation du cristal : celle du décor s'il en a une, sinon la lueur additive.
func _pulser() -> void:
	if _decor != null and _decor.has_method("pulse_cristal"):
		_decor.call("pulse_cristal", 0.9)
		return
	var tw := create_tween().set_parallel(true)
	_lueur.scale = Vector2(0.7, 0.7)
	tw.tween_property(_lueur, "modulate:a", 0.6, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lueur, "scale", Vector2(1.15, 1.15), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_lueur, "modulate:a", 0.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _process(dt: float) -> void:
	_t += dt
	if _decor != null:
		var cadre := _decor.get_node("Cadre") as Control
		if cadre.position != _rect.position or not is_equal_approx(cadre.scale.x * DECOR_TAILLE.x, _rect.size.x):
			_placer()
	if _t >= _prochain_pulse and not _demarre:
		_prochain_pulse = _t + randf_range(6.0, 8.0)
		_pulser()

# --- menu -----------------------------------------------------------------------------------

func _menu_principal() -> void:
	for p in [_options, _credits, _confirmation, _charger]:
		p.visible = false
	_menu_ouvert = true
	_b_continuer.activer(Jeu.sauvegarde_valide())
	for b in _boutons:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		create_tween().tween_property(b, "self_modulate", Color.WHITE, 0.2)
	_b_credits.focus_mode = Control.FOCUS_ALL
	_b_credits.mouse_filter = Control.MOUSE_FILTER_STOP
	var chaine: Array = []
	chaine.append_array(_boutons)
	chaine.append(_b_credits)
	MenuStyle.chainer(chaine)
	_b_credits.focus_neighbor_left = _b_credits.get_path_to(_b_quitter)
	focus_initial().grab_focus.call_deferred()
	_rail.queue_redraw()

## Focus au démarrage : Continuer s'il est actif, sinon Nouvelle partie.
func focus_initial() -> Control:
	return _b_continuer if not _b_continuer.disabled else _b_nouvelle

## Un panneau s'ouvre : la colonne reste visible, atténuée, sans focus ni survol.
func _ouvrir_panneau(p: Control) -> void:
	_menu_ouvert = false
	for b in _boutons:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		create_tween().tween_property(b, "self_modulate", Color(0.5, 0.52, 0.58), 0.2)
	_b_credits.focus_mode = Control.FOCUS_NONE
	_b_credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for autre in [_options, _credits, _confirmation, _charger]:
		autre.visible = autre == p
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.18)

func _valider(b: BoutonRunique, action: Callable) -> void:
	if _occupe or _demarre or not _menu_ouvert:
		return
	_occupe = true
	_audio.jouer("validation")
	if _decor != null and _decor.has_method("pulse_cristal"):
		_decor.call("pulse_cristal", 1.0)
	await b.valider()
	_occupe = false
	action.call()

func _nouvelle() -> void:
	if Jeu.sauvegarde_valide():
		_ouvrir_panneau(_confirmation)
		_confirmation.get_meta("non").grab_focus.call_deferred()
	else:
		_lancer(true)

func _ouvrir_options() -> void:
	_ouvrir_panneau(_options)
	_options.ouvrir()

func _ouvrir_credits() -> void:
	_ouvrir_panneau(_credits)
	_credits.get_meta("retour").grab_focus.call_deferred()

func _ouvrir_charger() -> void:
	_maj_charger()
	_ouvrir_panneau(_charger)
	(_b_charger_partie if not _b_charger_partie.disabled else _charger.get_meta("retour")).grab_focus.call_deferred()

func _quitter() -> void:
	_demarre = true
	_audio.baisser(0.5)
	var tw := create_tween()
	tw.tween_property(_noir, "modulate:a", 1.0, 0.5)
	await tw.finished
	Jeu.quitter()   # jeu exporté : sortie directe (Jeu.sortie_directe, le nettoyage du moteur plantait en release)

## Charge le monde (une seule fois par processus). `nouvelle` : ne lit pas la sauvegarde. `direct` : déjà au noir (relance F9).
func _lancer(nouvelle: bool, direct := false) -> void:
	if _demarre:
		return
	_demarre = true
	Jeu.nouvelle_partie = nouvelle
	for b in _boutons:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not direct:
		_audio.jouer("transition")
		_audio.baisser(1.3)
		var tw := create_tween()
		tw.tween_property(_noir, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
	if mode_test:
		return
	var ecran: CanvasLayer = CHARGEMENT.new()
	ecran.scene_jeu = Jeu.SCENE_JEU
	ecran.echelle_jeu = _echelle_jeu
	get_tree().root.add_child(ecran)
	ecran.demarrer()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if _demarre or not e.is_action_pressed("ui_cancel"):
		return
	if _credits.visible or _confirmation.visible or _charger.visible:
		get_viewport().set_input_as_handled()
		_audio.jouer("retour")
		_menu_principal()
	elif _menu_ouvert:
		# Échap sur le menu : le focus va sur « Quitter » (Entrée pour confirmer)
		get_viewport().set_input_as_handled()
		_b_quitter.grab_focus()

# --- panneaux --------------------------------------------------------------------------

func _titre_panneau(texte: String) -> Label:
	var t := Label.new()
	t.text = texte.to_upper()
	t.add_theme_font_override("font", MenuStyle.police_capitales(600))
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", MenuStyle.GIVRE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t

func _bouton_panneau(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: _audio.jouer("survol"))
	b.pressed.connect(func() -> void:
		_audio.jouer("validation")
		action.call())
	return b

func _panneau_confirmation() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "PanneauConfirmation"
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	p.add_child(v)
	v.add_child(_titre_panneau("Nouvelle partie"))
	var l := Label.new()
	l.text = "Une partie existe déjà.\nLa remplacer par une nouvelle ?"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 30)
	v.add_child(h)
	var oui := _bouton_panneau("Oui, recommencer", func() -> void: _lancer(true))
	var non := _bouton_panneau("Non", _menu_principal)
	h.add_child(oui)
	h.add_child(non)
	p.set_meta("non", non)
	return p

## Charger : la partie en cours (date, heure du jeu, pièces) et les copies de secours datées (Options > Copie de secours),
## chacune restaurable (la sauvegarde locale est gardée à côté, voir Jeu.restaurer_copie).
func _panneau_charger() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "PanneauCharger"
	p.visible = false
	p.custom_minimum_size = Vector2(820, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	v.add_child(_titre_panneau("Charger"))
	_resume = Label.new()
	_resume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_resume)
	_b_charger_partie = _bouton_panneau("Charger cette partie", func() -> void: _lancer(false))
	_b_charger_partie.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_b_charger_partie)
	var sep := HSeparator.new()
	var ligne := StyleBoxLine.new()
	ligne.color = Color(MenuStyle.ACIER, 0.5)
	ligne.thickness = 1
	sep.add_theme_stylebox_override("separator", ligne)
	v.add_child(sep)
	var st := Label.new()
	st.text = "Copies de secours"
	st.add_theme_color_override("font_color", MenuStyle.LUEUR.lerp(MenuStyle.GIVRE, 0.4))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var defil := ScrollContainer.new()
	defil.custom_minimum_size = Vector2(0, 150)
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defil.follow_focus = true
	v.add_child(defil)
	_liste_copies = VBoxContainer.new()
	_liste_copies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste_copies.add_theme_constant_override("separation", 6)
	defil.add_child(_liste_copies)
	_avis_charger = Label.new()
	_avis_charger.add_theme_color_override("font_color", MenuStyle.LUEUR.lerp(MenuStyle.GIVRE, 0.5))
	_avis_charger.add_theme_font_size_override("font_size", 24)
	_avis_charger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_avis_charger)
	var retour := _bouton_panneau("Retour", _menu_principal)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(retour)
	p.set_meta("retour", retour)
	return p

func _maj_charger(avis := "") -> void:
	var r := Jeu.resume_sauvegarde()
	if r.is_empty():
		_resume.text = "Aucune partie sauvegardée lisible."
		_b_charger_partie.disabled = true
		_b_charger_partie.focus_mode = Control.FOCUS_NONE
	else:
		var heure := float(r["heure"])
		var h_txt := (" — heure du jeu : %dh%02d" % [int(heure) % 24, int(fmod(heure, 1.0) * 60.0)]) if heure >= 0.0 else ""
		_resume.text = "Partie en cours, sauvegardée le %s%s\n%d pièces" % [r["date"], h_txt, r["pieces"]]
		_b_charger_partie.disabled = false
		_b_charger_partie.focus_mode = Control.FOCUS_ALL
	for c in _liste_copies.get_children():
		_liste_copies.remove_child(c)
		c.queue_free()
	var dossier: String = Jeu.dossier_secours()
	var copies := Jeu.copies_secours()
	if dossier == "":
		_liste_copies.add_child(_petit("Désactivée — à choisir dans Options > Copie de secours\n(un dossier Google Drive ou OneDrive, par exemple)."))
	elif copies.is_empty():
		_liste_copies.add_child(_petit("Aucune copie pour l'instant dans « %s »." % dossier))
	else:
		for i in range(copies.size() - 1, -1, -1):
			var chemin: String = copies[i]
			var b := _bouton_panneau("Restaurer la copie du %s" % _date_copie(chemin), func() -> void: _restaurer(chemin))
			b.name = "Copie%d" % (copies.size() - 1 - i)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 25)
			if not Jeu.sauvegarde_valide(chemin):
				b.disabled = true
				b.text += " (illisible)"
			_liste_copies.add_child(b)
	_avis_charger.text = avis

func _petit(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(MenuStyle.ARGENT, 0.75))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	return l

## « Hollowrim_sauvegarde_2026-10-26_19-40-12.json » → « 26/10/2026 à 19h40 ».
static func _date_copie(chemin: String) -> String:
	var n := chemin.get_file().get_basename()
	var morceaux := n.split("_")
	if morceaux.size() < 2:
		return n
	var d := morceaux[morceaux.size() - 2].split("-")
	var h := morceaux[morceaux.size() - 1].split("-")
	if d.size() < 3 or h.size() < 2:
		return n
	return "%s/%s/%s à %sh%s" % [d[2], d[1], d[0], h[0], h[1]]

func _restaurer(chemin: String) -> void:
	if Jeu.restaurer_copie(chemin):
		_b_continuer.activer(Jeu.sauvegarde_valide())
		_maj_charger("Copie restaurée : « Continuer » reprend cette partie.")
		_b_charger_partie.grab_focus.call_deferred()
	else:
		_maj_charger("Restauration impossible (copie illisible).")

func _panneau_credits() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "PanneauCredits"
	p.visible = false
	p.custom_minimum_size = Vector2(980, 560)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(_titre_panneau("Crédits"))
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(defil)
	var texte := Label.new()
	texte.text = credits_texte()
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.custom_minimum_size = Vector2(880, 0)
	texte.add_theme_font_size_override("font_size", 23)
	defil.add_child(texte)
	var retour := _bouton_panneau("Retour", _menu_principal)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(retour)
	p.set_meta("retour", retour)
	# défilement au clavier / à la manette pendant que « Retour » a le focus
	retour.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_down"):
			defil.scroll_vertical += 60
			retour.accept_event()
		elif e.is_action_pressed("ui_up"):
			defil.scroll_vertical -= 60
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
		"· Bruitages : Kenney (Impact Sounds, RPG Audio, Interface Sounds), artisticdude (RPG Sound Pack), rubberduck (80 CC0 creature SFX), SketchMan3, zeroisnotnull, spring-spring, Boss Level Audio — OpenGameArt",
		"· Musiques : congusbongus (Cathedral in the forest, Ancient caverns), Kaiser (Frost in the Northern Winter), RandomMind (Medieval: Battle, The Old Tower Inn), synth-thetic (Beyond the Frozen Veil), indieteur (Long Winter) — OpenGameArt",
		"· Ambiances du menu : Luke.RUSTLTD (vent), pagdev (feu), randommind (eau) — OpenGameArt",
		"",
		"Polices du menu et des titres (SIL Open Font License 1.1) : Alegreya (The Alegreya Project Authors), Cinzel (The Cinzel Project Authors), Jacquard (The Soft Type Project Authors).",
		"Citations de l'écran de chargement : d'après le Hávamál (poème eddique, domaine public), traduction libre.",
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
		await _captures(etape.substr(9))
		get_tree().quit()
	elif etape.begins_with("options:"):
		await _captures_options(etape.substr(8))
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
	elif etape == "clavier":
		var ok := await verifier_clavier()
		get_tree().quit(0 if ok else 1)
	elif etape == "continuer":
		if _b_continuer.disabled:
			print("TEST MENUS : ÉCHEC (Continuer grisé alors qu'une sauvegarde est attendue)")
			get_tree().quit(1)
			return
		await get_tree().create_timer(2.0).timeout   # fin de l'apparition des boutons
		_b_continuer.pressed.emit()
	elif etape == "restaurer":
		# sauvegarde locale rendue illisible : Continuer grisé, Charger propose les copies de secours ; on restaure la plus récente
		var f: String = load("res://scripts/monde.gd").fichier_sauvegarde()
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_string("{ corrompue")
		fa.close()
		_menu_principal()
		await get_tree().create_timer(2.0).timeout
		_b_charger.pressed.emit()
		await get_tree().create_timer(0.8).timeout
		var premiere := _liste_copies.get_node_or_null("Copie0") as Button
		print("TEST MENUS : sauvegarde corrompue, continuer %s, copie de secours %s" % ["grisé" if _b_continuer.disabled else "ACTIF", "proposée" if premiere != null else "ABSENTE"])
		if premiere == null or not _charger.visible:
			print("TEST MENUS : ÉCHEC (restauration non proposée)")
			get_tree().quit(1)
			return
		premiere.pressed.emit()
		await get_tree().process_frame
		print("TEST MENUS : restaurer %s" % ("OK" if not _b_continuer.disabled else "ÉCHEC"))
		if _b_continuer.disabled:
			get_tree().quit(1)
			return
		_b_charger_partie.pressed.emit()

## Parcours au clavier, sans sauvegarde (la sauvegarde de TEST est mise de côté puis remise) : Continuer grisé et hors du parcours,
## focus initial sur Nouvelle partie, Bas → Charger → Options → Quitter → Crédits → Nouvelle partie (boucle), Haut, Échap → Quitter,
## Entrée sur Options → panneau ouvert, Échap → retour au menu. Renvoie true si tout est bon (« TEST MENUS : clavier OK »).
func verifier_clavier() -> bool:
	var f: String = load("res://scripts/monde.gd").fichier_sauvegarde()
	var garde := FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else PackedByteArray()
	var garde_valide := Jeu.sauvegarde_valide(f)
	if FileAccess.file_exists(f):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	_menu_principal()
	await _images(3)
	var echecs := PackedStringArray()
	if not _b_continuer.disabled:
		echecs.append("Continuer actif sans sauvegarde")
	if _b_continuer.focus_mode != Control.FOCUS_NONE:
		echecs.append("Continuer sélectionnable")
	var attendu := ["Nouvelle partie", "Charger", "Options", "Quitter", "Crédits", "Nouvelle partie"]
	var vus := [_focus_texte()]
	for i in attendu.size() - 1:
		await _touche("ui_down")
		vus.append(_focus_texte())
	if vus != attendu:
		echecs.append("parcours Bas %s (attendu %s)" % [vus, attendu])
	await _touche("ui_up")
	if _focus_texte() != "Crédits":
		echecs.append("Haut depuis Nouvelle partie → %s" % _focus_texte())
	_b_nouvelle.grab_focus()
	await _touche("ui_cancel")
	if _focus_texte() != "Quitter":
		echecs.append("Échap → %s (attendu Quitter)" % _focus_texte())
	_b_options.grab_focus()
	await _touche("ui_accept")
	await get_tree().create_timer(0.7).timeout
	if not _options.visible:
		echecs.append("Entrée sur Options : panneau fermé")
	await _touche("ui_cancel")
	await _images(3)
	if _options.visible or not _menu_ouvert:
		echecs.append("Échap dans Options : pas de retour au menu")
	if garde.size() > 0:
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_buffer(garde)
		fa.close()
	_menu_principal()
	await _images(2)
	if garde_valide and (_b_continuer.disabled or _focus_texte() != "Continuer"):
		echecs.append("sauvegarde remise : Continuer %s, focus %s" % ["grisé" if _b_continuer.disabled else "actif", _focus_texte()])
	for e in echecs:
		print("TEST MENUS : ÉCHEC clavier : ", e)
	if echecs.is_empty():
		print("TEST MENUS : clavier OK (Continuer grisé sans sauvegarde, focus initial, parcours, Échap, Entrée)")
	return echecs.is_empty()

func _focus_texte() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return (f as Button).text if f is Button else str(f)

func _touche(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _images(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _images(2)

func _images(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Panneau Options seul, à plusieurs tailles de fenêtre (vérifie qu'il tient en hauteur), grille principale puis
## sous-panneaux Caméra et Touches : options_<L>x<H>[_camera|_touches].png ; ligne OPTIONS … DEPASSE si une partie
## du panneau sort de la fenêtre. (Le plein écran n'est pas essayé : la fenêtre de capture est hors écran.)
func _captures_options(dossier: String) -> void:
	await get_tree().create_timer(3.5).timeout
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		DisplayServer.window_set_size(taille)
		await get_tree().create_timer(0.8).timeout
		for vue: String in ["", "_camera", "_touches"]:
			_menu_principal()
			_ouvrir_options()
			if vue == "_camera":
				_options._basculer_camera()
			elif vue == "_touches":
				_options._basculer_touches()
			await get_tree().create_timer(0.5).timeout
			var reel := get_viewport().get_visible_rect().size
			var r := _options.get_global_rect()
			var dans := Rect2(Vector2.ZERO, reel).grow(0.5).encloses(r)
			print("OPTIONS %dx%d%s : panneau %s, fenêtre %s %s" % [int(reel.x), int(reel.y), vue, r, reel, "OK" if dans else "DEPASSE"])
			await capture(dossier.path_join("options_%dx%d%s.png" % [int(reel.x), int(reel.y), vue]))
	_options.fermer()

## Captures : repos, survol, Continuer grisé, panneaux, écran de chargement (démo), puis plusieurs tailles de fenêtre.
func _captures(dossier: String) -> void:
	await get_tree().create_timer(0.9).timeout   # milieu de l'apparition (logo qui se cristallise, boutons qui glissent)
	await capture(dossier.path_join("titre_apparition.png"))
	await get_tree().create_timer(2.8).timeout   # fin de l'apparition
	await capture(dossier.path_join("titre.png"))
	_b_nouvelle.grab_focus()
	await get_tree().create_timer(0.4).timeout
	await capture(dossier.path_join("titre_survol.png"))
	var f: String = load("res://scripts/monde.gd").fichier_sauvegarde()
	var garde := FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else PackedByteArray()
	if FileAccess.file_exists(f):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	_menu_principal()
	await get_tree().create_timer(0.5).timeout
	await capture(dossier.path_join("titre_continuer_grise.png"))
	if garde.size() > 0:
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_buffer(garde)
		fa.close()
	_menu_principal()
	_ouvrir_charger()
	await get_tree().create_timer(0.5).timeout
	await capture(dossier.path_join("charger.png"))
	_menu_principal()
	_ouvrir_options()
	await get_tree().create_timer(0.5).timeout
	await capture(dossier.path_join("options_titre.png"))
	_options.fermer()
	_ouvrir_credits()
	await get_tree().create_timer(0.5).timeout
	await capture(dossier.path_join("credits.png"))
	_menu_principal()
	_ouvrir_panneau(_confirmation)
	await get_tree().create_timer(0.5).timeout
	await capture(dossier.path_join("confirmation.png"))
	_menu_principal()
	var ecran: CanvasLayer = CHARGEMENT.new()
	ecran.demo = true
	get_tree().root.add_child(ecran)
	await get_tree().create_timer(2.5).timeout
	await capture(dossier.path_join("chargement.png"))
	ecran.queue_free()
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1920, 1200), Vector2i(1680, 1050), Vector2i(2560, 1080), Vector2i(3440, 1440)]:
		DisplayServer.window_set_size(taille)
		await get_tree().create_timer(0.6).timeout
		var reel := get_viewport().get_visible_rect().size
		await capture(dossier.path_join("titre_%dx%d.png" % [int(reel.x), int(reel.y)]))

func capture(chemin: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	img.save_png(chemin)
	print("TEST MENUS : capture ", chemin, " (", img.get_width(), "x", img.get_height(), ")")
