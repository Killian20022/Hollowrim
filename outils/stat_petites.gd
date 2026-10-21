extends SceneTree
## Inventaire des petites textures : taille, texels/m (d'après la tuile en mètres), mémoire (RGBA8 + mips), % de texels isolés.
##   godot --headless --path . --script res://outils/stat_petites.gd
## Les .res sont lus tels quels (relancer outils/generer_*.gd avant) ; PeintureInterieur est lu dans assets/bati.
func _ligne(groupe: String, nom: String, img: Image, tuile_m: float) -> float:
	var im := img.duplicate() as Image
	im.clear_mipmaps()
	im.convert(Image.FORMAT_RGB8)   # l'alpha des textures « seuil » (neige, mousse, piste) est un bruit voulu : on mesure la couleur seule
	var ko := im.get_width() * im.get_height() * 4 * 4.0 / 3.0 / 1024.0
	print("%-8s %-14s %4d x %-4d %5.0f tx/m %7.0f Ko  isolés %5.1f %%" % [groupe, nom, im.get_width(), im.get_height(), im.get_width() / tuile_m, ko, PeintureBati.part_isolee(im)])
	return ko
func _init() -> void:
	var total := 0.0
	for nom: String in ["lame", "argile", "os", "parchemin", "or", "toile"]:
		total += _ligne("crypte", nom, load("res://assets/crypte/%s.res" % nom), CrypteDecor.TUILE.get(nom, 1.0))
	for nom: String in ["roche", "roche_b", "roche_givre", "strate", "sol", "peau", "paille", "piste", "cristal", "mousse", "neige_sol"]:
		total += _ligne("grotte", nom, load("res://assets/grotte/%s.res" % nom), {"peau": 1.0, "paille": 1.0, "cristal": 2.0, "neige_sol": 4.0}.get(nom, 4.0))
	for nom: String in ["peau", "terre", "charbon"]:
		total += _ligne("interieur", nom, (load(PeintureBati.DOSSIER + nom + ".res") as Texture2D).get_image(), 1.0 if nom != "terre" else 2.0)
	for nom: String in ["roche", "roche_e", "os_e"]:
		var chemin := "res://assets/petites/%s.res" % nom if nom.ends_with("_e") and nom != "neige_e" else PeintureBati.DOSSIER + nom + ".res"
		if ResourceLoader.exists(chemin):
			total += _ligne("abords", nom, (load(chemin) as Texture2D).get_image(), 1.0 if nom == "os_e" else 4.0)
	print("total %.0f Ko" % total)
	quit()
