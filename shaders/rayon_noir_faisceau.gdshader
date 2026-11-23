// RAYON NOIR (sort CONTINU des ténèbres, scripts/magie/rayon_noir.gd) : dérivé du faisceau du RAYON DU NÉANT
// (shaders/rayon_neant_faisceau.gdshader, même tube englobant de RayonNeant._tube(), même forme calculée par pixel avec la
// distance entre le rayon de vue et l'axe). Différences pour le continu :
//   - plus fin, cœur NOIR profond, liseré POURPRE sombre (moins éclatant que le néant), filet pâle très fin ;
//   - ONDULATION LENTE qui court le long du rayon vers la cible (le rayon gonfle et le liseré s'avive au passage de l'onde) ;
//   - `vie` piloté par le script : 0 → 0,1 la tête file de la main à la cible (allumage ~0,2 s), 0,1..0,6 plateau (tenu),
//     0,6 → 1 le rayon se resserre et s'éteint (relâchement), en même temps que la fumée qui s'en échappe (script).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
#include "res://shaders/magie_bruit.gdshaderinc"

uniform vec3 noir : source_color = vec3(0.012, 0.004, 0.025);
uniform vec3 fume : source_color = vec3(0.16, 0.04, 0.30);
uniform vec3 bord : source_color = vec3(0.50, 0.15, 0.86);
uniform vec3 filet : source_color = vec3(0.86, 0.72, 1.0);
uniform float onde = 0.16;       // amplitude de l'ondulation (part du rayon)
uniform float onde_lg = 2.6;     // longueur d'onde (m)
uniform float onde_vit = 2.2;    // vitesse de l'onde vers la cible (m/s)
uniform float eclat = 1.0;       // éclat du liseré (double magie : plus)
uniform float vie = 0.0;
uniform float longueur = 10.0;   // m
uniform float rayon_max = 1.0;   // m : rayon du rayon loin de la source
uniform float rayon_min = 0.2;   // m : rayon à la sortie du cercle
uniform float ouverture = 14.0;  // m : distance sur laquelle le rayon s'ouvre
uniform float graine = 0.0;

const float GROS = 1.45;         // le volume englobant dépasse le rayon de ce facteur (fumée)

varying float v_s;               // abscisse du fragment en mètres
varying float v_u;               // 0..1
varying float v_th;              // angle autour (rad)
varying vec3 v_a;                // origine de l'axe (espace vue)
varying vec3 v_e;                // direction de l'axe (espace vue, unitaire)
varying float v_rad;             // distance à l'axe du sommet / rayon du rayon (0 au centre du couvercle, GROS sur la paroi)

float rk() {
	float fin = 1.0 - smoothstep(0.6, 1.0, vie);
	float naiss = smoothstep(0.0, 0.08, vie);
	return fin * naiss;
}

float vague(float s) {
	return sin((s - TIME * onde_vit) * TAU / onde_lg + graine);
}

float rayon_en(float s) {
	float ond = 1.0 + onde * vague(s) * smoothstep(0.0, 0.8, s);
	return mix(rayon_min, rayon_max, smoothstep(0.0, ouverture, s)) * rk() * ond;
}

void vertex() {
	v_u = UV.x;
	v_s = UV.x * longueur;
	v_th = UV.y * TAU;
	v_a = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_e = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	// UV.y < -0.5 : sommet du couvercle (centre)
	float r = rayon_en(v_s) * GROS;
	v_rad = length(VERTEX.xy) * GROS;
	VERTEX.xy *= r;
	VERTEX.z = UV.x;
}

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	float tete = clamp(vie / 0.1, 0.0, 1.0);
	float k = rk();
	if (k < 0.03) {
		discard;
	}
	// distance entre le rayon de vue (depuis l'œil, espace vue) et l'axe du tir
	vec3 D = -normalize(VIEW);
	vec3 ax = normalize(v_e);
	vec3 w0 = -v_a;
	float b = dot(D, ax);
	float dd = dot(D, w0);
	float ee = dot(ax, w0);
	float den = 1.0 - b * b;
	float tc = v_s;                       // abscisse (m) du point de l'axe le plus proche du rayon de vue
	float rho;
	if (den > 0.0004) {
		tc = (ee - b * dd) / den;
		float sc = (b * ee - dd) / den;
		rho = length(D * sc - (v_a + ax * tc));
	} else {
		rho = length(v_a - ax * dot(v_a, ax));  // vue dans l'axe : distance de l'œil à l'axe
	}
	float u_c = clamp(tc / longueur, 0.0, 1.0);
	float rr = max(rayon_en(clamp(tc, 0.0, longueur)), 0.001);
	float x = rho / rr;                      // 0 sur l'axe, 1 au bord du rayon
	// bouche du rayon (couvercle de départ, vu dans l'axe depuis la main) : on lit la position sur le couvercle lui-même
	float bouche = 1.0 - smoothstep(0.0005, 0.004, v_u);
	x = mix(x, v_rad, bouche);
	if (x > GROS || u_c > tete) {
		discard;
	}

	float n = mfbm2(vec2(tc * 0.9 - TIME * 6.0, v_th * 1.3 + graine));
	float n2 = mbruit(vec2(tc * 3.0 - TIME * 13.0, v_th * 2.0 + graine * 3.0));
	// frontière du cœur, déchirée par le bruit (l'axe est à x = 0)
	float s0 = 0.52 + (n - 0.5) * 0.26;
	float pv = 0.5 + 0.5 * vague(tc);     // passage de l'onde (0..1) : le liseré s'avive
	vec3 c = noir;
	float a = 1.0;
	if (x < s0) {
		// cœur noir ; des courants violets très sombres défilent dedans (pas un aplat)
		float cour = smoothstep(0.62, 1.0, mbruit(vec2(tc * 1.6 - TIME * 9.0, v_th * 2.5 + graine)));
		c = mix(noir, fume * 0.9, cour * 0.55);
	} else if (x < s0 + 0.04) {
		c = filet * (1.2 + 0.4 * pv) * eclat;
	} else if (x < s0 + 0.2) {
		float t = (x - s0 - 0.04) / 0.16;
		c = bord * (1.5 - 0.7 * t + 0.35 * n2 + 0.55 * pv) * eclat;
	} else {
		// fumée déchirée : se dissout vers l'extérieur, par paliers
		float t = (x - s0 - 0.2) / max(GROS - s0 - 0.2, 0.1);
		float f = (1.0 - t) * (0.5 + 0.9 * n) - 0.2;
		a = floor(clamp(f, 0.0, 1.0) * 3.0 + 0.5) / 3.0 * 0.85;
		c = mix(fume, bord * 0.5, n2 * 0.45 + 0.2 * (1.0 - t) + 0.15 * pv);
		if (a < 0.05) {
			discard;
		}
	}
	// brins de fumée enroulés en hélice (3) : ils filent le long du tir, surtout dans la fumée et au bord
	for (int h = 0; h < 3; h++) {
		float fh = float(h);
		float ph = fract(v_th / TAU * (3.0 + fh) + tc * (0.16 + 0.05 * fh) - TIME * (0.55 + 0.2 * fh) + fh * 0.33);
		float d = min(ph, 1.0 - ph);
		float larg = 0.035 + 0.02 * n2;
		if (d < larg && x > s0 + 0.12) {
			float vif = 1.0 - d / larg;
			c = mix(c, bord * 1.15, vif * 0.45);
			a = max(a, 0.85);
		}
	}
	// sortie du cercle : la source est plus claire ; le front s'amincit en pointe
	float sortie = (1.0 - smoothstep(0.0, 0.02, v_u)) * step(s0, x);
	c = mix(c, filet * 1.7, sortie * 0.6 * (1.0 - smoothstep(0.1, 0.3, vie)));
	float tete_fade = smoothstep(0.0, 0.05, tete - u_c);
	float fin_fade = 1.0 - smoothstep(0.96, 1.0, u_c);
	ALBEDO = c;
	ALPHA = clamp(a * tete_fade * fin_fade * mix(0.5, 1.0, k), 0.0, 1.0);
}
