class_name ProtoTampon
extends RefCounted
## Lot 1 (prototype) : tampon d'instantanés reçus [t_reçu, position, lacet, extra] ; lire(t) interpole à l'instant t
## (on lit en retard de DELAI s : ~100 ms, assez pour toujours avoir deux instantanés autour). Pas d'extrapolation.

const DELAI := 0.1
const MAX := 40

var _s: Array = []

func pousser(pos: Vector3, lacet: float, extra: Variant = null) -> void:
	_s.append([Time.get_ticks_msec() / 1000.0, pos, lacet, extra])
	if _s.size() > MAX:
		_s.pop_front()

func vide() -> bool:
	return _s.is_empty()

## {"pos", "lacet", "extra"} à (maintenant - DELAI) ; extra = celui de l'instantané le plus récent des deux.
func lire(maintenant := -1.0) -> Dictionary:
	if _s.is_empty():
		return {}
	var t := (maintenant if maintenant >= 0.0 else Time.get_ticks_msec() / 1000.0) - DELAI
	if t <= _s[0][0]:
		return {"pos": _s[0][1], "lacet": _s[0][2], "extra": _s[0][3]}
	for i in range(_s.size() - 1):
		var a: Array = _s[i]
		var b: Array = _s[i + 1]
		if t <= b[0]:
			var k: float = clampf((t - a[0]) / maxf(b[0] - a[0], 0.0001), 0.0, 1.0)
			return {"pos": (a[1] as Vector3).lerp(b[1], k), "lacet": lerp_angle(a[2], b[2], k), "extra": b[3]}
	var d: Array = _s[-1]
	return {"pos": d[1], "lacet": d[2], "extra": d[3]}
