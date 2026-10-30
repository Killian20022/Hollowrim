// SOUFFLE DE GIVRE du jet de glace (couche fine) : dessin d'une particule de magie_givre_process.gdshader. Même
// technique que la vague de flammes validée (magie_vague.gdshader, 2026-10-30) : carré tourné vers la caméra, motif
// évalué par pixel du MONDE (grain ps1), couleurs en paliers de la palette, couverture tramée par un bruit qui bout
// (jamais de Bayer). Fusion PRÉMULTIPLIÉE « mixte ».
//   - BOUFFÉE (2026-10-30, « une seule masse soudée de brume glacée ») : elle ne dessine plus SA forme (avant : volumes
//     de fumée Kenney en flipbook, chaque bouffée lisible, une grappe de boules) ; elle n'est plus qu'une EMPREINTE
//     (disque étiré) qui dit « il y a du givre ici ». Couleur, turbulence et tramage viennent d'un CHAMP PARTAGÉ calculé
//     pour le pixel le long de la LIGNE MÉDIANE réelle du souffle (jet_pts, posés par GestionMagie._vague_axe, qui
//     retombe un peu : l'air froid est lourd) : toutes les bouffées qui couvrent un pixel y prennent la même couleur,
//     elles se fondent en une masse. La découpe (corps, bruit n) est celle du feu validé (mêmes échelles : pas de
//     lambeaux) ; ce qui change : la turbulence défile ~2,5 × plus LENTEMENT (la brume rampe), autour du point touché le
//     bruit COULE vers le bas, la couleur est froide (cœur blanc-bleu pâle plafonné, jamais blanc pur ; bleu acier au
//     bord ; brume grise bleutée qui se dissipe en traîne de vapeur), paillettes de givre fines dans la masse, et
//     presque pas de lumière propre (le givre n'éclaire pas).
//   - CRISTAL (graine >= 100) : étoile Kenney qui tournoie et SCINTILLE (éclat qui pulse, chaque cristal à son rythme) ;
//     additive (n'assombrit jamais). Inchangé.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

uniform float eclat = 1.0;
uniform float opacite = 0.85;    // couverture du souffle (0..1)
uniform float gros_coeur = 1.0;  // taille du cœur clair (GestionMagie.GROS_COEUR, par école)
uniform float brume = 0.34;      // couverture de la vapeur froide (traîne, fin de vie)
uniform vec4 c0 : source_color = vec4(0.91, 0.95, 0.98, 1.0);  // éclat du givre (paillettes, cristaux) : jamais blanc pur
uniform vec4 c1 : source_color = vec4(0.80, 0.89, 0.95, 1.0);  // cœur blanc-bleu pâle
uniform vec4 c2 : source_color = vec4(0.62, 0.77, 0.89, 1.0);
uniform vec4 c3 : source_color = vec4(0.42, 0.59, 0.75, 1.0);  // bleu acier clair
uniform vec4 c4 : source_color = vec4(0.28, 0.41, 0.56, 1.0);  // bleu acier
uniform vec4 c5 : source_color = vec4(0.18, 0.27, 0.38, 1.0);
uniform vec4 c_brume : source_color = vec4(0.63, 0.71, 0.77, 1.0);  // vapeur froide
uniform sampler2D bruit : filter_linear, repeat_enable;
uniform sampler2D formes : filter_linear, repeat_disable;   // atlas 4×3 (Kenney Particle Pack, CC0) : étoiles des cristaux
// ligne médiane du souffle (monde) : 8 points de la paume (0) au bout (7), espacés de jet_long / 7 m
uniform vec3 jet_pts[8];
uniform float jet_long = 8.5;     // longueur de la ligne (m) : point touché, ou portée en champ libre
uniform float jet_portee = 8.5;   // portée en champ libre (m) : règle le réchauffement (dissipation) le long du souffle

varying vec2 v_px;
varying float v_rpx;
varying vec4 v_c;
varying vec2 v_ax;
varying float v_rl;
varying float v_cristal;
varying float v_proche;
varying vec4 v_j01;
varying vec4 v_j23;
varying vec4 v_j45;
varying vec4 v_j67;
varying vec4 v_jw0;
varying vec4 v_jw1;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 axe = MODEL_MATRIX[1].xyz;
	vec4 cc = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
	vec4 ca = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre + axe, 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float w = max(cc.w, 0.0001);
	vec2 pc = (cc.xy / w * 0.5 + 0.5) * vp;
	float m = max(magie_echelle, 1.0);
	float cristal = step(100.0, INSTANCE_CUSTOM.x);
	float rpx = s * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	// bouffée trop près de l'œil : pas de carré géant ; cristal : au moins un pixel et demi du monde (il reste lisible)
	rpx = cristal > 0.5 ? clamp(rpx, 1.5 * m, vp.y * 0.03) : min(rpx, vp.y * 0.15);
	vec2 pa = (ca.xy / max(ca.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 da = ca.w > 0.0001 ? pa - pc : vec2(0.0);
	float la = length(da);
	vec2 ax = la > 0.001 ? da / la : vec2(0.0, 1.0);
	// étirement : moindre que le feu (souffle lourd qui gonfle, pas langue qui file), retombe avec l'âge
	float rl = cristal > 0.5 ? rpx : clamp(la, rpx, rpx * mix(4.2, 1.7, smoothstep(0.08, 0.45, INSTANCE_CUSTOM.y)));
	vec2 c = (floor(pc / m) + 0.5) * m;
	vec2 off = vec2(-ax.y, ax.x) * VERTEX.x * 2.0 * (rpx + m) + ax * VERTEX.y * 2.0 * (rl + m);
	v_ax = ax;
	v_rl = max(rl, 0.5);
	POSITION = vec4(((c + off) / vp * 2.0 - 1.0) * cc.w, cc.z, cc.w);
	v_px = off;
	v_rpx = max(rpx, 0.5);
	v_c = INSTANCE_CUSTOM;
	v_c.x -= cristal * 100.0;
	v_cristal = cristal;
	v_proche = step(0.5, cc.w);
	vec2 jp_[8];
	float jw_[8];
	for (int i = 0; i < 8; i++) {
		vec4 cj = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(jet_pts[i], 1.0));
		jw_[i] = max(cj.w, 0.05);
		jp_[i] = (cj.xy / jw_[i] * 0.5 + 0.5) * vp;
	}
	v_j01 = vec4(jp_[0], jp_[1]);
	v_j23 = vec4(jp_[2], jp_[3]);
	v_j45 = vec4(jp_[4], jp_[5]);
	v_j67 = vec4(jp_[6], jp_[7]);
	v_jw0 = vec4(jw_[0], jw_[1], jw_[2], jw_[3]);
	v_jw1 = vec4(jw_[4], jw_[5], jw_[6], jw_[7]);
	if (s < 0.000001 || INSTANCE_CUSTOM.y >= 1.0 || cc.w < 0.5) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);   // inactive ou contre l'œil : hors du volume de vue
	}
}

#include "res://shaders/magie_bruit.gdshaderinc"

// dégradé c0 (h >= 1) → c5 (h <= 0), en paliers (3 par intervalle : palette resserrée, pas de dégradé lisse)
vec3 rampe(float h) {
	float x = clamp((1.0 - h) * 5.0, 0.0, 4.999);
	float i = floor(x);
	float f = floor(fract(x) * 3.0) / 3.0;
	vec3 a = i < 1.0 ? c0.rgb : (i < 2.0 ? c1.rgb : (i < 3.0 ? c2.rgb : (i < 4.0 ? c3.rgb : c4.rgb)));
	vec3 b = i < 1.0 ? c1.rgb : (i < 2.0 ? c2.rgb : (i < 3.0 ? c3.rgb : (i < 4.0 ? c4.rgb : c5.rgb)));
	return mix(a, b, f);
}

void fragment() {
	float m = max(magie_echelle, 1.0);
	vec2 q = (floor(v_px / m) + 0.5) * m;
	float g = v_c.x;
	float age = clamp(v_c.y, 0.0, 1.0);
	vec2 qa = vec2(dot(q, vec2(-v_ax.y, v_ax.x)) / v_rpx, dot(q, v_ax) / v_rl);
	vec2 cell = floor(FRAGCOORD.xy / m);
	if (v_cristal > 0.5) {
		float r = length(qa);
		if (r > 1.0) {
			discard;
		}
		float tr = mh2(cell + vec2(floor(TIME * 12.0) * 7.31, g));
		float cr = cos(v_c.z), sr = sin(v_c.z);
		vec2 ur = mat2(vec2(cr, sr), vec2(-sr, cr)) * qa;
		// CRISTAL : étoile qui tournoie et scintille (pulsation propre, éclats brefs)
		float fi = mod(floor(g * 3.7), 4.0);
		vec2 us = clamp(ur * 0.5 + 0.5, vec2(0.01), vec2(0.99));
		float e = texture(formes, (us + vec2(fi, 2.0)) / vec2(4.0, 3.0)).r;
		float sc = 0.5 + 0.5 * sin(TIME * (7.0 + fract(g * 0.37) * 9.0) + g * 5.0);
		float flash = 0.35 + 1.4 * pow(sc, 6.0);
		float vie = smoothstep(0.0, 0.05, age) * (1.0 - smoothstep(0.78, 1.0, age));
		float k = clamp((e - 0.12) * 2.2 * flash * vie, 0.0, 1.0);
		k = floor(k * 4.0 + tr) / 4.0;
		if (k <= 0.0) {
			discard;
		}
		if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
			discard;
		}
		vec3 col = mix(c2.rgb, c0.rgb, smoothstep(0.35, 0.8, e));
		ALBEDO = col * k * 1.4 * eclat;
		ALPHA = 0.0;   // additif
	} else {
		// --- BOUFFÉE : empreinte (disque étiré, moitié arrière courte), comme la vague de flammes ---
		qa.y *= qa.y < 0.0 ? mix(1.0, 2.6, clamp((v_rl / v_rpx - 1.0) * 0.5, 0.0, 1.0)) : 1.0;
		float r = length(qa);
		if (r > 1.0) {
			discard;
		}
		// --- CHAMP PARTAGÉ (identique à magie_vague) : coordonnées du souffle pour le centre du pixel du monde ---
		vec2 fc = (floor(FRAGCOORD.xy / m) + 0.5) * m;
		vec2 jp_[8] = vec2[8](v_j01.xy, v_j01.zw, v_j23.xy, v_j23.zw, v_j45.xy, v_j45.zw, v_j67.xy, v_j67.zw);
		float jw_[8] = float[8](v_jw0.x, v_jw0.y, v_jw0.z, v_jw0.w, v_jw1.x, v_jw1.y, v_jw1.z, v_jw1.w);
		float px_m = abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
		float ds = jet_long / 7.0;
		float sw = 0.0, ss = 0.0, sl = 0.0, sd = 0.0, swj = 0.0, sm_ = 0.0, smpp = 0.0;
		float best = 1e20;
		int bi = 0;
		float avant0 = 0.0;
		float e2m = 4.0 * m * m;
		for (int i = 0; i < 7; i++) {
			vec2 e = jp_[i + 1] - jp_[i];
			float le2 = max(dot(e, e), 1.0);
			float le = sqrt(le2);
			vec2 dp = fc - jp_[i];
			float tu = dot(dp, e) / le2;
			if (i == 0) {
				avant0 = max(-tu, 0.0) * le;
			}
			float tc = clamp(tu, 0.0, 1.0);
			vec2 dd = dp - e * tc;
			float d2 = dot(dd, dd);
			float crs = (dp.x * e.y - dp.y * e.x) / le;
			float li = (crs >= 0.0 ? 1.0 : -1.0) * sqrt(d2);
			float extra = 0.0;
			float lid = li;
			if (i == 6 && tu > 1.0) {
				li = crs;
				extra = (tu - 1.0) * le * jw_[7] / px_m;
			}
			float wa = jw_[i];
			float wb = jw_[i + 1];
			float ai = tc * wa / max(wb + tc * (wa - wb), 0.05);
			float wgt = 1.0 / ((d2 + e2m) * (d2 + e2m));
			sw += wgt;
			ss += wgt * (float(i) + ai) * ds;
			sm_ += wgt * extra;
			sl += wgt * li;
			sd += wgt * abs(lid);
			swj += wgt * mix(wa, wb, ai);
			smpp += wgt * ds / le;
			if (d2 < best) {
				best = d2;
				bi = i;
			}
		}
		float sj = ss / sw;
		float lat = sl / sw;
		float latd = sd / sw;
		float wj = swj / sw;
		float sm = sj + sm_ / sw;
		// rayon du souffle vu à l'écran (il s'ouvre un peu plus que le feu : la brume gonfle)
		float rj = (0.08 + 0.095 * sj) * px_m / max(wj, 0.05);
		float ln = lat / max(rj, m);
		float lna = latd / max(rj, m);
		float t = TIME;
		// turbulence : MÊMES échelles que le feu (découpe sans lambeaux), mais qui défile ~2,5 × plus lentement (≈ 3 m/s) :
		// la brume ROULE et rampe au lieu de fuser
		vec2 jp = vec2(ln * 0.16, sm * 0.30);
		vec2 wv = texture(bruit, vec2(jp.x * 0.7 + 0.37, jp.y * 0.55 - t * 0.42)).rg;
		vec2 np = jp + (wv - 0.5) * vec2(0.22, 0.30);
		float n = texture(bruit, vec2(np.x, np.y - t * 0.85)).b;
		float n2 = texture(bruit, vec2(np.x * 1.7 + 0.5, np.y * 1.6 - t * 0.55 + 0.21)).a;
		n = mix(n, n2, 0.4);
		// plaques de givre (COULEUR seulement, comme les veines du feu : la découpe reste celle de n)
		float n3 = texture(bruit, np * 3.4 + vec2(0.23, -t * 0.9)).r;
		// autour du BOUT (point touché) et là où le souffle file vers le fond : bruit dans le plan de l'écran, qui COULE
		// vers le bas (l'air froid tombe et s'étale), lentement
		float k_bout = smoothstep(jet_long - 1.2 * ds, jet_long + 0.5 * ds, sm);
		k_bout = max(k_bout, smoothstep(0.025, 0.07, smpp / sw * 0.3 * m));
		if (k_bout > 0.0) {
			vec2 pb = (fc - jp_[7]) * jw_[7] / px_m;
			vec2 wb = texture(bruit, pb * 0.21 + vec2(0.61, -t * 0.2)).rg;
			float nb = texture(bruit, pb * 0.36 + (wb - 0.5) * 0.3 + vec2(0.13, -t * 0.36)).b;
			n = mix(n, nb, k_bout);
		}
		// --- couverture : empreinte rongée par la turbulence PARTAGÉE (identique au feu) ---
		float corps = (1.0 - r) * 2.4 - 0.5 + (n - 0.5) * 2.5;
		corps -= bi == 0 ? clamp(avant0 / max(rj, 2.0 * m), 0.0, 1.0) * 2.5 : 0.0;
		corps -= smoothstep(0.42, 0.95, age) * (1.1 + (0.5 - n) * 1.8);
		corps *= smoothstep(0.0, 0.012, age) * v_proche;
		if (corps < 0.03) {
			discard;
		}
		if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
			discard;
		}
		// --- « froid » PARTAGÉ : se dissipe le long du souffle, plus dense sur l'axe, marbré par la turbulence ---
		float qd = sj / max(jet_portee, 1.0);
		float coeur = 1.0 - clamp(lna, 0.0, 1.6) / 1.6;
		float h = 0.64 - 0.85 * pow(qd, 1.2) + coeur * 0.26 * gros_coeur + (n - 0.5) * 0.6 + (wv.x - 0.5) * 0.25;
		h += (n3 - 0.5) * 0.35 * smoothstep(0.2, 0.5, h);
		// loin de l'axe (brume qui retombe, qui traîne quand on tourne, qui s'étale au contact) : bleu acier puis brume
		h -= clamp(lna - 0.8, 0.0, 1.4) * 0.4 * (1.0 - 0.5 * k_bout);
		// cœur blanc-bleu pâle, jamais blanc pur (plafond entre les paliers c1 et c2)
		h = min(h, 0.66 + 0.06 * smoothstep(0.3, 1.5, sj));
		float k = clamp(corps * 3.0, 0.0, 1.0);
		// couverture tramée par un bruit (pas de Bayer) qui bout à 12 images/s, la MÊME pour toutes les bouffées
		float tr = mh2(cell + vec2(floor(TIME * 12.0) * 7.31, 3.7));
		k = clamp(floor(k * 3.0 + tr) / 3.0, 0.0, 1.0);
		if (k <= 0.0) {
			discard;
		}
		vec3 c;
		float al;
		float lum;
		if (h > 0.0) {
			c = rampe(h);
			// masse presque couvrante (sinon l'empilement redessine les empreintes), les bords se dissipent en brume
			al = opacite * clamp(0.74 + h * 0.2, 0.0, 0.92) * (1.0 - 0.4 * smoothstep(0.9, 1.9, lna));
			lum = clamp(h - 0.62, 0.0, 1.0) * 0.18;   // presque pas de lumière propre : le givre n'éclaire pas
			// paillettes de givre fines dans la masse (pixels du monde qui scintillent, chacun à son instant)
			float sp = step(0.983, mh2(cell * 1.37 + vec2(floor(TIME * 8.0) * 3.1, 5.3))) * smoothstep(0.25, 0.5, h);
			c = mix(c, c0.rgb, sp);
			lum += sp * 0.55;
		} else {
			// traîne de vapeur froide : bleu acier qui pâlit en brume grise bleutée, légère, sans lumière
			float f = clamp(-h * 2.5, 0.0, 1.0);
			c = mix(c4.rgb, c_brume.rgb, f);
			al = mix(opacite * 0.62, brume, f);
			lum = 0.0;
		}
		// bouffées âgées (bout, cordon qui traîne quand on tourne, où elles s'espacent) : elles PÂLISSENT en vapeur
		// transparente au lieu de rester des boules couvrantes (alpha seulement : la découpe n'est pas touchée)
		float vieux = smoothstep(0.5, 0.95, age);
		c = mix(c, c_brume.rgb, vieux * 0.5);
		al *= 1.0 - 0.65 * vieux;
		lum *= 1.0 - vieux;
		ALBEDO = c * (al + lum) * eclat * k;
		ALPHA = al * k;
	}
}
