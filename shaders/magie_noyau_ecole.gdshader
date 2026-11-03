// NOYAUX des écoles tenus en main (scripts/magie/noyau_ecole.gd), pendants de la flamme runique (magie_aura forme 2) :
// carré face caméra posé au centre de l'énergie tenue, motif calculé AU PIXEL du monde en paliers francs.
//   ecole 1 GLACE       : halo givré derrière le noyau de cristaux 3D (qui, eux, sont des meshes) + paillettes qui montent
//   ecole 2 ÉLECTRICITÉ : BOULE D'ARCS : cœur blanc, plasma en filaments, arcs qui jaillissent et se re-tirent 9 à 14 fois /s
//                         (instables), arcs courbes qui longent la sphère
//   ecole 3 TÉNÈBRES    : SPHÈRE DE VOLUTES : corps noir aux bandes violettes qui tournent, liseré violet, volutes sombres
//                         qui s'enroulent et s'échappent, poussières violettes
// `charge` (0..1) : plus dense, plus vive, un peu plus large. Mélange alpha, sans éclairage : Compatibility / WebGL2.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

instance uniform float rayon = 0.1;
instance uniform float force = 1.0;
instance uniform float graine = 0.0;
instance uniform float charge = 0.0;
instance uniform float avance = 0.0;   // m vers l'œil (négatif : derrière les cristaux)
uniform int ecole = 2;
uniform float eclat = 1.3;
uniform vec4 c0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c1 : source_color = vec4(0.94, 0.95, 1.0, 1.0);
uniform vec4 c2 : source_color = vec4(0.70, 0.75, 1.0, 1.0);
uniform vec4 c3 : source_color = vec4(0.48, 0.48, 0.94, 1.0);
uniform vec4 c4 : source_color = vec4(0.29, 0.23, 0.82, 1.0);
uniform vec4 c5 : source_color = vec4(0.16, 0.10, 0.42, 1.0);

varying vec2 v_px;
varying float v_rpx;
varying vec2 v_haut;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 vers_oeil = normalize(INV_VIEW_MATRIX[3].xyz - centre);
	centre += vers_oeil * avance;
	vec4 cc = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
	vec4 ch = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre + vec3(0.0, 0.05, 0.0), 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float w = max(cc.w, 0.0001);
	vec2 pc = (cc.xy / w * 0.5 + 0.5) * vp;
	vec2 ph = (ch.xy / max(ch.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 hd = ph - pc;
	v_haut = dot(hd, hd) > 0.0001 ? normalize(hd) : vec2(0.0, 1.0);
	float rpx = rayon * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	vec2 p = floor(pc) + 0.5 + VERTEX.xy * 2.0 * (rpx + 1.0);
	POSITION = vec4((p / vp * 2.0 - 1.0) * cc.w, cc.z, cc.w);
	v_px = VERTEX.xy * 2.0 * (rpx + 1.0);
	v_rpx = rpx;
}

#include "res://shaders/magie_bruit.gdshaderinc"

vec3 palier(float i) {
	return i > 1.15 ? c0.rgb : (i > 0.95 ? c1.rgb : (i > 0.78 ? c2.rgb : (i > 0.6 ? c3.rgb : (i > 0.45 ? c4.rgb : c5.rgb))));
}

// distance signée au trait d'un arc : 1 sur l'axe, 0 à la demi-largeur `w`
float trait(float dd, float w) {
	return clamp(1.0 - dd / w, 0.0, 1.0);
}

void fragment() {
	float m = max(magie_echelle, 1.0);
	vec2 hx = vec2(v_haut.y, -v_haut.x);
	vec2 q = vec2(dot(v_px, hx), dot(v_px, v_haut)) / m;
	float rp = max(v_rpx / m, 1.0);
	vec2 u = q / rp;
	float tt = TIME + graine * 11.0;
	float ch = clamp(charge, 0.0, 1.0);
	float carre = max(abs(u.x), abs(u.y));
	float wpx = 1.15 / rp + 0.004;   // épaisseur d'un trait : ~1 pixel du monde
	float i = 0.0;
	float al = 1.0;
	vec3 c = vec3(0.0);
	if (ecole == 1) {
		// GLACE : halo givré (2 paliers, demi-transparent) + paillettes qui montent
		float d = length(vec2(u.x, u.y * 0.85));
		float hal = 1.0 - smoothstep(0.08, 0.6 + 0.05 * ch, d);
		hal *= 0.85 + 0.15 * sin(tt * 2.1 + graine);
		float f = 0.0;
		vec2 qb = vec2(q.x + sin(q.y * 0.3 + tt * 2.0) * 1.5, q.y - tt * rp * 0.5);
		vec2 cb = floor(qb / 1.6);
		float hb = mh2(cb + floor(graine * 13.0));
		float zone = (1.0 - smoothstep(0.35, 0.85, length(u)));
		float spark = step(1.0 - 0.009 * (1.0 + ch) * zone * force, hb);
		if (spark > 0.5) {
			c = mh2(cb + 3.1) > 0.55 ? c0.rgb : c1.rgb;
			al = 1.0;
		} else if (hal > 0.5) {
			c = c4.rgb;
			al = 0.26 * force;
		} else if (hal > 0.12) {
			c = c5.rgb;
			al = 0.2 * force;
		} else {
			discard;
		}
	} else if (ecole == 2) {
		// ÉLECTRICITÉ : boule d'arcs
		float R = 0.34 * (1.0 + 0.1 * ch);
		float d = length(u);
		float ang = atan(u.y, u.x);
		// corps : plasma en filaments (crêtes d'un bruit qui bouge vite)
		float n1 = mfbm2(u * 6.0 + vec2(tt * 1.7, -tt * 1.2) + graine);
		float n2 = mfbm2(u * 11.0 - vec2(tt * 2.3, tt * 0.8) + graine * 3.0);
		float crete = 1.0 - abs(2.0 * n1 - 1.0);
		float plasma = smoothstep(0.945, 0.98, crete) * 0.6 + smoothstep(0.965, 0.99, 1.0 - abs(2.0 * n2 - 1.0)) * 0.4;
		float dedans = 1.0 - smoothstep(R * 0.82, R, d);
		float corps = dedans * (0.3 + 0.12 * n1 + plasma + 0.08 * ch);
		float noy = (1.0 - smoothstep(0.0, 0.08 + 0.03 * ch, d));
		float body = max(corps, noy * 1.3);
		// arcs droits qui jaillissent du centre, zigzag fin ; chacun se re-tire à son rythme (instables)
		float arcs = 0.0;
		int na = 7 + int(ch * 3.0);
		for (int k = 0; k < 10; k++) {
			if (k >= na) {
				break;
			}
			float fk = float(k);
			float tk = floor(tt * (8.0 + fk * 1.3) + fk * 3.7);
			float a0 = 6.2832 * mh2(vec2(fk * 1.7, tk));
			float lg = R * (1.35 + 1.5 * mh2(vec2(fk + 9.0, tk)));
			vec2 dir = vec2(cos(a0), sin(a0));
			float al_ = dot(u, dir);
			if (al_ > 0.0 && al_ < lg) {
				float t = al_ / lg;
				float pp = dot(u, vec2(-dir.y, dir.x));
				float jag = (mbruit(vec2(al_ * 26.0 + fk * 5.0, tk * 1.7)) - 0.5) * 0.7 * lg * (0.25 + 0.75 * sqrt(t));
				jag += (mbruit(vec2(al_ * 9.0 + fk * 2.0, tk * 0.7 + 4.0)) - 0.5) * 0.5 * lg * t;
				float v = trait(abs(pp - jag), wpx * (1.7 - 0.9 * t));
				// l'arc s'éteint avant sa pointe, scintille
				v *= (1.0 - 0.6 * t) * step(0.18, mh2(vec2(floor(al_ * 40.0) + fk, tk + 5.0)) + (1.0 - t) * 0.5);
				arcs = max(arcs, v * 1.25);
			}
		}
		// arcs courbes qui longent la sphère (un arc de cercle déchiré, 3 à la fois)
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float tk = floor(tt * (5.0 + fk * 1.7) + fk * 5.3);
			float a0 = 6.2832 * mh2(vec2(fk * 3.1 + 1.0, tk));
			float span = 0.9 + 1.6 * mh2(vec2(fk + 4.0, tk));
			float da = mod(ang - a0 + 6.2832, 6.2832);
			if (da < span) {
				float rr = R * (1.02 + 0.08 * fk) + (mbruit(vec2(da * 12.0 + fk * 3.0, tk * 1.3)) - 0.5) * 0.09;
				float v = trait(abs(d - rr), wpx * 1.4) * (1.0 - 0.5 * da / span);
				arcs = max(arcs, v * 1.1);
			}
		}
		// contour de la sphère, discret
		float bord = trait(abs(d - R * 1.0), wpx * 0.9) * 0.55 * (0.5 + 0.5 * mbruit(vec2(ang * 5.0 + tt * 3.0, 1.0)));
		i = max(max(body, arcs * force * 1.1), bord) * force * (0.94 + 0.08 * sin(tt * 31.0) * sin(tt * 13.0));
		i *= 1.0 - smoothstep(0.85, 0.99, carre);
		// étincelles isolées autour
		vec2 cs = floor(q / 1.6 + vec2(0.0, floor(tt * 14.0)));
		float hs = mh2(cs + floor(graine * 7.0));
		float zs = (1.0 - smoothstep(0.35, 0.9, d)) * smoothstep(R * 0.9, R * 1.3, d);
		if (i < 0.2) {
			if (hs > 1.0 - 0.004 * zs * force * (1.0 + ch)) {
				c = c1.rgb;
				al = 1.0;
			} else {
				discard;
			}
		} else {
			c = palier(i);
			al = i > 0.45 ? 1.0 : 0.55;
		}
	} else {
		// TÉNÈBRES : sphère de volutes sombres
		float d = length(u);
		float ang = atan(u.y, u.x);
		// silhouette irrégulière : la sphère respire et se déforme
		float R = 0.33 * (1.0 + 0.1 * ch) * (1.0 + 0.09 * (mbruit(vec2(cos(ang), sin(ang)) * 1.6 + vec2(tt * 0.7, graine)) - 0.5) * 2.0);
		float sw = d / R;
		float a2 = ang + 2.3 * sw - tt * 0.8;
		vec2 pc2 = vec2(cos(a2), sin(a2));
		if (d < R) {
			// corps : noir, bandes violettes qui tournent (spirale gauchie par un bruit), relief de sphère
			float z = sqrt(max(1.0 - sw * sw, 0.0));
			float ph = ang * 3.0 + sw * 7.0 - tt * 1.6 + (mbruit(pc2 * 2.4 + vec2(sw * 3.0, tt * 0.4)) - 0.5) * 5.0;
			float band = 0.5 + 0.5 * sin(ph);
			float bn = mfbm2(pc2 * 3.0 + vec2(sw * 4.0 - tt * 0.9, graine));
			float lum = band * (0.45 + 0.55 * bn) * (0.35 + 0.65 * z);
			float rim = pow(1.0 - z, 2.4);
			c = c5.rgb;
			if (rim > 0.66) {
				c = c3.rgb;
			} else if (lum > 0.62 + 0.08 * (1.0 - ch) - 0.1 * ch) {
				c = c3.rgb;
			} else if (lum > 0.4) {
				c = c4.rgb;
			}
			// point d'ombre profond au centre : le vide
			if (sw < 0.22 && lum < 0.45) {
				c = vec3(0.025, 0.01, 0.05);
			}
			al = 1.0;
		} else {
			// volutes qui s'échappent : crêtes d'un bruit polaire enroulé, qui s'éloigne ; remplissage sombre, liseré violet
			float n = mfbm2(pc2 * 2.0 + vec2(sw * 3.2 - tt * 0.9, graine * 2.0));
			float crete = 1.0 - abs(2.0 * n - 1.0);
			float lim = 0.66 - 0.05 * ch;
			float zone = 1.0 - smoothstep(1.0, 1.75 + 0.15 * ch, sw);
			float v = (crete - (lim + (1.0 - zone) * (1.0 - lim))) / (1.0 - lim) + 0.02 * (force - 1.0);
			vec2 cs = floor(q / 1.6 + vec2(0.0, floor(tt * 6.0)));
			float hs = mh2(cs + floor(graine * 7.0));
			if (v > 0.0 && v < 0.035) {
				c = c3.rgb;
				al = 0.95;
			} else if (v >= 0.035) {
				c = v > 0.6 ? c5.rgb : vec3(0.06, 0.02, 0.12);
				al = 0.92;
			} else if (hs > 1.0 - 0.014 * zone * force * (1.0 + ch) && sw > 1.15) {
				c = mh2(cs + 3.1) > 0.5 ? c2.rgb : c3.rgb;
				al = 1.0;
			} else {
				discard;
			}
		}
	}
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.08);
	ALBEDO = c * eclat;
	ALPHA = al;
}
