class_name PuitsTripo
## ESSAI Tripo (branche essai/puits) : le puits de la place du village (mobilier_village.gd, module « puits ») devient le modèle Tripo
## allégé (assets/essai_tripo/puits.glb : margelle, 4 poteaux, treuil à manivelle, toit de bardeaux ; texture cuite 256 px, shader ps1)
## prolongé d'un VRAI conduit qui descend de 5 m : cylindre de moellons construit ici (aucune ressource en plus), assombri vers le bas
## par la couleur de sommet, avec la corde et le seau (construits ici, rigides) pendus dans le conduit au-dessus d'un disque d'eau noir et
## IMMOBILE (aucun effet sur l'eau). Le terrain n'est pas troué : le shader du conduit ramène les sommets sous le sol sur le plan du sol
## pour la profondeur seule (shaders/puits_conduit.gdshader, même astuce que le creux de neige de ps1.gdshader).
## `-- --sans-tripo` ou `--puits-ancien` rend le puits d'avant (kitbash Quaternius).
static var actif := not (OS.get_cmdline_user_args().has("--sans-tripo") or OS.get_cmdline_user_args().has("--puits-ancien"))
const MODELE := "res://assets/essai_tripo/puits.glb"
const TEXTURE := "res://assets/essai_tripo/puits_tex.png"
const SHADER := preload("res://shaders/puits_conduit.gdshader")

const R_INT := 0.62          # rayon intérieur de la margelle (m) : le conduit prolonge exactement la paroi
const Y_HAUT := 0.81         # haut du conduit (m au-dessus du sol) : niveau où se trouvait l'eau du modèle, 4 cm sous la margelle
const ECHELLE := 1.25        # le puits est agrandi (margelle ~1 m, emprise proche de l'ancien puits)
const PROFONDEUR := 4.6      # m (avant échelle) sous le sol jusqu'à l'eau : ~5,75 m réels
const FACES := 14
const R_EXT := 1.03          # rayon extérieur de la margelle (collision)
const H_COLLISION := 1.6     # plus haut que le saut : on ne monte pas sur la margelle (et on ne marche donc pas au-dessus du trou)

## Pose le puits : `xf` = repère du module (pied au sol, lacet), `sol_y_monde` = hauteur monde du terrain sous le puits.
static func poser(parent: Node3D, corps: StaticBody3D, xf: Transform3D, sol_y_monde: float, num: int) -> int:
	var racine := Node3D.new()
	racine.name = "PuitsTripo"
	racine.transform = xf.scaled_local(Vector3.ONE * ECHELLE)
	parent.add_child(racine)
	var tris := 0
	if ResourceLoader.exists(MODELE):
		var n := (load(MODELE) as PackedScene).instantiate() as Node3D
		n.name = "Margelle"
		MaisonTripo.ps1(n, Color(1.35, 1.35, 1.35), true)     # double face : aucune pièce fine (bardeau, poteau) ne laisse de trou
		racine.add_child(n)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = 90.0
			tris += _tris(mi.mesh)
	# le conduit est calé sur le terrain (le modèle est posé au plus bas de son emprise, enfoncé de 3 cm)
	var dy := clampf(sol_y_monde - parent.to_global(xf.origin).y, 0.0, 0.05)
	var mat := _materiau_conduit(TexturesBati.tex("pierre_brute"), sol_y_monde, Color(0.62, 0.7, 0.7))
	var cond := _conduit(mat)
	cond[0].position.y = dy
	racine.add_child(cond[0])
	tris += cond[1]
	if ResourceLoader.exists(TEXTURE):
		tris += _seau_et_corde(racine, dy, sol_y_monde)
	var forme := CollisionShape3D.new()
	forme.set_meta("objet", "puits#%d" % num)
	var cy := CylinderShape3D.new()
	cy.radius = R_EXT * ECHELLE
	cy.height = H_COLLISION * ECHELLE
	forme.shape = cy
	forme.transform = xf * Transform3D(Basis(), Vector3(0, H_COLLISION * ECHELLE * 0.5, 0))
	corps.add_child(forme)
	return tris

const SEAU_H := 0.24         # unités du modèle (x ECHELLE = 30 cm réels)
const SEAU_R := 0.112        # rayon haut (x ECHELLE = diamètre 28 cm)
const SEAU_HAUT_Y := -0.6    # haut du seau (unités du modèle, sol = 0)
const CORDE_HAUT_Y := 1.48   # point d'attache de la corde sur le treuil

## Seau rigide + corde, deux meshes SANS lien l'un avec l'autre : seule la corde a une longueur (cylindre fin), le seau est un solide
## d'échelle 1 (ancien défaut : seau et corde étaient un seul maillage déformé d'un bloc, ce qui étirait le seau sur 3,8 m).
static func _seau_et_corde(racine: Node3D, dy: float, sol_y_monde: float) -> int:
	var n := Node3D.new()
	n.name = "SeauEtCorde"
	n.position.y = dy
	racine.add_child(n)
	var tris := 0
	var m_bois := _materiau_conduit(_tex_unie([Color(0.42, 0.28, 0.16), Color(0.34, 0.22, 0.12)], [Color(0.2, 0.2, 0.22)]), sol_y_monde, Color(1.35, 1.35, 1.35))
	var m_fer := _materiau_conduit(_tex_unie([Color(0.18, 0.18, 0.2)], []), sol_y_monde, Color(1.35, 1.35, 1.35))
	var m_corde := _materiau_conduit(_tex_unie([Color(0.62, 0.5, 0.3), Color(0.5, 0.4, 0.24)], []), sol_y_monde, Color(1.35, 1.35, 1.35))
	for mt: ShaderMaterial in [m_bois, m_fer, m_corde]:
		mt.set_shader_parameter("devant", 0.02)
	# seau : tronc de cône, douves + deux cerclages (texture), dessus plein (l'eau/le vide vu d'en haut)
	var seau := MeshInstance3D.new()
	seau.name = "Seau"
	var cm := CylinderMesh.new()
	cm.top_radius = SEAU_R
	cm.bottom_radius = SEAU_R * 0.86
	cm.height = SEAU_H
	cm.radial_segments = 12
	cm.rings = 1
	# les positions sont cuites DANS les mesh : l'origine de chaque nœud reste celle du puits (le shader s'en sert pour la profondeur)
	seau.mesh = _cuire(cm, Transform3D(Basis(), Vector3(0, SEAU_HAUT_Y - SEAU_H * 0.5, 0)))
	seau.material_override = m_bois
	# anse : anneau vertical ancré aux bords du seau
	var anse := MeshInstance3D.new()
	anse.name = "Anse"
	var tm := TorusMesh.new()
	tm.outer_radius = SEAU_R * 1.0
	tm.inner_radius = SEAU_R * 0.9
	tm.rings = 12
	tm.ring_segments = 4
	anse.mesh = _cuire(tm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, SEAU_HAUT_Y + 0.02, 0)))
	anse.material_override = m_fer
	var haut_anse := SEAU_HAUT_Y + 0.02 + SEAU_R
	for mi in [seau, anse]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
		tris += _tris(mi.mesh)
	# corde : cylindre fin du treuil à l'anse ; c'est la SEULE pièce dont la longueur change
	var corde := MeshInstance3D.new()
	corde.name = "Corde"
	corde.material_override = m_corde
	corde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(corde)
	regler_corde(corde, haut_anse)
	tris += _tris(corde.mesh)
	return tris

## Longueur de la corde : on ne refait que le mesh de la corde (cylindre fin), jamais le seau (aucune échelle ni lien de poids).
static func regler_corde(corde: MeshInstance3D, y_bas: float) -> void:
	var cc := CylinderMesh.new()
	cc.top_radius = 0.022
	cc.bottom_radius = 0.022
	cc.radial_segments = 5
	cc.rings = 1
	cc.cap_top = false
	cc.cap_bottom = false
	cc.height = CORDE_HAUT_Y - y_bas
	corde.mesh = _cuire(cc, Transform3D(Basis(), Vector3(0, y_bas + cc.height * 0.5, 0)))

## Cuit une transformation dans les sommets d'un mesh primitif.
static func _cuire(m: Mesh, xf: Transform3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.append_from(m, 0, xf)
	return st.commit()

## Petite texture à bandes verticales (douves) ; `cerclages` : couleurs des bandes horizontales en haut et en bas.
static func _tex_unie(douves: Array, cerclages: Array) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for x in 8:
		var c: Color = douves[x % douves.size()]
		for y in 8:
			img.set_pixel(x, y, c)
	if not cerclages.is_empty():
		for x in 8:
			for y in [1, 6]:
				img.set_pixel(x, y, cerclages[0])
	return ImageTexture.create_from_image(img)

static func _materiau_conduit(tex: Texture2D, sol_y_monde: float, teinte: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("sol_y", sol_y_monde)
	m.set_shader_parameter("haut", Y_HAUT * ECHELLE)
	m.set_shader_parameter("rayon", (R_INT + 0.02) * ECHELLE)
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
	return 1.0     # le dégradé vers le noir est calculé par fragment dans le shader (profondeur sous la margelle)

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
			uv.append(Vector2(float(k) / FACES * 1.5, -y * 0.4))     # grosses pierres : une tuile = 2,5 m de paroi
			col.append(Color(o, o * 0.97, o * 0.95, 1.0) * (0.85 + 0.15 * float((i + k) % 2)))
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
