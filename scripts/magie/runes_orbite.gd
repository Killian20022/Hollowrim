class_name RunesOrbite
extends Node3D
## Runes nordiques en orbite autour de la magie tenue en main (références Jeux/references/avant_bras_magie/bras_*_1100.jpg) :
## un fil d'orbite fin et lumineux, des runes posées dessus qui tournent lentement dans un sens, et une seconde orbite plus
## serrée, inclinée autrement, dont les runes tournent dans l'autre sens. Variations de taille, de hauteur et d'éclat par
## rune. Le cercle suit la paume (mouvements des mains) mais reste tourné vers l'œil : les runes restent lisibles.
## MainSort (main_sort.gd) le crée quand un sort est tenu ; `intensite` suit l'aura, `charge` (0..1) resserre les orbites
## et accélère (état de charge, à brancher à l'étape suivante). Shader : shaders/runes_orbite.gdshader (additif, WebGL2).

const SH := preload("res://shaders/runes_orbite.gdshader")
## Par école : couleurs, signes (shader), rayon moyen des orbites (m), taille d'une rune (m), hauteur du centre des
## orbites au-dessus de la paume (m : le milieu de la flamme / du cristal tenu).
const ECOLES := {
	"feu": {"couleur": Color("#ff6a1a"), "coeur": Color("#ffc27a"), "signes": [6, 7, 8, 9, 1, 10, 6, 7], "rayon": 0.115, "taille": 0.026, "centre": 0.15},
	"glace": {"couleur": Color("#4fb4ff"), "coeur": Color("#e2f6ff"), "signes": [5, 3, 10, 0, 5, 3, 9, 8], "rayon": 0.108, "taille": 0.029, "centre": 0.075},
	"electricite": {"couleur": Color("#8a6cff"), "coeur": Color("#e6deff"), "signes": [2, 4, 2, 9, 2, 4, 8, 10], "rayon": 0.108, "taille": 0.029, "centre": 0.075},
	"tenebres": {"couleur": Color("#a23cff"), "coeur": Color("#e7b8ff"), "signes": [4, 1, 5, 7, 4, 1, 5, 6], "rayon": 0.108, "taille": 0.029, "centre": 0.075},
}
## Deux anneaux très fins, PARTIELS (un arc qui tourne, ni cercle complet ni grand cercle devant la caméra) : rayon (m),
## inclinaison (rad), fraction du tour visible, vitesse de rotation propre (rad/s), épaisseur du trait.
const ANNEAUX := [
	{"rayon": 0.115, "incl": Vector3(-0.95, 0.25, 0.15), "arc": 0.55, "vit": 0.34},
	{"rayon": 0.082, "incl": Vector3(0.7, -0.5, -0.7), "arc": 0.4, "vit": -0.5},
]
## États : cibles (rayon des orbites, vitesse, éclat) vers lesquelles les runes glissent sans à-coup.
## REPOS : lentes ; INCANTE : elles s'emballent un peu ; CHARGE : se resserrent et brillent (cf. `charge` 0..1) ;
## CANALISE : serrées et vives ; RECUPERATION : retour doux (elles regagnent leurs orbites).
const ETAT := {
	0: {"rayon": 1.0, "vit": 1.0, "eclat": 1.0},
	1: {"rayon": 0.96, "vit": 1.9, "eclat": 1.3},
	2: {"rayon": 0.9, "vit": 2.2, "eclat": 1.35},
	3: {"rayon": 0.8, "vit": 2.4, "eclat": 1.45},
	4: {"rayon": 1.0, "vit": 1.3, "eclat": 1.1},
}
const LARGEUR_FIL := 0.0016
const NB_RUNES := 7

var ecole := "feu"
var suivi: Node3D
## +1 main gauche, -1 main droite (sens et inclinaison en miroir : gauche ≠ droite).
var cote := 1.0
var intensite := 0.35
var charge := 0.0
## État d'incantation de la main (Incantation.REPOS..RECUPERATION) : MainSort le recopie à chaque image.
var etat := 0
## Réglages (composant réutilisable) : nombre de runes (≤ 8), vitesse, taille, luminosité.
var nombre := NB_RUNES
var vitesse_k := 1.0
var taille_k := 1.0
var lumi_k := 1.0
var _runes: Array = []          # [{mi, base, vit, rayon, phase, taille, eclat, bat, haut}]
var _fils: Array[MeshInstance3D] = []
var _etat_prec := 0
var _k_rayon := 1.0             # valeurs lissées vers la cible de l'état
var _k_vit := 1.0
var _k_eclat := 1.0
var _conv := 0.0                # convergence brève des runes au départ du sort (1 → 0)
var _mat_rune: ShaderMaterial
var _mat_fil: ShaderMaterial
var _t := 0.0
## Lueur courte de l'énergie tenue : n'éclaire QUE les avant-bras (AvantBras.CALQUE), creux de la paume et intérieur des
## doigts orangés, brassard dans la pénombre (références) ; l'aura du sort éclaire le monde, pas les bras.
var lueur: OmniLight3D
const LUEUR := 1.7              # énergie au repos (atténuation 1/d)
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
	for o in ANNEAUX.size():
		var fil := MeshInstance3D.new()
		fil.mesh = _ruban(float(ANNEAUX[o].rayon))
		fil.material_override = _mat_fil
		fil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fil.extra_cull_margin = 1.0
		fil.set_instance_shader_parameter("arc", float(ANNEAUX[o].arc))
		add_child(fil)
		_fils.append(fil)
	for k in mini(nombre, 8):
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = _mat_rune
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.0
		mi.set_instance_shader_parameter("symbole", float(signes[k % signes.size()]))
		add_child(mi)
		var h := _h(k * 7 + (0 if cote > 0.0 else 3))
		# orbite propre : plan incliné au hasard (mais stable), rayon et hauteur variés, sens alterné (horaire / antihoraire)
		var incl := Vector3(lerpf(-1.1, 1.1, _h(k * 17 + 5)), lerpf(-0.8, 0.8, _h(k * 19 + 8)), lerpf(-1.5, 1.5, _h(k * 23 + 2)))
		_runes.append({"mi": mi, "base": Basis.from_euler(incl),
			"vit": (0.42 + 0.5 * _h(k * 29 + 6)) * (1.0 if k % 2 == 0 else -1.0) * cote,
			"rayon": float(e.rayon) * (0.72 + 0.62 * _h(k * 31 + 3)), "phase": TAU * h,
			"taille": float(e.taille) * (0.85 + 0.3 * _h(k * 13 + 1)), "haut": 0.03 * (_h(k * 5 + 2) - 0.5),
			"eclat": 0.75 + 0.45 * _h(k * 11 + 4), "bat": TAU * _h(k * 3 + 9)})
	lueur = OmniLight3D.new()
	lueur.light_color = (e.couleur as Color).lerp(e.coeur, 0.35)
	lueur.light_cull_mask = AvantBras.CALQUE
	lueur.shadow_enabled = false
	lueur.light_specular = 0.25
	lueur.omni_range = 0.32
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

func _suivre() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if suivi == null or not is_instance_valid(suivi) or not suivi.is_inside_tree():
		return
	var b := cam.global_basis if cam != null else Basis.IDENTITY
	var e: Dictionary = ECOLES.get(ecole, ECOLES["feu"])
	# centre des orbites : le milieu de l'énergie tenue, AU-DESSUS de la paume (haut du monde, main penchée ou non)
	global_transform = Transform3D(b, suivi.global_position + Vector3.UP * float(e.centre))

func _process(dt: float) -> void:
	_t += dt
	_suivre()
	var e: Dictionary = ECOLES.get(ecole, ECOLES["feu"])
	# cible de l'état, lissée : jamais de saut (charge : resserre et accélère selon `charge`)
	var cib: Dictionary = ETAT.get(etat, ETAT[0])
	var kc := charge if etat == 2 else 0.0
	var v_rayon := float(cib.rayon) * (1.0 - 0.15 * kc)
	var v_vit := float(cib.vit) * (1.0 + 1.6 * kc)
	var v_eclat := float(cib.eclat) * (1.0 + 0.4 * kc)
	var lis := 1.0 - exp(-dt * 5.0)
	_k_rayon = lerpf(_k_rayon, v_rayon, lis)
	_k_vit = lerpf(_k_vit, v_vit, lis)
	_k_eclat = lerpf(_k_eclat, v_eclat, lis)
	# départ du sort : les runes convergent brièvement vers le centre puis regagnent leurs orbites
	if etat == 4 and _etat_prec in [1, 2, 3]:
		_conv = 1.0
	_etat_prec = etat
	_conv = maxf(_conv - dt * 3.2, 0.0)
	var conv := sin(minf(_conv, 1.0) * PI * 0.5)
	var resserre := _k_rayon * (1.0 - 0.55 * conv)
	var acc := _k_vit * vitesse_k
	var force := clampf(0.7 + 0.6 * intensite, 0.0, 1.8) * _k_eclat * lumi_k * (1.0 + 0.4 * conv)
	lueur.position = Vector3(0.025 * cote, 0.0, LUEUR_AVANCE)
	lueur_bras.position = Vector3(LUEUR_BRAS_POS.x * cote, LUEUR_BRAS_POS.y, LUEUR_BRAS_POS.z)
	var vif := _k_eclat * (1.0 + 0.4 * kc)
	lueur_bras.light_energy = LUEUR_BRAS * (0.5 + 0.8 * intensite) * vif
	lueur.light_energy = LUEUR * (0.5 + 0.8 * intensite) * vif * (0.94 + 0.06 * sin(_t * 17.0) * sin(_t * 6.3))
	for o in _fils.size():
		var f := _fils[o]
		var an: Dictionary = ANNEAUX[o]
		var ie: Vector3 = an.incl
		var bs := Basis.from_euler(Vector3(ie.x, ie.y * cote, ie.z * cote)) * Basis(Vector3.BACK, _t * float(an.vit) * acc * cote)
		f.basis = bs.scaled(Vector3.ONE * resserre)
		f.set_instance_shader_parameter("defile", _t * 0.02 * signf(float(an.vit)) * cote)
		f.set_instance_shader_parameter("eclat", force * 0.8 * (0.85 + 0.15 * sin(_t * 2.3 + o)))
	for r: Dictionary in _runes:
		var a: float = float(r.phase) + _t * float(r.vit) * acc
		var rr: float = float(r.rayon) * resserre
		var p: Vector3 = (r.base as Basis) * Vector3(cos(a) * rr, sin(a) * rr, 0.0)
		p.y = p.y * 0.6 + float(r.haut) + 0.003 * sin(_t * 1.7 + float(r.bat))
		var mi: MeshInstance3D = r.mi
		# profondeur : les runes devant (vers l'œil, +Z caméra) sont plus grandes et plus vives, celles du fond plus petites et pâles
		var dev := clampf(p.z / maxf(rr, 0.01), -1.0, 1.0)
		var s: float = float(r.taille) * taille_k * (0.9 + 0.2 * dev) * (1.0 + 0.06 * sin(_t * 2.9 + float(r.bat)))
		mi.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p)
		var pulse := 0.8 + 0.2 * sin(_t * 3.3 + float(r.bat) * 2.0)
		mi.set_instance_shader_parameter("eclat", float(r.eclat) * pulse * force * (0.7 + 0.3 * dev))
