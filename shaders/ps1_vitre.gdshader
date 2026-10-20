// Vitrage des fenêtres (lot « kit intérieur ») : cadre et plombs opaques, carreaux translucides (on voit le
// dehors depuis la maison), de plus en plus opaques avec la distance (vu de loin, c'est une fenêtre éclairée).
// Vu du dehors la nuit, les carreaux s'allument (`nuit` 0..1, réglée par `Interieur`) ; vu du dedans, jamais.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D tex_vitrage : source_color, filter_nearest, repeat_disable;
uniform float nuit = 0.0;
uniform vec3 lueur : source_color = vec3(1.0, 0.72, 0.34);
uniform vec2 fondu = vec2(6.0, 12.0);   // mètres : translucide → opaque (l intérieur est masqué au-delà de 13 m)
uniform float grille = 135.0;

varying float dist;

void vertex() {
	dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec4 t = texture(tex_vitrage, UV);
	bool carreau = t.a < 0.5;
	float f = smoothstep(fondu.x, fondu.y, dist);
	vec3 verre = FRONT_FACING ? mix(vec3(0.16, 0.2, 0.3), lueur * t.rgb * 1.5, nuit) : vec3(0.1, 0.14, 0.2);
	vec3 c = carreau ? verre : t.rgb * (FRONT_FACING ? 0.8 : 0.28);
	if (carreau && FRONT_FACING) {
		c = mix(c, lueur * t.rgb * 1.5, f * (1.0 - nuit));   // de jour, de loin : verre pâle
	}
	ALBEDO = c;
	ALPHA = carreau ? mix(0.34, 1.0, max(f, nuit * float(FRONT_FACING) * 0.75)) : 1.0;
}
