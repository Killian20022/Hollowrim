extends SceneTree
## Test de la capuche v3 des mages (persos/capuche_v3) : mage ennemi (ombre), völva et ancienne (visage montré).
##   - la capuche v3 est posée (glb Blender), visible, une seule face + doublure, budget (<= 1 100 triangles) ;
##   - elle épouse la tête : au repos, le sommet est à moins de 5 cm du crâne (fini la coquille d'œuf à 8 cm) et la largeur aux
##     tempes reste sous 1,35 fois celle de la tête ;
##   - AUCUNE TRAVERSÉE pendant les animations : sur 7 clips (8 instants chacun), aucun point visible de la tête / du cou (peau) ni
##     du col de la pèlerine ne ressort à travers la capuche de plus de TOL (segment centre du crâne -> point coupé par un triangle
##     posé de la capuche : la longueur au-delà est la traversée).
##   godot --headless --path . --script res://outils/test_capuche_mage.gd -- --nouvelle
const TOL := 0.008
const TRIS_MAX := 1100
const CLIPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Spell_Simple_Shoot", "Hit_Chest", "Idle_Talking"]
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

## Positions posées (repère du squelette) des sommets d'une pièce peau d'os.
func _poses(sq: Skeleton3D, mi: MeshInstance3D, a: Array, ids: PackedInt32Array) -> PackedVector3Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / v.size()
	var mats := {}
	var res := PackedVector3Array()
	for i in ids:
		var p := Vector3.ZERO
		for j in nb:
			var wj := w[i * nb + j]
			if wj <= 0.0:
				continue
			var bi := bones[i * nb + j]
			if not mats.has(bi):
				var os := GuerrierNordique._os_de_bind(mi.skin, sq, bi)
				mats[bi] = sq.get_bone_global_pose(os) * mi.skin.get_bind_pose(bi)
			p += ((mats[bi] as Transform3D) * v[i]) * wj
		res.append(p)
	return res

func _tous(n: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	for i in n:
		r.append(i)
	return r

## Sommets réellement utilisés par des triangles (les pièces filtrées gardent leur tableau de sommets).
func _utilises(a: Array, garder: Callable) -> PackedInt32Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var vu := {}
	for i in idx:
		if not vu.has(i) and garder.call(v[i]):
			vu[i] = true
	var r := PackedInt32Array()
	for i: int in vu:
		r.append(i)
	return r

func _verifier(nom: String, g: Node3D) -> void:
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	var cap := sq.get_node_or_null("capuche") as MeshInstance3D
	ok(cap != null and cap.visible and cap.has_meta("capuche_v3"), "%s : capuche v3 posée et visible" % nom)
	if cap == null or not cap.has_meta("capuche_v3"):
		return
	var ac := cap.mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = ac[Mesh.ARRAY_INDEX]
	var vc: PackedVector3Array = ac[Mesh.ARRAY_VERTEX]
	ok(idx.size() / 3 <= TRIS_MAX, "%s : capuche %d triangles (<= %d)" % [nom, idx.size() / 3, TRIS_MAX])
	var mat := cap.material_override as ShaderMaterial
	ok(mat != null and mat.shader != null and not mat.shader.code.contains("cull_disabled"), "%s : matériau à une face (doublure modelée)" % nom)
	# --- ajustement au repos : sommet et tempes
	var tete := sq.get_bone_global_rest(sq.find_bone("Head")).origin
	var peau := sq.get_node("peau") as MeshInstance3D
	var ap0 := peau.mesh.surface_get_arrays(0)
	var vp: PackedVector3Array = ap0[Mesh.ARRAY_VERTEX]
	var y_crane := -1e9
	var x_tete := 0.0
	for p in vp:
		if p.y > tete.y - 0.05 and absf(p.x) < 0.15 and absf(p.z) < 0.2:
			y_crane = maxf(y_crane, p.y)
	for p in vp:
		if absf(p.y - (y_crane - 0.09)) < 0.012 and absf(p.z) < 0.15:
			x_tete = maxf(x_tete, absf(p.x))
	var y_cap := -1e9
	var x_cap := 0.0
	for p in vc:
		y_cap = maxf(y_cap, p.y)
		if absf(p.y - (y_crane - 0.09)) < 0.015 and p.z < 0.05:
			x_cap = maxf(x_cap, absf(p.x))
	ok(y_cap - y_crane < 0.05, "%s : sommet de la capuche à %.1f cm au-dessus du crâne (< 5 ; ancienne capuche ~8)" % [nom, (y_cap - y_crane) * 100.0])
	ok(x_tete > 0.0 and x_cap / x_tete < 1.35, "%s : largeur aux tempes %.1f cm pour une tête de %.1f (x %.2f < 1,35)" % [nom, x_cap * 200.0, x_tete * 200.0, x_cap / maxf(x_tete, 1e-4)])
	# --- traversées pendant les animations
	var ids_c := _tous(vc.size())
	var cou := sq.get_bone_global_rest(sq.find_bone("neck_01")).origin
	# peau visible de la tête et du cou (la peau sous les manches et le crâne caché sont déjà retirés)
	var ids_p := _utilises(ap0, func(p: Vector3) -> bool: return p.y > cou.y - 0.04 and absf(p.x) < 0.15)
	var mante := sq.get_node("mante") as MeshInstance3D
	var am := mante.mesh.surface_get_arrays(0)
	var ids_m := _utilises(am, func(p: Vector3) -> bool: return p.y > cou.y + 0.03 and Vector2(p.x, p.z + 0.02).length() < 0.16)
	var ap := g.get_node("Animations") as AnimationPlayer
	# points DEDANS au repos (segment centre -> point libre) : seuls ceux-là doivent y rester ; ceux qui sont au-delà de l'ourlet
	# (épaules de la pèlerine) sont dehors par construction
	sq.reset_bone_poses()
	var dedans := {}
	var pc0 := _poses(sq, cap, ac, ids_c)
	var c0 := tete + Vector3(0, 0.09, 0.0)
	var pts0 := _poses(sq, peau, ap0, ids_p)
	pts0.append_array(_poses(sq, mante, am, ids_m))
	for i in pts0.size():
		var libre := true
		for t in range(0, idx.size(), 3):
			if Geometry3D.segment_intersects_triangle(c0, pts0[i], pc0[idx[t]], pc0[idx[t + 1]], pc0[idx[t + 2]]) != null:
				libre = false
				break
		if libre:
			dedans[i] = true
	print("  %s : %d points sous la capuche au repos sur %d" % [nom, dedans.size(), pts0.size()])
	var pire := 0.0
	var ou := ""
	var nb_pts := 0
	for clip in CLIPS:
		if not ap.has_animation(clip):
			continue
		ap.play(clip)
		var lg := ap.get_animation(clip).length
		var pire_clip := 0.0
		for k in 8:
			ap.seek(lg * k / 8.0, true)
			var pc := _poses(sq, cap, ac, ids_c)
			var tf := sq.get_bone_global_pose(sq.find_bone("Head"))
			var centre := tf * (sq.get_bone_global_rest(sq.find_bone("Head")).affine_inverse() * (tete + Vector3(0, 0.09, 0.0)))
			# triangles posés, rangés par direction depuis le centre
			var tri_dir := PackedVector3Array()
			for t in range(0, idx.size(), 3):
				tri_dir.append(((pc[idx[t]] + pc[idx[t + 1]] + pc[idx[t + 2]]) / 3.0 - centre).normalized())
			var pts := _poses(sq, peau, ap0, ids_p)
			pts.append_array(_poses(sq, mante, am, ids_m))
			nb_pts = pts.size()
			for ip in pts.size():
				if not dedans.has(ip):
					continue
				var p := pts[ip]
				var d := p - centre
				var lgp := d.length()
				if lgp < 1e-4:
					continue
				var dn := d / lgp
				for t in range(0, idx.size(), 3):
					if tri_dir[t / 3].dot(dn) < 0.82:
						continue
					var hit: Variant = Geometry3D.segment_intersects_triangle(centre, p, pc[idx[t]], pc[idx[t + 1]], pc[idx[t + 2]])
					if hit != null:
						var prof := p.distance_to(hit as Vector3)
						if prof > pire_clip:
							pire_clip = prof
						if prof > TOL and OS.get_cmdline_user_args().has("--detail"):
							print("    > %.1f mm %s t=%.2f %s repos=%s" % [prof * 1000.0, clip, k / 8.0, "peau" if ip < ids_p.size() else "mante", pts0[ip].snapped(Vector3.ONE * 0.005)])
						if prof > pire:
							pire = prof
							ou = "%s t=%.2f point=%s" % [clip, k / 8.0, p.snapped(Vector3.ONE * 0.01)]
		print("  %s %s : traversée max %.1f mm" % [nom, clip, pire_clip * 1000.0])
	ok(pire <= TOL, "%s : aucune traversée tête / cou / col à travers la capuche > %.0f mm sur %d clips x 8 instants (%d points ; pire %.1f mm %s)" % [nom, TOL * 1000.0, CLIPS.size(), nb_pts, pire * 1000.0, ou])

func _lancer() -> void:
	var g := MageNordique.creer({})
	root.add_child(g)
	_verifier("mage", g)
	ok(g.find_child("capuche", true, false) != null, "mage : capuche")
	g.free()
	for id in ["volva", "ancienne"]:
		var p := PnjNordique.creer(id)
		root.add_child(p)
		_verifier(id, p)
		p.free()
	# repli : sans la capuche v3, l'ancienne cagoule reste posée (aucune régression)
	CapucheMage.actif = false
	var ga := MageNordique.creer({})
	root.add_child(ga)
	var ca := ga.find_child("capuche", true, false) as MeshInstance3D
	ok(ca != null and ca.visible and not ca.has_meta("capuche_v3"), "repli : ancienne capuche quand CapucheMage.actif = false")
	ga.free()
	CapucheMage.actif = true
	print("TEST CAPUCHE MAGE : %s (%d échecs)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
