class_name GuerrierNordique
## Guerrier nordique « pilote » : la référence de qualité des personnages (refonte persos, branche refonte/persos_guerrier).
##
## Base = Humain.creer (corps homme Quaternius, visage, proportions, squelette 65 os, animations et ragdoll d'origine),
## habillée de l'équipement et du traitement de matières de la référence draugr (persos_b) :
##   cotte de mailles (tunique) sous un plastron de cuir rivé, grosse fourrure en MÈCHES géométriques aux épaules, cape
##   bleue à l'ourlet effiloché, ceinture à boucle ronde, brassards lacés cerclés de fer, pantalon à bandes molletières,
##   bottes fourrées, épée et bouclier rond en bois peint cerclé de fer (modelés par code), barbe et tresses nordiques,
##   casque à nasal en option. Contour sombre par coque inversée (next_pass) sur les pièces opaques.
## Textures : GuerrierTextures (128 texels/m, palettes froides, mipmaps pixel art). Shader : shaders/ps1_perso.gdshader
## (même accroche des sommets, même mapping affine que ps1, + découpe, soleil désaturé et ombres froides).
##
## Ne modifie aucun PNJ : NOUVELLE fabrique.
##   GuerrierNordique.creer({"casque": false, "bouclier": "bras" | "dos" | "", "epee": true, "sous_couche": false}) -> Node3D
## Contrat identique à Humain.creer : nœud racine -> Skeleton3D + AnimationPlayer « Animations », mêmes os
## (Head, spine_03, hand_r, lowerarm_l… : Ragdoll.equiper, PiedsAuSol.equiper marchent tels quels).

const SHADER := preload("res://shaders/ps1_perso.gdshader")
const CONTOUR := preload("res://shaders/contour_perso.gdshader")

const TEINTE_CHEVEUX := Color(0.95, 0.85, 0.75)
const PEAU := Color(0.95, 0.86, 0.82)

static var _shaders := {}
static var _contour: ShaderMaterial

static func shader(double_face: bool) -> Shader:
	if not _shaders.has(double_face):
		if not double_face:
			_shaders[false] = SHADER
		else:
			var sh := Shader.new()
			sh.code = SHADER.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
			_shaders[true] = sh
	return _shaders[double_face]

static func contour() -> ShaderMaterial:
	if _contour == null:
		_contour = ShaderMaterial.new()
		_contour.shader = CONTOUR
		_contour.set_shader_parameter("epaisseur", 1.2)
		Palette.materiaux.append(_contour)
		Palette._appliquer(_contour, Palette._ps1_actif)
	return _contour

static var _mats := {}

## Matériau du guerrier (partagé entre guerriers : même texture = même matériau).
static func materiau(tex: Texture2D, double_face := true, decoupe := false, avec_contour := true, cle := "") -> ShaderMaterial:
	var k := "%s|%s|%s|%s" % [cle if cle != "" else str(tex.get_rid()), double_face, decoupe, avec_contour]
	if _mats.has(k):
		return _mats[k]
	var m := ShaderMaterial.new()
	m.shader = shader(double_face)
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("decoupe", decoupe)
	if avec_contour:
		m.next_pass = contour()
	Palette.materiaux.append(m)
	Palette._appliquer(m, Palette._ps1_actif)
	_mats[k] = m
	return m

static func vider() -> void:
	_mats.clear()
	_shaders.clear()
	_contour = null
	GuerrierTextures.vider()

# ======================================================================================================== fabrique
static func creer(options := {}) -> Node3D:
	var C := Color.WHITE
	var app := {"corps": "homme", "barbe": true, "cheveux": "Hair_Long", "teinte_cheveux": TEINTE_CHEVEUX, "peau": PEAU,
		"tenue": {"tunique": C, "pantalon": C, "bottes": C, "ceinture": C, "brassards": C, "cape": C, "mante": C}}
	var casque: bool = options.get("casque", false)
	if casque:
		app["casque"] = "casque_nasal"
	var t0 := Time.get_ticks_usec()
	var racine := Humain.creer(app)
	_t("Humain.creer", t0)
	racine.name = "GuerrierNordique"
	var sq := racine.find_child("Skeleton3D", true, false) as Skeleton3D
	var pieces := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		pieces[String(mi.name)] = mi
	# -- vêtements existants : matières du guerrier
	_habiller(pieces["tunique"], materiau(GuerrierTextures.tex("mailles")))
	_habiller(pieces["pantalon"], materiau(GuerrierTextures.tex("pantalon")))
	_habiller(pieces["bottes"], materiau(GuerrierTextures.tex("bottes")))
	_habiller(pieces["ceinture"], materiau(GuerrierTextures.tex("ceinture")))
	_habiller(pieces["brassards"], materiau(GuerrierTextures.tex("brassards")))
	_habiller(pieces["mante"], materiau(GuerrierTextures.tex("mante")))
	_habiller(pieces["cape"], materiau(GuerrierTextures.tex("cape"), true, true, false))
	# sous-couche (corps entier rentré sous l'étoffe) : coupée par défaut (3 768 triangles), les pièces se recouvrent
	var sc: MeshInstance3D = pieces.get("SuperHero_Male")
	if sc and not options.get("sous_couche", false):
		sc.visible = false
	# peau, yeux, sourcils : mêmes textures (Humain._peau), passées au shader du guerrier (soleil désaturé, ombres froides) ;
	# contour sur la peau (visage, mains)
	for nom in ["peau", "Eyes", "Eyebrows"]:
		var mi: MeshInstance3D = pieces.get(nom)
		if mi == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null:
				continue
			var cle := "peau_%s_%d" % [nom, s]
			if not _mats.has(cle):
				var m2 := ShaderMaterial.new()
				m2.shader = shader(nom == "Eyebrows")
				for p in ["tex_base", "teinte", "emission", "saturation"]:
					m2.set_shader_parameter(p, m.get_shader_parameter(p))
				if nom == "peau":
					m2.next_pass = contour()
				Palette.materiaux.append(m2)
				Palette._appliquer(m2, Palette._ps1_actif)
				_mats[cle] = m2
			mi.set_surface_override_material(s, _mats[cle])
	# allègement (budget) : faces cachées retirées (arrière des globes oculaires, peau sous les manches et les brassards,
	# couches intérieures des cheveux et de la barbe), sourcils remplacés par rien (1-2 px à 2 m, ombrés par l'arcade)
	var tete := sq.get_bone_global_rest(sq.find_bone("Head")).origin + Vector3(0, 0.07, 0)
	_filtrer(pieces.get("Eyes"), func(c: Vector3, n: Vector3) -> bool: return n.z > -0.2)
	_filtrer(pieces.get("peau"), func(c: Vector3, n: Vector3) -> bool: return absf(c.x) < 0.19 or absf(c.x) > 0.69)
	if pieces.has("Eyebrows"):
		pieces["Eyebrows"].visible = false
	for nom in ["Hair_Long", "Hair_Beard"]:
		_filtrer(sq.get_node_or_null(nom), func(c: Vector3, n: Vector3) -> bool: return n.dot(c - tete) > -0.002)
	# cheveux et barbe : mèches Quaternius gardées, texture ramenée à la palette (64², au lieu de 2048²)
	for nom in ["Hair_Long", "Hair_Beard"]:
		var mi: MeshInstance3D = sq.get_node_or_null(nom)
		if mi:
			mi.material_override = materiau(_tex_cheveux(mi), true, false, true, "cheveux_" + nom)
	_t("matieres", t0)
	# -- pièces ajoutées
	_plastron(sq, pieces["tunique"])
	_t("plastron", t0)
	var rest_skin := sq.create_skin_from_rest_transforms()
	var acc := Accessoires.new(sq)
	acc.fourrure_bord(pieces["mante"], 1.25, 1.43, 0.10, 0.17, 1.0, 1.7)       # frange des épaules
	acc.fourrure_surface(pieces["mante"], 1.40, 1.58, 0.07, 0.11, 70)          # touffes sur le dessus
	acc.fourrure_bord(pieces["mante"], 1.52, 1.66, 0.05, 0.08, -0.6, 1.4)      # col (vers le haut)
	acc.fourrure_bord(pieces["bottes"], 0.30, 0.45, 0.06, 0.09, 1.0, 1.6)      # revers des bottes
	acc.boucle(Vector3(0.0, 0.988, 0.135))
	acc.tresses()
	var bouclier: String = options.get("bouclier", "bras")
	if bouclier != "":
		acc.bouclier(bouclier)
	if options.get("epee", true):
		acc.epee()
	_t("accessoires (geometrie)", t0)
	var mi_acc := acc.construire(rest_skin)
	_t("accessoires (materiaux)", t0)
	sq.add_child(mi_acc)
	racine.set_meta("guerrier_nordique", true)
	return racine

## Garde les triangles de `mi` pour lesquels garder(centre, normale) est vrai (même peau d'os, mêmes sommets).
static func _filtrer(mi: MeshInstance3D, garder: Callable) -> void:
	if mi == null:
		return
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nb: int = (a[Mesh.ARRAY_BONES] as PackedInt32Array).size() / v.size() if a[Mesh.ARRAY_BONES] != null else 4
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var garde := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var p0 := v[idx[t]]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		var n := (p2 - p0).cross(p1 - p0).normalized()
		if garder.call((p0 + p1 + p2) / 3.0, n):
			garde.append_array([idx[t], idx[t + 1], idx[t + 2]])
	a[Mesh.ARRAY_INDEX] = garde
	for k in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		a[k] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	var mat := mi.get_surface_override_material(0)
	mi.mesh = m
	if mat:
		mi.set_surface_override_material(0, mat)

static var chrono := false

static func _t(etape: String, t0: int) -> void:
	if chrono:
		print("GUERRIER %-26s %7.1f ms" % [etape, (Time.get_ticks_usec() - t0) / 1000.0])

static func _habiller(mi: MeshInstance3D, m: ShaderMaterial) -> void:
	mi.visible = true
	mi.material_override = m

## Texture d'origine des mèches de cheveux (Quaternius, 2048²) réduite en moyenne à 64² puis quantifiée dans la palette
## CHEVEUX par luminance (les brins et leur transparence de forme restent ; plus de micro-détail qui grouille).
static var _tex_q := {}

static func _tex_cheveux(mi: MeshInstance3D) -> Texture2D:
	var m := mi.material_override as ShaderMaterial
	var src: Texture2D = m.get_shader_parameter("tex_base") if m else null
	if src == null:
		return GuerrierTextures.tex("cheveux")
	var cle := src.resource_path
	if _tex_q.has(cle):
		return _tex_q[cle]
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	var lmin := 1.0
	var lmax := 0.0
	for y in 64:
		for x in 64:
			var l := img.get_pixel(x, y).get_luminance()
			lmin = minf(lmin, l)
			lmax = maxf(lmax, l)
	for y in 64:
		for x in 64:
			var l := (img.get_pixel(x, y).get_luminance() - lmin) / maxf(0.01, lmax - lmin)
			img.set_pixel(x, y, GuerrierTextures._c(GuerrierTextures.CHEVEUX, GuerrierTextures._ton(l, 5, x, y, 951, 0.3)))
	var t := ImageTexture.create_from_image(GuerrierTextures.mips_pixel(img))
	_tex_q[cle] = t
	return t

# ======================================================================================================== plastron
## Plastron de cuir : les triangles du TORSE de la tunique (hors manches, entre la taille et le haut de la poitrine),
## copiés avec leur peau d'os et gonflés de 1,3 cm le long de la normale. Mêmes UV que la tunique, texture propre.
const OS_BRAS := ["upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "clavicle_l", "clavicle_r", "hand_l", "hand_r"]

static func _plastron(sq: Skeleton3D, tunique: MeshInstance3D) -> void:
	var a := tunique.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var nb := bones.size() / v.size()
	var bras := {}
	for nom in OS_BRAS:
		bras[_bind_de(tunique.skin, sq, nom)] = true
	var garde := PackedInt32Array()
	var vmin := 1.0
	var vmax := 0.0
	for t in range(0, idx.size(), 3):
		var ok := true
		for k in 3:
			var i: int = idx[t + k]
			var p := v[i]
			if p.y < 0.99 or p.y > 1.47 or absf(p.x) > 0.215:
				ok = false
				break
			var poids_bras := 0.0
			for j in nb:
				if bras.has(bones[i * nb + j]):
					poids_bras += w[i * nb + j]
			if poids_bras > 0.35:
				ok = false
				break
		if ok:
			for k in 3:
				garde.append(idx[t + k])
				vmin = minf(vmin, uv[idx[t + k]].y)
				vmax = maxf(vmax, uv[idx[t + k]].y)
	# sommets réindexés, gonflés
	var carte := {}
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nuv := PackedVector2Array()
	var nbo := PackedInt32Array()
	var nw := PackedFloat32Array()
	var nidx := PackedInt32Array()
	for i in garde:
		if not carte.has(i):
			carte[i] = nv.size()
			nv.append(v[i] + nrm[i] * 0.013)
			nn.append(nrm[i])
			nuv.append(uv[i])
			for j in nb:
				nbo.append(bones[i * nb + j])
				nw.append(w[i * nb + j])
		nidx.append(carte[i])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = nv
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_TEX_UV] = nuv
	arr[Mesh.ARRAY_BONES] = nbo
	arr[Mesh.ARRAY_WEIGHTS] = nw
	arr[Mesh.ARRAY_INDEX] = nidx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	var mi := MeshInstance3D.new()
	mi.name = "plastron"
	mi.mesh = mesh
	mi.skin = tunique.skin
	sq.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.material_override = materiau(GuerrierTextures.tex("plastron", [snappedf(vmin, 0.01), snappedf(vmax, 0.01)]), true)

## Indice de bind (dans `skin`) de l'os `nom` (les maillages glTF indexent leurs poids par bind, pas par os).
static func _bind_de(skin: Skin, sq: Skeleton3D, nom: String) -> int:
	for b in skin.get_bind_count():
		if skin.get_bind_name(b) == nom or (skin.get_bind_bone(b) >= 0 and sq.get_bone_name(skin.get_bind_bone(b)) == nom):
			return b
	return -1

## Os du squelette d'un bind.
static func _os_de_bind(skin: Skin, sq: Skeleton3D, b: int) -> int:
	if skin.get_bind_bone(b) >= 0:
		return skin.get_bind_bone(b)
	return sq.find_bone(skin.get_bind_name(b))


# ======================================================================================================== accessoires
## Géométrie ajoutée, toute en un maillage peau d'os (peau de repos du squelette : bind i = os i) à 2 surfaces :
## opaque (bouclier, épée, boucle, tresses ; atlas GuerrierTextures.accessoires, contour) et découpée (mèches de fourrure).
class Accessoires:
	var sq: Skeleton3D
	var op := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var dec := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var graine := 1

	func _init(s: Skeleton3D) -> void:
		sq = s

	func _h(i: int) -> float:
		graine += 1
		return ObjetsTextures._h(i, graine, 977)

	## Triangle (sommets dans le repère du modèle au repos), poids rigides sur un os OU poids donnés (4 os) par sommet.
	## Godot : face avant = sommets dans le sens HORAIRE vus de devant. `dedans` = un point du côté intérieur : l'ordre est
	## corrigé pour que la face avant regarde vers l'extérieur (le contour par coque inversée en dépend).
	func _tri(s: Dictionary, p: Array, uv: Array, os_: Variant, dedans: Vector3) -> void:
		var p0: Vector3 = p[0]
		var n: Vector3 = (p[2] - p0).cross(p[1] - p0)
		var ordre := [0, 1, 2]
		if n.dot((p[0] + p[1] + p[2]) / 3.0 - dedans) < 0.0:
			ordre = [0, 2, 1]
			n = -n
		n = n.normalized()
		for k: int in ordre:
			s["v"].append(p[k])
			s["n"].append(n)
			s["uv"].append(uv[k])
			if os_ is int:
				s["b"].append_array([os_, 0, 0, 0])
				s["w"].append_array([1.0, 0.0, 0.0, 0.0])
			else:
				var pw: Array = os_[k]
				s["b"].append_array(pw[0])
				s["w"].append_array(pw[1])

	func _quad(s: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, os_: Variant, dedans: Vector3) -> void:
		# contour a b c d ; os_ = int ou [poids a, b, c, d]
		if os_ is int:
			_tri(s, [a, b, c], [ua, ub, uc], os_, dedans)
			_tri(s, [a, c, d], [ua, uc, ud], os_, dedans)
		else:
			_tri(s, [a, b, c], [ua, ub, uc], [os_[0], os_[1], os_[2]], dedans)
			_tri(s, [a, c, d], [ua, uc, ud], [os_[0], os_[2], os_[3]], dedans)

	## UV d'un point (texels) de l'atlas des accessoires.
	func _uva(x: float, y: float) -> Vector2:
		return Vector2(x / GuerrierTextures.ATLAS.x, y / GuerrierTextures.ATLAS.y)

	# ------------------------------------------------------------ fourrure en mèches
	## Poids d'os (convertis en os du squelette) du sommet de `mi` le plus proche de p.
	func _poids_proche(mi: MeshInstance3D, a: Array, p: Vector3) -> Array:
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var nb := bones.size() / v.size()
		var best := 0
		var bd := 1e9
		for i in v.size():
			var d := v[i].distance_squared_to(p)
			if d < bd:
				bd = d
				best = i
		# 4 plus gros poids
		var paires := []
		for j in nb:
			if w[best * nb + j] > 0.0:
				paires.append([w[best * nb + j], GuerrierNordique._os_de_bind(mi.skin, sq, bones[best * nb + j])])
		paires.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		var bo := [0, 0, 0, 0]
		var wo := [0.0, 0.0, 0.0, 0.0]
		var somme := 0.0
		for j in mini(4, paires.size()):
			bo[j] = paires[j][1]
			wo[j] = paires[j][0]
			somme += wo[j]
		for j in 4:
			wo[j] /= maxf(somme, 1e-5)
		return [PackedInt32Array(bo), PackedFloat32Array(wo)]

	## Une carte de mèches : racine centrée en `r`, de largeur `larg`, pendant selon `dir` (unitaire) sur `lg` mètres,
	## orientée face à `face` ; variante de mèche 0-3 (colonne de l'atlas des mèches).
	func _carte(mi: MeshInstance3D, a: Array, r: Vector3, cote: Vector3, dir: Vector3, larg: float, lg: float, variante: int, ext: Vector3) -> void:
		var g := r - cote * larg * 0.5
		var d := r + cote * larg * 0.5
		var gb := g + dir * lg
		var db := d + dir * lg
		var u0 := variante * 0.25
		var u1 := u0 + 0.25
		var pr := _poids_proche(mi, a, r)
		var pb := _poids_proche(mi, a, r + dir * lg * 0.6)
		_quad(dec, g, d, db, gb, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0), [pr, pr, pb, pb], r - ext * 0.1)

	## Frange de mèches le long des bords libres de `mi` compris entre y0 et y1 : une carte par arête (élargie pour se
	## recouvrir), pendant vers le bas et vers l'extérieur (`bas` : 1 = vers le bas, négatif = se dresse), longueur lg0-lg1.
	func fourrure_bord(mi: MeshInstance3D, y0: float, y1: float, lg0: float, lg1: float, bas: float, elargi: float) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var aretes := {}
		var refs := {}
		for t in range(0, idx.size(), 3):
			for k in 3:
				var i0: int = idx[t + k]
				var i1: int = idx[t + (k + 1) % 3]
				var p0 := v[i0].snapped(Vector3.ONE * 0.0005)
				var p1 := v[i1].snapped(Vector3.ONE * 0.0005)
				var cle := [p0, p1] if str(p0) < str(p1) else [p1, p0]
				aretes[cle] = int(aretes.get(cle, 0)) + 1
				refs[cle] = [i0, i1]
		var n := 0
		for cle in aretes:
			if aretes[cle] != 1:
				continue
			var i0: int = refs[cle][0]
			var i1: int = refs[cle][1]
			var p0 := v[i0]
			var p1 := v[i1]
			var m := (p0 + p1) * 0.5
			if m.y < y0 or m.y > y1:
				continue
			var cote := (p1 - p0)
			var lc := cote.length()
			if lc < 0.004:
				continue
			cote /= lc
			var ext := (nrm[i0] + nrm[i1]).normalized()
			ext.y = 0.0
			if ext.length() < 0.1:
				ext = Vector3(m.x, 0.0, m.z).normalized()
			ext = ext.normalized()
			var dir := (Vector3.DOWN * bas + ext * 0.55).normalized()
			var lg := lerpf(lg0, lg1, _h(n))
			_carte(mi, a, m - dir * 0.012 + ext * 0.004, cote, dir, maxf(lc * elargi, 0.035), lg, n % 4, ext)
			n += 1

	## Touffes posées sur la surface de `mi` (triangles entre y0 et y1) : cartes couchées, dirigées vers le bas et l'extérieur.
	func fourrure_surface(mi: MeshInstance3D, y0: float, y1: float, lg0: float, lg1: float, nombre: int) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var tris := []
		for t in range(0, idx.size(), 3):
			var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			if c.y >= y0 and c.y <= y1:
				tris.append(t)
		if tris.is_empty():
			return
		for k in nombre:
			var t: int = tris[int(_h(k) * tris.size()) % tris.size()]
			var b1 := _h(k + 1)
			var b2 := _h(k + 2) * (1.0 - b1)
			var p := v[idx[t]] * (1.0 - b1 - b2) + v[idx[t + 1]] * b1 + v[idx[t + 2]] * b2
			var n := (nrm[idx[t]] + nrm[idx[t + 1]] + nrm[idx[t + 2]]).normalized()
			var ext := Vector3(n.x, 0.0, n.z)
			if ext.length() < 0.05:
				ext = Vector3(p.x, 0.0, p.z)
			ext = ext.normalized()
			var dir := (Vector3.DOWN * 0.8 + ext * 0.6 + n * 0.25).normalized()
			var cote := ext.cross(Vector3.UP).normalized()
			_carte(mi, a, p + n * 0.006, cote, dir, lerpf(0.045, 0.07, _h(k + 3)), lerpf(lg0, lg1, _h(k + 4)), k % 4, ext)

	# ------------------------------------------------------------ boucle de ceinture (os pelvis)
	func boucle(centre: Vector3) -> void:
		var os_ := sq.find_bone("pelvis")
		var f := GuerrierTextures.R_FER
		var u := GuerrierTextures.R_UMBO
		var n := 10
		var r0 := 0.036
		var r1 := 0.026
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var e0 := Vector3(cos(a0), sin(a0), 0.0)
			var e1 := Vector3(cos(a1), sin(a1), 0.0)
			# anneau plat (fer) puis bossette bombée (umbo)
			_quad(op, centre + e0 * r1 + Vector3(0, 0, 0.006), centre + e1 * r1 + Vector3(0, 0, 0.006), centre + e1 * r0, centre + e0 * r0,
				_uva(f.position.x + 4 * i % 32, f.position.y + 2), _uva(f.position.x + 4 * (i + 1) % 32 + 0.01, f.position.y + 2),
				_uva(f.position.x + 4 * (i + 1) % 32 + 0.01, f.position.y + 12), _uva(f.position.x + 4 * i % 32, f.position.y + 12), os_, centre - Vector3(0, 0, 0.05))
			_tri(op, [centre + Vector3(0, 0, 0.016), centre + e1 * r1 + Vector3(0, 0, 0.006), centre + e0 * r1 + Vector3(0, 0, 0.006)],
				[_uva(u.position.x + 16, u.position.y + 2), _uva(u.position.x + 3.2 * (i + 1), u.position.y + 26), _uva(u.position.x + 3.2 * i, u.position.y + 26)], os_, centre - Vector3(0, 0, 0.05))

	# ------------------------------------------------------------ tresses de barbe (os Head)
	func tresses() -> void:
		var os_ := sq.find_bone("Head")
		var r := GuerrierTextures.R_TRESSE
		for cote in [-1.0, 1.0]:
			var haut := Vector3(0.022 * cote, 1.585, 0.098)
			var bas := Vector3(0.030 * cote, 1.47, 0.115)
			_tube(op, haut, bas, 0.012, 0.007, 4, os_, r)
			# tresse de tempe, devant l'oreille, jusqu'à la clavicule
			_tube(op, Vector3(0.078 * cote, 1.70, 0.035), Vector3(0.088 * cote, 1.52, 0.05), 0.014, 0.008, 4, os_, r)

	## Tube à `cotes` pans (UV : région de l'atlas, enroulée en u, du haut au bas en v).
	func _tube(s: Dictionary, a: Vector3, b: Vector3, ra: float, rb: float, cotes: int, os_: int, r: Rect2i, segments := 3) -> void:
		var axe := (b - a).normalized()
		var x := axe.cross(Vector3.FORWARD if absf(axe.z) < 0.9 else Vector3.RIGHT).normalized()
		var y := axe.cross(x)
		for sgm in segments:
			var t0 := float(sgm) / segments
			var t1 := float(sgm + 1) / segments
			var c0 := a.lerp(b, t0)
			var c1 := a.lerp(b, t1)
			var q0 := lerpf(ra, rb, t0)
			var q1 := lerpf(ra, rb, t1)
			for i in cotes:
				var a0 := TAU * i / cotes
				var a1 := TAU * (i + 1) / cotes
				var d0 := x * cos(a0) + y * sin(a0)
				var d1 := x * cos(a1) + y * sin(a1)
				var u0 := r.position.x + r.size.x * float(i) / cotes
				var u1 := r.position.x + r.size.x * float(i + 1) / cotes
				var v0 := r.position.y + r.size.y * t0
				var v1 := r.position.y + r.size.y * t1
				_quad(s, c0 + d0 * q0, c0 + d1 * q0, c1 + d1 * q1, c1 + d0 * q1, _uva(u0, v0), _uva(u1, v0), _uva(u1, v1), _uva(u0, v1), os_, (c0 + c1) * 0.5)

	# ------------------------------------------------------------ bouclier rond (bras gauche ou dos)
	## Repère local : centre à l'origine, face vers +Z, haut +Y ; rayon 0,40 m. Face bombée (planches, peinture : atlas),
	## cerclage de fer (bande + lèvres), umbo en dôme sur collerette, dos en bois brut.
	const RB := 0.40

	func bouclier(ou: String) -> void:
		var os_ := sq.find_bone("lowerarm_l" if ou == "bras" else "spine_03")
		var tr: Transform3D
		var rest := sq.get_bone_global_rest(os_)
		if ou == "bras":
			# au repos (pose en T), l'avant-bras gauche est horizontal vers +X : le bouclier se tient sur le dessus de
			# l'avant-bras (normale +Y au repos = vers l'extérieur une fois le bras baissé), haut du bouclier vers le coude.
			var cx := (rest.origin.x + sq.get_bone_global_rest(sq.find_bone("hand_l")).origin.x) * 0.5
			var b := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0))   # colonnes : x local, y local (haut), z local (face)
			b = Basis(Vector3.RIGHT, deg_to_rad(28.0)) * b * Basis(Vector3.FORWARD, deg_to_rad(-12.0))
			tr = Transform3D(b, Vector3(cx, rest.origin.y + 0.075, rest.origin.z + 0.02))
		else:
			tr = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(8.0)), Vector3(0.0, 1.22, -0.21))
		var n := 16
		var anneaux := [[0.105, 0.030], [0.25, 0.024], [0.375, 0.012]]     # [rayon, z] de la face bombée
		var fa := GuerrierTextures.R_FACE
		var fuv := func(p: Vector3) -> Vector2:
			return _uva(fa.position.x + (0.5 + p.x / (2.0 * RB * 0.97)) * fa.size.x, fa.position.y + (0.5 - p.y / (2.0 * RB * 0.97)) * fa.size.y)
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var e0 := Vector3(cos(a0), sin(a0), 0.0)
			var e1 := Vector3(cos(a1), sin(a1), 0.0)
			# face (planches peintes)
			for k in anneaux.size() - 1:
				var ri: float = anneaux[k][0]
				var ro: float = anneaux[k + 1][0]
				var zi: float = anneaux[k][1]
				var zo: float = anneaux[k + 1][1]
				var p := [e0 * ri + Vector3(0, 0, zi), e1 * ri + Vector3(0, 0, zi), e1 * ro + Vector3(0, 0, zo), e0 * ro + Vector3(0, 0, zo)]
				_quad(op, tr * p[1], tr * p[0], tr * p[3], tr * p[2], fuv.call(p[1]), fuv.call(p[0]), fuv.call(p[3]), fuv.call(p[2]), os_, tr * Vector3(0, 0, -1))
			# cerclage : lèvre avant, bande extérieure, lèvre arrière
			var f := GuerrierTextures.R_FER
			var uf0 := f.position.x + 32.0 * i / n
			var uf1 := f.position.x + 32.0 * (i + 1) / n
			var ro2 := RB + 0.008
			var lev := [[e0 * 0.372 + Vector3(0, 0, 0.016), e1 * 0.372 + Vector3(0, 0, 0.016), e1 * ro2 + Vector3(0, 0, 0.022), e0 * ro2 + Vector3(0, 0, 0.022), 0, 8, Vector3(0, 0, -1)],
				[e0 * ro2 + Vector3(0, 0, 0.022), e1 * ro2 + Vector3(0, 0, 0.022), e1 * ro2 + Vector3(0, 0, -0.016), e0 * ro2 + Vector3(0, 0, -0.016), 8, 20, Vector3.ZERO],
				[e0 * ro2 + Vector3(0, 0, -0.016), e1 * ro2 + Vector3(0, 0, -0.016), e1 * 0.385 + Vector3(0, 0, -0.016), e0 * 0.385 + Vector3(0, 0, -0.016), 20, 30, Vector3(0, 0, 1)]]
			for l: Array in lev:
				_quad(op, tr * l[1], tr * l[0], tr * l[3], tr * l[2], _uva(uf1, f.position.y + l[4]), _uva(uf0, f.position.y + l[4]),
					_uva(uf0, f.position.y + l[5]), _uva(uf1, f.position.y + l[5]), os_, tr * l[6])
			# dos (bois brut + sangles) : éventail
			var d := GuerrierTextures.R_DOS
			var duv := func(p: Vector3) -> Vector2:
				return _uva(d.position.x + (0.5 + p.x / (2.0 * RB)) * d.size.x, d.position.y + (0.5 - p.y / (2.0 * RB)) * d.size.y)
			var c := Vector3(0, 0, -0.016)
			var q0 := e0 * 0.385 + c
			var q1 := e1 * 0.385 + c
			_tri(op, [tr * c, tr * q0, tr * q1], [duv.call(c), duv.call(q0), duv.call(q1)], os_, tr * Vector3(0, 0, 1))
			# umbo : collerette plate + dôme (2 rangs)
			var u := GuerrierTextures.R_UMBO
			var uu0 := u.position.x + 32.0 * i / n
			var uu1 := u.position.x + 32.0 * (i + 1) / n
			var dome := [[0.105, 0.032, 30.0], [0.075, 0.040, 26.0], [0.068, 0.075, 16.0], [0.040, 0.105, 7.0], [0.0, 0.115, 0.0]]
			for k in dome.size() - 1:
				var A: Array = dome[k]
				var B: Array = dome[k + 1]
				var p := [e0 * A[0] + Vector3(0, 0, A[1]), e1 * A[0] + Vector3(0, 0, A[1]), e1 * B[0] + Vector3(0, 0, B[1]), e0 * B[0] + Vector3(0, 0, B[1])]
				if k == dome.size() - 2:
					_tri(op, [tr * p[1], tr * p[0], tr * p[3]], [_uva(uu1, u.position.y + A[2]), _uva(uu0, u.position.y + A[2]), _uva(uu0, u.position.y + 1)], os_, tr * Vector3.ZERO)
				else:
					_quad(op, tr * p[1], tr * p[0], tr * p[3], tr * p[2], _uva(uu1, u.position.y + A[2]), _uva(uu0, u.position.y + A[2]),
						_uva(uu0, u.position.y + B[2]), _uva(uu1, u.position.y + B[2]), os_, tr * Vector3.ZERO)

	# ------------------------------------------------------------ épée (main droite, même prise que les draugrs)
	## Repère de epee_nordique.glb : poignée de y = 0 à 0,08, garde à 0,07-0,11, lame jusqu'à 0,86 (largeur en x).
	const PRISE := Transform3D(Basis(Vector3(-0.999251, -0.038334, -0.005288), Vector3(-0.014458, 0.24307, 0.969901), Vector3(-0.035895, 0.969252, -0.243442)), Vector3(-0.007936, 0.142938, 0.002241))

	func epee() -> void:
		var os_ := sq.find_bone("hand_r")
		var tr := sq.get_bone_global_rest(os_) * PRISE
		var l := GuerrierTextures.R_LAME
		var f := GuerrierTextures.R_FER
		# lame : section en losange (4 pans) de la garde (y 0,105) à la pointe (0,88)
		var sec := [[0.105, 0.034, 0.006], [0.70, 0.029, 0.005], [0.80, 0.019, 0.004]]
		var pointe := Vector3(0, 0.885, 0)
		for k in sec.size():
			var A: Array = sec[k]
			var pa := [Vector3(-A[1], A[0], 0), Vector3(0, A[0], A[2]), Vector3(A[1], A[0], 0), Vector3(0, A[0], -A[2])]
			var va: float = l.position.y + l.size.y * (A[0] - 0.105) / 0.78
			if k == sec.size() - 1:
				for i in 4:
					var u0 := l.position.x + (0.0 if i < 2 else 8.0) + (0.0 if i % 2 == 0 else 8.0)
					_tri(op, [tr * pa[i], tr * pa[(i + 1) % 4], tr * pointe], [_uva(u0, va), _uva(u0 + 7.9, va), _uva(u0 + 4.0, l.position.y + l.size.y - 0.5)], os_, tr * Vector3(0, A[0], 0))
				break
			var B: Array = sec[k + 1]
			var pb := [Vector3(-B[1], B[0], 0), Vector3(0, B[0], B[2]), Vector3(B[1], B[0], 0), Vector3(0, B[0], -B[2])]
			var vb: float = l.position.y + l.size.y * (B[0] - 0.105) / 0.78
			for i in 4:
				# u : pan gauche 0-8, pan droit 8-16 (le fil clair est au bord de l'atlas de la lame)
				var u0 := l.position.x + (0.0 if i % 2 == 0 else 8.0)
				var u1 := u0 + 7.9
				_quad(op, tr * pa[i], tr * pa[(i + 1) % 4], tr * pb[(i + 1) % 4], tr * pb[i], _uva(u0, va), _uva(u1, va), _uva(u1, vb), _uva(u0, vb), os_, tr * Vector3(0, (A[0] + B[0]) * 0.5, 0))
		# garde : barre à 6 faces
		_boite(Vector3(-0.095, 0.078, -0.016), Vector3(0.095, 0.105, 0.016), tr, os_, f)
		# poignée : prisme à 6 pans
		_tube(op, tr * Vector3(0, 0.078, 0), tr * Vector3(0, -0.005, 0), 0.016, 0.015, 6, os_, GuerrierTextures.R_POIGNEE, 1)
		# pommeau : boîte trapue
		_boite(Vector3(-0.034, -0.040, -0.018), Vector3(0.034, -0.004, 0.018), tr, os_, f)

	func _boite(a: Vector3, b: Vector3, tr: Transform3D, os_: int, r: Rect2i) -> void:
		var c := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
			Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
		var faces := [[3, 2, 1, 0], [4, 5, 6, 7], [7, 6, 2, 3], [0, 1, 5, 4], [4, 7, 3, 0], [1, 2, 6, 5]]
		for fc: Array in faces:
			_quad(op, tr * c[fc[0]], tr * c[fc[1]], tr * c[fc[2]], tr * c[fc[3]], _uva(r.position.x + 2, r.position.y + 4), _uva(r.position.x + 30, r.position.y + 4),
				_uva(r.position.x + 30, r.position.y + 14), _uva(r.position.x + 2, r.position.y + 14), os_, tr * ((a + b) * 0.5))

	# ------------------------------------------------------------ assemblage
	func construire(skin: Skin) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		var s_op := -1
		var s_dec := -1
		for s: Dictionary in [op, dec]:
			if s["v"].is_empty():
				continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = s["v"]
			arr[Mesh.ARRAY_NORMAL] = s["n"]
			arr[Mesh.ARRAY_TEX_UV] = s["uv"]
			arr[Mesh.ARRAY_BONES] = s["b"]
			arr[Mesh.ARRAY_WEIGHTS] = s["w"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			if s == op:
				s_op = mesh.get_surface_count() - 1
			else:
				s_dec = mesh.get_surface_count() - 1
		var mi := MeshInstance3D.new()
		mi.name = "accessoires"
		mi.mesh = mesh
		mi.skin = skin
		mi.skeleton = NodePath("..")
		if s_op >= 0:
			mi.set_surface_override_material(s_op, GuerrierNordique.materiau(GuerrierTextures.tex("accessoires"), false, false, true))
		if s_dec >= 0:
			mi.set_surface_override_material(s_dec, GuerrierNordique.materiau(GuerrierTextures.tex("meches"), true, true, false))
		return mi
