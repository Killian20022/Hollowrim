extends SceneTree
## Manette (scripts/manette.gd, docs/OPTIONS_SAUVEGARDES.md « Manette ») dans le vrai monde, avec des événements InputEventJoypad*
## SIMULÉS (Input.parse_input_event : l'état d'Input ET les scripts les reçoivent comme d'une vraie manette) :
##   godot --headless --path . --script res://outils/test_manette.gd -- --nouvelle
## - InputMap : boutons par défaut ajoutés aux actions (clavier inchangé), commandes propres (main droite / gauche, raccourcis,
##   accroupi) ; zone morte radiale et courbe du stick droit ; remappage manette (échange, réservés, effacement) ;
## - dernière entrée : clavier -> manette -> clavier ; aides (bulles, cartouche F1, bandeaux, invite) en noms de boutons ;
## - déplacement au stick gauche (zone morte), caméra au stick droit (sensibilité, inversion Y), saut Y, esquive B ;
## - épée : RT court = coup léger, RT maintenu = coup puissant, LT = garde ; une gâchette tenue n'appuie qu'une fois ;
## - menu du personnage : Vue ouvre, RB / LB onglets, croix et stick gauche choisissent, B ferme (sans esquive à la reprise) ;
## - dialogue : A parle, A suit, croix choisit, B ferme sans esquiver.
## Avec fenêtre (godot_slot) et --photos-manette=<dossier> : menu Sac au pad, Options > Touches (colonne Manette, focus), bulle d'aide.

const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D
var _echecs := 0
var _captures := ""

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _envoyer(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _bouton(b: JoyButton, appui := true) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = appui
	_envoyer(e)

## Appui puis relâchement, une image entre les deux.
func _clic(b: JoyButton) -> void:
	_bouton(b, true)
	await _images(2)
	_bouton(b, false)
	await _images(2)

func _axe(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	_envoyer(e)

func _touche(k: Key) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = p
		_envoyer(e)
		await process_frame

func _a_manette(action: String, classe: String) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev.get_class() == classe:
			return true
	return false

func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await _images(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	var chemin := _captures.path_join(nom)
	root.get_texture().get_image().save_png(chemin)
	print("CAPTURE ", chemin)

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if p.get("donnees") is Dictionary and p.donnees.get("id") == id:
			return p
	return null

func _tester() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--photos-manette="):
			_captures = a.substr(17)
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(30)
	j = m.joueur
	_verif(root.has_node("Manette") and root.get_node("Manette").get_index() > m.get_index(), "nœud Manette posé après la scène (son _input passe avant le sien) : %s" % [root.get_children().map(func(c: Node) -> String: return c.name)])

	# --- InputMap
	_verif(_a_manette("interagir", "InputEventJoypadButton") and _a_manette("interagir", "InputEventKey"), "interagir : A ajouté, touche E gardée")
	_verif(_a_manette("main_droite", "InputEventJoypadMotion") and _a_manette("main_droite", "InputEventMouseButton"), "main droite : RT + clic gauche")
	_verif(_a_manette("raccourci_1", "InputEventKey") and _a_manette("raccourci_1", "InputEventJoypadButton"), "raccourci 1 : touche 1 + croix haut")
	_verif(InputMap.has_action("accroupi") and Manette.libelle("accroupi") == "L3", "accroupi : action prête (L3), en attendant la touche de la furtivité")
	_verif(_a_manette("avant", "InputEventJoypadMotion") and absf(InputMap.action_get_deadzone("avant") - 0.2) < 0.01, "avancer : stick gauche, zone morte 0,2")
	var nb := InputMap.action_get_events("interagir").size()
	Touches.appliquer()
	_verif(InputMap.action_get_events("interagir").size() == nb, "appliquer() répété : pas d'événement en double (%d)" % nb)
	_verif(Manette.libelle("saut") == "Y" and Manette.libelle("esquive") == "B" and Manette.libelle("main_gauche") == "LT" and Manette.libelle("menu") == "Vue", "libellés : Y saut, B esquive, LT main gauche, Vue menu")
	# zone morte radiale + courbe
	_verif(Manette.reponse(Vector2(0.15, 0.1), 0.2, 1.8) == Vector2.ZERO, "zone morte radiale : (0,15 ; 0,1) ne fait rien")
	var r := Manette.reponse(Vector2(0.6, 0.0), 0.2, 1.8)
	_verif(r.x > 0.0 and r.x < 0.5, "courbe douce : stick à 60 %% -> %.2f (plus fin que linéaire 0,5)" % r.x)
	_verif(is_equal_approx(Manette.reponse(Vector2(1, 0), 0.2, 2.6).x, 1.0), "plein régime au bord du stick")

	# --- dernière entrée et aides
	await _touche(KEY_F13)
	_verif(not Manette.actif(), "clavier : textes clavier")
	var g0 := Manette.generation
	_bouton(JOY_BUTTON_GUIDE)
	_bouton(JOY_BUTTON_GUIDE, false)
	await _images(2)
	_verif(Manette.actif() and Manette.generation != g0, "bouton de manette : dernière entrée = manette")
	var aide: Array = m.hud.aide_lignes
	_verif(aide.any(func(l: Array) -> bool: return l[0] == "RT" and l[1] == "frapper") and aide.any(func(l: Array) -> bool: return l[0] == "LT"), "cartouche F1 réécrit en boutons : %s" % [aide.map(func(l: Array) -> String: return l[0])])
	_verif(Aides.texte_de("ennemi").contains("Maintiens LT") and Aides.texte_de("coffre").begins_with("A :"), "bulles d'aide : « Maintiens LT », « A : ouvrir »")
	var tr := Manette.traduire([["E", "Prendre"], ["R", "Tout"], ["Échap", "Fermer"], ["1-0", "Raccourci"], ["Tab", "Onglet"]])
	_verif(tr.map(func(l: Array) -> String: return l[0]) == ["A", "Y", "B", "LB / RB"], "bandeaux : E->A, R->Y, Échap->B, Tab->LB/RB, 1-0 retiré (%s)" % [tr])

	# --- déplacement
	j.velocity = Vector3.ZERO
	await _images(10)
	var p0 := j.global_position
	_axe(JOY_AXIS_LEFT_Y, 0.12)
	await _images(20)
	_verif(Vector2(j.global_position.x - p0.x, j.global_position.z - p0.z).length() < 0.05, "stick gauche dans la zone morte : immobile")
	var avant := -j.global_transform.basis.z
	p0 = j.global_position
	_axe(JOY_AXIS_LEFT_Y, -1.0)
	await _images(40)
	_axe(JOY_AXIS_LEFT_Y, 0.0)
	var d := j.global_position - p0
	_verif(Vector2(d.x, d.z).dot(Vector2(avant.x, avant.z)) > 0.5, "stick gauche vers le haut : le joueur avance (%.2f m)" % Vector2(d.x, d.z).length())
	await _images(20)

	# --- caméra
	var lacet := j.rotation.y
	_axe(JOY_AXIS_RIGHT_X, 1.0)
	await _images(20)
	_axe(JOY_AXIS_RIGHT_X, 0.0)
	var d_lacet := wrapf(j.rotation.y - lacet, -PI, PI)
	_verif(d_lacet < -0.3, "stick droit à droite : la vue tourne à droite (%.2f rad)" % d_lacet)
	_axe(JOY_AXIS_RIGHT_X, 1.0)
	await process_frame
	var r1 := Manette.rotation_regard(0.1)
	Manette._reglages_test["sensibilite"] = 2.0
	var r2 := Manette.rotation_regard(0.1)
	_axe(JOY_AXIS_RIGHT_X, 0.0)
	_verif(r1.x < 0.0 and is_equal_approx(r2.x, r1.x * 2.0), "sensibilité 200 %% : rotation doublée (%.3f -> %.3f rad en 0,1 s)" % [r1.x, r2.x])
	Manette._reglages_test.erase("sensibilite")
	j.tete.rotation.x = 0.0
	_axe(JOY_AXIS_RIGHT_Y, -1.0)
	await _images(10)
	_axe(JOY_AXIS_RIGHT_Y, 0.0)
	var haut: float = j.tete.rotation.x
	Manette._reglages_test["inverser_y"] = true
	j.tete.rotation.x = 0.0
	_axe(JOY_AXIS_RIGHT_Y, -1.0)
	await _images(10)
	_axe(JOY_AXIS_RIGHT_Y, 0.0)
	_verif(haut > 0.05 and j.tete.rotation.x < -0.05, "stick droit vers le haut : regarde en haut (%.2f) ; inversé : en bas (%.2f)" % [haut, j.tete.rotation.x])
	Manette._reglages_test.erase("inverser_y")
	j.tete.rotation.x = 0.0

	# --- saut, esquive
	await _images(30)
	var esq: int = j.esquives
	await _clic(JOY_BUTTON_B)
	await _images(30)
	_verif(j.esquives == esq + 1, "B : esquive")
	await _images(40)
	var sol := j.is_on_floor()
	_bouton(JOY_BUTTON_Y)
	await physics_frame
	await physics_frame
	_verif(sol and j.velocity.y > 1.0, "Y : saut (vitesse verticale %.1f)" % j.velocity.y)
	_bouton(JOY_BUTTON_Y, false)
	await _images(60)

	# --- épée : RT court = léger, RT tenu = puissant, LT = garde
	j.mains.magie.equiper("droite", "epee")
	await _images(30)
	var ent: EntreesCombat = j.mains.entrees
	_axe(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var debut := ent.appui_debut
	_axe(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	_axe(JOY_AXIS_TRIGGER_RIGHT, 0.8)
	await process_frame
	_verif(debut >= 0.0 and ent.appui_debut == debut, "gâchette tenue (1,0 -> 0,9 -> 0,8) : un seul appui")
	_axe(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var vu_leger := false
	for i in 30:
		await process_frame
		vu_leger = vu_leger or j.mains.combat.etat == EtatCombat.ATTAQUE_LEGERE
	_verif(vu_leger, "RT court : coup léger")
	await _images(90)
	_axe(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var vu_charge := false
	for i in 50:
		await process_frame
		vu_charge = vu_charge or j.mains.combat.etat == EtatCombat.CHARGE_LOURDE
	_axe(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var vu_lourd := false
	for i in 40:
		await process_frame
		vu_lourd = vu_lourd or j.mains.combat.etat == EtatCombat.ATTAQUE_LOURDE
	_verif(vu_charge and vu_lourd, "RT maintenu : charge puis coup puissant")
	await _images(90)
	_axe(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _images(20)
	_verif(ent.garde_tenue and j.mains.combat.etat in [EtatCombat.GARDE, EtatCombat.PARADE], "LT maintenu : garde (état %d)" % j.mains.combat.etat)
	_axe(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _images(20)
	_verif(not ent.garde_tenue, "LT relâché : garde baissée")

	# --- menu du personnage
	var ui: MenuPersonnage = m.inventaire_ui
	await _clic(JOY_BUTTON_BACK)
	_verif(ui.ouvert and paused, "Vue : menu du personnage ouvert, jeu en pause")
	var o0 := ui.onglet_actif
	await _clic(JOY_BUTTON_RIGHT_SHOULDER)
	_verif(ui.onglet_actif != o0, "RB : onglet suivant (%s -> %s)" % [o0, ui.onglet_actif])
	ui.changer_onglet("sac")
	await _images(3)
	var sac: OngletSac = ui.onglet_courant()
	j.inventaire.ajouter("potion_soin", 2)
	j.inventaire.ajouter("minerai_fer", 1)
	sac.ouvrir()
	await _images(2)
	var s0 := sac._sel
	await _clic(JOY_BUTTON_DPAD_DOWN)
	var s1 := sac._sel
	_axe(JOY_AXIS_LEFT_Y, 1.0)
	await process_frame
	_axe(JOY_AXIS_LEFT_Y, 0.95)
	await process_frame
	_axe(JOY_AXIS_LEFT_Y, 0.0)
	await _images(2)
	_verif(s1 == s0 + 1 and sac._sel == s1 + 1, "Sac : croix bas puis UNE poussée du stick = deux lignes (%d -> %d -> %d)" % [s0, s1, sac._sel])
	await _capture("menu_sac_manette.png")
	var esq_menu: int = j.esquives
	await _clic(JOY_BUTTON_B)
	await _images(10)
	_verif(not ui.ouvert and not paused, "B : menu fermé")
	_verif(j.esquives == esq_menu, "le B qui ferme le menu ne fait pas esquiver à la reprise")
	await _clic(JOY_BUTTON_RIGHT_SHOULDER)
	_verif(ui.ouvert and ui.onglet_actif == "carte", "RB en jeu : carte")
	await _clic(JOY_BUTTON_B)
	await _images(5)

	# --- dialogue
	var d_ui: Control = m.dialogue
	var brodd := _pnj("forgeron")
	_verif(brodd != null, "Brodd trouvé")
	if brodd != null:
		brodd.set_physics_process(false)
		brodd.set_process(false)
		j.global_position = brodd.global_position + Vector3(0, 0, 1.5)
		j.velocity = Vector3.ZERO
		await _images(5)
		if d_ui._plus_proche() == null:
			d_ui.inviter(brodd)
		await _images(3)
		var invite: String = d_ui._invite_texte.text
		_verif(invite.begins_with("[A]"), "invite à la manette : « %s »" % invite)
		await _clic(JOY_BUTTON_A)
		_verif(d_ui._ouvert and j.en_dialogue, "A : dialogue ouvert")
		var tours := 0
		while d_ui._ouvert and not d_ui._choix_vis and tours < 40:
			await _clic(JOY_BUTTON_A)
			await _images(3)
			tours += 1
		_verif(d_ui._choix_vis, "A : répliques suivantes jusqu'au choix (%d appuis)" % tours)
		await _clic(JOY_BUTTON_DPAD_DOWN)
		_verif(d_ui._choix == 1, "croix bas : choix suivant")
		var esq_d: int = j.esquives
		await _clic(JOY_BUTTON_B)
		await _images(10)
		_verif(not d_ui._ouvert and not j.en_dialogue, "B : dialogue fermé")
		_verif(j.esquives == esq_d, "le B qui ferme le dialogue ne fait pas esquiver")

	# --- remappage manette (mode outil : rien n'est écrit)
	var autre := Manette.lier("saut", JOY_BUTTON_X)
	_verif(autre == "torche" and Manette.libelle("saut") == "X" and Manette.libelle("torche") == "Y", "remappage : X au saut, la torche récupère Y (échange)")
	var ex := InputEventJoypadButton.new()
	ex.button_index = JOY_BUTTON_X
	ex.pressed = true
	_verif(ex.is_action("saut") and not ex.is_action("torche"), "InputMap suit le remappage")
	_verif(Manette.lier("saut", JOY_BUTTON_START) == "" and Manette.libelle("saut") == "X", "Start est réservé : refusé")
	_verif(not Manette.attribuable(Manette.AXE + 2 * JOY_AXIS_LEFT_X), "les sticks ne s'attribuent pas")
	Manette.lier("attendre", Manette.LT)
	_verif(Manette.libelle("attendre") == "LT" and Manette.libelle("main_gauche") == "—", "LT à « Attendre » : la main gauche (sans ancien bouton) n'en a plus")
	Manette.retablir()
	_verif(Manette.libelle("saut") == "Y" and Manette.libelle("main_gauche") == "LT", "rétablir : boutons d'origine")

	# --- Options > Touches : colonne Manette
	var calque := CanvasLayer.new()
	calque.layer = 50
	root.add_child(calque)
	var options := PanelContainer.new()
	options.set_script(load("res://scripts/menu_options.gd"))
	calque.add_child(options)
	await _images(2)
	options.ouvrir()
	options._basculer_touches()
	await _images(3)
	var bm: Button = options._boutons_manette.get("interagir")
	_verif(bm != null and bm.text == "A" and options._boutons_manette.has("main_droite"), "Options > Touches : colonne Manette (interagir = %s)" % (bm.text if bm != null else "?"))
	options._attendre("interagir", 2)
	_bouton(JOY_BUTTON_LEFT_SHOULDER)
	await _images(2)
	_bouton(JOY_BUTTON_LEFT_SHOULDER, false)
	await _images(2)
	_verif(Manette.libelle("interagir") == "LB" and Manette.libelle("course") == "A" and options._message_touches.text.contains("Courir"), "Options : LB saisi à la manette, échange annoncé (%s)" % options._message_touches.text)
	Manette.retablir()
	options._maj_touches()
	options.set_anchors_preset(Control.PRESET_CENTER)
	(options._boutons_manette["esquive"] as Button).grab_focus()
	await _capture("options_touches_manette.png")
	options.queue_free()
	calque.queue_free()

	# --- bulle d'aide en noms de boutons (capture)
	if _captures != "" and m.get("aides") != null:
		var ai: Aides = m.aides
		ai.actif = true
		ai.vues.erase("ennemi")
		ai.proposer("ennemi")
		await _images(10)
		await _capture("aide_bulle_manette.png")
		m.hud.aide_forcee = true
		await _capture("aide_touches_manette.png")
		m.hud.aide_forcee = false

	# --- retour au clavier
	await _touche(KEY_F13)
	_verif(not Manette.actif() and not (m.hud.aide_lignes as Array).any(func(l: Array) -> bool: return l[0] == "RT"), "touche du clavier : aides de nouveau au clavier")
	print("ECHECS : %d" % _echecs)
	print("TEST MANETTE : ", "OK" if _echecs == 0 else "ÉCHEC (%d)" % _echecs)
	quit(1 if _echecs > 0 else 0)
