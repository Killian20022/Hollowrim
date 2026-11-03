// BOUFFÉES de volume des noyaux d'école (scripts/magie/noyau_ecole.gd) : fumée, brume, filaments, braises et cœur.
// Chaque instance d'un MultiMesh est un carré orienté vers la caméra (côté CPU : la rotation d'une bouffée allongée suit
// sa vitesse à l'écran) ; la forme est calculée ici, en paliers francs (même parti que la flamme runique).
//   COLOR.a            : opacité de l'instance
//   INSTANCE_CUSTOM.x  : graine ; .y : ton 0..1 (0 = couleur sombre, 1 = couleur claire) ; .z : sorte
//   sorte 0 = nuage (fumée / brume, bord déchiré)   1 = filament (trait effilé aux deux bouts)
//   sorte 2 = cœur (halo en paliers)                3 = braise (petit carré qui scintille)
// `mode` 0 : mélange (fumée sombre) ; 1 : additif (lueur, braises).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
#include "res://shaders/magie_bruit.gdshaderinc"

uniform int mode = 0;
uniform float eclat = 1.0;
uniform float dechire = 0.75;   // 0 = disque lisse ; 1 = très déchiré
uniform vec4 c_a : source_color = vec4(0.03, 0.01, 0.06, 1.0);   // corps
uniform vec4 c_b : source_color = vec4(0.35, 0.10, 0.54, 1.0);   // bord sombre
uniform vec4 c_c : source_color = vec4(0.82, 0.54, 1.0, 1.0);    // bord clair
uniform vec4 c_d : source_color = vec4(1.0, 0.91, 1.0, 1.0);     // cœur

varying vec4 v_cus;

void vertex() {
	v_cus = INSTANCE_CUSTOM;
}

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	vec2 u = UV * 2.0 - 1.0;
	float seed = v_cus.x;
	float ton = v_cus.y;
	float genre = v_cus.z;
	float a = 0.0;
	vec3 c = c_a.rgb;
	if (genre < 0.5) {
		float n = mfbm2(u * 1.7 + vec2(seed * 7.3, TIME * 0.3 + seed * 3.0));
		float d = length(u) + (n - 0.5) * dechire;
		float f = 1.0 - smoothstep(0.5, 1.0, d);
		a = floor(f * 4.0 + 0.5) / 4.0;
		if (a < 0.1) {
			discard;
		}
		// 3 paliers : cœur du nuage (sombre), bord, liseré clair vers la lumière
		if (a > 0.9) {
			c = mix(c_a.rgb, c_b.rgb, ton * 0.45);
		} else if (a > 0.45) {
			c = mix(c_a.rgb, c_b.rgb, 0.35 + 0.65 * ton);
		} else {
			c = mix(c_b.rgb, c_c.rgb, ton * 0.55);
		}
	} else if (genre < 1.5) {
		// filament : fuseau effilé, déchiré par un bruit le long du trait
		float n = mbruit(vec2(u.x * 4.0 + seed * 9.0, TIME * 1.5 + seed));
		float larg = (1.0 - abs(u.x)) * (0.5 + 0.5 * n);
		float f = larg - abs(u.y) * 1.6;
		if (f < 0.04) {
			discard;
		}
		a = f > 0.3 ? 1.0 : 0.6;
		c = f > 0.3 ? mix(c_c.rgb, c_d.rgb, ton) : mix(c_b.rgb, c_c.rgb, ton);
	} else if (genre < 2.5) {
		float r = length(u);
		if (r > 1.0) {
			discard;
		}
		a = r < 0.3 ? 1.0 : (r < 0.55 ? 0.7 : (r < 0.8 ? 0.4 : 0.18));
		c = r < 0.3 ? c_d.rgb : (r < 0.55 ? c_c.rgb : (r < 0.8 ? c_b.rgb : c_b.rgb * 0.7));
	} else {
		if (max(abs(u.x), abs(u.y)) > 0.7) {
			discard;
		}
		a = 0.6 + 0.4 * sin(TIME * 17.0 + seed * 40.0);
		c = ton > 0.5 ? c_d.rgb : c_c.rgb;
	}
	float al = clamp(COLOR.a, 0.0, 1.0) * a;
	if (mode == 1) {
		ALBEDO = c * al * eclat;
		ALPHA = 0.001;
	} else {
		ALBEDO = c * al;
		ALPHA = al;
	}
}
