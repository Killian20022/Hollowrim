// Ciel de nuit nordique : dégradé, étoiles scintillantes, lune, aurore boréale animée.
// L'aurore est posée au nord (-Z).
shader_type sky;

uniform vec3 couleur_haut : source_color = vec3(0.008, 0.012, 0.035);
uniform vec3 couleur_horizon : source_color = vec3(0.045, 0.07, 0.12);
uniform vec3 aurore_bas : source_color = vec3(0.15, 1.0, 0.55);
uniform vec3 aurore_haut : source_color = vec3(0.55, 0.2, 0.95);
uniform float aurore_force = 1.0;
uniform float jour = 0.0;     // 0 nuit, 1 plein jour (pâle : hiver polaire)
uniform float soleil = 0.0;   // l'astre dessiné : 0 lune, 1 soleil
uniform vec3 jour_haut : source_color = vec3(0.32, 0.42, 0.58);
uniform vec3 jour_horizon : source_color = vec3(0.72, 0.68, 0.66);

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
	vec3 haut = mix(couleur_haut, jour_haut, jour);
	vec3 horizon = mix(couleur_horizon, jour_horizon, jour);
	vec3 col = mix(horizon, haut, smoothstep(-0.05, 0.55, d.y));
	if (d.y < 0.0) {
		col = horizon * 0.6;
	}

	// étoiles : cellules d'une grille en 3D, quelques-unes allumées
	vec3 cellule = floor(d * 160.0);
	float h = hash3(cellule);
	if (h > 0.9965 && d.y > 0.02 && jour < 0.9) {
		float scintille = 0.6 + 0.4 * sin(TIME * (2.0 + h * 40.0) + h * 100.0);
		col += vec3(0.8, 0.85, 1.0) * (h - 0.9965) / 0.0035 * scintille * smoothstep(0.02, 0.2, d.y) * (1.0 - jour);
	}

	col += aurore(d) * (1.0 - jour);

	// lune
	float m = dot(d, LIGHT0_DIRECTION);
	if (LIGHT0_ENABLED) {
		float disque = smoothstep(0.99935, 0.99945, m);
		float taches = bruit(d.xy * 900.0) * 0.25 * (1.0 - soleil);
		vec3 astre = mix(vec3(0.95, 0.95, 0.85), vec3(1.6, 1.25, 0.85), soleil);
		col = mix(col, astre * (1.1 - taches), disque);
		col += mix(vec3(0.25, 0.3, 0.45), vec3(0.9, 0.6, 0.35), soleil) * pow(max(m, 0.0), 600.0) * 0.8;
		col += mix(vec3(0.1, 0.13, 0.2), vec3(0.45, 0.3, 0.2), soleil) * pow(max(m, 0.0), 30.0) * 0.4;
	}

	COLOR = col;
}
