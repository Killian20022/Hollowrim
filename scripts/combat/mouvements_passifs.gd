class_name MouvementsPassifs
extends RefCounted
## Animations passives procédurales des mains en vue FPS : respiration et micro-mouvements, balancement de marche
## (plus ample en courant), sprint (épée abaissée, torche stabilisée), réaction au saut et amortissement à
## l'atterrissage, inertie à la rotation de la caméra, léger retour après un arrêt brutal.
## Tout passe par des ressorts amortis intégrés à pas FIXE (PAS) : même mouvement à 30, 60 ou 144 images/s.
## `amplitude` (1 = normal) est réduite par l'option « Réduire les mouvements » (mal des transports).
## Le jeu n'a pas d'accroupissement : rien n'est prévu pour lui ici.

const PAS := 1.0 / 240.0
const RAIDEUR := 110.0       # ressort d'inertie (rad²/s²) : ~10,5 rad/s
const AMORTI := 0.5          # < 1 : un léger dépassement (le « retour » après un arrêt)
const VITESSE_SPRINT := 4.8  # au-delà : pose de sprint (joueur.COURSE = 6,5 ; marche 3,2)

var amplitude := 1.0
## Poids de l'arme (kg, DonneesArme.poids) : plus lourde = plus de retard dans les mouvements.
var poids := 1.6

var decalage_d := Transform3D()
var decalage_g := Transform3D()
## 0 → 1 : mélange vers la pose de sprint (lu par mains.gd).
var sprint := 0.0

var _acc := 0.0
var _t := 0.0
var _phase := 0.0
var _ampl_pas := 0.0
var _dec := Vector3.ZERO
var _vdec := Vector3.ZERO
var _rot := Vector3.ZERO
var _vrot := Vector3.ZERO
var _cible_dec := Vector3.ZERO
var _au_sol_prec := true
var _vy_prec := 0.0

## Mouvement de souris (pixels d'écran) depuis la dernière image : donne une impulsion d'inertie (indépendante des FPS).
func souris(delta: Vector2) -> void:
	var k := 0.0011 * clampf(poids / 1.6, 0.5, 2.0)
	_vrot.y += delta.x * k
	_vrot.x += delta.y * k

## vitesse_locale : vitesse du joueur dans son repère (x droite, z arrière) ; calme : bras libres (pas en attaque).
func avancer(dt: float, vitesse_locale: Vector3, au_sol: bool, calme: bool) -> void:
	_t += dt
	var plat := Vector2(vitesse_locale.x, vitesse_locale.z)
	var v := plat.length()
	# saut : les bras restent un instant en arrière de l'impulsion ; atterrissage : amorti proportionnel à la chute
	if _au_sol_prec and not au_sol and vitesse_locale.y > 1.0:
		_vdec.y -= 0.22
		_vrot.x -= 0.25
	elif not _au_sol_prec and au_sol and _vy_prec < -1.5:
		var choc := clampf(-_vy_prec / 9.0, 0.0, 1.0)
		_vdec.y -= 0.35 * choc + 0.08
		_vrot.x -= 0.5 * choc
	_au_sol_prec = au_sol
	_vy_prec = vitesse_locale.y
	# retard des bras sur le déplacement : en avançant ils reculent un peu ; à l'arrêt, le ressort dépasse et revient
	var lag := 0.0035 * clampf(poids / 1.6, 0.5, 2.0)
	_cible_dec = Vector3(-vitesse_locale.x * lag, (0.012 if not au_sol else 0.0), -vitesse_locale.z * lag * 0.6)
	_acc += dt
	var w := sqrt(RAIDEUR / clampf(poids / 1.6, 0.6, 2.0))
	var c := 2.0 * AMORTI * w
	while _acc >= PAS:
		_acc -= PAS
		_vdec += ((_cible_dec - _dec) * w * w - _vdec * c) * PAS
		_dec += _vdec * PAS
		_vrot += (-_rot * w * w - _vrot * c) * PAS
		_rot += _vrot * PAS
	_rot = _rot.clamp(Vector3(-0.12, -0.12, -0.12), Vector3(0.12, 0.12, 0.12))
	# balancement de marche (même rythme que les pas et la tête du joueur : 2,4 rad par mètre)
	if au_sol:
		_phase += dt * v * 2.4
	var lissage := 1.0 - exp(-8.0 * dt)
	_ampl_pas = lerpf(_ampl_pas, clampf(v / 6.5, 0.0, 1.0) if au_sol else 0.0, lissage)
	sprint = lerpf(sprint, 1.0 if (v > VITESSE_SPRINT and au_sol and calme) else 0.0, 1.0 - exp(-7.0 * dt))
	var a := _ampl_pas * (1.0 if calme else 0.3)
	var bob_d := Vector3(cos(_phase) * 0.012, (absf(sin(_phase)) - 0.5) * 0.018 * (1.0 + sprint * 0.6), 0.0) * a
	var bob_g := Vector3(cos(_phase + PI) * 0.010, (absf(sin(_phase + PI * 0.5)) - 0.5) * 0.016, 0.0) * a * (1.0 - sprint * 0.65)
	# respiration et micro-mouvements (sinus lents incommensurables : jamais figé, jamais répétitif à l'œil)
	var souffle := sin(_t * 1.6) * 0.005 + (sin(_t * 0.37) + sin(_t * 0.71 + 1.3)) * 0.0012
	var derive := Vector3(sin(_t * 0.53) * 0.0015, souffle, sin(_t * 0.29) * 0.001)
	var r_d := Vector3(_rot.x + sin(_t * 1.6) * 0.006, _rot.y, _rot.y * 0.5 + cos(_phase) * 0.02 * a)
	var r_g := Vector3(_rot.x * 0.8 + sin(_t * 1.6 + 0.6) * 0.006, _rot.y * 0.8, _rot.y * 0.3 - cos(_phase) * 0.015 * a)
	decalage_d = Transform3D(Basis.from_euler(r_d * amplitude), (_dec + bob_d + derive) * amplitude)
	decalage_g = Transform3D(Basis.from_euler(r_g * amplitude), (_dec * 0.8 + bob_g + derive * 0.8) * amplitude)
