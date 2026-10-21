class_name AbordsTumulus
## Abords du tumulus (lot F, zone témoin seulement) : dalles qui guident vers la porte, borne runique
## à la sortie nord du cercle, arbres morts sur les flancs, rochers et pierres de bordure au pied de la butte.
## RNG propre `ZoneBiome.graine("composition")` + 2 ; aucun tirage sur `monde.rng`.
## Les disques occupés (borne, arbres) sont déclarés dans `ZoneBiome.OCCUPATIONS`.

const BUTTE := Vector2(-38.0, -54.5)         # centre de la butte (rayon visible ≈ 7,4 m)
const BORNE := Vector2(-32.2, -42.6)         # à l'est du sentier, à la sortie nord du cercle
const ARBRES := [Vector2(-45.5, -58.5), Vector2(-30.5, -58.5)]
const ROCHERS := [[9.0, 0.1], [9.0, 2.9], [9.0, 4.3], [9.0, 5.0]]  # [rayon, angle] autour de BUTTE
const NB_BORDURE := 10
const PORTE_ANGLE := PI * 0.5                 # la porte est au sud de la butte (z croissant)

static func creer(monde: Node) -> void:
	if not ZoneBiome.actif or monde.tertre == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine("composition") + 2
	var racine := Node3D.new()
	racine.name = "AbordsTumulus"
	monde.add_child(racine)
	var corps := StaticBody3D.new()
	racine.add_child(corps)
	var m_roche := TexturesPetites.m_roche_e()   # roche feuilletée, 64 texels/m
	var m_roche_haute := m_roche
	_dalles(monde, racine, m_roche, rng)
	_borne(monde, racine, corps, m_roche_haute)
	_arbres(monde, racine, corps, rng)
	_rochers(monde, racine, m_roche, rng)
	_bordure(monde, racine, m_roche, rng)

## 5 dalles sur les 4 derniers mètres du sentier, en remontant depuis la porte.
static func _dalles(monde: Node, racine: Node3D, m: Material, rng: RandomNumberGenerator) -> void:
	var pts: PackedVector2Array = monde.chemins.points
	var fin := pts.size() - 1
	for k in 5:
		var s := 0.5 + k * 0.85  # abscisse depuis la porte
		var i := fin
		var reste := s
		while i > 0 and reste > pts[i].distance_to(pts[i - 1]):
			reste -= pts[i].distance_to(pts[i - 1])
			i -= 1
		var tang := (pts[i] - pts[maxi(i - 1, 0)]).normalized()
		var p: Vector2 = pts[i] - tang * reste
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9, 0.12, 0.7)
		mi.mesh = b
		mi.material_override = m
		var lacet := atan2(-tang.y, tang.x) + PI * 0.5 + rng.randf_range(-0.12, 0.12)  # côté large en travers du sentier
		mi.transform = Transform3D(Basis(Vector3.UP, lacet), Vector3(p.x + rng.randf_range(-0.08, 0.08), monde.hauteur(p.x, p.y), p.y))  # enfoncée de 6 cm
		racine.add_child(mi)

## Borne runique basse (1,4 m), runes émissives comme la stèle, sans lumière.
static func _borne(monde: Node, racine: Node3D, corps: StaticBody3D, m: Material) -> void:
	var taille := Vector3(0.55, 1.4, 0.45)
	var mi := MeshInstance3D.new()
	mi.mesh = CercleRunique.boite_neige(taille, 400)
	mi.material_override = m
	mi.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5).rotated(Vector3.BACK, 0.04), Vector3(BORNE.x, monde.hauteur(BORNE.x, BORNE.y) + taille.y * 0.5 - 0.15, BORNE.y))
	racine.add_child(mi)
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.8)
	var mr := CercleRunique.materiau_runes()
	for cote in [1.0, -1.0]:
		var r := MeshInstance3D.new()
		r.mesh = q
		r.material_override = mr
		r.position = Vector3(0, 0.0, 0.232 * cote)
		mi.add_child(r)
	var forme := CollisionShape3D.new()
	var bf := BoxShape3D.new()
	bf.size = taille
	forme.shape = bf
	forme.transform = mi.transform
	corps.add_child(forme)

## Deux arbres morts sur les flancs de la butte (collision mince).
static func _arbres(monde: Node, racine: Node3D, corps: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var rng_tex := RandomNumberGenerator.new()
	rng_tex.seed = ZoneBiome.graine("composition") + 3
	var m_tronc := Palette.materiau(monde.tex_roche, Vector2(1, 2), Color(0.95, 0.92, 0.88))
	var m_neige := TexturesBati.m_neige_toit_e()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = 4.0
	for k in ARBRES.size():
		var p: Vector2 = ARBRES[k]
		var s := rng.randf_range(1.0, 1.25)
		var h: float = monde.hauteur(p.x, p.y)
		var mi := MeshInstance3D.new()
		mi.mesh = Arbres.arbre_mort(20 + k, [m_tronc, null, m_neige])
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, h - 0.15, p.y))
		racine.add_child(mi)
		var forme := CollisionShape3D.new()
		forme.shape = cyl
		forme.position = Vector3(p.x, h + 1.8, p.y)
		corps.add_child(forme)

## Rochers bas au pied de la butte (sans collision).
static func _rochers(monde: Node, racine: Node3D, m: Material, rng: RandomNumberGenerator) -> void:
	for k in ROCHERS.size():
		var p := BUTTE + Vector2(cos(ROCHERS[k][1]), sin(ROCHERS[k][1])) * float(ROCHERS[k][0])
		var s := rng.randf_range(0.8, 1.3)
		var mesh := Rochers.rocher_mesh(70 + k)
		mesh.surface_set_material(0, m)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.45, s * rng.randf_range(0.8, 1.2))), Vector3(p.x, monde.hauteur(p.x, p.y) - s * 0.1, p.y))
		racine.add_child(mi)

## Pierres de bordure basses autour de la butte, avec un vide devant la porte (sans collision).
static func _bordure(monde: Node, racine: Node3D, m: Material, rng: RandomNumberGenerator) -> void:
	for k in NB_BORDURE:
		var a := TAU * k / NB_BORDURE + rng.randf_range(-0.12, 0.12)
		if absf(angle_difference(a, PORTE_ANGLE)) < 0.75:
			continue  # on ne barre pas l'accès à la porte
		var p := BUTTE + Vector2(cos(a), sin(a)) * rng.randf_range(8.0, 8.6)
		var taille := Vector3(rng.randf_range(0.55, 0.85), rng.randf_range(0.3, 0.45), rng.randf_range(0.4, 0.55))
		var mi := MeshInstance3D.new()
		mi.mesh = CercleRunique.boite_neige(taille, 500 + k, 0.12)
		mi.material_override = m
		mi.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.3, 0.3)).rotated(Vector3.BACK, rng.randf_range(-0.12, 0.12)), Vector3(p.x, monde.hauteur(p.x, p.y) + taille.y * 0.5 - 0.1, p.y))
		racine.add_child(mi)
