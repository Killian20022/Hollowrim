class_name DegatsObjets
extends RefCounted
## DÉGÂTS D'IMPACT d'un OBJET mis en mouvement par un sort de l'esprit (télékinésie lancée, vortex d'attraction, répulsion, objet lâché)
## qui percute un ennemi (docs/MAGIE.md, « Objets lancés sur les ennemis »). Appelé par ImpactsLances._objet_dans_corps.
##
## Courbe : dégâts BRUTS = K × E^1,3 où E = ½·m·v² (J), plancher 1, plafond 170 ; divisée par la RÉSISTANCE de la cible (chef ×0,35, troll
## ~×0,35). DegatsCombat en retire ~20 % (armure, posture) : ce sont les PV réellement perdus qui sont donnés ici (test_degats_ragdoll).
## Vitesses de lancer pleine charge de la télékinésie (masse -> v = 24 × (4/m)^0,3, bornée) ; ennemi courant = 104 PV (bandit, draugr) :
##   chope 0,4 kg, 30 m/s (E 180)   ~3      caisse 18 kg, 15 m/s (E 2 100)   ~67 (grosse blessure)
##   tonneau 28 kg, 13,4 m/s (E 2 500) ~87-110 selon le point d'impact : tue un bandit ; un guerrier (135 PV) survit ; un chef ~30 %
## Un coup fort (quantité de mouvement m·v >= Q_PROJETER) emporte l'ennemi en RAGDOLL (RagdollEsprit : vol, choc, relevé capturé) à la
## vitesse que lui donne le choc (conservation de la quantité de mouvement, un peu de rebond). Rien pour le joueur lanceur (ImpactsLances
## l'écarte déjà) ; réseau : DegatsCombat.appliquer et SortsEsprit.projeter passent par l'hôte pour une marionnette.
## `-- --sans-degats-objets` : courbe d'avant (ImpactsLances.DEGATS_OBJET).

static var actif := not ("--sans-degats-objets" in OS.get_cmdline_user_args())

const K := 0.0053
const EXPOSANT := 1.3
const MIN := 1.0
const MAX := 170.0
const RESISTE_CHEF := 0.35
## Quantité de mouvement (kg·m/s) qui emporte un ennemi en ragdoll ; masse minimale (une chope ne projette personne).
const Q_PROJETER := 110.0
const MASSE_PROJETER := 5.0
const RESTITUTION := 1.25
const MASSE_ENNEMI := 70.0

static func energie(masse: float, v: float) -> float:
	return 0.5 * masse * v * v

## Divise les dégâts : 1 pour un ennemi courant, ~0,35 pour un chef ou un troll.
static func resistance(ennemi: Node) -> float:
	var p := SortsEsprit.puissance(ennemi)
	var r := clampf(1.0 / sqrt(maxf(p, 1.0)), RESISTE_CHEF, 1.0)
	if SortsEsprit.est_chef(ennemi):
		r = minf(r, RESISTE_CHEF)
	return r

## Dégâts (PV) d'un objet d'énergie `e` sur `ennemi`.
static func degats(e: float, ennemi: Node, repli: float) -> float:
	if not actif:
		return repli
	return clampf(K * pow(maxf(e, 0.0), EXPOSANT), MIN, MAX) * (resistance(ennemi) if ennemi != null else 1.0)

## Après le coup : un choc fort emporte l'ennemi en ragdoll (sauf chef / mort / trop léger). Renvoie la vitesse donnée (0 = rien).
static func apres_impact(ennemi: Node3D, dir: Vector3, masse: float, v: float, lanceur: Node, resultat: String) -> float:
	if not actif or not (ennemi is CharacterBody3D) or resultat == "tue" or not SortsEsprit.vivant(ennemi) or SortsEsprit.est_chef(ennemi):
		return 0.0
	var q := masse * v
	if q < Q_PROJETER or masse < MASSE_PROJETER:
		return 0.0
	var es := esprit_de(lanceur)
	if es == null:
		return 0.0
	var ve := q / (MASSE_ENNEMI * maxf(SortsEsprit.puissance(ennemi), 0.4)) * RESTITUTION
	if ve < SortsEsprit.VITESSE_DECOLLE:
		return 0.0
	var plat := Vector3(dir.x, 0.0, dir.z)
	plat = plat.normalized() if plat.length() > 0.05 else dir
	es.projeter(ennemi as CharacterBody3D, plat * minf(ve, 16.0) + Vector3.UP * minf(ve * 0.3, 4.0), es._sort("repulsion"))
	return ve

static func esprit_de(joueur: Variant) -> SortsEsprit:
	if joueur == null or not is_instance_valid(joueur):
		return null
	var m: Variant = (joueur as Object).get("mains")
	if m == null or not is_instance_valid(m):
		return null
	var mg: Variant = (m as Object).get("magie")
	if mg == null or not is_instance_valid(mg):
		return null
	var es: Variant = (mg as Object).get("esprit")
	return es as SortsEsprit if es != null and is_instance_valid(es) else null
