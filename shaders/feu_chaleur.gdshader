// Distorsion de chaleur au-dessus d'un feu de camp : plan face à la caméra qui relit l'image déjà rendue et la décale par BLOCS de
// pixels (grille d'écran de `bloc` px, 8 i/s), jamais de flou ni de dégradé : l'esprit PS1. Le décalage est nul sur les bords
// (masque ovale en paliers) et plus fort en haut. Un seul plan par feu de camp, coupé au-delà de ~25 m par scripts/feu_fixe.gd.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D ecran : hint_screen_texture, filter_nearest, repeat_disable;
uniform float bloc = 6.0;
uniform float force_px = 3.0;
uniform float taille_x = 1.1;
uniform float taille_y = 1.8;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 vers = normalize(vec3(INV_VIEW_MATRIX[3].x - centre.x, 0.0, INV_VIEW_MATRIX[3].z - centre.z));
	vec3 droite = vec3(vers.z, 0.0, -vers.x);
	vec3 pos = centre + droite * VERTEX.x * taille_x + vec3(0.0, VERTEX.y * taille_y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 q = vec2(UV.x - 0.5, 1.0 - UV.y) * vec2(2.0, 1.0);   // x -1..1, y 0 (pied) .. 1 (haut)
	float m = 1.0 - length(vec2(q.x, q.y * 0.9 - 0.15));
	m = floor(clamp(m, 0.0, 1.0) * 3.0) / 3.0;
	if (m <= 0.0) {
		discard;
	}
	vec2 px = floor(FRAGCOORD.xy / bloc);
	float f = floor(TIME * 8.0);
	vec2 d = vec2(h21(px + f * 3.1) - 0.5, h21(px.yx * 1.7 + f * 5.3) - 0.5);
	d = floor(d * force_px * m * (0.5 + q.y) + 0.5);
	ALBEDO = textureLod(ecran, SCREEN_UV + d / VIEWPORT_SIZE, 0.0).rgb;
	ALPHA = 0.999;        // passe transparente : lit l'image rendue avant lui (flammes comprises)
}
