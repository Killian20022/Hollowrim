class_name ReactionOs
extends SkeletonModifier3D
## Réaction procédurale aux coups, ajoutée PAR-DESSUS l'animation (Hit_Chest, Sword_Idle, attaque…) : des ressorts amortis plient
## le corps dans le sens du coup, puis reviennent. Plus le stagger est fort, plus le corps encaisse. En état étourdi, un
## balancement lent (le corps titube) s'y ajoute.
##   reaction.frapper(direction_monde, force)                         buste + tête (ancienne interface)
##   reaction.frapper_zone(direction_monde, force, zone, lourd)        réaction SELON LA ZONE ET LA PUISSANCE (§8) :
##     tete    la tête et la nuque partent fort (coup du lapin), le buste suit peu
##     torse   le buste plie dans le sens du coup et se tord vers le côté touché
##     bras    le bras du côté touché est chassé, le buste tourne
##     jambes  le genou cède (flexion brève), le buste bascule un peu en avant
##   léger : SURSAUT NERVEUX (ressorts raides, petite amplitude, frisson bref) — lourd : ressorts plus mous, grande amplitude,
##   retour lent (la titubation et le recul viennent de l'ennemi : draugr._tituber).
## Désactivé à la mort (le ragdoll prend la main) : active = false.

## Part de la flexion prise par chaque os (somme ≈ 1,3 : la tête part un peu plus que le buste).
const POIDS := {"spine_01": 0.25, "spine_02": 0.25, "spine_03": 0.3, "neck_01": 0.2, "Head": 0.3}
const RAIDEUR := 140.0
const AMORTI := 13.0
## Sursaut (coup léger) : ressorts plus raides et plus amortis (retour en ~0,15 s), frisson de 0,18 s.
const RAIDEUR_SURSAUT := 320.0
const AMORTI_SURSAUT := 24.0
const FRISSON := 0.18

var etourdi := false
var _d := Vector3.ZERO      # flexion du buste (monde, horizontale) : direction × angle
var _v := Vector3.ZERO
var _td := Vector3.ZERO     # flexion propre de la tête / nuque
var _tv := Vector3.ZERO
var _tors := 0.0            # torsion du buste autour de la verticale (rad)
var _tors_v := 0.0
var _bras := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var _bras_v := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var _genou := 0.0
var _genou_v := 0.0
var _raideur := RAIDEUR
var _amorti := AMORTI
var _frisson := 0.0
var _t := 0.0
var _os: Array[int] = []
var _poids: Array[float] = []
var _ids := {}
## Dernière réaction (débogage, tests) : {zone, force, lourd}.
var derniere := {}

func frapper(direction: Vector3, force: float) -> void:
	var h := Vector3(direction.x, 0.0, direction.z)
	if h.length() < 0.01:
		return
	_v += h.normalized() * force * 9.0

## Réaction selon la zone touchée, la direction du coup (mouvement de la lame) et sa puissance (force ~0,15 léger → 0,7 lourd).
func frapper_zone(direction: Vector3, force: float, zone: String, lourd: bool) -> void:
	var sq := get_skeleton()
	var corps := sq.global_transform.basis if sq else Basis()
	var h := Vector3(direction.x, 0.0, direction.z)
	if h.length() < 0.01:
		h = -corps.z
	h = h.normalized()
	derniere = {"zone": zone, "force": force, "lourd": lourd}
	if lourd:
		_raideur = RAIDEUR * 0.8
		_amorti = AMORTI * 0.85
	else:
		_raideur = RAIDEUR_SURSAUT
		_amorti = AMORTI_SURSAUT
		_frisson = FRISSON
	var cote := signf(h.dot(corps.x.normalized()))       # côté vers lequel la lame pousse (repère du corps)
	var k := force * (9.0 if lourd else 13.0)
	match zone:
		"tete":
			_tv += h * k * 1.6
			_v += h * k * 0.35
			_tors_v += cote * k * 0.25
		"bras":
			var s := "l" if cote > 0.0 else "r"
			_bras_v[s] = Vector3(_bras_v[s]) + h * k * 1.8
			_v += h * k * 0.3
			_tors_v += cote * k * 0.6
		"jambes":
			_genou_v += k * (1.4 if lourd else 0.8)
			_v += (h * 0.4 - corps.z.normalized() * 0.4) * k * 0.5
		_:
			_v += h * k
			_tors_v += cote * k * 0.45
			_tv += h * k * 0.25

func _id(sq: Skeleton3D, nom: String) -> int:
	if not _ids.has(nom):
		_ids[nom] = sq.find_bone(nom)
	return _ids[nom]

func _tourner(sq: Skeleton3D, i: int, axe_monde: Vector3, angle: float) -> void:
	if i < 0 or absf(angle) < 1e-4:
		return
	var base_sq := sq.global_transform.basis.orthonormalized()
	var g := sq.get_bone_global_pose(i).basis.orthonormalized()
	var axe_os := ((base_sq * g).inverse() * axe_monde).normalized()
	sq.set_bone_pose_rotation(i, sq.get_bone_pose_rotation(i) * Quaternion(axe_os, angle))

## Flexion (vecteur horizontal direction × angle) appliquée à l'os i, part p.
func _plier(sq: Skeleton3D, i: int, d: Vector3, p: float) -> void:
	var ang := d.length()
	if ang < 0.002:
		return
	_tourner(sq, i, Vector3.UP.cross(d / ang).normalized(), ang * p)

func _process_modification_with_delta(delta: float) -> void:
	var sq := get_skeleton()
	if sq == null:
		return
	if _os.is_empty():
		for nom: String in POIDS:
			var i := sq.find_bone(nom)
			if i >= 0:
				_os.append(i)
				_poids.append(float(POIDS[nom]))
	var dt := minf(delta, 0.05)
	_t += dt
	var cible := Vector3.ZERO
	if etourdi:
		cible = Vector3(sin(_t * 2.3), 0.0, cos(_t * 1.7) * 0.6) * 0.16
	# les ressorts reprennent peu à peu leur raideur normale après un sursaut
	_raideur = lerpf(_raideur, RAIDEUR, 1.0 - exp(-3.0 * dt))
	_amorti = lerpf(_amorti, AMORTI, 1.0 - exp(-3.0 * dt))
	_v += (-(_d - cible) * _raideur - _v * _amorti) * dt
	_d = (_d + _v * dt).limit_length(0.9)
	_tv += (-_td * _raideur * 1.2 - _tv * _amorti) * dt
	_td = (_td + _tv * dt).limit_length(0.8)
	_tors_v += (-_tors * _raideur - _tors_v * _amorti) * dt
	_tors = clampf(_tors + _tors_v * dt, -0.5, 0.5)
	_genou_v += (-_genou * _raideur * 0.9 - _genou_v * _amorti) * dt
	_genou = clampf(_genou + _genou_v * dt, -0.1, 0.55)
	for s: String in ["l", "r"]:
		_bras_v[s] = Vector3(_bras_v[s]) + (-Vector3(_bras[s]) * _raideur - Vector3(_bras_v[s]) * _amorti) * dt
		_bras[s] = (Vector3(_bras[s]) + Vector3(_bras_v[s]) * dt).limit_length(1.0)
	_frisson = maxf(0.0, _frisson - dt)
	# frisson nerveux : petites secousses rapides qui s'éteignent (sinus incommensurables, même rendu à toute cadence)
	var fr := Vector3(sin(_t * 61.0), 0.0, sin(_t * 47.0 + 1.1)) * 0.035 * (_frisson / FRISSON)
	var base := _d + fr
	for k in _os.size():
		_plier(sq, _os[k], base, _poids[k])
	_plier(sq, _id(sq, "neck_01"), _td, 0.4)
	_plier(sq, _id(sq, "Head"), _td + fr, 0.6)
	if absf(_tors) > 1e-3:
		for nom in ["spine_01", "spine_02", "spine_03"]:
			_tourner(sq, _id(sq, nom), Vector3.UP, _tors / 3.0)
	for s: String in ["l", "r"]:
		_plier(sq, _id(sq, "upperarm_" + s), _bras[s], 1.0)
	if absf(_genou) > 1e-3:
		var droite := sq.global_transform.basis.x.normalized()
		for s in ["l", "r"]:
			_tourner(sq, _id(sq, "thigh_" + s), droite, -_genou)
			_tourner(sq, _id(sq, "calf_" + s), droite, _genou * 1.8)

## Amplitude courante (rad) des ressorts (tests) : buste, tête, genou.
func amplitude() -> Vector3:
	return Vector3(_d.length(), _td.length(), _genou)
