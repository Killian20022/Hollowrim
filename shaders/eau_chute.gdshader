// Nappe de cascade (géométrie Blender `Chute`, couleur de sommet : R = fondu des bords, G = progression de la chute, B = écume de lèvre).
// Filets verticaux qui coulent par pas (cadence), écume sur la lèvre, bords effilochés ; transparence par bruit de hachage
// (jamais de mélange alpha instable). Mêmes texels que le reste de l'eau : 16 par mètre.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D ruido : filter_nearest, repeat_enable;
uniform vec3 c_moyen : source_color = vec3(0.17, 0.36, 0.55);
uniform vec3 c_clair : source_color = vec3(0.62, 0.80, 0.92);
uniform vec3 c_ecume : source_color = vec3(0.90, 0.95, 1.0);
uniform float vitesse_chute = 3.2;    // m/s apparents
uniform float cadence = 8.0;
uniform float opacite = 0.8;
uniform float grille = 135.0;
uniform float temps_force = -1.0;
uniform float echelle_y = 1.0;        // hauteur réelle / hauteur du modèle (étire le motif)

varying vec3 couleur_s;

void vertex() {
	couleur_s = COLOR.rgb;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

vec3 rn(vec2 cell) {
	return texelFetch(ruido, ivec2(floor(cell)) & ivec2(127), 0).rgb;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float T0 = temps_force >= 0.0 ? temps_force : TIME;
	float T = floor(T0 * cadence) / cadence;
	float edge = couleur_s.r;
	float prog = couleur_s.g;
	float levre = couleur_s.b;
	// texels de 1/16 m : u en travers, v le long de la chute (arc en m, descend avec le temps)
	vec2 tx = vec2(floor(UV.x * 16.0), floor((UV.y * echelle_y - T * vitesse_chute) * 16.0));
	// filets : champs lisses étirés verticalement (8 et 5 texels par pas) = longs filets ; l'écume vient de lignes de crêtes
	vec3 a = rn(vec2(tx.x * 0.8, floor(tx.y / 8.0)));
	vec3 b = rn(vec2(tx.x * 1.6 + 31.0, floor(tx.y / 5.0)));
	float fil = a.r * 0.6 + b.g * 0.4;
	vec3 col = c_moyen;
	if (fil > 0.55) col = mix(c_moyen, c_clair, 0.6);
	if (fil > 0.68) col = c_clair;
	// écume : amas allongés qui s'épaississent vers le pied et couvrent la lèvre
	float fm = rn(vec2(tx.x * 1.1 + 13.0, floor(tx.y / 4.0))).b;
	float seuil_e = mix(0.93, 0.66, prog) - levre * 0.5;
	if (fm > seuil_e) col = c_ecume;
	// bords effilochés : le motif décide où l'eau s'arrête
	float alpha = opacite * smoothstep(0.0, 0.55, edge + (fil - 0.5) * 0.5);
	alpha = max(alpha, levre * 0.9);
	ALBEDO = col;
	EMISSION = col * 0.18;   // l'eau claire reste lisible la nuit sans briller
	ALPHA = alpha;
	ALPHA_HASH_SCALE = 1.0;
	ROUGHNESS = 0.5;
}
