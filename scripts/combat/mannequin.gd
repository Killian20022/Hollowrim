extends StaticBody3D
## Mannequin d'entraînement (scène de test du combat) : poteau, traverse et corps de paille. Il encaisse tous les coups
## sans mourir, vacille (ressort), lâche un peu de paille et affiche les dégâts au point touché (chiffre qui monte).
## Interface des ennemis : recevoir_coup(degats, origine, puissant, info = {}) -> "touche", vivant(), point_impact() ;
## extension noter_impact(point, direction) (DegatsCombat). Groupe « cibles_combat » (reconnu par TraceLame) ;
## pas dans « ennemis » pour ne pas être compté par l'IA, la musique ou les salles.

signal touche(degats: float, puissant: bool)

var nom_affiche := "Mannequin"
var vie := 999.0
var vie_max := 999.0
## Journal des coups reçus : {degats, puissant, temps (ms), point, info (contrat DegatsCombat)}.
var coups: Array[Dictionary] = []
var total := 0.0
var _point := Vector3.ZERO
var _corps: Node3D
var _angle := Vector2.ZERO
var _vangle := Vector2.ZERO

func _ready() -> void:
	add_to_group("cibles_combat")
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	add_child(forme)
	_corps = Node3D.new()
	add_child(_corps)
	var bois := _mat(Palette.tex("planches", Palette.PLANCHES, 4, 0.5), Vector2(1, 3))
	var paille := _mat(Palette.tex("foin", Palette.FOIN, 4, 0.6), Vector2(2, 2))
	var corde := _mat(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2.ONE)
	_cylindre(Vector3(0, 0.75, 0), 0.05, 1.5, bois)                 # poteau
	_boite(Vector3(0, 1.38, 0), Vector3(0.95, 0.07, 0.07), bois)     # traverse (bras)
	_cylindre(Vector3(0, 1.08, 0), 0.24, 0.62, paille)               # torse de paille
	_cylindre(Vector3(0, 1.38, 0), 0.25, 0.06, corde)                # liens
	_cylindre(Vector3(0, 0.85, 0), 0.25, 0.06, corde)
	_cylindre(Vector3(0, 1.62, 0), 0.13, 0.26, paille)               # tête
	_boite(Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.5), bois)       # socle

func _mat(t: Texture2D, uv: Vector2) -> ShaderMaterial:
	return Palette.materiau(t, uv)

func _cylindre(p: Vector3, r: float, h: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = p
	_corps.add_child(mi)

func _boite(p: Vector3, s: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = s
	mi.mesh = b
	mi.material_override = m
	mi.position = p
	_corps.add_child(mi)

func vivant() -> bool:
	return true

func point_impact() -> Vector3:
	return global_position + Vector3(0, 1.1, 0)

func noter_impact(point: Vector3, direction: Vector3) -> void:
	_point = point
	var local := global_transform.basis.inverse() * direction
	_vangle += Vector2(local.z, -local.x) * 2.5

func recevoir_coup(degats: float, origine: Vector3, puissant: bool, info: Dictionary = {}) -> String:
	var p: Vector3 = info.get("point", _point if _point != Vector3.ZERO else point_impact())
	_point = Vector3.ZERO
	coups.append({"degats": degats, "puissant": puissant, "temps": Time.get_ticks_msec(), "point": p, "info": info})
	total += degats
	var vers := global_position - origine
	vers.y = 0.0
	var local := global_transform.basis.inverse() * vers.normalized()
	_vangle += Vector2(-local.z, local.x) * (3.5 if puissant else 1.8)
	Effets.eclats(self, p, Color(0.62, 0.52, 0.26), 14 if puissant else 8, 2.5)
	Sons.jouer_a(self, ["impactWood_heavy_000", "chop"], p, 0.0 if puissant else -3.0)
	_chiffre(p, degats, puissant)
	touche.emit(degats, puissant)
	return "touche"

## Chiffre de dégâts pixel qui monte et s'efface.
func _chiffre(p: Vector3, degats: float, puissant: bool) -> void:
	var l := Label3D.new()
	l.text = str(roundi(degats))
	l.font = Palette.police()
	l.font_size = 32 if puissant else 22
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.modulate = Color(1.0, 0.55, 0.2) if puissant else Color(1.0, 0.92, 0.6)
	l.outline_size = 6
	l.outline_modulate = Color(0.08, 0.04, 0.02)
	var scene := get_tree().current_scene
	(scene if scene else get_tree().root).add_child(l)
	l.global_position = p + Vector3(0, 0.1, 0)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 0.6, 0), 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	t.chain().tween_callback(l.queue_free)

func _physics_process(dt: float) -> void:
	# vacillement du corps : ressort amorti, pivot au socle
	_vangle += (-_angle * 90.0 - _vangle * 6.0) * dt
	_angle += _vangle * dt
	_angle = _angle.limit_length(0.35)
	_corps.rotation = Vector3(_angle.x, 0.0, _angle.y)
