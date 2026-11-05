class_name ChargeSort
extends RefCounted
## CHARGE COMMUNE des sorts (réglages : data/magie/charge_sorts.json ; docs/MAGIE.md « Sorts lancés chargés »). Un seul
## mécanisme pour tous les sorts qui se chargent, jamais un sort par son nom :
##   - famille « projectile chargé » (type CHARGE + portée PROJECTILE : boule de feu, éclat de glace, lance de givre, trait
##     d'ombre…) : temps de charge, dégâts, coût et taille du projectile viennent TOUS du fichier de réglages ;
##   - les autres sorts à charge (rayon du néant, orage runique, zones chargées) gardent leurs champs de .tres (temps_charge,
##     degats_charge_min, cout_charge_min) mais partagent le ralenti du joueur, la pulsation et le son de la charge pleine.
## Machine à états : MainSort / Incantation (INCANTE → CHARGE → relâcher) ; dégâts et coût : LanceurSorts.facteur_charge / cout.

const FICHIER := "res://data/magie/charge_sorts.json"
## Charge considérée comme pleine (évite les arrondis de i.t / temps).
const PLEIN := 0.999

static var _r := {}

static func reglages() -> Dictionary:
	if _r.is_empty():
		var f := FileAccess.open(FICHIER, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_r = d if d is Dictionary else {}
		if _r.is_empty():
			push_warning("ChargeSort : %s illisible, valeurs par défaut" % FICHIER)
			_r = {"_defaut": true}
	return _r

static func reglage(cle: String, defaut: float) -> float:
	return float(reglages().get(cle, defaut))

## Sort de la famille « projectile chargé » (réglages communs).
static func projectile(s: DonneesSort) -> bool:
	return s != null and s.type == DonneesSort.Type.CHARGE and s.portee_mode == DonneesSort.Portee.PROJECTILE

static func pleine(charge: float) -> bool:
	return charge >= PLEIN

## Temps (s) de la charge, après l'incantation, jusqu'au maximum.
static func temps_plein(s: DonneesSort) -> float:
	return reglage("temps_plein", 1.2) if projectile(s) else maxf(s.temps_charge, 0.01)

## Part des dégâts (× s.degats) selon la charge 0..1 ; 1 hors charge.
static func facteur_degats(s: DonneesSort, charge: float) -> float:
	if s == null or not s.se_charge():
		return 1.0
	var c := clampf(charge, 0.0, 1.0)
	if projectile(s):
		if pleine(c):
			return 1.0
		return lerpf(reglage("part_degats_tap", 0.5), reglage("part_degats_avant_plein", 0.72), c)
	return lerpf(s.degats_charge_min, 1.0, c)

## Part du coût (× s.cout) selon la charge ; 1 hors charge.
static func facteur_cout(s: DonneesSort, charge: float) -> float:
	if s == null or not s.se_charge():
		return 1.0
	var c := clampf(charge, 0.0, 1.0)
	return lerpf(reglage("part_cout_tap", 0.5) if projectile(s) else s.cout_charge_min, 1.0, c)

## Échelle du visuel du projectile selon la charge (1 hors famille).
static func taille(s: DonneesSort, charge: float) -> float:
	if not projectile(s):
		return 1.0
	var c := clampf(charge, 0.0, 1.0)
	if pleine(c):
		return reglage("taille_plein", 1.5)
	return lerpf(reglage("taille_tap", 0.8), reglage("taille_avant_plein", 1.12), c)

## Facteur de vitesse du joueur pendant l'incantation / la charge d'un sort qui se charge.
static func vitesse_joueur() -> float:
	return clampf(reglage("vitesse_joueur", 0.65), 0.1, 1.0)

## Pulsation de la charge pleine (`t` = s depuis le maximum) : 0..1 par PALIERS francs (gros pixels, pas de sinus lisse) ;
## le premier instant est au plus haut (le « clic » du maximum se voit tout de suite).
static func pulsation(t: float) -> float:
	var n := maxi(2, int(reglage("pulsation_paliers", 3)))
	var u := fposmod(t * reglage("pulsation_hz", 3.0), 1.0)
	var tri := 1.0 - absf(u * 2.0 - 1.0)   # 0 → 1 → 0 sur une période
	tri = 1.0 - tri                        # départ au plus haut
	return floorf(tri * float(n) + 0.5) / float(n)
