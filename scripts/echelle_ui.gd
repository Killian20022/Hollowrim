class_name EchelleUi
## Échelle de l'interface : un facteur ENTIER (pixels nets, police pixel sans flou).
## La maquette de l'interface est faite pour 480x270 : on garde k = le plus grand entier tel que
## l'écran logique (taille / k) fasse au moins 480x270.
##   480x270 → ×1 (480x270)   640x360 → ×1 (640x360)   960x540 → ×2 (480x270)   1280x720 → ×2 (640x360)
## Chaque Control d'interface appelle appliquer(self) chaque image (ne fait rien si rien n'a changé),
## puis place ses éléments à partir de `size` (coordonnées relatives : centre, bas, droite).

const BASE := Vector2(480, 270)

static func facteur(ecran: Vector2) -> int:
	return maxi(1, mini(int(ecran.x / BASE.x), int(ecran.y / BASE.y)))

## Renvoie true si la taille logique a changé (il faut replacer les éléments).
static func appliquer(c: Control) -> bool:
	var ecran := c.get_viewport().get_visible_rect().size
	var k := float(facteur(ecran))
	var taille := (ecran / k).floor()
	if c.scale == Vector2(k, k) and c.size == taille and c.position == Vector2.ZERO:
		return false
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.scale = Vector2(k, k)
	c.size = taille
	return true
