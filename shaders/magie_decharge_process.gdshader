// DÉCHARGE du jet électrique (couche fine ; scripts/magie/gestion_magie.gd, _decharge_*) : simulation des ÉCLATS.
// Même architecture que la vague de flammes (magie_vague_process) : un GPUParticles3D par jet, rien sur le CPU.
// L'arc suit une courbe de Bézier quadratique paume → contrôle → bout (uniformes `o`, `c`, `b`, posés chaque image par
// _decharge_placer, mêmes points que l'arc maître CPU de _gen_jet_arc_vif). Chaque éclat vit 3 à 5 images et se
// RECALCULE à chaque image sur la courbe actuelle (il colle à l'arc même quand on tourne vite) :
//   genre 0 = trait (forme d'éclair spark_05-07 / trace_03, étiré le long de l'arc, de travers, décalé du milieu) ;
//   genre 1 = crépitement (nuage d'éclairs spark_01/02/04) au bout touché (gros) ou dans la paume (petit) ;
//   genre 2 = étincelle projetée depuis le bout (traînée trace_03 étirée dans le sens de sa vitesse, tombe) ;
//   genre 3 = éclair-fourche qui SAUTE du bout de l'arc vers le corps de la cible (trait court, dirigé au hasard).
// CUSTOM : x = graine, y = âge (0..1), z = genre × 8 + case de l'atlas, w = position t sur l'arc.
// COLOR : rgb = décalage (perpendiculaires 1 et 2, inclinaison), a = 1.
shader_type particles;
render_mode disable_force, disable_velocity;

uniform vec3 o = vec3(0.0);                 // paume (monde)
uniform vec3 c = vec3(0.0, 0.0, -1.0);      // point de contrôle
uniform vec3 b = vec3(0.0, 0.0, -2.0);      // bout (point touché ou portée)
uniform float touche = 0.0;                 // 1 : l'arc frappe quelque chose (crépitement et fourches au bout)
uniform float force = 1.0;                  // 1,0 ; 1,35 en double incantation (traits plus longs et plus écartés)
// ÉCLATEMENT (impact d'un sort électrique sur une surface) : o = c = b = point touché ; les traits rayonnent autour de la
// normale au lieu de suivre un arc, les étincelles sont renvoyées le long de la normale.
uniform float eclatement = 0.0;
uniform vec3 normale = vec3(0.0, 1.0, 0.0);

float h1(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

vec3 bez(float t) {
	return o * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t;
}

vec3 tangente(float t) {
	vec3 d = 2.0 * (1.0 - t) * (c - o) + 2.0 * t * (b - c);
	float l = length(d);
	return l > 0.0001 ? d / l : vec3(0.0, 0.0, -1.0);
}

// place l'éclat d'après ses paramètres et la courbe ACTUELLE
void poser(inout mat4 tr, vec4 cu, vec3 col, float age) {
	float g = cu.x;
	int genre = int(cu.z) / 8;
	float t = cu.w;
	float l = max(distance(o, b), 0.05);
	vec3 d = eclatement > 0.5 ? -normale : tangente(t);
	vec3 n1 = abs(d.y) < 0.95 ? normalize(cross(d, vec3(0.0, 1.0, 0.0))) : vec3(1.0, 0.0, 0.0);
	vec3 n2 = cross(n1, d);
	vec3 p;
	vec3 ax;
	float demi;
	float larg;
	if (genre == 0 && eclatement > 0.5) {
		// éclatement : trait qui rayonne depuis le point touché (de biais par rapport à la surface)
		vec3 dr = normalize(normale * (0.2 + col.b * 0.6) + n1 * (col.r - 0.5) * 2.0 + n2 * (col.g - 0.5) * 2.0);
		demi = (0.18 + 0.3 * fract(g * 3.7)) * force * mix(0.8, 1.2, age);
		ax = dr;
		p = b + dr * demi * 0.9;
		larg = demi * 0.5;
	} else if (genre == 0) {
		// trait : écart au milieu de l'arc (nul contre la paume et au bout), inclinaison au hasard (±40°)
		// touché : l'écart retombe à zéro au point d'impact ; dans le vide, le bout s'effiloche en fourches (pas de boule)
		float ec = (touche > 0.5 ? sin(3.14159 * t) : sin(1.5708 * t)) * l * 0.035 * force;
		p = bez(t) + (n1 * (col.r - 0.5) + n2 * (col.g - 0.5)) * 2.0 * ec;
		float inc = (col.b - 0.5) * 0.7 * smoothstep(0.1, 0.5, t);
		vec3 dev = normalize(n1 * (col.r - 0.5) + n2 * (col.g - 0.5) + vec3(0.0001));
		ax = normalize(d * cos(inc) + dev * sin(inc));
		// longueur : courte près de la paume (donc de l'œil), un quart de l'arc ailleurs
		demi = mix(0.04, clamp(l * 0.1, 0.18, 0.7), smoothstep(0.05, 0.45, t)) * (0.75 + 0.5 * fract(g * 3.7)) * force;
		larg = demi * 0.5;
	} else if (genre == 1) {
		// crépitement : nuage d'éclairs, au bout (touché) ou dans la paume
		bool bout = t > 0.5;
		p = bez(bout ? 1.0 : 0.0) + (n1 * (col.r - 0.5) + n2 * (col.g - 0.5)) * (bout ? 0.3 : 0.03) + vec3(0.0, bout ? (col.b - 0.4) * 0.5 : 0.0, 0.0);
		if (bout) {
			p -= d * 0.3;
		}
		ax = normalize(n1 * cos(g * 9.0) + n2 * sin(g * 9.0));
		demi = (bout ? 0.14 + 0.14 * fract(g * 5.3) : 0.018 + 0.014 * fract(g * 5.3)) * mix(0.7, 1.15, age) * force;
		larg = demi;
	} else if (genre == 2) {
		// étincelle : part du bout dans un cône renvoyé, tombe ; position intégrée analytiquement (pas d'état à garder)
		float tps = age * 0.16;
		vec3 v0 = normalize(-d * 0.6 + n1 * (col.r - 0.5) * 2.2 + n2 * (col.g - 0.5) * 2.2 + vec3(0.0, 0.5, 0.0)) * (3.0 + 4.0 * col.b);
		p = b - d * 0.1 + v0 * tps + vec3(0.0, -4.9, 0.0) * tps * tps;
		vec3 v = v0 + vec3(0.0, -9.8, 0.0) * tps;
		ax = normalize(v);
		demi = 0.05 + length(v) * 0.012;
		larg = max(0.03, demi * 0.45);   // assez large pour que la forme d'éclair (fourchue) se lise : pas un bâton droit
	} else {
		// fourche : saute du bout vers le corps touché (de haut en bas, sur ~1 m)
		vec3 dev = normalize(n1 * (col.r - 0.5) * 2.0 + vec3(0.0, (col.g - 0.6) * 2.0, 0.0) + d * 0.3);
		demi = (0.1 + 0.14 * col.b) * force;
		p = b - d * 0.2 + dev * demi;
		ax = dev;
		larg = demi * 0.45;
	}
	tr[0].xyz = n1 * larg;   // largeur (remplacée par la perpendiculaire écran dans le dessin)
	tr[1].xyz = ax * demi;   // axe et demi-longueur
	tr[2].xyz = cross(n1, ax) * larg;
	tr[3].xyz = p;
}

void start() {
	uint s = NUMBER * 7u + RANDOM_SEED * 13u;
	float ra = h1(s + 1u), rb = h1(s + 2u), rc = h1(s + 3u), rd = h1(s + 4u), re = h1(s + 5u), rf = h1(s + 6u);
	// répartition : 70 % traits le long de l'arc, puis au bout (si touché) crépitements, étincelles, fourches
	int genre = 0;
	float t = mix(0.1, 1.0, rb);
	if (eclatement > 0.5) {
		genre = ra < 0.5 ? 0 : (ra < 0.65 ? 1 : (ra < 0.9 ? 2 : 3));
		t = 1.0;
	} else if (ra > 0.7) {
		float x = (ra - 0.7) / 0.3;
		if (touche > 0.5) {
			genre = x < 0.3 ? 1 : (x < 0.8 ? 2 : 3);
			t = 1.0;
			if (x < 0.1) {
				t = 0.0;   // un peu de crépitement reste dans la paume
			}
		} else {
			// dans le vide : un peu de crépitement dans la paume, le reste en traits supplémentaires vers le bout
			genre = x < 0.3 ? 1 : 0;
			t = x < 0.3 ? 0.0 : mix(0.3, 1.0, rb);
		}
	}
	int cas = genre == 1 ? 4 + int(rc * 2.99) : int(rc * 3.99);
	if (genre == 2) {
		cas = 3;
	}
	CUSTOM = vec4(rd * 37.0, 0.0, float(genre * 8 + cas), t);
	COLOR = vec4(re, rf, h1(s + 7u), 1.0);
	VELOCITY = vec3(0.0);
	TRANSFORM = mat4(1.0);
	poser(TRANSFORM, CUSTOM, COLOR.rgb, 0.0);
}

void process() {
	float a = CUSTOM.y + DELTA / LIFETIME;
	CUSTOM.y = a;
	if (a >= 1.0) {
		ACTIVE = false;
	}
	poser(TRANSFORM, CUSTOM, COLOR.rgb, min(a, 1.0));
}
