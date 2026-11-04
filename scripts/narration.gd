class_name Narration
extends Control
## Écran de texte plein cadre : prologue de la nouvelle partie et fin du premier chapitre (textes : data/quetes.json "textes").
## Quelques pages sobres sur le monde assombri (le feu continue de brûler derrière) : E / Espace / Entrée / clic = page suivante,
## Échap = passer. Pendant l'écran, le joueur est « en dialogue » (ni marche ni combat), le jeu n'est PAS mis en pause.
## `fini` est émis à la dernière page (ou en passant) ; l'écran se retire alors tout seul.

signal fini

const FOND := Color("#0b0f1a")
const PARCHEMIN := Color("#e8e0c8")
const OR := Color("#e8a64a")
const GRIS := Color("#6d7488")
const LARGEUR_TEXTE := 320.0
const FONDU_ENTREE := 0.9
const FONDU_PAGE := 0.7

var joueur: CharacterBody3D
var titre := ""
var sous_titre := ""
var pages: Array = []
var page := 0
var actif := false

var _t := 0.0          # temps depuis le début de la page
var _entree := 0.0     # fondu d'entrée de tout l'écran
var _sortie := -1.0    # >= 0 : fondu de sortie en cours
var _police: FontFile
var _gothique: FontFile

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	visible = false

## Ouvre l'écran. `pages` : tableau de textes (un par page).
func lancer(titre_: String, pages_: Array, sous_titre_ := "") -> void:
	titre = titre_
	sous_titre = sous_titre_
	pages = pages_
	page = 0
	_t = 0.0
	_entree = 0.0
	_sortie = -1.0
	actif = not pages.is_empty()
	visible = actif
	if actif and joueur != null:
		joueur.en_dialogue = true
	if not actif:
		fini.emit()

func _unhandled_input(e: InputEvent) -> void:
	if not actif or _sortie >= 0.0:
		return
	var suivant := false
	if e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).physical_keycode:
			KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				suivant = true
			KEY_ESCAPE:
				_terminer()
				get_viewport().set_input_as_handled()
				return
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		suivant = true
	if suivant:
		get_viewport().set_input_as_handled()
		if _t < 0.5:
			return   # un appui parti trop tôt n'avale pas la page
		page += 1
		_t = 0.0
		if page >= pages.size():
			_terminer()

func _terminer() -> void:
	_sortie = 0.0

func _process(dt: float) -> void:
	if not actif:
		return
	EchelleUi.appliquer(self)
	_t += dt
	_entree = minf(1.0, _entree + dt / FONDU_ENTREE)
	if _sortie >= 0.0:
		_sortie += dt
		if _sortie >= 0.6:
			actif = false
			visible = false
			if joueur != null:
				joueur.en_dialogue = false
			fini.emit()
			return
	queue_redraw()

## Opacité globale de l'écran (0 = absent).
func opacite() -> float:
	if not actif:
		return 0.0
	return _entree * (1.0 - clampf(_sortie / 0.6, 0.0, 1.0)) if _sortie >= 0.0 else _entree

func texte_courant() -> String:
	return String(pages[mini(page, pages.size() - 1)]) if not pages.is_empty() else ""

func _draw() -> void:
	if not actif:
		return
	var a := opacite()
	draw_rect(Rect2(Vector2.ZERO, size), Color(FOND, 0.84 * a))
	var cx := floorf(size.x * 0.5)
	var y := floorf(size.y * 0.5) - 62.0
	var lt := _gothique.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x
	MenuStyle.texte_detoure(self, _gothique, Vector2(roundf(cx - lt * 0.5), y), titre, MenuStyle.TITRE_GRAND, OR, a)
	MenuStyle.dessiner_filet(self, cx, y + 8.0, 70.0, a)
	if sous_titre != "":
		var ls := _police.get_string_size(sous_titre, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x
		MenuStyle.texte_detoure(self, _police, Vector2(roundf(cx - ls * 0.5), y + 22.0), sous_titre, Palette.TAILLE_POLICE, MenuStyle.GRIS, a)
	var ap := a * clampf(_t / FONDU_PAGE, 0.0, 1.0)
	var texte := texte_courant()
	var pos := Vector2(roundf(cx - LARGEUR_TEXTE * 0.5), y + 42.0)
	draw_multiline_string(_police, pos + Vector2(1, 1), texte, HORIZONTAL_ALIGNMENT_CENTER, LARGEUR_TEXTE, Palette.TAILLE_POLICE, -1, Color(FOND, ap))
	draw_multiline_string(_police, pos, texte, HORIZONTAL_ALIGNMENT_CENTER, LARGEUR_TEXTE, Palette.TAILLE_POLICE, -1, Color(PARCHEMIN, ap))
	var pied := "E : continuer   Échap : passer   (%d / %d)" % [mini(page + 1, pages.size()), pages.size()]
	var lp := _police.get_string_size(pied, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x
	MenuStyle.texte_detoure(self, _police, Vector2(roundf(cx - lp * 0.5), size.y - 44.0), pied, Palette.TAILLE_POLICE, GRIS, a * clampf((_t - 1.2) / 0.6, 0.0, 1.0))
