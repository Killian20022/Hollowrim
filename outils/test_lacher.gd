extends SceneTree
## « Lâcher » dans l'inventaire (scripts/lacher.gd, inventaire_mains.gd) :
##   godot --headless --path . --script res://outils/test_lacher.gd -- --nouvelle
## Avec fenêtre (godot_slot.sh) et --sorties=<dossier> : lacher_inventaire.png, lacher_sac_au_sol.png.

const SCENE := preload("res://scenes/foret_test.tscn")

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
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

func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await _images(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	var chemin := _captures.path_join(nom)
	root.get_texture().get_image().save_png(chemin)
	print("CAPTURE ", chemin)

func _sacs() -> Array:
	return s.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and String(n.get_script().resource_path).ends_with("butin.gd") and String(n.cle_sauvegarde).begins_with("lache:"))

func _touche(code: Key, maj := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	e.shift_pressed = maj
	s.inventaire_ui._input(e)

func _tester() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sorties="):
			_captures = a.substr(10)
	ButinTables.reinitialiser()
	s = SCENE.instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	j = s.joueur
	await _images(30)
	var inv: Inventaire = j.inventaire
	inv.objets.clear()
	var ui: InventaireMains = s.inventaire_ui

	# --- règles
	_verif(Lacher.refus("potion_soin") == "" and Lacher.refus("minerai_fer") == "", "potion et minerai : lâchables")
	_verif(Lacher.refus("epee_skarnholt").contains("unique"), "objet unique : refusé (« %s »)" % Lacher.refus("epee_skarnholt"))
	_verif(Lacher.refus("fragment_sceau_os").contains("quête") and Lacher.refus("cle_archives").contains("quête"), "objets de quête : refusés (« %s »)" % Lacher.refus("cle_archives"))
	_verif(Lacher.refus("n_importe_quoi") != "", "objet inconnu : refusé")

	# --- lâcher 1 d'une pile
	inv.ajouter("potion_soin", 3)
	inv.ajouter("fragment_sceau_os", 1)
	var poids0 := inv.poids()
	var av: Vector3 = -(j.camera.global_basis.z)
	av.y = 0.0
	av = av.normalized()
	_verif(Lacher.lacher(j, s.hud, "potion_soin", 1) == "", "lâcher 1 potion")
	await _images(3)
	_verif(inv.nombre("potion_soin") == 2 and inv.poids() < poids0, "le sac perd 1 potion (reste %d), poids %.1f -> %.1f" % [inv.nombre("potion_soin"), poids0, inv.poids()])
	var sacs := _sacs()
	_verif(sacs.size() == 1, "un sac au sol est apparu")
	var sac: Node3D = sacs[0]
	var d: Vector3 = sac.global_position - j.global_position
	var devant: float = d.x * av.x + d.z * av.z
	_verif(devant > 0.8 and devant < 1.6 and sac.contenu == {"potion_soin": 1}, "il tombe devant le joueur (%.2f m) avec 1 potion" % devant)
	_verif(sac.a_fouille() and sac.find_children("*", "MeshInstance3D", false, false).size() >= 2, "sac visible et invite « Fouiller » posée")
	_verif(ButinTables.a_reste(sac.cle_sauvegarde) and ButinTables.corps.has(sac.cle_sauvegarde), "sac enregistré pour la sauvegarde (clé %s)" % sac.cle_sauvegarde)

	await _capture("lacher_sac_au_sol.png")      # (le sac est devant, sous la ligne de visée : peu visible en vue subjective)

	# --- refus : objet de quête
	var avant := inv.nombre("fragment_sceau_os")
	_verif(Lacher.lacher(j, s.hud, "fragment_sceau_os", 1) != "" and inv.nombre("fragment_sceau_os") == avant and _sacs().size() == 1, "objet de quête : rien lâché, sac intact")

	# --- sauvegarde : l'état exporté, un monde rechargé repose le sac
	var etat := ButinTables.exporter()
	_verif((etat["corps"] as Dictionary).has(sac.cle_sauvegarde) and (etat["restes"] as Dictionary).has(sac.cle_sauvegarde), "l'état exporté contient le sac lâché")
	var pos := sac.global_position
	ButinTables.reinitialiser()
	ButinTables.importer(etat)
	load("res://scripts/butin.gd").restaurer(s, j, s.hud)
	await _images(3)
	var apres := _sacs()
	_verif(apres.size() == 1 and apres[0].global_position.distance_to(pos) < 0.05 and apres[0].contenu == {"potion_soin": 1}, "partie rechargée : le sac est reposé au même endroit, même contenu")
	_verif(apres[0].find_children("*", "MeshInstance3D", false, false).size() >= 2, "le sac rechargé est visible")

	# --- ramasser : le sac se vide dans l'inventaire
	var avant_p := inv.nombre("potion_soin")
	var sac2: Node3D = apres[0]
	sac2.fouiller()
	await _images(3)
	var f := FenetreButin.trouver(sac2)
	if f != null and f.ouvert:
		f.tout_prendre()
	await _images(3)
	_verif(inv.nombre("potion_soin") == avant_p + 1 and not is_instance_valid(sac2), "ramassé par « Fouiller » : la potion revient au sac (%d -> %d)" % [avant_p, inv.nombre("potion_soin")])
	_verif(not ButinTables.a_reste("x") and _sacs().is_empty(), "le sac vide disparaît du sol")

	# --- interface : touche L, Maj+L, boutons, manette
	inv.objets.clear()
	inv.ajouter("potion_mana", 4)
	inv.ajouter("minerai_fer", 5)
	inv.ajouter("fragment_sceau_os", 1)
	var avant_sacs := _sacs().size()
	ui.categorie = "consommables"
	ui.ouvrir()
	await _images(3)
	ui._choisir("conso:potion_mana")
	await _images(2)
	var boutons := ui._fiche.find_children("*", "Button", true, false)
	_verif(boutons.size() == 2, "fiche d'une pile : deux boutons « Lâcher 1 » et « Tout » (%d)" % boutons.size())
	await _capture("lacher_inventaire.png")
	_touche(KEY_L)
	await _images(3)
	_verif(inv.nombre("potion_mana") == 3 and _sacs().size() == avant_sacs + 1 and ui.message.begins_with("Lâché"), "touche L : lâche 1 potion (« %s »)" % ui.message)
	_touche(KEY_L, true)
	await _images(3)
	_verif(inv.nombre("potion_mana") == 0 and _sacs().size() == avant_sacs + 2, "Maj+L : lâche toute la pile (reste %d)" % inv.nombre("potion_mana"))
	var bouton_ok := false
	ui._changer_categorie("divers")
	await _images(3)
	ui._choisir("sac:minerai_fer")
	await _images(2)
	var bs := ui._fiche.find_children("*", "Button", true, false)
	if bs.size() == 2:
		(bs[1] as Button).pressed.emit()      # « Tout (5) »
		bouton_ok = true
	await _images(3)
	_verif(bouton_ok and inv.nombre("minerai_fer") == 0 and _sacs().size() == avant_sacs + 3, "bouton « Tout » : les 5 minerais lâchés")
	ui._choisir("sac:fragment_sceau_os")
	await _images(2)
	_verif(ui._fiche.find_children("*", "Button", true, false).is_empty(), "objet de quête : aucun bouton, la raison est affichée")
	var r := ui.lacher(false)
	_verif(r.contains("quête") and ui.message.contains("quête") and inv.nombre("fragment_sceau_os") == 1, "objet de quête : refus clair dans le bandeau (« %s »)" % ui.message)
	var jy := InputEventJoypadButton.new()
	jy.button_index = JOY_BUTTON_Y
	jy.pressed = true
	ui._input(jy)
	_verif(inv.nombre("fragment_sceau_os") == 1, "manette Y : même refus sur l'objet de quête")
	ui._choisir("")
	_verif(ui.lacher(false) != "", "rien de choisi : message, pas d'erreur")
	await _capture("lacher_refus_quete.png")
	ui.fermer()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
