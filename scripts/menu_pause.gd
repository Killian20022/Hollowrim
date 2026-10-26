extends CanvasLayer
## Menu pause (Échap, ou Start à la manette) : Reprendre / Options / Sauvegarder / Retour au titre / Quitter.
## Met l'arbre en pause (le monde se fige ; ce calque tourne toujours). Ajouté par Monde._interface (une ligne).
## « Retour au titre » sauvegarde puis relance le processus (Jeu.relancer) : recréer le monde dans le même processus
## fait planter Godot (voir F9 dans monde.gd).

const OPTIONS := preload("res://scripts/menu_options.gd")

var monde: Node   # Monde (foret_test.tscn) : joueur, hud, sauvegarder()
var ouvert := false
var _racine: Control
var _menu: PanelContainer
var _boutons: Array = []
var _options: PanelContainer
var _avis: Label

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_racine = Control.new()
	_racine.theme = MenuStyle.theme()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.visible = false
	add_child(_racine)
	var voile := ColorRect.new()
	voile.color = Color(MenuStyle.FOND, 0.55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(voile)

	_menu = PanelContainer.new()
	_menu.custom_minimum_size = Vector2(200, 0)
	_racine.add_child(_menu)
	_centrer(_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_menu.add_child(v)
	var t := MenuStyle.etiquette("Pause", MenuStyle.OR)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_boutons = [
		MenuStyle.bouton("Reprendre", fermer),
		MenuStyle.bouton("Options", _ouvrir_options),
		MenuStyle.bouton("Sauvegarder", _sauvegarder),
		MenuStyle.bouton("Retour au titre", _retour_titre),
		MenuStyle.bouton("Quitter le jeu", _quitter),
	]
	for b: Button in _boutons:
		v.add_child(b)
	_avis = MenuStyle.etiquette("", MenuStyle.RUNE)
	_avis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_avis)
	MenuStyle.chainer(_boutons)

	_options = PanelContainer.new()
	_options.set_script(OPTIONS)
	_options.visible = false
	_options.ferme.connect(_menu_principal)
	_racine.add_child(_options)
	_centrer(_options)
	if not Jeu.mode_outil():
		Jeu.appliquer_camera(_joueur())   # champ de vision choisi dans les options
	if Jeu.test_titre() in ["nouvelle", "continuer", "restaurer", "relance"]:
		_test.call_deferred(Jeu.test_titre())

## Centre un panneau déjà ajouté : il passe dans un CenterContainer plein écran (suit sa taille quand son contenu change).
func _centrer(c: Control) -> void:
	var parent := c.get_parent()
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(centre)
	parent.move_child(centre, c.get_index())
	c.reparent(centre, false)

func _joueur() -> Node:
	return monde.get("joueur") if monde != null else null

func ouvrir() -> void:
	if ouvert:
		return
	var hud: Node = monde.get("hud") if monde != null else null
	if hud != null and hud.get("panneau_ouvert"):
		hud.panneau_ouvert = false   # Échap ferme aussi l'inventaire (Tab)
	ouvert = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_racine.visible = true
	_avis.text = ""
	_options.joueur = _joueur()
	_menu_principal()

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_racine.visible = false
	_options.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _menu_principal() -> void:
	_options.visible = false
	_menu.visible = true
	_boutons[0].grab_focus.call_deferred()

func _ouvrir_options() -> void:
	_menu.visible = false
	_options.ouvrir()

func _sauvegarder() -> void:
	var j := _joueur()
	if j != null and j.get("mort"):
		_avis.text = "Impossible : vous êtes mort"
		return
	monde.sauvegarder()
	_avis.text = "Partie sauvegardée" + ("" if Jeu.avertissement_secours == "" else " (copie de secours impossible)")

## Sauvegarde automatique en quittant la partie, sauf si le joueur est mort (on garderait une partie perdue).
func _sauver_en_partant() -> void:
	var j := _joueur()
	if monde != null and not (j != null and j.get("mort")):
		monde.sauvegarder()

func _retour_titre() -> void:
	_sauver_en_partant()
	Jeu.relancer("")

func _quitter() -> void:
	_sauver_en_partant()
	Jeu.quitter()

## Échap / Start : ouvre ou ferme. Pendant un dialogue, Échap reste au dialogue (il le ferme).
func _unhandled_input(e: InputEvent) -> void:
	var bascule: bool = (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE) \
		or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_START)
	if ouvert:
		if bascule or (e.is_action_pressed("ui_cancel") and _menu.visible):
			get_viewport().set_input_as_handled()
			fermer()
		return
	if not bascule:
		return
	var j := _joueur()
	if j != null and j.get("en_dialogue"):
		return
	get_viewport().set_input_as_handled()
	ouvrir()

## Pendant la pause, les touches du jeu (Tab, E, F5…) ne doivent rien faire : seul l'interface les reçoit.
func _input(e: InputEvent) -> void:
	if not ouvert or not (e is InputEventKey):
		return
	var k := e as InputEventKey
	if k.physical_keycode in [KEY_TAB, KEY_E, KEY_F5, KEY_F9, KEY_P, KEY_T, KEY_V]:
		get_viewport().set_input_as_handled()

# --- test automatique (outils/test_menus.sh : --test-titre=nouvelle|continuer [--test-titre-sortie=<dossier>]) -------------
## nouvelle : pause → captures (pause, options) → Sauvegarder → Quitter.  continuer : vérifie que la partie chargée est celle
## du fichier (position du joueur) puis quitte sans sauvegarder.
const TEMOIN_RELANCE := "user://test_relance.tmp"

func _test(etape: String) -> void:
	var sortie := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test-titre-sortie="):
			sortie = a.substr(20)
	var attente := 6.0   # --test-titre-attente=<s> : quitter plus tard (fils de chargement en arrière-plan terminés)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test-titre-attente="):
			attente = float(a.substr(21))
	await get_tree().create_timer(attente).timeout
	var j := _joueur()
	if etape == "relance":
		# « Retour au titre » : relance du processus ; le nouveau processus (écran titre) trouve le témoin et conclut
		FileAccess.open(TEMOIN_RELANCE, FileAccess.WRITE).store_string("1")
		print("TEST MENUS : retour au titre demandé")
		_retour_titre()
		return
	print("TEST MENUS : monde chargé (%s), joueur en %s" % [etape, j.global_position])
	if etape == "nouvelle":
		ouvrir()
		await get_tree().create_timer(0.6).timeout
		await _capture(sortie, "pause.png")
		_ouvrir_options()
		await get_tree().create_timer(0.6).timeout
		await _capture(sortie, "options_pause.png")
		_options.fermer()
		var fichier: String = monde.fichier_sauvegarde()
		# état reconnaissable, vérifié par l'étape « continuer »
		j.global_position = Vector3(6.0, monde.hauteur(6.0, 12.0) + 0.1, 12.0)
		j.inventaire.pieces = 42
		_sauvegarder()
		print("TEST MENUS : sauvegarde %s (%s)" % ["écrite" if FileAccess.file_exists(fichier) else "ABSENTE — ÉCHEC", fichier])
		var copies := Jeu.copies_secours()
		print("TEST MENUS : copie de secours %s (%d dans %s)" % ["OK" if copies.size() > 0 else "ABSENTE — ÉCHEC", copies.size(), Jeu.dossier_secours()])
		await get_tree().create_timer(0.3).timeout
		_quitter()
	elif etape == "continuer" or etape == "restaurer":
		var d = JSON.parse_string(FileAccess.get_file_as_string(monde.fichier_sauvegarde()))
		var p: Array = d["joueur"]["position"]
		var ecart := Vector3(p[0], p[1], p[2]).distance_to(j.global_position)
		var ok: bool = ecart < 1.5 and Vector2(j.global_position.x, j.global_position.z).distance_to(Vector2(6, 12)) < 1.5 and j.inventaire.pieces == 42
		print("TEST MENUS : continuer %s (écart à la position sauvegardée %.2f m, pièces %d)" % ["OK" if ok else "ÉCHEC", ecart, j.inventaire.pieces])
		Jeu.quitter()

func _capture(dossier: String, nom: String) -> void:
	if dossier == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom))
	print("TEST MENUS : capture ", dossier.path_join(nom))
