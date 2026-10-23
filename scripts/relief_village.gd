class_name ReliefVillage
## Relief du village v2 (lot C7a, plan docs/PLAN_VILLAGE_V2.md) : remplace l'ancien disque aplani (r 25 m autour de (44 ; 40)).
## Appelé par `monde.hauteur` (via _hauteur_ancienne / hauteur_sans_chemin) : `aplani(x, z, h_naturel, h_plateau)`.
##
## 1. EMPRISE : polygone de la palissade prolongée (PALISSADE) ; dedans + MARGE m la surface cible est imposée, puis raccord au
##    relief naturel sur FONDU m (smoothstep). Marge réduite à l'ouest (bord du lac) et près de la grille E (la rivière descend
##    du versant jusqu'à la palissade).
## 2. CIBLE : plateau plat à h_plateau (= monde.h_village = 3,6 m) jusqu'à z = 66, puis la HAUTE RUE : 3 bandes de terrasses
##    (T1 6,0 / T2 8,8 / T3 12,0 m) séparées par des transitions d'UNE case de maillage (2 m) = emplacement des murs de
##    soutènement, et un COULOIR D'ESCALIER (x 42..46, axe x = 44) creusé dans les bandes : 3 rampes de 4 m (≤ 39°) qui sont
##    à la fois le sol marchable et la future rampe de collision des marches. Tout est calé sur les sommets du maillage
##    (coordonnées paires) : le maillage du terrain reproduit exactement la cible (pas d'écart visuel/collision).
## 3. LIT DE LA RIVIÈRE : creusé « sec » (min) le long de RIVIERE, du bassin de la source (86,5 ; 58) au lac (12 ; 61) :
##    fond plat à eau − 0,6 m, rive jusqu'au niveau de l'eau, berge à PENTE_BERGE. Le niveau d'eau est donné par `niveau_eau`.
## Pour poser un objet sur le sol EXACT (collision) : DetailsSol.hauteur_maillage(monde, x, z).

const PALISSADE := [
	Vector2(20, 34), Vector2(27.7, 25.2), Vector2(36, 15), Vector2(54, 14.3), Vector2(60, 14), Vector2(72, 24),
	Vector2(73.5, 36), Vector2(74, 48), Vector2(66, 56), Vector2(65, 61.5), Vector2(63, 68), Vector2(60, 91),
	Vector2(32, 91), Vector2(28, 68), Vector2(23, 67), Vector2(19.5, 61.5), Vector2(15, 52)]
const BOITE := Rect2(-2.0, 0.0, 104.0, 106.0)  # hors de cette boîte : rien ne change (x -2..102, z 0..106)
const MARGE := 2.5            # m au-delà de la palissade où la cible reste imposée
const MARGE_OUEST := 1.0      # côté lac (x < 24)
const FONDU := 9.0            # raccord au relief naturel
const FONDU_OUEST := 7.0
const FONDU_RIVIERE := 6.0    # le long de la rivière, à l'est de la grille E

const H_T1 := 6.0
const H_T2 := 8.8
const H_T3 := 12.0
const Z_HAUTE_RUE := 66.0     # au nord : plateau ; au sud : terrasses
## Transitions des bandes (murs de soutènement) : [z_bas, z_haut, h_haut], de part et d'autre du couloir d'escalier.
## Ouest (x < 44) : T1 z 68..74 (6 m de fond pour H3), T2 76..78, T3 dès 80. Est : T1 68..72, T2 74..80 (pour H4), T3 dès 82.
const MURS_OUEST := [[66.0, 68.0, H_T1], [74.0, 76.0, H_T2], [78.0, 80.0, H_T3]]
const MURS_EST := [[66.0, 68.0, H_T1], [72.0, 74.0, H_T2], [80.0, 82.0, H_T3]]
## Couloir d'escalier : fond plat |x − 44| ≤ 2, joues d'une case (2 m) jusqu'aux bandes.
const ESCALIER_X := 44.0
const ESCALIER_DEMI := 2.0
const ESCALIER_JOUE := 2.0
## Volées (rampes) : [z_début, z_fin, h_fin] ; la 1re part de h_plateau. Paliers : T1 z 70..72, T2 76..78, T3 dès 82.
const VOLEES := [[66.0, 70.0, H_T1], [72.0, 76.0, H_T2], [78.0, 82.0, H_T3]]

## Rivière : [x, z, demi-largeur, niveau d'eau], de la source (bassin) vers le lac. Pente régulière bassin → grille E,
## 1 % sur le plateau, petite cascade (22 → 18) du moulin, puis niveau du lac (-0,8).
const RIVIERE := [
	[86.5, 58.0, 2.2, 12.5], [80.0, 59.0, 1.5, 9.66], [74.0, 60.0, 1.75, 6.8], [68.0, 61.0, 2.0, 3.8],
	[65.0, 61.5, 2.25, 3.05], [60.0, 61.5, 2.5, 3.0], [50.0, 61.5, 2.5, 2.89], [44.0, 61.5, 2.5, 2.82],
	[34.0, 61.0, 2.5, 2.71], [24.0, 61.0, 2.4, 2.6], [22.0, 61.0, 2.0, 2.6], [18.0, 61.0, 2.0, -0.8], [12.0, 61.0, 2.0, -0.8]]
const PROFONDEUR := 0.6       # fond du lit sous l'eau
const RIVE := 0.8             # largeur de la rive (fond → niveau de l'eau)
const PENTE_BERGE := 0.9      # berge au-dessus de l'eau (m par m)

# ------------------------------------------------------------------ relief

## Relief du village : `h` = relief naturel, `h0` = niveau du plateau (monde.h_village).
static func aplani(x: float, z: float, h: float, h0: float) -> float:
	if not BOITE.has_point(Vector2(x, z)):
		return h
	var w := poids(x, z)
	if w > 0.0:
		h = lerpf(h, cible(x, z, h0), w)
	return minf(h, lit(x, z))

## Poids de la surface cible (1 dans l'enceinte + marge, 0 au-delà du raccord).
static func poids(x: float, z: float) -> float:
	var d := distance_palissade(x, z)
	var ouest := 1.0 - smoothstep(20.0, 28.0, x)
	var marge := lerpf(MARGE, MARGE_OUEST, ouest)
	var fondu := lerpf(FONDU, FONDU_OUEST, ouest)
	# rivière à l'est de la grille E : elle dévale le versant jusqu'à la palissade ; le versant reste naturel (sinon ses
	# berges tomberaient sous l'eau) et le raccord y est court
	var riv_est := (1.0 - smoothstep(6.0, 12.0, absf(z - 61.0))) * smoothstep(60.0, 66.0, x)
	marge = lerpf(marge, 0.0, riv_est)
	fondu = lerpf(fondu, FONDU_RIVIERE, riv_est)
	return 1.0 - smoothstep(marge, marge + fondu, d)

## Surface voulue (sans raccord ni lit) : plateau, bandes de la haute rue et couloir d'escalier.
static func cible(x: float, z: float, h0: float) -> float:
	if z <= Z_HAUTE_RUE:
		return h0
	var bande := _profil(z, h0, MURS_OUEST if x < ESCALIER_X else MURS_EST)
	var rampe := _profil(z, h0, VOLEES)
	var k := clampf((absf(x - ESCALIER_X) - ESCALIER_DEMI) / ESCALIER_JOUE, 0.0, 1.0)
	return lerpf(rampe, bande, k)

static func _profil(z: float, h0: float, paliers: Array) -> float:
	var h := h0
	for p: Array in paliers:
		var t := clampf((z - float(p[0])) / (float(p[1]) - float(p[0])), 0.0, 1.0)
		h = lerpf(h, float(p[2]), t) if t < 1.0 else float(p[2])
		if t < 1.0:
			break
	return h

## Hauteur du lit (INF loin de la rivière) : fond plat, rive, berge.
static func lit(x: float, z: float) -> float:
	var r := riviere(x, z)
	if r.is_empty():
		return INF
	var d: float = r["distance"]
	var hw: float = r["demi_largeur"]
	var eau: float = r["eau"]
	if d <= hw - RIVE:
		return eau - PROFONDEUR
	if d <= hw:
		return eau - PROFONDEUR * (hw - d) / RIVE
	return eau + (d - hw) * PENTE_BERGE

## Point de la rivière le plus proche : {distance, demi_largeur, eau, abscisse (m depuis le bassin), direction (Vector2 aval)}.
## Vide à plus de 12 m de l'axe.
static func riviere(x: float, z: float) -> Dictionary:
	var p := Vector2(x, z)
	var meilleur := {}
	var dmin := 12.0
	var s0 := 0.0
	for i in RIVIERE.size() - 1:
		var a := Vector2(RIVIERE[i][0], RIVIERE[i][1])
		var b := Vector2(RIVIERE[i + 1][0], RIVIERE[i + 1][1])
		var ab := b - a
		var l := ab.length()
		var t := clampf((p - a).dot(ab) / (l * l), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < dmin:
			dmin = d
			meilleur = {
				"distance": d,
				"demi_largeur": lerpf(RIVIERE[i][2], RIVIERE[i + 1][2], t),
				"eau": lerpf(RIVIERE[i][3], RIVIERE[i + 1][3], t),
				"abscisse": s0 + l * t,
				"direction": ab / l,
			}
		s0 += l
	return meilleur

## Niveau de l'eau à l'aplomb de (x, z) (NAN hors du lit mouillé) — pour C7c (surface d'eau, pont, quai, roue).
static func niveau_eau(x: float, z: float) -> float:
	var r := riviere(x, z)
	if r.is_empty() or float(r["distance"]) > float(r["demi_largeur"]):
		return NAN
	return r["eau"]

# ------------------------------------------------------------------ emprise

## Distance signée à la palissade (négative dedans).
static func distance_palissade(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var dmin := INF
	var dedans := false
	var n := PALISSADE.size()
	for i in n:
		var a: Vector2 = PALISSADE[i]
		var b: Vector2 = PALISSADE[(i + 1) % n]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		dmin = minf(dmin, p.distance_to(a + ab * t))
		if (a.y > p.y) != (b.y > p.y) and p.x < a.x + (p.y - a.y) * ab.x / ab.y:
			dedans = not dedans
	return -dmin if dedans else dmin

static func dans_enceinte(x: float, z: float, marge := 0.0) -> bool:
	return distance_palissade(x, z) < marge

## Zone à dégager d'arbres et de rochers : enceinte + 1,5 m et lit de la rivière + 2 m (jusqu'au lac).
static func exclu(x: float, z: float) -> bool:
	if VillageBati.exclu(x, z):
		return true   # C7b : fermes, granges et moulin à vent hors enceinte
	if not BOITE.has_point(Vector2(x, z)):
		return false
	if distance_palissade(x, z) < 1.5:
		return true
	if x < 17.0:
		return false
	var r := riviere(x, z)
	return not r.is_empty() and float(r["distance"]) < float(r["demi_largeur"]) + 2.0

## Terrasse (nom) sous (x, z) dans l'enceinte : "plateau", "T1", "T2", "T3", "escalier", "mur" (transition) ou "" dehors.
static func terrasse(x: float, z: float, h0: float) -> String:
	if not dans_enceinte(x, z):
		return ""
	var h := cible(x, z, h0)
	if absf(x - ESCALIER_X) < ESCALIER_DEMI + ESCALIER_JOUE and z > Z_HAUTE_RUE and z < 82.0:
		if not [H_T1, H_T2, H_T3].any(func(v: float) -> bool: return absf(h - v) < 0.01):
			return "escalier"
	for e: Array in [[h0, "plateau"], [H_T1, "T1"], [H_T2, "T2"], [H_T3, "T3"]]:
		if absf(h - float(e[0])) < 0.01:
			return e[1]
	return "mur"
