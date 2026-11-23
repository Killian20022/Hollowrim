// TÉLÉKINÉSIE (scripts/magie/telekinesie.gd) : lueur ADDITIVE posée par-dessus un objet saisi ou visé (material_overlay, ou copie du
// maillage d'un objet vivant). Même principe que magie_voile.gdshader : on n'ajoute que de la lumière, en paliers francs (pas de
// tramage) : un BORD bleu pâle qui épouse la silhouette, des motes claires qui montent lentement sur la surface, et une onde qui
// parcourt l'objet de bas en haut. Sommets gonflés et accrochés à la grille du shader ps1 (`grille`) : la lueur reste collée.
// force : 0,45 = objet visé (surbrillance), ~1 = tenu, > 1 = au lancer.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 couleur : source_color = vec4(0.55, 0.77, 0.94, 1.0);
uniform vec4 coeur : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float force = 1.0;
uniform float grille = 135.0;
uniform float gonfle = 0.008;
uniform float cases = 48.0;      // cases du motif par mètre (repère de l'objet)

varying vec3 p_obj;
varying vec3 n_vue;
varying float h_monde;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	VERTEX += NORMAL * gonfle;
	p_obj = VERTEX;
	h_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	n_vue = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float bord = 1.0 - abs(normalize(n_vue).z);
	// bord en deux paliers (silhouette seulement : le bois, le fer restent lisibles au centre)
	float a = step(0.62, bord) * 0.35 + step(0.85, bord) * 0.45;
	// motes : quelques cases qui s'allument une à une et montent
	vec3 q = floor(p_obj * cases + vec3(0.0, -TIME * 2.2, 0.0));
	float n = h3(q);
	float clign = step(0.8, fract(n * 13.0 + TIME * 0.7));
	float mote = step(0.955, n) * (0.4 + 0.5 * clign);
	// onde lumineuse qui parcourt l'objet de bas en haut (une fine bande), surtout sur le bord
	float onde = step(0.95, fract(h_monde * 1.4 - TIME * 0.9)) * 0.45 * (0.3 + 0.7 * bord);
	a = max(a, max(mote, onde));
	a *= force;
	// paliers francs ; ce qui reste sous le premier palier disparaît (pas de voile sur tout l'objet)
	a = floor(a * 3.0 + 0.25) / 3.0;
	if (a <= 0.0) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
		return;
	}
	ALBEDO = mix(couleur.rgb, coeur.rgb, clamp(mote * clign + step(0.85, bord) * 0.6, 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 0.8);
}
