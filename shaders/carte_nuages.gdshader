// Carte du monde : couche de nuages au-dessus du relief, façon carte de Skyrim. Légers au centre (on voit la carte), épais
// sur le pourtour (cadre de brume) ; s'effacent quand on zoome (`clair` posé par l'onglet). Dessous gris, dessus blanc.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform sampler2D nuages : filter_linear, repeat_enable;
uniform vec2 vent = vec2(0.0035, 0.0012);
uniform float echelle_nuages = 0.0042;
uniform float clair = 1.0;       // 1 = vue d'ensemble, 0 = zoom serré
uniform vec2 bord = vec2(95.0, 175.0);
uniform float temps = 0.0;
uniform vec3 blanc : source_color = vec3(0.95, 0.96, 0.97);
uniform vec3 gris : source_color = vec3(0.66, 0.70, 0.75);

varying vec3 pm;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pm.xz * echelle_nuages + vent * temps;
	float n = texture(nuages, p).r;
	float n2 = texture(nuages, p * 2.7 + vec2(0.31, 0.17)).r;
	float d = max(abs(pm.x), abs(pm.z));
	float cadre = smoothstep(bord.x, bord.y, d);
	float seuil = mix(0.62, 0.30, cadre);
	float a = smoothstep(seuil, seuil + 0.16, n * 0.75 + n2 * 0.25);
	a *= mix(0.42 * clair, 0.96, cadre);
	float relief = clamp((n2 - 0.35) * 1.6, 0.0, 1.0);
	ALBEDO = mix(gris, blanc, relief);
	ALPHA = a;
}
