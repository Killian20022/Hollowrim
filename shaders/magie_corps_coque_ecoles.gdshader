// SOCLE « impact des sorts sur les corps » : COQUE des écoles de l'agent B (même principe que magie_corps_coque, le feu) :
// copie skinnée des maillages du corps (même maillage, peau, squelette : suit animation et ragdoll), dessinée dans la couche
// fine avec l'occlusion du monde. Un matériau par école (uniforme `ecole`), l'état par paramètres d'instance.
//   0 glace     : CROÛTE DE GIVRE qui gagne la surface depuis le point touché (mc_pt.w = rayon couvert) ; cristaux = sommets
//                 poussés le long de la normale (au hasard par sommet : facettes PS1), paliers glacés, reflets ; fond quand
//                 mc_ecoles.x baisse (les cristaux rentrent, la croûte se troue)
//   1 ténèbres  : VOLUTES sombres arrachées de la surface côté lanceur et entraînées vers sa main (mc_vers.xyz = direction
//                 du corps vers la main, w = force de l'aspiration) ; sinon elles montent doucement (corruption)
//   2 électricité : contour qui crépite (cases blanches et bleues) et veines qui courent sur le corps, papillotant
// Canaux (instance) : mc_mesh (x grille ps1), mc_ecoles (x givre, y choc, z ténèbres), mc_pt (xyz point, w rayon du givre),
// mc_vers (xyz direction vers la main, w aspiration).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

instance uniform vec4 mc_mesh = vec4(135.0, 0.0, 64.0, 0.0);
instance uniform vec4 mc_ecoles = vec4(0.0);
instance uniform vec4 mc_pt = vec4(0.0);
instance uniform vec4 mc_vers = vec4(0.0, 0.0, 1.0, 0.0);

uniform int ecole = 0;
uniform float cases = 48.0;
uniform float cristal = 0.05;        // m : hauteur des cristaux au plus
uniform float volute = 0.22;         // m : longueur des volutes aspirées
uniform float eclat = 1.0;

varying vec3 p_monde;
varying vec3 n_monde;
varying float m_v;                   // couverture (givre) / force (volutes, choc) au sommet
varying float pointe;                // 0..1 : sommet d'un cristal / bout d'une volute

float hh(float x) {
	return fract(sin(x * 91.345 + 7.13) * 47453.5453);
}

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

float couvert(vec3 pm, float graine) {
	float r = max(mc_pt.w, 0.001);
	float ir = graine * 0.3;
	return (1.0 - smoothstep(r * (0.5 + ir), r * (0.78 + ir), length(pm - mc_pt.xyz))) * mc_ecoles.x;
}

void vertex() {
	vec3 pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float echelle = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	// graine STABLE par sommet (l'index ne bouge pas avec l'animation, contrairement à la position)
	float g = hh(float(VERTEX_ID));
	vec3 dep = vec3(0.0);
	m_v = 0.0;
	pointe = 0.0;
	if (ecole == 0) {
		float m = couvert(pm, g);
		// côté tourné vers le tir d'abord ; le reste se couvre quand le givre est complet (mc_vers.w = 1 - plein)
		vec3 vt = normalize(mc_vers.xyz + vec3(0.0, 0.00001, 0.0));
		m *= mix(1.0, smoothstep(-0.55, 0.25, dot(nm, vt)), clamp(mc_vers.w, 0.0, 1.0));
		m_v = m;
		// un sommet sur trois devient la pointe d'un cristal ; les autres gonflent juste la croûte
		float pic = step(0.66, g) * (0.45 + 0.55 * hh(g * 17.0));
		pointe = pic * step(0.05, m);
		// près du point touché, les cristaux sont plus grands (éclats plantés dans le corps)
		float di = length(pm - mc_pt.xyz);
		float pres = 1.0 + 2.2 * exp(-(di * di) / 0.04) * step(0.85, g);
		dep = nm * (0.008 + 0.01 * m + cristal * pic * pres * smoothstep(0.15, 0.9, m));
	} else if (ecole == 1) {
		float k = mc_ecoles.z;
		vec3 v = normalize(mc_vers.xyz + vec3(0.0, 0.00001, 0.0));
		float face = clamp(dot(nm, v), 0.0, 1.0);
		float fl = bruit(pm * vec3(5.0, 5.0, 5.0) - v * TIME * 2.5);
		float asp = clamp(mc_vers.w, 0.0, 1.0);
		// aspirées vers la main (côté lanceur) ; sinon elles montent (corruption)
		vec3 vers = normalize(mix(vec3(0.0, 1.0, 0.0), v + vec3(0.0, 0.25, 0.0), asp));
		float lg = volute * k * fl * fl * (0.35 + 0.65 * mix(0.6, face, asp)) * step(0.4, g);
		pointe = clamp(lg / max(volute, 0.001), 0.0, 1.0);
		m_v = k;
		dep = nm * (0.01 + 0.012 * k) + vers * lg;
	} else {
		m_v = mc_ecoles.y;
		dep = nm * 0.012 * m_v;
	}
	VERTEX += (transpose(mat3(MODEL_MATRIX)) * dep) / (echelle * echelle);
	p_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_monde = nm;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (mc_mesh.x > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 gr = vec2(mc_mesh.x * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, mc_mesh.x) * max(magie_echelle, 1.0);
		clip.xy = round(clip.xy / clip.w * gr) / gr * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	if (mc_ecoles.x + mc_ecoles.y + mc_ecoles.z <= 0.003) {
		discard;
	}
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	vec3 nv = normalize((VIEW_MATRIX * vec4(n_monde, 0.0)).xyz);
	float bord = 1.0 - abs(nv.z);
	vec3 q = floor(p_monde * cases) / cases;
	vec3 c;
	float a;
	if (ecole == 0) {
		// facettes plates (normale de la face, PS1) éclairées d'en haut + reflet sur la tranche
		vec3 nf = normalize(cross(dFdx(p_monde), dFdy(p_monde)));
		float lum = clamp(dot(nf, normalize(vec3(0.3, 1.0, 0.2))) * 0.5 + 0.5, 0.0, 1.0);
		float m = m_v;
		float trou = bruit(q * 9.0);
		// la croûte se troue au bord du givre et pendant la fonte (jamais un aplat : le corps reste lisible)
		if (m < 0.1 || trou > 0.05 + 0.4 * m + pointe * 0.7) {
			discard;
		}
		// paliers glacés sombres (la croûte est dans l'ombre de la crypte) ; blanc seulement sur l'arête des cristaux
		float t = lum * 0.55 + pointe * 0.4 + step(0.8, bord) * 0.2;
		if (t > 0.9) {
			c = vec3(0.86, 0.94, 1.0);
		} else if (t > 0.68) {
			c = vec3(0.48, 0.7, 0.92);
		} else if (t > 0.45) {
			c = vec3(0.24, 0.45, 0.78);
		} else {
			c = vec3(0.11, 0.2, 0.42);
		}
		a = pointe > 0.05 ? 0.85 : 0.35;
		c *= eclat * 0.85;
	} else if (ecole == 1) {
		float v = bruit(q * vec3(9.0, 9.0, 9.0) + vec3(0.0, -TIME * 2.0, 0.0));
		float i = m_v * (v * 1.4 - 0.3) * (0.2 + 0.8 * max(pointe, smoothstep(0.45, 0.9, bord)));
		if (i <= 0.14) {
			discard;
		}
		if (i > 0.7) {
			c = vec3(0.75, 0.45, 1.0);   // liseré violet clair
		} else if (i > 0.5) {
			c = vec3(0.42, 0.13, 0.66);
		} else if (i > 0.3) {
			c = vec3(0.12, 0.04, 0.19);
		} else {
			c = vec3(0.04, 0.015, 0.06);
		}
		a = i > 0.5 ? 0.9 : 0.8;
	} else {
		// contour seulement (le voile fait les veines) : cases bleues qui crépitent, rares cases blanches
		float f1 = step(0.55, h3(floor(q * 6.0) + floor(TIME * 24.0)));
		float i = m_v * step(0.8, bord) * f1;
		if (i <= 0.2) {
			discard;
		}
		c = h3(q + floor(TIME * 12.0)) > 0.85 ? vec3(0.94, 0.95, 1.0) * 1.2 : vec3(0.42, 0.4, 0.92) * 1.1;
		a = 0.85;
	}
	ALBEDO = c;
	ALPHA = a;
}
