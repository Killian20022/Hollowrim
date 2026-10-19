extends Node3D
## Objet avec lequel on agit par la touche E (corps à fouiller, levier, porte, inscription).
## Passe par la boîte de dialogue : `action` renvoie les lignes à afficher (ou [] : rien
## à lire, l'action suffit). Propriétés à poser avant add_child : joueur, dialogue,
## nom, verbe, action ; facultatif : rayon, condition.

var joueur: CharacterBody3D
var dialogue: Control
var nom := ""
var verbe := ""                  # « Fouiller le corps d’Eirik »
var action: Callable             # () -> Array
var condition: Callable          # () -> bool ; l'objet n'est proposé que si vrai
var rayon := 2.3
var actif := true
var unique := false             # disparaît après usage

func nom_affiche() -> String:
	return nom

func texte_action() -> String:
	return verbe

func parler() -> Array:
	var lignes: Array = action.call() if action.is_valid() else []
	if unique:
		actif = false
		dialogue.retirer_invite(self)
	return lignes

func _process(_dt: float) -> void:
	var ok: bool = actif and not joueur.mort and (not condition.is_valid() or condition.call())
	if ok:
		var cam: Camera3D = joueur.camera
		var vers := global_position - cam.global_position
		ok = vers.length() < rayon + 1.0 and Vector2(joueur.global_position.x - global_position.x, joueur.global_position.z - global_position.z).length() < rayon
		ok = ok and (-cam.global_transform.basis.z).dot(vers.normalized()) > 0.7
	if ok:
		dialogue.inviter(self)
	else:
		dialogue.retirer_invite(self)
