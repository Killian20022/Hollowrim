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

// bruit de valeur 2D lisse (réseau entier, en texels)
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// crête 1D (0..1, pointue en 1) : arêtes
float rid(float x, float pas) {
	float r = 1.0 - abs(2.0 * b1(x, pas) - 1.0);
	return r * r;
}

// HAUTEUR FICTIVE de la face (°, « vers l'observateur ») au texel (azt, elt), pour le pic de sommet (paz, pe), demi-largeur w :
// arête centrale (cône), arêtes secondaires qui descendent en diagonale vers l'extérieur (éperons), strates
// horizontales, bosselage fin. La normale est tirée de ses différences : facettes, ressauts, creux enneigés.
float champ(float azt, float elt, float paz, float pe, float w) {
	float u = (azt - paz) / TEXEL;                  // ° depuis l'axe du pic
	float t = max(pe - elt / TEXEL, 0.0);           // ° sous le sommet
	float au = abs(u);
	float cote = u < 0.0 ? 0.0 : 57.0;
	float f = -au * (pe / w) * 0.9 - 0.55 * elt / TEXEL;      // cône + face qui se couche vers le haut
	// éperons : lignes |u| - 0,75 t = constante (descendent en s'écartant de l'arête centrale), deux échelles
	float q = (au - 0.75 * t) * TEXEL;
	f += 3.2 * rid(q + cote + graine * 13.0, 26.0) + 1.1 * rid(q * 1.7 + cote + 91.0, 11.0);
	// contreforts dans l'autre sens (facettes en losange), plus faibles
	float q2 = (au + 0.5 * t) * TEXEL;
	f += 1.0 * rid(q2 + cote + 33.0, 19.0);
	// strates : bancs horizontaux un peu ondulés, et bosselage
	f += 0.25 * n2(vec2(azt / 16.0, elt / 2.5 + 3.0 * n2(vec2(azt / 40.0, 7.0))));
	f += 0.15 * n2(vec2(azt / 8.0, elt / 6.0) + 50.0);
	return f;
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

	// --- profil (6e passe) : pied + grands massifs (pic, sous-sommet, épaule) + crête fractale commune.
	// Les massifs sont ÉTAGÉS : le plus bas est devant (il chevauche le plus haut), avec un contour sombre.
	float crete = base_el + dentelure * (0.6 * b1(az_t, 9.0) + 0.4 * b1(az_t, 3.0));
	float nz = 0.10 * (b1(az_t, 70.0) - 0.5) + 0.05 * (b1(az_t, 23.0) - 0.5) - 0.04 * rid(az_t + 11.0, 15.0)
		+ 0.05 * rid(az_t, 9.0) + 0.02 * rid(az_t + 5.0, 4.0) + 0.05 * floor(b1(az_t, 17.0) * 3.0) / 3.0;
	float jz = dentelure * (0.9 * (b1(az_t, 3.0) - 0.5) + 0.5 * (h11(az_t) - 0.5));
	float pic_el = -1.0;
	float pic_d = 0.0;      // écart d'azimut au sommet (°), signé
	float pic_w = 1.0;
	float pic_az = 0.0;
	float avant_h = 1e5;    // hauteur du massif de devant retenu
	int couvrent = 0;       // massifs dont la silhouette couvre ce texel
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
		float w = 1.5 * p.z * (d < 0.0 ? 1.0 - 0.35 * p.w : 1.0 + 0.35 * p.w);
		float e = p.y * (1.0 - abs(d) / w);
		e = max(e, p.y * 0.62 * (1.0 - abs(d - sign(d) * w * 0.45) / (w * 0.55)));   // épaule
		float cs = p.w >= 0.0 ? 1.0 : -1.0;
		e = max(e, p.y * 0.82 * (1.0 - abs(d - cs * w * 0.42) / (w * 0.3)));         // sous-sommet
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
	}
	bool contour = couvrent >= 2 && el > pic_el - 1.0 / TEXEL;
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
	// 5e passe : creux dans l'axe de la vallée de l'entrée (≈ 46°) et, pour la forêt devant le château, dans l'axe
	// du château (24°) : bande dorée, forêts du fond et falaise lisibles
	float creuse = (genre == 0 ? 4.0 : 3.5) * (1.0 - smoothstep(5.0, 16.0, abs(wrapd(az - 46.0))));
	if (genre == 1) {
		creuse = max(creuse, 4.5 * (1.0 - smoothstep(7.0, 14.0, abs(wrapd(az - chateau_az)))));
	}
	crete -= creuse * (genre == 0 ? 1.0 : 1.0) * step(pic_el, crete + 0.001 + creuse) * (genre == 0 ? 0.0 : 1.0);
	if (genre == 0 && pic_el < base_el + dentelure + 0.01) {
		crete -= creuse;
	}
	if (genre == 2) {
		crete = min(crete, mix(crete, chateau_el + 0.4, 1.0 - smoothstep(9.0, 15.0, abs(wrapd(az - chateau_az)))));
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
			// falaise : roche sombre, sapins accrochés aux vires (dents vert-noir), quelques corniches de neige
			float cote = dx < 0.0 ? 1.0 : 0.5;
			col = vec3(0.034, 0.036, 0.046) * (ambiant * 1.1 + col_lum * 0.45 * cote);
			if (h21(vec2(floor(dx / 3.0), 3.0)) > 0.65) col *= 0.65;                               // fissures verticales
			float vire = fract(dy / 6.0);
			float cell_s = floor(dx / 3.0);
			float hs = (2.0 + 3.0 * h11(cell_s + floor(dy / 6.0) * 13.0)) / 6.0;
			float dent = 1.0 - abs(fract(dx / 3.0) - 0.5) * 2.0;                   // pointe du sapin
			if (vire < hs * dent && h11(cell_s * 3.1 + floor(dy / 6.0)) > 0.3) {
				col = vec3(0.018, 0.032, 0.034) * (ambiant * 1.5 + col_lum * 0.2);
			}
			float corniche = step(0.8, h21(vec2(floor(dx / 5.0), floor(dy / 6.0)))) * step(vire, 0.12);
			col = mix(col, neige_o * (ambiant * 1.2 + col_lum * 0.5 * cote), corniche);
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
		// montagne (5e passe) : normale fictive tirée de champ() par différences d'un texel (fixées sur le cylindre)
		float paz_t = pic_az * TEXEL;
		float f0 = champ(az_t, el_t, paz_t, pic_el, pic_w);
		float fu = (champ(az_t + 1.0, el_t, paz_t, pic_el, pic_w) - f0) * TEXEL;
		float fv = (champ(az_t, el_t + 1.0, paz_t, pic_el, pic_w) - f0) * TEXEL;
		vec3 n = normalize(vec3(-fu, -fv, 1.0));
		// VOLUME : la face du pic tournée vers l'astre est claire et chaude, l'autre bleu-gris ; dégradé en paliers
		// (plus clair près de l'arête et du sommet, plus sombre vers le pied), les facettes ne font que le moduler
		float cs = sign(wrapd(az_soleil - pic_az) + 0.001);
		float face = cs * sign(pic_d + 0.0001) > 0.0 ? 1.0 : 0.0;            // 1 = face au soleil
		vec3 Ld = normalize(vec3(cs * 0.9, 0.35, 0.3));
		float facette = clamp(dot(n, Ld), 0.0, 1.0);
		float prof = pic_el - el;
		float rel = clamp(prof / max(pic_el - base_el, 0.5), 0.0, 1.0);   // 0 au sommet, 1 au pied
		float pres_arete = 1.0 - clamp(abs(pic_d) / max(pic_w * 0.6, 0.5), 0.0, 1.0);
		float dif = face * (0.55 + 0.25 * pres_arete + 0.2 * (1.0 - rel)) * (0.7 + 0.3 * facette)
			+ (1.0 - face) * (0.08 + 0.22 * facette * (1.0 - rel));
		// éperons : lignes qui descendent en s'écartant de l'arête (faîtes rocheux sombres)
		float q = (abs(pic_d) - 0.75 * prof) * TEXEL;
		float cote_e = pic_d < 0.0 ? 0.0 : 57.0;
		float faite = rid(q + cote_e + graine * 13.0, 26.0);
		// neige : couloirs VERTICAUX (1 à 2 texels, longueurs variées), replats, calotte ; roche sur les faîtes
		// (légèrement penchés vers l'extérieur, effilés vers le bas, courts : pas de rayures sur toute la face)
		float xc = az_t - sign(pic_d) * prof * TEXEL * 0.25 + 2.0 * (b1(el_t, 7.0) - 0.5);
		float col_c = floor(xc / 5.0);
		float lg = 0.12 + 0.4 * h11(col_c + 21.0);
		float couloir = step(0.62, h11(col_c * 1.7 + 3.0)) * step(rel, lg)
			* step(abs(fract(xc / 5.0) - 0.5), 0.1 + 0.2 * (1.0 - rel / max(lg, 0.01)));
		float tache = n2(vec2(az_t / 7.0, el_t / 4.0) + 20.0);
		float sn = 0.9 * n.y + 0.35 * (1.0 - faite) + 0.35 * (1.0 - rel) + 0.3 * (tache - 0.5);
		float neige = max(step(0.9, sn), couloir * step(faite, 0.8));
		float ton = floor(clamp(dif, 0.0, 0.999) * 7.0) / 6.0;            // 7 paliers, sans grain par texel
		vec3 neige_chaude = mix(neige_o, neige_c, ton);
		vec3 roche = mix(roche_o * 0.5, roche_c * 0.8, ton);
		vec3 base = neige > 0.5 ? neige_chaude : roche;
		col = base * (ambiant * 1.0 + col_lum * 0.95 * L * (0.2 + 0.8 * ton));
		// faîtes d'éperons rocheux : lignes sombres ; liseré clair sur la crête côté soleil
		if (faite > 0.84 && rel > 0.08) {
			col *= 0.5;
		}
		if (el > crete - 1.0 / TEXEL && face > 0.5) {
			col *= 1.3;
		}
		if (contour) {
			col *= 0.5;   // massif de devant : contour sombre d'un texel sur celui de derrière
		}
		// plafond : la neige lointaine reste rosée / dorée, jamais blanche
		float lc = dot(col, vec3(0.3, 0.55, 0.15));
		col *= min(1.0, 0.48 / max(lc, 0.001));
	}

	// --- perspective aérienne du plan, plus forte au pied (brume de vallée)
	vec2 dh = normalize(wp.xz - CAMERA_POSITION_WORLD.xz + vec2(0.0001));
	float k = smoothstep(-0.2, 1.0, dot(dh, sh));
	vec3 hz = mix(horizon, horizon_chaud, crep * k);
	float pied = 1.0 - smoothstep(base_el - 1.0, base_el + 2.5, el);
	float v = clamp(voile + 0.35 * pied * (1.0 - voile), 0.0, 0.95);
	v *= mix(1.0, 0.72, jour);
	if (ch > 0.5) {
		v *= ch > 3.5 ? 0.35 : 0.6;   // château sombre qui se détache ; falaise encore moins voilée (ses sapins ressortent)
	}   // de jour, le relief se détache mieux des nuages clairs
	if (ch > 2.5 && ch < 3.5) {
		v *= 0.3;   // fenêtres : nettes
	}
	ALBEDO = mix(col, hz, v);
}
