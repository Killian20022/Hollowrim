// v4 : plus de flaque NOIRE (pâté) : la tache est ADDITIVE, une braise violette translucide (jamais plus sombre que le mur) avec ses veines
//   et son liseré ; elle ronge toujours la surface (bord qui bouillonne) mais en lumière.
// TACHE D'OMBRE du RAYON NOIR (scripts/magie/rayon_noir.gd) : dérivée de la tache du rayon du néant (rayon_neant_tache.gdshader),
// pour un rayon TENU : la flaque noire RONGE la surface (bord déchiré qui bouillonne et s'étend : `etendue` 0..1), liseré pourpre
// qui pulse au rythme de l'onde du rayon, veines violettes qui rampent du centre vers le bord ; laissée derrière (balayage), elle
// s'éteint (`fondu` 1 → 0) : liseré d'abord, puis le noir. Paliers francs, aucun tramage.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
#include "res://shaders/magie_bruit.gdshaderinc"

uniform vec3 noir : source_color = vec3(0.010, 0.003, 0.02);
uniform vec3 bord : source_color = vec3(0.50, 0.15, 0.86);
uniform vec3 veine : source_color = vec3(0.72, 0.38, 1.0);
uniform float etendue = 0.0;   // 0..1 : la tache naît puis s'étend
uniform float fondu = 1.0;     // 1 tenue, → 0 laissée qui s'efface
uniform float graine = 0.0;

void fragment() {
	do {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
	}
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float t = TIME * 0.35;
	float n = mfbm2(p * 3.0 + vec2(graine, t));
	float pic = 0.5 + 0.5 * sin(ang * 7.0 + graine * 5.0 + t * 1.5) * mbruit(vec2(ang * 2.0, graine + t * 0.5));
	float rayon = (0.25 + 0.55 * smoothstep(0.0, 1.0, etendue)) * (0.75 + 0.45 * n * pic + 0.08 * sin(TIME * 2.4));
	float d = r - rayon;
	if (d > 0.16) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
	}
	float vif = smoothstep(0.0, 0.5, fondu);   // le liseré s'éteint d'abord
	float liseret = (1.0 - smoothstep(0.0, 0.06, abs(d + 0.022))) * vif * (0.8 + 0.2 * sin(TIME * 5.0 + ang * 3.0));
	vec3 c = bord * 0.28;
	float a = d < 0.0 ? 0.5 : 0.0;
	// lueur pourpre autour (paliers) : la surface rongée luit faiblement autour de la flaque
	if (d >= 0.0) {
		float g = 1.0 - smoothstep(0.0, 0.16, d);
		c = bord * 0.9;
		a = floor(g * 3.0) / 3.0 * 0.4 * vif;
	}
	// veines : filets violets qui rampent vers le bord (bruit radial qui défile vers l'extérieur)
	float v = mbruit(vec2(ang * 5.0 + graine, r * 6.0 - TIME * 1.6));
	float ve = (1.0 - smoothstep(0.0, 0.09, abs(v - 0.5))) * smoothstep(0.15, 0.6, r / max(rayon, 0.01)) * step(d, -0.03) * vif;
	if (ve > 0.35) {
		c = veine * 1.8;
	}
	if (liseret > 0.25) {
		c = bord * (2.0 + 1.2 * liseret);
		a = max(a, liseret);
	}
	a *= 0.82 + 0.18 * mbruit(p * 9.0 + graine);
	ALBEDO = c * clamp(a * smoothstep(0.0, 0.35, fondu), 0.0, 1.0);   // additif prémultiplié (couche fine : pas d'opacité)
	ALPHA = 0.0;
} while (false);
}
