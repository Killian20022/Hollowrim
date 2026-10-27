// Particules de magie pixel art (scripts/magie/gestion_magie.gd) : chaque particule est un CARRÉ de pixels entiers face à
// la caméra (taille arrondie au pixel, au moins 1 px, plafonnée à `taille_max`), centre accroché à la grille des pixels
// de l'écran ; couleur = rampe EN PALIERS de la particule (Gradient constant, peu de couleurs) ; opacité en 3 paliers.
// Pas de texture, pas de lecture d'écran : compatible rendus Mobile et Compatibility (navigateur).
uniform float eclat = 1.5;        // multiplicateur de couleur (HDR : dehors, le glow de la scène prend les cœurs)
uniform float taille_max = 12.0;  // plafond (px) : pas de gros pavés « camouflage » près de la caméra
uniform float paliers = 3.0;      // paliers d'opacité

void vertex() {
	vec4 centre = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0));
	float s = length(MODEL_MATRIX[0].xyz);
	vec2 vp = VIEWPORT_SIZE;
	float w = max(centre.w, 0.0001);
	float px = s * PROJECTION_MATRIX[1][1] / w * vp.y * 0.5;
	px = clamp(floor(px + 0.5), 1.0, taille_max);
	if (s < 0.000001) {
		px = 0.0;
	}
	vec2 p = (centre.xy / w * 0.5 + 0.5) * vp;
	p = mod(px, 2.0) > 0.5 ? floor(p) + 0.5 : floor(p + 0.5);
	p += VERTEX.xy * px;
	POSITION = vec4((p / vp * 2.0 - 1.0) * centre.w, centre.z, centre.w);
}

void fragment() {
	float a = ceil(COLOR.a * paliers - 0.05) / paliers;
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = COLOR.rgb * eclat;
	ALPHA = clamp(a, 0.0, 1.0);
}
