class_name AnimLod
extends Node
## Animation des PNJ (villageois, gardes) à cadence réduite quand ils sont HORS DU CHAMP (derrière ou sur le côté du joueur, à plus de 3 m) :
## leur AnimationPlayer passe en mode manuel et n'avance qu'une image sur 4 (avec le temps cumulé : même mouvement, mêmes signaux). Le squelette, l'IK des
## pieds et l'orientation de tête (modificateurs) ne sont recalculés qu'à ce moment-là. Dans le champ, rien ne change (mode normal).
## Opti 2026-11-20 (persos_anim) : un modificateur de squelette ACTIF tourne à chaque image même si l'animation est figée (mesuré, Godot 4.7) ;
## le Skeleton3D passe donc lui aussi en mode MANUEL hors champ et avance (skeleton.advance) avec l'animation : IK des pieds (2 rayons), tête,
## orientation des mains et ressorts ne coûtent plus rien entre deux pas. --sans-opti-squelette-lod : comportement d'avant (modificateurs à chaque image).
##   AnimLod.inscrire(pnj, pnj.anim)   (une fois, à la création du PNJ)
## Réévalué toutes les 0,1 s ; la marge (90° de part et d'autre de l'axe de vue, pour un demi-champ d'environ 55°) laisse 0,2 s à un demi-tour rapide.

const PAS_EVAL := 0.1
const CADENCE := 4
const DIST_MIN := 3.0
## Opti 2026-11-20 : DANS le champ mais loin, cadence réduite aussi (à 480x270, un PNJ de 1,8 m fait ~13 px de haut à 25 m, ~6 px à 50 m) :
## 1 image sur 2 au-delà de DIST_LOIN, 1 sur 3 au-delà de DIST_TRES_LOIN. --sans-opti-anim-distance : cadence pleine dans le champ.
const DIST_LOIN := 25.0
const DIST_TRES_LOIN := 50.0
static var opti_distance := not OS.get_cmdline_user_args().has("--sans-opti-anim-distance")

static var _inst: AnimLod
static var opti_squelette := not (OS.get_cmdline_user_args().has("--sans-opti-squelette-lod") or OS.get_cmdline_user_args().has("--sans-opti-squelettes"))
## Opti 2026-11-20 (2) : DANS le champ, les modificateurs COSMÉTIQUES (pieds au sol + IK + orienteur, suivi de tête, ressorts) s'effacent avec
## la distance : influence 1 jusqu'à DIST_MODIF, 0 à DIST_MODIF_FIN (fondu linéaire, réévalué toutes les 0,1 s : pas d'à-coup), et au-delà le
## squelette passe en mode MANUEL sans être avancé : plus aucun modificateur ni recalcul (l'animation pose toujours les os). Un squelette qui a
## d'AUTRES modificateurs (ragdoll, coupe, lance, arc…) n'est jamais gelé : seuls ses cosmétiques sont coupés. --sans-opti-squelettes : rien.
const DIST_MODIF := 10.0
const DIST_MODIF_FIN := 12.0
var _items: Array[Dictionary] = []
var _t := 0.0
var _image := 0

static func inscrire(pnj: Node3D, anim: AnimationPlayer) -> void:
	if pnj == null or anim == null:
		return
	if _inst == null or not is_instance_valid(_inst):
		_inst = AnimLod.new()
		_inst.name = "AnimLod"
		pnj.get_tree().root.add_child.call_deferred(_inst)
	var racine := anim.get_node_or_null(anim.root_node) as Node3D
	if racine != null:
		FusionOmbre.equiper.call_deferred(racine)      # une seule ombre par personnage (fusion_ombre.gd)
	_inst._items.append({"n": pnj, "a": anim, "acc": 0.0, "lent": false, "sk": null, "cad": 1, "mods": [], "autres": false, "nb": -1, "w": 1.0})

## Squelette animé par `a` (sous sa racine), mis en cache ; null si aucun.
static func _squelette(it: Dictionary) -> Skeleton3D:
	var sk: Variant = it["sk"]
	if sk != null and is_instance_valid(sk):
		return sk as Skeleton3D
	var a: AnimationPlayer = it["a"]
	var r := a.get_node_or_null(a.root_node)
	var s: Skeleton3D = r.find_child("Skeleton3D", true, false) as Skeleton3D if r != null else null
	it["sk"] = s
	return s

## Modificateurs cosmétiques du squelette (rescannés quand ses enfants changent) ; "autres" = il en a d'autres, actifs (à respecter).
static func _modifs(it: Dictionary, sk: Skeleton3D) -> void:
	if sk.get_child_count() == int(it["nb"]):
		return
	it["nb"] = sk.get_child_count()
	var mods: Array = []
	var autres := false
	for c in sk.get_children():
		if not (c is SkeletonModifier3D):
			continue
		if c is PiedsAuSol or c is PiedsAuSol.Orienteur or c is TwoBoneIK3D or c is SpringBoneSimulator3D or (c.get_script() != null and c.get_script().get_global_name() == "" and c.has_method("_tourner")):
			mods.append(c)
		elif (c as SkeletonModifier3D).active:
			autres = true
	it["mods"] = mods
	it["autres"] = autres

## Poids des cosmétiques (0-1) posé sur leurs influences.
static func _poids(it: Dictionary, w: float) -> void:
	if absf(w - float(it["w"])) < 0.001:
		return
	it["w"] = w
	for c in it["mods"]:
		if is_instance_valid(c):
			(c as SkeletonModifier3D).influence = w

## Avance le squelette en mode manuel (modificateurs) du temps cumulé.
static func _avancer(it: Dictionary, acc: float) -> void:
	var a: AnimationPlayer = it["a"]
	a.advance(acc)
	if opti_squelette:
		var sk := _squelette(it)
		if sk != null and sk.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL and (float(it["w"]) > 0.0 or bool(it["autres"])):
			sk.advance(acc)

func _process(dt: float) -> void:
	_image += 1
	_t -= dt
	var evaluer := _t <= 0.0
	var cam: Camera3D = null
	var cp := Vector3.ZERO
	var av := Vector3.ZERO
	if evaluer:
		_t = PAS_EVAL
		cam = get_viewport().get_camera_3d()
		if cam != null:
			cp = cam.global_position
			av = -cam.global_transform.basis.z
	var i := 0
	while i < _items.size():
		var it: Dictionary = _items[i]
		var n: Node3D = it["n"] as Node3D if is_instance_valid(it["n"]) else null
		var a: AnimationPlayer = it["a"] as AnimationPlayer if is_instance_valid(it["a"]) else null
		if n == null or a == null:
			_items.remove_at(i)
			continue
		if evaluer and cam != null:
			var v := n.global_position - cp
			var d := v.length()
			var hors := d > DIST_MIN and av.dot(v) < 0.0
			var cad := CADENCE if hors else (3 if d > DIST_TRES_LOIN else (2 if d > DIST_LOIN else 1))
			if not opti_distance and not hors:
				cad = 1
			it["cad"] = cad
			hors = cad > 1
			if hors != it["lent"]:
				it["lent"] = hors
				a.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if hors else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
				if not hors and float(it["acc"]) > 0.0:
					_avancer(it, float(it["acc"]))
					it["acc"] = 0.0
			if opti_squelette:
				var sk := _squelette(it)
				if sk != null:
					_modifs(it, sk)
					var w := 1.0 if hors and d < DIST_MODIF else clampf((DIST_MODIF_FIN - d) / (DIST_MODIF_FIN - DIST_MODIF), 0.0, 1.0)
					_poids(it, w)
					var gel := hors or (w <= 0.0 and not bool(it["autres"]))
					var mode := Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL if gel else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
					if sk.modifier_callback_mode_process != mode:
						sk.modifier_callback_mode_process = mode
		if it["lent"] and n.can_process():
			it["acc"] = float(it["acc"]) + dt
			if (_image + i) % int(it["cad"]) == 0:
				_avancer(it, float(it["acc"]))
				it["acc"] = 0.0
		i += 1
