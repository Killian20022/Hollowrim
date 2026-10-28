// SOCLE « impact des sorts sur les corps » (scripts/magie/impact_corps.gd) : ARCS SUR LE CORPS (électricité, drain de vie).
// Maillage FIXE de ImpactCorps.MAX_SEGMENTS sous-segments (partagé par tous les foyers) ; chaque sommet lit son sous-segment
// dans la texture `segs` (écrite par le comportement quand la forme des arcs change, ~20 fois par seconde) et les POINTS
// DU CORPS dans `pts` / `nrm` (les textures des émetteurs, mises à jour à chaque image) : les arcs suivent les os à chaque
// image (marche, attaque, chute, ragdoll) sans aucun calcul par sommet côté CPU.
// Largeur en pixels ENTIERS à l'écran (halo + cœur), comme magie_trait.gdshader ; additif (prémultiplié, ALPHA = 0).
//
// Sommets : UV = (couche 0 halo / 1 cœur, côté -1 / +1), UV2 = (n° du sous-segment, bout 0 / 1).
// Sous-segment s = 2 texels RGBA flottants :
//   texel 2s   : (point a, point b, nœud k0, nœud k1)        points = index dans pts ; b < 0 : selon le genre
//   texel 2s+1 : (graine, largeur, opacité, genre + 16 × nœuds du lien)
// Genres : 0 rampe (lien court sur la surface), 1 sol (du point vers le sol), 2 brindille (pointe hors du corps),
//          3 main (filament du drain : du point vers point_main, en spirale), 4 saut (entre deux os, arc qui se cambre).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;
uniform sampler2D pts : filter_nearest, repeat_disable;
uniform sampler2D nrm : filter_nearest, repeat_disable;
uniform sampler2D segs : filter_nearest, repeat_disable;
uniform vec3 point_main = vec3(0.0, 1.4, 3.0);   // relatif à l'origine du foyer
uniform float sol_y = 0.0;
uniform float ecart = 0.04;                      // m au-dessus de la surface (au-delà de la marge d'occlusion de 3 cm)
uniform float ampl = 0.22;                       // zigzag (× longueur du lien)
uniform float spirale = 0.09;                    // m : rayon de la spirale des filaments (genre 3)
uniform vec4 halo : source_color = vec4(0.29, 0.23, 0.82, 1.0);
uniform vec4 coeur : source_color = vec4(0.94, 0.95, 1.0, 1.0);
uniform float largeur_halo = 3.0;
uniform float largeur_coeur = 1.0;
uniform float eclat = 1.6;
uniform bool sombre = false;                     // drain : halo sombre en mélange (filaments noirs bordés de violet)

varying float couche;
varying float alpha_v;

float lire1(sampler2D t, int k) {
	vec4 c = texelFetch(t, ivec2(k / 4, 0), 0);
	int r = k % 4;
	return r == 0 ? c.x : (r == 1 ? c.y : (r == 2 ? c.z : c.w));
}

vec3 lire3(sampler2D t, int i) {
	return vec3(lire1(t, i * 3), lire1(t, i * 3 + 1), lire1(t, i * 3 + 2));
}

vec3 h33(float g) {
	vec3 p = vec3(g * 12.9898, g * 78.233, g * 37.719);
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float h11(float g) {
	return fract(sin(g * 91.345) * 47453.5453);
}

// point du sous-segment au nœud k (sur N) d'un lien a → b
vec3 point_lien(int ia, int ib, float k, float nn, float graine, int genre) {
	vec3 pa = lire3(pts, ia);
	vec3 na = normalize(lire3(nrm, ia) + vec3(0.0, 0.00001, 0.0));
	vec3 a = pa + na * ecart;
	vec3 b;
	vec3 nb = na;
	if (genre == 1) {
		vec3 r = h33(graine * 1.7);
		b = vec3(pa.x + r.x * 0.32, sol_y + 0.015, pa.z + r.z * 0.32);
	} else if (genre == 2) {
		b = a + normalize(na + h33(graine * 2.3) * 0.9) * (0.06 + 0.09 * h11(graine));
	} else if (genre == 3) {
		b = point_main;
	} else {
		vec3 pb = lire3(pts, max(ib, 0));
		nb = normalize(lire3(nrm, max(ib, 0)) + vec3(0.0, 0.00001, 0.0));
		b = pb + nb * ecart;
	}
	float t = k / max(nn, 1.0);
	vec3 ab = b - a;
	float l = length(ab);
	vec3 p = a + ab * t;
	if (genre == 3) {
		// filament du drain : spirale qui s'enroule le long du trajet (rayon nul aux deux bouts) et ondule dans le temps
		vec3 ax = ab / max(l, 0.0001);
		vec3 x = normalize(cross(ax, abs(ax.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		vec3 y = cross(ax, x);
		float ang = TIME * (5.0 + 3.0 * h11(graine)) + graine * 6.2831 - t * (9.0 + 4.0 * h11(graine + 1.0));
		// rayon plus grand près du corps (le filament s'y enroule), qui se resserre vers la paume
		float r = spirale * (0.6 + 0.8 * h11(graine + 3.0)) * pow(sin(t * 3.14159), 0.7) * (1.6 - t) * (1.0 + 0.35 * sin(TIME * 3.0 + graine * 5.0));
		// près du corps : le filament se détache le long de la normale avant de partir vers la main
		p += (x * cos(ang) + y * sin(ang)) * r + na * 0.18 * sin(min(t * 6.0, 3.14159)) * (1.0 - t);
		return p;
	}
	// zigzag : décalage au hasard aux nœuds intérieurs (nul aux deux bouts : l'arc reste accroché aux points)
	float ki = floor(k + 0.5);
	if (ki > 0.5 && ki < nn - 0.5) {
		vec3 j = h33(graine * 13.1 + ki * 7.7);
		j -= ab * dot(j, ab) / max(l * l, 0.000001);
		p += j * ampl * l;
	}
	// l'arc se cambre hors du corps (rampe : peu ; saut entre deux os : franchement)
	float cambre = genre == 4 ? 0.35 : (genre == 0 ? 0.12 : 0.0);
	p += normalize(na + nb + vec3(0.0, 0.00001, 0.0)) * cambre * l * sin(t * 3.14159);
	return p;
}

void vertex() {
	int sid = int(UV2.x + 0.5);
	float bout = UV2.y;
	vec4 s0 = texelFetch(segs, ivec2(sid * 2, 0), 0);
	vec4 s1 = texelFetch(segs, ivec2(sid * 2 + 1, 0), 0);
	couche = UV.x;
	alpha_v = s1.z;
	if (s1.z <= 0.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);   // sous-segment inutilisé : hors du cadre
	} else {
		int genre = int(mod(s1.w, 16.0) + 0.5);
		float nn = floor(s1.w / 16.0 + 0.001);
		vec3 p0 = point_lien(int(s0.x + 0.5), int(s0.y + 0.5), s0.z, nn, s1.x, genre);
		vec3 p1 = point_lien(int(s0.x + 0.5), int(s0.y + 0.5), s0.w, nn, s1.x, genre);
		vec3 moi = bout > 0.5 ? p1 : p0;
		vec3 autre = bout > 0.5 ? p0 : p1;
		vec4 a = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(moi, 1.0));
		vec4 b = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(autre, 1.0));
		vec2 vp = VIEWPORT_SIZE;
		float wa = max(a.w, 0.0001);
		vec2 pa = (a.xy / wa * 0.5 + 0.5) * vp;
		vec2 pb = (b.xy / max(b.w, 0.0001) * 0.5 + 0.5) * vp;
		vec2 d = pb - pa;
		if (dot(d, d) < 0.000001) {
			d = vec2(1.0, 0.0);
		}
		vec2 perp = normalize(vec2(-d.y, d.x));
		float lw = s1.y;
		if (genre == 3) {
			// filament : fin près du corps, plus épais vers la main
			lw *= mix(0.6, 1.5, s0.z / max(nn, 1.0) * (1.0 - bout) + s0.w / max(nn, 1.0) * bout);
		}
		float w = floor(mix(largeur_halo, largeur_coeur, UV.x) * max(lw, 0.0) * max(magie_echelle * (UV.x > 0.5 ? 0.75 : 1.25), 1.0) + 0.5);
		vec2 p = floor(pa) + 0.5 + perp * UV.y * w * 0.5;
		POSITION = vec4((p / vp * 2.0 - 1.0) * a.w, a.z, a.w);
	}
}

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	vec4 c = couche > 0.5 ? coeur : halo;
	float a = ceil(alpha_v * c.a * 3.0 - 0.05) / 3.0;
	if (a <= 0.0) {
		discard;
	}
	if (sombre && couche < 0.5) {
		// halo sombre (filament noir bordé de violet : le cœur clair est fin)
		ALBEDO = c.rgb * a;
		ALPHA = a * 0.8;
	} else {
		ALBEDO = c.rgb * eclat * a;   // additif en prémultiplié (voir magie_part_add)
		ALPHA = 0.0;
	}
}
