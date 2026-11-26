extends SceneTree
## Essai des chutes du compagnon mort, hors du monde : chaque variante (clip capturé + instant de départ + poussée du ragdoll) tombe
## sur un sol plat, est figée, puis photographiée de dessus et de 3/4 ; mesures de la pose (roulis du bassin, asymétrie des genoux,
## mains/torse). Sert à choisir une chute moins « en étoile » sans rien poser à la main.
##   godot --path . --script res://outils/essai_chute_compagnon.gd -- --sortie=<dossier absolu>
const W := 480
const H := 360
const VARIANTES := [
	["Death01", 0.37, Vector3(0.55, 0, -0.45), 22.0, "spine_03", 2.0],
	["Death01", 0.25, Vector3(1, 0, 0), 30.0, "spine_03", 2.0],
	["Death01", 0.25, Vector3(-1, 0, 0), 30.0, "spine_03", 2.0],
	["Death01", 0.5, Vector3(1, 0, 0.3), 35.0, "pelvis", 2.0],
	["Releve_Ventre", 0.0, Vector3(0.3, 0, 0), 8.0, "spine_03", 2.0],
	["Releve_Ventre", 0.0, Vector3(1, 0, 0), 25.0, "spine_03", 2.0],
	["Releve_Ventre", 0.0, Vector3(-1, 0, 0.2), 25.0, "pelvis", 4.0],
	["Releve_Ventre", 0.12, Vector3(1, 0, 0), 15.0, "spine_03", 4.0],
	["Releve_Dos", 0.0, Vector3(1, 0, 0), 25.0, "spine_03", 2.0],
	["Releve_Dos", 0.0, Vector3(0.6, 0, -0.4), 35.0, "thigh_l", 4.0],
	["Zombie_Reveil", 0.0, Vector3(0.5, 0, 0), 10.0, "spine_03", 2.0],
	["Zombie_Reveil", 0.0, Vector3(-1, 0, 0), 25.0, "pelvis", 4.0],
	["Fin_PlieGS", 0.55, Vector3(0.5, 0, 0), 15.0, "spine_03", 4.0],
	["Fin_PlieGS", 0.8, Vector3(0.5, 0, 0), 15.0, "spine_03", 4.0],
	["Fin_ArriereGS", 0.55, Vector3(0.5, 0, 0), 15.0, "spine_03", 4.0],
	["Fin_Agonie", 0.85, Vector3(0.5, 0, 0), 10.0, "spine_03", 4.0],
	["Fin_Agonie", 0.6, Vector3(1, 0, 0), 25.0, "spine_03", 4.0],
	["Death01", 0.37, Vector3(0.9, 0, -0.2), 28.0, "thigh_l", 4.0],
	["Death01", 0.3, Vector3(1, 0, -0.6), 45.0, "spine_03", 4.0],
	["Death01", 0.37, Vector3(0.55, 0, -0.45), 22.0, "spine_03", 5.0],
]
var sv: SubViewport
var cam: Camera3D

func _initialize() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.split("=", true, 1)[1]
	return defaut

func _go() -> void:
	var sortie := _arg("sortie", "C:/Users/lopezk19/Jeux/rendus/soir_2026-11-25/compagnon_mort/essai_chute")
	var seules := _arg("variantes", "")
	DirAccess.make_dir_recursive_absolute(sortie)
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var lum := DirectionalLight3D.new()
	lum.rotation_degrees = Vector3(-60, 30, 0)
	lum.light_energy = 1.2
	sv.add_child(lum)
	var sol := StaticBody3D.new()
	sol.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(200, 1, 20)
	cs.shape = bx
	cs.position = Vector3(40, -0.5, 0)
	sol.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 20)
	mi.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.3, 0.3, 0.33)
	mi.material_override = ms
	mi.position = Vector3(40, 0, 0)
	sol.add_child(mi)
	sv.add_child(sol)
	cam = Camera3D.new()
	cam.fov = 55.0
	sv.add_child(cam)
	var corps: Array = []
	for i in VARIANTES.size():
		if seules != "" and not (seules.split(",") as Array).has(str(i)):
			corps.append(null)
			continue
		var v: Array = VARIANTES[i]
		var c: Node3D = GardeMaison.creer(CrypteDonjon.COMPAGNON)
		c.position = Vector3(i * 4.0, 0.0, 0.0)
		sv.add_child(c)
		corps.append(c)
	for i in 3:
		await process_frame
	for i in VARIANTES.size():
		var c: Node3D = corps[i]
		if c == null:
			continue
		var v: Array = VARIANTES[i]
		CrypteDonjon.affaler(c, String(v[0]), float(v[1]), v[2], float(v[3]), String(v[4]), float(v[5]))
	for k in 1200:
		await physics_frame
		var tous := true
		for c: Node3D in corps:
			if c != null and c.get_node_or_null("Ragdoll") != null and not (c.get_node("Ragdoll") as Ragdoll).est_fige():
				tous = false
		if tous:
			break
	for i in VARIANTES.size():
		var c: Node3D = corps[i]
		if c == null:
			continue
		var rd := c.get_node_or_null("Ragdoll") as Ragdoll
		var P := func(n: String) -> Vector3: return (rd.pose_monde(n) as Transform3D).origin
		var B := func(n: String) -> Basis: return (rd.pose_monde(n) as Transform3D).basis
		var bassin: Vector3 = P.call("pelvis")
		var tete: Vector3 = P.call("Head")
		var axe := Vector3(tete.x - bassin.x, 0, tete.z - bassin.z).normalized()
		var cote := axe.cross(Vector3.UP)
		var genou_l: float = rad_to_deg(((P.call("thigh_l") - P.call("calf_l")) as Vector3).angle_to(P.call("foot_l") - P.call("calf_l")))
		var genou_r: float = rad_to_deg(((P.call("thigh_r") - P.call("calf_r")) as Vector3).angle_to(P.call("foot_r") - P.call("calf_r")))
		var pied_l: Vector3 = P.call("foot_l")
		var pied_r: Vector3 = P.call("foot_r")
		var ecart_pieds := absf((pied_l - pied_r).dot(cote))
		var main_l: Vector3 = P.call("hand_l")
		var main_r: Vector3 = P.call("hand_r")
		var dos: Vector3 = (B.call("spine_03") as Basis).z      # +z de l'os : devant ou derrière selon le squelette (comparer les variantes)
		print("VAR %02d %-14s t=%.2f fige=%s roulis(y de z spine_03)=%.2f %s genoux %.0f / %.0f pieds écartés %.2f m mains côté %.2f / %.2f le long %.2f / %.2f tête-bassin %.2f" % [i, VARIANTES[i][0], VARIANTES[i][1], rd.est_fige(), dos.y, "", genou_l, genou_r, ecart_pieds,
			(main_l - bassin).dot(cote), (main_r - bassin).dot(cote), (main_l - bassin).dot(axe), (main_r - bassin).dot(axe), Vector2(tete.x - bassin.x, tete.z - bassin.z).length()])
		print("      contact %02d : %s" % [i, _contact(c, rd, -0.0)])
		if OS.get_cmdline_user_args().has("--sans-image"):
			continue
		var ctr := (bassin + tete) * 0.5
		await _cliche(sortie + "/v%02d_dessus.png" % i, ctr + Vector3(0, 2.4, 0.01), ctr)
		await _cliche(sortie + "/v%02d_34.png" % i, ctr + Vector3(1.4, 1.1, 1.4), ctr)
	print("ESSAI OK ", sortie)
	quit(0)

## Plus bas sommet du corps (skinné, os physiques du ragdoll) par os physique, en cm au-dessus du sol (y = 0) ; « + » = posé sur une
## autre partie du corps (sommet d'un autre os à moins de 6 cm sous lui).
func _contact(c: Node3D, rd: Ragdoll, sol: float) -> String:
	var sq := c.find_child("Skeleton3D", true, false) as Skeleton3D
	var monde := {}
	var region := {}
	for b in sq.get_bone_count():
		var chaine: Array = []
		var x := b
		while x >= 0 and rd.pose_monde(sq.get_bone_name(x)) == null:
			chaine.push_front(x)
			x = sq.get_bone_parent(x)
		if x < 0:
			continue
		var t: Transform3D = rd.pose_monde(sq.get_bone_name(x))
		for y: int in chaine:
			t = t * sq.get_bone_pose(y)
		monde[b] = t
		region[b] = sq.get_bone_name(x)
	var bas := {}
	var pts: Array = []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null or mi.skin == null:
			continue
		var sk := mi.skin
		for s in mi.mesh.get_surface_count():
			var ar := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var bo: Variant = ar[Mesh.ARRAY_BONES]
			var we: Variant = ar[Mesh.ARRAY_WEIGHTS]
			if not (bo is PackedInt32Array):
				continue
			var k := (bo as PackedInt32Array).size() / vs.size()
			for i in range(0, vs.size(), 3):
				var acc := Vector3.ZERO
				var wmax := -1.0
				var reg := ""
				for j in k:
					var w: float = (we as PackedFloat32Array)[i * k + j]
					if w <= 0.0:
						continue
					var bi: int = (bo as PackedInt32Array)[i * k + j]
					var bone := sk.get_bind_bone(bi)
					if bone < 0:
						bone = sq.find_bone(sk.get_bind_name(bi))
					if not monde.has(bone):
						continue
					acc += ((monde[bone] as Transform3D) * sk.get_bind_pose(bi) * vs[i]) * w
					if w > wmax:
						wmax = w
						reg = region[bone]
				if reg == "":
					continue
				pts.append([acc, reg])
				if not bas.has(reg) or acc.y < (bas[reg] as Vector3).y:
					bas[reg] = acc
	var out: Array = []
	var pire := -INF
	for reg: String in bas:
		var p: Vector3 = bas[reg]
		var e := p.y - sol
		var porte := false
		if e > 0.03:
			for q: Array in pts:
				if q[1] != reg and (q[0] as Vector3).y < p.y and (q[0] as Vector3).distance_to(p) < 0.06:
					porte = true
					break
			if not porte:
				pire = maxf(pire, e)
		out.append("%s %.0f%s" % [reg, e * 100.0, "+" if porte else ""])
	return "PIRE %.1f cm | %s" % [pire * 100.0 if pire > -INF else 0.0, ", ".join(out)]

func _cliche(chemin: String, oeil: Vector3, cible: Vector3) -> void:
	cam.position = oeil
	cam.look_at(cible, Vector3.UP if absf((cible - oeil).normalized().y) < 0.98 else Vector3.FORWARD)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(chemin)
