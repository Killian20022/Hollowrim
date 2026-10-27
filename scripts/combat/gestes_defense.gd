class_name GestesDefense
## Gestes de la phase 3 (contre-attaque, finishers) et clips de défense (garde, encaisse, parade, garde brisée) en vue FPS,
## À PART des profils d'attaque : mêmes CLIPS À IMAGES CLÉS du bras droit (AnimateurBras, poses dans
## sources_blender/scripts/gestes_bras_epee.py). Garde : épée en travers devant, pointe vers la gauche (Skyrim) ; parade
## parfaite = petit choc de la garde (clip « parade ») ; coup bloqué = « encaisse » ; garde brisée = « garde_brisee ».

const GESTES := {
	# contre-attaque après une parade parfaite : la lame part de la garde, monte à gauche et fend en grande diagonale
	# jusqu'en bas à droite, plus ample et plus rapide qu'un coup léger (préparation courte : l'épée est déjà levée)
	"contre": {"clip": "contre", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 0.8], "force": 1.4, "tassement": 0.6},
	# finisher de taille (décapitation) : élan à droite, coupe HORIZONTALE qui traverse le centre de l'écran — là où la
	# caméra verrouillée a mis le cou de la cible — et finit à gauche
	"finisher_taille": {"clip": "finisher_taille"},
	# finisher au sol (coup de grâce) : épée levée haut, abattue verticalement à travers le centre sur le corps à terre
	"finisher_sol": {"clip": "finisher_sol"},
}

## FINISHERS MULTIPLES (retour utilisateur 2026-10-27 : « faire différents finish, genre l'épée qui reste plantée avec plein
## de sang et il la retire »). Chaque finisher = un clip du bras droit (marqueurs : frappe, contact, [pommeau], retrait,
## verrou, suivi, fin — voir sources_blender/scripts/gestes_bras_epee.py) et un point d'ANCRAGE : l'os de la cible
## (`ancre`) est amené sur la lame à `frac` de sa longueur (garde → pointe) au marqueur `contact`, pour que la lame
## entre VRAIMENT dans le corps (mains._aligner_finisher). `debout` : la cible reste debout (faux : à terre).
## `mort` : marqueur où subir_finisher est appelé (retrait pour les lames plantées, contact pour la décapitation).
const FINISHERS := {
	# de face, ennemi étourdi : estoc profond dans le torse, la lame reste plantée (jets pulsés), tournée, puis retirée
	"plantee": {"clip": "finisher_plantee", "ancre": "spine_03", "frac": 0.74, "debout": true, "mort": "retrait"},
	# de dos : même geste, plus court ; l'ennemi tourne le dos, il tombe en avant
	"dos": {"clip": "finisher_dos", "ancre": "spine_03", "frac": 0.74, "debout": true, "mort": "retrait", "dos": true},
	# à terre : lame plongée dans le torse du corps au sol, retirée
	"plonge": {"clip": "finisher_plonge", "ancre": "spine_03", "frac": 0.72, "debout": false, "mort": "retrait"},
	# après une parade : coup de pommeau au visage, puis estoc dans le torse, retrait
	"pommeau": {"clip": "finisher_pommeau", "ancre": "spine_03", "frac": 0.74, "debout": true, "mort": "retrait"},
	# pris de côté (ou presque mort) : coupe horizontale au cou, la tête vole (décapitation, gore ≠ 0)
	"decapitation": {"clip": "finisher_taille", "ancre": "neck_01", "frac": 0.55, "debout": true, "mort": "contact"},
}

## Finisher selon le contexte : catégorie de finisher_possible (etourdi, sol, apres_parade, rapide, lateral), joueur dans
## le dos de la cible, cible décapitable (draugr, squelette, bandit — gore activé), cible capable de tenir le finisher
## (preparer_finisher : draugr.gd, ennemi_base.gd) :
##   sol → plongé ; dans le dos (> 120°) → dos ; lateral → décapitation ; apres_parade → pommeau puis estoc ;
##   etourdi → épée plantée ; rapide → décapitation, sinon plantée. Sans preparer_finisher (mannequin) : décapitation.
## `force` (tests, captures) impose un type.
static func choisir_finisher(categorie: String, cible: Node3D, joueur: Node3D, force := "") -> String:
	if force != "" and FINISHERS.has(force):
		return force
	if categorie == "sol":
		return "plonge"
	var decap := _decapitable(cible)
	if cible == null or not cible.has_method("preparer_finisher"):
		return "decapitation"
	if joueur != null:
		var v := joueur.global_position - cible.global_position
		var face := cible.global_transform.basis.z
		if Vector2(v.x, v.z).length() > 0.05 and absf(Vector2(face.x, face.z).angle_to(Vector2(v.x, v.z))) > deg_to_rad(120.0):
			return "dos"
	match categorie:
		"lateral":
			return "decapitation" if decap else "plantee"
		"apres_parade":
			return "pommeau"
		"rapide":
			return "decapitation" if decap else "plantee"
	return "plantee"

static func _decapitable(cible: Node3D) -> bool:
	if cible == null:
		return false
	var cb: Variant = cible.get("combat")
	if cb is CombatEnnemi:
		return (cb as CombatEnnemi).profil.decapitable and Sang.niveau() > 0
	return true

## Pose tenue → [clip, temps] (outils, tests) ; pose(nom) la calcule si les bras du joueur sont chargés.
const POSES := {"garde": ["garde", 0.0], "encaisse": ["encaisse", 0.05], "parade": ["parade", 0.04], "garde_brisee": ["garde_brisee", 0.12]}

## Finishers : durées (s, temps de jeu ; ralenti léger en plus) — élan, coup, suivi. Total ≤ 0,8 s. Le clip suit les
## mêmes instants (marqueurs frappe = 0,26, fin_frappe = 0,38, fin = 0,72).
const FINISHER := {"elan": 0.26, "coup": 0.12, "suivi": 0.34}
## Échelle de temps pendant l'élan du finisher (ralenti léger ; le profil d'impact « finisher » ajoute le sien à l'impact).
const FINISHER_RALENTI := 0.7
## Vitesse de verrouillage de la caméra sur la cible (1/s) et part de la séquence pendant laquelle il dure (élan + coup).
const FINISHER_VERROU := 14.0

## Animateur des bras du joueur (posé par mains.gd) : sert à pose().
static var animateur: AnimateurBras

static func geste(nom: String) -> Dictionary:
	return GESTES[nom]

## Pose de l'épée (repère des mains) d'une pose de défense, lue dans son clip.
static func pose(nom: String) -> Transform3D:
	if animateur == null:
		return Transform3D()
	var c: Array = POSES[nom]
	return animateur.pose_arme(c[0], c[1])

## Ancien choix (avant les finishers multiples) : geste de finisher selon la catégorie.
static func geste_finisher(categorie: String) -> String:
	return "finisher_sol" if categorie == "sol" else "finisher_taille"
