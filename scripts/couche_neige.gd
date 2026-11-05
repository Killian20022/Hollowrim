class_name CoucheNeige
extends MeshInstance3D
## COUCHE DE NEIGE DÉFORMABLE : grille de 12 m de côté en tuiles de 2 m (seules les tuiles touchées par du relief sont dessinées), cases de 1/16 m (un sommet au centre de chaque texel du masque
## d'EffetsSol), posée à la hauteur EXACTE du maillage du terrain. Le vertex shader (variante « couche » de ps1.gdshader)
## l'enfonce de la profondeur lue dans le masque (empreintes de bottes, trou du feu) et la relève en bourrelet sur le pourtour ;
## le fragment shader recalcule la normale depuis la pente de la profondeur (parois ombrées, rebord éclairé).
## Le terrain n'est pas troué (un `discard` dans son shader coûtait ×1,9 de GPU dehors) : la couche est dessinée par-dessus, et la
## profondeur de ses sommets creusés est ramenée au niveau du sol (vertex shader), donc le creux passe devant le sol sans rien
## cacher de ce qui est devant.
## La grille ne bouge que par cases entières (EffetsSol la recentre sur le joueur) : rien ne glisse. Au repos : invisible, coût nul.

const COTE := 192                   # cases par côté (12 m)
const TUILE := 32                   # cases par côté d'une tuile (2 m) : 6 × 6 tuiles
const RES := 16.0
const DEMI := COTE / 2              # texels : coin de la grille = centre du joueur − 6 m, multiple de 1/16 m

static var _maillage: ArrayMesh
static var _tex_hauteurs: ImageTexture

## Crée la couche sous `monde` (monde.gd : `mat_terrain`, `hauteurs_maillage`). Null si le terrain n'est pas prêt.
static func creer(monde: Node) -> CoucheNeige:
	var mat: Variant = monde.get("mat_terrain")
	var hs: Variant = monde.get("hauteurs_maillage")
	if not (mat is ShaderMaterial) or not (hs is PackedFloat64Array) or (hs as PackedFloat64Array).is_empty():
		return null
	var n := int(sqrt(float((hs as PackedFloat64Array).size())))
	if n != 121:
		return null   # le shader suppose 120 cases de 2 m
	if _tex_hauteurs == null:
		var f := PackedFloat32Array()
		f.resize(n * n)
		for i in n * n:
			f[i] = hs[i]
		_tex_hauteurs = ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RF, f.to_byte_array()))
	var c := CoucheNeige.new()
	c.name = "CoucheNeige"
	var m: ShaderMaterial = (mat as ShaderMaterial).duplicate()
	m.shader = Palette.shader_couche()
	m.set_shader_parameter("relief_hauteurs", _tex_hauteurs)
	m.set_shader_parameter("grille", 0.0)   # pas d'accroche d'écran : des cases de 6 cm n'y survivraient pas
	var nt := COTE / TUILE
	for j in nt:
		for i in nt:
			var tuile := MeshInstance3D.new()
			tuile.mesh = _grille()
			tuile.material_override = m
			tuile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tuile.position = Vector3(i * TUILE / RES, 0.0, j * TUILE / RES)
			c.add_child(tuile)
	c.visible = false
	monde.add_child.call_deferred(c)   # le monde peut être encore en train de poser ses enfants
	return c

static func _grille() -> ArrayMesh:
	if _maillage != null:
		return _maillage
	var v := PackedVector3Array()
	var nv := TUILE + 1
	v.resize(nv * nv)
	for j in nv:
		for i in nv:
			v[j * nv + i] = Vector3((i + 0.5) / RES, 0.0, (j + 0.5) / RES)   # centre de texel
	var idx := PackedInt32Array()
	idx.resize(TUILE * TUILE * 6)
	var k := 0
	for j in TUILE:
		for i in TUILE:
			var a := j * nv + i
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + nv      # mêmes triangles que le terrain : a-b-c / b-d-c
			idx[k + 3] = a + 1; idx[k + 4] = a + nv + 1; idx[k + 5] = a + nv
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = idx
	_maillage = ArrayMesh.new()
	_maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_maillage.custom_aabb = AABB(Vector3(0, -6, 0), Vector3(TUILE / RES, 12, TUILE / RES))
	return _maillage

## Place la grille : coin = centre − 6 m, aligné sur la grille des texels. Renvoie (x0, z0) en m.
func placer(centre: Vector2) -> Vector2:
	var tx := floori(centre.x * RES) - DEMI
	var tz := floori(centre.y * RES) - DEMI
	var p := Vector2(tx / RES, tz / RES)
	global_position = Vector3(p.x, 0.0, p.y)
	return p

## Ne dessine que les tuiles qui touchent la boîte englobante du relief (x0, z0, x1, z1 en m, marge d'un texel comprise).
func filtrer(boite: Vector4) -> void:
	var o := global_position
	var cote := TUILE / RES
	for t in get_children():
		var q: Vector3 = (t as Node3D).position
		(t as Node3D).visible = o.x + q.x < boite.z + 0.1 and o.x + q.x + cote > boite.x - 0.1 and o.z + q.z < boite.w + 0.1 and o.z + q.z + cote > boite.y - 0.1
