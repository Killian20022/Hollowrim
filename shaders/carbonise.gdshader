// Voile « carbonisé » (Demembrement.carboniser, mort par le feu) posé en material_overlay sur les maillages du corps :
// multiplie la couleur (blend_mul) vers le charbon, par taches de BRUIT (texels d'écran, jamais de tramage Bayer) qui gagnent
// tout le corps quand `carbonise` monte à 1. Même accroche des sommets que le corps (grille), léger décalage vers la caméra.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;

uniform float grille = 135.0;
instance uniform float carbonise = 0.0;


float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	clip.z += 0.0004 * clip.w;   // juste devant le corps (reverse-z : plus grand = plus près)
	POSITION = clip;
}

void fragment() {
	// taches : bruit par cellule d'UV (stable quand le corps bouge) ; la carbonisation les allume une à une
	float n = hash(vec3(floor(UV * 40.0), 3.0));
	float noir = step(n, carbonise * 1.15);
	vec3 charbon = mix(vec3(0.16, 0.13, 0.12), vec3(0.09, 0.075, 0.07), step(0.5, hash(vec3(floor(UV * 96.0), 7.0))));
	ALBEDO = mix(vec3(1.0), charbon, noir * clamp(carbonise * 1.4, 0.0, 1.0));
}
