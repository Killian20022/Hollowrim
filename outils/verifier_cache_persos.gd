extends SceneTree
## Vérifie le cache disque des corps d'archétypes (CachePersos) : pour chaque corps du chargement (PNJ du village, Gardiens des gardes,
## draugrs du cercle), bâtit le corps SANS cache puis le relit du cache, et compare tout ce qui se voit ou se lit en jeu : arbre
## (noms, classes, transformations, visibilité, propriétaires, groupes, métas), maillages (tableaux de chaque surface octet par octet,
## peau), matières (shader, chaque paramètre ; textures comparées pixel par pixel), squelette (repos et poses), animations.
##   godot --headless --path . --script res://outils/verifier_cache_persos.gd     (écrit le cache s'il manque)
## Sortie : « CACHE <corps> : identique » ou la liste des écarts ; « CACHE bilan : n écarts ». Code de sortie = nombre de corps différents.
const CORPS := {
	"guerrier_garde": ["guerrier", {"casque": true, "bouclier": "bras", "epee": true}],
	"guerrier_forgeron": ["guerrier", {"casque": false, "bouclier": "", "epee": false, "avant_bras_nus": true}],
	"guerrier_eirik": ["guerrier", {"casque": false, "bouclier": "", "epee": false}],
	"gardien_dos": ["gardien", {"bouclier": "dos", "lance": true}],
	"gardien_bras": ["gardien", {"bouclier": "bras", "lance": true}],
	"chasseresse_chef": ["chasseresse", {"arc": false, "carquois": false, "couteau": false}],
	"draugr_bras": ["draugr", {"bouclier": "bras", "epee": true, "casque": true}],
	"draugr_nu": ["draugr", {"bouclier": "", "epee": false, "casque": false}],
}
var ecarts: Array = []
func _initialize() -> void:
	_lancer.call_deferred()
func _fab(a: String, o: Dictionary) -> Node3D:
	match a:
		"guerrier": return GuerrierNordique.creer(o)
		"gardien": return GardienNordique.creer(o)
		"chasseresse": return ChasseresseNordique.creer(o)
	return DraugrNordique.creer(o)
func _lancer() -> void:
	var differents := 0
	for nom: String in CORPS:
		var a: String = CORPS[nom][0]
		var o: Dictionary = CORPS[nom][1]
		# 1) le cache s'écrit si besoin (corps bâti), 2) corps bâti sans cache, 3) corps relu
		CachePersos.actif = true
		var e0 := CachePersos.ecrits
		var t := Time.get_ticks_usec()
		var premier := _fab(a, o)
		var t_premier := (Time.get_ticks_usec() - t) / 1000.0
		CachePersos.actif = false
		t = Time.get_ticks_usec()
		var bati := _fab(a, o)
		var t_bati := (Time.get_ticks_usec() - t) / 1000.0
		CachePersos.actif = true
		var l0 := CachePersos.lus
		t = Time.get_ticks_usec()
		var lu := _fab(a, o)
		var t_lu := (Time.get_ticks_usec() - t) / 1000.0
		ecarts.clear()
		if CachePersos.lus == l0:
			ecarts.append("PAS LU DU CACHE (écrit : %d ; refus : %s)" % [CachePersos.ecrits - e0, CachePersos.refus])
		_cmp_noeud(bati, lu, bati, lu)
		print("CACHE %-18s : %s  (premier %.0f ms, bâti %.0f ms, relu %.0f ms)" % [nom, "identique" if ecarts.is_empty() else "%d ÉCARTS" % ecarts.size(), t_premier, t_bati, t_lu])
		for e in ecarts.slice(0, 25):
			print("    ", e)
		if not ecarts.is_empty():
			differents += 1
		premier.free(); bati.free(); lu.free()
	print("CACHE bilan : %d corps différents sur %d" % [differents, CORPS.size()])
	quit(differents)

## Chemin sans les numéros des noms automatiques (@BoneAttachment3D@3 : compteur global du moteur, diffère entre deux constructions).
func _sans_auto(p: NodePath) -> String:
	var r := RegEx.create_from_string("@(\\w+)@\\d+")
	return r.sub(String(p), "@$1@", true)

func _e(ch: String, quoi: String, a: Variant, b: Variant) -> void:
	ecarts.append("%s : %s (%s / %s)" % [ch, quoi, str(a).left(80), str(b).left(80)])

func _cmp_noeud(a: Node, b: Node, ra: Node, rb: Node) -> void:
	var ch := String(ra.get_path_to(a))
	if a.get_class() != b.get_class(): _e(ch, "classe", a.get_class(), b.get_class())
	if a.name != b.name and not (String(a.name).begins_with("@") and String(b.name).begins_with("@")): _e(ch, "nom", a.name, b.name)
	if (a.owner == null) != (b.owner == null) or (a.owner != null and _sans_auto(ra.get_path_to(a.owner)) != _sans_auto(rb.get_path_to(b.owner))): _e(ch, "propriétaire", a.owner, b.owner)
	if a.get_groups() != b.get_groups(): _e(ch, "groupes", a.get_groups(), b.get_groups())
	if a.get_script() != b.get_script(): _e(ch, "script", a.get_script(), b.get_script())
	if a.get_meta_list() != b.get_meta_list(): _e(ch, "métas", a.get_meta_list(), b.get_meta_list())
	else:
		for m in a.get_meta_list():
			if not _egal(a.get_meta(m), b.get_meta(m)): _e(ch, "méta " + m, a.get_meta(m), b.get_meta(m))
	if a.scene_file_path != b.scene_file_path: _e(ch, "scene_file_path", a.scene_file_path, b.scene_file_path)
	if a is Node3D:
		if not (a as Node3D).transform.is_equal_approx((b as Node3D).transform) or (a as Node3D).transform != (b as Node3D).transform: _e(ch, "transform", a.transform, b.transform)
		if a.visible != b.visible: _e(ch, "visible", a.visible, b.visible)
	if a is VisualInstance3D and (a.layers != b.layers): _e(ch, "layers", a.layers, b.layers)
	if a is GeometryInstance3D:
		for p in ["cast_shadow", "extra_cull_margin", "lod_bias", "gi_mode", "transparency", "custom_aabb", "visibility_range_end"]:
			if a.get(p) != b.get(p): _e(ch, p, a.get(p), b.get(p))
		_cmp_mat(ch + " override", a.material_override, b.material_override)
	if a is MeshInstance3D:
		_cmp_mi(ch, a, b)
	if a is Skeleton3D:
		var sa := a as Skeleton3D
		var sb := b as Skeleton3D
		if sa.get_bone_count() != sb.get_bone_count(): _e(ch, "os", sa.get_bone_count(), sb.get_bone_count())
		else:
			for i in sa.get_bone_count():
				if sa.get_bone_rest(i) != sb.get_bone_rest(i) or sa.get_bone_pose(i) != sb.get_bone_pose(i) or sa.get_bone_name(i) != sb.get_bone_name(i) or sa.get_bone_parent(i) != sb.get_bone_parent(i):
					_e(ch, "os %d" % i, sa.get_bone_pose(i), sb.get_bone_pose(i))
	if a is BoneAttachment3D and (a.bone_name != b.bone_name or a.bone_idx != b.bone_idx): _e(ch, "bone", a.bone_name, b.bone_name)
	if a is AnimationPlayer:
		var pa := a as AnimationPlayer
		var pb := b as AnimationPlayer
		if pa.get_animation_library_list() != pb.get_animation_library_list(): _e(ch, "bibliothèques", pa.get_animation_library_list(), pb.get_animation_library_list())
		elif pa.get_animation_list() != pb.get_animation_list(): _e(ch, "animations", pa.get_animation_list(), pb.get_animation_list())
		else:
			for an in pa.get_animation_list():
				var x := pa.get_animation(an)
				var y := pb.get_animation(an)
				if x != y and (x.length != y.length or x.get_track_count() != y.get_track_count() or x.loop_mode != y.loop_mode):
					_e(ch, "animation " + an, x.length, y.length)
				elif x != y:
					for k in x.get_track_count():
						if x.track_get_path(k) != y.track_get_path(k) or x.track_get_key_count(k) != y.track_get_key_count(k):
							_e(ch, "piste %s/%d" % [an, k], x.track_get_path(k), y.track_get_path(k)); break
						for kk in x.track_get_key_count(k):
							if x.track_get_key_value(k, kk) != y.track_get_key_value(k, kk):
								_e(ch, "clé %s/%d/%d" % [an, k, kk], x.track_get_key_value(k, kk), y.track_get_key_value(k, kk)); break
		for p in ["root_node", "autoplay", "playback_default_blend_time", "callback_mode_process"]:
			if pa.get(p) != pb.get(p): _e(ch, p, pa.get(p), pb.get(p))
	if a.get_script() != null:
		for p: Dictionary in a.get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not _egal(a.get(p["name"]), b.get(p["name"])):
				_e(ch, "variable " + p["name"], a.get(p["name"]), b.get(p["name"]))
	if a.get_child_count() != b.get_child_count():
		_e(ch, "enfants", a.get_child_count(), b.get_child_count())
		return
	for i in a.get_child_count():
		_cmp_noeud(a.get_child(i), b.get_child(i), ra, rb)

func _cmp_mi(ch: String, a: MeshInstance3D, b: MeshInstance3D) -> void:
	if a.skeleton != b.skeleton: _e(ch, "skeleton", a.skeleton, b.skeleton)
	if (a.skin == null) != (b.skin == null): _e(ch, "skin", a.skin, b.skin)
	elif a.skin != null:
		if a.skin.get_bind_count() != b.skin.get_bind_count(): _e(ch, "binds", a.skin.get_bind_count(), b.skin.get_bind_count())
		else:
			for i in a.skin.get_bind_count():
				if a.skin.get_bind_pose(i) != b.skin.get_bind_pose(i) or a.skin.get_bind_name(i) != b.skin.get_bind_name(i) or a.skin.get_bind_bone(i) != b.skin.get_bind_bone(i):
					_e(ch, "bind %d" % i, a.skin.get_bind_pose(i), b.skin.get_bind_pose(i)); break
	if (a.mesh == null) != (b.mesh == null):
		_e(ch, "mesh", a.mesh, b.mesh); return
	if a.mesh == null: return
	if a.mesh.get_surface_count() != b.mesh.get_surface_count():
		_e(ch, "surfaces", a.mesh.get_surface_count(), b.mesh.get_surface_count()); return
	var am := a.mesh as ArrayMesh
	var bm := b.mesh as ArrayMesh
	if am and bm and (am.get_blend_shape_count() != bm.get_blend_shape_count() or am.blend_shape_mode != bm.blend_shape_mode): _e(ch, "blend shapes", am.get_blend_shape_count(), bm.get_blend_shape_count())
	for s in a.mesh.get_surface_count():
		var xa := a.mesh.surface_get_arrays(s)
		var xb := b.mesh.surface_get_arrays(s)
		if var_to_bytes(xa) != var_to_bytes(xb): _e(ch, "tableaux surface %d" % s, xa[0].size() if xa[0] else 0, xb[0].size() if xb[0] else 0)
		if am and bm and am.surface_get_format(s) != bm.surface_get_format(s): _e(ch, "format surface %d" % s, am.surface_get_format(s), bm.surface_get_format(s))
		if am and bm and var_to_bytes(am.surface_get_blend_shape_arrays(s)) != var_to_bytes(bm.surface_get_blend_shape_arrays(s)): _e(ch, "blend surface %d" % s, 0, 0)
		_cmp_mat("%s surface %d" % [ch, s], a.mesh.surface_get_material(s), b.mesh.surface_get_material(s))
		_cmp_mat("%s surcharge %d" % [ch, s], a.get_surface_override_material(s), b.get_surface_override_material(s))
	if a.mesh.get_aabb() != b.mesh.get_aabb(): _e(ch, "aabb", a.mesh.get_aabb(), b.mesh.get_aabb())
	_cmp_mat(ch + " overlay", a.material_overlay, b.material_overlay)

func _cmp_mat(ch: String, a: Material, b: Material) -> void:
	if (a == null) != (b == null):
		_e(ch, "matière", a, b); return
	if a == null: return
	if a.get_class() != b.get_class(): _e(ch, "classe matière", a.get_class(), b.get_class()); return
	if a.render_priority != b.render_priority: _e(ch, "priorité", a.render_priority, b.render_priority)
	if a is ShaderMaterial:
		var sa := a as ShaderMaterial
		var sb := b as ShaderMaterial
		if sa.shader.code != sb.shader.code: _e(ch, "code du shader", sa.shader.resource_path, sb.shader.resource_path)
		if sa.shader != sb.shader: _e(ch, "shader non partagé", sa.shader, sb.shader)
		for u: Dictionary in sa.shader.get_shader_uniform_list():
			var va: Variant = sa.get_shader_parameter(u["name"])
			var vb: Variant = sb.get_shader_parameter(u["name"])
			if not _egal(va, vb): _e(ch, "paramètre " + u["name"], va, vb)
	else:
		for p: Dictionary in a.get_property_list():
			if p["usage"] & PROPERTY_USAGE_STORAGE and p["name"] != "resource_name" and p["name"] != "resource_path" and p["name"] != "next_pass":
				if not _egal(a.get(p["name"]), b.get(p["name"])): _e(ch, p["name"], a.get(p["name"]), b.get(p["name"]))
	_cmp_mat(ch + " >next", a.next_pass, b.next_pass)

func _egal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Texture2D and b is Texture2D:
		if a == b: return true
		var ia := (a as Texture2D).get_image()
		var ib := (b as Texture2D).get_image()
		if ia == null or ib == null: return ia == ib
		return ia.get_size() == ib.get_size() and ia.get_format() == ib.get_format() and ia.has_mipmaps() == ib.has_mipmaps() and ia.get_data() == ib.get_data()
	if a is Resource and b is Resource:
		if a == b: return true
		return var_to_bytes_with_objects(a) == var_to_bytes_with_objects(b) or a.get_class() == b.get_class()
	if a is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _egal(a[i], b[i]): return false
		return true
	return a == b
