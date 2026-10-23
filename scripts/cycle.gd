extends Node
## Cycle jour/nuit d'hiver polaire (lot 2 « étalonnage et ciel ») : longue nuit bleue, aube brève,
## jour COUVERT gris-bleu, long crépuscule doré vers 17 h 30 (le plus soigné : c'est l'image de référence), nuit.
## Une journée de jeu dure 40 minutes réelles. La même lumière directionnelle sert de lune la nuit et de soleil bas le
## jour ; elle change d'astre quand elle est éteinte (vers 8 h et 19 h).
##
## API publique pour les autres lots (arrière-plan de montagnes, etc.) :
##   couleur_horizon(dir)  : couleur du ciel à l'horizon dans la direction monde `dir` (chaude vers le soleil couchant, froide ailleurs) ;
##   couleur_brume()       : couleur actuelle du brouillard (= couleur_horizon vers la caméra) ;
##   couleur_haut()        : couleur du zénith ;
##   chaleur()             : 0..1, force de la lueur crépusculaire/aube ; dir_astre() : direction horizontale du soleil/de la lune.

const SECONDES_PAR_HEURE := 100.0

var heure := 21.0
var env: Environment
var lumiere: DirectionalLight3D
var ciel: ShaderMaterial

## « froid » = couleur de l'horizon et du brouillard hors du côté du soleil ; « chaud » = côté du soleil (crépuscule seulement) ;
## « fin » = distance (m) où le brouillard est total (SOCLE_TECHNIQUE §3 bis).
const NUIT := {
	"ambiant": Color(0.34, 0.41, 0.60), "ambiant_e": 0.52, "froid": Color(0.04, 0.07, 0.15), "fin": 62.0, "expo": 1.1,
	"haut": Color(0.008, 0.014, 0.04), "glow": 0.88,
}
## Jour (lot C3 « midi », réf. references/exterieurs_v2_planche.png, vues de jour) : ciel d'hiver dégagé bleu franc,
## brume pâle bleu ciel (plus lavande), ombres bleues nettes ; le contraste vient d'un soleil bas presque blanc.
## (avant C3 : ambiant (0.52, 0.58, 0.72)×0.5, froid (0.50, 0.56, 0.66), fin 55, haut (0.22, 0.29, 0.42) : midi plat et lavande)
## « fin » ≤ 60 : × 1,25 sur les crêtes reste sous FIN_MAX.
const JOUR := {
	"ambiant": Color(0.50, 0.60, 0.80), "ambiant_e": 0.68, "froid": Color(0.62, 0.72, 0.86), "fin": 60.0, "expo": 1.05,
	"haut": Color(0.24, 0.37, 0.60), "glow": 1.3,
}
## Soleil de midi (pondéré par la clarte du jour, donc sans effet à l'aube ni au crépuscule) : plus fort, presque blanc.
const SOLEIL_MIDI := {"couleur": Color(1.0, 0.95, 0.87), "energie": 1.6}
const SOLEIL_BAS := {"couleur": Color(1.0, 0.88, 0.76), "energie": 1.2}
## Crépuscule : horizon violet-gris, côté soleil rose-ocre (la bande dorée est dessinée par le ciel), zénith bleu nuit.
const CREPUSCULE := {
	"ambiant": Color(0.40, 0.43, 0.60), "ambiant_e": 0.44, "froid": Color(0.22, 0.25, 0.34), "chaud": Color(0.62, 0.44, 0.34),
	"fin": 58.0, "expo": 1.3, "haut": Color(0.09, 0.11, 0.20), "glow": 1.15,
}
## Étalonnage (post-traitement, voir ps1_post.gdshader) : multiplicateurs appliqués aux ombres / aux hautes lumières.
const ETAL := {
	"nuit": {"ombre": Color(0.93, 0.97, 1.08), "clair": Color(1.0, 1.0, 1.01), "sat": 0.72, "contraste": 0.32},
	"jour": {"ombre": Color(0.90, 0.97, 1.07), "clair": Color(1.03, 1.02, 0.99), "sat": 0.84, "contraste": 0.46},
	"crep": {"ombre": Color(0.90, 0.94, 1.10), "clair": Color(1.08, 1.0, 0.90), "sat": 0.78, "contraste": 0.52},
}

## Le brouillard commence à ce rapport de sa fin (net jusqu'à ~20 m pour une fin à 55-60 m).
const DEBUT_RAPPORT := 0.36
## Tempête de neige (météo future) : fin du brouillard à 27 m ; `tempete` va de 0 (calme) à 1 (pleine tempête).
const FIN_TEMPETE := 27.0
var tempete := 0.0
## Facteur local de la portée (monde.gd : creux et forêt < 1, crêtes > 1), lissé côté monde.
var local := 1.0
## Plus grande distance de fin possible (crête, nuit claire) : sert à régler portées de visibilité et plan lointain.
const FIN_MAX := 75.0

## Azimut (rad, 0 = plein sud) du coucher : sud-ouest ; le soleil se lève au sud-est.
const AZIMUT_MAX := 0.93

var _j := 0.0      # clarté du jour 0..1
var _crep := 0.0   # force de la lueur crépusculaire / aube 0..1
var _dir_h := Vector2(-0.8, 0.6)  # direction horizontale du soleil (ou de la lune la nuit)
var _froid := Color(0.05, 0.075, 0.13)
var _chaud := Color(0.05, 0.075, 0.13)
var _haut := Color(0.008, 0.012, 0.035)
var _avant := Vector2(0.0, -1.0)  # direction horizontale de la caméra (brouillard dirigé)

## 0 la nuit, 1 en plein jour (≈ 10 h → 14 h 30), fondus de 8 h 36 à 10 h 24 et de 14 h 30 à 16 h 30. (Vitrages : s'allument quand < 1.)
func clarte() -> float:
	return _clarte_a(heure)

func _clarte_a(h: float) -> float:
	return smoothstep(8.6, 10.4, h) * (1.0 - smoothstep(14.5, 16.5, h))

## Lueur crépusculaire : maximale de 17 h 10 à 17 h 55, retombe vers 19 h 20 ; aube plus brève et plus pâle (8 h).
func _lueur_a(h: float) -> float:
	var soir := smoothstep(15.6, 17.2, h) * (1.0 - smoothstep(17.9, 19.3, h))
	var matin := 0.6 * smoothstep(7.2, 8.3, h) * (1.0 - smoothstep(9.0, 10.3, h))
	return maxf(soir, matin)

func texte_heure() -> String:
	return "%02dh%02d" % [int(heure), int(fmod(heure, 1.0) * 60.0)]

# --- API publique ----------------------------------------------------------------

func couleur_horizon(dir: Vector3) -> Color:
	var h := Vector2(dir.x, dir.z)
	var k := 0.0
	if h.length() > 0.001 and _crep > 0.0:
		k = _crep * smoothstep(-0.4, 1.0, h.normalized().dot(_dir_h))
	return _froid.lerp(_chaud, k)

func couleur_brume() -> Color:
	return couleur_horizon(Vector3(_avant.x, 0.0, _avant.y))

func couleur_haut() -> Color:
	return _haut

func chaleur() -> float:
	return _crep

func dir_astre() -> Vector2:
	return _dir_h

## Brouillard dirigé : chaud côté soleil couchant, froid ailleurs. Appelé chaque image par monde.gd avec l'avant de la caméra.
func orienter_brume(avant: Vector3) -> void:
	var a := Vector2(avant.x, avant.z)
	if a.length() < 0.01:
		return
	a = a.normalized()
	if a.distance_to(_avant) > 0.004:
		_avant = a
		env.fog_light_color = couleur_brume()

# --- cycle ----------------------------------------------------------------------

func _process(_dt: float) -> void:
	heure = fmod(heure + _dt / SECONDES_PAR_HEURE, 24.0)
	var h := heure
	var j := _clarte_a(h)
	var crep := _lueur_a(h)
	# aube (refonte « lumière », 2e passe) : dès 5 h le ciel s'éclaircit en bleu-gris et une lueur rose-orange pâle monte
	# à l'est ; `jc` éclaircit ciel / ambiant / brume sans toucher à clarte() (vitrages, PNJ)
	var aube := smoothstep(4.8, 6.0, h) * (1.0 - smoothstep(8.6, 10.4, h))
	crep = maxf(crep, 0.5 * aube * (1.0 - smoothstep(7.4, 9.2, h)))
	var jc := maxf(j, 0.3 * aube)
	_j = j
	_crep = crep

	# soleil : se lève au sud-est (8 h), culmine bas au sud (12 h 36), se couche au sud-ouest (17 h 12) ;
	# au crépuscule la lumière reste un soleil bas et chaud (le disque a déjà disparu dans le ciel), puis s'éteint.
	var t := clampf((h - 12.6) / 4.6, -1.15, 1.15)
	var az := t * AZIMUT_MAX
	var soleil_h := Vector2(-sin(az), cos(az))
	var haut_soleil := maxf(0.21, 0.34 * (1.0 - t * t))  # ≥ 12° : le soleil bas touche encore les façades (audit)
	var e_soleil := smoothstep(8.0, 9.4, h) * (1.0 - smoothstep(17.7, 18.9, h))
	var e_lune := (1.0 - smoothstep(7.3, 8.0, h)) + smoothstep(18.95, 19.7, h)
	var est_soleil := h > 8.0 and h < 18.95
	var vers_astre: Vector3
	var energie: float
	if est_soleil:
		vers_astre = Vector3(soleil_h.x, haut_soleil, soleil_h.y).normalized()
		# le jour couvert est doux ; la lumière rasante du couchant est plus forte et dorée
		# C3 : vers midi (j → 1) le soleil blanchit et se renforce ; aube et crépuscule (j ≈ 0) inchangés
		var e_jour := lerpf(SOLEIL_BAS["energie"], SOLEIL_MIDI["energie"], j)
		var c_jour: Color = SOLEIL_BAS["couleur"].lerp(SOLEIL_MIDI["couleur"], j)
		energie = e_soleil * lerpf(e_jour, 1.8, crep)
		lumiere.light_color = c_jour.lerp(Color(1.0, 0.60, 0.32), crep)
		_dir_h = soleil_h
	else:
		var a := 0.44 + (fmod(h + 12.0, 24.0) - 12.0) * 0.03
		vers_astre = Vector3(sin(a), 0.55, -cos(a)).normalized()
		energie = 0.75 * e_lune
		lumiere.light_color = Color(0.62, 0.72, 1.0)
		_dir_h = Vector2(vers_astre.x, vers_astre.z).normalized()
		if e_lune < 0.999 or aube > 0.01:
			_dir_h = soleil_h  # la lueur du ciel reste du côté du soleil jusqu'à la nuit noire
	lumiere.basis = Basis.looking_at(-vers_astre, Vector3.UP)
	lumiere.light_energy = energie

	var base_a: Color = NUIT["ambiant"].lerp(JOUR["ambiant"], jc).lerp(CREPUSCULE["ambiant"], crep)
	env.ambient_light_color = base_a
	env.ambient_light_energy = lerpf(lerpf(NUIT["ambiant_e"], JOUR["ambiant_e"], jc), CREPUSCULE["ambiant_e"], crep)
	env.tonemap_exposure = lerpf(lerpf(NUIT["expo"], JOUR["expo"], jc), CREPUSCULE["expo"], crep)
	# le glow ne garde que les vraies sources (flammes, fenêtres) : seuil haut en plein jour, la neige éclairée ne bave pas
	env.glow_hdr_threshold = lerpf(lerpf(NUIT["glow"], JOUR["glow"], jc), CREPUSCULE["glow"], crep)
	_froid = NUIT["froid"].lerp(JOUR["froid"], jc).lerp(CREPUSCULE["froid"], crep)
	_chaud = _froid.lerp(CREPUSCULE["chaud"], crep)
	_haut = NUIT["haut"].lerp(JOUR["haut"], jc).lerp(CREPUSCULE["haut"], crep)
	_fin_base = lerpf(lerpf(NUIT["fin"], JOUR["fin"], jc), CREPUSCULE["fin"], crep)
	_horizon = _froid
	appliquer_brume()
	ciel.set_shader_parameter("horizon_courant", _froid)
	ciel.set_shader_parameter("horizon_chaud", _chaud)
	ciel.set_shader_parameter("haut_courant", _haut)
	ciel.set_shader_parameter("dir_astre", Vector3(_dir_h.x, 0.0, _dir_h.y))
	ciel.set_shader_parameter("crep", crep)
	ciel.set_shader_parameter("jour", jc)
	ciel.set_shader_parameter("soleil", 1.0 if est_soleil else 0.0)
	_etalonner(jc, crep)
	_regler_neige_objets(_dt)

## Étalonnage global du post-traitement (nuit ↔ jour ↔ crépuscule).
func _etalonner(j: float, crep: float) -> void:
	var post = get_parent().get("post") if get_parent() != null else null
	if post == null:
		return
	var n: Dictionary = ETAL["nuit"]
	var d: Dictionary = ETAL["jour"]
	var c: Dictionary = ETAL["crep"]
	post.set_shader_parameter("etal_ombre", _mel(n["ombre"], d["ombre"], c["ombre"], j, crep))
	post.set_shader_parameter("etal_clair", _mel(n["clair"], d["clair"], c["clair"], j, crep))
	post.set_shader_parameter("etal_sat", lerpf(lerpf(n["sat"], d["sat"], j), c["sat"], crep))
	post.set_shader_parameter("etal_contraste", lerpf(lerpf(n["contraste"], d["contraste"], j), c["contraste"], crep))

func _mel(n: Color, d: Color, c: Color, j: float, crep: float) -> Vector3:
	var r := n.lerp(d, j).lerp(c, crep)
	return Vector3(r.r, r.g, r.b)

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
	env.fog_light_color = couleur_brume()
	env.fog_depth_begin = fin * DEBUT_RAPPORT
	env.fog_depth_end = fin
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	env.fog_height_density = 0.0
	env.fog_sky_affect = 0.0

# --- neige qui tient sur les objets (refonte « lumière », shaders/neige_tient.gdshaderinc) ----------------------

## Uniforme global `neige_objets` : 1 dehors, 0 sous terre (crypte, grotte), caméra dans un intérieur, ou option
## --sans-neige-objets (A/B). Relevé 4 fois par seconde, écrit seulement quand il change.
var _neige_objets := -1.0
var _neige_t := 0.0
var _sans_neige_objets := OS.get_cmdline_user_args().has("--sans-neige-objets")

func _regler_neige_objets(dt: float) -> void:
	_neige_t -= dt
	if _neige_t > 0.0 and _neige_objets >= 0.0:
		return
	_neige_t = 0.25
	_exclure_neige()
	var v := 0.0 if _sans_neige_objets or _sous_abri() else 1.0
	if v != _neige_objets:
		_neige_objets = v
		RenderingServer.global_shader_parameter_set("neige_objets", v)

func _sous_abri() -> bool:
	var m := get_parent()
	if m == null:
		return false
	if m.get("_sous_terre_actif") == true:
		return true
	var v = m.get("village")
	if v == null or not is_instance_valid(v):
		return false
	for ip in v.interieurs:
		if is_instance_valid(ip) and ip.dedans(ip._camera()):
			return true
	return false

## Matériaux ps1 qui ne reçoivent jamais la neige posée : l'eau (pas d'effet sur l'eau). Passe sur les matériaux créés
## depuis le dernier appel seulement.
var _nb_mat_vus := 0

func _exclure_neige() -> void:
	var mats: Array = Palette.materiaux
	if mats.size() == _nb_mat_vus:
		return
	var eau = Palette._cache.get("eau")
	for i in range(mini(_nb_mat_vus, mats.size()), mats.size()):
		var m: ShaderMaterial = mats[i]
		if eau != null and m.get_shader_parameter("tex_base") == eau:
			m.set_shader_parameter("neige_tient", 0.0)
	_nb_mat_vus = mats.size()
