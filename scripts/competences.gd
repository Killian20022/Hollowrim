class_name Competences
extends RefCounted
## Progression par la pratique, à la Skyrim : chaque action utile fait gagner de l'expérience dans la compétence
## concernée ; passé un seuil, elle monte d'un niveau (15 → 100). Les 8 compétences du RPG (docs/RPG.md §5 et §13, lot B) :
##   epee (= « une_main »)  : toucher avec une arme à une main   → dégâts + GAIN_COMPETENCE_EPEE × part du niveau
##   deux_mains             : toucher avec une arme à deux mains → même bonus, avec son propre niveau
##   parade                 : bloquer un coup                    → dégâts bloqués et vigueur dépensée réduits
##   armure                 : encaisser un coup sans garde       → (arbre seulement)
##   destruction            : toucher avec un sort offensif      → (arbre seulement)
##   restauration           : vie rendue par le soin, coups absorbés par la protection → (arbre seulement)
##   furtivite              : attaque furtive                    → (arbre seulement)
##   athletisme             : courir                             → la course coûte moins de vigueur
## Le nom interne « epee » est gardé (sauvegardes v1, HUD, tests) ; Progression le traduit en « une_main » (ALIAS_COMPETENCES).
## Courbe (lot B) : seuil(n) = 0,025 n² − 1,5 : 15 → 16 en ~4 XP (quelques coups), 50 → 51 en ~61, 99 → 100 en ~244.
## Les perks de l'arbre (Progression.mult_global / bonus_global) s'ajoutent ici pour la parade et la course.

signal niveau_gagne(nom: String, niveau: int)

const NOMS := {"epee": "Une main", "deux_mains": "Deux mains", "parade": "Parade", "armure": "Armure", "destruction": "Destruction",
	"restauration": "Restauration", "furtivite": "Furtivité", "athletisme": "Athlétisme"}
const DEPART := 15
const MAXIMUM := 100

var niveaux := {}
var experience := {}

func _init() -> void:
	for nom in NOMS:
		niveaux[nom] = DEPART
		experience[nom] = 0.0

## Expérience nécessaire pour passer du niveau n au suivant (croissante : premiers niveaux rapides, puis ralentit).
static func seuil(n: int) -> float:
	return 0.025 * float(n * n) - 1.5

func pratiquer(nom: String, quantite: float) -> void:
	if not niveaux.has(nom) or niveaux[nom] >= MAXIMUM or quantite <= 0.0:
		return
	experience[nom] += quantite
	while niveaux[nom] < MAXIMUM and experience[nom] >= seuil(niveaux[nom]):
		experience[nom] -= seuil(niveaux[nom])
		niveaux[nom] += 1
		niveau_gagne.emit(nom, niveaux[nom])
	if niveaux[nom] >= MAXIMUM:
		experience[nom] = 0.0

## Part de la progression vers le niveau suivant (0 → 1), pour l'affichage.
func progression(nom: String) -> float:
	if int(niveaux.get(nom, MAXIMUM)) >= MAXIMUM:
		return 1.0
	return experience[nom] / seuil(niveaux[nom])

func bonus(nom: String) -> float:
	return float(int(niveaux.get(nom, DEPART)) - DEPART) / float(MAXIMUM - DEPART)

## Bonus de dégâts du niveau de la compétence d'arme (« epee » / « une_main », ou « deux_mains »). Les perks passent
## ailleurs (ReglagesCombat.competence_arme dans DegatsCombat.calculer).
func multiplicateur_degats(nom := "epee") -> float:
	return 1.0 + bonus("deux_mains" if nom == "deux_mains" else "epee") * ReglagesCombat.GAIN_COMPETENCE_EPEE

## Facteur des dégâts bloqués et de la vigueur dépensée en garde : niveau de Parade, puis perks « parade » (÷ mult).
func reduction_parade() -> float:
	return (1.0 - bonus("parade") * 0.5) / maxf(Progression.mult_global("parade"), 0.1)

## Facteur du coût de la course : niveau d'Athlétisme, puis perks « cout_course » (fraction en moins, plancher 0,2).
func cout_course() -> float:
	return (1.0 - bonus("athletisme") * 0.5) * maxf(0.2, 1.0 - Progression.bonus_global("cout_course"))

func exporter() -> Dictionary:
	return {"niveaux": niveaux.duplicate(), "experience": experience.duplicate()}

func importer(d: Dictionary) -> void:
	for nom in niveaux:
		niveaux[nom] = clampi(int(d.get("niveaux", {}).get(nom, DEPART)), DEPART, MAXIMUM)
		experience[nom] = maxf(0.0, float(d.get("experience", {}).get(nom, 0.0)))
