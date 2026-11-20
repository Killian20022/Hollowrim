class_name FusionOmbre
## Opti 2026-11-20 (persos_anim) : UNE ombre par personnage au lieu d'une par pièce.
## Un garde projetait 10 à 19 ombres (corps, cotte, cheveux, barbe, accessoires, 5 pièces d'armure, tabard, 4 pièces d'épée…), un villageois 6 à 9 :
## autant d'appels de dessin dans CHAQUE passe d'ombre. On bâtit un maillage « ombre seule » (SHADOW_CASTING_SETTING_SHADOWS_ONLY) qui réunit
## la géométrie de toutes les pièces opaques qui projetaient, skinné sur le même squelette (peau Skin réunie ; les pièces rigides d'un
## BoneAttachment3D deviennent des sommets liés à 100 % à leur os), et les pièces cessent de projeter. Même géométrie, mêmes os : même ombre.
## Pour la rendre IDENTIQUE, le maillage garde une surface par (mode de face × contour) : la coque de contour (next_pass contour_perso,
## dilatée d'1,2 px) projette aussi, on la garde en next_pass de la surface des pièces qui l'avaient. Pas d'accroche des sommets dans la passe
## d'ombre (projection orthographique, cf. ps1.gdshader) : un matériau opaque simple donne les mêmes profondeurs.
## Exclues (gardent leur propre ombre) : pièces à découpe alpha (decoupe, ALPHA), à sommets déplacés (gonfle != 0, shaders inconnus),
## à formes de mélange, pièces non skinnées hors BoneAttachment3D.
## Défait à la mort (Ragdoll.declencher, Demembrement.trancher, Decapitation.decapiter) : les pièces reprennent leur ombre.
##   FusionOmbre.equiper(modele) (AnimLod.inscrire) ; FusionOmbre.retirer(modele). --sans-opti-ombre-fusion : rien.
const NOM := "OmbreFusion"
const META := "ombre_fusion"            # sur chaque pièce : son réglage d'ombre d'origine
static var actif := not OS.get_cmdline_user_args().has("--sans-opti-ombre-fusion")
static var _mats := {}                  # "cull|contour" -> ShaderMaterial
static var _ok_shader := {}             # Shader -> peut entrer dans la fusion

static func _materiau(cull: String, contour: Material) -> ShaderMaterial:
	var cle := cull + "|" + str(contour.get_instance_id() if contour else 0)
	if not _mats.has(cle):
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, %s, specular_disabled;\nvoid fragment() { ALBEDO = vec3(0.0); }\n" % cull
		var m := ShaderMaterial.new()
		m.shader = sh
		m.next_pass = contour
		_mats[cle] = m
	return _mats[cle]

## Mode de face d'un matériau (cull_back / cull_disabled / cull_front), "" s'il ne peut pas entrer dans la fusion.
static func _cull(m: Material) -> String:
	if m == null:
		return "cull_back"
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or b.grow:
			return ""
		return ["cull_back", "cull_front", "cull_disabled"][b.cull_mode]
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var sh := sm.shader
		if sh == null:
			return ""
		if not _ok_shader.has(sh):
			_ok_shader[sh] = _analyser(sh.code)
		var r: String = _ok_shader[sh]
		if r == "":
			return ""
		var g: Variant = sm.get_shader_parameter("gonfle")
		if g != null and absf(float(g)) > 0.00001:
			return ""
		if sh.code.contains("discard"):
			var d: Variant = sm.get_shader_parameter("decoupe")
			if d == null or bool(d):
				return ""
		return r
	return ""

## Shader acceptable : spatial, aucun ALPHA, aucun déplacement de sommet autre que « VERTEX += NORMAL * gonfle » (le bloc RELIEF_COUCHE
## n'est compilé que si défini). Rend le mode de face, ou "".
static func _analyser(code: String) -> String:
	if not code.contains("shader_type spatial"):
		return ""
	var c := code
	if not c.contains("#define RELIEF_COUCHE"):
		var re_if := RegEx.create_from_string("(?s)#ifdef RELIEF_COUCHE.*?#endif")
		c = re_if.sub(c, "", true)
	c = c.replace("VERTEX += NORMAL * gonfle;", "")
	if RegEx.create_from_string("\\bALPHA\\s*=").search(c) != null:
		return ""
	if RegEx.create_from_string("\\bVERTEX(\\.[xyz]+)?\\s*[-+*/]?=[^=]").search(c) != null:
		return ""
	if RegEx.create_from_string("\\bNORMAL\\s*[-+*/]?=[^=]").search(c) != null and c.contains("void vertex"):
		pass   # normales modifiées : sans effet sur la profondeur d'ombre
	var rm := RegEx.create_from_string("render_mode([^;]*);").search(c)
	var modes := rm.get_string(1) if rm != null else ""
	if modes.contains("cull_disabled"):
		return "cull_disabled"
	if modes.contains("cull_front"):
		return "cull_front"
	return "cull_back"

static func _mat_surface(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var m := mi.get_surface_override_material(s)
	return m if m != null else mi.mesh.surface_get_material(s)

## Os porteur d'une pièce rigide (BoneAttachment3D du squelette au-dessus d'elle, sans autre squelette entre), -1 sinon.
static func _attache(mi: MeshInstance3D, sq: Skeleton3D) -> BoneAttachment3D:
	var n := mi.get_parent()
	while n != null and n != sq:
		if n is BoneAttachment3D and n.get_parent() == sq:
			return n as BoneAttachment3D
		if n is Skeleton3D:
			return null
		n = n.get_parent()
	return null

static func equiper(modele: Node3D) -> MeshInstance3D:
	if not actif or modele == null:
		return null
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null or sq.get_node_or_null(NOM) != null:
		return null
	# groupes : clé "cull|contour" -> [ [mi, surface, skin ou null, BoneAttachment3D ou null], ... ]
	var groupes := {}
	var pieces: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.has_meta(META) or mi.mesh.get_blend_shape_count() > 0:
			continue
		var ombre: int = mi.get_meta("ombre0", mi.cast_shadow)      # réglage d'origine (les niveaux de détail le coupent au loin)
		if ombre != GeometryInstance3D.SHADOW_CASTING_SETTING_ON and ombre != GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED:
			continue
		var att: BoneAttachment3D = null
		if mi.skin == null:
			att = _attache(mi, sq)
			if att == null:
				continue
		elif mi.get_node_or_null(mi.skeleton) != sq or not (sq.global_transform.affine_inverse() * mi.global_transform).is_equal_approx(Transform3D.IDENTITY):
			continue
		if mi.material_overlay != null:
			continue
		var ok := true
		var surf: Array = []
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES or (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0:
				ok = false
				break
			var m := _mat_surface(mi, s)
			var cull := _cull(m)
			if cull == "":
				ok = false
				break
			if ombre == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED:
				cull = "cull_disabled"
			var contour: Material = m.next_pass if m != null else null
			if contour != null and not (contour is ShaderMaterial and (contour as ShaderMaterial).shader == GuerrierNordique.CONTOUR):
				ok = false
				break
			surf.append([cull, contour, s])
		if not ok:
			continue
		pieces.append(mi)
		for e in surf:
			var cle := "%s|%d" % [e[0], (e[1] as Object).get_instance_id() if e[1] != null else 0]
			if not groupes.has(cle):
				groupes[cle] = {"cull": e[0], "contour": e[1], "l": []}
			groupes[cle]["l"].append([mi, e[2], mi.skin, att])
	if pieces.size() < 2:
		return null
	# peau commune : les attaches de chaque pièce mises bout à bout (indices décalés) ; une attache par pièce rigide
	var peau := Skin.new()
	var decal := {}      # mi -> premier indice d'attache
	for mi in pieces:
		decal[mi] = peau.get_bind_count()
		if mi.skin != null:
			for b in mi.skin.get_bind_count():
				var nom := mi.skin.get_bind_name(b)
				var os := mi.skin.get_bind_bone(b)
				if nom != StringName("") and os < 0:
					os = sq.find_bone(nom)
				peau.add_bind(os, mi.skin.get_bind_pose(b))
		else:
			var att := _attache(mi, sq)
			peau.add_bind(sq.find_bone(att.bone_name), att.global_transform.affine_inverse() * mi.global_transform)
	var am := ArrayMesh.new()
	for cle in groupes:
		var g: Dictionary = groupes[cle]
		var v := PackedVector3Array()
		var nrm := PackedVector3Array()
		var bo := PackedInt32Array()
		var we := PackedFloat32Array()
		var ix := PackedInt32Array()
		for e: Array in g["l"]:
			var mi: MeshInstance3D = e[0]
			var a := mi.mesh.surface_get_arrays(e[1])
			var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var base := v.size()
			var d: int = decal[mi]
			v.append_array(pv)
			if pn.size() == pv.size():
				nrm.append_array(pn)
			else:
				for k in pv.size():
					nrm.append(Vector3.UP)
			if e[2] != null:
				var pb: PackedInt32Array = a[Mesh.ARRAY_BONES]
				var pw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
				var nb := pb.size() / maxi(1, pv.size())
				for k in pv.size():
					for q in 4:
						if q < nb:
							bo.append(pb[k * nb + q] + d)
							we.append(pw[k * nb + q])
						else:
							bo.append(d)
							we.append(0.0)
			else:
				for k in pv.size():
					bo.append_array([d, d, d, d])
					we.append_array([1.0, 0.0, 0.0, 0.0])
			var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if pi.is_empty():
				for k in pv.size():
					ix.append(base + k)
			else:
				for k in pi:
					ix.append(base + k)
		if ix.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_BONES] = bo
		arr[Mesh.ARRAY_WEIGHTS] = we
		arr[Mesh.ARRAY_INDEX] = ix
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, _materiau(g["cull"], g["contour"]))
	if am.get_surface_count() == 0:
		return null
	var fm := MeshInstance3D.new()
	fm.name = NOM
	fm.mesh = am
	fm.skin = peau
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	fm.set_meta("ombre0", GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	fm.extra_cull_margin = 0.5
	sq.add_child(fm)
	fm.skeleton = fm.get_path_to(sq)
	for mi in pieces:
		mi.set_meta(META, mi.get_meta("ombre0", mi.cast_shadow))
		mi.set_meta("ombre0", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return fm

## Rend leur ombre aux pièces et supprime le maillage d'ombre (mort, démembrement, changement d'équipement).
static func retirer(modele: Node3D) -> void:
	if modele == null:
		return
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return
	var fm := sq.get_node_or_null(NOM) as MeshInstance3D
	if fm == null:
		return
	var coupe := fm.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF     # niveau de détail lointain : ombres coupées
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta(META):
			var o: int = mi.get_meta(META)
			mi.remove_meta(META)
			mi.set_meta("ombre0", o)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if coupe else o
	sq.remove_child(fm)
	fm.queue_free()
