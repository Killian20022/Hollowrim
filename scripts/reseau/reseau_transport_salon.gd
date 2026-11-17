class_name ReseauSalonCode
extends RefCounted
## Codes de salon courts : 6 caractères, alphabet sans ambiguïté (ni 0/O ni 1/I/L), insensible à la casse et aux espaces.

const LONGUEUR := 6
const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

static func generer(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var s := ""
	for i in LONGUEUR:
		s += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	return s

## Remet un code saisi à la main sous forme canonique (majuscules, sans espaces ni tirets).
## Renvoie "" si ce ne peut pas être un code généré (mauvaise longueur ou caractère hors alphabet).
static func normaliser(saisie: String) -> String:
	var c := saisie.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if c.length() != LONGUEUR:
		return ""
	for ch in c:
		if not ALPHABET.contains(ch):
			return ""
	return c

static func est_valide(code: String) -> bool:
	return normaliser(code) != ""
