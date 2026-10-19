extends Node
## Quêtes (textes : data/quetes.json). Le jeu signale des événements — "parle:chef",
## "lieu:tertre", "ramasse:anneau_givre", "tue:svanhild", "objet:lame_antique>=3"… —
## et chaque quête avance quand survient le déclencheur de sa prochaine étape.
## Un événement arrivé avant le début d'une quête est retenu (on peut trouver l'amulette
## d'Eirik avant qu'Ylva ne la demande), sauf les conversations.

signal change

## Objets remis au donneur quand la quête se termine.
const REMIS := {"lames_brodd": {"lame_antique": 3}, "frere_ylva": {"amulette_eirik": 1}}

var joueur: CharacterBody3D
var hud: Control

var donnees := {}
var etat := {}      # identifiant de quête → nombre d'étapes faites (absent = pas commencée)
var vus := {}       # événements déjà survenus
var journal: Array = []

func _ready() -> void:
	var chemin := "res://data/quetes.json"
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
	if d is Dictionary:
		donnees = d
	else:
		push_warning("Quêtes : %s illisible" % chemin)
		donnees = {"quetes": [], "dialogues": {}, "textes": {}}
	joueur.inventaire.change.connect(func() -> void: signaler(""))

func texte(cle: String) -> Array:
	return donnees.get("textes", {}).get(cle, [])

func en_cours(id: String) -> bool:
	return etat.has(id) and etat[id] < _quete(id).get("etapes", []).size()

func faite(id: String, etape: String) -> bool:
	var q := _quete(id)
	if not etat.has(id):
		return false
	for i in etat[id]:
		if q["etapes"][i]["id"] == etape:
			return true
	return false

## Objectifs des quêtes en cours, pour le HUD : [[titre, objectif]…]
func objectifs() -> Array:
	var res := []
	for q in donnees["quetes"]:
		if en_cours(q["id"]):
			res.append([q["titre"], q["etapes"][etat[q["id"]] - 1]["objectif"]])
	return res

func _quete(id: String) -> Dictionary:
	for q in donnees["quetes"]:
		if q["id"] == id:
			return q
	return {}

func _satisfait(declencheur: String, evt: String) -> bool:
	if declencheur == evt and evt != "":
		return true
	if declencheur.begins_with("objet:"):
		var parts := declencheur.substr(6).split(">=")
		return joueur.inventaire.objets.get(parts[0], 0) >= int(parts[1])
	return vus.has(declencheur) and not declencheur.begins_with("parle:")

func signaler(evt: String) -> void:
	if evt != "":
		vus[evt] = true
	for q in donnees["quetes"]:
		var etapes: Array = q["etapes"]
		var n: int = etat.get(q["id"], -1)
		if n == -1:
			# une quête ne commence que par son propre déclencheur
			if etapes[0]["declencheur"] != evt:
				continue
			_completer(q, 0)
			n = 1
		elif n < etapes.size() and _satisfait(etapes[n]["declencheur"], evt):
			_completer(q, n)
			n += 1
		else:
			continue
		# étapes suivantes déjà remplies (objet déjà dans le sac…)
		while n < etapes.size() and _satisfait(etapes[n]["declencheur"], ""):
			_completer(q, n)
			n += 1

func _completer(q: Dictionary, i: int) -> void:
	var etapes: Array = q["etapes"]
	etat[q["id"]] = i + 1
	journal.append(etapes[i]["journal"])
	if i == 0:
		hud.avis("Nouvelle quête : " + q["titre"])
	if i + 1 >= etapes.size():
		hud.avis("Quête terminée : " + q["titre"])
		var remis: Dictionary = REMIS.get(q["id"], {})
		for id in remis:
			joueur.inventaire.retirer(id, remis[id])
		var r: Dictionary = q.get("recompense", {})
		if int(r.get("pieces", 0)) > 0:
			joueur.inventaire.ajouter("pieces", int(r["pieces"]))
			hud.avis("+ %d pièces" % int(r["pieces"]))
		for id in r.get("objets", {}):
			joueur.inventaire.ajouter(id, int(r["objets"][id]))
			hud.avis("+ " + joueur.inventaire.nom(id))
		Sons.jouer(self, ["sword-unsheathe"], -6.0)
	else:
		hud.avis(etapes[i]["objectif"])
	change.emit()

## Répliques de quête d'un villageois, ou [] s'il n'a rien de spécial à dire.
## Fait avancer la quête si lui parler en est la prochaine étape.
func repliques(villageois: String) -> Array:
	var dialogues: Dictionary = donnees.get("dialogues", {}).get(villageois, {})
	var evt := "parle:" + villageois
	for q in donnees["quetes"]:
		var etapes: Array = q["etapes"]
		var n: int = etat.get(q["id"], -1)
		var prochaine := 0 if n == -1 else n
		if prochaine < etapes.size() and etapes[prochaine]["declencheur"] == evt:
			var lignes: Array = dialogues.get("%s:%s" % [q["id"], etapes[prochaine]["id"]], [])
			signaler(evt)
			if not lignes.is_empty():
				return lignes
	for q in donnees["quetes"]:
		if en_cours(q["id"]):
			var lignes: Array = dialogues.get(q["id"] + ":pendant", [])
			if not lignes.is_empty():
				return lignes
	return []

func exporter() -> Dictionary:
	return {"etat": etat.duplicate(), "vus": vus.keys(), "journal": journal.duplicate()}

func importer(d: Dictionary) -> void:
	etat = {}
	for id in d.get("etat", {}):
		etat[id] = int(d["etat"][id])
	vus = {}
	for evt in d.get("vus", []):
		vus[evt] = true
	journal = d.get("journal", [])
	change.emit()
