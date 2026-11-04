class_name TransitionSort
extends RefCounted
## TRANSITION repos → charge → lancer / jet → fin d'UNE main qui tient un sort (logique pure, sans rendu). Docs : docs/MAGIE_TRANSITIONS.md.
## MainSort en crée une par main (`MainSort.transition(m)`), la met à jour à chaque image (`maj`) et la distribue à ceux qui
## dessinent la main : RunesOrbite (`runes.transition`, donc aussi NoyauEcole via `runes`), GestionMagie (aura, `transitions_aura`).
## Les effets de LANCER (jet, projectile, rayon…) lisent ces valeurs pour que la main SE TRANSFORME en sort au lieu de couper/apparaître.
##
## Valeurs continues (toutes lissées : jamais de saut) :
##   charge     0..1  charge du sort à charge (0 hors charge)
##   canal      0..1  « le jet est en cours » : monte en DUREE_CANAL (0,2 s) quand la canalisation commence, retombe en DUREE_FIN (0,3 s)
##   t_canal    s écoulées depuis le début du jet (reste figé pendant la retombée, remis à 0 quand `canal` retombe à 0) : un effet qui
##              accompagne le jet peut s'allonger avec lui (la flamme avance, les runes la suivent)
##   depart_p   0..1  progression du DÉPART d'un sort lancé (projectile, rayon, zone…) sur DUREE_DEPART (0,3 s) ; 1 = au repos / fini
##   fin_p      0..1  progression de la FIN d'un jet sur DUREE_FIN ; 1 = au repos / fini
##   fusion     0..1  DOUBLE MAGIE : les deux sources vont vers `point` (monte avec la charge, 1 pendant le jet, retombe après)
##   puissance  1..   gabarit du sort (1 seul, DOUBLE_PUISSANCE fusionné) : épaisseur, éclat et longueur des effets
## Géométrie (monde) :
##   direction  visée de la main (unitaire), mise à jour pendant canal / départ
##   longueur   distance paume → point visé, bornée par la portée du sort (m)
##   point      point de fusion (milieu des deux paumes) ; decalage = (point - paume) * fusion : à ajouter à la position de la main
##              pour tout ce qui doit se déplacer vers le point de fusion (runes, aura)
##   source     origine d'un jet / d'un projectile = paume + decalage, remontée de LEVEE m au centre de l'énergie tenue (jet : en
##              fondu avec `canal`) : le sort part du cœur de la boule de la main, pas de la paume sous elle
## Drapeaux :
##   phase      REPOS / CHARGE / DEPART / CANALISE / FIN (la plus récente)
##   forme      "jet" (sort canalisé) ou "lance" (tout le reste) ; ecole = école du sort tenu
##   double     vrai tant que la double magie est active (mémorisé jusqu'au retour de `fusion` à 0)
##   meneuse    en double, la main qui lance ; la suiveuse n'ajoute que ses runes et son aura (pas de 2e anneau)
##   anneau_commun  vrai quand les deux mains sont fusionnées : UN seul anneau runique (runes de chaque main intercalées)
## Signaux : charge_debutee, canalise_debutee, depart_lance(forme), fini (fin d'un jet ou coupure).
## Utilitaires : TransitionSort.lisse(x) (smoothstep), `intensite_fusion()`, `anneau_phase(k, n, cote)` (phases intercalées).

signal charge_debutee
signal canalise_debutee
signal depart_lance(forme: String)
signal fini

enum Phase { REPOS, CHARGE, DEPART, CANALISE, FIN }

const DUREE_CANAL := 0.2
const DUREE_FIN := 0.3
const DUREE_DEPART := 0.3
const DUREE_FUSION_MONTE := 0.25
const DUREE_FUSION_FIN := 0.35
## Gabarit d'un sort double fusionné (jet plus épais, anneau plus grand, plus vif).
const DOUBLE_PUISSANCE := 1.45
## Hauteur du centre de l'énergie tenue au-dessus de la paume (m) : origine des jets et des projectiles.
const LEVEE := 0.12

var phase := Phase.REPOS
var ecole := ""
var forme := "lance"
var charge := 0.0
var canal := 0.0
var t_canal := 0.0
var depart_p := 1.0
var fin_p := 1.0
var fusion := 0.0
var puissance := 1.0
var direction := Vector3.FORWARD
var longueur := 3.0
var point := Vector3.ZERO
var decalage := Vector3.ZERO
var source := Vector3.ZERO
var double := false
var meneuse := true
var anneau_commun := false
var _etat := Incantation.REPOS

static func lisse(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## Fusion « utile » (0..1) : même courbe que le déplacement des sources, pour les effets qui s'en servent (éclat, épaisseur).
func intensite_fusion() -> float:
	return lisse(fusion)

## Phase (rad) de la rune k parmi n pour un anneau runique COMMUN aux deux mains : les runes des deux mains s'intercalent
## (cote +1 / -1) au lieu de se superposer.
static func anneau_phase(k: int, n: int, cote: float) -> float:
	return TAU * (float(k) + (0.0 if cote > 0.0 else 0.5)) / maxf(float(n), 1.0)

func est_jet() -> bool:
	return canal > 0.001

## Mise à jour (une fois par image par MainSort) : `i` = incantation de la main (état, charge, double), `sort` = sort tenu (peut être null).
func maj(dt: float, i: Incantation, sort: DonneesSort) -> void:
	var etat := i.etat
	if sort != null:
		ecole = sort.ecole
		forme = "jet" if sort.canalise() else "lance"
	if etat != _etat:
		var prec := _etat
		_etat = etat
		match etat:
			Incantation.CHARGE:
				charge_debutee.emit()
			Incantation.CANALISE:
				fin_p = 1.0
				depart_p = 1.0
				phase = Phase.CANALISE
				canalise_debutee.emit()
			Incantation.RECUPERATION:
				if prec == Incantation.CANALISE:
					phase = Phase.FIN
					fin_p = 0.0
					fini.emit()
				elif prec in [Incantation.INCANTE, Incantation.CHARGE] and i.depuis_lancement < 0.1 + dt:
					phase = Phase.DEPART
					depart_p = 0.0
					depart_lance.emit(forme)
				else:
					phase = Phase.FIN   # coupée (interruption, changement de sort)
					fin_p = 0.0
					fini.emit()
			Incantation.INCANTE, Incantation.REPOS:
				pass
	if etat == Incantation.CHARGE:
		if phase != Phase.CHARGE:
			phase = Phase.CHARGE
		charge = lerpf(charge, i.charge, 1.0 - exp(-dt * 14.0))
	else:
		charge = move_toward(charge, 0.0, dt * 4.0)
	# jet : monte vite, retombe un peu moins vite
	var jette := etat == Incantation.CANALISE
	canal = move_toward(canal, 1.0 if jette else 0.0, dt / (DUREE_CANAL if jette else DUREE_FIN))
	if jette:
		t_canal += dt
	elif canal <= 0.0:
		t_canal = 0.0
	if depart_p < 1.0:
		depart_p = minf(depart_p + dt / DUREE_DEPART, 1.0)
	if fin_p < 1.0:
		fin_p = minf(fin_p + dt / DUREE_FIN, 1.0)
	if phase in [Phase.DEPART, Phase.FIN] and depart_p >= 1.0 and fin_p >= 1.0:
		phase = Phase.REPOS
	if etat == Incantation.REPOS and canal <= 0.0 and charge <= 0.0 and depart_p >= 1.0 and fin_p >= 1.0:
		phase = Phase.REPOS
	# double magie
	if i.double:
		double = true
		meneuse = i.meneuse
	var cible_fusion := 0.0
	if double:
		match etat:
			Incantation.INCANTE:
				cible_fusion = 0.15
			Incantation.CHARGE:
				cible_fusion = 0.2 + 0.8 * lisse(i.charge)
			Incantation.CANALISE, Incantation.RECUPERATION:
				cible_fusion = 1.0 if (canal > 0.01 or depart_p < 0.5) else 0.0
		if not i.double and etat in [Incantation.REPOS, Incantation.RECUPERATION] and canal <= 0.01 and depart_p >= 0.5:
			cible_fusion = 0.0
	var monte := cible_fusion > fusion
	fusion = move_toward(fusion, cible_fusion, dt / (DUREE_FUSION_MONTE if monte else DUREE_FUSION_FIN))
	if fusion <= 0.0 and not i.double:
		double = false
	puissance = lerpf(1.0, DOUBLE_PUISSANCE, intensite_fusion())
	anneau_commun = double and fusion > 0.55

## Position de la main fusionnée : `own` = paume de CETTE main, `autre` = paume de l'autre main (monde).
func poser_fusion(own: Vector3, autre: Vector3) -> void:
	point = (own + autre) * 0.5
	decalage = (point - own) * intensite_fusion()
	source = decalage + Vector3.UP * LEVEE * (lisse(canal) if forme == "jet" else 1.0)

## Visée (monde) : appelé par MainSort pendant canal / départ.
func viser(origine: Vector3, vers: Vector3, portee: float) -> void:
	var d := vers - origine
	var l := d.length()
	if l > 0.05:
		direction = d / l
	longueur = clampf(l, 0.5, maxf(portee, 0.5))
