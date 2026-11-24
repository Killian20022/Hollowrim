// HALO du RAYON NOIR (second passage du matériau de shaders/rayon_noir_faisceau.gdshader, scripts/magie/rayon_noir.gd) : lueur
// pourpre ADDITIVE, large et faible, autour du cœur noir (même calcul de distance à l'axe, volume englobant plus large). C'est elle
// qui garde le rayon lisible dans une crypte sombre ; elle ne touche jamais le cœur (x < 0,62) : le noir reste noir.
// Paliers francs (3) plutôt qu'un dégradé lisse, comme la fumée du faisceau ; aucun tramage.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
#include "res://shaders/magie_bruit.gdshaderinc"

uniform vec3 bord : source_color = vec3(0.50, 0.15, 0.86);
uniform float vie = 0.0;
uniform float longueur = 10.0;
uniform float rayon_max = 1.0;
uniform float rayon_min = 0.2;
uniform float ouverture = 14.0;
uniform float graine = 0.0;
uniform float onde = 0.0;
uniform float flux_vit = 26.0;
uniform float flux_pas = 1.7;
uniform float onde_lg = 2.6;
uniform float onde_vit = 2.2;
uniform float eclat = 1.0;
uniform float force_halo = 0.5;

const float GROS = 3.2;

varying float v_s;
varying float v_u;
varying vec3 v_a;
varying vec3 v_e;

float rk() {
	return (1.0 - smoothstep(0.6, 1.0, vie)) * smoothstep(0.0, 0.08, vie);
}

float vague(float s) {
	return sin((s - TIME * onde_vit) * TAU / onde_lg + graine);
}

float rayon_en(float s) {
	float ond = 1.0 + onde * vague(s) * smoothstep(0.0, 0.8, s);
	float evase = 1.0 + 0.12 * smoothstep(longueur - 0.25, longueur, s);
	return mix(rayon_min, rayon_max, smoothstep(0.0, ouverture, s)) * (1.0 + 1.8 * smoothstep(5.0, 40.0, s)) * rk() * ond * evase;
}

void vertex() {
	v_u = UV.x;
	v_s = UV.x * longueur;
	v_a = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_e = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	VERTEX.xy *= rayon_en(v_s) * GROS;
	VERTEX.z = UV.x;
}

void fragment() {
	do {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		ALBEDO = vec3(0.0);
		ALPHA = 1.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
	}
	float k = rk();
	float tete = clamp(vie / 0.1, 0.0, 1.0);
	vec3 D = -normalize(VIEW);
	vec3 ax = normalize(v_e);
	vec3 w0 = -v_a;
	float b = dot(D, ax);
	float dd = dot(D, w0);
	float ee = dot(ax, w0);
	float den = 1.0 - b * b;
	float tc = v_s;
	float rho;
	if (den > 0.0004) {
		tc = (ee - b * dd) / den;
		float sc = (b * ee - dd) / den;
		rho = length(D * sc - (v_a + ax * tc));
	} else {
		rho = length(v_a - ax * dot(v_a, ax));
	}
	float u_c = clamp(tc / longueur, 0.0, 1.0);
	if (k < 0.03 || u_c > tete || v_u < 0.003) {
		ALBEDO = vec3(0.0);
		ALPHA = 1.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
	}
	float rr = max(rayon_en(clamp(tc, 0.0, longueur)), 0.001);
	float x = rho / rr;
	if (x > GROS || x < 0.62) {
		ALBEDO = vec3(0.0);
		ALPHA = 1.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
	}
	float ph = fract((tc - TIME * flux_vit) / flux_pas + graine);
	// v3c : renflements ARRONDIS et irréguliers (deux ondes de longueurs différentes), de faible amplitude, qui glissent vers la cible
	float w1 = 0.5 + 0.5 * sin((tc - TIME * 9.0) * TAU / 3.1 + graine);
	float w2 = 0.5 + 0.5 * sin((tc - TIME * 5.5) * TAU / 5.3 + graine * 2.0);
	float pv = smoothstep(0.1, 0.9, w1 * (0.55 + 0.45 * w2));
	float n = mbruit(vec2(tc * 1.3 - TIME * 14.0, graine));
	float f = (1.0 - smoothstep(0.62, GROS * (0.88 + 0.09 * pv), x)) * (0.5 + 0.4 * pv + 0.15 * n);
	f = floor(f * 3.0 + 0.35) / 3.0;
	float bouts = smoothstep(0.0, 0.06, u_c) * (1.0 - smoothstep(0.97, 1.0, u_c)) * smoothstep(0.0, 0.05, tete - u_c);
	float axial = smoothstep(0.7, 0.97, abs(b));
	float vis = mix(1.0, smoothstep(0.08, 0.4, length(VERTEX)), axial);   // v3f : presque rien sur le premier mètre vu dans l'axe
	ALBEDO = bord * f * force_halo * eclat * k * bouts * vis * (1.0 + 0.9 * axial);
	ALPHA = 1.0;
} while (false);
}
