// Roche, sol, glace et cristaux de la grotte. Dérivé de crypte.gdshader :
// - texels nets, mipmaps « nearest », accroche des sommets au pixel du rendu ;
// - triplan = 1 : texture projetée en coordonnées MONDE (indépendante du maillage : tient sur une géométrie plus fine ou bosselée).
//   L'axe de projection est TIRÉ AU HASARD par texel monde selon le poids de la normale : la jonction entre deux projections est
//   un moucheté de pierre (pas de fondu, pas de couture droite). triplan = 0 : UV du maillage (piste, cristaux) ;
// - COLOR du sommet : rgb = occlusion ambiante peinte (accentuée par ao_gamma : creux quasi noirs), a = masque de la couche
//   superposée (neige, glace), comparé au SEUIL stocké dans l'alpha de tex_sup : bords déchiquetés au texel ;
// - givre : faces tournées vers le haut (arêtes, corniches, sommets des concrétions) blanchies par la carte de givre (seuil au texel) ;
// - mouille : sol mouillé par plaques (assombri, reflet spéculaire net des torches).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_sup : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_givre : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float grille = 180.0;      // accroche des sommets : H/2 à 640x360 (DA §3)
uniform vec3 emission : source_color = vec3(0.0);
uniform float emis_tex = 0.0;        // part de la texture réinjectée en émission (cristaux)
uniform float echelle_sup = 1.0;
uniform float decoupe = 0.0;        // 1 : l'alpha de tex_base est un seuil de bruit comparé au masque du sommet (piste, bords tramés)
uniform float triplan = 0.0;        // 1 : projection monde
uniform float echelle = 0.1875;       // tuiles par mètre (projection monde) : v2 : 128 texels / 5,33 m = 24 texels/m (GrotteTextures.DENSITE)
uniform vec4 bouche = vec4(0.0);     // xyz : bouche de la grotte (monde), w : rayon de fondu (0 = aucun) : la neige rejoint celle du dehors sans couture
uniform vec4 lueurs[3];             // lueurs de fond des grandes salles : xyz monde, w rayon (0 = éteinte) ; la roche proche prend un reflet bleu glacé
uniform float par_m = 24.0;         // texels par mètre : le tirage de l'axe de projection se fait par texel (jonctions en pixels francs)
uniform float givre = 0.0;          // part de givre sur les faces hautes (0 = aucun)
uniform float mouille = 0.0;        // part de sol mouillé (0 = sec)
uniform float ao_gamma = 1.0;       // contraste de l'occlusion peinte
uniform float sol_plat = 1.0;       // 1 : faces très plates = sol (peu de givre) ; 0 : calotte de givre pleine (rochers du kit)
uniform float modele = 0.0;         // passe 2 kit : modelé « éclairé d'en haut » (projection monde) : dessous et surplombs assombris, dessus éclaircis

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);  // grille exprimée pour 270 lignes : même pas en pixels à toute résolution
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

float h13(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float bruit2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h13(vec3(i, 7.0));
	float b = h13(vec3(i + vec2(1.0, 0.0), 7.0));
	float c = h13(vec3(i + vec2(0.0, 1.0), 7.0));
	float d = h13(vec3(i + vec2(1.0, 1.0), 7.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Échantillon projeté : un seul des trois plans, tiré par texel monde (moucheté aux jonctions).
vec4 proj(sampler2D t, vec3 p, vec3 n, float ech, vec2 dec) {
	vec3 a = pow(abs(n), vec3(5.0));
	a /= (a.x + a.y + a.z + 1e-5);
	float r = h13(floor(p * par_m));
	vec3 px = dFdx(p) * ech;
	vec3 py = dFdy(p) * ech;
	vec2 uv;
	vec2 gx;
	vec2 gy;
	if (r < a.y) {
		uv = vec2(p.x, p.z) * ech;
		gx = px.xz;
		gy = py.xz;
	} else if (r < a.y + a.x) {
		float s = sign(n.x);
		uv = vec2(-p.z * s, -p.y) * ech;
		gx = vec2(-px.z * s, -px.y);
		gy = vec2(-py.z * s, -py.y);
	} else {
		float s = sign(n.z);
		uv = vec2(p.x * s, -p.y) * ech;
		gx = vec2(px.x * s, -px.y);
		gy = vec2(py.x * s, -py.y);
	}
	return textureGrad(t, uv + dec, gx, gy);
}

void fragment() {
	vec3 n = normalize(wn);
	vec4 b;
	vec4 s;
	if (triplan > 0.5) {
		b = proj(tex_base, wp, n, echelle, vec2(0.0));
		s = proj(tex_sup, wp, n, echelle * echelle_sup, vec2(0.37, 0.13));
	} else {
		b = texture(tex_base, UV);
		s = texture(tex_sup, UV * echelle_sup + vec2(0.37, 0.13));
	}
	if (decoupe > 0.5 && COLOR.a < b.a) {
		discard;
	}
	// couche superposée : bord de plaque net au texel (pixel art), ni demi-teinte ni dégradé
	float amt = (COLOR.a - s.a) > 0.0 ? 1.0 : 0.0;
	amt *= step(0.01, COLOR.a);
	vec3 c = mix(b.rgb, s.rgb, amt);
	float fb = 0.0;
	if (bouche.w > 0.0 && amt > 0.5) {
		fb = 1.0 - smoothstep(0.0, bouche.w, distance(wp.xz, bouche.xz));
		fb *= fb;
	}
	float spec = 0.0;
	float rough = 1.0;
	// givre sur les faces hautes : la pente règle la part, la carte de givre (alpha = seuil) découpe au texel
	if (givre > 0.0) {
		vec4 gv = textureGrad(tex_givre, wp.xz * echelle, dFdx(wp.xz) * echelle, dFdy(wp.xz) * echelle);
		// pente forte (arêtes, corniches, têtes de rochers) : pleine part ; sol plat : plaques seulement
		// 4e passe : plus de « confettis » sur les parois verticales ; seules les faces franchement horizontales (rebords,
		// dessus de rochers, sol) prennent du givre, et en liseré sur l'arête haute (COLOR.a) plutôt qu'en plaques éparses
		float plat = smoothstep(0.62, 0.86, n.y);
		float pas_sol = 1.0 - 0.9 * sol_plat * smoothstep(0.88, 0.97, n.y);     // 5e passe : pas de plaques en grain sur les sols plats
		float part = plat * pas_sol * givre;
		part *= mix(0.3, 1.0, clamp(COLOR.r, 0.0, 1.0)) * 0.6;   // jamais plein : la carte de givre découpe toujours en grain
		// « arête haute » du relief (COLOR.a relevé sur les dessus de corniche, têtes de stalagmites) : liseré franc
		part = max(part, clamp(COLOR.a - 0.3, 0.0, 1.0) * smoothstep(0.5, 0.75, n.y) * pas_sol * givre * 0.95);
		if (part > gv.a) {
			c = gv.rgb;
			amt = 1.0;
		}
	}
	// sol mouillé : plaques basse fréquence, assombries, reflet net
	if (mouille > 0.0 && amt < 0.5) {
		float sol_ = clamp((n.y - 0.6) * 4.0, 0.0, 1.0);
		float pl = bruit2(wp.xz * 0.55) * 0.65 + bruit2(wp.xz * 2.1) * 0.35;
		float w = step(0.52, pl) * sol_ * mouille;
		c *= mix(1.0, 0.62, w);
		spec = 0.5 * w;
		rough = mix(1.0, 0.22, w);
	}
	vec3 ao = pow(max(COLOR.rgb, vec3(0.0)), vec3(ao_gamma));
	if (modele > 0.0) {
		ao *= mix(1.0, mix(0.55, 1.14, smoothstep(-0.7, 0.8, n.y)), modele);
	}
	// bouche : la neige de la grotte rejoint celle du dehors (même blanc froid) en gardant son motif de plaques
	vec3 neige_dehors = vec3(0.80, 0.84, 0.92) * clamp(dot(c, vec3(0.333)) * 1.9, 0.55, 1.1);
	float lueur = 0.0;
	for (int i = 0; i < 3; i++) {
		if (lueurs[i].w > 0.0) {
			float q = 1.0 - smoothstep(0.0, lueurs[i].w, distance(wp, lueurs[i].xyz));
			lueur = max(lueur, q * q);
		}
	}
	vec3 reflet = vec3(0.30, 0.50, 0.95) * lueur * (0.25 + dot(c, vec3(0.333)) * 2.0) * mix(0.6, 1.0, ao.g) * 0.8;
	ALBEDO = c * ao * teinte.rgb * (1.0 - fb);
	EMISSION = emission + c * emis_tex + neige_dehors * fb * fb + reflet;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
