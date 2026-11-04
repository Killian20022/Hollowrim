class_name Aides
extends Control
## Bulles d'aide contextuelles : chacune apparaît UNE SEULE FOIS, au moment où elle sert (premier ennemi, premier sort en main,
## premier coffre, menu et carte). Le cartouche des touches, lui, reste celui du HUD (hud.demarrer / F1).
## - Désactivables : Options → « Bulles d'aide » (Jeu.option("jeu", "aides")).
## - État sauvegardé : `vues` (clés déjà montrées) dans la sauvegarde (monde.gd, clé « aides_vues »). Une partie d'avant cette clé
##   est une partie de vétéran : monde.gd appelle tout_vu() et rien ne s'affiche.
## - Rien ne s'affiche pendant un dialogue, un menu, la pause ni après la mort ; les bulles se suivent avec un temps de répit.
## Textes : TEXTES. Ajouter une aide = une entrée + une condition dans _sonder().

const DUREE := 7.0
const REPIT := 3.0        # secondes entre deux bulles
const DELAI_MENU := 45.0  # le rappel « menu / carte » arrive après ce temps de jeu actif
const LARGEUR := 250.0
const FOND := Color("#0b0f1a")
const PARCHEMIN := Color("#e8e0c8")
const OR := Color("#e8a64a")

const TEXTES := {
	"ennemi": ["Premier combat", "Clic gauche : frapper. Clic droit : garde. Recule quand ta vie baisse : mieux vaut fuir que mourir."],
	"sort": ["Magie", "Un sort est en main. Maintiens le clic pour le charger, relâche pour le lancer. Le mana revient tout seul. Les touches 1 à 0 changent de sorts."],
	"coffre": ["Coffre", "E : ouvrir, puis choisis ce que tu emportes. Le sac a une limite de poids : trop chargé, tu ralentis."],
	"menu": ["Menu et carte", "Tab : sac, magie, compétences, journal des quêtes et carte du royaume. F1 : rappel des touches."],
}

var hud: Control
var joueur: CharacterBody3D
var dialogue: Control      # invite d'action (E) : détecte le premier coffre
var vues := {}
var actif := false         # posé par monde.gd une fois la partie prête (et le prologue fini)

var _file: Array = []      # clés en attente
var _cle := ""             # bulle à l'écran
var _t := 0.0
var _repit := 0.0
var _jeu_actif := 0.0      # secondes de jeu « libre » depuis le début
var _sonde_t := 0.0
var _police: FontFile
var _gothique: FontFile
var _cadre: StyleBoxTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	_cadre = MenuStyle.cadre_orne()

func exporter() -> Array:
	return vues.keys()

func importer(cles: Array) -> void:
	vues = {}
	for c in cles:
		vues[String(c)] = true

## Partie d'avant les aides : rien à expliquer à un joueur qui connaît déjà le jeu.
func tout_vu() -> void:
	for c in TEXTES:
		vues[c] = true

static func activees() -> bool:
	return bool(Jeu.option("jeu", "aides"))

## Met une aide en file si elle est active, jamais vue et pas déjà en attente. Renvoie vrai si elle est mise en file.
func proposer(cle: String) -> bool:
	if not TEXTES.has(cle) or vues.has(cle) or _file.has(cle) or _cle == cle or not activees():
		return false
	_file.append(cle)
	return true

func cle_courante() -> String:
	return _cle

func _libre() -> bool:
	if joueur == null or joueur.mort or bool(joueur.get("en_dialogue")) or get_tree().paused:
		return false
	return hud == null or not bool(hud.get("panneau_ouvert"))

func _process(dt: float) -> void:
	EchelleUi.appliquer(self)
	if not actif:
		return
	if not _libre():
		queue_redraw()
		return
	_jeu_actif += dt
	_sonde_t -= dt
	if _sonde_t <= 0.0:
		_sonde_t = 0.25
		_sonder()
	if _cle != "":
		_t += dt
		if _t >= DUREE:
			_cle = ""
			_repit = REPIT
	elif not _file.is_empty():
		_repit = maxf(0.0, _repit - dt)
		if _repit <= 0.0:
			_cle = _file.pop_front()
			vues[_cle] = true
			_t = 0.0
	queue_redraw()

## Conditions d'apparition (appelée 4 fois par seconde).
func _sonder() -> void:
	if not activees():
		return
	if hud != null and hud.has_method("cible_actuelle") and hud.cible_actuelle() != null:
		proposer("ennemi")
	if _sort_en_main():
		proposer("sort")
	if dialogue != null and dialogue.has_method("invite_courante"):
		var p: Node3D = dialogue.invite_courante()
		var verbe: Variant = p.get("verbe") if p != null else null   # un villageois n'a pas de « verbe »
		if verbe is String and (verbe as String).to_lower().contains("coffre"):
			proposer("coffre")
	if _jeu_actif >= DELAI_MENU:
		proposer("menu")

func _sort_en_main() -> bool:
	var m: Variant = joueur.mains.get("magie") if joueur != null and joueur.get("mains") != null else null
	if m == null or not (m.get("eq") is EquipementMains):
		return false
	var eq: EquipementMains = m.eq
	for main: String in ["gauche", "droite"]:
		if String((eq.mains[main] as Dictionary).get("categorie", "")) == "sort":
			return true
	return false

## Opacité de la bulle (fondu 0,3 s en entrée, 0,6 s en sortie).
func alpha() -> float:
	if _cle == "":
		return 0.0
	return clampf(minf(_t / 0.3, (DUREE - _t) / 0.6), 0.0, 1.0)

func _draw() -> void:
	var a := alpha()
	if a <= 0.01 or not _libre():
		return
	var titre: String = TEXTES[_cle][0]
	var texte: String = TEXTES[_cle][1]
	var taille_texte := _police.get_multiline_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, LARGEUR, Palette.TAILLE_POLICE)
	var t := Vector2(LARGEUR + 28.0, ceilf(taille_texte.y) + 52.0)
	var o := Vector2(floorf((size.x - t.x) * 0.5), floorf(size.y - t.y - 62.0))
	_cadre.modulate_color = Color(1, 1, 1, a)
	draw_style_box(_cadre, Rect2(o, t))
	_cadre.modulate_color = Color.WHITE
	MenuStyle.texte_detoure(self, _gothique, o + Vector2(14, 27), titre, MenuStyle.TITRE_GRAND, OR, a)
	var pos := o + Vector2(14, 41)
	draw_multiline_string(_police, pos + Vector2(1, 1), texte, HORIZONTAL_ALIGNMENT_LEFT, LARGEUR, Palette.TAILLE_POLICE, -1, Color(FOND, a))
	draw_multiline_string(_police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, LARGEUR, Palette.TAILLE_POLICE, -1, Color(PARCHEMIN, a))
