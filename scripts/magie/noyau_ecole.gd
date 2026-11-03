class_name NoyauEcole
extends Node3D
## NOYAU 3D de l'énergie tenue en main pour les écoles glace, électricité et ténèbres : pendant, pour chaque élément, de la
## flamme runique (feu : shaders/magie_aura.gdshader forme 2). Ne dessine que la FORME CENTRALE ; les runes, leurs orbites,
## les états (repos / début d'incantation / charge / retour) et la lueur sur les avant-bras viennent de RunesOrbite, dont ce
## nœud est l'enfant : il en relit l'état lissé (`_k_vit`, `_k_eclat`, `_conv`), donc rien n'est dupliqué.
##   glace       : grappe de cristaux hexagonaux (12, tailles variées) qui tourne, éclats qui flottent, halo givré, BRUME froide
##                 qui retombe sur la main et givre (petits cristaux) sur les doigts
##   électricité : boule d'arcs (magie_noyau_ecole ecole 2) + masse de plasma en bouffées + ARCS RAMIFIÉS 3D, les mêmes traits
##                 que les éclairs de Force (GestionMagie.eclair_noyau : foudre_ramifiee, même matériau, 30 /s)
##   ténèbres    : FUMÉE VOLUMÉTRIQUE sombre (bouffées en 3D sur des spirales inclinées, aspirées vers un cœur violet),
##                 filaments qui s'effilochent, braises violettes ; aucun disque plat (magie_bouffee)
## Rendu sur le calque de la couche fine (CoucheMagie.CALQUE) comme la flamme : même netteté, preset rétro compris.
## Réglages : `taille_k`, `lumi_k`, `vitesse_k` (reprennent ceux de RunesOrbite si on les passe).

const SH_NOYAU := preload("res://shaders/magie_noyau_ecole.gdshader")
const SH_CRISTAL := preload("res://shaders/magie_cristal.gdshader")
const SH_BOUFFEE := preload("res://shaders/magie_bouffee.gdshader")
const ECOLES := ["glace", "electricite", "tenebres"]
## Palettes (cœur → bord) des carrés procéduraux, même ordre que GestionMagie.AURA_PAL.
const PAL := {
	"glace": ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8", "#1b2c5a"],
	"electricite": ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0", "#4a3ad0", "#2a1a6a"],
	"tenebres": ["#ffe8ff", "#f0d0ff", "#d08aff", "#9a3ae0", "#5a1a8a", "#06030c"],
}
const ID_ECOLE := {"glace": 1, "electricite": 2, "tenebres": 3}
## Rayon (m) du carré selon l'école : la glace tient dans un halo, la boule et la sphère remplissent le creux de la main.
const RAYON := {"glace": 0.15, "electricite": 0.27, "tenebres": 0.15}
## Cristaux de la grappe (2x la taille de la v1) : [inclinaison (rad), azimut (rad), longueur, rayon, décalage du pied]
const GRAPPE := [
	[0.0, 0.0, 0.15, 0.024, 0.0],
	[0.42, 0.5, 0.108, 0.018, 0.004],
	[0.55, 2.3, 0.1, 0.017, 0.004],
	[0.5, 4.2, 0.118, 0.019, 0.004],
	[0.8, 1.4, 0.07, 0.013, 0.008],
	[0.85, 3.4, 0.078, 0.014, 0.008],
	[0.95, 5.3, 0.064, 0.012, 0.008],
	[0.3, 1.0, 0.052, 0.01, 0.012],
	[1.1, 0.2, 0.046, 0.009, 0.014],
	[1.05, 2.9, 0.05, 0.009, 0.014],
	[1.15, 4.8, 0.044, 0.008, 0.016],
	[0.7, 5.9, 0.04, 0.008, 0.012],
]
## Givre sur les doigts : [x, y, z] dans le repère caméra (x vers les doigts : multiplié par `cote`), longueur, inclinaison
const GIVRE := [
	[0.045, 0.03, 0.012, 0.03, 0.9], [0.075, 0.055, 0.008, 0.026, 1.0], [0.1, 0.085, 0.004, 0.022, 1.1],
	[0.02, 0.05, 0.016, 0.022, 0.6], [0.06, 0.085, 0.01, 0.02, 0.7], [-0.015, 0.025, 0.014, 0.018, 0.5],
	[0.115, 0.05, 0.002, 0.016, 1.2],
]
const NB_ECLATS := 11
const BAS := -0.07   # le pied de la grappe, sous le centre de l'énergie (m ; multiplié par ECH)
const ECH := 1.3    # gabarit : tout est déjà dimensionné pour tenir ~2x la hauteur de la main (comme la flamme)
const NB_FUMEE := 96
const NB_FIL := 18
const NB_BRAISE := 16
const NB_BRUME := 30
const NB_PLASMA := 16

var ecole := "glace"
var runes: RunesOrbite
var taille_k := 1.0
var lumi_k := 1.0
var vitesse_k := 1.0
var _t := 0.0
var _naiss := 0.0
var _quad: MeshInstance3D
var _halo: MeshInstance3D
var _mat_cristal: ShaderMaterial
var _grappe: Node3D
var _pieds: Array = []     # [{n, incl, az, haut}]
var _eclats: Array = []    # [{n, a, vit, rayon, y, basc, spin, taille}]
var _graine := 0.0
var _givre: Array = []     # [{n, pos, incl}]
var _arcs: Dictionary = {}   # éclair 3D (GestionMagie.eclair_noyau)
var _etat_arcs := {"r": 1.0, "ch": 0.0, "f": 1.0}
var _mix: Bouffees          # nuages (fumée, brume) et filaments, triés en profondeur, mélange alpha
var _add: Bouffees          # lueurs, braises, cœur : additif
var _part: Array = []       # [{h1, h2, h3, base: Basis, sens}] une entrée par bouffée de fumée / brume / plasma
var _axe := Basis.IDENTITY   # axe du tourbillon (ténèbres), figé dans le monde à la naissance

static func possede(nom: String) -> bool:
	return ECOLES.has(nom) and not EffetsMagie.muet

func _ready() -> void:
	top_level = true
	_graine = randf() * 10.0
	if ecole == "glace":
		_construire_glace()
	elif ecole == "electricite":
		_quad = _carre(ecole, 0.0)
		_construire_plasma()
		var g := GestionMagie.obtenir()
		if g != null:
			_arcs = g.eclair_noyau(self, func() -> Dictionary: return _etat_arcs)
	else:
		_construire_tenebres()

func _exit_tree() -> void:
	if not _arcs.is_empty():
		var g := GestionMagie.instance   # pas obtenir() : à la fermeture, l'arbre est en train de se défaire
		if g != null and is_instance_valid(g):
			g.eclair_fin(_arcs)

## Matériau des bouffées : palette (corps, bord sombre, bord clair, cœur) et mode (0 mélange, 1 additif).
func _mat_bouffee(mode: int, pal: Array, dechire := 0.75, eclat := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_BOUFFEE
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("dechire", dechire)
	m.set_shader_parameter("eclat", eclat)
	for k in 4:
		m.set_shader_parameter(["c_a", "c_b", "c_c", "c_d"][k], Color(pal[k]))
	m.render_priority = mode
	return m

func _nouveau_nuage(n: int, mat: ShaderMaterial) -> Bouffees:
	var b := Bouffees.new(n, mat)
	add_child(b.mi)
	return b

## Une entrée de `_part` par bouffée : plan de spirale incliné (autour de l'axe du tourbillon, avec une dispersion
## qui remplit le volume), sens et graines.
func _tirer_part(n: int, dispersion: float, graine: int) -> void:
	for k in n:
		var h1 := _h(graine + k * 3 + 1)
		var h2 := _h(graine + k * 5 + 2)
		var h3 := _h(graine + k * 7 + 3)
		var incl := Basis.from_euler(Vector3((h1 - 0.5) * dispersion, (h2 - 0.5) * dispersion * 1.4, h3 * TAU))
		_part.append({"h1": h1, "h2": h2, "h3": h3, "base": incl})

# ---------------------------------------------------------------- ténèbres

const PAL_FUMEE := ["#07030c", "#4a1a78", "#b070f0", "#f0d8ff"]
const PAL_BRAISE := ["#07030c", "#9a3ae0", "#d08aff", "#f6e4ff"]

func _construire_tenebres() -> void:
	_mix = _nouveau_nuage(NB_FUMEE + NB_FIL, _mat_bouffee(0, PAL_FUMEE, 0.85))
	_add = _nouveau_nuage(NB_BRAISE + 2, _mat_bouffee(1, PAL_BRAISE, 0.7, 1.35))
	_tirer_part(NB_FUMEE + NB_FIL + NB_BRAISE, 2.2, 100)

## Position d'une bouffée de fumée au point `p` (0 = dehors, 1 = absorbée) de sa spirale : elle s'enroule en accélérant
## vers le cœur.
func _spirale(k: int, p: float, R: float, t: float, sens: float) -> Vector3:
	var e: Dictionary = _part[k]
	var r := R * pow(1.0 - p, 1.5) + 0.008
	var th := float(e.h3) * TAU + sens * (4.6 * p + t * 0.5)
	var loc := Vector3(cos(th) * r, sin(th) * r * 0.9, (float(e.h1) - 0.5) * r * 0.5)
	return _axe * ((e.base as Basis) * loc)

func _maj_tenebres(ch: float, vit: float, vif: float, haut_k: float, larg_k: float, conv: float) -> void:
	var b := runes.global_basis
	if _naiss < 0.05:
		_axe = b * Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.UP, 0.4)   # l'axe regarde vers l'œil, un peu de biais
	var R := 0.15 * (1.0 + 0.12 * ch) * larg_k
	var rate := 0.18 * vit * (1.0 + 0.5 * ch)
	var lot: Array = []
	for k in NB_FUMEE:
		var p := fposmod(_t * rate + float(k) / NB_FUMEE, 1.0)
		var pos := _spirale(k, p, R, _t, 1.0) + Vector3(0.0, 0.012 * haut_k, 0.0)
		var e: Dictionary = _part[k]
		var s := lerpf(0.078, 0.03, p) * (0.8 + 0.5 * float(e.h2)) * (1.0 + 0.08 * ch) * minf(haut_k, 1.3)
		var al := smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.82, 1.0, p)) * 0.8
		lot.append([pos, _bb(b, float(e.h3) * TAU + _t * 0.3 * (1.0 if k % 2 == 0 else -1.0), s, s), Color(1, 1, 1, al), Color(float(e.h1), p, 0.0, 0.0)])
	# filaments : plus longs, effilochés dans le sens du mouvement (tangente de la spirale projetée à l'écran)
	for f in NB_FIL:
		var k := NB_FUMEE + f
		var p := fposmod(_t * rate * 0.8 + float(f) / NB_FIL + 0.3, 1.0)
		var pos := _spirale(k, p, R * 1.15, _t, 1.0)
		var tang := _spirale(k, minf(p + 0.04, 1.0), R * 1.15, _t, 1.0) - pos
		var ang := atan2(tang.dot(b.y), tang.dot(b.x))
		var e: Dictionary = _part[k]
		var lg := lerpf(0.1, 0.05, p) * (0.8 + 0.5 * float(e.h2))
		var al := smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.85, 1.0, p)) * 0.9
		lot.append([pos, _bb(b, ang, lg, lg * 0.11), Color(1, 1, 1, al), Color(float(e.h1), 0.3 + 0.7 * p, 1.0, 0.0)])
	_mix.ecrire(lot, b)
	# braises : petits carrés violets qui s'élèvent en tournant autour de la fumée, et le cœur violet qui bat
	var braises: Array = []
	for q in NB_BRAISE:
		var k := NB_FUMEE + NB_FIL + q
		var p := fposmod(_t * 0.22 * vit + float(q) / NB_BRAISE, 1.0)
		var e: Dictionary = _part[k]
		var th := float(e.h3) * TAU + _t * (0.6 + float(e.h1)) * (1.0 if q % 2 == 0 else -1.0)
		var rr := (0.09 + 0.07 * float(e.h2)) * (1.0 - 0.3 * p) * larg_k
		var pos := Vector3(cos(th) * rr, lerpf(-0.07, 0.16, p) * haut_k + 0.02 * sin(th * 2.0), sin(th) * rr)
		var s := 0.008 + 0.007 * float(e.h1)
		var al := smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.7, 1.0, p))
		braises.append([pos, _bb(b, 0.0, s, s), Color(1, 1, 1, al), Color(float(e.h2), float(q % 2), 3.0, 0.0)])
	var bat := 0.9 + 0.1 * sin(_t * 5.0) + 0.15 * ch
	var rc := 0.05 * bat * (1.0 + 0.2 * ch) * minf(larg_k, 1.2) * (1.0 - 0.4 * conv)
	braises.append([Vector3.ZERO, _bb(b, 0.0, rc, rc), Color(1, 1, 1, 0.75 * minf(vif, 1.3)), Color(0.0, 1.0, 2.0, 0.0)])
	braises.append([Vector3.ZERO, _bb(b, 0.0, rc * 2.2, rc * 2.2), Color(1, 1, 1, 0.2 * minf(vif, 1.3)), Color(0.5, 1.0, 2.0, 0.0)])
	_add.ecrire(braises, b, false)

# ---------------------------------------------------------------- électricité

const PAL_PLASMA := ["#2a1a6a", "#4a3ad0", "#9aa8ff", "#f0f2ff"]

## Masse de plasma : bouffées additives violettes qui flottent autour du cœur (volume, vu de tous les côtés).
func _construire_plasma() -> void:
	_add = _nouveau_nuage(NB_PLASMA, _mat_bouffee(1, PAL_PLASMA, 0.6, 1.1))
	_tirer_part(NB_PLASMA, 6.0, 300)

func _maj_plasma(ch: float, vit: float, vif: float, larg_k: float) -> void:
	var b := runes.global_basis
	var lot: Array = []
	for k in NB_PLASMA:
		var e: Dictionary = _part[k]
		var th := float(e.h3) * TAU + _t * (0.9 + 1.2 * float(e.h1)) * vit * (1.0 if k % 2 == 0 else -1.0)
		var rr := (0.03 + 0.08 * float(e.h2)) * larg_k * (1.0 + 0.15 * ch)
		var pos := (e.base as Basis) * Vector3(cos(th) * rr, sin(th) * rr * 0.9, 0.0)
		var s := (0.06 + 0.05 * float(e.h1)) * (1.0 + 0.12 * ch)
		var al := (0.13 + 0.07 * sin(_t * 9.0 + k)) * minf(vif, 1.3) * (1.0 + 0.4 * ch)
		lot.append([pos, _bb(b, 0.0, s, s), Color(1, 1, 1, al), Color(float(e.h2), 0.5, 0.0, 0.0)])
	var rc := 0.05 * larg_k * (1.0 + 0.2 * ch) * (0.92 + 0.08 * sin(_t * 23.0))
	lot.append([Vector3.ZERO, _bb(b, 0.0, rc, rc), Color(1, 1, 1, 0.3 * minf(vif, 1.3)), Color(0.0, 1.0, 2.0, 0.0)])
	_add.ecrire(lot, b, false)

## Carré procédural (magie_noyau_ecole) sur le calque de la couche fine.
func _carre(nom: String, avance: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = SH_NOYAU
	mat.set_shader_parameter("ecole", int(ID_ECOLE[nom]))
	var p: Array = PAL[nom]
	for k in 6:
		mat.set_shader_parameter("c%d" % k, Color(p[k]))
	mat.set_shader_parameter("eclat", {"glace": 1.1, "electricite": 1.1, "tenebres": 1.25}[nom])
	var qd := QuadMesh.new()
	qd.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = qd
	mi.material_override = mat
	mi.layers = CoucheMagie.CALQUE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	mi.set_instance_shader_parameter("rayon", float(RAYON[nom]))
	mi.set_instance_shader_parameter("graine", _graine)
	mi.set_instance_shader_parameter("avance", avance)
	add_child(mi)
	return mi

# ---------------------------------------------------------------- glace

func _construire_glace() -> void:
	_mat_cristal = ShaderMaterial.new()
	_mat_cristal.shader = SH_CRISTAL
	_mat_cristal.set_shader_parameter("c_ombre", Color("#1a3a78"))
	_mat_cristal.set_shader_parameter("c_milieu", Color("#4a9ae8"))
	_mat_cristal.set_shader_parameter("c_clair", Color("#a8dcff"))
	_mat_cristal.set_shader_parameter("c_reflet", Color("#f4fbff"))
	_halo = _carre("glace", -0.06)
	_grappe = Node3D.new()
	add_child(_grappe)
	for k in GRAPPE.size():
		var g: Array = GRAPPE[k]
		var mi := _mesh_cristal(float(g[3]), float(g[2]))
		_grappe.add_child(mi)
		_pieds.append({"n": mi, "incl": float(g[0]), "az": float(g[1]), "haut": float(g[4]), "l": float(g[2])})
	for g: Array in GIVRE:
		var mi := _mesh_cristal(float(g[3]) * 0.22, float(g[3]))
		add_child(mi)
		_givre.append({"n": mi, "pos": Vector3(float(g[0]), float(g[1]), float(g[2])), "incl": float(g[4])})
	_mix = _nouveau_nuage(NB_BRUME, _mat_bouffee(0, ["#4a78c0", "#8cc0f0", "#d8f0ff", "#ffffff"], 0.9))
	_tirer_part(NB_BRUME, 0.0, 500)
	for k in NB_ECLATS:
		var mi := _mesh_cristal(0.0085 + 0.006 * _h(k * 3 + 1), 0.03 + 0.028 * _h(k * 5 + 2))
		add_child(mi)
		_eclats.append({"n": mi, "a": TAU * _h(k * 7 + 3), "vit": (0.5 + 0.7 * _h(k * 11 + 4)) * (1.0 if k % 2 == 0 else -1.0),
			"rayon": 0.085 + 0.06 * _h(k * 13 + 5), "y": lerpf(-0.08, 0.15, _h(k * 17 + 6)), "basc": TAU * _h(k * 19 + 7),
			"spin": 1.0 + 1.6 * _h(k * 23 + 8), "incl": Vector3(_h(k * 29 + 1) * TAU, _h(k * 31 + 2) * TAU, 0.0)})

## Carré orienté vers la caméra (base `cam`), tourné de `ang` (rad) dans le plan de l'écran, de demi-largeur `sx` et hauteur `sy`.
static func _bb(cam: Basis, ang: float, sx: float, sy: float) -> Basis:
	return cam * Basis(Vector3.BACK, ang) * Basis.from_scale(Vector3(sx, sy, 1.0))

func _h(i: int) -> float:
	var x := (i * 73856093) ^ 19349663
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffff) / 65535.0

## Cristal hexagonal : prisme de 6 pans fermé par deux pointes, pied à l'origine, pointe vers +Y (facettes plates).
func _mesh_cristal(r: float, l: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pointe := l * 0.32
	var corps := l - pointe
	var bas: Array[Vector3] = []
	var haut: Array[Vector3] = []
	for s in 6:
		var a := TAU * s / 6.0
		bas.append(Vector3(cos(a) * r, corps * 0.18, sin(a) * r))
		haut.append(Vector3(cos(a) * r * 0.92, corps, sin(a) * r * 0.92))
	var pied := Vector3(0.0, -r * 0.35, 0.0)
	var tete := Vector3(0.0, l, 0.0)
	for s in 6:
		var s2 := (s + 1) % 6
		for v in [bas[s], haut[s], haut[s2], bas[s], haut[s2], bas[s2], haut[s], tete, haut[s2], bas[s2], pied, bas[s]]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat_cristal
	mi.layers = CoucheMagie.CALQUE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi

# ---------------------------------------------------------------- vie

func _process(dt: float) -> void:
	if runes == null or not is_instance_valid(runes):
		return
	_t += dt
	_naiss = minf(_naiss + dt * 3.0, 1.0)
	# réglages de la main (double magie : runes plus vives et plus rapides) relus à chaque image : MainSort les change après la naissance
	taille_k = runes.taille_k
	lumi_k = runes.lumi_k
	vitesse_k = runes.vitesse_k
	global_transform = Transform3D(Basis.IDENTITY, runes.global_position)
	var ch: float = runes.charge if runes.etat == 2 else 0.0
	var conv := sin(minf(runes._conv, 1.0) * PI * 0.5)
	var vit: float = runes._k_vit * vitesse_k
	var vif: float = runes._k_eclat * lumi_k
	var nais := sin(_naiss * PI * 0.5)
	# charge : x1,3 en hauteur et x1,15 en largeur au plus (comme la flamme) ; les départs resserrent le noyau
	var ech := ECH
	var haut_k := (1.0 + 0.3 * ch) * (1.0 - 0.35 * conv) * taille_k * nais * ech
	var larg_k := (1.0 + 0.15 * ch) * (1.0 - 0.3 * conv) * taille_k * nais
	var larg_c := larg_k * ech
	var forc := clampf(0.78 + 0.35 * runes.intensite, 0.0, 1.3) * (0.97 + 0.04 * sin(_t * 9.0)) * minf(vif, 1.45)
	if ecole == "glace":
		_maj_glace(ch, vit, vif, haut_k, larg_c, larg_k, forc)
	elif ecole == "electricite":
		_quad.set_instance_shader_parameter("rayon", float(RAYON[ecole]) * larg_k)
		_quad.set_instance_shader_parameter("force", forc)
		_quad.set_instance_shader_parameter("charge", ch)
		_etat_arcs = {"r": larg_k, "ch": ch, "f": forc}
		_maj_plasma(ch, vit, vif, larg_k)
	else:
		_maj_tenebres(ch, vit, vif, haut_k, larg_k, conv)

func _maj_glace(ch: float, vit: float, vif: float, haut_k: float, larg_c: float, larg_k: float, forc: float) -> void:
	_mat_cristal.set_shader_parameter("eclat", clampf(0.9 + 0.35 * (vif - 1.0) + 0.1 * ch, 0.7, 1.5))
	_halo.set_instance_shader_parameter("rayon", float(RAYON["glace"]) * larg_k)
	_halo.set_instance_shader_parameter("force", forc)
	_halo.set_instance_shader_parameter("charge", ch)
	# la grappe tourne lentement sur son axe, balance un peu ; chaque cristal respire à son rythme
	_grappe.basis = Basis(Vector3.UP, _t * 0.45 * vit) * Basis(Vector3.RIGHT, 0.05 * sin(_t * 0.9)) * Basis.IDENTITY.scaled(Vector3(larg_c, haut_k, larg_c))
	_grappe.position = Vector3(0.0, BAS * haut_k + 0.004 * sin(_t * 1.3), 0.0)
	for k in _pieds.size():
		var p: Dictionary = _pieds[k]
		var b := Basis(Vector3.UP, float(p.az)) * Basis(Vector3.BACK, -float(p.incl) * (1.0 - 0.12 * ch) + 0.03 * sin(_t * 1.1 + k))
		var n: MeshInstance3D = p.n
		n.transform = Transform3D(b * Basis(Vector3.UP, _t * 0.3 * vit * (1.0 if k % 2 == 0 else -1.0)), Vector3(sin(float(p.az)) * 0.004, float(p.haut), cos(float(p.az)) * 0.004))
	# éclats flottants : orbites inclinées, remontent et redescendent, basculent ; se resserrent en charge
	for e: Dictionary in _eclats:
		var a: float = float(e.a) + _t * float(e.vit) * vit * 0.9
		var rr := float(e.rayon) * (1.0 - 0.22 * ch) * (1.0 - 0.5 * minf(runes._conv, 1.0)) * larg_c
		var y := float(e.y) * haut_k + 0.007 * sin(_t * 1.6 + float(e.basc))
		var n: MeshInstance3D = e.n
		var inc: Vector3 = e.incl
		var b := Basis.from_euler(Vector3(inc.x + _t * 0.7 * float(e.spin) * vit * 0.5, inc.y + _t * 0.5 * float(e.spin), 0.0))
		n.transform = Transform3D(b * Basis.IDENTITY.scaled(Vector3.ONE * (1.0 + 0.1 * ch)), Vector3(cos(a) * rr, y, sin(a) * rr))

	_maj_brume_givre(ch, vit, vif, larg_c, haut_k)

## Brume froide qui naît autour des cristaux, retombe sur la main et s'étale ; givre : petits cristaux posés sur les doigts.
func _maj_brume_givre(ch: float, vit: float, vif: float, larg_c: float, haut_k: float) -> void:
	var b := runes.global_basis
	var lot: Array = []
	var cote: float = runes.cote
	for k in NB_BRUME:
		var e: Dictionary = _part[k]
		var p := fposmod(_t * 0.2 * vit + float(k) / NB_BRUME, 1.0)
		var th := float(e.h3) * TAU + _t * 0.25 * (1.0 if k % 2 == 0 else -1.0)
		var rr := (0.03 + 0.1 * p) * larg_c * (0.6 + 0.8 * float(e.h2))
		# naît à mi-hauteur de la grappe, tombe et s'élargit jusqu'à la paume (puis un peu en dessous : elle coule sur la main)
		var pos := Vector3(cos(th) * rr, lerpf(0.0, -0.17, pow(p, 0.8)) * haut_k, sin(th) * rr) + b.x * (0.02 * cote * p)
		var s := lerpf(0.04, 0.085, p) * (0.8 + 0.5 * float(e.h1)) * larg_c
		var al := smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.6, 1.0, p)) * 0.17 * minf(vif, 1.3) * (1.0 + 0.5 * ch)
		lot.append([pos, _bb(b, float(e.h3) * TAU, s, s * 0.8), Color(1, 1, 1, al), Color(float(e.h1), 0.3 + 0.7 * (1.0 - p), 0.0, 0.0)])
	_mix.ecrire(lot, b)
	# givre sur les doigts : repère de la paume (suivi), placé avec la caméra ; scintille doucement avec la charge
	var palme := runes.suivi.global_position - global_position
	for g: Dictionary in _givre:
		var o: Vector3 = g.pos
		var pos := palme + b.x * (o.x * cote) + b.y * o.y + b.z * o.z
		var bas := b * Basis(Vector3.BACK, -float(g.incl) * cote) * Basis.IDENTITY.scaled(Vector3.ONE * (0.9 + 0.2 * ch))
		(g.n as MeshInstance3D).transform = Transform3D(bas, pos)


## MultiMesh de carrés orientés vers la caméra (shader magie_bouffee), triés du plus loin au plus près pour le mélange alpha.
class Bouffees extends RefCounted:
	var mi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	var n := 0

	func _init(nb: int, mat: ShaderMaterial) -> void:
		n = nb
		var qd := QuadMesh.new()
		qd.size = Vector2.ONE
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = qd
		mm.instance_count = nb
		mm.visible_instance_count = 0
		mi.multimesh = mm
		mi.material_override = mat
		mi.layers = CoucheMagie.CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-0.6, -0.6, -0.6), Vector3(1.2, 1.2, 1.2))
		mi.extra_cull_margin = 1.0

	## lot : [[position, basis (déjà mis à l'échelle), couleur (alpha = opacité), données personnalisées], ...]
	func ecrire(lot: Array, cam: Basis, trier := true) -> void:
		if trier:
			var vue := -cam.z
			lot.sort_custom(func(a: Array, c: Array) -> bool: return (a[0] as Vector3).dot(vue) > (c[0] as Vector3).dot(vue))
		var m := mini(lot.size(), n)
		mm.visible_instance_count = m
		for i in m:
			var l: Array = lot[i]
			mm.set_instance_transform(i, Transform3D(l[1], l[0]))
			mm.set_instance_color(i, l[2])
			mm.set_instance_custom_data(i, l[3])
