class_name FacadeTertre
## Lot 5, 2e passe : façade du tertre en pierre taillée irrégulière (au lieu de quatre boîtes) : deux pierres levées
## effilées, linteau en bloc chanfreiné chargé de neige, jambages et assises de pierre autour de la porte, seuil
## de dalles, dalle de porte enfoncée. Les COLLISIONS sont celles d'origine (mêmes boîtes) : seul l'habillage change.

static func _mesh(parent: Node3D, m: BatiGeo.Maillage, pos: Vector3, mat: Material, lacet := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m.mesh()
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, lacet), pos)
	parent.add_child(mi)

static func _collision(corps: StaticBody3D, taille: Vector3, pos: Vector3) -> void:
	var bs := BoxShape3D.new()
	bs.size = taille
	var cs := CollisionShape3D.new()
	cs.shape = bs
	corps.add_child(cs)
	cs.transform = Transform3D(Basis(), pos)

static func construire(parent: Node3D, corps: StaticBody3D, m_facade: Material, m_dalle: Material) -> void:
	# deux pierres levées de part et d'autre de la porte (collision d'origine : 0,8 × 3,0 × 0,8)
	for x in [-1.3, 1.3]:
		_mesh(parent, BatiGeo.pierre_levee(Vector3(0.8, 3.0, 0.8), 910 + int(x * 10.0)), Vector3(x, 1.3, -0.4), m_facade, 0.2 * signf(x))
		_collision(corps, Vector3(0.8, 3.0, 0.8), Vector3(x, 1.3, -0.4))
		# assises de pierre qui calent le pied et jambage extérieur
		for i in 2:
			_mesh(parent, BatiGeo.bloc(Vector3(1.0 - i * 0.18, 0.4, 0.95), 920 + i + int(x * 4.0), 0.2, 0.08, 0.3), Vector3(x * (1.0 + 0.04 * i) + signf(x) * 0.12, -0.05 + i * 0.36, -0.35), m_facade, 0.1 * i * signf(x))
	# linteau : grosse dalle posée sur les deux pierres (collision d'origine : 3,6 × 0,7 × 1,0)
	_mesh(parent, BatiGeo.bloc(Vector3(3.7, 0.72, 1.05), 931, 0.12, 0.03, 1.0, 0.8), Vector3(0, 3.0, -0.4), m_facade)
	_collision(corps, Vector3(3.6, 0.7, 1.0), Vector3(0, 3.0, -0.4))
	# cales de pierre entre linteau et piliers
	for x in [-1.75, 1.75]:
		_mesh(parent, BatiGeo.bloc(Vector3(0.5, 0.36, 0.7), 940 + int(x * 3.0), 0.2, 0.08, 0.5), Vector3(x, 2.62, -0.4), m_facade)
	# dalle de porte enfoncée (collision d'origine : 1,9 × 2,6 × 0,2)
	_mesh(parent, BatiGeo.bloc(Vector3(1.9, 2.6, 0.2), 950, 0.06, 0.02, 0.0, 0.8), Vector3(0, 1.2, -0.75), m_dalle)
	_collision(corps, Vector3(1.9, 2.6, 0.2), Vector3(0, 1.2, -0.75))
	# seuil : trois dalles posées (visuel seul : 8 cm de haut, la montée reste franchissable)
	for k in 3:
		_mesh(parent, BatiGeo.bloc(Vector3(0.95, 0.1, 0.8), 960 + k, 0.25, 0.08, 0.4), Vector3(-0.95 + k * 0.95, 0.0, 0.25), m_facade, 0.06 * (k - 1))
