// FLUX des jets canalisés en couche fine (scripts/magie/gestion_magie.gd, _flux_*) : ruban tourné vers la caméra le long
// de l'axe du jet (de la paume, -Z local, sur `longueur` m), rayon r0 → r1 ; le volume est un FEU (ou givre, ou ombre)
// PROCÉDURAL : bruit fractal défilant, en mètres (même grain de près comme de loin), seuillé en paliers de couleurs
// francs (cœur blanc → jaune → orange → rouge → bord sombre), bords rongés par le bruit. Chaque fragment est un pixel de
// la couche fine : détail au pixel près, sans texture. Les particules (flammèches, étincelles, poudre) passent par-dessus.
// Sommets : UV.x = position le long du jet (0..1), UV.y = côté (-1..1).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

instance uniform float longueur = 5.0;
instance uniform float r0 = 0.04;
instance uniform float r1 = 0.5;
instance uniform float force = 1.0;
instance uniform float graine = 0.0;
uniform int ecole = 0;           // 0 feu, 1 glace (souffle de givre), 2 ténèbres (drain : coule vers la main), 3 soin
uniform float vitesse = 7.0;     // défilement le long du jet (m/s)
uniform float grain = 1.0;       // échelle du bruit (plus grand = plus fin)
uniform float eclat = 1.35;
uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);   // cœur
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);
uniform vec4 c5 : source_color = vec4(0.35, 0.10, 0.11, 1.0);  // bord

varying float v_t;
varying float v_s;
varying float v_r;
varying float v_ap;   // distance À L'ÉCRAN depuis la paume (px) : le bruit suit la forme vue, raccourci compris
varying float v_cp;   // écart à l'axe à l'écran (px)

void vertex() {
	float t = UV.x;
	vec3 a = (MODEL_MATRIX * vec4(0.0, 0.0, -t * longueur, 1.0)).xyz;
	vec3 b = (MODEL_MATRIX * vec4(0.0, 0.0, -(t * longueur + 0.05), 1.0)).xyz;
	vec4 ca = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(a, 1.0));
	vec4 cb = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(b, 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float wa = max(ca.w, 0.0001);
	vec2 pa = (ca.xy / wa * 0.5 + 0.5) * vp;
	vec2 pb = (cb.xy / max(cb.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 d = pb - pa;
	if (dot(d, d) < 0.000001) {
		d = vec2(1.0, 0.0);
	}
	vec2 perp = normalize(vec2(-d.y, d.x));
	vec4 c0p = PROJECTION_MATRIX * (VIEW_MATRIX * vec4((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, 1.0));
	vec2 p0 = (c0p.xy / max(c0p.w, 0.0001) * 0.5 + 0.5) * vp;
	float r = mix(r0, r1, pow(t, 0.55));
	float rpx = r * abs(PROJECTION_MATRIX[1][1]) / wa * vp.y * 0.5;
	vec2 p = floor(pa) + 0.5 + perp * UV.y * (rpx + 1.0);
	POSITION = vec4((p / vp * 2.0 - 1.0) * ca.w, ca.z, ca.w);
	v_t = t;
	v_s = UV.y;
	v_r = r;
	v_ap = length(pa - p0);
	v_cp = UV.y * (rpx + 1.0);
}

#include "res://shaders/magie_bruit.gdshaderinc"

void fragment() {
	float sens = ecole == 2 ? -1.0 : 1.0;   // le drain remonte vers la main
	float tt = TIME + graine * 7.0;
	// grain À L'ÉCRAN, en pixels du monde (m = pixels fins par pixel du monde) : langues de ~18 px de long et ~5 px de
	// large, étirées dans le sens du flux ; détail secondaire 3 fois plus fin (les pixels fins)
	float m = max(magie_echelle, 1.0) * grain;
	float n = mfbm2(vec2(v_ap / (18.0 * m) - sens * tt * vitesse * 0.35, v_cp / (5.0 * m) + tt * 0.3 + graine));
	vec2 q2 = vec2(v_ap / (6.0 * m) - sens * tt * vitesse * 0.9, v_cp / (1.8 * m) - tt * 0.5 + graine * 3.0);
	float n2 = mbruit(q2);
	float s = abs(v_s);
	float profil = 1.0 - s * s;
	float debut = smoothstep(0.0, 0.03, v_t);
	float fin = 1.0 - smoothstep(0.8, 1.0, v_t + (n - 0.5) * 0.3);
	// intensité : forme du cône + bruit très contrasté (langues, trous, crêtes) ; refroidit en s'éloignant de la paume
	float i = profil * 0.95 + (n - 0.5) * 1.6 + (n2 - 0.5) * 0.6 - 0.12 - v_t * 0.22;
	i *= debut * fin * force;
	// cœur chauffé à blanc sur l'axe près de la paume
	i += (1.0 - s) * (1.0 - v_t) * (1.0 - v_t) * 0.45 * force;
	vec3 c;
	float al = 1.0;
	if (ecole == 2) {
		// ténèbres : cœur NOIR, bords violets lumineux, rehauts presque blancs sur les crêtes du bruit
		if (i < 0.24) {
			discard;
		}
		float bordure = s + (n - 0.5) * 0.5;
		c = bordure > 0.78 ? c1.rgb : (bordure > 0.62 ? c2.rgb : (bordure > 0.42 ? c3.rgb : (bordure > 0.22 ? c4.rgb : c5.rgb)));
		if (n2 > 0.74 && bordure > 0.5) {
			c = c0.rgb;
		}
	} else {
		if (i < 0.22) {
			discard;
		}
		c = i > 1.12 ? c0.rgb : (i > 0.92 ? c1.rgb : (i > 0.74 ? c2.rgb : (i > 0.56 ? c3.rgb : (i > 0.4 ? c4.rgb : c5.rgb))));
		if (ecole == 1) {
			// givre : brume plus ou moins dense (3 paliers d'opacité) et paillettes blanches
			al = i > 0.66 ? 1.0 : (i > 0.4 ? 0.66 : 0.33);
			if (n2 > 0.74) {
				c = c0.rgb;
				al = 1.0;
			}
		}
	}
	// occlusion en dernier : les pixels déjà jetés par le motif ne la paient pas
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	ALBEDO = c * eclat;
	ALPHA = al;
}
