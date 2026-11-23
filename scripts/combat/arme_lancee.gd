class_name ArmeLancee
extends RigidBody3D
## ARME en corps rigide, saisissable par la télékinésie (groupe « telekinesable ») et qui se plante (ImpactsLances) :
##   ArmeLancee.creer(id) -> ArmeLancee        modèle du catalogue (ArmesEnnemis.instancier : nœuds « prise » / « pointe »), masse réelle
##                                              de sa famille (ImpactsLances.MASSES), boîte de collision le long de la lame
## Contrat télékinésie : donnees_arme(), masse_telekinesie(), saisi_telekinesie(saisi) — saisie alors qu'elle est plantée : elle est
## ARRACHÉE (giclée à la plaie). Plantée : invite « Reprendre » (touche E) quand une boîte de dialogue existe ; reprendre(joueur) la remet au sac.
## Origine du corps = centre de la prise (le corps tourne autour de la poignée, comme une vraie lame lancée).

var id_arme := ""
var modele: Node3D
var _donnees: DonneesArme
var _inter: Node3D

static func creer(id: String) -> ArmeLancee:
	var d := ArmesEnnemis.donnees_arme(id) if id != "" else null
	if d == null:
		d = CatalogueArmes.donnees("epee_soldat")
		id = "epee_soldat"
	var m: Node3D = ArmesEnnemis.instancier(id)
	if m == null and d.modele != "" and ResourceLoader.exists(d.modele):
		m = (load(d.modele) as PackedScene).instantiate() as Node3D
		EpeesLongues.habiller(m)
	if m == null:
		return null
	var a := ArmeLancee.new()
	a.name = "ArmeLancee_" + id
	a.id_arme = id
	a._donnees = d
	a.mass = ImpactsLances.masse_arme(d)
	a.continuous_cd = true
	a.can_sleep = true
	a.collision_layer = 1
	a.collision_mask = 1
	var pr := m.get_node_or_null("prise") as Node3D
	m.position = -(pr.position if pr != null else Vector3(0, d.milieu_poignee, 0))
	a.add_child(m)
	a.modele = m
	# boîte de collision : l'encombrement des maillages dans le repère du modèle
	var bb := AABB()
	var premier := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var t := mi.transform
		var n: Node = mi.get_parent()
		while n != null and n != m:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * mi.mesh.get_aabb()
		bb = b if premier else bb.merge(b)
		premier = false
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(maxf(bb.size.x, 0.04), maxf(bb.size.y, 0.1), maxf(bb.size.z, 0.04)) * 0.9
	f.shape = bs
	f.position = m.position + bb.get_center()
	a.add_child(f)
	a.add_to_group("telekinesable")
	return a

func donnees_arme() -> DonneesArme:
	return _donnees

func masse_telekinesie() -> float:
	return mass

func saisi_telekinesie(saisi: bool) -> void:
	if saisi and ImpactsLances.plantee(self):
		ImpactsLances.arracher(self, true)
	if saisi:
		_retirer_invite()

## Appelé par ImpactsLances quand l'arme se fiche (corps ou mur) : invite « Reprendre ».
func sur_plantee(_dans: Node) -> void:
	var j := _joueur()
	if j == null:
		return
	var dlg := _dialogue(j)
	if dlg == null:
		return
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = j
	it.dialogue = dlg
	it.nom = String(Inventaire.objet(id_arme).get("nom", _donnees.nom if _donnees else "Arme"))
	it.verbe = "Reprendre"
	it.rayon = 2.2
	it.unique = true
	it.action = func() -> Array:
		reprendre(j)
		return []
	it.condition = func() -> bool: return ImpactsLances.plantee(self)
	add_child(it)
	_inter = it

## Fin du vol sans plantage (Telekinesie._fin_suivi) : posée là, RAMASSABLE (« Prendre », touche E) et toujours saisissable.
func au_repos_telekinesie() -> void:
	if ImpactsLances.plantee(self) or is_instance_valid(_inter):
		return
	var j := _joueur()
	var dlg := _dialogue(j) if j != null else null
	if dlg == null:
		return
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = j
	it.dialogue = dlg
	it.nom = String(Inventaire.objet(id_arme).get("nom", _donnees.nom if _donnees else "Arme"))
	it.verbe = "Prendre"
	it.rayon = 1.8
	it.unique = true
	it.action = func() -> Array:
		var inv: Variant = j.get("inventaire")
		if inv != null and Inventaire.connu(id_arme):
			inv.ajouter(id_arme, 1)
		queue_free()
		return []
	it.condition = func() -> bool: return not ImpactsLances.plantee(self)
	add_child(it)
	_inter = it

## Retirer l'arme plantée = la reprendre : arrachée (giclée si elle est dans un corps) puis rangée dans le sac.
func reprendre(j: Node) -> bool:
	if not ImpactsLances.plantee(self):
		return false
	ImpactsLances.arracher(self, true)
	var inv: Variant = j.get("inventaire") if j != null else null
	if inv != null and Inventaire.connu(id_arme):
		inv.ajouter(id_arme, 1)
	Sons.jouer_a(get_parent() if get_parent() else self, ["cloth1"], global_position, -8.0, 0.2)
	queue_free()
	return true

func _retirer_invite() -> void:
	if is_instance_valid(_inter):
		if _inter.get("dialogue") != null and _inter.dialogue.has_method("retirer_invite"):
			_inter.dialogue.retirer_invite(_inter)
		_inter.queue_free()

func _joueur() -> CharacterBody3D:
	var l: Variant = get_meta("lance_par", null)
	if l is CharacterBody3D and is_instance_valid(l):
		return l
	return get_tree().get_first_node_in_group("joueur_local") as CharacterBody3D

func _dialogue(j: Node) -> Control:
	for n in get_tree().get_nodes_in_group("dialogue"):
		if n is Control and n.has_method("inviter"):
			return n
	var scene := get_tree().current_scene
	if scene != null:
		for n in scene.find_children("*", "Control", true, false):
			if n.has_method("inviter") and n.get("joueur") == j:
				return n
	return null
