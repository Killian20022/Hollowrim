// SOUFFLE DE GIVRE du jet de glace (couche fine ; scripts/magie/gestion_magie.gd, _givre_*) : simulation. Même
// architecture que la vague de flammes (magie_vague_process.gdshader) : particules dans le repère du MONDE, sous-pas
// d'émission entre deux images, plan d'arrêt au point touché. Deux familles dans un seul émetteur :
//   - BOUFFÉES de souffle (~70 %) : sortent vite dans un cône, freinent fort (l'air froid est lourd : elles RETOMBENT un
//     peu au lieu de monter), gonflent et roulent sur elles-mêmes (rotation propre rapide), poussées par une turbulence
//     qui dépend de la position ; au point touché elles s'écrasent et s'étalent en brume ;
//   - CRISTAUX (~30 %) : petits, portent plus loin (moins freinés), tournoient vite et papillonnent dans la turbulence,
//     retombent un peu ; au point touché ils S'ACCROCHENT (vitesse nulle, collés au plan) et scintillent jusqu'à leur fin.
// CUSTOM : x = graine (+ 100 pour un cristal), y = âge (0..1), z = rotation (rad), w = vitesse de rotation.
// COLOR.r = teinte propre, COLOR.g = variation de taille.
shader_type particles;
render_mode disable_force;

uniform float vitesse = 14.0;     // vitesse de sortie (m/s)
uniform float traine = 1.5;       // freinage (1/s) : x(t) = v0 / k · (1 - e^(-k t))
uniform float ecart = 0.12;       // demi-ouverture du cône de sortie (rad)
uniform float taille0 = 0.1;     // rayon d'une bouffée à la naissance (m)
uniform float taille1 = 0.6;      // rayon d'une bouffée en fin de vie (m)
uniform float lourd = 0.45;       // l'air froid retombe (m/s², croît avec l'âge)
uniform float turb = 3.2;         // turbulence (m/s²)
uniform float part_cristaux = 0.3;
uniform float taille_cristal = 0.035;
uniform vec4 arret = vec4(0.0);   // xyz = point touché (monde), w = 1 si le jet touche quelque chose
uniform vec3 arret_dir = vec3(0.0, 0.0, -1.0);
uniform float colle = 0.05;       // les cristaux s'accrochent à cette distance AVANT le point touché (m)
uniform float etale = 2.2;        // vieillissement des bouffées après l'impact (×)
uniform vec3 prec_o = vec3(0.0);
uniform mat3 prec_base = mat3(1.0);
uniform float pas = 0.016;

float h1(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

void start() {
	uint b = NUMBER * 7u + RANDOM_SEED * 13u;
	float ra = h1(b + 1u), rb = h1(b + 2u), rc = h1(b + 3u), rd = h1(b + 4u), re = h1(b + 5u);
	bool cristal = h1(b + 7u) < part_cristaux;
	float th = ra * 6.2831853;
	// cristaux un peu plus dispersés (ils fusent autour du souffle)
	float rr = pow(rb, 0.75) * ecart * (cristal ? 1.35 : 1.0);
	vec3 d = normalize(vec3(cos(th) * rr, sin(th) * rr, -1.0));
	float v = vitesse * (cristal ? (0.85 + 0.4 * rc) : (0.75 + 0.4 * rc));
	vec3 p = vec3(cos(th) * 0.02 * rd, sin(th) * 0.02 * rd, -0.04);
	float rs = h1(b + 6u);
	float dt0 = rs * min(pas, 0.05);
	mat3 bc = mat3(EMISSION_TRANSFORM[0].xyz, EMISSION_TRANSFORM[1].xyz, EMISSION_TRANSFORM[2].xyz);
	vec3 vw = normalize(mix(bc * d, prec_base * d, rs)) * v;
	vec3 ow = mix(EMISSION_TRANSFORM[3].xyz, prec_o, rs) + mix(bc * p, prec_base * p, rs);
	if (RESTART_POSITION) {
		float t0 = cristal ? taille_cristal : taille0;
		TRANSFORM = mat4(vec4(t0, 0.0, 0.0, 0.0), vec4(0.0, t0, 0.0, 0.0), vec4(0.0, 0.0, t0, 0.0), vec4(ow + vw * dt0, 1.0));
	}
	if (RESTART_VELOCITY) {
		VELOCITY = vw;
	}
	if (RESTART_CUSTOM) {
		// cristaux : rotation propre rapide (ils tournoient) ; bouffées : roulis plus lent mais net
		float w = cristal ? (re - 0.5) * 26.0 : (re - 0.5) * 7.0;
		CUSTOM = vec4(rd * 37.0 + (cristal ? 100.0 : 0.0), dt0 / LIFETIME, ra * 6.2831853, w);
	}
	if (RESTART_COLOR) {
		COLOR = vec4(re, rc, 0.0, 1.0);
	}
}

void process() {
	bool cristal = CUSTOM.x >= 100.0;
	float g = CUSTOM.x - (cristal ? 100.0 : 0.0);
	float a = CUSTOM.y;
	vec3 p = TRANSFORM[3].xyz;
	float k_age = 1.0;
	bool accroche = false;
	bool ecrase = false;
	if (arret.w > 0.5) {
		float s = dot(p - arret.xyz, arret_dir);
		if (cristal) {
			// givre qui s'accroche : le cristal se plante au point touché et n'en bouge plus
			if (s > -colle && s < 0.6) {   // (au-delà : plan déplacé loin devant, le cristal reste libre)
				TRANSFORM[3].xyz = p - arret_dir * (s + colle);
				p = TRANSFORM[3].xyz;
				VELOCITY = vec3(0.0);
				accroche = true;
				k_age = 0.55;
			}
		} else if (s > -0.35) {
			float vp = dot(VELOCITY, arret_dir);
			if (vp > 0.0) {
				vec3 lat = (p - arret.xyz) - arret_dir * s;
				float ll = length(lat);
				vec3 dl = ll > 0.01 ? lat / ll : normalize(vec3(sin(g * 3.0), 0.1, cos(g * 3.0)));
				float q = min(1.0, DELTA * 14.0);
				// la brume s'écrase et s'étale (un peu vers le bas : l'air froid coule) ; étalement modéré : à pleine
				// vitesse latérale, les bouffées étirées faisaient de grandes « ailes » pâles autour de la cible
				VELOCITY += (dl * 0.4 + vec3(0.0, -0.1, 0.0) - arret_dir) * vp * q;
			}
			// elle s'y amortit (elle gonfle sur place au lieu de fuser)
			VELOCITY *= exp(-5.0 * DELTA);
			ecrase = true;
			k_age = etale;
		}
	}
	if (!accroche) {
		VELOCITY *= exp(-traine * (cristal ? 0.55 : 1.0) * DELTA);
		VELOCITY.y -= (cristal ? 1.6 : lourd) * a * DELTA;
		float t = TIME;
		vec3 tu = vec3(sin(p.y * 2.1 + p.z * 0.8 + t * 3.3 + g),
					   sin(p.z * 1.7 + p.x * 1.0 + t * 2.7 + g * 1.3),
					   sin(p.x * 1.9 + p.y * 1.2 - t * 3.1 + g * 0.7));
		VELOCITY += tu * turb * (cristal ? 1.7 : 1.0) * smoothstep(0.04, 0.4, a) * DELTA;
	}
	a += DELTA / LIFETIME * k_age;
	CUSTOM.y = a;
	if (a >= 1.0) {
		ACTIVE = false;
	}
	CUSTOM.z += CUSTOM.w * DELTA * (accroche ? 0.15 : (1.0 - 0.5 * a));
	float vl = length(VELOCITY);
	vec3 vd = vl > 0.001 ? VELOCITY / vl : vec3(0.0, 0.0, -1.0);
	vec3 ax = abs(vd.y) < 0.95 ? normalize(cross(vd, vec3(0.0, 1.0, 0.0))) : vec3(1.0, 0.0, 0.0);
	if (cristal) {
		// cristal : taille fixe (chaque cristal à sa mesure), rond (la forme est l'étoile du dessin)
		float sc = taille_cristal * (0.55 + 0.9 * COLOR.g);
		TRANSFORM[0].xyz = ax * sc;
		TRANSFORM[1].xyz = vd * sc;
		TRANSFORM[2].xyz = cross(ax, vd) * sc;
	} else {
		// bouffée : gonfle vite au départ puis plus lentement ; étirée dans le sens de la vitesse (souffle, pas langue)
		float sz = mix(taille0, taille1, pow(min(a, 1.0), 0.6)) * (0.7 + 0.6 * COLOR.g);
		// (plus étirées en vol : un flot soudé, pas un chapelet de boules ; peu étirées une fois écrasées)
		float el = ecrase ? 1.0 + clamp(vl * 0.12, 0.0, 1.2) : 1.0 + clamp(vl * 0.36, 0.0, 4.6);
		TRANSFORM[0].xyz = ax * sz;
		TRANSFORM[1].xyz = vd * sz * el;
		TRANSFORM[2].xyz = cross(ax, vd) * sz;
	}
}
