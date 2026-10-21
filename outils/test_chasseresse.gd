extends SceneTree
## Test de la Chasseresse nordique (ChasseresseNordique) : contrat de Humain.creer (mêmes 65 os, AnimationPlayer « Animations »,
## clips dont la posture d'archer Pistol_Aim_Neutral / Pistol_Shoot), ragdoll (16 os physiques), budget de triangles et de
## surfaces (arc porté ET arc tendu), échange automatique des deux arcs au changement de clip, matériaux tous au shader PS1
## (accroche des sommets), aucun PNJ modifié, et traversées grossières de l'arc dans le corps (> 6 cm de profondeur).
##   godot --headless --path . --script res://outils/test_chasseresse.gd -- --nouvelle
const ANIMS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Pistol_Aim_Neutral", "Pistol_Shoot", "Hit_Chest", "Death01"]
const BUDGET := 7500
const SURFACES_MAX := 10
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _surfaces(n: Node) -> int:
	var s := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			s += mi.mesh.get_surface_count()
	return s

## Volumes du corps (capsules entre deux os, rayon) au temps courant.
func _volumes(sq: Skeleton3D) -> Array:
	var g := func(o: String) -> Vector3: return sq.get_bone_global_pose(sq.find_bone(o)).origin
	return [[g.call("pelvis"), g.call("neck_01"), 0.11], [g.call("Head") + Vector3(0, 0.02, 0), g.call("Head") + Vector3(0, 0.14, 0), 0.08],
		[g.call("thigh_l"), g.call("calf_l"), 0.065], [g.call("thigh_r"), g.call("calf_r"), 0.065], [g.call("calf_l"), g.call("foot_l"), 0.045], [g.call("calf_r"), g.call("foot_r"), 0.045]]

func _profondeur(p: Vector3, vols: Array) -> float:
	var pire := 0.0
	for v: Array in vols:
		var a: Vector3 = v[0]
		var b: Vector3 = v[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		pire = maxf(pire, float(v[2]) - p.distance_to(a + ab * t))
	return pire

func _points(sq: Skeleton3D, meta: String, locaux: Array) -> Array:
	var m: Array = sq.get_meta(meta)
	var o: int = m[0]
	var tr: Transform3D = sq.get_bone_global_pose(o) * sq.get_bone_global_rest(o).affine_inverse() * m[1]
	var res := []
	for l: Vector3 in locaux:
		res.append(tr * l)
	return res

func _lancer() -> void:
	var t0 := Time.get_ticks_usec()
	var c := ChasseresseNordique.creer({})
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	root.add_child(c)
	var h := Humain.creer({"corps": "femme", "tenue": {"tunique": Color.WHITE}})
	root.add_child(h)
	var sq := c.find_child("Skeleton3D", true, false) as Skeleton3D
	var sqh := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var memes := sq.get_bone_count() == sqh.get_bone_count()
	for i in sqh.get_bone_count():
		memes = memes and sq.get_bone_name(i) == sqh.get_bone_name(i)
	ok(memes, "mêmes os que Humain.creer (%d)" % sq.get_bone_count())
	var ap := c.get_node_or_null("Animations") as AnimationPlayer
	var manque := []
	for a in ANIMS:
		if ap == null or not ap.has_animation(a):
			manque.append(a)
	ok(manque.is_empty(), "AnimationPlayer « Animations » et clips %s (absents : %s) ; creer %.0f ms" % [ANIMS, manque, dt])
	var porte := sq.get_node_or_null("arc_porte") as MeshInstance3D
	var vise := sq.get_node_or_null("arc_vise") as MeshInstance3D
	ap.play("Idle")
	ok(porte != null and vise != null and porte.visible and not vise.visible, "Idle : arc porté main gauche visible, arc tendu caché")
	var tris := _tris(c)
	ok(tris <= BUDGET, "Idle : %d triangles visibles (<= %d)" % [tris, BUDGET])
	ok(_surfaces(c) <= SURFACES_MAX, "Idle : %d surfaces visibles (<= %d)" % [_surfaces(c), SURFACES_MAX])
	ap.play("Pistol_Aim_Neutral")
	ok(vise != null and vise.visible and not porte.visible, "Pistol_Aim_Neutral : arc tendu main droite visible, arc porté caché")
	ok(_tris(c) <= BUDGET and _surfaces(c) <= SURFACES_MAX, "visée : %d triangles, %d surfaces visibles" % [_tris(c), _surfaces(c)])
	ap.play("Walk")
	ok(porte.visible and not vise.visible, "Walk : retour de l'arc dans la main gauche")
	var non_ps1 := []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s)
			if m == null: m = mi.material_override
			if not (m is ShaderMaterial) or not ((m as ShaderMaterial).shader.code.contains("grille")):
				non_ps1.append("%s/%d" % [mi.name, s])
	ok(non_ps1.is_empty(), "toutes les surfaces passent par un shader PS1 à accroche (%s)" % [non_ps1])
	var tun := sqh.get_node("tunique") as MeshInstance3D
	ok((tun.material_override as ShaderMaterial).shader != GuerrierNordique.SHADER, "Humain.creer (PNJ) non modifié")
	# traversées de l'arc (points le long de la branche et de la corde)
	var arc := []
	for k in 13:
		var t := -1.0 + 2.0 * k / 12.0
		arc.append(Vector3(0, t * 0.72, -0.11 * t * t))
	for clip in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Hit_Chest", "Pistol_Aim_Neutral", "Pistol_Shoot"]:
		ap.play(clip)
		var meta := "arc_vise" if ChasseresseNordique.clip_de_visee(clip) else "arc_porte"
		var lg := ap.get_animation(clip).length
		var pire := 0.0
		for k in 12:
			ap.seek(lg * k / 12.0, true)
			var vols := _volumes(sq)
			for p: Vector3 in _points(sq, meta, arc):
				pire = maxf(pire, _profondeur(p, vols))
		ok(pire < 0.06, "%s : traversée max de l'arc (%s) %.3f m (< 0,06)" % [clip, meta, pire])
	var rd := Ragdoll.equiper(c) as Ragdoll
	ok(rd != null and rd.os.size() == 16, "ragdoll : %d os physiques" % (rd.os.size() if rd else 0))
	print("TEST CHASSERESSE : %s (%d échecs)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
