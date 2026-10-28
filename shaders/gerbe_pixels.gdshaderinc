// Gerbes de GROS PIXELS CARRÉS (scripts/combat/gerbe_pixels.gd) : éclats d'os, sang, étincelles, échardes du corps à corps.
// Inspiré de magie_part.gdshaderinc (même accroche à la grille des pixels), mais sans couche fine ni occlusion : il dessine
// dans le rendu principal (640x360), la profondeur du monde suffit.
// Chaque particule est un CARRÉ de pixels entiers face à la caméra : taille en mètres (échelle de la particule) convertie en
// pixels d'écran, arrondie, bornée à [taille_min, taille_max] (on lit un éclat à 6 m comme à 1 m) ; centre accroché à la
// grille des pixels. Couleur = celle de la particule (ParticleProcessMaterial.color_initial_ramp en PALIERS : chaque éclat
// tire une couleur de la palette) ; opacité en paliers (pas de dégradé lisse, esprit pixel).
// Pas de texture, pas de lecture d'écran : compatible Mobile et Compatibility.
uniform float eclat = 1.0;        // multiplicateur de couleur (étincelles : > 1, le glow de la scène les prend dehors)
uniform float taille_min = 3.0;   // px
uniform float taille_max = 8.0;   // px
uniform float paliers = 3.0;      // paliers d'opacité
// > 0 : TRAÎNÉE (étincelle filante) : la particule (axe Y = vitesse, particle_flag_align_y) s'étire derrière elle sur
// `etire` fois sa taille, en pixels francs ; vue de face elle reste un carré
uniform float etire = 0.0;

void vertex() {
	vec4 centre = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0));
	float s = length(MODEL_MATRIX[0].xyz);
	vec2 vp = VIEWPORT_SIZE;
	float w = max(centre.w, 0.0001);
	float px = s * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;   // abs : axe Y retourné sous Vulkan
	px = clamp(floor(px + 0.5), taille_min, taille_max);
	if (s < 0.000001) {
		px = 0.0;   // particule éteinte (échelle nulle en fin de vie)
	}
	vec2 p = (centre.xy / w * 0.5 + 0.5) * vp;
	p = mod(px, 2.0) > 0.5 ? floor(p) + 0.5 : floor(p + 0.5);
	if (etire > 0.0 && px > 0.0) {
		vec3 dm = normalize(MODEL_MATRIX[1].xyz + vec3(0.0, 0.000001, 0.0));
		vec4 c2 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz - dm * s * etire, 1.0));
		vec2 p2 = (c2.xy / max(c2.w, 0.0001) * 0.5 + 0.5) * vp;
		vec2 d = c2.w > 0.0001 ? p2 - p : vec2(0.0);
		float l = min(length(d), px * 4.0);
		vec2 ax = l > px * 1.5 ? normalize(d) : vec2(0.0, 1.0);
		float lg = max(floor(l + 0.5), px);
		p += vec2(-ax.y, ax.x) * VERTEX.x * px + ax * (VERTEX.y + 0.5) * lg;
	} else {
		p += VERTEX.xy * px;
	}
	POSITION = vec4((p / vp * 2.0 - 1.0) * centre.w, centre.z, centre.w);
}

void fragment() {
	float a = ceil(COLOR.a * paliers - 0.05) / paliers;
	if (a <= 0.0) {
		discard;
	}
	// couleur de la particule en sRVB → linéaire (sinon les rouges sombres virent au rose)
	vec3 c = COLOR.rgb;
	c = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
	ALBEDO = c * eclat;   // additif (blend_add) : la couleur s'ajoute, pondérée par l'opacité
	ALPHA = clamp(a, 0.0, 1.0);
}
