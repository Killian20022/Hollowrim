extends SceneTree
## Vérifie le glb du jarl animé : mêmes os et même pose de repos que homme_vetu.glb (les clips de Humain.bibliotheque() s'y appliquent tels quels).
##   godot --headless --path . --script res://outils/verif_tripo_jarl_rig.gd
func _init() -> void:
	var a: Node = (load("res://assets/pnj/tripo_jarl_rig.glb") as PackedScene).instantiate()
	var b: Node = (load("res://assets/modeles/humains/homme_vetu.glb") as PackedScene).instantiate()
	var sa: Skeleton3D = a.find_child("Skeleton3D", true, false)
	var sb: Skeleton3D = b.find_child("Skeleton3D", true, false)
	print("chemin jarl : ", a.get_path_to(sa), " humain : ", b.get_path_to(sb))
	print("os jarl ", sa.get_bone_count(), " humain ", sb.get_bone_count())
	var pire := 0.0
	var pire_n := ""
	var dpos := 0.0
	var dpos_n := ""
	for i in sb.get_bone_count():
		var n := sb.get_bone_name(i)
		var j := sa.find_bone(n)
		if j < 0:
			print("MANQUE ", n)
			continue
		var qa := sa.get_bone_rest(j).basis.get_rotation_quaternion()
		var qb := sb.get_bone_rest(i).basis.get_rotation_quaternion()
		var ang := rad_to_deg(qa.angle_to(qb))
		if ang > pire:
			pire = ang
			pire_n = n
		var dp := sa.get_bone_rest(j).origin.distance_to(sb.get_bone_rest(i).origin)
		if dp > dpos:
			dpos = dp
			dpos_n = n
	print("écart de rotation de repos max : %.3f° (%s) ; de position : %.3f m (%s)" % [pire, pire_n, dpos, dpos_n])
	for i in sa.get_bone_count():
		var n := sa.get_bone_name(i)
		if n.begins_with("cape"):
			print(n, " parent ", sa.get_bone_name(sa.get_bone_parent(i)), " rest ", sa.get_bone_rest(i))
	for mi: MeshInstance3D in sa.find_children("*", "MeshInstance3D", false, false):
		print("mesh ", mi.name, " tris ", mi.mesh.get_faces().size() / 3, " skin ", mi.skin != null, " aabb ", mi.mesh.get_aabb())
	# chemins de pistes des clips contre le squelette du jarl
	var bib := Humain.bibliotheque()
	var idle := bib.get_animation("Walk")
	var manquants := 0
	for t in idle.get_track_count():
		var p := String(idle.track_get_path(t))
		var os_ := p.get_slice(":", 1)
		if sa.find_bone(os_) < 0:
			manquants += 1
	print("pistes de Walk : ", idle.get_track_count(), " ex. ", idle.track_get_path(0), " os absents : ", manquants)
	quit(0)
