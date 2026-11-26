// LIGNES DE VITESSE (« vitesse lumière ») autour du RAYON NOIR (scripts/magie/rayon_noir.gd, v3d) : une coque cylindrique légèrement plus large
// que la gaine (même tube que le faisceau), sur laquelle filent de fins traits de lumière dans le sens du tir. Aucun calcul CPU par trait :
// la coque est découpée en cellules angulaires, chaque cellule a son trait (vitesse, longueur, période, épaisseur tirés d'un hasard stable).
// Tête blanc-rose, traîne magenta qui s'éteint ; plus dense près de la main, la coque s'écarte légèrement vers le bout.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"

uniform vec3 bord : source_color = vec3(0.78, 0.13, 0.66);
uniform vec3 filet : source_color = vec3(1.0, 0.77, 0.95);
uniform float vie = 0.0;
uniform float longueur = 10.0;
uniform float rayon_max = 1.0;
uniform float rayon_min = 0.2;
uniform float ouverture = 7.0;
uniform float graine = 0.0;
uniform float coque = 4.0;       // rayon de la coque / rayon de la gaine
uniform float force = 2.6;       // v4 : plus lumineux en continu
uniform float cellules = 64.0;   // v4 : beaucoup plus de traits (40 avant)
uniform float elan = 0.0;        // v4 : 1 au déclenchement → 0 en ~0,5 s : traits plus nombreux, plus rapides, plus larges, plus vifs (effet warp)

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
	VERTEX.xy *= rayon_en(v_s) * coque * (1.0 + 0.3 * u) * (1.0 + 0.9 * elan * (1.0 - u));
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
		float th = v_th * (cellules + 40.0 * elan);
		float cell = floor(th);
		float loc = fract(th);
		float h1 = h11(cell), h2 = h11(cell + 17.0), h3 = h11(cell + 41.0), h4 = h11(cell + 73.0), h5 = h11(cell + 97.0);
		float dens = mix(0.6, 0.35, smoothstep(0.0, 0.85, v_u)) + 0.5 * elan;   // v5 : moins de traits pendant la tenue (v4 : 0,95 → 0,55), la gerbe du déclenchement reste
		float rare = step(0.88, h5);                  // quelques traits très longs et très rapides (hyperespace)
		float vit = mix(70.0 + 90.0 * h2, 220.0 + 80.0 * h2, rare) * (1.0 + 0.8 * elan);
		float per = mix(22.0 + 25.0 * h3, 70.0 + 30.0 * h3, rare);
		float lon = mix(10.0 + 16.0 * h4, 36.0 + 24.0 * h4, rare) * (1.0 + 0.6 * elan);
		float q = fract((v_s - TIME * vit) / per + h5);
		float lf = lon / per;
		float tail = (q - (1.0 - lf)) / lf;                     // 0 : bout de traîne, 1 : tête
		float on = step(0.0, tail) * step(h1, dens);
		float lig = 1.0 - smoothstep(0.0, 0.07 + 0.06 * h4, abs(loc - 0.5) - 0.07);
		float tete_l = smoothstep(0.7, 0.97, tail);
		float b = pow(clamp(tail, 0.0, 1.0), 1.8) * (1.0 - smoothstep(0.985, 1.0, q)) * on * lig;
		vec3 c = mix(bord * 1.0, mix(bord, filet, 0.35) * 1.4, tete_l);   // v5 : traits violets, têtes lavande (v4 : magenta 1,7 / blanc-rose 3,4)
		float bout = smoothstep(0.0, 0.5 / max(longueur, 0.5), v_u) * (1.0 - smoothstep(0.96, 1.0, v_u / max(tete, 0.01)));
		float pc = smoothstep(0.08, 0.4, length(VERTEX));              // v3f : pas de traits collés à l'œil
		float al_v = clamp(b * bout * k * 0.95 * pc * (1.0 + 0.6 * elan), 0.0, 1.0);
		// v5 : un peu de matière violette sous chaque trait (mélange, opacité 0,3 × trait) : violet aussi sur un ciel clair, pas blanc
		float am_v = al_v * 0.3;
		ALBEDO = bord * 0.8 * am_v + c * force * (1.0 + 0.68 * elan) * al_v;   // v5b : pic -30 % (2,4 -> 1,68)
		ALPHA = am_v;
	} while (false);
}
