class_name CrypteDecor
extends RefCounted
## Décor de la crypte (lot 7a) : structure modulaire, mobilier, petits objets, lumières.
##
## Principes (règles de l'utilisateur + bible) :
## - grille de 1, 2 et 4 m ; les surfaces sont des quads par morceaux de 4 m au plus ; UV = position en mètres
##   divisée par la taille de tuile → densité de texels UNIFORME (16 texels/m pour la pierre, 32 pour bois/fer/objets) ;
## - le maillage est fusionné par cellule de 8 m et par matériau : peu d'appels de dessin, culling par cellule, et
##   moins de 8 lumières par objet (limite du renderer mobile) ;
## - aucune collision n'est ajoutée au passage du joueur : les collisions d'origine (sol, plafond, murs, linteaux,
##   piliers, estrade, sarcophage) sont refaites à l'identique ; seules quelques pièces contre les murs en ont une ;
## - lumières : OmniLight3D courtes et fortement atténuées, sans ombre ; flammes = sprites pixel art animés ;
##   halos = cartes additives à anneaux posterisés (net, pas de glow).

const CASE := 8.0
const FEU := Color(1.0, 0.56, 0.24)

const TUILE := {
	"mur0": 4.0, "mur1": 4.0, "mur2": 4.0, "dalle0": 4.0, "dalle1": 4.0, "voute": 4.0,
	"bois": 2.0, "fer": 1.0, "lame": 1.0, "gravure": 2.0, "argile": 1.0, "os": 0.5, "parchemin": 0.5,
	"toile": 1.0, "noir": 1.0, "halo": 1.0, "halo_f": 1.0, "rai": 1.0, "braise": 1.0,
	# donjon (agrandissement) : pierre givrée / glace, ossuaire, or
	"mur3": 4.0, "mur4": 4.0, "dalle3": 4.0, "dalle4": 4.0, "ossuaire": 4.0, "or": 0.5,
}

const CRYPTE_SHADER := preload("res://shaders/crypte.gdshader")
const FLAMME_SHADER := preload("res://shaders/crypte_flamme.gdshader")

var racine: Node3D
var corps: StaticBody3D
var rng := RandomNumberGenerator.new()

var _mats := {}
var _tex := {}
var _bufs := {}
var _fait := {}
var lumieres: Array = []       # [OmniLight3D, énergie, phase]
var toutes: Array = []         # toutes les OmniLight3D du décor (allumées selon la position du joueur, voir tertre.gd)
var _flammes_def: Array = []    # [position, échelle, phase] : fusionnées en MultiMesh par cellule dans finir()
var _nb_pieces := 0
## Donjon : remplace une matière par une autre dans quad() (« mur0 » -> « mur4 » : tout un décor passe en glace d'un coup).
var theme := {}
## Hauteur du sol sous les sommets, codée dans l'alpha de la couleur de sommet (1 + y/20, y relatif au sol de la crypte) :
## le shader en tire la bande de crasse du pied de mur, pour les étages et les escaliers.
var niveau_a := 1.0

const RELIEF := {"mur0": 0.75, "mur1": 0.75, "mur2": 0.75, "dalle0": 0.8, "dalle1": 0.8, "voute": 0.7, "bois": 0.8, "fer": 0.7, "gravure": 1.0,
	"mur3": 0.8, "mur4": 0.9, "dalle3": 0.8, "dalle4": 0.9, "ossuaire": 1.0}
const AVEC_MIPS := ["mur0", "mur1", "mur2", "dalle0", "voute", "bois", "fer", "lame", "gravure", "argile", "os", "parchemin", "toile",
	"mur3", "mur4", "dalle3", "dalle4", "ossuaire", "or"]
const SANS_MIPS := ["halo", "rai", "flamme"]

var _taches := {}    # nom -> id de tâche ; les images sont peintes dans des fils d'exécution pendant que le plan se construit
var _images := {}    # nom -> Image (tableau d'un seul élément par tâche : pas d'écriture concurrente dans un même conteneur)

func _init(parent: Node3D, solide: StaticBody3D, partage: CrypteDecor = null) -> void:
	racine = parent
	corps = solide
	rng.seed = 7007
	if partage != null:
		# second décor (le donjon, bâti dans un fil d'exécution) : mêmes images, déjà peintes ; ses propres matériaux
		partage.attendre_tout()
		_images = partage._images
		_tex = partage._tex.duplicate()
		rng.seed = 7013
		return
	for nom in AVEC_MIPS + SANS_MIPS:
		var cible: Array = [null]
		_images[nom] = cible
		_taches[nom] = WorkerThreadPool.add_task(_peindre.bind(nom, cible))

func _peindre(nom: String, cible: Array) -> void:
	# précalculées par outils/generer_crypte.gd dans assets/crypte/*.res (version vérifiée) ; repli : calcul
	var base := "%s/%s" % [CrypteTextures.DOSSIER, nom]
	if ResourceLoader.exists(base + ".res"):
		var a: Image = ResourceLoader.load(base + ".res")
		if a != null and a.get_meta("version", -1) == CrypteTextures.VERSION:
			cible[0] = a
			cible.append(ResourceLoader.load(base + "_nm.res") if ResourceLoader.exists(base + "_nm.res") else null)
			return
	var paire := CrypteTextures.paire(nom)
	cible[0] = CrypteTextures.mips_image(paire[0]) if nom in AVEC_MIPS else paire[0]
	cible.append(paire[1])      # carte de pentes (ou null) ; ses mipmaps linéaires sont déjà générées

func _attendre(nom: String) -> void:
	if _taches.has(nom):
		WorkerThreadPool.wait_for_task_completion(_taches[nom])
		_taches.erase(nom)

func attendre_tout() -> void:
	for nom in _taches.keys():
		_attendre(nom)

# ------------------------------------------------------------------ matériaux
func mat(nom: String) -> Material:
	if _mats.has(nom):
		return _mats[nom]
	var m: Material
	match nom:
		"noir":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(0.015, 0.02, 0.03)
			m = s
		"braise":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(1.0, 0.42, 0.1)
			m = s
		"halo", "rai", "halo_f":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			s.albedo_texture = _texture("halo" if nom == "halo_f" else nom)
			if nom == "halo_f":
				s.albedo_color = Color(0.35, 0.6, 1.0)
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.no_depth_test = false
			s.disable_receive_shadows = true
			m = s
		_:
			var sm := ShaderMaterial.new()
			if nom == "mur4" or nom == "dalle4":
				sm.set_shader_parameter("emission", Vector3(0.012, 0.034, 0.056))     # la glace garde un fond bleu dans le noir
			elif nom == "or":
				sm.set_shader_parameter("emission", Vector3(0.04, 0.028, 0.004))
				sm.set_shader_parameter("crasse", 0.0)
			var sh := CRYPTE_SHADER
			if nom == "toile":
				var s2 := Shader.new()
				s2.code = CRYPTE_SHADER.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
				sh = s2
				sm.set_shader_parameter("decoupe", 0.5)
				sm.set_shader_parameter("crasse", 0.0)
				sm.set_shader_parameter("emission", Vector3(0.06, 0.08, 0.1))
			sm.shader = sh
			sm.set_shader_parameter("tex_base", _texture(nom))
			var nm := _pentes(nom)
			if nm != null:
				sm.set_shader_parameter("tex_nm", nm)
				sm.set_shader_parameter("relief", RELIEF.get(nom, 1.0))
			if nom == "fer" or nom == "lame":
				sm.set_shader_parameter("crasse", 0.0)
			m = sm
	_mats[nom] = m
	return m

func _pentes(nom: String) -> ImageTexture:
	_attendre(nom)
	var cible: Array = _images[nom]
	if cible.size() < 2 or cible[1] == null:
		return null
	return ImageTexture.create_from_image(cible[1])

func _texture(nom: String) -> ImageTexture:
	if not _tex.has(nom):
		_attendre(nom)
		var cible: Array = _images[nom]
		_tex[nom] = ImageTexture.create_from_image(cible[0])    # halo, rai, flamme : sans mipmaps (alpha en paliers)
	return _tex[nom]

# ------------------------------------------------------------------ accumulateur de maillage
func _buf(c: Vector3, nom: String) -> Dictionary:
	var cle := "%d,%d,%d|%s" % [floori(c.x / CASE), floori(c.z / CASE), 1 if c.y < -3.0 else 0, nom]      # l'étage inférieur a ses propres maillages
	if not _bufs.has(cle):
		_bufs[cle] = {"nom": nom, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray()}
	return _bufs[cle]

func _uv(p: Vector3, n: Vector3, tuile: float) -> Vector2:
	var a := n.abs()
	var uv: Vector2
	if a.y >= a.x and a.y >= a.z:
		uv = Vector2(p.x, p.z)
	elif a.x >= a.z:
		uv = Vector2(p.z, -p.y)
	else:
		uv = Vector2(p.x, -p.y)
	return uv / tuile

func _tri(b: Dictionary, a: Vector3, bb: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ca := Color.WHITE, cb := Color.WHITE, cc := Color.WHITE) -> void:
	var geo := (bb - a).cross(c - a)
	var v: PackedVector3Array = b["v"]
	var nn: PackedVector3Array = b["n"]
	var uu: PackedVector2Array = b["u"]
	var co: PackedColorArray = b["c"]
	if niveau_a != 1.0:
		ca.a *= niveau_a
		cb.a *= niveau_a
		cc.a *= niveau_a
	if geo.dot(n) > 0.0:    # Godot : face avant = sens horaire
		v.append(a); v.append(c); v.append(bb)
		uu.append(ua); uu.append(uc); uu.append(ub)
		co.append(ca); co.append(cc); co.append(cb)
	else:
		v.append(a); v.append(bb); v.append(c)
		uu.append(ua); uu.append(ub); uu.append(uc)
		co.append(ca); co.append(cb); co.append(cc)
	nn.append(n); nn.append(n); nn.append(n)

## Quad a-b-c-d (ordre de contour), normale n ; UV imposés ou calculés depuis les positions p_uv.
func quad(nom_: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uvs: Array = [], p_uv: Array = [], cols: Array = []) -> void:
	var nom: String = theme.get(nom_, nom_) if not theme.is_empty() else nom_
	var centre := (a + b + c + d) * 0.25
	var buf := _buf(centre, nom)
	var t: float = TUILE.get(nom, 1.0)
	var u: Array = uvs
	if u.is_empty():
		var pp: Array = p_uv if not p_uv.is_empty() else [a, b, c, d]
		u = [_uv(pp[0], n, t), _uv(pp[1], n, t), _uv(pp[2], n, t), _uv(pp[3], n, t)]
	if cols.is_empty():
		cols = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	_tri(buf, a, b, c, n, u[0], u[1], u[2], cols[0], cols[1], cols[2])
	_tri(buf, a, c, d, n, u[0], u[2], u[3], cols[0], cols[2], cols[3])

const _FACES := [
	[Vector3.RIGHT, [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
	[Vector3.LEFT, [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1)]],
	[Vector3.UP, [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3.DOWN, [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]],
	[Vector3.BACK, [Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1)]],
	[Vector3.FORWARD, [Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)]],
]

## Boîte pleine (6 faces) ; `faces` : masque des faces à produire (par défaut toutes) ; UV = position en mètres.
func boite(nom: String, centre: Vector3, taille: Vector3, lacet := 0.0, sans_dessous := false, decal := Vector3.ZERO) -> void:
	var h := taille * 0.5
	var basis := Basis(Vector3.UP, lacet)
	for f in _FACES:
		var n: Vector3 = f[0]
		if sans_dessous and n == Vector3.DOWN:
			continue
		var pts: Array = f[1]
		var w: Array = []
		var pu: Array = []
		for p: Vector3 in pts:
			w.append(centre + basis * (p * h))
			pu.append(centre + p * h + decal)
		quad(nom, w[0], w[1], w[2], w[3], basis * n, [], pu)
	_nb_pieces += 1

## Boîte autonome (pièces mobiles : herse, levier) : maillage propre, UV en mètres comme le reste.
func instance_boite(parent: Node3D, nom: String, taille: Vector3, pos: Vector3, lacet := 0.0) -> MeshInstance3D:
	var buf := {"nom": nom, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray()}
	var h := taille * 0.5
	var t: float = TUILE.get(nom, 1.0)
	for f in _FACES:
		var n: Vector3 = f[0]
		var pts: Array = f[1]
		var q: Array = []
		var u: Array = []
		for p: Vector3 in pts:
			q.append(p * h)
			u.append(_uv(p * h, n, t))
		_tri(buf, q[0], q[1], q[2], n, u[0], u[1], u[2])
		_tri(buf, q[0], q[2], q[3], n, u[0], u[2], u[3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = buf["v"]
	arr[Mesh.ARRAY_NORMAL] = buf["n"]
	arr[Mesh.ARRAY_TEX_UV] = buf["u"]
	arr[Mesh.ARRAY_COLOR] = buf["c"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(nom)
	mi.position = pos
	mi.rotation.y = lacet
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func solide(centre: Vector3, taille: Vector3) -> void:
	var bs := BoxShape3D.new()
	bs.size = taille
	var cs := CollisionShape3D.new()
	cs.shape = bs
	cs.position = centre
	corps.add_child(cs)

## Boîte visible ET solide (collision identique à l'ancienne _boite).
func boite_pleine(nom: String, centre: Vector3, taille: Vector3) -> void:
	boite(nom, centre, taille)
	solide(centre, taille)

## Solide de révolution (pilier octogonal, urne, tonneau, brasero) : profil [Vector2(rayon, y)] de bas en haut.
func tour(nom: String, base: Vector3, profil: Array, cotes := 8, decal := -1.0, sommet := true) -> void:
	var t: float = TUILE.get(nom, 1.0)
	var d: float = PI / cotes if decal < 0.0 else decal
	for k in profil.size() - 1:
		var p0: Vector2 = profil[k]
		var p1: Vector2 = profil[k + 1]
		for i in cotes:
			var a0 := d + TAU * i / cotes
			var a1 := d + TAU * (i + 1) / cotes
			var q0 := base + Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var q1 := base + Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var q2 := base + Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var q3 := base + Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var milieu := (q0 + q1 + q2 + q3) * 0.25
			var sortant := Vector3(milieu.x - base.x, 0, milieu.z - base.z).normalized()
			var n := (q1 - q0).cross(q3 - q0).normalized()
			if n.dot(sortant) < 0.0:
				n = -n
			var cote := 2.0 * maxf(p0.x, p1.x) * sin(PI / cotes)
			var u0 := (i * cote) / t
			var u1 := ((i + 1) * cote) / t
			quad(nom, q0, q1, q2, q3, n, [Vector2(u0, -p0.y / t), Vector2(u1, -p0.y / t), Vector2(u1, -p1.y / t), Vector2(u0, -p1.y / t)])
	if sommet:
		var top: Vector2 = profil[profil.size() - 1]
		if top.x > 0.001:
			var c := base + Vector3(0, top.y, 0)
			var b := _buf(c, nom)
			for i in cotes:
				var a0 := d + TAU * i / cotes
				var a1 := d + TAU * (i + 1) / cotes
				var q0 := c + Vector3(cos(a0) * top.x, 0, sin(a0) * top.x)
				var q1 := c + Vector3(cos(a1) * top.x, 0, sin(a1) * top.x)
				_tri(b, c, q0, q1, Vector3.UP, _uv(c, Vector3.UP, t), _uv(q0, Vector3.UP, t), _uv(q1, Vector3.UP, t))
	_nb_pieces += 1

## Arche (rib) : `plan` "x" = l'arche franchit un vide le long de X (extrudée le long de Z), "z" = l'inverse.
## Largeur libre w, naissance à la hauteur ys, flèche f (sommet à ys+f) ; brisée si f >= w/2, sinon segmentaire.
func arc(nom: String, plan: String, cx: float, cz: float, w: float, ys: float, f: float, ep := 0.32, prof := 0.45, seg := 8) -> void:
	var t: float = TUILE.get(nom, 1.0)
	var intr: Array = []     # Vector2(u, y) de gauche à droite
	var extr: Array = []
	var demi := w * 0.5
	if f >= demi:
		var xc := (w * w / 4.0 - f * f) / w      # centre de l'arc droit (≤ 0 : sur la gauche)
		var R := demi - xc
		var a1 := atan2(f, -xc)
		for s in range(0, seg + 1):              # moitié gauche : de la naissance au sommet (arc miroir)
			var a := a1 * float(s) / seg
			intr.append(Vector2(-(xc + R * cos(a)), ys + R * sin(a)))
			extr.append(Vector2(-(xc + (R + ep) * cos(a)), ys + (R + ep) * sin(a)))
		for s in range(seg - 1, -1, -1):         # moitié droite : du sommet à la naissance
			var a := a1 * float(s) / seg
			intr.append(Vector2(xc + R * cos(a), ys + R * sin(a)))
			extr.append(Vector2(xc + (R + ep) * cos(a), ys + (R + ep) * sin(a)))
	else:
		var yc := (f * f - demi * demi) / (2.0 * f)
		var R := f - yc
		var a_s := atan2(-yc, demi)
		for s in range(0, 2 * seg + 1):
			var a := lerpf(PI - a_s, a_s, float(s) / (2 * seg))
			intr.append(Vector2(R * cos(a), ys + yc + R * sin(a)))
			extr.append(Vector2((R + ep) * cos(a), ys + yc + (R + ep) * sin(a)))
	var cen := Vector2(0.0, ys)
	var hd := prof * 0.5
	for k in intr.size() - 1:
		var i0: Vector2 = intr[k]
		var i1: Vector2 = intr[k + 1]
		var e0: Vector2 = extr[k]
		var e1: Vector2 = extr[k + 1]
		var m3 := func(p: Vector2, wz: float) -> Vector3:
			return Vector3(cx + p.x, p.y, cz + wz) if plan == "x" else Vector3(cx + wz, p.y, cz + p.x)
		var nz := Vector3(0, 0, 1) if plan == "x" else Vector3(1, 0, 0)
		var s0 := float(k) * 0.4
		var s1 := float(k + 1) * 0.4
		# faces avant et arrière
		for sg in [1.0, -1.0]:
			var pa: Vector3 = m3.call(i0, hd * sg)
			var pb: Vector3 = m3.call(i1, hd * sg)
			var pc: Vector3 = m3.call(e1, hd * sg)
			var pd: Vector3 = m3.call(e0, hd * sg)
			quad(nom, pa, pb, pc, pd, nz * sg)
		# intrados et extrados
		var mi := (i0 + i1) * 0.5
		var dir_i := Vector2(0, ys) - mi
		if f < demi:
			dir_i = Vector2(0, ys + (f * f - demi * demi) / (2.0 * f)) - mi
		var ni2 := dir_i.normalized()
		var nint: Vector3 = Vector3(ni2.x, ni2.y, 0) if plan == "x" else Vector3(0, ni2.y, ni2.x)
		var ia: Vector3 = m3.call(i0, -hd)
		var ib: Vector3 = m3.call(i1, -hd)
		var ic: Vector3 = m3.call(i1, hd)
		var id_: Vector3 = m3.call(i0, hd)
		quad(nom, ia, ib, ic, id_, nint, [Vector2(s0, 0), Vector2(s1, 0), Vector2(s1, prof / t * 1.0), Vector2(s0, prof / t * 1.0)])
		var ea: Vector3 = m3.call(e0, -hd)
		var eb: Vector3 = m3.call(e1, -hd)
		var ec: Vector3 = m3.call(e1, hd)
		var ed: Vector3 = m3.call(e0, hd)
		quad(nom, ea, eb, ec, ed, -nint, [Vector2(s0, 0), Vector2(s1, 0), Vector2(s1, prof / t), Vector2(s0, prof / t)])
	_nb_pieces += 1

## Occlusion ambiante cuite dans les sommets : 1 = rien, `fond` au contact. Teinte un peu froide (l'ombre est bleutée).
func _ao(d: float, portee: float, fond: float) -> Color:
	var t := clampf(d / portee, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var f := lerpf(fond, 1.0, t)
	return Color(f, f, minf(1.0, f + 0.07 * (1.0 - f)))

## Points de coupe d'un segment [a, b] : bords, bords + marge, puis pas de 4 m au plus ; sans doublons proches.
func _coupes(a: float, b: float, marges: Array) -> Array:
	var pts := [a, b]
	for m: float in marges:
		if b - a > 2.0 * m + 0.1:
			pts.append(a + m)
			pts.append(b - m)
	pts.sort()
	var res := [pts[0]]
	for k in range(1, pts.size()):
		if pts[k] - res[res.size() - 1] > 0.05:
			res.append(pts[k])
	var out := [res[0]]
	for k in range(1, res.size()):
		var n := maxi(1, int(ceil((res[k] - out[out.size() - 1]) / 4.0 - 0.001)))
		var d0: float = out[out.size() - 1]
		for j in range(1, n + 1):
			out.append(lerpf(d0, res[k], float(j) / n))
	return out

# ------------------------------------------------------------------ surfaces modulaires (pas de 4 m), AO cuite
func plan_h(nom: String, x0: float, x1: float, z0: float, z1: float, y: float, vers_haut: bool, marge := 0.9, fond := 0.5) -> void:
	var n := Vector3.UP if vers_haut else Vector3.DOWN
	var xs := _coupes(x0, x1, [marge])
	var zs := _coupes(z0, z1, [marge])
	var col := func(x: float, z: float) -> Color:
		return _ao(minf(minf(x - x0, x1 - x), minf(z - z0, z1 - z)), marge, fond)
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			quad(nom, Vector3(xs[i], y, zs[j]), Vector3(xs[i + 1], y, zs[j]), Vector3(xs[i + 1], y, zs[j + 1]), Vector3(xs[i], y, zs[j + 1]), n, [], [],
				[col.call(xs[i], zs[j]), col.call(xs[i + 1], zs[j]), col.call(xs[i + 1], zs[j + 1]), col.call(xs[i], zs[j + 1])])

## Mur vertical ; `axe` "x" : le mur s'étend le long de X à z = fixe (normale ±Z) ; "z" : le long de Z à x = fixe.
## Coins (extrémités du pan) et haut du mur assombris (sommets) ; le pied l'est par le shader.
func plan_v(nom: String, axe: String, fixe: float, a0: float, a1: float, y0: float, y1: float, signe: float) -> void:
	if a1 - a0 < 0.01 or y1 - y0 < 0.01:
		return
	var s := _coupes(a0, a1, [0.7])
	var ys := _coupes(y0, y1, [0.8])
	var col := func(a: float, y: float) -> Color:
		var f := _ao(minf(a - a0, a1 - a), 0.7, 0.55) * _ao(y1 - y, 0.8, 0.5)
		if y0 > 0.5:     # dessous d'un linteau : l'angle avec le mur est sombre aussi
			f *= _ao(y - y0, 0.5, 0.7)
		return f
	for i in s.size() - 1:
		for j in ys.size() - 1:
			var ya: float = ys[j]
			var yb: float = ys[j + 1]
			var cc := [col.call(s[i], ya), col.call(s[i + 1], ya), col.call(s[i + 1], yb), col.call(s[i], yb)]
			if axe == "x":
				quad(nom, Vector3(s[i], ya, fixe), Vector3(s[i + 1], ya, fixe), Vector3(s[i + 1], yb, fixe), Vector3(s[i], yb, fixe), Vector3(0, 0, signe), [], [], cc)
			else:
				quad(nom, Vector3(fixe, ya, s[i]), Vector3(fixe, ya, s[i + 1]), Vector3(fixe, yb, s[i + 1]), Vector3(fixe, yb, s[i]), Vector3(signe, 0, 0), [], [], cc)

func _pas(a: float, b: float, pas := 4.0) -> Array:
	var n := maxi(1, int(ceil((b - a) / pas - 0.001)))
	var r := []
	for i in n + 1:
		r.append(lerpf(a, b, float(i) / n))
	return r

# ------------------------------------------------------------------ pièce rectangulaire
## Remplace l'ancien _salle : mêmes collisions (sol, plafond, murs, linteaux), surfaces refaites.
## ouvertures : [côté, centre, largeur] avec côté nord (z mini) / sud (z maxi) / ouest (x mini) / est (x maxi).
func salle(x0: float, x1: float, z0: float, z1: float, h: float, ouvertures: Array, y := 0.0, mur := "mur0") -> void:
	var xmin := minf(x0, x1)
	var xmax := maxf(x0, x1)
	var zmin := minf(z0, z1)
	var zmax := maxf(z0, z1)
	var cx := (xmin + xmax) * 0.5
	var cz := (zmin + zmax) * 0.5
	var lx := xmax - xmin
	var lz := zmax - zmin
	# --- collisions : strictement celles d'origine
	solide(Vector3(cx, y - 0.2, cz), Vector3(lx + 0.6, 0.4, lz + 0.6))
	solide(Vector3(cx, y + h + 0.2, cz), Vector3(lx + 0.6, 0.4, lz + 0.6))
	for cote in ["nord", "sud", "ouest", "est"]:
		var horizontal: bool = cote in ["nord", "sud"]
		var fixe: float = (zmin if cote == "nord" else zmax) if horizontal else (xmin if cote == "ouest" else xmax)
		var debut: float = xmin if horizontal else zmin
		var fin: float = xmax if horizontal else zmax
		var morceaux := [[debut, fin]]
		for o in ouvertures:
			if o[0] != cote:
				continue
			var nouveaux := []
			for m in morceaux:
				var a: float = o[1] - o[2] * 0.5
				var b: float = o[1] + o[2] * 0.5
				if b <= m[0] or a >= m[1]:
					nouveaux.append(m)
				else:
					if a > m[0]:
						nouveaux.append([m[0], a])
					if b < m[1]:
						nouveaux.append([b, m[1]])
			morceaux = nouveaux
		if h > 3.0:
			for o in ouvertures:
				if o[0] == cote:
					solide(Vector3(o[1], y + (3.0 + h) * 0.5, fixe) if horizontal else Vector3(fixe, y + (3.0 + h) * 0.5, o[1]),
						Vector3(o[2], h - 3.0, 0.6) if horizontal else Vector3(0.6, h - 3.0, o[2]))
		for m in morceaux:
			var longueur: float = m[1] - m[0]
			if longueur < 0.05:
				continue
			var milieu: float = (m[0] + m[1]) * 0.5
			solide(Vector3(milieu, y + h * 0.5, fixe) if horizontal else Vector3(fixe, y + h * 0.5, milieu),
				Vector3(longueur + 0.6, h, 0.6) if horizontal else Vector3(0.6, h, longueur + 0.6))
	# --- surfaces visibles : sol, plafond, faces intérieures des murs, embrasures
	var xa := xmin + 0.3
	var xb := xmax - 0.3
	var za := zmin + 0.3
	var zb := zmax - 0.3
	plan_h("dalle0", xa, xb, za, zb, y, true)
	plan_h("voute", xa, xb, za, zb, y + h, false)
	var ho := minf(h, 3.0)
	var idx := 0
	for cote in ["nord", "sud", "ouest", "est"]:
		var horizontal: bool = cote in ["nord", "sud"]
		var plan: float = {"nord": zmin + 0.3, "sud": zmax - 0.3, "ouest": xmin + 0.3, "est": xmax - 0.3}[cote]
		var signe: float = 1.0 if cote in ["nord", "ouest"] else -1.0
		var a0: float = xa if horizontal else za
		var a1: float = xb if horizontal else zb
		var libres := [[a0, a1]]
		var clairs: Array = []
		for o in ouvertures:
			if o[0] != cote:
				continue
			var ca: float = o[1] - o[2] * 0.5 + 0.3
			var cb: float = o[1] + o[2] * 0.5 - 0.3
			clairs.append([ca, cb, o.size() > 3 and o[3]])      # 4e élément : ouverture secrète (pas de cadre, relief de mur)
			var nouveaux := []
			for m in libres:
				if cb <= m[0] or ca >= m[1]:
					nouveaux.append(m)
				else:
					if ca > m[0]:
						nouveaux.append([m[0], ca])
					if cb < m[1]:
						nouveaux.append([cb, m[1]])
			libres = nouveaux
		for m in libres:
			plan_v(_var_mur(mur, idx), "x" if horizontal else "z", plan, m[0], m[1], y, y + h, signe)
			idx += 1
		var axe := "x" if horizontal else "z"
		var fixe_mur: float = plan - signe * 0.3      # axe du mur (le plan visible est à 0,3 m vers l'intérieur)
		for c in clairs:
			if h > 3.0:
				plan_v(_var_mur(mur, idx), axe, plan, c[0], c[1], y + 3.0, y + h, signe)
				idx += 1
			# embrasure : jambages, seuil et dessous de linteau (une seule fois par ouverture)
			var cle := "%s|%.1f|%.1f|%.1f" % [axe, fixe_mur, c[0], y]
			var deja := _fait.has(cle)
			_fait[cle] = true
			for e in ([] if deja else [c[0], c[1]]):
				var sg: float = 1.0 if e == c[0] else -1.0   # normale vers le passage
				if horizontal:
					quad(mur, Vector3(e, y, fixe_mur - 0.3), Vector3(e, y, fixe_mur + 0.3), Vector3(e, y + ho, fixe_mur + 0.3), Vector3(e, y + ho, fixe_mur - 0.3), Vector3(sg, 0, 0))
				else:
					quad(mur, Vector3(fixe_mur - 0.3, y, e), Vector3(fixe_mur + 0.3, y, e), Vector3(fixe_mur + 0.3, y + ho, e), Vector3(fixe_mur - 0.3, y + ho, e), Vector3(0, 0, sg))
			if deja:
				if not c[2]:
					_cadre(horizontal, plan, signe, c[0], c[1], ho, y)
				continue
			if horizontal:
				quad("dalle0", Vector3(c[0], y, fixe_mur - 0.3), Vector3(c[1], y, fixe_mur - 0.3), Vector3(c[1], y, fixe_mur + 0.3), Vector3(c[0], y, fixe_mur + 0.3), Vector3.UP)
				quad("voute", Vector3(c[0], y + ho, fixe_mur - 0.3), Vector3(c[1], y + ho, fixe_mur - 0.3), Vector3(c[1], y + ho, fixe_mur + 0.3), Vector3(c[0], y + ho, fixe_mur + 0.3), Vector3.DOWN)
			else:
				quad("dalle0", Vector3(fixe_mur - 0.3, y, c[0]), Vector3(fixe_mur + 0.3, y, c[0]), Vector3(fixe_mur + 0.3, y, c[1]), Vector3(fixe_mur - 0.3, y, c[1]), Vector3.UP)
				quad("voute", Vector3(fixe_mur - 0.3, y + ho, c[0]), Vector3(fixe_mur + 0.3, y + ho, c[0]), Vector3(fixe_mur + 0.3, y + ho, c[1]), Vector3(fixe_mur - 0.3, y + ho, c[1]), Vector3.DOWN)
			# cadre de porte épais : deux jambages et un linteau en saillie sur le mur
			if not c[2]:
				_cadre(horizontal, plan, signe, c[0], c[1], ho, y)
			else:
				_relief_mur(horizontal, plan, signe, c[0], c[1], y, h)
		# soubassement en deux assises irrégulières, corniche à trois ressauts sur corbeaux, pierres en saillie
		for m in libres:
			_relief_mur(horizontal, plan, signe, m[0], m[1], y, h)

## Relief géométrique d'un pan de mur : pierres de soubassement de profondeur variable, corniche (ressauts + corbeaux),
## quelques pierres d'assise en saillie (alignées sur les assises de 0,5 m de la texture).
func _relief_mur(horizontal: bool, plan: float, signe: float, a0: float, a1: float, y: float, h: float) -> void:
	var dos := func(a: float, y_c: float, lon: float, ep: float, haut: float, nom: String) -> void:
		var c := Vector3(a, y + y_c, plan + signe * (ep * 0.5)) if horizontal else Vector3(plan + signe * (ep * 0.5), y + y_c, a)
		boite(nom, c, Vector3(lon, haut, ep) if horizontal else Vector3(ep, haut, lon))
	var a := a0
	while a < a1 - 0.05:                                 # assise basse : 0,3 m, saillie 0,10 à 0,20
		var l := minf(rng.randf_range(0.7, 1.5), a1 - a)
		dos.call(a + l * 0.5, 0.15 + rng.randf_range(-0.01, 0.01), l - 0.02, rng.randf_range(0.10, 0.20), 0.3 + rng.randf_range(-0.03, 0.03), "mur1" if rng.randf() < 0.4 else "mur0")
		a += l
	a = a0 + rng.randf_range(0.0, 0.5)
	while a < a1 - 0.05:                                 # seconde assise : 0,3 à 0,62, saillie 0,04 à 0,09
		var l := minf(rng.randf_range(0.9, 1.7), a1 - a)
		dos.call(a + l * 0.5, 0.46, l - 0.02, rng.randf_range(0.04, 0.09), 0.32, "mur0" if rng.randf() < 0.6 else "mur1")
		a += l
	dos.call((a0 + a1) * 0.5, h - 0.1, a1 - a0, 0.12, 0.2, "mur0")      # corniche : trois ressauts
	dos.call((a0 + a1) * 0.5, h - 0.3, a1 - a0, 0.07, 0.2, "mur1")
	dos.call((a0 + a1) * 0.5, h - 0.45, a1 - a0, 0.035, 0.12, "mur0")
	a = a0 + 0.9                                         # corbeaux sous la corniche
	while a < a1 - 0.5:
		dos.call(a, h - 0.38, 0.3, 0.2, 0.26, "mur1")
		a += 2.0
	if a1 - a0 > 1.6:                                    # pierres d'assise en saillie
		for k in int((a1 - a0) / 2.6):
			var cen := rng.randf_range(a0 + 0.8, a1 - 0.8)
			var rang := rng.randi_range(1, maxi(1, int(minf(h, 3.0) / 0.5) - 3))
			dos.call(cen, rang * 0.5 + 0.25, rng.randf_range(0.7, 1.2), rng.randf_range(0.04, 0.09), 0.48, "mur1" if rng.randf() < 0.5 else "mur2")

func _var_mur(base: String, i: int) -> String:
	if base == "mur0":
		return "mur0" if i % 3 != 2 else "mur1"
	if base == "mur1":
		return "mur1" if i % 2 == 0 else "mur0"
	return base

func _cadre(horizontal: bool, plan: float, signe: float, ca: float, cb: float, ho: float, y: float) -> void:
	var p_in := plan + signe * 0.08
	for k in 2:
		var lado := ca - 0.22 if k == 0 else cb + 0.22
		if horizontal:
			boite("mur0", Vector3(lado, y + ho * 0.5, p_in), Vector3(0.44, ho, 0.16))
		else:
			boite("mur0", Vector3(p_in, y + ho * 0.5, lado), Vector3(0.16, ho, 0.44))
	var l := cb - ca + 0.88
	var m := (ca + cb) * 0.5
	if horizontal:
		boite("mur0", Vector3(m, y + ho - 0.2, p_in + signe * 0.03), Vector3(l, 0.4, 0.22))
	else:
		boite("mur0", Vector3(p_in + signe * 0.03, y + ho - 0.2, m), Vector3(0.22, 0.4, l))

# ------------------------------------------------------------------ structure : piliers, contreforts, poutres
## Pilier octogonal : fût à pans, base et chapiteau évasés. Collision = la boîte d'origine.
func pilier(x: float, z: float, h: float, largeur := 0.9, y := 0.0) -> void:
	var r := largeur * 0.5 / cos(PI / 8.0)
	var prof := [
		Vector2(r * 1.32, y), Vector2(r * 1.32, y + 0.26), Vector2(r * 1.1, y + 0.36), Vector2(r, y + 0.52),
		Vector2(r, y + h - 0.62), Vector2(r * 1.1, y + h - 0.5), Vector2(r * 1.32, y + h - 0.38), Vector2(r * 1.32, y + h),
	]
	tour("mur0", Vector3(x, 0, z), prof, 8, PI / 8.0)
	# bague de pierre à mi-hauteur
	var yb := y + h * 0.5
	tour("mur1", Vector3(x, 0, z), [Vector2(r * 1.06, yb - 0.1), Vector2(r * 1.06, yb + 0.1)], 8, PI / 8.0, false)
	solide(Vector3(x, y + h * 0.5, z), Vector3(largeur, h, largeur))

func contrefort(x: float, z: float, h: float, sens_x: float, sens_z: float, l := 0.7, p := 0.5) -> void:
	# pilier engagé contre un mur : (sens_x, sens_z) = direction du mur vers la pièce
	var dx := p if absf(sens_x) > 0.5 else l
	var dz := p if absf(sens_z) > 0.5 else l
	boite("mur0", Vector3(x, h * 0.5, z), Vector3(dx, h, dz))
	boite("mur1", Vector3(x + sens_x * 0.06, h - 0.2, z + sens_z * 0.06), Vector3(dx + 0.12 if absf(sens_x) > 0.5 else dx + 0.12, 0.4, dz + 0.12))
	boite("mur1", Vector3(x + sens_x * 0.06, 0.2, z + sens_z * 0.06), Vector3(dx + 0.12, 0.4, dz + 0.12))
	solide(Vector3(x, h * 0.5, z), Vector3(dx, h, dz))

func poutre(x0: float, x1: float, y: float, z: float, ep := 0.3) -> void:
	boite("bois", Vector3((x0 + x1) * 0.5, y, z), Vector3(x1 - x0, ep, ep))
	boite("fer", Vector3(x0 + 0.05, y, z), Vector3(0.04, ep + 0.06, ep + 0.06))
	boite("fer", Vector3(x1 - 0.05, y, z), Vector3(0.04, ep + 0.06, ep + 0.06))

# ------------------------------------------------------------------ lumière
func lumiere(pos: Vector3, couleur: Color, energie: float, portee: float, att := 1.7, vacille := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = att
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 20.0
	l.distance_fade_length = 6.0
	l.position = pos
	racine.add_child(l)
	toutes.append(l)
	if vacille:
		lumieres.append([l, energie, rng.randf() * 10.0])
	return l

## Flamme en sprite pixel art (fusionnée en MultiMesh par cellule dans finir()) ; `echelle` 1 = torche, 1,7 = brasero.
func flamme(pos: Vector3, echelle := 1.0) -> void:
	_flammes_def.append([pos, echelle, rng.randf() * 4.0])

func _mat_flamme() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = FLAMME_SHADER
	sm.set_shader_parameter("atlas", _texture("flamme"))
	return sm

## Même flamme, isolée, accrochée à un parent (torche tenue en main).
func flamme_sur(parent: Node3D, pos: Vector3, echelle := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	mi.mesh = q
	var sm := _mat_flamme()
	sm.set_shader_parameter("echelle_u", echelle)
	mi.material_override = sm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Carte additive (halo, rai) : centre, normale horizontale ou verticale, largeur x hauteur.
func carte(nom: String, centre: Vector3, normale: Vector3, w: float, h: float) -> void:
	var n := normale.normalized()
	var droite := Vector3.UP.cross(n)
	var haut := Vector3.UP
	if absf(n.y) > 0.9:
		droite = Vector3.RIGHT
		haut = Vector3.FORWARD
	else:
		droite = droite.normalized()
	var a := centre - droite * w * 0.5 - haut * h * 0.5
	var b := centre + droite * w * 0.5 - haut * h * 0.5
	var c := centre + droite * w * 0.5 + haut * h * 0.5
	var d := centre - droite * w * 0.5 + haut * h * 0.5
	quad(nom, a, b, c, d, n, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])

## Applique murale : platine, bras, coupelle, torche goudronnée, flamme, halo net sur le mur, lumière courte.
func applique(plan_mur: Vector3, vers: Vector3, haut := 2.1, portee := 5.0, energie := 1.9, avec_lumiere := true) -> void:
	var d := vers.normalized()
	var lacet := atan2(d.x, d.z)
	var p := Vector3(plan_mur.x, haut, plan_mur.z)
	boite("fer", p + d * 0.03, Vector3(0.16, 0.36, 0.06), lacet)
	boite("fer", p + d * 0.17 - Vector3(0, 0.06, 0), Vector3(0.05, 0.05, 0.32), lacet)
	tour("fer", p + d * 0.32 - Vector3(0, 0.1, 0), [Vector2(0.05, 0.0), Vector2(0.075, 0.12)], 6, -1.0, false)
	tour("bois", p + d * 0.32 - Vector3(0, 0.08, 0), [Vector2(0.03, 0.0), Vector2(0.035, 0.3)], 6, -1.0, true)
	tour("bois", p + d * 0.32 + Vector3(0, 0.12, 0), [Vector2(0.045, 0.0), Vector2(0.062, 0.1)], 6, -1.0, false)
	flamme(p + d * 0.32 + Vector3(0, 0.2, 0), 1.6)
	carte("halo", p + d * 0.13 + Vector3(0, 0.3, 0), d, 1.4, 1.4)
	if avec_lumiere:
		lumiere(p + d * 0.5 + Vector3(0, 0.45, 0), FEU, energie, portee, 1.8)

func brasero(pos: Vector3, froid := false) -> void:  # froid : lumière bleue (inutilisée dans la crypte actuelle)
	var prof := [Vector2(0.36, 0.0), Vector2(0.32, 0.1), Vector2(0.24, 0.36), Vector2(0.26, 0.66), Vector2(0.44, 0.74), Vector2(0.5, 0.9), Vector2(0.42, 0.92)]
	tour("mur0", pos, prof, 8, PI / 8.0, false)
	tour("fer", pos + Vector3(0, 0.0, 0), [Vector2(0.505, 0.78), Vector2(0.505, 0.9)], 8, PI / 8.0, false)   # cerclage
	tour("braise", pos + Vector3(0, 0.84, 0), [Vector2(0.4, 0.0), Vector2(0.4, 0.0)], 8, PI / 8.0, true)
	flamme(pos + Vector3(0, 0.9, 0), 1.7)
	carte("halo", pos + Vector3(0, 0.02, 0), Vector3.UP, 3.4, 3.4)
	lumiere(pos + Vector3(0, 1.4, 0), Color(0.45, 0.75, 1.0) if froid else FEU, 2.4, 5.8, 1.7)

# ------------------------------------------------------------------ mobilier (Méso)
func sarcophage(pos: Vector3, taille: Vector3, lacet := 0.0, collision := true) -> void:
	boite("mur0", pos + Vector3(0, taille.y * 0.5, 0), taille, lacet)
	boite("gravure", pos + Vector3(0, taille.y + 0.07, 0), Vector3(taille.x + 0.1, 0.14, taille.z + 0.1), lacet)
	boite("gravure", pos + Vector3(0, taille.y + 0.19, 0), Vector3(taille.x - 0.22, 0.1, taille.z - 0.3), lacet)
	boite("mur1", pos + Vector3(0, 0.07, 0), Vector3(taille.x + 0.14, 0.14, taille.z + 0.14), lacet)
	if collision:
		var b := Basis(Vector3.UP, lacet)
		var s := b * Vector3(taille.x, 0, taille.z)
		solide(pos + Vector3(0, taille.y * 0.5, 0), Vector3(absf(s.x), taille.y, absf(s.z)))

func coffre(pos: Vector3, lacet := 0.0, collision := true) -> void:
	var b := Basis(Vector3.UP, lacet)
	boite("bois", pos + Vector3(0, 0.22, 0), Vector3(0.9, 0.44, 0.56), lacet)
	boite("bois", pos + Vector3(0, 0.5, 0), Vector3(0.9, 0.12, 0.5), lacet)
	boite("bois", pos + Vector3(0, 0.58, 0), Vector3(0.9, 0.06, 0.38), lacet)
	for dx in [-0.3, 0.3]:
		boite("fer", pos + b * Vector3(dx, 0.31, 0), Vector3(0.09, 0.64, 0.6), lacet)
	boite("fer", pos + b * Vector3(0, 0.44, 0.285), Vector3(0.12, 0.14, 0.03), lacet)
	boite("fer", pos + Vector3(0, 0.02, 0), Vector3(0.94, 0.05, 0.6), lacet)
	if collision:
		var s := b * Vector3(0.9, 0, 0.56)
		solide(pos + Vector3(0, 0.3, 0), Vector3(absf(s.x), 0.6, absf(s.z)))

func bougie(pos: Vector3) -> void:
	tour("os", pos, [Vector2(0.03, 0.0), Vector2(0.026, 0.14)], 6, 0.0, true)
	tour("fer", pos, [Vector2(0.06, 0.0), Vector2(0.06, 0.012)], 6, 0.0, true)
	flamme(pos + Vector3(0, 0.14, 0), 0.4)
	lumiere(pos + Vector3(0, 0.4, 0), FEU, 0.9, 4.0, 1.8)

func urne(pos: Vector3, e := 1.0) -> void:
	var prof := [Vector2(0.13, 0.0), Vector2(0.2, 0.08), Vector2(0.25, 0.22), Vector2(0.21, 0.4), Vector2(0.12, 0.5), Vector2(0.14, 0.56), Vector2(0.09, 0.56)]
	var pe: Array = []
	for p: Vector2 in prof:
		pe.append(p * e)
	tour("argile", pos, pe, 8, 0.0, false)

func tonneau(pos: Vector3, e := 1.0) -> void:
	var prof := [Vector2(0.3, 0.0), Vector2(0.37, 0.25), Vector2(0.4, 0.5), Vector2(0.37, 0.75), Vector2(0.3, 1.0)]
	var pe: Array = []
	for p: Vector2 in prof:
		pe.append(p * e)
	tour("bois", pos, pe, 8, 0.0, true)
	for y in [0.16, 0.84]:
		var r: float = (0.34 if y < 0.5 else 0.34) * e + 0.012
		tour("fer", pos + Vector3(0, y * e, 0), [Vector2(r, -0.03 * e), Vector2(r, 0.03 * e)], 8, 0.0, false)

func table(pos: Vector3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	boite("bois", pos + Vector3(0, 0.76, 0), Vector3(1.1, 0.07, 0.65), lacet)
	for sx in [-0.5, 0.5]:
		for sz in [-0.27, 0.27]:
			boite("bois", pos + b * Vector3(sx, 0.36, sz), Vector3(0.07, 0.72, 0.07), lacet)
	boite("bois", pos + Vector3(0, 0.22, 0), Vector3(0.95, 0.05, 0.05), lacet)
	boite("parchemin", pos + b * Vector3(-0.25, 0.8, 0.05), Vector3(0.3, 0.012, 0.22), lacet + 0.2)
	tour("fer", pos + b * Vector3(0.28, 0.795, -0.08), [Vector2(0.1, 0.0), Vector2(0.12, 0.012), Vector2(0.07, 0.02)], 8, 0.0, false)
	tour("fer", pos + b * Vector3(0.36, 0.795, 0.14), [Vector2(0.07, 0.0), Vector2(0.085, 0.01), Vector2(0.05, 0.016)], 8, 0.0, false)

func etagere(pos: Vector3, lacet: float, largeur := 1.8, haut := 2.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	for sx in [-largeur * 0.5, largeur * 0.5]:
		boite("bois", pos + b * Vector3(sx, haut * 0.5, 0), Vector3(0.07, haut, 0.34), lacet)
	for y in [0.05, 0.7, 1.35, haut - 0.03]:
		boite("bois", pos + Vector3(0, y, 0), Vector3(largeur, 0.05, 0.34), lacet)
	boite("bois", pos + b * Vector3(0, haut * 0.5, -0.15), Vector3(largeur, haut, 0.03), lacet)
	for k in 7:        # rouleaux et grimoires posés
		var x := -largeur * 0.4 + k * (largeur * 0.8 / 6.0)
		var yy: float = [0.075, 0.725, 1.375][k % 3]
		boite("parchemin" if k % 2 == 0 else "bois", pos + b * Vector3(x, yy + 0.09, 0.0), Vector3(0.16, 0.2 if k % 2 else 0.14, 0.22), lacet)
	urne(pos + b * Vector3(largeur * 0.3, 0.0, 0.0) + Vector3(0, 1.38, 0), 0.5)

# ------------------------------------------------------------------ petits objets (Micro)
func crane(pos: Vector3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	var prof := [Vector2(0.055, 0.0), Vector2(0.085, 0.05), Vector2(0.095, 0.11), Vector2(0.07, 0.17), Vector2(0.0, 0.19)]
	tour("os", pos + Vector3(0, 0.035, 0), prof, 6, 0.0, true)
	boite("os", pos + b * Vector3(0, 0.03, 0.05), Vector3(0.09, 0.05, 0.08), lacet)
	for sx in [-0.03, 0.03]:
		boite("noir", pos + b * Vector3(sx, 0.11, 0.085), Vector3(0.036, 0.04, 0.02), lacet)
	boite("noir", pos + b * Vector3(0, 0.075, 0.09), Vector3(0.02, 0.03, 0.02), lacet)

func os_tas(pos: Vector3, n := 4, rayon := 0.4) -> void:
	for k in n:
		var a := rng.randf() * TAU
		var d := rng.randf() * rayon
		var l := rng.randf_range(0.2, 0.36)
		boite("os", pos + Vector3(cos(a) * d, 0.02 + 0.02 * (k % 2), sin(a) * d), Vector3(l, 0.04, 0.04), rng.randf() * TAU)
		boite("os", pos + Vector3(cos(a) * d, 0.03, sin(a) * d), Vector3(0.07, 0.05, 0.07), rng.randf() * TAU)
	crane(pos + Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)), rng.randf() * TAU)

func arme(pos: Vector3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	boite("lame", pos + Vector3(0, 0.013, 0) + b * Vector3(0.45, 0, 0), Vector3(0.82, 0.014, 0.075), lacet)
	boite("fer", pos + Vector3(0, 0.018, 0) + b * Vector3(0.03, 0, 0), Vector3(0.05, 0.03, 0.24), lacet)
	boite("bois", pos + Vector3(0, 0.014, 0) - b * Vector3(0.1, 0, 0), Vector3(0.18, 0.03, 0.03), lacet)
	boite("fer", pos + Vector3(0, 0.02, 0) - b * Vector3(0.21, 0, 0), Vector3(0.05, 0.04, 0.05), lacet)

func toile(coin: Vector3, a: Vector3, b: Vector3, l := 1.1) -> void:
	# triangle incliné : le coin, un point le long du mur A, un point le long du mur B plus bas
	var p0 := coin
	var p1 := coin + a.normalized() * l - Vector3(0, 0.1 * l, 0)
	var p2 := coin + b.normalized() * l - Vector3(0, 0.85 * l, 0)
	var n := (p1 - p0).cross(p2 - p0).normalized()
	var buf := _buf((p0 + p1 + p2) / 3.0, "toile")
	_tri(buf, p0, p1, p2, n, Vector2(0, 0), Vector2(1, 0), Vector2(0, 1))

func rai(pos_bas: Vector3, haut: float, largeur := 1.4) -> void:
	for k in 2:
		var n := Vector3(1, 0, 0) if k == 0 else Vector3(0, 0, 1)
		carte("rai", pos_bas + Vector3(0, haut * 0.5, 0), n, largeur, haut)

## Flaque de lumière froide au sol sous un rai.
func flaque_froide(pos: Vector3, diametre := 3.0) -> void:
	carte("halo_f", pos + Vector3(0, 0.02, 0), Vector3.UP, diametre, diametre)

func oculus(pos: Vector3, cote := 1.6) -> void:
	# trou carré au plafond : fond noir, cadre de pierre en saillie
	quad("noir", pos + Vector3(-cote * 0.5, -0.01, -cote * 0.5), pos + Vector3(cote * 0.5, -0.01, -cote * 0.5), pos + Vector3(cote * 0.5, -0.01, cote * 0.5), pos + Vector3(-cote * 0.5, -0.01, cote * 0.5), Vector3.DOWN)
	for s in [-1.0, 1.0]:
		boite("mur1", pos + Vector3(s * (cote * 0.5 + 0.12), -0.08, 0), Vector3(0.24, 0.16, cote + 0.48))
		boite("mur1", pos + Vector3(0, -0.08, s * (cote * 0.5 + 0.12)), Vector3(cote, 0.16, 0.24))

func poussiere(centre: Vector3, ext: Vector3, nombre := 28) -> void:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = 7.0
	p.position = centre
	p.visibility_aabb = AABB(-ext - Vector3.ONE, ext * 2.0 + Vector3(2, 2, 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.022, 0.022)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.albedo_color = Color(0.7, 0.8, 1.0, 0.8)
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(p)

# ------------------------------------------------------------------ vie et fin
## Lumières qui vacillent : trois fréquences + un tirage par pas de 1/12 s (le feu « saute » comme en pixel art).
func vaciller(t: float) -> void:
	for l in lumieres:
		var ph: float = l[2]
		var pas := floorf(t * 12.0 + ph * 3.0)
		var h := fposmod(sin(pas * 12.9898 + ph) * 43758.5453, 1.0)
		var f := 0.84 + sin(t * 6.3 + ph) * 0.06 + sin(t * 15.1 + ph * 2.0) * 0.04 + (h - 0.5) * 0.12
		(l[0] as OmniLight3D).light_energy = l[1] * f

## Construit les maillages fusionnés (un par cellule de 8 m et par matériau).
func finir() -> void:
	attendre_tout()
	for cle in _bufs:
		var b: Dictionary = _bufs[cle]
		var v: PackedVector3Array = b["v"]
		if v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = b["n"]
		arr[Mesh.ARRAY_TEX_UV] = b["u"]
		arr[Mesh.ARRAY_COLOR] = b["c"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat(b["nom"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Decor_" + String(cle).replace("|", "_").replace(",", "_").replace("-", "m")
		racine.add_child(mi)
	_bufs.clear()
	var par_case := {}
	for f in _flammes_def:
		var p: Vector3 = f[0]
		var cle := Vector2i(floori(p.x / CASE), floori(p.z / CASE))
		if not par_case.has(cle):
			par_case[cle] = []
		par_case[cle].append(f)
	for cle in par_case:
		var liste: Array = par_case[cle]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.center_offset = Vector3(0, 0.5, 0)
		mm.mesh = q
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, liste[i][0]))
			mm.set_instance_custom_data(i, Color(liste[i][2], liste[i][1], 0.0, 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat_flamme()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "Flammes_%d_%d" % [cle.x, cle.y]
		racine.add_child(mmi)
	_flammes_def.clear()
