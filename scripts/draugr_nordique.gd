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
##   DraugrNordique.creer({"bouclier": "bras" | "dos" | "", "epee": true}) -> Node3D (contrat de Humain.creer)

const SHADER := preload("res://shaders/ps1_draugr.gdshader")
const LUEUR := Vector3(3.0, 5.4, 7.6)
const TEINTE_CHAIR := Color(0.80, 0.74, 0.64)
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
	var app := {"corps": "homme", "barbe": false, "cheveux": "Hair_Long", "teinte_cheveux": Color(0.8, 0.76, 0.7), "peau": TEINTE_CHAIR,
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
	var sc: MeshInstance3D = pieces.get("SuperHero_Male")
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
			m2.set_shader_parameter("saturation", 0.18)
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
		GuerrierNordique._filtrer(mi_ch, func(c: Vector3, n: Vector3) -> bool: return n.dot(c - tete) > -0.002 and not (c.z > 0.03 and c.y > 1.64) and not (c.z > 0.0 and c.y < 1.54))
		GuerrierNordique._decimer(mi_ch, func(p: Vector3) -> float: return 0.03)
		mi_ch.material_override = materiau(_tex_cheveux(mi_ch), true, false, true, "cheveux_draugr")
	# -- pièces ajoutées
	var plastron := GuerrierNordique._plastron(sq, pieces["tunique"])
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
	acc.casque(pe, mi_ch)
	# épaulières puis fourrure (frange sous les épaulières, touffes dans le dos, col)
	acc.epaulieres(pieces["mante"])
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
	acc.lambeaux(pieces["pteruges"], pieces["tunique"])
	acc.boucle(Vector3(0.0, 0.988, 0.152), 0.062)
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
	racine.set_meta("draugr_nordique", true)
	return racine

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
		return c.y > MASQUE_Y1 and c.y < MASQUE_Y0 and c.z > 0.035 and absf(c.x) < MASQUE_X

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
			if absf(q.x) < 0.024 and q.y > 1.635 and q.y < 1.705:
				q.z = minf(q.z, 0.094)
			# joues creusées sous les pommettes
			var ax := absf(q.x)
			if ax > 0.035 and ax < 0.08 and q.y > 1.60 and q.y < 1.66:
				var f := sin((ax - 0.035) / 0.045 * PI) * sin((q.y - 1.60) / 0.06 * PI)
				q.z -= 0.007 * f
				q.x *= 1.0 - 0.06 * f
			return q
		integrer_pos(peau, op, func(c: Vector3, n: Vector3) -> bool: return AccDraugr._dans_masque(c),
			func(p: Vector3) -> Vector2: return _uvr(R, (p.x + MASQUE_X) / (2.0 * MASQUE_X), (MASQUE_Y0 - p.y) / (MASQUE_Y0 - MASQUE_Y1)), deforme)
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
				if p.y > 1.66 and absf(p.x) < 0.2:
					pts.append(p)
		var C := Vector3(0.0, 1.70, -0.012)
		var sommet := Vector3(0.0, 1.85, -0.012)
		for p in pts:
			sommet.y = maxf(sommet.y, p.y + 0.03)
		# bord : y selon l'angle (0 = devant) ; rayon horizontal ajusté
		var bord_y := func(th: float) -> float: return 1.728 - 0.035 * (0.5 - 0.5 * cos(th))
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
		var bas := Vector3(0.0, 1.645, 0.104)
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

	# ------------------------------------------------------------ épaulières (coques de lames sur la mante)
	## Triangles de la mante sur les épaules (|x| > 0,14, y > 1,36, -0,15 < z < 0,13 : le dessus de l'épaule, tournés vers l'extérieur), gonflés de 2,4 cm (+ bombés
	## vers le haut au centre), mêmes poids que la mante : elles suivent les épaules dans toutes les animations.
	func epaulieres(mante: MeshInstance3D) -> void:
		var R := DraugrTextures.R_EPAUL
		var centre := Vector3(0.0, 1.42, -0.02)
		var garder := func(c: Vector3, n: Vector3) -> bool:
			return absf(c.x) > 0.14 and c.y > 1.36 and c.z > -0.15 and c.z < 0.13 and n.dot(c - centre) > 0.0
		var deforme := func(p: Vector3, n: Vector3) -> Vector3:
			var bombe := clampf((absf(p.x) - 0.12) / 0.18, 0.0, 1.0)
			return p + n * (0.020 + 0.012 * sin(bombe * PI)) + Vector3(signf(p.x) * 0.01 * bombe, 0.004, 0)
		integrer_pos(mante, op, garder, func(p: Vector3) -> Vector2: return _uvr(R, (p.z + 0.23) / 0.42, (1.64 - p.y) / 0.32), deforme)

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

	# ------------------------------------------------------------ assemblage (matériaux du draugr, lueur des yeux)
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
			else:
				s_dec = mesh.get_surface_count() - 1
		var mi := MeshInstance3D.new()
		mi.name = "accessoires"
		mi.mesh = mesh
		mi.skin = skin
		mi.skeleton = NodePath("..")
		if s_op >= 0:
			mi.set_surface_override_material(s_op, DraugrNordique.materiau(DraugrTextures.tex("accessoires"), false, false, true))
		if s_dec >= 0:
			mi.set_surface_override_material(s_dec, DraugrNordique.materiau(DraugrTextures.tex("decoupes"), true, true, false))
		return mi
