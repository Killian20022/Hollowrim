class_name DonneesSort
extends Resource
## « SpellData » : tout ce qui distingue un sort tenu dans une main, sur le modèle de DonneesArme (une .tres par sort dans
## data/sorts/). Changer de sort = changer de ressource ; la logique (scripts/magie/lanceur_sorts.gd) ne connaît que les
## types ci-dessous, jamais un sort par son nom. Valeurs et règles : docs/MAGIE.md.

## RAPIDE : part à la fin de l'incantation (projectile ou éclair instantané) ; CANALISE : tant que le bouton est tenu
## (jet, drain, soin, protection) ; CHARGE : se charge en maintenant, part au relâchement (projectile ou zone) ;
## ZONE : zone posée au point visé ou autour du joueur ; ENCHANT : enchante l'arme de l'autre main.
enum Type { RAPIDE, CANALISE, CHARGE, ZONE, ENCHANT }
## Comment le sort atteint ses cibles.
enum Portee { PROJECTILE, JET, CHAINE, ZONE_VISEE, ZONE_SOI, SOI }

@export var id := ""
@export var nom := ""
## "feu", "glace", "electricite", "tenebres", "soin", "protection".
@export var ecole := "feu"
@export var type: Type = Type.RAPIDE
@export var portee_mode: Portee = Portee.PROJECTILE
## Icône (HUD, agent effets) ; facultatif.
@export var icone := ""
## Décrit en une ligne (HUD, guide).
@export_multiline var description := ""

@export_group("Coûts et rythme")
## Mana payé au lancement (RAPIDE, CHARGE à pleine charge, ZONE, ENCHANT).
@export var cout := 10.0
## Mana par seconde (CANALISE).
@export var cout_par_seconde := 0.0
## Part du coût payée par une charge minimale (CHARGE) : coût × lerp(cout_charge_min, 1, charge).
@export var cout_charge_min := 0.6
## Incantation (s) avant le départ ou le début de la canalisation : jamais plus court que la fenêtre de double incantation.
@export var incantation := 0.16
## Temps pour atteindre la pleine charge (CHARGE, ZONE chargée).
@export var temps_charge := 0.0
## Récupération après le lancement (s) : la main ne peut rien lancer d'autre.
@export var recuperation := 0.25
## Temps de recharge du sort (s), compté depuis le lancement.
@export var recharge := 0.0

@export_group("Effets")
## Dégâts directs (RAPIDE, CHARGE, ZONE) ; par seconde (CANALISE).
@export var degats := 10.0
## Dégâts à charge minimale (CHARGE) : degats × lerp(degats_charge_min, 1, charge).
@export var degats_charge_min := 0.6
## Type de dégâts transmis à CalculDegats (résistances de ProfilCible) : "feu", "glace", "electricite", "tenebres".
@export var type_degats := "feu"
## Statut appliqué (Statuts) : "brulure", "gel", "choc", "corruption" ; "" = aucun.
@export var statut := ""
@export var duree_statut := 3.0
## Puissance du statut (brûlure : dégâts/s ; gel : ralentissement 0..1 ; choc : titubement en s ; corruption : part de
## dégâts reçus en plus).
@export var puissance_statut := 1.0
## Force de déséquilibre (posture ennemie, unité de CalculDegats.STAGGER) par coup ; par seconde en CANALISE.
@export var stagger := 6.0
## Portée (m) : jet, chaîne, zone visée.
@export var portee := 18.0
## Largeur d'un jet (m) / rayon d'une zone ou d'une explosion (m).
@export var largeur := 0.8
@export var rayon := 0.0
## Durée d'une zone persistante (tempête) ; 0 = instantanée.
@export var duree_zone := 0.0
## Intervalle des dégâts d'une zone persistante (s).
@export var intervalle_zone := 0.5
## Projectile : vitesse (m/s), forme visuelle ("boule", "eclat", "lance", "trait", "orbe"), nombre (éclats), écart (°),
## cibles traversées (lance).
@export var vitesse := 24.0
@export var forme := "boule"
@export var nombre := 1
@export var ecart := 0.0
@export var traverse := 0
## Chaîne : rebonds (cibles en plus de la première), distance de rebond, dégâts conservés à chaque rebond.
@export var rebonds := 0
@export var distance_rebond := 6.0
@export var attenuation_rebond := 0.75
## Drain : part des dégâts rendue en vie au lanceur. Soin : vie par seconde (CANALISE) ou d'un coup.
@export var drain := 0.0
@export var soin := 0.0
## Protection : réduction des coups de face (corps à corps / projectiles et sorts), mana par point absorbé, cône (°).
@export var reduction_physique := 0.0
@export var reduction_magique := 0.0
@export var mana_par_absorbe := 0.0
@export var cone := 120.0
## Attire les cibles vers le centre (vortex de l'explosion obscure), m/s.
@export var attraction := 0.0
## Enchantement : durée (s), dégâts ajoutés à chaque coup d'épée, statut appliqué par la lame.
@export var duree_enchant := 0.0
@export var degats_enchant := 0.0

@export_group("Double incantation")
## Multiplicateurs quand les deux mains lancent CE sort ensemble (fenêtre de synchronisation) ; clés lues par
## LanceurSorts.version_double : degats, cout, portee, largeur, rayon, duree_statut, puissance_statut, stagger, vitesse,
## drain, soin, reduction ; « rebonds_plus », « nombre_plus », « traverse_plus » s'ajoutent.
@export var double := {"degats": 2.2, "cout": 2.4, "largeur": 1.4, "rayon": 1.4, "duree_statut": 1.5, "puissance_statut": 1.4, "stagger": 1.8}

@export_group("Animation")
## Profil d'animation de la main (PosesIncantation) : "paume" (jet, projectile), "poing" (charge serrée), "levee" (zone),
## "soi" (soin, protection), "lame" (enchantement : la main passe sur la lame).
@export var profil := "paume"
## Interruption : un coup reçu d'au moins ce montant (dégâts) coupe l'incantation, la charge ou la canalisation.
@export var seuil_interruption := 8.0

func canalise() -> bool:
	return type == Type.CANALISE

func se_charge() -> bool:
	return type == Type.CHARGE or (type == Type.ZONE and temps_charge > 0.0)

func offensif() -> bool:
	return ecole in ["feu", "glace", "electricite", "tenebres"] and type != Type.ENCHANT

## Résumé pour le HUD (contrat avec l'agent effets : etat_mains_change).
func resume() -> Dictionary:
	return {"genre": "sort", "id": id, "nom": nom, "ecole": ecole, "type": Type.keys()[type].to_lower(), "icone": icone,
		"cout": cout if type != Type.CANALISE else cout_par_seconde, "par_seconde": type == Type.CANALISE, "recharge": recharge}
