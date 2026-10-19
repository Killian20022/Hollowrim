class_name ZoneBiome
## Zone témoin du nouveau biome : feu → rôdeur → cercle → tumulus.
## Hors zone, ou avec --biome=ancien, le masque vaut 0 : le monde reste celui d'avant.

const X0 := -58.0
const X1 := 4.0
const Z0 := -64.0
const Z1 := 4.0
const FONDU := 8.0  # largeur de la bande de transition, à l'intérieur de la zone (m)

## Disques réservés (composition) : [centre Vector2, rayon]. Vide pour l'instant.
const OCCUPATIONS := []

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
