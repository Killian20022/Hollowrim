class_name EcranChargement
extends CanvasLayer
## Écran de chargement Hollowrim (écran titre → monde) : fond sombre, neige lente, rune qui tourne et pulse, étape en cours,
## citation du Hávamál ou conseil, barre d'avancement. Il fait aussi entrer le monde SANS figer l'image :
##  1. scène du monde lue en tâche de fond (ResourceLoader.load_threaded_request : compilation des scripts) ;
##  2. monde instancié puis ajouté à l'arbre EN PAUSE, avec Jeu.chargement_etale : Monde._ready rend une image entre ses étapes
##     (Monde._souffle, images normales — jamais RenderingServer.force_draw, voir Monde._prechauffer_rendu), rendu 3D coupé ;
##  3. monde prêt (Monde.pret) : fondu au noir, l'échelle de la fenêtre du jeu (640x360 agrandi, project.godot) est rétablie,
##     la pause est levée, le noir s'efface sur le monde.
## Ajouté à la racine (il survit à l'écran titre, libéré à la fin). `demo` : aucune scène chargée (captures, test des menus).

signal termine

const CITATIONS := [
	["Le bétail meurt, les parents meurent, soi-même on meurt aussi ; mais la renommée ne meurt jamais, pour qui sut la gagner.", "Hávamál, 76"],
	["Qu'en plein champ nul ne s'écarte d'un pas de ses armes : on ne sait jamais quand on aura besoin de sa lance.", "Hávamál, 38"],
	["Mieux vaut vivre que mourir : au vivant, il reste toujours une vache.", "Hávamál, 70"],
	["Celui qui arrive a besoin de feu, car il a froid aux genoux ; de vivres et de vêtements, lui qui a franchi les monts.", "Hávamál, 3"],
	["Nul meilleur fardeau à porter en chemin qu'un grand savoir.", "Hávamál, 10"],
	["Le voyageur prudent se tait et écoute ; il ouvre les yeux, il ouvre les oreilles.", "Hávamál, 7"],
	["Conseil : maintenez le clic gauche pour un coup puissant ; le clic droit pare.", ""],
	["Conseil : la touche T allume la torche, V passe de la première à la troisième personne.", ""],
	["Conseil : Tab ouvre le sac et le journal des quêtes ; F5 sauvegarde la partie.", ""],
	["Conseil : trois gardiens dorment au cercle de pierres runiques. Approchez à pas comptés.", ""],
]
## Libellés des étapes de Monde._ready (Jeu.etape_chargement : mot-clé → texte).
const ETAPES := [
	["textures", "Les runes s'éveillent"], ["environnement", "Le ciel se couvre"], ["arriere", "Les montagnes se dressent"],
	["terrain", "La terre se soulève"], ["arbres", "Les forêts grandissent"], ["rochers", "Les pierres affleurent"],
	["sous-bois", "Le sous-bois s'épaissit"], ["sol", "La neige recouvre la lande"], ["cercle", "Le cercle runique s'éclaire"],
	["details", "La neige recouvre la lande"], ["abords", "Les sentiers se tracent"], ["rues", "Skarnholt allume ses foyers"],
	["mobilier", "Skarnholt allume ses foyers"], ["village", "Skarnholt allume ses foyers"], ["eau", "La rivière reprend son cours"],
	["joueur", "Le voyageur s'avance"], ["interface", "Le voyageur s'avance"], ["draugrs", "Les morts remuent sous les pierres"],
	["villageois", "Les villageois s'éveillent"], ["tertre", "Le tertre garde ses secrets"], ["grotte", "La grotte attend"],
]
## Nombre d'étapes de Monde._ready (marques _chrono) : sert à l'avancement de la barre.
const ETAPES_MONDE := 26
const DUREE_CITATION := 7.0
const DUREE_MINI := 1.6   # l'écran reste au moins ce temps (lisible même si tout est en cache)

var scene_jeu := ""
var echelle_jeu := {}     # réglages d'échelle de la fenêtre à rétablir pour le monde (voir EcranTitre)
var demo := false
var avancement := 0.0     # affiché (lissé)
var _cible := 0.0
var _racine: Control
var _rune: Control
var _barre: Control
var _etape: Label
var _citation: Label
var _auteur: Label
var _nom: Label
var _noir: ColorRect
var _fond_flou: TextureRect
var _neige: CPUParticles2D
var _t := 0.0
var _t_citation := 0.0
var _i_citation := 0
var _phase := ""          # "", "scene", "monde", "fin"
var _monde: Node
var _debut := 0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_racine)
	var fond := ColorRect.new()
	fond.color = Color("#05070c")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(fond)
	# souvenir flou du paysage du titre (image réduite à 48 px de large puis agrandie : rien qu'une lueur de couleurs)
	_fond_flou = TextureRect.new()
	var img: Image = (load("res://assets/ui/titre_reference.jpg") as Texture2D).get_image()
	img.resize(48, 27, Image.INTERPOLATE_BILINEAR)
	img.resize(512, 288, Image.INTERPOLATE_CUBIC)   # flou lisse même sans filtrage linéaire
	_fond_flou.texture = ImageTexture.create_from_image(img)
	_fond_flou.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fond_flou.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fond_flou.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fond_flou.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fond_flou.modulate = Color(0.32, 0.36, 0.45, 1.0)
	_racine.add_child(_fond_flou)
	var vignette := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.92))
	g.set_offset(0, 0.25)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	vignette.texture = gt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(vignette)
	_neige = CPUParticles2D.new()
	_neige.amount = 110
	_neige.lifetime = 14.0
	_neige.preprocess = 14.0
	_neige.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_neige.direction = Vector2(0.2, 1.0)
	_neige.spread = 10.0
	_neige.gravity = Vector2.ZERO
	_neige.initial_velocity_min = 18.0
	_neige.initial_velocity_max = 45.0
	_neige.color = Color(0.8, 0.88, 1.0, 0.45)
	_racine.add_child(_neige)

	_nom = Label.new()
	_nom.text = "HOLLOWRIM"
	var espacee := FontVariation.new()   # propre à ce titre (l'espacement ne touche pas la police partagée)
	espacee.base_font = MenuStyle.police_capitales(700)
	_nom.add_theme_font_override("font", espacee)
	_nom.add_theme_color_override("font_color", Color(MenuStyle.ARGENT, 0.9))
	_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_racine.add_child(_nom)
	_rune = Control.new()
	_rune.draw.connect(_dessiner_rune)
	_racine.add_child(_rune)
	_etape = _label(MenuStyle.police_titre(500), Color(MenuStyle.GIVRE, 0.85))
	_citation = _label(MenuStyle.police_titre(450), Color(MenuStyle.ARGENT, 0.92))
	_citation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auteur = _label(MenuStyle.police_capitales(500), Color(MenuStyle.ACIER, 0.9))
	_barre = Control.new()
	_barre.draw.connect(_dessiner_barre)
	_racine.add_child(_barre)
	_noir = ColorRect.new()
	_noir.color = Color.BLACK
	_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noir.modulate.a = 1.0
	_racine.add_child(_noir)
	_i_citation = randi() % CITATIONS.size()
	_montrer_citation(false)
	_etape.text = "Les sagas se rassemblent"
	get_viewport().size_changed.connect(_placer)
	_placer()
	_debut = Time.get_ticks_msec()
	create_tween().tween_property(_noir, "modulate:a", 0.0, 0.6)

func _label(police: Font, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", police)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_racine.add_child(l)
	return l

## Mise en page relative à la hauteur de l'écran (lisible de 1280x720 à 2560x1440, 16:10 et ultra-large).
func _placer() -> void:
	var v := get_viewport().get_visible_rect().size
	var k := v.y / 1080.0
	var cx := v.x * 0.5
	_neige.position = Vector2(cx, -10)
	_neige.emission_rect_extents = Vector2(v.x * 0.6, 4)
	_neige.scale_amount_min = 1.5 * k
	_neige.scale_amount_max = 3.2 * k
	_nom.add_theme_font_size_override("font_size", roundi(46 * k))
	_nom.add_theme_constant_override("outline_size", 0)
	_nom.size = Vector2(v.x, 60 * k)
	_nom.position = Vector2(0, v.y * 0.25)
	(_nom.get_theme_font("font") as FontVariation).spacing_glyph = roundi(10 * k)
	var r := 92.0 * k
	_rune.size = Vector2(r * 2.6, r * 2.6)
	_rune.pivot_offset = _rune.size * 0.5
	_rune.position = Vector2(cx, v.y * 0.47) - _rune.size * 0.5
	_etape.add_theme_font_size_override("font_size", roundi(30 * k))
	_etape.size = Vector2(v.x, 44 * k)
	_etape.position = Vector2(0, v.y * 0.47 + r * 1.45)
	var lc := minf(v.x * 0.62, 1300.0 * k)
	_citation.add_theme_font_size_override("font_size", roundi(31 * k))
	_citation.size = Vector2(lc, 0)
	_citation.custom_minimum_size = Vector2(lc, 0)
	_citation.position = Vector2(cx - lc * 0.5, v.y * 0.73)
	_auteur.add_theme_font_size_override("font_size", roundi(20 * k))
	_auteur.size = Vector2(v.x, 30 * k)
	_auteur.position = Vector2(0, v.y * 0.73 + 96 * k)
	var lb := minf(v.x * 0.36, 720.0 * k)
	_barre.size = Vector2(lb, 26 * k)
	_barre.position = Vector2(cx - lb * 0.5, v.y * 0.885)

## Lance le chargement de `scene_jeu` (ou rien en démo).
func demarrer() -> void:
	if demo:
		return
	Jeu.etapes_chargement = 0
	Jeu.etape_chargement = ""
	if ResourceLoader.load_threaded_request(scene_jeu, "", true) != OK:
		push_warning("Chargement en tâche de fond impossible, chargement direct : " + scene_jeu)
	_phase = "scene"

func _process(dt: float) -> void:
	_t += dt
	_t_citation += dt
	if _t_citation > DUREE_CITATION:
		_t_citation = 0.0
		_i_citation = (_i_citation + 1) % CITATIONS.size()
		_montrer_citation(true)
	match _phase:
		"scene":
			var p := []
			var st := ResourceLoader.load_threaded_get_status(scene_jeu, p)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_cible = 0.25 * float(p[0] if p.size() > 0 else 0.0)
			elif st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				var ps: PackedScene = ResourceLoader.load_threaded_get(scene_jeu) if st == ResourceLoader.THREAD_LOAD_LOADED else load(scene_jeu)
				if ps == null:
					push_error("Scène du monde illisible : " + scene_jeu)
					_phase = ""
					get_tree().change_scene_to_file(scene_jeu)
					return
				_entrer_monde(ps)
		"monde":
			_cible = 0.25 + 0.73 * clampf(float(Jeu.etapes_chargement) / ETAPES_MONDE, 0.0, 1.0)
			_etape.text = _libelle(Jeu.etape_chargement)
			if is_instance_valid(_monde) and _monde.get("pret") == true and Time.get_ticks_msec() - _debut > DUREE_MINI * 1000.0:
				_finir()
	if demo:
		_cible = fmod(_t * 0.12, 1.0)
	avancement = lerpf(avancement, _cible, 1.0 - exp(-6.0 * dt)) if _cible >= avancement else _cible
	_rune.queue_redraw()
	_barre.queue_redraw()

func _libelle(cle: String) -> String:
	var c := cle.to_lower()
	var res := _etape.text
	for e: Array in ETAPES:
		if c.contains(e[0]):
			res = e[1]
	return res

func _entrer_monde(ps: PackedScene) -> void:
	_phase = "monde"
	var arbre := get_tree()
	_monde = ps.instantiate()
	Jeu.chargement_etale = true
	arbre.paused = true
	get_viewport().disable_3d = true   # rien à voir derrière l'écran de chargement : pas de rendu 3D tant que le monde se bâtit
	arbre.root.add_child(_monde)        # Monde._ready rend la main à sa première étape (Monde._souffle)
	arbre.current_scene = _monde

func _finir() -> void:
	_phase = "fin"
	_cible = 1.0
	Jeu.chargement_etale = false
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(_noir, "modulate:a", 1.0, 0.45)
	await tw.finished
	# fenêtre rendue au jeu : rendu 640x360 agrandi d'un facteur entier (project.godot), rendu 3D, fin de la pause
	var w := get_window()
	if not echelle_jeu.is_empty():
		w.content_scale_mode = echelle_jeu["mode"]
		w.content_scale_aspect = echelle_jeu["aspect"]
		w.content_scale_size = echelle_jeu["taille"]
		w.content_scale_stretch = echelle_jeu["etirement"]
		w.content_scale_factor = echelle_jeu["facteur"]
	get_viewport().disable_3d = false
	get_tree().paused = false
	for c in _racine.get_children():
		if c != _noir:
			c.visible = false
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_noir, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	termine.emit()
	queue_free()

func _montrer_citation(fondu: bool) -> void:
	var c: Array = CITATIONS[_i_citation]
	var poser := func() -> void:
		_citation.text = ("« %s »" % c[0]) if c[1] != "" else c[0]
		_auteur.text = c[1]
	if not fondu:
		poser.call()
		return
	var tw := create_tween()
	tw.tween_property(_citation, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(_auteur, "modulate:a", 0.0, 0.5)
	tw.tween_callback(poser)
	tw.tween_property(_citation, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(_auteur, "modulate:a", 1.0, 0.7)

## Rune : anneau de 24 entailles qui tourne lentement, deux cercles, losange runique qui pulse au centre.
func _dessiner_rune() -> void:
	var s := _rune.size
	var c := s * 0.5
	var r := s.x / 2.6
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	var acier := Color(MenuStyle.ACIER, 0.85)
	_rune.draw_arc(c, r * 1.18, 0, TAU, 96, Color(MenuStyle.ACIER_SOMBRE, 0.9), maxf(1.0, r * 0.012), true)
	_rune.draw_arc(c, r * 0.98, 0, TAU, 96, Color(MenuStyle.LUEUR, 0.10 + 0.12 * pulse), maxf(2.0, r * 0.05), true)
	_rune.draw_arc(c, r * 0.98, 0, TAU, 96, acier, maxf(1.0, r * 0.014), true)
	var a0 := _t * 0.35
	for i in 24:
		var a := a0 + TAU * i / 24.0
		var d := Vector2(cos(a), sin(a))
		var long := 0.16 if i % 3 == 0 else 0.08
		var col := acier.lerp(MenuStyle.LUEUR, pulse * (0.6 if i % 3 == 0 else 0.2))
		_rune.draw_line(c + d * r * 1.02, c + d * r * (1.02 + long), col, maxf(1.0, r * 0.02), true)
	# arc lumineux qui court sur l'anneau (indicateur d'activité)
	var b := -_t * 1.6
	for k in 12:
		_rune.draw_arc(c, r * 0.98, b + k * 0.06, b + (k + 1) * 0.06, 6, Color(MenuStyle.LUEUR.lerp(Color.WHITE, 0.3), 0.08 * k), maxf(2.0, r * 0.03), true)
	MenuStyle.dessiner_losange(_rune, c, r * 0.55, 0.45 + 0.55 * pulse)

## Barre : cadre d'acier, remplissage bleu avec reflet, petit losange au bout.
func _dessiner_barre() -> void:
	var s := _barre.size
	var h := s.y * 0.32
	var y := (s.y - h) * 0.5
	var cadre := Rect2(0, y, s.x, h)
	_barre.draw_rect(cadre, Color(0.02, 0.03, 0.045, 0.9))
	var w := (s.x - 4) * clampf(avancement, 0.0, 1.0)
	if w > 0.5:
		_barre.draw_rect(Rect2(2, y + 2, w, h - 4), Color(MenuStyle.LUEUR, 0.75))
		_barre.draw_rect(Rect2(2, y + 2, w, (h - 4) * 0.4), Color(1, 1, 1, 0.18))
		_barre.draw_rect(Rect2(2, y - 3, w, h + 6), Color(MenuStyle.LUEUR, 0.08))
	_barre.draw_rect(cadre, MenuStyle.ACIER, false, 1.0)
	MenuStyle.dessiner_losange(_barre, Vector2(2 + w, s.y * 0.5), s.y * 0.45, 0.8)
	MenuStyle.dessiner_losange(_barre, Vector2(-s.y * 0.7, s.y * 0.5), s.y * 0.3, 0.0)
	MenuStyle.dessiner_losange(_barre, Vector2(s.x + s.y * 0.7, s.y * 0.5), s.y * 0.3, 0.0)

## Pendant le chargement, rien ne passe au monde (Tab, Échap, souris…) ; F11 reste à la fenêtre (Fenetre, autoload).
func _input(e: InputEvent) -> void:
	if _phase != "" and not (e is InputEventKey and (e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed))):
		get_viewport().set_input_as_handled()
