class_name ButinTables
extends RefCounted
## Tables de butin à GRAINE FIXE (data/butin/*.json) : un contenant (coffre, urne, tonneau, corps…) tire toujours le même
## contenu pour une même graine du monde et un même identifiant stable → sauvegarde / rechargement identiques. Documentation
## et contrat pour les lots suivants (coffre animé, fenêtre de butin, cassables, marchands) : docs/BUTIN.md.
##   ButinTables.tirer(table, graine, zone) -> Array[Dictionary]  [{id, n, rarete}] (les pièces : id « pieces »)
##   ButinTables.tirer_pour(id_contenant, table, zone)             idem, graine = graine(id_contenant)
##   ButinTables.contenu(liste) -> Dictionary                      {id: n} (format de scripts/butin.gd)
##   ButinTables.resoudre(butin, id_contenant) -> Dictionary       butin fixe + tirage de sa clé « table » (DonjonKit)
##   ButinTables.table_pour(type, zone) -> String                  table d'un type de contenant dans une zone (zones.json)
##   ButinTables.piller / est_pille / exporter / importer          contenants vidés, sauvegardés avec la partie (monde.gd)
## Aucune dépendance au hasard global (randi) : seul un RandomNumberGenerator semé ici est utilisé, dans un ordre fixe.

const DOSSIER := "res://data/butin/"
const RARETES := ["commun", "peu_commun", "rare", "unique"]
const NOMS_RARETE := {"commun": "commun", "peu_commun": "peu commun", "rare": "rare", "unique": "unique"}
## Couleurs de rareté (fenêtre de butin L3, marchands L8) : gris acier, vert, bleu glace, or (palette des icônes).
const COULEURS_RARETE := {"commun": "#c8d0dc", "peu_commun": "#7fc87a", "rare": "#7fc0f0", "unique": "#e8a64a"}
const GRAINE_MONDE_DEFAUT := 20261028
const PROFONDEUR_MAX := 4

## Graine du monde (sauvegardée) : changer de graine = autres contenus pour tous les contenants non encore ouverts.
static var graine_monde := GRAINE_MONDE_DEFAUT
## Contenants vidés : id → true (sauvegardé). Les coffres de la crypte et de la grotte gardent en plus leur marque quetes.vus.
static var pilles := {}
## Objets uniques déjà pris (prendre()) : un second exemplaire est changé en pièces (valeur).
static var uniques_pris := {}
## Lot L3 : objets laissés dans un contenant OUVERT (fenêtre de butin fermée avant de tout prendre) : {id_contenant: {id: n}} ;
## sauvegardé (clé « restes ») ; les pièces n'y sont jamais (versées à l'ouverture).
static var restes := {}
## Corps fouillables encore chargés (butin des ennemis tués, scripts/butin.gd) : {cle: {"pos": [x, y, z], "nom": String}} ; leurs objets
## sont dans `restes[cle]` (même clé). Sauvegardé (clé « corps ») : une partie rechargée repose le corps (Butin.restaurer).
static var corps := {}
static var _tables := {}
static var _zones := {}
static var _charge := false

# ------------------------------------------------------------------ données

## Lecture paresseuse (aussi depuis le fil de construction de la crypte) : tout est lu dans des variables locales puis publié
## d'un coup, et _charge n'est vrai qu'après : un autre fil ne voit jamais une table à moitié remplie (au pire, il relit).
static func _charger() -> void:
	if _charge:
		return
	var tabs := {}
	var zs := {}
	for f in DirAccess.get_files_at(DOSSIER):
		if not f.ends_with(".json") or f == "objets.json":
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + f))
		if not (d is Dictionary):
			push_warning("Butin : %s illisible" % f)
			continue
		if f == "zones.json":
			zs = d.get("zones", {})
			continue
		var t: Dictionary = d.get("tables", {})
		for k in t:
			if tabs.has(k):
				push_warning("Butin : table %s définie deux fois (%s)" % [k, f])
			tabs[k] = t[k]
	_tables = tabs
	_zones = zs
	_charge = true

## Relit les fichiers (tests, outils).
static func recharger() -> void:
	_charge = false
	_tables = {}
	_zones = {}
	_charger()

static func tables() -> Dictionary:
	_charger()
	return _tables

static func existe(table: String) -> bool:
	_charger()
	return _tables.has(table)

static func zone(nom: String) -> Dictionary:
	_charger()
	return _zones.get(nom, _zones.get("defaut", {}))

## Table d'un type de contenant (coffre, coffre_riche, coffre_boss, urne, tonneau, caisse, sac, draugr, bandit, mage, troll)
## dans une zone (crypte, crypte_basse, grotte, village…) ; repli sur la zone « defaut » ; "" si aucune.
static func table_pour(type: String, nom_zone := "") -> String:
	var z: Dictionary = zone(nom_zone).get("tables", {})
	if z.has(type):
		return String(z[type])
	return String(zone("defaut").get("tables", {}).get(type, ""))

# ------------------------------------------------------------------ graine

## Hachage FNV-1a 32 bits (stable d'une version de Godot à l'autre, contrairement à String.hash qui n'est pas contractuel).
static func hacher(texte: String) -> int:
	var h := 2166136261
	for o in texte.to_utf8_buffer():
		h = ((h ^ o) * 16777619) & 0xFFFFFFFF
	return h

## Graine d'un contenant : graine du monde + identifiant STABLE (ex. « crypte:cof_ossuaire », « draugr:cr_g4_1 »).
static func graine(id_contenant: String) -> int:
	return hacher("%d:%s" % [graine_monde, id_contenant])

# ------------------------------------------------------------------ tirage

## Tire une table. Résultat : [{id, n, rarete}] — les pièces d'abord (id « pieces »), puis les objets dans l'ordre du tirage,
## un même id regroupé. Même (table, graine, zone) = même résultat. Table inconnue : [] et avertissement.
static func tirer(table: String, graine_tirage: int, nom_zone := "") -> Array[Dictionary]:
	_charger()
	var acc := {}
	var ordre: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = graine_tirage
	_tirer_dans(table, rng, zone(nom_zone), acc, ordre, 0)
	var res: Array[Dictionary] = []
	if acc.has("pieces") and int(acc["pieces"]["n"]) > 0:
		res.append(acc["pieces"])
	for id in ordre:
		if id != "pieces":
			res.append(acc[id])
	return res

static func tirer_pour(id_contenant: String, table: String, nom_zone := "") -> Array[Dictionary]:
	return tirer(table, graine(id_contenant), nom_zone)

static func _tirer_dans(table: String, rng: RandomNumberGenerator, z: Dictionary, acc: Dictionary, ordre: Array[String], prof: int) -> void:
	if prof > PROFONDEUR_MAX:
		push_warning("Butin : sous-tables trop profondes (%s)" % table)
		return
	if not _tables.has(table):
		push_warning("Butin : table inconnue « %s »" % table)
		return
	var t: Dictionary = _tables[table]
	if t.has("or"):
		var n := roundi(_nombre(rng, t["or"]) * float(z.get("or", 1.0)))
		if n > 0:
			_ajouter(acc, ordre, "pieces", n, "commun")
	for g: Dictionary in t.get("garanti", []):
		_ajouter(acc, ordre, String(g["id"]), _nombre(rng, g.get("n", 1)), _rarete(g))
	var entrees: Array = t.get("entrees", [])
	var poids: Array[float] = []
	var total := float(t.get("rien", 0.0))
	var bonus: Dictionary = z.get("rarete", {})
	for e: Dictionary in entrees:
		var p := maxf(0.0, float(e.get("poids", 1.0))) * float(bonus.get(_rarete(e), 1.0))
		poids.append(p)
		total += p
	var nb := _nombre(rng, t.get("tirages", 1))
	for k in nb:
		if total <= 0.0:
			break
		var x := rng.randf() * total
		var choisi := -1
		for i in poids.size():
			if x < poids[i]:
				choisi = i
				break
			x -= poids[i]
		if choisi < 0:
			continue   # tirage « rien »
		var e: Dictionary = entrees[choisi]
		if e.has("table"):
			_tirer_dans(String(e["table"]), rng, z, acc, ordre, prof + 1)
		else:
			var id := String(e["id"])
			var r := _rarete(e)
			var n := _nombre(rng, e.get("n", 1))
			if r == "unique" and acc.has(id):
				continue   # un unique au plus une fois par tirage
			_ajouter(acc, ordre, id, n, r)

## Nombre fixe (int) ou intervalle [min, max] inclus.
static func _nombre(rng: RandomNumberGenerator, v: Variant) -> int:
	if v is Array and (v as Array).size() >= 2:
		return rng.randi_range(int(v[0]), int(v[1]))
	return int(v)

## Rareté d'une entrée : la sienne, sinon celle de l'objet (data/butin/objets.json), sinon « commun ».
static func _rarete(e: Dictionary) -> String:
	if e.has("rarete"):
		return String(e["rarete"])
	if e.has("id"):
		return rarete_de(String(e["id"]))
	return "commun"

static func rarete_de(id: String) -> String:
	if id == "pieces":
		return "commun"
	return String(Inventaire.objet(id).get("rarete", "commun"))

static func _ajouter(acc: Dictionary, ordre: Array[String], id: String, n: int, r: String) -> void:
	if n <= 0:
		return
	if acc.has(id):
		acc[id]["n"] = int(acc[id]["n"]) + n
		return
	acc[id] = {"id": id, "n": n, "rarete": r}
	ordre.append(id)

# ------------------------------------------------------------------ conversions

## Liste de tirage → {id: n} (format de scripts/butin.gd et des coffres de donjon).
static func contenu(liste: Array) -> Dictionary:
	var d := {}
	for o: Dictionary in liste:
		d[String(o["id"])] = int(d.get(String(o["id"]), 0)) + int(o["n"])
	return d

## Butin d'un coffre de donjon : objets fixes (coffres de quête : inchangés) + tirage de la clé « table » (et « zone »)
## avec la graine de `id_contenant`. Sans clé « table » : le butin est rendu tel quel (copie).
static func resoudre(butin: Dictionary, id_contenant: String) -> Dictionary:
	var d := {}
	for k in butin:
		if k != "table" and k != "zone":
			d[k] = butin[k]
	if not butin.has("table"):
		return d
	for o in tirer_pour(id_contenant, String(butin["table"]), String(butin.get("zone", ""))):
		d[o["id"]] = int(d.get(o["id"], 0)) + int(o["n"])
	return d

## Met le contenu dans le sac : un unique déjà pris devient des pièces (sa valeur). Renvoie ce qui a été réellement
## ajouté [{id, n, rarete}] (pour les avis / la fenêtre de butin).
static func prendre(inv: Inventaire, liste: Array) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for o: Dictionary in liste:
		var id := String(o["id"])
		var n := int(o["n"])
		if id != "pieces" and not Inventaire.connu(id):
			continue
		if String(o.get("rarete", rarete_de(id))) == "unique":
			if uniques_pris.has(id) or inv.a(id):
				var v := int(Inventaire.objet(id).get("valeur", 0)) * n
				if v > 0:
					inv.ajouter("pieces", v)
					res.append({"id": "pieces", "n": v, "rarete": "commun"})
				continue
			uniques_pris[id] = true
		inv.ajouter(id, n)
		res.append({"id": id, "n": n, "rarete": o.get("rarete", rarete_de(id))})
	return res

# ------------------------------------------------------------------ état (sauvegarde)

static func piller(id_contenant: String) -> void:
	pilles[id_contenant] = true

static func est_pille(id_contenant: String) -> bool:
	return pilles.has(id_contenant)

## Lot L3 : objets encore dans un contenant ouvert ({} si rien) ; le dictionnaire rendu est celui de l'état (la fenêtre de butin le vide).
static func reste(id_contenant: String) -> Dictionary:
	return restes.get(id_contenant, {})

static func a_reste(id_contenant: String) -> bool:
	return restes.has(id_contenant) and not (restes[id_contenant] as Dictionary).is_empty()

static func exporter() -> Dictionary:
	var p: Array = pilles.keys()
	p.sort()
	var u: Array = uniques_pris.keys()
	u.sort()
	var r := {}
	for id in restes:
		if not (restes[id] as Dictionary).is_empty():
			r[id] = (restes[id] as Dictionary).duplicate()
	var c := {}
	for id in corps:
		if a_reste(id):
			c[id] = (corps[id] as Dictionary).duplicate(true)
	return {"graine": graine_monde, "pilles": p, "uniques": u, "restes": r, "corps": c}

## Partie chargée. Une ancienne sauvegarde (sans « butin ») garde la graine par défaut et aucun contenant pillé.
static func importer(d: Dictionary) -> void:
	reinitialiser()
	graine_monde = int(d.get("graine", GRAINE_MONDE_DEFAUT))
	for id in d.get("pilles", []):
		pilles[String(id)] = true
	for id in d.get("uniques", []):
		uniques_pris[String(id)] = true
	var r: Variant = d.get("restes", {})
	if r is Dictionary:
		for id in r:
			var o := {}
			for k in r[id]:
				if int(r[id][k]) > 0:
					o[String(k)] = int(r[id][k])      # JSON : nombres relus en flottants
			if not o.is_empty():
				restes[String(id)] = o
	var c: Variant = d.get("corps", {})      # absent des anciennes sauvegardes : aucun corps à reposer
	if c is Dictionary:
		for id in c:
			var e: Variant = c[id]
			if e is Dictionary and (e as Dictionary).get("pos", []) is Array and ((e as Dictionary)["pos"] as Array).size() == 3 and a_reste(String(id)):
				corps[String(id)] = {"pos": ((e as Dictionary)["pos"] as Array).duplicate(), "nom": String((e as Dictionary).get("nom", "Dépouille"))}

## Nouvelle partie.
static func reinitialiser() -> void:
	graine_monde = GRAINE_MONDE_DEFAUT
	pilles = {}
	uniques_pris = {}
	restes = {}
	corps = {}

# ------------------------------------------------------------------ vérification (tests)

## Erreurs des données : objet inconnu, sous-table absente, poids négatif, rareté inconnue, zone vers une table absente.
static func verifier() -> Array[String]:
	recharger()
	var err: Array[String] = []
	for nom in _tables:
		var t: Dictionary = _tables[nom]
		for g: Dictionary in t.get("garanti", []):
			if not Inventaire.connu(String(g.get("id", ""))):
				err.append("%s : garanti inconnu %s" % [nom, g.get("id", "")])
		for e: Dictionary in t.get("entrees", []):
			if e.has("table"):
				if not _tables.has(String(e["table"])):
					err.append("%s : sous-table absente %s" % [nom, e["table"]])
			elif not Inventaire.connu(String(e.get("id", ""))):
				err.append("%s : objet inconnu %s" % [nom, e.get("id", "")])
			if float(e.get("poids", 1.0)) < 0.0:
				err.append("%s : poids négatif" % nom)
			if not RARETES.has(_rarete(e)):
				err.append("%s : rareté inconnue %s" % [nom, _rarete(e)])
	for z in _zones:
		for type in (_zones[z].get("tables", {}) as Dictionary):
			if not _tables.has(String(_zones[z]["tables"][type])):
				err.append("zone %s : table absente pour %s" % [z, type])
	return err
