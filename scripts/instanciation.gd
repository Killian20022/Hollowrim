class_name Instanciation
## Point unique de création des MultiMesh (arbres, genévriers, rochers…).
## Lot A : les instances sont regroupées par cellules de CELLULE m (grille alignée sur l'origine
## du monde), un MultiMeshInstance3D par (mesh, cellule), avec une portée de visibilité : les
## cellules hors champ ou trop lointaines ne coûtent plus rien au GPU.

## Côté d'une cellule, en mètres.
const CELLULE := 20.0

## Crée les MultiMeshInstance3D d'un mesh sous `parent` et les renvoie.
## Réglages :
##   "ombre"        bool, vrai par défaut : le mesh projette des ombres.
##   "portee"       float, 0 = illimitée : distance au-delà de laquelle la cellule disparaît.
##   "marge"        float, 10 par défaut : hystérésis de la portée (pas de fondu).
##   "ombre_proche" float, 0 = ombres sur toute la portée : si > 0, l'affichage lointain est sans
##                  ombre et un second MMI « ombre seule » ne couvre que cette distance (méta "lod").
##   "lod_mesh"     Mesh simplifié affiché de "lod_debut" (85 m) à "lod_portee" (250 m), sans ombre :
##                  garde l'horizon boisé quand le mesh complet est coupé à "portee" (méta "lod").
static func repartir(parent: Node, mesh: Mesh, transforms: Array, reglages := {}) -> Array:
	var portee: float = reglages.get("portee", 0.0)
	var marge: float = reglages.get("marge", 10.0)
	var ombre_proche: float = reglages.get("ombre_proche", 0.0)
	var ombre: bool = reglages.get("ombre", true)
	# regroupement par cellule (l'ordre d'insertion reste celui des transforms)
	var cellules := {}
	for t: Transform3D in transforms:
		var cle := Vector2i(floori(t.origin.x / CELLULE), floori(t.origin.z / CELLULE))
		if not cellules.has(cle):
			cellules[cle] = []
		cellules[cle].append(t)
	var lod_mesh: Mesh = reglages.get("lod_mesh", null)
	var resultat: Array = []
	for cle: Vector2i in cellules:
		var liste: Array = cellules[cle]
		# nœud au centre de la cellule, transforms exprimés en local
		var centre := Vector3((cle.x + 0.5) * CELLULE, 0.0, (cle.y + 0.5) * CELLULE)
		var separe := ombre and portee > 0.0 and ombre_proche > 0.0
		var principal := _creer(mesh, liste, centre)
		if not ombre or separe:
			principal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_portee(principal, portee, marge)
		parent.add_child(principal)
		resultat.append(principal)
		if separe:
			var ombres := _creer(mesh, liste, centre)
			ombres.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			ombres.set_meta("lod", "ombre")
			_portee(ombres, minf(ombre_proche, portee), marge)
			parent.add_child(ombres)
			resultat.append(ombres)
		if lod_mesh != null and portee > 0.0:
			var loin := _creer(lod_mesh, liste, centre)
			loin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			loin.set_meta("lod", "loin")
			_portee(loin, reglages.get("lod_portee", 250.0), marge)
			loin.visibility_range_begin = reglages.get("lod_debut", 85.0)
			loin.visibility_range_begin_margin = marge
			parent.add_child(loin)
			resultat.append(loin)
	return resultat

static func _creer(mesh: Mesh, liste: Array, centre: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = liste.size()
	for k in liste.size():
		var t: Transform3D = liste[k]
		t.origin -= centre
		mm.set_instance_transform(k, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = centre
	return mmi

static func _portee(mmi: MultiMeshInstance3D, portee: float, marge: float) -> void:
	if portee <= 0.0:
		return
	mmi.visibility_range_end = portee
	mmi.visibility_range_end_margin = marge
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
