class_name GestesBouclier
extends RefCounted
## Gestes du BOUCLIER (main gauche, IK) — à part des clips du bras droit (bras_epee.tres n'est pas touché).
## Chaque pose = repère du bouclier dans le repère caméra (+X droite, +Y haut, -Z devant), écrite DIRECTEMENT pour la main
## gauche (pas de miroir) : [centre du poing sur la poignée, axe de la poignée (+Y du modèle), normale de la face peinte
## (+X du modèle)]. L'IK de la main gauche amène le poing sur la poignée (mains._poser_torche) ; le poignet reste dans
## ses limites (orientation_main.gd).
##   repos   : bas à gauche, face tournée vers le centre (on voit la peinture de biais, le centre de l'écran reste libre)
##   garde   : levé devant, à gauche du centre, le bord haut sous la ligne des yeux (on voit l'ennemi par-dessus)
##   impact  : coup bloqué — le bouclier recule vers le visage et bascule (geste court)
##   coup    : parade parfaite — coup de bouclier poussé vers l'avant (l'attaquant est déséquilibré)
##   brisee  : garde brisée — le bouclier est rabattu vers le bas à gauche
##   attaque : contrepoids pendant un coup d'épée — le bouclier s'écarte à gauche, la lame balaie l'écran devant lui
##   sprint  : rabattu le long du corps

const POSES := {
	"repos": [Vector3(-0.42, -0.36, -0.50), Vector3(0.10, 1.0, 0.22), Vector3(1.0, 0.10, -0.22)],
	"garde": [Vector3(-0.17, -0.33, -0.46), Vector3(0.22, 1.0, 0.0), Vector3(0.18, 0.16, -1.0)],
	"impact": [Vector3(-0.17, -0.36, -0.39), Vector3(0.30, 1.0, 0.12), Vector3(0.22, 0.42, -1.0)],
	"coup": [Vector3(-0.09, -0.30, -0.60), Vector3(0.30, 1.0, -0.05), Vector3(0.10, 0.05, -1.0)],
	"brisee": [Vector3(-0.42, -0.60, -0.40), Vector3(0.65, 0.8, 0.1), Vector3(0.75, -0.35, -0.55)],
	"attaque": [Vector3(-0.50, -0.42, -0.44), Vector3(0.05, 1.0, 0.25), Vector3(1.0, 0.0, 0.05)],
	"sprint": [Vector3(-0.46, -0.52, -0.40), Vector3(0.25, 1.0, 0.35), Vector3(1.0, -0.15, 0.0)],
}

## Durées des gestes courts (s) ; « brisee » = le titubement de la garde brisée (DefenseJoueur.TITUBE).
const DUREES := {"impact": 0.26, "coup": 0.34, "brisee": DefenseJoueur.TITUBE}
## Ressorts (1/s) : levée de la garde (vive), baisse, contrepoids des coups.
const LEVEE := 24.0
const BAISSE := 10.0
const CONTREPOIDS := 18.0

var k_garde := 0.0
var k_attaque := 0.0
var k_sprint := 0.0
## Geste court en cours ("" : aucun) et son temps.
var geste := ""
var t := 0.0
## Nombre de gestes joués (tests).
var joues := {}

static func transform_pose(nom: String) -> Transform3D:
	var p: Array = POSES[nom]
	return ProfilsAnimation.transform_pose(p, 1.0)

func declencher(nom: String) -> void:
	geste = nom
	t = 0.0
	joues[nom] = int(joues.get(nom, 0)) + 1

## Poids du geste court : monte vite (premier quart), tient, retombe sur la seconde moitié.
func poids_geste() -> float:
	if geste == "":
		return 0.0
	var d := float(DUREES[geste])
	return smoothstep(0.0, d * 0.22, t) * (1.0 - smoothstep(d * 0.5, d, t))

## Pose de repos du bouclier : celle de sa DonneesArme (repos_poignee / repos_lame / repos_fil, écrites pour la main droite
## comme toutes les armes, mises en miroir ici) ; POSES["repos"] seulement sans données.
var repos := Transform3D()
var repos_ok := false

func regler_repos(d: DonneesArme) -> void:
	repos = ProfilsAnimation.transform_pose([d.repos_poignee, d.repos_lame, d.repos_fil], -1.0)
	repos_ok = true

## Une image : `garde` (garde levée), `attaque` (coup d'épée en cours), `sprint`. Renvoie le repère du bouclier (caméra).
func avancer(dt: float, garde: bool, attaque: bool, sprint: bool) -> Transform3D:
	k_garde = lerpf(k_garde, 1.0 if garde else 0.0, 1.0 - exp(-(LEVEE if garde else BAISSE) * dt))
	k_attaque = lerpf(k_attaque, 1.0 if attaque and not garde else 0.0, 1.0 - exp(-CONTREPOIDS * dt))
	k_sprint = lerpf(k_sprint, 1.0 if sprint and not garde and not attaque else 0.0, 1.0 - exp(-8.0 * dt))
	if geste != "":
		t += dt
		if t >= float(DUREES[geste]):
			geste = ""
	return pose_courante()

func pose_courante() -> Transform3D:
	var p := melange(repos if repos_ok else transform_pose("repos"), transform_pose("garde"), k_garde)
	p = melange(p, transform_pose("attaque"), k_attaque)
	p = melange(p, transform_pose("sprint"), k_sprint)
	if geste != "":
		p = melange(p, transform_pose(geste), poids_geste())
	return p

static func melange(a: Transform3D, b: Transform3D, k: float) -> Transform3D:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	return Transform3D(Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), k)), a.origin.lerp(b.origin, k))
