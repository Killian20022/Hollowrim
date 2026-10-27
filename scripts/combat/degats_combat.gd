class_name DegatsCombat
## Calcul et application des dégâts d'un coup du joueur. L'interface des cibles reste celle des ennemis existants :
##   recevoir_coup(degats: float, origine: Vector3, puissant: bool) -> "touche" | "tue" | "bloque" | ""
## Extension facultative (n'oblige aucun ennemi existant à changer) : noter_impact(point: Vector3, direction: Vector3),
## appelée juste avant recevoir_coup quand la cible la possède (mannequin : chiffre de dégâts au point touché).

## Coup affaibli (endurance insuffisante) : dégâts multipliés, jamais « puissant ».
const AFFAIBLI := 0.5

## Dégâts d'un coup : base de l'arme × charge (lourd) × compétence × trophée × affaibli.
static func calculer(arme: DonneesArme, lourd: bool, charge: float, affaibli: bool, mult_competence: float, bonus_trophee: float) -> float:
	var base := arme.degats_lourd * lerpf(1.0, arme.bonus_charge_max, clampf(charge, 0.0, 1.0)) if lourd else arme.degats_leger
	if affaibli:
		base *= AFFAIBLI
	return base * mult_competence * bonus_trophee

static func appliquer(cible: Node, degats: float, origine: Vector3, puissant: bool, point: Vector3, direction: Vector3) -> String:
	if cible == null or not is_instance_valid(cible):
		return ""
	if cible.has_method("noter_impact"):
		cible.noter_impact(point, direction)
	if cible.has_method("recevoir_coup"):
		return String(cible.recevoir_coup(degats, origine, puissant))
	return ""
