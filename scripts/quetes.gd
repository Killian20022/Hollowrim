extends Node
## Quêtes (textes : data/quetes.json). Le jeu signale des événements — "parle:chef",
## "lieu:tertre", "ramasse:anneau_givre", "tue:svanhild", "objet:lame_antique>=3"… —
## et chaque quête avance quand survient le déclencheur de sa prochaine étape.
## Un événement arrivé avant le début d'une quête est retenu (on peut trouver l'amulette
## d'Eirik avant qu'Ylva ne la demande), sauf les conversations.

signal change
## Une quête vient d'être menée à son terme (récompenses données) : autosauvegarde (Monde).
signal quete_terminee(id: String)
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
## JOURNAL À INDEX ENTIER (idée OpenMW) : `etat[quête]` EST l'index de la quête = nombre d'étapes faites. 0 / absent = pas commencée,
## 1…n-1 = en cours (l'étape suivante à faire est celle d'index `etat`), n = terminée (n = nombre d'étapes). Aucune autre copie :
## en_cours, fini, faite, objectifs, le journal affiché et les filtres des répliques le lisent tous. Les sauvegardes d'avant
## portaient déjà cet entier : elles se chargent telles quelles.
var etat := {}
var vus := {}       # événements déjà survenus
## Date de chaque entrée du journal : "<quête>:<index de l'étape>" → [jour de jeu, heure] (absente des anciennes parties).
var dates := {}
## Quêtes échouées (drapeau, à côté de l'index) : id → true. Aucune quête n'échoue encore ; le filtre `echouee` des répliques le lit.
var echecs := {}

## Entrées du journal, dans l'ordre où elles ont été écrites : [{quete, titre, i, etape, texte, jour, heure}] (jour 0 = non daté).
func entrees(id := "") -> Array:
	var res: Array = []
	for q: Dictionary in donnees["quetes"]:
		if id != "" and q["id"] != id:
			continue
		for i in int(etat.get(q["id"], 0)):
			var d: Array = dates.get("%s:%d" % [q["id"], i], [0, 0.0])
			res.append({"quete": q["id"], "titre": q["titre"], "i": i, "etape": q["etapes"][i]["id"], "texte": q["etapes"][i]["journal"],
				"jour": int(d[0]), "heure": float(d[1])})
	# chronologique ; les entrées non datées (anciennes parties) d'abord, dans l'ordre des quêtes puis des étapes
	for k in res.size():
		res[k]["ordre"] = k
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka: float = a["jour"] * 24.0 + a["heure"] if a["jour"] > 0 else 0.0
		var kb: float = b["jour"] * 24.0 + b["heure"] if b["jour"] > 0 else 0.0
		return a["ordre"] < b["ordre"] if ka == kb else ka < kb)
	return res

## Textes du journal (compat. : l'ancienne liste de textes).
var journal: Array:
	get:
		return entrees().map(func(e: Dictionary) -> String: return e["texte"])

## Index entier d'une quête (0 = pas commencée).
func index(id: String) -> int:
	return int(etat.get(id, 0))

## Une quête échoue : drapeau posé, elle n'est plus « en cours ».
func echouer(id: String) -> void:
	if not echecs.has(id) and not fini(id):
		echecs[id] = true
		change.emit()

func echouee(id: String) -> bool:
	return echecs.has(id)

## Avance l'index d'une quête jusqu'à `i` (jamais en arrière), en jouant les étapes intermédiaires (récompenses comprises).
func avancer_index(id: String, i: int) -> void:
	var q := _quete(id)
	if q.is_empty():
		return
	for k in range(index(id), mini(i, q["etapes"].size())):
		_completer(q, k)

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

## [jour de jeu, heure] (le cycle jour/nuit est un frère de ce nœud dans le monde ; sans cycle : jour 1, midi).
func _maintenant() -> Array:
	var c: Variant = get_parent().get("cycle") if get_parent() != null else null
	return [int(c.jour), float(c.heure)] if c != null else [1, 12.0]

func _completer(q: Dictionary, i: int) -> void:
	var etapes: Array = q["etapes"]
	etat[q["id"]] = i + 1
	dates["%s:%d" % [q["id"], i]] = _maintenant()
	if i == 0 and not q.get("discrete", false):
		hud.avis("Nouvelle quête : " + q["titre"])
		if etapes.size() > 1:
			Sons.interface(self, ["ui_quete_debut"], -7.0)
	if i + 1 >= etapes.size():
		if not q.get("discrete", false):
			hud.avis("Quête terminée : " + q["titre"])
		var remis: Dictionary = REMIS.get(q["id"], {})
		for id in remis:
			joueur.inventaire.retirer(id, remis[id])
		var r: Dictionary = q.get("recompense", {})
		joueur.progression.gagner_xp(float(r.get("xp", Progression.XP_QUETE_DEFAUT)))   # RPG : XP de niveau (lot B : recompense.xp)
		if int(r.get("pieces", 0)) > 0:
			joueur.inventaire.ajouter("pieces", int(r["pieces"]))
			hud.avis("+ %d pièces" % int(r["pieces"]))
		for id in r.get("objets", {}):
			joueur.inventaire.ajouter(id, int(r["objets"][id]))
			hud.avis("+ " + joueur.inventaire.nom(id))
		if r.get("reputation") is Dictionary and Rangs.courant != null:
			Rangs.courant.recompenser(r["reputation"])   # réputation de faction (data/quetes.json : recompense.reputation)
		if not q.get("discrete", false):
			Sons.interface(self, ["ui_quete_fin"], -6.0)
		quete_terminee.emit(String(q["id"]))   # autosauvegarde de fin de quête (Sauvegardes)
		change.emit()
		signaler("fini:" + q["id"])   # une quête peut en lancer une autre (premier déclencheur « fini:<id> ») : la suite de l'histoire
		return
	elif hud.has_method("objectif_change"):
		hud.objectif_change()   # l'objectif s'affiche sous la boussole (hud.gd), plus en double en haut à gauche
	else:
		hud.avis(etapes[i]["objectif"])
	change.emit()

## Un événement fait-il avancer au moins une quête ? (la prochaine étape d'une quête non terminée l'attend)
func _attend(evt: String) -> bool:
	for q in donnees["quetes"]:
		var etapes: Array = q["etapes"]
		var n := index(q["id"])
		if n < etapes.size() and _egal(etapes[n]["declencheur"], evt):
			return true
	return false

## Répliques de quête d'un villageois, ou [] s'il n'a rien de spécial à dire (sujet « quete » de data/dialogue/repliques.json :
## première réplique valide ; l'avancement d'une quête dont lui parler est la prochaine étape se joue ici). `pnj` = son nœud
## (disposition, rang, lieu pour les filtres) ; facultatif.
func repliques(villageois: String, pnj: Node = null) -> Array:
	var evt := "parle:" + villageois
	var retenues := RepliquesFiltrees.choisir("quete", _contexte(villageois, pnj))
	if _attend(evt):
		signaler(evt)
		# une étape franchie sans réplique (le chef qui lance « Skarnholt ») : les répliques « pendant » se lisent après coup
		if retenues.is_empty() or String(retenues[0].get("cumul", "")) == "":
			retenues = RepliquesFiltrees.choisir("quete", _contexte(villageois, pnj))
	_effets(retenues, pnj)
	return RepliquesFiltrees.lignes(retenues)

## Réplique « après » d'un villageois selon l'état du monde (sujet « apres » : de la plus avancée à la plus générale, la première
## valide l'emporte) ; [] si aucune (le villageois retombe alors sur ses « apres » fixes de villageois.json).
func apres(villageois: String, pnj: Node = null) -> Array:
	var retenues := RepliquesFiltrees.choisir("apres", _contexte(villageois, pnj))
	_effets(retenues, pnj)
	return RepliquesFiltrees.lignes(retenues)

func _contexte(villageois: String, pnj: Node) -> Dictionary:
	var ctx := RepliquesFiltrees.contexte(pnj, self)
	if String(ctx["pnj"]) == "":
		ctx["pnj"] = villageois
	return ctx

## Effets des répliques dites : signaler un événement, avancer le journal, donner un objet, marquer la mémoire du PNJ, échouer.
func _effets(retenues: Array, pnj: Node) -> void:
	for r: Dictionary in retenues:
		for e: Dictionary in r.get("effets", []):
			if e.has("signaler"):
				signaler(String(e["signaler"]))
			if e.has("journal"):
				avancer_index(String(e["journal"]["quete"]), int(e["journal"]["index"]))
			if e.has("donner"):
				joueur.inventaire.ajouter(String(e["donner"]["objet"]), int(e["donner"].get("n", 1)))
			if e.has("disposition") and pnj != null and Disposition.courante != null:
				Disposition.courante.noter(pnj, String(e["disposition"]))
			if e.has("echec"):
				echouer(String(e["echec"]))

func fini(id: String) -> bool:
	return etat.has(id) and etat[id] >= _quete(id).get("etapes", []).size()

## Quêtes lancées par la fin d'une autre (premier déclencheur « fini:<id> ») : à rattraper pour une partie chargée dont la
## quête-mère est déjà terminée (sauvegarde d'avant l'ajout de la suite).
func _rattraper() -> void:
	for q in donnees["quetes"]:
		var d: String = q["etapes"][0]["declencheur"]
		if d.begins_with("fini:") and not etat.has(q["id"]) and fini(d.substr(5)):
			vus[d] = true
			_completer(q, 0)

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
	return {"etat": etat.duplicate(), "vus": vus.keys(), "dates": dates.duplicate(), "echecs": echecs.keys()}

func importer(d: Dictionary) -> void:
	etat = {}
	for id in d.get("etat", {}):
		etat[id] = int(d["etat"][id])
	vus = {}
	for evt in d.get("vus", []):
		vus[evt] = true
	# anciennes parties : « journal » (liste de textes) n'est plus lu, l'index suffit à le reconstruire ; sans dates, sans échecs
	dates = {}
	var dd: Variant = d.get("dates", {})
	if dd is Dictionary:
		for k in dd:
			if dd[k] is Array and (dd[k] as Array).size() == 2:
				dates[String(k)] = [int(dd[k][0]), float(dd[k][1])]
	echecs = {}
	for id in d.get("echecs", []):
		echecs[String(id)] = true
	_sac = joueur.inventaire.objets.duplicate()
	joueur.regler_benediction(benediction())  # ancienne sauvegarde : pas de choix → 100 de vie max
	_rattraper()
	change.emit()
