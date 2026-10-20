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

## Lot 7 : « brume » = couleur de l'horizon du ciel (le brouillard se fond dans le ciel, sans raccord) ;
## « fin » = distance (m) où le brouillard est total : au-delà, plus rien n'est dessiné (voir SOCLE_TECHNIQUE §3 bis).
const NUIT := {
	"ambiant": Color(0.32, 0.4, 0.62), "ambiant_e": 0.55, "brume": Color(0.05, 0.075, 0.13), "fin": 60.0, "expo": 1.1,
	"haut": Color(0.008, 0.012, 0.035),
}
const JOUR := {
	"ambiant": Color(0.55, 0.62, 0.76), "ambiant_e": 0.62, "brume": Color(0.60, 0.65, 0.74), "fin": 50.0, "expo": 1.0,
	"haut": Color(0.26, 0.38, 0.58),
}
## Crépuscule : l'horizon vire au rose-violet (et le ciel haut au bleu profond) quand ni la nuit ni le jour ne dominent.
const CREPUSCULE := {"brume": Color(0.52, 0.36, 0.46), "haut": Color(0.10, 0.12, 0.30), "ambiant": Color(0.5, 0.45, 0.62)}

## Le brouillard commence à ce rapport de sa fin (net jusqu'à ~20 m pour une fin à 55-60 m).
const DEBUT_RAPPORT := 0.36
## Tempête de neige (météo future) : fin du brouillard à 27 m ; `tempete` va de 0 (calme) à 1 (pleine tempête).
const FIN_TEMPETE := 27.0
var tempete := 0.0
## Facteur local de la portée (monde.gd : creux et forêt < 1, crêtes > 1), lissé côté monde.
var local := 1.0
## Plus grande distance de fin possible (crête, nuit claire) : sert à régler portées de visibilité et plan lointain.
const FIN_MAX := 75.0

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
		vers_astre = Vector3(sin(a), 0.24 + 0.12 * cos(a), cos(a)).normalized()
		energie = lerpf(0.15, 1.45, j)
		lumiere.light_color = Color(1.0, 0.86, 0.7)
	else:
		var a := 0.44 + (fmod(heure + 12.0, 24.0) - 12.0) * 0.03
		vers_astre = Vector3(sin(a), 0.55, -cos(a)).normalized()
		energie = lerpf(0.75, 0.15, j)
		lumiere.light_color = Color(0.62, 0.72, 1.0)
	lumiere.basis = Basis.looking_at(-vers_astre, Vector3.UP)
	lumiere.light_energy = energie
	var crep := 4.0 * j * (1.0 - j)  # 0 en pleine nuit et en plein jour, 1 à mi-chemin
	crep *= crep  # resserré autour du vrai crépuscule
	env.ambient_light_color = NUIT["ambiant"].lerp(JOUR["ambiant"], j).lerp(CREPUSCULE["ambiant"], crep * 0.5)
	env.ambient_light_energy = lerpf(NUIT["ambiant_e"], JOUR["ambiant_e"], j)
	env.tonemap_exposure = lerpf(NUIT["expo"], JOUR["expo"], j)
	# le glow ne garde que les vraies sources (flammes) : seuil haut en plein jour, la neige éclairée ne bave plus
	env.glow_hdr_threshold = lerpf(0.9, 1.25, j)
	_horizon = NUIT["brume"].lerp(JOUR["brume"], j).lerp(CREPUSCULE["brume"], crep * 0.8)
	_fin_base = lerpf(NUIT["fin"], JOUR["fin"], j)
	appliquer_brume()
	ciel.set_shader_parameter("horizon_courant", _horizon)
	ciel.set_shader_parameter("haut_courant", NUIT["haut"].lerp(JOUR["haut"], j).lerp(CREPUSCULE["haut"], crep * 0.7))
	ciel.set_shader_parameter("jour", j)
	ciel.set_shader_parameter("soleil", 1.0 if est_jour else 0.0)

var _horizon := Color(0.05, 0.075, 0.13)
var _fin_base := 60.0

## Distance où le brouillard est total (m), tempête et facteur local compris.
func fin_brume() -> float:
	var f := _fin_base * local
	return lerpf(f, FIN_TEMPETE * minf(local, 1.0), tempete)

## Brouillard en profondeur : net jusqu'à `debut`, effacement progressif jusqu'à `fin`, brume seule au-delà.
func appliquer_brume() -> void:
	var fin := fin_brume()
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = _horizon
	env.fog_depth_begin = fin * DEBUT_RAPPORT
	env.fog_depth_end = fin
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	env.fog_height_density = 0.0
	env.fog_sky_affect = 0.0
