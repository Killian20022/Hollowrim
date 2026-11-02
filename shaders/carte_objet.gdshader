// Carte du monde : sapins, bâtiments, palissade, pierres (couleur de sommet), même accroche PS1 et même brume que le relief.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D nuages : filter_linear, repeat_enable;
uniform vec2 vent = vec2(0.0035, 0.0012);
uniform float echelle_nuages = 0.0042;
uniform float ombre_nuages = 0.22;
uniform vec3 brume_couleur : source_color = vec3(0.82, 0.85, 0.87);
uniform vec2 brume_dist = vec2(112.0, 205.0);
uniform float grille = 150.0;
uniform float temps = 0.0;
uniform vec3 emission_base : source_color = vec3(0.0);

varying vec3 pm;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0) * 0.5;
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float n = texture(nuages, pm.xz * echelle_nuages + vent * temps).r;
	c *= 1.0 - ombre_nuages * smoothstep(0.5, 0.75, n);
	float b = smoothstep(brume_dist.x, brume_dist.y, max(abs(pm.x), abs(pm.z)));
	ALBEDO = mix(c, vec3(0.0), b);
	EMISSION = brume_couleur * b + emission_base;
}
