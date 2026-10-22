class_name DraugrNordique
## Draugr nordique (refonte persos, branche refonte/persos_draugr) d'après la référence Image ChatGPT 14_01_59-5 (et la crypte
## 10_50_57-2) : guerrier mort-vivant en armure ancienne rouillée.
##
## Même recette que le Guerrier pilote validé (GuerrierNordique) : base Humain.creer (corps Quaternius, 65 os, mêmes animations
## et ragdoll), pièces existantes retexturées, accessoires MODELÉS par code dans 2 surfaces d'atlas (opaque + découpée), contour
## par coque, 128 texels/m, mipmaps pixel art, aucune normal map. On APPELLE le code du guerrier (fonctions statiques et classe
## Accessoires, étendue ici) ; rien n'y est modifié.
## Propre au draugr :
##   - masque-crâne : triangles du VISAGE copiés de la peau (même peau d'os), orbites creusées, nez aplati, joues creusées,
##     texture d'os peinte (orbites, cavité nasale, dents) ; le reste de la peau en chair desséchée gris-brun ;
##   - yeux : cartes bleu glacé LUISANTES (couleur de sommet lue par shaders/ps1_draugr.gdshader) — le seul bleu du perso ;
##   - casque à nasal et crête rivée (spangenhelm rouillé), ajusté à la tête et aux cheveux ; cheveux longs filasse dessous ;
##   - épaulières : coques de lames de fer posées sur la mante, frange de fourrure sale dessous ; col de fourrure ;
##   - cotte de mailles brun-gris ferreux rongée, ourlets déchirés (découpe) ; seconde couche de mailles sur la poitrine ;
##   - tabard et ptéruges de tissu cendré en lambeaux ; médaillon, baudrier et boucle ronde ; bandes molletières, revers fourrés ;
##   - bouclier rond en planches délavées (rune pâle, trous, morceau arraché) et épée rouillée ébréchée.
##   DraugrNordique.creer({"bouclier": "bras" | "dos" | "", "epee": true, "corps": "homme" | "femme", "casque": true}) -> Node3D
##   (contrat de Humain.creer). Variantes : "corps": "femme" (Svanhild), "casque": false (crâne et cheveux funéraires visibles).

const SHADER := preload("res://shaders/ps1_draugr.gdshader")
const LUEUR := Vector3(3.0, 5.4, 7.6)
const TEINTE_CHAIR := Color(0.64, 0.58, 0.49)   # passe 2 : peau parcheminée gris-brun, plus sombre et terne
const RAIDEUR := preload("res://scripts/draugr_raideur.gd")
const BOUCLIER_ECH := 0.7    # passe 2 : bouclier à 70 % de la taille de la passe 1
## passe 2 : membres décharnés (facteur du rayon autour de l'axe de l'os ; 1 = inchangé)
const MAIGREUR := {"upperarm_l": 0.66, "upperarm_r": 0.66, "lowerarm_l": 0.60, "lowerarm_r": 0.60, "thigh_l": 0.70, "thigh_r": 0.70, "calf_l": 0.62, "calf_r": 0.62}
## Jupe et cape en lambeaux modelés dans Blender (sources_blender/scripts/draugr_lambeaux.py) ; vide = ancienne version par code
const LAMBEAUX_BLENDER := "res://assets/persos/draugr/blender/lambeaux.glb"
const APPOINT := Vector3(0.13, 0.12, 0.11)

static var _shaders := {}
static var _mats := {}

static func shader(double_face: bool) -> Shader:
	if not _shaders.has(double_face):
		if not double_face:
			_shaders[false] = SHADER
		else:
			var sh := Shader.new()
			sh.code = SHADER.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
			_shaders[true] = sh
	return _shaders[double_face]

## Matériau du draugr (partagé entre draugrs).
static func materiau(tex: Texture2D, double_face := true, decoupe := false, avec_contour := true, cle := "") -> ShaderMaterial:
	var k := "%s|%s|%s|%s" % [cle if cle != "" else str(tex.get_rid()), double_face, decoupe, avec_contour]
	if _mats.has(k):
		return _mats[k]
	var m := ShaderMaterial.new()
	m.shader = shader(double_face)
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("decoupe", decoupe)
	m.set_shader_parameter("lueur", LUEUR)
	# lumière propre neutre-chaude : côté ombre et de nuit, la silhouette brune ne tombe pas au noir ni au bleu
	m.set_shader_parameter("appoint", APPOINT)
	if avec_contour:
		m.next_pass = GuerrierNordique.contour()
	Palette.materiaux.append(m)
	Palette._appliquer(m, Palette._ps1_actif)
	_mats[k] = m
	return m

static func vider() -> void:
	_mats.clear()
	_shaders.clear()
	DraugrTextures.vider()

# ======================================================================================================== fabrique
static func creer(options := {}) -> Node3D:
	var C := Color.WHITE
	var femme: bool = options.get("corps", "homme") == "femme"
	var casque: bool = options.get("casque", true)
	AccDraugr.dy = -0.045 if femme else 0.0     # tête et cou du corps femme : 4,5 cm plus bas
	var app := {"corps": "femme" if femme else "homme", "barbe": false, "cheveux": "Hair_Long", "teinte_cheveux": Color(0.8, 0.76, 0.7), "peau": TEINTE_CHAIR,
		"tenue": {"tunique": C, "pantalon": C, "bottes": C, "ceinture": C, "brassards": C, "mante": C, "pteruges": C}}
	var racine := Humain.creer(app)
	racine.name = "DraugrNordique"
	var sq := racine.find_child("Skeleton3D", true, false) as Skeleton3D
	var pieces := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		pieces[String(mi.name)] = mi
	_habiller(pieces["tunique"], materiau(DraugrTextures.tex("mailles"), true, true))
	_habiller(pieces["pantalon"], materiau(DraugrTextures.tex("pantalon")))
	_habiller(pieces["bottes"], materiau(DraugrTextures.tex("bottes")))
	_habiller(pieces["brassards"], materiau(DraugrTextures.tex("brassards")))
	_habiller(pieces["mante"], materiau(DraugrTextures.tex("mante")))
	for nom in ["tunique", "pantalon", "bottes", "brassards", "mante", "peau", "ceinture", "pteruges"]:
		_maigrir(sq, pieces.get(nom))
	var sc: MeshInstance3D = pieces.get("SuperHero_Female") if femme else pieces.get("SuperHero_Male")
	if sc == null:
		sc = pieces.get("Superhero_Female")
	if sc:
		sc.visible = false
	# peau : chair desséchée gris-brun (texture d'origine, teinte terne, très désaturée), appoint faible ; contour
	var pe: MeshInstance3D = pieces.get("peau")
	for s in pe.mesh.get_surface_count():
		var m := pe.get_surface_override_material(s) as ShaderMaterial
		if m == null:
			continue
		var cle := "peau_draugr_%d" % s
		if not _mats.has(cle):
			var m2 := ShaderMaterial.new()
			m2.shader = shader(false)
			m2.set_shader_parameter("tex_base", m.get_shader_parameter("tex_base"))
			m2.set_shader_parameter("teinte", TEINTE_CHAIR)
			m2.set_shader_parameter("saturation", 0.12)
			m2.set_shader_parameter("appoint", APPOINT)
			m2.next_pass = GuerrierNordique.contour()
			Palette.materiaux.append(m2)
			Palette._appliquer(m2, Palette._ps1_actif)
			_mats[cle] = m2
		pe.set_surface_override_material(s, _mats[cle])
	var yeux := GuerrierNordique._centres_yeux(pieces.get("Eyes"))
	for nom in ["Eyes", "Eyebrows"]:
		if pieces.has(nom):
			pieces[nom].visible = false
	GuerrierNordique._filtrer(pe, func(c: Vector3, n: Vector3) -> bool: return absf(c.x) < 0.19 or absf(c.x) > 0.69)
	# mains décimées (2,7 cm), arrière du crâne et nuque (sous le casque et les cheveux) 1,8 cm ; visage intact (masque-crâne)
	GuerrierNordique._decimer(pe, func(p: Vector3) -> float: return 0.027 if absf(p.x) > 0.5 else (0.018 if p.z < 0.035 else 0.0))
	# cheveux : couches intérieures retirées, mèche de front retirée (sous le casque, devant le crâne), décimés, palette terne
	var tete := sq.get_bone_global_rest(sq.find_bone("Head")).origin + Vector3(0, 0.07, 0)
	var mi_ch: MeshInstance3D = sq.get_node_or_null("Hair_Long")
	if mi_ch:
		GuerrierNordique._filtrer(mi_ch, func(c: Vector3, n: Vector3) -> bool: return n.dot(c - tete) > -0.002 and not (casque and c.z > 0.03 and c.y > 1.64 + AccDraugr.dy) and not (c.z > 0.0 and c.y < 1.54 + AccDraugr.dy))
		GuerrierNordique._decimer(mi_ch, func(p: Vector3) -> float: return 0.03)
		mi_ch.material_override = materiau(_tex_cheveux(mi_ch), true, false, true, "cheveux_draugr")
	# -- pièces ajoutées
	# passe 2 : poitrine ouverte en V sur la tunique et le plastron (côtes et clavicules à nu)
	var ouvert := func(c: Vector3, n: Vector3) -> bool: return not (c.z > 0.0 and c.y > 1.20 and c.y < 1.56 and absf(c.x) < 0.062 + (c.y - 1.20) * 0.16)
	GuerrierNordique._filtrer(pieces["tunique"], ouvert)
	var plastron := GuerrierNordique._plastron(sq, pieces["tunique"])
	GuerrierNordique._filtrer(plastron, ouvert)
	# mante ouverte en V sur le devant (comme le guerrier, plus large) : mailles, médaillon et baudrier lisibles
	GuerrierNordique._filtrer(pieces["mante"], func(c: Vector3, n: Vector3) -> bool: return not (c.z > 0.0 and absf(c.x) < 0.17 + (c.y - 1.30) * 0.3 and c.y < 1.55))
	var rest_skin := sq.create_skin_from_rest_transforms()
	var acc := AccDraugr.new(sq)
	var A := Vector2(GuerrierTextures.ATLAS)
	acc.integrer(plastron, acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 + GuerrierTextures.PL_U0, (uv.y - GuerrierTextures.PL_V0 / 128.0) * 128.0 + GuerrierTextures.R_PLASTRON.position.y) / A)
	acc.baudrier(plastron)
	acc.integrer(pieces["ceinture"], acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 + GuerrierTextures.PL_U0, clampf((uv.y - 0.698) / 0.302, 0.0, 1.0) * 15.6 + 0.2 + GuerrierTextures.R_CEINT.position.y) / A,
		func(p: Vector3, n: Vector3) -> Vector3: return Vector3(p.x, 0.989 + (p.y - 0.989) * 1.55, p.z) + n * 0.006)
	# masque-crâne (retiré de la peau), yeux luisants, casque
	acc.masque(pe, yeux)
	acc.yeux(yeux)
	if casque:
		acc.casque(pe, mi_ch)
	# épaulières puis fourrure (frange sous les épaulières, touffes dans le dos, col)
	acc.epaulieres(pieces["mante"])
	acc.cotes(pe)
	acc.poitrine_libre = true
	acc.fourrure_bord(pieces["mante"], 1.25, 1.45, 0.10, 0.19, 1.0, 1.7)
	acc.dos_seul = true
	acc.fourrure_surface(pieces["mante"], 1.36, 1.60, 0.07, 0.13, 60)
	acc.dos_seul = false
	acc.col_libre = true
	acc.fourrure_bord(pieces["mante"], 1.52, 1.66, 0.05, 0.09, -0.6, 1.4)
	acc.col_libre = false
	acc.poitrine_libre = false
	acc.fourrure_bord(pieces["bottes"], 0.30, 0.45, 0.06, 0.10, 1.0, 1.6)
	# lambeaux : ptéruges et tabard (devant / derrière)
	if LAMBEAUX_BLENDER.is_empty() or not ResourceLoader.exists(LAMBEAUX_BLENDER):
		acc.lambeaux(pieces["pteruges"], pieces["tunique"])
		acc.cape(pieces["mante"], pieces["tunique"])
	else:
		acc.lambeaux_blender(pieces["mante"], pieces["tunique"])
	acc.boucle(Vector3(0.0, 0.988, 0.152), 0.074)
	acc.fibule(plastron, Vector2(-0.085, 1.37))
	for nom in ["ceinture", "pteruges"]:
		pieces[nom].visible = false
	plastron.visible = false
	var bouclier: String = options.get("bouclier", "bras")
	if bouclier != "":
		acc.bouclier(bouclier)
	if options.get("epee", true):
		acc.epee()
	sq.add_child(acc.construire(rest_skin))
	var rd: SkeletonModifier3D = RAIDEUR.new()
	rd.name = "Raideur"
	sq.add_child(rd)
	AccDraugr.dy = 0.0
	racine.set_meta("draugr_nordique", true)
	return racine

## Passe 2 : amaigrit une pièce (position de repos) : chaque sommet est rapproché de l'axe de l'os porteur (bras, jambes) selon
## ses poids ; torse resserré en largeur. Mêmes poids d'os : aucune animation n'est touchée.
static func _maigrir(sq: Skeleton3D, mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null:
		return
	var segs := {}
	for nom: String in MAIGREUR:
		var i := sq.find_bone(nom)
		var fils := -1
		for j in sq.get_bone_count():
			if sq.get_bone_parent(j) == i:
				fils = j
				break
		if i >= 0 and fils >= 0:
			segs[i] = [sq.get_bone_global_rest(i).origin, sq.get_bone_global_rest(fils).origin, MAIGREUR[nom]]
	var torse := {}
	for nom in ["spine_01", "spine_02", "spine_03"]:
		torse[sq.find_bone(nom)] = true
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / v.size()
	var cache := {}
	for i in v.size():
		var p := v[i]
		var q := p
		for j in nb:
			var wj := w[i * nb + j]
			if wj <= 0.0:
				continue
			var b := bones[i * nb + j]
			if not cache.has(b):
				cache[b] = maxi(0, GuerrierNordique._os_de_bind(mi.skin, sq, b))
			var os_: int = cache[b]
			if segs.has(os_):
				var s: Array = segs[os_]
				var ab: Vector3 = s[1] - s[0]
				var t := clampf((p - s[0]).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
				q += ((s[0] + ab * t) - p) * (1.0 - float(s[2])) * wj
			elif torse.has(os_):
				q.x -= p.x * 0.09 * wj
		v[i] = q
	a[Mesh.ARRAY_VERTEX] = v
	for k in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		a[k] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	var mat := mi.get_surface_override_material(0)
	mi.mesh = m
	if mat:
		mi.set_surface_override_material(0, mat)

static func _habiller(mi: MeshInstance3D, m: ShaderMaterial) -> void:
	mi.visible = true
	mi.material_override = m

## Mèches Quaternius gardées, texture réduite à 64² et quantifiée dans la palette CHEVEUX du draugr (filasse gris-brun).
static var _tex_q := {}

static func _tex_cheveux(mi: MeshInstance3D) -> Texture2D:
	var m := mi.material_override as ShaderMaterial
	var src: Texture2D = m.get_shader_parameter("tex_base") if m else null
	if src == null:
		return DraugrTextures.tex("cheveux")
	if _tex_q.has(src.resource_path):
		return _tex_q[src.resource_path]
	var cle_res := "cheveux_q_" + src.resource_path.get_file().get_basename()
	var img := DraugrTextures.charger(cle_res)
	if img == null:
		img = src.get_image()
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
				img.set_pixel(x, y, DraugrTextures._c(DraugrTextures.CHEVEUX, DraugrTextures._ton(l, 5, x, y, 1951, 0.4)))
		img = GuerrierTextures.mips_pixel(img)
		DraugrTextures.sauver(cle_res, img)
	var t := ImageTexture.create_from_image(img)
	_tex_q[src.resource_path] = t
	return t

# ======================================================================================================== accessoires
class AccDraugr extends GuerrierNordique.Accessoires:
	## plages de sommets de la surface opaque qui LUISENT (yeux) : alpha de couleur 0
	var lueurs: Array[Vector2i] = []

	func _init(s: Skeleton3D) -> void:
		super(s)

	## touffes de surface seulement dans le dos (la poitrine reste en mailles, médaillon et baudrier lisibles)
	var dos_seul := false
	## troisième surface : jupe et cape modelées (texture Blender), découpée, sans contour
	var lam := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}

	func _poitrine(p: Vector3) -> bool:
		# poitrine dégagée plus large que le guerrier (pas de plastron de cuir : mailles, médaillon et baudrier à lire)
		return (poitrine_libre and p.z > 0.0 and absf(p.x) < 0.17 and p.y < 1.56) or (col_libre and p.z > 0.0 and absf(p.x) < 0.15) \
			or (dos_seul and p.z > -0.03)

	func _uvr(r: Rect2i, fx: float, fy: float) -> Vector2:
		return _uva(r.position.x + clampf(fx, 0.0, 1.0) * r.size.x, r.position.y + clampf(fy, 0.0, 1.0) * r.size.y)

	## Copie les triangles de `mi` retenus par garder(centre, normale) dans la surface `s`, UV calculés depuis la position de
	## repos (uvpos(p) -> UV d'atlas), sommets passés par deforme(p, n) ; peau d'os d'origine (bind -> os du squelette).
	func integrer_pos(mi: MeshInstance3D, s: Dictionary, garder: Callable, uvpos: Callable, deforme := Callable()) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var nb := bones.size() / v.size()
		var os_de := {}
		for t in range(0, idx.size(), 3):
			var p0 := v[idx[t]]
			var p1 := v[idx[t + 1]]
			var p2 := v[idx[t + 2]]
			if not garder.call((p0 + p1 + p2) / 3.0, (p2 - p0).cross(p1 - p0).normalized()):
				continue
			for k in 3:
				var i: int = idx[t + k]
				var p := v[i]
				s["uv"].append(uvpos.call(p))
				if deforme.is_valid():
					p = deforme.call(p, nrm[i])
				s["v"].append(p)
				s["n"].append(nrm[i])
				var bo := [0, 0, 0, 0]
				var wo := [0.0, 0.0, 0.0, 0.0]
				for j in mini(nb, 4):
					var b := bones[i * nb + j]
					if not os_de.has(b):
						os_de[b] = maxi(0, GuerrierNordique._os_de_bind(mi.skin, sq, b))
					bo[j] = os_de[b]
					wo[j] = w[i * nb + j]
				s["b"].append_array(PackedInt32Array(bo))
				s["w"].append_array(PackedFloat32Array(wo))

	# ------------------------------------------------------------ masque-crâne
	const MASQUE_X := 0.085
	const MASQUE_Y0 := 1.745
	const MASQUE_Y1 := 1.585

	static func _dans_masque(c: Vector3) -> bool:
		return c.y > MASQUE_Y1 + dy and c.y < MASQUE_Y0 + dy and c.z > 0.035 and absf(c.x) < MASQUE_X

	func masque(peau: MeshInstance3D, yeux: Array) -> void:
		var R := DraugrTextures.R_CRANE
		var deforme := func(p: Vector3, n: Vector3) -> Vector3:
			var q := p
			# orbites creusées (6 mm au centre)
			for e: Vector3 in yeux:
				var d := Vector2(q.x - e.x, (q.y - e.y) * 1.2).length()
				if d < 0.024:
					q.z -= 0.006 * (1.0 - d / 0.024)
			# nez aplati (cavité nasale peinte)
			if absf(q.x) < 0.024 and q.y > 1.635 + dy and q.y < 1.705 + dy:
				q.z = minf(q.z, 0.094)
			# joues creusées sous les pommettes
			var ax := absf(q.x)
			if ax > 0.035 and ax < 0.08 and q.y > 1.60 + dy and q.y < 1.66 + dy:
				var f := sin((ax - 0.035) / 0.045 * PI) * sin((q.y - 1.60 - dy) / 0.06 * PI)
				q.z -= 0.007 * f
				q.x *= 1.0 - 0.06 * f
			return q
		integrer_pos(peau, op, func(c: Vector3, n: Vector3) -> bool: return AccDraugr._dans_masque(c),
			func(p: Vector3) -> Vector2: return _uvr(R, (p.x + MASQUE_X) / (2.0 * MASQUE_X), (MASQUE_Y0 + dy - p.y) / (MASQUE_Y0 - MASQUE_Y1)), deforme)
		GuerrierNordique._filtrer(peau, func(c: Vector3, n: Vector3) -> bool: return not AccDraugr._dans_masque(c))

	# ------------------------------------------------------------ yeux luisants (os Head), dans les orbites creusées
	func yeux(centres: Array) -> void:
		var os_ := sq.find_bone("Head")
		var r := GuerrierTextures.R_OEIL
		var debut: int = op["v"].size()
		for c: Vector3 in centres:
			var cote := signf(c.x)
			var p := Vector3(c.x, c.y - 0.002, c.z - 0.001)
			var dx := Vector3(0.019, 0, -0.007 * cote)
			var dy := Vector3(0, 0.013, 0)
			_quad(op, p - dx - dy, p + dx - dy, p + dx + dy, p - dx + dy,
				_uva(r.position.x, r.end.y), _uva(r.end.x, r.end.y), _uva(r.end.x, r.position.y), _uva(r.position.x, r.position.y), os_, p - Vector3(0, 0, 0.05))
		lueurs.append(Vector2i(debut, op["v"].size()))

	# ------------------------------------------------------------ casque à nasal et crête (os Head)
	## Dôme à 12 pans x 4 rangs ajusté (rayon par direction) aux sommets de la tête et des cheveux + 1,3 cm ; bord plus bas
	## sur les côtés et derrière ; bandeau rivé, crête de l'avant à l'arrière, nasal jusqu'au bout du nez.
	const PANS := 12
	const RANGS := [0.0, 0.3, 0.56, 0.8, 0.94]

	func casque(peau: MeshInstance3D, cheveux: MeshInstance3D) -> void:
		var os_ := sq.find_bone("Head")
		var pts := PackedVector3Array()
		for mi: MeshInstance3D in [peau, cheveux]:
			if mi == null:
				continue
			for p: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if p.y > 1.66 + dy and absf(p.x) < 0.2:
					pts.append(p)
		var C := Vector3(0.0, 1.70 + dy, -0.012)
		var sommet := Vector3(0.0, 1.85 + dy, -0.012)
		for p in pts:
			sommet.y = maxf(sommet.y, p.y + 0.03)
		# bord : y selon l'angle (0 = devant) ; rayon horizontal ajusté
		var bord_y := func(th: float) -> float: return 1.728 + dy - 0.035 * (0.5 - 0.5 * cos(th))
		var anneau := []    # anneau[k][i] = point
		for k in RANGS.size():
			var ligne := []
			for i in PANS:
				var th := TAU * i / PANS
				var y0: float = bord_y.call(th)
				var y: float = lerpf(y0, sommet.y, RANGS[k])
				var dir := Vector3(sin(th), 0.0, cos(th))
				var rmax := 0.0
				for p in pts:
					if absf(p.y - y) > 0.03:
						continue
					var q := Vector3(p.x - C.x, 0.0, p.z - C.z)
					var l := q.length()
					if l < 1e-4 or q.dot(dir) / l < 0.94:
						continue
					rmax = maxf(rmax, l)
				if rmax <= 0.0:
					rmax = 0.1 * (1.0 - RANGS[k] * 0.9)
				ligne.append(Vector3(C.x, y, C.z) + dir * (rmax + 0.013))
			anneau.append(ligne)
		# rayon décroissant vers le sommet (profil en ogive, pas de creux)
		for k in range(1, RANGS.size()):
			for i in PANS:
				var lo: Vector3 = anneau[k - 1][i]
				var hi: Vector3 = anneau[k][i]
				var rl := Vector2(lo.x - C.x, lo.z - C.z).length()
				var rh := Vector2(hi.x - C.x, hi.z - C.z).length()
				var cible := minf(rh, rl * (1.0 - 0.18 * k))
				var d := Vector3(hi.x - C.x, 0, hi.z - C.z).normalized()
				anneau[k][i] = Vector3(C.x, hi.y, C.z) + d * maxf(cible, 0.02)
		var R := DraugrTextures.R_CASQUE
		var dedans := C + Vector3(0, 0.05, 0)
		for k in RANGS.size() - 1:
			for i in PANS:
				var j := (i + 1) % PANS
				var u0 := float(i) / PANS
				var u1 := float(i + 1) / PANS
				var v0 := 1.0 - float(RANGS[k])
				var v1 := 1.0 - float(RANGS[k + 1])
				_quad(op, anneau[k][i], anneau[k][j], anneau[k + 1][j], anneau[k + 1][i], _uvr(R, u0, v0), _uvr(R, u1, v0), _uvr(R, u1, v1), _uvr(R, u0, v1), os_, dedans)
		var kh := RANGS.size() - 1
		for i in PANS:
			var j := (i + 1) % PANS
			_tri(op, [anneau[kh][i], anneau[kh][j], sommet], [_uvr(R, float(i) / PANS, 0.06), _uvr(R, float(i + 1) / PANS, 0.06), _uvr(R, (i + 0.5) / PANS, 0.0)], os_, dedans)
		# bandeau rivé (bord épaissi : face extérieure + lèvre inférieure)
		var F := GuerrierTextures.R_FER
		for i in PANS:
			var j := (i + 1) % PANS
			var a0: Vector3 = anneau[0][i]
			var a1: Vector3 = anneau[0][j]
			var e0 := Vector3(a0.x - C.x, 0, a0.z - C.z).normalized() * 0.006
			var e1 := Vector3(a1.x - C.x, 0, a1.z - C.z).normalized() * 0.006
			var h0 := a0.lerp(anneau[1][i], 0.32)
			var h1 := a1.lerp(anneau[1][j], 0.32)
			var fu0 := F.position.x + 32.0 * i / PANS
			var fu1 := F.position.x + 32.0 * (i + 1) / PANS
			_quad(op, a0 + e0 - Vector3(0, 0.004, 0), a1 + e1 - Vector3(0, 0.004, 0), h1 + e1, h0 + e0, _uva(fu0, F.position.y + 22), _uva(fu1, F.position.y + 22), _uva(fu1, F.position.y + 6), _uva(fu0, F.position.y + 6), os_, dedans)
			_quad(op, a0 - Vector3(0, 0.004, 0), a1 - Vector3(0, 0.004, 0), a1 + e1 - Vector3(0, 0.004, 0), a0 + e0 - Vector3(0, 0.004, 0), _uva(fu0, F.position.y + 30), _uva(fu1, F.position.y + 30), _uva(fu1, F.position.y + 31), _uva(fu0, F.position.y + 31), os_, dedans + Vector3(0, 0.2, 0))
		# crête : arête de l'avant (i = 0) à l'arrière (i = PANS/2) en passant par le sommet, en toit (2 pans)
		var meridien := []
		for k in RANGS.size():
			meridien.append(anneau[k][0])
		meridien.append(sommet)
		for k in range(RANGS.size() - 1, -1, -1):
			meridien.append(anneau[k][PANS / 2])
		for k in meridien.size() - 1:
			var p0: Vector3 = meridien[k]
			var p1: Vector3 = meridien[k + 1]
			var n0 := (p0 - C).normalized()
			var n1 := (p1 - C).normalized()
			var lx := Vector3(0.011, 0, 0)
			var v0 := F.position.y + 4.0 + k * 3.0
			var v1 := v0 + 3.0
			_quad(op, p0 - lx, p1 - lx, p1 + n1 * 0.009, p0 + n0 * 0.009, _uva(F.position.x + 2, v0), _uva(F.position.x + 2, v1), _uva(F.position.x + 12, v1), _uva(F.position.x + 12, v0), os_, C)
			_quad(op, p0 + n0 * 0.009, p1 + n1 * 0.009, p1 + lx, p0 + lx, _uva(F.position.x + 12, v0), _uva(F.position.x + 12, v1), _uva(F.position.x + 26, v1), _uva(F.position.x + 26, v0), os_, C)
		# nasal : du bandeau au bout du nez (aplati), en léger biseau
		var haut: Vector3 = anneau[0][0] + Vector3(0, 0.01, 0.004)
		var bas := Vector3(0.0, 1.645 + dy, 0.104)
		_boite_libre([haut + Vector3(-0.012, 0, 0), haut + Vector3(0.012, 0, 0), bas + Vector3(0.009, 0, 0), bas + Vector3(-0.009, 0, 0)], 0.007, os_, F)

	## Plaque épaisse : contour avant a b c d (dans l'ordre), épaisseur vers l'arrière (-Z), 5 faces visibles.
	func _boite_libre(q: Array, ep: float, os_: int, r: Rect2i) -> void:
		var arr := Vector3(0, 0, -ep)
		var b := [q[0] + arr, q[1] + arr, q[2] + arr, q[3] + arr]
		var dedans: Vector3 = (q[0] + q[1] + q[2] + q[3]) / 4.0 + arr * 0.5
		var u0 := _uva(r.position.x + 2, r.position.y + 2)
		var u1 := _uva(r.position.x + 30, r.position.y + 2)
		var u2 := _uva(r.position.x + 30, r.position.y + 14)
		var u3 := _uva(r.position.x + 2, r.position.y + 14)
		_quad(op, q[0], q[1], q[2], q[3], u0, u1, u2, u3, os_, dedans)
		for k in 4:
			var k1 := (k + 1) % 4
			_quad(op, q[k], b[k], b[k1], q[k1], u0, u1, u2, u3, os_, dedans)

	# ------------------------------------------------------------ épaulières en DÔME (passe 2)
	## Calotte de fer bombée (ellipsoïde à 9 pans, 4 rangs + collerette évasée) posée sur l'épaule, rivets peints en couronne ;
	## poids repris de la mante au sommet voisin : elle suit l'épaule dans toutes les animations.
	func epaulieres(mante: MeshInstance3D) -> void:
		var R := DraugrTextures.R_EPAUL
		var am := mante.mesh.surface_get_arrays(0)
		var N := 9
		var phis := [0.0, 0.5, 0.95, 1.3, 1.5]
		for nom in ["upperarm_l", "upperarm_r"]:
			var o := sq.get_bone_global_rest(sq.find_bone(nom)).origin
			var sg := signf(o.x)
			# sommet de la mante au-dessus de l'épaule : la coupole se pose dessus
			var ytop := o.y + 0.08
			for q: Vector3 in am[Mesh.ARRAY_VERTEX]:
				if absf(q.x - o.x) < 0.06 and absf(q.z - o.z) < 0.08:
					ytop = maxf(ytop, q.y)
			var C := Vector3(o.x * 0.97, ytop - 0.05, o.z + 0.005)
			var d := Vector3(sg * 0.50, 0.87, 0.0).normalized()
			var zz := Vector3(0, 0, 1)
			var ww := d.cross(zz) * -sg
			var pt := func(k: int, i: int) -> Vector3:
				var ph: float = phis[k]
				var th := TAU * i / N
				var lat := 1.0 + (0.14 if k == phis.size() - 1 else 0.0)
				return C + d * cos(ph) * 0.105 + (zz * cos(th) * 0.125 + ww * sin(th) * 0.128) * sin(ph) * lat
			var uv := func(k: int, i: int) -> Vector2:
				return _uva(R.position.x + float(R.size.x) * i / N, R.position.y + float(R.size.y) * float(phis[k]) / 1.5)
			var pw := func(p: Vector3) -> Array: return _poids_proche(mante, am, p)
			var dedans := C - d * 0.04
			for i in N:
				var j := (i + 1) % N
				var j_u := i + 1
				var ua: Vector2 = uv.call(0, i)
				_tri(op, [pt.call(0, 0), pt.call(1, i), pt.call(1, j)], [Vector2(ua.x, _uva(0, R.position.y).y), uv.call(1, i), uv.call(1, j_u)],
					[pw.call(pt.call(0, 0)), pw.call(pt.call(1, i)), pw.call(pt.call(1, j))], dedans)
				for k in range(1, phis.size() - 1):
					var a: Vector3 = pt.call(k, i)
					var b: Vector3 = pt.call(k, j)
					var c: Vector3 = pt.call(k + 1, j)
					var e: Vector3 = pt.call(k + 1, i)
					_quad(op, a, b, c, e, uv.call(k, i), uv.call(k, j_u), uv.call(k + 1, j_u), uv.call(k + 1, i), [pw.call(a), pw.call(b), pw.call(c), pw.call(e)], dedans)

	# ------------------------------------------------------------ poitrine décharnée : côtes, sternum, clavicules (passe 2)
	## Altitude de la surface de la peau (devant) au point (x, y), par le sommet de peau le plus proche en (x, y).
	func _z_peau(peau: MeshInstance3D, x: float, y: float) -> float:
		var v: PackedVector3Array = peau.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var z := -9.0
		var best := 1e9
		for p in v:
			if p.z > 0.0:
				var d := (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y)
				if d < best:
					best = d
					z = p.z
		return z if best < 0.0016 else 0.10

	func cotes(peau: MeshInstance3D) -> void:
		var os_ := sq.find_bone("spine_03")
		var R := DraugrTextures.R_OSS
		var os_u := func(fx: float, fy: float, moitie: int) -> Vector2: return _uva(R.position.x + moitie * 32 + fx * 31.0, R.position.y + fy * 31.0)
		# fond : chair desséchée creusée entre les côtes (deux panneaux, un par côté)
		for sg: float in [-1.0, 1.0]:
			var pts := []
			for kx in 3:
				var col := []
				for ky in 3:
					var x := sg * (0.012 + kx * 0.046)
					var y := 1.25 + ky * 0.115
					col.append(Vector3(x, y, _z_peau(peau, x, y) + 0.004 - kx * 0.003))
				pts.append(col)
			for kx in 2:
				for ky in 2:
					_quad(op, pts[kx][ky], pts[kx + 1][ky], pts[kx + 1][ky + 1], pts[kx][ky + 1], os_u.call(0, 0, 1), os_u.call(1, 0, 1), os_u.call(1, 1, 1), os_u.call(0, 1, 1), os_, Vector3(0, 1.4, 0.0))
		# côtes : bandes courbes, se courbant vers l'arrière
		for k in 5:
			var y0 := 1.44 + dy * 0.7 - k * 0.05
			for sg: float in [-1.0, 1.0]:
				var xs := [0.016, 0.050, 0.082, 0.110]
				for s in 3:
					var xa: float = xs[s] * sg
					var xb: float = xs[s + 1] * sg
					var ya := y0 - 0.010 * s - 0.0008
					var yb := y0 - 0.010 * (s + 1) - 0.0008
					var za := _z_peau(peau, xa, ya) + 0.010 - s * 0.003
					var zb := _z_peau(peau, xb, yb) + 0.010 - (s + 1) * 0.003
					var h := 0.0125
					_quad(op, Vector3(xa, ya + h, za), Vector3(xb, yb + h, zb), Vector3(xb, yb, zb), Vector3(xa, ya, za), os_u.call(0, 0, 0), os_u.call(1, 0, 0), os_u.call(1, 1, 0), os_u.call(0, 1, 0), os_, Vector3(xa, ya, za - 0.12))
		# sternum
		for s in 3:
			var ya := 1.50 + dy - s * 0.085
			var yb := ya - 0.085
			var za := _z_peau(peau, 0.0, ya) + 0.011
			var zb := _z_peau(peau, 0.0, yb) + 0.011
			_quad(op, Vector3(-0.011, ya, za), Vector3(0.011, ya, za), Vector3(0.011, yb, zb), Vector3(-0.011, yb, zb), os_u.call(0, 0, 0), os_u.call(1, 0, 0), os_u.call(1, 1, 0), os_u.call(0, 1, 0), os_, Vector3(0, ya, za - 0.12))
		# clavicules : barres en V légèrement relevées vers les épaules
		for sg: float in [-1.0, 1.0]:
			var pa := Vector3(sg * 0.012, 1.52 + dy, _z_peau(peau, 0.0, 1.52 + dy) + 0.012)
			var pb := Vector3(sg * 0.075, 1.545 + dy, _z_peau(peau, sg * 0.075, 1.54 + dy) + 0.014)
			var pc := Vector3(sg * 0.140, 1.545 + dy, _z_peau(peau, sg * 0.13, 1.54 + dy) + 0.004)
			for seg: Array in [[pa, pb], [pb, pc]]:
				var a: Vector3 = seg[0]
				var b: Vector3 = seg[1]
				var h := Vector3(0, 0.014, 0)
				var ep := Vector3(0, 0.0, 0.010)
				_quad(op, a + h, b + h, b, a, os_u.call(0, 0, 0), os_u.call(1, 0, 0), os_u.call(1, 1, 0), os_u.call(0, 1, 0), os_, a - Vector3(0, 0, 0.12))
				_quad(op, a + h + ep * 0.0, b + h, b + h - ep, a + h - ep, os_u.call(0, 0, 0), os_u.call(1, 0, 0), os_u.call(1, 0.5, 0), os_u.call(0, 0.5, 0), os_, a - Vector3(0, 0.12, 0))

	# ------------------------------------------------------------ lambeaux : ptéruges + tabard devant / derrière
	func lambeaux(pteruges: MeshInstance3D, tunique: MeshInstance3D) -> void:
		var R := DraugrTextures.R_TABARD
		var D := Vector2(GuerrierTextures.DECOUPES)
		var tour := func(p: Vector3) -> Vector2:
			var u := (atan2(p.x, p.z) / TAU + 0.5) * R.size.x
			return Vector2(R.position.x + u, R.position.y + clampf((0.98 - p.y) / 0.34, 0.0, 1.0) * R.size.y) / D
		integrer_pos(pteruges, dec, func(c: Vector3, n: Vector3) -> bool: return true, tour,
			func(p: Vector3, n: Vector3) -> Vector3: return p + n * 0.004)
		# tabard : panneaux devant et derrière de la jupe de mailles, gonflés de 2,2 cm et allongés de 12 cm vers le genou
		var panneau := func(p: Vector3) -> Vector2:
			var u := clampf((p.x + 0.15) / 0.30, 0.0, 1.0) * R.size.x * 0.5 + (0.0 if p.z > 0.0 else R.size.x * 0.5)
			return Vector2(R.position.x + u, R.position.y + clampf((1.0 - p.y) / 0.42, 0.0, 1.0) * R.size.y) / D
		integrer_pos(tunique, dec, func(c: Vector3, n: Vector3) -> bool: return c.y < 0.99 and absf(c.x) < 0.15 and absf(n.z) > 0.5 and signf(n.z) == signf(c.z + 0.03),
			panneau, func(p: Vector3, n: Vector3) -> Vector3:
				var q := p + n * 0.022
				if q.y < 0.86:
					q.y -= (0.86 - q.y) * 0.6
				return q)
		# seconde couche (jupe en lambeaux de la référence) : panneau plus bas et plus lâche, par-dessus, texture décalée
		var panneau2 := func(p: Vector3) -> Vector2:
			var u := clampf((p.x + 0.15) / 0.30, 0.0, 1.0) * R.size.x * 0.5 + (0.0 if p.z > 0.0 else R.size.x * 0.5)
			return Vector2(R.position.x + fposmod(u + R.size.x * 0.31, R.size.x), R.position.y + clampf((0.93 - p.y) / 0.50, 0.0, 1.0) * R.size.y) / D
		integrer_pos(tunique, dec, func(c: Vector3, n: Vector3) -> bool: return c.y < 0.93 and c.y > 0.55 and absf(c.x) < 0.17 and absf(n.z) > 0.5 and signf(n.z) == signf(c.z + 0.03),
			panneau2, func(p: Vector3, n: Vector3) -> Vector3:
				var q := p + n * 0.040
				q.y -= (0.93 - q.y) * 0.35 + 0.04
				return q)

	# ------------------------------------------------------------ jupe et cape modelées dans Blender
	static var _lamb_cache := {}
	## décalage vertical de la tête / du cou (corps femme : -0,045 m), posé par DraugrNordique.creer
	static var dy := 0.0

	## Lit lambeaux.glb (pièces légères « lambeaux_jupe » et « lambeaux_cape », UV de lambeaux_bake.png) et les verse dans la
	## troisième surface (lam), poids d'os copiés du sommet le plus proche de la mante (haut) ou de la tunique (bas).
	func lambeaux_blender(mante: MeshInstance3D, tunique: MeshInstance3D) -> void:
		if not _lamb_cache.has("arrays"):
			var scene := (load(DraugrNordique.LAMBEAUX_BLENDER) as PackedScene).instantiate()
			var res := []
			for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
				res.append([mi.mesh.surface_get_arrays(0), String(mi.name).contains("cape")])
			scene.free()
			_lamb_cache["arrays"] = res
		var am := mante.mesh.surface_get_arrays(0)
		var at := tunique.mesh.surface_get_arrays(0)
		var cache := {}
		for entree: Array in _lamb_cache["arrays"]:
			var a: Array = entree[0]
			var est_cape: bool = entree[1]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			for t in range(0, idx.size(), 3):
				var p: Array = [v[idx[t]], v[idx[t + 1]], v[idx[t + 2]]]
				var uvs: Array = [uv[idx[t]], uv[idx[t + 1]], uv[idx[t + 2]]]
				var pw: Array = []
				for k in 3:
					var key := idx[t + k]
					var ck := Vector3i(((p[k] as Vector3) * 1000.0).round()) + Vector3i(0, 0, 100000 if est_cape else 0)
					if not cache.has(ck):
						# poids pris au NIVEAU D'ATTACHE de la lanière (hanches / épaules) : elle bouge d'un bloc, sans cisaillement
						var q: Vector3 = p[k]
						cache[ck] = _poids_proche(mante, am, Vector3(q.x * 0.25, 1.30, q.z)) if est_cape else _poids_proche(tunique, at, Vector3(q.x * 0.3, 0.97, q.z))
					pw.append(cache[ck])
				var c: Vector3 = (p[0] + p[1] + p[2]) / 3.0
				_tri(lam, p, uvs, pw, Vector3(0.0, c.y, -0.03))

	# ------------------------------------------------------------ bouclier réduit
	## Passe 2 : copie du bouclier du guerrier à l'échelle BOUCLIER_ECH (texture gris-noir fendue, cerclage rouillé).
	func bouclier(ou: String) -> void:
		var os_ := sq.find_bone("lowerarm_l" if ou == "bras" else "spine_03")
		var tr: Transform3D
		var rest := sq.get_bone_global_rest(os_)
		if ou == "bras":
			# au repos (pose en T), l'avant-bras gauche est horizontal vers +X : le bouclier se tient sur le dessus de
			# l'avant-bras (normale +Y au repos = vers l'extérieur une fois le bras baissé), haut du bouclier vers le coude.
			var cx := (rest.origin.x + sq.get_bone_global_rest(sq.find_bone("hand_l")).origin.x) * 0.5
			var b := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0))   # colonnes : x local, y local (haut), z local (face)
			var rg: Vector3 = GuerrierNordique.reglage_bouclier
			b = Basis(Vector3.RIGHT, deg_to_rad(rg.y)) * b * Basis(Vector3.FORWARD, deg_to_rad(rg.z))
			tr = Transform3D(b.scaled(Vector3.ONE * DraugrNordique.BOUCLIER_ECH), Vector3(cx, rest.origin.y + rg.x * 0.78, rest.origin.z + 0.02))   # passe 2 : 70 % de la taille, plus près du bras décharné
		else:
			tr = Transform3D((Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(8.0))).scaled(Vector3.ONE * DraugrNordique.BOUCLIER_ECH), Vector3(0.0, 1.22, -0.21))
		sq.set_meta("bouclier", [os_, tr])     # contrôle des traversées (outils/test_guerrier.gd)
		var n := 14
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

	# ------------------------------------------------------------ épée large ébréchée (passe 2)
	func epee() -> void:
		var os_ := sq.find_bone("hand_r")
		var tr := sq.get_bone_global_rest(os_) * PRISE
		sq.set_meta("epee", [os_, tr])
		var l := GuerrierTextures.R_LAME
		var f := GuerrierTextures.R_FER
		# lame de draugr : large (9 cm), à peine effilée, bords ébréchés (largeurs gauche / droite décalées), épaisse, rouillée
		# [y, demi-largeur gauche, demi-largeur droite, demi-épaisseur]
		var sec := [[0.105, 0.036, 0.036, 0.008], [0.20, 0.044, 0.044, 0.008], [0.33, 0.048, 0.048, 0.008], [0.38, 0.048, 0.039, 0.0075],
			[0.43, 0.040, 0.047, 0.0075], [0.51, 0.045, 0.045, 0.007], [0.57, 0.036, 0.044, 0.007], [0.62, 0.044, 0.038, 0.0065],
			[0.69, 0.041, 0.040, 0.006], [0.77, 0.030, 0.031, 0.005]]
		var pointe := Vector3(0.002, 0.875, 0)
		for k in sec.size():
			var A: Array = sec[k]
			var pa := [Vector3(-A[1], A[0], 0), Vector3(0, A[0], A[3]), Vector3(A[2], A[0], 0), Vector3(0, A[0], -A[3])]
			var va: float = l.position.y + l.size.y * (A[0] - 0.105) / 0.77
			if k == sec.size() - 1:
				for i in 4:
					var u0 := l.position.x + (0.0 if i < 2 else 8.0) + (0.0 if i % 2 == 0 else 8.0)
					_tri(op, [tr * pa[i], tr * pa[(i + 1) % 4], tr * pointe], [_uva(u0, va), _uva(u0 + 7.9, va), _uva(u0 + 4.0, l.position.y + l.size.y - 0.5)], os_, tr * Vector3(0, A[0], 0))
				break
			var B: Array = sec[k + 1]
			var pb := [Vector3(-B[1], B[0], 0), Vector3(0, B[0], B[3]), Vector3(B[2], B[0], 0), Vector3(0, B[0], -B[3])]
			var vb: float = l.position.y + l.size.y * (B[0] - 0.105) / 0.77
			for i in 4:
				var u0 := l.position.x + (0.0 if i % 2 == 0 else 8.0)
				var u1 := u0 + 7.9
				_quad(op, tr * pa[i], tr * pa[(i + 1) % 4], tr * pb[(i + 1) % 4], tr * pb[i], _uva(u0, va), _uva(u1, va), _uva(u1, vb), _uva(u0, vb), os_, tr * Vector3(0, (A[0] + B[0]) * 0.5, 0))
		# garde simple : barre droite épaisse
		_boite(Vector3(-0.088, 0.076, -0.020), Vector3(0.088, 0.106, 0.020), tr, os_, f)
		# poignée : prisme à 6 pans, pommeau trapu
		_tube(op, tr * Vector3(0, 0.078, 0), tr * Vector3(0, -0.005, 0), 0.016, 0.015, 6, os_, GuerrierTextures.R_POIGNEE, 1)
		_boite(Vector3(-0.036, -0.042, -0.019), Vector3(0.036, -0.004, 0.019), tr, os_, f)

	# ------------------------------------------------------------ cape en lambeaux (dos) : lanières pointues (passe 2)
	## Deux rangées de lanières géométriques (rectangle + pointe), longueurs et pointes irrégulières, pendues aux épaules.
	func cape(mante: MeshInstance3D, tunique: MeshInstance3D) -> void:
		var R := DraugrTextures.R_LAMB
		var D := Vector2(GuerrierTextures.DECOUPES)
		var am := mante.mesh.surface_get_arrays(0)
		var at := tunique.mesh.surface_get_arrays(0)
		var rang := 0
		for r in 3:
			var n := 8 - r % 2 + (r / 2)
			for i in n:
				var xc := (-0.165 + 0.33 * (i + 0.5) / n) * (1.0 - r * 0.05)
				var w := 0.38 / n * (1.0 + 0.25 * (_h(i + r * 9) - 0.5))
				var y0 := 1.43 - r * 0.17
				var lg := 0.34 + _h(i + r * 17) * 0.50 - r * 0.06
				var z0 := -0.125 - r * 0.018
				var ymid := y0 - lg * 0.62
				var ytip := y0 - lg
				var tip_dx := (_h(i + 40 + r) - 0.5) * 0.04
				var zb := z0 - 0.045 - lg * 0.06
				var pts := [Vector3(xc - w * 0.5, y0, z0), Vector3(xc + w * 0.5, y0, z0), Vector3(xc + w * 0.47, ymid, zb), Vector3(xc - w * 0.47, ymid, zb), Vector3(xc + tip_dx, ytip, zb - 0.03)]
				var pw := []
				for p: Vector3 in pts:
					pw.append(_poids_proche(mante, am, p) if p.y > 1.12 else _poids_proche(tunique, at, p))
				var u0 := (R.position.x + (i % 2) * 16.0) / D.x
				var u1 := u0 + 16.0 / D.x
				var v0 := R.position.y / D.y
				var v1 := (R.position.y + R.size.y * 0.62) / D.y
				var v2 := (R.position.y + R.size.y) / D.y
				var dentro := Vector3(xc, y0 - lg * 0.5, 0.0)
				_quad(dec, pts[0], pts[1], pts[2], pts[3], Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), [pw[0], pw[1], pw[2], pw[3]], dentro)
				var mid: Vector3 = (pts[3] + pts[2]) * 0.5
				var ta := Vector3(xc - w * 0.26 + tip_dx, ytip + lg * 0.08 * _h(i + 70 + r), zb - 0.03)
				var tb := Vector3(xc + w * 0.26 + tip_dx, ytip + lg * 0.20 * _h(i + 80 + r), zb - 0.03)
				var pm := _poids_proche(tunique, at, mid) if mid.y <= 1.12 else _poids_proche(mante, am, mid)
				var pa := _poids_proche(tunique, at, ta) if ta.y <= 1.12 else _poids_proche(mante, am, ta)
				var pb := _poids_proche(tunique, at, tb) if tb.y <= 1.12 else _poids_proche(mante, am, tb)
				var um := (u0 + u1) * 0.5
				_tri(dec, [pts[3], mid, ta], [Vector2(u0, v1), Vector2(um, v1), Vector2(u0 + (u1 - u0) * 0.25, v2)], [pw[3], pm, pa], dentro)
				_tri(dec, [mid, pts[2], tb], [Vector2(um, v1), Vector2(u1, v1), Vector2(u0 + (u1 - u0) * 0.75, v2)], [pm, pw[2], pb], dentro)

	# ------------------------------------------------------------ assemblage (matériaux du draugr, lueur des yeux)
	func construire(skin: Skin) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		var s_op := -1
		var s_dec := -1
		var s_lam := -1
		for s: Dictionary in [op, dec, lam]:
			if s["v"].is_empty():
				continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = s["v"]
			arr[Mesh.ARRAY_NORMAL] = s["n"]
			arr[Mesh.ARRAY_TEX_UV] = s["uv"]
			arr[Mesh.ARRAY_BONES] = s["b"]
			arr[Mesh.ARRAY_WEIGHTS] = s["w"]
			if s == op:
				var col := PackedColorArray()
				col.resize(s["v"].size())
				col.fill(Color(1, 1, 1, 1))
				for l in lueurs:
					for i in range(l.x, l.y):
						col[i] = Color(1, 1, 1, 0)
				arr[Mesh.ARRAY_COLOR] = col
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			if s == op:
				s_op = mesh.get_surface_count() - 1
			elif s == dec:
				s_dec = mesh.get_surface_count() - 1
			else:
				s_lam = mesh.get_surface_count() - 1
		var mi := MeshInstance3D.new()
		mi.name = "accessoires"
		mi.mesh = mesh
		mi.skin = skin
		mi.skeleton = NodePath("..")
		if s_op >= 0:
			mi.set_surface_override_material(s_op, DraugrNordique.materiau(DraugrTextures.tex("accessoires"), false, false, true))
		if s_dec >= 0:
			mi.set_surface_override_material(s_dec, DraugrNordique.materiau(DraugrTextures.tex("decoupes"), true, true, false))
		if s_lam >= 0:
			mi.set_surface_override_material(s_lam, DraugrNordique.materiau(DraugrTextures.tex("lambeaux"), true, true, false))
		return mi
