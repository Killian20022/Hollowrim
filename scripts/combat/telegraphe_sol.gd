extends RefCounted
## Repère au sol d'un geste annoncé des ennemis courants (draugr.gd) : même construction que le disque du troll
## (EnnemiBase._disque_sol : anneau net dès le départ + disque qui se remplit), mais ROUGE ORANGÉ — le bleu reste celui
## du givre (troll, mage). Rendu sans lumière, transparent. Effacé par effacer() (ou à la mort de l'ennemi).

const COULEUR := Color(1.0, 0.32, 0.22)

## Pose le repère en `centre` (monde), rayon `rayon`, qui se remplit en `duree` s. `parent` : nœud qui le porte (la scène).
static func disque(parent: Node, espace: World3D, centre: Vector3, rayon: float, duree: float, exclure: Array[RID] = []) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Telegraphe"
	parent.add_child(racine)
	racine.global_position = _sol(espace, centre, exclure) + Vector3(0, 0.05, 0)
	var anneau := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = rayon - 0.1
	t.outer_radius = rayon
	t.rings = 28
	t.ring_segments = 4
	anneau.mesh = t
	anneau.scale = Vector3(1, 0.15, 1)
	anneau.material_override = _mat(Color(COULEUR.r, COULEUR.g, COULEUR.b, 0.9))
	anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(anneau)
	var disque_mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = 0.02
	c.radial_segments = 28
	c.rings = 1
	disque_mi.mesh = c
	var md := _mat(Color(COULEUR.r, COULEUR.g, COULEUR.b, 0.14))
	disque_mi.material_override = md
	disque_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disque_mi.scale = Vector3(0.1, 1, 0.1)
	racine.add_child(disque_mi)
	var tw := racine.create_tween()
	tw.set_parallel(true)
	tw.tween_property(disque_mi, "scale", Vector3.ONE, duree)
	tw.tween_property(md, "albedo_color:a", 0.5, duree)
	return racine

## Efface le repère en fondu.
static func effacer(n: Node3D, duree := 0.25) -> void:
	if not is_instance_valid(n):
		return
	var tw := n.create_tween()
	tw.set_parallel(true)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override as StandardMaterial3D
		if m:
			tw.tween_property(m, "albedo_color:a", 0.0, duree)
	tw.chain().tween_callback(n.queue_free)

static func _sol(espace: World3D, p: Vector3, exclure: Array[RID]) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.0, 0), p - Vector3(0, 4.0, 0))
	q.exclude = exclure
	var r := espace.direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else p

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
