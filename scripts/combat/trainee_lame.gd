class_name TraineeLame
extends MeshInstance3D
## Traînée de lame pixel art : ruban entre les positions successives de la garde et de la pointe pendant la frappe et
## le suivi (repère des mains, donc de la caméra : la traînée accompagne la vue comme le viewmodel). Les échantillons
## sont pris à PAS FIXE (mains.gd, grille du tracé 1/240 s) : arc lisse quel que soit le nombre d'images par seconde.
## Chaque échantillon s'efface en DUREE s ; le shader (shaders/trainee_lame.gdshader) quantifie l'opacité en 4 paliers
## et 3 tons (couleur de l'arme : DonneesArme.couleur_trainee / couleur_trainee_coeur).

const SHADER := preload("res://shaders/trainee_lame.gdshader")
## Durée de vie d'un échantillon (s).
const DUREE := 0.1
## Échantillons gardés au plus (0,1 s à 240 Hz + marge).
const MAX := 64

var _ech: Array = []   # [instant, garde, pointe]
var _horloge := 0.0
var _im := ImmediateMesh.new()
var _mat := ShaderMaterial.new()

func _init() -> void:
	mesh = _im
	_mat.shader = SHADER
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	top_level = false

func couleurs(base: Color, vif: Color) -> void:
	_mat.set_shader_parameter("couleur", base)
	_mat.set_shader_parameter("coeur", vif)

## Ajoute un échantillon (repère du parent) daté de `retard` s avant l'instant courant (échantillons sous-image).
func ajouter(garde: Vector3, pointe: Vector3, retard := 0.0) -> void:
	_ech.append([_horloge - retard, garde, pointe])
	if _ech.size() > MAX:
		_ech.pop_front()

## Coupe la traînée (rupture : nouveau coup, rebond) : les échantillons restants s'effacent, sans relier au suivant.
func couper() -> void:
	if not _ech.is_empty() and _ech[_ech.size() - 1].size() == 3:
		_ech[_ech.size() - 1].append(true)

func vider() -> void:
	_ech.clear()
	_im.clear_surfaces()

## Avance l'horloge, oublie les échantillons effacés et reconstruit le ruban.
func avancer(dt: float) -> void:
	_horloge += dt
	while not _ech.is_empty() and _horloge - float(_ech[0][0]) > DUREE:
		_ech.pop_front()
	_im.clear_surfaces()
	if _ech.size() < 2:
		return
	var paires := []
	for i in range(1, _ech.size()):
		if (_ech[i - 1] as Array).size() == 3:   # 4e élément : rupture
			paires.append(i)
	if paires.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in paires:
		var a: Array = _ech[i - 1]
		var b: Array = _ech[i]
		var va := clampf(1.0 - (_horloge - float(a[0])) / DUREE, 0.0, 1.0)
		var vb := clampf(1.0 - (_horloge - float(b[0])) / DUREE, 0.0, 1.0)
		_quad(a[1], a[2], b[1], b[2], va, vb)
	_im.surface_end()

func _sommet(p: Vector3, le_long: float, vie: float) -> void:
	_im.surface_set_color(Color(1, 1, 1, vie))
	_im.surface_set_uv(Vector2(0.0, le_long))
	_im.surface_add_vertex(p)

func _quad(ga: Vector3, pa: Vector3, gb: Vector3, pb: Vector3, va: float, vb: float) -> void:
	_sommet(ga, 0.0, va); _sommet(pa, 1.0, va); _sommet(pb, 1.0, vb)
	_sommet(ga, 0.0, va); _sommet(pb, 1.0, vb); _sommet(gb, 0.0, vb)
