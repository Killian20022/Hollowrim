extends SceneTree
## Captures « plus aucun ? » (arc, flèche, crochet, sorts de l'esprit, lames enchantées) (FENÊTRE hors écran via godot_slot.sh) :
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/capture_icones_inconnues.gd -- --nouvelle --paisible --sortie=<dossier>
## Vues (640x360, données réelles, aucune sauvegarde) : Sac (armes, armures, bijoux, potions) avec l'aperçu 3D — deux instants
## du tour pour voir la rotation —, Équipement (main droite, torse), Magie, barre d'objets (raccourcis armes + potion), coffre
## de Grima, boutique de Brodd, forge, butin d'un coffre du monde. Planche finale : apercu_tour.png (6 instants du tour).
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var sortie := ""

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	if sortie == "":
		sortie = "res://captures/icones_apercu"
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _dossier() -> String:
	return ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie

func _capturer(nom: String) -> Image:
	await _images(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_dossier())
	var f := _dossier().path_join(nom + ".png")
	img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size())
	return img

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(90)
	m.hud.aide_t = 0.0
	m.hud.lieux_vus["Skarnholt"] = true
	m.cycle.heure = 12.0
	m.cycle._process(0.0)
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	inv.pieces = 1840
	for o: Array in [["arc_chasseur", 1], ["fleche", 40], ["crochet", 6], ["epee_rubis", 1], ["potion_soin", 2], ["cle_archives", 1]]:
		inv.ajouter(o[0], o[1])
	var mains: EquipementMains = j.mains.magie.eq
	mains.apprendre_tout()
	var ui: InventaireMains = m.inventaire_ui
	ui.ouvrir("sac")
	await _images(10)
	var sac := ui.onglet("sac") as OngletSac
	for v: Array in [["arme", "arc_chasseur", "1_sac_armes"], ["divers", "crochet", "2_sac_divers"]]:
		sac.filtrer(v[0])
		sac.choisir(v[1])
		sac.queue_redraw()
		await _images(20)
		await _capturer(v[2])
	ui.changer_onglet("magie")
	await _images(10)
	await _capturer("3_magie")
	var om := ui.onglet("magie")
	for v: Array in [["telekinesie", "3b_magie_esprit"], ["enchant_tenebres", "3c_magie_lames"]]:
		om.call("choisir", v[0])
		om.queue_redraw()
		await _images(8)
		await _capturer(v[1])
	ui.fermer()
	await _images(10)
	var sv: ServicesPnj = m.services
	var g := Stockage.conteneur("coffre_grima")
	for o: Array in [["arc_chasseur", 1], ["fleche", 20], ["crochet", 3], ["epee_rubis", 1]]:
		g.ajouter(o[0], o[1])
	var fc: FenetreCoffre = sv.fenetre_coffre
	fc.ouvrir("coffre_grima")
	fc.changer_cote(0)
	await _images(10)
	await _capturer("4_coffre")
	fc.fermer()
	var mb: Marchand = m.marchand
	mb.ouvrir("forgeron")
	mb._choisir(2)
	await _images(10)
	await _capturer("5_boutique")
	mb.fermer()
	var fb: FenetreButin = m.fenetre_butin
	fb.ouvrir("Coffre de bandit", {"arc_chasseur": 1, "fleche": 12, "crochet": 2}, 37)
	await _images(10)
	await _capturer("6_butin")
	fb.fermer()
	await _images(4)
	quit(0)
