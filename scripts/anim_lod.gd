class_name AnimLod
extends Node
## Animation des PNJ (villageois, gardes) à cadence réduite quand ils sont HORS DU CHAMP (derrière ou sur le côté du joueur, à plus de 3 m) :
## leur AnimationPlayer passe en mode manuel et n'avance qu'une image sur 4 (avec le temps cumulé : même mouvement, mêmes signaux). Le squelette, l'IK des
## pieds et l'orientation de tête (modificateurs) ne sont recalculés qu'à ce moment-là. Dans le champ, rien ne change (mode normal).
##   AnimLod.inscrire(pnj, pnj.anim)   (une fois, à la création du PNJ)
## Réévalué toutes les 0,1 s ; la marge (90° de part et d'autre de l'axe de vue, pour un demi-champ d'environ 55°) laisse 0,2 s à un demi-tour rapide.

const PAS_EVAL := 0.1
const CADENCE := 4
const DIST_MIN := 3.0

static var _inst: AnimLod
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
	_inst._items.append({"n": pnj, "a": anim, "acc": 0.0, "lent": false})

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
			if hors != it["lent"]:
				it["lent"] = hors
				a.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if hors else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
				if not hors and float(it["acc"]) > 0.0:
					a.advance(float(it["acc"]))
					it["acc"] = 0.0
		if it["lent"] and n.can_process():
			it["acc"] = float(it["acc"]) + dt
			if (_image + i) % CADENCE == 0:
				a.advance(float(it["acc"]))
				it["acc"] = 0.0
		i += 1
