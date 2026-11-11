class_name Formation
extends RefCounted
## LEÇONS DES MAÎTRES (gameplay/economie, docs/ECONOMIE.md) : un puits d'or modeste et utile. Quelques villageois enseignent UNE
## compétence (data/marchands.json, section « formations ») : une leçon payée = exactement un niveau de plus (Competences, sans perk
## ni bonus de repos), jusqu'au plafond du maître ; au plus `lecons_par_periode` leçons par maître et par période de
## `renouvellement_jours` jours de jeu (horloge Marchand.heures, comme le réassort). Prix = prix_fixe + prix_niveau x niveau actuel.
## Branché par ServicesPnj.options (une ligne) : choix « Leçon : <compétence> (<prix> pièces) » sur la dernière réplique ; le maître
## répond par une réplique (réussite ou refus expliqué), puis le choix revient. État sauvegardé par Marchand.exporter (clé « formations »).

## maître -> {periode, n} : leçons données pendant la période.
static var lecons := {}

static func donnees() -> Dictionary:
	var d: Variant = Marchand.donnees().get("formations", {})
	return d if d is Dictionary else {}

static func maitre(id: String) -> Dictionary:
	var m: Variant = donnees().get("maitres", {}).get(id, {})
	return m if m is Dictionary else {}

static func est_maitre(id: String) -> bool:
	return not maitre(id).is_empty()

static func competence_de(id: String) -> String:
	return String(maitre(id).get("competence", ""))

static func nom_competence(id: String) -> String:
	var c := Progression.interne(Progression.canonique(competence_de(id)))
	return String(Competences.NOMS.get(c, c))

static func periode() -> int:
	return floori(Marchand.heures / (24.0 * maxf(0.01, float(donnees().get("renouvellement_jours", 2)))))

## Leçons encore possibles chez ce maître pendant la période.
static func restantes(id: String) -> int:
	var e: Dictionary = lecons.get(id, {})
	var faites := int(e.get("n", 0)) if int(e.get("periode", -1)) == periode() else 0
	return maxi(0, int(donnees().get("lecons_par_periode", 3)) - faites)

static func prix(prog: Progression, id: String) -> int:
	var niv := prog.competence(competence_de(id)) if prog != null else Competences.DEPART
	return int(donnees().get("prix_fixe", 40)) + int(donnees().get("prix_niveau", 6)) * niv

## "" si la leçon est possible, sinon la réplique du maître qui refuse.
static func refus(prog: Progression, inv: Inventaire, id: String) -> String:
	if prog == null or inv == null or not est_maitre(id):
		return "Pas maintenant."
	var m := maitre(id)
	if prog.competence(competence_de(id)) >= int(m.get("max", 50)):
		return String(m.get("refus_max", "Je ne peux plus rien t’apprendre. Va trouver meilleur maître que moi."))
	if restantes(id) <= 0:
		return String(m.get("refus_fatigue", "Assez pour aujourd’hui. Reviens dans deux jours."))
	if inv.pieces < prix(prog, id):
		return "Une leçon, c’est %d pièces. Reviens quand ta bourse sera plus lourde." % prix(prog, id)
	return ""

## Donne la leçon : paie, +1 niveau. Renvoie "" si faite, sinon la réplique de refus.
static func prendre_lecon(prog: Progression, inv: Inventaire, id: String) -> String:
	var r := refus(prog, inv, id)
	if r != "":
		return r
	var p := prix(prog, id)
	inv.retirer("pieces", p)
	var c := Progression.interne(Progression.canonique(competence_de(id)))
	var cp: Competences = prog.competences
	var n0 := int(cp.niveaux[c])
	cp.pratiquer(c, maxf(0.0, Competences.seuil(n0) - float(cp.experience[c])) + 0.001)
	if int(cp.niveaux[c]) > n0 + 1:      # garde-fou : jamais plus d'un niveau par leçon
		cp.niveaux[c] = n0 + 1
		cp.experience[c] = 0.0
	var e: Dictionary = lecons.get(id, {})
	if int(e.get("periode", -1)) != periode():
		e = {"periode": periode(), "n": 0}
	e["n"] = int(e["n"]) + 1
	lecons[id] = e
	return ""

## Choix de dialogue du maître `id_pnj` (ServicesPnj.options) ; `avis` : Callable(texte) pour le HUD (facultatif).
static func options(id_pnj: String, joueur: Node, avis: Callable = Callable()) -> Array:
	if not est_maitre(id_pnj) or joueur == null:
		return []
	var prog: Progression = joueur.get("progression")
	if prog == null:
		return []
	var texte := "Leçon : %s (%d pièces)" % [nom_competence(id_pnj), prix(prog, id_pnj)]
	return [{"texte": texte, "action": _lecon.bind(id_pnj, joueur, avis)}]

## Action du choix « Leçon » : renvoie la réplique du maître (réussite ou refus).
static func _lecon(id_pnj: String, joueur: Node, avis: Callable) -> Array:
	var prog: Progression = joueur.get("progression")
	var inv: Inventaire = joueur.get("inventaire")
	var p := prix(prog, id_pnj)
	var r := prendre_lecon(prog, inv, id_pnj)
	if r != "":
		return [r]
	var niv := prog.competence(competence_de(id_pnj))
	if avis.is_valid():
		avis.call("%s : niveau %d (-%d pièces)" % [nom_competence(id_pnj), niv, p])
	var lignes: Array = maitre(id_pnj).get("reussite", ["Bien. Tu progresses."])
	return [String(lignes[niv % lignes.size()])]

static func exporter() -> Dictionary:
	return lecons.duplicate(true)

static func importer(d: Dictionary) -> void:
	lecons = {}
	for id: String in d:
		if est_maitre(id) and d[id] is Dictionary:
			lecons[id] = {"periode": int(d[id].get("periode", 0)), "n": int(d[id].get("n", 0))}

static func reinitialiser() -> void:
	lecons = {}
