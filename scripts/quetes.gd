extends Node
## Quêtes (textes : data/quetes.json). Le jeu signale des événements — "parle:chef",
## "lieu:tertre", "ramasse:anneau_givre", "tue:svanhild", "objet:lame_antique>=3"… —
## et chaque quête avance quand survient le déclencheur de sa prochaine étape.
## Un événement arrivé avant le début d'une quête est retenu (on peut trouver l'amulette
## d'Eirik avant qu'Ylva ne la demande), sauf les conversations.

signal change
## Chaque événement signalé (hors "") : les ennemis en attente (reveil_evt) s'y abonnent.
signal evenement(evt: String)

## Objets remis au donneur quand la quête se termine.
const REMIS := {"lames_brodd": {"lame_antique": 3}, "frere_ylva": {"amulette_eirik": 1}, "repaire_hrafn": {"registre_hrafn": 1}, "expedition_sigrun": {"broche_sigrun": 1}}

## Choix moral du tombeau (événements "choix:piller_offrandes" / "choix:respecter_offrandes", mémorisés dans `vus` donc sauvegardés).
const CHOIX_PILLER := "choix:piller_offrandes"
const CHOIX_RESPECTER := "choix:respecter_offrandes"
const PILLAGE_PIECES := 240
const PILLAGE_RELIQUES := 3
var _sac := {}  # état du sac au dernier changement : sert à détecter « ramasse:<objet> »

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
	_sac = joueur.inventaire.objets.duplicate()
	joueur.inventaire.change.connect(_sac_change)

## Tout objet dont le nombre augmente signale « ramasse:<id> » (en plus des signaux explicites du jeu : idempotent).
func _sac_change() -> void:
	var avant := _sac
	_sac = joueur.inventaire.objets.duplicate()
	for id in _sac:
		if _sac[id] > avant.get(id, 0):
			signaler("ramasse:" + id)
	signaler("")

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

## Un déclencheur peut proposer des variantes séparées par « | » (« lieu:camp_hrafn|tue:hrafn ») : la première survenue suffit.
func _egal(declencheur: String, evt: String) -> bool:
	if evt == "":
		return false
	return declencheur == evt or (declencheur.contains("|") and evt in declencheur.split("|"))

func _satisfait(declencheur: String, evt: String) -> bool:
	if declencheur.contains("|"):
		for d in declencheur.split("|"):
			if _satisfait(d, evt):
				return true
		return false
	if declencheur == evt and evt != "":
		return true
	if declencheur.begins_with("objet:"):
		var parts := declencheur.substr(6).split(">=")
		return joueur.inventaire.objets.get(parts[0], 0) >= int(parts[1])
	return vus.has(declencheur) and not declencheur.begins_with("parle:")

func signaler(evt: String) -> void:
	if evt != "":
		vus[evt] = true
		evenement.emit(evt)
	for q in donnees["quetes"]:
		var etapes: Array = q["etapes"]
		var n: int = etat.get(q["id"], -1)
		if n == -1:
			# une quête ne commence que par son propre déclencheur
			if not _egal(etapes[0]["declencheur"], evt):
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
			# L9 : réplique propre à l'étape en cours (« <quête>:pendant_<étape> »), sinon la réplique générale
			var n: int = etat.get(q["id"], -1)
			var et: Array = q["etapes"]
			var lignes: Array = dialogues.get("%s:pendant_%s" % [q["id"], et[n]["id"]], []) if n >= 0 and n < et.size() else []
			if lignes.is_empty():
				lignes = dialogues.get(q["id"] + ":pendant", [])
			if not lignes.is_empty():
				return lignes
	return []

## Choix moral dans le tombeau : renvoie false si un choix a déjà été fait (définitif). `choix` = "piller_offrandes" | "respecter_offrandes".
## Respecter : Bénédiction des ancêtres (+10 vie max, sauvegardée). Piller : pièces + reliques d'offrande, et l'événement
## "vague_gardiens" (les gardiens du serment se lèvent : reveil_evt côté crypte).
func choisir(choix: String) -> bool:
	if choix_fait() != "" or not choix in ["piller_offrandes", "respecter_offrandes"]:
		return false
	signaler("choix:" + choix)
	if choix == "respecter_offrandes":
		joueur.regler_benediction(true, true)
		hud.avis("Bénédiction des ancêtres : +10 vie maximale")
	else:
		joueur.inventaire.ajouter("pieces", PILLAGE_PIECES)
		if Inventaire.OBJETS.has("relique_offrande"):
			joueur.inventaire.ajouter("relique_offrande", PILLAGE_RELIQUES)
		hud.avis("+ %d pièces" % PILLAGE_PIECES)
		signaler("vague_gardiens")
	change.emit()
	return true

## "" (pas de choix), "piller_offrandes" ou "respecter_offrandes".
func choix_fait() -> String:
	if vus.has(CHOIX_PILLER):
		return "piller_offrandes"
	if vus.has(CHOIX_RESPECTER):
		return "respecter_offrandes"
	return ""

func benediction() -> bool:
	return vus.has(CHOIX_RESPECTER)

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
	_sac = joueur.inventaire.objets.duplicate()
	joueur.regler_benediction(benediction())  # ancienne sauvegarde : pas de choix → 100 de vie max
	change.emit()
