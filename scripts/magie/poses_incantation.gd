class_name PosesIncantation
## Poses FPS des mains qui incantent (paume ouverte vers l'avant, comme les planches references/magie/*_fps_1100.jpg),
## À PART des gestes de l'épée (mains.gd, profils_animation.gd ne sont pas touchés). Chaque pose : position du poignet
## (os de la main) dans le repère caméra (+X droite, +Y haut, -Z devant), direction de la PAUME, direction des DOIGTS,
## fermeture des doigts (0 = main ouverte, 1 = poing). Écrite pour la main GAUCHE ; la droite est le miroir en X.
## MainSort (main_sort.gd) interpole vers la pose voulue (ressort) et pose les os de la main par IK + orientation.

const POSES := {
	# main levée au repos, sort prêt (lueur dans la paume), doigts à demi refermés
	"repos": {"pos": Vector3(-0.25, -0.25, -0.40), "paume": Vector3(0.30, 0.25, -1.0), "doigts": Vector3(0.10, 1.0, -0.15), "fermeture": 0.38},
	# incantation : la main monte et s'ouvre
	"incante": {"pos": Vector3(-0.22, -0.20, -0.45), "paume": Vector3(0.22, 0.05, -1.0), "doigts": Vector3(0.05, 1.0, -0.30), "fermeture": 0.18},
	# charge « paume » (jet, zone) : main ramenée, doigts en griffe, énergie qui s'accumule
	"charge": {"pos": Vector3(-0.21, -0.23, -0.36), "paume": Vector3(0.45, 0.35, -0.8), "doigts": Vector3(0.10, 1.0, -0.10), "fermeture": 0.55},
	# charge « poing » (boule de feu, lance) : poing serré sur l'énergie
	"poing": {"pos": Vector3(-0.22, -0.25, -0.33), "paume": Vector3(0.55, 0.30, -0.75), "doigts": Vector3(0.10, 1.0, 0.05), "fermeture": 0.78},
	# départ : bras tendu, paume vers la cible
	"lance": {"pos": Vector3(-0.16, -0.16, -0.56), "paume": Vector3(0.10, 0.0, -1.0), "doigts": Vector3(0.0, 1.0, -0.55), "fermeture": 0.05},
	# canalisation : bras tendu, doigts écartés (jet, arc, drain)
	"canalise": {"pos": Vector3(-0.17, -0.18, -0.53), "paume": Vector3(0.15, 0.0, -1.0), "doigts": Vector3(0.0, 1.0, -0.40), "fermeture": 0.08},
	# zone : paume vers le ciel (charge), puis frappée vers le sol (départ)
	"levee": {"pos": Vector3(-0.24, -0.14, -0.40), "paume": Vector3(0.10, 1.0, -0.15), "doigts": Vector3(0.20, 0.15, -1.0), "fermeture": 0.30},
	"levee_lance": {"pos": Vector3(-0.20, -0.30, -0.50), "paume": Vector3(0.05, -1.0, -0.35), "doigts": Vector3(0.10, -0.30, -1.0), "fermeture": 0.05},
	# soin / protection : paume large devant soi
	"soi": {"pos": Vector3(-0.15, -0.19, -0.46), "paume": Vector3(0.25, 0.05, -1.0), "doigts": Vector3(0.05, 1.0, -0.20), "fermeture": 0.0},
	# enchantement : la main passe le long de la lame (de la garde vers la pointe, `lame_fin` à la fin de l'incantation)
	"lame": {"pos": Vector3(0.04, -0.22, -0.42), "paume": Vector3(1.0, 0.15, -0.2), "doigts": Vector3(0.0, 0.5, -1.0), "fermeture": 0.1},
	"lame_fin": {"pos": Vector3(-0.06, 0.02, -0.62), "paume": Vector3(1.0, 0.15, -0.2), "doigts": Vector3(0.0, 0.7, -1.0), "fermeture": 0.1},
	# l'épée frappe : la main qui tient le sort s'écarte et descend (contrepoids), sans se mettre dans la trajectoire
	"ecartee": {"pos": Vector3(-0.34, -0.38, -0.36), "paume": Vector3(0.35, 0.35, -0.9), "doigts": Vector3(0.10, 1.0, 0.0), "fermeture": 0.45},
	# bouclier : repos (bas à gauche) et garde (devant, face au coup)
	"bouclier": {"pos": Vector3(-0.30, -0.32, -0.36), "paume": Vector3(0.9, 0.0, -0.4), "doigts": Vector3(0.0, 1.0, 0.0), "fermeture": 0.85},
	"bouclier_garde": {"pos": Vector3(-0.13, -0.20, -0.36), "paume": Vector3(1.0, 0.0, -0.15), "doigts": Vector3(0.0, 1.0, 0.1), "fermeture": 0.85},
}

## Double incantation : les deux mains se rapprochent du centre (décalage en X vers l'axe, pour la main gauche).
const RAPPROCHE_DOUBLE := 0.07
## Tremblement de la canalisation et de la pleine charge (m, rad/s).
const TREMBLE := 0.003

static func pose(nom: String, main := "gauche") -> Dictionary:
	var p: Dictionary = POSES.get(nom, POSES["repos"])
	if main == "gauche":
		return p
	var m := {}
	for k in ["pos", "paume", "doigts"]:
		var v: Vector3 = p[k]
		m[k] = Vector3(-v.x, v.y, v.z)
	m["fermeture"] = p["fermeture"]
	return m

## Pose voulue selon l'état de l'incantation (Incantation), le profil d'animation du sort et la charge.
static func pour(etat: String, profil: String, charge: float, depuis_lancement: float, t: float, main := "gauche") -> Dictionary:
	var nom := "repos"
	match etat:
		"incante":
			nom = "lame" if profil == "lame" else ("levee" if profil == "levee" else ("soi" if profil == "soi" else "incante"))
		"charge":
			nom = "poing" if profil == "poing" else ("levee" if profil == "levee" else "charge")
		"canalise":
			nom = "soi" if profil == "soi" else "canalise"
		"recuperation":
			if depuis_lancement < 0.22:
				nom = "levee_lance" if profil == "levee" else ("lame_fin" if profil == "lame" else "lance")
	var p := pose(nom, main)
	if etat == "incante" and profil == "lame":
		p = melange(p, pose("lame_fin", main), clampf(t / 0.5, 0.0, 1.0))
	if etat == "charge" and charge > 0.0:
		# la main se resserre un peu à mesure que la charge monte
		p = p.duplicate()
		p["fermeture"] = minf(1.0, float(p["fermeture"]) + charge * 0.12)
	return p

static func melange(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], k), "paume": (a["paume"] as Vector3).lerp(b["paume"], k).normalized(),
		"doigts": (a["doigts"] as Vector3).lerp(b["doigts"], k).normalized(), "fermeture": lerpf(a["fermeture"], b["fermeture"], k)}
