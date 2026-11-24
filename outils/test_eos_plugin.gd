extends SceneTree
## Test headless du plugin EOSG SANS compte Epic : chargement, API réellement utilisée par l'adaptateur, échec propre avec de faux identifiants.
## godot --headless --path . --script res://outils/test_eos_plugin.gd
var ok := 0
var ko := 0
func _v(c: bool, t: String) -> void:
	if c: ok += 1
	else:
		ko += 1
		print("ECHEC : ", t)
func _init() -> void:
	_v(ClassDB.class_exists("EOSGMultiplayerPeer"), "classe EOSGMultiplayerPeer chargée")
	_v(ClassDB.class_exists("IEOS"), "IEOS")
	for m in ["create_server", "create_client", "accept_all_connection_requests", "deny_all_connection_requests", "get_all_peers", "set_auto_accept_connection_requests"]:
		_v(ClassDB.class_has_method("EOSGMultiplayerPeer", m), "méthode du pair : " + m)
	_v(ClassDB.class_has_signal("EOSGMultiplayerPeer", "incoming_connection_request"), "signal incoming_connection_request")
	call_deferred("_suite")
func _suite() -> void:
	var racine := get_root()
	for a in ["EOSGRuntime", "HPlatform", "HAuth", "HLobbies", "HP2P"]:
		_v(racine.has_node(a), "autoload " + a)
	# transport : disponibilité sans fichier de réglages
	var t := ReseauTransportEOS.new()
	t.chemin_cfg = "user://_absent_eos.cfg"
	_v(ReseauTransportEOS.plugin_present(), "plugin_present()")
	_v(not t.disponible() and "absent" in t.message, "indisponible sans eos.cfg : " + t.message)
	# faux identifiants : l'adaptateur doit échouer proprement (message), sans planter
	var c := ConfigFile.new()
	for k in {"product_name": "Hollowrim", "product_version": "0.1", "product_id": "x", "sandbox_id": "x", "deployment_id": "x", "client_id": "x", "client_secret": "x", "nom_joueur": "Test"}:
		c.set_value("eos", k, {"product_name": "Hollowrim", "product_version": "0.1", "product_id": "x", "sandbox_id": "x", "deployment_id": "x", "client_id": "x", "client_secret": "x", "nom_joueur": "Test"}[k])
	c.save("user://_faux_eos.cfg")
	var t2 := ReseauTransportEOS.new()
	t2.chemin_cfg = "user://_faux_eos.cfg"
	_v(t2.disponible(), "disponible() avec cfg complet : " + t2.message)
	var fin := [false]
	var res := [false]
	(func() -> void:
		res[0] = await t2.preparer_async()
		fin[0] = true).call()
	var t0 := Time.get_ticks_msec()
	while not fin[0] and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	_v(fin[0], "preparer_async() rend la main (délai)")
	_v(not res[0] and t2.message != "", "faux identifiants refusés avec un message : " + t2.message)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_faux_eos.cfg"))   # notre fichier temporaire
	print("[test_eos_plugin] ", ok, " ok, ", ko, " échecs")
	print("TEST_EOS_PLUGIN ", "OK" if ko == 0 else "ECHEC")
	quit(1 if ko > 0 else 0)
