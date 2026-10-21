extends SceneTree
## Sonde (chasseresse) : répartition des UV de la tunique (manches / torse / jupe), profil de la cape, pose de la main gauche en Idle.
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var h := Humain.creer({"corps": "femme", "cheveux": "Hair_Long", "tenue": {"tunique": Color.WHITE, "pantalon": Color.WHITE, "bottes": Color.WHITE, "ceinture": Color.WHITE, "mante": Color.WHITE, "brassards": Color.WHITE, "cape": Color.WHITE}})
	root.add_child(h)
	var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var tun := sq.get_node("tunique") as MeshInstance3D
	var a := tun.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var zones := {"manche": [Vector2(9, 9), Vector2(-9, -9)], "torse_devant": [Vector2(9, 9), Vector2(-9, -9)], "torse_dos": [Vector2(9, 9), Vector2(-9, -9)], "jupe": [Vector2(9, 9), Vector2(-9, -9)]}
	for i in v.size():
		var p := v[i]
		var z := "manche" if absf(p.x) > 0.24 else ("jupe" if p.y < 0.95 else ("torse_devant" if p.z > 0.0 else "torse_dos"))
		zones[z][0] = zones[z][0].min(uv[i])
		zones[z][1] = zones[z][1].max(uv[i])
	for z in zones:
		print("TUNIQUE %s uv %s..%s" % [z, zones[z][0], zones[z][1]])
	# correspondance hauteur <-> v sur le devant (x ~ 0)
	for i in v.size():
		if absf(v[i].x) < 0.02 and v[i].z > 0.0:
			print("DEVANT y=%.3f z=%.3f v=%.3f u=%.3f" % [v[i].y, v[i].z, uv[i].y, uv[i].x])
	# manche : y/x <-> uv
	for i in range(0, v.size(), 7):
		if absf(v[i].x) > 0.3:
			print("MANCHE x=%.3f y=%.3f z=%.3f uv=%s" % [v[i].x, v[i].y, v[i].z, uv[i]])
	# profil arrière (z min) cape / tunique / mante par hauteur, au centre
	for nom in ["cape", "tunique", "mante"]:
		var mi := sq.get_node(nom) as MeshInstance3D
		var vv: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for y in [1.5, 1.45, 1.4, 1.3, 1.2, 1.1, 1.0, 0.9]:
			var zmin := 9.0
			var zmax := -9.0
			for p in vv:
				if absf(p.y - y) < 0.03 and absf(p.x) < 0.12:
					zmin = minf(zmin, p.z)
					zmax = maxf(zmax, p.z)
			print("PROFIL %s y=%.2f zmin=%.3f zmax=%.3f" % [nom, y, zmin, zmax])
	var pe := sq.get_node("peau") as MeshInstance3D
	var vp: PackedVector3Array = pe.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for y in [1.45, 1.4, 1.35]:
		var zmax := -9.0
		for p in vp:
			if absf(p.y - y) < 0.02 and absf(p.x) < 0.15:
				zmax = maxf(zmax, p.z)
		print("PEAU devant y=%.2f zmax=%.3f" % [y, zmax])
	var ap := h.get_node("Animations") as AnimationPlayer
	for clip in ["Idle", "Walk", "Jog_Fwd", "Hit_Chest"]:
		ap.play(clip)
		ap.seek(ap.get_animation(clip).length * 0.3, true)
		var o := sq.find_bone("hand_l")
		print("POSE %s hand_l=%s" % [clip, sq.get_bone_global_pose(o)])
		print("REST hand_l=%s" % [sq.get_bone_global_rest(o)])
	quit()
