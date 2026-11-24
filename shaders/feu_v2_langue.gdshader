// FEU v2 : LANGUES de flamme en rubans fins (comme les arcs de la foudre v2 : formes structurées, largeur ENTIÈRE en pixels
// écran, paliers de couleur nets). Le chemin de chaque ruban est calculé ICI (aucune mise à jour CPU) ; le maillage ne porte que
// UV = (t le long du ruban, côté -1/+1) et COLOR = (graine, graine2, 1, 1).
//   mode 0 : flammèches qui S'ENROULENT autour d'une orbe (rayon local 1) et filent vers la queue (axe `axe`)
//   mode 1 : langues qui LÈCHENT une surface (le +Y local est la normale) : partent du sol, s'écartent et se courbent
//   mode 2 : éclats radiaux d'une EXPLOSION (age 0..1), courbés vers le haut
//   mode 3 : filets d'accompagnement d'un JET (le jet part vers -Z local, longueur `longueur`, évasement `evase`)
// Additif prémultiplié, sans texture ; occlusion de la couche fine (magie_occ).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;
uniform int mode = 0;
uniform float largeur_px = 3.0;
uniform float force = 1.5;
uniform vec3 axe = vec3(0.0, 1.0, 0.0);
uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);
instance uniform float eclat = 1.0;
instance uniform float age = 0.0;        // explosion 0..1
instance uniform float etire = 0.0;      // queue de l'orbe (0 = flamme assise, 1 = en vol)
instance uniform float longueur = 8.0;   // jet : longueur en m (repère local)
instance uniform float evase = 0.5;      // jet : demi-largeur au bout (repère local)

varying float v_t;
varying float v_graine;
varying float v_cote;

vec3 perp_base(vec3 a, out vec3 u, out vec3 v) {
	vec3 r = abs(a.y) < 0.92 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	u = normalize(cross(a, r));
	v = cross(a, u);
	return a;
}

float h1(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

vec3 chemin(float t, float s, float s2) {
	vec3 u; vec3 v;
	if (mode == 0) {
		vec3 ax = perp_base(normalize(axe), u, v);
		float z0 = (s2 - 0.5) * 1.5;
		float rr0 = sqrt(max(1.0 - z0 * z0, 0.04)) * 0.97;
		float a = s * 6.2832 + t * (4.5 + 3.0 * s2) + TIME * (2.2 + 3.0 * s2) * (s > 0.5 ? 1.0 : -0.8);
		float rr = rr0 * (1.04 - 0.55 * t) * (1.0 + 0.1 * sin(t * 9.0 + TIME * 4.0 + s * 20.0));
		float z = z0 * 0.8 + t * (0.45 + etire * 1.5 + 0.5 * s2);
		return ax * z + (u * cos(a) + v * sin(a)) * rr;
	} else if (mode == 1) {
		float a = s * 6.2832;
		float r0 = 0.1 + 0.55 * s2;
		float pul = 0.6 + 0.4 * sin(TIME * (8.0 + 6.0 * s2) + s * 40.0);
		float hh = (0.5 + 0.8 * s2) * pul;
		vec3 d = vec3(cos(a), 0.0, sin(a));
		vec3 lat = vec3(-d.z, 0.0, d.x);
		float w = sin(t * 7.0 + TIME * 9.0 + s * 30.0) * 0.12 * t;
		return d * (r0 + t * 0.55) + lat * w + vec3(0.0, 1.0, 0.0) * (hh * sin(t * 1.5707) * (0.15 + 0.85 * t) + 0.02);
	} else if (mode == 2) {
		float e = 1.0 - pow(1.0 - clamp(age, 0.0, 1.0), 2.4);
		float ys = 0.15 + 0.85 * s2;
		float a = s * 6.2832;
		vec3 d = normalize(vec3(cos(a) * (1.0 - ys * 0.5), ys, sin(a) * (1.0 - ys * 0.5)));
		float rb = (0.3 + 1.5 * e) * (0.7 + 0.5 * h1(s * 91.0));
		float ra = rb * (0.25 + 0.55 * age);
		float r = mix(ra, rb, t);
		return d * r + vec3(0.0, 1.0, 0.0) * (age * 0.9 * t * t + 0.0) + vec3(-d.z, 0.0, d.x) * sin(t * 5.0 + s * 20.0) * 0.06 * t;
	}
	// mode 3 : filets de jet (vers -Z)
	float sp = pow(t, 0.8) * evase;
	float a = s * 6.2832 + TIME * (2.0 + 3.0 * s2) * (s > 0.5 ? 1.0 : -1.0) + t * 4.0;
	float rr = sp * (0.25 + 0.75 * s2) * (1.0 + 0.2 * sin(t * 11.0 - TIME * 10.0 + s * 25.0));
	return vec3(cos(a) * rr, sin(a) * rr + t * t * 0.18 * evase, -t * longueur);
}

void vertex() {
	float t = UV.x;
	float s = COLOR.r;
	float s2 = COLOR.g;
	vec3 p0 = chemin(t, s, s2);
	vec3 p1 = chemin(min(t + 0.03, 1.0), s, s2);
	if (t > 0.97) {
		p1 = p0;
		p0 = chemin(t - 0.03, s, s2);
	}
	vec4 a = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(p0, 1.0));
	vec4 b = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(p1, 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float wa = max(a.w, 0.0001);
	vec2 pa = (a.xy / wa * 0.5 + 0.5) * vp;
	vec2 pb = (b.xy / max(b.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 d = pb - pa;
	if (dot(d, d) < 0.000001) {
		d = vec2(1.0, 0.0);
	}
	vec2 perp = normalize(vec2(-d.y, d.x));
	float loin = clamp(5.0 / wa, 0.5, 1.0);
	float prof = mode == 2 ? (1.0 - 0.7 * (1.0 - t)) : (1.0 - pow(t, 0.9));
	if (mode == 3) {
		prof = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.7, 1.0, t));
	}
	float wpx = largeur_px * loin * (0.35 + 0.65 * prof) * (0.7 + 0.6 * s2);
	float w = max(floor(wpx * max(magie_echelle, 1.0) + 0.5), 1.0);
	vec2 p = floor(pa) + 0.5 + perp * UV.y * w * 0.5;
	POSITION = vec4((p / vp * 2.0 - 1.0) * a.w, a.z, a.w);
	v_t = t;
	v_graine = s;
	v_cote = UV.y;
}

void fragment() {
	bool cache = magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX);
	float t = v_t;
	float heat;
	float al;
	if (mode == 0) {
		heat = 0.8 - 0.72 * t + 0.1 * sin(TIME * 9.0 + v_graine * 30.0);
		al = 1.0 - 0.55 * t;
	} else if (mode == 1) {
		heat = 0.85 - 0.75 * t + 0.08 * sin(TIME * 12.0 + v_graine * 40.0);
		al = 1.0 - 0.4 * t;
	} else if (mode == 2) {
		heat = 1.0 - 0.9 * clamp(age * 1.1 + (1.0 - t) * 0.25, 0.0, 1.0);
		al = clamp(1.4 - 1.5 * age, 0.0, 1.0);
	} else {
		heat = 0.74 - 0.6 * t + 0.1 * sin(TIME * 14.0 + v_graine * 33.0 - t * 12.0);
		al = 0.85 * (1.0 - 0.45 * t);
	}
	// filament : les rubans de jet et de léchage se découpent en tirets qui défilent (langues, pas des fils continus)
	if (mode == 1 || mode == 3) {
		float dash = fract(t * (mode == 3 ? 2.2 : 1.6) - TIME * (mode == 3 ? 2.8 : 1.3) + v_graine * 7.0);
		al *= dash < (mode == 3 ? 0.5 : 0.3) ? 0.0 : 1.0;
	}
	// bord du ruban un cran plus rouge que le milieu (relief du filet)
	heat -= 0.18 * smoothstep(0.55, 1.0, abs(v_cote));
	vec3 c = heat > 0.82 ? c0.rgb : (heat > 0.62 ? c1.rgb : (heat > 0.42 ? c2.rgb : (heat > 0.24 ? c3.rgb : c4.rgb)));
	float a = ceil(clamp(al * eclat, 0.0, 1.5) * 4.0 - 0.1) / 4.0;
	ALBEDO = (cache || a <= 0.0) ? vec3(0.0) : c * force * a;
	ALPHA = 0.0;
}
