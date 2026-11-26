extends SceneTree
## joueur_base passe 2 : sections du corps de l'homme et de la femme (au repos, repère du squelette), par os : largeur (x) et
## profondeur (z) du tronc à la hauteur de chaque os du tronc, rayon des membres autour de chaque segment, longueurs d'os.
## Sert à régler JoueurBase.AJUSTEMENT_ARMURE (armures faites pour l'homme, portées par la femme).
##   godot --headless --path . --script res://outils/mesure_corps_joueur.gd
const TRONC := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"]
const MEMBRES := ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l", "foot_l"]

func _init() -> void:
	var m := {}
	for s in ["homme", "femme"]:
		m[s] = _mesurer(s)
	print("os            homme (x / z)        femme (x / z)        rapport f/h")
	for o: String in m["homme"]:
		var h: Vector3 = m["homme"][o]
		var f: Vector3 = m["femme"][o]
		print("%-12s  %.3f %.3f %.3f   %.3f %.3f %.3f   %.2f %.2f %.2f" % [o, h.x, h.y, h.z, f.x, f.y, f.z, f.x / h.x, f.y / maxf(h.y, 0.001), f.z / h.z])
	quit()

func _mesurer(sexe: String) -> Dictionary:
	var racine: Node3D = (load(JoueurBase.MODELES[sexe]) as PackedScene).instantiate()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var P := PackedVector3Array()
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		for s in mi.mesh.get_surface_count():
			P.append_array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	var r := {}
	# tronc : bande de +-2 cm à la hauteur de l'os, |x| < 0,19 (bras en T exclus) ; x = demi-largeur (95e centile), y = longueur de
	# l'os (jusqu'à l'enfant), z = demi-profondeur
	for o: String in TRONC:
		var i := sq.find_bone(o)
		var p := sq.get_bone_global_rest(i).origin
		var xs: Array[float] = []
		var zs: Array[float] = []
		for v in P:
			if absf(v.y - p.y) < 0.02 and absf(v.x) < 0.19:
				xs.append(absf(v.x))
				zs.append(absf(v.z - p.z))
		xs.sort(); zs.sort()
		r[o] = Vector3(xs[int(xs.size() * 0.95)] if xs.size() > 0 else 0.0, _longueur(sq, i), zs[int(zs.size() * 0.95)] if zs.size() > 0 else 0.0)
	# membres : rayon (75e centile) des sommets qui se projettent au milieu du segment os -> os enfant
	for o: String in MEMBRES:
		var i := sq.find_bone(o)
		var a := sq.get_bone_global_rest(i).origin
		var b := a + sq.get_bone_global_rest(i).basis.y.normalized() * _longueur(sq, i)
		var ds: Array[float] = []
		for v in P:
			var t := (v - a).dot(b - a) / (b - a).length_squared()
			if t > 0.25 and t < 0.75:
				var d := (v - (a + (b - a) * t)).length()
				if d < 0.16:
					ds.append(d)
		ds.sort()
		var rr := ds[int(ds.size() * 0.75)] if ds.size() > 0 else 0.0
		r[o] = Vector3(rr, _longueur(sq, i), rr)
	r["hauteur"] = Vector3(_max_y(P), _max_y(P), _max_y(P))
	racine.free()
	return r

func _longueur(sq: Skeleton3D, i: int) -> float:
	var p := sq.get_bone_global_rest(i).origin
	for j in sq.get_bone_count():
		if sq.get_bone_parent(j) == i and not sq.get_bone_name(j).contains("leaf"):
			return (sq.get_bone_global_rest(j).origin - p).length()
	return 0.1

func _max_y(P: PackedVector3Array) -> float:
	var m := 0.0
	for v in P:
		m = maxf(m, v.y)
	return m
