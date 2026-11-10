class_name PaletteTripo
## Passe palette des modèles Tripo (audit 2026-11-10, job G1) : UNE seule table de réglages de matériau par modèle, lue par
## ArmureTripo (armure dorée du garde halle_e), EnnemiTripo (draugr, archer draugr, squelette, gobelin) et PuitsTripo (margelle).
## On ne touche QUE la teinte, la saturation, la valeur (et le contraste / la lueur) des matériaux : ni maillage, ni échelle,
## ni texture source (les GLB et PNG restent tels quels). Le trio gardes Tripo / Gunnar / Eirwen sert de référence et n'est pas réglé ici.
## Réversible : `-- --palette-tripo-ancienne` rend les réglages d'avant (table ANCIENNE), pour comparer au même cadrage.
##
## Champs (tous facultatifs, défaut = sans effet) :
##   teinte     Color   multiplie la texture (valeur + chaleur : < 1 assombrit, r < b refroidit)
##   saturation float   1 = texture telle quelle, 0 = gris (appliquée APRÈS la teinte, par le shader)
##   contraste  float   1 = tel quel ; < 1 rapproche les tons du pivot (squelette : moins de blanc ivoire contre les creux noirs)
##   pivot      float   luminance autour de laquelle le contraste se resserre
##   lueur      Vector3 armure : émission proportionnelle à l'albédo (reflets à contre-jour)

const TABLE := {
	# or vieilli patiné : moins saturé, plus sombre, presque plus de lueur propre (elle faisait « plastique émissif »)
	"armure": {"teinte": Color(0.52, 0.46, 0.37), "saturation": 0.68, "lueur": Vector3(0.34, 0.3, 0.24)},
	# draugrs : le cuivre est refroidi (désaturé puis tiré vers un gris-bleu vert-de-gris) et assombri
	"draugr": {"teinte": Color(0.62, 0.75, 0.72), "saturation": 0.32},
	"archer": {"teinte": Color(0.6, 0.73, 0.7), "saturation": 0.32},
	# squelette : os jauni, moins ivoire, moins contrasté ; pagne rouge désaturé
	"squelette": {"teinte": Color(0.8, 0.74, 0.6), "saturation": 0.55, "contraste": 0.8, "pivot": 0.42},
	# gobelin : vert peint ramené vers un olive terreux sombre
	"gobelin": {"teinte": Color(0.66, 0.6, 0.48), "saturation": 0.42},
	# puits : pierre et toit assombris (c'était l'objet le plus clair de la place)
	"puits": {"teinte": Color(1.0, 1.0, 1.02), "saturation": 0.8},
}

## Réglages d'avant la passe (valeurs reprises telles quelles des scripts, commit 808bdc6a).
const ANCIENNE := {
	"armure": {"teinte": Color(0.5, 0.43, 0.34), "saturation": 1.0, "lueur": Vector3(0.7, 0.63, 0.52)},
	"draugr": {"teinte": Color(0.95, 0.88, 0.8)},
	"archer": {"teinte": Color(0.9, 0.9, 0.9)},
	"squelette": {"teinte": Color(0.9, 0.9, 0.9)},
	"gobelin": {"teinte": Color(0.95, 0.95, 0.95)},
	"puits": {"teinte": Color(1.35, 1.35, 1.35)},
}

static var ancienne := OS.get_cmdline_user_args().has("--palette-tripo-ancienne")

static func reglage(id: String) -> Dictionary:
	return (ANCIENNE if ancienne else TABLE).get(id, {})

static func teinte(id: String, defaut := Color.WHITE) -> Color:
	return reglage(id).get("teinte", defaut)

## Pose saturation / contraste / pivot sur un matériau dont le shader a ces paramètres (ceux absents de la table restent neutres).
static func appliquer(m: ShaderMaterial, id: String) -> void:
	var r := reglage(id)
	m.set_shader_parameter("teinte", r.get("teinte", Color.WHITE))
	m.set_shader_parameter("saturation", float(r.get("saturation", 1.0)))
	if m.shader != null and m.shader.code.contains("uniform float contraste"):
		m.set_shader_parameter("contraste", float(r.get("contraste", 1.0)))
		m.set_shader_parameter("pivot", float(r.get("pivot", 0.4)))
