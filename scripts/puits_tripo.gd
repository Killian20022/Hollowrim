class_name PuitsTripo
## ESSAI Tripo (branche essai/puits) : le puits de la place du village (mobilier_village.gd, module « puits ») devient le modèle Tripo
## allégé (assets/essai_tripo/puits.glb : margelle, 4 poteaux, treuil à manivelle, toit de bardeaux ; texture cuite 256 px, shader ps1)
## prolongé d'un VRAI conduit qui descend de 5 m : cylindre de moellons construit ici (aucune ressource en plus), assombri vers le bas
## par la couleur de sommet, avec la corde et le seau (puits_seau.glb) pendus dans le conduit au-dessus d'un disque d'eau noir et
## IMMOBILE (aucun effet sur l'eau). Le terrain n'est pas troué : le shader du conduit ramène les sommets sous le sol sur le plan du sol
## pour la profondeur seule (shaders/puits_conduit.gdshader, même astuce que le creux de neige de ps1.gdshader).
## `-- --sans-tripo` ou `--puits-ancien` rend le puits d'avant (kitbash Quaternius).
static var actif := not (OS.get_cmdline_user_args().has("--sans-tripo") or OS.get_cmdline_user_args().has("--puits-ancien"))
const MODELE := "res://assets/essai_tripo/puits.glb"
const MODELE_SEAU := "res://assets/essai_tripo/puits_seau.glb"
const TEXTURE := "res://assets/essai_tripo/puits_tex.png"
const SHADER := preload("res://shaders/puits_conduit.gdshader")

const R_INT := 0.62          # rayon intérieur de la margelle (m) : le conduit prolonge exactement la paroi
const Y_HAUT := 0.81         # haut du conduit (m au-dessus du sol) : niveau où se trouvait l'eau du modèle, 4 cm sous la margelle
const PROFONDEUR := 5.0      # m sous le sol jusqu'à l'eau
const FACES := 14
const R_EXT := 1.03          # rayon extérieur de la margelle (collision)
const H_COLLISION := 1.6     # plus haut que le saut : on ne monte pas sur la margelle (et on ne marche donc pas au-dessus du trou)

## Pose le puits : `xf` = repère du module (pied au sol, lacet), `sol_y_monde` = hauteur monde du terrain sous le puits.
static func poser(parent: Node3D, corps: StaticBody3D, xf: Transform3D, sol_y_monde: float, num: int) -> int:
	var racine := Node3D.new()
	racine.name = "PuitsTripo"
	racine.transform = xf
	parent.add_child(racine)
	var tris := 0
	if ResourceLoader.exists(MODELE):
		var n := (load(MODELE) as PackedScene).instantiate() as Node3D
		n.name = "Margelle"
		MaisonTripo.ps1(n, Color(1.35, 1.35, 1.35), false)
		racine.add_child(n)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = 90.0
			tris += _tris(mi.mesh)
	# le conduit est calé sur le terrain (le modèle est posé au plus bas de son emprise, enfoncé de 3 cm)
	var dy := clampf(sol_y_monde - parent.to_global(xf.origin).y, 0.0, 0.05)
	var mat := _materiau_conduit(TexturesBati.tex("pierre_fine"), sol_y_monde, Color(1.25, 1.25, 1.25))
	var cond := _conduit(mat)
	cond[0].position.y = dy
	racine.add_child(cond[0])
	tris += cond[1]
	if ResourceLoader.exists(MODELE_SEAU) and ResourceLoader.exists(TEXTURE):
		var s := (load(MODELE_SEAU) as PackedScene).instantiate() as Node3D
		s.name = "SeauEtCorde"
		var mat_seau := _materiau_conduit(load(TEXTURE) as Texture2D, sol_y_monde, Color(1.35, 1.35, 1.35))
		for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				mi.set_surface_override_material(k, mat_seau)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tris += _tris(mi.mesh)
		s.position.y = dy
		racine.add_child(s)
	var forme := CollisionShape3D.new()
	forme.set_meta("objet", "puits#%d" % num)
	var cy := CylinderShape3D.new()
	cy.radius = R_EXT
	cy.height = H_COLLISION
	forme.shape = cy
	forme.transform = xf * Transform3D(Basis(), Vector3(0, H_COLLISION * 0.5, 0))
	corps.add_child(forme)
	return tris

static func _materiau_conduit(tex: Texture2D, sol_y_monde: float, teinte: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("sol_y", sol_y_monde)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.suivre(m)
	return m

static func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		if a[Mesh.ARRAY_INDEX] != null:
			t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		else:
			t += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t

## Dégradé de couleur de sommet : clair en haut (à peine plus sombre que la margelle), presque noir au fond.
static func _ombre(y: float) -> float:
	if y >= 0.0:
		return 1.0 - (Y_HAUT - y) / Y_HAUT * 0.3
	var prof := clampf(-y / PROFONDEUR, 0.0, 1.0)
	return pow(1.0 - prof, 1.7) * 0.7 + 0.03

## Conduit : [MeshInstance3D, triangles]. Parois vers l'intérieur, rayon irrégulier d'un anneau à l'autre (pierres), un anneau pile
## au niveau du sol (chaque triangle est tout au-dessus ou tout au-dessous : voir le shader), eau noire immobile au fond.
static func _conduit(mat: ShaderMaterial) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5517
	var ys: Array[float] = [Y_HAUT, Y_HAUT * 0.5, 0.0]
	var n_bas := 11
	for i in range(1, n_bas + 1):
		ys.append(-PROFONDEUR * float(i) / n_bas + (rng.randf_range(-0.05, 0.05) if i < n_bas else 0.0))
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var base_r: Array[float] = []
	for k in FACES:
		base_r.append(rng.randf_range(0.0, 0.03))
	for i in ys.size():
		var y: float = ys[i]
		var o := _ombre(y)
		for k in FACES + 1:
			var kk := k % FACES
			var a := TAU * float(kk) / FACES
			var r := R_INT
			if i >= 3:
				r -= base_r[kk] + (rng.randf_range(0.0, 0.02) if k < FACES else 0.0)
			if k == FACES:
				r = Vector2(v[i * (FACES + 1)].x, v[i * (FACES + 1)].z).length()
			v.append(Vector3(sin(a) * r, y, cos(a) * r))
			uv.append(Vector2(float(k) / FACES * 2.0, -y * 0.5))     # une tuile de pierre = 2 m de paroi
			col.append(Color(o, o * 0.97, o * 0.95, 1.0))
	for i in ys.size() - 1:
		for k in FACES:
			var a0 := i * (FACES + 1) + k
			var a1 := a0 + FACES + 1
			# face visible de l'intérieur du puits (sens horaire vu de l'axe) : le shader cull_back écarte la paroi proche
			idx.append_array([a0, a1, a0 + 1, a0 + 1, a1, a1 + 1])
	# disque d'eau au fond : noir bleuté, immobile, à peine plus clair au centre
	var fond := ys[ys.size() - 1]
	var i0 := v.size()
	var centre_col := Color(0.20, 0.27, 0.34)
	v.append(Vector3(0, fond, 0)); uv.append(Vector2(0.5, 0.5)); col.append(centre_col * 0.16)
	for k in FACES:
		var a := TAU * float(k) / FACES
		v.append(Vector3(sin(a) * (R_INT - 0.03), fond, cos(a) * (R_INT - 0.03)))
		uv.append(Vector2(0.5 + sin(a) * 0.5, 0.5 + cos(a) * 0.5))
		col.append(Color(0.02, 0.03, 0.04))
	for k in FACES:
		idx.append_array([i0, i0 + 1 + (k + 1) % FACES, i0 + 1 + k])
	var ar := []
	ar.resize(Mesh.ARRAY_MAX)
	ar[Mesh.ARRAY_VERTEX] = v
	ar[Mesh.ARRAY_TEX_UV] = uv
	ar[Mesh.ARRAY_COLOR] = col
	ar[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar)
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Conduit"
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-R_INT, -PROFONDEUR - 0.2, -R_INT), Vector3(R_INT * 2.0, PROFONDEUR + Y_HAUT + 0.4, R_INT * 2.0))
	return [mi, idx.size() / 3]
