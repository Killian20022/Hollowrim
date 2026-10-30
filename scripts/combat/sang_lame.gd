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

## Sang déposé par un coup (× ProfilImpact.sang × part) : léger 1 → 0,14, lourd 2,2 → 0,31, finisher 4,5 → 0,63.
## Retouche 2026-10-30 : 6 coups légers ≈ 0,84 → ~40 % de la lame couverte (moitié haute ~55 %), plafond ~48 % (moitié haute ~65 %), filets compris (calibré hors
## Godot sur une copie du masque) ; la lame n'est jamais entièrement rouge.
const PAR_COUP := 0.14
## Le sang reste frais (brillant, goutte) DUREE_FRAIS s après le dernier coup, sèche en DUREE_SECHE s, puis s'efface en DUREE_EFFACE s.
const DUREE_FRAIS := 3.0
const DUREE_SECHE := 14.0
const DUREE_EFFACE := 26.0
const SANG_TEXEL := 0.003

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

var _envoye := Vector4(-1, -1, -1, -1)

## Paramètres envoyés seulement s'ils ont changé de plus d'un pas visible (chaque envoi repasse par le serveur de rendu).
func _appliquer() -> void:
	if mat == null:
		return
	var v := Vector4(quantite if actif else 0.0, sec, coule, 0.0)
	if absf(v.x - _envoye.x) > 0.004 or (v.x == 0.0) != (_envoye.x == 0.0):
		mat.set_shader_parameter("sang_quantite", v.x)
		_envoye.x = v.x
	if absf(v.y - _envoye.y) > 0.01:
		mat.set_shader_parameter("sang_sec", v.y)
		_envoye.y = v.y
	if absf(v.z - _envoye.z) > 0.01:
		mat.set_shader_parameter("sang_coule", v.z)
		_envoye.z = v.z
	if depuis == 0.0 or _envoye.w < 0.0:
		mat.set_shader_parameter("sang_couleur", couleur)
		_envoye.w = 1.0

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

## Masque (retouche 2026-10-30, plus de pavés francs) : texels de 3 mm ; bruit fractal à 3 octaves étiré le long de la lame (taches
## organiques, contours déchiquetés par l'octave fine + un grain d'un texel) ; plus de sang sur la moitié haute et les tranchants ;
## ÉPAISSEUR en 3 paliers (film mince qui laisse voir l'acier, sang, caillot sombre) ; gouttelettes isolées autour des taches ;
## FILETS : 4 coulures d'un texel qui serpentent dans la gouttière vers la garde, terminées par une perle ; sec par plaques ;
## un texel clair mouillé tant que c'est frais. Jamais de tramage.
const _FRAGMENT := """
	if (sang_quantite > 0.002) {
		vec3 sg_ax = sang_pointe - sang_garde;
		float sg_l = max(length(sg_ax), 0.01);
		float sg_t0 = dot(sg_pos - sang_garde, sg_ax / sg_l);
		vec2 sg_q = floor(vec2(sg_pos.x + sg_pos.z * 0.6, sg_t0) / sang_texel);
		vec2 sg_p = (sg_q + 0.5) * sang_texel;
		float sg_t = sg_p.y / sg_l;
		vec2 sg_g = vec2(sang_graine, sang_graine * 1.7);
		vec2 sg_uv = vec2(sg_p.x / 0.012, sg_p.y / 0.05) + sg_g;
		float sg_nb = 0.55 * sg_b(sg_uv) + 0.30 * sg_b(sg_uv * vec2(2.3, 2.1) + 17.0) + 0.15 * sg_b(sg_uv * vec2(5.0, 4.5) + 31.0);
		float sg_grain = sg_h(sg_q + sg_g);
		sg_nb += (sg_grain - 0.5) * 0.05;
		float sg_zone = smoothstep(0.12, 0.62, sg_t) * (1.0 - smoothstep(0.985, 1.02, sg_t));
		float sg_bord = step(0.32, abs(normalize(sg_n).x));
		float sg_seuil = 0.755 - sang_quantite * (0.12 + 0.11 * sg_zone + 0.10 * sg_bord);
		float sg_e = sg_nb - sg_seuil;
		float sg_m = step(0.0, sg_e);
		float sg_film = sg_m * (1.0 - step(0.03, sg_e));
		float sg_caillot = step(0.10, sg_e);
		// gouttelettes isolées autour des taches
		float sg_gt = step(-0.06, sg_e) * (1.0 - sg_m) * step(0.955, sg_h(sg_q * 1.37 + sg_g + 9.0)) * step(0.08, sang_quantite);
		// filets dans la gouttière, vers la garde
		float sg_fil = 0.0;
		float sg_perle = 0.0;
		for (int k = 0; k < 4; k++) {
			float fk = float(k);
			float sg_hk = sg_h(vec2(fk * 7.3 + sang_graine, 3.1));
			if (sg_hk < 0.2) { continue; }
			float sg_xc = (fk - 1.5) * 0.0052 + (sg_h(vec2(fk, sang_graine)) - 0.5) * 0.003
				+ 0.0013 * sin(sg_p.y * 90.0 + fk * 2.1 + sang_graine) + 0.0007 * sin(sg_p.y * 230.0 + fk * 4.7);
			float sg_haut = 0.48 + sg_h(vec2(fk, 7.7 + sang_graine)) * 0.42;
			float sg_lg = sang_coule * (0.12 + sg_h(vec2(fk, 1.3 + sang_graine)) * 0.3) * min(1.0, sang_quantite * 2.2);
			float sg_bas = sg_haut - sg_lg;
			float sg_dx = abs(sg_p.x - sg_xc);
			float dedans = step(sg_bas, sg_t) * step(sg_t, sg_haut) * step(0.06, sg_t) * step(0.08, sang_quantite);
			sg_fil = max(sg_fil, dedans * step(sg_dx, sang_texel * 0.5));
			float sg_bout = step(sg_bas - 2.0 * sang_texel / sg_l, sg_t) * step(sg_t, sg_bas + sang_texel / sg_l) * step(0.03, sg_lg);
			sg_perle = max(sg_perle, sg_bout * step(sg_dx, sang_texel * 1.1) * step(0.06, sg_t));
		}
		float sg_tout = max(max(sg_m, sg_gt), max(sg_fil, sg_perle));
		vec3 sg_frais = min(sang_couleur * 1.8, vec3(1.0));
		vec3 sg_seche = sang_couleur * vec3(0.62, 0.46, 0.42);
		float sg_s = step(0.5, sang_sec + (sg_nb - 0.5) * 0.9 - 0.05);
		vec3 sg_c = mix(sg_frais, sg_seche, sg_s) * mix(1.0, 0.68, max(sg_caillot, sg_perle)) * mix(1.0, 0.86, sg_fil * (1.0 - sg_m));
		float sg_brille = step(0.975, sg_h(sg_q + sg_g + 5.0)) * (1.0 - sg_s) * max(sg_caillot, sg_perle);
		sg_c += sg_brille * vec3(0.22, 0.07, 0.05);
		// film mince : l'acier transparaît (palier, pas de dégradé lissé)
		float sg_op = sg_tout * mix(1.0, 0.6, sg_film * (1.0 - max(sg_fil, sg_perle)));
		ALBEDO = mix(ALBEDO, sg_c, sg_op);
		EMISSION *= 1.0 - sg_tout;
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
