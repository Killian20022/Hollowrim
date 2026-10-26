// Eau du monde (rivières, ruisseaux, lacs, bassins souterrains, flaques) : voir docs/EAU.md et scripts/eau.gd.
// Tout est ancré sur des TEXELS D'EAU de 1/16 m (comme le sol), agrandis avec la distance (un texel ne descend jamais sous un
// pixel d'écran) ; les ondes avancent par PAS de temps (cadence) : jamais de bruit sous le pixel, jamais de scintillement continu.
//  - profondeur, courant et turbulence viennent d'une CARTE précalculée (`carte`, RGBA8) : R,G = courant (m/s / vitesse), B = profondeur,
//    A = turbulence (pied de chute, rapides). Aucune profondeur n'est devinée à l'écran : couleur stable.
//  - le fond est lu dans l'écran (réfraction de quelques pixels) ; la lisière, les pierres et les berges sont repérées par la
//    profondeur de la scène (écume de contact).
//  - reflets : marche courte dans l'écran (12 pas, profondeur) ; repli sur le ciel du cycle jour/nuit.
//  - lumière : light() maison, éclats d'astre / de torche en pixels durs (pas de reflet spéculaire lisse).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D carte : filter_linear, repeat_disable;
uniform vec4 carte_rect = vec4(0.0, 0.0, 0.01, 0.01);     // x0, z0 (m), 1/largeur, 1/hauteur
uniform sampler2D ruido : filter_nearest, repeat_enable;  // 128² : R,G = champs lisses, B = crêtes
uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D profondeur_ecran : hint_depth_texture, filter_nearest, repeat_disable;

uniform vec3 c_peu : source_color = vec3(0.30, 0.52, 0.60);       // eau claire près des berges
uniform vec3 c_moyen : source_color = vec3(0.16, 0.32, 0.50);
uniform vec3 c_profond : source_color = vec3(0.07, 0.14, 0.28);
uniform vec3 c_clair : source_color = vec3(0.62, 0.78, 0.88);     // éclat des crêtes
uniform vec3 c_ecume : source_color = vec3(0.86, 0.92, 0.98);
uniform vec3 c_ecume_ombre : source_color = vec3(0.62, 0.72, 0.85);
uniform float absorption = 0.9;        // 1/m : vitesse à laquelle l'eau vire au bleu profond
uniform float transparence = 1.4;      // 1/m : le fond disparaît (pierres visibles dans les 0,5 premiers mètres)
uniform float refraction = 0.25;       // décalage du fond (en pixels × cette valeur)
uniform float vitesse = 1.0;           // facteur du courant de la carte
uniform vec2 derive = vec2(0.0);       // courant uniforme ajouté (lacs : dérive lente)
uniform float cadence = 7.0;           // pas de temps de l'animation par seconde
uniform float ond_amp = 1.0;           // amplitude des ondulations (0 = miroir)
uniform float ond_taille = 1.0;        // taille des ondes (1 = ~0,5 m)
uniform float etirement = 0.5;         // étirement des ondes dans le sens du courant (0,5 = deux fois plus longues)
uniform float eclats = 1.0;            // crêtes claires / creux sombres
uniform float reflet_force = 1.0;
uniform float reflet_flou = 1.0;       // déformation des reflets par les ondes
uniform float reflet_portee = 40.0;    // m
uniform float spec_force = 1.0;
uniform float ecume_force = 1.0;
uniform float vaguelettes = 1.0;       // petites lignes qui lèchent la berge
uniform float fondu_loin = 55.0;       // m : au-delà, ondes et éclats s'effacent (aucun scintillement lointain)
uniform float grille = 135.0;
uniform float temps_force = -1.0;      // >= 0 : temps imposé (captures reproductibles)
uniform bool debug_masque = false;     // mesures : l'eau en rose uni
uniform float sombre = 1.0;            // multiplicateur de lumière propre (souterrain)

// ciel simplifié (renseigné chaque image par Eau depuis cycle.gd)
uniform vec3 ciel_froid : source_color = vec3(0.22, 0.25, 0.34);
uniform vec3 ciel_chaud : source_color = vec3(0.62, 0.44, 0.34);
uniform vec3 ciel_haut : source_color = vec3(0.09, 0.11, 0.20);
uniform vec2 ciel_dir = vec2(-0.8, 0.6);
uniform float ciel_chaleur = 0.0;

// glace : la carte `carte_glace` (nearest, R = mode × 50, G = intensité) donne en chaque point
// 0 liquide, 1 partielle, 2 couverte, 3 bords gelés, 4 plaques flottantes ; l'intensité règle la part gelée / la largeur / la densité
uniform sampler2D carte_glace : filter_nearest, repeat_disable;
uniform float glace_bord = 0.7;        // largeur max de la glace de rive (m)
uniform float glace_plaques = 0.62;    // densité max des plaques
uniform float glace_ton_plaques = 0.0; // 0 = taches de bruit (prototype) ; 1 = ton par grandes plaques de Voronoï (grands lacs gelés, sans carrés)
uniform float affine = 0.0;            // ignoré (gardé pour Palette.regler_ps1)
uniform vec3 g_clair : source_color = vec3(0.90, 0.95, 1.0);
uniform vec3 g_moyen : source_color = vec3(0.64, 0.78, 0.90);
uniform vec3 g_sombre : source_color = vec3(0.38, 0.55, 0.75);
uniform vec3 g_fente : source_color = vec3(0.20, 0.34, 0.52);

varying vec2 pos_monde;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 rn(vec2 cell) {
	return texelFetch(ruido, ivec2(floor(cell)) & ivec2(127), 0).rgb;
}

// champ d'ondes à deux phases (courant) : x,y = pente, z = crête
vec3 champ(vec2 p, vec2 f, float T, float echelle) {
	float sp = clamp(length(f), 0.0, 1.5);
	vec2 dir = sp > 0.01 ? f / sp : vec2(1.0, 0.0);
	float per = 2.6;
	float t = T / per;
	float ph0 = fract(t);
	float ph1 = fract(t + 0.5);
	float w0 = 1.0 - abs(2.0 * ph0 - 1.0);
	vec3 r = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		float ph = k == 0 ? ph0 : ph1;
		float w = k == 0 ? w0 : 1.0 - w0;
		vec2 q = p - f * ph * per;
		vec2 a = vec2(dot(q, dir) * mix(1.0, etirement, clamp(sp, 0.0, 1.0)), dot(q, vec2(-dir.y, dir.x)));
		vec2 n = a * (16.0 / echelle) / ond_taille;
		vec3 g = rn(n * 0.75);
		vec3 g2 = rn(n * 0.31 + 41.0);
		r += w * vec3(g.rg * 0.65 + g2.rg * 0.35, g.b);   // pentes : deux échelles ; crête : lignes fines de la première
	}
	return r;
}

// ciel à l'horizon dans la direction monde d (même loi que cycle.gd.couleur_horizon)
vec3 ciel_dans(vec3 d) {
	vec2 h = d.xz;
	float k = 0.0;
	if (length(h) > 0.001) k = ciel_chaleur * smoothstep(-0.4, 1.0, dot(normalize(h), ciel_dir));
	vec3 hor = mix(ciel_froid, ciel_chaud, k);
	return mix(hor, ciel_haut, smoothstep(0.02, 0.75, d.y));
}

float lin_depth(vec2 uv, mat4 ip) {
	float d = texture(profondeur_ecran, uv).r;
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(v.z / v.w);
}

// voronoi léger : x = distance au germe le plus proche, y = distance au bord (F2 - F1), z = hachage de la cellule
vec3 voro(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash21(i + g), hash21(i + g + 17.3));
			float d = length(g + o * 0.8 + 0.1 - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash21(i + g + 3.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

// masque de glace en un point (m) : mode et intensité k de la carte, profondeur d, courant f, turbulence, temps ; j = grain par texel
float glace_en(int mode, float k, vec2 p, float d, vec2 f, float turb, float T, float j) {
	if (mode == 0 || k <= 0.01) return 0.0;
	vec3 r = rn(floor(p * 16.0) * 0.35);
	float champ_g = r.r * 0.6 + r.g * 0.4;
	float g = 0.0;
	if (mode == 2) {
		g = 1.0;
		if (turb > 0.3 || (champ_g > 0.82 && d < 0.35)) g = 0.0;
	} else if (mode == 1) {
		g = step(1.0 - k, champ_g * 0.85 + (1.0 - smoothstep(0.0, 0.9, d)) * 0.3);
	} else if (mode == 3) {
		g = step(d, glace_bord * k * (0.5 + 0.9 * r.r));
	} else {
		vec3 v2 = voro(p * 0.55 - f * T * 0.2);
		float taille = 0.22 + 0.30 * v2.z;
		g = (v2.z < glace_plaques * k && v2.x < taille - (j - 0.5) * 0.10) ? 1.0 : 0.0;
		g *= step(0.08, d);
		g = max(g, step(d, glace_bord * 0.35 * k * (0.5 + r.r)));
	}
	return g * step(0.0, d) * (1.0 - step(0.5, turb));
}

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float T0 = temps_force >= 0.0 ? temps_force : TIME;
	float T = floor(T0 * cadence) / cadence;
	vec3 pw3 = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 pw = pw3.xz;
	float dist = length(VERTEX);
	// texel d'eau : 1/16 m, doublé tant qu'il serait plus fin qu'un pixel
	vec2 fw = max(abs(dFdx(pw)), abs(dFdy(pw)));
	float pix = max(fw.x, fw.y);
	float lod = clamp(ceil(log2(max(pix * 16.0, 1.0))), 0.0, 3.0);
	float cell = exp2(lod) / 16.0;
	vec2 pc = (floor(pw / cell) + 0.5) * cell;
	vec4 c = texture(carte, (pc - carte_rect.xy) * carte_rect.zw);
	float d = c.b * 3.25 - 0.25;                    // profondeur (m)
	vec2 f = (c.rg * 2.0 - 1.0) * vitesse + derive;  // courant (m/s)
	float turb = c.a;
	float loin = 1.0 - smoothstep(fondu_loin * 0.55, fondu_loin, dist);
	vec2 tc = floor(pw / cell);
	vec3 rb = vec3(hash21(tc), hash21(tc + 7.7), hash21(tc + 13.1));
	vec3 rl = rn(tc * 0.35);   // bruit lisse (taches)
	// bord irrégulier : la lisière se découpe en texels
	if (d + (rb.b - 0.5) * 0.05 < -0.012) discard;

	// --- ondulations (pente + crête) ---
	vec3 w = champ(pc, f, T, 1.0);
	float fad = loin * clamp(1.0 - (lod - 1.0) * 0.35, 0.0, 1.0);
	float amp = ond_amp * fad * (0.25 + 0.75 * smoothstep(0.0, 0.25, d));
	vec3 n_m = normalize(vec3((w.x - 0.5) * 0.45 * amp, 1.0, (w.y - 0.5) * 0.45 * amp));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_m, 0.0)).xyz);

	// --- couleur de l'eau par bandes de profondeur ---
	float prof_t = 1.0 - exp(-d * absorption);
	prof_t += (rl.g - 0.5) * 0.12;
	vec3 col_eau;
	float bande = floor(clamp(prof_t, 0.0, 0.999) * 4.0);   // 4 paliers : pixel art
	if (bande < 1.0) col_eau = c_peu;
	else if (bande < 2.0) col_eau = mix(c_peu, c_moyen, 0.55);
	else if (bande < 3.0) col_eau = c_moyen;
	else col_eau = c_profond;

	// crêtes claires et creux sombres : amas de pixels qui avancent avec le courant
	float cr = w.z;
	float lum = 0.0;
	if (eclats > 0.0) {
		float seuil = 0.80 - 0.05 * clamp(length(f), 0.0, 1.0);
		if (cr > seuil && d > 0.04) lum = 1.0;
		else if (cr < 0.07) lum = -1.0;
		lum *= fad * eclats;
	}
	col_eau = lum > 0.5 ? mix(col_eau, c_clair, 0.35) : (lum < -0.5 ? col_eau * 0.82 : col_eau);

	// --- fond vu à travers l'eau ---
	float lin_eau = -VERTEX.z;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 off = vec2(n_m.x, n_m.z) * refraction * (6.0 + 22.0 * clamp(d, 0.0, 1.0)) * px * fad;
	off = round(off / px) * px;
	vec2 uv_f = SCREEN_UV + off;
	if (lin_depth(uv_f, INV_PROJECTION_MATRIX) < lin_eau - 0.02) uv_f = SCREEN_UV;
	vec3 fond = textureLod(ecran, uv_f, 0.0).rgb;
	float vis = exp(-d * transparence);
	vec3 base_eau = col_eau;
	float opaque = 1.0 - vis * 0.9;                       // part de teinte d'eau (le fond complète le reste)
	vec3 fond_teinte = fond * mix(vec3(0.82, 0.95, 1.0), vec3(0.5, 0.7, 0.9), clamp(d, 0.0, 1.0));

	// --- écume : lisière, contact avec les pierres, turbulence ---
	float dscene = lin_depth(SCREEN_UV, INV_PROJECTION_MATRIX) - lin_eau;       // épaisseur d'eau le long du regard, jusqu'à la scène
	float bruit_e = rb.g;
	float contact = (1.0 - smoothstep(0.02, 0.05 + 0.04 * bruit_e, dscene)) * step(0.0, dscene + 0.05);
	float rive = 1.0 - smoothstep(0.01, 0.035 + 0.03 * bruit_e, d);
	float ec_turb = 0.0;
	if (turb > 0.02) {
		vec3 wt = champ(pc * 1.3, vec2(0.0, 0.7), T, 1.0);
		ec_turb = step(1.0 - turb * 0.9, wt.z * 0.55 + wt.x * 0.55);
	}
	// vaguelettes : lignes parallèles à la rive qui avancent vers elle
	float vag = 0.0;
	if (vaguelettes > 0.0 && d < 0.5) {
		float ph = d * 6.5 - T * 0.28 + rb.r * 0.5;
		vag = step(0.92, fract(ph)) * (1.0 - smoothstep(0.1, 0.5, d)) * step(0.1, d) * fad * vaguelettes;
	}
	float ecume = clamp(max(max(contact, rive), max(ec_turb, vag * 0.8)) * ecume_force, 0.0, 1.0);
	ecume = ecume > 0.5 ? 1.0 : 0.0;

	// --- glace ---
	float glace = 0.0;
	vec3 col_glace = g_moyen;
	vec2 gl = texture(carte_glace, (pc - carte_rect.xy) * carte_rect.zw).rg;
	int g_mode = int(gl.r * 255.0 / 50.0 + 0.5);
	if (g_mode != 0) {
		glace = glace_en(g_mode, gl.g, pc, d, f, turb, T, rb.r);
		float g_x = glace_en(g_mode, gl.g, pc - vec2(cell, 0.0), d, f, turb, T, rb.r);
		float g_z = glace_en(g_mode, gl.g, pc - vec2(0.0, cell), d, f, turb, T, rb.r);
		float champ_g = rl.r * 0.55 + rl.g * 0.45;
		float tache = rl.b;
		if (glace_ton_plaques > 0.0) {
			vec3 vp = voro(pc * 0.42);
			tache = mix(rl.b, vp.z, glace_ton_plaques);
			champ_g = mix(champ_g, 0.25 + 0.5 * vp.z, glace_ton_plaques);
		}
		float t_g = 0.42 + (tache - 0.5) * 0.9 + (1.0 - exp(-d * 1.2)) * 0.35;
		col_glace = t_g > 0.80 ? g_sombre : (t_g > 0.50 ? g_moyen : g_clair);
		if (champ_g > 0.66) col_glace = g_clair;
		// fentes (correctif lac_horizon) : bords de Voronoï tracés EN TEXELS — un texel est sur la fente si son voisin x ou z
		// tombe dans une autre cellule → traits continus d'un texel. L'ancien seuil F2-F1 < 0,045 donnait une fente de
		// ~1,5 cm, plus fine qu'un texel (6 cm), et les taches claires (champ_g) la coupaient encore : TIRETS sombres épars.
		// Une arête sur trois seulement (réseau clairsemé), proches seulement (lod 0, texel 6 cm : dès lod 1 une cellule ne fait que ~5 texels et ses arêtes redeviennent des tirets).
		if (g_mode != 4 && lod < 0.5) {
			float id0 = voro(pc * 1.6).z;
			float idx = voro((pc - vec2(cell, 0.0)) * 1.6).z;
			float idz = voro((pc - vec2(0.0, cell)) * 1.6).z;
			bool fx = idx != id0 && fract((id0 + idx) * 13.71) < 0.34;
			bool fz = idz != id0 && fract((id0 + idz) * 13.71) < 0.34;
			// voisin en diagonale : bouche les coins des arêtes obliques (sinon escalier de texels qui ne se touchent que par un coin = tirets)
			float idd = voro((pc - vec2(cell, cell)) * 1.6).z;
			bool fd = idd != id0 && fract((id0 + idd) * 13.71) < 0.34;
			// fondu avec la distance : la fente s'éclaircit vers la teinte de la glace avant la limite du lod 0 (pas de coupure nette)
			float f_fente = 1.0 - smoothstep(0.35, 0.95, pix * 16.0);
			if (fx || fz || fd) col_glace = mix(col_glace, mix(g_sombre, g_fente, 0.4), f_fente);
		}
		if (glace > 0.5 && (g_x < 0.5 || g_z < 0.5)) col_glace = g_clair;
	}

	// --- reflets ---
	vec3 refl = vec3(0.0);
	float fres = 0.0;
	if (reflet_force > 0.0) {
		vec3 V = normalize(VERTEX);
		float nv = clamp(dot(-V, NORMAL), 0.0, 1.0);
		fres = (0.03 + 0.97 * pow(1.0 - nv, 4.0)) * reflet_force;
		fres = clamp(fres * (1.0 - 0.6 * step(0.5, glace)), 0.0, 0.85);
		vec3 R = reflect(V, NORMAL);
		vec3 Rm = normalize((INV_VIEW_MATRIX * vec4(R, 0.0)).xyz);
		vec3 sky = ciel_dans(Rm);
		refl = sky;
		if (fres > 0.01 && R.z < 0.0 && lod < 3.0) {
			float t = 0.15;
			float ok = 0.0;
			vec2 uv_h = vec2(0.0);
			for (int i = 0; i < 12; i++) {
				vec3 pr = VERTEX + R * t;
				vec4 cp = PROJECTION_MATRIX * vec4(pr, 1.0);
				vec2 uv = cp.xy / cp.w * 0.5 + 0.5;
				if (cp.w <= 0.0 || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;
				float sd = lin_depth(uv, INV_PROJECTION_MATRIX);
				float ray = -pr.z;
				float ep = 0.25 + 0.35 * t;
				if (ray > sd + 0.03 && ray < sd + ep && t > 0.3) {
					ok = 1.0;
					uv_h = uv;
					break;
				}
				t = t * 1.55 + 0.1;
				if (t > reflet_portee) break;
			}
			if (ok > 0.5) {
				vec2 ed = abs(uv_h * 2.0 - 1.0);
				float bordf = 1.0 - smoothstep(0.82, 1.0, max(ed.x, ed.y));
				// reflet adouci : point d'impact calé sur des blocs de 4 pixels et lu dans une version floue de l'écran,
				// pour qu'il ne change pas de pixel en pixel quand la caméra bouge
				uv_h += vec2(n_m.x, n_m.z) * 0.012 * reflet_flou;
				vec2 bloc = 4.0 * px;
				uv_h = (floor(uv_h / bloc) + 0.5) * bloc;
				vec3 hit = textureLod(ecran, uv_h, 2.0).rgb;
				refl = mix(refl, hit, bordf);
			}
		}
	}

	// --- assemblage ---
	vec3 surface = base_eau;
	float w_surf = clamp(opaque + 0.12, 0.0, 1.0);
	vec3 emis = fond_teinte * (1.0 - w_surf);
	emis += refl * fres * 0.9;
	float cov = max(ecume, glace);
	if (glace > 0.5) {
		surface = col_glace;
		w_surf = 0.96;
		emis = refl * fres * 0.4 + fond * 0.04;
	}
	if (ecume > 0.5 && glace < 0.5) {
		surface = mix(c_ecume_ombre, c_ecume, step(0.35, rl.r));
		w_surf = 1.0;
		emis = vec3(0.0);
	}
	ALBEDO = surface * w_surf;
	EMISSION = emis * sombre;
	if (debug_masque) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(1.0, 0.0, 1.0);
	}
	ALPHA = 1.0;
	ROUGHNESS = 0.2;
	SPECULAR = 0.0;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * nl / PI * sombre;
	// éclat d'astre ou de torche : quelques pixels durs sur les facettes bien orientées
	vec3 H = normalize(LIGHT + VIEW);
	float s = dot(NORMAL, H);
	float eclat = smoothstep(0.9965, 0.9975, s);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * eclat * spec_force * 0.8;
}
