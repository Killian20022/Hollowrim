class_name PersoDefs
## Definitions des personnages vivants (PersoDef) : habitants du hameau, bandits de la grotte, joueur. Voir docs/PERSONNAGES_TECH.md pour creer une variante.
## Une variante tient en un dictionnaire : morphologie, tete 1-3, coiffure 0-3, barbe 0-2, couleurs (noms de palette ou Color), accessoires.

static var _cache := {}

const VILLAGEOIS := {
	# Gunnhild, la cheffe : robe bleue sur tunique de lin, mante de fourrure blanche, cuir clair
	"chef": {"corps": "femme", "tete": 2, "cheveux": 2, "couleur_cheveux": Color("#d9b46e"), "tunique": "lin", "sur": "bleu", "pantalon": "bleu",
		"cuir": "cuir_c", "fourrure": "blanc", "accessoires": ["robe", "cape_courte"], "iris": Color("#3f6f9a")},
	# Brodd, le forgeron : bras nus massifs, tablier de cuir, barbe courte, bourse
	"forgeron": {"corps": "homme", "tete": 1, "cheveux": 1, "barbe": 1, "couleur_cheveux": Color("#5a3820"), "peau": Color("#e2b392"), "tunique": "brun",
		"sur": "cuir", "pantalon": "noir", "cuir": "cuir_b", "accessoires": ["tablier", "sacoche"]},
	# Ylva, la chasseuse : capuche verte, fourrure brune, carquois, bourse
	"chasseuse": {"corps": "femme", "tete": 3, "cheveux": 3, "couleur_cheveux": Color("#b5502a"), "tunique": "mousse", "sur": "mousse", "pantalon": "brun",
		"cuir": "cuir_a", "fourrure": "brun", "accessoires": ["capuche", "cape_courte", "carquois", "sacoche"], "iris": Color("#5a7a4a")},
	# Sigrun, la volva : longue robe, grande cape a capuche violette
	"volva": {"corps": "femme", "tete": 2, "cheveux": 2, "couleur_cheveux": Color("#dddde6"), "peau": Color("#e6d2c6"), "tunique": "violet", "sur": "violet",
		"pantalon": "gris", "cuir": "cuir_b", "fourrure": "gris", "accessoires": ["robe", "cape_longue", "capuche"], "iris": Color("#7a5aa0")},
	# Haldor, le garde : tunique rouge, epaulieres, lanieres, cape courte, casque et bouclier
	"garde": {"corps": "homme", "tete": 1, "cheveux": 2, "barbe": 1, "couleur_cheveux": Color("#8a5f38"), "tunique": Color("#8a3228"), "sur": "gris", "pantalon": "gris",
		"cuir": "cuir_b", "fourrure": "gris", "accessoires": ["cape_courte", "epaulieres", "pteruges"], "casque": "casque_nasal", "bouclier": true},
	# Grima, l'ancienne : robe grise, foulard, chale de laine
	"ancienne": {"corps": "femme", "tete": 3, "cheveux": 3, "couleur_cheveux": Color("#e6e6e6"), "peau": Color("#e3cfc2"), "tunique": "lin", "sur": "gris",
		"pantalon": "lin", "cuir": "cuir_c", "fourrure": "gris", "accessoires": ["robe", "capuche", "cape_courte"]},
}

const BANDITS := [
	{"corps": "homme", "tete": 2, "cheveux": 1, "barbe": 1, "couleur_cheveux": Color("#4a2e18"), "peau": Color("#eec9b3"), "tunique": "cuir", "sur": "brun", "pantalon": "brun",
		"cuir": "cuir_b", "fourrure": "brun", "accessoires": ["capuche", "cape_courte", "sacoche"]},
	{"corps": "homme", "tete": 1, "cheveux": 2, "barbe": 2, "couleur_cheveux": Color("#7a5430"), "peau": Color("#eec9b3"), "tunique": "cuir", "sur": "gris", "pantalon": "gris",
		"cuir": "cuir_a", "fourrure": "gris", "accessoires": ["epaulieres", "pteruges", "gilet"], "casque": "casque_nasal"},
	{"corps": "homme", "tete": 3, "cheveux": 2, "barbe": 0, "couleur_cheveux": Color("#2e251c"), "peau": Color("#eec9b3"), "tunique": "lin", "sur": "gris", "pantalon": "noir",
		"cuir": "cuir_a", "fourrure": "brun", "accessoires": ["capuche", "cape_courte", "sacoche"]},
	{"corps": "homme", "tete": 1, "cheveux": 1, "barbe": 1, "couleur_cheveux": Color("#8c8378"), "peau": Color("#eec9b3"), "tunique": "cuir", "sur": "brun", "pantalon": "brun",
		"cuir": "cuir_b", "fourrure": "blanc", "accessoires": ["carquois", "pteruges", "cape_courte"]},
]

## Tunique d'un bleu proche de la laine des manches FPS (objets_textures.gd LAINE #2d3956), cuir sombre comme les gants et brassards FPS : meme palette a la 1re et a la 3e personne.
const JOUEUR := {"corps": "homme", "tete": 1, "cheveux": 1, "barbe": 1, "couleur_cheveux": Color("#6b4528"), "tunique": Color("#34436b"), "sur": Color("#4a5468"), "pantalon": "brun",
	"cuir": "cuir_b", "fourrure": "gris", "accessoires": ["gilet", "cape_courte", "sacoche"], "peau": Color("#eec9b3")}

static func villageois(id: String) -> PersoDef:
	return _def("v:" + id, VILLAGEOIS.get(id, VILLAGEOIS["chef"]))

static func bandit(k: int) -> PersoDef:
	return _def("b:%d" % k, BANDITS[k % BANDITS.size()])

static func joueur() -> PersoDef:
	return _def("joueur", JOUEUR)

static func _def(cle: String, d: Dictionary) -> PersoDef:
	if not _cache.has(cle):
		_cache[cle] = PersoDef.depuis(d)
	return _cache[cle]

## Toutes les definitions nommees (galeries, tests).
static func toutes() -> Dictionary:
	var r := {}
	for id: String in VILLAGEOIS:
		r["pnj_" + id] = villageois(id)
	for k in BANDITS.size():
		r["bandit_%d" % k] = bandit(k)
	r["joueur"] = joueur()
	return r
