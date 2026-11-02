class_name ApercuObjet
extends TextureRect
## APERÇU 3D TOURNANT de l'objet choisi dans une fiche du menu (Sac, Équipement ; comme l'inventaire de Skyrim) : un RenduObjet
## (scripts/rendu_objet.gd : SubViewport à monde propre, fond transparent, rendu PS1) affiché 1:1 dans un cadre de vélin. Il tourne
## lentement ; glisser à la souris (ou stick droit de la manette) pour le faire tourner à la main, il reprend seul ensuite.
## COÛT NUL MENU FERMÉ : le studio n'existe que tant que l'aperçu est visible (onglet affiché, menu ouvert) ; caché, il est libéré.
## Usage (dans le _draw d'un onglet) :
##   if not _apercu.placer(Rect2(x, y, 64, 64), id): <dessiner l'icône à la place>   # false : pas de modèle 3D
##   _apercu.cacher()                                                               # rien à montrer
## Le cadre (MenuStyle.cadre_apercu) est dessiné par l'onglet ; l'aperçu occupe l'intérieur.

const TOUR := 0.7            # rad / s
const REPRISE := 1.6         # s sans toucher avant que le tour reprenne
const ZONE_MORTE := 0.22

var id := ""
var rendu: RenduObjet = null
var _glisse := false
var _repos := 0.0

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	visible = false
	set_process(false)

## Montre `oid` dans `r` (coordonnées du parent) ; false si l'objet n'a pas de modèle 3D (l'appelant dessine son icône).
func placer(r: Rect2, oid: String) -> bool:
	if oid == "" or not ObjetMonde.a_modele(IconesObjets.cle(oid)):
		cacher()
		return false
	position = r.position
	size = r.size
	visible = true
	if rendu == null or rendu.size != Vector2i(r.size):
		_liberer()
		_creer(Vector2i(r.size))
	if oid != id or rendu.id == "":
		id = oid
		_montrer()
	return true

func cacher() -> void:
	if visible:
		visible = false

func _creer(taille: Vector2i) -> void:
	rendu = RenduObjet.creer(taille)
	rendu.name = "Studio"
	add_child(rendu)
	texture = rendu.get_texture()
	set_process(true)

func _montrer() -> void:
	var o := IconesObjets.cle(id)
	rendu.montrer(o)
	if o in RenduObjet.RETOURNES:
		rendu.orienter(Basis(Vector3.RIGHT, PI))
	var a := RenduObjet.angles_pour(o)
	rendu.lacet = a.x
	rendu.tangage = clampf(a.y, -0.75, -0.3)
	rendu.marge = 0.95
	rendu.cadrer()
	rendu.tourner = TOUR

func _liberer() -> void:
	if rendu != null:
		rendu.queue_free()
		rendu = null
		texture = null
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_liberer()      # menu fermé ou autre onglet : plus de SubViewport, plus de rendu
		id = ""
	elif what == NOTIFICATION_PREDELETE:
		rendu = null

func _gui_input(e: InputEvent) -> void:
	if rendu == null:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_glisse = (e as InputEventMouseButton).pressed
		rendu.tourner = 0.0
		_repos = 0.0
		accept_event()
	elif e is InputEventMouseMotion and _glisse:
		var m := e as InputEventMouseMotion
		tourner_de(m.relative.x * 0.045, m.relative.y * 0.02)
		accept_event()

## Tourne à la main (rad) : lacet autour de la verticale, tangage borné.
func tourner_de(d_lacet: float, d_tangage := 0.0) -> void:
	if rendu == null:
		return
	rendu.tourner = 0.0
	_repos = 0.0
	rendu.lacet += d_lacet
	rendu.tangage = clampf(rendu.tangage + d_tangage, -1.35, 0.35)
	rendu.cadrer()

func _process(dt: float) -> void:
	if rendu == null:
		return
	var sx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var sy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(sx) > ZONE_MORTE or absf(sy) > ZONE_MORTE:
		tourner_de((sx if absf(sx) > ZONE_MORTE else 0.0) * 3.0 * dt, (sy if absf(sy) > ZONE_MORTE else 0.0) * 1.5 * dt)
		return
	if rendu.tourner == 0.0 and not _glisse:
		_repos += dt
		if _repos > REPRISE:
			rendu.tourner = TOUR
