class_name SauvegardeMulti
extends RefCounted
## Sauvegarde coop (lot 5b) : une partie = un MONDE (celui de l'hôte) + un PERSONNAGE par joueur.
##
##   MONDE      heure, jour, quêtes, morts, contenants/butin, portes, marchands, faune, PNJ (Vie), sommeil…
##   PERSONNAGE inventaire, équipement, progression, magie, PV/endurance, position de retour, prime de crime et rangs,
##              coffres sûrs (Stockage), bulles d'aide et lieux vus, favoris du sac, PNJ déjà parlés
##
## Le fichier d'un emplacement (user://sauvegarde*.json, format v2 de Migration, inchangé) reste UN seul fichier = monde + personnage de
## l'hôte : une partie coop se rouvre donc en solo, et toute ancienne sauvegarde solo se charge comme avant (Migration.migrer, puis
## Monde.importer_monde + Monde.importer_personnage sur le même dictionnaire). Ici : le partage des clés (separer / fusionner),
## les fichiers PERSONNAGE d'un invité (user://personnages/<nom>.json) et la validation de ce qu'un invité apporte à l'hôte.
## Fonctions statiques sans dépendance aux autoloads (testables avec --script).

const VERSION_PERSONNAGE := 1
## Clés du dictionnaire de sauvegarde qui appartiennent au personnage ; toutes les autres sont le monde.
const CLES_PERSONNAGE := ["joueur", "progression", "equipement_corps", "inventaire", "magie", "stockage", "aides_vues", "menu",
	"lieux_vus", "test_butin_fait", "crime", "rangs", "villageois_parles"]

## Plafonds de validation d'un personnage apporté par un invité (cohérents avec le jeu, larges pour ne pas gêner un vrai joueur).
const PIECES_MAX := 1_000_000
const QUANTITE_MAX := 9999
const OBJETS_DISTINCTS_MAX := 1500
const TAILLE_MAX := 1_500_000   # octets sérialisés
const POINTS_MAX := 400
const ATTRIBUT_MAX := 200
const STAT_MAX := 2000.0
const DISTANCE_MAX := 20000.0   # position de retour : jamais plus loin (carte 1 km² prévue : 500 m)

# ---------- monde / personnage ----------

## Sépare un dictionnaire de sauvegarde (format v2) en {"monde": …, "personnage": …}. Copies profondes.
static func separer(d: Dictionary) -> Dictionary:
	var monde := {}
	var perso := {}
	for k in d:
		if CLES_PERSONNAGE.has(String(k)):
			perso[k] = _copie(d[k])
		else:
			monde[k] = _copie(d[k])
	return {"monde": monde, "personnage": perso}

## Recolle un monde et un personnage en un dictionnaire de sauvegarde v2 (chaque clé vient de sa moitié).
static func fusionner(monde: Dictionary, perso: Dictionary) -> Dictionary:
	var r := {}
	for k in monde:
		if not CLES_PERSONNAGE.has(String(k)):
			r[k] = _copie(monde[k])
	for k in perso:
		if CLES_PERSONNAGE.has(String(k)):
			r[k] = _copie(perso[k])
	return r

## Ancienne ou nouvelle sauvegarde -> version courante (Migration) puis découpée : {"monde", "personnage"}.
static func depuis_sauvegarde(d: Dictionary) -> Dictionary:
	return separer(Migration.migrer(d))

static func _copie(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v

# ---------- fichiers PERSONNAGE ----------

## Nom de fichier sûr : minuscules, chiffres, « _ » et « - » ; 24 caractères au plus ; jamais vide.
static func nom_fichier(nom: String) -> String:
	var r := ""
	var bas := nom.strip_edges().to_lower()
	for i in bas.length():
		var c := bas[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			r += c
		elif c == " " or c == ".":
			r += "_"
		else:   # lettres accentuées : sans accent quand c'est simple, sinon abandonnées
			var sans := _sans_accent(c)
			if sans != "":
				r += sans
	r = r.left(24)
	return r if r != "" else "joueur"

static func _sans_accent(c: String) -> String:
	const TABLE := {"é": "e", "è": "e", "ê": "e", "ë": "e", "à": "a", "â": "a", "ä": "a", "î": "i", "ï": "i", "ô": "o", "ö": "o",
		"ù": "u", "û": "u", "ü": "u", "ç": "c", "ñ": "n"}
	return String(TABLE.get(c, ""))

## Dossier des personnages : celui du jeu, ou un dossier de TEST par copie du projet (mêmes règles que Sauvegardes.fichier_base).
static func dossier() -> String:
	if Sauvegardes.fichier_base() == Sauvegardes.SAUVEGARDE_REELLE:
		return "user://personnages/"
	return "user://personnages_test_%08x/" % (hash(ProjectSettings.globalize_path("res://")) & 0xffffffff)

static func chemin_personnage(nom: String) -> String:
	return dossier() + nom_fichier(nom) + ".json"

static func personnage_existe(nom: String) -> bool:
	return not lire_personnage(nom).is_empty()

## Écrit le personnage de `nom` (écriture atomique, relue). `perso` : dictionnaire au format de sauvegarde (clés CLES_PERSONNAGE).
static func ecrire_personnage(nom: String, perso: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier()))
	var conteneur := {"format": "personnage", "version": VERSION_PERSONNAGE, "nom": nom, "date": Time.get_unix_time_from_system(),
		"personnage": separer(perso)["personnage"]}
	return Sauvegardes.ecrire(chemin_personnage(nom), JSON.stringify(conteneur, "\t"))

## Relit le personnage de `nom` : le dictionnaire de personnage, ou {} s'il n'y a pas de fichier / s'il est illisible.
static func lire_personnage(nom: String) -> Dictionary:
	var f := chemin_personnage(nom)
	if not FileAccess.file_exists(f):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(f)) != OK or not j.data is Dictionary:
		return {}
	var c: Dictionary = j.data
	if String(c.get("format", "")) != "personnage" or not c.get("personnage") is Dictionary:
		return {}
	return (c["personnage"] as Dictionary).duplicate(true)

static func effacer_personnage(nom: String) -> void:
	var f := chemin_personnage(nom)
	if FileAccess.file_exists(f):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

# ---------- validation côté hôte ----------

## Vérifie et assainit un personnage reçu d'un invité. Renvoie {"ok": bool, "personnage": Dictionary, "corrections": Array[String], "raison": String}.
## Modèle de confiance (Valheim) : le personnage vit chez l'invité, l'hôte n'écarte que l'impossible (types, plafonds, objets
## inconnus, valeurs non finies, position folle). Il ne peut PAS prouver qu'un inventaire a été gagné honnêtement.
static func valider(brut: Variant) -> Dictionary:
	var corr: Array[String] = []
	if not brut is Dictionary:
		return {"ok": false, "personnage": {}, "corrections": corr, "raison": "Personnage illisible."}
	if var_to_bytes(brut).size() > TAILLE_MAX:
		return {"ok": false, "personnage": {}, "corrections": corr, "raison": "Personnage trop volumineux."}
	var p := {}
	for k in CLES_PERSONNAGE:
		if (brut as Dictionary).has(k):
			var propre: Variant = _nettoyer((brut as Dictionary)[k], 0)
			if propre != null:
				p[k] = propre
	if p.has("inventaire"):
		p["inventaire"] = _valider_inventaire(p["inventaire"], corr)
	if p.has("progression"):
		p["progression"] = _valider_progression(p["progression"], corr)
	if p.has("joueur"):
		p["joueur"] = _valider_joueur(p["joueur"], corr)
	if p.has("magie") and p["magie"] is Dictionary:
		var m: Dictionary = p["magie"]
		if m.has("mana") and (not _fini(m["mana"]) or float(m["mana"]) < 0.0 or float(m["mana"]) > STAT_MAX):
			m["mana"] = clampf(float(m["mana"]) if _fini(m["mana"]) else 0.0, 0.0, STAT_MAX)
			corr.append("mana ramené dans les limites")
	return {"ok": true, "personnage": p, "corrections": corr, "raison": ""}

static func _fini(v: Variant) -> bool:
	return (v is float and is_finite(v)) or v is int

## Ne garde que des types simples (bool, nombre fini, texte court, tableau, dictionnaire à clés texte), profondeur et taille bornées.
static func _nettoyer(v: Variant, profondeur: int) -> Variant:
	if profondeur > 8:
		return null
	if v is bool or v is int:
		return v
	if v is float:
		return v if is_finite(v) else 0.0
	if v is String or v is StringName:
		return String(v).left(300)
	if v is Array:
		var a := []
		for e in (v as Array).slice(0, 6000):
			a.append(_nettoyer(e, profondeur + 1))
		return a
	if v is Dictionary:
		var d := {}
		var n := 0
		for k in v:
			if not (k is String or k is StringName):
				continue
			n += 1
			if n > 6000:
				break
			d[String(k).left(120)] = _nettoyer(v[k], profondeur + 1)
		return d
	return null   # objet, nœud, Callable… : jamais accepté

static func _valider_inventaire(inv: Variant, corr: Array[String]) -> Dictionary:
	var r := {"pieces": 0, "objets": {}}
	if not inv is Dictionary:
		corr.append("inventaire illisible : sac vide")
		return r
	var d: Dictionary = inv
	var pieces := int(d.get("pieces", 0)) if _fini(d.get("pieces", 0)) else 0
	if pieces < 0 or pieces > PIECES_MAX:
		corr.append("pièces ramenées dans [0 ; %d]" % PIECES_MAX)
	r["pieces"] = clampi(pieces, 0, PIECES_MAX)
	var objets: Dictionary = {}
	var src: Variant = d.get("objets", {})
	if src is Dictionary:
		var inconnus := 0
		for id in src:
			var vrai := Inventaire.alias(String(id))
			if not Inventaire.connu(vrai):
				inconnus += 1
				continue
			if objets.size() >= OBJETS_DISTINCTS_MAX:
				break
			var q := int(src[id]) if _fini(src[id]) else 0
			if q > QUANTITE_MAX:
				corr.append("quantité de %s ramenée à %d" % [vrai, QUANTITE_MAX])
			q = clampi(q, 0, QUANTITE_MAX)
			if q > 0:
				objets[vrai] = int(objets.get(vrai, 0)) + q
		if inconnus > 0:
			corr.append("%d objet(s) inconnu(s) retiré(s)" % inconnus)
	r["objets"] = objets
	if d.get("voles") is Dictionary:
		var voles := {}
		for id in d["voles"]:
			if objets.has(String(id)) and _fini(d["voles"][id]):
				voles[String(id)] = clampi(int(d["voles"][id]), 0, int(objets[String(id)]))
		if not voles.is_empty():
			r["voles"] = voles
	return r

static func _valider_progression(pr: Variant, corr: Array[String]) -> Dictionary:
	if not pr is Dictionary:
		corr.append("progression illisible : personnage neuf")
		return {}
	var d: Dictionary = (pr as Dictionary).duplicate(true)
	var niv := clampi(int(d.get("niveau", 1)) if _fini(d.get("niveau", 1)) else 1, 1, Progression.NIVEAU_MAX)
	if int(d.get("niveau", 1)) != niv:
		corr.append("niveau ramené à %d" % niv)
	d["niveau"] = niv
	d["xp_niveau"] = clampf(float(d.get("xp_niveau", 0.0)) if _fini(d.get("xp_niveau", 0.0)) else 0.0, 0.0, 1.0e9)
	for cle in ["points_perk", "points_attribut"]:
		var v := int(d.get(cle, 0)) if _fini(d.get(cle, 0)) else 0
		if v < 0 or v > POINTS_MAX:
			corr.append("%s ramenés dans [0 ; %d]" % [cle, POINTS_MAX])
		d[cle] = clampi(v, 0, POINTS_MAX)
	if d.get("attributs") is Dictionary:
		for k in d["attributs"]:
			d["attributs"][k] = clampi(int(d["attributs"][k]) if _fini(d["attributs"][k]) else 0, 0, ATTRIBUT_MAX)
	if d.get("competences") is Dictionary:
		var c: Dictionary = d["competences"]
		if c.get("niveaux") is Dictionary:
			for k in c["niveaux"]:
				c["niveaux"][k] = clampi(int(c["niveaux"][k]) if _fini(c["niveaux"][k]) else Competences.DEPART, Competences.DEPART, Competences.MAXIMUM)
		if c.get("experience") is Dictionary:
			for k in c["experience"]:
				c["experience"][k] = clampf(float(c["experience"][k]) if _fini(c["experience"][k]) else 0.0, 0.0, 1.0e9)
	return d

static func _valider_joueur(j: Variant, corr: Array[String]) -> Dictionary:
	if not j is Dictionary:
		return {}
	var d: Dictionary = (j as Dictionary).duplicate(true)
	for cle in ["vie", "vigueur"]:
		if d.has(cle):
			var v := float(d[cle]) if _fini(d[cle]) else 1.0
			if v < 0.0 or v > STAT_MAX:
				corr.append("%s ramenée dans les limites" % cle)
			d[cle] = clampf(v, 0.0, STAT_MAX)
	if d.has("lacet"):
		d["lacet"] = float(d["lacet"]) if _fini(d["lacet"]) else 0.0
	if d.has("apparence") and not (String(d["apparence"]) in JoueurBase.SEXES):   # joueur_base : homme / femme seulement
		d["apparence"] = JoueurBase.DEFAUT
		corr.append("corps inconnu : homme")
	if d.has("position"):
		var p: Variant = d["position"]
		var bon: bool = p is Array and (p as Array).size() == 3
		if bon:
			for c in p:
				if not _fini(c) or absf(float(c)) > DISTANCE_MAX:
					bon = false
		if not bon:
			d.erase("position")
			corr.append("position de retour invalide : ignorée")
	return d
