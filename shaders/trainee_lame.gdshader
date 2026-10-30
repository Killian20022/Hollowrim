// Traînée de lame pixel art (scripts/combat/trainee_lame.gd) : ruban garde → pointe, sommets accrochés à la grille
// d'écran de 270 lignes comme le shader ps1, palette LIMITÉE à 3 tons et 4 paliers d'opacité (pas de dégradé lisse,
// pas de tramage ordonné : bords effrités au bruit blanc, coups_v4). UV.y : 0 à la garde → 1 à la pointe ; COLOR.a : vie de l'échantillon (1 neuf → 0 effacé).
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
	// bande le long du TRANCHANT : naît au quart de la lame (près de la garde, rien), pleine sur le dernier tiers ;
	// s'éteint avec l'âge (les échantillons les plus anciens disparaissent d'abord : la traînée « rattrape » la lame).
	// Une bande large (et non un croissant au bout de la pointe) suit la partie de la lame qui traverse l'écran : avec
	// une lame levée, un croissant limité à la pointe restait collé au haut de l'image, identique d'un coup à l'autre.
	float a = vie * smoothstep(0.3, 0.8, le_long);
	// coups_v4 (traînée DISCRÈTE) : bords effrités par un BRUIT blanc sur la grille de l'écran 480×270 (cases de la taille d'un
	// pixel du rendu ; jamais de matrice de Bayer) : la queue de la traînée se dissout en pixels épars au lieu d'un bord net.
	vec2 cell = floor(FRAGCOORD.xy / max(VIEWPORT_SIZE.y / 270.0, 1.0));
	float bruit = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	a -= bruit * 0.35 * (1.0 - a);
	float q = floor(a * 4.0 + 0.25) / 4.0;   // 4 paliers
	if (q <= 0.0) {
		discard;
	}
	vec3 c = q >= 0.75 ? coeur.rgb : (q >= 0.5 ? mix(couleur.rgb, coeur.rgb, 0.45) : couleur.rgb);
	ALBEDO = c;
	ALPHA = q >= 0.75 ? 0.8 : (q >= 0.5 ? 0.55 : 0.3);
}
