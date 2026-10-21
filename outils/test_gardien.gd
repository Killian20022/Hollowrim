extends SceneTree
## Test du Gardien nordique (GardienNordique) : contrat de Humain.creer (mêmes 65 os, AnimationPlayer « Animations », clips + alias
## Garde_Faction / Lance_Estoc), ragdoll (16 os physiques), budget de triangles et de surfaces, shader PS1 partout, aucun PNJ ni
## guerrier modifié (bibliothèque d'animations partagée intacte), traversées du bouclier et de la lance dans le corps, lance
## VERTICALE et talon près du sol en garde en faction, lance pointée devant au coup de l'estoc.
##   godot --headless --path . --script res://outils/test_gardien.gd -- --nouvelle
const ANIMS := ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Attack", "Hit_Chest", "Death01", "Garde_Faction", "Lance_Estoc"]
const BUDGET := 7500
const SURFACES_MAX := 10
const DEGAGEMENT_BOUCLIER := 0.02   # traversée max du bouclier dans le corps (passe 1 : 0,052 en course ; passe 2 : 0)
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

## Volumes du corps (capsules entre deux os, rayon) au temps courant.
func _volumes(sq: Skeleton3D) -> Array:
	var g := func(o: String) -> Vector3: return sq.get_bone_global_pose(sq.find_bone(o)).origin
	return [[g.call("pelvis"), g.call("neck_01"), 0.12], [g.call("Head") + Vector3(0, 0.02, 0), g.call("Head") + Vector3(0, 0.14, 0), 0.085],
		[g.call("thigh_l"), g.call("calf_l"), 0.07], [g.call("thigh_r"), g.call("calf_r"), 0.07], [g.call("calf_l"), g.call("foot_l"), 0.05], [g.call("calf_r"), g.call("foot_r"), 0.05]]

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
	var g := GardienNordique.creer({})
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	root.add_child(g)
	var h := Humain.creer({"corps": "homme", "tenue": {"tunique": Color.WHITE}})
	root.add_child(h)
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	var sqh := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var memes := sq.get_bone_count() == sqh.get_bone_count()
	for i in sqh.get_bone_count():
		memes = memes and sq.get_bone_name(i) == sqh.get_bone_name(i)
	ok(memes, "mêmes os que Humain.creer (%d)" % sq.get_bone_count())
	var ap := g.get_node_or_null("Animations") as AnimationPlayer
	var manque := []
	for a in ANIMS:
		if ap == null or not ap.has_animation(a):
			manque.append(a)
	ok(manque.is_empty(), "AnimationPlayer « Animations » et clips %s (absents : %s) ; creer %.0f ms" % [ANIMS, manque, dt])
	var t1 := Time.get_ticks_usec()
	var g2 := GardienNordique.creer({})
	print("INFO   2e gardien (animations et textures en cache) : %.0f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
	g2.free()
	# la bibliothèque partagée des PNJ n'est pas touchée : l'Idle d'un humain n'est pas celui du gardien
	var aph := h.get_node("Animations") as AnimationPlayer
	ok(aph.get_animation("Idle") != ap.get_animation("Idle") and aph.get_animation("Walk") != ap.get_animation("Walk"), "Humain.creer garde ses clips (bibliothèque partagée non modifiée)")
	var gg := GuerrierNordique.creer({})
	ok((gg.get_node("Animations") as AnimationPlayer).get_animation("Idle") == aph.get_animation("Idle"), "le guerrier garde ses clips")
	gg.free()
	var tris := _tris(g)
	ok(tris <= BUDGET, "%d triangles visibles (<= %d)" % [tris, BUDGET])
	var surfaces := 0
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			surfaces += mi.mesh.get_surface_count()
	ok(surfaces <= SURFACES_MAX, "%d surfaces visibles (<= %d)" % [surfaces, SURFACES_MAX])
	var non_ps1 := []
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s)
			if m == null: m = mi.material_override
			if not (m is ShaderMaterial) or not ((m as ShaderMaterial).shader.code.contains("grille")):
				non_ps1.append("%s/%d" % [mi.name, s])
	ok(non_ps1.is_empty(), "toutes les surfaces passent par un shader PS1 à accroche (%s)" % [non_ps1])
	# Humain.creer inchangé pour les autres : la tunique d'un humain garde le shader ps1 d'origine
	var tun := sqh.get_node("tunique") as MeshInstance3D
	ok((tun.material_override as ShaderMaterial).shader != GuerrierNordique.SHADER, "Humain.creer (PNJ) non modifié")
	# lance : verticale en garde en faction (angle < 12°), talon entre -2 et +10 cm du sol ; pointée devant à l'estoc
	var m: Array = sq.get_meta("lance")
	var axe := func() -> Array:
		var trl: Transform3D = sq.get_bone_global_pose(m[0]) * sq.get_bone_global_rest(m[0]).affine_inverse() * m[1]
		return [trl.basis.y.normalized(), (trl * Vector3(0, -float(m[2]) - 0.05, 0)).y]
	var pire_v := 0.0
	var talon := [9.0, -9.0]
	ap.play("Idle")
	for k in 8:
		ap.seek(ap.get_animation("Idle").length * k / 8.0, true)
		var r: Array = axe.call()
		pire_v = maxf(pire_v, rad_to_deg((r[0] as Vector3).angle_to(Vector3.UP)))
		talon = [minf(talon[0], r[1]), maxf(talon[1], r[1])]
	ok(pire_v < 12.0 and talon[0] > -0.02 and talon[1] < 0.10, "garde en faction : lance à %.1f° de la verticale (< 12), talon de %.3f à %.3f m (-0,02 à 0,10)" % [pire_v, talon[0], talon[1]])
	ap.play("Sword_Attack")
	ap.seek(ap.get_animation("Sword_Attack").length * 0.45, true)
	var re: Array = axe.call()
	var dv: Vector3 = re[0]
	ok(dv.z > 0.85, "estoc : lance pointée devant (axe %s)" % dv)
	# traversées
	var disque := [Vector3.ZERO]
	for i in 12:
		var a := TAU * i / 12.0
		disque.append(Vector3(cos(a), sin(a), 0) * 0.38)
		disque.append(Vector3(cos(a), sin(a), 0) * 0.2)
	var lame := []
	for k in 8:
		lame.append(Vector3(0, 0.12 + k * 0.15, 0))    # hampe au-dessus du poing et fer (le bas de la hampe longe la jambe)
	for clip in ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Attack", "Hit_Chest"]:
		ap.play(clip)
		var lg := ap.get_animation(clip).length
		var pire_b := 0.0
		var pire_e := 0.0
		for k in 12:
			ap.seek(lg * k / 12.0, true)
			var vols := _volumes(sq)
			for p: Vector3 in _points(sq, "bouclier", disque):
				pire_b = maxf(pire_b, _profondeur(p, vols))
			for p: Vector3 in _points(sq, "lance", lame):
				pire_e = maxf(pire_e, _profondeur(p, vols))
		ok(pire_b < DEGAGEMENT_BOUCLIER and pire_e < 0.06, "%s : traversée max bouclier %.3f m (< %.3f), lance %.3f m (< 0,06)" % [clip, pire_b, DEGAGEMENT_BOUCLIER, pire_e])
	# ragdoll
	var rd := Ragdoll.equiper(g) as Ragdoll
	ok(rd != null and rd.os.size() == 16, "ragdoll : %d os physiques" % (rd.os.size() if rd else 0))
	print("TEST GARDIEN : %s (%d échecs)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
