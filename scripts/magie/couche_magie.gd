class_name CoucheMagie
extends Node
## Couche FINE de la magie (option « Détail des sorts », docs/MAGIE_EFFETS.md) : les visuels de GestionMagie (calque de
## rendu 19) sont dessinés dans un SubViewport à la résolution de l'écran par une caméra calée chaque image sur celle du
## joueur, puis posés par-dessus le monde (shaders/magie_compose.gdshader), AVANT le post-traitement ps1 (qui les étalonne
## et les réduit en 15 bits comme le reste). Le monde, lui, reste en 640x360 : la fenêtre passe en échelle CANVAS_ITEMS
## (interface identique) et la 3D de la fenêtre est rendue à 1/k en plus proche voisin (SCALING_3D_MODE_NEAREST).
## Occlusion : ProfondeurMagie copie la profondeur du monde ; shaders/magie_occ.gdshaderinc cache les fragments derrière.
##   Élevé : pixel de magie = pixel de l'écran (1/2 du pixel du monde en 1280x720, 1/3 en 1920x1080, au plus 1/4)
##   Moyen : pixel de magie = 1/2 pixel du monde
##   Rétro : rendu d'avant (tout en 640x360, couche fine éteinte)
## La couche ne dessine RIEN quand aucun effet n'est visible (SubViewport à l'arrêt) : coût nul hors combat... sauf
## l'échelle de la fenêtre, gardée (basculer à chaque sort ferait sauter l'image).

const CALQUE := 1 << 18          # calque de rendu 19 : visuels de la magie (GestionMagie)
const RETRO := 0
const MOYEN := 1
const ELEVE := 2
const NOMS := ["retro", "moyen", "eleve"]
const SH_COMPOSE := preload("res://shaders/magie_compose.gdshader")

## Niveau imposé par un outil (galerie) ; -1 = option du joueur / argument --detail-sorts=retro|moyen|eleve.
static var niveau_force := -1

var niveau := RETRO
## Facteur entier écran / monde (2 en 1280x720) et facteur de la couche fine (pixels de magie par pixel du monde).
var k := 1
var m := 1
var actif := false
var vp: SubViewport
var cam: Camera3D
var profondeur: ProfondeurMagie
var _calque: CanvasLayer
var _rect: TextureRect
var _cam_monde: Camera3D
var _compositor_ajoute: Compositor
var _bascule := false            # c'est NOUS qui avons mis la fenêtre en CANVAS_ITEMS
var _env: Environment
var _env_source: Environment
var _vue_prec := Transform3D.IDENTITY
var _utile := false              # au moins un visuel de magie à l'écran (GestionMagie.demander_couche)
var _utile_t := 0.0

static func niveau_voulu() -> int:
	if niveau_force >= 0:
		return niveau_force
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--detail-sorts="):
			var i := NOMS.find(a.substr(15))
			if i >= 0:
				return i
	if Jeu.mode_outil():
		return RETRO   # outils et tests : images comparables d'un lancement à l'autre (la galerie impose ELEVE)
	return clampi(int(Jeu.option("affichage", "detail_sorts")), RETRO, ELEVE)

static func possible() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() != null

func _init() -> void:
	regler(niveau_voulu())

func _ready() -> void:
	process_priority = 1000
	RenderingServer.frame_pre_draw.connect(_avant_rendu)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_avant_rendu):
		RenderingServer.frame_pre_draw.disconnect(_avant_rendu)
	_eteindre()

## Change de niveau (menu des options : Jeu.regler puis GestionMagie.instance.couche.regler).
func regler(n: int) -> void:
	niveau = n if possible() else RETRO
	if niveau == RETRO:
		_eteindre()
	elif vp == null:
		_creer()

## Pixels de la couche par pixel du monde, pour le niveau courant et la taille de fenêtre courante.
func facteur_couche() -> int:
	if niveau == ELEVE:
		return clampi(k, 2, 4)
	if niveau == MOYEN:
		return 2
	return 1

## Appelé par GestionMagie quand un visuel existe (la couche se met en veille 0,5 s après le dernier).
func demander() -> void:
	_utile = true
	_utile_t = 0.5

func _creer() -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre != null:
		var w := arbre.root
		var t := Vector2(w.size)
		var b := Vector2(w.content_scale_size)
		k = maxi(1, int(minf(t.x / maxf(b.x, 1.0), t.y / maxf(b.y, 1.0)) + 0.01))
	vp = SubViewport.new()
	vp.name = "CoucheMagie"
	vp.transparent_bg = true
	vp.use_hdr_2d = true            # sortie linéaire HDR : magie_compose fait le passage en sRVB (cœurs chauffés à blanc)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.positional_shadow_atlas_size = 0
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(640, 360)
	add_child(vp)
	cam = Camera3D.new()
	cam.cull_mask = CALQUE
	vp.add_child(cam)
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = _env
	cam.current = true
	_calque = CanvasLayer.new()
	_calque.layer = 0                 # sous le post-traitement ps1 (calque 1) : la magie est étalonnée avec le monde
	add_child(_calque)
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.texture = vp.get_texture()
	var mat := ShaderMaterial.new()
	mat.shader = SH_COMPOSE
	_rect.material = mat
	_rect.visible = false
	_calque.add_child(_rect)
	profondeur = ProfondeurMagie.new()
	RenderingServer.global_shader_parameter_set("magie_prof", profondeur.texture)

func _eteindre() -> void:
	actif = false
	RenderingServer.global_shader_parameter_set("magie_occ", 0.0)
	RenderingServer.global_shader_parameter_set("magie_pas", 1.0)
	_detacher_compositor()
	if profondeur != null:
		profondeur.finir()
		profondeur = null
	if _cam_monde != null and is_instance_valid(_cam_monde):
		_cam_monde.cull_mask |= CALQUE
	_cam_monde = null
	var w := get_tree().root if is_inside_tree() else null
	if w != null and _bascule:
		if w.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
			w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		w.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		w.scaling_3d_scale = 1.0
	_bascule = false
	if vp != null:
		vp.queue_free()
		_calque.queue_free()
		vp = null
		cam = null
		_calque = null
		_rect = null

func _detacher_compositor() -> void:
	if _compositor_ajoute != null and profondeur != null:
		var effets := _compositor_ajoute.compositor_effects
		effets.erase(profondeur)
		_compositor_ajoute.compositor_effects = effets
	if _cam_monde != null and is_instance_valid(_cam_monde) and _cam_monde.compositor == _compositor_ajoute and _compositor_ajoute != null and _compositor_ajoute.compositor_effects.is_empty():
		_cam_monde.compositor = null
	_compositor_ajoute = null

## Juste avant le rendu de l'image (après tous les _process : caméra et mains posées) : échelle de la fenêtre, caméra
## de la couche calée sur celle du monde, profondeur de l'image précédente, veille.
func _avant_rendu() -> void:
	if vp == null or not is_inside_tree():
		return
	var w := get_tree().root
	# la fenêtre est en échelle « jeu » (VIEWPORT, project.godot) : on la passe en CANVAS_ITEMS ; l'écran titre et
	# l'écran de chargement (DISABLED, haute définition) ne sont jamais touchés
	if w.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		_bascule = true
	if w.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS or not _bascule:
		_veille(w)
		return
	var base := Vector2(w.content_scale_size)
	var cible := Vector2(w.get_texture().get_size())   # image de la fenêtre (zone utile, sans les bandes noires)
	k = maxi(1, int(minf(cible.x / base.x, cible.y / base.y) + 0.01))
	# 3D de la fenêtre : exactement la taille de base (640x360), agrandie en plus proche voisin
	w.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	w.scaling_3d_scale = clampf(base.y / maxf(cible.y, 1.0), 0.1, 1.0)
	RenderingServer.global_shader_parameter_set("magie_pas", cible.y / base.y)
	m = facteur_couche()
	if k < 2:
		_veille(w)   # fenêtre 640x360 : rien de plus fin à gagner
		return
	var c := w.get_camera_3d()
	if c != _cam_monde:
		if _cam_monde != null and is_instance_valid(_cam_monde):
			_cam_monde.cull_mask |= CALQUE
		_detacher_compositor()
		_cam_monde = c
		if c != null:
			if c.compositor == null:
				c.compositor = Compositor.new()
			_compositor_ajoute = c.compositor
			var effets := _compositor_ajoute.compositor_effects
			if not effets.has(profondeur) and not OS.get_cmdline_user_args().has("--sans-occlusion"):
				effets.append(profondeur)
				_compositor_ajoute.compositor_effects = effets
	if c == null:
		_veille(w)
		return
	c.cull_mask &= ~CALQUE
	_utile_t -= get_process_delta_time()
	if not _utile and _utile_t <= 0.0:
		_veille(w)
		return
	_utile = false
	var taille := Vector2i(int(base.x) * m, int(base.y) * m)
	if vp.size != taille:
		vp.size = taille
	cam.global_transform = c.global_transform
	cam.projection = c.projection
	cam.fov = c.fov
	cam.size = c.size
	cam.near = c.near
	cam.far = c.far
	cam.keep_aspect = c.keep_aspect
	cam.h_offset = c.h_offset
	cam.v_offset = c.v_offset
	cam.frustum_offset = c.frustum_offset
	_copier_tonemap(c)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rect.visible = true
	actif = true
	var occ := profondeur.pret() and profondeur.copies > 0
	RenderingServer.global_shader_parameter_set("magie_occ", 1.0 if occ else 0.0)
	RenderingServer.global_shader_parameter_set("magie_vue_prec", Projection(profondeur.vue.affine_inverse()))
	RenderingServer.global_shader_parameter_set("magie_echelle", float(m))

## La couche fine dessine-t-elle les sorts (sinon ils restent dans le rendu du monde) ?
func fine() -> bool:
	if niveau == RETRO or k < 2:
		return false
	var arbre := Engine.get_main_loop() as SceneTree
	return _bascule or (arbre != null and arbre.root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)

func _veille(w: Window) -> void:
	actif = false
	# sorts éventuels dessinés par le monde (la caméra les exclut de nouveau dès que la couche reprend, même image)
	if _cam_monde != null and is_instance_valid(_cam_monde):
		_cam_monde.cull_mask |= CALQUE
	if vp != null:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _rect != null:
		_rect.visible = false
	RenderingServer.global_shader_parameter_set("magie_occ", 0.0)
	if not _bascule or w.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		if _bascule:
			w.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			w.scaling_3d_scale = 1.0
			RenderingServer.global_shader_parameter_set("magie_pas", 1.0)

## Exposition du monde reprise par la couche (même luminosité que les sorts du mode rétro).
func _copier_tonemap(c: Camera3D) -> void:
	var src: Environment = c.environment
	if src == null:
		var we := c.get_world_3d().environment if c.get_world_3d() != null else null
		src = we
	if src == _env_source:
		return
	_env_source = src
	if src != null:
		_env.tonemap_exposure = src.tonemap_exposure
