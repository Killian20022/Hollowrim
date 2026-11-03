// Lit de braises d'un feu de camp / foyer : carte HORIZONTALE additive posée sur les braises, en CASES de monde (grille fixe au sol,
// donc stable quand on bouge), 3 tons francs (braise sombre, rouge, orange vif), cases qui s'allument et s'éteignent par PALIERS
// (8 i/s), pulsation lente globale `pouls` (réglée par scripts/feu_fixe.gd). Aucun dégradé lisse, aucun tramage : bruit de valeur.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform float rayon = 0.5;
uniform float case_m = 0.05;
uniform float pouls = 1.0;
uniform vec3 c_vif : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 c_rouge : source_color = vec3(0.85, 0.20, 0.06);
uniform vec3 c_sombre : source_color = vec3(0.30, 0.06, 0.03);

varying vec3 v_monde;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	vec2 cell = floor(v_monde.xz / case_m);
	float f = floor(TIME * 8.0);
	float n = h21(cell + 17.0);
	float n2 = h21(cell * 1.3 + f * 1.7);
	float allume = n * 0.55 + n2 * 0.45;
	float bord = 1.0 - r;
	float respire = 0.9 + 0.1 * floor(sin(TIME * 1.7 + h21(floor(v_monde.xz * 0.37)) * 6.0) * 3.0 + 0.5) / 3.0;   // respiration lente, par paliers
	float v = allume * (0.55 + 0.9 * bord) * pouls * respire;
	vec3 col;
	if (v > 0.78) {
		col = c_vif;
	} else if (v > 0.5) {
		col = c_rouge;
	} else if (v > 0.3 - 0.0) {
		col = c_sombre;
	} else {
		discard;
	}
	ALBEDO = col * (0.8 + 0.4 * pouls);
	ALPHA = 1.0;
}
