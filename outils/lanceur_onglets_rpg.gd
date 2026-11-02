extends SceneTree
## LANCEUR du lot D : les onglets Compétences / Quêtes / Personnage dans la coquille d'essai (outils/coquille_essai_d.gd) sur le
## vrai joueur de scenes/test_combat.tscn, et l'annonce « Niveau supérieur » du HUD. FENÊTRE (via /tmp/godot_slot.sh).
##   Essai à la main :  godot --path . --script res://outils/lanceur_onglets_rpg.gd -- --nouvelle [--onglet=quetes] [--vierge]
##     (Tab / Q / E / LB / RB : onglets ; Échap : ferme le menu, N : niveau gagné, C : compétence gagnée, K : rouvre, F10 : quitte)
##   Captures :         … -- --nouvelle --captures="C:/Users/lopezk19/Desktop/Skyrim captures/rpg_onglets"
##     → D_competences.png, D_competences_branche.png, D_personnage.png, D_personnage_sans_choix.png, D_quetes.png,
##       D_annonce_niveau.png (640x360 natifs) + planches *_vs_maquette.png (maquette A ×4 | rendu ×3, côte à côte).
## --vierge : partie neuve (niveau 1) au lieu de l'état de démonstration (niveau 9, compétences, perks, quêtes avancées).
## Rien n'est sauvegardé (le jeu ne sauvegarde pas dans test_combat ; aucune écriture de user://sauvegarde.json).

const SCENE := preload("res://scenes/test_combat.tscn")
const COQUILLE := preload("res://outils/coquille_essai_d.gd")
const QUETES := preload("res://scripts/quetes.gd")
const MAQUETTES := "C:/Users/lopezk19/Desktop/Skyrim captures/maquettes_menu/png/"

var s: Node3D
var coquille: Control
var sortie := ""

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var depart := "competences"
	for a in args:
		if a.begins_with("--captures="):
			sortie = a.substr(11).trim_prefix("\"").trim_suffix("\"")
		if a.begins_with("--onglet="):
			depart = a.substr(9)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	for i in 40:
		await process_frame
	s.placer_joueur(Vector3(0, 0, 3), 0.0, -4.0)
	var j: Node = s.joueur
	var q := Node.new()
	q.set_script(QUETES)
	q.joueur = j
	q.hud = s.hud
	s.add_child(q)
	s.hud.quetes = q
	if not args.has("--vierge"):
		etat_demo(j, q)
	var calque := CanvasLayer.new()
	calque.layer = 50
	calque.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(calque)
	coquille = COQUILLE.new()
	coquille.joueur = j
	calque.add_child(coquille)
	var oc := OngletCompetences.new()
	coquille.ajouter(oc)
	var oq := OngletQuetes.new()
	oq.quetes = q
	coquille.ajouter(oq)
	coquille.ajouter(OngletPersonnage.new())
	if sortie != "":
		await _captures(j, oc)
		quit()
		return
	coquille.ouvrir(depart)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var touches := Node.new()
	touches.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(touches)
	touches.set_script(_script_touches())
	touches.set("lanceur", self)

## État de démonstration (comme la maquette : niveau 9, 2 points, Une main 42…) posé directement (outil, pas une règle).
static func etat_demo(j: Node, q: Node) -> void:
	var pr: Progression = j.progression
	pr.importer({"niveau": 9, "xp_niveau": 372.0, "points_perk": 2, "points_attribut": 1,
		"attributs": {"vie": 20, "magie": 30, "vigueur": 20},
		"perks": {"lame_aguerrie": 3, "croc_de_fer": 1, "eleve_de_tyr": 1, "bras_de_l_ours": 1, "rempart_de_tilleul": 2,
			"souffle_du_guetteur": 1, "paroles_de_puissance": 2, "souffle_de_niflheim": 1, "pied_leger": 1},
		"competences": {"niveaux": {"une_main": 52, "deux_mains": 18, "parade": 31, "armure": 24, "destruction": 38,
			"restauration": 22, "furtivite": 15, "athletisme": 27}, "experience": {"epee": 3.0, "parade": 6.0, "athletisme": 2.0}}})
	j.recalculer_stats()
	j.vie = j.vie_max - 12.0
	j.vigueur = j.vigueur_max * 0.8
	j.mana = j.mana_max * 0.9
	var inv: Inventaire = j.inventaire
	for id in ["potion_soin", "potion_soin", "minerai_fer", "minerai_fer", "fourrure_troll", "lame_antique", "cristal_givre", "epee_verre"]:
		inv.ajouter(id, 1)
	inv.pieces = 1280
	# quêtes : 1 terminée, 3 en cours (état posé, journal des étapes faites)
	q.etat = {"anneau_givre": 3, "frere_ylva": 3, "lames_brodd": 2, "repaire_hrafn": 1}
	q.change.emit()

func _capturer(nom: String, maquette := "") -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(sortie)
	var chemin := sortie.path_join(nom + ".png")
	img.save_png(chemin)
	print("CAPTURE ", chemin, " ", img.get_size())
	if maquette != "" and FileAccess.file_exists(MAQUETTES + maquette):
		var m := Image.load_from_file(MAQUETTES + maquette)
		m.convert(Image.FORMAT_RGBA8)
		m.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		var r := img.duplicate() as Image
		r.convert(Image.FORMAT_RGBA8)
		r.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		var planche := Image.create(3840 + 16, 1080, false, Image.FORMAT_RGBA8)
		planche.fill(Color("#0b0f1a"))
		planche.blit_rect(m, Rect2i(0, 0, 1920, 1080), Vector2i.ZERO)
		planche.blit_rect(r, Rect2i(0, 0, 1920, 1080), Vector2i(1936, 0))
		var cp := sortie.path_join(nom + "_vs_maquette.png")
		planche.save_png(cp)
		print("PLANCHE ", cp)

func _captures(j: Node, oc: OngletCompetences) -> void:
	coquille.ouvrir("competences")
	oc.choisir("soif_du_loup")
	await _capturer("D_competences", "A_4_competences.png")
	oc.choisir("colere_de_thor")
	await _capturer("D_competences_branche")
	coquille.aller(2)
	await _capturer("D_personnage", "A_1_equipement.png")
	j.progression.points_attribut = 0
	j.progression.change.emit()
	await _capturer("D_personnage_sans_choix")
	coquille.aller(1)
	await _capturer("D_quetes", "A_2_inventaire.png")
	coquille.fermer()
	paused = false
	var e: EcranNiveau = s.hud.ecran_niveau
	e.figer = true
	e.annoncer_niveau(10)
	j.progression.points_attribut = 1
	e.annoncer_competence("une_main", 53)
	e.annoncer_competence("destruction", 39)
	for i in 20:
		await process_frame
	await _capturer("D_annonce_niveau")

func _script_touches() -> GDScript:
	var g := GDScript.new()
	g.source_code = """extends Node
var lanceur
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var j = lanceur.s.joueur
	match e.keycode:
		KEY_N:
			j.progression.gagner_xp(j.progression.seuil_niveau(j.progression.niveau))
		KEY_C:
			j.progression.competences.pratiquer("epee", 50.0)
		KEY_K:
			if not lanceur.coquille.ouvert:
				lanceur.coquille.ouvrir()
		KEY_F10:
			lanceur.quit()
"""
	g.reload()
	return g
