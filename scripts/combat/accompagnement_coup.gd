class_name AccompagnementCoup
extends RefCounted
## ACCOMPAGNEMENT DU CORPS pendant les coups d'épée (coups_v4, retour utilisateur du 2026-10-29 soir : « que les coups d'épée
## soient plus profonds, plus gracieux, bien accompagnés, qu'on ait envie d'utiliser l'épée »). Les clips Mixamo validés (coup 1
## diagonale, coup 2 revers, estoc « Stabbing », puissant « Downward ») ne changent pas : on ajoute AUTOUR d'eux ce que fait le
## corps d'un escrimeur (références : Skyrim, Chivalry 2, Mordhau, Kingdom Come — le coup part du corps, la vue l'accompagne) :
##   - RYTHME : armé vif qui se pose (anticipation courte), tension tenue, puis frappe qui ACCÉLÈRE (temps du clip déformé :
##     t_prep / t_actif ; mêmes instants à toutes les cadences, le tracé de la lame suit la même courbe que l'image) ;
##   - SUIVI qui va au bout : à la fin de la frappe, la pointe garde sa vitesse et la perd en douceur (décalage additif de la main
##     dans le sens du coup, constante de temps TAU_SUIVI) au lieu de s'arrêter sec, puis revient avec le retour au repos ;
##   - AVANCÉE du joueur sur l'armé (0,3 à 0,6 m selon le coup, « elan » du geste) : impulsion dans le recul du joueur
##     (joueur._recul, décroissance exp(-8 t)), bloquée par les murs et les ennemis (move_and_slide) ;
##   - VUE qui suit la lame : roulis / tangage / lacet de la caméra vers la pointe de l'épée (2 à 4°, ressort critique, retour
##     amorti), CameraCorps.suivre_lame ; option « Caméra des coups » (0 = coupée, confort), plafonnée par « Réduire les mouvements ».
## Tout se coupe avec `actif = false` (comparaisons avant / après, outils).

static var actif := true

## Avancée par défaut (m) d'un geste sans « elan » ; impulsion par mètre d'avancée (recul du joueur : ∫ v0·e^(−8t) = v0 / 8,
## filtré par la réactivité du sol (10/s), même intégrale).
const ELAN_DEFAUT := 0.3
const ELAN_IMPULSION := 8.0
## On ne s'avance pas plus près que ça (m) d'une cible devant soi (mains._donner_elan).
const DISTANCE_CIBLE := 0.9
## Déformation du temps : armé (sortie rapide, arrivée posée), frappe (départ retenu, accélération franche).
const EXPO_PREP := 1.7
const EXPO_ACTIF := 1.35
## Suivi : l'épaule (le corps) continue de tourner dans le sens du coup après la fin de la frappe — rotation du bras entier
## autour de l'épaule, vitesse angulaire de départ = celle de la pointe autour de l'épaule (pas de cassure), décroissance
## exponentielle (TAU_SUIVI s), angle borné à ANGLE_SUIVI (la constante de temps raccourcit pour les coups très rapides).
const TAU_SUIVI := 0.09
const ANGLE_SUIVI := 0.3      # rad (17°)
## Vue : amplitudes (rad) par unité d'écart de la pointe à l'écran (1 = bord de l'écran), plafond total.
const LACET := 0.035        # 2°
const TANGAGE := 0.045      # 2,6°
const ROULIS := 0.07        # 4°
const PLAFOND := 0.07       # 4°

var _omega := Vector3.ZERO   # vitesse angulaire de la pointe autour de l'épaule (repère des mains, rad/s) à la fin de la frappe
var _pivot := Vector3.ZERO   # épaule (repère des mains)

## Temps du clip pendant l'armé : u (0..1) → part de l'armé.
static func prep(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, EXPO_PREP) if actif else u

## Temps du clip pendant la frappe : u (0..1) → part de la frappe. Courbe qui accélère, mélangée à 35 % de linéaire : la lame
## ne « cale » pas après la tension (vitesse de départ 0,35 × la vitesse du clip), puis finit 1,4 × plus vite.
static func frappe(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return lerpf(u, pow(u, EXPO_ACTIF * 1.6), 0.65) if actif else u

## Fin de la frappe : vitesse et position de la pointe, position de l'épaule (repère des mains), mesurées par mains.gd sur le clip.
func noter_fin(vitesse: Vector3, pointe: Vector3, epaule: Vector3) -> void:
	_omega = Vector3.ZERO
	_pivot = epaule
	var r := pointe - epaule
	if actif and vitesse.is_finite() and r.length_squared() > 1e-4:
		_omega = r.cross(vitesse) / r.length_squared()

func oublier() -> void:
	_omega = Vector3.ZERO

## Décalage additif du bras (repère des mains) pendant la récupération : t = temps depuis la fin de la frappe (s), k = part de la
## récupération (0..1). Rotation autour de l'épaule qui démarre à la vitesse de la pointe, tend vers ANGLE_SUIVI au plus, puis
## revient au repos sur la seconde moitié de la récupération.
func suivi(t: float, k: float) -> Transform3D:
	var w := _omega.length()
	if w < 1e-3:
		return Transform3D()
	var tau := minf(TAU_SUIVI, ANGLE_SUIVI / w)
	var angle := w * tau * (1.0 - exp(-t / tau)) * (1.0 - smoothstep(0.3, 0.95, k))
	var rot := Transform3D(Basis(_omega / w, angle), Vector3.ZERO)
	return Transform3D(Basis(), _pivot) * rot * Transform3D(Basis(), -_pivot)

## Impulsion d'avancée (m/s, monde) pour un geste : `elan` m vers l'avant du joueur, à plat.
static func impulsion(avant: Vector3, elan: float) -> Vector3:
	var a := Vector3(avant.x, 0.0, avant.z)
	if not actif or a.length_squared() < 1e-6:
		return Vector3.ZERO
	return a.normalized() * elan * ELAN_IMPULSION

## Rotation visée pour la vue (tangage x, lacet y, roulis z ; rad) : la pointe de l'épée à l'écran (unités : 1 = bord), écart à
## sa place au repos ; `poids` 0..1 (geste en cours), `force` (puissant ×1,3).
static func cible_vue(pointe: Vector2, repos: Vector2, poids: float, force: float) -> Vector3:
	if not actif or poids <= 0.0:
		return Vector3.ZERO
	var d := (pointe - repos).limit_length(1.6) * poids * force
	# lame vers la gauche : la vue tourne un peu à gauche (lacet +) et s'incline à gauche (roulis +) ; lame basse : la vue baisse
	var r := Vector3(d.y * TANGAGE, -d.x * LACET, -d.x * ROULIS)
	return r.limit_length(PLAFOND)
