// ÉCLAIR D'ALLUMAGE du RAYON NOIR (scripts/magie/rayon_noir.gd, v4) : quad face à la caméra, centré devant la paume, qui ne dure
// qu'environ 0,2 s au déclenchement : flash blanc-rose au cœur, DEUX ONDES DE CHOC circulaires qui s'élargissent très vite depuis la
// paume (jusqu'aux bords de l'écran en vue joueur) et des rayons de lumière (style hyperespace) qui giclent du centre. ADDITIF : ne
// peut jamais assombrir. `k` : 0 → 1 pendant la durée de l'éclair ; `force` : intensité générale.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"

uniform vec3 bord : source_color = vec3(0.78, 0.13, 0.66);
uniform vec3 filet : source_color = vec3(1.0, 0.77, 0.95);
uniform float k = 0.0;
uniform float force = 1.0;
uniform float graine = 0.0;

float h11(float x) { return fract(sin(x * 127.1 + graine * 3.1) * 43758.5453); }

void fragment() {
	do {
		if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
			break;
		}
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p);
		if (r > 1.0 || k <= 0.0 || k >= 1.0) {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
			break;
		}
		float ang = atan(p.y, p.x);
		// flash central : très vif, s'éteint en ~un tiers de la durée
		float fl = (1.0 - smoothstep(0.0, 0.3, r * (0.9 + 1.6 * k))) * (1.0 - smoothstep(0.0, 0.35, k));
		// onde de choc 1 (rapide, fine, blanche) et onde 2 (plus lente, plus épaisse, magenta)
		float r1 = 1.0 - pow(1.0 - clamp(k * 1.25, 0.0, 1.0), 3.0);
		float r2 = 1.0 - pow(1.0 - clamp(k * 1.0 - 0.06, 0.0, 1.0), 2.4);
		float o1 = (1.0 - smoothstep(0.0, 0.012 + 0.022 * k, abs(r - r1 * 0.98))) * (1.0 - smoothstep(0.55, 1.0, k));
		float o2 = (1.0 - smoothstep(0.0, 0.02 + 0.04 * k, abs(r - r2 * 0.8))) * (1.0 - smoothstep(0.4, 1.0, k)) * 0.8;
		// rayons : 36 gerbes de longueurs différentes qui giclent du centre
		float n = 60.0;
		float cell = floor(fract(ang / TAU) * n);
		float fa = fract(ang / TAU * n) - 0.5;
		float lon = 0.35 + 0.65 * h11(cell);
		float tete = k * 1.5 * (0.7 + 0.5 * h11(cell + 7.0));
		float fin = tete - 0.35 * lon;
		float lat = abs(fa) * TAU * r / n;
		float ray = (1.0 - smoothstep(0.002, 0.007 + 0.004 * h11(cell + 11.0), lat)) * step(fin, r) * step(r, tete) * step(0.25, h11(cell + 3.0));
		ray *= 1.0 - smoothstep(0.5, 1.0, k);
		vec3 c = vec3(0.0);
		c += mix(bord, filet, 0.5) * 1.6 * fl;   // v5 : moins blanc
		c += mix(bord * 1.5, filet * 1.6, 0.35) * o1 * 1.3;
		c += bord * 1.6 * o2;
		c += mix(bord, filet, 0.4) * 1.6 * ray;
		float fondu = 1.0 - smoothstep(0.78, 1.0, r);
		ALBEDO = c * fondu * force * 0.7;   // v5b : pic du déclenchement atténué de 30 %
		ALPHA = 0.0;
	} while (false);
}
