class_name MouvementsPassifs
extends RefCounted
## Animations passives procédurales des mains en vue FPS : respiration et micro-mouvements, balancement de marche
## (plus ample en courant), sprint (épée abaissée, torche stabilisée), réaction au saut et amortissement à
## l'atterrissage, inertie à la rotation de la caméra, léger retour après un arrêt brutal.
## Tout passe par des ressorts amortis intégrés à pas FIXE (PAS) : même mouvement à 30, 60 ou 144 images/s.
## `amplitude` (1 = normal) : option « Balancement de l'arme » (0..1), plafonnée à 0,35 par « Réduire les mouvements »
## (CameraCorps.facteurs). Main gauche (torche, sort, bouclier) : mêmes mouvements, suivis avec un léger retard (ressort
## critique de 22 rad/s, ~45 ms) et un balancement de marche en opposition de phase — les deux mains restent coordonnées.
## Inertie : ressort légèrement sous-amorti (AMORTI 0,65 : dépassement ~7 % à l'arrêt brutal), plafond DOUX (tanh) de
## l'inertie de rotation à ROT_MAX ; la souris compte en angle tourné (pixels × sensibilité, mains.gd).
## Le jeu n'a pas d'accroupissement : rien n'est prévu pour lui ici.

const PAS := 1.0 / 240.0
const RAIDEUR := 110.0       # ressort d'inertie (rad²/s²) : ~10,5 rad/s
const AMORTI := 0.65         # < 1 : un léger dépassement (le « retour » après un arrêt), ~7 %
const ROT_MAX := 0.07        # rad (4°) : plafond doux de l'inertie de rotation (virage très brusque)
const W_GAUCHE := 22.0       # rad/s : la main gauche suit la droite (déphasage naturel)
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
var _vy_min := 0.0
var _dec_g := Vector3.ZERO
var _vdec_g := Vector3.ZERO
var _rot_g := Vector3.ZERO
var _vrot_g := Vector3.ZERO
## Mesures (tests, planches) : dernière chute amortie (m) et rotation d'inertie affichée (rad, avant `amplitude`).
var derniere_chute := 0.0
var rot_affichee := Vector3.ZERO
var rot_affichee_g := Vector3.ZERO
var _y_haut := -INF
var _souris_attente := Vector2.ZERO

## Mouvement de souris (pixels d'écran × sensibilité) depuis la dernière image : impulsion d'inertie, RÉPARTIE sur les pas
## fixes de l'image suivante (une force continue : même courbe à 30, 60 ou 144 images/s).
func souris(delta: Vector2) -> void:
	var k := 0.0011 * clampf(poids / 1.6, 0.5, 2.0)
	_souris_attente += Vector2(delta.y, delta.x) * k

## vitesse_locale : vitesse du joueur dans son repère (x droite, z arrière) ; calme : bras libres (pas en attaque) ;
## altitude (facultative) : hauteur des pieds (m) — la chute se mesure alors entre le point le plus haut du vol et le sol
## (exact à toute cadence) ; sinon d'après la vitesse de chute maximale.
func avancer(dt: float, vitesse_locale: Vector3, au_sol: bool, calme: bool, altitude := INF) -> void:
	_t += dt
	var plat := Vector2(vitesse_locale.x, vitesse_locale.z)
	var v := plat.length()
	# saut : les bras restent un instant en arrière de l'impulsion ; atterrissage : amorti proportionnel à la HAUTEUR de
	# chute (vitesse de chute maximale pendant le vol : ne dépend pas de l'image où le sol est touché)
	if not au_sol:
		_vy_min = minf(_vy_min, vitesse_locale.y)
		if altitude != INF:
			_y_haut = maxf(_y_haut, altitude)
	# impulsions appliquées APRÈS l'intégration de l'image (elles partent de l'instant où l'état est constaté)
	var i_dec := Vector3.ZERO
	var i_rot := Vector3.ZERO
	if _au_sol_prec and not au_sol and vitesse_locale.y > 1.0:
		i_dec.y -= 0.22
		i_rot.x -= 0.25
	elif not _au_sol_prec and au_sol:
		var h := _vy_min * _vy_min / (2.0 * 13.0)   # joueur.GRAVITE
		if altitude != INF and _y_haut > -INF:
			h = maxf(_y_haut - altitude, 0.0)
		if _vy_min < -1.5:
			derniere_chute = h
			var choc := clampf(h / 3.0, 0.0, 1.0)
			i_dec.y -= 0.35 * choc + 0.08
			i_rot.x -= 0.5 * choc
		_vy_min = 0.0
		_y_haut = -INF
	if au_sol and altitude != INF:
		_y_haut = altitude   # départ du saut / bord d'où l'on tombe
	_au_sol_prec = au_sol
	# retard des bras sur le déplacement : en avançant ils reculent un peu ; à l'arrêt, le ressort dépasse et revient
	var lag := 0.0035 * clampf(poids / 1.6, 0.5, 2.0)
	_cible_dec = Vector3(-vitesse_locale.x * lag, (0.012 if not au_sol else 0.0), -vitesse_locale.z * lag * 0.6)
	_acc += dt
	var w := sqrt(RAIDEUR / clampf(poids / 1.6, 0.6, 2.0))
	var c := 2.0 * AMORTI * w
	var n := floori(_acc / PAS + 1e-6)   # 1/30 s = exactement 8 pas malgré l'arrondi
	_acc -= n * PAS
	var wg2 := W_GAUCHE * W_GAUCHE
	var part := _souris_attente / float(n) if n > 0 else Vector2.ZERO
	if n > 0:
		_souris_attente = Vector2.ZERO
	for i in n:
		_vrot.x += part.x
		_vrot.y += part.y
		_vdec += ((_cible_dec - _dec) * w * w - _vdec * c) * PAS
		_dec += _vdec * PAS
		_vrot += (-_rot * w * w - _vrot * c) * PAS
		_rot += _vrot * PAS
		_vdec_g += ((_dec - _dec_g) * wg2 - _vdec_g * 2.0 * W_GAUCHE) * PAS
		_dec_g += _vdec_g * PAS
		_vrot_g += ((_rot - _rot_g) * wg2 - _vrot_g * 2.0 * W_GAUCHE) * PAS
		_rot_g += _vrot_g * PAS
	_vdec += i_dec
	_vrot += i_rot
	_rot = _rot.clamp(Vector3(-0.2, -0.2, -0.2), Vector3(0.2, 0.2, 0.2))
	var rot := _doux(_rot)
	var rot_g := _doux(_rot_g)
	rot_affichee = rot
	rot_affichee_g = rot_g
	# balancement de marche (même rythme que les pas et la tête du joueur : 2,4 rad par mètre)
	if au_sol:
		_phase += dt * v * 2.4
	var lissage := 1.0 - exp(-8.0 * dt)
	_ampl_pas = lerpf(_ampl_pas, clampf(v / 6.5, 0.0, 1.0) if au_sol else 0.0, lissage)
	sprint = lerpf(sprint, 1.0 if (v > VITESSE_SPRINT and au_sol and calme) else 0.0, 1.0 - exp(-7.0 * dt))
	var a := _ampl_pas * (1.0 if calme else 0.3)
	var bob_d := Vector3(cos(_phase) * 0.012, (sin(_phase) * sin(_phase) - 0.5) * 0.018 * (1.0 + sprint * 0.6), 0.0) * a
	var bob_g := Vector3(cos(_phase + PI) * 0.010, (cos(_phase) * cos(_phase) - 0.5) * 0.016, 0.0) * a * (1.0 - sprint * 0.65)
	# respiration et micro-mouvements (sinus lents incommensurables : jamais figé, jamais répétitif à l'œil)
	var souffle := sin(_t * 1.6) * 0.005 + (sin(_t * 0.37) + sin(_t * 0.71 + 1.3)) * 0.0012
	var derive := Vector3(sin(_t * 0.53) * 0.0015, souffle, sin(_t * 0.29) * 0.001)
	var r_d := Vector3(rot.x + sin(_t * 1.6) * 0.006, rot.y, rot.y * 0.5 + cos(_phase) * 0.02 * a)
	var r_g := Vector3(rot_g.x * 0.8 + sin(_t * 1.6 + 0.6) * 0.006, rot_g.y * 0.8, rot_g.y * 0.3 - cos(_phase) * 0.015 * a)
	# l'inertie de rotation déplace aussi un peu les mains (virage à droite : elles restent à gauche)
	var glisse_d := Vector3(-rot.y * 0.08, rot.x * 0.05, 0.0)
	var glisse_g := Vector3(-rot_g.y * 0.08, rot_g.x * 0.05, 0.0)
	decalage_d = Transform3D(Basis.from_euler(r_d * amplitude), (_dec + glisse_d + bob_d + derive) * amplitude)
	decalage_g = Transform3D(Basis.from_euler(r_g * amplitude), (_dec_g * 0.8 + glisse_g * 0.8 + bob_g + derive * 0.8) * amplitude)

## Plafond doux (tanh) de l'inertie de rotation : linéaire pour les petits virages, jamais au-delà de ROT_MAX.
static func _doux(r: Vector3) -> Vector3:
	return Vector3(ROT_MAX * tanh(r.x / ROT_MAX), ROT_MAX * tanh(r.y / ROT_MAX), ROT_MAX * tanh(r.z / ROT_MAX))
