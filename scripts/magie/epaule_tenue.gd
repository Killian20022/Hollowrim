extends SkeletonModifier3D
## Épaules de la tenue « runes » (MainSort, références Jeux/references/avant_bras_magie/bras_feu_1100.jpg) : avant l'IK
## des bras, l'origine de l'os `upperarm_*` est déplacée de `decalages[os]` (repère du SQUELETTE, m). Sans cela l'épaule
## reste derrière l'œil et l'avant-bras file vers la caméra : on n'en voit qu'un moignon au bord de l'écran. Épaule plus
## basse et plus en dehors → l'avant-bras part du coin bas et monte vers la main, presque parallèle à l'écran.
## Décalage nul : l'os n'est pas touché (clips de l'épée, torche, bouclier intacts) ; une fois remis à l'origine du repos.

var decalages := {}
var _ecrit := {}

func _process_modification_with_delta(_dt: float) -> void:
	var sq := get_skeleton()
	if sq == null:
		return
	for nom: String in decalages:
		var d: Vector3 = decalages[nom]
		var i := sq.find_bone(nom)
		if i < 0:
			continue
		if d.is_zero_approx():
			if _ecrit.get(nom, false):
				sq.set_bone_pose_position(i, sq.get_bone_rest(i).origin)
				_ecrit[nom] = false
			continue
		var parent := Transform3D()
		var j := sq.get_bone_parent(i)
		while j >= 0:
			parent = sq.get_bone_pose(j) * parent
			j = sq.get_bone_parent(j)
		sq.set_bone_pose_position(i, sq.get_bone_rest(i).origin + parent.basis.inverse() * d)
		_ecrit[nom] = true
