class_name GardeMaison
## GARDES EN ARMURE « MAISON » (décision de l'utilisateur, 2026-11-11 : les armures Tripo des gardes ont des trous impossibles à boucher,
## elles sont abandonnées). Un garde = le corps Quaternius du Gardien nordique (GardienNordique, base Humain.creer : 65 os, ragdoll,
## démembrement, animations partagées) habillé par ArmureVisible (le système du héros) avec NOS pièces d'armure (assets/modeles/armures/
## porte/<id>.glb, skinnées sur ce squelette) : ce que la pièce recouvre est masqué sur le corps, comme sur le héros.
##
## TOUT est DATA-DRIVEN (data/gardes.json) : on ne dépend que des IDENTIFIANTS des pièces (fiches data/objets/armures.json), jamais de leur
## géométrie : une version affinée d'un glb (même id) se branche sans retouche.
##   « ensembles » : nom -> {tete, torse, mains, pieds[, jambes]} (ids d'armures) ;
##   « roles »     : rôle -> {ensemble, arme (lance | epee | arc), bouclier (bras | dos | "" ; défaut : bras aux postes, dos en ronde)} ;
##   par garde     : « role », et pour la variété « ensemble » (autre ensemble), « pieces » ({emplacement: id | ""} : remplace une pièce ;
##                   "" = aucune), « sans_casque » (pas de pièce de tête : le casque à nasal du Gardien reste), plus poil / peau / rase /
##                   taille / largeur comme les autres gardes.
## Armes : lance (clips à la lance du Gardien : faction lance droite, garde, estoc), épée du jeu au poing (clips d'épée d'Humain),
## arc du jeu (ChasseresseNordique.equiper_arc, clips Pistol_*). Lance et bouclier du Gardien sont SORTIS du maillage des accessoires
## (maillage « armes_garde ») avant l'habillage : le masquage d'ArmureVisible (zones des mains, du dos) ne les ronge pas.
## Butin : pieces_portees(modele) = les ids portés (PnjCombat les laisse sur le corps d'un garde tué).
##   GardeMaison.creer(g: Dictionary) -> Node3D      (contrat d'Humain.creer : Skeleton3D, « Animations », ragdoll)
## Retour arrière : --gardes-armures-tripo (corps GardeTripo d'avant), --modeles-anciens=gardes (Gardien d'origine), « "modele_ancien": true ».

const DONNEES := "res://data/gardes.json"
const EPEE := preload("res://assets/modeles/joueur/epee_nordique.glb")
## Prise de l'épée dans la main droite : celle du héros (corps_joueur.gd, PRISE), même corps, même main.
const PRISE_EPEE := Transform3D(Basis(Vector3(-0.999251, -0.038334, -0.005288), Vector3(-0.014458, 0.24307, 0.969901), Vector3(-0.035895, 0.969252, -0.243442)), Vector3(-0.007936, 0.142938, 0.002241))
const META := "armure_garde"           # méta du modèle : {emplacement: id} portés

static var _bases := {}                # "arme|bouclier" -> Gardien de référence (hors arbre, lance et bouclier déjà séparés)
static var _ensembles := {}
static var _roles := {}

## Vrai si les gardes prennent ce corps (défaut) ; faux avec --gardes-armures-tripo, --modeles-anciens=gardes ou "modele_ancien".
static func actif(g: Dictionary = {}) -> bool:
	if not ModelesTripo.actif("gardes") or ModelesTripo.ancien_impose(g):
		return false
	return not OS.get_cmdline_user_args().has("--gardes-armures-tripo")

static func _lire() -> void:
	if not _roles.is_empty():
		return
	var d := GardesVillage.donnees()
	_ensembles = d.get("ensembles", {})
	_roles = d.get("roles", {})

static func ensembles() -> Dictionary:
	_lire()
	return _ensembles

static func roles() -> Dictionary:
	_lire()
	return _roles

## Rôle d'un garde : « role » de ses données, sinon déduit de l'ancien corps Tripo (lancier, épée, archer, verre, armure dorée).
static func role_de(g: Dictionary) -> String:
	if g.has("role"):
		return String(g["role"])
	if g.get("armure_verre", false):
		return "elite"
	if g.get("armure_tripo", false):
		return "chef"
	match String(g.get("tripo", "")):
		"tripo_garde_lance":
			return "lancier"
		"tripo_archer":
			return "archer"
	return "epee"

## Pièces portées {emplacement: id} : ensemble du rôle (ou « ensemble »), puis « pieces », « sans_casque ».
static func pieces_de(g: Dictionary) -> Dictionary:
	var r: Dictionary = roles().get(role_de(g), {})
	var nom := String(g.get("ensemble", r.get("ensemble", "acier")))
	var p: Dictionary = (ensembles().get(nom, {}) as Dictionary).duplicate()
	for e: String in (g.get("pieces", {}) as Dictionary):
		p[e] = String(g["pieces"][e])
	if g.get("sans_casque", false):
		p["tete"] = ""
	for e: String in p.keys():
		if String(p[e]) == "":
			p.erase(e)
	return p

static func arme_de(g: Dictionary) -> String:
	return String(g.get("arme", (roles().get(role_de(g), {}) as Dictionary).get("arme", "epee")))

static func bouclier_de(g: Dictionary) -> String:
	if g.has("bouclier"):
		return String(g["bouclier"])
	var r: Dictionary = roles().get(role_de(g), {})
	if r.has("bouclier"):
		return String(r["bouclier"])
	if arme_de(g) == "arc":
		return ""
	return "dos" if String(g.get("type", "poste")) == "ronde" else "bras"

## Ids portés par un modèle de garde (butin), [] si ce n'est pas un garde en armure maison.
static func pieces_portees(modele: Node) -> Array:
	if modele == null or not modele.has_meta(META):
		return []
	return (modele.get_meta(META) as Dictionary).values()

# ======================================================================================================== fabrique
## Libère les Gardiens de référence (les copies gardent maillages, peaux et matières partagés).
static func liberer_bases() -> void:
	for b: Node in _bases.values():
		if is_instance_valid(b):
			b.free()
	_bases.clear()

static func creer(g: Dictionary) -> Node3D:
	var arme := arme_de(g)
	var bouclier := bouclier_de(g)
	var cle := "%s|%s" % [arme, bouclier]
	if not _bases.has(cle) or not is_instance_valid(_bases[cle]):
		_bases[cle] = _base(arme, bouclier)
	var n := (_bases[cle] as Node3D).duplicate() as Node3D
	n.name = "GardeMaison"
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	GardesVillage.varier(n, g)
	if arme != "lance":
		# clips d'épée / d'arc d'Humain (le Gardien a les clips à la lance : bras relevé sur une hampe)
		var ap := n.get_node("Animations") as AnimationPlayer
		ap.stop()
		ap.remove_animation_library("")
		ap.add_animation_library("", Humain.bibliotheque())
	match arme:
		"epee":
			_epee(sq, n.get_node("Animations"))
		"arc":
			ChasseresseNordique.equiper_arc(n, sq)
	var pieces := pieces_de(g)
	var eq := EquipementCorps.new()
	for e: String in pieces:
		if eq.emplacements.has(e) and ArmureVisible.a_modele(String(pieces[e])):
			eq.emplacements[e] = String(pieces[e])
	ArmureVisible.equiper(n, sq, eq, null)
	var portees := {}
	for e: String in eq.emplacements:
		if String(eq.emplacements[e]) != "":
			portees[e] = String(eq.emplacements[e])
	n.set_meta(META, portees)
	n.set_meta("garde_maison", role_de(g))
	var h := clampf(float(g.get("taille", 1.0)), 0.9, 1.1)
	var l := clampf(float(g.get("largeur", 1.0)), 0.92, 1.08)
	n.scale = Vector3(h * l, h, h * l)
	return n

## Gardien de référence d'une combinaison : lance et bouclier sortis des accessoires (maillage « armes_garde »).
static func _base(arme: String, bouclier: String) -> Node3D:
	var b := GardienNordique.creer({"bouclier": bouclier, "lance": arme == "lance"}).duplicate() as Node3D
	var sq := b.find_child("Skeleton3D", true, false) as Skeleton3D
	var acc := sq.get_node_or_null("accessoires") as MeshInstance3D
	if acc != null:
		_separer_armes(sq, acc)
	return b

## Triangles de la lance (rigides sur hand_r, le long de la hampe) et du bouclier (rigides sur son os, dans son disque) -> « armes_garde ».
static func _separer_armes(sq: Skeleton3D, acc: MeshInstance3D) -> void:
	var lance: Array = sq.get_meta("lance", [])
	var bouc: Array = sq.get_meta("bouclier", [])
	if lance.is_empty() and bouc.is_empty():
		return
	var src := acc.mesh
	var reste := ArrayMesh.new()
	var armes := ArrayMesh.new()
	var mat_armes: Material = null
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for i in v.size():
				idx[i] = i
		var nb := bo.size() / maxi(v.size(), 1)
		var garde := PackedInt32Array()
		var pris := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var tri := [idx[t], idx[t + 1], idx[t + 2]]
			var c := (v[tri[0]] + v[tri[1]] + v[tri[2]]) / 3.0
			var arme := false
			if s == 0:
				if not lance.is_empty() and _rigide(bo, w, nb, tri, int(lance[0])):
					var loc: Vector3 = (lance[1] as Transform3D).affine_inverse() * c
					arme = Vector2(loc.x, loc.z).length() < 0.07 and loc.y > -float(lance[2]) - 0.15 and loc.y < 1.5
				if not arme and not bouc.is_empty() and _rigide(bo, w, nb, tri, int(bouc[0])):
					var lb: Vector3 = (bouc[1] as Transform3D).affine_inverse() * c
					arme = Vector2(lb.x, lb.y).length() < 0.46 and absf(lb.z) < 0.14
			if arme:
				pris.append_array(tri)
				continue
			garde.append_array(tri)
		var a1 := a.duplicate()
		a1[Mesh.ARRAY_INDEX] = garde if not garde.is_empty() else PackedInt32Array([0, 0, 0])
		reste.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a1)
		reste.surface_set_material(s, src.surface_get_material(s))
		if not pris.is_empty():
			var a2 := a.duplicate()
			a2[Mesh.ARRAY_INDEX] = pris
			armes.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			mat_armes = acc.get_surface_override_material(s)
	var mats := []
	for s in src.get_surface_count():
		mats.append(acc.get_surface_override_material(s))
	acc.mesh = reste
	for s in mats.size():
		acc.set_surface_override_material(s, mats[s])
	if armes.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.name = "armes_garde"
		mi.mesh = armes
		mi.skin = acc.skin
		sq.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.set_surface_override_material(0, mat_armes)
		mi.extra_cull_margin = acc.extra_cull_margin
		mi.owner = acc.owner

static func _rigide(bo: PackedInt32Array, w: PackedFloat32Array, nb: int, tri: Array, os_: int) -> bool:
	for i: int in tri:
		if bo[i * nb] != os_ or w[i * nb] < 0.99:
			return false
	return true

## Épée du jeu au poing droit (prise du héros), mêmes matières que l'épée des gardes Tripo. Hors des clips d'épée, le poignet fléchit
## (GardeTripo.PoignetRepos) : la lame descend le long de la jambe au lieu de pointer derrière le garde.
static func _epee(sq: Skeleton3D, ap: AnimationPlayer) -> void:
	var pr := GardeTripo.PoignetRepos.new()
	pr.name = "PoignetRepos"
	pr.os_main = sq.find_bone("hand_r")
	pr.anim = ap
	sq.add_child(pr)
	var acc := BoneAttachment3D.new()
	acc.name = "EpeeMain"
	acc.bone_name = "hand_r"
	sq.add_child(acc)
	var arme: Node3D = EPEE.instantiate()
	arme.name = "EpeeJeu"
	arme.transform = PRISE_EPEE
	acc.add_child(arme)
	GardeTripo._matieres_epee(arme)
