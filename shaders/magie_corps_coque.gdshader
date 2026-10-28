// SOCLE « impact des sorts sur les corps » (scripts/magie/impact_corps.gd) : COQUE de flammes qui ÉPOUSE la silhouette.
// Copie skinnée des maillages du corps (même maillage, même peau, même squelette : elle suit animation et ragdoll),
// gonflée de quelques centimètres le long des normales et dessinée dans la couche fine (CoucheMagie.CALQUE), avec
// l'occlusion par la profondeur du monde : le corps cache la coque de dos, il reste lisible au centre, et les flammes
// débordent de son contour. Flammes procédurales en cases (bruit 3D du monde qui MONTE), plus denses :
//   - du côté tourné vers le jet et près du point touché (mc_feu, mc_dir) ;
//   - sur le BORD de la silhouette vue de l'œil (le centre du corps reste visible à travers).
// Un seul matériau partagé ; l'état passe par les paramètres d'instance (mêmes canaux que magie_corps.gdshader).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

instance uniform vec4 mc_feu = vec4(0.0);
instance uniform vec4 mc_dir = vec4(0.0, 0.0, -1.0, 0.0);
instance uniform vec4 mc_mesh = vec4(135.0, 0.006, 64.0, 0.0);
instance uniform vec4 mc_autre = vec4(0.0);

uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);   // #fffbe8
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);   // #fff0a8
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);  // #fcb53a
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);  // #ec6a1f
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);  // #b3341f
uniform vec4 c5 : source_color = vec4(0.35, 0.10, 0.11, 1.0);  // #5a1a1c
uniform float eclat = 1.3;
uniform float gonfle_max = 0.055;   // m : épaisseur de la coque au plus chaud
uniform float rayon_chaud = 0.55;   // m
uniform float rayon_coeur = 0.17;   // m : tache blanc-jaune au point touché
uniform float cases = 48.0;         // cases du motif par mètre (pixels francs)
uniform float montee = 1.0;         // vitesse de montée du motif
uniform float entraine = 0.45;      // m : langues entraînées dans le sens du jet sur le bord de la silhouette
uniform float ecarte_bord = 0.2;   // m : … et écartées du corps
uniform float hauteur = 0.42;       // m : les langues soulèvent la coque jusqu'à cette hauteur
uniform bool plein = false;         // mise au point : coque pleine (vérifie qu'elle suit le corps)

varying vec3 p_monde;
varying vec3 n_monde;
varying float chaleur_v;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float bruit(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float chaleur_en(vec3 p, vec3 n) {
	vec3 d = normalize(mc_dir.xyz + vec3(0.0, 0.00001, 0.0));
	float face = clamp(-dot(n, d) * 0.6 + 0.4, 0.0, 1.0);
	float di = length(p - mc_feu.xyz);
	float prox = exp(-(di * di) / (rayon_chaud * rayon_chaud));
	return mc_feu.w * face * (0.3 + 0.7 * prox);
}

void vertex() {
	vec3 pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float hv = chaleur_en(pm, nm);
	float echelle = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	// langues : les sommets chauds sont soulevés (bruit qui monte) → la coque s'effiloche vers le haut, hors du corps
	float t = TIME;
	float fl = bruit(pm * vec3(6.0, 2.2, 6.0) - vec3(0.0, t * montee * 2.2, 0.0));
	// bord de la silhouette vue du JET : la coque y est entraînée dans le sens du jet et s'écarte du corps (le flux
	// contourne l'obstacle et ressort sur les côtés, au-dessus des épaules, entre les jambes)
	vec3 dj = normalize(mc_dir.xyz + vec3(0.0, 0.00001, 0.0));
	float bj = 1.0 - abs(dot(nm, dj));
	vec3 np = nm - dj * dot(nm, dj);
	np = length(np) > 0.001 ? normalize(np) : nm;
	float sous_jet = clamp(mc_autre.w, 0.0, 1.0);   // w : part du jet (1 sous le jet, 0 pendant la brûlure)
	float hk = clamp(hv, 0.0, 1.2);
	float fl2 = bruit(pm * vec3(5.0, 5.0, 5.0) - dj * t * 3.0);
	vec3 dep = nm * (0.012 + gonfle_max * hk)
		+ vec3(0.0, 1.0, 0.0) * hauteur * hk * fl * fl
		+ (dj * entraine + np * ecarte_bord) * sous_jet * smoothstep(0.55, 0.95, bj) * hk * fl2;
	VERTEX += (transpose(mat3(MODEL_MATRIX)) * dep) / (echelle * echelle);
	p_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_monde = nm;
	chaleur_v = hv * (0.6 + 0.4 * fl);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// même grille d'accroche que le corps (couche fine : grille × magie_echelle) : la coque ne glisse pas sur lui
	if (mc_mesh.x > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(mc_mesh.x * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, mc_mesh.x) * max(magie_echelle, 1.0);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	if (mc_feu.w <= 0.003) {
		discard;
	}
	if (plein) {
		ALBEDO = vec3(clamp(chaleur_v, 0.0, 1.0), clamp(mc_feu.w, 0.0, 1.0), 0.0);
		ALPHA = 1.0;
	} else {
		if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
			discard;
		}
		vec3 nv = normalize((VIEW_MATRIX * vec4(n_monde, 0.0)).xyz);
		float bord = 1.0 - abs(nv.z);                       // 0 face à l'œil, 1 sur le contour
		// cases du monde (pixels francs) ; langues verticales (bruit étiré en hauteur) qui montent
		vec3 q = floor(p_monde * cases) / cases;
		float t = TIME;
		float v = bruit(q * vec3(11.0, 3.0, 11.0) - vec3(0.0, t * montee * 3.0, 0.0)) * 0.65
			+ bruit(q * vec3(23.0, 7.0, 23.0) - vec3(0.0, t * montee * 6.0, 0.0)) * 0.35;
		// densité : contour de la silhouette et côté chaud ; au centre du corps, seulement le plus chaud (corps lisible)
		float dens = chaleur_v * (0.25 + 1.0 * smoothstep(0.25, 0.85, bord));
		float i = dens * (v * 1.7 - 0.55);
		// cœur d'impact : éclaboussure blanc-jaune qui s'étale sur la surface autour du point touché (pas une sphère)
		vec3 dj = normalize(mc_dir.xyz + vec3(0.0, 0.00001, 0.0));
		float di = length(p_monde - mc_feu.xyz);
		float coeur = exp(-(di * di) / (rayon_coeur * rayon_coeur)) * clamp(-dot(n_monde, dj), 0.0, 1.0) * min(mc_feu.w, 1.2) * clamp(mc_autre.w, 0.0, 1.0);
		i = max(i, coeur * (0.4 + 0.6 * v));
		if (i <= 0.06) {
			discard;
		}
		vec3 c;
		if (i > 0.62) {
			c = c0.rgb;
		} else if (i > 0.44) {
			c = c1.rgb;
		} else if (i > 0.28) {
			c = c2.rgb;
		} else if (i > 0.16) {
			c = c3.rgb;
		} else if (i > 0.1) {
			c = c4.rgb;
		} else {
			c = c5.rgb;
		}
		ALBEDO = c * eclat;
		ALPHA = 1.0;
	}
}
