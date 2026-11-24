extends SceneTree
## LOT 5b : le panneau Multijoueur (scripts/reseau/ecran_multi.gd) piloté par script, sans fenêtre :
##   godot --headless --path . --script res://outils/test_ecran_multi.gd -- --port=25034
## Navigation clavier (Haut/Bas en boucle, Entrée, Échap), manette (croix, A, B), adresse / port / nom invalides, hébergement
## (salon, liste des joueurs, 4 au plus), connexion ratée (message lisible), lancement. Temps réel : PAS de --fixed-fps.
## Imprime « RESULTAT : OK » / « RESULTAT : ECHEC ».

var _echecs := 0
var _port := 25034
var _panneau: EcranMulti
var _fermes := 0
var _lancements: Array = []
var _R: Node

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			_port = int(a.substr(7))
	_lancer.call_deferred()

func _v(cond: bool, msg: String) -> void:
	print(("ok      " if cond else "ECHEC   ") + msg)
	if not cond:
		_echecs += 1

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _touche(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _images(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _images(2)

func _pad(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	await _images(2)
	var r := InputEventJoypadButton.new()
	r.button_index = b
	r.pressed = false
	Input.parse_input_event(r)
	await _images(2)

func _focus() -> String:
	var f := root.gui_get_focus_owner()
	return String(f.name) if f != null else "(rien)"

func _attendre(cond: Callable, delai := 20.0) -> bool:
	var t := 0.0
	while not cond.call() and t < delai:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()

func _lancer() -> void:
	_R = root.get_node("Reseau")
	var fond := Control.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.theme = MenuStyle.theme_titre()
	root.add_child(fond)
	_panneau = EcranMulti.new()
	_panneau.persistance = false
	_panneau.ferme.connect(func() -> void: _fermes += 1)
	_panneau.lancer_partie.connect(func(role: String, nouveau: bool, emplacement: int) -> void: _lancements.append([role, nouveau, emplacement]))
	fond.add_child(_panneau)
	await _images(3)
	await _scenario()
	_R.deconnecter()
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : OK" if _echecs == 0 else "RESULTAT : ECHEC")
	quit(0 if _echecs == 0 else 1)

func _scenario() -> void:
	# --- choix : clavier
	_panneau.visible = true
	_panneau.ouvrir()
	await _images(3)
	_v(_panneau.vue == "choix" and _focus() == "BoutonHeberger", "ouverture : choix Héberger / Rejoindre, focus sur Héberger (%s)" % _focus())
	await _touche("ui_down")
	_v(_focus() == "BoutonRejoindre", "Bas -> Rejoindre")
	await _touche("ui_down")
	_v(_focus() == "BoutonHebergerInternet", "Bas -> Héberger par Internet")
	await _touche("ui_down")
	_v(_focus() == "BoutonRejoindreCode", "Bas -> Rejoindre avec un code")
	await _touche("ui_down")
	_v(_focus() == "BoutonRetour", "Bas -> Retour")
	await _touche("ui_down")
	_v(_focus() == "BoutonHeberger", "Bas -> retour au début (boucle)")
	await _touche("ui_up")
	_v(_focus() == "BoutonRetour", "Haut -> Retour (boucle)")
	await _touche("ui_cancel")
	_v(_fermes == 1, "Échap : le panneau se referme (retour au menu principal)")

	# --- jeu par Internet (EOS) : sans eos.cfg, message clair et on reste au choix
	# (ignoré si un VRAI eos.cfg existe dans user:// ou à côté de l'exe : ce test ne l'écrase jamais)
	if ReseauTransportEOS.chemin_cfg_defaut() == ReseauTransportEOS.CFG and not FileAccess.file_exists(ReseauTransportEOS.CFG):
		_panneau.ouvrir()
		await _images(3)
		var vue_avant := _panneau.vue
		(_panneau.find_child("BoutonHebergerInternet", true, false) as Button).pressed.emit()
		await _images(2)
		var avis := _panneau.find_child("Avis", true, false) as Label
		_v(_panneau.vue == "choix" and avis.text != "", "Héberger par Internet sans configuration : reste au choix avec un message (%s)" % avis.text)
		_v(not ReseauTransportEOS.plugin_present() or "eos.cfg" in avis.text, "le message nomme eos.cfg")
		(_panneau.find_child("BoutonRejoindreCode", true, false) as Button).pressed.emit()
		await _images(2)
		_v(_panneau.vue == "choix" and avis.text != "", "Rejoindre avec un code sans configuration : message")
		_v(_R.transport is ReseauTransportENet, "le transport reste ENet")
		if ReseauTransportEOS.plugin_present():
			# cfg fictif complet : le mode « code » s'ouvre (champ code, pas de port) sans rien envoyer à Epic
			var c := ConfigFile.new()
			for k in ReseauTransportEOS.CLES_OBLIGATOIRES:
				c.set_value("eos", k, "x")
			c.save("user://eos.cfg")
			(_panneau.find_child("BoutonRejoindreCode", true, false) as Button).pressed.emit()
			await _images(2)
			_v(_panneau.vue == "rejoindre" and (_panneau.find_child("Adresse", true, false) as LineEdit).placeholder_text.contains("K7PQ4X"), "mode code : champ « code du salon »")
			(_panneau.find_child("BoutonConnecter", true, false) as Button).pressed.emit()
			await _images(2)
			_v(_panneau.vue == "rejoindre" and "Code invalide" in avis.text, "code vide refusé avec un message (%s)" % avis.text)
			_panneau.retour()
			await _images(2)
			_v(_panneau.vue == "choix" and _R.transport is ReseauTransportENet, "retour : ENet rétabli")
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://eos.cfg"))
		_panneau.vue = vue_avant

	# --- manette
	_panneau.ouvrir()
	await _images(3)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_v(_focus() == "BoutonRejoindre", "manette : croix bas -> Rejoindre (%s)" % _focus())
	await _pad(JOY_BUTTON_A)
	await _images(3)
	_v(_panneau.vue == "rejoindre" and _focus() == "Adresse", "manette : A sur Rejoindre -> formulaire, focus sur l'adresse (%s)" % _focus())
	await _pad(JOY_BUTTON_B)
	await _images(2)
	_v(_panneau.vue == "choix", "manette : B -> retour au choix")

	# --- rejoindre : saisies invalides
	_panneau._aller("choix")
	await _images(3)
	await _touche("ui_down")
	await _touche("ui_accept")
	await _images(3)
	_v(_panneau.vue == "rejoindre", "Entrée sur Rejoindre -> formulaire")
	await _touche("ui_cancel")
	_v(_panneau.vue == "choix", "Échap dans le formulaire (champ de saisie) -> choix")
	_panneau._aller("rejoindre")
	await _images(3)
	var champ_a: LineEdit = _panneau._champ_adresse
	champ_a.text = "999.1.1.1:24565"
	champ_a.grab_focus()
	await _images(2)
	await _touche("ui_down")
	_v(_focus() == "NomInvite", "Bas depuis l'adresse -> nom (%s)" % _focus())
	await _touche("ui_down")
	_v(_focus() == "BoutonConnecter", "Bas -> Se connecter (%s)" % _focus())
	await _touche("ui_accept")
	await _images(3)
	_v(_panneau.vue == "rejoindre" and not _R.est_en_ligne() and _panneau._avis.text.contains("invalide"), "adresse 999.1.1.1 : refusée sans connexion, message « %s »" % _panneau._avis.text)
	champ_a.text = ""
	_panneau._connecter()
	_v(_panneau._avis.text.contains("Saisir"), "adresse vide : « %s »" % _panneau._avis.text)
	champ_a.text = "10.0.0.1:12"
	_panneau._connecter()
	_v(_panneau._avis.text.contains("Port invalide") and not _R.est_en_ligne(), "port 12 : « %s »" % _panneau._avis.text)
	champ_a.text = "127.0.0.1:%d" % _port
	_panneau._champ_nom_r.text = "   "
	_panneau._connecter()
	_v(_panneau._avis.text.contains("nom") and not _R.est_en_ligne(), "nom vide : « %s »" % _panneau._avis.text)

	# --- connexion vers personne : échec lisible
	_panneau._champ_nom_r.text = "Astrid"
	champ_a.text = "127.0.0.1:%d" % _port
	_panneau._connecter()
	_v(_panneau.vue == "connexion" and _R.est_en_ligne(), "connexion lancée vers un port sans hôte (écran « Connexion à… »)")
	var t0 := Time.get_ticks_msec()
	_v(await _attendre(func() -> bool: return _panneau.vue == "rejoindre", 60.0), "la connexion échoue et le formulaire revient (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_v(_panneau._avis.text.contains("Impossible de joindre") and not _R.est_en_ligne(), "message lisible : « %s »" % _panneau._avis.text)
	_v(_R.nom_joueur == "Astrid", "le nom saisi est celui du joueur réseau")

	# --- héberger
	_panneau._aller("choix")
	await _images(2)
	_panneau._aller("heberger")
	await _images(3)
	_v(_focus() == "ChoixMonde", "formulaire Héberger : focus sur le choix du monde (%s)" % _focus())
	var avant := _panneau._b_monde.text
	var n_mondes: int = _panneau._emplacements.size()
	_v(n_mondes >= 1 and _panneau._emplacements.back() == EcranMulti.NOUVEAU_MONDE, "le choix propose « Nouveau monde » + %d sauvegarde(s) : « %s »" % [n_mondes - 1, avant])
	if n_mondes > 1:
		await _touche("ui_right")
		_v(_panneau._b_monde.text != avant, "Droite change de monde : « %s »" % _panneau._b_monde.text)
		await _touche("ui_left")
		_v(_panneau._b_monde.text == avant, "Gauche revient : « %s »" % _panneau._b_monde.text)
	_panneau._champ_nom_h.text = "Killian"
	_panneau._champ_port_h.text = "80"
	_panneau._ouvrir_partie()
	_v(_panneau.vue == "heberger" and _panneau._avis.text.contains("Port invalide") and not _R.est_en_ligne(), "port 80 refusé : « %s »" % _panneau._avis.text)
	_panneau._champ_port_h.text = "abc"
	_panneau._ouvrir_partie()
	_v(_panneau._avis.text.contains("pas un nombre"), "port « abc » refusé : « %s »" % _panneau._avis.text)
	_panneau._champ_nom_h.text = ""
	_panneau._ouvrir_partie()
	_v(_panneau._avis.text.contains("nom") and not _R.est_en_ligne(), "nom vide refusé : « %s »" % _panneau._avis.text)
	_panneau._champ_nom_h.text = "Killian"
	_panneau._champ_port_h.text = str(_port)
	_panneau._ouvrir_partie()
	await _images(3)
	_v(_panneau.vue == "salon" and _R.est_en_ligne() and _R.est_hote(), "hébergement : le salon s'ouvre, le port %d est ouvert" % _port)
	var liste: VBoxContainer = _panneau._liste_joueurs
	_v(liste.get_child_count() == 1 and (liste.get_child(0) as Label).text.contains("Killian") and (liste.get_child(0) as Label).text.contains("hôte") and (liste.get_child(0) as Label).text.contains("vous"), "liste des joueurs : « %s »" % (liste.get_child(0) as Label).text)
	_v(_panneau._titre_salon.text.contains("1 / 4"), "compteur : « %s »" % _panneau._titre_salon.text)
	_v(_focus() == "BoutonLancer", "salon (hôte) : focus sur « Lancer la partie » (%s)" % _focus())
	# un invité arrive (simulé dans le registre : la vraie arrivée est testée par test_sauvegarde_multi_reseau)
	_R.registre.ajouter(7, {"nom": "Astrid"})
	_R.joueur_connecte.emit(7)
	await _images(3)
	_v(liste.get_child_count() == 2 and (liste.get_child(1) as Label).text.contains("Astrid") and _panneau._titre_salon.text.contains("2 / 4"), "un invité arrive : « %s », %s" % [(liste.get_child(1) as Label).text if liste.get_child_count() > 1 else "?", _panneau._titre_salon.text])
	_R.registre.retirer(7)
	_R.joueur_deconnecte.emit(7)
	await _images(3)
	_v(liste.get_child_count() == 1, "l'invité part : la liste se met à jour")
	# lancement
	(_panneau._b_lancer as Button).pressed.emit()
	await _images(2)
	_v(_lancements.size() == 1 and _lancements[0][0] == "hote" and bool(_R.infos_partie.get("lancee", false)), "« Lancer la partie » : signal lancer_partie(hote) et partie marquée lancée %s" % str(_lancements))
	_R.deconnecter()
	# quitter le salon
	_panneau._aller("heberger")
	_panneau._champ_nom_h.text = "Killian"
	_panneau._champ_port_h.text = str(_port)
	_panneau._ouvrir_partie()
	await _images(3)
	await _touche("ui_cancel")
	_v(_panneau.vue == "heberger" and not _R.est_en_ligne(), "Échap dans le salon : on quitte, la connexion est coupée")
	# message du port déjà pris
	_v(EcranMulti.texte_erreur(ERR_CANT_CREATE, 24565).contains("24565") and EcranMulti.texte_erreur(ERR_CANT_CREATE, 24565).contains("utilisé"), "message « port déjà pris » : « %s »" % EcranMulti.texte_erreur(ERR_CANT_CREATE, 24565))
