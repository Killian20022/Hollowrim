extends Node
## Cycle jour/nuit d'hiver polaire : longue nuit, crépuscules bleus, jour court et pâle.
## Une journée de jeu dure 40 minutes réelles. La même lumière directionnelle sert de lune
## la nuit et de soleil bas le jour ; elle change d'astre pendant les crépuscules, quand
## elle est presque éteinte.

const SECONDES_PAR_HEURE := 100.0

var heure := 21.0
var env: Environment
var lumiere: DirectionalLight3D
var ciel: ShaderMaterial

const NUIT := {
	"ambiant": Color(0.32, 0.4, 0.62), "ambiant_e": 0.55, "brume": Color(0.1, 0.14, 0.22), "densite": 0.024,
}
const JOUR := {
	"ambiant": Color(0.62, 0.66, 0.74), "ambiant_e": 0.75, "brume": Color(0.5, 0.54, 0.62), "densite": 0.017,
}

## 0 la nuit, 1 en plein jour (11 h → 14 h), fondus de 9 h à 11 h et de 14 h à 16 h.
func clarte() -> float:
	return smoothstep(9.0, 11.0, heure) * (1.0 - smoothstep(14.0, 16.0, heure))

func texte_heure() -> String:
	return "%02dh%02d" % [int(heure), int(fmod(heure, 1.0) * 60.0)]

func _process(dt: float) -> void:
	heure = fmod(heure + dt / SECONDES_PAR_HEURE, 24.0)
	var j := clarte()
	var est_jour := heure > 10.0 and heure < 15.0
	# lune : haute au nord-est et tourne lentement ; soleil : rase l'horizon au sud
	var vers_astre: Vector3
	var energie: float
	if est_jour:
		var a := (heure - 12.5) / 2.5 * 0.9
		vers_astre = Vector3(sin(a), 0.1 + 0.08 * cos(a), cos(a)).normalized()
		energie = lerpf(0.15, 1.05, j)
		lumiere.light_color = Color(1.0, 0.86, 0.7)
	else:
		var a := 0.44 + (fmod(heure + 12.0, 24.0) - 12.0) * 0.03
		vers_astre = Vector3(sin(a), 0.55, -cos(a)).normalized()
		energie = lerpf(0.75, 0.15, j)
		lumiere.light_color = Color(0.62, 0.72, 1.0)
	lumiere.basis = Basis.looking_at(-vers_astre, Vector3.UP)
	lumiere.light_energy = energie
	env.ambient_light_color = NUIT["ambiant"].lerp(JOUR["ambiant"], j)
	env.ambient_light_energy = lerpf(NUIT["ambiant_e"], JOUR["ambiant_e"], j)
	env.fog_light_color = NUIT["brume"].lerp(JOUR["brume"], j)
	env.fog_density = lerpf(NUIT["densite"], JOUR["densite"], j)
	ciel.set_shader_parameter("jour", j)
	ciel.set_shader_parameter("soleil", 1.0 if est_jour else 0.0)
