extends SceneTree
## Essai RÉEL EOS à deux instances (même machine ou non). Aucun identifiant dans le code : le chemin de eos.cfg est passé en argument.
##   hôte   : godot --headless --path . --script res://outils/essai_eos_reel.gd -- --cfg=<eos.cfg> --role=hote --echange=<fichier> [--duree=40]
##   invité : godot --headless --path . --script res://outils/essai_eos_reel.gd -- --cfg=<eos.cfg> --role=invite --echange=<fichier>
## L'hôte écrit le code du salon dans le fichier d'échange ; l'invité l'attend, rejoint le salon, se connecte et échange un message.
## Ne journalise que des états (jamais le contenu de la cfg).
var _rep := {}
var _vus: Array = []
var _msg_recu := ""

func _init() -> void:
	_run.call_deferred()

## Journal optionnel (--journal=<fichier>) : la sortie standard est perdue si Godot est tué par le délai.
func _j(m: String) -> void:
	print(m)
	var f := _arg("journal")
	if f != "":
		var h := FileAccess.open(f, FileAccess.READ_WRITE if FileAccess.file_exists(f) else FileAccess.WRITE)
		h.seek_end(); h.store_line("%d %s" % [Time.get_ticks_msec(), m]); h.close()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _run() -> void:
	await process_frame
	var role := _arg("role", "hote")
	var echange := _arg("echange", "user://eos_echange.txt")
	var tag := "[%s] " % role
	var t := ReseauTransportEOS.new()
	t.chemin_cfg = _arg("cfg")
	t.nom_joueur = "Essai" + role.capitalize()
	t.device_id_jetable = (role == "invite")   # 2e instance sur la même machine : identité distincte de l'hôte
	if not t.disponible():
		_j(tag + str("indisponible : " + str(t.message))); quit(1); return
	if not await t.preparer_async():
		_j(tag + str("preparer KO : " + str(t.message))); quit(2); return
	_j(tag + "connecté EOS")
	var pair: MultiplayerPeer
	if role == "hote":
		var code: String = await t.ouvrir_salon_async()
		if code == "":
			_j(tag + str("salon KO : " + str(t.message))); quit(3); return
		_j(tag + str("salon ouvert, code=" + str(code)))
		pair = t.creer_hote(0)
		if pair == null:
			_j(tag + str("creer_hote KO : " + str(t.message))); quit(4); return
		var f := FileAccess.open(echange, FileAccess.WRITE)
		f.store_string(code); f.close()
	else:
		var code := ""
		for i in 60:
			if FileAccess.file_exists(echange):
				code = FileAccess.get_file_as_string(echange).strip_edges()
				if code != "": break
			await create_timer(1.0).timeout
		_j(tag + str("code lu=" + str(code)))
		if not await t.rejoindre_salon_async(code):
			_j(tag + str("rejoindre KO : " + str(t.message))); quit(5); return
		_j(tag + str("salon rejoint"))
		pair = t.creer_client("", 0)
		if pair == null:
			_j(tag + str("creer_client KO : " + str(t.message))); quit(6); return
	var mp := SceneMultiplayer.new()
	mp.multiplayer_peer = pair
	set_multiplayer(mp)
	mp.peer_connected.connect(func(id): _vus.append(id); _j(tag + "peer_connected " + str(id)))
	mp.peer_disconnected.connect(func(id): _j(tag + "peer_disconnected " + str(id)))
	mp.peer_packet.connect(func(id, p: PackedByteArray): _msg_recu = p.get_string_from_utf8(); _j(tag + "message reçu de " + str(id) + " : " + _msg_recu))
	var fin := Time.get_ticks_msec() + int(float(_arg("duree", "45")) * 1000.0)
	var envoye := false
	while Time.get_ticks_msec() < fin:
		await create_timer(0.25).timeout
		if not _vus.is_empty() and not envoye:
			envoye = true
			mp.send_bytes(("bonjour de " + role).to_utf8_buffer(), _vus[0])
		if envoye and _msg_recu != "":
			await create_timer(2.0).timeout
			break
	_j(tag + "RESULTAT connexion=" + str(not _vus.is_empty()) + " message=" + str(_msg_recu != ""))
	_j("arrêt...")
	if ReseauTransportEOS.sortie_propre():   # comme Jeu.quitter() : salon quitté (1 s max) puis processus tué
		return
	quit(0 if not _vus.is_empty() else 7)
