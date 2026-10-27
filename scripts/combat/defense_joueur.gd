class_name DefenseJoueur
extends RefCounted
## Défense du joueur (phase 3, docs/COMBAT.md) : garde orientée, réduction et coût d'endurance selon l'arme (DonneesArme),
## garde brisée à 0 d'endurance, parade parfaite (fenêtre courte, anti-spam), fenêtre de contre-attaque.
## Logique pure (aucun nœud) : mains.gd l'avance et lui signale les levées de garde ; joueur.recevoir_coup lui soumet les
## coups reçus (encaisser). Tous les réglages sont ici.

## Angle de défense : la garde couvre un cône de ANGLE_DEFENSE degrés devant le joueur (rien dans le dos).
const ANGLE_DEFENSE := 120.0
## Parade parfaite : coup reçu dans les FENETRE_PARADE premières secondes de la garde.
const FENETRE_PARADE := 0.18
## Anti-spam : chaque levée de garde dans les SPAM_DELAI s qui suivent la précédente réduit la fenêtre de SPAM_PAS s
## (au plus jusqu'à FENETRE_MIN) ; une levée après SPAM_DELAI s de calme retrouve la fenêtre entière.
const SPAM_DELAI := 0.9
const SPAM_PAS := 0.045
const FENETRE_MIN := 0.04
## Coût d'endurance d'un coup bloqué : dégâts × COUT_BLOCAGE × (compétence Parade) × cout_garde de l'arme ; parade : × COUT_PARADE.
const COUT_BLOCAGE := 1.1
const COUT_PARADE := 0.3
## Garde brisée (l'endurance ne suffit pas à payer un coup bloqué) : titube TITUBE s, garde impossible GARDE_IMPOSSIBLE s ;
## le coup qui brise passe en partie (PART_BRISEE des dégâts non réduits).
const TITUBE := 0.45
const GARDE_IMPOSSIBLE := 1.0
const PART_BRISEE := 0.5
## Contre-attaque : fenêtre après une parade parfaite (s).
const FENETRE_CONTRE := 0.6

## Temps depuis la levée de la garde (s).
var temps_garde := 9.0
## Fenêtre de parade de la levée en cours (réduite par l'anti-spam).
var fenetre := FENETRE_PARADE
## Levées récentes (anti-spam) et temps depuis la dernière.
var levees := 0
var _depuis_levee := 9.0
## Garde impossible encore `brisee` s ; titube encore `titube` s.
var brisee := 0.0
var titube := 0.0
## Fenêtre de contre-attaque restante (s) ; position de l'attaquant paré.
var contre := 0.0
var origine_paree := Vector3.ZERO
## Compteurs (débogage, tests).
var nb_bloques := 0
var nb_parades := 0
var nb_brisees := 0

func avancer(dt: float) -> void:
	temps_garde += dt
	_depuis_levee += dt
	brisee = maxf(0.0, brisee - dt)
	titube = maxf(0.0, titube - dt)
	contre = maxf(0.0, contre - dt)

## Garde levée maintenant : fenêtre de parade de cette levée (anti-spam).
func lever() -> void:
	levees = levees + 1 if _depuis_levee < SPAM_DELAI else 0
	_depuis_levee = 0.0
	temps_garde = 0.0
	fenetre = maxf(FENETRE_MIN, FENETRE_PARADE - SPAM_PAS * levees)

func peut_garder() -> bool:
	return brisee <= 0.0

func en_parade() -> bool:
	return temps_garde < fenetre

## Le coup venu de `origine` est-il dans le cône de garde du joueur ?
static func couvre(joueur: Node3D, origine: Vector3) -> bool:
	var vers := origine - joueur.global_position
	vers.y = 0.0
	if vers.length() < 0.01:
		return true
	var face := -joueur.global_transform.basis.z
	face.y = 0.0
	return vers.normalized().dot(face.normalized()) >= cos(deg_to_rad(ANGLE_DEFENSE * 0.5))

## Coup reçu en garde levée et couverte. Renvoie {issue: "parade" | "bloque" | "brisee", degats: dégâts qui passent,
## cout: endurance dépensée}. `vigueur` : endurance actuelle ; `reduction_competence` : Competences.reduction_parade().
func encaisser(degats: float, vigueur: float, arme: DonneesArme, reduction_competence: float, origine: Vector3) -> Dictionary:
	var parade := en_parade()
	var cout := degats * (COUT_PARADE if parade else COUT_BLOCAGE) * reduction_competence * arme.cout_garde
	if parade and vigueur > 0.0:
		nb_parades += 1
		contre = FENETRE_CONTRE
		origine_paree = origine
		return {"issue": "parade", "degats": 0.0, "cout": minf(cout, vigueur)}
	if vigueur <= cout:
		# l'endurance ne suffit pas : la garde cède, une partie du coup passe
		nb_brisees += 1
		brisee = GARDE_IMPOSSIBLE
		titube = TITUBE
		return {"issue": "brisee", "degats": degats * PART_BRISEE, "cout": vigueur}
	nb_bloques += 1
	return {"issue": "bloque", "degats": degats * (1.0 - arme.reduction_garde) * reduction_competence, "cout": cout}
