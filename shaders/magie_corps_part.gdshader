// SOCLE « impact des sorts sur les corps » (scripts/magie/impact_corps.gd, docs/MAGIE_IMPACT_CORPS.md) : émission de
// particules depuis la SURFACE d'un corps. Les points (positions et normales du monde, relatives à l'émetteur) sont écrits
// chaque image par SurfaceCorps dans deux textures RGBA flottantes (xyz tassés, voir lire3) : ils suivent les os (animation, ragdoll).
// Chaque particule tire un point par rejet selon le POIDS de son mode (côté tourné vers le jet, bord de la silhouette,
// voisinage du point d'impact, foyers de brûlure…) : la densité suit l'impact sans aucun calcul par point côté CPU.
// Dessin : shaders magie_part_add / magie_part_mix (carrés de pixels, traînée selon l'axe Y = vitesse), comme le reste.
//
// Modes (ajouter les suivants à la fin, sans renuméroter : l'agent des autres écoles s'y branche) :
//   0 langues   : flammes de surface, côté impact, qui montent (flottabilité) et suivent le souffle du jet
//   1 contour   : flux qui CONTOURNE le corps : naît sur le bord de la silhouette (normale ⟂ au jet), file dans le sens du jet
//   2 eclabouss : cœur d'impact : éclaboussure TANGENTE à la surface autour du point touché
//   3 escarbille: escarbilles fines qui s'échappent par les bords et du côté impact
//   4 fumee     : fumée légère au-dessus des foyers
//   5 sol       : flammes au sol, autour des points bas (pieds)
shader_type particles;
// les répulseurs du foyer (déviation du jet autour du corps) ne poussent pas ces particules-ci
render_mode disable_force;

uniform sampler2D pts : filter_nearest, repeat_disable;
uniform sampler2D nrm : filter_nearest, repeat_disable;
uniform int nb_pts = 0;
uniform int mode = 0;
// jet (repère du monde ; point_impact relatif à l'émetteur) ; k_jet = 0 hors du jet
uniform vec3 dir_jet = vec3(0.0, 0.0, -1.0);
uniform vec3 point_impact = vec3(0.0);
uniform float rayon_jet = 0.45;
uniform float k_jet = 0.0;
// foyers de brûlure (xyz relatif, w = rayon, 0 = éteint) et leur force
uniform vec4 foyers[4];
uniform float k_foyers = 0.0;
uniform float sol_y = 0.0;
uniform float poids_min = 0.0;      // mise au point : poids plancher (1 = émission sur tous les points)          // hauteur du sol sous le corps (relative)
// cinématique
uniform vec2 vitesse = vec2(0.5, 1.5);
uniform vec3 gravite = vec3(0.0, 2.0, 0.0);
uniform vec2 amorti = vec2(1.0, 2.0);
uniform float ouvert = 0.3;         // dispersion de la direction
uniform float ecarte = 0.02;        // naissance décalée le long de la normale (m)
uniform float turb = 0.0;           // ondulation (m/s²)
uniform float suit_jet = 0.35;      // part de la direction du jet dans la vitesse
// apparence
uniform vec2 taille = vec2(0.02, 0.05);
uniform int courbe = 1;             // 0 plat, 1 descend, 2 bosse, 3 monte
uniform float alea_vie = 0.3;
uniform float chaud = 0.4;          // départ dans la rampe : les particules froides (loin de l'impact) sautent les blancs
uniform sampler2D rampe : filter_nearest, repeat_disable;   // couleurs sRVB brutes (magie_part les passe en linéaire)

// point i : 3 flottants tassés dans une texture RGBA flottante (SurfaceCorps.TEXELS)
float lire1(sampler2D t, int k) {
	vec4 c = texelFetch(t, ivec2(k / 4, 0), 0);
	int r = k % 4;
	return r == 0 ? c.x : (r == 1 ? c.y : (r == 2 ? c.z : c.w));
}

vec3 lire3(sampler2D t, int i) {
	return vec3(lire1(t, i * 3), lire1(t, i * 3 + 1), lire1(t, i * 3 + 2));
}

uint h(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

float alea(inout uint s) {
	s = h(s);
	return float(s) / 4294967295.0;
}

vec3 sphere(inout uint s) {
	float z = alea(s) * 2.0 - 1.0;
	float a = alea(s) * 6.2831853;
	float r = sqrt(max(1.0 - z * z, 0.0));
	return vec3(r * cos(a), z, r * sin(a));
}

float foyer(vec3 p) {
	float m = 0.0;
	for (int i = 0; i < 4; i++) {
		if (foyers[i].w > 0.0) {
			float d = length(p - foyers[i].xyz) / foyers[i].w;
			m = max(m, exp(-d * d));
		}
	}
	return m;
}

// poids (0..1) d'un point pour le mode courant, et sa « chaleur » (0..1 : départ dans la rampe)
vec2 poids(vec3 p, vec3 n) {
	vec3 d = dir_jet;
	vec3 v = p - point_impact;
	float axe = length(v - d * dot(v, d));
	float prox = exp(-(axe * axe) / max(rayon_jet * rayon_jet, 0.0001));
	float face = clamp(-dot(n, d), 0.0, 1.0);
	float bord = 1.0 - abs(dot(n, d));
	float di = length(v);
	float imp = exp(-(di * di) / 0.05);
	float f = foyer(p);
	float w = 0.0;
	float c = 0.0;
	if (mode == 0) {
		w = k_jet * prox * (0.2 + 0.8 * face) + k_foyers * f;
		c = clamp(k_jet * prox * face * 1.3 + imp * k_jet, 0.0, 1.0);
	} else if (mode == 1) {
		float large = exp(-(axe * axe) / max(rayon_jet * rayon_jet * 2.2, 0.0001));
		w = k_jet * smoothstep(0.45, 0.92, bord) * large * step(-0.35, -dot(n, d));
		c = clamp(k_jet * large * 0.6, 0.0, 1.0);
	} else if (mode == 2) {
		w = k_jet * imp * (0.3 + 0.7 * face);
		c = 1.0;
	} else if (mode == 3) {
		w = k_jet * prox * (0.35 + 0.65 * smoothstep(0.5, 0.95, bord)) + k_foyers * f * 0.7;
		c = 0.8;
	} else if (mode == 4) {
		w = k_foyers * f + k_jet * prox * 0.25;
		c = 0.0;
	} else if (mode == 5) {
		float bas = 1.0 - smoothstep(0.08, 0.4, p.y - sol_y);
		w = bas * (k_jet * (0.4 + 0.6 * prox) + k_foyers * 0.6);
		c = 0.3;
	}
	return vec2(clamp(max(w, poids_min), 0.0, 1.0), c);
}

void start() {
	uint s = h(NUMBER * 747796405u + RANDOM_SEED);
	CUSTOM = vec4(0.0, 0.0, 0.0, 1.0 - alea_vie * alea(s));
	int choisi = -1;
	vec3 p = vec3(0.0);
	vec3 n = vec3(0.0, 1.0, 0.0);
	vec2 wc = vec2(0.0);
	if (nb_pts > 0) {
		// tirage par rejet : la densité d'émission suit le poids du mode
		for (int k = 0; k < 8; k++) {
			int i = int(alea(s) * float(nb_pts)) % nb_pts;
			vec3 pp = lire3(pts, i);
			vec3 nn = lire3(nrm, i);
			vec2 q = poids(pp, nn);
			if (alea(s) < q.x) {
				choisi = i;
				p = pp;
				n = normalize(nn + vec3(0.0, 0.00001, 0.0));
				wc = q;
				break;
			}
		}
	}
	if (choisi < 0) {
		// rien à émettre ici cette fois : particule éteinte jusqu'à son prochain tour
		ACTIVE = false;
		CUSTOM.w = 0.0;
		TRANSFORM = mat4(vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0, -1000.0, 0.0, 1.0));
		VELOCITY = vec3(0.0);
		COLOR = vec4(0.0);
	} else {
		vec3 d = dir_jet;
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 dir;
		vec3 pos = p + n * ecarte;
		if (mode == 1) {
			// le flux glisse sur le corps et part dans le sens du jet, en s'écartant de la silhouette
			vec3 np = n - d * dot(n, d);
			np = length(np) > 0.001 ? normalize(np) : n;
			// vu du lanceur, le flux s'ÉCARTE de la silhouette (composante perpendiculaire au jet) en continuant sa route
			dir = np * 1.0 + d * 0.55 + up * 0.35;
		} else if (mode == 2) {
			vec3 t = p - point_impact;
			t -= n * dot(t, n);
			t = length(t) > 0.002 ? normalize(t) : normalize(sphere(s) - n * dot(sphere(s), n) + vec3(0.0001));
			dir = t + n * 0.3 + d * 0.15;
		} else if (mode == 3) {
			dir = n * 0.7 + up * 0.7 + d * suit_jet;
		} else if (mode == 4) {
			dir = up + n * 0.3;
			pos += up * 0.06;
		} else if (mode == 5) {
			// au sol, autour du pied
			vec3 r = sphere(s);
			pos = vec3(p.x + r.x * 0.22, sol_y + 0.02, p.z + r.z * 0.22);
			dir = up + d * suit_jet * 0.5;
		} else {
			// la flamme naît sur la surface et MONTE en la léchant (peu de normale : elle colle au corps)
			dir = n * 0.25 + up * 0.9 + d * suit_jet * k_jet;
		}
		dir = normalize(normalize(dir) + sphere(s) * ouvert);
		float v = mix(vitesse.x, vitesse.y, alea(s));
		CUSTOM.x = wc.y;                       // chaleur au départ
		float t0 = mix(taille.x, taille.y, alea(s));
		CUSTOM.z = t0;                         // taille de départ
		if (RESTART_POSITION) {
			TRANSFORM = mat4(vec4(t0, 0.0, 0.0, 0.0), vec4(0.0, t0, 0.0, 0.0), vec4(0.0, 0.0, t0, 0.0), vec4(pos, 1.0));
			TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
		}
		if (RESTART_VELOCITY) {
			VELOCITY = dir * v;
		}
		COLOR = texture(rampe, vec2(0.0, 0.5));
		CUSTOM.y = 0.0;
	}
}

void process() {
	if (CUSTOM.w <= 0.0) {
		ACTIVE = false;
	} else {
		CUSTOM.y += DELTA / max(LIFETIME, 0.001);
		float age = CUSTOM.y / CUSTOM.w;
		if (age >= 1.0) {
			ACTIVE = false;
		}
		vec3 p = TRANSFORM[3].xyz;
		VELOCITY += gravite * DELTA;
		if (turb > 0.0) {
			float ph = float(INDEX) * 1.7;
			VELOCITY += vec3(sin(p.y * 9.0 + TIME * 7.0 + ph), 0.0, cos(p.y * 8.0 - TIME * 6.0 + ph * 1.3)) * turb * DELTA;
		}
		uint sa = h(uint(INDEX) * 2654435761u + 17u);
		float am = mix(amorti.x, amorti.y, float(sa & 1023u) / 1023.0);
		VELOCITY *= max(1.0 - am * DELTA, 0.0);
		float k = 1.0;
		if (courbe == 1) {
			k = mix(1.0, 0.2, age);
		} else if (courbe == 2) {
			k = age < 0.35 ? mix(0.3, 1.0, age / 0.35) : mix(1.0, 0.45, (age - 0.35) / 0.65);
		} else if (courbe == 3) {
			k = mix(0.35, 1.0, age);
		}
		float t0 = CUSTOM.z;
		float sc = t0 * k;
		vec3 y = length(VELOCITY) > 0.0001 ? normalize(VELOCITY) : vec3(0.0, 1.0, 0.0);
		vec3 x = normalize(cross(y, abs(y.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		vec3 z = cross(x, y);
		TRANSFORM[0] = vec4(x * sc, 0.0);
		TRANSFORM[1] = vec4(y * sc, 0.0);
		TRANSFORM[2] = vec4(z * sc, 0.0);
		// rampe : les particules chaudes (près de l'impact) partent du blanc, les autres sautent les premiers paliers
		float u0 = (1.0 - CUSTOM.x) * chaud;
		COLOR = texture(rampe, vec2(clamp(u0 + age * (1.0 - u0), 0.0, 0.999), 0.5));
	}
}
