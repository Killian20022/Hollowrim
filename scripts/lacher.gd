class_name Lacher
extends RefCounted
## LÂCHER un objet du sac (inventaire I) : il tombe devant le joueur dans un petit SAC AU SOL, ramassable par « Fouiller » (E) comme le
## butin d'un corps (scripts/butin.gd, fenêtre de butin FenetreButin). Réutilise le butin existant : le sac au sol est un Butin sans pièces
## dont la clé « lache:<n> » le fait SAUVEGARDER avec la partie (ButinTables.restes / corps, repris par Butin.restaurer).
## Non lâchables : objets uniques (rarete « unique ») et objets de quête (valeur 0 hors consommables, ou « quete »: true fiche).

const NOM := "Objet lâché"
const DISTANCE := 1.1

## "" si `id` peut être lâché, sinon la raison (message clair pour l'inventaire).
static func refus(id: String) -> String:
	var o := Inventaire.objet(id)
	if o.is_empty():
		return "Objet inconnu."
	var nom := String(o.get("nom", id))
	if String(o.get("rarete", "")) == "unique":
		return "%s est un objet unique : on ne s'en défait pas." % nom
	if bool(o.get("quete", false)) or (Inventaire.categorie_de(id) != "consommable" and float(o.get("valeur", 0)) <= 0.0):
		return "%s est un objet de quête : impossible de le lâcher." % nom
	return ""

## Lâche `n` exemplaires de `id` devant le joueur. Renvoie "" (fait) ou la raison du refus.
static func lacher(joueur: CharacterBody3D, hud: Control, id: String, n: int) -> String:
	if joueur == null or not is_instance_valid(joueur):
		return "Impossible ici."
	var inv: Inventaire = joueur.inventaire
	var r := refus(id)
	if r != "":
		return r
	n = clampi(n, 1, inv.nombre(id))
	if inv.nombre(id) <= 0:
		return "Vous n'en avez pas."
	var parent := joueur.get_parent()
	if parent == null:
		return "Impossible ici."
	inv.retirer(id, n)
	var b := Node3D.new()
	b.set_script(preload("res://scripts/butin.gd"))
	b.joueur = joueur
	b.hud = hud
	b.nom_corps = NOM
	b.contenu = {id: n}
	b.cle_sauvegarde = "lache:%d_%d" % [Time.get_unix_time_from_system() as int, Time.get_ticks_usec()]
	parent.add_child(b)
	var pt := _point(joueur)
	b.global_position = pt + Vector3(0, ObjetMonde.hausse_sol(pt, parent), 0)   # sur les pavés du village (sans collision), pas dessous
	return ""

## Devant le joueur (selon la caméra), posé sur le sol (rayon vers le bas ; le joueur est exclu).
static func _point(joueur: CharacterBody3D) -> Vector3:
	var av := -joueur.global_basis.z
	var cam: Variant = joueur.get("camera")
	if cam is Camera3D:
		av = -(cam as Camera3D).global_basis.z
	av.y = 0.0
	av = av.normalized() if av.length() > 0.05 else Vector3.FORWARD
	var p := joueur.global_position + av * DISTANCE
	var espace := joueur.get_world_3d().direct_space_state
	var haut := Vector3(p.x, joueur.global_position.y + 1.0, p.z)
	var q := PhysicsRayQueryParameters3D.create(haut, haut - Vector3(0, 3.0, 0))
	q.exclude = [joueur.get_rid()]
	var res := espace.intersect_ray(q)
	if res.is_empty():
		return Vector3(p.x, joueur.global_position.y, p.z)
	# mur entre le joueur et le point : le sac tombe à ses pieds
	var m := PhysicsRayQueryParameters3D.create(joueur.global_position + Vector3(0, 0.6, 0), Vector3(p.x, joueur.global_position.y + 0.6, p.z))
	m.exclude = [joueur.get_rid()]
	if not espace.intersect_ray(m).is_empty():
		return joueur.global_position
	return res["position"]

## Visuel du Butin « lache: » : les OBJETS EUX-MÊMES posés au sol (ObjetMonde.tas : bijou, arme couchée, armure affaissée…), au plus
## ObjetMonde.MAX_TAS côte à côte ; les objets sans modèle 3D (potions, ingrédients…) et le surplus : une sacoche nouée.
## `contenu` : {id: n} encore au sol (vide = sac seul). Rappelé après une fouille partielle : l'ancien visuel est remplacé.
static func habiller(noeud: Node3D, contenu := {}) -> void:
	var ancien := noeud.get_node_or_null("Visuel")
	if ancien != null:
		noeud.remove_child(ancien)
		ancien.queue_free()
	var v := ObjetMonde.tas(contenu, "sol") if not contenu.is_empty() else ObjetMonde.sacoche()
	v.name = "Visuel"
	noeud.add_child(v)
