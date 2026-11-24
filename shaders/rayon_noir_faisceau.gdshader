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
uniform float onde = 0.0;        // (v1 : ondulation lente ; v2 : rayon tendu, plus d'ondulation)
uniform float onde_lg = 2.6;
uniform float onde_vit = 2.2;
uniform float flux_vit = 26.0;   // v2 : vitesse des impulsions pourpres qui filent de la main vers la cible (m/s)
uniform float flux_pas = 1.7;    // v2 : écart entre deux impulsions (m) → ~15 par seconde en un point
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
	float evase = 1.0 + 0.12 * smoothstep(longueur - 0.25, longueur, s);   // à peine évasé en touchant
	return mix(rayon_min, rayon_max, smoothstep(0.0, ouverture, s)) * (1.0 + 1.8 * smoothstep(5.0, 40.0, s)) * rk() * ond * evase;
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
	do {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
	}
	float tete = clamp(vie / 0.1, 0.0, 1.0);
	float k = rk();
	if (k < 0.03) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
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
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
		break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
	}

	// v3f (1re personne) : faisceau vu dans son axe -> cœur fin, quasi invisible tout près de l'œil, couleurs/lignes qui dominent
	float axial = smoothstep(0.7, 0.97, abs(b));                       // 0 : vue de côté (inchangée), 1 : dans l'axe
	float dcam = length(VERTEX);                                       // distance œil -> fragment (m)
	float pres_cam = smoothstep(0.08, 0.4, dcam);                       // 0 collé à l'œil, 1 au-delà de ~3 m
	float vis = mix(1.0, pres_cam, axial);                             // la vue de côté ne change pas
	float n = mfbm2(vec2(tc * 0.9 - TIME * 6.0, v_th * 1.3 + graine));
	float n2 = mbruit(vec2(tc * 3.0 - TIME * 13.0, v_th * 2.0 + graine * 3.0));
	// frontière du cœur, déchirée par le bruit (l'axe est à x = 0)
	float s0 = mix(0.34, 0.13, axial) + 0.05 * sin(tc * 2.3 - TIME * 6.0 + graine) * smoothstep(0.0, 1.5, tc) + (n - 0.5) * 0.05;   // v3 : le cœur sombre ondule   // v2 : cœur tendu, bord net (le bruit ne déforme plus la silhouette)
	float e2 = s0 + 0.13 + 0.45 * axial;   // dans l'axe : ruban lumineux plus large autour du cœur fin
	// impulsions qui filent vers la cible (rapides, nettes) et scintillement du liseré (24 Hz, par paliers : aucun tramage)
	float ph = fract((tc - TIME * flux_vit) / flux_pas + graine);
	float puls = pow(1.0 - smoothstep(0.0, 0.22, min(ph, 1.0 - ph) * 2.0), 2.0);
	float sc = 0.82 + 0.18 * fract(sin(floor(TIME * 24.0) * 12.9898 + graine) * 43758.5453);
	float pv = puls;
	vec3 c = noir;
	float a = 1.0;
	if (x < s0) {
		// cœur noir ; des courants violets très sombres défilent dedans (pas un aplat)
		float cour = smoothstep(0.62, 1.0, mbruit(vec2(tc * 1.6 - TIME * 9.0, v_th * 2.5 + graine)));
		c = mix(noir, fume * 1.7, cour * mix(0.85, 1.0, axial));
		a = 1.0 - 0.7 * axial;                                         // cœur sombre fin et translucide dans l'axe (pas un aplat)
		// stries pourpres fines au cœur, qui filent avec les impulsions
		float st = 1.0 - smoothstep(0.0, 0.06, abs(fract(v_th / TAU * 3.0 + graine) - 0.5) * 2.0 - 0.9);
		c = mix(c, bord * 1.6, puls * st * 0.8);
		c = mix(c, bord * 1.2, axial * 0.45);
	} else if (x < s0 + 0.05) {
		c = filet * (1.25 + 1.1 * pv) * eclat * sc;
	} else if (x < e2) {
		float t = (x - s0 - 0.05) / (e2 - s0 - 0.05);
		c = bord * (1.9 - 0.6 * t + 1.2 * pv) * eclat * sc * (1.0 + 0.5 * axial);
	} else {
		// fumée déchirée : se dissout vers l'extérieur, par paliers
		float t = (x - e2) / max(GROS - e2, 0.1);
		float f = (1.0 - t) * (0.4 + 0.8 * n) - 0.25;
		a = floor(clamp(f, 0.0, 1.0) * 4.0 + 0.5) / 4.0 * 0.78;   // fumée plus légère autour, la silhouette reste le trait
		c = mix(fume, bord * 0.5, n2 * 0.45 + 0.2 * (1.0 - t) + 0.15 * pv);
		if (a < 0.05) {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
			break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
		}
	}
	// brins de fumée enroulés en hélice (3) : ils filent le long du tir, surtout dans la fumée et au bord
	for (int h = 0; h < 3; h++) {
		float fh = float(h);
		float phh = fract(v_th / TAU * (3.0 + fh) + tc * (0.16 + 0.05 * fh) - TIME * (3.2 + 0.6 * fh) + fh * 0.33);
		float d = min(phh, 1.0 - phh);
		float larg = 0.035 + 0.02 * n2;
		if (d < larg && x > e2 + 0.01) {
			float vif = 1.0 - d / larg;
			c = mix(c, bord * 1.5, vif * 0.6);
			a = max(a, 0.7);
		}
	}
	// deux spirales fines et claires (magenta-blanc) qui s'enroulent sur la gaine et filent vers la cible
	for (int h2 = 0; h2 < 2; h2++) {
		float sens = h2 == 0 ? 1.0 : -1.0;
		float ph2 = fract(v_th / TAU * 2.0 + tc * 0.55 * sens - TIME * 1.6 + float(h2) * 0.5);
		float d2 = abs(ph2 - 0.5);
		float sp = (1.0 - smoothstep(0.0, 0.06, d2)) * smoothstep(s0 + 0.04, s0 + 0.12, x) * (1.0 - smoothstep(s0 + 0.2, s0 + 0.5, x));
		c = mix(c, filet * 1.8, sp * 0.7);
		a = max(a, sp * 0.9);
	}
	// stries lumineuses fines qui défilent vite le long du rayon (tirets, vitesses différentes par strie)
	float cs = floor(v_th / TAU * 10.0);
	float lg = 1.0 - smoothstep(0.04, 0.14, abs(fract(v_th / TAU * 10.0) - 0.5));
	float tir = smoothstep(0.62, 0.92, fract(tc * 0.32 - TIME * (6.0 + 2.0 * mod(cs, 3.0)) + cs * 0.37));
	float zs = smoothstep(0.08, 0.2, x) * (1.0 - smoothstep(s0 + 0.35, GROS, x));
	c = mix(c, filet * 1.7, tir * lg * zs * 0.85);
	a = max(a, tir * lg * zs * 0.9);
	// intensité variable : plus vive et plus fine près de la main, qui s'apaise en s'évasant, et un battement lent
	float pres = exp(-tc / 2.8);
	c *= 1.0 + (0.9 * pres + 0.25 * sin(tc * 0.9 - TIME * 4.0 + graine)) * step(s0 - 0.02, x);
	// sortie du cercle : la source est plus claire ; le front s'amincit en pointe
	float sortie = (1.0 - smoothstep(0.0, 0.02, v_u)) * step(s0, x);
	c = mix(c, filet * 2.4, sortie * 0.8 * (1.0 - smoothstep(0.1, 0.22, vie)));
	float tete_fade = smoothstep(0.0, 0.05, tete - u_c);
	float fin_fade = 1.0 - smoothstep(0.96, 1.0, u_c);
	c *= 1.0 + 0.4 * axial * step(s0 - 0.02, x);                     // liseré et lignes plus vifs dans l'axe
	ALBEDO = c;
	ALPHA = clamp(a * tete_fade * fin_fade * mix(0.5, 1.0, k) * vis, 0.0, 1.0);
} while (false);
}
