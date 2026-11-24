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
	if not t.disponible():
		print(tag, "indisponible : ", t.message); quit(1); return
	if not await t.preparer_async():
		print(tag, "preparer KO : ", t.message); quit(2); return
	print(tag, "connecté EOS")
	var pair: MultiplayerPeer
	if role == "hote":
		var code: String = await t.ouvrir_salon_async()
		if code == "":
			print(tag, "salon KO : ", t.message); quit(3); return
		print(tag, "salon ouvert, code=", code)
		pair = t.creer_hote(0)
		if pair == null:
			print(tag, "creer_hote KO : ", t.message); quit(4); return
		var f := FileAccess.open(echange, FileAccess.WRITE)
		f.store_string(code); f.close()
	else:
		var code := ""
		for i in 60:
			if FileAccess.file_exists(echange):
				code = FileAccess.get_file_as_string(echange).strip_edges()
				if code != "": break
			await create_timer(1.0).timeout
		print(tag, "code lu=", code)
		if not await t.rejoindre_salon_async(code):
			print(tag, "rejoindre KO : ", t.message); quit(5); return
		print(tag, "salon rejoint")
		pair = t.creer_client("", 0)
		if pair == null:
			print(tag, "creer_client KO : ", t.message); quit(6); return
	var mp := SceneMultiplayer.new()
	mp.multiplayer_peer = pair
	set_multiplayer(mp)
	mp.peer_connected.connect(func(id): _vus.append(id); print(tag, "peer_connected ", id))
	mp.peer_disconnected.connect(func(id): print(tag, "peer_disconnected ", id))
	mp.peer_packet.connect(func(id, p: PackedByteArray): _msg_recu = p.get_string_from_utf8(); print(tag, "message reçu de ", id, " : ", _msg_recu))
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
	print(tag, "RESULTAT connexion=", not _vus.is_empty(), " message=", _msg_recu != "")
	await t.fermer_salon_async()
	quit(0 if not _vus.is_empty() else 7)
