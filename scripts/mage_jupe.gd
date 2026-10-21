class_name MageJupe
extends MeshInstance3D
## Jupe de la robe du Mage nordique : maillage recalculé à chaque mise à jour du squelette (signal skeleton_updated, après
## l'animation ou le ragdoll), dans le repère du Skeleton3D. Une jupe longue pesée sur les os (skinning linéaire) traversait les
## jambes ou se tendait en voile à la course (talon qui remonte) : ici chaque colonne de la jupe PEND de la taille (longueurs de
## tissu conservées) et chaque point est repoussé le long de son rayon hors des jambes (cuisses, mollets, pieds en sphères,
## marge comprise) : la jambe reste DANS la jupe, la jupe ne gonfle que là où une jambe la pousse.
## Passe 2 :
##   - PESANTEUR : debout, les colonnes pendent selon la verticale (seul le cap du bassin est suivi, sa bascule ne l'est qu'à
##     SUIVI_BASCULE) : à la course le bassin penche de 20-30° et une jupe rigide partait en balancier jusqu'à 0,75 m derrière ;
##     couché (mort, ragdoll : bassin incliné de plus de ~50°), la jupe suit de nouveau le bassin en entier ;
##   - CLOCHE PLAFONNÉE : aucun point à plus de CLOCHE_MAX de l'axe (ni de son rayon de repos + CLOCHE_JEU). Là où une jambe
##     (genou levé, talon relevé) pousserait le tissu au-delà, la colonne se DRAPE sur la jambe : elle se pose sur le dessus
##     de la jambe au rayon plafond et le reste de la colonne s'y replie ; la jambe sort SOUS l'ourlet local (ourlet relevé
##     par le genou ou le talon) au lieu de gonfler la robe en cloche.
## Paroi extérieure (atlas MageTextures.R_JUPE), doublure (R_DOUBLURE) et lèvre d'ourlet. Calcul en tableaux Packed, sans
## allocation par image hors du maillage (outils/test_mage.gd mesure le coût).

var sq: Skeleton3D
var repos: Array = []          # [anneau][secteur] points au repos (repère du squelette)
var uvs := PackedVector2Array()
var index := PackedInt32Array()
var nb_ext := 0                # sommets de la paroi extérieure ((N + 1) x K), puis doublure, puis lèvre
var os_ := {}
var rayon_cuisse := 0.095      # 7 cm de jambe + 2,5 cm de marge
var rayon_mollet := 0.080
var rayon_pied := 0.07
var lissage := 0.25
const SUIVI_BASCULE := 0.25    # part de la bascule du bassin suivie par la jupe debout (0 = verticale pure)
const CLOCHE_MAX := 0.46       # rayon horizontal maximal depuis l'axe de la jupe (m) ; l'axe est 3 cm derrière le bassin
const CLOCHE_JEU := 0.22       # et au plus rayon de repos + CLOCHE_JEU (le haut de la jupe gonfle moins que l'ourlet)
var arr := []
var mat: Material
## dernier état calculé (contrôle des traversées : outils/test_mage.gd)
var anneaux: Array = []

# --- données précalculées (Packed)
var K := 0
var N := 0
var _rep := PackedVector3Array()    # K x N, points au repos
var _drest := PackedVector3Array()  # K x N, segment de tissu au repos (anneau k-1 -> k)
var _cap := PackedFloat32Array()    # K x N, rayon plafond
var _yk := PackedFloat32Array()     # K, hauteur de l'anneau au repos
# --- tampons réutilisés
var _pts := PackedVector3Array()    # K x N, résultat
var _ligne := PackedVector3Array()  # N
var _sph := PackedFloat32Array()    # sphères des jambes : x, y, z, r
var _disq := PackedFloat32Array()   # disques de la coupe courante : ex, ez, D, r
var _os_jambes := PackedInt32Array()   # thigh, calf, foot, ball (gauche puis droite)
var _drape := PackedByteArray()     # N : colonne drapée (repliée) à partir de l'anneau courant
var _v := PackedVector3Array()
var _n := PackedVector3Array()

func preparer(s: Skeleton3D, points: Array, m: Material) -> void:
	sq = s
	repos = points
	mat = m
	name = "jupe"
	for o in ["pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]:
		os_[o] = sq.find_bone(o)
	for o in ["thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]:
		_os_jambes.append(os_[o])
	K = repos.size()
	N = repos[0].size()
	_rep.resize(K * N)
	_drest.resize(K * N)
	_cap.resize(K * N)
	_yk.resize(K)
	for k in K:
		_yk[k] = float(repos[k][0].y)
		for i in N:
			var p: Vector3 = repos[k][i]
			_rep[k * N + i] = p
			_drest[k * N + i] = Vector3.ZERO if k == 0 else p - (repos[k - 1][i] as Vector3)
			var r := Vector2(p.x, p.z - MageNordique.Z_CENTRE).length()
			_cap[k * N + i] = maxf(r, minf(CLOCHE_MAX, r + CLOCHE_JEU))
	_pts.resize(K * N)
	_ligne.resize(N)
	_drape.resize(N)
	var R := MageTextures.R_JUPE
	var D := MageTextures.R_DOUBLURE
	var A := Vector2(MageTextures.ATLAS)
	var y0: float = _yk[0]
	var y1: float = _yk[K - 1]
	# paroi extérieure : (N + 1) colonnes (couture dédoublée pour les UV)
	for k in K:
		var v: float = R.position.y + (y0 - _yk[k]) / (y0 - y1) * (R.size.y - 0.5)
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
	_v.resize(uvs.size())
	_n.resize(uvs.size())
	mesh = ArrayMesh.new()
	custom_aabb = AABB(Vector3(-1.2, -0.3, -1.2), Vector3(2.4, 2.4, 2.4))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = index
	sq.skeleton_updated.connect(_sur_mise_a_jour)
	mettre_a_jour()

## Sphères des jambes (centre, rayon) le long des capsules cuisse / mollet / pied : la coupe horizontale d'une jambe inclinée
## ou couchée (talon relevé à la course) est l'union des coupes de ses sphères.
func _spheres() -> void:
	if _sph.size() != 32 * 4:
		_sph.resize(32 * 4)
		_disq.resize(32 * 4)
	var o := 0
	for c in 2:
		var th := sq.get_bone_global_pose(_os_jambes[c * 4]).origin
		var ca := sq.get_bone_global_pose(_os_jambes[c * 4 + 1]).origin
		var fo := sq.get_bone_global_pose(_os_jambes[c * 4 + 2]).origin
		var ba := sq.get_bone_global_pose(_os_jambes[c * 4 + 3]).origin
		o = _segment(o, th, ca, rayon_cuisse, 6, 0)
		o = _segment(o, ca, fo, rayon_mollet, 6, 1)
		o = _segment(o, fo, ba, rayon_pied, 3, 1)

func _segment(o: int, a: Vector3, b: Vector3, r: float, nseg: int, j0: int) -> int:
	for j in range(j0, nseg + 1):
		var p := a.lerp(b, float(j) / nseg)
		_sph[o] = p.x
		_sph[o + 1] = p.y
		_sph[o + 2] = p.z
		_sph[o + 3] = r
		o += 4
	return o

## Hauteur du dessus des jambes au point horizontal (x, z) (-1e9 si aucune jambe à cet endroit).
func _dessus_jambe(x: float, z: float) -> float:
	var haut := -1e9
	for s in range(0, _sph.size(), 4):
		var dx := x - _sph[s]
		var dz := z - _sph[s + 2]
		var r := _sph[s + 3]
		var d2 := dx * dx + dz * dz
		if d2 < r * r:
			haut = maxf(haut, _sph[s + 1] + sqrt(r * r - d2))
	return haut

## Calcule les points de la jupe dans _pts (K x N).
func _calculer() -> void:
	var po := sq.get_bone_global_pose(os_["pelvis"]) * sq.get_bone_global_rest(os_["pelvis"]).affine_inverse()
	# pesanteur : cap du bassin seul (debout), bascule suivie en partie ; couché, rotation complète
	var b_plein := po.basis.orthonormalized()
	var bascule := acos(clampf(b_plein.y.y, -1.0, 1.0))
	var f := b_plein.z
	f.y = 0.0
	var cap_y := atan2(f.x, f.z) if f.length_squared() > 1e-8 else 0.0
	var suivi := lerpf(SUIVI_BASCULE, 1.0, smoothstep(deg_to_rad(40.0), deg_to_rad(60.0), bascule))
	var B := Basis(Quaternion(Vector3.UP, cap_y).slerp(b_plein.get_rotation_quaternion(), suivi))
	var plafonne := suivi < 0.6
	_spheres()
	var nsph := _sph.size()
	for i in N:
		_pts[i] = po * _rep[i]
		_drape[i] = 0
	var taille := po * Vector3(0, _yk[0], MageNordique.Z_CENTRE)
	var cos_d := cos(PI / N)
	var sin_d := sin(PI / N)
	for k in range(1, K):
		var ysomme := 0.0
		var base := k * N
		for i in N:
			var prev := _pts[base - N + i]
			var q := prev + B * _drest[base + i] if _drape[i] == 0 else prev
			_ligne[i] = q
			ysomme += q.y
		var ym := ysomme / N
		# axe de la jupe à cette hauteur : sous le centre de la taille, incliné comme les colonnes (pesanteur), coupe des
		# jambes à la hauteur moyenne de l'anneau
		var axe := taille + B * Vector3(0, _yk[k] - _yk[0], 0)
		var nd := 0
		for s in range(0, nsph, 4):
			var dy := absf(_sph[s + 1] - ym)
			var r := _sph[s + 3]
			if dy < r:
				var cx := _sph[s] - axe.x
				var cz := _sph[s + 2] - axe.z
				var D := sqrt(cx * cx + cz * cz)
				if D > 1e-4:
					_disq[nd] = cx / D
					_disq[nd + 1] = cz / D
					_disq[nd + 2] = D
					_disq[nd + 3] = sqrt(r * r - dy * dy)
					nd += 4
		for i in N:
			if _drape[i] != 0:
				_pts[base + i] = _ligne[i]
				continue
			var m := (_ligne[(i + N - 1) % N] + _ligne[(i + 1) % N]) * 0.5
			var q := _ligne[i].lerp(m, lissage)
			var ux := q.x - axe.x
			var uz := q.z - axe.z
			var lq := sqrt(ux * ux + uz * uz)
			if lq < 1e-5:
				_pts[base + i] = q
				continue
			ux /= lq
			uz /= lq
			var t_max := lq
			# repoussé hors des disques (élargis d'un demi-secteur : la corde vers le secteur voisin ne coupe pas la jambe)
			for d in range(0, nd, 4):
				var ex := _disq[d]
				var ez := _disq[d + 1]
				var D := _disq[d + 2]
				var rr := _disq[d + 3]
				var c := ux * ex + uz * ez
				var sn := absf(ux * ez - uz * ex)
				var cd := 1.0
				var sd := 0.0
				if sn > sin_d or c < cos_d:
					cd = c * cos_d + sn * sin_d
					sd = sn * cos_d - c * sin_d
				if cd <= 0.0:
					continue
				var perp := D * sd
				if perp >= rr:
					continue
				t_max = maxf(t_max, D * cd + sqrt(rr * rr - perp * perp))
			var cap := _cap[base + i]
			if plafonne and t_max > cap:
				# drapé : la colonne se pose sur le dessus de la jambe au rayon plafond, le reste s'y replie
				var px := axe.x + ux * cap
				var pz := axe.z + uz * cap
				var y := minf(_pts[base - N + i].y, maxf(q.y, _dessus_jambe(px, pz) + 0.012))
				q = Vector3(px, y, pz)
				_drape[i] = 1
			elif t_max > lq:
				q = Vector3(axe.x + ux * t_max, q.y, axe.z + uz * t_max)
			elif plafonne and lq > cap:
				q = Vector3(axe.x + ux * cap, q.y, axe.z + uz * cap)
			_pts[base + i] = q

## Points de la jupe [anneau][secteur] (contrôle : outils/test_mage.gd).
func calculer() -> Array:
	_calculer()
	var res := []
	for k in K:
		var l := []
		for i in N:
			l.append(_pts[k * N + i])
		res.append(l)
	anneaux = res
	return res

## Fréquence selon la distance à la caméra active : chaque image à moins de 8 m, une sur 2 jusqu'à 16 m, une sur 4 au-delà ;
## rien si le personnage est caché.
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
	_calculer()
	var W := N + 1
	var pel := sq.get_bone_global_pose(os_["pelvis"]).origin
	for k in K:
		var kh := maxi(k - 1, 0) * N
		var kb := mini(k + 1, K - 1) * N
		var kk := k * N
		for i in W:
			var ii := i % N
			var p := _pts[kk + ii]
			var tg := _pts[kk + (ii + 1) % N] - _pts[kk + (ii + N - 1) % N]
			var vt := _pts[kb + ii] - _pts[kh + ii]
			var radial := Vector3(p.x - pel.x, 0.0, p.z - pel.z)
			if vt.length_squared() < 1e-8:
				vt = Vector3.DOWN
			var nn := tg.cross(vt)
			if nn.length_squared() < 1e-10:
				nn = radial
			nn = nn.normalized()
			if nn.dot(radial) < 0.0:
				nn = -nn
			var o := k * W + i
			_v[o] = p
			_n[o] = nn
			_v[nb_ext + o] = p - nn * 0.006
			_n[nb_ext + o] = -nn
	var bas := (K - 1) * W
	for i in W:
		_v[nb_ext * 2 + i] = _v[nb_ext + bas + i] + Vector3(0, 0.002, 0)
		_n[nb_ext * 2 + i] = Vector3.DOWN
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	var m := mesh as ArrayMesh
	m.clear_surfaces()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
