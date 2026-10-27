extends Node3D
## Débogage du combat (F3 ou --debug-combat) : tracé de lame du dernier coup (segments parcourus par les points de la
## lame, impacts en rouge), segment tranchant courant (jaune), et en haut à gauche : état de combat, endurance, charge,
## geste, rayons lancés, cibles touchées. Nœud enfant des mains ; le dessin est en coordonnées monde (top_level).

var mains: Node3D
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _texte := Label.new()
var _calque := CanvasLayer.new()

func _ready() -> void:
	top_level = true
	global_transform = Transform3D()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_mi.mesh = _mesh
	_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_calque.layer = 50
	add_child(_calque)
	_texte.position = Vector2(4, 30)
	_texte.add_theme_font_override("font", Palette.police())
	_texte.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE)
	_texte.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_texte.add_theme_color_override("font_outline_color", Color.BLACK)
	_texte.add_theme_constant_override("outline_size", 2)
	_calque.add_child(_texte)

## Affiche / cache le dessin et le texte (le CanvasLayer ne suit pas la visibilité du nœud 3D).
func montrer(v: bool) -> void:
	visible = v
	_calque.visible = v
	set_process(v)

func _process(_dt: float) -> void:
	if mains == null:
		return
	var j: Node = mains.joueur
	var tr: TraceLame = mains.trace
	_texte.text = "État : %s (%s)   geste : %s%s\nEndurance : %d / %d   charge : %d %%   combo : %d\nRayons : %d   cibles touchées : %d%s" % [
		mains.combat.nom(), ["REPOS", "ARMER", "CHARGE", "FRAPPE", "RETOUR", "GARDE", "ENCAISSE"][mains.etat],
		mains._geste_nom, " (lourd)" if mains._lourd else "",
		int(j.vigueur), int(j.vigueur_max), int(mains._charge * 100.0), mains._combo,
		tr.rayons, tr.nb_cibles, "   LAME ARRÊTÉE" if tr.arretee else ""]
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var n := 0
	for s in tr.debug_segments:
		_mesh.surface_set_color(Color(0.3, 0.8, 1.0))
		_mesh.surface_add_vertex(s[0])
		_mesh.surface_add_vertex(s[1])
		n += 1
	for p: Vector3 in tr.debug_impacts:
		for axe in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			_mesh.surface_set_color(Color(1.0, 0.15, 0.1))
			_mesh.surface_add_vertex(p - axe * 0.08)
			_mesh.surface_add_vertex(p + axe * 0.08)
			n += 1
	# segment tranchant courant (garde → pointe prolongée)
	var xf: Transform3D = mains.pivot_epee.global_transform
	var pts: PackedVector3Array = mains.arme.points_lame(mains._garde_lame, mains._pointe_lame)
	if pts.size() >= 2:
		_mesh.surface_set_color(Color(1.0, 0.9, 0.2))
		_mesh.surface_add_vertex(xf * pts[0])
		_mesh.surface_add_vertex(xf * pts[pts.size() - 1])
		n += 1
	if n == 0:
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()
