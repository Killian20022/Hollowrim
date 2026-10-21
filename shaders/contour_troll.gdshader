// Contour sombre du Troll de givre : même coque inversée que contour_perso (épaisseur constante en pixels, accrochée à la grille
// ps1), mais RECULÉE de `recul` mètres le long du rayon de vue. La coque ne perce plus dans les creux du corps (sous les
// pectoraux, sous le menton, plis du ventre : les « traits de plastron » de la passe 2) ; elle reste visible au bord de la
// silhouette et là où un membre passe devant le corps à plus de `recul`.
shader_type spatial;
render_mode unshaded, cull_front, specular_disabled, shadows_disabled;

uniform vec4 couleur : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform float epaisseur = 1.2;   // pixels
uniform float recul = 0.10;      // mètres (repère de la caméra)
uniform float grille = 135.0;
uniform float affine = 1.0;      // inutilisé (présent pour Palette.regler_ps1)

void vertex() {
	vec4 vue = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vue.xyz += normalize(vue.xyz) * recul;
	vec4 clip = PROJECTION_MATRIX * vue;
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
