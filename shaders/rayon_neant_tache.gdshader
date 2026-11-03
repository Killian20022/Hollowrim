// TACHE D'OMBRE laissée au sol par le rayon du néant (scripts/magie/rayon_neant.gd) : flaque noire au bord déchiré, liseré
// violet qui s'éteint, quelques filets qui s'étirent. `vie` 0..1 (naissance rapide, longue décroissance).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
#include "res://shaders/magie_bruit.gdshaderinc"

uniform vec3 noir : source_color = vec3(0.012, 0.004, 0.025);
uniform vec3 bord : source_color = vec3(0.62, 0.22, 1.0);
uniform float vie = 0.0;
uniform float graine = 0.0;

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float n = mfbm2(p * 3.2 + graine);
	float pic = 0.5 + 0.5 * sin(ang * 7.0 + graine * 5.0) * mbruit(vec2(ang * 2.0, graine));
	float rayon = (0.42 + 0.5 * n * pic) * smoothstep(0.0, 0.12, vie);
	float d = r - rayon;
	float fond = 1.0 - smoothstep(0.55, 1.0, vie);
	if (d > 0.07) {
		discard;
	}
	float liseret = (1.0 - smoothstep(0.0, 0.07, abs(d + 0.025))) * (1.0 - smoothstep(0.0, 0.5, vie));
	vec3 c = noir;
	float a = d < 0.0 ? 0.88 : 0.0;
	if (liseret > 0.2) {
		c = bord * (1.2 + 0.8 * liseret);
		a = max(a, liseret);
	}
	// taches d'ombre sombres plus claires au centre : pas un disque plat
	a *= 0.8 + 0.2 * mbruit(p * 9.0 + graine);
	ALBEDO = c;
	ALPHA = clamp(a * fond, 0.0, 1.0);
}
