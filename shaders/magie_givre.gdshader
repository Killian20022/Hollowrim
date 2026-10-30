// SOUFFLE DE GIVRE du jet de glace (couche fine) : dessin d'une particule de magie_givre_process.gdshader. Même
// architecture que la vague de flammes (magie_vague.gdshader) : carré tourné vers la caméra, motif évalué par pixel du
// MONDE (grain ps1), couleurs en paliers de la palette, couverture tramée par un bruit qui bout (jamais de Bayer).
//   - BOUFFÉE : volumes de fumée Kenney enchaînés en flipbook fondu, tourbillon (twirl) qui tourne avec la bouffée (la
//     brume ROULE), déformés par le bruit précalculé ; cœur blanc → cyan → bleu profond au bord, puis brume froide pâle
//     qui se dissipe ; quelques points de givre qui scintillent dans le cœur.
//   - CRISTAL (graine >= 100) : étoile Kenney qui tournoie et SCINTILLE (éclat qui pulse, chaque cristal à son rythme),
//     blanc au centre, cyan autour ; additive (n'assombrit jamais).
// Fusion PRÉMULTIPLIÉE « mixte » : les parties claires éclairent (rgb > alpha), la brume couvre légèrement.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

uniform float eclat = 1.0;
uniform float opacite = 0.85;    // couverture du souffle (0..1)
uniform float gros_coeur = 1.0;  // taille du cœur clair (GestionMagie.GROS_COEUR)
uniform float brume = 0.4;       // couverture de la brume en fin de vie
uniform vec4 c0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);    // cœur blanc
uniform vec4 c1 : source_color = vec4(0.89, 0.97, 1.0, 1.0);
uniform vec4 c2 : source_color = vec4(0.62, 0.89, 1.0, 1.0);  // cyan
uniform vec4 c3 : source_color = vec4(0.31, 0.65, 0.91, 1.0);
uniform vec4 c4 : source_color = vec4(0.16, 0.36, 0.75, 1.0); // bleu profond
uniform vec4 c5 : source_color = vec4(0.09, 0.16, 0.40, 1.0);
uniform vec4 c_brume : source_color = vec4(0.74, 0.85, 0.93, 1.0);
uniform sampler2D bruit : filter_linear, repeat_enable;
uniform sampler2D formes : filter_linear, repeat_disable;   // atlas 4×3 (Kenney Particle Pack, CC0)

varying vec2 v_px;
varying float v_rpx;
varying vec4 v_c;
varying vec2 v_ax;
varying float v_rl;
varying float v_cristal;
varying float v_proche_d;

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
	float rl = cristal > 0.5 ? rpx : clamp(la, rpx, rpx * 5.0);
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
	v_proche_d = cc.w;
	if (s < 0.000001 || INSTANCE_CUSTOM.y >= 1.0 || cc.w < 0.5) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);   // inactive ou contre l'œil : hors du volume de vue
	}
}

#include "res://shaders/magie_bruit.gdshaderinc"

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
	float cr = cos(v_c.z), sr = sin(v_c.z);
	vec2 ur = mat2(vec2(cr, sr), vec2(-sr, cr)) * qa;
	float r = length(qa);
	if (r > 1.0) {
		discard;
	}
	vec2 cell = floor(FRAGCOORD.xy / m);
	float tr = mh2(cell + vec2(floor(TIME * 12.0) * 7.31, g));
	if (v_cristal > 0.5) {
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
		// BOUFFÉE de souffle
		float tt = TIME + g;
		vec2 np = ur * (1.3 + age * 0.9) + vec2(g * 1.3, g * 0.7);
		vec2 w = texture(bruit, (np * 0.8 + vec2(0.0, tt * 1.3)) * 0.125).rg;
		float n = texture(bruit, (np * 1.2 + (w - 0.5) * 2.2 + vec2(tt * 0.7, -tt * 1.1 - age * 2.5)) * 0.125).b;
		vec2 dw = (w - 0.5) * (0.2 + 0.2 * age);
		vec2 up = clamp(ur * 0.5 * (1.0 + 0.1 * age) + 0.5 + dw, vec2(0.01), vec2(0.99));
		float fa = age * 4.5 + TIME * 1.2 + g * 3.0;
		float fi = floor(fa);
		float ff = smoothstep(0.15, 0.85, fract(fa));
		float ia = mod(fi, 4.0), ib = mod(fi + 1.0, 4.0);
		float vol = mix(texture(formes, (up + vec2(ia, 0.0)) / vec2(4.0, 3.0)).r, texture(formes, (up + vec2(ib, 0.0)) / vec2(4.0, 3.0)).r, ff);
		// tourbillon : la brume roule (twirl tourné avec la bouffée), surtout au milieu de sa vie
		float tw = texture(formes, (up + vec2(mod(floor(g * 5.0), 3.0), 1.0)) / vec2(4.0, 3.0)).r;
		float dens = mix(vol, max(vol * 0.8, tw * 1.1), 0.5 * smoothstep(0.08, 0.3, age) * (1.0 - smoothstep(0.6, 0.85, age))) * 1.6;
		if (age > 0.6) {
			float fin = texture(formes, (up + vec2(3.0, 1.0)) / vec2(4.0, 3.0)).r;
			dens = mix(dens, fin * 1.25, smoothstep(0.6, 0.9, age));
		}
		float corps = (dens - 0.08 + (n - 0.5) * (0.3 + 0.3 * age)) * 2.8;
		corps -= max(0.0, 0.45 - n) * 1.8 * age * age;
		corps -= (1.0 - smoothstep(0.02, 0.06, age)) * 0.12;
		corps *= smoothstep(0.0, 0.012, age) * (1.0 - smoothstep(0.75, 1.0, age));
		if (corps < 0.03) {
			discard;
		}
		if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
			discard;
		}
		// teinte : blanc au cœur des jeunes bouffées denses, cyan, bleu profond au bord et en vieillissant, puis brume
		float h = 0.46 - age * 0.45 + (dens - 0.55) * 0.75 + (0.35 - r) * 0.45 * gros_coeur + (n - 0.5) * 0.9 + (w.x - 0.5) * 0.3
			+ (fract(g * 0.618) - 0.5) * 0.25;
		// pas de voile blanc laiteux contre la main
		h = min(h, mix(0.55, 0.92, smoothstep(0.8, 1.2, dens)) + 0.15 * smoothstep(0.6, 2.5, v_proche_d));
		float k = clamp(corps, 0.0, 1.0);
		k = clamp(floor(k * 4.0 + tr) / 4.0, 0.0, 1.0);
		if (k <= 0.0) {
			discard;
		}
		float vieux = smoothstep(0.55, 0.95, age);
		vec3 c = rampe(h);
		float al = opacite * clamp(0.55 + h * 0.3, 0.25, 1.0);
		float lum = clamp(h - 0.7, 0.0, 1.0) * 0.4;
		// givre qui scintille dans le cœur (points brefs, chaque pixel du monde à son instant)
		float sp = step(0.985, mh2(cell * 1.37 + vec2(floor(TIME * 9.0) * 3.1, g * 11.0))) * step(0.45, dens) * (1.0 - vieux);
		c = mix(c, c0.rgb, sp);
		lum += sp * 0.8;
		// brume froide en fin de vie : pâle, légère, sans lumière
		c = mix(c, c_brume.rgb, vieux * 0.75);
		al = mix(al, brume, vieux);
		lum *= 1.0 - vieux;
		ALBEDO = c * (al + lum) * eclat * k;
		ALPHA = al * k;
	}
}
