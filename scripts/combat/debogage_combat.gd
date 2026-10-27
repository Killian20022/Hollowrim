extends Node3D
## Débogage du combat (F3 ou --debug-combat), dessiné en coordonnées monde (top_level), par-dessus tout :
##   - trajectoire de la pointe (1,5 s) colorée par phase : gris préparation, violet charge, ROUGE fenêtre active (la lame
##     blesse), orange fenêtre active trop lente pour blesser (TraceLame.VITESSE_MIN), bleu récupération, vert garde ;
##   - nappe balayée du dernier coup : rayons œil → lame aux échantillons (cyan) et sous-instants fins (bleu sombre) ;
##   - points de contact (croix rouges) ; segment tranchant courant (jaune) ;
##   - formes de collision (hitboxes) des ennemis et cibles à moins de 8 m (vert, rouge si touchées par le coup) ;
##   - texte : état, geste, fenêtre active (s), vitesse de la lame, rayons / requêtes de volume, cibles touchées.

var mains: Node3D
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _texte := Label.new()
var _calque := CanvasLayer.new()
## Trajectoire de la pointe : [position monde, couleur], la plus ancienne d'abord.
var _trajet: Array = []
const DUREE_TRAJET := 1.5
var _horloge := 0.0
var _formes := {}   # Shape3D -> PackedVector3Array (lignes de get_debug_mesh)

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
	var fen: Array = mains._geste.get("fenetre", [0.0, 1.0]) if not mains._geste.is_empty() else [0.0, 1.0]
	var actif_d: float = mains._duree_prep + mains._duree_tenue + float(fen[0]) * mains._duree_active
	var actif_f: float = mains._duree_prep + mains._duree_tenue + float(fen[1]) * mains._duree_active
	_texte.text = "État : %s (%s)   geste : %s%s\nEndurance : %d / %d   charge : %d %%   combo : %d\nFenêtre active : %.3f-%.3f s   lame %s°/s (blesse ≥ %d)\nRayons : %d   volumes : %d   cibles touchées : %d%s" % [
		mains.combat.nom(), ["REPOS", "ARMER", "CHARGE", "FRAPPE", "RETOUR", "GARDE", "ENCAISSE"][mains.etat],
		mains._geste_nom, " (lourd)" if mains._lourd else "",
		int(j.vigueur), int(j.vigueur_max), int(mains._charge * 100.0), mains._combo,
		actif_d, actif_f, "—" if is_inf(tr.vitesse) else str(roundi(tr.vitesse)), int(TraceLame.VITESSE_MIN),
		tr.rayons, tr.requetes, tr.nb_cibles, "   LAME ARRÊTÉE" if tr.arretee else ""]
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var n := 0
	for s in tr.debug_segments:
		_mesh.surface_set_color(Color(0.15, 0.3, 0.7) if s.size() > 2 and int(s[2]) == 1 else Color(0.3, 0.85, 1.0))
		_mesh.surface_add_vertex(s[0])
		_mesh.surface_add_vertex(s[1])
		n += 1
	n += _dessiner_trajet(_dt)
	n += _dessiner_formes(tr)
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

## Couleur de la phase en cours (trajectoire de la pointe).
func _couleur_phase() -> Color:
	var c: EtatCombat = mains.combat
	match c.etat:
		EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CONTRE:
			if not mains._actif_lance:
				return Color(0.6, 0.6, 0.6)
			return Color(1.0, 0.1, 0.05) if mains.trace.vitesse >= TraceLame.VITESSE_MIN else Color(1.0, 0.55, 0.1)
		EtatCombat.FINISHER:
			return Color(1.0, 0.1, 0.05)
		EtatCombat.CHARGE_LOURDE:
			return Color(0.7, 0.3, 1.0)
		EtatCombat.RECUPERATION:
			return Color(0.3, 0.5, 1.0)
		EtatCombat.GARDE, EtatCombat.PARADE:
			return Color(0.2, 1.0, 0.3)
	return Color(0.85, 0.85, 0.85, 0.5)

func _dessiner_trajet(dt: float) -> int:
	_horloge += dt
	var t := _horloge
	var pointe: Vector3 = mains.pivot_epee.global_transform * mains._pointe_lame
	_trajet.append([pointe, _couleur_phase(), t])
	while not _trajet.is_empty() and t - float(_trajet[0][2]) > DUREE_TRAJET:
		_trajet.pop_front()
	var n := 0
	for i in range(1, _trajet.size()):
		_mesh.surface_set_color(_trajet[i][1])
		_mesh.surface_add_vertex(_trajet[i - 1][0])
		_mesh.surface_add_vertex(_trajet[i][0])
		n += 1
	return n

## Formes de collision des cibles proches (8 m) : lignes de Shape3D.get_debug_mesh, rouges si touchées par ce coup.
func _dessiner_formes(tr: TraceLame) -> int:
	var n := 0
	var j: Node3D = mains.joueur
	for groupe in ["ennemis", "cibles_combat"]:
		for c in get_tree().get_nodes_in_group(groupe):
			if not (c is Node3D) or (c as Node3D).global_position.distance_to(j.global_position) > 8.0:
				continue
			var couleur := Color(1.0, 0.2, 0.2) if tr.touches.has(c.get_instance_id()) else Color(0.4, 1.0, 0.4)
			for cs in c.find_children("*", "CollisionShape3D", true, false):
				var forme: Shape3D = (cs as CollisionShape3D).shape
				if forme == null or (cs as CollisionShape3D).disabled:
					continue
				if not _formes.has(forme):
					_formes[forme] = _lignes(forme)
				var xf: Transform3D = (cs as Node3D).global_transform
				var l: PackedVector3Array = _formes[forme]
				for k in range(0, l.size() - 1, 2):
					_mesh.surface_set_color(couleur)
					_mesh.surface_add_vertex(xf * l[k])
					_mesh.surface_add_vertex(xf * l[k + 1])
					n += 1
	return n

static func _lignes(forme: Shape3D) -> PackedVector3Array:
	var res := PackedVector3Array()
	var m := forme.get_debug_mesh()
	if m == null or m.get_surface_count() == 0:
		return res
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx = a[Mesh.ARRAY_INDEX]
	if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
		for i in idx:
			res.append(v[i])
	else:
		res = v
	return res
