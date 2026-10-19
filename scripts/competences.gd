class_name Competences
extends RefCounted
## Progression par la pratique, à la Skyrim : chaque action utile fait gagner de l'expérience
## dans la compétence concernée ; passé un seuil, elle monte d'un niveau (15 → 100).
##   epee        : toucher un ennemi       → dégâts +0,5 % par niveau au-dessus de 15
##   parade      : bloquer un coup         → dégâts bloqués et vigueur dépensée réduits
##   athletisme  : courir                  → la course coûte moins de vigueur

signal niveau_gagne(nom: String, niveau: int)

const NOMS := {"epee": "Épée", "parade": "Parade", "athletisme": "Athlétisme"}
const DEPART := 15
const MAXIMUM := 100

var niveaux := {"epee": DEPART, "parade": DEPART, "athletisme": DEPART}
var experience := {"epee": 0.0, "parade": 0.0, "athletisme": 0.0}

## Expérience nécessaire pour passer du niveau n au suivant (croissante, comme dans Skyrim).
static func seuil(n: int) -> float:
	return 4.0 + pow(float(n), 1.6) * 0.18

func pratiquer(nom: String, quantite: float) -> void:
	if niveaux[nom] >= MAXIMUM:
		return
	experience[nom] += quantite
	while niveaux[nom] < MAXIMUM and experience[nom] >= seuil(niveaux[nom]):
		experience[nom] -= seuil(niveaux[nom])
		niveaux[nom] += 1
		niveau_gagne.emit(nom, niveaux[nom])

## Part de la progression vers le niveau suivant (0 → 1), pour l'affichage.
func progression(nom: String) -> float:
	return experience[nom] / seuil(niveaux[nom])

func bonus(nom: String) -> float:
	return float(niveaux[nom] - DEPART) / float(MAXIMUM - DEPART)

func multiplicateur_degats() -> float:
	return 1.0 + bonus("epee") * 0.6

func reduction_parade() -> float:
	return 1.0 - bonus("parade") * 0.5

func cout_course() -> float:
	return 1.0 - bonus("athletisme") * 0.5

func exporter() -> Dictionary:
	return {"niveaux": niveaux.duplicate(), "experience": experience.duplicate()}

func importer(d: Dictionary) -> void:
	for nom in niveaux:
		niveaux[nom] = int(d.get("niveaux", {}).get(nom, DEPART))
		experience[nom] = float(d.get("experience", {}).get(nom, 0.0))
