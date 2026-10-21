class_name PersoDef
extends Resource
## Description d'un personnage « base unifiee » : AUCUNE scene par PNJ, la fabrique `Personnage.creer(def)` assemble tout sous un seul Skeleton3D.
## Une variante = quelques champs (morphologie, tete, coiffure, barbe, couleurs, accessoires) ; les couleurs sont des PARAMETRES D'INSTANCE du
## shader (rampes de 8 tons recalculees, palette 15 bits) : changer la tunique de lin en laine bordeaux ne cree ni texture ni materiau.

## Morphologie : « homme » ou « femme » (deux bases, voir docs/PERSONNAGES_TECH.md).
@export_enum("homme", "femme") var corps := "homme"
## Tete 1 (carree), 2 (longue), 3 (ronde).
@export_range(1, 3) var tete := 1
## Coiffure : 0 aucune, 1 courte, 2 mi-longue, 3 chignon et natte.
@export_range(0, 3) var cheveux := 0
## Barbe (hommes) : 0 aucune, 1 courte, 2 tressee.
@export_range(0, 2) var barbe := 0
@export var peau := Color("#e8c9ae")
@export var couleur_cheveux := Color("#5a3a20")
@export var iris := Color("#4a6a8a")
## Couleurs de base des regions d'etoffe (la rampe de 8 tons en est deduite dans le shader).
@export var tunique := Color("#9b8a6c")
@export var pantalon := Color("#5d4a38")
@export var cuir := Color("#6a4426")
## Surcouche : robe, gilet, cape, tablier.
@export var sur := Color("#7a2a30")
@export var fourrure := Color("#aeb4c0")
## Accessoires par emplacement : gilet, tablier, cape_courte, cape_longue, capuche, robe, epaulieres, pteruges, sacoche, carquois.
@export var accessoires := PackedStringArray()
## Casque ("casque_nasal", "couronne_givre", "casque_draugr") et bouclier dorsal : modeles existants de assets/modeles/equipement.
@export var casque := ""
@export var bouclier := false
## Ressorts (capes, pans, capuche) : coupes au-dela de DIST_RESSORTS (voir PersoRessorts).
@export var ressorts := true
## Echelle de taille (1 = base).
@export var echelle := 1.0

## Palettes de tunique (swap de rampe) : lin ecru, cuir tanne, vert mousse, laine bordeaux.
const TUNIQUES := {
	"lin": Color("#9b8a6c"), "cuir": Color("#6a4426"), "mousse": Color("#4f6540"), "bordeaux": Color("#7a2a30"),
	"bleu": Color("#34487c"), "gris": Color("#6a6c70"), "violet": Color("#5a4474"), "brun": Color("#6a4e34"),
}
const PANTALONS := {"brun": Color("#5d4a38"), "gris": Color("#55585c"), "lin": Color("#8d7f68"), "bleu": Color("#3c4660"), "noir": Color("#34302c")}
const FOURRURES := {"blanc": Color("#aeb4c0"), "gris": Color("#7d818c"), "brun": Color("#6b4c34")}
const CUIRS := {"cuir_a": Color("#6a4426"), "cuir_b": Color("#443020"), "cuir_c": Color("#7d5a38")}

## Construit une definition depuis un dictionnaire compact (chaines = noms de palette, Color = valeur directe).
static func depuis(d: Dictionary) -> PersoDef:
	var p := PersoDef.new()
	for k: String in d:
		var v: Variant = d[k]
		match k:
			"tunique": p.tunique = _col(v, TUNIQUES)
			"pantalon": p.pantalon = _col(v, PANTALONS)
			"cuir": p.cuir = _col(v, CUIRS)
			"sur": p.sur = _col(v, TUNIQUES)
			"fourrure": p.fourrure = _col(v, FOURRURES)
			"accessoires": p.accessoires = PackedStringArray(v)
			_: p.set(k, v)
	return p

static func _col(v: Variant, palette: Dictionary) -> Color:
	return v if v is Color else palette.get(String(v), Color.WHITE)

func a(nom: String) -> bool:
	return accessoires.has(nom)
