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

## Compteur d'appels par fonction du contrat (tests : test_magie vérifie que les vrais sorts appellent bien les visuels).
static var appels := {}
## Coupe tout rendu (outils qui ne comptent que les appels) : les appels sont comptés quand même.
static var muet := false

static func _compter(f: String) -> void:
	appels[f] = int(appels.get(f, 0)) + 1

static func _g() -> GestionMagie:
	return GestionMagie.obtenir()

## Jets en cours (id de la paume → {debut, vu}) : le geste de départ et le retour au repos des écoles à lancer propre
## (LancerEcole) s'enchaînent sur le front montant / descendant de `jet`.
static var _jets_lancer := {}
const _ECOLES_LANCER := ["glace", "electricite", "tenebres"]

## Zone lancée par le joueur (nova, tempête, explosion obscure) : geste de départ de la main qui tient le sort, vers le point visé.
static func _lancer_zone(ecole: String, position: Vector3) -> void:
	if not _ECOLES_LANCER.has(ecole):
		return
	var l := LancerEcole.mains_de(ecole, position, 1000.0)
	if l.is_empty():
		return
	var main: Node3D = l[0]
	var d := position - main.global_position
	if d.length() < 0.3:
		d = Vector3.DOWN + Vector3.FORWARD * 0.3
	if ecole == "electricite":
		LancerElec.tension(main, position, 1.0, 0.5, l[1] if l.size() > 1 and bool(_g()._double.get(ecole, false)) else null)
	else:
		LancerEcole.depart(ecole, main, d, 1.0)

static func _lancer_jet(ecole: String, origine: Node3D, direction: Vector3, portee: float, actif: bool) -> void:
	if origine == null or not is_instance_valid(origine) or not _ECOLES_LANCER.has(ecole) or direction.length() < 0.01:
		return
	var id := origine.get_instance_id()
	var maintenant := Time.get_ticks_msec() / 1000.0
	if actif:
		var j: Dictionary = _jets_lancer.get(id, {})
		if j.is_empty() or maintenant - float(j.vu) > 0.4:
			if ecole == "electricite":
				var l := LancerEcole.mains_de(ecole, origine.global_position)
				LancerElec.tension(origine, origine.global_position + direction.normalized() * minf(portee, 6.0), 1.0, 0.45, l[1] if l.size() > 1 and l[0] == origine and bool(_g()._double.get(ecole, false)) else null)
			else:
				LancerEcole.depart(ecole, origine, direction, 1.0)
		_jets_lancer[id] = {"vu": maintenant, "ecole": ecole}
	elif _jets_lancer.has(id):
		_jets_lancer.erase(id)
		# BRANCHEMENT PROVISOIRE (fin du jet) : le repos se reforme dans la main
		match ecole:
			"glace":
				LancerGlace.reformer(origine)
			"electricite":
				LancerElec.reformer(origine)
			"tenebres":
				LancerTenebres.reformer(origine)

## Position de la source d'un jet ou d'un projectile : la paume, ramenée vers le point de fusion en double magie
## (TransitionSort.decalage, posé par MainSort) ; la paume elle-même quand rien n'est fusionné.
static func pos_origine(n: Node3D) -> Vector3:
	if muet:
		return n.global_position
	return _g().pos_origine(n)

## Aura autour de la main (flammes, givre, arcs, volutes, motes dorées, anneau runique) et lumière colorée légère.
## `intensite` 0 = éteinte ; 0..1 = charge croissante (taille, densité, lumière) ; jusqu'à 1,5 pour un pic. Persistante :
## inutile de rappeler chaque image si rien ne change. Suit `main` (repère du viewmodel) sans retard.
static func aura_main(main: Node3D, ecole: String, intensite: float) -> void:
	_compter("aura_main")
	SonsMagie.aura(main, ecole, intensite)
	if muet:
		return
	_g().aura_main(main, ecole, intensite)

## Couleur franche de chaque école pour le signal « charge pleine » (lumière brève de la main).
const COULEUR_PLEINE := {"feu": Color(1.0, 0.55, 0.15), "glace": Color(0.5, 0.78, 1.0), "electricite": Color(0.6, 0.6, 1.0),
	"tenebres": Color(0.62, 0.25, 1.0), "soin": Color(1.0, 0.85, 0.4), "protection": Color(0.7, 0.85, 1.0)}

## Charge PLEINE atteinte (sorts qui se chargent, ChargeSort) : appelé UNE fois au maximum. Son « verrou » de la charge et
## éclat bref de lumière dans la main ; ensuite l'aura pulse par paliers (intensité donnée par MainSort._intensite).
static func charge_pleine(main: Node3D, ecole: String) -> void:
	_compter("charge_pleine")
	if main == null or not is_instance_valid(main):
		return
	SonsMagie.charge_pleine(ecole, main.global_position)
	if muet:
		return
	var c: Color = COULEUR_PLEINE.get(ecole, COULEUR_PLEINE["feu"])
	_g().lumiere("charge_pleine%d" % main.get_instance_id(), main.global_position, c, 3.2, 3.5, 4.0, 0.22)

## Sort canalisé : jet de flammes, souffle de givre, arc électrique ramifié, faisceau de drain (ténèbres), flux doré
## (soin), bouclier runique devant la main (protection). À appeler CHAQUE IMAGE tant que `actif` ; s'éteint aussi seul
## 0,2 s après le dernier appel. Part de `origine` (suivie), vers `direction`, sur `portee` m, `largeur` m au bout.
static func jet(ecole: String, origine: Node3D, direction: Vector3, portee: float, largeur: float, actif: bool) -> void:
	_compter("jet")
	SonsMagie.jet(ecole, origine, actif)
	if muet:
		return
	_lancer_jet(ecole, origine, direction, portee, actif)
	_g().jet(ecole, origine, direction, portee, largeur, actif)
	EffetsSol.sort_jet(ecole, origine, direction, portee, largeur, actif)   # monde réactif : traînée de fonte, brûlure

## Visuel d'un projectile (formes : "boule", "eclat", "lance", "trait", "orbe"). La logique l'ajoute à la scène, le
## déplace et le libère (queue_free) à l'impact ; la traînée et la lumière sont gérées ici (elles s'éteignent seules).
## Le visuel s'oriente seul dans le sens du déplacement.
## `taille` : échelle de la charge (ChargeSort.taille ; 1 = tir normal, ~0,8 au tap, ~1,5 à pleine charge).
static func projectile_visuel(ecole: String, forme: String, taille := 1.0) -> Node3D:
	_compter("projectile_visuel")
	if muet:
		return Node3D.new()
	# glace, électricité, ténèbres : le sort lancé NAÎT de l'effet au repos (scripts/magie/lancer_ecole.gd)
	var lancer := LancerEcole.projectile(ecole, forme, taille)
	if lancer != null:
		return lancer
	return _g().projectile_visuel(ecole, forme, taille)

## Impact : explosion de feu, éclats de glace, onde électrique, éruption obscure, éclat doré, onde runique.
## `force` ~1 (0,3 à 3) règle taille et densité.
static func impact(ecole: String, position: Vector3, normale: Vector3, force: float) -> void:
	_compter("impact")
	SonsMagie.impact(ecole, position, force)
	if muet:
		return
	_g().impact(ecole, position, normale, force)
	EffetsSol.sort_impact(ecole, position, normale, force)   # neige fondue, bloc de glace, brûlure, ombre

## Zone : explosion incendiaire (sol en feu), nova gelée (pics de glace), tempête statique (éclairs du ciel),
## explosion obscure (épines), cercle de soin, cercle de protection. Dure `duree` s.
static func zone(ecole: String, position: Vector3, rayon: float, duree: float) -> void:
	_compter("zone")
	SonsMagie.zone(ecole, position, rayon)
	if muet:
		return
	_lancer_zone(ecole, position)
	_g().zone(ecole, position, rayon, duree)
	EffetsSol.sort_zone(ecole, position, rayon, duree)

## Chaîne d'éclairs entre des points (0,45 s, redessinée toutes les 0,05 s). `ecole` "tenebres" = arcs violets.
static func chaine(ecole: String, points: Array[Vector3]) -> void:
	_compter("chaine")
	SonsMagie.chaine(ecole, points)
	if muet:
		return
	if ecole == "electricite" and points.size() > 1:
		LancerElec.tension(null, points[1], 1.0, 0.3, null, points[0])   # les arcs de la paume se tendent vers la première cible
	_g().chaine(ecole, points)
	EffetsSol.sort_points(ecole, points)

## Décharge d'un sort à charge, d'un coup, de `depart` (paume) à `fin` : forme "orage" = éclairs de Force ramifiés qui
## frappent `fin` et ses abords (éclair du ciel au sol, arcs rampants, flash). `k` ~1 (0,5 à 1,4) : charge atteinte ;
## `normale` : celle de la surface touchée. Dure 0,6 à 1 s.
static func decharge(ecole: String, forme: String, depart: Vector3, fin: Vector3, k: float, normale := Vector3.UP) -> void:
	_compter("decharge")
	SonsMagie.decharge(forme, depart, k)
	if muet:
		return
	if ecole == "electricite":
		var l := LancerEcole.mains_de(ecole, depart, 0.5)
		LancerElec.tension(l[0] if not l.is_empty() else null, fin, k, 0.55, l[1] if l.size() > 1 and bool(_g()._double.get(ecole, false)) else null, depart)
	_g().decharge(ecole, forme, depart, fin, k, normale)
	EffetsSol.sort_impact(ecole, fin, normale, k)

## Statut visible sur une cible (statuts : "brulure", "gel", "choc", "corruption") pendant `duree` s (rappeler
## prolonge ; duree <= 0 retire). Couche additive sur le modèle (gel bleuté, choc, corruption) + particules.
static func statut_cible(cible: Node3D, statut: String, duree: float) -> void:
	_compter("statut_cible")
	if muet:
		return
	_g().statut_cible(cible, statut, duree)

## Enchantement d'arme : flammes le long de la lame, givre, arcs, aura obscure. Couche ADDITIVE (material_overlay) :
## le modèle et sa texture restent visibles. La lame = moitié la plus longue de la boîte du modèle, loin de l'origine.
static func enchant_arme(arme: Node3D, ecole: String, actif: bool) -> void:
	_compter("enchant_arme")
	SonsMagie.enchant(ecole, arme.global_position if arme != null and arme.is_inside_tree() else Vector3.ZERO, actif)
	if muet:
		return
	_g().enchant_arme(arme, ecole, actif)

## Réaction entre deux écoles : "vapeur", "decharge", "decharge_incendiaire", "cristaux_corrompus",
## "flammes_obscures", "arcs_violets".
static func reaction(nom: String, position: Vector3, rayon: float) -> void:
	_compter("reaction")
	SonsMagie.reaction(nom, position)
	if muet:
		return
	_g().reaction(nom, position, rayon)

## Double incantation (deux mains, même école) : jets élargis et plus denses, arcs épais, lance plus massive, lumière
## renforcée, et un effet entre les deux mains porteuses d'une aura de cette école (vortex obscur, couronne de cristaux,
## arc électrique, foyer de flammes).
static func double(ecole: String, actif: bool) -> void:
	_compter("double")
	SonsMagie.double(ecole, actif)
	if muet:
		return
	_g().double(ecole, actif)

# ---------------------------------------------------------------- hors contrat (outils)

## Compile tous les réglages une fois (à appeler au chargement d'un niveau : pas d'à-coup au premier sort).
static func prechauffer() -> void:
	_g().prechauffer()

## Compteurs : émetteurs, particules, lumières, éclairs, pics, disques, statuts, auras, jets, projectiles, refus.
static func stats() -> Dictionary:
	return _g().stats()

static func tout_arreter() -> void:
	SonsMagie.tout_arreter()
	_g().tout_arreter()
