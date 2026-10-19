// Outil de diagnostic (outils/galerie_trous.gd) : même tremblement de sommets que ps1.gdshader,
// mais SANS élimination des faces arrière, qui sont peintes en jaune. Du jaune visible = on voit
// l'intérieur d'un maillage (un trou dans le rendu réel en cull_back).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float grille = 135.0;
uniform vec3 dos : source_color = vec3(1.0, 1.0, 0.0); // couleur des faces arrière (une par maillage)

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float l = 0.12 + 0.4 * max(dot(normalize(NORMAL), normalize(vec3(0.3, 0.5, 0.8))), 0.0);
	ALBEDO = FRONT_FACING ? vec3(l) : dos;
}
