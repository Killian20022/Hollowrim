class_name RetourCoups
## Retours sensoriels des coups du joueur sur ce qui n'a pas de CombatEnnemi (décor, murs, dragon…), réglables ici.
## Arrêt sur image, secousse et voile rouge d'un coup qui PORTE : une seule source, les profils d'impact (ProfilImpact,
## RetourImpact.jouer) ; les cibles équipées d'un CombatEnnemi (draugrs, mannequin) les jouent elles-mêmes avec le profil
## calculé (léger, moyen, lourd, critique, finisher) — mains.gd n'en rajoute pas.

## Arrêt sur image et ralenti : false = coupés (tests à pas fixe) ; lu aussi par RetourImpact.jouer.
static var arret_actif := true
## Secousse de caméra (échelle de joueur.secousse, décroît de 1,8 par seconde).
const SECOUSSE_MUR := 0.18
const SECOUSSE_BLOQUE := 0.3

## Coup qui porte sur une cible sans CombatEnnemi : profil d'impact « leger » ou « lourd ».
static func touche(joueur: Node, lourd: bool) -> void:
	RetourImpact.jouer(joueur, ProfilImpact.de("lourd" if lourd else "leger"), joueur)

static func bloque(joueur: Node) -> void:
	joueur.secousse = maxf(joueur.secousse, SECOUSSE_BLOQUE)

## La lame heurte le décor : quelques étincelles carrées et un choc métallique, la main rebondit.
static func mur(joueur: Node, point: Vector3, normale: Vector3, materiau: String) -> void:
	var bois := materiau == "bois"
	# gerbe de gros pixels (GerbePixels) : échardes sur le bois ; gravillons + étincelles sur la pierre et le métal
	var d := (normale + Vector3.UP * 0.3).normalized()
	if bois:
		GerbePixels.emettre(joueur, point + normale * 0.03, d, "bois", 0.9)
	else:
		GerbePixels.emettre(joueur, point + normale * 0.03, d, "pierre", 0.8)
		GerbePixels.emettre(joueur, point + normale * 0.03, d, "etincelles", 1.0)
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
