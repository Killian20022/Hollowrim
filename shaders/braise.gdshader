// Lot 6 : braises de la tête de torche, texture pixel art (croûte noire et fentes incandescentes) sans éclairage ;
// la luminosité des fentes vacille avec la flamme.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_echelle = vec2(2.0, 1.0);
uniform float phase = 0.0;

void fragment() {
	vec3 c = texture(tex, UV * uv_echelle).rgb;
	float lueur = smoothstep(0.35, 0.8, dot(c, vec3(0.5, 0.35, 0.15)));        // seulement les pixels incandescents vacillent
	float v = 0.88 + 0.12 * sin(TIME * 17.0 + phase) * sin(TIME * 7.3 + phase * 2.0);
	ALBEDO = c * mix(1.0, v, lueur);
}
