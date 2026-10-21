// Contour sombre des personnages pilotes : coque inversée d'épaisseur constante À L'ÉCRAN (en pixels),
// accrochée à la même grille que ps1 (le contour ne glisse pas par rapport au corps). Posé en `next_pass`
// des matériaux opaques (même maillage, même peau d'os : suit les animations). Pas sur les cartes découpées.
shader_type spatial;
render_mode unshaded, cull_front, specular_disabled, shadows_disabled;

uniform vec4 couleur : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform float epaisseur = 1.2;   // pixels
uniform float grille = 135.0;
uniform float affine = 1.0;      // inutilisé (présent pour Palette.regler_ps1)

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// direction de la normale en PIXELS (l'écran n'est pas carré), décalage d'`epaisseur` pixels
	vec2 n = (PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xy * VIEWPORT_SIZE;
	if (length(n) > 1e-5) {
		clip.xy += normalize(n) * epaisseur * 2.0 / VIEWPORT_SIZE * clip.w;
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
