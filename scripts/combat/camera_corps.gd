class_name CameraCorps
extends RefCounted
## Caméra « corps » de la vue FPS (joueur.gd) : tout est SUBTIL, la caméra ne fait jamais le mouvement des bras.
## - balancement de tête synchronisé aux pas (même phase que les sons de pas de joueur.gd : un pas à chaque multiple de π,
##   au point le plus bas de la tête) ;
## - saut (la tête reste un instant en arrière de l'impulsion) et atterrissage (amorti proportionnel à la HAUTEUR de chute,
##   déduite de la vitesse de chute maximale : indépendante des images par seconde) ;
## - accompagnement minime des attaques du joueur (≤ 0,4° dans le sens de la lame), micro-secousse à l'impact (légère <
##   lourde, venue de joueur.secousse), amortissement lent après un coup puissant, coup reçu (tête rejetée du côté opposé).
## Ressorts CRITIQUES (sans dépassement) intégrés à pas FIXE de 1/240 s : même mouvement à 30, 60 ou 144 images/s.
## L'arrêt sur image (Effets.arret_image) ralentit dt : les ressorts se figent avec le jeu, rien ne saute à la reprise.
## Options (menu Options, 0..1) : `tete` (Mouvement de tête) et `secousses` (Secousses) ; « Réduire les mouvements »
## plafonne tout à REDUIT_* (voir facteurs()).

const PAS := 1.0 / 240.0
## Plafonds imposés par « Réduire les mouvements » (mal des transports).
const REDUIT_ARME := 0.35
const REDUIT_TETE := 0.25
const REDUIT_SECOUSSES := 0.3
## Ressorts (rad/s) : rapide (saut, atterrissage, attaques), lent (amorti après un coup puissant ou reçu).
const W_RAPIDE := 11.0
const W_LENT := 6.5
## Balancement de tête à pleine course (6,5 m/s) ; × vitesse / 6,5 en dessous (marche 3,2 m/s ≈ ×0,49).
const BOB_Y := 0.022       # m (point haut entre deux pas)
const BOB_X := 0.009       # m (gauche-droite, un cycle tous les deux pas)
const BOB_ROULIS := 0.0035 # rad (0,2°)
## Secousse (joueur.secousse s, 0..1, en s²) : décalage d'image et roulis.
const SECOUSSE_DEC := 0.06   # m
const SECOUSSE_ROULIS := 0.035   # rad (2° à s = 1)
const GRAVITE := 13.0   # joueur.GRAVITE

var tete := 1.0
var secousses := 1.0

## Sorties (repère de la tête) : camera.position, camera.rotation, (h_offset, v_offset).
var position := Vector3.ZERO
var rotation := Vector3.ZERO
var decalage := Vector2.ZERO
## Rotation sans le bruit de secousse (mesures).
var rotation_lisse := Vector3.ZERO
## Dernière chute amortie (m, mesures / tests).
var derniere_chute := 0.0

var _acc := 0.0
var _t := 0.0
var _p := Vector3.ZERO      # ressort rapide : position
var _vp := Vector3.ZERO
var _r := Vector3.ZERO      # ressort rapide : rotation (tangage, lacet, roulis)
var _vr := Vector3.ZERO
var _rt := Vector3.ZERO     # ressort lent de la tête : tangage après l'atterrissage
var _vrt := Vector3.ZERO
var _rl := Vector3.ZERO     # ressort lent des coups : rotation
var _vrl := Vector3.ZERO
var _pl := Vector3.ZERO     # ressort lent des coups : position
var _vpl := Vector3.ZERO
var _ampl := 0.0
var _au_sol_prec := true
var _vy_min := 0.0
var _y_haut := -INF
var _bruit := FastNoiseLite.new()

func _init() -> void:
	_bruit.frequency = 1.0

## Facteurs effectifs des options : {arme, tete, secousses} (0..1), « Réduire les mouvements » compris.
static func facteurs() -> Dictionary:
	var f := {
		"arme": clampf(float(Jeu.option("affichage", "balancement_arme")), 0.0, 1.0),
		"tete": clampf(float(Jeu.option("affichage", "mouvement_tete")), 0.0, 1.0),
		"secousses": clampf(float(Jeu.option("affichage", "secousses")), 0.0, 1.0),
	}
	if bool(Jeu.option("affichage", "reduire_mouvements")):
		f["arme"] = minf(f["arme"], REDUIT_ARME)
		f["tete"] = minf(f["tete"], REDUIT_TETE)
		f["secousses"] = minf(f["secousses"], REDUIT_SECOUSSES)
	return f

## Impulsion qui donne un pic `pic` à un ressort critique de pulsation w partant du repos (pic = v0 / (w·e)).
static func _impulsion(pic: float, w: float) -> float:
	return pic * w * exp(1.0)

## Attaque du joueur (début de la frappe) : dir = sens de la lame à l'écran (x vers la droite, y vers le bas), force ~1.
## La vue suit d'au plus 0,4° : un accompagnement, pas le geste.
func accompagner(dir: Vector2, force: float) -> void:
	var d := dir.limit_length(1.0) * clampf(force, 0.0, 1.6)
	_vr.y += _impulsion(-d.x * 0.0045, W_RAPIDE)
	_vr.x += _impulsion(-d.y * 0.0035, W_RAPIDE)
	_vr.z += _impulsion(-d.x * 0.0015, W_RAPIDE)

## Coup du joueur qui porte (montée de joueur.secousse) : petit recul de la vue, puis pour un coup puissant (s ≥ 0,45)
## un amorti lent vers le bas (le poids du coup passe dans le corps).
func impact(s: float) -> void:
	_vr.x += _impulsion(0.004 * s, W_RAPIDE)
	if s >= 0.45:
		_vrl.x += _impulsion(-0.009 * s, W_LENT)
		_vpl.y += _impulsion(-0.012 * s, W_LENT)

## Coup reçu : direction de l'attaquant dans le repère du joueur (x droite, z arrière), force 0..1 (≈ dégâts / 30).
## La tête est rejetée en arrière et penche du côté opposé au coup (ressort lent).
func coup_recu(vers_local: Vector3, force: float) -> void:
	var k := clampf(force, 0.2, 1.0)
	var v := Vector3(vers_local.x, 0.0, vers_local.z).normalized() if Vector2(vers_local.x, vers_local.z).length() > 0.01 else Vector3(0, 0, -1)
	_vrl.x += _impulsion(0.016 * k * maxf(-v.z, 0.3), W_LENT)   # de face : la tête part en arrière
	_vrl.z += _impulsion(0.018 * k * v.x, W_LENT)               # attaquant à droite : on penche à gauche (roulis +)
	_vrl.y += _impulsion(-0.008 * k * v.x, W_LENT)

## Une image de jeu. v_sol : vitesse au sol (m/s) ; phase : phase des pas de joueur.gd (_pas) ; vy : vitesse verticale ;
## s : joueur.secousse (0..1) ; altitude (facultative) : hauteur des pieds — la chute se mesure alors entre le point le
## plus haut du vol et le sol (exact à toute cadence), sinon d'après la vitesse de chute maximale.
func avancer(dt: float, v_sol: float, phase: float, au_sol: bool, vy: float, s: float, altitude := INF) -> void:
	_t += dt
	# saut / atterrissage
	if not au_sol:
		_vy_min = minf(_vy_min, vy)
		if altitude != INF:
			_y_haut = maxf(_y_haut, altitude)
	# impulsions de saut / atterrissage appliquées APRÈS l'intégration de l'image (départ à l'instant constaté)
	var i_p := Vector3.ZERO
	var i_r := Vector3.ZERO
	var i_rt := Vector3.ZERO
	if _au_sol_prec and not au_sol and vy > 1.0:
		i_p.y += _impulsion(-0.007, W_RAPIDE)
		i_r.x += _impulsion(0.003, W_RAPIDE)
	elif not _au_sol_prec and au_sol:
		var h := _vy_min * _vy_min / (2.0 * GRAVITE)
		if altitude != INF and _y_haut > -INF:
			h = maxf(_y_haut - altitude, 0.0)
		if _vy_min < -2.0:
			derniere_chute = h
			var creux := clampf(0.004 + 0.016 * h, 0.0, 0.06)
			i_p.y += _impulsion(-creux, W_RAPIDE)
			i_rt.x += _impulsion(-creux * 0.25, W_LENT)
		_vy_min = 0.0
		_y_haut = -INF
	if au_sol and altitude != INF:
		_y_haut = altitude
	_au_sol_prec = au_sol
	# ressorts critiques à pas fixe (epsilon : 1/30 s = exactement 8 pas malgré l'arrondi)
	_acc += dt
	var n := floori(_acc / PAS + 1e-6)
	_acc -= n * PAS
	var wr2 := W_RAPIDE * W_RAPIDE
	var wl2 := W_LENT * W_LENT
	for i in n:
		_vp += (-_p * wr2 - _vp * 2.0 * W_RAPIDE) * PAS
		_p += _vp * PAS
		_vr += (-_r * wr2 - _vr * 2.0 * W_RAPIDE) * PAS
		_r += _vr * PAS
		_vrt += (-_rt * wl2 - _vrt * 2.0 * W_LENT) * PAS
		_rt += _vrt * PAS
		_vrl += (-_rl * wl2 - _vrl * 2.0 * W_LENT) * PAS
		_rl += _vrl * PAS
		_vpl += (-_pl * wl2 - _vpl * 2.0 * W_LENT) * PAS
		_pl += _vpl * PAS
	_vp += i_p
	_vr += i_r
	_vrt += i_rt
	# balancement de tête : amplitude lissée (pas de saut à l'arrêt ni au décollage)
	_ampl = lerpf(_ampl, clampf(v_sol / 6.5, 0.0, 1.0) if au_sol else 0.0, 1.0 - exp(-8.0 * dt))
	var bob := Vector3(cos(phase) * BOB_X, sin(phase) * sin(phase) * BOB_Y, 0.0) * _ampl   # sin² : creux au pas, sans pointe
	var roulis_pas := cos(phase) * BOB_ROULIS * _ampl
	# secousse : bruit CONTINU dans le temps, lent (~6 motifs/s, quelques Hz) : la même courbe à 30, 60 ou 144 images/s
	# (l'ancien bruit à ~80 motifs/s était sous-échantillonné différemment à chaque cadence : un grésillement aléatoire)
	var s2 := s * s
	decalage = Vector2(_bruit.get_noise_2d(_t * 6.0, 0.0), _bruit.get_noise_2d(0.0, _t * 6.0)) * s2 * SECOUSSE_DEC * secousses
	var roulis_secousse := _bruit.get_noise_2d(_t * 5.0, 50.0) * s2 * SECOUSSE_ROULIS
	position = (bob + _p) * tete + _pl * secousses
	rotation_lisse = (_r + _rt + Vector3(0, 0, roulis_pas)) * tete + _rl * secousses
	rotation = rotation_lisse + Vector3(0, 0, roulis_secousse * secousses)

## Amplitude courante (m, rad) des trois composantes, pour les mesures.
func etat() -> Dictionary:
	return {"position": position, "rotation": rotation, "decalage": decalage}
