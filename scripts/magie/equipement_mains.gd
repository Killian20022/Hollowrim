class_name EquipementMains
extends RefCounted
## Équipement GÉNÉRALISÉ des deux mains : chaque emplacement contient un objet défini par des données — arme
## (DonneesArme EPEE), arme à deux mains (deux_mains), sort (DonneesSort), bouclier, torche, ou rien. Les règles de
## compatibilité viennent de data/magie/regles_mains.json (aucune combinaison codée en dur ici ni dans le contrôleur).
## Le combat à l'épée (mains.gd / Equipement) reçoit toujours une DonneesArme par main : pour une main qui tient un
## sort, c'est data/armes/main_sort.tres (pas de modèle, catégorie SORT) ; la logique du sort est dans MainSort.

signal change(main: String)
## Un raccourci 1-0 a été réassigné ou vidé (écran d'inventaire).
signal raccourcis_change

const FICHIER_REGLES := "res://data/magie/regles_mains.json"
const FICHIER_RACCOURCIS := "res://data/magie/raccourcis.json"
const DOSSIER_SORTS := "res://data/sorts/%s.tres"
const DOSSIER_ARMES := "res://data/armes/%s.tres"
const FICHIER_INVENTAIRE := "res://data/magie/inventaire.json"
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
## Objets équipables ajoutés à l'exécution (id → Resource), consultés par objet() avant les fichiers : butin unique, tests.
var objets_supplementaires := {}
## Catalogue de l'écran d'inventaire (data/magie/inventaire.json) : catégories, objets équipables, ordre des écoles.
var catalogue := {}
var _en_pose := false

func _init(eq: Equipement = null, inv: Inventaire = null) -> void:
	equipement = eq if eq != null else Equipement.new()
	inventaire = inv
	regles = _lire(FICHIER_REGLES)
	raccourcis = _lire(FICHIER_RACCOURCIS).get("raccourcis", [])
	catalogue = _lire(FICHIER_INVENTAIRE)
	if catalogue.get("tout_disponible", false) or not catalogue.has("sorts_depart"):   # période de test : tous les sorts
		for f in DirAccess.get_files_at("res://data/sorts/"):
			var id := f.trim_suffix(".remap").trim_suffix(".tres")
			if f.ends_with(".tres") or f.ends_with(".tres.remap"):
				if not sorts_connus.has(id):
					sorts_connus.append(id)
	else:   # fin du « tout disponible » : sorts de départ (inventaire.json), les autres par les tomes
		for id in catalogue["sorts_depart"]:
			if sort_par_id(String(id)) != null and not sorts_connus.has(String(id)):
				sorts_connus.append(String(id))
	sorts_connus.sort()
	_synchroniser("gauche")
	_synchroniser("droite")
	equipement.change.connect(_sur_equipement)

## Connaît tous les sorts de data/sorts/ (tests, outils de capture : depuis la fin du « tout disponible », une partie neuve n'a que les sorts de départ).
func apprendre_tout() -> void:
	for f in DirAccess.get_files_at("res://data/sorts/"):
		var id := f.trim_suffix(".remap").trim_suffix(".tres")
		if (f.ends_with(".tres") or f.ends_with(".tres.remap")) and not sorts_connus.has(id):
			sorts_connus.append(id)
	sorts_connus.sort()

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
	if objets_supplementaires.has(id):
		return objets_supplementaires[id]
	var s := sort_par_id(id)
	if s != null:
		return s
	var chemin := DOSSIER_ARMES % id   # toute DonneesArme de data/armes/ par son id (butin, bouclier…)
	if id.is_valid_filename() and ResourceLoader.exists(chemin):
		return load(chemin) as DonneesArme
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
## Un raccourci de consommable ({"conso": id}) ne change pas les mains : MainSort.raccourci l'utilise (Consommables).
func raccourci(i: int) -> Array:
	var refuses := []
	if i < 0 or i >= raccourcis.size():
		return refuses
	var r: Dictionary = raccourcis[i]
	if r.has("conso"):
		return refuses
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

# ------------------------------------------------------------------ inventaire (écran I : scripts/inventaire_mains.gd)

const NOMS_ECOLES := {"feu": "Feu", "glace": "Glace", "electricite": "Électricité", "tenebres": "Ténèbres", "soin": "Soin", "protection": "Protection"}
const NOMS_TYPES := {"rapide": "rapide", "canalise": "canalisé", "charge": "chargé", "zone": "zone", "enchant": "enchantement"}
const NOMS_STATUTS := {"brulure": "brûlure", "gel": "gel (ralentit)", "choc": "choc (étourdit)", "corruption": "corruption (affaiblit)"}

## Objets équipables que le joueur possède, dans une catégorie du catalogue (armes, sorts…) : ids lus par objet().
## Rien n'est codé en dur : objets de data/magie/inventaire.json (condition `inventaire` facultative), sorts connus,
## objets_supplementaires ; triés par école pour les sorts.
func objets_possedes(categorie_id := "") -> Array[String]:
	var res: Array[String] = []
	var genres: Array = []
	for c: Dictionary in catalogue.get("categories", []):
		if String(c.get("id", "")) == categorie_id:
			genres = c.get("genres", [])
	var candidats: Array[String] = []
	var test: bool = catalogue.get("tout_disponible", false)
	for o: Dictionary in catalogue.get("objets", []):
		var cond := String(o.get("inventaire", ""))
		if cond == "" and not test:       # L9 : condition préparée pour la fin du « tout disponible » (inventaire.json, _inventaire_hors_test)
			cond = String(o.get("inventaire_hors_test", ""))
		if cond != "" and (inventaire == null or not inventaire.a(cond)):
			continue
		candidats.append(String(o.get("id", "")))
	for id in objets_supplementaires:
		if not candidats.has(String(id)):
			candidats.append(String(id))
	var ordre: Array = catalogue.get("ordre_ecoles", [])
	var sorts := sorts_connus.duplicate()
	sorts.sort_custom(func(x: String, y: String) -> bool:
		var cx := _cle_tri(x, ordre)
		var cy := _cle_tri(y, ordre)
		return cx < cy if cx != cy else x < y)
	candidats.append_array(sorts)
	for id in candidats:
		var r := objet(id)
		if r == null or res.has(id):
			continue
		if (genres.is_empty() and categorie_id != "") or (not genres.is_empty() and not genres.has(categorie_de(r))):
			continue
		res.append(id)
	return res

## Clé de tri d'un sort : école (ordre du catalogue), enchantements en fin d'école.
func _cle_tri(id: String, ordre: Array) -> int:
	var s := sort_par_id(id)
	if s == null:
		return 999
	var e := ordre.find(s.ecole)
	return (e if e >= 0 else 50) * 10 + (1 if s.type == DonneesSort.Type.ENCHANT else 0)

## Fiche lisible d'un objet (écran d'inventaire) : {id, nom, genre, ecole, deux_mains, lignes: [texte]}.
func fiche(id: String) -> Dictionary:
	var r := objet(id)
	var f := {"id": id, "nom": "?", "genre": "vide", "ecole": "", "deux_mains": false, "lignes": []}
	if r == null:
		return f
	var cat := categorie_de(r)
	f["genre"] = cat
	var l: Array = f["lignes"]
	if r is DonneesSort:
		var s := r as DonneesSort
		var t := String(DonneesSort.Type.keys()[s.type]).to_lower()
		f["nom"] = s.nom
		f["ecole"] = s.ecole
		l.append("%s, %s" % [NOMS_ECOLES.get(s.ecole, s.ecole), NOMS_TYPES.get(t, t)])
		if s.canalise():
			l.append("Coût : %d mana/s" % roundi(s.cout_par_seconde))
		else:
			l.append("Coût : %d mana" % roundi(s.cout))
		if s.type == DonneesSort.Type.ENCHANT:
			l.append("Lame : +%d par coup, %d s" % [roundi(s.degats_enchant), roundi(s.duree_enchant)])
		elif s.soin > 0.0:
			l.append("Soin : %d%s" % [roundi(s.soin), "/s" if s.canalise() else ""])
		elif s.reduction_physique > 0.0:
			l.append("Absorbe %d %% des coups de face" % roundi(s.reduction_physique * 100.0))
		elif s.degats > 0.0:
			var n := " x%d" % s.nombre if s.nombre > 1 else ""
			l.append("Dégâts : %d%s%s" % [roundi(s.degats), "/s" if s.canalise() else "", n])
		if s.statut != "":
			l.append("Effet : %s, %s s" % [NOMS_STATUTS.get(s.statut, s.statut), str(snappedf(s.duree_statut, 0.1))])
		if s.drain > 0.0:
			l.append("Rend %d %% des dégâts en vie" % roundi(s.drain * 100.0))
		if s.recharge > 0.0:
			l.append("Recharge : %s s" % str(snappedf(s.recharge, 0.1)))
		if s.se_charge():
			l.append("Maintenir pour charger (%s s)" % str(snappedf(s.temps_charge, 0.1)))
		if not s.double.is_empty() and s.type != DonneesSort.Type.ENCHANT:
			l.append("Dans les deux mains : double incantation")
	elif r is DonneesArme:
		var a := r as DonneesArme
		f["deux_mains"] = a.deux_mains
		match cat:
			"vide":
				f["nom"] = "Main nue"
				l.append("Rien en main.")
			"arme", "arme_deux_mains":
				f["nom"] = a.nom
				l.append("Dégâts : %s (léger) / %s (lourd)" % [str(snappedf(a.degats_leger, 0.5)), str(snappedf(a.degats_lourd, 0.5))])
				l.append("Vitesse : %s   Endurance : %d / %d" % [str(snappedf(a.vitesse, 0.05)), roundi(a.cout_leger), roundi(a.cout_lourd)])
				l.append("Garde : %d %%" % roundi(a.reduction_garde * 100.0))
				if a.element != "":
					l.append("Effet : %s" % NOMS_STATUTS.get(a.element, a.element))
				if a.deux_mains:
					l.append("Arme à deux mains : occupe les deux mains")
			"bouclier":
				f["nom"] = a.nom
				l.append("Garde : %d %% (endurance x%s)" % [roundi(a.reduction_garde * 100.0), str(snappedf(a.cout_garde, 0.05))])
				l.append("Clic droit : lever le bouclier")
			"torche":
				f["nom"] = a.nom
				l.append("Éclaire les grottes et la nuit.")
			_:
				f["nom"] = a.nom
		if a.description != "":
			l.append(a.description)
	if r is DonneesSort and (r as DonneesSort).description != "":
		l.append((r as DonneesSort).description)
	return f

## Ce que provoquerait l'équipement de `id` dans `main`, sans rien changer : {"refus": raison ou "", "effet": texte}.
## « effet » explique les conséquences permises (arme à deux mains qui libère l'autre main, enchantement retiré…).
func essai(main: String, id: String) -> Dictionary:
	var r := objet(id)
	var raison := refus(main, r)
	if raison != "":
		return {"refus": raison, "effet": ""}
	var cat := categorie_de(r)
	var deux: Array = regles.get("occupe_deux_mains", ["arme_deux_mains"])
	var effet := ""
	if deux.has(cat) and categorie(autre(main)) != "vide":
		effet = "Occupe les deux mains : la main gauche sera libérée."
	elif main == "gauche" and cat != "vide" and deux.has(categorie("droite")):
		effet = "L'arme à deux mains sera rangée."
	else:
		var s := sort(autre(main))
		if s != null and s.type == DonneesSort.Type.ENCHANT and categorie(main).begins_with("arme") and not cat.begins_with("arme"):
			effet = "L'enchantement de l'autre main sera retiré (plus d'arme)."
	return {"refus": "", "effet": effet}

## Raccourci i (0..9) = la paire de mains donnée (ids). "" ou la raison du refus. Les deux mains sont mémorisées.
func assigner_raccourci(i: int, gauche: String, droite: String) -> String:
	if i < 0 or i >= 10:
		return "Raccourci inconnu."
	if objet(gauche) == null or objet(droite) == null:
		return "Objet inconnu."
	if refus("gauche", objet(gauche)) != "" and categorie_de(objet(gauche)) != "sort":
		return refus("gauche", objet(gauche))
	if refus("droite", objet(droite)) != "" and categorie_de(objet(droite)) != "sort":
		return refus("droite", objet(droite))
	while raccourcis.size() <= i:
		raccourcis.append({"touche": str((raccourcis.size() + 1) % 10)})
	var e: Dictionary = raccourcis[i]
	e.erase("conso")
	e["gauche"] = gauche
	e["droite"] = droite
	e["nom"] = "%s | %s" % [fiche(gauche)["nom"], fiche(droite)["nom"]]
	raccourcis_change.emit()
	return ""

## Raccourci i (0..9) = un consommable du sac (potion, nourriture : catégorie « consommable » de data/butin/objets.json).
## La touche l'utilise sans changer les mains. "" ou la raison du refus.
func assigner_conso(i: int, id: String) -> String:
	if i < 0 or i >= 10:
		return "Raccourci inconnu."
	if not Consommables.est(id):
		return "Seuls les potions et la nourriture se rangent seuls dans un raccourci."
	while raccourcis.size() <= i:
		raccourcis.append({"touche": str((raccourcis.size() + 1) % 10)})
	var e: Dictionary = raccourcis[i]
	e.erase("gauche")
	e.erase("droite")
	e["conso"] = id
	e["nom"] = String(Inventaire.objet(id).get("nom", id))
	raccourcis_change.emit()
	return ""

## Consommable du raccourci i ("" si c'est une paire de mains ou une case vide).
func conso_du_raccourci(i: int) -> String:
	if i < 0 or i >= raccourcis.size():
		return ""
	return String(raccourcis[i].get("conso", ""))

## Vide le raccourci i : la touche ne change plus rien (aucune main dans l'entrée).
func vider_raccourci(i: int) -> void:
	if i < 0 or i >= raccourcis.size():
		return
	var e: Dictionary = raccourcis[i]
	e.erase("gauche")
	e.erase("droite")
	e.erase("conso")
	e["nom"] = ""
	raccourcis_change.emit()

## Raccourcis sauvegardés : entrées {touche, gauche, droite, nom} ; une main inconnue (sort retiré…) est ignorée.
func importer_raccourcis(liste: Array) -> void:
	for i in mini(liste.size(), 10):
		if not (liste[i] is Dictionary):
			continue
		var src: Dictionary = liste[i]
		var e := {"touche": String(src.get("touche", str((i + 1) % 10))), "nom": String(src.get("nom", ""))}
		for m in ["gauche", "droite"]:
			if src.has(m) and objet(String(src[m])) != null:
				e[m] = String(src[m])
		if src.has("conso") and Consommables.est(String(src["conso"])):
			e["conso"] = String(src["conso"])
		while raccourcis.size() <= i:
			raccourcis.append({"touche": str((raccourcis.size() + 1) % 10)})
		raccourcis[i] = e

# ------------------------------------------------------------------ sauvegarde

func exporter() -> Dictionary:
	return {"gauche": String(mains["gauche"].get("id", "vide")), "droite": String(mains["droite"].get("id", "vide")), "sorts_connus": sorts_connus.duplicate(),
		"raccourcis": raccourcis.duplicate(true)}

func importer(d: Dictionary) -> void:
	if d.is_empty():
		return
	if d.has("sorts_connus"):
		sorts_connus.clear()
		for s in d["sorts_connus"]:
			if sort_par_id(String(s)) != null:
				sorts_connus.append(String(s))
		if catalogue.get("tout_disponible", false):   # période de test : tous les sorts restent connus
			for f in DirAccess.get_files_at("res://data/sorts/"):
				var id := f.trim_suffix(".remap").trim_suffix(".tres")
				if (f.ends_with(".tres") or f.ends_with(".tres.remap")) and not sorts_connus.has(id):
					sorts_connus.append(id)
			sorts_connus.sort()
	if d.get("raccourcis") is Array:
		importer_raccourcis(d["raccourcis"])
	# la droite d'abord (enchantement, deux mains), puis la gauche
	for m in ["droite", "gauche"]:
		if d.has(m) and equiper(m, String(d[m])) != "":
			equiper(m, "vide")
