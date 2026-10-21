extends SceneTree
## Outil (mage pilote) : prise du bâton. Repère vertical (axe y du monde) centré dans la paume droite (milieu poignet / jointure
## du majeur), exprimé dans le repère posé de hand_r, pour les poses Idle et Spell_Simple_Idle ; la prise retenue est le
## compromis (rotation à mi-chemin) : bâton presque droit au repos ET pendant le lancement de sort -> MageNordique.PRISE_BATON.
##   godot --headless --path . --script res://outils/inspecter_mage.gd
func _init() -> void:
	_lancer.call_deferred()

func _prise(sq: Skeleton3D, ap: AnimationPlayer, clip: String, t: float) -> Transform3D:
	ap.play(clip)
	ap.seek(ap.get_animation(clip).length * t, true)
	var H := sq.get_bone_global_pose(sq.find_bone("hand_r"))
	var M := sq.get_bone_global_pose(sq.find_bone("middle_01_r")).origin
	return H.affine_inverse() * Transform3D(Basis(), (H.origin + M) * 0.5)

func _lancer() -> void:
	var h := Humain.creer({"corps": "homme", "tenue": {"tunique": Color.WHITE}})
	root.add_child(h)
	var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := h.get_node("Animations") as AnimationPlayer
	var a := _prise(sq, ap, "Idle", 0.25)
	var b := _prise(sq, ap, "Spell_Simple_Idle", 0.25)
	var q := Quaternion(a.basis.orthonormalized()).slerp(Quaternion(b.basis.orthonormalized()), float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 0.35)
	var pr := Transform3D(Basis(q), (a.origin + b.origin) * 0.5)
	print("PRISE_BATON := Transform3D(Basis(Vector3(%f, %f, %f), Vector3(%f, %f, %f), Vector3(%f, %f, %f)), Vector3(%f, %f, %f))" % [pr.basis.x.x, pr.basis.x.y, pr.basis.x.z, pr.basis.y.x, pr.basis.y.y, pr.basis.y.z, pr.basis.z.x, pr.basis.z.y, pr.basis.z.z, pr.origin.x, pr.origin.y, pr.origin.z])
	for clip in ["Idle", "Spell_Simple_Idle", "Walk", "Spell_Simple_Shoot"]:
		ap.play(clip)
		ap.seek(ap.get_animation(clip).length * 0.25, true)
		var axe := (sq.get_bone_global_pose(sq.find_bone("hand_r")) * pr).basis.y
		print("%s : axe du bâton %s (inclinaison %.0f°)" % [clip, axe.snapped(Vector3.ONE * 0.01), rad_to_deg(axe.angle_to(Vector3.UP))])
	quit()
