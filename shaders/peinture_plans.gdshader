// PEINTURE du lointain (refonte « lumière », 8e passe) : chaque plan peint (voir plans_peints.gdshader) est dessiné UNE
// FOIS au démarrage dans une texture 2 160 x H (1 texel = 1/6° d'azimut x 1/6° d'élévation, exactement les texels du
// cylindre : aucune interpolation, aucun scintillement). Tout le détail coûteux est ici, gratuit à l'exécution :
// silhouettes à sommets secondaires, normale fictive à plusieurs échelles (facettes, éperons, ravines, strates,
// granulation), couloirs de neige, barres rocheuses, contours entre massifs étagés, sapins individuels en rangs, château.
// Sortie (RGBA8, valeurs brutes) :
//   A = classe : 0 vide | 0,25 montagne | 0,5 forêt | 0,75 château / falaise | 1 fenêtre
//   G, B = normale fictive (x vers l'azimut croissant, y vers le haut), codée 0..1
//   R = montagne : < 0,5 roche (clarté R/0,45), >= 0,5 neige (clarté (R-0,5)/0,5)
//       forêt : < 0,5 ramure (profondeur R/0,45 : 0 devant, 1 au fond), >= 0,5 neige sur les branches (idem)
//       château : 0,1 pierre | 0,4 toit enneigé | 0,6 roche de falaise | 0,8 sapin de falaise | 0,95 corniche de neige
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform float el0_t = -36.0;            // texel d'élévation de la rangée 0 (en 1/6°)
uniform int genre = 0;                  // 0 montagnes, 1 forêt, 2 forêt + château
uniform float base_el = 1.0;
uniform float dentelure = 0.3;
uniform int nb_pics = 0;
uniform vec4 pics[16];                  // azimut (°), élévation du sommet (°), demi-largeur (°), dissymétrie (-1..1)
uniform float graine = 0.0;
uniform float chateau_az = 24.0;
uniform float chateau_el = 3.0;
uniform float chateau_ech = 1.5;

const float TEXEL = 6.0;

float h11(float x) {
	return fract(sin(x * 127.1 + graine * 31.7) * 43758.5453);
}

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031 + graine * 0.013);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float b1(float x, float pas) {
	float c = floor(x / pas);
	float f = fract(x / pas);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h11(c), h11(c + 1.0), f);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float rid(float x, float pas) {
	float r = 1.0 - abs(2.0 * b1(x, pas) - 1.0);
	return r * r;
}

float wrapd(float a) {
	return mod(a + 180.0, 360.0) - 180.0;
}

// bruit de crête commun (mêmes formules que arriere_plan._colonnes, pour que les bornes du maillage restent valables)
float crete_nz(float x) {
	return 0.10 * (b1(x, 70.0) - 0.5) + 0.05 * (b1(x, 23.0) - 0.5) - 0.04 * rid(x + 11.0, 15.0)
		+ 0.05 * rid(x, 9.0) + 0.02 * rid(x + 5.0, 4.0) + 0.05 * floor(b1(x, 17.0) * 3.0) / 3.0;
}

// profil d'un massif (°) à l'écart d'azimut d : pic, épaule, sous-sommet + 3 sommets secondaires en couches
float massif(vec4 p, float d, float i, out float w) {
	w = 1.5 * p.z * (d < 0.0 ? 1.0 - 0.35 * p.w : 1.0 + 0.35 * p.w);
	float e = p.y * (1.0 - abs(d) / w);
	e = max(e, p.y * 0.62 * (1.0 - abs(d - sign(d) * w * 0.45) / (w * 0.55)));
	float cs = p.w >= 0.0 ? 1.0 : -1.0;
	e = max(e, p.y * 0.82 * (1.0 - abs(d - cs * w * 0.42) / (w * 0.3)));
	for (int s = 0; s < 3; s++) {
		float fs = float(s) + i * 7.0;
		float o = (h11(fs * 3.7 + 1.0) - 0.5) * 1.2 * w;
		float hs = p.y * (0.55 + 0.35 * h11(fs * 5.3 + 2.0));
		float ws = w * (0.16 + 0.15 * h11(fs * 9.1 + 3.0));
		e = max(e, hs * (1.0 - abs(d - o) / ws));
	}
	return e;
}

// hauteur fictive de la face (°) : cône d'arête, éperons diagonaux (3 échelles), contreforts, ravines, strates,
// granulation. La normale en est tirée par différences d'un texel.
float champ(float azt, float elt, float paz, float pe, float w) {
	float u = (azt - paz) / TEXEL;
	float t = max(pe - elt / TEXEL, 0.0);
	float au = abs(u);
	float cote = u < 0.0 ? 0.0 : 57.0;
	float f = -au * (pe / w) * 0.9 - 0.55 * elt / TEXEL;
	float q = (au - 0.75 * t) * TEXEL;
	f += 3.2 * rid(q + cote + graine * 13.0, 26.0) + 1.1 * rid(q * 1.7 + cote + 91.0, 11.0) + 0.45 * rid(q * 3.1 + cote + 17.0, 6.0);
	float q2 = (au + 0.5 * t) * TEXEL;
	f += 1.0 * rid(q2 + cote + 33.0, 19.0);
	f -= 0.5 * rid(azt + 0.3 * elt + 71.0, 7.0) * smoothstep(0.5, 3.0, t);        // ravines
	f += 0.25 * n2(vec2(azt / 16.0, elt / 2.5 + 3.0 * n2(vec2(azt / 40.0, 7.0))));
	f += 0.18 * n2(vec2(azt / 5.0, elt / 4.0) + 50.0);
	return f;
}

vec4 coder(float classe, vec3 n, float r) {
	return vec4(clamp(r, 0.0, 1.0), n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, classe);
}

void fragment() {
	float az_t = floor(FRAGCOORD.x) - 1080.0 + 0.5;
	float el_t = el0_t + floor(FRAGCOORD.y) + 0.5;
	float az = az_t / TEXEL;
	float el = el_t / TEXEL;
	vec4 sortie = vec4(0.0);

	float nz = crete_nz(az_t);
	float jz = dentelure * (0.9 * (b1(az_t, 3.0) - 0.5) + 0.5 * (h11(az_t) - 0.5));
	float crete = base_el + dentelure * (0.6 * b1(az_t, 9.0) + 0.4 * b1(az_t, 3.0));
	float creuse = (genre == 0 ? 4.0 : 3.5) * (1.0 - smoothstep(5.0, 16.0, abs(wrapd(az - 46.0))));

	if (genre == 0) {
		// --- montagnes : massifs étagés (le plus bas devant), contour sombre où il recouvre celui de derrière
		float pic_el = -1.0;
		float pic_d = 0.0;
		float pic_w = 1.0;
		float pic_az = 0.0;
		float avant_h = 1e5;
		int couvrent = 0;
		float max_e = -1.0;
		float max_d = 0.0;
		float max_w = 1.0;
		float max_az = 0.0;
		for (int i = 0; i < 16; i++) {
			if (i >= nb_pics) {
				break;
			}
			vec4 p = pics[i];
			float d = wrapd(az - p.x);
			float w;
			float e = massif(p, d, float(i), w);
			float hl = max(e - base_el, 0.0);
			e += hl * nz + (hl > 0.0 ? jz : 0.0);
			crete = max(crete, e);
			if (e > max_e) {
				max_e = e; max_d = d; max_w = w; max_az = p.x;
			}
			if (el <= e && hl > 0.0) {
				couvrent++;
				if (p.y < avant_h) {
					avant_h = p.y; pic_el = e; pic_d = d; pic_w = w; pic_az = p.x;
				}
			}
		}
		if (couvrent == 0) {
			pic_el = max_e; pic_d = max_d; pic_w = max_w; pic_az = max_az;
			crete -= creuse * step(pic_el, base_el + dentelure + 0.01);
		}
		if (el <= crete) {
			float paz_t = pic_az * TEXEL;
			float f0 = champ(az_t, el_t, paz_t, pic_el, pic_w);
			float fu = (champ(az_t + 1.0, el_t, paz_t, pic_el, pic_w) - f0) * TEXEL;
			float fv = (champ(az_t, el_t + 1.0, paz_t, pic_el, pic_w) - f0) * TEXEL;
			vec3 n = normalize(vec3(-fu, -fv, 1.0));
			// volume : la normale de détail est ramenée vers celle de la face (côté du pic), pour garder deux grands
			// pans lumière / ombre que les facettes ne font que moduler
			vec3 n_face = normalize(vec3(-sign(pic_d + 0.0001) * 0.85, 0.35, 0.45));
			n = normalize(mix(n_face, n, 0.45));
			float prof = pic_el - el;
			float rel = clamp(prof / max(pic_el - base_el, 0.5), 0.0, 1.0);
			float q = (abs(pic_d) - 0.75 * prof) * TEXEL;
			float cote_e = pic_d < 0.0 ? 0.0 : 57.0;
			float faite = rid(q + cote_e + graine * 13.0, 26.0);
			float faite2 = rid(q * 1.7 + cote_e + 91.0, 11.0);
			float faite3 = rid(q * 3.1 + cote_e + 17.0, 6.0);
			float barre = step(0.66, n2(vec2(az_t / 12.0, el_t / 1.6) + 70.0)) * step(0.12, rel);
			// couloirs de neige : suivent la pente (penchés vers l'extérieur), effilés, longueurs variées, ondulés
			float xc = az_t - sign(pic_d) * prof * TEXEL * 0.3 + 2.5 * (n2(vec2(el_t / 6.0, az_t / 30.0)) - 0.5);
			float col_c = floor(xc / 4.0);
			float lg = 0.15 + 0.5 * h11(col_c + 21.0);
			float couloir = step(0.5, h11(col_c * 1.7 + 3.0)) * step(rel, lg)
				* step(abs(fract(xc / 4.0) - 0.5), 0.12 + 0.22 * (1.0 - rel / max(lg, 0.01)));
			float tache = n2(vec2(az_t / 6.0, el_t / 3.0) + 20.0);
			float sn = 0.7 * n.y + 0.35 * (1.0 - faite) + 0.45 * (1.0 - rel) + 0.45 * (tache - 0.5);
			float neige = max(step(0.88, sn), couloir * step(faite, 0.82))
				* step(faite, 0.78) * step(faite2, 0.86) * (1.0 - barre);
			// clarté : plus sombre vers le pied, lignes de roche, barres, contour ; granulation par texel (fixe)
			float b = 1.0 - 0.35 * rel;
			if ((faite > 0.84 || faite2 > 0.92 || faite3 > 0.95) && rel > 0.05) {
				b *= 0.5;
				neige = 0.0;
			} else if (barre > 0.5) {
				b *= 0.72;
			}
			if (couvrent >= 2 && el > pic_el - 1.0 / TEXEL) {
				b *= 0.45;
				neige = 0.0;
			}
			b *= 0.86 + 0.14 * h21(vec2(az_t, el_t) + 7.0);
			// liseré : le texel de crête prend la pente vers l'extérieur (éclairé d'un côté, sombre de l'autre)
			if (el > crete - 1.0 / TEXEL) {
				n = normalize(vec3(sign(-pic_d + 0.0001) * -0.9, 0.5, 0.4));
			}
			sortie = coder(0.25, n, neige > 0.5 ? 0.5 + 0.5 * b : 0.45 * b);
		}
	} else {
		// --- forêt : 3 rangs de sapins individuels (le plus proche devant, plus grand, plus bas), ramures en
		// étages, neige au bord des branches ; sous les rangs, masse boisée
		for (int i = 0; i < 16; i++) {
			if (i >= nb_pics) {
				break;
			}
			vec4 p = pics[i];
			float w;
			float e = massif(p, wrapd(az - p.x), float(i), w);
			crete = max(crete, e);
		}
		crete -= creuse;
		if (genre == 2) {
			crete = min(crete, mix(crete, chateau_el + 0.4, 1.0 - smoothstep(9.0, 15.0, abs(wrapd(az - chateau_az)))));
		}
		float trouve = 0.0;
		vec3 n = vec3(0.0, 0.3, 0.95);
		float r = 0.0;
		for (int k = 2; k >= 0; k--) {
			float fk = float(k);
			float larg = 3.0 + fk;                                   // pas des sapins (texels)
			float ligne = crete - fk * 1.1;                         // pied du rang (le rang 0 est au fond, en haut)
			float x = az_t + fk * 17.0;
			float cell = floor(x / larg);
			float xx = x - cell * larg - larg * 0.5 + (h11(cell * 1.3 + fk) - 0.5);
			float ht = (5.0 + 6.0 * h11(cell + 7.0 + fk * 11.0)) * (0.8 + 0.25 * fk);   // hauteur (texels)
			float y = el_t - ligne * TEXEL;                          // hauteur au-dessus du pied du rang
			if (trouve < 0.5 && y < ht && y > -1.0) {
				float etage = fract(y / 2.5);
				float hw = (larg * 0.62 + 0.5) * (1.0 - y / ht) * (0.72 + 0.28 * (1.0 - etage));
				if (abs(xx) <= hw) {
					trouve = 1.0;
					n = normalize(vec3(sign(xx) * 0.7 * (1.0 - abs(xx) / max(hw, 0.5)) , 0.35, 0.6));
					float prof_r = (2.0 - fk) / 2.0;                // 0 devant, 1 au fond
					bool neige = etage > 0.62 && abs(xx) > hw - 1.5 && h21(vec2(az_t, el_t) + fk) > 0.35;
					neige = neige || (y > ht - 1.5 && h11(cell + 3.0) > 0.5);
					r = neige ? 0.5 + 0.45 * prof_r : 0.45 * prof_r;
				}
			}
		}
		if (trouve < 0.5 && el_t < (crete - 2.2) * TEXEL) {
			trouve = 1.0;   // masse boisée sous les rangs : ramure sombre, quelques touches de neige
			bool neige = h21(vec2(az_t, el_t) + 5.0) > 0.86;
			n = vec3(0.0, 0.2, 0.98);
			r = neige ? 0.5 : 0.05;
		}
		if (trouve > 0.5) {
			sortie = coder(0.5, n, r);
		}
		// --- château (plan genre 2) : falaise sombre et boisée, enceinte crénelée, tours, toits, fenêtres
		if (genre == 2) {
			float ch = 0.0;
			float dx = floor(wrapd(az - chateau_az) * TEXEL / chateau_ech) + 0.5;
			float dy = floor((el - chateau_el) * TEXEL / chateau_ech) + 0.5;
			float hf = 32.0;
			float demi_f = mix(40.0, 23.0, clamp(dy / hf, 0.0, 1.0)) + 2.0 * (b1(dy + 3.0, 3.0) - 0.5);
			if (dy >= 0.0 && dy < hf && abs(dx) < demi_f) {
				ch = 4.0;
			}
			float yb = hf;
			if (abs(dx) < 20.0 && dy >= yb && dy < yb + 7.0) {
				ch = 1.0;
			}
			if (abs(dx) < 20.0 && dy >= yb + 7.0 && dy < yb + 9.0 && mod(floor(dx + 20.0), 4.0) < 2.0) {
				ch = 1.0;
			}
			vec4 tours[5] = vec4[5](vec4(-19.0, 3.0, 17.0, 1.0), vec4(-7.0, 3.0, 13.0, 0.0), vec4(5.0, 4.0, 24.0, 1.0),
				vec4(18.0, 3.0, 15.0, 0.0), vec4(12.0, 2.0, 19.0, 1.0));
			for (int k = 0; k < 5; k++) {
				vec4 t = tours[k];
				float lx = dx - t.x;
				if (abs(lx) <= t.y && dy >= yb && dy < yb + t.z) {
					ch = 1.0;
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
					ch = 1.0;
				}
			}
			vec3 nc = vec3(dx < 0.0 ? 0.6 : -0.6, 0.2, 0.77);
			if (ch > 3.5) {
				float vire = fract(dy / 6.0);
				float cell_s = floor(dx / 3.0);
				float hs = (2.0 + 3.0 * h11(cell_s + floor(dy / 6.0) * 13.0)) / 6.0;
				float dent = 1.0 - abs(fract(dx / 3.0) - 0.5) * 2.0;
				float r_c = h21(vec2(floor(dx / 3.0), 3.0)) > 0.65 ? 0.55 : 0.6;
				if (vire < hs * dent && h11(cell_s * 3.1 + floor(dy / 6.0)) > 0.3) {
					r_c = 0.8;
				} else if (h21(vec2(floor(dx / 5.0), floor(dy / 6.0))) > 0.8 && vire < 0.12) {
					r_c = 0.95;
				}
				sortie = coder(0.75, nc, r_c);
			} else if (ch > 2.5) {
				sortie = coder(1.0, nc, 0.0);
			} else if (ch > 1.5) {
				sortie = coder(0.75, nc, 0.4);
			} else if (ch > 0.5) {
				sortie = coder(0.75, nc, 0.1);
			}
		}
	}
	COLOR = sortie;
}
