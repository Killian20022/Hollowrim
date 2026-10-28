// SOCLE « impact des sorts sur les corps » (scripts/magie/impact_corps.gd) : couche posée par-dessus les maillages d'un
// corps touché (material_overlay). UN SEUL matériau partagé par tous les corps : l'état de chaque maillage passe par des
// paramètres D'INSTANCE (set_instance_shader_parameter) → aucun matériau créé ni dupliqué par impact.
// Mélange prémultiplié : sortie = lumière ajoutée + fond × (1 − ALPHA) → la même passe ÉCLAIRE (braises, contours
// rougeoyants, flammèches) et ASSOMBRIT (carbonisation légère).
// Sommets gonflés de `gonfle` et accrochés à la MÊME grille que le shader ps1 du modèle (comme magie_voile) : pas de
// scintillement entre le corps et sa couche.
//
// Canaux (instance) :
//   mc_feu  : xyz = point d'impact (monde), w = chaleur 0..1 (1 = sous le jet, ~0,4 = brûlure)
//   mc_dir  : xyz = direction du jet (monde), w = carbonisation 0..1
//   mc_mesh : x = grille ps1 du modèle (0 = aucune), y = gonfle (m, repère objet), z = cases du motif par mètre
//   mc_autre: x = couverture du feu (0..1, grandit avec la durée du jet), y, z libres (B passe par mc_ecoles) ; w = part du jet (0..1)
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

// index d'instance fixés (10..15) : le voile est un material_overlay, il partage les emplacements d'instance du maillage avec
// le matériau du personnage (ps1_draugr : eclair = 0 ; perso : 0..8) ; sans index, mc_feu écrasait ces paramètres-là.
instance uniform vec4 mc_feu : instance_index(10) = vec4(0.0);
instance uniform vec4 mc_dir : instance_index(11) = vec4(0.0, 0.0, -1.0, 0.0);
instance uniform vec4 mc_mesh : instance_index(12) = vec4(135.0, 0.006, 64.0, 0.0);
instance uniform vec4 mc_autre : instance_index(13) = vec4(0.0);
// écoles de l'agent B (givre, choc, ténèbres) : mc_ecoles (14), mc_pt (15)
#include "res://shaders/magie_corps_ecoles.gdshaderinc"

uniform vec4 c0 : source_color = vec4(0.35, 0.07, 0.05, 1.0);   // rouge sombre (braise qui meurt)
uniform vec4 c1 : source_color = vec4(0.70, 0.20, 0.12, 1.0);   // #b3341f
uniform vec4 c2 : source_color = vec4(0.93, 0.42, 0.12, 1.0);   // #ec6a1f
uniform vec4 c3 : source_color = vec4(0.99, 0.71, 0.23, 1.0);   // #fcb53a
uniform vec4 c4 : source_color = vec4(1.0, 0.94, 0.66, 1.0);    // #fff0a8
uniform vec3 charbon : source_color = vec3(0.05, 0.03, 0.025);
uniform float eclat = 1.35;
uniform float rayon_chaud = 0.5;   // rayon (m) de la zone la plus chaude autour de l'impact

varying vec3 p_obj;
varying vec3 p_monde;
varying vec3 n_monde;
varying vec3 n_vue;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	VERTEX += NORMAL * mc_mesh.y;
	p_obj = VERTEX;
	p_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	n_vue = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (mc_mesh.x > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(mc_mesh.x * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, mc_mesh.x);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

vec3 palette(float t) {
	// paliers francs (pas de dégradé lisse) : PS1
	if (t < 0.2) return c0.rgb;
	if (t < 0.4) return c1.rgb;
	if (t < 0.62) return c2.rgb;
	if (t < 0.85) return c3.rgb;
	return c4.rgb;
}

void fragment() {
	float chaleur = mc_feu.w;
	float carbo = mc_dir.w;
	if (chaleur <= 0.002 && carbo <= 0.002 && !ecoles_actives()) {
		discard;
	}
	vec3 d = normalize(mc_dir.xyz + vec3(0.0, 0.00001, 0.0));
	vec3 n = normalize(n_monde);
	float face = clamp(-dot(n, d) * 0.5 + 0.5, 0.0, 1.0);          // côté tourné vers le jet
	vec3 v = p_monde - mc_feu.xyz;
	float di = length(v);
	float rc = rayon_chaud * (1.0 + 0.9 * clamp(mc_autre.x, 0.0, 1.0));   // couverture du feu (FeuCorps)
	float prox = exp(-(di * di) / (rc * rc));    // près du point touché
	float hloc = chaleur * face * face * (0.2 + 0.8 * prox);
	float cases = mc_mesh.z;
	// lueur du corps éclairé de l'intérieur : 3 paliers concentriques autour du point touché (pas de grain)
	float a_lum = step(0.3, hloc) * 0.2 + step(0.55, hloc) * 0.2 + step(0.8, hloc) * 0.2;
	float t = hloc;
	// braises (grosses cases rares qui palpitent), là où ça a chauffé puis carbonisé
	vec3 qb = floor(p_obj * cases * 0.4);
	float b = h3(qb + 3.1);
	float palp = 0.55 + 0.45 * sin(TIME * (4.0 + b * 6.0) + b * 30.0);
	float braise = step(0.93, b) * clamp(hloc * 1.4 + carbo * min(chaleur * 2.5, 1.0), 0.0, 1.0) * palp;
	// contour rougeoyant (bord de la silhouette vue de l'œil), côté chaud
	float bord = 1.0 - abs(normalize(n_vue).z);
	// (2026-10-28, intensité) contour plus large et plus vif, côté chaud : la silhouette se lit DANS les flammes
	float contour = (step(0.62, bord) * 0.75 + step(0.8, bord) * 0.25) * chaleur * (0.35 + 0.65 * face);
	a_lum = max(a_lum, max(braise, contour * 0.85));
	t = max(t, max(braise * 0.6, contour * step(0.8, bord) * 0.75));
	a_lum = ceil(clamp(a_lum, 0.0, 0.8) * 3.0 - 0.05) / 3.0;
	// jamais d'aplat clair : au plus de l'orange (le blanc-jaune est réservé au cœur de la coque, dans la couche fine)
	vec3 lum = palette(clamp(t * 0.75 + 0.12, 0.0, 0.8)) * eclat * a_lum * 0.9;
	// carbonisation : taches sombres (jamais un aplat : le motif du corps reste lisible)
	float tache = h3(floor(p_obj * cases * 0.3) + 11.0);
	float a_noir = carbo * (0.25 + 0.45 * step(0.4, tache)) * (0.45 + 0.55 * face);
	a_noir = floor(a_noir * 4.0) / 4.0;
	// givre, choc, ténèbres (magie_corps_ecoles.gdshaderinc)
	vec3 add_e = vec3(0.0);
	float a_e = 0.0;
	voile_ecoles(p_monde, p_obj, n, n_vue, cases, TIME, add_e, a_e);
	if (a_lum <= 0.0 && a_noir <= 0.0 && a_e <= 0.0 && dot(add_e, vec3(1.0)) <= 0.0) {
		discard;
	}
	// sortie prémultipliée : couleur ajoutée + fond × (1 − ALPHA)
	ALBEDO = lum + charbon * a_noir + add_e;
	ALPHA = clamp(a_noir + a_e, 0.0, 0.85);
}
