// LIGNES DE VITESSE (« vitesse lumière ») autour du RAYON NOIR (scripts/magie/rayon_noir.gd, v3d) : une coque cylindrique légèrement plus large
// que la gaine (même tube que le faisceau), sur laquelle filent de fins traits de lumière dans le sens du tir. Aucun calcul CPU par trait :
// la coque est découpée en cellules angulaires, chaque cellule a son trait (vitesse, longueur, période, épaisseur tirés d'un hasard stable).
// Tête blanc-rose, traîne magenta qui s'éteint ; plus dense près de la main, la coque s'écarte légèrement vers le bout.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"

uniform vec3 bord : source_color = vec3(0.78, 0.13, 0.66);
uniform vec3 filet : source_color = vec3(1.0, 0.77, 0.95);
uniform float vie = 0.0;
uniform float longueur = 10.0;
uniform float rayon_max = 1.0;
uniform float rayon_min = 0.2;
uniform float ouverture = 7.0;
uniform float graine = 0.0;
uniform float coque = 3.0;       // rayon de la coque / rayon de la gaine
uniform float force = 1.7;
uniform float cellules = 40.0;

varying float v_s;
varying float v_u;
varying float v_th;

float rk() {
	return (1.0 - smoothstep(0.6, 1.0, vie)) * smoothstep(0.0, 0.08, vie);
}
float h11(float x) { return fract(sin(x * 127.1 + graine * 3.7) * 43758.5453); }

float rayon_en(float s) {
	return mix(rayon_min, rayon_max, smoothstep(0.0, ouverture, s)) * (1.0 + 1.8 * smoothstep(5.0, 40.0, s)) * rk();
}

void vertex() {
	v_u = UV.x;
	v_s = UV.x * longueur;
	v_th = UV.y;
	float u = UV.x;
	VERTEX.xy *= rayon_en(v_s) * coque * (1.0 + 0.3 * u);
	VERTEX.z = UV.x;
}

void fragment() {
	do {
		float k = rk();
		float tete = clamp(vie / 0.1, 0.0, 1.0);
		if (k < 0.03 || v_u < 0.004 || v_u > tete || magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
			break;
		}
		float th = v_th * cellules;
		float cell = floor(th);
		float loc = fract(th);
		float h1 = h11(cell), h2 = h11(cell + 17.0), h3 = h11(cell + 41.0), h4 = h11(cell + 73.0), h5 = h11(cell + 97.0);
		float dens = mix(1.0, 0.6, smoothstep(0.0, 0.85, v_u));
		float vit = 35.0 + 60.0 * h2;
		float per = 9.0 + 14.0 * h3;
		float lon = 3.0 + 7.0 * h4;
		float q = fract((v_s - TIME * vit) / per + h5);
		float lf = lon / per;
		float tail = (q - (1.0 - lf)) / lf;                     // 0 : bout de traîne, 1 : tête
		float on = step(0.0, tail) * step(h1, dens);
		float lig = 1.0 - smoothstep(0.0, 0.04 + 0.05 * h4, abs(loc - 0.5) - 0.04);
		float tete_l = smoothstep(0.82, 1.0, tail);
		float b = pow(clamp(tail, 0.0, 1.0), 2.2) * (1.0 - smoothstep(0.985, 1.0, q)) * on * lig;
		vec3 c = mix(bord * 1.5, filet * 2.2, tete_l);
		float bout = smoothstep(0.0, 0.5 / max(longueur, 0.5), v_u) * (1.0 - smoothstep(0.96, 1.0, v_u / max(tete, 0.01)));
		ALBEDO = c * force;
		ALPHA = clamp(b * bout * k * 0.95, 0.0, 1.0);
	} while (false);
}
