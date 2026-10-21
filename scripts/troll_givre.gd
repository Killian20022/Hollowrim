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
## Budget : <= 7 500 triangles, 4 surfaces (peau, fourrure découpée, griffes/crocs/gueule/oreilles, yeux luisants).

const ECHELLE := 1.6
## Densité globale des mèches (budget 7 500 triangles).
const DENSITE := 0.53
## Tête agrandie (passe 3 : elle était petite et enfouie) : facteur sur la chair de l'os Head ; les seuils du visage et de la
## crinière sont exprimés dans le repère de la passe 2 (on divise par TK) et les accessoires du visage grandissent d'autant.
const TK := 1.16

## Facteur sur la position de repos d'un os (= longueur du segment de son PARENT). Côtés gauche et droit (_l / _r).
const POSITION := {
	"upperarm": 1.55,       # largeur d'épaules (clavicule)
	"lowerarm": 1.6,        # bras
	"hand": 1.7,            # avant-bras
	"index_01": 1.6, "middle_01": 1.6, "ring_01": 1.6, "pinky_01": 1.6, "thumb_01": 1.5,
	"index_02": 1.55, "middle_02": 1.55, "ring_02": 1.55, "pinky_02": 1.55, "thumb_02": 1.5,
	"index_03": 1.55, "middle_03": 1.55, "ring_03": 1.55, "pinky_03": 1.55, "thumb_03": 1.5,
	"index_04_leaf": 1.4, "middle_04_leaf": 1.4, "ring_04_leaf": 1.4, "pinky_04_leaf": 1.4, "thumb_04_leaf": 1.4,
	"neck_01": 0.62,        # cou rentré dans les épaules
	"Head": 0.85,           # tête un peu sortie des épaules (passe 3)
	"thigh": Vector3(1.4, 1.0, 1.0),    # bassin large (seulement en x)
	"ball": 1.5,            # grands pieds
	"ball_leaf": 1.4,
}
## Épaisseur (x, z locaux de l'os) et longueur (y local) de la chair de chaque os.
const CHAIR := {
	"pelvis": [1.4, 1.0], "spine_01": [1.45, 1.0], "spine_02": [1.58, 1.0], "spine_03": [1.72, 1.0],
	"clavicle": [1.9, 1.55], "upperarm": [1.85, 1.6], "lowerarm": [2.0, 1.7], "hand": [2.05, 1.7],
	"index": [1.9, 1.55], "middle": [1.9, 1.55], "ring": [1.9, 1.55], "pinky": [1.9, 1.55], "thumb": [1.9, 1.5],
	"neck_01": [2.15, 0.62], "Head": [1.36 * TK, 1.06 * TK],
	"thigh": [1.62, 1.0], "calf": [1.6, 1.0], "foot": [2.15, 1.0], "ball": [2.25, 1.55],   # pieds larges de troll
}
## Posture voûtée : rotations ajoutées à chaque clé de rotation de l'os, dans toute la bibliothèque, autour d'axes du REPÈRE DU
## MODÈLE (x = droite du troll, y = haut, z = avant) appliqués à la pose animée de l'os (pas à son repos) : [axe, degrés], cumulables.
## Les rotations se COMPOSENT le long de la chaîne (un enfant hérite de celles de ses parents) : le torse penché de ~50° entraînerait
## les bras vers l'arrière, d'où la forte compensation des épaules (-58°) qui les ramène pendants, un peu en avant, mains aux genoux.
## Jambes : bassin basculé (+10°), cuisses -42° (genou en avant de ~32°), mollets +57° (tibia en arrière de ~25°), pieds -25° (à
## plat) ; le bassin est abaissé d'autant (DESCENTE) pour garder les pieds au sol.
const VOUTE := {
	"pelvis": [[Vector3.RIGHT, 10.0]],
	"spine_01": [[Vector3.RIGHT, 14.0]], "spine_02": [[Vector3.RIGHT, 14.0]], "spine_03": [[Vector3.RIGHT, 12.0]],
	"neck_01": [[Vector3.RIGHT, -12.0]], "Head": [[Vector3.RIGHT, -34.0]],
	"clavicle_l": [[Vector3.BACK, 13.0]], "clavicle_r": [[Vector3.BACK, -13.0]],
	"upperarm_l": [[Vector3.RIGHT, -58.0], [Vector3.BACK, -9.0]], "upperarm_r": [[Vector3.RIGHT, -58.0], [Vector3.BACK, 9.0]],
	"lowerarm_l": [[Vector3.RIGHT, -8.0]], "lowerarm_r": [[Vector3.RIGHT, -8.0]],
	"hand_l": [[Vector3.RIGHT, -10.0]], "hand_r": [[Vector3.RIGHT, -10.0]],
	"thigh_l": [[Vector3.RIGHT, -42.0], [Vector3.BACK, 7.0]], "thigh_r": [[Vector3.RIGHT, -42.0], [Vector3.BACK, -7.0]],
	"calf_l": [[Vector3.RIGHT, 57.0]], "calf_r": [[Vector3.RIGHT, 57.0]],
	"foot_l": [[Vector3.RIGHT, -25.0]], "foot_r": [[Vector3.RIGHT, -25.0]],
}
## Abaissement du bassin (repère du modèle, avant l'agrandissement x ECHELLE) qui compense les genoux fléchis.
const DESCENTE := 0.125

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
	var mm := GuerrierNordique.materiau(TrollTextures.tex("meches"), true, true, false, "troll_meches")
	mm.set_shader_parameter("ombre_froide", Vector3(0.50, 0.52, 0.62))   # ombre moins bleue : la fourrure reste crème au crépuscule
	mm.set_shader_parameter("ombre_force", 0.55)
	mm.set_shader_parameter("soleil_desat", 0.85)     # soleil couchant en grande partie ramené au gris : crème, pas « pêche »
	mm.set_shader_parameter("contour_froid", Vector3(0.20, 0.21, 0.25))
	mi.set_surface_override_material(1, mm)
	var ma := GuerrierNordique.materiau(TrollTextures.tex("accessoires"), false, false, false, "troll_acc")
	ma.next_pass = _contour()
	mi.set_surface_override_material(2, ma)
	mi.set_surface_override_material(3, _mat_yeux())
	# taille de créature : l'Armature (parent du squelette) est agrandie ; la racine garde une échelle 1
	(sq.get_parent() as Node3D).scale = Vector3.ONE * ECHELLE
	var ap := racine.get_node("Animations") as AnimationPlayer
	ap.remove_animation_library("")
	ap.add_animation_library("", bibliotheque(sq))
	racine.set_meta("troll_givre", true)
	return racine

## Contour du troll : coque reculée de 10 cm le long du rayon de vue (plus de traits dans les creux du corps).
static func _contour() -> ShaderMaterial:
	if not _mats.has("contour"):
		var c := ShaderMaterial.new()
		c.shader = preload("res://shaders/contour_troll.gdshader")
		c.set_shader_parameter("epaisseur", 1.2)
		c.set_shader_parameter("recul", 0.10)
		Palette.materiaux.append(c)
		Palette._appliquer(c, Palette._ps1_actif)
		_mats["contour"] = c
	return _mats["contour"]

static func _mat_peau() -> ShaderMaterial:
	var m := GuerrierNordique.materiau(TrollTextures.tex("peau"), false, false, false, "troll_peau")
	m.next_pass = _contour()
	m.set_shader_parameter("ombre_froide", Vector3(0.40, 0.46, 0.62))   # ombre propre moins bleue : le modelé peint reste lisible
	m.set_shader_parameter("ombre_force", 0.85)
	m.set_shader_parameter("appoint", Vector3(0.06, 0.07, 0.09))
	m.set_shader_parameter("contour_froid", Vector3(0.22, 0.28, 0.40))
	return m

static func _mat_yeux() -> ShaderMaterial:
	var m := GuerrierNordique.materiau(TrollTextures.tex("yeux"), false, false, false, "troll_yeux")
	m.set_shader_parameter("emission", Color(0.35, 0.85, 1.6))
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
				r = Quaternion(d[0], deg_to_rad(d[1] * _part(an))) * r
			# valeurs d'origine lues avant écriture (la rotation du parent, elle, inclut déjà ses propres décalages)
			var cles := []
			for k in a.track_get_key_count(t):
				cles.append([a.track_get_key_time(t, k), a.track_get_key_value(t, k)])
			for k in cles.size():
				var p := _rot_globale(sq, a, pistes, sq.get_bone_parent(o), cles[k][0])
				var q: Quaternion = cles[k][1]
				a.track_set_key_value(t, k, (p.inverse() * r * p * q).normalized())
	# mains ouvertes en serres (les clips humains ferment le poing : les griffes y disparaissaient) : doigts au repos, légèrement pliés
	for an in _biblio.get_animation_list():
		var a := _biblio.get_animation(an)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var nom_os := String(a.track_get_path(t)).get_slice(":", 1)
			if TrollGivre._famille(nom_os) in ["index", "middle", "ring", "pinky"]:
				var o := sq.find_bone(nom_os)
				var repos := sq.get_bone_rest(o).basis.get_rotation_quaternion()
				for k in a.track_get_key_count(t):
					var q: Quaternion = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, repos.slerp(q, 0.25))
	# genoux fléchis : le bassin descend (piste de position exprimée dans le repère de « root », qui est z-haut)
	for an in _biblio.get_animation_list():
		var a := _biblio.get_animation(an)
		var bas := sq.get_bone_rest(0).basis.inverse() * Vector3(0, -DESCENTE * _part(an), 0)
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).get_slice(":", 1) == "pelvis":
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) + bas)
	if _biblio.has_animation("Punch_Cross"):
		_biblio.add_animation("Troll_Attaque", _biblio.get_animation("Punch_Cross").duplicate(true))
	# balayage de griffes : le coup d'épée large (Sword_Attack), déjà voûté, mains ouvertes en serres
	if _biblio.has_animation("Sword_Attack"):
		_biblio.add_animation("Troll_Griffes", _biblio.get_animation("Sword_Attack").duplicate(true))
	return _biblio

## Part de la voûte appliquée à un clip : les courses penchent déjà le buste (sinon le troll courrait à l'horizontale).
static func _part(an: String) -> float:
	return 0.6 if an in ["Jog_Fwd", "Sprint", "Crouch_Fwd"] else 1.0

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
	ctx.geo_peinture()
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
		var q := (p - tete) / TrollGivre.TK
		if q.z <= 0.02:
			return p
		var avant := smoothstep(0.02, 0.10, q.z)
		var arc := exp(-pow((q.y - 0.125) / 0.025, 2.0)) * avant
		q.z += arc * 0.024
		var bas := smoothstep(0.09, 0.02, q.y) * avant
		q.x *= 1.0 + bas * 0.22
		q.z += bas * 0.026
		# museau : bosse du nez et de la lèvre supérieure, avancée (passe 3 : museau plus marqué)
		var mus := exp(-pow((q.y - 0.075) / 0.03, 2.0) - pow(q.x / 0.045, 2.0)) * avant
		q.z += mus * 0.016
		return tete + q * TrollGivre.TK

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

	## Géométrie du corps pour la peinture 3D de la peau (TrollTextures.peau) : positions/normales au nouveau repos, UV,
	## triangle fourré ou nu (même découpe que la fourrure), repères anatomiques.
	func geo_peinture() -> void:
		var four := PackedByteArray()
		four.resize(ci.size() / 3)
		var lp := 0.0
		var s3 := os_("spine_03")
		for t in range(0, ci.size(), 3):
			var p0 := cv[ci[t]]
			var c := (p0 + cv[ci[t + 1]] + cv[ci[t + 2]]) / 3.0
			var nf := (cv[ci[t + 2]] - p0).cross(cv[ci[t + 1]] - p0).normalized()
			if nf.dot(cn[ci[t]] + cn[ci[t + 1]] + cn[ci[t + 2]]) < 0.0:
				nf = -nf
			var reg := region(dom[ci[t]], c, nf)
			four[t / 3] = 1 if (not reg.is_empty() and reg[0] >= 200.0) else 0
			if dom[ci[t]] == s3 and nf.z > 0.5:
				lp = maxf(lp, absf(c.x))
		var rp := {"larg_torse": lp, "tete_k": TrollGivre.TK, "yeux_y": (_centres_yeux()[0] as Vector3).y}
		for b in ["spine_01", "spine_02", "spine_03", "pelvis", "Head", "upperarm_l", "upperarm_r"]:
			rp[b] = g_nouv[os_(b)].origin
		TrollTextures.geo = {"v": cv, "n": cn, "uv": cuv, "i": ci, "four": four, "rep": rp}

	# ------------------------------------------------------------ fourrure en mèches
	## Région de fourrure d'un triangle du corps (au nouveau repos) : [nombre de mèches par m², lg0, lg1, variante min, max, type]
	## ou [] (peau nue). Types : 0 = pend (bas + dehors), 1 = suit le membre (vers l'enfant de l'os), 2 = se dresse (crinière du crâne).
	func region(o: int, c: Vector3, n: Vector3) -> Array:
		var nom := sq.get_bone_name(o)
		var f := TrollGivre._famille(nom)
		var tete := g_nouv[os_("Head")].origin
		match f:
			"Head":
				var q := (c - tete) / TrollGivre.TK
				if q.z > 0.035 and q.y < 0.17 and q.y > 0.025 and absf(q.x) < 0.075:
					return []                                   # visage nu
				if absf(q.x) > 0.06 and q.y > 0.095 and q.y < 0.165 and q.z > -0.03 and q.z < 0.04:
					return []                                   # tour des oreilles
				if q.z > 0.02 and q.y <= 0.025:
					return [700.0, 0.14, 0.24, 0, 2, 0]         # barbe (pend sur le haut du poitrail)
				if absf(q.x) >= 0.06 and q.z > -0.03 and q.y < 0.11:
					return [900.0, 0.18, 0.28, 0, 2, 4]         # favoris : la crinière ENCADRE le visage et tombe sur le poitrail
				if q.y > 0.15 and q.z > 0.02:
					return [1250.0, 0.06, 0.10, 0, 2, 2]        # frange courte : ne tombe pas devant les yeux
				if q.y > 0.15:
					return [1250.0, 0.13, 0.21, 0, 2, 2]         # crâne : touffes rejetées en arrière, pointes givrées
				return [950.0, 0.19, 0.30, 0, 2, 3]             # crinière (côtés, nuque) : longue, tombe sur les épaules
			"neck_01":
				if n.z > 0.1:
					return []                                   # gorge nue (la barbe la couvre)
				return [800.0, 0.18, 0.28, 0, 3, 3]
			"clavicle":
				if n.z < 0.3:
					return [900.0, 0.22, 0.34, 0, 2, 3]         # manteau des épaules (dessus et dos), tombe sur le deltoïde
				return []
			"spine_03":
				if n.z < -0.15 or (n.y > 0.6 and n.z < 0.3):
					return [520.0, 0.17, 0.27, 1, 4, 3]         # haut du dos
				if absf(c.x) < 0.07 and c.y > g_nouv[os_("spine_03")].origin.y - 0.10:
					return [160.0, 0.10, 0.17, 0, 2, 0]         # touffe du sternum (prolonge la barbe)
				return [28.0, 0.05, 0.08, 3, 5, 0]              # poitrine : poils clairsemés
			"spine_02", "spine_01":
				if c.y < g_nouv[os_("pelvis")].origin.y + 0.13:
					return [520.0, 0.13, 0.22, 3, 6, 0]         # ceinture de poils (taille)
				if c.z < -0.02:
					return [420.0, 0.15, 0.24, 2, 5, 3]         # dos
				if absf(c.x) < 0.03:
					return [90.0, 0.05, 0.08, 3, 5, 0]          # ligne de poils du nombril
				return []                                       # ventre nu
			"pelvis":
				if c.y > g_nouv[os_("pelvis")].origin.y - 0.06:
					return [520.0, 0.14, 0.24, 3, 6, 0]         # pagne de poils
				return []
			"thigh":
				if c.y > g_nouv[os_(nom)].origin.y - 0.12:
					return [460.0, 0.13, 0.22, 3, 6, 0]         # pagne (haut des cuisses)
				if n.z < 0.3:
					return [150.0, 0.09, 0.14, 4, 7, 0]         # cuisse : poil plus court, gris
				return []
			"upperarm":
				var pres := clampf(1.0 - absf(c.x - g_nouv[os_(nom)].origin.x) / 0.18, 0.0, 1.0)
				return [560.0 + 500.0 * pres, 0.15 + 0.06 * pres, 0.25 + 0.08 * pres, 0, 4, 1]   # bras fourrés, deltoïde bien couvert             # bras entièrement fourrés, mèches pendantes
			"lowerarm":
				var axe2 := g_nouv[os_(nom)].origin
				var t := clampf(absf(c.x - axe2.x) / 0.40, 0.0, 1.0)
				return [420.0 + 300.0 * t, 0.15, 0.25, 0, 4, 1]   # avant-bras très fourni (manchon blanc), pend
			"hand":
				if n.y > 0.3 and absf(c.x - g_nouv[os_(nom)].origin.x) < 0.07:
					return [380.0, 0.07, 0.11, 2, 5, 1]         # touffes du poignet
				return []
			"calf":
				var genou := g_nouv[os_(nom)].origin.y
				var t2 := clampf((genou - c.y) / 0.45, 0.0, 1.0)
				return [260.0 + 320.0 * t2, 0.12, 0.20, 2, 6, 0]   # mollet, guêtre de poils vers la cheville
			"foot":
				if n.y > 0.3 and c.z < g_nouv[os_(nom)].origin.z + 0.08:
					return [320.0, 0.07, 0.12, 2, 6, 0]
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
			var attendu: float = reg[0] * aire * TrollGivre.DENSITE
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
						dir = (Vector3.DOWN * 1.0 + e3 * 0.35 + nrm * (0.32 - 0.22 * maxf(nrm.y, 0.0))).normalized()   # se détache sans partir à l'horizontale
					1:
						var enfant := (g_nouv[mini(o + 1, g_nouv.size() - 1)].origin - g_nouv[o].origin).normalized()
						dir = (enfant * 0.9 + nrm * 0.28).normalized()
					2:
						dir = (Vector3.UP * 0.12 + Vector3(0, 0, -0.8) + nrm * 0.55).normalized()
					4:
						# favoris : tombent le long des joues, un peu en avant et en dehors (encadrent le visage)
						dir = (Vector3.DOWN * 0.85 + ext * 0.45 + Vector3(0, 0, 0.05) + nrm * 0.22).normalized()
				var cote := dir.cross(nrm)
				if cote.length() < 0.05:
					cote = dir.cross(Vector3.FORWARD)
				cote = cote.normalized()
				# longueur : tirage + champ lent (plaques de poil plus long / plus court) ; quelques longues touffes dépassent
				var champ := 0.8 + 0.45 * (sin(p.x * 23.0 + p.y * 7.0) * sin(p.z * 19.0 - p.y * 11.0) * 0.5 + 0.5)
				var lg: float = lerpf(reg[1], reg[2], pow(_h(k), 0.7)) * champ * (1.3 if _h(k + 5) < 0.15 else 1.0)
				var larg := lerpf(0.13, 0.20, _h(k + 1)) * clampf(lg / 0.12, 0.55, 1.0)
				var variante := int(reg[3]) + int(_h(k + 2) * (int(reg[4]) - int(reg[3]) + 1))
				if reg[0] >= 200.0 and _h(k + 7) < 0.2:
					variante = 6 + int(_h(k + 8) * 2.0)               # sous-couche : touffe courte et sombre sous les autres
					lg *= 0.6
				var sens := 1.0 if _h(k + 9) < 0.5 else -1.0
				_carte(p + nrm * 0.004 - dir * 0.015, cote, dir, larg, lg, mini(variante, 7), poids(i_proche), nrm, sens)
				k += 3
				nb += 1
		if GuerrierNordique.chrono:
			print("TROLL mèches : %d cartes" % nb)

	## Touffe : carte effilée (pointe à 70 % de la racine), 1 ou 2 tronçons qui se décollent de la peau puis se RECOURBENT
	## (vers le bas et sur le côté `sens`) ; u = la case de 32 texels de la variante, v = 0 racine -> 1 pointe.
	func _carte(r: Vector3, cote: Vector3, dir: Vector3, larg: float, lg: float, variante: int, pw: Array, nrm: Vector3, sens := 1.0) -> void:
		var u0 := (variante * float(TrollTextures.MW) + 0.5) / (8.0 * TrollTextures.MW)
		var u1 := (variante * float(TrollTextures.MW) + TrollTextures.MW - 0.5) / (8.0 * TrollTextures.MW)
		var segs := 1 if lg < 0.11 else 2
		var chute := (dir + Vector3.DOWN * 0.5 + cote * 0.6 * sens).normalized()
		var dedans := r - nrm * 0.1
		var a := r
		for j in segs:
			var t0 := float(j) / segs
			var t1 := float(j + 1) / segs
			var d := dir.lerp(chute, (t0 + t1) * 0.5).normalized()
			if j == 0 and segs > 1:
				d = (d + nrm * 0.3 * (1.0 - maxf(nrm.y, 0.0))).normalized()   # se décolle de la peau (pas sur le dessus des épaules)
			var b := a + d * lg / segs
			var w0 := larg * lerpf(1.0, 0.7, t0) * 0.5
			var w1 := larg * lerpf(1.0, 0.7, t1) * 0.5
			_quad(dec, a - cote * w0, a + cote * w0, b + cote * w1, b - cote * w1, Vector2(u0, t0), Vector2(u1, t0), Vector2(u1, t1), Vector2(u0, t1), [pw, pw, pw, pw], dedans)
			a = b

	# ------------------------------------------------------------ griffes, crocs, gueule, arcade, yeux
	func accessoires() -> void:
		# GRANDES griffes d'ivoire au bout de chaque doigt (trait le plus marquant de la référence), recourbées vers la paume (-y au repos)
		for cote in ["l", "r"]:
			for f in ["index", "middle", "ring", "pinky", "thumb"]:
				var o3 := os_("%s_03_%s" % [f, cote])
				var bout := g_nouv[os_("%s_04_leaf_%s" % [f, cote])].origin
				var d := (bout - g_nouv[o3].origin).normalized()
				var lg := 0.15 if f != "thumb" else 0.12
				var base := bout - d * 0.02
				var pointe := base + d * lg + Vector3.DOWN * lg * 0.6
				cone(op, base, pointe, 0.021, 4, rigide(o3), TrollTextures.R_GRIFFE, Vector3.UP * lg * 0.16)
			# griffes des orteils : 4 en éventail au bout du pied
			var ob := os_("ball_%s" % cote)
			var bout_p := g_nouv[os_("ball_leaf_%s" % cote)].origin
			for j in 4:
				var dx := (j - 1.5) * 0.056 * (1.0 if cote == "l" else -1.0)
				var base := bout_p + Vector3(dx, 0.03, -0.02)
				var pointe := base + Vector3(dx * 0.45, -0.05, 0.12)
				cone(op, base, pointe, 0.022, 4, rigide(ob), TrollTextures.R_GRIFFE, Vector3.UP * 0.02)
		var hd := os_("Head")
		var pw := rigide(hd)
		var yeux := _centres_yeux()
		var arc := TrollTextures.R_ARCADE
		var gq := TrollTextures.R_GUEULE
		var cr := TrollTextures.R_CROC
		# arcade sourcilière lourde et froncée : prisme au-dessus des yeux, plus bas vers le nez (air féroce)
		var oy: Vector3 = (yeux[0] + yeux[1]) * 0.5
		var pts := [porter(Vector3(-0.07, 1.716, 0.058), hd), porter(Vector3(-0.014, 1.700, 0.090), hd), porter(Vector3(0.014, 1.700, 0.090), hd), porter(Vector3(0.07, 1.716, 0.058), hd)]
		for i in 3:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var haut := Vector3(0, 0.024, -0.012) * TrollGivre.TK
			var avant := Vector3(0, -0.002, 0.022) * TrollGivre.TK
			_quad(op, a + haut, b + haut, b + avant, a + avant, _uva(arc.position.x + i * 5, arc.position.y + 1), _uva(arc.position.x + i * 5 + 5, arc.position.y + 1),
				_uva(arc.position.x + i * 5 + 5, arc.end.y - 3), _uva(arc.position.x + i * 5, arc.end.y - 3), [pw, pw, pw, pw], oy - Vector3(0, 0, 0.05))
			_quad(op, a + avant, b + avant, b + Vector3(0, -0.016, 0.006) * TrollGivre.TK, a + Vector3(0, -0.016, 0.006) * TrollGivre.TK, _uva(arc.position.x + i * 5, arc.end.y - 2), _uva(arc.position.x + i * 5 + 5, arc.end.y - 2),
				_uva(arc.position.x + i * 5 + 5, arc.end.y - 0.5), _uva(arc.position.x + i * 5, arc.end.y - 0.5), [pw, pw, pw, pw], oy - Vector3(0, 0, 0.05))
		# oreilles pointues : cônes de peau sur les côtés du crâne, vers le haut, le dehors et l'arrière (la crinière s'écarte autour)
		for s: float in [-1.0, 1.0]:
			var base_o := porter(Vector3(0.074 * s, 1.708, 0.005), hd)
			cone(op, base_o, base_o + Vector3(0.085 * s, 0.05, -0.05) * TrollGivre.TK, 0.026 * TrollGivre.TK, 4, pw, arc)
		# gueule grande ouverte (trapèze sombre devant la bouche), crocs du haut et défenses du bas
		var m0 := porter(Vector3(-0.042, 1.648, 0.094), hd)
		var m1 := porter(Vector3(0.042, 1.648, 0.094), hd)
		var m2 := porter(Vector3(0.032, 1.596, 0.088), hd)
		var m3 := porter(Vector3(-0.032, 1.596, 0.088), hd)
		var fz := Vector3(0, 0, 0.008) * TrollGivre.TK
		_quad(op, m0 + fz, m1 + fz, m2 + fz, m3 + fz, _uva(gq.position.x, gq.position.y), _uva(gq.end.x, gq.position.y), _uva(gq.end.x, gq.end.y), _uva(gq.position.x, gq.end.y), [pw, pw, pw, pw], (m0 + m2) * 0.5 - Vector3(0, 0, 0.05))
		for s: float in [-1.0, 1.0]:
			var hautc := porter(Vector3(0.028 * s, 1.649, 0.093), hd) + fz * 1.5
			var K := TrollGivre.TK
			cone(op, hautc, hautc + Vector3(-0.002 * s, -0.042, 0.006) * K, 0.011 * K, 3, pw, cr)
			var petit := porter(Vector3(0.011 * s, 1.649, 0.094), hd) + fz * 1.5
			cone(op, petit, petit + Vector3(0, -0.02, 0.003) * K, 0.006 * K, 3, pw, cr)
			var basc := porter(Vector3(0.034 * s, 1.595, 0.088), hd) + fz * 1.5
			cone(op, basc, basc + Vector3(0.006 * s, 0.05, 0.008) * K, 0.013 * K, 3, pw, cr)
		# nez large et écrasé (passe 3) : pyramide de peau entre les yeux et la gueule, narines sombres dessous
		var nz_h := porter(Vector3(0.0, 1.690, 0.094), hd)
		var nz_p := porter(Vector3(0.0, 1.664, 0.104), hd) + Vector3(0, 0, 0.022) * TrollGivre.TK
		var nz_g := porter(Vector3(-0.026, 1.656, 0.096), hd) + Vector3(0, 0, 0.006)
		var nz_d := porter(Vector3(0.026, 1.656, 0.096), hd) + Vector3(0, 0, 0.006)
		var nz_b := porter(Vector3(0.0, 1.655, 0.100), hd) + Vector3(0, 0, 0.010) * TrollGivre.TK
		var nc := (nz_h + nz_b) * 0.5 - Vector3(0, 0, 0.04)
		var ua := _uva(arc.position.x + 2, arc.position.y + 2)
		var ub := _uva(arc.position.x + 12, arc.position.y + 2)
		var uc := _uva(arc.position.x + 7, arc.position.y + 9)
		_tri(op, [nz_h, nz_g, nz_p], [ua, ub, uc], [pw, pw, pw], nc)
		_tri(op, [nz_h, nz_p, nz_d], [ua, uc, ub], [pw, pw, pw], nc)
		var ga := _uva(gq.position.x + 4, gq.position.y + 6)
		var gb := _uva(gq.position.x + 12, gq.position.y + 6)
		var gc := _uva(gq.position.x + 8, gq.position.y + 9)
		_tri(op, [nz_g, nz_b, nz_p], [ga, gc, gb], [pw, pw, pw], nc)
		_tri(op, [nz_p, nz_b, nz_d], [gb, gc, ga], [pw, pw, pw], nc)
		# yeux luisants : cartes dans les orbites, plus grandes (lisibles à 4 m)
		for c: Vector3 in yeux:
			var sx := signf(c.x)
			var dx := Vector3(0.025, 0, 0.006 * -sx) * TrollGivre.TK
			var dy := Vector3(0, 0.013, 0) * TrollGivre.TK
			var p := c + Vector3(0, -0.003, 0.004)
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
