class_name EcranNiveau
extends Control
## Annonces de progression (lot D), enfant du HUD (hud.gd) :
## - « Niveau supérieur » : feuille de vélin au bord rongé en haut de l'écran, grand sceau de cire rouge portant le niveau,
##   rubans, titre gothique à l'encre, filet, rappel des gains (point d'arbre, attribut à choisir : Tab › Personnage).
##   ~4,5 s, fondu ; ne met PAS le jeu en pause (le choix d'attribut se fait dans l'onglet Personnage).
## - Gains de compétence : petite bande de vélin discrète à droite (nom en rubrique, niveau, barre), ~3 s ; au plus 3 à la fois,
##   la même compétence met sa bande à jour au lieu d'en empiler une autre.
## Tout est figé (et caché) quand le jeu est en pause ou que le panneau du HUD est ouvert, comme les annonces du HUD.
## Captures : figer = true garde l'annonce opaque.

const DUREE_NIVEAU := 4.5
const DUREE_COMPETENCE := 3.0
const MAX_BANDES := 3
const TAILLE_FEUILLE := Vector2i(300, 74)
const TAILLE_BANDE := Vector2i(150, 26)

var joueur: Node = null
var figer := false
var _niveaux: Array = []          ## [niveau, temps écoulé] (file)
var _bandes: Array = []           ## [nom canonique, niveau, temps écoulé]
var _police: FontFile
var _gothique: FontFile
var _feuille: ImageTexture
var _bande: ImageTexture
var _sceau: ImageTexture

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	_feuille = ImageTexture.create_from_image(Parchemin.feuille(TAILLE_FEUILLE, 11))
	_bande = ImageTexture.create_from_image(Parchemin.feuille(TAILLE_BANDE, 23))
	_sceau = ImageTexture.create_from_image(Parchemin.sceau(19, 5))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Un niveau de personnage gagné (Progression.niveau_perso).
func annoncer_niveau(n: int) -> void:
	_niveaux.append([n, 0.0])
	if _niveaux.size() > 3:
		_niveaux.remove_at(1)
	Sons.jouer(self, ["sword-unsheathe"], -6.0)
	queue_redraw()

## Une compétence montée (Progression.niveau_competence, nom canonique ; un nom interne « epee » est accepté).
func annoncer_competence(nom: String, niveau: int) -> void:
	nom = Progression.canonique(nom)
	for b: Array in _bandes:
		if b[0] == nom:
			b[1] = niveau
			b[2] = minf(b[2], 0.2)
			queue_redraw()
			return
	_bandes.append([nom, niveau, 0.0])
	if _bandes.size() > MAX_BANDES:
		_bandes.pop_front()
	Sons.jouer(self, ["sword-unsheathe"], -14.0)
	queue_redraw()

## Textes en cours (tests) : « Niveau supérieur|9 » ou "".
func niveau_courant() -> String:
	return "" if _niveaux.is_empty() else "Niveau supérieur|%d" % int(_niveaux[0][0])

## Bandes de compétence affichées (tests) : [« Une main 17 », …].
func bandes() -> Array:
	return _bandes.map(func(b: Array) -> String: return "%s %d" % [Parchemin.nom_competence(b[0]), int(b[1])])

func _cache() -> bool:
	var h := get_parent()
	return get_tree().paused or (h != null and bool(h.get("panneau_ouvert")))

func _process(dt: float) -> void:
	if _niveaux.is_empty() and _bandes.is_empty():
		return
	if _cache():
		queue_redraw()
		return
	if not figer:
		if not _niveaux.is_empty():
			_niveaux[0][1] += dt
			if _niveaux[0][1] >= DUREE_NIVEAU:
				_niveaux.pop_front()
		for b: Array in _bandes:
			b[2] += dt
		_bandes = _bandes.filter(func(b: Array) -> bool: return b[2] < DUREE_COMPETENCE)
	queue_redraw()

func _alpha(t: float, duree: float, entree := 0.3, sortie := 0.7) -> float:
	if figer:
		return 1.0
	return clampf(minf(t / entree, (duree - t) / sortie), 0.0, 1.0)

func _draw() -> void:
	if _cache():
		return
	if not _niveaux.is_empty():
		_dessiner_niveau(_niveaux[0])
	for i in _bandes.size():
		_dessiner_bande(_bandes[i], i)

## La feuille « Niveau supérieur » centrée en haut (sous la boussole, au-dessus des annonces du HUD qui commencent à y ≈ 104).
func _dessiner_niveau(n: Array) -> void:
	var a := _alpha(n[1], DUREE_NIVEAU)
	if a <= 0.01:
		return
	var glisse := 0.0 if figer else (1.0 - clampf(n[1] / 0.3, 0.0, 1.0)) * -6.0
	var p := Vector2(floorf((size.x - TAILLE_FEUILLE.x) * 0.5), 28.0 + roundf(glisse))
	var m := Color(1, 1, 1, a)
	# ombre portée douce sur le jeu (un rectangle sombre décalé)
	draw_rect(Rect2(p + Vector2(3, 3), Vector2(TAILLE_FEUILLE) - Vector2(2, 2)), Color(0, 0, 0, 0.35 * a))
	draw_texture(_feuille, p, m)
	# filet intérieur à l'encre (double trait pâle)
	draw_rect(Rect2(p + Vector2(6, 5), Vector2(TAILLE_FEUILLE) - Vector2(12, 10)), Color(Parchemin.PALE, 0.8 * a), false, 1.0)
	# rubans sous le sceau, puis le sceau à cheval sur le bord gauche
	var sc := p + Vector2(-8, 12)
	var cs := sc + _sceau.get_size() * 0.5
	for k in [-1, 1]:
		for y in 20:
			var x: float = cs.x + k * (3 + y * 0.35)
			draw_rect(Rect2(roundf(x) - 3, cs.y + 10 + y, 6, 1), Color(Parchemin.RUBRIQUE if y < 18 else Parchemin.RUBRIQUE_SOMBRE, a))
	draw_texture(_sceau, sc, m)
	var s := str(int(n[0]))
	var tl := Parchemin.largeur(_police, s, 32)
	draw_string(_police, Vector2(roundf(cs.x - tl * 0.5) + 1, cs.y + 12), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(Parchemin.RUBRIQUE_SOMBRE, a))
	draw_string(_police, Vector2(roundf(cs.x - tl * 0.5), cs.y + 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(Parchemin.OR_CLAIR, a))
	# titre, filet, gains
	var x0 := p.x + 52.0
	var lt := Parchemin.largeur(_gothique, "Niveau supérieur", Parchemin.TITRE)
	var cx := roundf(x0 + (TAILLE_FEUILLE.x - 60.0 - lt) * 0.5)
	draw_string(_gothique, Vector2(cx, p.y + 29), "Niveau supérieur", HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TITRE, Color(Parchemin.ENCRE, a))
	var fl := Vector2(x0 + 10, p.y + 36)
	draw_rect(Rect2(fl, Vector2(TAILLE_FEUILLE.x - 80, 1)), Color(Parchemin.PALE, a))
	for c: float in [fl.x - 3.0, fl.x + TAILLE_FEUILLE.x - 78.0]:
		draw_rect(Rect2(c - 1, fl.y - 1, 3, 3), Color(Parchemin.RUBRIQUE, a))
	var pr = joueur.get("progression") if joueur != null else null
	var gains := "Niveau %d · +1 point d'arbre · +1 attribut" % int(n[0])
	var rappel := "Tab › Personnage : graver ton choix"
	if pr is Progression and (pr as Progression).points_attribut > 1:
		rappel = "Tab › Personnage : %d choix en attente" % (pr as Progression).points_attribut
	var lg := Parchemin.largeur(_police, gains)
	draw_string(_police, Vector2(roundf(x0 + (TAILLE_FEUILLE.x - 60.0 - lg) * 0.5), p.y + 51), gains, HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TAILLE, Color(Parchemin.ENCRE, a))
	var lr := Parchemin.largeur(_police, rappel)
	draw_string(_police, Vector2(roundf(x0 + (TAILLE_FEUILLE.x - 60.0 - lr) * 0.5), p.y + 63), rappel, HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TAILLE, Color(Parchemin.RUBRIQUE, a))

## Bande discrète d'un gain de compétence, à droite (sous le cartouche d'aide du HUD), glisse depuis le bord.
func _dessiner_bande(b: Array, i: int) -> void:
	var a := _alpha(b[2], DUREE_COMPETENCE, 0.2, 0.5)
	if a <= 0.01:
		return
	var glisse := 0.0 if figer else (1.0 - clampf(b[2] / 0.2, 0.0, 1.0)) * 40.0
	var p := Vector2(size.x - TAILLE_BANDE.x - 10 + roundf(glisse), 132.0 + i * (TAILLE_BANDE.y + 4))
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(TAILLE_BANDE) - Vector2(2, 2)), Color(0, 0, 0, 0.3 * a))
	draw_texture(_bande, p, Color(1, 1, 1, a))
	draw_string(_police, p + Vector2(9, 13), Parchemin.nom_competence(b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TAILLE, Color(Parchemin.RUBRIQUE, a))
	var s := str(int(b[1]))
	draw_string(_police, p + Vector2(TAILLE_BANDE.x - 9 - Parchemin.largeur(_police, s), 13), s, HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TAILLE, Color(Parchemin.ENCRE, a))
	var part := _part(b[0])
	var r := Rect2(p + Vector2(9, 17), Vector2(TAILLE_BANDE.x - 18, 4))
	draw_rect(r, Color(Parchemin.ENCRE, a))
	draw_rect(r.grow(-1), Color(Parchemin.FOND_BARRE, a))
	draw_rect(Rect2(r.position + Vector2.ONE, Vector2(roundf((r.size.x - 2) * part), 2)), Color(Parchemin.BOIS, a))

func _part(nom: String) -> float:
	if joueur == null:
		return 0.0
	var c = joueur.get("competences")
	var i := Progression.interne(nom)
	if c is Competences and (c as Competences).niveaux.has(i):
		return clampf((c as Competences).progression(i), 0.0, 1.0)
	return 0.0
