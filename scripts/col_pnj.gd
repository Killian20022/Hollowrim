class_name ColPnj
## [pnj/realisme_v1, passe 2] Collet des PNJ maison (laine ou cuir) : remplace l'anneau plat et pâle de la mante du Guerrier. Pèlerine
## courte posée sur les épaules : bord du cou roulé (épaisseur), pan qui descend sur les épaules avec des plis (ondulation du bord
## libre, ombre dans les creux par couleur de sommet), ourlet épais. Porté par neck_01 / spine_03 / clavicules (poids lissés), donc
## il suit le buste et les épaules sans nouvel os. Texture : laine tricotée ou cuir cousu, dans une couleur nordique sourde.

static var _tex := {}

static func batir(sq: Skeleton3D, couleur: Color, cuir: bool, femme: bool, g: int) -> MeshInstance3D:
	var cou := sq.get_bone_global_rest(sq.find_bone("neck_01")).origin
	var i_cou := sq.find_bone("neck_01")
	var i_sp := sq.find_bone("spine_03")
	var i_cl := sq.find_bone("clavicle_l")
	var i_cr := sq.find_bone("clavicle_r")
	var e := 0.92 if femme else 1.0
	var y0 := cou.y - 0.005          # bord du cou
	var c0 := Vector3(0, y0, cou.z + 0.040)
	var nt := 28
	# anneaux de profil (rayon x, rayon z, hauteur relative, épaisseur) : du col roulé à l'ourlet
	var prof := [[0.078, 0.070, 0.022], [0.090, 0.083, 0.012], [0.108, 0.098, -0.010], [0.150, 0.120, -0.045], [0.190, 0.140, -0.085], [0.205, 0.150, -0.110]]
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var bo := PackedInt32Array()
	var w := PackedFloat32Array()
	var idx := PackedInt32Array()
	var ep := 0.012 if cuir else 0.016
	var npli := 9 + g % 3
	# ajustement : chaque anneau passe au-dessus des étoffes et de la peau du cou (rayon mesuré par secteur d'angle)
	var besoin := _besoins(sq, c0, prof, nt)
	for couche in 2:          # 0 = dessus, 1 = dessous (rentré de l'épaisseur)
		for j in prof.size():
			var pr: Array = prof[j]
			var fj := float(j) / (prof.size() - 1)
			for i in nt + 1:
				var a := TAU * float(i) / nt
				var pli := sin(a * npli + float(g % 7)) * fj
				var rx := float(pr[0]) * e * (1.0 + 0.07 * pli * fj)
				var rz := float(pr[1]) * e * (1.0 + 0.07 * pli * fj)
				var dy := float(pr[2]) + 0.012 * pli * fj
				# devant : le collet descend un peu plus bas (encolure en V adoucie) ; dos : remonte sur la nuque
				dy -= 0.018 * maxf(0.0, cos(a)) * fj
				var dir := Vector3(sin(a), 0, cos(a))
				var r_e := Vector2(dir.x * rx, dir.z * rz).length()
				var r_b: float = (besoin[j] as PackedFloat32Array)[i % nt]
				var r := maxf(r_e, r_b + ep + 0.006)
				var p := c0 + Vector3(dir.x * r, dy, dir.z * r)
				var n := Vector3(dir.x, 0.9 - fj * 0.6, dir.z).normalized()
				if couche == 1:
					p -= n * ep
					n = -n
				v.append(p)
				nrm.append(n)
				uv.append(Vector2(float(i) / nt * 4.0, fj))
				var o := (0.82 + 0.18 * (pli * 0.5 + 0.5)) if couche == 0 else 0.55
				if j == 0:
					o *= 0.85
				col.append(Color(o, o, o, 1.0))
				# poids : cou en haut, buste en bas, clavicule du côté
				var wc := clampf(1.0 - fj * 2.2, 0.0, 1.0) * 0.7
				var wl := smoothstep(0.06, 0.16, p.x) * fj * 0.45
				var wr := smoothstep(0.06, 0.16, -p.x) * fj * 0.45
				var ws := 1.0 - wc - wl - wr
				bo.append_array([i_cou, i_sp, i_cl, i_cr])
				w.append_array([wc, ws, wl, wr])
		var base := couche * prof.size() * (nt + 1)
		for j in prof.size() - 1:
			for i in nt:
				var a0 := base + j * (nt + 1) + i
				var b0 := a0 + nt + 1
				if couche == 0:
					idx.append_array([a0, b0, b0 + 1, a0, b0 + 1, a0 + 1])
				else:
					idx.append_array([a0, b0 + 1, b0, a0, a0 + 1, b0 + 1])
	# ourlet et bord du cou : bandes qui joignent dessus et dessous
	var n1 := prof.size() * (nt + 1)
	for j in [0, prof.size() - 1]:
		for i in nt:
			var a0: int = j * (nt + 1) + i
			var b0: int = a0 + n1
			idx.append_array([a0, a0 + 1, b0 + 1, a0, b0 + 1, b0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_BONES] = bo
	arr[Mesh.ARRAY_WEIGHTS] = w
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "collet"
	mi.mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = GuerrierNordique.shader(true)
	mat.set_shader_parameter("tex_base", texture(couleur, cuir))
	mat.set_shader_parameter("contour_froid", Vector3(0.06, 0.07, 0.09))
	mat.set_shader_parameter("rehaut", 0.35)
	mat.next_pass = GuerrierNordique.contour()
	Palette.suivre(mat)
	Palette._appliquer(mat, Palette._ps1_actif)
	mi.material_override = mat
	sq.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = sq.create_skin_from_rest_transforms()
	return mi

## Rayon horizontal minimal par anneau et par secteur : étoffes visibles (tunique, mante, cape courte) et peau du cou à la hauteur
## de l'anneau (± 2,5 cm), lissé sur 3 secteurs.
static func _besoins(sq: Skeleton3D, c0: Vector3, prof: Array, nt: int) -> Array:
	var pts := PackedVector3Array()
	for nom in ["tunique", "mante", "cape_courte", "peau", "robe", "accessoires"]:
		var mi := sq.get_node_or_null(nom) as MeshInstance3D
		if mi == null or not mi.visible or mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]
			for q in v:
				if q.y > c0.y - 0.16 and q.y < c0.y + 0.05 and absf(q.x) < 0.30:
					pts.append(q)
	var res: Array = []
	for j in prof.size():
		var yj := c0.y + float((prof[j] as Array)[2])
		var b := PackedFloat32Array()
		b.resize(nt)
		for q in pts:
			if absf(q.y - yj) > 0.025:
				continue
			var d := Vector2(q.x - c0.x, q.z - c0.z)
			var i := posmod(int(roundf(atan2(d.x, d.y) / TAU * nt)), nt)
			b[i] = maxf(b[i], d.length())
		var l := PackedFloat32Array()
		l.resize(nt)
		for i in nt:
			l[i] = maxf(b[i], maxf(b[(i + 1) % nt], b[(i + nt - 1) % nt]) * 0.97)
		res.append(l)
	return res

## Laine tricotée (côtes verticales, grain, fils) ou cuir (grain, griffures, couture le long de l'ourlet), 32 x 16, répétée 4 fois
## autour du cou (u) ; v = du cou à l'ourlet.
static func texture(c: Color, cuir: bool) -> ImageTexture:
	var cle := "%s_%s" % [c.to_html(), cuir]
	if _tex.has(cle):
		return _tex[cle]
	var W := 32
	var H := 16
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var f := 1.0
			if cuir:
				f += (RealismePnj._h(x, y, 501) - 0.5) * 0.14 + (RealismePnj.bruit(x, y, W, H, 8, 4, 502) - 0.5) * 0.22
				if y == H - 3 and x % 3 == 0:
					f = 1.28                 # couture (points clairs)
				if y >= H - 1:
					f *= 0.7                 # tranche de l'ourlet
			else:
				f += (0.12 if x % 2 == 0 else -0.10)          # côtes du tricot
				f += (RealismePnj._h(x / 2, y, 503) - 0.5) * 0.16
				f += (RealismePnj.bruit(x, y, W, H, 6, 3, 504) - 0.5) * 0.18
				if y >= H - 2:
					f *= 0.82
			var p := c * clampf(f, 0.5, 1.4)
			p.a = 1.0
			img.set_pixel(x, y, p)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[cle] = t
	return t
