class_name GestesLourds
## GESTES PROPRES des armes lourdes (branche combat/gestes_lourds) : HACHES, MASSES, MARTEAUX à une main et GRAND MARTEAU
## à deux mains. Une table de gestes PAR FAMILLE, au même format que ProfilsAnimation.PROFILS (qui les lit en repli :
## ProfilsAnimation.profil) ; les coups d'épée ne changent pas.
##
## Branchement : CatalogueArmes.donnees pose `d.profil = GestesLourds.profil_pour(...)` :
##   - entrée du catalogue avec "gestes": "hache" (Hache de guerre, Hachette de forestier : famille une_main) → « hache » ;
##   - famille « masse » → « masse » ; famille « marteau » → « marteau » ; marteau tenu à deux mains → « grand_marteau ».
## Clips : sources_blender/scripts/gestes_lourds.py → assets/animations/bras_lourds.tres (bibliothèque « lourd/ » de
## AnimateurBras), poses écrites à la main en espace écran (même solveur que l'épée), rythme mesuré sur les captures Mixamo
## « Standing Melee Attack Downward » (écrasement : armé 0,7 s, chute 0,2 s, arrêt mort) et « Standing Melee Attack
## Backhand » (crochet : armé 0,6 s, frappe 0,4 s).
## Le grand marteau garde la mécanique « deux mains » de combat/claymore_2mains (deux_mains = true : main gauche en IK sur
## le manche, mains._poser_deux_mains ; tenues de garde « _2m ») et n'en remplace que les coups et le repos.
##
## Clés propres aux gestes lourds (en plus de celles de ProfilsAnimation) :
##   « mordant »   : [durée (s), recul (m)] — au contact d'une cible, la tête de l'arme s'arrête net (le geste se fige
##                   `durée` s) et le poing recule de `recul` m (hache : petit arrêt net + recul ; masse : arrêt sourd) ;
##   « secousse »  : secousse de caméra minimale au contact (joueur.secousse, 0..1 ; modérée pour la masse) ;
##   « suivi »     : part du suivi d'épaule de coups_v4 gardée après la frappe (0 = arrêt net, le clip fait le rebond) ;
##   « trainee »   : [début, fin] de la traînée le long de garde → pointe (0..1) ; [] = pas de traînée. Masses et
##                   marteaux : seulement la tête (pas de ruban d'épée fine).

## Décalage du poing le long du manche (m, repère du modèle) : manche tenu PLUS BAS que le repère « prise » (une main) ;
## le grand marteau garde sa prise (la main gauche descend vers le bout du manche : ecart_mains du catalogue).
const PRISE := {"hache": -0.07, "masse": -0.08, "marteau": -0.08, "grand_marteau": 0.0}

const PROFILS := {
	# HACHES : tailles courtes et cassantes, plutôt en diagonale descendante ; à l'impact la tête mord (arrêt net) puis le
	# poing recule un peu. Combo : 1 diagonale haut-droite → bas-gauche, 2 revers haut-gauche → bas-droite, 3 taille verticale.
	"hache": {
		"combo": ["h_diag", "h_revers", "h_haut"],
		"lourd": "h_lourd",
		"lourds": {},
		"tenues": {"repos": "repos_h"},
		"gestes": {
			"h_diag": {"clip": "h_a", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3,
				"mordant": [0.07, 0.035], "secousse": 0.2, "suivi": 0.0, "trainee": [0.45, 1.0]},
			"h_revers": {"clip": "h_b", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3,
				"mordant": [0.07, 0.035], "secousse": 0.2, "suivi": 0.0, "trainee": [0.45, 1.0]},
			"h_haut": {"clip": "h_c", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.06, 0.9], "force": 1.2, "tassement": 0.6, "elan": 0.4,
				"mordant": [0.09, 0.045], "secousse": 0.28, "suivi": 0.0, "trainee": [0.45, 1.0]},
			# souris tirée vers le bas / en avançant : la taille verticale
			"verticale_l": {"clip": "h_c", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.06, 0.9], "force": 1.2, "tassement": 0.6, "elan": 0.4,
				"mordant": [0.09, 0.045], "secousse": 0.28, "suivi": 0.0, "trainee": [0.45, 1.0]},
			"h_lourd": {"clip": "lourd_h", "charge": "charge_h", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.08, 0.8], "force": 1.0, "tassement": 0.9, "elan": 0.5,
				"mordant": [0.11, 0.05], "secousse": 0.4, "suivi": 0.0, "trainee": [0.45, 1.0]},
		},
	},
	# MASSE à une main : écrasements lourds, poids en tête (armé lent, chute rapide, arrêt sourd, secousse modérée).
	# Combo : 1 crochet droite → gauche, 2 revers gauche → droite, 3 écrasement du haut vers le bas.
	"masse": {
		"combo": ["m_crochet", "m_revers", "m_haut"],
		"lourd": "m_lourd",
		"lourds": {},
		"tenues": {"repos": "repos_m"},
		"gestes": {
			"m_crochet": {"clip": "m_a", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.08, 1.0], "force": 1.0, "elan": 0.35,
				"mordant": [0.06, 0.02], "secousse": 0.32, "suivi": 0.0, "trainee": [0.72, 1.0]},
			"m_revers": {"clip": "m_b", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 1.0], "force": 1.0, "elan": 0.35,
				"mordant": [0.06, 0.02], "secousse": 0.32, "suivi": 0.0, "trainee": [0.72, 1.0]},
			"m_haut": {"clip": "m_c", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.1, 0.9], "force": 1.25, "tassement": 0.9, "elan": 0.45,
				"mordant": [0.08, 0.025], "secousse": 0.4, "suivi": 0.0, "trainee": [0.72, 1.0]},
			# variantes contextuelles (souris balayée, pas de côté, en avançant)
			"horizontale": {"clip": "m_a", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.08, 1.0], "force": 1.0, "elan": 0.35,
				"mordant": [0.06, 0.02], "secousse": 0.32, "suivi": 0.0, "trainee": [0.72, 1.0]},
			"horizontale_gd": {"clip": "m_b", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 1.0], "force": 1.0, "elan": 0.35,
				"mordant": [0.06, 0.02], "secousse": 0.32, "suivi": 0.0, "trainee": [0.72, 1.0]},
			"verticale_l": {"clip": "m_c", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.1, 0.9], "force": 1.25, "tassement": 0.9, "elan": 0.45,
				"mordant": [0.08, 0.025], "secousse": 0.4, "suivi": 0.0, "trainee": [0.72, 1.0]},
			"m_lourd": {"clip": "lourd_m", "charge": "charge_m", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.1, 0.8], "force": 1.0, "tassement": 1.1, "elan": 0.55,
				"mordant": [0.1, 0.03], "secousse": 0.5, "suivi": 0.0, "trainee": [0.72, 1.0]},
		},
	},
	# MARTEAU DE GUERRE à une main : mêmes trajectoires que la masse (poids en tête), l'écrasement vertical ouvre le combo
	# (bec et tête d'acier : coup du haut d'abord), impacts un peu plus lourds.
	"marteau": {
		"combo": ["mt_haut", "mt_crochet", "mt_revers"],
		"lourd": "mt_lourd",
		"lourds": {},
		"tenues": {"repos": "repos_m"},
		"gestes": {
			"mt_haut": {"clip": "m_c", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.1, 1.0], "force": 1.1, "tassement": 1.0, "elan": 0.45,
				"mordant": [0.09, 0.025], "secousse": 0.42, "suivi": 0.0, "trainee": [0.75, 1.0]},
			"mt_crochet": {"clip": "m_a", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.08, 1.0], "force": 1.0, "elan": 0.35,
				"mordant": [0.07, 0.02], "secousse": 0.35, "suivi": 0.0, "trainee": [0.75, 1.0]},
			"mt_revers": {"clip": "m_b", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 0.9], "force": 1.15, "elan": 0.35,
				"mordant": [0.07, 0.02], "secousse": 0.35, "suivi": 0.0, "trainee": [0.75, 1.0]},
			"horizontale": {"clip": "m_a", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.08, 1.0], "force": 1.0, "elan": 0.35,
				"mordant": [0.07, 0.02], "secousse": 0.35, "suivi": 0.0, "trainee": [0.75, 1.0]},
			"horizontale_gd": {"clip": "m_b", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 1.0], "force": 1.0, "elan": 0.35,
				"mordant": [0.07, 0.02], "secousse": 0.35, "suivi": 0.0, "trainee": [0.75, 1.0]},
			"verticale_l": {"clip": "m_c", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.1, 1.0], "force": 1.1, "tassement": 1.0, "elan": 0.45,
				"mordant": [0.09, 0.025], "secousse": 0.42, "suivi": 0.0, "trainee": [0.75, 1.0]},
			"mt_lourd": {"clip": "lourd_m", "charge": "charge_m", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.1, 0.8], "force": 1.0, "tassement": 1.2, "elan": 0.55,
				"mordant": [0.11, 0.03], "secousse": 0.55, "suivi": 0.0, "trainee": [0.75, 1.0]},
		},
	},
	# GRAND MARTEAU à deux mains (famille marteau, deux_mains = true) : grands coups verticaux tête → sol, très lents, fort
	# impact. Garde, parade, encaisse, garde brisée et course : celles de la famille « deux_mains » (bras_2mains.tres).
	"grand_marteau": {
		"combo": ["gm_vertical", "gm_diag", "gm_vertical"],
		"lourd": "gm_lourd",
		"lourds": {},
		"tenues": {"repos": "repos_gm", "sprint": "sprint_2m", "garde": "garde_2m", "encaisse": "encaisse_2m",
			"parade": "parade_2m", "garde_brisee": "brisee_2m"},
		"gestes": {
			"gm_vertical": {"clip": "gm_a", "fenetre": [0.0, 1.0], "cotes": [0, 0], "enchainement": [0.15, 0.85], "force": 1.15, "tassement": 1.3, "elan": 0.55,
				"mordant": [0.1, 0.03], "secousse": 0.55, "suivi": 0.0, "trainee": [0.78, 1.0]},
			"gm_diag": {"clip": "gm_b", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.15, 0.85], "force": 1.0, "tassement": 1.0, "elan": 0.5,
				"mordant": [0.09, 0.03], "secousse": 0.5, "suivi": 0.0, "trainee": [0.78, 1.0]},
			"gm_lourd": {"clip": "lourd_gm", "charge": "charge_gm", "fenetre": [0.0, 1.0], "cotes": [0, 0], "enchainement": [0.15, 0.8], "force": 1.0, "tassement": 1.5, "elan": 0.7,
				"mordant": [0.13, 0.035], "secousse": 0.7, "suivi": 0.0, "trainee": [0.78, 1.0]},
		},
	},
}

## Profil de gestes d'une arme du catalogue : `gestes` (champ explicite de l'entrée, ex. "hache"), sinon la famille ;
## "" = garder le profil de la famille (épées, dagues, boucliers : inchangés).
static func profil_pour(famille: String, gestes: String, deux_mains: bool) -> String:
	var g := gestes if gestes != "" else famille
	if g == "marteau" and deux_mains:
		return "grand_marteau"
	return g if PROFILS.has(g) else ""

static func est_lourd(nom_profil: String) -> bool:
	return PROFILS.has(nom_profil)

## Décalage du poing le long du manche pour cette arme (0 hors gestes lourds).
static func decalage_prise(arme: DonneesArme) -> float:
	return float(PRISE.get(arme.profil, 0.0)) if arme != null else 0.0

## Part du suivi d'épaule (coups_v4) gardée après la frappe.
static func part_suivi(geste: Dictionary) -> float:
	return float(geste.get("suivi", 1.0))

## Traînée : extrémités [a, b] (repère des mains) entre garde et pointe selon « trainee » ; [] = aucune.
static func points_trainee(geste: Dictionary, garde: Vector3, pointe: Vector3) -> Array:
	if not geste.has("trainee"):
		return [garde, pointe]
	var t: Array = geste["trainee"]
	if t.size() < 2:
		return []
	return [garde.lerp(pointe, float(t[0])), garde.lerp(pointe, float(t[1]))]

## Mordant au contact : décalage additif du poing (repère des mains) pendant les `d` s qui suivent le contact (u = temps
## écoulé depuis le contact) — recul rapide vers l'arrière/le haut, puis relâché ; Transform3D() hors mordant.
static func recul_mordant(geste: Dictionary, u: float) -> Transform3D:
	var m: Array = geste.get("mordant", [])
	if m.size() < 2 or u < 0.0:
		return Transform3D()
	var d := maxf(float(m[0]), 1e-3)
	var k := u / (d * 2.5)
	if k >= 1.0:
		return Transform3D()
	var amp := float(m[1]) * sin(minf(k * 4.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.3, 1.0, k))
	return Transform3D(Basis(), Vector3(0.0, 0.35, 1.0).normalized() * amp)

## Durée de l'arrêt net de la tête au contact (s ; 0 sans mordant).
static func arret_mordant(geste: Dictionary) -> float:
	var m: Array = geste.get("mordant", [])
	return float(m[0]) if m.size() >= 2 else 0.0
