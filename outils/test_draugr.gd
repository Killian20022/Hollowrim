extends SceneTree
## Test du Draugr nordique (DraugrNordique), calqué sur test_guerrier : contrat de Humain.creer, clips, ragdoll, budget,
## shader PS1, PNJ intacts, traversées bouclier / épée, + yeux luisants (sommets d'alpha 0, lueur bleue) et palette sans
## bleu hors des yeux (aucune texture du draugr à dominante bleue).
## Base : test du Guerrier nordique pilote (GuerrierNordique) : contrat de Humain.creer (mêmes 65 os, AnimationPlayer « Animations »,
## clips), ragdoll (16 os physiques), budget de triangles, matériaux tous au shader PS1 (accroche des sommets), aucun PNJ modifié
## (Humain.creer garde ses pièces), et traversées grossières bouclier / épée dans le corps sur 6 clips (> 6 cm de profondeur).
##   godot --headless --path . --script res://outils/test_draugr.gd -- --nouvelle
const ANIMS := ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "Hit_Chest", "Death01"]
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
	var g := DraugrNordique.creer({})
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
	ok((tun.material_override as ShaderMaterial).shader != DraugrNordique.SHADER and (tun.material_override as ShaderMaterial).shader != GuerrierNordique.SHADER, "Humain.creer (PNJ) non modifié")
	# yeux luisants : sommets d'alpha 0 dans la surface opaque des accessoires, matériau à lueur bleue
	var acc := sq.get_node("accessoires") as MeshInstance3D
	var col: PackedColorArray = acc.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var nl := 0
	for c in col:
		if c.a < 0.5:
			nl += 1
	var lu: Vector3 = (acc.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("lueur")
	ok(nl == 12 and lu.z > lu.x and lu.z > 1.0, "yeux luisants : %d sommets émissifs (12 attendus), lueur %s" % [nl, lu])
	# palette : aucune texture à dominante bleue (moyenne des texels opaques), hors région de l'œil
	var bleues := []
	for nom in ["mailles", "pantalon", "bottes", "brassards", "mante", "accessoires", "decoupes"]:
		var img := DraugrTextures.tex(nom).get_image()
		var s := Vector3.ZERO
		var n := 0
		var r_oeil := GuerrierTextures.R_OEIL if nom == "accessoires" else Rect2i()
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if r_oeil.has_point(Vector2i(x, y)):
					continue
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					s += Vector3(c.r, c.g, c.b)
					n += 1
		s /= maxf(n, 1)
		if s.z > s.x + 0.01:
			bleues.append("%s %s" % [nom, s])
	ok(bleues.is_empty(), "palette du draugr sans bleu hors des yeux (textures bleutées : %s)" % [bleues])
	# traversées
	var disque := [Vector3.ZERO]
	for i in 12:
		var a := TAU * i / 12.0
		disque.append(Vector3(cos(a), sin(a), 0) * 0.38)
		disque.append(Vector3(cos(a), sin(a), 0) * 0.2)
	var lame := []
	for k in 6:
		lame.append(Vector3(0, 0.15 + k * 0.14, 0))
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
			for p: Vector3 in _points(sq, "epee", lame):
				pire_e = maxf(pire_e, _profondeur(p, vols))
		ok(pire_b < DEGAGEMENT_BOUCLIER and pire_e < 0.06, "%s : traversée max bouclier %.3f m (< %.3f), épée %.3f m (< 0,06)" % [clip, pire_b, DEGAGEMENT_BOUCLIER, pire_e])
	# ragdoll
	var rd := Ragdoll.equiper(g) as Ragdoll
	ok(rd != null and rd.os.size() == 16, "ragdoll : %d os physiques" % (rd.os.size() if rd else 0))
	print("TEST DRAUGR : %s (%d échecs)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
