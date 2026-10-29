// VAGUE de flammes du jet de feu (couche fine ; scripts/magie/gestion_magie.gd, _vague_*) : simulation des BOUFFÉES.
// Chaque bouffée naît dans la paume, part dans un cône étroit à grande vitesse, freine (traînée de l'air), grossit, monte
// de plus en plus (flottabilité), est poussée par une turbulence qui dépend de sa position (les voisines se tordent
// ensemble) et vieillit : son âge pilote la couleur dans le shader de dessin (magie_vague.gdshader : blanc-jaune → orange
// → rouge sombre → fumée). Les bouffées vivent dans le repère du MONDE (local_coords = false) : quand on tourne la vue,
// celles déjà parties continuent leur route (jet « tuyau d'arrosage »), seules les nouvelles suivent la main.
// Plan d'arrêt (`arret`) : au-delà du point touché (cible, mur), la vitesse vers l'avant passe en ÉTALEMENT latéral et la
// bouffée vieillit plus vite : la vague s'écrase et lèche la surface au lieu de la traverser.
// CUSTOM : x = graine, y = âge (0..1), z = rotation (rad), w = vitesse de rotation. COLOR.r = température propre.
shader_type particles;
render_mode disable_force;

uniform float vitesse = 16.0;     // vitesse de sortie (m/s)
uniform float traine = 1.25;      // freinage (1/s) : x(t) = v0 / k · (1 - e^(-k t))
uniform float ecart = 0.09;       // demi-ouverture du cône de sortie (rad)
uniform float taille0 = 0.13;     // rayon à la naissance (m)
uniform float taille1 = 0.95;     // rayon en fin de vie (m)
uniform float montee = 2.2;       // flottabilité (m/s², croît avec l'âge)
uniform float turb = 3.0;         // turbulence (m/s²)
uniform vec4 arret = vec4(0.0, 0.0, 0.0, 0.0);   // xyz = point touché (monde), w = 1 si le jet touche quelque chose
uniform vec3 arret_dir = vec3(0.0, 0.0, -1.0);   // direction du jet (monde) au point touché
uniform float etale = 3.0;        // vieillissement après l'impact (×)
// SOUS-PAS d'émission : repère de l'émetteur à l'image précédente et durée de l'image. Chaque bouffée naît à un instant
// tiré dans l'image écoulée : origine et direction interpolées entre les deux repères, déjà avancée du temps écoulé.
// Le jet reste d'un seul tenant même quand on tourne vite (plus de chapelet image par image).
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
	// direction dans le cône (repère de l'émetteur, -Z = avant) : la plupart près de l'axe, quelques-unes plus ouvertes
	float th = ra * 6.2831853;
	float rr = pow(rb, 0.75) * ecart;
	vec3 d = normalize(vec3(cos(th) * rr, sin(th) * rr, -1.0));
	float v = vitesse * (0.78 + 0.44 * rc);
	vec3 p = vec3(cos(th) * 0.02 * rd, sin(th) * 0.02 * rd, -0.04);
	float rs = h1(b + 6u);                     // 0 = maintenant, 1 = début de l'image écoulée
	float dt0 = rs * min(pas, 0.05);
	mat3 bc = mat3(EMISSION_TRANSFORM[0].xyz, EMISSION_TRANSFORM[1].xyz, EMISSION_TRANSFORM[2].xyz);
	vec3 vw = normalize(mix(bc * d, prec_base * d, rs)) * v;
	vec3 ow = mix(EMISSION_TRANSFORM[3].xyz, prec_o, rs) + mix(bc * p, prec_base * p, rs);
	if (RESTART_POSITION) {
		TRANSFORM = mat4(vec4(taille0, 0.0, 0.0, 0.0), vec4(0.0, taille0, 0.0, 0.0), vec4(0.0, 0.0, taille0, 0.0),
			vec4(ow + vw * dt0, 1.0));
	}
	if (RESTART_VELOCITY) {
		VELOCITY = vw;
	}
	if (RESTART_CUSTOM) {
		CUSTOM = vec4(rd * 37.0, dt0 / LIFETIME, ra * 6.2831853, (re - 0.5) * 5.0);
	}
	if (RESTART_COLOR) {
		COLOR = vec4(re, rc, 0.0, 1.0);
	}
}

void process() {
	float a = CUSTOM.y;
	vec3 p = TRANSFORM[3].xyz;
	float g = CUSTOM.x;
	float k_age = 1.0;
	// freinage de l'air
	VELOCITY *= exp(-traine * DELTA);
	// flottabilité : la flamme monte de plus en plus en refroidissant
	VELOCITY.y += montee * a * a * DELTA;
	// turbulence : champ lisse qui dépend de la position (voisines cohérentes) et du temps ; nulle à la naissance
	float t = TIME;
	vec3 tu = vec3(sin(p.y * 1.9 + p.z * 0.7 + t * 3.1 + g),
				   sin(p.z * 1.6 + p.x * 0.9 + t * 2.6 + g * 1.3),
				   sin(p.x * 1.7 + p.y * 1.1 - t * 2.9 + g * 0.7));
	VELOCITY += tu * turb * smoothstep(0.05, 0.5, a) * DELTA;
	// impact : au-delà du point touché, l'avancée devient étalement latéral, la bouffée s'écrase et vieillit vite
	if (arret.w > 0.5) {
		float s = dot(p - arret.xyz, arret_dir);
		if (s > -0.35) {
			float vp = dot(VELOCITY, arret_dir);
			if (vp > 0.0) {
				vec3 lat = (p - arret.xyz) - arret_dir * s;
				float ll = length(lat);
				vec3 dl = ll > 0.01 ? lat / ll : normalize(vec3(sin(g * 3.0), 0.4, cos(g * 3.0)));
				float q = min(1.0, DELTA * 14.0);
				VELOCITY += (dl * 0.7 + vec3(0.0, 0.45, 0.0) - arret_dir) * vp * q;
			}
			k_age = etale;
		}
	}
	a += DELTA / LIFETIME * k_age;
	CUSTOM.y = a;
	if (a >= 1.0) {
		ACTIVE = false;
	}
	CUSTOM.z += CUSTOM.w * DELTA * (1.0 - 0.6 * a);
	// taille : gonfle vite au départ puis plus lentement (la flamme s'ouvre), chaque bouffée à sa mesure
	float sz = mix(taille0, taille1, pow(min(a, 1.0), 0.6)) * (0.7 + 0.6 * COLOR.g);
	// étirement dans le sens de la vitesse : les bouffées jeunes et rapides sont des LANGUES qui filent (le jet est
	// continu à la sortie de la main), les vieilles, freinées, s'arrondissent. Axe Y = vitesse × étirement ; X = rayon.
	float vl = length(VELOCITY);
	vec3 vd = vl > 0.001 ? VELOCITY / vl : vec3(0.0, 0.0, -1.0);
	float el = 1.0 + clamp(vl * 0.26, 0.0, 4.2);
	vec3 ax = abs(vd.y) < 0.95 ? normalize(cross(vd, vec3(0.0, 1.0, 0.0))) : vec3(1.0, 0.0, 0.0);
	TRANSFORM[0].xyz = ax * sz;
	TRANSFORM[1].xyz = vd * sz * el;
	TRANSFORM[2].xyz = cross(ax, vd) * sz;
}
