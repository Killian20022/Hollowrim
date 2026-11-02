class_name Lieux
## Registre UNIQUE des lieux du monde extérieur et des cibles de quête (carte du menu, boussole du HUD).
## Branche rpg/carte (2026-11-02). Statique, aucune règle de jeu : on lit le monde, on ne le modifie pas.
##
## - liste()            : tous les lieux [{id, nom, type, pos: Vector2 (x, z monde), rayon, decouvrable, majeur, note}]
## - position(id, m)    : Vector3 monde du lieu (posé sur le relief si le monde est fourni ; porte réelle du tertre / de la grotte)
## - decouvert(id, hud) : true si le lieu est connu du joueur. Les lieux « decouvrables » suivent hud.lieux_vus (clé = nom,
##                        annonce « Lieu découvert » du HUD, sauvegardée par monde.gd) ; les autres (repères visibles de loin :
##                        feu de camp, lac, moulin, château) sont toujours connus.
## - cibles_quetes(q, m): [{quete, titre, objectif, pos: Vector3, lieu, suivie}] une par quête EN COURS : où mène la
##                        prochaine étape (déclencheur de l'étape suivante → lieu, via CIBLES ou le champ facultatif
##                        "carte" d'une étape de data/quetes.json). « suivie » = la quête la plus récente (celle du HUD).
## - position_joueur(m) : position « carte » du joueur (sous terre : la porte du tertre ou de la grotte où il est entré).
##
## AGRANDISSEMENT (~1 km²) : ajouter les lieux dans LIEUX (une ligne chacun) ; la carte et la boussole les reprennent
## sans autre changement. Un lieu « decouvrable » doit aussi être déclaré au HUD (hud.lieu_nomme(pos, rayon, nom)) avec le
## MÊME nom : la boussole (branche hud/barre_objets) peut appeler Lieux.declarer_au_hud(hud, monde) au lieu des lignes
## de monde._interface (fait la même chose, sans doublon).
## Une étape de quête dont le déclencheur n'est pas dans CIBLES peut porter "carte": "<id de lieu>" dans data/quetes.json.

## Types : libellé de légende (le dessin des icônes est dans OngletCarte).
const TYPES := {
	"village": "Village", "cercle": "Pierres levées", "tertre": "Tertre, crypte", "grotte": "Grotte, mine",
	"feu": "Feu de camp", "ferme": "Ferme", "moulin": "Moulin", "lac": "Lac", "chateau": "Château",
}

## [id, nom, type, x, z, rayon de découverte (m), decouvrable, majeur, note]
## Positions : constantes du monde (monde.gd VILLAGE / CERCLE / TUMULUS, GrotteAcces.SITE, VillageBati.EXTERIEURS,
## EauVillage.LAC_CENTRE, ArrierePlan.CHATEAU_AZIMUT / CHATEAU_DIST) recopiées ici ; test_onglet_carte vérifie qu'elles
## n'ont pas bougé.
const LIEUX := [
	["skarnholt", "Skarnholt", "village", 44.0, 40.0, 30.0, true, true, "Hameau de Gunnhild"],
	["cercle", "Cercle des pierres runiques", "cercle", -38.0, -34.0, 12.0, true, true, "Les morts y bougent"],
	["tertre", "Tertre de Svanhild", "tertre", -38.0, -48.0, 8.0, true, true, "Crypte de la reine-guerrière"],
	["grotte", "Grotte des bandits", "grotte", 92.0, -27.0, 10.0, true, true, "La vieille mine"],
	["feu", "Feu de camp", "feu", 0.0, 0.0, 0.0, false, false, "Point de départ"],
	["lac", "Lac gelé", "lac", -22.0, 46.0, 0.0, false, false, ""],
	["moulin", "Moulin à vent", "moulin", 95.5, 13.0, 0.0, false, false, ""],
	["fermes", "Fermes", "ferme", 76.0, 22.0, 0.0, false, false, ""],
	["chateau", "Château lointain", "chateau", 243.9, 548.1, 0.0, false, true, "À l'horizon, au sud"],
]

## Déclencheur de quête → lieu. Clé exacte d'abord, puis préfixe (« ramasse:fragment_sceau » couvre les trois éclats).
## « parle:<pnj> » vise le PNJ lui-même (groupe « villageois », donnees.id), sinon Skarnholt.
const CIBLES := {
	"lieu:tertre": "tertre", "lieu:vestibule_crypte": "tertre", "lieu:tombe_svanhild": "tertre", "lieu:salle_trone": "tertre",
	"tue:svanhild": "tertre", "tue:jarl": "tertre", "ramasse:anneau_givre": "tertre", "ramasse:amulette_eirik": "tertre",
	"ramasse:fragment_sceau": "tertre", "meca:": "tertre", "ramasse:hache_kolbeinn": "tertre", "choix:": "tertre",
	"lieu:camp_hrafn": "grotte", "lieu:ilot_sigrun": "grotte", "lieu:grotte": "grotte", "tue:hrafn": "grotte",
	"ramasse:registre_hrafn": "grotte", "ramasse:journal_sigrun": "grotte", "ramasse:broche_sigrun": "grotte",
	"objet:lame_antique": "cercle", "ramasse:lame_antique": "cercle",
	"ramasse:epee_skarnholt": "skarnholt", "parle:": "skarnholt",
}

static var _liste: Array = []

static func liste() -> Array:
	if _liste.is_empty():
		for l: Array in LIEUX:
			_liste.append({"id": l[0], "nom": l[1], "type": l[2], "pos": Vector2(l[3], l[4]), "rayon": l[5],
				"decouvrable": l[6], "majeur": l[7], "note": l[8]})
	return _liste

static func lieu(id: String) -> Dictionary:
	for l: Dictionary in liste():
		if l["id"] == id:
			return l
	return {}

## Position monde du lieu. Avec le monde : porte réelle du tertre / de la grotte, hauteur du relief.
static func position(id: String, monde: Node = null) -> Vector3:
	var l := lieu(id)
	if l.is_empty():
		return Vector3.ZERO
	var p: Vector2 = l["pos"]
	if monde != null:
		var porte := _porte(id, monde)
		if porte != Vector3.ZERO:
			return porte
		if monde.has_method("hauteur") and absf(p.x) < 400.0 and absf(p.y) < 400.0:
			return Vector3(p.x, monde.hauteur(p.x, p.y), p.y)
	return Vector3(p.x, 0.0, p.y)

static func _porte(id: String, monde: Node) -> Vector3:
	var n: Node = null
	if id == "tertre":
		n = monde.get("tertre")
	elif id == "grotte":
		n = monde.get("grotte_acces")
	if n != null and n.get("porte_dehors") is Vector3:
		return n.porte_dehors
	return Vector3.ZERO

static func decouvert(id: String, hud: Node) -> bool:
	var l := lieu(id)
	if l.is_empty():
		return false
	if not l["decouvrable"]:
		return true
	if hud == null or not (hud.get("lieux_vus") is Dictionary):
		return true   # pas de suivi de découverte (scène d'essai) : tout est connu
	return (hud.lieux_vus as Dictionary).has(l["nom"])

## Déclare les lieux « decouvrables » au HUD (annonce « Lieu découvert ») ; ignore ceux déjà déclarés sous le même nom.
static func declarer_au_hud(hud: Node, monde: Node) -> void:
	if hud == null or not hud.has_method("lieu_nomme"):
		return
	var deja := {}
	for ln: Array in hud.get("lieux_nommes"):
		deja[ln[2]] = true
	for l: Dictionary in liste():
		if l["decouvrable"] and not deja.has(l["nom"]):
			hud.lieu_nomme(position(l["id"], monde), float(l["rayon"]), l["nom"])

## Lieu visé par un déclencheur (un seul, sans « | ») ; "" si inconnu.
static func lieu_du_declencheur(evt: String) -> String:
	if CIBLES.has(evt):
		return CIBLES[evt]
	if evt.begins_with("objet:"):
		var id := evt.substr(6).get_slice(">=", 0)
		if CIBLES.has("objet:" + id):
			return CIBLES["objet:" + id]
	var meilleur := ""
	for cle: String in CIBLES:
		if evt.begins_with(cle) and cle.length() > meilleur.length():
			meilleur = cle
	return CIBLES.get(meilleur, "")

## Cible de chaque quête en cours (voir l'en-tête).
static func cibles_quetes(quetes: Node, monde: Node) -> Array:
	var res: Array = []
	if quetes == null or not (quetes.get("donnees") is Dictionary):
		return res
	var objectifs: Array = quetes.objectifs() if quetes.has_method("objectifs") else []
	var titre_suivi: String = String(objectifs[-1][0]) if not objectifs.is_empty() else ""
	for q: Dictionary in quetes.donnees.get("quetes", []):
		if not quetes.en_cours(q["id"]):
			continue
		var n: int = int(quetes.etat[q["id"]])
		var etapes: Array = q["etapes"]
		var suivante: Dictionary = etapes[n]
		var pos := Vector3.INF
		var id_lieu := String(suivante.get("carte", ""))
		if id_lieu == "":
			for evt: String in String(suivante["declencheur"]).split("|"):
				if evt.begins_with("parle:") and monde != null:
					var pnj := _pnj(monde, evt.substr(6))
					if pnj != null:
						pos = pnj.global_position
						id_lieu = "skarnholt"
						break
				id_lieu = lieu_du_declencheur(evt)
				if id_lieu != "":
					break
		if pos == Vector3.INF and id_lieu != "":
			pos = position(id_lieu, monde)
		if pos == Vector3.INF:
			continue
		res.append({"quete": q["id"], "titre": q["titre"], "objectif": etapes[n - 1]["objectif"], "pos": pos, "lieu": id_lieu,
			"suivie": q["titre"] == titre_suivi})
	return res

static func _pnj(monde: Node, id: String) -> Node3D:
	if not monde.is_inside_tree():
		return null
	for v in monde.get_tree().get_nodes_in_group("villageois"):
		var d = v.get("donnees")
		if d is Dictionary and d.get("id", "") == id and v is Node3D:
			return v
	return null

## Position du joueur pour la carte : sous terre (crypte sous le tertre, grotte loin sous la carte), la porte d'entrée.
static func position_joueur(monde: Node) -> Vector3:
	var j: Node3D = monde.get("joueur") if monde != null else null
	if j == null:
		return Vector3.ZERO
	var p := j.global_position
	var ga: Node = monde.get("grotte_acces")
	if ga != null and (ga.get("dedans") or p.y < GrotteAcces.SEUIL_Y):
		return _porte("grotte", monde)
	var t: Node = monde.get("tertre")
	if t != null and t.get("dedans"):
		return _porte("tertre", monde)
	return p

## Vrai si le joueur est sous terre (la carte le dit : « Sous terre »).
static func sous_terre(monde: Node) -> String:
	var j: Node3D = monde.get("joueur") if monde != null else null
	if j == null:
		return ""
	var ga: Node = monde.get("grotte_acces")
	if ga != null and (ga.get("dedans") or j.global_position.y < GrotteAcces.SEUIL_Y):
		return "grotte"
	var t: Node = monde.get("tertre")
	if t != null and t.get("dedans"):
		return "tertre"
	return ""
