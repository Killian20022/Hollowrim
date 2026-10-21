// Ciel nordique : dégradé, bande dorée au crépuscule, étoiles, lune, aurore, et NUAGES EN DEUX COUCHES (refonte « nuages ») :
//  - couche basse (strato-cumulus) : projetée sur un vrai plan haut (les formes s'aplatissent et rapetissent vers l'horizon),
//    densité variable avec de grandes trouées, bords effilochés et transparents, dessous sombre, bords et touches de lumière
//    côté astre (liserés orange/roses au couchant), modelé en 7 tons doux ;
//  - couche haute (cirrus) : voiles fins très étirés dans le sens du vent, plus lents (parallaxe) ;
//  - les deux couches dérivent avec le vent et se déforment lentement (octaves animées à des vitesses différentes) ;
//  - anti-scintillement : chaque octave s'efface quand elle devient plus fine que le pixel (empreinte analytique du pixel
//    sur le plan des nuages), puis voile de brume à l'horizon.
// L'aurore est posée au nord (-Z). Aucun tramage ici (le tramage par bruit est dans ps1_post).
shader_type sky;

uniform vec3 aurore_bas : source_color = vec3(0.15, 1.0, 0.55);
uniform vec3 aurore_haut : source_color = vec3(0.55, 0.2, 0.95);
uniform float aurore_force = 1.0;
uniform float jour = 0.0;     // 0 nuit, 1 plein jour (couvert)
uniform float crep = 0.0;     // lueur crépusculaire / aube, 0..1
uniform float soleil = 0.0;   // l'astre dessiné : 0 lune, 1 soleil
// couleurs courantes fixées par cycle.gd (l'horizon « froid » est aussi la couleur du brouillard : aucun raccord)
uniform vec3 horizon_courant : source_color = vec3(0.05, 0.075, 0.13);
uniform vec3 horizon_chaud : source_color = vec3(0.05, 0.075, 0.13);
uniform vec3 haut_courant : source_color = vec3(0.008, 0.012, 0.035);
uniform vec3 dir_astre = vec3(-0.8, 0.0, 0.6);  // direction horizontale du soleil (ou de la lune)
uniform float couverture = 1.0;  // 1 = couche de nuages normale, <1 = ciel plus dégagé
uniform float temps_force = -1.0;  // ≥ 0 : temps des nuages imposé (captures reproductibles) ; < 0 : TIME
uniform vec2 vent = vec2(0.94, 0.34);  // direction du vent dans le plan XZ (les nuages dérivent vers +vent)
uniform float angle_pixel = 0.0035;    // angle d'un pixel (rad) : 72° / 360 px ; sert à effacer les détails trop fins

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// bruit des nuages : hachage sans sinus (le sinus perd en précision loin de l'origine et strie le ciel de fines lignes)
float hash_n(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit_n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_n(i), hash_n(i + vec2(1.0, 0.0)), f.x), mix(hash_n(i + vec2(0.0, 1.0)), hash_n(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float t = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) {
			break;
		}
		s += a * bruit_n(p);
		t += a;
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s / t;
}

// densité des nuages : courants étirés dans le sens du vent + déformation, ce qui donne des formes déchiquetées
float densite(vec2 q, int oct) {
	vec2 w = vec2(bruit_n(q * 0.7 + 3.1), bruit_n(q * 0.7 + 11.7)) - 0.5;
	return fbm(q + w * 0.6, oct);
}

// fbm des nuages filtré : chaque octave tourne (pas d'alignement sur la grille du bruit), dérive à sa propre vitesse
// (la forme évolue) et s'efface quand sa période devient plus petite que ~2 pixels (empreinte `fp`, en unités du plan)
float fbm_nuage(vec2 p, int oct, float fp, float t, vec2 v0, float gain) {
	float s = 0.0;
	float a = 0.5;
	float f = 1.0;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) {
			break;
		}
		float lod = 1.0 - smoothstep(0.22, 0.5, fp * f);
		s += a * lod * (bruit_n(p) - 0.5);
		p = mat2(vec2(1.62, 1.18), vec2(-1.18, 1.62)) * p + v0 * t * (0.6 + 0.45 * float(i)) + vec2(5.3, 1.7);
		f *= 2.0;
		a *= gain;
	}
	return s;
}

// quantification douce : n paliers, transitions courtes (pas d'aplat pelucheux ni de bord en escalier dur)
float paliers(float v, float n) {
	float x = clamp(v, 0.0, 1.0) * n;
	float i = floor(x);
	float f = x - i;
	return min((i + smoothstep(0.38, 0.62, f)) / n, 1.0);
}

vec3 palette(vec3 nuit, vec3 cr, vec3 jr) {
	return mix(mix(nuit, jr, jour), cr, crep);
}

vec3 aurore(vec3 d) {
	vec3 acc = vec3(0.0);
	if (d.y < 0.02) {
		return acc;
	}
	const int COUCHES = 18;
	for (int i = 0; i < COUCHES; i++) {
		float k = float(i) / float(COUCHES - 1);
		float h = 1.0 + k * 1.1;
		vec2 q = d.xz / d.y * h;  // point sur un plan à la hauteur h
		float x = q.x * 0.32 + TIME * 0.015;
		float courbe = sin(x * 1.6 + sin(x * 0.55 + TIME * 0.04) * 2.2) * 0.7
			+ (bruit(vec2(x * 0.9, TIME * 0.02)) - 0.5) * 1.6;
		float ecart = q.y + 2.4 - courbe;
		float bande = exp(-ecart * ecart * 5.0);
		// stries verticales qui ondulent
		float stries = 0.35 + 0.65 * bruit(vec2(q.x * 5.0 + TIME * 0.25, k * 2.0));
		stries *= 0.6 + 0.4 * bruit(vec2(q.x * 1.3 - TIME * 0.1, 7.0));
		vec3 c = mix(aurore_bas, aurore_haut, smoothstep(0.15, 1.0, k));
		acc += c * bande * stries * (1.0 - k * 0.7);
	}
	return acc * (0.11 * aurore_force) * smoothstep(0.03, 0.3, d.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	// perf (refonte « lumière ») : la carte de radiance (ambiant et reflets désactivés, 32²) n'a besoin que du dégradé :
	// ni nuages, ni aurore, ni étoiles dans les 6 faces recalculées à chaque image (le shader lit TIME)
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(horizon_courant, haut_courant, smoothstep(-0.02, 0.6, max(d.y, 0.0)));
	} else {
		vec2 dh = d.xz / max(length(d.xz), 0.0001);
		vec2 sh = normalize(dir_astre.xz + vec2(0.0001));
		float vers = dot(dh, sh);                       // 1 face au soleil, -1 dos au soleil
		float az = smoothstep(-0.45, 1.0, vers);        // proximité du soleil en azimut (0..1)

		// horizon : froid, chaud du côté du soleil couchant (identique au brouillard, voir cycle.couleur_horizon)
		vec3 hz = mix(horizon_courant, horizon_chaud, crep * az);
		float y = max(d.y, 0.0);
		vec3 col = mix(hz, haut_courant, smoothstep(-0.02, 0.6, y));

		// bande dorée sous les nuages : or à l'horizon, orange, puis rose-violet vers le haut
		float k = crep * (0.25 + 0.75 * az);
		// couleurs en linéaire (le moteur applique ensuite la courbe sRGB) : or, orange brûlé, rose-violet
		vec3 or_ = mix(vec3(0.85, 0.42, 0.13), vec3(0.40, 0.14, 0.09), smoothstep(0.01, 0.07, y));
		or_ = mix(or_, vec3(0.045, 0.045, 0.075), smoothstep(0.05, 0.25, y));
		float forme = 1.0 - smoothstep(0.0, 0.2, y);
		forme = forme * forme;
		col = mix(col, or_, clamp(k * forme * smoothstep(0.0, 0.03, y) * 1.15, 0.0, 1.0));
		// bande orange-dorée NETTE (4e passe, comme la référence) : sous le banc de nuages sombres, à l'horizon, derrière
		// les montagnes peintes (bord haut ≈ 15-18°, découpé par le bas des nuages) ; côté couchant, crépuscule et aube
		float az_ang = atan(d.x, d.z);
		float yc = 0.31 + 0.05 * (bruit_n(vec2(az_ang * 5.0, 3.0)) - 0.5) + 0.02 * (bruit_n(vec2(az_ang * 23.0, 9.0)) - 0.5);
		float ep = 0.02;
		float trou = crep * (0.3 + 0.7 * az * az) * step(y, yc) * smoothstep(0.0, 0.01, y);
		// or en bas, orange au milieu, orange brûlé contre les nuages (paliers nets, pas de dégradé lisse)
		float hb = floor(clamp(y / yc, 0.0, 0.999) * 4.0) / 3.0;
		vec3 or_trou = mix(vec3(1.00, 0.66, 0.26), vec3(0.78, 0.30, 0.10), hb);
		col = mix(col, or_trou, trou);
		if (d.y < 0.0) {
			col = hz;
		}

		// étoiles : cellules d'une grille en 3D, quelques-unes allumées
		vec3 cellule = floor(d * 160.0);
		float h = hash3(cellule);
		if (h > 0.9965 && d.y > 0.02 && jour < 0.9) {
			float scintille = 0.6 + 0.4 * sin(TIME * (2.0 + h * 40.0) + h * 100.0);
			col += vec3(0.8, 0.85, 1.0) * (h - 0.9965) / 0.0035 * scintille * smoothstep(0.02, 0.2, d.y) * (1.0 - jour) * (1.0 - crep);
		}

		float k_aurore = (1.0 - jour) * (1.0 - crep * 0.9) * aurore_force;
		if (k_aurore > 0.004) {
			col += aurore(d) * (1.0 - jour) * (1.0 - crep * 0.9);  // 18 couches : sautées le jour et au crépuscule plein
		}

		// astre : lune ou soleil
		float m = dot(d, LIGHT0_DIRECTION);
		if (LIGHT0_ENABLED) {
			float disque = smoothstep(0.99935, 0.99945, m);
			float taches = bruit(d.xy * 900.0) * 0.25 * (1.0 - soleil);
			vec3 astre = mix(vec3(0.95, 0.95, 0.85), vec3(1.6, 1.25, 0.85), soleil);
			col = mix(col, astre * (1.1 - taches), disque);
			col += mix(vec3(0.25, 0.3, 0.45), vec3(0.9, 0.6, 0.35), soleil) * pow(max(m, 0.0), 600.0) * 0.8;
			col += mix(vec3(0.1, 0.13, 0.2), vec3(0.45, 0.3, 0.2), soleil) * pow(max(m, 0.0), 30.0) * 0.4;
		}

		// --- nuages : deux couches projetées sur des plans horizontaux (au-dessus de l'horizon seulement) ----------------
		if (d.y > 0.0) {
			float t = temps_force >= 0.0 ? temps_force : TIME;
			vec2 wd = normalize(vent);
			vec2 wp = vec2(-wd.y, wd.x);
			// point sur le plan des nuages (hauteur 1) ; le petit décalage borne l'infini à l'horizon
			float hy = d.y + 0.085;
			vec2 pl = d.xz / hy;
			pl = vec2(dot(pl, wd), dot(pl, wp));      // repère du vent : x = sens du vent
			vec2 shw = vec2(dot(sh, wd), dot(sh, wp)); // direction de l'astre dans ce repère
			// empreinte d'un pixel sur le plan : radiale (verticale à l'écran) et tangentielle ; moyenne pondérée vers la radiale
			float fp_r = angle_pixel / (hy * hy);
			float fp_t = angle_pixel * length(d.xz) / hy;
			float fp = pow(fp_r, 0.6) * pow(fp_t, 0.4);
			float pres_hz = 1.0 - smoothstep(0.0, 0.2, d.y);   // proximité de l'horizon
			float m_astre = LIGHT0_ENABLED ? max(dot(d, LIGHT0_DIRECTION), 0.0) : 0.0;

			// couleurs des nuages (linéaire) : dessous sombre, corps, bord éclairé, éclat ; nuit / crépuscule / jour couvert
			vec3 c_sombre = palette(vec3(0.006, 0.009, 0.022), vec3(0.018, 0.019, 0.032), vec3(0.11, 0.13, 0.17));
			vec3 c_corps = palette(vec3(0.016, 0.024, 0.050), vec3(0.042, 0.044, 0.068), vec3(0.22, 0.25, 0.31));
			vec3 c_bord = palette(vec3(0.050, 0.068, 0.125), vec3(0.085, 0.09, 0.15), vec3(0.44, 0.48, 0.56));
			vec3 c_eclat = palette(vec3(0.13, 0.15, 0.24), vec3(0.16, 0.16, 0.24), vec3(0.72, 0.74, 0.78));
			// au couchant, côté soleil : liserés orange près de l'horizon, roses plus haut
			vec3 chaud = mix(vec3(0.62, 0.20, 0.24), vec3(1.00, 0.46, 0.14), clamp(az * az * (0.4 + 0.8 * pres_hz), 0.0, 1.0));
			float k_chaud = crep * (0.2 + 0.8 * az * az);

			// --- couche haute : cirrus fins, fibreux, très étirés dans le sens du vent, lents (plus hauts → parallaxe)
			vec2 q2 = pl * vec2(0.4, 1.6) * 1.4 - vec2(t * 0.012, t * 0.0015);
			float fp2 = fp * 1.4 * 1.6;
			float w2 = bruit_n(q2 * vec2(0.3, 0.6) + vec2(3.7, t * 0.003)) - 0.5;
			float n2 = 0.5 + fbm_nuage(q2 + vec2(w2 * 1.2, w2 * 0.5), 4, fp2, t, vec2(0.010, 0.003), 0.55);
			float fibre = 1.0 - abs(n2 * 2.0 - 1.0);                      // crêtes fines : fibres de cirrus
			float cov2 = bruit_n(q2 * vec2(0.06, 0.15) + vec2(11.0, 2.0)) - 0.5;
			float cir = smoothstep(0.72, 0.95, fibre) * smoothstep(-0.05, 0.25, cov2 - (1.0 - couverture) * 0.2) * 0.38;
			cir *= smoothstep(0.015, 0.09, d.y);
			vec3 c_cir = mix(c_bord, c_eclat, 0.3 + 0.7 * smoothstep(0.85, 1.0, fibre));
			c_cir = mix(c_cir, chaud * mix(0.55, 1.0, az), k_chaud * 0.85);
			c_cir += mix(vec3(0.05, 0.06, 0.09), vec3(0.40, 0.28, 0.16), soleil) * pow(m_astre, 12.0) * 0.6;

			// --- couche basse : strato-cumulus, densité variable, grandes trouées
			vec2 q = pl * vec2(0.75, 1.0) * 4.4 - vec2(t * 0.06, 0.0);
			float fp1 = fp * 4.4;
			// zones épaisses / clairsemées (très grande échelle, lente) : le ciel n'est jamais couvert partout
			float cov = bruit_n(q * 0.036 + vec2(t * 0.0012, 7.3)) - 0.5;
			// déformation lente du domaine (la forme évolue) puis détail filtré
			vec2 wq = vec2(bruit_n(q * 0.16 + vec2(t * 0.02, 1.3)), bruit_n(q * 0.16 + vec2(5.2, -t * 0.016))) - 0.5;
			vec2 r = q + wq * 1.6;
			float n1 = fbm_nuage(r, 5, fp1, t, vec2(0.04, 0.016), 0.64);
			float seuil = mix(mix(0.08, 0.02, jour), 0.03, crep) + (1.0 - couverture) * 0.3 + trou * 0.18
				- smoothstep(0.05, 0.5, d.y) * 0.04;
			float dens = n1 + cov * 0.6 - seuil;
			// alpha : bords transparents et effilochés, fondu vers l'horizon (jamais de mur coupé net)
			float alpha = smoothstep(0.0, 0.07, dens) * smoothstep(0.0, 0.06, d.y);
			if (alpha > 0.002) {
				float epais = smoothstep(0.03, 0.30, dens);   // épaisseur : le dessous des parties épaisses est sombre
				// lumière : la densité baisse du côté de l'astre → bord éclairé ; densité grossière (3 octaves) au point décalé
				float d_ici = fbm_nuage(r, 3, fp1, t, vec2(0.04, 0.016), 0.64) + cov * 0.6;
				float d_la = fbm_nuage(r + shw * vec2(0.75, 1.0) * 0.2, 3, fp1, t, vec2(0.04, 0.016), 0.64) + cov * 0.6;
				float bord = clamp((d_ici - d_la) * 9.0, 0.0, 1.0);
				// petites touches de lumière : le détail fin (n1 - grossier) éclaire les bosses du dessous
				float fin = n1 - d_ici + cov * 0.6;                 // détail fin (octaves 4-5)
				float touches = clamp(fin * 8.0 + 0.1, 0.0, 1.0);
				float vers_astre = 0.25 + 0.75 * az;
				float v = 0.30 * (1.0 - epais) + 0.40 * bord * vers_astre + 0.34 * touches * (0.45 + 0.55 * vers_astre) + fin * 0.9
					+ 0.25 * pow(m_astre, 6.0) * (1.0 - epais * 0.6);
				v = paliers(v, 7.0);
				vec3 c = mix(c_sombre, c_corps, smoothstep(0.0, 0.34, v));
				c = mix(c, c_bord, smoothstep(0.30, 0.66, v));
				c = mix(c, c_eclat, smoothstep(0.64, 1.0, v));
				// liserés chauds du dessous côté soleil (couchant / aube), sur les bords et les touches éclairés
				float lis = paliers(smoothstep(0.3, 0.95, bord * 1.1 + touches * 0.45) * (1.0 - epais * 0.4), 4.0);
				c = mix(c, chaud * (0.85 + 0.4 * pres_hz), clamp(k_chaud * lis * az * 1.2, 0.0, 1.0));
				// bord des nuages qui coiffent la bande dorée : liseré orange
				float pres_trou = crep * (0.3 + 0.7 * az * az) * step(yc, y) * (1.0 - step(yc + ep * 2.0, y));
				c = mix(c, vec3(0.80, 0.36, 0.12), pres_trou * (1.0 - epais) * 0.8);
				// voile de brume : vers l'horizon les nuages se fondent dans la couleur du ciel (perspective aérienne)
				c = mix(c, col, pres_hz * pres_hz * 0.65);
				// la couche haute se voit à travers les bords transparents de la couche basse
				col = mix(col, c_cir, cir * (1.0 - alpha));
				col = mix(col, c, alpha);
			} else {
				col = mix(col, c_cir, cir);
			}
		}

		COLOR = col;
	}
}
