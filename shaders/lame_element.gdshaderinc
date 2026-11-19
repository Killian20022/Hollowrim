// Particules de l'EFFET PASSIF D'ÉLÉMENT des lames (scripts/combat/effet_element_lame.gd) : même dessin que les particules de
// magie (magie_part.gdshaderinc) — chaque particule est un CARRÉ de pixels entiers face à la caméra (au moins 1 px, plafonné à
// `taille_max`), centre accroché à la grille des pixels de l'écran, couleur = rampe EN PALIERS, opacité en 3 paliers — mais
// dans le rendu principal (pas de couche fine, pas d'occlusion reprojetée) : la lame est tout près de l'œil.
uniform float eclat = 1.0;        // multiplicateur de couleur (HDR léger : seuls les cœurs vifs touchent le glow)
uniform float taille_max = 2.0;   // plafond (px) : de près, 2 px au plus ; de loin, 1 px
uniform float paliers = 3.0;      // paliers d'opacité
// > 0 : traînée d'un pixel de large (étincelles) derrière la particule (axe Y = vitesse, particle_flag_align_y)
uniform float etire = 0.0;

void vertex() {
	vec4 centre = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0));
	float s = length(MODEL_MATRIX[0].xyz);
	vec2 vp = VIEWPORT_SIZE;
	float w = max(centre.w, 0.0001);
	float px = s * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	vec2 p = (centre.xy / w * 0.5 + 0.5) * vp;
	px = clamp(floor(px + 0.5), 1.0, taille_max);
	if (s < 0.000001) {
		px = 0.0;
	}
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
	// pas de discard (test_shaders_sans_discard, docs/BANC_PERF.md) : a <= 0 donne ALPHA = 0 (mélange) ou ALBEDO = 0 (additif
	// prémultiplié), donc rien à l'écran ; depth_draw_never : aucune profondeur écrite non plus
	float a = clamp(ceil(COLOR.a * paliers - 0.05) / paliers, 0.0, 1.0);
	vec3 c = COLOR.rgb;
	c = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
#ifdef LAME_ADD
	ALBEDO = c * eclat * a;
	ALPHA = 0.0;
#else
	ALBEDO = c * eclat;
	ALPHA = a;
#endif
}
