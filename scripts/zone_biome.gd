class_name ZoneBiome
## Zone témoin du nouveau biome : feu → rôdeur → cercle → tumulus.
## Hors zone, ou avec --biome=ancien, le masque vaut 0 : le monde reste celui d'avant.

const X0 := -58.0
const X1 := 4.0
const Z0 := -64.0
const Z1 := 4.0
const FONDU := 8.0  # largeur de la bande de transition, à l'intérieur de la zone (m)

## Disques réservés (composition, lot F) : [centre Vector2, rayon]. Évités par les rochers (lot B)
## et la végétation (lot E). Positions fixes (polaires autour du cercle (-38,-34), calculées une fois) :
## 2 menhirs couchés (r 11, 2,6 rad ; r 11,4, 4,2 rad), 3 arbres morts (r 11,5 / 12,2 / 11 ; 1,8 / 3,3 / 5,9 rad),
## 6 rochers bas, puis abords du tumulus (borne runique, 2 arbres morts des flancs).
## À garder en phase avec `CercleRunique.ELEMENTS` et `AbordsTumulus`.
const OCCUPATIONS := [
	[Vector2(-47.43, -28.33), 2.6], [Vector2(-43.59, -43.94), 3.2],
	[Vector2(-40.61, -22.80), 1.6], [Vector2(-50.05, -35.92), 1.6], [Vector2(-27.80, -38.11), 1.6],
	[Vector2(-35.70, -25.71), 1.0], [Vector2(-43.53, -26.40), 1.0], [Vector2(-48.29, -31.46), 1.0],
	[Vector2(-44.80, -39.26), 1.0], [Vector2(-28.26, -33.02), 1.0], [Vector2(-30.21, -37.14), 1.0],
	[Vector2(-32.20, -42.60), 1.5], [Vector2(-45.50, -58.50), 1.8], [Vector2(-30.50, -58.50), 1.8],
]

## Posé par monde._ready() (--biome=ancien|nouveau) avant toute génération.
static var actif := false

## 0 hors zone (ou si inactif), 1 au cœur, smoothstep dans la bande de fondu.
static func masque(x: float, z: float) -> float:
	if not actif:
		return 0.0
	var d := minf(minf(x - X0, X1 - x), minf(z - Z0, Z1 - z))
	if d <= 0.0:
		return 0.0
	return smoothstep(0.0, FONDU, d)

## Graine entière stable pour un système (RNG propre : "foret_zone", "sous_bois", "rochers_zone"…).
static func graine(nom: String) -> int:
	return 7919 + nom.hash() % 1000003

## Hachage déterministe d'une position, dans [0, 1) ; `sel` distingue plusieurs usages. Aucun RNG.
static func alea_pos(x: float, z: float, sel: int = 0) -> float:
	var h := (roundi(x * 64.0) * 73856093) ^ (roundi(z * 64.0) * 19349663) ^ (sel * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	h = (h * 668265263) & 0xffffffff
	return float(h & 0xffffff) / 16777216.0
