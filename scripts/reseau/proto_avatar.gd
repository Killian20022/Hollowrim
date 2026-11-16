class_name ProtoAvatar
extends RefCounted
## Lot 1 (prototype) : avatar d'un joueur DISTANT = une instance de joueur.gd avec est_local = false (aucune entrée lue, aucune
## caméra courante, corps à la 3e personne : corps_joueur.gd + CorpsCoupsTps). Nom « Joueur_<peer_id> ». Sa position vient du réseau.

const JOUEUR := preload("res://scripts/joueur.gd")

var id := 0
var noeud: CharacterBody3D
var tampon := ProtoTampon.new()

static func creer(parent: Node, peer_id: int, pos: Vector3) -> ProtoAvatar:
	var a := ProtoAvatar.new()
	a.id = peer_id
	a.noeud = CharacterBody3D.new()
	a.noeud.set_script(JOUEUR)
	a.noeud.set("est_local", false)   # AVANT add_child (lu par _ready)
	a.noeud.name = "Joueur_%d" % peer_id
	a.noeud.position = pos
	parent.add_child(a.noeud)
	var r := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Reseau")
	if r != null:
		r.registre.definir_noeud(peer_id, a.noeud)   # pertinence par distance, « joueur le plus proche »
	return a

## Instantané reçu : position, lacet, tangage de la tête, vitesse, accroupi.
func recevoir(pos: Vector3, lacet: float, tangage: float, vel: Vector3, accroupi: bool) -> void:
	tampon.pousser(pos, lacet, [tangage, vel, accroupi])

## Une image physique : place l'avatar à la position interpolée (le corps lit velocity / is_on_floor pour sa marche).
func avancer() -> void:
	var r := tampon.lire()
	if r.is_empty() or not is_instance_valid(noeud):
		return
	var pos: Vector3 = r["pos"]
	var ex: Array = r["extra"]
	noeud.global_position = pos
	noeud.rotation.y = r["lacet"]
	noeud.tete.rotation.x = ex[0]
	# is_on_floor() n'est vrai qu'après un move_and_slide : petit pas vers le bas puis retour à la position exacte
	noeud.velocity = Vector3(0.0, -1.0, 0.0)
	noeud.move_and_slide()
	noeud.global_position = pos
	noeud.velocity = ex[1]
	noeud.set("accroupi", ex[2])
