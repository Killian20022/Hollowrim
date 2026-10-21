class_name MageJupe
extends MeshInstance3D
## Jupe de la robe du Mage nordique : maillage recalculé à chaque mise à jour du squelette (signal skeleton_updated, après
## l'animation ou le ragdoll), dans le repère du Skeleton3D. Une jupe longue pesée sur les os (skinning linéaire) traversait les
## jambes ou se tendait en voile à la course (talon qui remonte) : ici chaque colonne de la jupe PEND du bassin (longueurs de
## tissu conservées) et chaque point est repoussé le long de son rayon hors des jambes (cuisses et mollets en capsules, marge
## comprise) : la jambe reste DANS la jupe par construction, la jupe ne gonfle que là où une jambe la pousse.
## Paroi extérieure (atlas MageTextures.R_JUPE), doublure (R_DOUBLURE) et lèvre d'ourlet. Coût : ~200 points, < 0,2 ms CPU.

var sq: Skeleton3D
var repos: Array = []          # [anneau][secteur] points au repos (repère du squelette)
var longueurs: Array = []      # [anneau][secteur] longueur du tissu entre l'anneau k-1 et k
var uvs := PackedVector2Array()
var index := PackedInt32Array()
var nb_ext := 0                # sommets de la paroi extérieure ((N + 1) x K), puis doublure, puis lèvre
var os_ := {}
var rayon_cuisse := 0.095      # 7 cm de jambe + 2,5 cm de marge (cordes entre deux rayons)
var rayon_mollet := 0.080
var lissage := 0.25
var arr := []
var mat: Material
## dernier état calculé (contrôle des traversées : outils/test_mage.gd)
var anneaux: Array = []

func preparer(s: Skeleton3D, points: Array, m: Material) -> void:
	sq = s
	repos = points
	mat = m
	name = "jupe"
	for o in ["pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]:
		os_[o] = sq.find_bone(o)
	var K := repos.size()
	var N: int = repos[0].size()
	for k in K:
		var l := []
		for i in N:
			l.append(0.0 if k == 0 else (repos[k][i] as Vector3).distance_to(repos[k - 1][i]))
		longueurs.append(l)
	var R := MageTextures.R_JUPE
	var D := MageTextures.R_DOUBLURE
	var A := Vector2(MageTextures.ATLAS)
	var y0: float = repos[0][0].y
	var y1: float = repos[K - 1][0].y
	# paroi extérieure : (N + 1) colonnes (couture dédoublée pour les UV)
	for k in K:
		var v: float = R.position.y + (y0 - float(repos[k][0].y)) / (y0 - y1) * (R.size.y - 0.5)
		for i in N + 1:
			uvs.append(Vector2(R.position.x + R.size.x * float(i) / N, v) / A)
	nb_ext = uvs.size()
	# doublure
	for k in K:
		for i in N + 1:
			uvs.append(Vector2(D.position.x + 2.0 + (D.size.x - 4.0) * float(i) / N, D.position.y + 2.0 + 28.0 * float(k) / (K - 1)) / A)
	# lèvre (anneau intérieur de l'ourlet)
	for i in N + 1:
		uvs.append(Vector2(R.position.x + R.size.x * float(i) / N, R.end.y - 0.5) / A)
	var W := N + 1
	for k in K - 1:
		for i in N:
			var a := k * W + i
			var b := a + 1
			var c := a + W + 1
			var d := a + W
			index.append_array([a, b, c, a, c, d])                                  # extérieur (horaire vu de dehors)
			index.append_array([nb_ext + a, nb_ext + c, nb_ext + b, nb_ext + a, nb_ext + d, nb_ext + c])   # doublure
	var bas := (K - 1) * W
	var levre := nb_ext * 2
	for i in N:
		index.append_array([bas + i, levre + i, bas + i + 1, bas + i + 1, levre + i, levre + i + 1])
	mesh = ArrayMesh.new()
	custom_aabb = AABB(Vector3(-1.2, -0.3, -1.2), Vector3(2.4, 2.4, 2.4))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = index
	sq.skeleton_updated.connect(_sur_mise_a_jour)
	mettre_a_jour()

func _pose(o: String) -> Vector3:
	return sq.get_bone_global_pose(os_[o]).origin

## Coupe horizontale des capsules des jambes à la hauteur y : disques [centre 2D, rayon] (7 sphères par capsule, la coupe
## d'une jambe inclinée ou couchée — talon relevé à la course — est leur union).
func _coupe(caps: Array, y: float) -> Array:
	var res := []
	for cp: Array in caps:
		var a: Vector3 = cp[0]
		var b: Vector3 = cp[1]
		var r: float = cp[2]
		for j in 7:
			var c := a.lerp(b, j / 6.0)
			var dy := absf(c.y - y)
			if dy < r:
				res.append([Vector2(c.x, c.z), sqrt(r * r - dy * dy)])
	return res

## Repousse q le long du rayon horizontal (axe -> q) hors des disques de la coupe. Le disque est « élargi » d'un demi-secteur
## (cos_d, sin_d = cos/sin du demi-angle) : le rayon voisin le couvre aussi, la corde entre deux points ne coupe pas la jambe.
## disques : [direction unitaire depuis l'axe, distance D, rayon] (préparés une fois par anneau).
static func _pousser(q: Vector3, axe: Vector3, disques: Array, cos_d: float, sin_d: float) -> Vector3:
	var u := Vector2(q.x - axe.x, q.z - axe.z)
	var lq := u.length()
	if lq < 1e-5:
		return q
	u /= lq
	var t_max := lq
	for dq: Array in disques:
		var e: Vector2 = dq[0]
		var D: float = dq[1]
		var rr: float = dq[2]
		var c := u.dot(e)
		var sn := absf(u.cross(e))
		var cd := c
		var sd := sn
		if sn > sin_d or c < cos_d:
			cd = c * cos_d + sn * sin_d       # cos(Δ - δ)
			sd = sn * cos_d - c * sin_d       # sin(Δ - δ)
		else:
			cd = 1.0
			sd = 0.0
		if cd <= 0.0:
			continue
		var perp := D * sd
		if perp >= rr:
			continue
		t_max = maxf(t_max, D * cd + sqrt(rr * rr - perp * perp))
	if t_max <= lq:
		return q
	return Vector3(axe.x + u.x * t_max, q.y, axe.z + u.y * t_max)

func calculer() -> Array:
	var K := repos.size()
	var N: int = repos[0].size()
	var po := sq.get_bone_global_pose(os_["pelvis"]) * sq.get_bone_global_rest(os_["pelvis"]).affine_inverse()
	var caps := []
	for c in ["l", "r"]:
		caps.append([_pose("thigh_" + c), _pose("calf_" + c), rayon_cuisse])
		caps.append([_pose("calf_" + c), _pose("foot_" + c), rayon_mollet])
		caps.append([_pose("foot_" + c), _pose("ball_" + c), 0.07])
	var res := []
	res.append([])
	for i in N:
		res[0].append(po * repos[0][i])
	for k in range(1, K):
		var ligne := []
		var ysomme := 0.0
		for i in N:
			var prev: Vector3 = res[k - 1][i]
			var q: Vector3 = po * repos[k][i]
			var d := q - prev
			q = prev + d.normalized() * float(longueurs[k][i])
			ligne.append(q)
			ysomme += q.y
		# lissage latéral (le tissu ne fait pas de pointes d'un secteur à l'autre), puis jambes repoussées (en dernier)
		var axe := po * Vector3(0, repos[k][0].y, MageNordique.Z_CENTRE)
		var disques := []
		for dq: Array in _coupe(caps, ysomme / N):
			var cc: Vector2 = dq[0] - Vector2(axe.x, axe.z)
			var D := cc.length()
			if D > 1e-4:
				disques.append([cc / D, D, dq[1]])
		var cos_d := cos(PI / N)
		var sin_d := sin(PI / N)
		var lisse := []
		for i in N:
			var m: Vector3 = (ligne[(i + N - 1) % N] + ligne[(i + 1) % N]) * 0.5
			var q: Vector3 = (ligne[i] as Vector3).lerp(m, lissage)
			if not disques.is_empty():
				q = _pousser(q, axe, disques, cos_d, sin_d)
			lisse.append(q)
		res.append(lisse)
	anneaux = res
	return res

## Fréquence selon la distance à la caméra active : chaque image à moins de 8 m, une sur 2 jusqu'à 16 m, une sur 4 au-delà ;
## rien si le personnage est caché. `forcer` : calcul immédiat (création, captures, tests).
var _compteur := 0

func _sur_mise_a_jour() -> void:
	if not is_visible_in_tree():
		return
	_compteur += 1
	var pas := 1
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam:
		var d := cam.global_position.distance_to(global_position)
		pas = 1 if d < 8.0 else (2 if d < 16.0 else 4)
	if _compteur % pas == 0:
		mettre_a_jour()

func mettre_a_jour() -> void:
	var res := calculer()
	var K := res.size()
	var N: int = res[0].size()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	v.resize(uvs.size())
	n.resize(uvs.size())
	var W := N + 1
	for k in K:
		for i in W:
			var ii := i % N
			var p: Vector3 = res[k][ii]
			var g: Vector3 = res[k][(ii + N - 1) % N]
			var dd: Vector3 = res[k][(ii + 1) % N]
			var h: Vector3 = res[maxi(k - 1, 0)][ii]
			var b: Vector3 = res[mini(k + 1, K - 1)][ii]
			var nn := (dd - g).cross(b - h).normalized()
			var ax := Vector3(p.x, p.y, p.z) - (sq.get_bone_global_pose(os_["pelvis"]).origin)
			if nn.dot(Vector3(ax.x, 0, ax.z)) < 0.0:
				nn = -nn
			v[k * W + i] = p
			n[k * W + i] = nn
			v[nb_ext + k * W + i] = p - nn * 0.006
			n[nb_ext + k * W + i] = -nn
	var bas := (K - 1) * W
	for i in W:
		v[nb_ext * 2 + i] = v[nb_ext + bas + i] + Vector3(0, 0.002, 0)
		n[nb_ext * 2 + i] = Vector3.DOWN
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	var m := mesh as ArrayMesh
	m.clear_surfaces()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
