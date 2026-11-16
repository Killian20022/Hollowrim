extends SceneTree
## Test headless lot 6 : sélecteur de transport, repli propre sans plugin EOS, codes de salon, réglages EOS.
##   godot --headless --path . --script res://outils/test_transport_choix.gd
## Imprime « TEST_TRANSPORT OK » ou « TEST_TRANSPORT ECHEC (n) ».

var _echecs := 0

func _v(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	# --- sélection par arguments / réglages
	var cfg := "user://test_reseau_tmp.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	_v(ReseauTransportChoix.nom_demande(PackedStringArray([]), cfg) == "enet", "défaut = enet")
	_v(ReseauTransportChoix.nom_demande(PackedStringArray(["--transport=EOS"]), cfg) == "eos", "--transport=EOS -> eos")
	_v(ReseauTransportChoix.nom_demande(PackedStringArray(["--x", "--transport=enet"]), cfg) == "enet", "--transport=enet -> enet")
	var c := ConfigFile.new()
	c.set_value("reseau", "transport", "eos")
	c.save(cfg)
	_v(ReseauTransportChoix.nom_demande(PackedStringArray([]), cfg) == "eos", "réglage fichier -> eos")
	_v(ReseauTransportChoix.nom_demande(PackedStringArray(["--transport=enet"]), cfg) == "enet", "la ligne de commande l'emporte sur le fichier")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))

	# --- résolution et repli
	var r := ReseauTransportChoix.resoudre("enet")
	_v(r.transport is ReseauTransportENet and not r.repli and r.message == "", "resoudre(enet) = ENet sans message")
	r = ReseauTransportChoix.resoudre("")
	_v(r.transport is ReseauTransportENet, "resoudre('') = ENet")
	r = ReseauTransportChoix.resoudre("truc")
	_v(r.transport is ReseauTransportENet and r.repli and "inconnu" in r.message, "nom inconnu : repli ENet + message")
	var plugin := ReseauTransportEOS.plugin_present()
	print("INFO   plugin EOSG présent : ", plugin)
	r = ReseauTransportChoix.resoudre("eos")
	if plugin:
		print("INFO   plugin présent : le repli dépend de user://eos.cfg ; repli=", r.repli, " ", r.message)
	else:
		_v(r.transport is ReseauTransportENet and r.repli, "EOS sans plugin : repli sur ENet")
		_v("EOSG" in r.message and "ENet" in r.message, "message clair : " + str(r.message))

	# --- transport EOS isolé sans plugin
	var t := ReseauTransportEOS.new()
	_v(t.nom() == "EOS" and t.salon_supporte(), "EOS : nom et salon_supporte")
	if not plugin:
		_v(not t.disponible() and t.message != "", "EOS.disponible() = false avec message")
		_v(t.creer_hote(25051) == null and t.erreur == ERR_UNAVAILABLE, "EOS.creer_hote sans plugin = null / ERR_UNAVAILABLE")
		_v(t.creer_client("", 25051) == null, "EOS.creer_client sans hôte = null")
		_v(t.creer_client("abc", 25051) == null and t.erreur == ERR_UNAVAILABLE, "EOS.creer_client sans plugin = null")
		var code: String = await t.ouvrir_salon_async()
		_v(code == "" and t.message != "", "EOS.ouvrir_salon_async sans plugin = '' + message")
		var ok: bool = await t.rejoindre_salon_async("ABC234")
		_v(not ok and t.message != "", "EOS.rejoindre_salon_async sans plugin = false + message")
	var ok2: bool = await t.rejoindre_salon_async("ZZ")
	_v(not ok2 and t.erreur == ERR_INVALID_PARAMETER, "code invalide refusé")

	# --- réglages EOS
	var tmp := "user://test_eos_tmp.cfg"
	var g := ProjectSettings.globalize_path(tmp)
	DirAccess.remove_absolute(g)
	var l := ReseauTransportEOS.lire_cfg(tmp)
	_v(not l.fichier and l.manquants.size() == ReseauTransportEOS.CLES_OBLIGATOIRES.size(), "pas de fichier : tout manque")
	var e := ConfigFile.new()
	for k in ["product_name", "product_version", "product_id", "sandbox_id", "deployment_id", "client_id"]:
		e.set_value("eos", k, "x")
	e.save(tmp)
	l = ReseauTransportEOS.lire_cfg(tmp)
	_v(l.fichier and l.manquants == ["client_secret"], "client_secret manquant détecté : " + str(l.manquants))
	e.set_value("eos", "client_secret", "y")
	e.save(tmp)
	l = ReseauTransportEOS.lire_cfg(tmp)
	_v(l.manquants.is_empty(), "réglages complets")
	t.chemin_cfg = tmp
	if not plugin:
		_v(not t.disponible() and "EOSG" in t.message, "complet mais plugin absent : indisponible, message plugin")
	DirAccess.remove_absolute(g)

	# --- codes de salon
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var distincts := {}
	var tous_ok := true
	for i in 300:
		var s := ReseauSalonCode.generer(rng)
		distincts[s] = true
		if s.length() != 6 or ReseauSalonCode.normaliser(s) != s:
			tous_ok = false
	_v(tous_ok, "300 codes générés : 6 caractères, valides, idempotents")
	_v(distincts.size() > 290, "codes variés (%d distincts / 300)" % distincts.size())
	_v(ReseauSalonCode.normaliser(" ab c-d 23 ") == "ABCD23", "normalisation : espaces, tirets, casse")
	_v(ReseauSalonCode.normaliser("ABCD2") == "" and ReseauSalonCode.normaliser("ABCD2O") == "" and ReseauSalonCode.normaliser("ABCD21") == "", "longueur / 0-O-1-I-L refusés")

	# --- transport par défaut dans l'autoload + ENet inchangé + échange de transport sans toucher au reste
	var res: Node = root.get_node_or_null("Reseau")
	_v(res != null and res.transport is ReseauTransportENet, "autoload Reseau : transport par défaut = ENet")
	if res != null:
		var ancien = res.transport
		res.transport = ReseauTransportENet.new()
		var he: int = res.heberger(25051)
		_v(he == OK and res.est_en_ligne() and res.est_hote(), "ENet : heberger(25051) fonctionne après remplacement du transport")
		res.deconnecter()
		_v(not res.est_en_ligne() and res.joueurs() == [1], "retour solo propre")
		res.transport = ancien
	var enet := ReseauTransportENet.new()
	_v(enet.disponible() and not enet.salon_supporte(), "ENet : disponible, pas de salon")
	var cs: String = await enet.ouvrir_salon_async()
	_v(cs == "" and enet.message != "", "ENet : ouvrir_salon_async = '' + message")

	print("TEST_TRANSPORT OK" if _echecs == 0 else "TEST_TRANSPORT ECHEC (%d)" % _echecs)
	quit(0 if _echecs == 0 else 1)
