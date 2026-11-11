extends Control
## Œil de détection (furtivité, docs/COMBAT.md « Furtivité ») : un petit œil en pixels au-dessus des raccourcis, visible seulement
## quand le joueur est accroupi ou repéré. Fermé = personne ne le remarque ; il s'ouvre et rougit à mesure que la vigilance
## (joueur.detection, 0..1) monte ; plein = repéré. Rien d'autre à l'écran : pas de barre, pas de chiffre.
const FOND := Color("#0b0f1a")
const PARCHEMIN := Color("#e8e0c8")
const FER := Color("#56627a")
const OR := Color("#e8a64a")
const ROUGE := Color("#c8382a")
const LARG := 13
## Demi-largeur du blanc de l'œil à chaque rangée, de la plus haute (0) à la plus basse (6) ; ouverture = rangées dessinées.
const FORME := [2, 4, 6, 6, 6, 4, 2]

var joueur: Node
var _alpha := 0.0
var _ouvert := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	if joueur == null or not is_instance_valid(joueur):
		return
	var lu: Variant = joueur.get("detection")   # null : joueur factice des tests de HUD
	var d := float(lu) if lu != null else 0.0
	var actif: bool = (joueur.get("accroupi") == true or d > 0.02) and joueur.get("mort") != true
	_alpha = move_toward(_alpha, 1.0 if actif else 0.0, 4.0 * dt)
	_ouvert = move_toward(_ouvert, d, 3.0 * dt)
	queue_redraw()

func _draw() -> void:
	if _alpha < 0.02:
		return
	var d := clampf(_ouvert, 0.0, 1.0)
	var centre := Vector2(floorf(size.x * 0.5), size.y - 62.0)
	var x0 := centre.x - floorf(LARG * 0.5)
	var rangees := 1 if d < 0.03 else (3 if d < 0.35 else (5 if d < 0.7 else 7))
	var debut := (7 - rangees) >> 1
	var couleur_iris := OR if d < 0.7 else ROUGE
	draw_rect(Rect2(x0 - 2.0, centre.y - 2.0, LARG + 4.0, 11.0), Color(FOND, 0.35 * _alpha))
	for r in rangees:
		var ligne := debut + r
		var demi: int = FORME[ligne] if rangees > 1 else 6
		var y := centre.y + float(ligne)
		draw_rect(Rect2(centre.x - demi, y, demi * 2 + 1, 1.0), Color(FER if rangees == 1 else PARCHEMIN, _alpha))
		if rangees > 1:   # contour sombre aux deux bouts de la rangée
			draw_rect(Rect2(centre.x - demi - 1, y, 1.0, 1.0), Color(FOND, _alpha))
			draw_rect(Rect2(centre.x + demi + 1, y, 1.0, 1.0), Color(FOND, _alpha))
	if rangees >= 3:
		var iris := 3 if rangees >= 5 else 1
		draw_rect(Rect2(centre.x - floorf(iris * 0.5), centre.y + 3.0 - floorf(iris * 0.5), iris, iris), Color(couleur_iris, _alpha))
		draw_rect(Rect2(centre.x, centre.y + 3.0, 1.0, 1.0), Color(FOND, _alpha))
