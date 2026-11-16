class_name StubLot2a
extends RefCounted
## STUB du lot 2a (Replicateur / Rejoindre) : n'existe que tant que les autoloads `Replicateur` et `Rejoindre` (branche multi/lot2a) ne sont pas
## fusionnés. ReseauMondeVivant l'utilise UNIQUEMENT si /root/Replicateur est absent. Même contrat que 2a :
##   enregistrer(id, noeud, fournisseur: Callable() -> Dictionary, appliquer: Callable(etat: Dictionary), pertinence_m)
##   contributeur(nom, exporter, importer)
## Logique volontairement minimale (aucune pertinence, aucune interpolation : dernier état reçu appliqué à chaque image) : de quoi tester en
## 2 instances avant la fusion. À SUPPRIMER (avec ce fichier) à la fusion avec 2a : ReseauMondeVivant bascule seul sur les vrais autoloads.

const TYPE_ETAT := "stub_etat"
const PERIODE := 1.0 / 15.0

var _entites := {}   # id -> {noeud, fournisseur, appliquer}
var _recu := {}      # id -> dernier état reçu
var _t := 0.0
var contributeurs := {}

func _init() -> void:
	Reseau.abonner(TYPE_ETAT, _sur_etat)

func enregistrer(id: Variant, noeud: Node, fournisseur: Callable, appliquer: Callable, _pertinence_m := 90.0) -> void:
	_entites[id] = {"noeud": noeud, "fournisseur": fournisseur, "appliquer": appliquer}

func retirer(id: Variant) -> void:
	_entites.erase(id)

func est_marionnette() -> bool:
	return Reseau.est_en_ligne() and not Reseau.est_hote()

func contributeur(nom: String, exporter: Callable, importer: Callable) -> void:
	contributeurs[nom] = [exporter, importer]

## Appelé à chaque image par ReseauMondeVivant.
func tick(dt: float) -> void:
	if not Reseau.est_en_ligne():
		return
	if Reseau.est_hote():
		_t += dt
		if _t < PERIODE or Reseau.joueurs().size() < 2:
			return
		_t = 0.0
		var paquet := {}
		for id in _entites.keys():
			var e: Dictionary = _entites[id]
			if not is_instance_valid(e["noeud"]):
				_entites.erase(id)
				continue
			paquet[id] = (e["fournisseur"] as Callable).call()
		Reseau.envoyer_evenement(TYPE_ETAT, 0, paquet)
	else:
		for id in _recu:
			if _entites.has(id) and is_instance_valid(_entites[id]["noeud"]):
				(_entites[id]["appliquer"] as Callable).call(_recu[id])

func _sur_etat(_exp: int, _id: Variant, donnees: Variant) -> void:
	if not Reseau.est_hote() and donnees is Dictionary:
		_recu.merge(donnees, true)
