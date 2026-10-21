// Ciel nordique (lot 2 « étalonnage et ciel ») : dégradé, GRANDE COUCHE DE NUAGES en pixel art (formes déchiquetées,
// volumes en paliers, bords éclairés côté astre), bande dorée sous les nuages au crépuscule, étoiles, lune, aurore.
// Tout est calculé en direction du regard : la taille des nuages ne dépend pas de la résolution interne du jeu.
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
		// trouée orange FINE (refonte « lumière ») : une fente irrégulière entre deux bancs de nuages, au-dessus de la
		// ligne des arbres, derrière les cimes (≈ 12-15°), côté couchant seulement ; ≤ 3 % du ciel
		float az_ang = atan(d.x, d.z);
		float yc = 0.235 + 0.04 * (bruit_n(vec2(az_ang * 7.0, 3.0)) - 0.5) + 0.015 * (bruit_n(vec2(az_ang * 31.0, 9.0)) - 0.5);
		float ep = 0.016 + 0.012 * bruit_n(vec2(az_ang * 11.0, 5.0));
		float trou = crep * (0.4 + 0.6 * az * az) * (1.0 - smoothstep(ep * 0.5, ep, abs(y - yc)));
		vec3 or_trou = mix(vec3(0.95, 0.52, 0.18), vec3(0.62, 0.26, 0.12), smoothstep(0.0, ep, abs(y - yc)));
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

		// --- couche de nuages (au-dessus de l'horizon seulement) -------------------------------------------------
		if (d.y > 0.0) {
			// plan de nuages : les formes rapetissent vers l'horizon (perspective) ; vent lent et régulier
			vec2 p = d.xz / (d.y + 0.2) * 7.5 + vec2(TIME * 0.012, TIME * 0.005);
			vec2 q = p * vec2(1.0, 1.3);  // étirement : les nuages s'allongent à l'horizontale
			float n = densite(q, 5);
			// couverture : très épaisse en hauteur, des trouées près de l'horizon (la bande dorée se montre en dessous)
			float seuil_h = mix(0.50, 0.36, smoothstep(0.02, 0.45, d.y));
			float seuil_n = mix(0.64, 0.50, smoothstep(0.02, 0.45, d.y));      // nuit : plus de trouées (étoiles, aurore)
			float seuil_j = mix(0.52, 0.42, smoothstep(0.02, 0.45, d.y));      // jour : couvert avec des trouées claires
			float seuil = mix(mix(seuil_n, seuil_j, jour), seuil_h, crep) + (1.0 - couverture) * 0.3 + trou * 0.45;
			// l'horizon lui-même reste dégagé : fondu des nuages tout près du bord (jamais de mur coupé net)
			float fond = smoothstep(0.0, 0.035, d.y);
			float masque = smoothstep(seuil, seuil + 0.035, n) * fond;
			if (masque > 0.001) {
				float s = clamp((n - seuil) / (1.0 - seuil), 0.0, 1.0);
				// volumes en paliers + texture déchiquetée fine
				float fin = fbm(q * 3.0 + vec2(5.0, 1.0), 3);
				float grain = hash_n(floor(q * 14.0));  // moucheté pixel art
				float ton = floor(clamp(s * 0.7 + fin * 0.5 + (grain - 0.5) * 0.45, 0.0, 0.999) * 4.0) / 3.0;
				// bord éclairé : la densité baisse du côté de l'astre
				vec2 L = sh * 0.035;
				float d3 = densite(q, 3);  // une seule fois pour le bord éclairé et le dessous
				float ecart = d3 - densite(q + L * vec2(0.9, 1.05), 3);
				float rim = floor(clamp(ecart * 22.0, 0.0, 0.999) * 3.0) / 2.0;
				// seconde source : le dessous des nuages reçoit la lueur de l'horizon
				float bas = d3 - densite(q + normalize(q + vec2(0.0001)) * 0.05, 3);
				float rim_bas = floor(clamp(bas * 16.0, 0.0, 0.999) * 3.0) / 2.0;

				vec3 sombre = palette(vec3(0.003, 0.005, 0.014), vec3(0.016, 0.017, 0.028), vec3(0.075, 0.09, 0.125));
				vec3 moyen = palette(vec3(0.012, 0.018, 0.040), vec3(0.040, 0.043, 0.062), vec3(0.17, 0.20, 0.25));
				// crépuscule : gris-violet de la référence (#272931 #393b47 #55607b), rim un peu plus clair
				vec3 clair = palette(vec3(0.035, 0.060, 0.130), vec3(0.11, 0.115, 0.19), vec3(0.45, 0.50, 0.58));
				vec3 c = mix(sombre, moyen, ton);
				float proche_horizon = 1.0 - smoothstep(0.0, 0.32, d.y);
				float eclat = rim * (0.12 + 0.88 * az * az) * (0.55 + 0.45 * proche_horizon);
				c = mix(c, clair, eclat * mix(0.55, 1.0, crep));
				// le dessous des nuages du côté du couchant brille (or / orange)
				c = mix(c, vec3(0.80, 0.30, 0.08), crep * az * smoothstep(0.0,1.0,1.0 - smoothstep(0.0, 0.12, d.y)) * rim_bas * 0.7);
				// bords des nuages qui bordent la trouée : liseré orange d'un ou deux pixels
				float pres_trou = crep * (0.4 + 0.6 * az * az) * (1.0 - smoothstep(ep, ep * 2.6, abs(y - yc)));
				c = mix(c, vec3(0.70, 0.32, 0.12), pres_trou * (1.0 - s) * 0.8);
				// à la nuit, les nuages couvrent aussi un peu l'aurore et les étoiles : le fond est atténué par le masque
				col = mix(col, c, masque);
			}
		}

		COLOR = col;
	}
}
