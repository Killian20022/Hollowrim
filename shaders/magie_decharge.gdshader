// DÉCHARGE du jet électrique (couche fine) : dessin d'UN éclat (particule de magie_decharge_process.gdshader).
// Quadrilatère À L'ÉCRAN tendu entre les deux extrémités projetées de l'éclat (axe = MODEL_MATRIX[1], demi-longueur),
// largeur proportionnelle ; il porte une forme d'éclair du Kenney Particle Pack (CC0, atlas 4×2 de 128² :
// spark_05, spark_06, spark_07, trace_03 / spark_01, spark_02, spark_04, star_04).
// VIVANT : à chaque image (30 /s) l'éclat change de forme (case suivante de l'atlas, miroir au hasard, glissement le
// long de son axe) et d'éclat (scintillement : plein, à moitié, ou éteint une image sur cinq environ).
// Couleur : cœur blanc-bleu → bleu → violet selon l'intensité, en PALIERS (palette du jet électrique) ; motif évalué
// au pixel du MONDE, couverture tramée par un bruit qui change à chaque image (jamais de Bayer). Additif (prémultiplié,
// ALPHA = 0, comme magie_trait).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

uniform float eclat = 1.25;
uniform float cadence = 30.0;    // changements de forme par seconde
uniform vec4 c0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);        // cœur blanc
uniform vec4 c1 : source_color = vec4(0.94, 0.95, 1.0, 1.0);      // blanc-bleu
uniform vec4 c2 : source_color = vec4(0.71, 0.75, 1.0, 1.0);      // bleu clair
uniform vec4 c3 : source_color = vec4(0.48, 0.48, 0.94, 1.0);     // bleu-violet
uniform vec4 c4 : source_color = vec4(0.29, 0.23, 0.82, 1.0);     // violet
uniform vec4 c5 : source_color = vec4(0.16, 0.10, 0.42, 1.0);     // violet sombre (halo)
uniform sampler2D formes : filter_linear, repeat_disable;

varying vec2 v_px;      // même chose en pixels de la couche (pour le grain au pixel du monde)
varying vec2 v_ax;      // axe à l'écran
varying float v_rl;     // demi-longueur (px)
varying float v_rw;     // demi-largeur (px)
varying vec4 v_c;       // graine, âge, genre/case, t

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 axe = MODEL_MATRIX[1].xyz;
	float w0 = length(MODEL_MATRIX[0].xyz);
	vec4 cc = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
	vec4 ca = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre + axe, 1.0));
	vec4 cb = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre - axe, 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float m = max(magie_echelle, 1.0);
	float w = max(cc.w, 0.0001);
	vec2 pc = (cc.xy / w * 0.5 + 0.5) * vp;
	vec2 pa = (ca.xy / max(ca.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 pb = (cb.xy / max(cb.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 da = pa - pb;
	float la = length(da) * 0.5;
	vec2 ax = la > 0.001 ? da / (la * 2.0) : vec2(0.0, 1.0);
	float rw = w0 * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	// contre l'œil (paume à ~0,45 m) : pas de bandeau géant ; un trait vu de face reste un trait court
	float rl = clamp(la, rw * 0.8, vp.y * 0.3);
	rw = clamp(rw, m * 1.5, vp.y * 0.12);
	vec2 cen = (floor(((pa + pb) * 0.5) / m) + 0.5) * m;
	vec2 off = vec2(-ax.y, ax.x) * VERTEX.x * 2.0 * (rw + m) + ax * VERTEX.y * 2.0 * (rl + m);
	POSITION = vec4(((cen + off) / vp * 2.0 - 1.0) * cc.w, cc.z, cc.w);
	v_px = off;
	v_ax = ax;
	v_rl = max(rl, 0.5);
	v_rw = max(rw, 0.5);
	v_c = INSTANCE_CUSTOM;
	if (w0 < 0.000001 || INSTANCE_CUSTOM.y >= 1.0 || cc.w < 0.3 || ca.w < 0.05 || cb.w < 0.05) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);   // inactive ou contre l'œil : hors du volume de vue
	}
}

float mh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	// pixel du MONDE : coordonnées du quad ramenées au centre du gros pixel
	vec2 q = (floor(v_px / m) + 0.5) * m;
	vec2 u = vec2(dot(q, vec2(-v_ax.y, v_ax.x)) / v_rw, dot(q, v_ax) / v_rl);
	if (abs(u.x) > 1.0 || abs(u.y) > 1.0) {
		discard;
	}
	float g = v_c.x;
	float age = clamp(v_c.y, 0.0, 1.0);
	int genre = int(v_c.z) / 8;
	int cas = int(v_c.z) - genre * 8;
	// image courante (30 /s), décalée par éclat : la forme et l'éclat changent à chaque image
	float img = floor(TIME * cadence + g * 13.0);
	float hz = mh(vec2(img, g));
	float hz2 = mh(vec2(g, img * 1.7));
	int ci = cas;
	if (genre == 0) {
		ci = (cas + int(img)) % 4;            // trait : enchaîne les 4 formes d'éclair
	} else if (genre == 1) {
		ci = 4 + (cas - 4 + int(img)) % 3;    // crépitement : enchaîne les 3 nuages
		if (hz2 > 0.8) {
			ci = 7;                            // et parfois l'éclat en croix (star_04)
		}
	} else if (genre == 3) {
		ci = int(img + g) % 2;                // fourche : formes les plus anguleuses
	}
	// miroir et glissement au hasard à chaque image (la même forme n'est jamais deux fois la même)
	vec2 uu = u;
	if (hz > 0.5) {
		uu.x = -uu.x;
	}
	if (genre == 1 && hz2 > 0.5) {
		uu = vec2(uu.y, -uu.x);               // nuage tourné d'un quart
	}
	float gl = genre == 1 ? 0.0 : (hz2 - 0.5) * 0.5;
	vec2 tuv = vec2(uu.x * 0.5 + 0.5, fract(0.5 - uu.y * 0.5 + gl));
	tuv = clamp(tuv, vec2(0.01), vec2(0.99));
	float cx = float(ci % 4), cy = float(ci / 4);
	float v = texture(formes, (tuv + vec2(cx, cy)) / vec2(4.0, 2.0)).r;
	// extrémités du trait estompées (le glissement ne montre pas de coupure nette)
	if (genre != 1) {
		v *= 1.0 - smoothstep(0.7, 1.0, abs(u.y));
	}
	// scintillement : une image sur cinq éteinte, sinon plein ou à moitié ; naissance franche, fin qui s'efface
	float sc = hz < 0.18 ? 0.0 : (hz < 0.5 ? 0.55 : 1.0);
	if (genre == 2) {
		sc = 1.0;
	}
	sc *= 1.0 - smoothstep(0.65, 1.0, age);
	float k = v * sc * 1.35;
	if (k < 0.04) {
		discard;
	}
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	// paliers + tramage par bruit (change à chaque image) : 5 niveaux d'intensité
	vec2 cell = floor(FRAGCOORD.xy / m);
	float tr = mh(cell + vec2(img * 7.31, g));
	float kq = clamp(floor(k * 5.0 + tr * 0.9) / 5.0, 0.0, 1.0);
	if (kq <= 0.0) {
		discard;
	}
	// couleur : blanc au cœur des traits intenses, bleu puis violet vers le halo
	vec3 col = rampe(clamp(kq * 1.05 - 0.05, 0.0, 1.0));
	float force = kq * (genre == 1 ? 0.45 : 1.0);
	ALBEDO = col * eclat * force;
	ALPHA = 0.0;
}
