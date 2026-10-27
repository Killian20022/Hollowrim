class_name RetourCoups
## Retours sensoriels des coups du joueur (son, étincelles, arrêt sur image, secousse de caméra), réglables ici.
## Les ennemis jouent eux-mêmes leur son de chair et leurs éclats (draugr.recevoir_coup) : on n'en rajoute pas.

## Arrêt sur image (s de temps réel) : bref, configurable ; false = coupé (tests à pas fixe).
static var arret_actif := true
const ARRET_LEGER := 0.05
const ARRET_LOURD := 0.10
## Secousse de caméra (échelle de joueur.secousse, décroît de 1,8 par seconde).
const SECOUSSE_LEGER := 0.22
const SECOUSSE_LOURD := 0.45
const SECOUSSE_MUR := 0.18
const SECOUSSE_BLOQUE := 0.3

static func touche(joueur: Node, lourd: bool) -> void:
	if arret_actif:
		Effets.arret_image(joueur.get_tree(), ARRET_LOURD if lourd else ARRET_LEGER)
	joueur.secousse = maxf(joueur.secousse, SECOUSSE_LOURD if lourd else SECOUSSE_LEGER)

static func bloque(joueur: Node) -> void:
	joueur.secousse = maxf(joueur.secousse, SECOUSSE_BLOQUE)

## La lame heurte le décor : quelques étincelles carrées et un choc métallique, la main rebondit.
static func mur(joueur: Node, point: Vector3, normale: Vector3, materiau: String) -> void:
	var bois := materiau == "bois"
	Effets.eclats(joueur, point + normale * 0.03, Color(0.6, 0.45, 0.3) if bois else Color(3.0, 2.1, 0.7), 6 if bois else 9, 2.2, not bois)
	Sons.jouer_a(joueur, ["impactWood_heavy_000"] if bois else ["impactPlate_medium_000", "impactPlate_medium_001"], point, -4.0, 0.15)
	joueur.secousse = maxf(joueur.secousse, SECOUSSE_MUR)

## Charge maximale atteinte : tintement discret et reflet sur la lame (pas d'effet envahissant).
static func charge_max(mains: Node3D, acier: ShaderMaterial, emission_base: Color) -> void:
	Sons.jouer(mains, ["impactMetal_heavy_001"], -20.0, 0.02)
	if acier == null:
		return
	var t := mains.create_tween()
	t.tween_method(func(k: float) -> void:
		acier.set_shader_parameter("emission", emission_base + Color(0.35, 0.3, 0.22) * k), 1.0, 0.0, 0.35)
