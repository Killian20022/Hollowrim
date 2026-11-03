extends Node3D
## Pilote de la flamme de torche en gros pixels (shaders/flamme_pixels.gdshader). Posé au PIED de la flamme par Torche.construire,
## il vit avec la torche : 1re personne comme 3e personne (même code, aucune entrée clavier : seule la vitesse de la flamme dans le monde compte).
##   - vitesse = déplacement réel du nœud entre deux images (lissée), donc marche, course, virage de la caméra, balancement de la main,
##     animation du corps, saut et chute : tout couche la flamme ;
##   - ressort amorti (légèrement sous-amorti) : la pointe est tirée vers « contre la vitesse », dépasse un peu et revient ; à l'arrêt elle
##     se redresse et vacille ;
##   - atterrissage / départ de saut : saut de vitesse verticale → « secousse » qui agite la flamme un instant ;
##   - braises détachées en traînée (particules monde, carrés de gerbe_pixels) : plus nombreuses quand ça va vite ;
##   - lumière : vacille en accord avec la taille de la flamme (énergie lissée, déplacement léger), sans stroboscope.
## Lu par mains.gd et corps_joueur.gd : `facteur_lumiere` (≈ 1) multiplie l'énergie de base de la lumière.

const HAUT_M := 0.196            # hauteur nominale de la flamme au repos (m) = cases_h × cell_m
const SOUPLESSE := 0.05          # m de recul de la pointe par m/s de vitesse
const MAX_RECUL := 0.25          # m
const RAIDEUR := 15.0            # rad/s du ressort
const AMORTI := 0.42             # rapport d'amortissement (< 1 : un peu de rebond)

var mat: ShaderMaterial
var lumiere: OmniLight3D
var halo: Node3D
var lumiere_base := Vector3.ZERO
var halo_base := Vector3.ZERO
var braises: GPUParticles3D
## Multiplicateur de l'énergie de la lumière (≈ 0,85 à 1,15), lu par le propriétaire de la torche.
var facteur_lumiere := 1.0

var _prec := Vector3.ZERO
var _a_prec := false
var _vit := Vector3.ZERO
var _pointe := Vector3.ZERO     # recul courant (m, monde)
var _pointe_v := Vector3.ZERO
var _secousse := 0.0
var _vit_y_prec := 0.0
var _lum := 1.0
var _t := 0.0

func _process(dt: float) -> void:
	if dt <= 0.0:
		return
	if not is_visible_in_tree():
		_a_prec = false
		return
	_t += dt
	var pos := global_position
	if not _a_prec or pos.distance_to(_prec) > 6.0 * dt * 10.0 + 1.0:
		_prec = pos   # première image, torche rangée puis ressortie, téléportation : pas de vitesse fantôme
		_a_prec = true
		_vit = Vector3.ZERO
		_pointe = Vector3.ZERO
		_pointe_v = Vector3.ZERO
	var v := (pos - _prec) / dt
	_prec = pos
	_vit = _vit.lerp(v, 1.0 - exp(-16.0 * dt))
	# secousse : saut brusque de la vitesse verticale (décollage, atterrissage, choc)
	var acc_y := absf(_vit.y - _vit_y_prec) / dt
	_vit_y_prec = _vit.y
	_secousse = maxf(_secousse - dt * 2.2, 0.0)
	if acc_y > 30.0:
		_secousse = minf(_secousse + clampf((acc_y - 30.0) / 120.0, 0.0, 0.8), 1.2)
	# ressort : cible = recul opposé à la vitesse (la composante verticale pèse moins : chute = flamme qui s'allonge)
	var cible := -Vector3(_vit.x, _vit.y * 0.6, _vit.z) * SOUPLESSE
	if cible.length() > MAX_RECUL:
		cible = cible.normalized() * MAX_RECUL
	var w := RAIDEUR
	_pointe_v += ((cible - _pointe) * w * w - _pointe_v * 2.0 * AMORTI * w) * dt
	_pointe += _pointe_v * dt
	if _pointe.length() > MAX_RECUL * 1.25:
		_pointe = _pointe.normalized() * MAX_RECUL * 1.25
	var haut := HAUT_M
	# couchée : elle perd de la hauteur et s'étire (la longueur est gardée en partie) ; en chute elle s'allonge
	var h_rec := Vector2(_pointe.x, _pointe.z).length()
	haut *= clampf(1.0 - h_rec * 1.1, 0.5, 1.0)
	haut += clampf(_pointe.y, -0.12, 0.1)
	var pointe := Vector3(_pointe.x, haut, _pointe.z)
	var agit := clampf(0.15 + _vit.length() * 0.05 + _secousse, 0.0, 1.4)
	mat.set_shader_parameter("pointe", pointe)
	mat.set_shader_parameter("agitation", agit)
	# lumière : taille de la flamme + vacillement lent par paliers (14/s) ; position suit la pointe à moitié
	var palier := floorf(_t * 14.0)
	var scint := fposmod(sin(palier * 12.9898) * 43758.5453, 1.0)
	var cible_l := 1.0 + (haut / HAUT_M - 1.0) * 0.5 + sin(_t * 11.0) * 0.05 + sin(_t * 23.0) * 0.03 + (scint - 0.5) * 0.12 + _secousse * 0.06 * sin(_t * 22.0)
	_lum = lerpf(_lum, cible_l, 1.0 - exp(-18.0 * dt))
	facteur_lumiere = _lum
	if lumiere != null:
		lumiere.position = lumiere_base + to_local_dir(Vector3(_pointe.x, 0.0, _pointe.z)) * 0.45 + Vector3(0.0, (haut - HAUT_M) * 0.5, 0.0)
	if halo != null:
		halo.position = halo_base + to_local_dir(Vector3(_pointe.x, 0.0, _pointe.z)) * 0.5
	if braises != null:
		braises.amount_ratio = clampf(0.35 + _vit.length() * 0.2, 0.35, 1.0)

## Vecteur monde → repère du parent (sans l'échelle ni la translation).
func to_local_dir(d: Vector3) -> Vector3:
	var p := get_parent() as Node3D
	return p.global_transform.basis.orthonormalized().inverse() * d if p != null else d
