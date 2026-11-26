// RAYON NOIR (sort CONTINU des ténèbres, scripts/magie/rayon_noir.gd) : dérivé du faisceau du RAYON DU NÉANT
// v5 : un CORPS entre les deux extrêmes : cœur violet-aubergine TEXTURÉ (matière à opacité partielle, prémultipliée, comme la fumée
//   du noyau tenu en main), gaine violette saturée, liseré fin, brillance en filaments et éclats localisés. (v3 : masse noire opaque ;
//   v4 : tout additif, un fil clair sans corps.)
// v4 : PLUS AUCUN NOIR. Le faisceau est ADDITIF (blend_premul_alpha, ALPHA = 0 : seule façon d'être additif dans la couche fine de la magie) (il ne peut jamais assombrir le fond) : cœur violet-noir translucide très fin, lumière
//   magenta/violette dominante, fumée violette lumineuse. (Historique : v3 = cœur noir opaque, fumée sombre.)
// (shaders/rayon_neant_faisceau.gdshader, même tube englobant de RayonNeant._tube(), même forme calculée par pixel avec la
// distance entre le rayon de vue et l'axe). Différences pour le continu :
//   - plus fin, cœur NOIR profond, liseré POURPRE sombre (moins éclatant que le néant), filet pâle très fin ;
//   - ONDULATION LENTE qui court le long du rayon vers la cible (le rayon gonfle et le liseré s'avive au passage de l'onde) ;
//   - `vie` piloté par le script : 0 → 0,1 la tête file de la main à la cible (allumage ~0,2 s), 0,1..0,6 plateau (tenu),
//     0,6 → 1 le rayon se resserre et s'éteint (relâchement), en même temps que la fumée qui s'en échappe (script).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_back, depth_draw_never, fog_disabled, shadows_disabled;
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
// v5 : opacité de la matière sombre (cœur : de AM_MIN à AM_MAX selon la densité des volutes ; gaine : AM_GAINE)
const float AM_MIN = 0.72;
const float AM_MAX = 0.9;
const float AM_GAINE = 0.7;   // la gaine garde sa couleur violette même sur un ciel clair (l'additif seul y blanchit)

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
	return mix(rayon_min, rayon_max, smoothstep(0.0, ouverture, s)) * (1.0 + 1.8 * smoothstep(5.0, 40.0, s)) * rk() * ond * evase
		* mix(0.6, 1.0, smoothstep(0.0, 0.35, s));   // v5b : il sort du cercle déjà épais (raccord avec l'orbe), pointe courte
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
	// v5 : vue presque DANS L'AXE (1re personne) : le point de l'axe le plus proche du rayon de vue tombe souvent hors du faisceau
	// (au-delà du bout) et la distance y était fausse : le rayon se lisait comme un anneau à la main puis un entonnoir au bout, sans
	// corps entre les deux. On garde la plus petite distance RELATIVE (distance / rayon local) sur l'abscisse la plus proche (bornée)
	// et sur quelques abscisses en progression géométrique (le faisceau s'évase) : le corps est continu de la main à la cible.
	{
		float tb = clamp(tc, 0.0, longueur);
		vec3 pb = v_a + ax * tb;
		float prb = dot(pb, D);
		float bx = (prb > 0.0 ? length(pb - D * prb) : 1.0e3) / max(rayon_en(tb), 0.001);
		for (int i = 0; i < 7; i++) {
			float ti = min(0.3 * pow(2.0, float(i)), longueur);
			vec3 pi = v_a + ax * ti;
			float pri = dot(pi, D);
			float xi = (pri > 0.0 ? length(pi - D * pri) : 1.0e3) / max(rayon_en(ti), 0.001);
			if (xi < bx) {
				bx = xi;
				tb = ti;
			}
		}
		tc = tb;
		rho = bx * max(rayon_en(tb), 0.001);
	}
	float u_c = clamp(tc / longueur, 0.0, 1.0);
	float rr = max(rayon_en(clamp(tc, 0.0, longueur)), 0.001);
	float x = rho / rr;                      // 0 sur l'axe, 1 au bord du rayon
	// bouche du rayon (couvercle de départ, vu dans l'axe depuis la main) : on lit la position sur le couvercle lui-même
	float bouche = 1.0 - smoothstep(0.0005, 0.004, v_u);
	x = mix(x, min(x, v_rad), bouche);   // v5 : le couvercle ne masque plus le corps vu dans l'axe
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
	// v5 : MATIÈRE. Le rayon a un CORPS (cœur sombre aubergine, texturé et en mouvement) bordé d'une GAINE violette saturée et d'un
	// liseré fin ; la lumière est portée par des filaments et des éclats LOCALISÉS. Trois parts accumulées :
	//   cm / am : matière (mélange prémultiplié : ALBEDO += cm * am, ALPHA = am, comme magie_bouffee mode 0) — elle assombrit un peu le
	//             fond, sans jamais être un aplat (densité variable par paliers, jamais au-delà de AM_MAX) ;
	//   gl      : lueur additive (ALPHA inchangé).
	// Même parti que le noyau des ténèbres tenu en main (magie_noyau_ecole, école 3) : corps sombre, bandes violettes qui tournent,
	// volutes, liseré violet.
	float s0 = 0.5 + 0.05 * sin(tc * 2.3 - TIME * 6.0 + graine) * smoothstep(0.0, 1.5, tc) + (n - 0.5) * 0.1;   // bord du cœur (ondule)
	float e2 = s0 + 0.3;                                    // bord extérieur de la gaine
	float ph = fract((tc - TIME * flux_vit) / flux_pas + graine);
	float puls = pow(1.0 - smoothstep(0.0, 0.22, min(ph, 1.0 - ph) * 2.0), 2.0);
	float sc = 0.85 + 0.15 * fract(sin(floor(TIME * 24.0) * 12.9898 + graine) * 43758.5453);
	vec3 cm = noir;
	float am = 0.0;
	vec3 gl = vec3(0.0);
	// bandes torsadées (3 filaments) qui défilent vers la cible en tournant, comme les bandes du noyau
	float tw = v_th / TAU * 3.0 + tc * 0.45 - TIME * 2.6 + (mbruit(vec2(tc * 0.7 - TIME * 3.0, graine)) - 0.5) * 1.2;
	float bande = 0.5 + 0.5 * sin(tw * TAU);
	// volutes : bruit fractal qui file le long du tir (densité variable)
	float vol = mfbm2(vec2(tc * 1.4 - TIME * 7.5, v_th * 1.6 + graine * 2.0));
	if (x < e2) {
		// matière du cœur, plus légère dans la gaine ; densité en paliers (aucun tramage)
		float dens = clamp(0.35 + 0.55 * vol + 0.25 * bande, 0.0, 1.0);
		float coeur = 1.0 - smoothstep(s0 - 0.12, s0 + 0.04, x);
		am = mix(AM_GAINE, mix(AM_MIN, AM_MAX, dens), coeur);
		am = floor(am * 8.0 + 0.5) / 8.0;
		cm = mix(noir, fume, clamp(bande * 0.6 + vol * 0.5, 0.0, 1.0));
		cm = mix(cm, bord * 0.85, 1.0 - coeur);             // la gaine : violet saturé
		// lueur intérieure faible (le cœur se lit violet, pas gris) + bandes claires qui tournent
		gl += fume * 0.12 * coeur + bord * 0.28 * smoothstep(0.82, 0.97, bande) * coeur * (0.6 + 0.4 * vol);
		// impulsions qui filent vers la cible (au centre du cœur, discrètes)
		gl += bord * 0.35 * puls * coeur * (1.0 - smoothstep(0.0, s0 * 0.6, x));
		// éclats : quelques points vifs qui filent (pointes de brillance LOCALISÉES)
		float ecl = step(0.8, mbruit(vec2(tc * 5.0 - TIME * 22.0, v_th * 3.0 + graine * 5.0))) * step(0.45, vol);   // points étoilés (comme l'orbe tenu)
		gl += filet * 0.9 * ecl * coeur;
		// filaments clairs torsadés dans le corps (2, sens opposés), fins
		for (int h2 = 0; h2 < 2; h2++) {
			float sens = h2 == 0 ? 1.0 : -1.0;
			float ph2 = fract(v_th / TAU * 2.0 + tc * 0.55 * sens - TIME * 1.6 + float(h2) * 0.5);
			float sp = (1.0 - smoothstep(0.0, 0.05, abs(ph2 - 0.5))) * smoothstep(0.12, 0.3, x);
			gl += mix(bord * 1.1, filet, 0.2) * sp * 0.45;
		}
		// gaine : lumière violette saturée, plus vive contre le cœur (rim), qui s'éteint vers l'extérieur
		if (x >= s0) {
			float t = (x - s0) / (e2 - s0);
			gl += bord * (0.75 - 0.45 * t + 0.4 * puls) * eclat * sc;
			gl += mix(bord, filet, 0.3) * 0.8 * (1.0 - smoothstep(0.0, 0.06, x - s0)) * eclat * sc;   // liseré net contre le cœur   // liseré fin contre le cœur
		}
	} else if (x < e2 + 0.04) {
		// liseré extérieur, fin
		gl = mix(bord, filet, 0.15) * 0.6 * eclat * sc;
		am = AM_GAINE * 0.7;
		cm = bord * 0.7;
	} else {
		// fumée déchirée autour du rayon : volutes sombres-violettes (matière légère) qui se dissolvent par paliers
		float t = (x - e2) / max(GROS - e2, 0.1);
		float f = (1.0 - t) * (0.4 + 0.8 * n) - 0.3;
		float fa = floor(clamp(f, 0.0, 1.0) * 4.0 + 0.5) / 4.0;
		if (fa < 0.05) {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
			break;   // pas de return dans fragment() (refusé par Godot) : sortie de la boucle à un tour
		}
		am = fa * 0.35;
		cm = mix(noir, fume, 0.5 + 0.5 * n2);
		gl = mix(fume, bord * 0.8, n2 * 0.5 + 0.2) * fa * 0.35;
		// brins de fumée enroulés en hélice (3), liseré violet
		for (int h = 0; h < 3; h++) {
			float fh = float(h);
			float phh = fract(v_th / TAU * (3.0 + fh) + tc * (0.16 + 0.05 * fh) - TIME * (3.2 + 0.6 * fh) + fh * 0.33);
			float d = min(phh, 1.0 - phh);
			float larg = 0.035 + 0.02 * n2;
			if (d < larg) {
				gl += bord * 0.6 * (1.0 - d / larg);
			}
		}
	}
	// stries fines qui défilent vite le long du rayon (tirets) : violettes, quelques têtes claires
	float cs = floor(v_th / TAU * 10.0);
	float lg = 1.0 - smoothstep(0.04, 0.14, abs(fract(v_th / TAU * 10.0) - 0.5));
	float tir = smoothstep(0.62, 0.92, fract(tc * 0.32 - TIME * (6.0 + 2.0 * mod(cs, 3.0)) + cs * 0.37));
	float zs = smoothstep(s0 - 0.1, s0 + 0.05, x) * (1.0 - smoothstep(e2, GROS, x));
	gl += mix(bord * 1.1, filet, 0.35 * tir) * tir * lg * zs * 0.6;
	// plus vif près de la main, battement lent
	float pres = exp(-tc / 2.8);
	gl *= 1.0 + 0.5 * pres + 0.2 * sin(tc * 0.9 - TIME * 4.0 + graine);
	// sortie du cercle : la source est plus claire au tout début (allumage)
	float sortie = (1.0 - smoothstep(0.0, 0.02, v_u)) * step(s0, x);
	gl += filet * 1.4 * sortie * (1.0 - smoothstep(0.1, 0.22, vie));
	float tete_fade = smoothstep(0.0, 0.05, tete - u_c);
	float fin_fade = 1.0 - smoothstep(0.96, 1.0, u_c);
	float m = clamp(tete_fade * fin_fade * mix(0.5, 1.0, k) * vis, 0.0, 1.0);
	am = clamp(am * m, 0.0, AM_MAX);
	// prémultiplié : matière (cm * am, opacité am) + lumière additive (gl, sans opacité)
	ALBEDO = cm * am + gl * m;
	ALPHA = am;
} while (false);
}
