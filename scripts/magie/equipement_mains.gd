class_name EquipementMains
extends RefCounted
## Équipement GÉNÉRALISÉ des deux mains : chaque emplacement contient un objet défini par des données — arme
## (DonneesArme EPEE), arme à deux mains (deux_mains), sort (DonneesSort), bouclier, torche, ou rien. Les règles de
## compatibilité viennent de data/magie/regles_mains.json (aucune combinaison codée en dur ici ni dans le contrôleur).
## Le combat à l'épée (mains.gd / Equipement) reçoit toujours une DonneesArme par main : pour une main qui tient un
## sort, c'est data/armes/main_sort.tres (pas de modèle, catégorie SORT) ; la logique du sort est dans MainSort.

signal change(main: String)

const FICHIER_REGLES := "res://data/magie/regles_mains.json"
const FICHIER_RACCOURCIS := "res://data/magie/raccourcis.json"
const DOSSIER_SORTS := "res://data/sorts/%s.tres"
const MAIN_SORT := preload("res://data/armes/main_sort.tres")
const BOUCLIER := preload("res://data/armes/bouclier.tres")

var equipement: Equipement
var inventaire: Inventaire
var regles := {}
var raccourcis: Array = []
## Contenu logique de chaque main : {"categorie": String, "id": String, "ressource": Resource}.
var mains := {"gauche": {}, "droite": {}}
## Sorts connus (ids de data/sorts/) : sauvegardés.
var sorts_connus: Array[String] = []
var _sorts := {}
var _en_pose := false

func _init(eq: Equipement = null, inv: Inventaire = null) -> void:
	equipement = eq if eq != null else Equipement.new()
	inventaire = inv
	regles = _lire(FICHIER_REGLES)
	raccourcis = _lire(FICHIER_RACCOURCIS).get("raccourcis", [])
	for f in DirAccess.get_files_at("res://data/sorts/"):
		var id := f.trim_suffix(".remap").trim_suffix(".tres")
		if f.ends_with(".tres") or f.ends_with(".tres.remap"):
			if not sorts_connus.has(id):
				sorts_connus.append(id)
	sorts_connus.sort()
	_synchroniser("gauche")
	_synchroniser("droite")
	equipement.change.connect(_sur_equipement)

static func _lire(chemin: String) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	return d if d is Dictionary else {}

func sort_par_id(id: String) -> DonneesSort:
	if not _sorts.has(id):
		var chemin := DOSSIER_SORTS % id
		_sorts[id] = load(chemin) as DonneesSort if ResourceLoader.exists(chemin) else null
	return _sorts[id]

## Catégorie (vide, arme, arme_deux_mains, sort, bouclier, torche) d'une ressource.
static func categorie_de(r: Resource) -> String:
	if r is DonneesSort:
		return "sort"
	if r is DonneesArme:
		var a := r as DonneesArme
		match a.categorie:
			DonneesArme.Categorie.EPEE:
				return "arme_deux_mains" if a.deux_mains else "arme"
			DonneesArme.Categorie.TORCHE:
				return "torche"
			DonneesArme.Categorie.BOUCLIER:
				return "bouclier"
			DonneesArme.Categorie.SORT:
				return "sort"
	return "vide"

## Objet désigné par un identifiant (raccourcis, sauvegarde) : vide, epee (selon l'inventaire), torche, bouclier, ou un sort.
func objet(id: String) -> Resource:
	match id:
		"", "vide":
			return Equipement.MAIN_VIDE
		"epee":
			return Equipement.EPEE_SKARNHOLT if inventaire != null and inventaire.a("epee_skarnholt") else Equipement.EPEE_METAL
		"torche":
			return Equipement.TORCHE
		"bouclier":
			return BOUCLIER
	var s := sort_par_id(id)
	if s != null:
		return s
	return null

func categorie(main: String) -> String:
	return String(mains[main].get("categorie", "vide"))

func sort(main: String) -> DonneesSort:
	return mains[main].get("ressource") as DonneesSort

func arme(main: String) -> DonneesArme:
	return mains[main].get("ressource") as DonneesArme

func autre(main: String) -> String:
	return "droite" if main == "gauche" else "gauche"

## "" si `r` peut aller dans `main`, sinon la raison (lisible par le joueur).
func refus(main: String, r: Resource) -> String:
	if r == null:
		return "Objet inconnu."
	var cat := categorie_de(r)
	var permis: Array = regles.get("permis", {}).get(main, [])
	if not permis.is_empty() and not permis.has(cat):
		return String(regles.get("refus", {}).get("%s:%s" % [main, cat], "Cet objet ne va pas dans cette main."))
	if r is DonneesSort:
		var s := r as DonneesSort
		if not sorts_connus.has(s.id):
			return "Sort inconnu."
		if s.type == DonneesSort.Type.ENCHANT:
			var en: Dictionary = regles.get("enchantement", {})
			if not (en.get("autre_main", ["arme"]) as Array).has(categorie(autre(main))):
				return String(en.get("raison", "Il faut une arme dans l'autre main."))
	return ""

## Équipe `r` (ressource) ou un identifiant dans `main`. Renvoie "" ou la raison du refus. Une arme à deux mains libère
## la main gauche ; équiper la main gauche quand la droite porte une arme à deux mains range celle-ci.
func equiper(main: String, quoi: Variant) -> String:
	var r: Resource = quoi if quoi is Resource else objet(String(quoi))
	var raison := refus(main, r)
	if raison != "":
		return raison
	var cat := categorie_de(r)
	var deux: Array = regles.get("occupe_deux_mains", ["arme_deux_mains"])
	if main == "gauche" and cat != "vide" and deux.has(categorie("droite")):
		_poser("droite", Equipement.MAIN_VIDE)
	_poser(main, r)
	if deux.has(cat) and categorie("gauche") != "vide":
		_poser("gauche", Equipement.MAIN_VIDE)
	# un enchantement dont l'arme a disparu de l'autre main n'a plus de sens : la main se vide
	for m in ["gauche", "droite"]:
		var s := sort(m)
		if s != null and s.type == DonneesSort.Type.ENCHANT and refus(m, s) != "":
			_poser(m, Equipement.MAIN_VIDE)
	return ""

func _poser(main: String, r: Resource) -> void:
	var cat := categorie_de(r)
	mains[main] = {"categorie": cat, "id": _id(r), "ressource": r}
	var rangee := equipement.gauche_rangee
	var donnees: DonneesArme = MAIN_SORT if cat == "sort" else r as DonneesArme
	_en_pose = true
	if main == "droite":
		equipement.equiper("droite", donnees)
	else:
		equipement.equiper("gauche", donnees)
		if cat == "sort":
			equipement.gauche_rangee = rangee   # T ressort toujours la torche (ou le bouclier), jamais une « main qui incante »
	_en_pose = false
	change.emit(main)

static func _id(r: Resource) -> String:
	if r is DonneesSort:
		return (r as DonneesSort).id
	if r is DonneesArme:
		var a := r as DonneesArme
		if a == Equipement.EPEE_METAL or a == Equipement.EPEE_SKARNHOLT:
			return "epee"
		return a.id
	return "vide"

## Changement venu de l'Equipement lui-même (T : torche, inventaire : épée de Skarnholt) : la logique suit.
func _sur_equipement(main: String) -> void:
	if _en_pose:
		return
	_synchroniser(main)
	change.emit(main)

func _synchroniser(main: String) -> void:
	var a: DonneesArme = equipement.main_droite if main == "droite" else equipement.main_gauche
	if a == MAIN_SORT and categorie(main) == "sort":
		return
	if a == MAIN_SORT:
		a = Equipement.MAIN_VIDE
	mains[main] = {"categorie": categorie_de(a), "id": _id(a), "ressource": a}

## Le clic droit lève-t-il la garde (au lieu d'activer la main gauche) ? Règle « garde » de regles_mains.json.
func clic_droit_garde() -> bool:
	for p: Dictionary in regles.get("garde", {}).get("paires", []):
		var g := String(p.get("gauche", "*"))
		var d := String(p.get("droite", "*"))
		if (g == "*" or g == categorie("gauche")) and (d == "*" or d == categorie("droite")):
			return true
	return false

## Arme qui pare (réduction, coût) : le bouclier s'il est porté, sinon l'arme de la main droite.
func arme_de_garde(defaut: DonneesArme) -> DonneesArme:
	if categorie("gauche") == "bouclier":
		return arme("gauche")
	return defaut

## Raccourci n (index 0..9) : équipe les deux mains ; renvoie les raisons de refus (vide = tout est passé).
func raccourci(i: int) -> Array:
	var refuses := []
	if i < 0 or i >= raccourcis.size():
		return refuses
	var r: Dictionary = raccourcis[i]
	# la droite d'abord (une arme à deux mains libère la gauche ; un enchantement à gauche exige l'arme à droite)
	for m in ["droite", "gauche"]:
		if r.has(m):
			var raison := equiper(m, String(r[m]))
			if raison != "":
				refuses.append([m, raison])
	return refuses

func index_raccourci(touche: String) -> int:
	for i in raccourcis.size():
		if String(raccourcis[i].get("touche", "")) == touche:
			return i
	return -1

## Résumé d'une main pour le HUD (contrat etat_mains_change).
func resume(main: String) -> Dictionary:
	var r: Resource = mains[main].get("ressource")
	if r is DonneesSort:
		return (r as DonneesSort).resume()
	var a := r as DonneesArme
	var cat := categorie(main)
	var genre := "arme" if cat.begins_with("arme") else cat
	return {"genre": genre, "id": String(mains[main].get("id", "vide")), "nom": a.nom if a != null else "", "deux_mains": cat == "arme_deux_mains"}

# ------------------------------------------------------------------ sauvegarde

func exporter() -> Dictionary:
	return {"gauche": String(mains["gauche"].get("id", "vide")), "droite": String(mains["droite"].get("id", "vide")), "sorts_connus": sorts_connus.duplicate()}

func importer(d: Dictionary) -> void:
	if d.is_empty():
		return
	if d.has("sorts_connus"):
		sorts_connus.clear()
		for s in d["sorts_connus"]:
			if sort_par_id(String(s)) != null:
				sorts_connus.append(String(s))
	# la droite d'abord (enchantement, deux mains), puis la gauche
	for m in ["droite", "gauche"]:
		if d.has(m) and equiper(m, String(d[m])) != "":
			equiper(m, "vide")
