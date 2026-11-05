class_name ZoneSon
extends Node
## Pilote la table de mixage selon la situation du joueur (voir Mixage) : reverb de la salle où il se trouve
## (grotte / crypte / maison, dehors = sec) et ducking de la musique pendant un dialogue ou un finisher.
## Le monde pose `monde` avant add_child ; l'état est relu 4 fois par seconde (les transitions sont des fondus de Mixage).

var monde: Node3D
var _acc := 0.0

## Salle où se trouve `pos` : "dehors", "grotte", "crypte" ou "maison".
static func zone_en(monde_: Node, pos: Vector3) -> String:
	if monde_ == null:
		return "dehors"
	var tertre = monde_.get("tertre")
	if tertre != null and is_instance_valid(tertre) and tertre.get("dedans"):
		return "crypte"
	var grotte = monde_.get("grotte_acces")
	if grotte != null and is_instance_valid(grotte) and grotte.get("dedans"):
		return "grotte"
	var village = monde_.get("village")
	if village != null and village.get("interieurs") != null:
		for ip: Interieur in village.interieurs:
			if is_instance_valid(ip) and ip.is_inside_tree() and ip.dedans(ip.to_local(pos), 0.0) and absf(pos.y - ip.global_position.y) < 3.0:
				return "maison"
	return "dehors"

func _process(dt: float) -> void:
	_acc += dt
	if _acc < 0.25 or monde == null or monde.get("joueur") == null:
		return
	_acc = 0.0
	var j: Node3D = monde.joueur
	var z := zone_en(monde, j.global_position)
	if z != Mixage.zone:
		Mixage.zone_vers(z)
	Mixage.duck("dialogue", bool(j.get("en_dialogue")))
	var mains = j.get("mains")
	Mixage.duck("finisher", mains != null and mains.get("combat") != null and mains.combat.etat == EtatCombat.FINISHER)

func _exit_tree() -> void:
	Mixage.reinitialiser()
