class_name RunesOrbite
extends Node3D
## Runes nordiques en orbite autour de la magie tenue en main (références Jeux/references/avant_bras_magie/bras_*_1100.jpg) :
## un fil d'orbite fin et lumineux, des runes posées dessus qui tournent lentement dans un sens, et une seconde orbite plus
## serrée, inclinée autrement, dont les runes tournent dans l'autre sens. Variations de taille, de hauteur et d'éclat par
## rune. Le cercle suit la paume (mouvements des mains) mais reste tourné vers l'œil : les runes restent lisibles.
## MainSort (main_sort.gd) le crée quand un sort est tenu ; `intensite` suit l'aura, `charge` (0..1) resserre les orbites
## et accélère (état de charge, à brancher à l'étape suivante). Shader : shaders/runes_orbite.gdshader (additif, WebGL2).

const SH := preload("res://shaders/runes_orbite.gdshader")
## Par école : couleurs, signes (shader), nombre de runes (orbite principale, orbite inverse), rayon (m), taille d'une rune (m).
const ECOLES := {
	"feu": {"couleur": Color("#ff4a12"), "coeur": Color("#ffb066"), "signes": [0, 0, 3, 0, 1, 0, 2], "n": [5, 2], "rayon": 0.122, "taille": 0.028},
	"glace": {"couleur": Color("#4fb4ff"), "coeur": Color("#e2f6ff"), "signes": [5, 3, 5, 0, 5, 3], "n": [4, 2], "rayon": 0.115, "taille": 0.025},
	"electricite": {"couleur": Color("#8a6cff"), "coeur": Color("#e6deff"), "signes": [2, 4, 2, 0, 2, 4], "n": [4, 2], "rayon": 0.115, "taille": 0.025},
	"tenebres": {"couleur": Color("#a23cff"), "coeur": Color("#e7b8ff"), "signes": [4, 1, 5, 4, 1, 5], "n": [4, 2], "rayon": 0.112, "taille": 0.025},
}
## Inclinaison des orbites par rapport au plan de l'écran (rad) : principale penchée vers l'avant, seconde vers l'autre côté.
const INCLINAISON := [Vector3(-0.42, 0.18, 0.12), Vector3(0.55, -0.35, -0.5)]
const VITESSE := [0.32, -0.48]      # rad/s (sens horaire / antihoraire vus de l'œil)
const RAYON_RELATIF := [1.0, 0.72]
const LARGEUR_FIL := 0.0021

var ecole := "feu"
var suivi: Node3D
## +1 main gauche, -1 main droite (sens et inclinaison en miroir : gauche ≠ droite).
var cote := 1.0
var intensite := 0.35
var charge := 0.0
var _runes: Array = []          # [{mi, orbite, phase, taille, haut, eclat}]
var _fils: Array[MeshInstance3D] = []
var _mat_rune: ShaderMaterial
var _mat_fil: ShaderMaterial
var _t := 0.0
## Lueur courte de l'énergie tenue : n'éclaire QUE les avant-bras (AvantBras.CALQUE), creux de la paume et intérieur des
## doigts orangés, brassard dans la pénombre (références) ; l'aura du sort éclaire le monde, pas les bras.
var lueur: OmniLight3D
const LUEUR := 1.0              # énergie au repos (atténuation 1/d)
## La lueur est avancée vers l'œil (m) : le dos de la main et les jointures, tournés vers la caméra, prennent le reflet
## orangé de l'énergie comme sur les références, au lieu d'une silhouette noire.
const LUEUR_AVANCE := 0.025
## Reflet plus faible et plus large posé sous la main, côté poignet : les arêtes des rouleaux, des plaques et des clous du
## brassard prennent l'orange de l'énergie (références : bras sombres mais lisibles), sans brûler le gant.
var lueur_bras: OmniLight3D
const LUEUR_BRAS := 0.45
const LUEUR_BRAS_POS := Vector3(-0.14, -0.02, 0.3)   # main gauche (x en miroir pour la droite), repère caméra

func _ready() -> void:
	top_level = true
	var e: Dictionary = ECOLES.get(ecole, ECOLES["feu"])
	_mat_rune = ShaderMaterial.new()
	_mat_rune.shader = SH
	_mat_rune.set_shader_parameter("couleur", e.couleur)
	_mat_rune.set_shader_parameter("coeur", e.coeur)
	_mat_fil = _mat_rune.duplicate()
	_mat_fil.set_shader_parameter("ligne", true)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var signes: Array = e.signes
	var k := 0
	for o in 2:
		var n: int = (e.n as Array)[o]
		if o == 0:
			var fil := MeshInstance3D.new()
			fil.mesh = _ruban(float(e.rayon) * RAYON_RELATIF[o])
			fil.material_override = _mat_fil
			fil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fil.extra_cull_margin = 1.0
			add_child(fil)
			_fils.append(fil)
		for i in n:
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = _mat_rune
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 1.0
			mi.set_instance_shader_parameter("symbole", float(signes[k % signes.size()]))
			add_child(mi)
			var h := _h(k * 7 + (0 if cote > 0.0 else 3))
			_runes.append({"mi": mi, "orbite": o, "phase": TAU * (i + 0.37 * o + 0.15 * h) / n,
				"taille": float(e.taille) * (0.82 + 0.36 * _h(k * 13 + 1)) * (0.85 if o == 1 else 1.0),
				"haut": 0.006 * (_h(k * 5 + 2) - 0.5), "eclat": 0.75 + 0.5 * _h(k * 11 + 4), "bat": TAU * _h(k * 3 + 9)})
			k += 1
	lueur = OmniLight3D.new()
	lueur.light_color = (e.couleur as Color).lerp(e.coeur, 0.35)
	lueur.light_cull_mask = AvantBras.CALQUE
	lueur.shadow_enabled = false
	lueur.light_specular = 0.25
	lueur.omni_range = 0.24
	lueur.light_energy = LUEUR
	add_child(lueur)
	lueur_bras = OmniLight3D.new()
	lueur_bras.light_color = (e.couleur as Color).lerp(Color(0.8, 0.7, 0.62), 0.5)
	lueur_bras.light_cull_mask = AvantBras.CALQUE
	lueur_bras.shadow_enabled = false
	lueur_bras.light_specular = 0.12
	lueur_bras.omni_range = 0.5
	lueur_bras.omni_attenuation = 1.6
	lueur_bras.light_energy = LUEUR_BRAS
	add_child(lueur_bras)
	_suivre()

func _h(i: int) -> float:
	var x := (i * 73856093) ^ 19349663
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffff) / 65535.0

## Ruban circulaire (rayon r, largeur LARGEUR_FIL) dans le plan XY ; UV.x = fraction du tour, UV.y = travers.
func _ruban(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 96
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		var w := LARGEUR_FIL * 0.5
		var p := [d0 * (r - w), d1 * (r - w), d1 * (r + w), d0 * (r + w)]
		var uv := [Vector2(float(i) / n, 0.0), Vector2(float(i + 1) / n, 0.0), Vector2(float(i + 1) / n, 1.0), Vector2(float(i) / n, 1.0)]
		for t in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[t])
			st.add_vertex(p[t])
	return st.commit()

func _base_orbite(o: int) -> Basis:
	var e: Vector3 = INCLINAISON[o]
	return Basis.from_euler(Vector3(e.x, e.y * cote, e.z * cote))

func _suivre() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if suivi == null or not is_instance_valid(suivi) or not suivi.is_inside_tree():
		return
	var b := cam.global_basis if cam != null else Basis.IDENTITY
	global_transform = Transform3D(b, suivi.global_position)

func _process(dt: float) -> void:
	_t += dt
	_suivre()
	var e: Dictionary = ECOLES.get(ecole, ECOLES["feu"])
	var resserre := 1.0 - 0.35 * charge
	var acc := 1.0 + 3.0 * charge
	var force := clampf(0.55 + 0.6 * intensite, 0.0, 1.6)
	lueur.position = Vector3(0.025 * cote, 0.0, LUEUR_AVANCE)
	lueur_bras.position = Vector3(LUEUR_BRAS_POS.x * cote, LUEUR_BRAS_POS.y, LUEUR_BRAS_POS.z)
	lueur_bras.light_energy = LUEUR_BRAS * (0.5 + 0.8 * intensite) * (1.0 + 0.8 * charge)
	lueur.light_energy = LUEUR * (0.5 + 0.8 * intensite) * (1.0 + 1.5 * charge) * (0.92 + 0.08 * sin(_t * 17.0) * sin(_t * 6.3))
	for o in _fils.size():
		var f := _fils[o]
		f.basis = _base_orbite(o).scaled(Vector3.ONE * resserre)
		f.set_instance_shader_parameter("defile", _t * 0.02 * signf(VITESSE[o]) * cote)
		f.set_instance_shader_parameter("eclat", force * (0.85 + 0.15 * sin(_t * 2.3)))
	for r: Dictionary in _runes:
		var o: int = r.orbite
		var a: float = float(r.phase) + _t * VITESSE[o] * acc * cote
		var rr: float = float(e.rayon) * RAYON_RELATIF[o] * resserre
		var p := _base_orbite(o) * Vector3(cos(a) * rr, sin(a) * rr, 0.0)
		p.y += float(r.haut) + 0.003 * sin(_t * 1.7 + float(r.bat))
		var mi: MeshInstance3D = r.mi
		# les runes restent dans le plan de l'écran (face à l'œil), celles du fond un peu plus petites et plus pâles
		var prof := clampf(-p.z / rr, -1.0, 1.0)
		var s: float = float(r.taille) * (1.0 + 0.08 * prof) * (1.0 + 0.06 * sin(_t * 2.9 + float(r.bat)))
		mi.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p)
		var pulse := 0.8 + 0.2 * sin(_t * 3.3 + float(r.bat) * 2.0)
		mi.set_instance_shader_parameter("eclat", float(r.eclat) * pulse * force * (0.8 + 0.2 * prof))
