extends Node3D
## Bourse laissée par un ennemi vaincu : on la ramasse en marchant dessus.

var joueur: CharacterBody3D
var hud: Control
var contenu := {}  # identifiant → nombre
var _t := 0.0

func _ready() -> void:
	var bourse := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.16, 0.18)
	bourse.mesh = b
	bourse.material_override = Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2.ONE, Color(1.4, 1.2, 1.0))
	bourse.position.y = 0.08
	add_child(bourse)
	# petite lueur dorée pour qu'on la repère dans la neige
	var eclat := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3.ONE * 0.05
	eclat.mesh = q
	eclat.material_override = Palette.lueur(Color(2.4, 1.8, 0.6))
	eclat.position.y = 0.2
	add_child(eclat)

func _process(dt: float) -> void:
	_t += dt
	get_child(1).position.y = 0.22 + sin(_t * 3.0) * 0.04
	if joueur.global_position.distance_to(global_position) < 1.3:
		for id in contenu:
			joueur.inventaire.ajouter(id, contenu[id])
			hud.avis("+ %d %s" % [contenu[id], joueur.inventaire.nom(id)])
		Sons.jouer(self, ["handleCoins", "handleCoins2"], -4.0)
		queue_free()
