extends SceneTree
## Captures du lot E RPG « stockage, marchands, forge » (FENÊTRE hors écran via godot_slot.sh) :
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_stockage.gd -- --nouvelle --paisible --sortie=<dossier>
## Vues : coffre loué chez Grima (objet dans l'intérieur, puis fenêtre coffre ↔ sac, aussi en 480x270), Gunnar (« Acheter la
## maison »), maison des Frostmark achetée (râtelier garni, coffre de la maison), boutique de Brodd (Acheter, Vendre filtré),
## forge de Brodd, fenêtre de butin d'un coffre du monde.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var sortie := ""
var args := {}

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sortie = String(args.get("sortie", "res://captures/rpg_stockage"))
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	var f := dossier.path_join(nom + ".png")
	img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size())

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if p.donnees.get("id") == id:
			return p
	return null

func _jour() -> void:
	m.cycle.heure = 12.0
	m.cycle._process(0.0)

## Joueur dans l'intérieur `ip` au point local `ou`, regard sur le point local `cible`.
func _dans(ip: Node3D, ou: Vector3, cible: Vector3) -> void:
	var j: CharacterBody3D = m.joueur
	j.global_position = ip.to_global(ou)
	j.velocity = Vector3.ZERO
	m._viser(ip.to_global(cible))

func _devant(p: Node3D) -> void:
	p.set_physics_process(false)
	var dir: Vector3 = m.village.global_position - p.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
	var j: CharacterBody3D = m.joueur
	j.global_position = p.global_position + dir * 1.7 + Vector3(0, 0.1, 0)
	j.velocity = Vector3.ZERO
	m._viser(p.global_position + Vector3(0, 1.45, 0))

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(90)
	m.hud.aide_t = 0.0
	m.hud.lieux_vus["Skarnholt"] = true      # pas d'annonce « Lieu découvert » sur les vues d'intérieur
	m.joueur.mains.visible = false
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	var sv: ServicesPnj = m.services
	var fc: FenetreCoffre = sv.fenetre_coffre
	_jour()
	# un sac de voyageur réaliste
	inv.pieces = 2380
	for o: Array in [["potion_soin", 5], ["potion_mana", 2], ["pain_seigle", 3], ["os_draugr", 7], ["minerai_fer", 6], ["minerai_argent", 3],
			["cristal_givre", 2], ["epee_soldat", 1], ["hache_guerre", 1], ["cle_archives", 1], ["dague_acier", 1], ["collier_or", 1]]:
		inv.ajouter(o[0], o[1])
	var g := Stockage.conteneur("coffre_grima")
	for o: Array in [["grand_marteau", 1], ["ecu_chevalier", 1], ["fourrure_troll", 2], ["relique_offrande", 1], ["tome_lance_givre", 1], ["coupe_argent", 1]]:
		g.ajouter(o[0], o[1])
	g.pieces = 400
	# --- 1. coffre loué chez Grima : l'objet dans l'intérieur
	var ig: Interieur = m.village.interieur("grima")
	ig.basculer(true, false)
	_dans(ig, Vector3(1.5, 0.5, 0.7), ServicesPnj.COFFRE_GRIMA + Vector3(0, 0.2, 0))
	await _images(90)
	_jour()
	await _capturer("1_coffre_grima_interieur")
	# --- 2. la fenêtre coffre ↔ sac
	fc.ouvrir("coffre_grima")
	fc.changer_cote(0)
	fc._choisir(fc.lignes[0].find("fourrure_troll"))
	await _images(10)
	await _capturer("2_coffre_grima_fenetre")
	fc.changer_cote(1)
	fc._choisir(fc.lignes[1].find("cle_archives"))
	await _images(6)
	await _capturer("3_coffre_grima_quete_refusee")
	fc._choisir(fc.lignes[1].find("minerai_fer"))
	get_root().content_scale_size = Vector2i(480, 270)
	await _images(10)
	await _capturer("4_coffre_grima_480x270")
	get_root().content_scale_size = Vector2i(640, 360)
	fc.fermer()
	await _images(4)
	# --- 3. Gunnar : acheter la maison
	var d: Control = m.dialogue
	var chef := _pnj("chef")
	_devant(chef)
	await _images(30)
	d._ouvrir(chef)
	var n := 0
	while d._ouvert and not d._choix_vis and n < 80:
		d._suite()
		await _images(6)
		n += 1
	await _images(20)
	await _capturer("5_gunnhild_acheter_maison")
	d._valider_choix()
	await _images(30)
	await _capturer("6_maison_achetee_avis")
	# --- 4. la maison : râtelier garni, coffre
	var km := Stockage.conteneur("coffre_maison")
	for id in ["claymore", "marteau_guerre", "epee_doree", "hache_guerre"]:
		km.ajouter(id, 1)
	km.ajouter("fourrure_troll", 1)
	sv._actualiser_ratelier()
	var im: Interieur = m.village.interieur(Stockage.MAISON)
	im.basculer(true, false)
	_dans(im, Vector3(-1.7, 0.5, -0.1), ServicesPnj.RATELIER + Vector3(0, 0.95, 0))
	await _images(420)          # bandeau « Nouvelle quête » (Gunnar) et avis du HUD effacés
	_jour()
	await _capturer("7_maison_ratelier")
	_dans(im, Vector3(1.45, 0.5, 1.0), ServicesPnj.COFFRE_MAISON + Vector3(0, 0.2, 0))
	await _images(60)
	await _capturer("8_maison_coffre_interieur")
	fc.ouvrir("coffre_maison")
	fc.changer_cote(0)
	await _images(8)
	await _capturer("9_maison_coffre_fenetre")
	fc.fermer()
	# --- 5. boutique de Brodd
	var mb: Marchand = m.marchand
	mb.ouvrir("forgeron")
	mb._choisir(2)
	await _images(8)
	await _capturer("10_marchand_acheter")
	mb.changer_onglet(1)
	mb.changer_categorie("arme")
	await _images(8)
	await _capturer("11_marchand_vendre_armes")
	mb.fermer()
	# --- 6. forge
	var fo: Forge = sv.forge
	Forge.ameliorer(j, "hache_guerre")
	fo.ouvrir()
	fo._choisir(fo.lignes.find("epee_soldat"))
	await _images(8)
	await _capturer("12_forge_epee")
	fo._choisir(fo.lignes.find("hache_guerre+1"))
	await _images(6)
	await _capturer("13_forge_hache_plus1")
	fo.fermer()
	# --- 7. butin d'un coffre du monde (prendre seulement)
	var fb: FenetreButin = m.fenetre_butin
	fb.ouvrir("Coffre de bandit", {"epee_verre": 1, "potion_soin_forte": 2, "minerai_argent": 3, "anneau_cuivre": 1}, 37)
	await _images(8)
	await _capturer("14_butin_coffre_monde")
	fb.fermer()
	await _images(4)
	quit(0)
