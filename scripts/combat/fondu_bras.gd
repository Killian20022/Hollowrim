extends SkeletonModifier3D
## Fondu près de l'œil des bras 1re personne (combat/bras_vide_1p, 2026-11-26) : DERNIER modificateur du squelette des
## bras (après les clips, l'IK et la torsion des avant-bras), donc sur la pose de l'image même qui va être rendue — un
## coup qui balaie la vue en 2 images (contre-attaque) ne passe pas entre les mailles. Calcul et pose : AvantBras.

var racine: Node

func _process_modification_with_delta(_dt: float) -> void:
	if racine == null or not is_inside_tree():
		return
	AvantBras.regler_fondu(racine, get_viewport().get_camera_3d())
