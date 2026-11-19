// Arcs de l'effet passif « électricité » des lames (effet_element_lame.gd) : lignes d'un pixel, couleur de sommet, additif.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform float eclat = 1.5;

void fragment() {
	vec3 c = COLOR.rgb;
	c = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
	ALBEDO = c * eclat;
}
