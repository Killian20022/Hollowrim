// VAGUE de flammes du jet de feu (couche fine) : dessin d'UNE bouffée (particule de magie_vague_process.gdshader).
// Carré tourné vers la caméra, rayon = échelle de la particule, étiré dans le sens de la vitesse.
// UN SEUL VOLUME DE FEU (2026-10-29 soir, « vague de pixels uniforme, moins de petits bouts de flamme ») : la bouffée ne
// dessine plus SA forme (avant : flammes du Kenney Particle Pack, chacune lisible) ; elle n'est plus qu'une EMPREINTE
// (disque étiré, doux) qui dit « il y a du feu ici ». Couleur, motif et bords viennent d'un CHAMP PARTAGÉ, calculé pour
// le pixel et non pour la bouffée : la LIGNE MÉDIANE réelle du jet (jet_pts : 8 points posés chaque image par
// GestionMagie._vague_axe, d'après l'historique des poses de la main : en tournant, elle suit le cordon qui traîne) est
// projetée à l'écran ; pour chaque pixel, le point le plus proche de cette ligne donne les coordonnées du jet (distance à
// la paume s, écart à la ligne). Toutes les bouffées qui couvrent un pixel y trouvent la même couleur, le même bruit, le
// même tramage : elles se fondent en une masse continue, sans couture.
//   - turbulence : bruit précalculé déformé par un second bruit, qui DÉFILE le long du jet (la matière avance) et bout ;
//   - dégradé : cœur clair près de la main → jaune → orange → rouge sombre → fumée au bout, plus chaud sur l'axe ;
//   - bords : la même turbulence ronge l'enveloppe des empreintes (bords déchiquetés, pas de formes de flamme) et les
//     bouffées âgées se trouent en lambeaux.
// Rendu ps1 : tout est évalué au centre du pixel du MONDE, couleurs en paliers de la palette, couverture tramée par un
// bruit qui bout (12 images/s), jamais une matrice de Bayer. Fusion PRÉMULTIPLIÉE « mixte » : le cœur chaud éclaire, le
// corps du feu couvre (presque opaque, sinon l'empilement des bouffées redessinerait leurs contours).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

uniform float eclat = 1.0;
uniform float opacite = 1.0;     // couverture des flammes (0..1)
uniform float gros_coeur = 1.0;  // taille du cœur chaud (GestionMagie.GROS_COEUR, par école) : 1 = normal, > 1 = cœur plus large
uniform float fumee = 0.55;      // couverture de la fumée en fin de vie
uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);   // chauffé à blanc
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);
uniform vec4 c5 : source_color = vec4(0.35, 0.10, 0.11, 1.0);
uniform vec4 c_fumee : source_color = vec4(0.11, 0.09, 0.09, 1.0);
// bruit fractal précalculé, périodique (GestionMagie._tex_bruit_vague : 64², 4 canaux indépendants, 3 octaves,
// 8 cases par période) : 3 lectures de texture au lieu de bruits calculés par pixel
uniform sampler2D bruit : filter_linear, repeat_enable;
// ligne médiane du jet (monde) : 8 points de la paume (0) au bout (7), également espacés de jet_long / 7 mètres
// (GestionMagie._vague_axe, un matériau par jet)
uniform vec3 jet_pts[8];
uniform float jet_long = 10.5;     // longueur de la ligne (m) : point touché, ou portée en champ libre
uniform float jet_portee = 10.5;   // portée en champ libre (m) : règle le refroidissement le long du jet

varying vec2 v_px;      // position dans le carré, en pixels de la couche (0 = centre)
varying float v_rpx;    // rayon en pixels de la couche
varying vec4 v_c;       // graine, âge (seul utilisé), rotation
varying vec2 v_ax;      // axe d'étirement à l'écran (sens de la vitesse)
varying float v_rl;     // demi-longueur en pixels le long de l'axe
varying float v_proche; // 0 tout contre l'œil (pas de voile pâle sur la main), 1 au-delà de ~0,8 m
// ligne médiane projetée à l'écran (identique pour toutes les bouffées) : points 0-7 en pixels de la couche (2 par
// vec4) et leurs profondeurs (pour remonter de l'écran à la distance réelle le long du jet)
varying vec4 v_j01;
varying vec4 v_j23;
varying vec4 v_j45;
varying vec4 v_j67;
varying vec4 v_jw0;
varying vec4 v_jw1;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 axe = MODEL_MATRIX[1].xyz;   // sens de la vitesse × rayon × étirement
	vec4 cc = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
	vec4 ca = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre + axe, 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float w = max(cc.w, 0.0001);
	vec2 pc = (cc.xy / w * 0.5 + 0.5) * vp;
	float m = max(magie_echelle, 1.0);
	float rpx = s * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	// trop près de l'œil (bouffée qui naît dans la paume) : pas de carré géant
	rpx = min(rpx, vp.y * 0.15);
	// étirement vu à l'écran : de face (vitesse vers l'œil) la bouffée reste ronde, de profil c'est une langue
	vec2 pa = (ca.xy / max(ca.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 da = ca.w > 0.0001 ? pa - pc : vec2(0.0);
	float la = length(da);
	vec2 ax = la > 0.001 ? da / la : vec2(0.0, 1.0);
	// (jeune : langue qui file ; en vieillissant l'étirement retombe, sinon les empreintes qui s'éloignent de l'œil
	// dessinent un éventail de rayons autour du bout)
	float rl = clamp(la, rpx, rpx * mix(5.2, 2.0, smoothstep(0.08, 0.45, INSTANCE_CUSTOM.y)));
	// centre calé sur la grille des pixels du MONDE : le motif ne glisse pas d'un sous-pixel à l'autre
	vec2 c = (floor(pc / m) + 0.5) * m;
	vec2 off = vec2(-ax.y, ax.x) * VERTEX.x * 2.0 * (rpx + m) + ax * VERTEX.y * 2.0 * (rl + m);
	v_ax = ax;
	v_rl = max(rl, 0.5);
	POSITION = vec4(((c + off) / vp * 2.0 - 1.0) * cc.w, cc.z, cc.w);
	v_px = off;
	v_rpx = max(rpx, 0.5);
	v_c = INSTANCE_CUSTOM;
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
	// (et contre l'œil, où la bouffée serait de toute façon effacée : on n'en paie pas les pixels)
	if (s < 0.000001 || INSTANCE_CUSTOM.y >= 1.0 || cc.w < 0.5) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);   // particule inactive : hors du volume de vue
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
	// pixel du MONDE (grain ps1) : empreinte évaluée au centre du gros pixel
	vec2 q = (floor(v_px / m) + 0.5) * m;
	float age = clamp(v_c.y, 0.0, 1.0);
	// empreinte de la bouffée : disque étiré dans le sens de la vitesse (étirement défait)
	vec2 qa = vec2(dot(q, vec2(-v_ax.y, v_ax.x)) / v_rpx, dot(q, v_ax) / v_rl);
	// la moitié ARRIÈRE de l'empreinte est courte (une bouffée qui file ne déborde pas en arrière de la paume)
	qa.y *= qa.y < 0.0 ? mix(1.0, 2.6, clamp((v_rl / v_rpx - 1.0) * 0.5, 0.0, 1.0)) : 1.0;
	float r = length(qa);
	if (r > 1.0) {
		discard;
	}
	// --- CHAMP PARTAGÉ : coordonnées du JET pour le centre du pixel du monde (les mêmes pour toutes les bouffées) ---
	// point le plus proche sur la ligne médiane projetée (7 segments) : distance réelle à la paume (sj, remontée par la
	// perspective dans le segment) et écart à la ligne en pixels, rapporté au rayon du jet vu à cette distance (ln : 0 sur
	// la ligne, 1 au bord). (Un calcul en 3D « rayon de vue / axe » ne marche pas en vue FPS : l'œil est presque SUR
	// l'axe, tous les rayons le frôlent.)
	vec2 fc = (floor(FRAGCOORD.xy / m) + 0.5) * m;
	vec2 jp_[8] = vec2[8](v_j01.xy, v_j01.zw, v_j23.xy, v_j23.zw, v_j45.xy, v_j45.zw, v_j67.xy, v_j67.zw);
	float jw_[8] = float[8](v_jw0.x, v_jw0.y, v_jw0.z, v_jw0.w, v_jw1.x, v_jw1.y, v_jw1.z, v_jw1.w);
	// Chaque segment donne SA distance réelle (sj_i) et son écart signé ; on les MÉLANGE, pondérés par la proximité
	// (1/d²²) : pas de couture droite là où le segment le plus proche change (creux d'un virage quand on tourne, deux
	// segments à des distances différentes). Le dernier segment est prolongé au-delà du bout pour l'écart et la distance
	// (sinon, autour du point touché, l'écart devient une distance au POINT et le motif dessine des anneaux), mais sa
	// proximité reste mesurée au bout lui-même (sinon sa droite prolongée « capte » des pixels loin du jet).
	float px_m = abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
	float ds = jet_long / 7.0;
	float sw = 0.0, ss = 0.0, sl = 0.0, sd = 0.0, swj = 0.0, sm_ = 0.0, smpp = 0.0;
	float best = 1e20;
	int bi = 0;
	float avant0 = 0.0;   // à l'écran, distance (px) en arrière de la paume (> 0 : derrière la main)
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
		float cr = (dp.x * e.y - dp.y * e.x) / le;   // écart perpendiculaire signé à la droite du segment
		float li = (cr >= 0.0 ? 1.0 : -1.0) * sqrt(d2);
		float extra = 0.0;
		float lid = li;   // écart RÉEL (distance au bout au-delà de celui-ci) : chaleur du cœur, refroidissement
		if (i == 6 && tu > 1.0) {
			li = cr;                                   // au-delà du bout : écart à la droite prolongée (motif)
			extra = (tu - 1.0) * le * jw_[7] / px_m;   // et surplus converti en mètres à cette profondeur
		}
		float wa = jw_[i];
		float wb = jw_[i + 1];
		float ai = tc * wa / max(wb + tc * (wa - wb), 0.05);   // fraction réelle du segment (perspective)
		float wgt = 1.0 / ((d2 + e2m) * (d2 + e2m));
		sw += wgt;
		ss += wgt * (float(i) + ai) * ds;
		sm_ += wgt * extra;
		sl += wgt * li;
		sd += wgt * abs(lid);
		swj += wgt * mix(wa, wb, ai);
		smpp += wgt * ds / le;   // mètres de jet par pixel d'écran, le long du segment
		if (d2 < best) {
			best = d2;
			bi = i;
		}
	}
	float sj = ss / sw;
	float lat = sl / sw;     // écart signé pour le MOTIF (pas d'anneaux autour du bout)
	float latd = sd / sw;    // écart réel pour la CHALEUR (pas de rayon brûlant dans le prolongement du bout)
	float wj = swj / sw;
	// au-delà du bout (cible, mur : la matière y est écrasée et déborde) : même distance que le bout ; le motif continue
	// avec le surplus (sinon : motif figé en stries)
	float sm = sj + sm_ / sw;
	// rayon du jet (le spray s'ouvre) vu à l'écran à cette distance
	float rj = (0.07 + 0.085 * sj) * px_m / max(wj, 0.05);
	float ln = lat / max(rj, m);
	float lna = latd / max(rj, m);
	float t = TIME;
	// turbulence qui défile le long du jet (≈ 7 m/s) et bout : déformation lente + bruit fin déformé, + un 2e canal à
	// contre-temps (le motif ne glisse pas en bloc : il se renouvelle)
	vec2 jp = vec2(ln * 0.16, sm * 0.30);
	vec2 wv = texture(bruit, vec2(jp.x * 0.7 + 0.37, jp.y * 0.55 - t * 1.05)).rg;
	vec2 np = jp + (wv - 0.5) * vec2(0.22, 0.30);
	float n = texture(bruit, vec2(np.x, np.y - t * 2.2)).b;
	float n2 = texture(bruit, vec2(np.x * 1.7 + 0.5, np.y * 1.6 - t * 1.4 + 0.21)).a;
	n = mix(n, n2, 0.4);
	// relief du feu : un 3e bruit plus fin, déformé comme les autres, creuse des veines sombres dans le cœur
	float n3 = texture(bruit, np * 2.9 + vec2(0.23, -t * 3.1)).r;
	n = clamp(n + (n3 - 0.5) * 0.45, 0.0, 1.0);
	// autour du BOUT (point touché : la matière s'y écrase et s'étale de tous côtés) : les coordonnées du jet n'ont plus
	// de sens (anneaux, stries) ; on passe à un bruit posé dans le plan de l'écran autour du bout, en mètres à cette
	// profondeur, qui bout et monte
	float k_bout = smoothstep(jet_long - 1.2 * ds, jet_long + 0.5 * ds, sm);
	// idem là où le jet file vers le fond (vu de l'œil, des mètres de jet tiennent en quelques pixels) : le motif en
	// coordonnées du jet s'y tasserait en tourbillon de rayons
	k_bout = max(k_bout, smoothstep(0.025, 0.07, smpp / sw * 0.3 * m));
	if (k_bout > 0.0) {
		vec2 pb = (fc - jp_[7]) * jw_[7] / px_m;
		vec2 wb = texture(bruit, pb * 0.21 + vec2(0.61, t * 0.5)).rg;
		float nb = texture(bruit, pb * 0.36 + (wb - 0.5) * 0.3 + vec2(0.13, t * 0.9)).b;
		n = mix(n, nb, k_bout);
	}
	// --- couverture : empreinte rongée par la turbulence PARTAGÉE (bords déchiquetés, aucune forme propre) ---
	float corps = (1.0 - r) * 2.4 - 0.5 + (n - 0.5) * 2.5;
	// rien en arrière de la paume (à l'écran, avant le début de l'axe)
	corps -= bi == 0 ? clamp(avant0 / max(rj, 2.0 * m), 0.0, 1.0) * 2.5 : 0.0;
	// bouffées âgées (le haut du panache, le bout) : se trouent en lambeaux (toujours par le champ partagé), puis
	// s'effacent
	corps -= smoothstep(0.42, 0.95, age) * (1.1 + (0.5 - n) * 1.8);
	// naissance (apparaît dans la paume, pas de pop) et rien contre l'œil (pas de voile sur la main)
	corps *= smoothstep(0.0, 0.012, age) * v_proche;
	if (corps < 0.03) {
		discard;
	}
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	// --- température PARTAGÉE : refroidit le long du jet, plus chaude sur l'axe, veinée par la turbulence ---
	float qd = sj / max(jet_portee, 1.0);
	float coeur = 1.0 - clamp(lna, 0.0, 1.6) / 1.6;
	float h = 0.62 - 0.95 * pow(qd, 1.3) + coeur * 0.30 * gros_coeur + (smoothstep(0.15, 0.85, n) - 0.5) * 1.9 + (wv.x - 0.5) * 0.5;
	// loin de l'axe (matière qui monte, qui traîne quand on tourne, qui déborde de la cible) : elle a refroidi
	// (moins autour du point touché : la flamme écrasée lèche la cible, elle reste vive)
	h -= clamp(lna - 1.0, 0.0, 1.4) * 0.26 * (1.0 - 0.6 * k_bout);
	// tout près de la paume : jaune d'or saturé, pas un voile blanc laiteux autour de la main
	h = min(h, 0.54 + 0.06 * smoothstep(0.3, 1.5, sj));   // le cœur reste ORANGE (jamais crème)
	// bord net (déchiqueté par la turbulence) plutôt qu'un large halo de points tramés
	float k = clamp(corps * 3.0, 0.0, 1.0);
	// couverture tramée par un bruit (pas de Bayer) qui « bout » à 12 images/s, la MÊME pour toutes les bouffées
	vec2 cell = floor(FRAGCOORD.xy / m);
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
		// corps du feu presque opaque (la masse ne laisse pas voir l'empilement des bouffées) ; lumière seulement sur le
		// cœur blanc-jaune
		al = opacite * clamp(0.82 + h * 0.15, 0.0, 0.97);
		lum = clamp(h - 0.4, 0.0, 1.0) * 0.35;
	} else {
		// fumée : rouge sombre qui noircit, couvrante mais légère, sans lumière
		float f = clamp(-h * 2.5, 0.0, 1.0);
		c = mix(c5.rgb, c_fumee.rgb, f);
		al = mix(opacite * 0.8, fumee, f);
		lum = 0.0;
	}
	ALBEDO = c * (al + lum) * eclat * k;
	ALPHA = al * k;
}
