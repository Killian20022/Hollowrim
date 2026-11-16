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
const REMIS := {"lames_brodd": {"lame_antique": 3}, "frere_ylva": {"amulette_eirik": 1}, "repaire_hrafn": {"registre_hrafn": 1}, "expedition_sigrun": {"broche_sigrun": 1},
	"cendre_runes": {"cristal_givre": 1}, "peau_troll": {"fourrure_troll": 1}}

## Choix moral du tombeau (événements "choix:piller_offrandes" / "choix:respecter_offrandes", mémorisés dans `vus` donc sauvegardés).
const CHOIX_PILLER := "choix:piller_offrandes"
const CHOIX_RESPECTER := "choix:respecter_offrandes"
const PILLAGE_PIECES := 240
const PILLAGE_RELIQUES := 3
var _sac := {}  # état du sac au dernier changement : sert à détecter « ramasse:<objet> »

var joueur: CharacterBody3D
var hud: Control
## LOT 5a : quêtes PARTAGÉES. L'hôte détient l'état (index, événements vus, dates, échecs) ; un invité ROUTE ses signalements vers lui et reçoit l'état
## en retour (scripts/reseau/quetes_coop.gd). Chacun reçoit la récompense de fin de quête dans son propre sac. Hors ligne : `_coop` ne fait rien.
var _coop: QuetesCoop = null
var _objets_test: Dictionary = {}     # inventaire de l'invité dont l'hôte traite l'évènement (vide : celui de l'hôte)

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
			res.append({"quete": q["id"], "titre": q["titre"], "i": i, "etape": q["etapes"][i]["id"], "texte": String(_issue(q, i).get("journal", q["etapes"][i]["journal"])),
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
	if _coop != null and _coop.router("echouer", [id]):
		return
	if not echecs.has(id) and not fini(id):
		echecs[id] = true
		change.emit()
		_partager()

func echouee(id: String) -> bool:
	return echecs.has(id)

## Avance l'index d'une quête jusqu'à `i` (jamais en arrière), en jouant les étapes intermédiaires (récompenses comprises).
func avancer_index(id: String, i: int) -> void:
	if _coop != null and _coop.router("avancer", [id, i]):
		return
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
	_coop = QuetesCoop.installer(self)

## Tout objet dont le nombre augmente signale « ramasse:<id> » (en plus des signaux explicites du jeu : idempotent).
func _sac_change() -> void:
	var avant := _sac
	_sac = joueur.inventaire.objets.duplicate()
	for id in _sac:
		if _sac[id] > avant.get(id, 0):
			signaler("ramasse:" + id)
	# invité : « objet:x>=n » se juge sur son sac ; on ne dérange l'hôte que si une étape en attente vient d'être remplie
	if _coop == null or not _coop.invite() or _objet_pret():
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
		return (_objets_test if not _objets_test.is_empty() else joueur.inventaire.objets).get(parts[0], 0) >= int(parts[1])
	return vus.has(declencheur) and not declencheur.begins_with("parle:")

func signaler(evt: String) -> void:
	if _coop != null and _coop.router("signaler", [evt]):
		return
	_signaler(evt)
	_partager()

## Une étape en attente dont la condition « objet:… » est déjà remplie par le sac local ?
func _objet_pret() -> bool:
	for q in donnees["quetes"]:
		var etapes: Array = q["etapes"]
		var n := index(q["id"])
		if n >= 1 and n < etapes.size() and String(etapes[n]["declencheur"]).contains("objet:") and _satisfait(etapes[n]["declencheur"], ""):
			return true
	return false

## Signale l'état aux invités (coalescé à l'image suivante) ; sans effet hors ligne ou chez un invité.
func _partager() -> void:
	if _coop != null:
		_coop.marquer()

func _signaler(evt: String) -> void:
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
	_partager()
	if i == 0 and not q.get("discrete", false):
		hud.avis("Nouvelle quête : " + q["titre"])
		if etapes.size() > 1:
			Sons.interface(self, ["ui_quete_debut"], -7.0)
	if i + 1 >= etapes.size():
		if not q.get("discrete", false):
			hud.avis("Quête terminée : " + q["titre"])
		_donner_recompense(q)
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

## Récompense de fin de quête DANS LE SAC LOCAL : objets remis au donneur, XP, pièces, objets, réputation de faction. En coop chaque joueur
## la reçoit chez lui (l'hôte à la fin de la quête, les invités quand l'état partagé leur arrive : QuetesCoop).
func _donner_recompense(q: Dictionary) -> void:
	var remis: Dictionary = REMIS.get(q["id"], q.get("remis", {}))
	for id in remis:
		joueur.inventaire.retirer(id, mini(int(remis[id]), joueur.inventaire.nombre(id)) if _coop != null and _coop.invite() else remis[id])
	var r: Dictionary = recompense_de(String(q["id"]))
	joueur.progression.gagner_xp(float(r.get("xp", Progression.XP_QUETE_DEFAUT)))   # RPG : XP de niveau (lot B : recompense.xp)
	if int(r.get("pieces", 0)) > 0:
		joueur.inventaire.ajouter("pieces", int(r["pieces"]))
		hud.avis("+ %d pièces" % int(r["pieces"]))
	for id in r.get("objets", {}):
		joueur.inventaire.ajouter(id, int(r["objets"][id]))
		hud.avis("+ " + joueur.inventaire.nom(id))
	if r.get("reputation") is Dictionary and Rangs.courant != null:
		Rangs.courant.recompenser(r["reputation"])   # réputation de faction (data/quetes.json : recompense.reputation)

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

## Réplique de RANG d'un PNJ (sujet « rang » : le chef, les membres et les villageois qui reconnaissent le rang du joueur dans une faction) :
## [] si le joueur n'a pas de rang qui compte pour lui. Une seule ligne tirée au sort (les entrées sont `hasard`).
func rang(villageois: String, pnj: Node = null) -> Array:
	var retenues := RepliquesFiltrees.choisir("rang", _contexte(villageois, pnj))
	_effets(retenues, pnj)
	return RepliquesFiltrees.lignes(retenues)

func _contexte(villageois: String, pnj: Node) -> Dictionary:
	var ctx := RepliquesFiltrees.contexte(pnj, self)
	if String(ctx["pnj"]) == "":
		ctx["pnj"] = villageois
	return ctx

## Effets des répliques dites : signaler un événement, avancer le journal, donner ou retirer un objet, marquer la mémoire du PNJ
## (ou d'un autre : « disposition_pnj »), échouer, afficher un avis.
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
			if e.has("retirer"):
				joueur.inventaire.retirer(String(e["retirer"]["objet"]), int(e["retirer"].get("n", 1)))
			if e.has("disposition_pnj") and Disposition.courante != null and is_instance_valid(Disposition.courante):
				Disposition.courante.noter_cle("pnj:" + String(e["disposition_pnj"]["pnj"]), String(e["disposition_pnj"]["evt"]))
			if e.has("avis") and hud != null:
				hud.avis(String(e["avis"]))

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

# ------------------------------------------------------------------------------------------- issues et choix (quêtes à fins multiples)
## Étape à plusieurs ISSUES (data/quetes.json : "issues": {"<événement>": {journal, recompense}}) : en général son déclencheur
## propose ces événements en variantes (« issue:q:a|issue:q:b »), et une étape suivante peut reprendre les mêmes clés pour varier
## son propre texte. L'issue retenue = la première clé déjà survenue (`vus`, donc sauvegardée) ; elle remplace le texte du journal
## de l'étape et ajoute sa récompense (pièces et objets cumulés, réputation additionnée) à celle de la quête. Sans issue : rien ne change.
func _issue(q: Dictionary, i: int) -> Dictionary:
	var iss: Variant = (q["etapes"][i] as Dictionary).get("issues")
	if not (iss is Dictionary):
		return {}
	for evt: String in iss:
		if vus.has(evt):
			return iss[evt]
	return {}

## Événement d'issue retenu pour une quête ("" si aucune) : la première issue survenue, toutes étapes confondues.
func issue(id: String) -> String:
	var q := _quete(id)
	for e: Dictionary in q.get("etapes", []):
		if e.get("issues") is Dictionary:
			for evt: String in e["issues"]:
				if vus.has(evt):
					return evt
	return ""

## Récompense d'une quête, issues comprises (lue aussi par l'onglet Quêtes).
func recompense_de(id: String) -> Dictionary:
	var q := _quete(id)
	var r: Dictionary = (q.get("recompense", {}) as Dictionary).duplicate(true)
	for i in (q.get("etapes", []) as Array).size():
		var ri: Variant = _issue(q, i).get("recompense")
		if not (ri is Dictionary):
			continue
		for cle in ri:
			var v: Variant = ri[cle]
			if v is Dictionary:
				var d: Dictionary = (r.get(cle, {}) as Dictionary).duplicate()
				for k in v:
					d[k] = d.get(k, 0) + v[k]
				r[cle] = d
			elif cle == "pieces":
				r[cle] = int(r.get(cle, 0)) + int(v)
			else:
				r[cle] = v
	return r

## Ce que le journal affiche à la ligne « Reçu » : la récompense (recompense_de) plus les objets déjà remis sur le moment par un
## choix (issue "recu": {"objets": {...}} dans data/quetes.json, ex. l'anneau de cuivre de Brodd) ; affichage seul, rien n'est donné.
func recu_de(id: String) -> Dictionary:
	var r := recompense_de(id)
	var q := _quete(id)
	for i in (q.get("etapes", []) as Array).size():
		var deja: Variant = _issue(q, i).get("recu")
		if deja is Dictionary and (deja as Dictionary).get("objets") is Dictionary:
			var d: Dictionary = (r.get("objets", {}) as Dictionary).duplicate()
			for k in deja["objets"]:
				d[k] = int(d.get(k, 0)) + int(deja["objets"][k])
			r["objets"] = d
	return r

## Choix proposés dans le dialogue de `id_pnj` (data/quetes.json, "choix" d'une quête : {id, pnj, index, si?, texte, repond,
## effets?, exige?, refus?}) : [{texte, action}] pour ServicesPnj.options. Un choix n'est offert que si la quête est à l'index
## voulu et si ses filtres `si` (ceux de RepliquesFiltrees : heure, journal, vu…) passent. Le valider signale
## « issue:<quête>:<id> » (sauf "signaler" explicite), joue ses effets, et le PNJ répond par `repond`.
func options(id_pnj: String, pnj: Node = null) -> Array:
	var res: Array = []
	var ctx := _contexte(id_pnj, pnj)
	for q: Dictionary in donnees.get("quetes", []):
		for c: Dictionary in q.get("choix", []):
			if String(c.get("pnj", "")) != id_pnj or index(q["id"]) != int(c.get("index", -1)):
				continue
			if c.get("si") is Dictionary and not RepliquesFiltrees.valide({"filtres": c["si"]}, ctx):
				continue
			res.append({"texte": String(c["texte"]), "action": choisir_option.bind(String(q["id"]), String(c["id"]), pnj)})
	return res

## Joue un choix de quête (voir `options`) ; renvoie les répliques du PNJ ([] si le choix n'existe plus).
func choisir_option(id: String, choix_id: String, pnj: Node = null) -> Array:
	var q := _quete(id)
	for c: Dictionary in q.get("choix", []):
		if String(c["id"]) != choix_id or index(id) != int(c.get("index", -1)):
			continue
		if c.get("si") is Dictionary and not RepliquesFiltrees.valide({"filtres": c["si"]}, _contexte(String(c["pnj"]), pnj)):
			continue   # même id, autre variante (le PNJ ne répond pas pareil selon le journal ou l'heure)
		var exige: Dictionary = c.get("exige", {})
		for obj in exige:
			if joueur.inventaire.objets.get(obj, 0) < int(exige[obj]):
				return c.get("refus", ["…"])
		_effets([{"effets": c.get("effets", [])}], pnj)
		signaler(String(c.get("signaler", "issue:%s:%s" % [id, choix_id])))
		for evt in c.get("puis", []):   # événements à la suite (une issue qui clôt aussitôt la quête)
			signaler(String(evt))
		return (c.get("repond", []) as Array).duplicate()
	return []

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
	_partager()


# ------------------------------------------------------------------------------------------- coop (lot 5a) : état partagé
## Partie PARTAGÉE de l'état (envoyée par l'hôte à chaque changement) : index, événements vus, dates, échecs.
func exporter_partage() -> Dictionary:
	return exporter()

## Invité : adopte l'état de l'hôte. `notifier` (message en direct, pas l'instantané de connexion) : annonces et RÉCOMPENSES des étapes
## franchies depuis le dernier état connu (nouvelle quête, objectif, fin de quête = récompense dans MON sac).
func appliquer_partage(d: Dictionary, notifier: bool) -> void:
	var avant := etat.duplicate()
	var benie := benediction()
	etat = {}
	for id in d.get("etat", {}):
		etat[id] = int(d["etat"][id])
	for evt in d.get("vus", []):
		vus[evt] = true
	dates = {}
	var dd: Variant = d.get("dates", {})
	if dd is Dictionary:
		for k in dd:
			if dd[k] is Array and (dd[k] as Array).size() == 2:
				dates[String(k)] = [int(dd[k][0]), float(dd[k][1])]
	echecs = {}
	for id in d.get("echecs", []):
		echecs[String(id)] = true
	if not notifier:
		_sac = joueur.inventaire.objets.duplicate()
	for id: String in etat:
		var q := _quete(id)
		if q.is_empty():
			continue
		var fin := mini(int(etat[id]), (q["etapes"] as Array).size())
		if notifier:
			for i in range(int(avant.get(id, 0)), fin):
				_notifier_distant(q, i)
	if benediction() != benie:
		joueur.regler_benediction(benediction())
	change.emit()

## Retour d'une étape franchie PAR UN AUTRE JOUEUR (ou par l'hôte) : mêmes annonces et sons que _completer, récompense de fin chez moi.
func _notifier_distant(q: Dictionary, i: int) -> void:
	var etapes: Array = q["etapes"]
	if i == 0 and not q.get("discrete", false):
		hud.avis("Nouvelle quête : " + q["titre"])
		if etapes.size() > 1:
			Sons.interface(self, ["ui_quete_debut"], -7.0)
	if i + 1 >= etapes.size():
		if not q.get("discrete", false):
			hud.avis("Quête terminée : " + q["titre"])
		_donner_recompense(q)
		if not q.get("discrete", false):
			Sons.interface(self, ["ui_quete_fin"], -6.0)
		quete_terminee.emit(String(q["id"]))
	elif hud.has_method("objectif_change"):
		hud.objectif_change()
	else:
		hud.avis(etapes[i]["objectif"])
