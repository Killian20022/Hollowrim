// FAISCEAU de l'arc électrique (couche fine ; scripts/magie/gestion_magie.gd, _faisceau_*) : le CORPS épais de l'arc,
// d'un seul tenant, de la paume au point frappé. Un ruban fixe (UV.x = t le long de l'arc, UV.y = côté -1/+1) est tendu
// À L'ÉCRAN sur la courbe de Bézier paume → contrôle → bout (uniformes `arc_o`, `arc_c`, `arc_b`, mêmes points que la décharge et
// l'arc maître) ; sa demi-largeur suit la perspective (enveloppe de `enveloppe` m) dans des bornes en pixels.
// Dans ce ruban, le fragment dessine :
//   - 3 brins tressés (4 en double) en ZIGZAG (bruit linéaire par morceaux, 2 octaves) qui changent de forme 30 fois par
//     seconde : le brin maître épais (cœur blanc de 3 pixels du monde), deux brins fins qui le croisent et papillotent ;
//   - 2 fourches par image qui jaillissent du brin maître et s'éteignent (ramification) ;
//   - une gaine (lueur autour du brin maître) qui COUVRE un peu le fond en violet sombre (opacité partielle) : sur la neige
//     de jour, l'arc reste bleu-violet au lieu de blanchir (l'additif pur s'y perdait).
// Couleurs : paliers de la palette électrique (blanc → blanc-bleu → bleu → violet), tramage par un BRUIT qui change à
// chaque image (jamais de Bayer), motif évalué au pixel du MONDE.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

uniform vec3 arc_o = vec3(0.0);
uniform vec3 arc_c = vec3(0.0, 0.0, -1.0);
uniform vec3 arc_b = vec3(0.0, 0.0, -2.0);
uniform float touche = 0.0;          // 1 : l'arc frappe quelque chose (les brins convergent au bout)
uniform float force = 1.0;           // 0..1 : montée à l'allumage
uniform float dbl = 0.0;             // double incantation : un brin de plus, gaine plus large
uniform float graine = 0.0;
uniform float enveloppe = 0.2;       // demi-largeur du ruban (m) avant les bornes en pixels
uniform float px_min = 7.0;          // bornes de la demi-largeur (pixels du MONDE)
uniform float px_max = 22.0;
uniform float coeur_px = 2.0;        // demi-épaisseur du cœur du brin maître (pixels du monde)
uniform float eclat = 1.35;
uniform float ombre = 0.72;          // couverture maximale de la gaine (0 = additif pur)
uniform vec4 c0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c1 : source_color = vec4(0.94, 0.95, 1.0, 1.0);
uniform vec4 c2 : source_color = vec4(0.71, 0.75, 1.0, 1.0);
uniform vec4 c3 : source_color = vec4(0.48, 0.48, 0.94, 1.0);
uniform vec4 c4 : source_color = vec4(0.29, 0.23, 0.82, 1.0);
uniform vec4 c5 : source_color = vec4(0.16, 0.10, 0.42, 1.0);
uniform vec4 gaine_c : source_color = vec4(0.10, 0.05, 0.30, 1.0);

varying float v_t;
varying float v_off;      // décalage perpendiculaire (pixels de l'écran)
varying float v_h;        // demi-largeur (pixels de l'écran)
varying float v_lpx;      // longueur de l'arc à l'écran (pixels) : pente des zigzags

vec3 bez(float t) {
	return arc_o * (1.0 - t) * (1.0 - t) + arc_c * 2.0 * (1.0 - t) * t + arc_b * t * t;
}

vec2 ecran(vec4 cl, vec2 vp) {
	return (cl.xy / max(cl.w, 0.0001) * 0.5 + 0.5) * vp;
}

void vertex() {
	float t = UV.x;
	vec3 p = bez(t);
	vec3 p2 = bez(min(t + 0.02, 1.0));
	vec3 p1 = bez(max(t - 0.02, 0.0));
	vec2 vp = VIEWPORT_SIZE;
	float m = max(magie_echelle, 1.0);
	vec4 cp = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p, 1.0));
	vec2 sa = ecran(PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p1, 1.0)), vp);
	vec2 sb = ecran(PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p2, 1.0)), vp);
	vec2 d = sb - sa;
	if (dot(d, d) < 0.000001) {
		d = vec2(1.0, 0.0);
	}
	vec2 perp = normalize(vec2(-d.y, d.x));
	float w = max(cp.w, 0.05);
	float h = enveloppe * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	h = clamp(h, px_min * m, px_max * m) * (1.0 + 0.3 * dbl);
	vec2 s = ecran(cp, vp) + perp * UV.y * h;
	POSITION = vec4((s / vp * 2.0 - 1.0) * cp.w, cp.z, cp.w);
	v_t = t;
	v_off = UV.y * h;
	v_h = h;
	vec2 so = ecran(PROJECTION_MATRIX * (VIEW_MATRIX * vec4(arc_o, 1.0)), vp);
	vec2 sbt = ecran(PROJECTION_MATRIX * (VIEW_MATRIX * vec4(arc_b, 1.0)), vp);
	v_lpx = max(length(sbt - so), 8.0);
	if (cp.w < 0.08) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
	}
}

float mh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// zigzag : bruit linéaire par morceaux (sommets au hasard, segments droits = éclair), 2 octaves ; renvoie -1..1
float zig(float x, float img, float s) {
	float k = floor(x);
	float f = fract(x);
	float a = mix(mh(vec2(k, img + s)), mh(vec2(k + 1.0, img + s)), f);
	float x2 = x * 3.1 + 5.0;
	float k2 = floor(x2);
	float f2 = fract(x2);
	float a2 = mix(mh(vec2(k2, img * 1.3 + s + 9.0)), mh(vec2(k2 + 1.0, img * 1.3 + s + 9.0)), f2);
	return (a * 2.0 - 1.0) * 0.78 + (a2 * 2.0 - 1.0) * 0.22;
}

vec3 rampe(float h) {
	float x = clamp((1.0 - h) * 5.0, 0.0, 4.999);
	float i = floor(x);
	float f = floor(fract(x) * 2.0) / 2.0;
	vec3 a = i < 1.0 ? c0.rgb : (i < 2.0 ? c1.rgb : (i < 3.0 ? c2.rgb : (i < 4.0 ? c3.rgb : c4.rgb)));
	vec3 bb = i < 1.0 ? c1.rgb : (i < 2.0 ? c2.rgb : (i < 3.0 ? c3.rgb : (i < 4.0 ? c4.rgb : c5.rgb)));
	return mix(a, bb, f);
}

void fragment() {
	float m = max(magie_echelle, 1.0);
	float t = v_t;
	float y = (floor(v_off / m) + 0.5) * m;        // pixel du MONDE en travers
	float img = floor(TIME * 30.0);
	float l = max(distance(arc_o, arc_b), 0.3);
	float nk = 5.0 + l * 2.2;                       // sommets du zigzag sur la longueur
	// enveloppe : naît fin dans la paume, s'ouvre, converge sur la cible (ou s'effiloche dans le vide)
	float env = smoothstep(0.0, 0.16, t) * (touche > 0.5 ? mix(1.0, 0.25, smoothstep(0.82, 1.0, t)) : mix(1.0, 1.35, smoothstep(0.7, 1.0, t)));
	float bord = touche > 0.5 ? 1.0 : 1.0 - smoothstep(0.88, 1.0, t);
	float hm = v_h * 0.62 * env;
	float I = 0.0;          // intensité additive (0..1+)
	float gaine = 0.0;      // couverture violette autour du brin maître
	float ns = 3.0 + dbl;
	float y_maitre = 0.0;
	for (float i = 0.0; i < 4.0; i += 1.0) {
		if (i >= ns) {
			break;
		}
		float sg = graine * 17.0 + i * 31.7;
		// le brin maître change de forme une image sur deux (lisible), les autres à chaque image
		float im = i < 0.5 ? floor(img * 0.5) : img;
		float x = t * nk + sg;
		float amp = i < 0.5 ? 0.45 : 0.9;
		float yi = zig(x, im, sg) * hm * amp;
		if (i < 0.5) {
			y_maitre = yi;
		}
		// pente locale (épaisseur constante dans les segments obliques)
		float yi2 = zig(x + 0.02, im, sg) * hm * amp;
		float dd = abs(y - yi) / sqrt(1.0 + pow((yi2 - yi) / (0.02 * v_lpx / nk), 2.0));
		float flick = mh(vec2(img, sg));
		float ki = i < 0.5 ? (flick < 0.1 ? 0.6 : 0.8 + 0.2 * flick) : (flick < 0.3 ? 0.0 : (flick < 0.65 ? 0.5 : 0.85));
		float cw = (i < 0.5 ? coeur_px : coeur_px * 0.45) * m * (1.0 + 0.25 * dbl);
		float core = 1.0 - smoothstep(cw, cw + m, dd);
		float halo = exp(-max(dd - cw, 0.0) / ((i < 0.5 ? 4.0 : 1.8) * m));
		I = max(I, ki * (core * 1.15 + halo * (i < 0.5 ? 0.62 : 0.35)));
		if (i < 0.5) {
			gaine = exp(-max(dd - cw, 0.0) / (6.5 * m * (1.0 + 0.4 * dbl)));
		}
	}
	// fourches : 2 par image, partent du brin maître et s'en écartent en zigzag, s'éteignent vers leur bout
	for (float k = 0.0; k < 2.0; k += 1.0) {
		float sk = graine * 7.0 + k * 13.3 + img * 0.37;
		float t0 = 0.3 + 0.6 * mh(vec2(sk, 1.0));
		float lg = 0.06 + 0.12 * mh(vec2(sk, 2.0));
		float u = (t - t0) / lg;
		if (u > 0.0 && u < 1.0) {
			float sens = mh(vec2(sk, 3.0)) < 0.5 ? -1.0 : 1.0;
			float y0 = zig(t0 * nk + graine * 17.0, floor(img * 0.5), graine * 17.0) * v_h * 0.62 * 0.45 * env;
			float yf = y0 + sens * u * v_h * (0.45 + 0.4 * mh(vec2(sk, 4.0))) + zig(u * 4.0 + sk, img, sk) * v_h * 0.12 * u;
			float dd = abs(y - yf);
			float cw = coeur_px * 0.5 * m * (1.0 - u * 0.6);
			float kf = (1.0 - u) * (1.0 - smoothstep(cw, cw + m, dd)) + (1.0 - u) * 0.3 * exp(-max(dd - cw, 0.0) / (1.5 * m));
			I = max(I, kf * 0.9);
		}
	}
	I *= force * bord;
	gaine *= force * bord * env;
	if (I < 0.03 && gaine < 0.03) {
		discard;
	}
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	// paliers + tramage par bruit (change à chaque image)
	vec2 cell = floor(FRAGCOORD.xy / m);
	float tr = mh(cell + vec2(img * 7.31, graine));
	float kq = clamp(floor(I * 5.0 + tr * 0.9) / 5.0, 0.0, 1.2);
	float gq = clamp(floor(gaine * 4.0 + tr * 0.9) / 4.0, 0.0, 1.0);
	vec3 col = rampe(clamp(kq * 1.0 - 0.02, 0.0, 1.0));
	float a = gq * ombre;
	// pixel mixte (magie_compose) : couverture violette (rgb <= a) + lumière ajoutée
	ALBEDO = gaine_c.rgb * a + col * eclat * kq;
	ALPHA = a;
}
