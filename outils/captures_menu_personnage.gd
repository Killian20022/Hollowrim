extends SceneTree
## Captures du menu du personnage (lot C) pour comparaison avec les maquettes A_parchemin : une image par onglet (rendu réel,
## 640x360) et une planche « jeu | maquette » (jeu agrandi x2 au plus proche à gauche, maquette A à droite).
##   godot --path . --script res://outils/captures_menu_personnage.gd -- --nouvelle --captures=<dossier> [--maquettes=<dossier png>]
## Données RÉELLES (intégration RPG) : armures du lot A (data/objets/armures.json), arbre du lot B (data/competences/arbre.json),
## favoris du Sac ; aucune sauvegarde. Vues : chaque onglet + l'annonce de niveau (EcranNiveau, figée).

const SCENE := preload("res://scenes/test_combat.tscn")
const ARMURES := ["capuche_cuir", "armure_fourrure", "gants_os", "bottes_cuir", "casque_fer", "cuirasse_acier_nordique", "heaume_jarl",
	"bottes_rodeur"]

var _dossier := ""
var _maquettes := "C:/Users/lopezk19/Desktop/Skyrim captures/maquettes_menu/png"

func _init() -> void:
	_lancer.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capture(nom: String, maquette: String) -> void:
	await _images(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_dossier)
	img.save_png(_dossier.path_join(nom + ".png"))
	print("CAPTURE ", _dossier.path_join(nom + ".png"))
	if maquette == "":
		return
	var m := Image.load_from_file(_maquettes.path_join(maquette))
	if m == null:
		return
	var jeu := img.duplicate()
	jeu.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	m.convert(Image.FORMAT_RGBA8)
	m.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	jeu.convert(Image.FORMAT_RGBA8)
	var planche := Image.create_empty(2576, 720, false, Image.FORMAT_RGBA8)
	planche.fill(Color("#0b0f1a"))
	planche.blit_rect(jeu, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	planche.blit_rect(m, Rect2i(0, 0, 1280, 720), Vector2i(1296, 0))
	planche.save_png(_dossier.path_join(nom + "_vs_maquette.png"))
	print("PLANCHE ", _dossier.path_join(nom + "_vs_maquette.png"))

func _lancer() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_dossier = a.substr(11)
		elif a.begins_with("--maquettes="):
			_maquettes = a.substr(12)
	if _dossier == "" or DisplayServer.get_name() == "headless":
		print("captures : fenêtre et --captures=<dossier> nécessaires")
		quit(1)
		return
	for id in ARMURES:
		assert(Inventaire.connu(id), "armure réelle absente : " + id)
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	var j: CharacterBody3D = s.joueur
	var ui: InventaireMains = s.inventaire_ui
	await _images(20)
	var inv: Inventaire = j.inventaire
	for id in ARMURES + ["amulette_givre", "epee_verre", "epee_rubis",
			"epee_or", "hache_kolbeinn", "potion_soin", "potion_mana", "tome_lance_givre", "minerai_argent", "cristal_givre", "fourrure_troll",
			"relique_offrande", "anneau_givre"]:
		inv.ajouter(id, 3 if id.begins_with("potion") else 1)
	inv.pieces = 1280
	j.progression.gagner_xp(2900.0, false)
	for id in ["capuche_cuir", "armure_fourrure", "gants_os", "bottes_cuir", "amulette_givre"]:
		print("EQUIPER ", id, " -> ", j.equipement_corps.equiper(id))
	for id in ["epee_rubis", "potion_soin", "heaume_jarl"]:
		ui.basculer_favori(id)
	# quelques perks réels (lot B) pour un arbre vivant
	j.progression.points_perk += 6
	for p: String in Progression.perks_de("une_main").slice(0, 3):
		print("PERK ", p, " -> ", j.progression.acheter_perk(p))
	j.mains.magie.eq.apprendre_tout()
	j.mains.magie.equiper("droite", "epee_verre")
	j.mains.magie.equiper("gauche", "bouclier")
	j.vigueur = j.vigueur_max * 0.8
	j.mana = j.mana_max * 0.9
	ui.ouvrir("equipement")
	(ui.onglet("equipement") as OngletEquipement).sel = 3
	ui.onglet("equipement").queue_redraw()
	await _capture("C_1_equipement", "A_1_equipement.png")
	var oe := ui.onglet("equipement") as OngletEquipement
	oe.sel = 0
	oe._ouvrir_choix()
	oe.queue_redraw()
	await _capture("C_1b_equipement_changer", "")
	oe.choix = []
	ui.changer_onglet("sac")
	var sac := ui.onglet("sac") as OngletSac
	sac.filtrer("arme")
	sac.choisir("epee_rubis")
	await _capture("C_2_sac", "A_2_inventaire.png")
	sac.filtrer("armure")
	sac.choisir("cuirasse_acier_nordique")
	await _capture("C_2b_sac_armures", "")
	sac.filtrer("favoris")
	await _capture("C_2c_sac_favoris", "")
	ui.changer_onglet("magie")
	(ui.onglet("magie") as OngletMagie).choisir("boule_feu")
	await _capture("C_3_magie", "")
	ui.changer_onglet("competences")
	var oc := ui.onglet("competences") as OngletCompetences
	print("ARBRE source=", oc.source, " perks=", oc.perks.size())
	await _capture("C_4_competences", "")
	ui.changer_onglet("quetes")
	await _capture("C_5_quetes", "")
	ui.changer_onglet("carte")
	await _capture("C_5b_carte", "")
	ui.changer_onglet("personnage")
	await _capture("C_6_personnage", "")
	ui.fermer()
	await _images(5)
	var en: EcranNiveau = s.hud.ecran_niveau
	en.figer = true
	en.annoncer_niveau(j.progression.niveau)
	await _images(30)
	await _capture("C_7_annonce_niveau", "")
	quit(0)
