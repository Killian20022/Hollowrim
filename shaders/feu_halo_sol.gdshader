// Halo de chaleur d'un feu : carte HORIZONTALE additive posée au sol, anneaux en PALIERS FRANCS (5 niveaux), bord déchiqueté par un
// bruit de valeur en cases de monde (jamais de Bayer), niveaux qui respirent d'un palier avec la lumière (`pouls`, 14 i/s côté script).
// Plus l'ambiance est sombre plus il se lit ; additif : n'écrase pas la neige, la réchauffe.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 teinte : source_color = vec3(1.0, 0.50, 0.16);
uniform float intensite = 0.5;
uniform float pouls = 1.0;
uniform float niveaux = 6.0;
uniform float case_m = 0.12;

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
	// décroissance DOUCE jusqu'à zéro au bord de la carte (aucun bord net), gonflée près du feu
	float v = 1.0 - smoothstep(0.0, 1.0, r);
	v = pow(v, 2.4);
	// quantification en gros pixels MAIS tramée par un bruit de valeur en cases de monde (jamais de Bayer) : les paliers se mêlent
	float bruit = mix(h21(floor(v_monde.xz / case_m)), h21(floor(v_monde.xz / (case_m * 2.0)) + 7.0), 0.5);
	float pal = floor(v * niveaux * pouls + bruit) / niveaux;
	if (pal <= 0.0) {
		discard;
	}
	ALBEDO = teinte * pal * intensite;
	ALPHA = 1.0;
}
