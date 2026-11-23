class_name ArmeTelekinesie
extends RigidBody3D
## ARME SAISIE PAR LA TÉLÉKINÉSIE (scripts/magie/telekinesie.gd) : une arme posée dans le monde (ObjetMonde d'une arme, arme lâchée
## par un ennemi mort : visuel « ArmeSol » d'un Butin, meta « tk_arme ») devient ce corps rigide au moment de la saisie.
##   - repère : +Y le long de la lame (vers la pointe), origine au milieu de l'arme ; collision : boîte fine de la lame ;
##   - le visuel est celui d'ObjetMonde (pose « ratelier » : pommeau en bas, pointe en haut), recentré ;
##   - la source disparaît (l'objet quitte le butin du corps : pas de double) ; au repos après un lancer, l'arme reste un corps
##     posé là (gelé), RAMASSABLE (« Prendre », touche E) et de nouveau saisissable (groupe `telekinesable`).
## Contrat (docs/MAGIE.md, « Télékinésie ») : donnees_arme(), masse_telekinesie(), saisi_telekinesie(saisi).

var id := ""
var joueur: CharacterBody3D
var dialogue: Control
var longueur := 1.0
var _arme: DonneesArme
var _inter: Node3D

static func donnees_de(oid: String) -> DonneesArme:
	for i in [oid, _base(oid)]:
		if CatalogueArmes.connu(i):
			return CatalogueArmes.donnees(i)
	return ObjetMonde._arme(oid)

## Change le visuel posé `v` (meta « tk_arme ») en corps rigide au même endroit ; la source est retirée.
static func depuis_visuel(v: Node3D) -> ArmeTelekinesie:
	if v == null or not is_instance_valid(v) or not v.is_inside_tree():
		return null
	var oid := String(v.get_meta("tk_arme", ""))
	if oid == "":
		return null
	var b := Telekinesie._boite_locale(v)
	var c := v.global_transform * b.get_center()
	var axe_l := Vector3.RIGHT
	var t := b.size
	if t.y >= t.x and t.y >= t.z:
		axe_l = Vector3.UP
	elif t.z >= t.x:
		axe_l = Vector3.BACK
	var dir := (v.global_basis * axe_l).normalized()
	var a := ArmeTelekinesie.new()
	a.id = oid
	a.name = "ArmeTk_" + oid
	a._arme = donnees_de(oid)
	# qui ramassera : le joueur et la boîte de dialogue de la source (ObjetMonde : son invite ; Butin : ses champs)
	var src: Node = v
	var butin: Node = v.get_parent() if v.get_parent() != null and v.get_parent().has_meta("arme_sol") else null
	if v is ObjetMonde:
		var it = v.get("_inter")
		if it != null and is_instance_valid(it):
			a.joueur = it.get("joueur")
			a.dialogue = it.get("dialogue")
	elif butin != null:
		a.joueur = butin.get("joueur")
		a.dialogue = butin.get("dialogue")
	var monde: Node = v.get_tree().current_scene
	if monde == null:
		monde = v.get_tree().root
	monde.add_child(a)
	var y := dir
	var x := y.cross(Vector3.UP)
	if x.length() < 0.1:
		x = Vector3.RIGHT
	x = x.normalized()
	a.global_transform = Transform3D(Basis(x, y, x.cross(y).normalized()), c)
	a._monter()
	# la source s'efface : arme sortie du butin du corps (elle ne se ramasse plus deux fois)
	if butin != null:
		var contenu = butin.get("contenu")
		if contenu is Dictionary and (contenu as Dictionary).has(oid):
			var n := int(contenu[oid]) - 1
			if n <= 0:
				(contenu as Dictionary).erase(oid)
			else:
				contenu[oid] = n
		butin.remove_meta("arme_sol")
	src.queue_free()
	return a

func _init() -> void:
	collision_layer = Cassable.CALQUE
	collision_mask = 1 | Cassable.CALQUE
	continuous_cd = true
	linear_damp = 0.05
	angular_damp = 1.0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.1
	physics_material_override = pm
	add_to_group(Telekinesie.GROUPE)

func _monter() -> void:
	var vis := ObjetMonde.visuel(_base(id), "ratelier")
	vis.name = "Visuel"
	add_child(vis)
	var b := Telekinesie._boite_locale(vis)
	longueur = maxf(b.size.y, 0.3)
	vis.position = Vector3(-b.get_center().x, -b.get_center().y, -b.get_center().z)
	mass = clampf(_arme.poids if _arme != null else Telekinesie.MASSE_ARME, 0.4, 12.0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(clampf(b.size.x, 0.05, 0.3), longueur * 0.96, clampf(b.size.z, 0.04, 0.2))
	cs.shape = bs
	add_child(cs)
	set_meta("tk_rayon", longueur * 0.5)

static func _base(oid: String) -> String:
	return ArmesEnnemis._de_base(oid)

func donnees_arme() -> DonneesArme:
	return _arme

func masse_telekinesie() -> float:
	return mass

func saisi_telekinesie(saisi: bool) -> void:
	if saisi:
		freeze = false
		if _inter != null and is_instance_valid(_inter):
			_inter.queue_free()
		_inter = null

## Fin du vol (Telekinesie._fin_suivi) : posée là, gelée, ramassable.
func au_repos_telekinesie() -> void:
	if freeze:
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	if joueur == null or dialogue == null or not is_instance_valid(joueur) or not is_instance_valid(dialogue):
		return
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = String(Inventaire.objet(id).get("nom", id))
	it.verbe = "Prendre"
	it.rayon = 1.8
	it.unique = true
	it.action = func() -> Array:
		ButinTables.prendre(joueur.inventaire, [{"id": id, "n": 1, "rarete": ButinTables.rarete_de(id)}])
		queue_free()
		return []
	add_child(it)
	it.global_position = global_position + Vector3.UP * 0.1
	_inter = it
