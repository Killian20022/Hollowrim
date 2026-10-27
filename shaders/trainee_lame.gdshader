// Traînée de lame pixel art (scripts/combat/trainee_lame.gd) : ruban garde → pointe, sommets accrochés à la grille
// d'écran de 270 lignes comme le shader ps1, palette LIMITÉE à 3 tons et 4 paliers d'opacité (pas de dégradé lisse,
// pas de tramage). UV.y : 0 à la garde → 1 à la pointe ; COLOR.a : vie de l'échantillon (1 neuf → 0 effacé).
// Compatible rendu Web (Compatibility) : unshaded, mélange alpha, sans texture.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 couleur : source_color = vec4(0.72, 0.8, 0.92, 1.0);
uniform vec4 coeur : source_color = vec4(1.0);
uniform float grille = 135.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float vie = COLOR.a;
	float le_long = UV.y;
	// bande côté pointe (le dernier tiers de la lame), bord vif à la pointe ; s'éteint avec l'âge
	float a = vie * smoothstep(0.5, 0.97, le_long);
	a = max(a, vie * step(0.9, le_long) * 1.0);
	float q = floor(a * 4.0 + 0.3) / 4.0;   // 4 paliers
	if (q <= 0.0) {
		discard;
	}
	vec3 sombre = couleur.rgb * 0.7;
	vec3 c = q >= 0.75 ? coeur.rgb : (q >= 0.5 ? mix(couleur.rgb, coeur.rgb, 0.5) : (q >= 0.25 ? couleur.rgb : sombre));
	ALBEDO = c;
	ALPHA = 0.35 + q * 0.6;
}
