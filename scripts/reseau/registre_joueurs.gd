class_name RegistreJoueurs
extends RefCounted
## Registre des joueurs : identifiant réseau (peer id, hôte = 1) -> nœud du personnage + infos libres (nom, couleur…).
## Solo : un seul joueur, id 1. Tenu à jour par l'autoload Reseau (connexions / déconnexions) ; le jeu y range
## le nœud de chaque avatar (`Reseau.registre.definir_noeud(id, noeud)`).

signal joueur_ajoute(id: int)
signal joueur_retire(id: int)

var _noeuds := {}   # id -> Node (peut être null tant que l'avatar n'existe pas)
var _infos := {}    # id -> Dictionary

func ajouter(id: int, infos: Dictionary = {}) -> void:
	if _infos.has(id):
		_infos[id].merge(infos, true)
		return
	_noeuds[id] = null
	_infos[id] = infos.duplicate()
	joueur_ajoute.emit(id)

func retirer(id: int) -> void:
	if not _infos.has(id):
		return
	_noeuds.erase(id)
	_infos.erase(id)
	joueur_retire.emit(id)

func vider() -> void:
	for id in ids():
		retirer(id)

func a(id: int) -> bool:
	return _infos.has(id)

func definir_noeud(id: int, noeud: Node) -> void:
	if not _infos.has(id):
		ajouter(id)
	_noeuds[id] = noeud

## Nœud du joueur `id` (null s'il n'existe pas ou n'a plus d'instance valide).
func noeud(id: int) -> Node:
	var n: Node = _noeuds.get(id)
	return n if is_instance_valid(n) else null

func infos(id: int) -> Dictionary:
	return _infos.get(id, {})

func definir_info(id: int, cle: String, valeur: Variant) -> void:
	if _infos.has(id):
		_infos[id][cle] = valeur

## Identifiants triés (hôte en premier).
func ids() -> Array[int]:
	var r: Array[int] = []
	for id: int in _infos:
		r.append(id)
	r.sort()
	return r

func taille() -> int:
	return _infos.size()
