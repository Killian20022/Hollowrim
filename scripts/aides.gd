class_name Aides
extends Control
## Bulles d'aide contextuelles : chacune apparaît UNE SEULE FOIS, au moment où elle sert (premier ennemi, premier sort en main,
## premier coffre, menu et carte). Le cartouche des touches, lui, reste celui du HUD (hud.demarrer / F1).
## - Désactivables : Options → « Bulles d'aide » (Jeu.option("jeu", "aides")).
## - État sauvegardé : `vues` (clés déjà montrées) dans la sauvegarde (monde.gd, clé « aides_vues »). Une partie d'avant cette clé
##   est une partie de vétéran : monde.gd appelle tout_vu() et rien ne s'affiche.
## - Rien ne s'affiche pendant un dialogue, un menu, la pause ni après la mort ; les bulles se suivent avec un temps de répit.
## - Mécaniques de monde (vol vu, prime, serrure, lit / attente, rang de faction) : une bulle à la 1re occurrence, déclenchée par les
##   signaux de Crime et de Rangs (brancher) ou par l'invite d'action.
## - PREMIER COMBAT GUIDÉ (jalon 3 de l'acte I, docs/BIBLE_TRAME_BIOMES.md) : le rôdeur isolé entre le feu et le cercle (monde.sbire)
##   sert de leçon. Bloquer → frapper → coup puissant → se soigner, chaque bulle déclenchée par ce que fait le joueur (voir _guide) ;
##   elles préemptent la file, restent jusqu'au geste demandé (DUREE_GUIDE au plus), se sautent avec la touche d'aide (passer) et ne
##   reviennent jamais (clés « guide_* » sauvegardées). Pendant la leçon, le draugr retient son geste rouge (non parable).
## - Les touches écrites dans les textes sont des jetons {action} remplacés par la configuration des contrôles (Touches) à l'affichage.
## Textes : TEXTES. Ajouter une aide = une entrée + une condition dans _sonder().

const DUREE := 7.0
const DUREE_GUIDE := 18.0   # s : une bulle du guide attend le geste demandé, au plus ce temps
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
	"menu": ["Menu et carte", "{menu} : sac, magie, compétences, journal des quêtes et carte du royaume. {aide} : rappel des touches."],
	"vol": ["Vol vu", "Un témoin t'a vu prendre ce qui n'est pas à toi. Il crie, les gardes viennent. Prends à l'abri des regards, ou paie ce que tu dois."],
	"prime": ["Prime", "Les gardes de Skarnholt connaissent ton crime. Paie l'amende, plaide ta cause ou purge ta peine en geôle. Ta prime fond un peu chaque heure."],
	"sommeil": ["Repos", "{attendre} : attendre ou dormir quelques heures. Un lit à toi redonne des forces ; celui d'un autre, c'est une intrusion. Pas de repos en plein combat."],
	"crochetage": ["Serrure", "Il te faut un crochet (forge de Brodd). Tourne-le avec la souris jusqu'à sentir la serrure céder ; clic droit pour renoncer. Sous un regard, c'est une intrusion."],
	"rang": ["Rang de faction", "Tu as changé de rang. Parle au chef de ta faction pour monter : réputation, savoir-faire et délai comptent. Une trahison fait tout perdre."],
}

## Premier combat guidé : chaque bulle suit un geste du joueur. Clés sauvegardées avec les autres (une seule fois par partie).
## Textes courts : ces bulles s'affichent en haut de l'écran (sous la boussole), cadre compact, pour laisser voir le draugr et l'arme.
## « {aide} : passer » est écrit à part, sur la ligne du titre (passer_de).
const GUIDE := {
	"guide_garde": ["Bloquer", "Il marche sur toi. Maintiens le clic droit : ta garde se lève. Levée quand son arme arrive : parade, il vacille."],
	"guide_frappe": ["Frapper", "Clic gauche : coup rapide. Frappe quand il vacille, puis remets ta garde. Chaque coup coûte de l'endurance."],
	"guide_puissant": ["Coup puissant", "Maintiens le clic gauche, puis relâche. Lent et coûteux, mais il brise sa garde et le renverse."],
	"guide_soin": ["Se soigner", "Recule et soigne-toi : potion de soin dans le sac ({inventaire}, Potions), ou sort de soin (touche 9), clic maintenu."],
}
const LARGEUR_GUIDE := 192.0   # px logiques : la bulle du guide tient entre la torche et la lame
const TITRE_GUIDE := MenuStyle.TITRE_GRAND   # le gothique à 16 se lit mal (« Coup puissant »)
const DECALAGE_GUIDE := -10.0  # px logiques : un peu à gauche du centre, la lame tenue à droite ne touche pas le cadre
const ORDRE_GUIDE := ["guide_garde", "guide_frappe", "guide_puissant", "guide_soin"]
const DIST_GUIDE := 12.0    # m : le draugr est « sur » le joueur
const DELAI_ETAPE := 10.0   # s : sans le geste demandé, l'étape suivante vient quand même
const SEUIL_SOIN := 0.6     # part de la vie sous laquelle vient la bulle « se soigner »
## Mêmes bulles à la manette (dernière entrée : Manette.actif()) : %s = boutons réels, remappage compris (texte_de()).
const TEXTES_MANETTE := {
	"ennemi": "%s : frapper (maintiens %s : coup puissant). Maintiens %s : garde. %s : esquive. Recule quand ta vie baisse : mieux vaut fuir que mourir.",
	"sort": "Un sort est en main. Maintiens %s (main droite) ou %s (main gauche) pour le charger, relâche pour le lancer. Le mana revient tout seul. La croix change de sorts.",
	"coffre": "%s : ouvrir, puis choisis ce que tu emportes. Le sac a une limite de poids : trop chargé, tu ralentis.",
	"menu": "%s : sac, magie, compétences, journal des quêtes et carte du royaume (LB / RB : page suivante). Start : pause.",
	"guide_garde": "Il marche sur toi. Maintiens %s : ta garde se lève. Levée quand son arme arrive : parade, il vacille.",
	"guide_frappe": "%s : coup rapide. Frappe quand il vacille, puis remets ta garde. Chaque coup coûte de l'endurance.",
	"guide_puissant": "Maintiens %s, puis relâche. Lent et coûteux, mais il brise sa garde et le renverse.",
	"guide_soin": "Recule et soigne-toi : potion de soin dans le sac (%s, Potions), ou sort de soin (raccourci de la croix), %s maintenu.",
}

## Texte manette d'une bulle ("" : pas de version manette, ou dernière entrée au clavier ; texte_de() prend alors le texte clavier).
static func _texte_manette(cle: String) -> String:
	if not Manette.actif() or not TEXTES_MANETTE.has(cle):
		return ""
	var d := Manette.libelle("main_droite")
	var g := Manette.libelle("main_gauche")
	match cle:
		"ennemi":
			return TEXTES_MANETTE[cle] % [d, d, g, Manette.libelle("esquive")]
		"sort":
			return TEXTES_MANETTE[cle] % [d, g]
		"coffre":
			return TEXTES_MANETTE[cle] % Manette.libelle("interagir")
		"menu":
			return TEXTES_MANETTE[cle] % Manette.libelle("menu")
		"guide_garde":
			return TEXTES_MANETTE[cle] % g
		"guide_frappe", "guide_puissant":
			return TEXTES_MANETTE[cle] % d
		"guide_soin":
			return TEXTES_MANETTE[cle] % [_bouton("inventaire", "menu"), d]
	return ""

## Bouton d'une commande à la manette ; celui de `repli` si elle n'a pas de bouton (ex. le sac sans bouton : on l'ouvre par le menu).
static func _bouton(id: String, repli: String = "") -> String:
	if Manette.code_de(id) != Manette.AUCUN or repli == "":
		return Manette.libelle(id)
	return Manette.libelle(repli)

var hud: Control
var joueur: CharacterBody3D
var dialogue: Control      # invite d'action (E) : détecte le premier coffre
var crime: Node
var rangs: Node
var cycle: Node
var guide_cible: CharacterBody3D   # le draugr isolé de la leçon (monde.sbire) ; null = pas de leçon
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
var _g_t := 0.0            # secondes depuis la dernière étape du guide
var _g_faits := {}         # gestes vus pendant la leçon : "garde", "leger", "lourd", "soin"
var _g_vie := 0.0          # vie du joueur quand la bulle « se soigner » s'est montrée

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	_cadre = MenuStyle.cadre_orne()

## Abonne les aides de monde (crime, rang de faction), l'heure et le draugr de la leçon. Tout est facultatif (tests).
func brancher(crime_: Node, rangs_: Node, cycle_: Node, cible: CharacterBody3D) -> void:
	crime = crime_
	rangs = rangs_
	cycle = cycle_
	if cible != null:
		guide_cible = cible
	if crime != null and crime.has_signal("crime_commis") and not crime.crime_commis.is_connected(_sur_crime):
		crime.crime_commis.connect(_sur_crime)
	if rangs != null and rangs.has_signal("rang_change") and not rangs.rang_change.is_connected(_sur_rang):
		rangs.rang_change.connect(_sur_rang)

func _sur_crime(type: String, _juridiction: String, _temoins: int) -> void:
	if type == "vol":
		proposer("vol")
	proposer("prime")

func _sur_rang(_faction: String, r: int) -> void:
	if r >= 0:
		proposer("rang")

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
	for c in GUIDE:
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
	if joueur == null or joueur.mort or bool(joueur.get("en_dialogue")) or PauseCoop.en_pause(get_tree()):
		return false
	return hud == null or not bool(hud.get("panneau_ouvert"))

func _process(dt: float) -> void:
	EchelleUi.appliquer(self)
	_retenir_geste()
	if not actif:
		return
	if not _libre():
		queue_redraw()
		return
	_jeu_actif += dt
	_suivre_gestes()
	if GUIDE.has(_cle) and Input.is_action_just_pressed("aide"):
		passer_guide()
	_sonde_t -= dt
	if _sonde_t <= 0.0:
		_sonde_t = 0.25
		_sonder()
	if _cle != "":
		_t += dt
		if _t >= _duree():
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
		# le draugr de la leçon a ses propres bulles (bloquer, frapper, coup puissant, soin) : pas de doublon « Premier combat »
		if not (hud.cible_actuelle() == guide_cible and _guide_ennemi() != null and not _guide_fini()):
			proposer("ennemi")
	if _sort_en_main():
		proposer("sort")
	if dialogue != null and dialogue.has_method("invite_courante"):
		var p: Node3D = dialogue.invite_courante()
		var verbe: Variant = p.get("verbe") if p != null else null   # un villageois n'a pas de « verbe »
		if verbe is String and (verbe as String).to_lower().contains("coffre"):
			proposer("coffre")
		if verbe is String and (verbe as String).to_lower().contains("dormir"):
			proposer("sommeil")
		if p != null and int(p.get_meta("verrou", 0)) > 0:
			proposer("crochetage")
	if _jeu_actif >= DELAI_MENU:
		proposer("menu")
	if cycle != null and (float(cycle.get("heure")) >= 22.0 or float(cycle.get("heure")) < 5.0):
		proposer("sommeil")   # la première nuit avancée : on peut attendre le jour
	_guide()

# ------------------------------------------------------------------------------------------------ premier combat guidé

func _duree() -> float:
	return DUREE_GUIDE if GUIDE.has(_cle) else DUREE

func _guide_fini() -> bool:
	return vues.has("guide_soin")

func _guide_ennemi() -> Variant:
	if guide_cible == null or not is_instance_valid(guide_cible) or not guide_cible.has_method("vivant") or not guide_cible.vivant():
		return null
	return guide_cible

## Tant que la leçon n'est pas finie, le draugr ne lance pas son geste rouge (non parable) : il ne doit pas punir l'élève.
func _retenir_geste() -> void:
	var d: Variant = _guide_ennemi()
	if d != null and not _guide_fini() and activees() and d.has_method("differer_geste_annonce"):
		d.differer_geste_annonce(5.0)

func _combat() -> EtatCombat:
	var m: Variant = joueur.get("mains") if joueur != null else null
	return m.combat if m != null and m.get("combat") != null else null

## Note les gestes du joueur pendant la leçon (chaque image : un coup léger ne dure qu'une fraction de seconde).
func _suivre_gestes() -> void:
	if not vues.has("guide_garde") or _guide_fini():
		return
	var c := _combat()
	if c == null:
		return
	match c.etat:
		EtatCombat.GARDE, EtatCombat.PARADE:
			_g_faits["garde"] = true
		EtatCombat.ATTAQUE_LEGERE, EtatCombat.CONTRE:
			_g_faits["leger"] = true
		EtatCombat.CHARGE_LOURDE, EtatCombat.ATTAQUE_LOURDE:
			_g_faits["lourd"] = true

## Montre une bulle du guide TOUT DE SUITE (elle remplace celle à l'écran) et retient l'étape.
func _montrer(cle: String) -> void:
	vues[cle] = true
	if cle == "guide_garde":
		vues["ennemi"] = true
		_file.erase("ennemi")
		_g_faits = {}
	elif cle == "guide_frappe":
		_g_faits.erase("leger")   # un coup donné AVANT la bulle ne compte pas : on attend celui qu'elle demande
	elif cle == "guide_puissant":
		_g_faits.erase("lourd")
	_cle = cle
	_t = 0.0
	_g_t = 0.0
	_repit = 0.0

## Étape faite : la bulle en cours s'efface (fondu de sortie).
func _clore(cle: String) -> void:
	if _cle == cle:
		_t = maxf(_t, _duree() - 0.6)

## Passer la leçon : la touche d'aide pendant une bulle du guide les écarte toutes.
func passer_guide() -> void:
	for c in GUIDE:
		vues[c] = true
	if GUIDE.has(_cle):
		_cle = ""

## Étape en cours : la première bulle du guide pas encore montrée.
func etape_guide() -> String:
	for c in ORDRE_GUIDE:
		if not vues.has(c):
			return c
	return ""

func _guide() -> void:
	if _cle == "guide_soin" and joueur != null and float(joueur.get("vie")) > _g_vie + 5.0:
		_clore("guide_soin")   # il s'est soigné
	if _guide_fini() or not activees():
		return
	_suivre_gestes()
	_g_t += 0.25
	var d: Variant = _guide_ennemi()
	var vie := float(joueur.get("vie")) if joueur != null else 0.0
	var vie_max := maxf(1.0, float(joueur.get("vie_max"))) if joueur != null else 1.0
	match etape_guide():
		"guide_garde":
			if d != null and _cle == "" and d.global_position.distance_to(joueur.global_position) < DIST_GUIDE and (d.etat == d.TRAQUE or d.etat == d.ATTAQUE):
				_montrer("guide_garde")
		"guide_frappe":
			if d == null:
				_fin_sans_draugr(vie, vie_max)
			elif _g_faits.has("garde") or _g_t >= DELAI_ETAPE:
				_montrer("guide_frappe")
		"guide_puissant":
			if d == null:
				_fin_sans_draugr(vie, vie_max)
			elif _g_faits.has("leger") or _g_t >= DELAI_ETAPE:
				_montrer("guide_puissant")
		"guide_soin":
			if _g_faits.has("lourd"):
				_clore("guide_puissant")
			# la vie baisse (ou le combat est fini et la vie n'est pas pleine) : c'est le moment de se soigner
			if vie < vie_max * SEUIL_SOIN or (d == null and vie < vie_max - 1.0):
				_montrer("guide_soin")
				_g_vie = vie
			elif d == null and _cle != "guide_puissant":
				passer_guide()   # victoire sans une égratignure : rien à soigner

## Le draugr est tombé avant la fin de la leçon : on garde la bulle « se soigner » s'il a été touché, sinon la leçon s'arrête.
func _fin_sans_draugr(vie: float, vie_max: float) -> void:
	for c in ["guide_frappe", "guide_puissant"]:
		vues[c] = true
	if GUIDE.has(_cle):
		_cle = ""
	if vie < vie_max - 1.0:
		_montrer("guide_soin")
		_g_vie = vie
	else:
		passer_guide()

## Texte affiché : les jetons {action} deviennent les touches réelles du joueur (configuration des contrôles).
## Texte d'une bulle pour l'appareil de la dernière entrée : version manette (TEXTES_MANETTE) si elle existe, sinon texte clavier
## dont les {commande} prennent la touche réelle (ou le bouton de manette quand la manette est active et la commande liée).
static func texte_de(cle: String) -> String:
	var m := _texte_manette(cle)
	if m != "":
		return m
	var t: String = String((TEXTES[cle] if TEXTES.has(cle) else GUIDE[cle])[1])
	for a: Dictionary in Touches.ACTIONS:
		var id := String(a["id"])
		var lib := Manette.libelle(id) if Manette.actif() and Manette.code_de(id) != Manette.AUCUN else Touches.libelles(id)
		t = t.replace("{" + id + "}", lib)
	return t

static func passer_de() -> String:
	return "%s : passer" % (Manette.libelle("aide") if Manette.actif() and Manette.code_de("aide") != Manette.AUCUN else Touches.libelles("aide"))

static func titre_de(cle: String) -> String:
	return String((TEXTES[cle] if TEXTES.has(cle) else GUIDE[cle])[0])

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
	return clampf(minf(_t / 0.3, (_duree() - _t) / 0.6), 0.0, 1.0)

func _draw() -> void:
	var a := alpha()
	if a <= 0.01 or not _libre():
		return
	var titre := titre_de(_cle)
	var texte := texte_de(_cle)
	if GUIDE.has(_cle):
		_dessiner_guide(titre, texte, a)
		return
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

## Bulle du premier combat guidé : en haut, centrée sous la boussole, compacte (le draugr et l'arme restent visibles).
func _dessiner_guide(titre: String, texte: String, a: float) -> void:
	var taille_texte := _police.get_multiline_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, LARGEUR_GUIDE, Palette.TAILLE_POLICE)
	var t := Vector2(LARGEUR_GUIDE + 20.0, ceilf(taille_texte.y) + 42.0)
	var o := Vector2(floorf((size.x - t.x) * 0.5 + DECALAGE_GUIDE), 20.0)
	_cadre.modulate_color = Color(1, 1, 1, a)
	draw_style_box(_cadre, Rect2(o, t))
	_cadre.modulate_color = Color.WHITE
	MenuStyle.texte_detoure(self, _gothique, o + Vector2(10, 26), titre, TITRE_GUIDE, OR, a)
	var passer := "(%s)" % passer_de()
	var lp := _police.get_string_size(passer, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x
	draw_string(_police, o + Vector2(t.x - 10.0 - lp, 24), passer, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE, Color(PARCHEMIN, a * 0.7))
	var pos := o + Vector2(10, 38)
	draw_multiline_string(_police, pos + Vector2(1, 1), texte, HORIZONTAL_ALIGNMENT_LEFT, LARGEUR_GUIDE, Palette.TAILLE_POLICE, -1, Color(FOND, a))
	draw_multiline_string(_police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, LARGEUR_GUIDE, Palette.TAILLE_POLICE, -1, Color(PARCHEMIN, a))
