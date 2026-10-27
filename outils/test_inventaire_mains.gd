extends SceneTree
## Test de l'écran d'inventaire des deux mains (scripts/inventaire_mains.gd) dans scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/test_inventaire_mains.gd -- --nouvelle
## Ouverture (touche I) et pause, catégories, équiper main gauche / droite, refus expliqués, arme à deux mains (les deux
## emplacements), raccourci assigné depuis l'inventaire puis utilisé, raccourci vidé, sauvegarde / rechargement (fichier
## de test, jamais user://sauvegarde.json), fermeture. Avec fenêtre (godot_slot) et --captures=<dossier> : 3 captures.

const SCENE := preload("res://scenes/test_combat.tscn")

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var magie: Node
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

func _touche(code: Key) -> void:
	for appui in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = appui
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame

func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await _images(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	var chemin := _captures.path_join(nom)
	root.get_texture().get_image().save_png(chemin)
	print("CAPTURE ", chemin)

func _tester() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_captures = a.substr(11)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	magie = j.mains.magie
	ui = s.inventaire_ui
	eq = magie.eq
	await _images(20)
	_verif(ui != null and eq != null, "inventaire présent dans la scène de test (InventaireMains + EquipementMains)")
	_verif(InputMap.has_action("inventaire"), "action « inventaire » (I) reconfigurable dans l'InputMap")
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "torche")

	# --- ouverture par la touche I : jeu en pause
	await _touche(KEY_I)
	_verif(ui.ouvert and paused, "touche I : inventaire ouvert, jeu en pause")
	_verif(ui.categorie == "armes", "catégorie de départ : Armes")
	var armes := eq.objets_possedes("armes")
	_verif(armes.has("vide") and armes.has("epee") and armes.has("torche") and armes.has("bouclier"), "Armes : main nue, épée, torche, bouclier (%s)" % str(armes))
	var sorts := eq.objets_possedes("sorts")
	_verif(sorts.size() == eq.sorts_connus.size() and eq.sort_par_id(sorts[0]).ecole == "feu", "Sorts : %d sorts connus, triés par école (%s…)" % [sorts.size(), sorts[0]])
	_verif(eq.objets_possedes("divers").is_empty(), "Divers : rien d'équipable (le sac s'y affiche)")
	var f := eq.fiche("boule_feu")
	_verif(String(f["nom"]) == "Boule de feu" and (f["lignes"] as Array).any(func(l: String) -> bool: return l.begins_with("Coût")) and (f["lignes"] as Array).any(func(l: String) -> bool: return l.begins_with("Dégâts")), "fiche d'un sort : nom, coût en mana, dégâts (%s)" % str(f["lignes"]))
	var fe := eq.fiche("epee")
	_verif((fe["lignes"] as Array).any(func(l: String) -> bool: return l.begins_with("Dégâts")) and (fe["lignes"] as Array).any(func(l: String) -> bool: return l.begins_with("Vitesse")), "fiche d'une arme : dégâts, vitesse (%s)" % str(fe["lignes"]))
	await _capture("inventaire_armes.png")

	# --- équiper : main gauche / main droite
	ui._changer_categorie("sorts")
	await _images(2)
	_verif(ui._liste.get_child_count() >= sorts.size(), "liste des sorts affichée (%d lignes)" % ui._liste.get_child_count())
	_verif(ui.equiper("gauche", "jet_flammes") == "" and eq.mains["gauche"]["id"] == "jet_flammes", "clic droit : Jet de flammes dans la main gauche")
	_verif(ui.equiper("droite", "chaine_eclairs") == "" and eq.mains["droite"]["id"] == "chaine_eclairs" and eq.mains["gauche"]["id"] == "jet_flammes", "clic gauche : Chaîne d'éclairs dans la main droite (la gauche garde son sort)")
	_verif(ui.equiper("droite", "jet_flammes") == "" and eq.mains["droite"]["id"] == "jet_flammes", "même sort dans les deux mains (double incantation possible)")
	# refus expliqués
	var r1 := ui.equiper("gauche", "enchant_feu")
	_verif(r1.contains("épée") and eq.mains["gauche"]["id"] == "jet_flammes", "refus lisible : « %s »" % r1)
	var r2 := ui.equiper("droite", "bouclier")
	_verif(r2.contains("bras gauche") and ui.message == r2, "refus lisible : « %s » (bandeau)" % r2)
	var r3 := ui.equiper("gauche", "epee")
	_verif(r3.contains("main droite"), "refus lisible : « %s »" % r3)
	_verif(String(eq.essai("droite", "torche")["refus"]) != "", "fiche : la raison est connue AVANT d'essayer (torche en main droite : « %s »)" % eq.essai("droite", "torche")["refus"])
	ui._choisir("bouclier")
	await _images(2)
	await _capture("inventaire_refus.png")

	# --- arme à deux mains (donnée de test, aucune n'existe encore dans data/armes)
	var espadon := (load("res://data/armes/epee_metal.tres") as DonneesArme).duplicate() as DonneesArme
	espadon.id = "espadon_test"
	espadon.nom = "Espadon (test)"
	espadon.deux_mains = true
	eq.objets_supplementaires["espadon_test"] = espadon
	_verif(eq.objets_possedes("armes").has("espadon_test"), "une arme à deux mains apparaît dans Armes (données, rien de codé en dur)")
	ui.equiper("gauche", "torche")
	var e2 := eq.essai("droite", "espadon_test")
	_verif(String(e2["effet"]).contains("deux mains"), "fiche : « %s »" % e2["effet"])
	_verif(ui.equiper("droite", "espadon_test") == "" and eq.categorie("droite") == "arme_deux_mains" and eq.categorie("gauche") == "vide", "arme à deux mains : occupe les deux emplacements (gauche libérée)")
	_verif(ui.message.contains("deux mains"), "message : « %s »" % ui.message)
	ui._changer_categorie("armes")
	await _images(2)
	_verif((ui._main_ui["gauche"]["nom"] as Label).text.contains("deux mains"), "aperçu : la main gauche affiche « %s »" % (ui._main_ui["gauche"]["nom"] as Label).text)
	await _capture("inventaire_deux_mains.png")
	_verif(ui.equiper("gauche", "torche") == "" and eq.categorie("droite") == "vide" and eq.categorie("gauche") == "torche" and ui.message.contains("rangée"), "torche à gauche : l'arme à deux mains est rangée (« %s »)" % ui.message)

	# --- raccourcis assignés depuis l'inventaire
	ui.equiper("droite", "epee")
	ui.equiper("gauche", "drain_vie")
	_verif(ui.memoriser(4) == "" and eq.raccourcis[4]["gauche"] == "drain_vie" and eq.raccourcis[4]["droite"] == "epee", "raccourci 5 ← drain de vie | épée (%s)" % str(eq.raccourcis[4]))
	ui.equiper("gauche", "bouclier")
	await _touche(KEY_3)
	_verif(eq.raccourcis[2]["gauche"] == "bouclier" and eq.raccourcis[2]["droite"] == "epee", "touche 3 dans l'inventaire : raccourci 3 ← bouclier | épée")
	ui.vider_raccourci(9)
	_verif(not eq.raccourcis[9].has("gauche") and not eq.raccourcis[9].has("droite"), "raccourci 0 vidé")
	_verif(j.raccourcis is Array and (j.raccourcis as Array).size() == 8, "HUD : joueur.raccourcis toujours lisible (8 cases)")

	# --- fermeture
	await _touche(KEY_I)
	_verif(not ui.ouvert and not paused, "touche I : inventaire fermé, jeu repris")
	magie.raccourci(4)
	_verif(eq.mains["gauche"]["id"] == "drain_vie" and eq.mains["droite"]["id"] == "epee", "touche 5 en jeu : drain de vie | épée équipés")
	magie.raccourci(9)
	_verif(eq.mains["gauche"]["id"] == "drain_vie" and eq.mains["droite"]["id"] == "epee", "touche 0 (vidée) : les mains ne changent pas")

	# --- sauvegarde / rechargement (fichier de test du worktree, jamais la vraie partie)
	var fichier := "user://test_inventaire_mains.json"
	var sv := FileAccess.open(fichier, FileAccess.WRITE)
	sv.store_string(JSON.stringify({"magie": magie.exporter()}, "\t"))
	sv.close()
	eq.assigner_raccourci(4, "vide", "vide")
	eq.raccourcis[9] = {"touche": "0", "gauche": "torche", "droite": "epee"}
	magie.equiper("gauche", "torche")
	var lu: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fichier))
	magie.importer(lu["magie"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	_verif(eq.raccourcis[4].get("gauche") == "drain_vie" and eq.raccourcis[4].get("droite") == "epee" and eq.raccourcis[2].get("gauche") == "bouclier", "rechargement : raccourcis assignés restaurés (5 = drain | épée, 3 = bouclier | épée)")
	_verif(not eq.raccourcis[9].has("gauche"), "rechargement : raccourci 0 toujours vide")
	_verif(eq.mains["gauche"]["id"] == "drain_vie" and eq.mains["droite"]["id"] == "epee", "rechargement : mains restaurées")
	_verif(eq.raccourcis.size() == 10, "10 raccourcis après rechargement")

	# --- pas d'inventaire mort
	j.mort = true
	await _touche(KEY_I)
	_verif(not ui.ouvert, "mort : l'inventaire ne s'ouvre pas")
	j.mort = false

	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
