class_name DegatsCombat
## Calcul et application des dégâts d'un coup du joueur. Interface des cibles (contrat commun avec combat/degats_gore) :
##   recevoir_coup(degats: float, origine: Vector3, puissant: bool, info: Dictionary = {}) -> "touche" | "tue" | "bloque" | ""
## Le 4e paramètre est passé seulement si la méthode de la cible l'accepte (les ennemis à 3 paramètres marchent
## toujours). info : type ("tranchant"), point (impact monde), direction (mouvement de la lame au contact, normalisé),
## normale, zone ("tete" / "torse" / "bras" / "jambes" / ""), attaque ("legere" / "lourde" / "chargee_max" / "contre"),
## arme (id de la DonneesArme), stagger (force de déséquilibre), collider (nœud touché).
## Extension facultative : noter_impact(point, direction), appelée avant recevoir_coup (mannequin : chiffre de dégâts).

## Coup affaibli (endurance insuffisante) : dégâts multipliés, jamais « puissant ».
const AFFAIBLI := 0.5

## Dégâts d'un coup : base de l'arme × charge (lourd) × compétence × trophée × affaibli.
static func calculer(arme: DonneesArme, lourd: bool, charge: float, affaibli: bool, mult_competence: float, bonus_trophee: float) -> float:
	var base := arme.degats_lourd * lerpf(1.0, arme.bonus_charge_max, clampf(charge, 0.0, 1.0)) if lourd else arme.degats_leger
	if affaibli:
		base *= AFFAIBLI
	# progression (arbre de compétences à venir) : multiplicateur de la famille d'arme, 1,0 pour l'instant (ReglagesCombat)
	return base * mult_competence * bonus_trophee * ReglagesCombat.competence_arme(arme.famille, arme.deux_mains)

## Force de déséquilibre (stagger) d'un coup, dans l'unité des postures ennemies (CalculDegats.STAGGER : léger 12, lourd 28,
## chargé 42, contre 34) × le déséquilibre propre de l'arme rapporté à l'épée de métal (léger 0,3 ; lourd 0,7) ; la charge
## ajoute jusqu'à +50 % au coup lourd (pleine charge = 42 pour l'épée de métal).
const DESEQUILIBRE_REF_LEGER := 0.3
const DESEQUILIBRE_REF_LOURD := 0.7
static func stagger(arme: DonneesArme, attaque: String, charge := 0.0) -> float:
	match attaque:
		"legere":
			return CalculDegats.STAGGER["legere"] * arme.desequilibre_leger / DESEQUILIBRE_REF_LEGER
		"contre":
			return CalculDegats.STAGGER["contre"] * arme.desequilibre_lourd / DESEQUILIBRE_REF_LOURD
	return CalculDegats.STAGGER["lourde"] * arme.desequilibre_lourd / DESEQUILIBRE_REF_LOURD * (1.0 + clampf(charge, 0.0, 1.0) * 0.5)

static func appliquer(cible: Node, degats: float, origine: Vector3, puissant: bool, info: Dictionary) -> String:
	if cible == null or not is_instance_valid(cible):
		return ""
	if cible.has_method("noter_impact"):
		cible.noter_impact(info.get("point", Vector3.ZERO), info.get("direction", Vector3.ZERO))
	if not cible.has_method("recevoir_coup"):
		return ""
	# magie (docs/MAGIE.md) : corruption, lame enchantée, combos épée + statut, puis réaction / statut / drain après le coup
	degats = Elements.avant_coup(cible, degats, info)
	var res := ""
	if cible.get_method_argument_count("recevoir_coup") >= 4:
		res = String(cible.recevoir_coup(degats, origine, puissant, info))
	else:
		res = String(cible.recevoir_coup(degats, origine, puissant))
	Elements.apres_coup(cible, res, info, degats)
	return res

## Zone touchée d'après la hauteur du point d'impact sur la cible (pieds à son origine, taille 1,8 m × echelle) et son
## écart latéral : tête au-dessus de 83 %, jambes sous 45 %, bras sur les côtés du torse.
static func zone(cible: Node3D, point: Vector3) -> String:
	if cible == null:
		return ""
	var echelle: float = float(cible.get("echelle")) if cible.get("echelle") != null else 1.0
	var local := cible.global_transform.affine_inverse() * point
	var h := local.y / (1.8 * echelle)
	if h > 0.83:
		return "tete"
	if h < 0.45:
		return "jambes"
	if absf(local.x) > 0.24 * echelle:
		return "bras"
	return "torse"
