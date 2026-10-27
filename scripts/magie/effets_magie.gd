class_name EffetsMagie
## API des VISUELS de la magie (contrat avec la logique des sorts, branche magie/sorts). CLASSE STATIQUE : rien à
## déclarer dans project.godot ; le premier appel crée un nœud « GestionMagie » dans la scène courante (pools, plafonds,
## lumières, mise à jour par image : scripts/magie/gestion_magie.gd). Aucune logique de jeu ici : pas de dégâts, pas
## de mana, pas de collision de projectile (le rayon de `jet` sert seulement à placer le bout visuel).
## Doc complète, plafonds et coûts : docs/MAGIE_EFFETS.md.
##
## Écoles : "feu", "glace", "electricite", "tenebres", "soin", "protection" (une école inconnue retombe sur "feu").
##
## Exemple (logique) :
##   EffetsMagie.aura_main(main_gauche, "feu", charge)                    # chaque image pendant la charge (0 = éteinte)
##   EffetsMagie.jet("feu", main_gauche, -camera.global_basis.z, 6.0, 1.2, clic_maintenu)   # chaque image
##   var p := EffetsMagie.projectile_visuel("feu", "boule"); scene.add_child(p)  # la logique déplace p puis le libère
##   EffetsMagie.impact("feu", point, normale, 1.0)

const ECOLES := ["feu", "glace", "electricite", "tenebres", "soin", "protection"]
const FORMES := ["boule", "eclat", "lance", "trait", "orbe"]
const STATUTS := ["brulure", "gel", "choc", "corruption"]
const REACTIONS := ["vapeur", "decharge", "decharge_incendiaire", "cristaux_corrompus", "flammes_obscures", "arcs_violets"]

static func _g() -> GestionMagie:
	return GestionMagie.obtenir()

## Aura autour de la main (flammes, givre, arcs, volutes, motes dorées, anneau runique) et lumière colorée légère.
## `intensite` 0 = éteinte ; 0..1 = charge croissante (taille, densité, lumière) ; jusqu'à 1,5 pour un pic. Persistante :
## inutile de rappeler chaque image si rien ne change. Suit `main` (repère du viewmodel) sans retard.
static func aura_main(main: Node3D, ecole: String, intensite: float) -> void:
	_g().aura_main(main, ecole, intensite)

## Sort canalisé : jet de flammes, souffle de givre, arc électrique ramifié, faisceau de drain (ténèbres), flux doré
## (soin), bouclier runique devant la main (protection). À appeler CHAQUE IMAGE tant que `actif` ; s'éteint aussi seul
## 0,2 s après le dernier appel. Part de `origine` (suivie), vers `direction`, sur `portee` m, `largeur` m au bout.
static func jet(ecole: String, origine: Node3D, direction: Vector3, portee: float, largeur: float, actif: bool) -> void:
	_g().jet(ecole, origine, direction, portee, largeur, actif)

## Visuel d'un projectile (formes : "boule", "eclat", "lance", "trait", "orbe"). La logique l'ajoute à la scène, le
## déplace et le libère (queue_free) à l'impact ; la traînée et la lumière sont gérées ici (elles s'éteignent seules).
## Le visuel s'oriente seul dans le sens du déplacement.
static func projectile_visuel(ecole: String, forme: String) -> Node3D:
	return _g().projectile_visuel(ecole, forme)

## Impact : explosion de feu, éclats de glace, onde électrique, éruption obscure, éclat doré, onde runique.
## `force` ~1 (0,3 à 3) règle taille et densité.
static func impact(ecole: String, position: Vector3, normale: Vector3, force: float) -> void:
	_g().impact(ecole, position, normale, force)

## Zone : explosion incendiaire (sol en feu), nova gelée (pics de glace), tempête statique (éclairs du ciel),
## explosion obscure (épines), cercle de soin, cercle de protection. Dure `duree` s.
static func zone(ecole: String, position: Vector3, rayon: float, duree: float) -> void:
	_g().zone(ecole, position, rayon, duree)

## Chaîne d'éclairs entre des points (0,45 s, redessinée toutes les 0,05 s). `ecole` "tenebres" = arcs violets.
static func chaine(ecole: String, points: Array[Vector3]) -> void:
	_g().chaine(ecole, points)

## Statut visible sur une cible (statuts : "brulure", "gel", "choc", "corruption") pendant `duree` s (rappeler
## prolonge ; duree <= 0 retire). Couche additive sur le modèle (gel bleuté, choc, corruption) + particules.
static func statut_cible(cible: Node3D, statut: String, duree: float) -> void:
	_g().statut_cible(cible, statut, duree)

## Enchantement d'arme : flammes le long de la lame, givre, arcs, aura obscure. Couche ADDITIVE (material_overlay) :
## le modèle et sa texture restent visibles. La lame = moitié la plus longue de la boîte du modèle, loin de l'origine.
static func enchant_arme(arme: Node3D, ecole: String, actif: bool) -> void:
	_g().enchant_arme(arme, ecole, actif)

## Réaction entre deux écoles : "vapeur", "decharge", "decharge_incendiaire", "cristaux_corrompus",
## "flammes_obscures", "arcs_violets".
static func reaction(nom: String, position: Vector3, rayon: float) -> void:
	_g().reaction(nom, position, rayon)

## Double incantation (deux mains, même école) : jets élargis et plus denses, arcs épais, lance plus massive, lumière
## renforcée, et un effet entre les deux mains porteuses d'une aura de cette école (vortex obscur, couronne de cristaux,
## arc électrique, foyer de flammes).
static func double(ecole: String, actif: bool) -> void:
	_g().double(ecole, actif)

# ---------------------------------------------------------------- hors contrat (outils)

## Compile tous les réglages une fois (à appeler au chargement d'un niveau : pas d'à-coup au premier sort).
static func prechauffer() -> void:
	_g().prechauffer()

## Compteurs : émetteurs, particules, lumières, éclairs, pics, disques, statuts, auras, jets, projectiles, refus.
static func stats() -> Dictionary:
	return _g().stats()

static func tout_arreter() -> void:
	_g().tout_arreter()
