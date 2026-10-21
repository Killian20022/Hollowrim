// Lointain PEINT (refonte « lumière », 4e passe) : au-delà de ~600 m, 5 plans en couches (cylindres centrés sur le
// centre de la carte, voir scripts/arriere_plan.gd) dont l'image est DESSINÉE ici, par texel, au style de la référence :
// grands triangles francs à arête centrale, face au soleil claire et rosée, face à l'ombre bleu-gris foncé, couloirs
// de neige qui rayonnent du sommet le long des pentes, bandes de sapins dentelées, château en silhouette.
// - 1 texel ≈ 1 pixel à 640x360 : grille de 1/6° en azimut et en élévation, fixée sur le cylindre (rien ne dépend de
//   l'écran : pas de scintillement en tournant, la parallaxe vient des rayons différents des plans).
// - Pas de tramage ici (ni Bayer ni bruit) : aplats nets ; le bruit 15 bits de ps1_post fait le reste.
// - Couleurs pilotées chaque image par cycle.gd via arriere_plan.gd (_actualiser) : horizon, lumière, ambiant, crépuscule.
// - Profondeur truquée comme arriere_plan.gdshader : derrière le monde, devant le ciel, tri exact entre plans.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

uniform float rayon = 1000.0;
uniform float niveau0 = 0.0;
uniform int genre = 0;                  // 0 montagnes, 1 forêt (bandes de sapins), 2 forêt + château
uniform float voile = 0.3;              // perspective aérienne propre au plan (0 net, 1 = couleur d'horizon)
uniform float base_el = 1.0;            // élévation du pied du profil (°)
uniform float dentelure = 0.3;          // amplitude du bruit de crête (°)
uniform int nb_pics = 0;
uniform vec4 pics[16];                  // azimut (°), élévation du sommet (°), demi-largeur (°), dissymétrie (-1..1)
uniform float graine = 0.0;
uniform float chateau_az = 24.0;
uniform float chateau_el = 3.0;         // élévation du pied de la falaise du château (°)
uniform float chateau_ech = 1.5;        // taille du château (texels de dessin par texel écran)
// cycle (mêmes noms que arriere_plan.gdshader)
uniform vec3 horizon : source_color = vec3(0.05, 0.075, 0.13);
uniform vec3 horizon_chaud : source_color = vec3(0.05, 0.075, 0.13);
uniform vec3 dir_astre = vec3(-0.8, 0.0, 0.6);
uniform float crep = 0.0;
uniform vec3 haut : source_color = vec3(0.008, 0.012, 0.035);
uniform vec3 dir_lum = vec3(0.3, 0.6, -0.7);
uniform vec3 col_lum : source_color = vec3(0.45, 0.54, 0.75);
uniform vec3 ambiant : source_color = vec3(0.18, 0.22, 0.34);
uniform float jour = 0.0;

varying vec3 wp;

const float TEXEL = 6.0;   // texels par degré (2 160 colonnes au tour)

float h11(float x) {
	return fract(sin(x * 127.1 + graine * 31.7) * 43758.5453);
}

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031 + graine * 0.013);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// bruit 1D lisse (valeurs par cellule de `pas` texels)
float b1(float x, float pas) {
	float c = floor(x / pas);
	float f = fract(x / pas);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h11(c), h11(c + 1.0), f);
}

float wrapd(float a) {
	return mod(a + 180.0, 360.0) - 180.0;
}

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 cp = PROJECTION_MATRIX * vp;
	cp.z = cp.w * (0.02 / max(cp.w, 40.0));
	POSITION = cp;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// texel du cylindre (centre du texel : tout le calcul est constant par texel)
	float az_t = floor(degrees(atan(wp.x, wp.z)) * TEXEL) + 0.5;
	float az = az_t / TEXEL;
	float el_t = floor(degrees(atan(wp.y - niveau0, rayon)) * TEXEL) + 0.5;
	float el = el_t / TEXEL;

	// --- profil : pied + pics triangulaires (le plus haut l'emporte) + dentelure de crête
	float crete = base_el + dentelure * (0.6 * b1(az_t, 9.0) + 0.4 * b1(az_t, 3.0));
	float pic_el = -1.0;
	float pic_d = 0.0;      // écart d'azimut au sommet (°), signé
	float pic_w = 1.0;
	for (int i = 0; i < 16; i++) {
		if (i >= nb_pics) {
			break;
		}
		vec4 p = pics[i];
		float d = wrapd(az - p.x);
		float w = 1.5 * p.z * (d < 0.0 ? 1.0 - 0.35 * p.w : 1.0 + 0.35 * p.w);   // massifs larges
		float e = p.y * (1.0 - abs(d) / w);
		// épaule : une arête secondaire casse le flanc (deux pentes au lieu d'une)
		e = max(e, p.y * 0.62 * (1.0 - abs(d - sign(d) * w * 0.45) / (w * 0.55)));
		// sous-sommet : une seconde pointe franche sur le flanc le plus long
		float cs = p.w >= 0.0 ? 1.0 : -1.0;
		e = max(e, p.y * 0.82 * (1.0 - abs(d - cs * w * 0.42) / (w * 0.3)));
		e += dentelure * 0.5 * (b1(az_t + float(i) * 37.0, 4.0) - 0.5);
		if (e > pic_el) {
			pic_el = e;
			pic_d = d;
			pic_w = w;
			crete = max(crete, e);
		}
	}
	bool foret = genre >= 1;
	float sapin = 0.0;
	if (foret) {
		// bandes de sapins dentelées : un sapin par cellule de 4 à 7 texels, pointe triangulaire
		float cell = floor(az_t / 5.0);
		float larg = 4.0 + floor(h11(cell) * 3.0);
		float x = az_t - cell * 5.0 - 2.5;
		float ht = (5.0 + h11(cell + 7.0) * 7.0) / TEXEL;
		sapin = ht * max(0.0, 1.0 - abs(x) / (larg * 0.5 + 0.5));
		crete += sapin;
	}

	// --- château peint (plan genre 2) : falaise, enceinte crénelée, tours carrées, toits pointus, fenêtres
	float ch = 0.0;          // 1 = pierre du château, 2 = toit enneigé, 3 = fenêtre, 4 = falaise
	float dx = floor(wrapd(az - chateau_az) * TEXEL / chateau_ech) + 0.5;      // texels de dessin
	float dy = floor((el - chateau_el) * TEXEL / chateau_ech) + 0.5;
	if (genre == 2) {
		// falaise : trapèze abrupt (pied 70 texels, tête 46), 26 texels de haut, bords rongés
		float hf = 32.0;
		float demi_f = mix(40.0, 23.0, clamp(dy / hf, 0.0, 1.0)) + 2.0 * (b1(dy + 3.0, 3.0) - 0.5);
		if (dy >= 0.0 && dy < hf && abs(dx) < demi_f) {
			ch = 4.0;
		}
		float yb = hf;   // dessus de la falaise
		// enceinte : mur de 7 texels sur 40 de large, créneaux 2/2
		if (abs(dx) < 20.0 && dy >= yb && dy < yb + 7.0) {
			ch = 1.0;
		}
		if (abs(dx) < 20.0 && dy >= yb + 7.0 && dy < yb + 9.0 && mod(floor(dx + 20.0), 4.0) < 2.0) {
			ch = 1.0;
		}
		// tours : [centre, demi-largeur, hauteur, toit pointu]
		vec4 tours[5] = vec4[5](vec4(-19.0, 3.0, 17.0, 1.0), vec4(-7.0, 3.0, 13.0, 0.0), vec4(5.0, 4.0, 24.0, 1.0),
			vec4(18.0, 3.0, 15.0, 0.0), vec4(12.0, 2.0, 19.0, 1.0));
		for (int k = 0; k < 5; k++) {
			vec4 t = tours[k];
			float lx = dx - t.x;
			if (abs(lx) <= t.y && dy >= yb && dy < yb + t.z) {
				ch = 1.0;
				// fenêtres : 1 texel, deux étages
				if (abs(lx) < t.y - 0.5 && mod(floor(lx + t.y), 2.0) > 0.5 && (floor(dy - yb) == floor(t.z * 0.72) || floor(dy - yb) == floor(t.z * 0.42))) {
					ch = 3.0;
				}
			}
			if (t.w > 0.5) {
				float top = yb + t.z;
				float hr = (t.y + 1.0) * 1.6;
				if (dy >= top && dy < top + hr && abs(lx) <= (t.y + 1.0) * (1.0 - (dy - top) / hr)) {
					ch = 2.0;
				}
			} else if (abs(lx) <= t.y && dy >= yb + t.z && dy < yb + t.z + 2.0 && mod(floor(lx + t.y), 2.0) < 1.0) {
				ch = 1.0;   // créneaux des tours
			}
		}
	}

	if (el > crete && ch < 0.5) {
		discard;
	}

	// --- matières et lumière
	vec2 sh = normalize(dir_astre.xz + vec2(0.0001));
	float az_soleil = degrees(atan(sh.x, sh.y));
	float L = max(dot(normalize(dir_lum), vec3(0.0, 0.3, 0.0)) + 0.7, 0.0);  // force de l'astre (bas sur l'horizon)
	vec3 roche_o = vec3(0.030, 0.037, 0.058);   // face à l'ombre : bleu-gris foncé
	vec3 roche_c = vec3(0.090, 0.090, 0.105);   // face au soleil
	vec3 neige_o = vec3(0.20, 0.24, 0.34);
	vec3 neige_c = vec3(0.62, 0.62, 0.68);
	vec3 col;
	if (ch > 0.5) {
		vec3 pierre = vec3(0.045, 0.048, 0.060);
		col = pierre * (ambiant * 1.4 + col_lum * 0.25);
		if (ch > 3.5) {
			// falaise : roche striée verticalement, corniches de neige (lignes de 1 texel), côté gauche éclairé
			float cote = dx < 0.0 ? 1.0 : 0.55;
			col = vec3(0.060, 0.062, 0.075) * (ambiant * 1.2 + col_lum * 0.6 * cote);
			if (h21(vec2(floor(dx / 2.0), 3.0)) > 0.6) col *= 0.6;                                // fissures verticales
			float corniche = step(0.72, h21(vec2(floor(dx / 5.0), floor(dy / 3.0)))) * step(fract(dy / 3.0), 0.34);
			col = mix(col, neige_o * (ambiant * 1.3 + col_lum * 0.7 * cote), corniche);
		} else if (ch > 2.5) {
			col = mix(col, vec3(1.6, 0.9, 0.4), 0.95 * (1.0 - jour));
		} else if (ch > 1.5) {
			col = neige_o * (ambiant * 1.3 + col_lum * 0.5);
		}
	} else if (foret) {
		// sapins : vert-noir bleuté, givre en pointe, quelques troncs de neige entre deux
		vec3 f = vec3(0.022, 0.040, 0.045);
		float givre = step(0.82, h21(vec2(az_t, el_t)) ) * step(crete - 2.5 / TEXEL, el);
		col = mix(f, neige_o * 0.8, givre) * (ambiant * 1.6 + col_lum * 0.25);
		if (el < base_el - 0.2) {
			col = mix(col, neige_o * (ambiant * 1.4 + col_lum * 0.3), 0.35);   // pied de la bande : neige dans le sous-bois
		}
	} else {
		// montagne : face éclairée = côté du sommet tourné vers l'astre
		float cote_soleil = sign(wrapd(az_soleil - (az - pic_d)));
		bool eclaire = sign(pic_d) == cote_soleil || abs(pic_d) < 0.5 / TEXEL && cote_soleil > 0.0;
		float prof = pic_el - el;                    // profondeur sous le sommet (°)
		float rel = prof / max(pic_el - base_el, 0.5);   // 0 au sommet, 1 au pied
		// couloirs : traits qui rayonnent du sommet (a constant le long d'une droite issue du sommet), serrés et fins
		// comme dans la référence : la face est striée de neige sur toute sa hauteur, plus large près du sommet
		float a = pic_d / max(prof, 0.05);
		float fa = a * 13.0 + graine * 3.0;
		float couloir = step(0.5, h11(floor(fa)));
		float largeur = 0.10 + 0.3 * (1.0 - rel) + 0.15 * h11(floor(fa) + 5.0);
		couloir *= step(abs(fract(fa) - 0.5), largeur * 0.5);
		// les couloirs s'arrêtent à des hauteurs différentes (cassures) et se perdent dans le pied
		couloir *= step(rel, 0.55 + 0.4 * h11(floor(fa) + 19.0));
		// éperons rocheux : une nervure sombre sur deux le long du flanc
		float nervure = step(0.7, h11(floor(a * 5.0 + graine) + 41.0)) * step(abs(fract(a * 5.0 + graine) - 0.5), 0.08);
		// névés : plaques de neige par cellules de 4x2 texels sur la moitié haute
		float neve = step(0.9, h21(vec2(floor(az_t / 7.0), floor(el_t / 3.0)))) * step(rel, 0.6) * step(0.5, h11(floor(fa) + 3.0));
		// calotte : neige jusqu'à 18-30 % sous le sommet, bord dentelé
		float calotte = step(rel, 0.10 + 0.10 * b1(az_t, 5.0));
		float neige = max(max(calotte, couloir), neve) * (1.0 - nervure * step(0.12, rel));
		vec3 lum = eclaire ? ambiant * 1.0 + col_lum * 0.9 * L : ambiant * 0.9;
		col = (neige > 0.5 ? (eclaire ? neige_c : neige_o) : (eclaire ? roche_c : roche_o)) * lum;
		// arête centrale : un liseré clair d'un texel côté éclairé
		if (eclaire && abs(pic_d) < 1.0 / TEXEL) {
			col *= 1.25;
		}
		// plafond : la neige lointaine reste rosée / dorée, jamais blanche
		float lc = dot(col, vec3(0.3, 0.55, 0.15));
		col *= min(1.0, 0.42 / max(lc, 0.001));
	}

	// --- perspective aérienne du plan, plus forte au pied (brume de vallée)
	vec2 dh = normalize(wp.xz - CAMERA_POSITION_WORLD.xz + vec2(0.0001));
	float k = smoothstep(-0.2, 1.0, dot(dh, sh));
	vec3 hz = mix(horizon, horizon_chaud, crep * k);
	float pied = 1.0 - smoothstep(base_el - 1.0, base_el + 2.5, el);
	float v = clamp(voile + 0.35 * pied * (1.0 - voile), 0.0, 0.95);
	if (ch > 2.5 && ch < 3.5) {
		v *= 0.3;   // fenêtres : nettes
	}
	ALBEDO = mix(col, hz, v);
}
