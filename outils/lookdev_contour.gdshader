// Look-dev : contour sombre par coque inversée, d'épaisseur constante À L'ÉCRAN (en pixels de 640×360),
// accroché à la même grille que ps1 (le contour ne glisse pas par rapport au corps).
shader_type spatial;
render_mode unshaded, cull_front, specular_disabled;

uniform vec4 couleur : source_color = vec4(0.06, 0.05, 0.07, 1.0);
uniform float epaisseur = 1.0;   // pixels
uniform float grille = 180.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 n = (PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xy;
	if (length(n) > 1e-5) {
		clip.xy += normalize(n) * epaisseur * 2.0 / VIEWPORT_SIZE.y * clip.w;
	}
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = couleur.rgb;
}
