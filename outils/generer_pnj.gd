extends SceneTree
## Précalcule les textures teintées des PNJ (PnjNordique) dans assets/pnj/<clé>.res. À relancer (VERSION++) après toute modif des teintes :
##   godot --headless --path . --script res://outils/generer_pnj.gd
func _init() -> void:
	PnjNordique.enregistrer = true
	for id: String in PnjNordique.IDS:
		PnjNordique.creer(id).free()
	print("textures des PNJ précalculées")
	quit()
