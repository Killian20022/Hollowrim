class_name SangLame
extends Node3D
## SANG SUR LA LAME DU JOUEUR (sang v2, 2026-10-30) : chaque coup d'épée qui fait saigner dépose du sang sur la lame ; il
## s'accumule coup après coup (taches → lame couverte), coule vers la garde, goutte tant qu'il est frais, sèche (brun sombre,
## plus de reflet mouillé) puis s'efface par plaques (le seuil du bruit remonte : pas de fondu d'opacité, pas de tramage).
##   SangLame.equiper(hote, materiau_lame, garde, pointe)   mains.gd, à chaque changement d'arme (matériau = copie propre au joueur)
##   SangLame.coup(intensite, couleur)                        CombatEnnemi.effets_impact, coup d'arme qui fait saigner
##   SangLame.instance.quantite / .sec                        état (tests, captures)
## Le rendu est une variante du shader de la lame (shader_de : le code du shader ps1 / reflet + un masque de sang calculé dans le
## repère du modèle, texels de SANG_TEXEL m, bruit de valeur étiré le long de la lame + coulures d'un texel de large).

## Sang déposé par un coup (× ProfilImpact.sang × part) : léger 1 → 0,16, lourd 2,2 → 0,35, finisher 4,5 → 0,72.
const PAR_COUP := 0.16
## Le sang reste frais (brillant, goutte) DUREE_FRAIS s après le dernier coup, sèche en DUREE_SECHE s, puis s'efface en DUREE_EFFACE s.
const DUREE_FRAIS := 3.0
const DUREE_SECHE := 14.0
const DUREE_EFFACE := 26.0
const SANG_TEXEL := 0.0055

static var _variantes := {}
static var instance: SangLame
## Faux = sang v2 coupé (mesures de coût).
static var actif := true

var mat: ShaderMaterial
var garde := Vector3(0, 0.1, 0)
var pointe := Vector3(0, 0.9, 0)
var quantite := 0.0
var sec := 0.0
var coule := 0.0
var couleur := Color(0.30, 0.03, 0.025)
var depuis := 999.0
var _goutte := 0.0
## Temps CPU cumulé (µs, mesures).
static var cout_us := 0

static func equiper(hote: Node3D, materiau: ShaderMaterial, g: Vector3, p: Vector3) -> SangLame:
	if hote == null or materiau == null:
		return null
	var s := SangLame.new()
	s.name = "SangLame"
	s.garde = g
	s.pointe = p
	s.mat = materiau
	var avant := instance
	hote.add_child(s)
	var variante := shader_de(materiau.shader)
	if variante != materiau.shader:
		var sauve := {}
		for u: Dictionary in materiau.shader.get_shader_uniform_list():
			sauve[u["name"]] = materiau.get_shader_parameter(u["name"])
		materiau.shader = variante
		for k: String in sauve:
			if sauve[k] != null:
				materiau.set_shader_parameter(k, sauve[k])
	materiau.set_shader_parameter("sang_garde", g)
	materiau.set_shader_parameter("sang_pointe", p)
	materiau.set_shader_parameter("sang_graine", randf() * 97.0)
	if is_instance_valid(avant) and avant != s:
		# changement d'arme : la nouvelle lame est propre
		avant.queue_free()
	instance = s
	s._appliquer()
	return s

## Coup qui fait saigner : `intensite` ≈ ProfilImpact.sang × part de sang du coup.
static func coup(intensite: float, c: Color) -> void:
	if not actif or not is_instance_valid(instance) or Sang.niveau() == 0:
		return
	instance._coup(intensite, c)

func _coup(intensite: float, c: Color) -> void:
	var ajout := PAR_COUP * clampf(intensite, 0.3, 4.5) * (1.0 if Sang.niveau() == 2 else 0.5)
	# la couleur suit le sang le plus récent (mélange pondéré : le sang frais recouvre le sang sec)
	var k := ajout / maxf(quantite + ajout, 0.001)
	couleur = couleur.lerp(c, k) if quantite > 0.02 else c
	quantite = minf(1.0, quantite + ajout)
	sec *= 0.25
	coule = minf(coule, 0.35)
	depuis = 0.0
	_appliquer()

func _process(dt: float) -> void:
	if quantite <= 0.0:
		return
	var t0 := Time.get_ticks_usec()
	depuis += dt
	# coule vers la garde pendant les premières secondes
	coule = minf(1.0, coule + dt / 2.5)
	if depuis > DUREE_FRAIS:
		sec = minf(1.0, sec + dt / DUREE_SECHE)
		quantite = maxf(0.0, quantite - dt / DUREE_EFFACE)
	# gouttes qui tombent de la lame tant que le sang est frais et abondant
	if actif and quantite > 0.2 and sec < 0.35 and is_inside_tree():
		_goutte -= dt
		if _goutte <= 0.0:
			_goutte = randf_range(0.45, 1.1) / quantite
			var t := randf_range(0.45, 0.95)
			var pos := global_transform * garde.lerp(pointe, t)
			GouttesSang.lacher(self, pos, couleur, Vector3.ZERO, randf() < 0.3)
	_appliquer()
	cout_us += Time.get_ticks_usec() - t0

func _appliquer() -> void:
	if mat == null:
		return
	mat.set_shader_parameter("sang_quantite", quantite if actif else 0.0)
	mat.set_shader_parameter("sang_sec", sec)
	mat.set_shader_parameter("sang_coule", coule)
	mat.set_shader_parameter("sang_couleur", couleur)

## Remet la lame propre (tests, captures).
func nettoyer() -> void:
	quantite = 0.0
	sec = 0.0
	coule = 0.0
	depuis = 999.0
	_appliquer()

# ------------------------------------------------------------------ shader

const _UNIFORMES := """
uniform float sang_quantite = 0.0;
uniform float sang_sec = 0.0;
uniform float sang_coule = 0.0;
uniform vec3 sang_couleur : source_color = vec3(0.30, 0.03, 0.025);
uniform vec3 sang_garde = vec3(0.0, 0.1, 0.0);
uniform vec3 sang_pointe = vec3(0.0, 0.9, 0.0);
uniform float sang_texel = %s;
uniform float sang_graine = 0.0;
varying vec3 sg_pos;
varying vec3 sg_n;
float sg_h(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float sg_b(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sg_h(i), sg_h(i + vec2(1.0, 0.0)), f.x), mix(sg_h(i + vec2(0.0, 1.0)), sg_h(i + vec2(1.0)), f.x), f.y); }
"""

## Masque : texels de la lame (travers, long) ; bruit étiré le long de la lame (traînées laissées par la chair) ; plus de sang sur
## la moitié haute (la partie qui entre dans le corps) et sur les tranchants ; coulures d'un texel vers la garde, terminées par
## une goutte ; deux tons (film / caillot), sec en paliers par plaques ; un texel clair mouillé tant que c'est frais.
const _FRAGMENT := """
	if (sang_quantite > 0.002) {
		vec3 sg_ax = sang_pointe - sang_garde;
		float sg_l = max(length(sg_ax), 0.01);
		float sg_t = dot(sg_pos - sang_garde, sg_ax / sg_l) / sg_l;
		vec2 sg_q = floor(vec2(sg_pos.x + sg_pos.z * 0.6, sg_t * sg_l) / sang_texel);
		vec2 sg_qs = sg_q + vec2(sang_graine, sang_graine * 1.7);
		float sg_nb = sg_b(sg_qs * vec2(0.55, 0.11)) * 0.62 + sg_b(sg_qs * vec2(1.1, 0.4) + 17.0) * 0.28 + sg_h(sg_qs) * 0.10;
		float sg_zone = smoothstep(0.12, 0.62, sg_t) * (1.0 - smoothstep(0.985, 1.02, sg_t));
		float sg_bord = step(0.32, abs(normalize(sg_n).x));
		float sg_couv = sang_quantite * (0.45 + 0.7 * sg_zone) + sg_bord * 0.14 * sang_quantite;
		float sg_m = step(1.0 - sg_couv, sg_nb);
		float sg_caillot = step(1.0 - sg_couv * 0.55, sg_nb);
		float sg_col = sg_q.x + sang_graine;
		if (sg_h(vec2(sg_col, 3.1)) > 0.62) {
			float sg_t0 = 0.42 + sg_h(vec2(sg_col, 7.7)) * 0.5;
			float sg_lg = sang_coule * (0.05 + sg_h(vec2(sg_col, 1.3)) * 0.22) * min(1.0, sang_quantite * 2.5);
			float sg_tr = step(sg_t0 - sg_lg, sg_t) * step(sg_t, sg_t0) * step(0.08, sg_t);
			float sg_bout = step(sg_t0 - sg_lg - 1.6 * sang_texel / sg_l, sg_t) * step(sg_t, sg_t0 - sg_lg) * step(0.02, sg_lg);
			sg_m = max(sg_m, max(sg_tr, sg_bout));
			sg_caillot = max(sg_caillot, sg_bout);
		}
		vec3 sg_frais = sang_couleur * 1.35;
		vec3 sg_seche = sang_couleur * vec3(0.62, 0.46, 0.42);
		float sg_s = step(0.5, sang_sec + (sg_nb - 0.5) * 0.9 - 0.05);
		vec3 sg_c = mix(sg_frais, sg_seche, sg_s) * mix(1.0, 0.62, sg_caillot);
		float sg_brille = step(0.9, sg_h(sg_qs + 5.0)) * (1.0 - sg_s) * sg_caillot;
		sg_c += sg_brille * vec3(0.22, 0.07, 0.05);
		ALBEDO = mix(ALBEDO, sg_c, sg_m);
		EMISSION *= 1.0 - sg_m;
	}
	ROUGHNESS = 1.0;
}"""

## Variante d'un shader dérivé de ps1.gdshader (lame, lame dorée, obsidienne : reflet L9 compris) avec le masque de sang.
static func shader_de(base: Shader) -> Shader:
	if base == null:
		return null
	if base.code.contains("sang_quantite"):
		return base
	var cle := base.get_instance_id()
	if _variantes.has(cle):
		return _variantes[cle]
	var sh := Shader.new()
	sh.code = base.code \
		.replace("uniform vec3 emission : source_color = vec3(0.0);", "uniform vec3 emission : source_color = vec3(0.0);" + (_UNIFORMES % str(SANG_TEXEL))) \
		.replace("void vertex() {\n", "void vertex() {\n\tsg_pos = VERTEX;\n\tsg_n = NORMAL;\n") \
		.replace("\tROUGHNESS = 1.0;\n}", _FRAGMENT)
	_variantes[cle] = sh
	return sh
