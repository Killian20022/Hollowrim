// Lot 6 : halo chaud de la torche tenue, carte additive TOUJOURS face à la caméra, anneaux posterisés nets (texture halo, filtre
// plus proche voisin). `intensite` suit la lumière vacillante (réglée par mains.gd).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform sampler2D halo : source_color, filter_nearest, repeat_disable;
uniform float taille = 0.6;
uniform float intensite = 1.0;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 droite = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 haut = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 pos = centre + droite * VERTEX.x * taille + haut * VERTEX.y * taille;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
}

void fragment() {
	vec4 t = texture(halo, UV);
	ALBEDO = t.rgb * intensite;
	ALPHA = t.a;
}
