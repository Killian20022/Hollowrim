class_name ReglagesCombat
## TABLE UNIQUE D'ÉQUILIBRAGE DU COMBAT (branche combat/equilibrage, 2026-10-30). Tous les chiffres « qui décident combien
## de coups il faut » sont ici ; les autres fichiers les lisent. Rapport : Desktop/Skyrim captures/equilibrage/equilibrage.md.
##
## Repère : l'épée de départ (epee_metal, famille epee_longue en acier) fait 14 au coup léger, 28 au coup puissant (×2), 36
## au puissant pleinement chargé (×1,3). Cibles (coups légers de l'épée de départ, au torse) :
##   sbire / squelette 3-4 · draugr / bandit 5-7 · guerrier / ancien 8-10 · gardien d'élite 11-12 · chef 25-40 · dragon 55+.
## Dégâts reçus (joueur 100 PV, sans armure) : draugr standard ≈ 9-10 coups, guerrier ≈ 7, chef 3-5.
##
## Les dégâts des ARMES restent dans leurs données (data/armes/catalogue_armes.json : famille × matériau × mult ;
## data/armes/*.tres pour les épées écrites à la main), ceux des SORTS dans data/sorts/*.tres — mêmes repères que ci-dessus.

# ------------------------------------------------------------------ ennemis : PV et dégâts infligés au joueur

## PV par sorte d'ennemi (draugr.gd, ennemi_base.gd et dérivés, dragon.gd, et les vie_imposee des donjons).
const VIE := {
	"sbire": 60.0,          # draugr chétif : 4-5 coups légers (3 à la tête ; un coup chargé à la tête ne suffit plus)
	"squelette": 65.0,      # os secs : 5 coups légers, 3 coups puissants
	"draugr": 104.0,        # draugr / bandit standard : 7-8 coups légers (+30 % le 2026-11-05 : ils doivent tenir assez pour MENACER)
	"bandit": 104.0,        # bandits des grottes (grotte_jeu)
	"guerrier": 135.0,      # draugr ancien (casque, mailles) : 10 coups légers
	"gardien": 150.0,       # gardiens nommés de la crypte (Os, Givre, Eau) : 12 coups
	"gardien_serment": 135.0,  # gardiens du serment (vague) : comme un guerrier
	"mage": 70.0,           # mage nordique : robe, 5 coups
	"troll": 420.0,         # troll de givre (mini-chef, régénère) : 30 coups
	"svanhild": 400.0,      # chefs : 25-40 coups, avec leurs phases
	"hrafn": 380.0,
	"jarl": 480.0,
	"dragon": 800.0,        # dégâts bruts (pas de profil) : 57 coups, la phase au sol en coûte ~17
}

## Dégâts d'un coup de l'ennemi sur le joueur (avant garde / protection). Le 2e coup d'un combo de draugr fait ×1,25.
const DEGATS := {
	"sbire": 8.0,           # 13 coups pour tuer le joueur
	"squelette": 9.0,       # 11
	"zombie": 10.0,         # 10
	"draugr": 11.0,         # 9-10 (combo : 13,75)
	"archer_melee": 7.0,    # l'arc est son arme (tir : degats_tir de draugr.gd)
	"guerrier": 14.0,       # 7-8
	"gardien": 16.0,        # 6-7
	"mage": 6.0,            # bâton (ses sorts : mage_nordique_ia.gd)
	"troll": 26.0,          # balayage (onde ×1,33, charge = ce chiffre)
	"svanhild": 20.0,       # 5 coups
	"hrafn": 18.0,          # 5-6 coups, rapide
	"jarl": 28.0,           # 3-4 coups, lent, bouclier
}

# ------------------------------------------------------------------ menace des ennemis courants (nuit 2026-11-05)

## Ennemis « courants » (sbire, squelette, draugr, guerrier, bandit ; ni chef, ni archer) : draugr.gd, `_menace`. Modèle : le troll.
## Coups légers : geste accéléré (premier coup ~0,5 s après l'arrivée au contact au lieu de ~0,65 s) ; enchaînement de 1 à
## MENACE_SERIE_MAX coups (dégâts × MENACE_SERIE_MULT[n]), le suivant part dès la fin de l'impact du précédent s'il est encore à portée.
const MENACE_RYTHME := 1.3
const MENACE_SERIE_MAX := {"sbire": 2, "squelette": 2, "draugr": 3, "bandit": 3, "guerrier": 3}
const MENACE_SERIE_MULT := [1.0, 1.15, 1.3]
## Part du geste (0..1) à laquelle le coup suivant de la série démarre.
const MENACE_SERIE_DEPART := 0.62
## Pause entre deux séries (s), pendant laquelle l'ennemi tourne autour du joueur au lieu de rester planté.
const MENACE_PAUSE := Vector2(0.7, 1.4)
## Une fois sur deux, il fait d'abord un pas en arrière de cette durée (s) : le joueur doit le suivre, le coup suivant arrive de plus loin.
const MENACE_REPLI := 0.45
## Hyper-armure : après chaque titubement, les coups légers et moyens ne le font plus tituber pendant ce temps (sinon un joueur
## qui spamme enchaîne les titubements de 0,3 s et l'ennemi n'attaque jamais).
const MENACE_ARMURE := 0.9
## Geste NON PARABLE annoncé (coup de taille) : préparation lente lisible (MENACE_LOURD_PREPARATION s, repère rouge au sol, éclair),
## puis frappe en MENACE_LOURD_ANNONCE - préparation s. Pas de parade parfaite, MENACE_LOURD_IMPARABLE des dégâts traversent la
## garde. Seul le pas de côté / l'esquive l'évite (ou un coup lourd qui l'interrompt). Il reste planté ensuite (punition).
const MENACE_LOURD_ANNONCE := 0.95
const MENACE_LOURD_PREPARATION := 0.62
const MENACE_LOURD_DEGATS := 1.6
const MENACE_LOURD_IMPARABLE := 0.5
const MENACE_LOURD_RAYON := 1.5
const MENACE_LOURD_AVANCE := 1.5
## Attente avant le premier geste annoncé (s) et entre deux (tirage), et part de séries qui deviennent un geste annoncé.
const MENACE_LOURD_PREMIER := Vector2(1.6, 2.6)
const MENACE_LOURD_ENTRE := Vector2(3.0, 5.0)
## Contournement : quand plusieurs ennemis courants sont sur le joueur, ceux qui ne sont pas au contact passent sur le flanc.
const MENACE_FLANC_ANGLE := 1.35
const MENACE_FLANC_RAYON := 2.3
const MENACE_FLANC_MAX := 2.8

# ------------------------------------------------------------------ esquive du joueur (touche Alt gauche ou C)

## Pas de côté (ou en arrière sans direction) : distance, durée, invulnérabilité (depuis le début), coût de vigueur, attente.
const ESQUIVE_DISTANCE := 2.7
const ESQUIVE_DUREE := 0.34
const ESQUIVE_INVULNERABLE := 0.2
const ESQUIVE_COUT := 20.0
const ESQUIVE_ATTENTE := 0.2
## Annulation de la récupération d'un coup : tout de suite si le coup a raté, après ce délai (s) s'il a touché.
const ESQUIVE_ANNULE_TOUCHE := 0.2

static func vie(sorte: String, defaut := 80.0) -> float:
	return float(VIE.get(sorte, defaut))

static func degats(sorte: String, defaut := 11.0) -> float:
	return float(DEGATS.get(sorte, defaut))

# ------------------------------------------------------------------ coups du joueur

## Multiplicateur selon l'attaque (après les dégâts de l'arme : le coup puissant a sa propre base, degats_lourd ≈ 2 × léger,
## et la pleine charge multiplie par bonus_charge_max ≈ 1,2-1,3 — plus de ×1,25 en plus : c'était un empilement).
const MULT_ATTAQUE := {"legere": 1.0, "lourde": 1.0, "chargee_max": 1.0, "contre": 1.3, "finisher": 1.0}
## Coup critique : seulement sur une cible étourdie (posture brisée) ou au sol. (Avant : aussi tout coup puissant à la tête,
## qui s'empilait avec le ×1,6 de la zone : ×2,4 → un coup chargé à la tête tuait un draugr.)
const CRITIQUE := 1.35
## Os (squelettes) : les coups puissants les brisent (+15 % ; avant +30 %).
const OS_LOURD := 1.15
## Attaque furtive : ennemi qui ne combat pas encore (endormi, de garde, en patrouille) frappé dans le dos (ou endormi).
## Bonus marqué, mais un chef n'en reçoit qu'une part et n'y perd jamais plus de FURTIF_PLAFOND_BOSS de sa vie.
const FURTIF := 2.5
const FURTIF_BOSS := 1.5
const FURTIF_PLAFOND_BOSS := 0.15

# ------------------------------------------------------------------ finishers

## Finisher sur posture brisée (étourdi, au sol, après parade, pris de côté) : seulement si la vie est déjà sous cette part
## (sinon le finisher, qui tue d'un coup, revenait à un one-shot dès la première garde brisée).
const FINISHER_POSTURE_VIE := 0.5
## Chefs (draugr boss, troll) : finisher seulement à vie basse réelle, quelle que soit la posture.
const FINISHER_BOSS_VIE := 0.25

# ------------------------------------------------------------------ progression du personnage (niveaux, arbre : à venir)

## Multiplicateurs par compétence, prévus pour l'arbre de compétences : TOUS À 1,0 pour l'instant. DegatsCombat les applique
## selon la famille de l'arme ; la magie selon l'école ; la furtivité et l'armure aux endroits indiqués.
const COMPETENCES := {
	"une_main": 1.0,        # une_main, epee_longue, dague, masse
	"deux_mains": 1.0,      # deux_mains, marteau
	"destruction": 1.0,     # sorts offensifs (MainSort / LanceurSorts)
	"furtivite": 1.0,       # × FURTIF
	"armure": 1.0,          # dégâts reçus (diviseur, joueur.gd)
	"parade": 1.0,          # garde (DefenseJoueur)
}
## Gain de l'ancienne compétence « épée » par la pratique (Competences.multiplicateur_degats : 1 + bonus × GAIN, bonus 0→1
## du niveau 15 au niveau 100) : 0,6 avant ; ramené à 0,3 pour ne pas écraser l'équilibrage en fin de partie.
const GAIN_COMPETENCE_EPEE := 0.3

## Valeur de base × multiplicateur de l'arbre du joueur courant (Progression.mult_global : 1,0 sans joueur ou sans perk).
## Tous les appelants (DegatsCombat, LanceurSorts, CalculDegats, joueur.recevoir_coup) reçoivent ainsi les perks sans changer.
static func competence(nom: String) -> float:
	return float(COMPETENCES.get(nom, 1.0)) * Progression.mult_global(nom)

## Compétence d'arme d'une famille de DonneesArme.
static func competence_arme(famille: String, deux_mains := false) -> float:
	if deux_mains or famille in ["deux_mains", "marteau"]:
		return competence("deux_mains")
	return competence("une_main")
