class_name Instanciation
## Point unique de création des MultiMesh (arbres, genévriers, rochers…).
## Le lot A y ajoutera le découpage en cellules et les portées de visibilité.

## Crée les MultiMeshInstance3D d'un mesh sous `parent` et les renvoie.
## Réglages : "ombre" (bool, vrai par défaut).
static func repartir(parent: Node, mesh: Mesh, transforms: Array, reglages := {}) -> Array:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not reglages.get("ombre", true):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return [mmi]
