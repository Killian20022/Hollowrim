// Modes d'émission des écoles de l'agent B (inclus par magie_corps_part.gdshader, numéros 6 et suivants, sans renuméroter) :
//   6 aspire  : ténèbres : fragments ARRACHÉS à la surface (surtout côté lanceur) et aspirés vers la main (point_main, monde),
//               en spirale autour de l'axe ; meurent en arrivant dans la paume
//   7 givre   : glace : sur la zone gelée (distance au point_impact < rayon_jet, force k_jet) : cristaux, scintillements, buée
//   8 fonte   : glace : gouttes qui tombent de la zone gelée pendant la fonte (force k_foyers)
// Les paramètres du foyer sont réutilisés (lus dans la texture des points depuis la fusion avec le socle de A, passés en
// arguments) : point_impact = origine du givre, rayon_jet = rayon couvert, dir_jet = direction du jet / du lanceur vers
// le corps, k_jet / k_foyers = forces ; point_main (monde, mode 6) = texel P+7 (réservé aux écoles B).
uniform float aspiration = 22.0;                 // m/s² vers la main (mode 6)
uniform float tourbillon = 6.0;                  // m/s² autour de l'axe corps → main (mode 6)

vec3 point_main() {
	return texelFetch(pts, ivec2(P + 7, 0), 0).xyz;
}

float masque_givre(vec3 p, vec3 point_impact, float rayon_jet) {
	float r = max(rayon_jet, 0.001);
	float di = length(p - point_impact);
	return 1.0 - smoothstep(r * 0.75, r, di);
}

vec2 poids_ecoles(vec3 p, vec3 n, float face, float prox, float k_jet, vec3 point_impact, float rayon_jet, float k_foyers) {
	float w = 0.0;
	float c = 0.0;
	if (mode == 6) {
		// côté tourné vers le lanceur surtout, mais toute la silhouette « se vide »
		w = k_jet * (0.15 + 0.85 * face * face) + k_foyers * foyer(p) * 0.5;
		c = clamp(face, 0.0, 1.0);
	} else if (mode == 7) {
		w = k_jet * masque_givre(p, point_impact, rayon_jet) * (0.5 + 0.5 * clamp(n.y * 0.5 + 0.5, 0.0, 1.0));
		c = 0.5;
	} else if (mode == 8) {
		// gouttes : bas des formes gelées (normale vers le bas) pendant la fonte
		w = k_foyers * masque_givre(p, point_impact, rayon_jet) * (0.3 + 0.7 * clamp(-n.y, 0.0, 1.0));
		c = 0.0;
	}
	return vec2(w, c);
}

vec3 depart_ecoles(vec3 p, vec3 n, vec3 d, inout uint s, inout vec3 pos) {
	vec3 up = vec3(0.0, 1.0, 0.0);
	if (mode == 6) {
		// arraché : part le long de la normale, l'aspiration le courbe ensuite vers la main
		return n * 1.0 + up * 0.15;
	} else if (mode == 7) {
		// presque immobile, collé à la surface (scintillement) ou buée qui glisse et retombe (gravité du réglage)
		pos += n * 0.01;
		return n * 0.6 + up * 0.2;
	}
	// 8 : la goutte se détache vers le bas
	return -up + n * 0.25;
}

// mode 6 : accélération vers la main + tourbillon autour de l'axe ; vrai = la particule est arrivée (à éteindre)
bool aspirer(inout vec3 vel, vec3 p, float dt, uint index, float t) {
	vec3 v = point_main() - p;
	float l = length(v);
	if (l < 0.16) {
		return true;
	}
	vec3 ax = v / l;
	vec3 tg = normalize(cross(ax, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
	vec3 tg2 = cross(ax, tg);
	float ph = float(index) * 2.39;
	vel += (ax * aspiration * (0.6 + 0.4 * min(l, 3.0) / 3.0) + (tg * cos(ph + t * 3.0) + tg2 * sin(ph + t * 3.0)) * tourbillon) * dt;
	// vitesse orientée vers la main (pas d'orbite qui dépasse la paume)
	float vv = length(vel);
	vel = mix(vel, ax * vv, clamp(dt * 3.5, 0.0, 1.0));
	return false;
}
