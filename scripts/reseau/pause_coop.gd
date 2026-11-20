class_name PauseCoop
extends RefCounted
## LOT 3 — « pause » des menus et fenêtres, compatible coop. Remplace `get_tree().paused = true/false` dans les fenêtres.
##   Solo (pas en ligne) : EXACTEMENT l'ancien comportement (le monde est mis en pause / repris).
##   Coop : le monde ne s'arrête JAMAIS ; le joueur local est seulement « occupé » (joueur.en_dialogue = true tant qu'au moins une
##   source est ouverte : ni marche ni combat, vulnérable) et la fenêtre reste affichée.
## API : PauseCoop.demander_pause(source) / liberer(source) / en_pause(arbre) / occupe().
##   `source` = le nœud qui ouvre (fenêtre, menu) ; plusieurs sources peuvent être ouvertes en même temps.
##   Les lectures `get_tree().paused` (« un menu est-il ouvert ? ») deviennent `PauseCoop.en_pause(get_tree())`.

static var _sources: Array = []        # sources actives en coop (nœuds)
static var _avait_dialogue := false    # en_dialogue valait déjà vrai quand la première source s'est ouverte

## Autoload « Reseau » par son chemin : les scripts de tests (--script) compilent avant les autoloads, l'identifiant global y est inconnu.
## Opti cpu_scripts (2026-11-20) : appelé plusieurs fois par pas et par PNJ ; le nœud Reseau (autoload) est gardé tant qu'il est dans
## l'arbre (sinon recherché comme avant : même résultat).
static var _reseau_garde: Node
static func R() -> Node:
	if is_instance_valid(_reseau_garde) and _reseau_garde.is_inside_tree():
		return _reseau_garde
	_reseau_garde = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Reseau")
	return _reseau_garde

static func coop() -> bool:
	var r := R()
	return r != null and r.est_en_ligne()

## Joueur local (groupe « joueur_local », posé par joueur.gd).
static func joueur_local(arbre: SceneTree) -> Node:
	return arbre.get_first_node_in_group("joueur_local") if arbre != null else null

static func demander_pause(source: Node) -> void:
	var arbre := source.get_tree()
	if arbre == null:
		return
	if not coop():
		arbre.paused = true
		return
	_purger()
	if source in _sources:
		return
	if _sources.is_empty():
		var j := joueur_local(arbre)
		if j != null:
			_avait_dialogue = bool(j.get("en_dialogue"))
			j.set("en_dialogue", true)
	_sources.append(source)

static func liberer(source: Node) -> void:
	var arbre := source.get_tree() if is_instance_valid(source) else null
	if not coop():
		if arbre != null:
			arbre.paused = false
		return
	_sources.erase(source)
	_purger()
	if _sources.is_empty() and arbre != null:
		var j := joueur_local(arbre)
		if j != null and not _avait_dialogue and not bool(j.get("a_terre")):
			j.set("en_dialogue", false)

## Menu ouvert ? Solo : l'arbre est en pause ; coop : au moins une fenêtre ouverte (le monde, lui, tourne).
static func en_pause(arbre: SceneTree) -> bool:
	return arbre.paused or occupe()

static func occupe() -> bool:
	_purger()
	return not _sources.is_empty()

static func _purger() -> void:
	for i in range(_sources.size() - 1, -1, -1):
		if not is_instance_valid(_sources[i]):
			_sources.remove_at(i)

## Remise à zéro (tests, retour au titre).
static func reinitialiser() -> void:
	_sources.clear()
	_avait_dialogue = false
