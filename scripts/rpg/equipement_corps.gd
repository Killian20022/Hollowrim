class_name EquipementCorps
extends RefCounted
## Équipement de corps (Q3 b) : tete, torse, mains, pieds, cou, anneau. Les mains (armes, bouclier, sorts, torche) restent
## à EquipementMains (ne pas fusionner : docs/RPG.md §6). Contrat : docs/RPG.md §4.
## Un objet équipé RESTE dans le sac (il compte dans le poids, Q5) ; s'il quitte le sac (vendu, lâché, déposé), il est
## retiré de son emplacement automatiquement. Armure non visible sur le héros pour l'instant (Q4 a).
## LOT 0 : API et règles de base ; LOT A : effets en jeu (formule d'armure dans joueur.recevoir_coup, ensembles…).

signal change(emplacement: String)

var inventaire: Inventaire = null
var emplacements := {"tete": "", "torse": "", "mains": "", "pieds": "", "cou": "", "anneau": ""}

func _init(inv: Inventaire = null) -> void:
	lier(inv)

func lier(inv: Inventaire) -> void:
	if inventaire != null and inventaire.change.is_connected(_sur_sac):
		inventaire.change.disconnect(_sur_sac)
	inventaire = inv
	if inventaire != null:
		inventaire.change.connect(_sur_sac)

## "" si l'objet peut être porté, sinon la raison (message lisible).
func refus(id: String) -> String:
	if not Inventaire.connu(id):
		return "Objet inconnu."
	var e := Inventaire.emplacement_de(id)
	if e == "" or not emplacements.has(e):
		return "%s ne se porte pas." % Inventaire.objet(id).get("nom", id)
	if inventaire != null and not inventaire.a(id):
		return "Vous n'avez pas cet objet."
	return ""

## Équipe `id` à son emplacement (remplace l'objet qui y était) : "" si fait, sinon la raison.
func equiper(id: String) -> String:
	var r := refus(id)
	if r != "":
		return r
	var e := Inventaire.emplacement_de(id)
	if emplacements[e] == id:
		return ""
	emplacements[e] = id
	change.emit(e)
	return ""

func retirer(emplacement: String) -> void:
	if emplacements.get(emplacement, "") == "":
		return
	emplacements[emplacement] = ""
	change.emit(emplacement)

func objet_a(emplacement: String) -> String:
	return String(emplacements.get(emplacement, ""))

func est_equipe(id: String) -> bool:
	return id != "" and emplacements.values().has(id)

## Somme des points d'armure portés (avant multiplicateur de la compétence Armure : lot A).
func armure_totale() -> float:
	var t := 0.0
	for e in emplacements:
		if emplacements[e] != "":
			t += float(Inventaire.objet(emplacements[e]).get("armure", 0.0))
	return t

## Somme des effets portés (clés communes : docs/RPG.md §3), lue par Progression.bonus().
func effets_totaux() -> Dictionary:
	var t := {}
	for e in emplacements:
		if emplacements[e] == "":
			continue
		var ef: Variant = Inventaire.objet(emplacements[e]).get("effets", {})
		if ef is Dictionary:
			for k in ef:
				if typeof(ef[k]) in [TYPE_INT, TYPE_FLOAT]:
					t[k] = float(t.get(k, 0.0)) + float(ef[k])
	return t

## Le sac a changé : un objet porté qui n'y est plus est retiré.
func _sur_sac() -> void:
	if inventaire == null:
		return
	for e in emplacements:
		if emplacements[e] != "" and not inventaire.a(emplacements[e]):
			emplacements[e] = ""
			change.emit(e)

func exporter() -> Dictionary:
	return emplacements.duplicate()

## Relit les emplacements (après l'inventaire) ; objet inconnu, absent du sac ou au mauvais emplacement : ignoré.
func importer(d: Dictionary) -> void:
	for e in emplacements:
		emplacements[e] = ""
	for e in d:
		var id := Inventaire.alias(String(d[e]))
		if emplacements.has(e) and id != "" and refus(id) == "" and Inventaire.emplacement_de(id) == e:
			emplacements[e] = id
	change.emit("")
