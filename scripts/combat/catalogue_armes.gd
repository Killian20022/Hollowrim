class_name CatalogueArmes
## Armes trouvables (data/armes/catalogue_armes.json) : 8 épées hybrides + 12 armes Quaternius CC0, chacune à la fois
## OBJET DU SAC (Inventaire.objet → nom, poids, valeur, rareté, catégorie « arme ») et DonneesArme ÉQUIPABLE
## (EquipementMains.objet). Les stats viennent d'une FAMILLE (base en acier) x un MATÉRIAU (multiplicateurs) x le `mult`
## propre à l'arme : changer l'équilibrage d'une famille ou d'un matériau = une ligne du JSON.
##
## Familles (FAMILLES) : une_main, epee_longue, deux_mains, dague, masse, marteau, bouclier. Le champ DonneesArme.famille
## porte la famille de chaque arme (aussi sur les .tres écrits à la main : epee_metal… = « epee_longue », bouclier = « bouclier ») ;
## une arme qui se tient à deux mains a DonneesArme.deux_mains = true (famille deux_mains, ou grand marteau).
## Branche combat/claymore_2mains : s'y brancher par `arme.deux_mains` / `arme.famille == CatalogueArmes.FAMILLE_DEUX_MAINS`
## et le profil « deux_mains » (déjà posé par la famille). Si data/armes/<id>.tres existe (claymore.tres, coeur_de_braise.tres),
## il sert de MODÈLE : modèle 3D, poses et réglages d'animation restent les siens, seules les stats de combat s'y appliquent.
##
## API :  CatalogueArmes.ids() / connu(id) / famille_de(id) / ids_famille(famille)
##        CatalogueArmes.donnees(id) -> DonneesArme (mise en cache) ; stats(id) -> Dictionary ; fiche_objet(id) -> Dictionary
##        CatalogueArmes.verifier() -> Array[String] (erreurs des données, test_armes_catalogue)

const FICHIER := "res://data/armes/catalogue_armes.json"
const DOSSIER_TRES := "res://data/armes/%s.tres"
const FAMILLES := ["une_main", "epee_longue", "deux_mains", "dague", "masse", "marteau", "bouclier"]
const FAMILLE_DEUX_MAINS := "deux_mains"
## Longueur totale attendue du modèle par famille (m, min / max) : contrôle des échelles (test).
const LONGUEURS := {"une_main": [0.6, 1.1], "epee_longue": [1.05, 1.35], "deux_mains": [1.35, 1.7], "dague": [0.4, 0.6],
	"masse": [0.7, 0.95], "marteau": [0.75, 1.45], "bouclier": [0.6, 0.9]}

static var _d := {}
static var _lu := false
static var _cache := {}

static func donnees_brutes() -> Dictionary:
	if not _lu:   # publié d'un coup puis marqué lu (lecture possible depuis le fil de construction, comme Inventaire._butin)
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_d = v if v is Dictionary else {}
		_lu = true
	return _d

static func ids() -> Array[String]:
	var r: Array[String] = []
	for id in donnees_brutes().get("armes", {}):
		r.append(String(id))
	return r

static func connu(id: String) -> bool:
	return donnees_brutes().get("armes", {}).has(id)

static func entree(id: String) -> Dictionary:
	return donnees_brutes().get("armes", {}).get(id, {})

static func famille_de(id: String) -> String:
	return String(entree(id).get("famille", ""))

static func ids_famille(famille: String) -> Array[String]:
	var r: Array[String] = []
	for id in ids():
		if famille_de(id) == famille:
			r.append(id)
	return r

static func nom_famille(famille: String) -> String:
	return String(donnees_brutes().get("familles", {}).get(famille, {}).get("nom", famille))

static func nom_materiau(materiau: String) -> String:
	return String(donnees_brutes().get("materiaux", {}).get(materiau, {}).get("nom", materiau))

## Stats calculées : famille x matériau x mult de l'arme. Clés : degats_leger, degats_lourd, vitesse, preparation,
## recuperation, allonge, portee, inertie, poids, valeur, cout_leger, cout_lourd, reduction_garde, cout_garde,
## desequilibre_leger, desequilibre_lourd, multi_cibles, bonus_charge_max, type_degats, element (Dictionary ou {}).
static func stats(id: String) -> Dictionary:
	var a := entree(id)
	if a.is_empty():
		return {}
	var f: Dictionary = donnees_brutes().get("familles", {}).get(String(a.get("famille", "")), {})
	var m: Dictionary = donnees_brutes().get("materiaux", {}).get(String(a.get("materiau", "")), {})
	var k: Dictionary = a.get("mult", {})
	var mul := func(cle: String) -> float: return float(m.get(cle, 1.0)) * float(k.get(cle, 1.0))
	var deg: Array = f.get("degats", [0.0, 0.0])
	var cout: Array = f.get("cout", [0.0, 0.0])
	var des: Array = f.get("desequilibre", [0.0, 0.0])
	var s := {
		"degats_leger": snappedf(float(deg[0]) * mul.call("degats"), 0.1),
		"degats_lourd": snappedf(float(deg[1]) * mul.call("degats"), 0.1),
		"vitesse": snappedf(float(f.get("vitesse", 1.0)) * mul.call("vitesse"), 0.01),
		"preparation": snappedf(float(f.get("preparation", 1.0)) * mul.call("preparation"), 0.01),
		"recuperation": snappedf(float(f.get("recuperation", 1.0)) * mul.call("recuperation"), 0.01),
		"allonge": snappedf(float(f.get("allonge", 0.33)) * float(k.get("allonge", 1.0)), 0.01),
		"portee": snappedf(float(f.get("portee", 2.0)) * float(k.get("portee", 1.0)), 0.01),
		"inertie": snappedf(float(f.get("inertie", 1.6)) * float(m.get("poids", 1.0)) * float(k.get("inertie", 1.0)), 0.05),
		"poids": snappedf(float(f.get("poids", 8.0)) * mul.call("poids"), 0.5),
		"valeur": int(roundf(float(f.get("valeur", 50)) * mul.call("valeur") / 5.0) * 5.0),
		"cout_leger": snappedf(float(cout[0]) * mul.call("cout"), 0.5),
		"cout_lourd": snappedf(float(cout[1]) * mul.call("cout"), 0.5),
		"reduction_garde": snappedf(clampf(float(f.get("garde", 0.85)) + float(m.get("garde", 0.0)) + float(k.get("garde", 0.0)), 0.4, 0.97), 0.01),
		"cout_garde": snappedf(float(f.get("cout_garde", 1.0)) * float(m.get("cout_garde", 1.0)), 0.05),
		"desequilibre_leger": snappedf(float(des[0]) * mul.call("desequilibre"), 0.01),
		"desequilibre_lourd": snappedf(float(des[1]) * mul.call("desequilibre"), 0.01),
		"multi_cibles": int(f.get("multi_cibles", 2)),
		"bonus_charge_max": float(f.get("bonus_charge", 1.3)),
		"type_degats": String(f.get("type", "tranchant")),
		"element": {} if String(a.get("famille", "")) == "bouclier" else (m.get("element", {}) as Dictionary),
	}
	return s

## Fiche d'objet du sac (format de Inventaire.objet) : {nom, poids, valeur, rarete, categorie "arme", icone, famille, materiau}.
static func fiche_objet(id: String) -> Dictionary:
	var a := entree(id)
	if a.is_empty():
		return {}
	var s := stats(id)
	var f: Dictionary = donnees_brutes().get("familles", {}).get(String(a.get("famille", "")), {})
	return {"nom": String(a.get("nom", id)), "poids": s["poids"], "valeur": s["valeur"], "rarete": String(a.get("rarete", "commun")),
		"categorie": "arme", "icone": String(f.get("icone", "epee")), "famille": String(a.get("famille", "")), "materiau": String(a.get("materiau", ""))}

## Une ligne pour la boutique / la fenêtre de butin : « Arme à deux mains en rubis, 20/50 dégâts ».
static func resume(id: String) -> String:
	var a := entree(id)
	if a.is_empty():
		return ""
	var s := stats(id)
	var t := "%s en %s" % [nom_famille(String(a["famille"])), nom_materiau(String(a["materiau"]))]
	if String(a["famille"]) == "bouclier":
		return "%s, garde %d %%" % [t, roundi(float(s["reduction_garde"]) * 100.0)]
	if bool(a.get("reglages", {}).get("deux_mains", false)) and String(a["famille"]) != FAMILLE_DEUX_MAINS:
		t += " (deux mains)"
	return "%s, %d/%d dégâts" % [t, roundi(float(s["degats_leger"])), roundi(float(s["degats_lourd"]))]

## DonneesArme équipable de l'arme `id` (null si inconnue), mise en cache (une seule ressource par arme : Equipement compare
## les ressources par identité).
static func donnees(id: String) -> DonneesArme:
	if _cache.has(id):
		return _cache[id]
	var a := entree(id)
	if a.is_empty():
		return null
	var f: Dictionary = donnees_brutes().get("familles", {}).get(String(a.get("famille", "")), {})
	var propre := DOSSIER_TRES % id
	var d: DonneesArme
	if id.is_valid_filename() and ResourceLoader.exists(propre):
		d = (load(propre) as DonneesArme).duplicate() as DonneesArme   # .tres de l'arme : modèle et poses gardés
	else:
		d = (load(String(f.get("modele_base", "res://data/armes/epee_metal.tres"))) as DonneesArme).duplicate() as DonneesArme
		d.modele = String(a.get("modele", ""))
		d.habillage = "epees_longues"
		d.reperes_du_modele = true
		d.milieu_poignee = 0.0 if String(a["famille"]) == "bouclier" else 0.03
		d.profil = String(f.get("profil", "epee_longue"))
		d.deux_mains = bool(f.get("deux_mains", false))
		if a.has("materiau_lame"):
			d.materiau_lame = String(a["materiau_lame"])
		for cle in (a.get("reglages", {}) as Dictionary):
			d.set(cle, a["reglages"][cle])
		# gestes propres (combat/gestes_lourds) : haches (« gestes »: "hache"), masses, marteaux, grand marteau à deux mains
		var gl := GestesLourds.profil_pour(String(a.get("famille", "")), String(a.get("gestes", "")), d.deux_mains)
		if gl != "":
			d.profil = gl
		var m: Dictionary = donnees_brutes().get("materiaux", {}).get(String(a.get("materiau", "")), {})
		if m.has("trainee"):
			d.couleur_trainee = Color(String(m["trainee"][0]))
			d.couleur_trainee_coeur = Color(String(m["trainee"][1]))
		if m.has("son_garde"):
			d.son_garde = String(m["son_garde"])
		d.hauteur_son = float(m.get("hauteur_son", 1.0))
	d.id = id
	d.nom = String(a.get("nom", id))
	d.famille = String(a.get("famille", ""))
	d.materiau = String(a.get("materiau", ""))
	if a.has("description"):
		d.description = String(a["description"])
	_appliquer_stats(d, stats(id))
	_cache[id] = d
	return d

static func _appliquer_stats(d: DonneesArme, s: Dictionary) -> void:
	d.reduction_garde = s["reduction_garde"]
	d.cout_garde = s["cout_garde"]
	d.poids = s["inertie"]
	if d.categorie == DonneesArme.Categorie.BOUCLIER:
		return   # un bouclier ne frappe pas : garde seulement (coût, part absorbée)
	d.degats_leger = s["degats_leger"]
	d.degats_lourd = s["degats_lourd"]
	d.vitesse = s["vitesse"]
	d.preparation = s["preparation"]
	d.recuperation = s["recuperation"]
	d.allonge = s["allonge"]
	d.portee = s["portee"]
	d.cout_leger = s["cout_leger"]
	d.cout_lourd = s["cout_lourd"]
	d.desequilibre_leger = s["desequilibre_leger"]
	d.desequilibre_lourd = s["desequilibre_lourd"]
	d.multi_cibles = s["multi_cibles"]
	d.bonus_charge_max = s["bonus_charge_max"]
	d.type_degats = s["type_degats"]
	var e: Dictionary = s["element"]
	d.element = String(e.get("statut", ""))
	d.element_type = String(e.get("type", ""))
	d.element_degats = float(e.get("degats", 0.0))
	d.element_duree = float(e.get("duree", 3.0))
	d.element_puissance = float(e.get("puissance", 1.0))
	d.element_lourd_seulement = bool(e.get("lourd_seulement", false))

## Erreurs des données (familles, matériaux, modèles, raretés).
static func verifier() -> Array[String]:
	var err: Array[String] = []
	var d := donnees_brutes()
	for f in FAMILLES:
		if not d.get("familles", {}).has(f):
			err.append("famille absente : %s" % f)
	for id in ids():
		var a := entree(id)
		if not FAMILLES.has(String(a.get("famille", ""))):
			err.append("%s : famille inconnue %s" % [id, a.get("famille", "")])
		if not d.get("materiaux", {}).has(String(a.get("materiau", ""))):
			err.append("%s : matériau inconnu %s" % [id, a.get("materiau", "")])
		if not ResourceLoader.exists(String(a.get("modele", ""))):
			err.append("%s : modèle absent %s" % [id, a.get("modele", "")])
		if not ButinTables.RARETES.has(String(a.get("rarete", ""))):
			err.append("%s : rareté inconnue %s" % [id, a.get("rarete", "")])
		if String(a.get("nom", "")) == "":
			err.append("%s : sans nom" % id)
	return err
