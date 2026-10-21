class_name TrollGivre
## Troll de givre (refonte persos, branche refonte/persos_troll) : créature unique, voûtée, ~2,7 m, longs bras, fourrure blanc-gris
## givrée en MÈCHES géométriques, peau gris bleuté, yeux bleus luisants, griffes et crocs d'ivoire (référence : image ChatGPT
## « 14_02_00-6 »). Aucune IA : modèle, animations, matières.
##
## Choix : PAS de modèle Blender séparé. Le troll est le corps Quaternius (65 os, celui de Humain.creer) REMODELÉ par code :
##   - squelette : positions de repos des os modifiées (épaules x1,45, bras x1,6, avant-bras x1,65, mains x1,3, cou rentré, bassin
##     élargi) ; les clips d'animations.glb n'animent que la ROTATION des os (et la position du bassin) : ils restent valables tels
##     quels sur ces nouvelles longueurs ;
##   - maillage : chaque sommet suit la peau d'os vers la nouvelle pose de repos, avec une ÉPAISSEUR par os (torse x1,55, avant-bras
##     x1,75, cou x1,7…) : même UV, même pondération, aucune retouche de peau à faire ;
##   - posture voûtée : décalages de rotation « cuits » dans une copie de la bibliothèque d'animations (dos courbé, tête relevée,
##     épaules haussées, bras écartés) : Idle, Walk, Jog_Fwd, Sprint, Punch_Cross (attaque), Hit_Chest, Death01… tous voûtés ;
##   - le tout agrandi x1,5 (nœud Armature) : 2,73 m debout, ~2,5 m voûté.
## Ainsi le troll garde le contrat de Humain.creer (Skeleton3D, AnimationPlayer « Animations », mêmes noms d'os) et la même chaîne
## de rendu que le Guerrier (shaders/ps1_perso.gdshader, contour par coque, mipmaps pixel art).
##
##   TrollGivre.creer({}) -> Node3D
## Budget : <= 9 000 triangles, 4 surfaces (peau, fourrure découpée, griffes/crocs/gueule, yeux luisants).

const ECHELLE := 1.5

## Facteur sur la position de repos d'un os (= longueur du segment de son PARENT). Côtés gauche et droit (_l / _r).
const POSITION := {
	"upperarm": 1.45,       # largeur d'épaules (clavicule)
	"lowerarm": 1.6,        # bras
	"hand": 1.65,           # avant-bras
	"index_01": 1.3, "middle_01": 1.3, "ring_01": 1.3, "pinky_01": 1.3, "thumb_01": 1.3,
	"index_02": 1.25, "middle_02": 1.25, "ring_02": 1.25, "pinky_02": 1.25, "thumb_02": 1.25,
	"index_03": 1.25, "middle_03": 1.25, "ring_03": 1.25, "pinky_03": 1.25, "thumb_03": 1.25,
	"index_04_leaf": 1.25, "middle_04_leaf": 1.25, "ring_04_leaf": 1.25, "pinky_04_leaf": 1.25, "thumb_04_leaf": 1.25,
	"neck_01": 0.78,        # cou rentré dans les épaules
	"Head": 0.8,
	"thigh": Vector3(1.35, 1.0, 1.0),   # bassin large (seulement en x)
	"ball": 1.3,            # grands pieds
	"ball_leaf": 1.3,
}
## Épaisseur (x, z locaux de l'os) et longueur (y local) de la chair de chaque os.
const CHAIR := {
	"pelvis": [1.38, 1.0], "spine_01": [1.42, 1.0], "spine_02": [1.5, 1.0], "spine_03": [1.55, 1.0],
	"clavicle": [1.5, 1.45], "upperarm": [1.62, 1.6], "lowerarm": [1.78, 1.65], "hand": [1.5, 1.3],
	"index": [1.45, 1.25], "middle": [1.45, 1.25], "ring": [1.45, 1.25], "pinky": [1.45, 1.25], "thumb": [1.45, 1.25],
	"neck_01": [1.75, 0.78], "Head": [1.34, 1.08],
	"thigh": [1.5, 1.0], "calf": [1.5, 1.0], "foot": [1.45, 1.0], "ball": [1.4, 1.3],
}
## Posture voûtée : rotations ajoutées à chaque clé de rotation de l'os, dans toute la bibliothèque, autour d'axes du REPÈRE DU
## MODÈLE (x = droite du troll, y = haut, z = avant) appliqués à la pose animée de l'os (pas à son repos) : [axe, degrés], cumulables.
const VOUTE := {
	"spine_01": [[Vector3.RIGHT, 15.0]], "spine_02": [[Vector3.RIGHT, 14.0]], "spine_03": [[Vector3.RIGHT, 10.0]],
	"neck_01": [[Vector3.RIGHT, -16.0]], "Head": [[Vector3.RIGHT, -18.0]],
	"clavicle_l": [[Vector3.BACK, 5.0]], "clavicle_r": [[Vector3.BACK, -5.0]],
	# bras : un peu ramenés (les clavicules allongées et l'Idle d'origine les écartaient à 40°) mais écartés en garde, griffes dehors (référence), un peu en avant
	"upperarm_l": [[Vector3.RIGHT, -8.0], [Vector3.BACK, -6.0]], "upperarm_r": [[Vector3.RIGHT, -8.0], [Vector3.BACK, 6.0]],
	"thigh_l": [[Vector3.BACK, 4.0]], "thigh_r": [[Vector3.BACK, -4.0]],
}

static var _maillage: ArrayMesh
static var _repos := {}          # os -> nouvelle position de repos (locale)
static var _biblio: AnimationLibrary
static var _mats := {}

static func vider() -> void:
	_maillage = null
	_repos.clear()
	_biblio = null
	_mats.clear()
	TrollTextures.vider()

static func _cle_os(nom: String) -> String:
	if nom.ends_with("_l") or nom.ends_with("_r"):
		return nom.substr(0, nom.length() - 2)
	return nom

## Famille d'os (doigts : index_02_l -> index).
static func _famille(nom: String) -> String:
	var c := _cle_os(nom)
	for f in ["index", "middle", "ring", "pinky", "thumb"]:
		if c.begins_with(f):
			return f
	return c

# ======================================================================================================== fabrique
static func creer(options := {}) -> Node3D:
	var racine := Humain.creer({"corps": "homme"})
	racine.name = "TrollGivre"
	var sq := racine.find_child("Skeleton3D", true, false) as Skeleton3D
	var corps: MeshInstance3D = null
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if String(mi.name).begins_with("SuperHero"):
			corps = mi
		mi.visible = false
	if _maillage == null:
		_maillage = _construire(sq, corps)
	# nouvelles positions de repos
	for i in sq.get_bone_count():
		if _repos.has(i):
			var r := sq.get_bone_rest(i)
			r.origin = _repos[i]
			sq.set_bone_rest(i, r)
	sq.reset_bone_poses()
	for vieux: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		vieux.free()
	var mi := MeshInstance3D.new()
	mi.name = "troll"
	mi.mesh = _maillage
	sq.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = sq.create_skin_from_rest_transforms()
	mi.set_surface_override_material(0, _mat_peau())
	mi.set_surface_override_material(1, GuerrierNordique.materiau(TrollTextures.tex("meches"), true, true, false, "troll_meches"))
	mi.set_surface_override_material(2, GuerrierNordique.materiau(TrollTextures.tex("accessoires"), false, false, true, "troll_acc"))
	mi.set_surface_override_material(3, _mat_yeux())
	# taille de créature : l'Armature (parent du squelette) est agrandie ; la racine garde une échelle 1
	(sq.get_parent() as Node3D).scale = Vector3.ONE * ECHELLE
	var ap := racine.get_node("Animations") as AnimationPlayer
	ap.remove_animation_library("")
	ap.add_animation_library("", bibliotheque(sq))
	racine.set_meta("troll_givre", true)
	return racine

static func _mat_peau() -> ShaderMaterial:
	var m := GuerrierNordique.materiau(TrollTextures.tex("peau"), false, false, true, "troll_peau")
	m.set_shader_parameter("appoint", Vector3(0.06, 0.07, 0.09))
	m.set_shader_parameter("contour_froid", Vector3(0.22, 0.28, 0.40))
	return m

static func _mat_yeux() -> ShaderMaterial:
	var m := GuerrierNordique.materiau(TrollTextures.tex("yeux"), false, false, false, "troll_yeux")
	m.set_shader_parameter("emission", Color(0.25, 0.65, 1.2))
	m.set_shader_parameter("appoint", Vector3(0.6, 0.6, 0.6))
	return m

# ======================================================================================================== animations
## Copie de la bibliothèque des humains, voûtée (VOUTE) ; « Troll_Attaque » = Punch_Cross (coup de griffes croisé).
static func bibliotheque(sq: Skeleton3D) -> AnimationLibrary:
	if _biblio != null:
		return _biblio
	_biblio = Humain.bibliotheque().duplicate(true)
	var ordre := []
	for nom: String in VOUTE:
		ordre.append(sq.find_bone(nom))
	ordre.sort()      # parents avant enfants (indices croissants dans ce squelette)
	for an in _biblio.get_animation_list():
		var a := _biblio.get_animation(an)
		var pistes := {}
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				pistes[sq.find_bone(String(a.track_get_path(t)).get_slice(":", 1))] = t
		for o: int in ordre:
			if not pistes.has(o):
				continue
			var t: int = pistes[o]
			var r := Quaternion.IDENTITY
			for d: Array in VOUTE[sq.get_bone_name(o)]:
				r = Quaternion(d[0], deg_to_rad(d[1])) * r
			# valeurs d'origine lues avant écriture (la rotation du parent, elle, inclut déjà ses propres décalages)
			var cles := []
			for k in a.track_get_key_count(t):
				cles.append([a.track_get_key_time(t, k), a.track_get_key_value(t, k)])
			for k in cles.size():
				var p := _rot_globale(sq, a, pistes, sq.get_bone_parent(o), cles[k][0])
				var q: Quaternion = cles[k][1]
				a.track_set_key_value(t, k, (p.inverse() * r * p * q).normalized())
	if _biblio.has_animation("Punch_Cross"):
		_biblio.add_animation("Troll_Attaque", _biblio.get_animation("Punch_Cross").duplicate(true))
	return _biblio

## Rotation globale (repère du squelette) de l'os `o` au temps `tps` du clip (rotations seules : les positions n'y changent rien).
static func _rot_globale(sq: Skeleton3D, a: Animation, pistes: Dictionary, o: int, tps: float) -> Quaternion:
	var q := Quaternion.IDENTITY
	while o >= 0:
		var l: Quaternion = a.rotation_track_interpolate(pistes[o], tps) if pistes.has(o) else sq.get_bone_rest(o).basis.get_rotation_quaternion()
		q = l * q
		o = sq.get_bone_parent(o)
	return q

# ======================================================================================================== maillage
## Construit le maillage peau d'os (bind i = os i) : corps remodelé + fourrure + accessoires + yeux, et remplit _repos.
static func _construire(sq: Skeleton3D, corps: MeshInstance3D) -> ArrayMesh:
	var n_os := sq.get_bone_count()
	var g_anc: Array[Transform3D] = []
	for i in n_os:
		g_anc.append(sq.get_bone_global_rest(i))
	# nouvelles positions de repos
	var locaux: Array[Transform3D] = []
	for i in n_os:
		var r := sq.get_bone_rest(i)
		var f: Variant = POSITION.get(_cle_os(sq.get_bone_name(i)), 1.0)
		if f is Vector3:
			# facteur exprimé en axes GLOBAUX : appliqué au décalage global puis ramené dans le repère du parent
			var p := sq.get_bone_parent(i)
			var bp := g_anc[p].basis
			var dg := bp * r.origin
			dg *= f
			r.origin = bp.inverse() * dg
		else:
			r.origin *= float(f)
		locaux.append(r)
		_repos[i] = r.origin
	var g_nouv: Array[Transform3D] = []
	for i in n_os:
		var p := sq.get_bone_parent(i)
		g_nouv.append(locaux[i] if p < 0 else g_nouv[p] * locaux[i])
	# matrice de déformation par os : nouvelle pose * chair * inverse de l'ancienne pose
	var deform: Array[Transform3D] = []
	for i in n_os:
		var ch: Array = CHAIR.get(_famille(sq.get_bone_name(i)), [1.0, 1.0])
		var s := Transform3D(Basis.from_scale(Vector3(ch[0], ch[1], ch[0])), Vector3.ZERO)
		deform.append(g_nouv[i] * s * g_anc[i].affine_inverse())
	var ctx := Ctx.new()
	ctx.sq = sq
	ctx.g_anc = g_anc
	ctx.g_nouv = g_nouv
	ctx.deform = deform
	ctx.corps(corps)
	ctx.fourrure()
	ctx.accessoires()
	return ctx.assembler()

class Ctx:
	var sq: Skeleton3D
	var g_anc: Array[Transform3D]
	var g_nouv: Array[Transform3D]
	var deform: Array[Transform3D]
	# corps
	var cv := PackedVector3Array()
	var cn := PackedVector3Array()
	var cuv := PackedVector2Array()
	var cb := PackedInt32Array()
	var cw := PackedFloat32Array()
	var ci := PackedInt32Array()
	var dom := PackedInt32Array()      # os dominant par sommet
	# surfaces ajoutées
	var dec := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var op := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var yx := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var graine := 7

	func _h(i: int) -> float:
		graine += 1
		return ObjetsTextures._h(i, graine, 1401)

	func os_(nom: String) -> int:
		return sq.find_bone(nom)

	## Point de l'ancien repos porté par l'os `o` -> nouveau repos (déformation de la chair de l'os ; visage remodelé pour la tête).
	func porter(p: Vector3, o: int) -> Vector3:
		var q := deform[o] * p
		return visage(q) if o == os_("Head") else q

	## Remodelage du visage (nouveau repos) : arcade sourcilière avancée, bas du visage élargi et avancé (mâchoire prognathe).
	func visage(p: Vector3) -> Vector3:
		var tete := g_nouv[os_("Head")].origin
		var q := p - tete
		if q.z <= 0.02:
			return p
		var avant := smoothstep(0.02, 0.10, q.z)
		var arc := exp(-pow((q.y - 0.125) / 0.025, 2.0)) * avant
		q.z += arc * 0.022
		var bas := smoothstep(0.09, 0.02, q.y) * avant
		q.x *= 1.0 + bas * 0.22
		q.z += bas * 0.018
		return tete + q

	# ------------------------------------------------------------ corps
	func corps(mi: MeshInstance3D) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var nb := bones.size() / v.size()
		var os_de := {}
		for i in v.size():
			var paires := []
			for j in nb:
				var wt := w[i * nb + j]
				if wt <= 0.0:
					continue
				var b := bones[i * nb + j]
				if not os_de.has(b):
					os_de[b] = maxi(0, GuerrierNordique._os_de_bind(mi.skin, sq, b))
				paires.append([wt, os_de[b]])
			paires.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
			var bo := [0, 0, 0, 0]
			var wo := [0.0, 0.0, 0.0, 0.0]
			var somme := 0.0
			for j in mini(4, paires.size()):
				bo[j] = paires[j][1]
				wo[j] = paires[j][0]
				somme += wo[j]
			var p := Vector3.ZERO
			for j in 4:
				wo[j] /= maxf(somme, 1e-5)
				if wo[j] > 0.0:
					p += deform[bo[j]] * v[i] * wo[j]
			cv.append(p)
			cuv.append(uv[i])
			cb.append_array(PackedInt32Array(bo))
			cw.append_array(PackedFloat32Array(wo))
			dom.append(bo[0])
		ci = idx
		# visage : arcade avancée, mâchoire élargie et avancée (prognathe)
		var hd := os_("Head")
		for i in cv.size():
			if dom[i] == hd:
				cv[i] = visage(cv[i])
		# normales lissées (sommets soudés par position)
		var acc := {}
		for t in range(0, ci.size(), 3):
			var p0 := cv[ci[t]]
			var n := (cv[ci[t + 2]] - p0).cross(cv[ci[t + 1]] - p0)
			for k in 3:
				var cle := cv[ci[t + k]].snapped(Vector3.ONE * 0.0002)
				acc[cle] = acc.get(cle, Vector3.ZERO) + n
		cn.resize(cv.size())
		for i in cv.size():
			cn[i] = (acc.get(cv[i].snapped(Vector3.ONE * 0.0002), Vector3.UP) as Vector3).normalized()

	# ------------------------------------------------------------ outils de géométrie
	func _tri(s: Dictionary, p: Array, uv: Array, pw: Array, dedans: Vector3) -> void:
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
			s["b"].append_array(pw[k][0])
			s["w"].append_array(pw[k][1])

	func _quad(s: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, pw: Array, dedans: Vector3) -> void:
		_tri(s, [a, b, c], [ua, ub, uc], [pw[0], pw[1], pw[2]], dedans)
		_tri(s, [a, c, d], [ua, uc, ud], [pw[0], pw[2], pw[3]], dedans)

	func rigide(o: int) -> Array:
		return [PackedInt32Array([o, 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0])]

	func poids(i: int) -> Array:
		return [cb.slice(i * 4, i * 4 + 4), cw.slice(i * 4, i * 4 + 4)]

	func _uva(x: float, y: float) -> Vector2:
		return Vector2(x / TrollTextures.ATLAS.x, y / TrollTextures.ATLAS.y)

	## Cône à `cotes` pans de la base (centre b, rayon r, plan perpendiculaire à l'axe) à la pointe, région d'atlas en u, v = 0 base -> 1 pointe.
	func cone(s: Dictionary, base: Vector3, pointe: Vector3, r: float, cotes: int, pw: Array, reg: Rect2i, courbe := Vector3.ZERO) -> void:
		var axe := (pointe - base).normalized()
		var x := axe.cross(Vector3.UP if absf(axe.y) < 0.9 else Vector3.RIGHT).normalized()
		var y := axe.cross(x)
		var milieu := base.lerp(pointe, 0.55) + courbe
		for i in cotes:
			var a0 := TAU * i / cotes
			var a1 := TAU * (i + 1) / cotes
			var e0 := (x * cos(a0) + y * sin(a0)) * r
			var e1 := (x * cos(a1) + y * sin(a1)) * r
			var u0 := reg.position.x + reg.size.x * float(i) / cotes
			var u1 := reg.position.x + reg.size.x * float(i + 1) / cotes
			var vb := float(reg.position.y)
			var vm := reg.position.y + reg.size.y * 0.55
			var vp := float(reg.end.y) - 0.5
			# base -> milieu (rayon 0,55) -> pointe : griffe recourbée
			_quad(s, base + e0, base + e1, milieu + e1 * 0.55, milieu + e0 * 0.55, _uva(u0, vb), _uva(u1, vb), _uva(u1, vm), _uva(u0, vm), [pw, pw, pw, pw], base.lerp(pointe, 0.3) + courbe * 0.5)
			_tri(s, [milieu + e0 * 0.55, milieu + e1 * 0.55, pointe], [_uva(u0, vm), _uva(u1, vm), _uva((u0 + u1) * 0.5, vp)], [pw, pw, pw], milieu)

	# ------------------------------------------------------------ fourrure en mèches
	## Région de fourrure d'un triangle du corps (au nouveau repos) : [nombre de mèches par m², lg0, lg1, variante min, max, type]
	## ou [] (peau nue). Types : 0 = pend (bas + dehors), 1 = suit le membre (vers l'enfant de l'os), 2 = se dresse (crinière du crâne).
	func region(o: int, c: Vector3, n: Vector3) -> Array:
		var nom := sq.get_bone_name(o)
		var f := TrollGivre._famille(nom)
		var tete := g_nouv[os_("Head")].origin
		match f:
			"Head":
				var q := c - tete
				if q.z > 0.04 and q.y < 0.165 and q.y > 0.03 and absf(q.x) < 0.09:
					return []                                   # visage nu
				if q.z > 0.02 and q.y <= 0.03:
					return [600.0, 0.08, 0.13, 0, 2, 0]         # barbe
				if q.y > 0.16:
					return [750.0, 0.10, 0.16, 0, 2, 2]         # crinière dressée sur le crâne
				return [800.0, 0.14, 0.22, 0, 3, 0]             # crinière (côtés, nuque)
			"neck_01":
				if n.z > 0.2:
					return []                                   # gorge nue (la barbe la couvre)
				return [650.0, 0.16, 0.24, 0, 3, 3]
			"clavicle":
				if n.y > 0.45 or n.z < -0.2:
					return [520.0, 0.16, 0.24, 0, 4, 3]         # dessus des épaules
				return []
			"spine_03":
				if n.z < -0.25 or n.y > 0.7:
					return [380.0, 0.16, 0.26, 1, 5, 3]         # haut du dos
				return []                                       # poitrine nue
			"spine_02", "spine_01":
				if c.y < g_nouv[os_("pelvis")].origin.y + 0.16:
					return [420.0, 0.14, 0.21, 3, 7, 0]         # haut du pagne (taille)
				if c.z < -0.03:
					return [200.0, 0.12, 0.18, 3, 7, 0]         # dos
				return []
			"pelvis":
				if c.y > g_nouv[os_("pelvis")].origin.y - 0.05:
					return [420.0, 0.14, 0.21, 3, 7, 0]         # pagne
				return []
			"thigh":
				if c.y > g_nouv[os_(nom)].origin.y - 0.10:
					return [420.0, 0.14, 0.21, 3, 7, 0]         # pagne (haut des cuisses)
				return []
			"upperarm":
				var axe := g_nouv[os_(nom)].origin
				var dist := absf(c.x - axe.x)
				if (n.y > 0.0 or c.z < axe.z - 0.02) and dist < 0.22:
					return [380.0 * (1.0 - dist / 0.22) + 40.0, 0.12, 0.20, 0, 4, 3]   # crinière qui descend sur l'épaule (pend, détachée)
				return []
			"lowerarm":
				var axe2 := g_nouv[os_(nom)].origin
				var t := clampf(absf(c.x - axe2.x) / 0.36, 0.0, 1.0)
				return [260.0 + 260.0 * t, 0.12, 0.20, 2, 6, 1]   # avant-bras, plus fourni vers le poignet
			"hand":
				if n.y > 0.4 and absf(c.x - g_nouv[os_(nom)].origin.x) < 0.06:
					return [300.0, 0.06, 0.09, 3, 6, 1]         # touffes du poignet
				return []
			"calf":
				var genou := g_nouv[os_(nom)].origin.y
				var t2 := clampf((genou - c.y) / 0.45, 0.0, 1.0)
				return [200.0 + 260.0 * t2, 0.11, 0.17, 2, 7, 0]   # mollet, plus fourni vers la cheville
			"foot":
				if n.y > 0.3 and c.z < g_nouv[os_(nom)].origin.z + 0.08:
					return [260.0, 0.06, 0.10, 3, 7, 0]
				return []
		return []

	func fourrure() -> void:
		var hd := os_("Head")
		var tete := g_nouv[hd].origin
		var k := 0
		var nb := 0
		for t in range(0, ci.size(), 3):
			var i0 := ci[t]
			var i1 := ci[t + 1]
			var i2 := ci[t + 2]
			var p0 := cv[i0]
			var p1 := cv[i1]
			var p2 := cv[i2]
			var c := (p0 + p1 + p2) / 3.0
			var nf := (p2 - p0).cross(p1 - p0)
			var aire := nf.length() * 0.5
			nf = nf.normalized()
			if nf.dot(cn[i0] + cn[i1] + cn[i2]) < 0.0:
				nf = -nf
			var o := dom[i0]
			var reg := region(o, c, nf)
			if reg.is_empty():
				continue
			# nombre de mèches de ce triangle : partie entière + tirage
			var attendu: float = reg[0] * aire
			var nombre := int(attendu)
			if _h(t) < attendu - nombre:
				nombre += 1
			for m in nombre:
				var b1 := _h(t + m * 3)
				var b2 := _h(t + m * 3 + 1) * (1.0 - b1)
				var p := p0 * (1.0 - b1 - b2) + p1 * b1 + p2 * b2
				var i_proche := i0 if (1.0 - b1 - b2) >= maxf(b1, b2) else (i1 if b1 >= b2 else i2)
				var nrm := (cn[i0] * (1.0 - b1 - b2) + cn[i1] * b1 + cn[i2] * b2).normalized()
				var ext := Vector3(nrm.x, 0.0, nrm.z)
				if ext.length() < 0.05:
					ext = Vector3(p.x, 0.0, p.z)
				ext = ext.normalized()
				var dir: Vector3
				match int(reg[5]):
					0:
						dir = (Vector3.DOWN * 0.85 + ext * 0.45 + nrm * 0.25).normalized()
						if o == hd and (p - tete).y > 0.0 and (p - tete).z < 0.0:
							dir = (Vector3.DOWN * 0.7 + Vector3.BACK * 0.0 + Vector3(0, 0, -0.5) + nrm * 0.3).normalized()
					3:
						# épaules, nuque, haut du dos : pend vers le bas, en dehors et en arrière, jamais sur la poitrine
						var e3 := Vector3(ext.x, 0.0, minf(ext.z, 0.0) - 0.25).normalized()
						dir = (Vector3.DOWN * 0.8 + e3 * 0.45 + nrm * 0.5).normalized()   # se détache de la peau : pas de « tuiles » couchées
					1:
						var enfant := (g_nouv[mini(o + 1, g_nouv.size() - 1)].origin - g_nouv[o].origin).normalized()
						dir = (enfant * 0.85 + nrm * 0.45).normalized()
					2:
						dir = (Vector3.UP * 0.35 + Vector3(0, 0, -0.75) + nrm * 0.45).normalized()
				var cote := dir.cross(nrm)
				if cote.length() < 0.05:
					cote = dir.cross(Vector3.FORWARD)
				cote = cote.normalized()
				var lg := lerpf(reg[1], reg[2], _h(k))
				var larg := lerpf(0.075, 0.115, _h(k + 1))
				var variante := int(reg[3]) + int(_h(k + 2) * (int(reg[4]) - int(reg[3]) + 1))
				_carte(p + nrm * 0.004 - dir * 0.015, cote, dir, larg, lg, mini(variante, 7), poids(i_proche), nrm)
				k += 3
				nb += 1
		if GuerrierNordique.chrono:
			print("TROLL mèches : %d cartes" % nb)

	func _carte(r: Vector3, cote: Vector3, dir: Vector3, larg: float, lg: float, variante: int, pw: Array, nrm: Vector3) -> void:
		var g := r - cote * larg * 0.5
		var d := r + cote * larg * 0.5
		var u0 := (variante * 16.0 + 0.5) / 128.0
		var u1 := (variante * 16.0 + 15.5) / 128.0
		var bout := dir * lg
		if lg < 0.19:
			_quad(dec, g, d, d + bout, g + bout, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0), [pw, pw, pw, pw], r - nrm * 0.1)
			return
		# longue mèche : 2 tronçons, le milieu s'écarte de la peau (volume, pas de « plumeau » plaqué)
		var mid := dir * lg * 0.5 + nrm * 0.012
		_quad(dec, g, d, d + mid, g + mid, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.5), Vector2(u0, 0.5), [pw, pw, pw, pw], r - nrm * 0.1)
		_quad(dec, g + mid, d + mid, d + bout, g + bout, Vector2(u0, 0.5), Vector2(u1, 0.5), Vector2(u1, 1.0), Vector2(u0, 1.0), [pw, pw, pw, pw], r - nrm * 0.1)

	# ------------------------------------------------------------ griffes, crocs, gueule, arcade, yeux
	func accessoires() -> void:
		# griffes des mains : au bout de chaque doigt, prolongeant la phalange, recourbées vers la paume (-y au repos)
		for cote in ["l", "r"]:
			for f in ["index", "middle", "ring", "pinky", "thumb"]:
				var o3 := os_("%s_03_%s" % [f, cote])
				var bout := g_nouv[os_("%s_04_leaf_%s" % [f, cote])].origin
				var d := (bout - g_nouv[o3].origin).normalized()
				var lg := 0.085 if f != "thumb" else 0.07
				var base := bout - d * 0.012
				var pointe := base + d * lg + Vector3.DOWN * lg * 0.45
				cone(op, base, pointe, 0.013, 4, rigide(o3), TrollTextures.R_GRIFFE, Vector3.UP * lg * 0.12)
			# griffes des orteils : 4 en éventail au bout du pied
			var ob := os_("ball_%s" % cote)
			var bout_p := g_nouv[os_("ball_leaf_%s" % cote)].origin
			for j in 4:
				var dx := (j - 1.5) * 0.034 * (1.0 if cote == "l" else -1.0)
				var base := bout_p + Vector3(dx, 0.022, -0.01)
				var pointe := base + Vector3(dx * 0.4, -0.03, 0.06)
				cone(op, base, pointe, 0.012, 4, rigide(ob), TrollTextures.R_GRIFFE, Vector3.UP * 0.008)
		var hd := os_("Head")
		var pw := rigide(hd)
		var yeux := _centres_yeux()
		var arc := TrollTextures.R_ARCADE
		var gq := TrollTextures.R_GUEULE
		var cr := TrollTextures.R_CROC
		# arcade sourcilière froncée : prisme au-dessus des yeux, plus bas vers le nez (air féroce)
		var oy: Vector3 = (yeux[0] + yeux[1]) * 0.5
		var pts := [porter(Vector3(-0.058, 1.712, 0.062), hd), porter(Vector3(-0.012, 1.703, 0.088), hd), porter(Vector3(0.012, 1.703, 0.088), hd), porter(Vector3(0.058, 1.712, 0.062), hd)]
		for i in 3:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var haut := Vector3(0, 0.022, -0.008)
			var avant := Vector3(0, -0.004, 0.02)
			_quad(op, a + haut, b + haut, b + avant, a + avant, _uva(arc.position.x + i * 5, arc.position.y + 1), _uva(arc.position.x + i * 5 + 5, arc.position.y + 1),
				_uva(arc.position.x + i * 5 + 5, arc.end.y - 3), _uva(arc.position.x + i * 5, arc.end.y - 3), [pw, pw, pw, pw], oy - Vector3(0, 0, 0.05))
			_quad(op, a + avant, b + avant, b + Vector3(0, -0.012, 0.004), a + Vector3(0, -0.012, 0.004), _uva(arc.position.x + i * 5, arc.end.y - 2), _uva(arc.position.x + i * 5 + 5, arc.end.y - 2),
				_uva(arc.position.x + i * 5 + 5, arc.end.y - 0.5), _uva(arc.position.x + i * 5, arc.end.y - 0.5), [pw, pw, pw, pw], oy - Vector3(0, 0, 0.05))
		# gueule ouverte (trapèze sombre devant la bouche) et crocs
		var m0 := porter(Vector3(-0.030, 1.640, 0.094), hd)
		var m1 := porter(Vector3(0.030, 1.640, 0.094), hd)
		var m2 := porter(Vector3(0.022, 1.612, 0.090), hd)
		var m3 := porter(Vector3(-0.022, 1.612, 0.090), hd)
		var fz := Vector3(0, 0, 0.006)
		_quad(op, m0 + fz, m1 + fz, m2 + fz, m3 + fz, _uva(gq.position.x, gq.position.y), _uva(gq.end.x, gq.position.y), _uva(gq.end.x, gq.end.y), _uva(gq.position.x, gq.end.y), [pw, pw, pw, pw], (m0 + m2) * 0.5 - Vector3(0, 0, 0.05))
		for s: float in [-1.0, 1.0]:
			# crocs du haut (pendent) et défenses du bas (se dressent), aux coins de la gueule
			var hautc := porter(Vector3(0.020 * s, 1.641, 0.093), hd) + fz * 1.5
			cone(op, hautc, hautc + Vector3(0, -0.026, 0.004), 0.007, 3, pw, cr)
			var basc := porter(Vector3(0.024 * s, 1.611, 0.090), hd) + fz * 1.5
			cone(op, basc, basc + Vector3(0.004 * s, 0.034, 0.006), 0.009, 3, pw, cr)
		# yeux luisants : petites cartes dans les orbites
		for c: Vector3 in yeux:
			var sx := signf(c.x)
			var dx := Vector3(0.016, 0, 0.004 * -sx)
			var dy := Vector3(0, 0.008, 0)
			var p := c + Vector3(0, -0.002, 0.003)
			_quad(yx, p - dx - dy, p + dx - dy, p + dx + dy, p - dx + dy, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), [pw, pw, pw, pw], p - Vector3(0, 0, 0.05))

	## Centres des yeux Quaternius (ancien repos) portés par la tête remodelée.
	func _centres_yeux() -> Array:
		var hd := os_("Head")
		return [porter(Vector3(0.030, 1.699, 0.080), hd), porter(Vector3(-0.030, 1.699, 0.080), hd)]

	# ------------------------------------------------------------ assemblage : 4 surfaces (peau, mèches, accessoires, yeux)
	func assembler() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = cv
		arr[Mesh.ARRAY_NORMAL] = cn
		arr[Mesh.ARRAY_TEX_UV] = cuv
		arr[Mesh.ARRAY_BONES] = cb
		arr[Mesh.ARRAY_WEIGHTS] = cw
		arr[Mesh.ARRAY_INDEX] = ci
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		for s: Dictionary in [dec, op, yx]:
			var a2 := []
			a2.resize(Mesh.ARRAY_MAX)
			a2[Mesh.ARRAY_VERTEX] = s["v"]
			a2[Mesh.ARRAY_NORMAL] = s["n"]
			a2[Mesh.ARRAY_TEX_UV] = s["uv"]
			a2[Mesh.ARRAY_BONES] = s["b"]
			a2[Mesh.ARRAY_WEIGHTS] = s["w"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		mesh.custom_aabb = AABB(Vector3(-2.2, -0.3, -2.2), Vector3(4.4, 2.6, 4.4))   # mort couchée comprise
		return mesh
