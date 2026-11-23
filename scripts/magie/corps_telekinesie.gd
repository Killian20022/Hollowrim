class_name CorpsTelekinesie
extends RigidBody3D
## PROP PHYSIQUE SAISISSABLE (tonneau, chaise, tabouret, seau…) pour les TESTS et la DÉMO de la télékinésie : un prop Quaternius texturé
## (PropsQuat) dans un corps rigide du groupe `telekinesable`, avec la collision du catalogue. C'est un REPLI : rendre les meubles
## du monde physiques, saisissables et cassables est le travail de la branche « cassables partout » (Cassable.recevoir_choc) ;
## ce corps n'est posé que par outils/test_telekinesie.gd et la scène de démo (scenes/test_telekinesie.tscn).

## Masses (kg) par défaut des props de démo.
const MASSES := {"pq_tonneau": 28.0, "pq_tonneau_2": 28.0, "pq_chaise": 7.0, "pq_chaise_2": 7.0, "pq_tabouret": 4.0, "pq_seau_bois": 3.0,
	"pq_caisse": 18.0, "pq_vase_2": 3.5, "pq_banc": 22.0}

var prop := ""

## Pose le prop `id` sous `parent` à `xf` (pied au sol) ; `masse` < 0 : table MASSES.
static func creer(id: String, parent: Node3D, xf: Transform3D, masse := -1.0) -> CorpsTelekinesie:
	var c := CorpsTelekinesie.new()
	c.prop = id
	c.name = "Tk_" + id
	c.mass = masse if masse > 0.0 else float(MASSES.get(id, 8.0))
	var mi := PropsQuat.instancier(id, "interieur")
	var aabb := mi.mesh.get_aabb() if mi != null and mi.mesh != null else AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.8, 0.6))
	var centre := aabb.get_center()
	if mi != null:
		mi.position = -centre      # origine du corps au centre de la boîte (comme ObjetVivant)
		c.add_child(mi)
	var cs := CollisionShape3D.new()
	var infos: Dictionary = PropsQuat.infos(id).get("collision", {})
	if String(infos.get("type", "")) == "cylindre":
		var cy := CylinderShape3D.new()
		cy.radius = float(infos["rayon"])
		cy.height = float(infos["hauteur"])
		cs.shape = cy
	else:
		var b := BoxShape3D.new()
		b.size = aabb.size * 0.96
		cs.shape = b
	c.add_child(cs)
	parent.add_child(c)
	c.global_transform = xf * Transform3D(Basis(), centre)
	return c

func _init() -> void:
	collision_layer = Cassable.CALQUE | 1
	collision_mask = 1 | Cassable.CALQUE
	continuous_cd = true
	can_sleep = true
	angular_damp = 1.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.08
	physics_material_override = pm
	add_to_group(Telekinesie.GROUPE)

func masse_telekinesie() -> float:
	return mass
