extends SceneTree
## Captures « icônes dessinées depuis les modèles 3D + aperçu 3D tournant » (FENÊTRE hors écran via godot_slot.sh) :
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_icones_apercu.gd -- --nouvelle --paisible --sortie=<dossier>
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
	for o: Array in [["epee_rubis", 1], ["epee_verre", 1], ["hache_guerre", 1], ["claymore", 1], ["marteau_guerre", 1], ["bouclier_cercle", 1],
			["dague_acier", 1], ["armure_fourrure", 1], ["casque_fer", 1], ["cuirasse_acier_nordique", 1], ["bottes_cuir", 1], ["gants_os", 1],
			["capuche_cuir", 1], ["amulette_givre", 1], ["anneau_braise", 1], ["anneau_orage", 1], ["collier_portefaix", 1],
			["potion_soin", 4], ["potion_mana", 2], ["potion_endurance", 1], ["pain_seigle", 2], ["tome_boule_feu", 1],
			["minerai_argent", 3], ["cristal_givre", 2], ["fourrure_troll", 1], ["os_draugr", 5], ["coupe_argent", 1], ["cle_archives", 1]]:
		inv.ajouter(o[0], o[1])
	for id in ["armure_fourrure", "capuche_cuir", "bottes_cuir", "amulette_givre"]:
		j.equipement_corps.equiper(id)
	var mains: EquipementMains = j.mains.magie.eq
	mains.apprendre_tout()
	j.mains.magie.equiper("droite", "epee_rubis")
	j.mains.magie.equiper("gauche", "bouclier")
	# --- menu : Sac
	var ui: InventaireMains = m.inventaire_ui
	ui.ouvrir("sac")
	await _images(10)
	var sac := ui.onglet("sac") as OngletSac
	for v: Array in [["arme", "epee_rubis", "1_sac_arme"], ["arme", "claymore", "2_sac_claymore"], ["armure", "cuirasse_acier_nordique", "3_sac_armure"],
			["armure", "casque_fer", "3b_sac_casque"], ["bijou", "anneau_braise", "4_sac_bijou"], ["consommable", "potion_soin", "5_sac_potion"],
			["ingredient", "cristal_givre", "6_sac_ingredient"]]:
		sac.filtrer(v[0])
		sac.choisir(v[1])
		sac.queue_redraw()
		await _images(20)
		await _capturer(v[2])
	# le tour : 6 instants de l'aperçu de l'épée en rubis (planche)
	sac.filtrer("arme")
	sac.choisir("epee_rubis")
	sac.queue_redraw()
	await _images(10)
	var tours: Array[Image] = []
	for k in 6:
		await _images(30)
		await RenderingServer.frame_post_draw
		tours.append(root.get_viewport().get_texture().get_image().get_region(Rect2i(326, 30, 300, 110)))
	var pl := Image.create_empty(300 * 3, 110 * 2, false, Image.FORMAT_RGBA8)
	for k in 6:
		tours[k].convert(Image.FORMAT_RGBA8)
		pl.blit_rect(tours[k], Rect2i(0, 0, 300, 110), Vector2i((k % 3) * 300, (k / 3) * 110))
	pl.resize(pl.get_width() * 2, pl.get_height() * 2, Image.INTERPOLATE_NEAREST)
	pl.save_png(_dossier().path_join("7_apercu_tour.png"))
	# --- Équipement
	ui.changer_onglet("equipement")
	var oe := ui.onglet("equipement") as OngletEquipement
	oe.sel = 3
	oe.queue_redraw()
	await _images(20)
	await _capturer("8_equipement_main_droite")
	oe.sel = 1
	oe.queue_redraw()
	await _images(20)
	await _capturer("9_equipement_torse")
	ui.changer_onglet("magie")
	await _images(10)
	await _capturer("10_magie")
	ui.fermer()
	await _images(10)
	# --- barre d'objets
	mains.assigner_raccourci(0, "bouclier", "epee_rubis")
	mains.assigner_raccourci(1, "vide", "hache_guerre")
	mains.assigner_raccourci(2, "boule_feu", "epee_verre")
	mains.assigner_conso(3, "potion_soin")
	mains.assigner_conso(4, "potion_mana")
	mains.assigner_raccourci(5, "vide", "claymore")
	var hc: Node = m.hud.combat_ui
	hc.set("_force_visible", true)
	j.vie = j.vie_max * 0.7
	await _images(40)
	var barre := await _capturer("11_barre_objets")
	var zoom := barre.get_region(Rect2i(110, 322, 420, 38))
	zoom.resize(420 * 3, 38 * 3, Image.INTERPOLATE_NEAREST)
	zoom.save_png(_dossier().path_join("11_barre_objets_x3.png"))
	j.mains.magie.raccourci(1)
	await _images(14)
	await _capturer("11b_barre_objets_ruban")
	hc.set("_force_visible", false)
	# --- coffre, boutique, forge, butin
	var sv: ServicesPnj = m.services
	var g := Stockage.conteneur("coffre_grima")
	for o: Array in [["grand_marteau", 1], ["ecu_chevalier", 1], ["fourrure_troll", 2], ["relique_offrande", 1], ["tome_lance_givre", 1],
			["coupe_argent", 1], ["anneau_marchand", 1], ["gantelets_fer", 1]]:
		g.ajouter(o[0], o[1])
	var fc: FenetreCoffre = sv.fenetre_coffre
	fc.ouvrir("coffre_grima")
	fc.changer_cote(0)
	await _images(10)
	await _capturer("12_coffre")
	fc.fermer()
	var mb: Marchand = m.marchand
	mb.ouvrir("forgeron")
	mb._choisir(2)
	await _images(10)
	await _capturer("13_boutique")
	mb.fermer()
	var fo: Forge = sv.forge
	fo.ouvrir()
	fo._choisir(maxi(0, fo.lignes.find("hache_guerre")))
	await _images(10)
	await _capturer("14_forge")
	fo.fermer()
	var fb: FenetreButin = m.fenetre_butin
	fb.ouvrir("Coffre de bandit", {"epee_verre": 1, "potion_soin_forte": 2, "minerai_argent": 3, "anneau_cuivre": 1, "casque_os": 1}, 37)
	await _images(10)
	await _capturer("15_butin")
	fb.fermer()
	await _images(4)
	quit(0)
