class_name ArmesEnnemis
extends RefCounted
## Vraies armes des ennemis : les armes du CATALOGUE (data/armes/catalogue_armes.json : épée de soldat, hache de guerre, hachette, masse cloutée,
## gourdin, sabre de pillard, dague…) tenues dans la main droite, à la place des boîtes de fer d'avant. Données : data/armes/armes_ennemis.json
## (profil par sorte d'ennemi, tirage pondéré, usure, bornes d'équilibrage). Doc : docs/ARMES_ENNEMIS.md.
##   ArmesEnnemis.tirer(profil, ident) -> String        arme tirée à graine STABLE (même ennemi = même arme, sauvegarde comprise)
##   ArmesEnnemis.poser(sq, corps, id, arme, profil)    arme dans la main : même prise que l'épée des draugrs Tripo (EnnemiTripo.PRISE, poing mesuré,
##                                                      ArmeAplombTripo : lame jamais « en broche » au repos et en marche, rendue au clip pendant les coups)
##   ArmesEnnemis.stats_combat(id) -> Dictionary        rapports dégâts / rythme / portée par rapport à l'épée de soldat (bornés)
##   ArmesEnnemis.arme_de(modele) -> String             arme tenue (méta « arme_id » du modèle)
##   ArmesEnnemis.lacher(modele, butin) -> Node3D       à la mort : l'arme quitte la main et se pose au sol (ObjetMonde), liée au butin du corps

const FICHIER := "res://data/armes/armes_ennemis.json"
const SOL := "ArmeSol"

static var _d := {}
static var _lu := false
static var _n := 0

static func donnees() -> Dictionary:
	if not _lu:
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_d = v if v is Dictionary else {}
		_lu = true
	return _d

## Identifiant de catalogue de l'arme (ou d'un unique : « hache_kolbeinn » = modèle d'une arme du catalogue + teinte).
static func connu(id: String) -> bool:
	return CatalogueArmes.connu(id) or (donnees().get("uniques", {}) as Dictionary).has(id)

static func _de_base(id: String) -> String:
	var u: Dictionary = (donnees().get("uniques", {}) as Dictionary).get(id, {})
	return String(u.get("modele_de", id))

## Arme tirée dans `profil` (data), graine = `ident` : stable d'une partie à l'autre. Sans ident, tirage propre à l'appel (compteur).
static func tirer(profil: String, ident: String) -> String:
	var p: Dictionary = (donnees().get("profils", {}) as Dictionary).get(profil, {})
	var liste: Array = p.get("armes", [])
	if liste.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	if ident == "":
		_n += 1
		rng.seed = ("sans_ident|%s|%d" % [profil, _n]).hash()
	else:
		rng.seed = (ident + "|arme").hash()
	var total := 0.0
	for e: Dictionary in liste:
		total += float(e.get("poids", 1.0))
	var x := rng.randf() * total
	for e: Dictionary in liste:
		x -= float(e.get("poids", 1.0))
		if x < 0.0:
			return String(e["id"])
	return String(liste[liste.size() - 1]["id"])

## Le butin du corps contient-il l'arme ? (non pour les uniques : déjà posés dans le monde comme objets uniques.)
static func butin_possible(id: String) -> bool:
	var u: Dictionary = (donnees().get("uniques", {}) as Dictionary).get(id, {})
	return CatalogueArmes.connu(id) and bool(u.get("butin", true))

static func famille(id: String) -> String:
	return CatalogueArmes.famille_de(_de_base(id))

static func deux_mains(id: String) -> bool:
	var d := CatalogueArmes.donnees(_de_base(id))
	return d != null and d.deux_mains

## Longueur RÉELLE de l'arme (m), mesurée sur son modèle : de la prise au point le plus éloigné du maillage le long de l'axe du manche (prise -> pointe).
## C'est elle qui fixe la portée au corps à corps (stats_combat), pas une valeur écrite à la main.
static var _longueurs := {}
static func longueur(id: String) -> float:
	var k := _de_base(id)
	if _longueurs.has(k):
		return _longueurs[k]
	var a := instancier(k)
	var lg := 0.0
	if a != null:
		var pr := a.get_node_or_null("prise") as Node3D
		var po := a.get_node_or_null("pointe") as Node3D
		var axe := Vector3.UP
		var o := Vector3.ZERO
		if pr != null and po != null:
			o = pr.position
			axe = (po.position - pr.position).normalized()
		for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var t := mi.transform
			var n: Node = mi.get_parent()
			while n != null and n != a:
				t = (n as Node3D).transform * t
				n = n.get_parent()
			var bb := mi.mesh.get_aabb()
			for i in 8:
				lg = maxf(lg, ((t * bb.get_endpoint(i)) - o).dot(axe))
		a.free()
	_longueurs[k] = lg
	return lg

## Rapports de l'arme à la référence (épée de soldat), bornés par « equilibre » : {degats, rythme, portee (m, écart à la portée de base)}.
static func stats_combat(id: String) -> Dictionary:
	var eq: Dictionary = donnees().get("equilibre", {})
	var s := CatalogueArmes.stats(_de_base(id))
	var r := CatalogueArmes.stats(String(donnees().get("reference", "epee_soldat")))
	if s.is_empty() or r.is_empty():
		return {"degats": 1.0, "rythme": 1.0, "portee": 0.0}
	var bd: Array = eq.get("degats", [0.8, 1.35])
	var br: Array = eq.get("rythme", [0.8, 1.12])
	var bp: Array = eq.get("portee", [-0.2, 0.15])
	return {
		"degats": clampf(float(s["degats_leger"]) / float(r["degats_leger"]), float(bd[0]), float(bd[1])),
		"rythme": clampf(float(s["vitesse"]) / float(r["vitesse"]), float(br[0]), float(br[1])),
		"portee": clampf((longueur(id) - longueur(String(donnees().get("reference", "epee_soldat")))) * 0.5, float(bp[0]), float(bp[1])),
	}

## Modèle d'une arme (hors de l'arbre) : scène du catalogue habillée en matériaux PS1, teintée par l'usure du profil (ou la teinte de l'unique).
static func instancier(id: String, profil := "") -> Node3D:
	var u: Dictionary = (donnees().get("uniques", {}) as Dictionary).get(id, {})
	var a := CatalogueArmes.entree(_de_base(id))
	if a.is_empty() or not ResourceLoader.exists(String(a.get("modele", ""))):
		return null
	var n := (load(String(a["modele"])) as PackedScene).instantiate() as Node3D
	n.name = "Modele_" + id
	EpeesLongues.habiller(n)
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		g.visibility_range_end = 50.0      # inutile au loin ; le LOD automatique du maillage (import) allège déjà le reste
	var t: Array = u.get("teinte", ((donnees().get("profils", {}) as Dictionary).get(profil, {}) as Dictionary).get("usure", []))
	if t.size() == 3:
		var f := Color(float(t[0]), float(t[1]), float(t[2]))
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			EnnemisNordiques._teinter(mi, f)
	return n

## Centre du poing d'un corps qui n'a pas de maillage mesuré (bandits, chef) : repère de hand_r de l'épée qu'ils tenaient (EnnemiTripo.PRISE).
static func centre_fixe() -> Vector3:
	return EnnemiTripo.PRISE.origin + EnnemiTripo.PRISE.basis.y.normalized() * 0.03

## Arme dans la main droite de `sq` (os hand_r). `centre` : centre du poing dans le repère de hand_r (EnnemiTripo.centre_poing pour les corps Tripo).
## Le nœud « Arme » (BoneAttachment3D) a l'arme pour enfant 0 puis le nœud d'aplomb ; `ap` (AnimationPlayer) est relié par l'appelant.
static func poser(sq: Skeleton3D, centre: Vector3, id_corps: String, id: String, profil := "", axe := Vector3.ZERO) -> Node3D:
	var a := instancier(id, profil)
	if a == null:
		return null
	var acc := BoneAttachment3D.new()
	acc.name = "Arme"
	acc.bone_name = "hand_r"
	sq.add_child(acc)
	acc.add_child(a)
	var e: float = EnnemiTripo.ECH_ARME.get(id_corps, 1.0)
	var prise := a.get_node_or_null("prise") as Node3D
	var grip := prise.position.y if prise != null else 0.03
	var fam: Dictionary = (donnees().get("familles", {}) as Dictionary).get(famille(id), {})
	var u: Dictionary = (donnees().get("uniques", {}) as Dictionary).get(id, {})
	var rg: Dictionary = (donnees().get("prises", {}) as Dictionary).get(_de_base(id), {})      # réglage propre à l'arme (prime sur la famille)
	var tors := float(rg.get("torsion", u.get("torsion", fam.get("torsion", 0.0))))
	var cb: Array = rg.get("cible", u.get("cible", fam.get("cible", [])))
	var lim := float(rg.get("limite", u.get("limite", fam.get("limite", 180.0))))
	# Base de l'arme : orientation historique (PRISE incliné de INCL), puis rotation minimale qui amène l'axe du manche sur la ligne des
	# articulations MESURÉE du poing (axe non nul) : le manche traverse le poing fermé au lieu de longer l'avant-bras.
	var base := Basis(Vector3.RIGHT, deg_to_rad(EnnemiTripo.INCL)) * EnnemiTripo.PRISE.basis
	if axe.length() > 0.5:
		base = Basis(Quaternion(base.y.normalized(), axe.normalized())) * base
	var bs := base * Basis(Vector3.UP, deg_to_rad(tors))
	bs = bs.scaled(Vector3.ONE * e)
	a.transform = Transform3D(bs, centre - bs.y.normalized() * grip * e)
	var ar: Node = preload("res://scripts/arme_aplomb_tripo.gd").new()
	ar.name = "Aplomb"
	ar.set("sq", sq)
	ar.set("arme", a)
	ar.set("base", base)
	ar.set("centre", centre)
	ar.set("ech", e)
	ar.set("grip", grip)
	ar.set("incl", 0.0)
	ar.set("torsion", tors)
	ar.set("limite", lim)
	if cb.size() == 3:
		ar.set("cible", Vector3(float(cb[0]), float(cb[1]), float(cb[2])))
	if axe.length() > 0.5:
		ar.set("doigts", centre.normalized())
	ar.set("os", sq.find_bone("hand_r"))
	acc.add_child(ar)
	return a

static func arme_de(modele: Node) -> String:
	return String(modele.get_meta("arme_id", "")) if modele != null else ""

## Retire l'arme de la main (dépouille, mort) ; renvoie le nœud « Arme » retiré (à libérer) ou null.
static func retirer(modele: Node) -> Node:
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var acc := sq.get_node_or_null("Arme") if sq != null else null
	if acc != null:
		acc.get_parent().remove_child(acc)
	return acc

## Arme posée sur le sol pour le corps `butin` (Butin) : l'objet du catalogue couché (ObjetMonde), en `local` (repère du butin).
## Le visuel porte le nom « ArmeSol » et disparaît quand l'arme n'est plus dans le corps (Butin._apres_fouille).
static func poser_au_sol(butin: Node3D, id: String, local: Vector3, lacet := 0.0) -> Node3D:
	var v := ObjetMonde.visuel(_de_base(id), "sol", absi(id.hash()))
	v.name = SOL
	butin.add_child(v)
	v.position = local
	v.rotate_y(lacet)
	butin.set_meta("arme_sol", id)
	return v

## Sol sous `p` (rayon vers le bas, calque 1 : terrain et décors) : {"pos", "normale"} ; `p` et le haut si rien.
static func sol_sous(ref: Node3D, p: Vector3) -> Dictionary:
	var espace := ref.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.2, 0), p - Vector3(0, 3.0, 0), 1)
	var r := espace.intersect_ray(q)
	if r.is_empty():
		return {"pos": p, "normale": Vector3.UP}
	return {"pos": r["position"], "normale": r["normal"]}

## Mort de `modele` (Draugr) : l'arme quitte la main, tombe et se pose sur le sol près de la main (couchée, à plat sur la pente) ; elle est aussi
## dans le butin du corps (`butin.contenu`, posé par l'appelant) : la même arme du catalogue se ramasse en fouillant le corps.
static func lacher(modele: Node3D, butin: Node3D, id: String) -> Node3D:
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var main := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin if sq != null else butin.global_position
	var acc := retirer(modele)
	if acc != null:
		acc.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = (id + "|chute").hash()
	var cible := main + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
	var sol := sol_sous(butin, cible)
	var v := poser_au_sol(butin, id, butin.to_local(main), rng.randf() * TAU)
	var n: Vector3 = sol["normale"]
	if n.y < 0.999 and n.y > 0.5:
		v.global_basis = Basis(Quaternion(Vector3.UP, n)) * v.global_basis      # couchée à plat sur la pente
	var t := v.create_tween()
	t.tween_property(v, "position", butin.to_local(sol["pos"]) + Vector3(0, 0.01, 0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return v

## Dépouille statique / corps restauré : le modèle perd son arme (elle est au sol, dans le butin) ; si l'arme est encore dans `butin.contenu`,
## elle est posée près du corps (côté de la main droite), sinon rien au sol.
static func deposer_depouille(modele: Node3D, butin: Node3D) -> void:
	var id := arme_de(modele)
	if id == "":
		return
	var acc := retirer(modele)
	if acc != null:
		acc.queue_free()
	if butin.contenu.has(id) and butin_possible(id) and butin.get_node_or_null(SOL) == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = (id + "|chute").hash()
		var v := poser_au_sol(butin, id, modele.basis * Vector3(0.55, 0.0, 0.1) + modele.position, rng.randf() * TAU)
		v.position.y = 0.01
