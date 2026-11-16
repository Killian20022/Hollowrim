class_name ReseauTransportChoix
extends RefCounted
## Choix du transport réseau : ligne de commande `--transport=enet|eos`, sinon user://reseau.cfg ([reseau] transport="eos"),
## sinon ENet. Si EOS est demandé mais indisponible (plugin absent, user://eos.cfg incomplet), repli sur ENet avec un message clair.

const CFG := "user://reseau.cfg"
const NOMS := ["enet", "eos"]

## Nom de transport demandé (« enet » par défaut). `args` = arguments à examiner ; `cfg` = fichier de réglages.
static func nom_demande(args: PackedStringArray, cfg: String = CFG) -> String:
	for a in args:
		if a.begins_with("--transport="):
			return a.substr(12).strip_edges().to_lower()
	if FileAccess.file_exists(cfg):
		var c := ConfigFile.new()
		if c.load(cfg) == OK:
			return str(c.get_value("reseau", "transport", "enet")).strip_edges().to_lower()
	return "enet"

## Résout un nom en transport utilisable. Renvoie {transport, nom, message, repli:bool}.
static func resoudre(nom: String) -> Dictionary:
	var n := nom.strip_edges().to_lower()
	if n == "" or n == "enet":
		return {"transport": ReseauTransportENet.new(), "nom": "enet", "message": "", "repli": false}
	if n == "eos":
		var t := ReseauTransportEOS.new()
		if t.disponible():
			return {"transport": t, "nom": "eos", "message": "", "repli": false}
		return {"transport": ReseauTransportENet.new(), "nom": "enet", "repli": true,
			"message": "Transport EOS demandé mais indisponible : " + t.message + " Repli sur ENet (IP directe)."}
	return {"transport": ReseauTransportENet.new(), "nom": "enet", "repli": true,
		"message": "Transport inconnu « %s » (valeurs : %s). Repli sur ENet." % [nom, ", ".join(NOMS)]}

## Transport à utiliser au démarrage (arguments du processus + réglages). Journalise un éventuel repli.
static func depuis_arguments() -> ReseauTransport:
	var args := PackedStringArray(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	var r := resoudre(nom_demande(args))
	if r.message != "":
		print("[Reseau] ", r.message)
	return r.transport
