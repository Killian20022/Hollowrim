extends SceneTree
func _init() -> void:
	var h := Humain.creer({"corps": "homme"})
	var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		var t := 0
		for s in mi.mesh.get_surface_count():
			t += mi.mesh.surface_get_array_index_len(s) / 3
		print("PIECE %s surf=%d tris=%d aabb=%s" % [mi.name, mi.mesh.get_surface_count(), t, mi.get_aabb()])
	for i in sq.get_bone_count():
		print("OS %d %s parent=%d rest=%s glob=%s" % [i, sq.get_bone_name(i), sq.get_bone_parent(i), sq.get_bone_rest(i).origin, sq.get_bone_global_rest(i).origin])
	var lib := Humain.bibliotheque()
	print("ANIMS ", lib.get_animation_list())
	for nom in ["Idle", "Walk", "Punch_Cross"]:
		var a := lib.get_animation(nom)
		var pos := []
		var sc := []
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				pos.append(str(a.track_get_path(t)).get_slice(":", 1))
			if a.track_get_type(t) == Animation.TYPE_SCALE_3D:
				sc.append(str(a.track_get_path(t)).get_slice(":", 1))
		print("ANIM %s len=%.2f tracks=%d pos=%s scale=%s" % [nom, a.length, a.get_track_count(), pos, sc])
	quit()
