// FLUX des jets canalisés (scripts/magie/gestion_magie.gd, _flux_*) : un ruban tourné vers la caméra qui suit une COURBE
// (Bézier quadratique) de la paume (origine locale) au bout du jet (`bout`, en local) : le point de contrôle est sur
// l'axe de visée actuel (-Z local), le bout suit la visée avec un retard (inertie d'un fluide quand on tourne la vue),
// sans jamais se détacher de la paume. Rayon r0 (paume, cône étroit et dense) → r1 (cible), qui s'ouvre progressivement.
//
// Le volume est procédural (rien n'est texturé) : bruit fractal TRANSPORTÉ le long du jet (la matière coule de la main
// vers l'avant, vitesse lisible), déformé par un second bruit (domain warp : langues qui ondulent et se tordent), dans des
// coordonnées qui s'élargissent avec le cône (les langues grandissent en s'éloignant). Bords rongés par le bruit, densité
// et température qui décroissent avec la distance, fragmentation en bout (le jet se défait en lambeaux), étalement au
// contact (`etale`). Fusion PRÉMULTIPLIÉE : le cœur est lumineux (additif), les bords froids sont en partie couvrants
// (fumée rouge sombre) ; dégradé de température continu, juste arrondi en paliers fins (rendu 15 bits du post ps1).
// Sommets : UV.x = position le long du jet (0..1), UV.y = côté (-1..1).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

instance uniform float longueur = 5.0;
instance uniform float r0 = 0.03;
instance uniform float r1 = 0.5;
instance uniform float force = 1.0;
instance uniform float graine = 0.0;
instance uniform vec3 bout = vec3(0.0, 0.0, -5.0);   // bout du jet, repère local (retard d'inertie compris)
instance uniform float etale = 0.0;                  // 0..1 : le jet touche une surface et s'étale au contact
uniform int ecole = 0;           // 0 feu, 1 glace (souffle de givre), 2 ténèbres (drain : coule vers la main), 3 soin
uniform float vitesse = 7.0;     // vitesse de la matière le long du jet (m/s)
uniform float allonge = 1.0;     // fréquence du bruit LE LONG du jet (1 = langues très étirées ; feu : plus courtes, roulées)
uniform float evase = 0.8;       // ouverture du cône le long du jet (r0 → r1 en t^evase : plus petit = s'ouvre vite)
uniform float ouvre = 1.0;       // part du rayon nominal réellement couverte (bords moins rongés au-dessus de 1)
uniform float eclat = 1.35;
// > 0 : SPRAY (feu) : le corps du jet est une suite de BOUFFÉES qui naissent dans la paume, gonflent en s'éloignant et
// se déchirent (vagues de flamme), pas un tube continu ; valeur = écart entre deux bouffées (unités de u, cf. fragment)
uniform float bouffees = 0.0;
uniform float marge = 1.35;      // débord du ruban au-delà du rayon nominal (les bouffées débordent du cône)
uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);   // cœur (chauffé à blanc)
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);
uniform vec4 c5 : source_color = vec4(0.35, 0.10, 0.11, 1.0);  // bord (fumée sombre)

varying float v_t;
varying float v_s;
varying float v_d;    // distance le long du jet (m)
varying float v_cp;   // écart à l'axe À L'ÉCRAN (pixels de ce rendu) : grain fin au pixel près

vec3 courbe(float t) {
	vec3 c = vec3(0.0, 0.0, -longueur * 0.5);
	return 2.0 * (1.0 - t) * t * c + t * t * bout;
}

void vertex() {
	float t = UV.x;
	vec3 la = courbe(t);
	vec3 lb = t < 0.98 ? courbe(t + 0.02) : la + (bout - courbe(0.98));
	vec3 a = (MODEL_MATRIX * vec4(la, 1.0)).xyz;
	vec3 b = (MODEL_MATRIX * vec4(lb, 1.0)).xyz;
	vec4 ca = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(a, 1.0));
	vec4 cb = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(b, 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float wa = max(ca.w, 0.0001);
	vec2 pa = (ca.xy / wa * 0.5 + 0.5) * vp;
	vec2 pb = (cb.xy / max(cb.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 d = pb - pa;
	if (dot(d, d) < 0.000001) {
		d = vec2(1.0, 0.0);
	}
	vec2 perp = normalize(vec2(-d.y, d.x));
	// cône : étroit et dense dans la paume, puis s'ouvre ; au contact, le bout s'évase (la flamme s'étale)
	float r = mix(r0, r1, pow(t, evase)) * (1.0 + etale * 0.55 * smoothstep(0.8, 1.0, t));
	float rpx = r * abs(PROJECTION_MATRIX[1][1]) / wa * vp.y * 0.5;
	// marge : les langues débordent du rayon nominal (le bruit ronge vers l'intérieur ET pousse vers l'extérieur)
	vec2 p = pa + perp * UV.y * (rpx * marge + 1.0);
	// w = 1 : interpolation AFFINE à l'écran. Le ruban est construit à l'écran (pas plan en 3D) : avec la correction de
	// perspective, chaque triangle d'une tranche interpolait le côté différemment (dents de scie régulières le long du jet)
	POSITION = vec4(p / vp * 2.0 - 1.0, ca.z / wa, 1.0);
	v_t = t;
	v_s = UV.y * marge;
	v_d = t * longueur;
	v_cp = UV.y * (rpx * marge + 1.0);
}

#include "res://shaders/magie_bruit.gdshaderinc"

// dégradé continu c0 (h >= 1) → c5 (h <= 0), arrondi en paliers fins (4 par intervalle)
vec3 rampe(float h) {
	float x = clamp((1.0 - h) * 5.0, 0.0, 4.999);
	float i = floor(x);
	float f = floor(fract(x) * 4.0) / 4.0;
	vec3 a = i < 1.0 ? c0.rgb : (i < 2.0 ? c1.rgb : (i < 3.0 ? c2.rgb : (i < 4.0 ? c3.rgb : c4.rgb)));
	vec3 b = i < 1.0 ? c1.rgb : (i < 2.0 ? c2.rgb : (i < 3.0 ? c3.rgb : (i < 4.0 ? c4.rgb : c5.rgb)));
	return mix(a, b, f);
}

void fragment() {
	float sens = ecole == 2 ? -1.0 : 1.0;   // le drain remonte de la cible vers la main
	float tt = TIME + graine * 7.0;
	float t = v_t;
	float s = v_s;
	float as = abs(s);
	float m = max(magie_echelle, 1.0);
	// coordonnées du flux : le long du jet en mètres, compressées au loin (les langues s'allongent en s'éloignant de la
	// paume, comme une flamme qui ralentit en s'ouvrant) ; en travers, le côté normalisé (suit l'ouverture du cône)
	float u = pow(v_d + 0.15, 0.72);
	// transport : la matière avance d'environ `vitesse` unités de u par seconde. Toutes les couches de bruit sont
	// ÉTIRÉES DANS LE SENS DU FLUX (fréquence le long < fréquence en travers) : vu de la main, le jet est très raccourci
	// et des motifs plus serrés le long dessineraient des zigzags réguliers au lieu de langues
	float av = tt * vitesse * sens;
	float ul = (u - av) * allonge;
	// bouffées : chacune est un ovale du plan (u, côté) transporté avec la matière ; taille, retard, dérive latérale et
	// teinte propres (hachage de son numéro). 3 voisines suffisent (elles se chevauchent d'une demi-bouffée au plus)
	float puff_d = 9.0;
	float puff_h = 0.5;
	if (bouffees > 0.0) {
		float ph = (u - av) / bouffees;
		float i0 = floor(ph);
		for (int k = -1; k <= 1; k++) {
			float id = i0 + float(k);
			float h1 = mh2(vec2(id, graine * 13.0 + 1.0));
			float h2 = mh2(vec2(id * 1.7 + 3.1, graine * 7.0 + 5.0));
			float dx = (ph - (id + 0.5 + (h1 - 0.5) * 0.4)) / (0.62 + 0.3 * h2);
			// dérive latérale : les vagues ne sortent pas toutes dans l'axe (spray, pas rayon)
			float off = (h2 - 0.5) * 0.6 * smoothstep(0.05, 0.8, t);
			// rayon : la bouffée gonfle en s'éloignant (au-delà du cône nominal vers le bout), plus ou moins selon h1
			float rad = (0.72 + 0.4 * h1) * mix(0.75, 1.2, smoothstep(0.0, 0.9, t));
			float ds = (s - off) / rad;
			float dd = sqrt(dx * dx + ds * ds);
			if (dd < puff_d) {
				puff_d = dd;
				puff_h = h1;
			}
		}
		// hors de toute bouffée et loin de l'axe : rien à dessiner (évite les bruits des pixels vides du ruban)
		if (puff_d > 1.9 && as / ouvre > 1.9) {
			discard;
		}
	}
	vec2 p = vec2(ul * 1.1, s * 1.5 + graine * 1.7);
	// domain warp : le champ qui tord les langues dérive lui aussi avec le flux, plus lentement (tourbillons)
	vec2 w = vec2(mfbm2(p * vec2(0.7, 1.0) + vec2(av * 0.4 * allonge, tt * 0.9)),
				  mfbm2(p * vec2(0.8, 0.9) + vec2(5.2 + av * 0.35 * allonge, -tt * 0.7)));
	float n = mfbm(p * vec2(1.3, 2.8) + (w - 0.5) * vec2(1.4, 2.8));
	// langues fines, même transport (cohérence) ; grain au pixel en travers pour des bords nets
	float f = mbruit(vec2(ul * 3.2, s * 10.0 + (w.x - 0.5) * 4.0 + graine * 3.0));
	float g = mbruit(vec2(ul * 8.0, v_cp / (1.3 * m) + graine * 9.0));

	// bord rongé : le bruit pousse et creuse le contour (plus fort en s'éloignant de la paume)
	float e = as / ouvre + (n - 0.5) * (1.0 + 0.7 * t) + (f - 0.5) * (0.45 + 0.35 * t) + (g - 0.5) * 0.16;
	if (bouffees > 0.0) {
		// SPRAY : remplace le cône continu par les bouffées (distance normalisée au bord de la bouffée la plus proche),
		// fondues dans un cœur continu près de la paume (la flamme y est dense, les vagues s'en détachent)
		float sp = smoothstep(0.02, 0.18, t);
		float de = mix(as / ouvre, puff_d, sp);
		e = de + (n - 0.5) * (0.85 + 0.6 * t) + (f - 0.5) * (0.4 + 0.35 * t) + (g - 0.5) * 0.16;
	}
	float corps = 1.0 - e;
	// feu : la densité ne s'effondre pas avec la distance (le flux porte jusqu'à la cible, comme le sort Flames) ;
	// tt_d = distance « vieillie » : le feu ne se défait vraiment que sur le dernier cinquième
	// (spray : les vagues se trouent davantage en s'éloignant, la visée reste lisible au bout)
	float tt_d = ecole == 0 ? t * (bouffees > 0.0 ? 1.0 : 0.35) : t;
	// trous dans le corps (là où le bruit est faible) : des langues séparées, pas un tube plein
	corps -= max(0.0, 0.42 - n) * (1.2 + 2.0 * tt_d) + max(0.0, 0.3 - f) * 0.8 * tt_d;
	if (bouffees > 0.0) {
		// spray : entre deux vagues, la matière s'amincit (cols) ; dans chaque vague, des trous qui s'ouvrent en
		// s'éloignant (volutes, langues séparées) ; près de la paume le cœur reste plein
		corps -= max(0.0, 0.5 - n) * 1.6 * smoothstep(0.1, 0.6, t) + max(0.0, puff_d - 0.55) * 0.5 * smoothstep(0.05, 0.3, t);
	}
	// langues qui s'échappent des bords : filaments fins, étirés dans le sens du flux et tordus par le même champ
	// (domain warp), qui débordent du cône puis se détachent
	float lg = mbruit(vec2(ul * 1.8, s * 11.0 + (w.y - 0.5) * 7.0 + graine * 5.0));
	lg = lg * 0.7 + mbruit(vec2(ul * 2.6, s * 17.0 + w.x * 4.0)) * 0.3;   // contour irrégulier
	// (spray : la distance qui compte est celle au bord des bouffées, les langues lèchent chaque vague)
	float a_l = bouffees > 0.0 ? mix(as / ouvre, puff_d, smoothstep(0.02, 0.18, t)) * 0.8 : as;
	float langue = (lg - 0.62) * 3.4 - max(0.0, a_l - 0.55) * (1.1 - 0.4 * t) + (g - 0.5) * 0.2;
	corps = max(corps, langue * smoothstep(0.04, 0.25, t));
	// fragmentation en bout : des trous s'ouvrent, le jet se défait en lambeaux qui continuent d'avancer
	float bout_jet = sens > 0.0 ? smoothstep(ecole == 0 ? 0.82 : 0.62, 1.02, t) : 1.0 - smoothstep(-0.02, 0.38, t);
	corps -= bout_jet * (0.25 + (1.0 - n) * 0.85 + (0.5 - f) * 0.3) * (1.0 - etale * 0.45);
	// pas de coupure nette au bout : le jet s'éteint (moins quand il s'étale contre une surface)
	if (sens > 0.0) {
		corps -= smoothstep(0.86, 1.0, t) * (1.0 - etale * 0.6) * 0.9;
	} else {
		// drain : la matière naît dans la cible (ou dans le vide) en lambeaux, pas sur un bord vertical
		corps -= smoothstep(0.78, 1.0, t) * (0.35 + (1.0 - n) * 0.6) * (1.0 - etale * 0.7);
	}
	// pas de bord droit du ruban : la matière s'efface avant la marge
	corps -= smoothstep(marge - 0.3, marge, as) * 1.5;
	// naissance dans la paume : le cône part d'un point dense
	corps *= smoothstep(0.0, 0.03, t) * force;
	if (corps < 0.02) {
		discard;
	}
	// occlusion après le motif : les pixels jetés ne la paient pas
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	// bord doux sur 2 pixels environ (pas d'escalier dur, pas de flou)
	float k = smoothstep(0.02, 0.16, corps);
	vec3 c;
	float al;
	if (ecole == 2) {
		// ténèbres (cf. tenebres_fps_1100.jpg) : lueur violette translucide, traversée de volutes de fumée NOIRE
		// couvrantes (crêtes du bruit transporté vers la main), rehauts presque blancs sur les filaments
		float fumee = smoothstep(0.5, 0.68, n + (f - 0.5) * 0.35) * (1.0 - smoothstep(0.75, 1.15, as));
		float lueur = clamp((1.0 - as * 0.8) * 0.7 + (f - 0.5) * 0.6, 0.0, 1.0);
		vec3 viol = mix(c3.rgb, mix(c2.rgb, c1.rgb, step(0.72, lueur)), clamp(lueur * 1.3, 0.0, 1.0));
		c = viol * (0.45 + lueur * 1.1) * (1.0 - fumee) * eclat;
		if (g > 0.84 && f > 0.6 && fumee < 0.5) {
			c = c1.rgb * eclat;
		}
		c += c5.rgb * fumee * 0.8;
		al = mix(0.15, 0.85, fumee);
		// près de la main, la matière aspirée se resserre et s'éclaire (elle se fond dans le vortex de la paume)
		c *= mix(1.4, 1.0, smoothstep(0.0, 0.3, t));
	} else {
		// température : chaud sur l'axe et près de la paume, refroidit vers les bords et le bout
		// la température suit le bruit transporté : des langues jaunes, orange et rouges qui filent dans le jet
		float h = (1.0 - as) * 0.32 + corps * 0.3 + (n - 0.5) * 1.1 + (f - 0.5) * 0.5 + (g - 0.5) * 0.12
			- tt_d * 0.35 + (1.0 - t) * (1.0 - t) * pow(max(1.0 - as, 0.0), 3.0) * 0.5;
		if (ecole == 0 && bouffees > 0.0) {
			// feu en spray : blanc-jaune dans la paume, orange au milieu, rouge sombre au bout ; chaque vague a sa
			// propre température (puff_h) et refroidit de son bord vers son cœur
			h = (1.0 - as) * 0.2 + corps * 0.3 + (n - 0.5) * 1.25 + (f - 0.5) * 0.5 + (g - 0.5) * 0.12
				- t * 0.38 + 0.1 + (puff_h - 0.5) * 0.25
				+ (1.0 - t) * (1.0 - t) * pow(max(1.0 - as, 0.0), 3.0) * 0.4;
		} else if (ecole == 0) {
			// feu : blanc seulement sur un filet le long de l'axe près de la paume ; le corps reste jaune-orange saturé
			h -= 0.14 + 0.12 * as;
		}
		if (ecole == 1) {
			h = corps * 1.0 + (1.0 - as) * 0.2 - t * 0.2 + (f - 0.5) * 0.3;
		}
		c = rampe(h);
		// couverture et lumière : les bords froids couvrent (fumée rouge sombre), le cœur chaud éclaire (additif) ;
		// sortie prémultipliée « mixte » (rgb > alpha), partagée par magie_compose en couverture + lumière
		al = clamp(0.5 - h * 0.4, 0.12, 0.42);
		// les parties froides s'effacent (pas de nappe translucide autour du jet) : fumée seulement par endroits
		if (bouffees <= 0.0) {
			k *= smoothstep(0.0, 0.3, h + (n - 0.5) * 0.4 + (ecole == 0 ? 0.12 + t * 0.15 : 0.0));
		}
		if (ecole == 0 && bouffees > 0.0) {
			// feu en spray : flamme COUVRANTE (on ne voit pas le décor au travers du corps), lumière seulement sur les
			// parties chaudes (sinon tout sature en blanc laiteux) ; la structure vient des trous et des vagues, la
			// fumée rouge sombre s'amincit au bout (le jet s'ouvre, la visée reste lisible)
			al = clamp(0.68 + h * 0.3, 0.55, 0.95) * (1.0 - 0.3 * smoothstep(0.6, 1.0, t));
			k *= smoothstep(-0.25, 0.05, h + (n - 0.5) * 0.3);
		} else if (ecole == 0) {
			// feu : à l'intérieur du cône, les creux froids sont des trous de lumière (on voit au travers), pas de la
			// suie opaque ; un peu de fumée rouge sombre seulement sur le pourtour et vers le bout
			al = clamp(0.3 - h * 0.3, 0.05, 0.24) * mix(0.35, 1.0, smoothstep(0.35, 0.9, as + t * 0.3));
			k *= smoothstep(-0.05, 0.28, h + (n - 0.5) * 0.3 + (1.0 - as) * 0.1 + t * 0.15);
		}
		float lum = clamp(h, 0.0, 1.3) * 0.6;
		if (ecole == 0 && bouffees > 0.0) {
			lum = clamp(h - 0.35, 0.0, 1.0) * 0.55;
		}
		if (ecole == 1) {
			al = clamp(0.5 - h * 0.25, 0.1, 0.45);
			lum = clamp(h, 0.0, 1.2) * 0.35;
			if (g > 0.82) {
				lum += 0.6;
			}
		} else if (ecole == 3) {
			al *= 0.35;
			lum *= 0.8;
		}
		c *= (al + lum) * eclat;
	}
	ALBEDO = c * k;
	ALPHA = al * k;
}
