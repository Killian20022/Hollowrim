extends SceneTree
## Menu du personnage (lot C, docs/RPG.md §8-9 ; scripts/menu/menu_personnage.gd + onglets Équipement / Sac / Magie) dans
## scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/test_menu_personnage.gd -- --nouvelle
## Ouverture / fermeture (Tab, I, K, J, Échap, pause), signets, onglets du lot D (classe chargée ou page « à venir »),
## Sac sans doublon d'armes (hache de Kolbeinn visible, tenable depuis le lot A), équiper depuis le Sac / l'Équipement / la Magie,
## porter / retirer un objet de corps, comparaison, lâcher, favoris, raccourcis, sauvegarde (fichier de test, jamais
## user://sauvegarde.json), mort. Avec fenêtre (godot_slot) et --captures=<dossier> : une capture par onglet.

const SCENE := preload("res://scenes/test_combat.tscn")

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var ui: InventaireMains
var eq: EquipementMains
var _captures := ""

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _touche(code: Key, maj := false) -> void:
	for appui in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.shift_pressed = maj
		e.pressed = appui
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame

func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await _images(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	var chemin := _captures.path_join(nom)
	root.get_texture().get_image().save_png(chemin)
	print("CAPTURE ", chemin)

func _ids_sac(o: OngletSac) -> Array:
	return o.lignes.map(func(l: Dictionary) -> String: return String(l["id"]))

func _tester() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_captures = a.substr(11)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	ui = s.inventaire_ui
	eq = j.mains.magie.eq
	await _images(20)
	_verif(ui is MenuPersonnage and eq != null, "le menu du personnage remplace l'ancien écran I (InventaireMains hérite de MenuPersonnage)")
	var inv: Inventaire = j.inventaire
	for id in ["epee_or", "hache_kolbeinn", "minerai_fer", "lame_antique", "amulette_givre", "potion_soin", "fragment_sceau_os"]:
		inv.ajouter(id, 3 if id == "potion_soin" or id == "minerai_fer" else 1)
	j.mains.magie.equiper("droite", "epee")
	j.mains.magie.equiper("gauche", "torche")

	# --- ouverture / fermeture
	await _touche(KEY_TAB)
	_verif(ui.ouvert and paused and ui.onglet_actif == "equipement", "Tab : menu ouvert sur Équipement, jeu en pause")
	await _capture("menu_equipement.png")
	await _touche(KEY_TAB)
	_verif(ui.onglet_actif == "sac", "Tab (ouvert) : onglet suivant = Sac")
	await _touche(KEY_TAB, true)
	_verif(ui.onglet_actif == "equipement", "Maj+Tab : onglet précédent")
	await _touche(KEY_ESCAPE)
	_verif(not ui.ouvert and not paused, "Échap : menu fermé, jeu repris")
	await _touche(KEY_I)
	_verif(ui.ouvert and ui.onglet_actif == "sac", "I : menu ouvert sur le Sac")
	await _touche(KEY_I)
	_verif(not ui.ouvert and not paused, "I sur le Sac : fermé")
	await _touche(KEY_K)
	_verif(ui.ouvert and ui.onglet_actif == "competences", "K : Compétences")
	var oc := ui.onglet("competences")
	_verif(oc != null and (oc.get_script().resource_path.ends_with("onglet_competences.gd") or oc is MenuPersonnage.OngletAVenir),
		"Compétences : onglet du lot D s'il existe, sinon page « à venir » (%s)" % oc.get_script().resource_path)
	await _touche(KEY_J)
	_verif(ui.onglet_actif == "quetes", "J (ouvert) : Quêtes")
	var nb_signets := 0
	for o: Dictionary in MenuPersonnage.ONGLETS:
		nb_signets += 1 if ui.onglet(o["id"]) != null else 0
	_verif(nb_signets == 8, "8 signets : Équipement, Sac, Magie, Compétences, Quêtes, Carte, Personnage, Factions")
	ui._vue.queue_redraw()
	await _images(2)
	var x_en_tete := 20.0 + Parchemin.largeur(Palette.police(), "Voyageur · niveau %d" % int(j.progression.niveau))
	var chevauche := ui._signets.size() != 8
	for k in ui._signets.size():
		var r: Rect2 = ui._signets[k][0]
		chevauche = chevauche or r.position.x < x_en_tete + 4.0 or r.end.x > ui._vue.size.x - 60.0
		if k > 0:
			chevauche = chevauche or r.position.x < (ui._signets[k - 1][0] as Rect2).end.x
	_verif(not chevauche, "8 signets entre l'en-tête « Voyageur · niveau N » et le poids, sans chevauchement (%s)" %
		str(ui._signets.map(func(s: Array) -> String: return "%d-%d" % [int(s[0].position.x), int(s[0].end.x)])))
	await _touche(KEY_ESCAPE)

	# --- Sac : une arme une seule fois, la hache de Kolbeinn visible
	ui.ouvrir("sac")
	await _images(2)
	var sac := ui.onglet("sac") as OngletSac
	sac.filtrer("tout")
	var tous := _ids_sac(sac)
	_verif(tous.count("epee_or") == 1, "Tout : l'épée en or n'apparaît qu'une fois")
	sac.filtrer("arme")
	var armes := _ids_sac(sac)
	_verif(armes.has("epee_or") and armes.has("hache_kolbeinn") and armes.has("epee") and armes.has("bouclier") and not armes.has("vide"),
		"Armes : épée de départ, bouclier, épée en or, hache de Kolbeinn (%s)" % str(armes))
	sac.filtrer("divers")
	var divers := _ids_sac(sac)
	_verif(divers.has("lame_antique") and not divers.has("epee_or") and not divers.has("hache_kolbeinn") and not divers.has("minerai_fer"),
		"Divers : plus de doublon des armes (%s)" % str(divers))
	sac.filtrer("tout")
	sac.choisir("hache_kolbeinn")
	# intégration RPG : depuis le lot A, la hache de Kolbeinn se TIENT (data/armes/hache_kolbeinn.tres)
	var fh := sac.fiche("hache_kolbeinn")
	var deg := ""
	for l: Array in fh["lignes"]:
		if String(l[0]) == "Dégâts":
			deg = String(l[1])
	_verif(deg.contains(" léger · ") and deg.ends_with(" lourd") and not deg.contains(".0"), "fiche de la hache : dégâts au format du menu (« %s »)" % deg)
	var rh := sac.action_principale()
	_verif(ui.tenu("droite") == "hache_kolbeinn", "hache de Kolbeinn : se tient depuis le Sac (lot A) (« %s »)" % rh)
	sac.choisir("epee")
	sac.action_principale()
	_verif(ui.tenu("droite") == "epee", "épée de départ reprise en main droite")
	sac.choisir("hache_kolbeinn")
	sac.choisir("epee_or")
	var f := sac.fiche("epee_or")
	_verif(not (f["compare"] as Array).is_empty() and String(f["compare"][2]).begins_with("vs "), "fiche : comparaison avec l'arme tenue (%s)" % str(f["compare"]))
	await _capture("menu_sac.png")
	await _touche(KEY_E)
	_verif(ui.tenu("droite") == "epee_or", "E dans le Sac : épée en or en main droite")
	_verif(sac._marque("epee_or") == "D", "marque D sur l'épée tenue")
	sac.choisir("torche")
	await _touche(KEY_G)
	_verif(ui.tenu("gauche") == "torche", "G : torche en main gauche")
	# objet de corps
	sac.choisir("amulette_givre")
	await _touche(KEY_E)
	_verif(j.equipement_corps.objet_a("cou") == "amulette_givre" and sac._marque("amulette_givre") == "P", "E : amulette portée (cou), marque P")
	await _touche(KEY_E)
	_verif(j.equipement_corps.objet_a("cou") == "", "E à nouveau : amulette retirée")
	# favoris
	sac.choisir("minerai_fer")
	await _touche(KEY_F)
	_verif(ui.est_favori("minerai_fer"), "F : minerai en favori")
	sac.filtrer("favoris")
	_verif(_ids_sac(sac) == ["minerai_fer"], "Favoris : seulement le minerai")
	sac.filtrer("tout")
	# lâcher
	sac.choisir("minerai_fer")
	var n_min := inv.nombre("minerai_fer")
	var vu := [n_min]   # scène de test sans interactions : le sac au sol se reverse aussitôt (Butin._verser) ; on note le retrait
	var suivre := func() -> void: vu.append(inv.nombre("minerai_fer"))
	inv.change.connect(suivre)
	await _touche(KEY_R)
	inv.change.disconnect(suivre)
	_verif(vu.min() == n_min - 1 and ui.message.begins_with("Lâché"), "R : 1 minerai lâché (%d → %d, « %s »)" % [n_min, vu.min(), ui.message])
	sac.choisir("fragment_sceau_os")
	await _touche(KEY_R)
	_verif(inv.nombre("fragment_sceau_os") == 1 and ui.message.contains("quête"), "objet de quête : jamais lâché (« %s »)" % ui.message)
	# catégories au clavier
	sac.filtrer("tout")
	await _touche(KEY_RIGHT)
	_verif(sac.filtre == "favoris", "→ : catégorie suivante")
	sac.filtrer("consommable")
	sac.choisir("potion_soin")
	await _touche(KEY_7)
	_verif(String(eq.raccourcis[6].get("conso", "")) == "potion_soin", "7 sur une potion : raccourci 7 = potion de soin")

	# --- Équipement : emplacements, changer, retirer
	ui.changer_onglet("equipement")
	await _images(2)
	var oe := ui.onglet("equipement") as OngletEquipement
	oe.sel = 4   # cou
	await _touche(KEY_E)
	var ids_choix := oe.choix.map(func(c: Dictionary) -> String: return String(c["id"]))
	_verif(ids_choix.has("amulette_givre") and ids_choix.has(""), "E sur Amulette : liste (rien, amulette de givre)")
	oe.choix_sel = ids_choix.find("amulette_givre")
	await _touche(KEY_E)
	_verif(j.equipement_corps.objet_a("cou") == "amulette_givre" and oe.choix.is_empty(), "choisir : amulette portée depuis l'Équipement")
	oe.sel = 3   # main droite
	await _touche(KEY_E)
	var ids_d := oe.choix.map(func(c: Dictionary) -> String: return String(c["id"]))
	_verif(ids_d.has("epee") and not ids_d.has("bouclier") and not ids_d.has("torche"), "main droite : candidats permis seulement (pas de bouclier ni torche)")
	await _capture("menu_equipement_changer.png")
	oe.choix_sel = ids_d.find("epee")
	await _touche(KEY_E)
	_verif(ui.tenu("droite") == "epee", "choisir : épée en main droite depuis l'Équipement")
	oe.sel = 7
	await _touche(KEY_R)
	_verif(ui.tenu("gauche") == "vide", "R sur Main gauche : main nue")
	oe.sel = 4
	await _touche(KEY_E)
	await _touche(KEY_ESCAPE)
	_verif(ui.ouvert and oe.choix.is_empty(), "Échap dans la liste : annule sans fermer le menu")
	await _touche(KEY_R)
	_verif(j.equipement_corps.objet_a("cou") == "", "R sur Amulette : retirée")
	j.equipement_corps.equiper("amulette_givre")
	await _touche(KEY_DOWN)
	_verif(oe.sel == 5, "↓ : emplacement suivant")

	# --- Magie
	ui.changer_onglet("magie")
	await _images(2)
	var om := ui.onglet("magie") as OngletMagie
	_verif(om.sorts.size() == eq.sorts_connus.size() and om.sorts.size() > 0, "Magie : %d sorts connus" % om.sorts.size())
	om.choisir("soin")
	await _touche(KEY_G)
	_verif(ui.tenu("gauche") == "soin", "G dans la Magie : Soin en main gauche")
	await _touche(KEY_5)
	_verif(eq.raccourcis[4].get("gauche") == "soin" and eq.raccourcis[4].get("droite") == "epee", "5 : raccourci 5 = soin | épée")
	await _capture("menu_magie.png")
	om.choisir("jet_flammes")
	await _touche(KEY_E)
	_verif(ui.tenu("droite") == "jet_flammes", "E : Jet de flammes en main droite")

	# --- compatibilité de l'ancien écran
	ui.categorie = "consommables"
	_verif(ui.onglet_actif == "sac" and ui.categorie == "consommables", "categorie = consommables → Sac filtré Potions")
	ui._choisir("conso:potion_soin")
	_verif(ui.choisi == "potion_soin", "_choisir(« conso:… ») accepté")
	ui.categorie = "sorts"
	_verif(ui.onglet_actif == "magie", "categorie = sorts → Magie")

	# --- fermeture, sauvegarde
	await _touche(KEY_ESCAPE)
	_verif(not ui.ouvert and not paused, "Échap : fermé")
	var fichier := "user://test_menu_personnage.json"
	var sv := FileAccess.open(fichier, FileAccess.WRITE)
	var fav_avant: Array = ui.favoris.keys()
	sv.store_string(JSON.stringify({"magie": j.mains.magie.exporter(), "equipement_corps": j.equipement_corps.exporter(), "inventaire": inv.exporter(),
		"menu": ui.exporter_menu()}))
	sv.close()
	j.equipement_corps.retirer("cou")
	j.mains.magie.equiper("droite", "epee")
	var lu: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fichier))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	inv.importer(lu["inventaire"])
	j.equipement_corps.importer(lu["equipement_corps"])
	j.mains.magie.importer(lu["magie"])
	ui.favoris.clear()
	ui.importer_menu(lu["menu"])
	_verif(not fav_avant.is_empty() and ui.favoris.keys().size() == fav_avant.size() and fav_avant.all(func(x): return ui.est_favori(x)),
		"rechargement : favoris du Sac restaurés (clé menu.favoris) %s" % str(fav_avant))
	ui.importer_menu({"favoris": {"minerai_fer": true, "objet_disparu_xyz": true, "7": 3}})
	var tol := ui.est_favori("minerai_fer") and not ui.est_favori("objet_disparu_xyz") and ui.favoris.size() == 1
	ui.importer_menu(null)
	ui.importer_menu("n'importe quoi")
	_verif(tol and ui.favoris.is_empty(), "favoris : migration tolérante (dictionnaire, inconnus ignorés, clé absente ou invalide = aucun)")
	_verif(j.equipement_corps.objet_a("cou") == "amulette_givre" and ui.tenu("droite") == "jet_flammes" and eq.raccourcis[4].get("gauche") == "soin",
		"rechargement : amulette portée, mains et raccourcis équipés depuis le menu restaurés")
	# --- mort : pas de menu
	j.mort = true
	await _touche(KEY_TAB)
	_verif(not ui.ouvert, "mort : Tab n'ouvre pas le menu")
	j.mort = false
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
