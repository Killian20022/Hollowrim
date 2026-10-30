class_name ProfilCible
extends Resource
## Profil de dégâts d'une cible (draugr, squelette, bandit, mannequin…) : armure, résistances, zones, posture, sang.
## Données pures (Resource) : réglages modifiables dans data/combat/cible_<nom>.tres (sinon valeurs par défaut de _defaut()).
##   ProfilCible.pour("draugr_guerrier") -> ProfilCible     (copie : chaque ennemi peut la modifier, ex. boss)
## Voir docs/DEGATS.md pour la signification de chaque valeur et le calcul complet (CalculDegats).

@export var nom := ""
## Matière touchée : "chair" (sang), "os" (éclats d'os, pas de sang), "bois" (copeaux) ; règle les sons et les effets.
@export var matiere := "chair"
## Armure plate retirée des coups tranchants au torse, aux bras et aux jambes (pas à la tête sauf casque).
@export var armure := 0.0
## Armure plate de la tête (casque).
@export var armure_tete := 0.0
## Part des dégâts absorbée (0..1), tous types confondus.
@export var armure_part := 0.0
## Multiplicateurs par type de dégât (1 = normal, < 1 résistance, > 1 vulnérabilité).
@export var resistances := {"tranchant": 1.0, "contondant": 1.0, "feu": 1.0, "glace": 1.0, "magique": 1.0, "electricite": 1.0, "tenebres": 1.0}
## Multiplicateurs par zone touchée.
@export var zones := {"tete": 1.4, "torse": 1.0, "bras": 0.75, "jambes": 0.85}   # tête : 1,6 avant l'équilibrage
## Jauge d'équilibre : réduite par la force de stagger de chaque coup ; vide = posture brisée (étourdi, finisher possible).
@export var posture_max := 45.0
## Récupération de posture (par seconde) après `posture_delai` s sans coup.
@export var posture_regen := 10.0
@export var posture_delai := 1.4
## Seuils de stagger (force effective d'un coup) des réactions moyenne, lourde et chute.
@export var seuil_moyen := 11.0
@export var seuil_lourd := 24.0
@export var seuil_chute := 30.0
## Poids : divise le recul et le stagger reçus (1 = humain).
@export var poids := 1.0
## Chance de bloquer au bouclier un coup léger de face (pondérée par la posture restante).
@export var chance_blocage := 0.0
## Durée de l'état étourdi (posture brisée) : fenêtre de finisher.
@export var duree_etourdi := 2.6
@export var sang := true
@export var couleur_sang := Color(0.30, 0.03, 0.025)
@export var decapitable := true
## Voix de mort-vivant (râles de draugr) ; faux = voix humaine (bandits).
@export var mort_vivant := true
## Vie sous laquelle (part de la vie max) un coup lourd de face ouvre le finisher « rapide ».
@export var seuil_finisher_vie := 0.22

const DOSSIER := "res://data/combat/cible_%s.tres"

static func pour(nom_profil: String) -> ProfilCible:
	var chemin := DOSSIER % nom_profil
	if ResourceLoader.exists(chemin):
		var r := load(chemin) as ProfilCible
		if r != null:
			return r.duplicate(true) as ProfilCible
	return _defaut(nom_profil)

## Nom de profil d'un ennemi de draugr.gd (type, boss, modèle).
static func nom_pour(type: String, boss: String, modele: Node) -> String:
	if type.begins_with("squelette"):
		return "squelette"
	if modele != null and modele.has_meta("draugr_nordique"):
		return "draugr_guerrier" if type == "guerrier" else "draugr"
	if boss == "svanhild" or boss == "jarl":
		return "draugr_guerrier"
	if modele != null and (modele.has_meta("perso_def") or modele.has_meta("armes_nordiques")):
		return "bandit"
	return "draugr_guerrier" if type == "guerrier" else ("draugr" if type == "sbire" else "bandit")

static func _defaut(n: String) -> ProfilCible:
	var p := ProfilCible.new()
	p.nom = n
	match n:
		"draugr":
			p.couleur_sang = Color(0.26, 0.04, 0.03)   # sang de mort-vivant : épais, sombre, encore rouge
			p.posture_max = 55.0   # un coup puissant chargé (42) ne brise plus la garde à lui seul
			p.resistances = {"tranchant": 1.0, "contondant": 1.0, "feu": 1.25, "glace": 1.0, "magique": 1.0, "electricite": 1.0, "tenebres": 0.7}   # mort-vivant (magie)
		"draugr_guerrier":
			p.armure_tete = 2.0     # casque
			p.armure_part = 0.08    # cotte de mailles
			p.couleur_sang = Color(0.26, 0.04, 0.03)
			p.posture_max = 70.0
			p.resistances = {"tranchant": 1.0, "contondant": 1.0, "feu": 1.25, "glace": 1.0, "magique": 1.0, "electricite": 1.15, "tenebres": 0.7}   # mort-vivant en mailles (magie)
			p.chance_blocage = 0.3
			p.seuil_moyen = 13.0
			p.seuil_lourd = 26.0
			p.poids = 1.1
		"squelette":
			p.matiere = "os"
			p.sang = false
			p.couleur_sang = Color(0.72, 0.68, 0.56)
			p.resistances = {"tranchant": 1.0, "contondant": 1.4, "feu": 0.9, "glace": 0.8, "magique": 1.2, "electricite": 0.9, "tenebres": 0.6}
			p.zones = {"tete": 1.4, "torse": 1.0, "bras": 0.8, "jambes": 0.9}
			p.posture_max = 45.0
			p.chance_blocage = 0.3
			p.poids = 0.8
		"bandit":
			p.armure_part = 0.05
			p.couleur_sang = Color(0.40, 0.025, 0.02)   # sang vivant, rouge franc
			p.mort_vivant = false
			p.posture_max = 55.0
			p.seuil_finisher_vie = 0.25
		"troll_givre":
			# mini-boss lourd : cuir épais mais pas d'armure (faible), posture très haute (poids 2 : le stagger reçu est divisé par 2),
			# jamais renversé ; vulnérable au feu, presque insensible au givre ; sang sombre, épais, violacé ; voix de bête (râles graves)
			p.armure = 1.0
			p.armure_part = 0.03
			p.resistances = {"tranchant": 1.0, "contondant": 0.9, "feu": 1.75, "glace": 0.25, "magique": 1.0, "electricite": 1.1, "tenebres": 1.0}
			p.zones = {"tete": 1.3, "torse": 1.0, "bras": 0.8, "jambes": 0.9}
			p.couleur_sang = Color(0.24, 0.045, 0.07)
			p.posture_max = 110.0
			p.posture_regen = 18.0
			p.posture_delai = 1.2
			p.seuil_moyen = 15.0
			p.seuil_lourd = 24.0
			p.seuil_chute = 999.0
			p.poids = 2.0
			p.duree_etourdi = 3.2
			p.seuil_finisher_vie = 0.15
		"mage_nordique":
			# lanceur de sorts : robe de laine, aucune armure, posture faible (chaque coup l'interrompt), facile à achever
			p.couleur_sang = Color(0.40, 0.025, 0.02)
			p.mort_vivant = false
			p.resistances = {"tranchant": 1.0, "contondant": 1.0, "feu": 1.25, "glace": 0.5, "magique": 0.8, "electricite": 1.3, "tenebres": 0.9}
			p.posture_max = 22.0
			p.posture_regen = 8.0
			p.posture_delai = 1.6
			p.seuil_moyen = 7.0
			p.seuil_lourd = 18.0
			p.seuil_chute = 24.0
			p.poids = 0.9
			p.duree_etourdi = 3.0
			p.seuil_finisher_vie = 0.25
		"mannequin":
			p.matiere = "bois"
			p.sang = false
			p.couleur_sang = Color(0.62, 0.48, 0.30)
			p.posture_max = 60.0
			p.posture_regen = 30.0
			p.posture_delai = 0.8
			p.duree_etourdi = 2.0
			p.poids = 1.5
	return p
