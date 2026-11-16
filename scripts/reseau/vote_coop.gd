class_name VoteCoop
extends Node
## LOT 3 — vote à l'unanimité entre tous les joueurs (sommeil, attente…). L'HÔTE arbitre ; chaque machine a son nœud « VoteCoop »
## (même nom/rôle partout). Un vote est refusé dès qu'un joueur dit non, s'il est touché / en combat (via `verificateur`), ou au bout
## de `timeout` secondes (un joueur muet = refus). Solo : `proposer` accepte tout de suite, sans réseau.
##   proposer(type, donnees, timeout) : n'importe quel joueur ; réponse via le signal `clos` sur TOUTES les machines.
##   repondre(oui, raison)            : réponse du joueur local au vote en cours (touche O / N par défaut).
##   verificateur : Callable(type, donnees) -> String ; raison de refus LOCALE (« » = d'accord possible). Rappelé à l'ouverture et à
##   chaque `verifier()` (appelé par exemple quand le joueur est touché) : une raison non vide = refus immédiat.
## Signaux : ouvert(id, type, auteur, donnees, timeout), clos(id, type, accepte, raison, donnees).

signal ouvert(id: int, type: String, auteur: int, donnees: Dictionary, timeout: float)
signal clos(id: int, type: String, accepte: bool, raison: String, donnees: Dictionary)

const TIMEOUT_DEFAUT := 15.0

var verificateur := Callable()
var courant := {}                # vote en cours vu d'ici : {id, type, auteur, donnees, timeout, reste, repondu}
var _votes := {}                 # HÔTE : id -> {type, auteur, donnees, attendus: Array, oui: Array, reste: float}
var _suivant := 1
var _calque: CanvasLayer
var _texte: Label
var historique: Array = []       # votes clos vus d'ici [{id,type,accepte,raison}] (tests)

func _ready() -> void:
	name = "VoteCoop"
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseCoop.R().abonner("vote_demande", _sur_demande)
	PauseCoop.R().abonner("vote_ouvert", _sur_ouvert)
	PauseCoop.R().abonner("vote_reponse", _sur_reponse)
	PauseCoop.R().abonner("vote_clos", _sur_clos)
	PauseCoop.R().joueur_deconnecte.connect(_sur_depart)
	_calque = CanvasLayer.new()
	_calque.layer = 48
	add_child(_calque)
	_texte = Label.new()
	_texte.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_texte.position = Vector2(-200, 24)
	_texte.size = Vector2(400, 40)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62))
	_texte.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_texte.add_theme_constant_override("outline_size", 4)
	_texte.visible = false
	_calque.add_child(_texte)

func _exit_tree() -> void:
	PauseCoop.R().desabonner("vote_demande", _sur_demande)
	PauseCoop.R().desabonner("vote_ouvert", _sur_ouvert)
	PauseCoop.R().desabonner("vote_reponse", _sur_reponse)
	PauseCoop.R().desabonner("vote_clos", _sur_clos)

# ------------------------------------------------------------------------------------------------ API

func en_cours() -> bool:
	return not courant.is_empty()

func proposer(type: String, donnees: Dictionary = {}, timeout := TIMEOUT_DEFAUT) -> void:
	if not PauseCoop.R().est_en_ligne():
		clos.emit(0, type, true, "", donnees)      # solo : d'accord d'office
		return
	if PauseCoop.R().est_hote():
		_ouvrir_hote(PauseCoop.R().mon_id(), type, donnees, timeout)
	else:
		PauseCoop.R().envoyer_evenement("vote_demande", 0, {"type": type, "donnees": donnees, "timeout": timeout})

func repondre(oui: bool, raison := "") -> void:
	if courant.is_empty() or bool(courant["repondu"]):
		return
	courant["repondu"] = true
	_maj_texte()
	_envoyer_reponse(int(courant["id"]), PauseCoop.R().mon_id(), oui, raison)

## À rappeler quand l'état local change (touché, combat…) : un refus local met fin au vote en cours.
func verifier() -> void:
	if courant.is_empty() or not verificateur.is_valid():
		return
	var r := String(verificateur.call(courant["type"], courant["donnees"]))
	if r != "":
		courant["repondu"] = true
		_envoyer_reponse(int(courant["id"]), PauseCoop.R().mon_id(), false, r)

# ------------------------------------------------------------------------------------------------ hôte

func _ouvrir_hote(auteur: int, type: String, donnees: Dictionary, timeout: float) -> void:
	for v: Dictionary in _votes.values():
		if v["type"] == type:
			return      # un seul vote du même type à la fois
	var id := _suivant
	_suivant += 1
	var attendus: Array = PauseCoop.R().joueurs().duplicate()
	_votes[id] = {"type": type, "auteur": auteur, "donnees": donnees, "attendus": attendus, "oui": [auteur], "reste": timeout}
	var msg := {"type": type, "auteur": auteur, "donnees": donnees, "timeout": timeout}
	PauseCoop.R().envoyer_evenement("vote_ouvert", id, msg)
	_sur_ouvert(PauseCoop.R().mon_id(), id, msg)       # l'hôte applique aussi en local
	_conclure_si_possible(id)

func _sur_demande(expediteur: int, _id: Variant, d: Variant) -> void:
	if PauseCoop.R().est_hote():
		_ouvrir_hote(expediteur, String(d["type"]), d["donnees"], float(d["timeout"]))

func _sur_reponse(expediteur: int, id: Variant, d: Variant) -> void:
	if not PauseCoop.R().est_hote() or not _votes.has(int(id)):
		return
	_enregistrer(int(id), expediteur, bool(d["oui"]), String(d.get("raison", "")))

func _envoyer_reponse(id: int, de: int, oui: bool, raison: String) -> void:
	if PauseCoop.R().est_hote():
		if _votes.has(id):
			_enregistrer(id, de, oui, raison)
	else:
		PauseCoop.R().envoyer_evenement("vote_reponse", id, {"oui": oui, "raison": raison})

func _enregistrer(id: int, de: int, oui: bool, raison: String) -> void:
	var v: Dictionary = _votes[id]
	if not oui:
		_clore(id, false, raison if raison != "" else "refusé")
		return
	if not (de in v["oui"]):
		v["oui"].append(de)
	_conclure_si_possible(id)

func _conclure_si_possible(id: int) -> void:
	if not _votes.has(id):
		return
	var v: Dictionary = _votes[id]
	for p: int in v["attendus"]:
		if not (p in v["oui"]):
			return
	_clore(id, true, "")

func _clore(id: int, accepte: bool, raison: String) -> void:
	var v: Dictionary = _votes[id]
	_votes.erase(id)
	var msg := {"type": v["type"], "accepte": accepte, "raison": raison, "donnees": v["donnees"]}
	PauseCoop.R().envoyer_evenement("vote_clos", id, msg)
	_sur_clos(PauseCoop.R().mon_id(), id, msg)

func _sur_depart(id: int) -> void:
	if not PauseCoop.R().est_hote():
		return
	for vid: int in _votes.keys():
		var v: Dictionary = _votes[vid]
		v["attendus"].erase(id)
		v["oui"].erase(id)
		if v["auteur"] == id:
			_clore(vid, false, "l'auteur est parti")
		else:
			_conclure_si_possible(vid)

# ------------------------------------------------------------------------------------------------ toutes machines

func _sur_ouvert(_exp: int, id: Variant, d: Variant) -> void:
	var moi: int = PauseCoop.R().mon_id()
	courant = {"id": int(id), "type": String(d["type"]), "auteur": int(d["auteur"]), "donnees": d["donnees"],
		"timeout": float(d["timeout"]), "reste": float(d["timeout"]), "repondu": int(d["auteur"]) == moi}
	ouvert.emit(int(id), courant["type"], courant["auteur"], courant["donnees"], courant["timeout"])
	_maj_texte()
	if int(d["auteur"]) != moi:
		verifier()      # d'emblée en désaccord (combat, touché) : refus automatique

func _sur_clos(_exp: int, id: Variant, d: Variant) -> void:
	if not courant.is_empty() and int(courant["id"]) == int(id):
		courant = {}
	_texte.visible = false
	historique.append({"id": int(id), "type": String(d["type"]), "accepte": bool(d["accepte"]), "raison": String(d["raison"])})
	clos.emit(int(id), String(d["type"]), bool(d["accepte"]), String(d["raison"]), d["donnees"])

func _process(dt: float) -> void:
	if not courant.is_empty():
		courant["reste"] = float(courant["reste"]) - dt
		_maj_texte()
	if PauseCoop.R().est_hote():      # le délai est tenu par l'hôte
		for id: int in _votes.keys():
			_votes[id]["reste"] = float(_votes[id]["reste"]) - dt
			if float(_votes[id]["reste"]) <= 0.0:
				_clore(id, false, "délai dépassé")

func _unhandled_key_input(e: InputEvent) -> void:
	if courant.is_empty() or bool(courant["repondu"]) or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).keycode
	if k == KEY_O or k == KEY_ENTER:
		repondre(true)
	elif k == KEY_N or k == KEY_ESCAPE:
		repondre(false, "refusé")
	else:
		return
	get_viewport().set_input_as_handled()

func _maj_texte() -> void:
	if courant.is_empty():
		_texte.visible = false
		return
	var qui := "Vous proposez" if int(courant["auteur"]) == PauseCoop.R().mon_id() else "Joueur %d propose" % int(courant["auteur"])
	var que: String = String(courant["donnees"].get("libelle", courant["type"]))
	var fin := "(en attente des autres, %d s)" % ceili(courant["reste"]) if bool(courant["repondu"]) \
		else "[O] accepter   [N] refuser  (%d s)" % ceili(courant["reste"])
	_texte.text = "%s : %s\n%s" % [qui, que, fin]
	_texte.visible = true
