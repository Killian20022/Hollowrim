class_name DemoCrime
extends RefCounted
## Serrures du village pour le système de crime (crime.gd, crochetage.gd) :
##   - deux COFFRES VERROUILLÉS posés sur des coffres du décor des intérieurs : celui de Gunnhild au bout est de la longue maison
##     (Adepte, 40 pièces et une coupe d'argent) et celui de Sigrún chez elle (Expert, un collier d'or) ; on les crochète (E), puis on
##     les fouille : leur contenu est VOLÉ (Crime.signaler_vol : prime si quelqu'un voit, confisqué à l'arrestation) ;
##   - `--demo-crime` (argument utilisateur : tests, films) : la porte de la maison de Sigrún est verrouillée (Apprenti) ; crochetée, elle
##     s'ouvre comme les autres. Sans l'argument, les portes restent celles des intérieurs (leurs verrous viennent d'ailleurs).
## Un coffre vidé est noté dans ButinTables.pilles (« crime_<id> », sauvegardé avec les contenants pillés) ; son verrou se referme au
## chargement d'une partie s'il n'a pas été vidé.

const COFFRES := [
	{"id": "coffre_gunnhild", "interieur": "halle", "pos": Vector3(6.42, Interieurs.F + 0.6, 1.2), "verrou": 2, "proprietaire": "chef",
		"nom": "Coffre de Gunnhild", "contenu": {"pieces": 40, "coupe_argent": 1}},
	{"id": "coffre_sigrun", "interieur": "sigrun", "pos": Vector3(3.5, Interieurs.F + 0.6, -1.9), "verrou": 3, "proprietaire": "volva",
		"nom": "Coffre de Sigrún", "contenu": {"pieces": 15, "collier_or": 1}},
]
const PORTE_DEMO := {"interieur": "sigrun", "verrou": 1, "proprietaire": "volva"}

static func poser(crime: Crime) -> void:
	var monde := crime.monde
	if monde == null or monde.get("village") == null:
		return
	var village: Node = monde.village
	for f: Dictionary in COFFRES:
		var ip: Node3D = village.interieur(String(f["interieur"])) if village.has_method("interieur") else null
		if ip == null:
			continue
		var c := coffre(crime, f)
		c.position = f["pos"]
		ip.add_child(c)
	if OS.get_cmdline_user_args().has("--demo-crime"):
		verrouiller_porte(crime, village.interieur(String(PORTE_DEMO["interieur"])), int(PORTE_DEMO["verrou"]), String(PORTE_DEMO["proprietaire"]))

## Coffre verrouillé interactif (touche E) : crocheter, puis fouiller (contenu volé à son propriétaire).
static func coffre(crime: Crime, f: Dictionary) -> Node3D:
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.name = String(f["id"])
	it.joueur = crime.joueur
	it.dialogue = crime.dialogue
	it.nom = String(f["nom"])
	it.rayon = 1.6
	var cle := "crime_" + String(f["id"])
	it.set_meta("verrou", int(f["verrou"]))
	it.set_meta("proprietaire", String(f["proprietaire"]))
	it.set_meta("contenu", (f["contenu"] as Dictionary).duplicate())
	_verbe(it)
	it.condition = func() -> bool: return not ButinTables.pilles.has(cle) and not (it.get_meta("contenu") as Dictionary).is_empty()
	it.action = func() -> Array:
		if int(it.get_meta("verrou", 0)) > 0:
			crime.demander_crochetage(it)
			return []
		return _fouiller(crime, it, f)
	crime.crochetage_fini.connect(func(c: Node3D, ok: bool) -> void:
		if c == it and ok:
			_verbe(it))
	return it

static func _verbe(it: Node3D) -> void:
	var v := int(it.get_meta("verrou", 0))
	it.verbe = ("Crocheter le coffre (%s)" % Crochetage.NOMS[clampi(v, 1, 4)]) if v > 0 else "Fouiller le coffre"

static func _fouiller(crime: Crime, it: Node3D, f: Dictionary) -> Array:
	var contenu: Dictionary = it.get_meta("contenu")
	var lignes: Array = []
	for id: String in contenu:
		var n := int(contenu[id])
		crime.joueur.inventaire.ajouter(id, n)
		lignes.append("%s ×%d" % [crime.joueur.inventaire.nom(id), n] if id != "pieces" else "%d pièces" % n)
		if id != "pieces":
			it.set_meta("id_objet", id)
			it.set_meta("nombre", n)
	it.set_meta("contenu", {})
	ButinTables.pilles["crime_" + String(f["id"])] = true      # sauvegardé avec les contenants pillés
	Sons.jouer(it, ["handleCoins", "handleCoins2"], -8.0)
	crime.signaler_vol(it, String(f["proprietaire"]), it.global_position)
	return ["Tu prends : " + ", ".join(lignes) + "."]

## Porte d'un intérieur verrouillée (niveau 1-4) : l'invite devient « Crocheter la porte » tant que le verrou tient.
static func verrouiller_porte(crime: Crime, ip: Node3D, niveau: int, proprietaire: String) -> void:
	if ip == null or ip.get("interactif") == null:
		return
	var it: Node3D = ip.interactif
	ip.set_meta("verrou", niveau)
	ip.set_meta("proprietaire", proprietaire)
	var ouvrir: Callable = it.action
	it.verbe = "Crocheter la porte (%s)" % Crochetage.NOMS[clampi(niveau, 1, 4)]
	it.action = func() -> Array:
		if int(ip.get_meta("verrou", 0)) > 0:
			crime.demander_crochetage(ip)
			return []
		return ouvrir.call()
	crime.crochetage_fini.connect(func(c: Node3D, ok: bool) -> void:
		if c == ip and ok:
			it.verbe = "Ouvrir la porte")
