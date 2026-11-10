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

## Perf : la place compte ~100 objets Interactif ; leur _process (distance, cône de vue) ne tourne que pour ceux à moins de `rayon` + 1,5 m du joueur.
## Un balayage toutes les 0,1 s allume / éteint leur traitement (marge : 1,5 m ≈ 0,2 s de course) ; un objet éteint retire son invite.
static var _tous: Array = []
static var _balayage_arme := false

func _ready() -> void:
	_tous.append(self)
	if not _balayage_arme:
		_balayage_arme = true
		_balayer(get_tree())

static func _balayer(arbre: SceneTree) -> void:
	var vivants := false
	var i := 0
	while i < _tous.size():
		var n = _tous[i]
		if not is_instance_valid(n):
			_tous.remove_at(i)
			continue
		i += 1
		vivants = true
		var j: Node3D = n.joueur
		if j == null or not n.is_inside_tree():
			continue
		var dx: float = j.global_position.x - n.global_position.x
		var dz: float = j.global_position.z - n.global_position.z
		var r: float = n.rayon + 1.5
		var loin: bool = dx * dx + dz * dz > r * r
		if loin and n.is_processing():
			n.set_process(false)
			if n.dialogue != null and is_instance_valid(n.dialogue):
				n.dialogue.retirer_invite(n)
		elif not loin and not n.is_processing():
			n.set_process(true)
	if vivants:
		arbre.create_timer(0.1).timeout.connect(_balayer.bind(arbre))
	else:
		_balayage_arme = false

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
