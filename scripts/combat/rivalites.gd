class_name Rivalites
## Combats entre ennemis de factions HOSTILES (data/factions.json, retours exe 5) : le placement les sépare (outils/test_factions.gd),
## mais une poursuite ou une errance peut les mettre face à face ; ils se battent alors avec leur IA ordinaire, la cible changeant
## seulement de « joueur » à « rival ». Ciblage minimal :
##   - chercher(soi, rayon) : l'ennemi vivant hostile le plus proche, au même étage, en vue (rayon des yeux au torse) ;
##   - cible(soi, rival, joueur) : le rival s'il est plus près que le joueur, sinon le joueur (rien ne change pour le joueur seul) ;
##   - frapper(attaquant, victime, degats) : coup ordinaire (CombatEnnemi : dégâts, réaction, sang) marqué « rival » : ni arrêt sur
##     image, ni secousse de caméra, ni sang sur la lame du joueur ; la victime prend l'attaquant pour rival et riposte.
## Les IA qui s'en servent (BeteQuat, draugr.gd) gardent leur rival dans `rival` et le rafraîchissent PERIODE s ; les chefs, les archers
## et les ennemis sans faction n'ont pas de rival.

const PERIODE := 0.5
const ETAGE := 3.0        # écart vertical au-delà duquel un rival n'est pas pris (étages de la crypte, corniches)

static func vivant(n: Node) -> bool:
	return n != null and is_instance_valid(n) and n.is_inside_tree() and n.has_method("vivant") and n.vivant()

## L'ennemi vivant d'une faction hostile à celle de `soi`, le plus proche dans `rayon` m (horizontal), au même étage et en vue ; null sinon.
static func chercher(soi: Node3D, rayon: float, voir := true) -> Node3D:
	var f := Factions.de(soi)
	if f == "" or Factions.ennemies_de(f).is_empty():
		return null
	var meilleur: Node3D = null
	var dm := rayon
	for e in soi.get_tree().get_nodes_in_group("ennemis"):
		if e == soi or not vivant(e) or not Factions.hostiles(f, Factions.de(e)):
			continue
		var n := e as Node3D
		var v := n.global_position - soi.global_position
		if absf(v.y) > ETAGE:
			continue
		v.y = 0.0
		var d := v.length()
		if d >= dm:
			continue
		if voir and not _en_vue(soi, n):
			continue
		dm = d
		meilleur = n
	return meilleur

static func _en_vue(soi: Node3D, n: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(soi.global_position + Vector3(0, 0.8, 0), n.global_position + Vector3(0, 0.8, 0))
	var ex: Array[RID] = []
	for e in soi.get_tree().get_nodes_in_group("ennemis"):
		if e is CollisionObject3D:
			ex.append((e as CollisionObject3D).get_rid())
	var j: Variant = soi.get("joueur")
	if j is CollisionObject3D and is_instance_valid(j):
		ex.append((j as CollisionObject3D).get_rid())
	q.exclude = ex
	return soi.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Cible du moment : le rival vivant s'il est plus près (horizontalement) que le joueur, sinon le joueur.
static func cible(soi: Node3D, rival: Node3D, joueur: Node3D) -> Node3D:
	if not vivant(rival):
		return joueur
	if joueur == null or not is_instance_valid(joueur):
		return rival
	var dr := Vector2(rival.global_position.x - soi.global_position.x, rival.global_position.z - soi.global_position.z).length()
	var dj := Vector2(joueur.global_position.x - soi.global_position.x, joueur.global_position.z - soi.global_position.z).length()
	return rival if dr < dj else joueur

## Coup d'un ennemi sur un rival : recevoir_coup ordinaire, info marquée « rival » (pas de retour d'impact pour le joueur, CombatEnnemi).
static func frapper(attaquant: Node3D, victime: Node3D, degats: float, puissant := false) -> String:
	if not vivant(victime):
		return ""
	var info := {"type": "tranchant" if Factions.de(attaquant) in ["draugr", "pillard"] else "contondant", "attaque": "lourde" if puissant else "legere",
		"zone": "torse", "rival": true}
	var r := String(victime.recevoir_coup(degats, attaquant.global_position, puissant, info))
	if vivant(victime) and "rival" in victime:
		victime.set("rival", attaquant)
		if victime.has_method("alerter"):
			victime.alerter()
	return r
