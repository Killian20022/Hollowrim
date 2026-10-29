// Particules de magie pixel art (scripts/magie/gestion_magie.gd) : chaque particule est un CARRÉ de pixels entiers face à
// la caméra (taille arrondie au pixel, au moins 1 px, plafonnée à `taille_max`), centre accroché à la grille des pixels
// de l'écran ; couleur = rampe EN PALIERS de la particule (Gradient constant, peu de couleurs) ; opacité en 3 paliers.
// Pas de texture, pas de lecture d'écran : compatible rendus Mobile et Compatibility (navigateur).
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;   // pixels de la couche fine par pixel du monde (1 en rétro)
uniform float eclat = 1.5;        // multiplicateur de couleur (HDR : dehors, le glow de la scène prend les cœurs)
uniform float taille_max = 12.0;  // plafond (px) : pas de gros pavés « camouflage » près de la caméra
uniform float paliers = 3.0;      // paliers d'opacité
// > 0 : TRAÎNÉE (flammèche, étincelle filante) : la particule (axe Y = vitesse, particle_flag_align_y) s'étire derrière
// elle sur `etire` fois sa taille en mètres, en pixels francs ; vue de face (vitesse vers la caméra) elle reste un point
uniform float etire = 0.0;
// > 0 : palier « GROS PIXELS » (impacts et explosions, PresetsMagie.GROS) : carré de gros_px.x à gros_px.y pixels du MONDE
// (pixels internes : magie_echelle pixels de la couche fine chacun), aligné sur leur grille ; pas de traînée. La taille suit
// toujours la particule (courbe « descend » : il rétrécit en disparaissant), bornée à ce palier.
uniform vec2 gros_px = vec2(0.0);

void vertex() {
	vec4 centre = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0));
	float s = length(MODEL_MATRIX[0].xyz);
	vec2 vp = VIEWPORT_SIZE;
	float w = max(centre.w, 0.0001);
	float px = s * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;   // abs : axe Y retourné sous Vulkan
	// couche fine (magie_echelle > 1) : plafond en pixels fins = 0,25 × m × plafond (×0,5 à ×2) : en mètres, un quart
	// d'avant ; le volume vient du nombre (PresetsMagie.FIN) et des motifs procéduraux, pas de pavés près de la caméra
	vec2 p = (centre.xy / w * 0.5 + 0.5) * vp;
	if (gros_px.y > 0.0) {
		float u = max(magie_echelle, 1.0);
		float pm = clamp(floor(px / u + 0.5), gros_px.x, gros_px.y);
		px = s < 0.000001 ? 0.0 : pm * u;
		p = (mod(pm, 2.0) > 0.5 ? floor(p / u) + 0.5 : floor(p / u + 0.5)) * u;
	} else {
		px = clamp(floor(px + 0.5), 1.0, magie_echelle > 1.0 ? max(floor(taille_max * magie_echelle * 0.2 + 0.5), 1.0) : taille_max);
		if (s < 0.000001) {
			px = 0.0;
		}
		p = mod(px, 2.0) > 0.5 ? floor(p) + 0.5 : floor(p + 0.5);
	}
	// traînée : seulement pour les petites particules (les grosses, près de l'œil, feraient des planches)
	if (etire > 0.0 && gros_px.y <= 0.0 && px > 0.0 && px <= 5.0 * max(magie_echelle * 0.5, 1.0)) {
		vec3 dm = normalize(MODEL_MATRIX[1].xyz + vec3(0.0, 0.000001, 0.0));
		vec4 c2 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz - dm * s * etire, 1.0));
		vec2 p2 = (c2.xy / max(c2.w, 0.0001) * 0.5 + 0.5) * vp;
		vec2 d = c2.w > 0.0001 ? p2 - p : vec2(0.0);
		float l = min(length(d), px * 5.0);
		// trop courte (vitesse vers l'œil) : carré droit, pas de losange
		vec2 ax = l > px * 1.5 ? normalize(d) : vec2(0.0, 1.0);
		float lg = max(floor(l + 0.5), px);
		p += vec2(-ax.y, ax.x) * VERTEX.x * px + ax * (VERTEX.y + 0.5) * lg;
	} else {
		p += VERTEX.xy * px;
	}
	POSITION = vec4((p / vp * 2.0 - 1.0) * centre.w, centre.z, centre.w);
}

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	float a = ceil(COLOR.a * paliers - 0.05) / paliers;
	if (a <= 0.0) {
		discard;
	}
	// la couleur des particules (rampe) arrive en sRVB : la passer en linéaire (sinon les rouges sombres virent au rose)
	vec3 c = COLOR.rgb;
	c = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
#ifdef MAGIE_ADD
	// additif écrit en « prémultiplié » sans opacité : identique à blend_add sur le monde, et la couche fine (fond
	// transparent) garde une opacité nulle là où il n'y a que de la lumière
	ALBEDO = c * eclat * clamp(a, 0.0, 1.0);
	ALPHA = 0.0;
#else
	ALBEDO = c * eclat;
	ALPHA = clamp(a, 0.0, 1.0);
#endif
}
