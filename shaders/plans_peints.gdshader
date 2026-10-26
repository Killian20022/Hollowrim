// Lointain PEINT (refonte « lumière ») : au-delà de ~600 m, 4 plans en couches (cylindres centrés sur le centre de la
// carte, voir scripts/arriere_plan.gd). 8e passe : le dessin (silhouettes, facettes, neige, sapins, château) est PEINT
// UNE FOIS au démarrage par peinture_plans.gdshader dans une texture par plan ; ce shader ne fait plus que la lire et
// appliquer l'éclairage de l'heure (cycle.gd via arriere_plan._actualiser) et la perspective aérienne.
// - 1 texel = 1/6° x 1/6°, fixé sur le cylindre et lu sans interpolation : pas de scintillement en tournant.
// - Pas de tramage (ni Bayer ni bruit) ici ; le bruit 15 bits de ps1_post fait le reste.
// - Profondeur truquée comme arriere_plan.gdshader : derrière le monde, devant le ciel, tri exact entre plans.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

uniform float rayon = 1000.0;
uniform float niveau0 = 0.0;
uniform float voile = 0.3;              // perspective aérienne propre au plan (0 net, 1 = couleur d'horizon)
uniform float base_el = 1.0;            // élévation du pied du profil (°)
uniform sampler2D peinture : filter_nearest, repeat_disable;   // voir peinture_plans.gdshader (codage)
uniform float el0_t = -36.0;            // texel d'élévation de la rangée 0
uniform int hauteur_t = 256;            // nombre de rangées
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

float wrapd(float a) {
	return mod(a + 180.0, 360.0) - 180.0;
}

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 cp = PROJECTION_MATRIX * vp;
	cp.z = cp.w * (0.02 / max(cp.w, 40.0));
	POSITION = cp;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float az = degrees(atan(wp.x, wp.z));
	float el = degrees(atan(wp.y - niveau0, rayon));
	int ix = clamp(int(floor(az * TEXEL)) + 1080, 0, 2159);
	int iy = int(floor(el * TEXEL) - el0_t);
	vec4 t = texelFetch(peinture, ivec2(ix, clamp(iy, 0, hauteur_t - 1)), 0);
	if (iy >= hauteur_t || t.a < 0.12) {
		discard;
	}
	float classe = t.a;
	vec3 n = vec3(t.g * 2.0 - 1.0, t.b * 2.0 - 1.0, 0.0);
	n.z = sqrt(max(1.0 - n.x * n.x - n.y * n.y, 0.05));

	// lumière : l'astre du côté de son azimut (x = azimut croissant), rasante ; 7 paliers
	vec2 sh = normalize(dir_astre.xz + vec2(0.0001));
	float az_soleil = degrees(atan(sh.x, sh.y));
	float cs = sign(wrapd(az_soleil - az) + 0.001);
	vec3 Ld = normalize(vec3(cs * 0.9, 0.35, 0.3));
	float dif = clamp(dot(n, Ld), 0.0, 1.0);
	float ton = floor(min(dif, 0.999) * 7.0) / 6.0;
	float L = max(dot(normalize(dir_lum), vec3(0.0, 0.3, 0.0)) + 0.7, 0.0);
	vec3 lum = ambiant * 1.0 + col_lum * 0.95 * L * (0.2 + 0.8 * ton);
	vec3 roche_o = vec3(0.030, 0.037, 0.058);
	vec3 roche_c = vec3(0.090, 0.090, 0.105);
	vec3 neige_o = vec3(0.20, 0.24, 0.34);
	vec3 neige_c = vec3(0.62, 0.62, 0.68);
	vec3 col;
	float v_fact = 1.0;
	float prof_f = 0.0;
	if (classe < 0.37) {
		// montagne : roche ou neige, clarté peinte
		bool neige = t.r >= 0.5;
		float b = neige ? (t.r - 0.5) * 2.0 : t.r / 0.45;
		col = (neige ? mix(neige_o, neige_c, ton) : mix(roche_o * 0.5, roche_c * 0.8, ton)) * lum * mix(0.45, 1.0, b);
		col *= mix(1.0, dif > 0.35 ? 1.12 : 0.62, jour);   // de jour : contraste lumière / ombre renforcé
		float lc = dot(col, vec3(0.3, 0.55, 0.15));
		col *= min(1.0, 0.48 / max(lc, 0.001));
	} else if (classe < 0.62) {
		// forêt : ramure vert-noir bleuté, neige au bord des branches, rangs du fond plus voilés
		bool neige = t.r >= 0.5;
		prof_f = neige ? (t.r - 0.5) / 0.45 : t.r / 0.45;
		vec3 f = vec3(0.022, 0.040, 0.045) * (ambiant * 1.6 + col_lum * 0.5 * L * ton);
		col = neige ? mix(neige_o * 0.7, neige_c * 0.6, ton) * (ambiant * 1.1 + col_lum * 0.6 * L) : f;
	} else if (classe < 0.87) {
		// château et falaise
		if (t.r < 0.25) {
			// pierre du château (C6) : gris bleuté lisible, face au soleil nettement éclairée, sombre la nuit
			col = vec3(0.085, 0.088, 0.105) * (ambiant * 1.1 + col_lum * 0.8 * (0.25 + 0.75 * ton));
			v_fact = 0.3;
		} else if (t.r < 0.5) {
			col = neige_o * (ambiant * 1.3 + col_lum * 0.5);
			v_fact = 0.6;
		} else if (t.r < 0.7) {
			// falaise (C6) : roche sombre en facettes (ombre / lumière), plus foncée que les murs pour qu'on lise le château dessus
			col = vec3(0.034, 0.038, 0.050) * (ambiant * 1.1 + col_lum * 0.9 * (0.15 + 0.85 * ton)) * (t.r < 0.58 ? 0.7 : 1.0);
			v_fact = 0.45;
		} else if (t.r < 0.9) {
			col = vec3(0.018, 0.032, 0.034) * (ambiant * 1.5 + col_lum * 0.2);
			v_fact = 0.35;
		} else {
			col = neige_o * (ambiant * 1.2 + col_lum * 0.5 * (0.3 + 0.7 * ton));
			v_fact = 0.35;
		}
	} else {
		// fenêtre : chaude la nuit
		col = mix(vec3(0.045, 0.048, 0.060) * (ambiant * 1.4), vec3(1.6, 0.9, 0.4), 0.95 * (1.0 - 0.55 * jour));
		v_fact = 0.18;
	}

	// --- perspective aérienne du plan, plus forte au pied ; de jour voile léger en haut et bleu en bas
	vec2 dh = normalize(wp.xz - CAMERA_POSITION_WORLD.xz + vec2(0.0001));
	float k = smoothstep(-0.2, 1.0, dot(dh, sh));
	vec3 hz = mix(horizon, horizon_chaud, crep * k);
	float pied = 1.0 - smoothstep(base_el - 1.0, base_el + 2.5, el);
	float bas_j = jour * (1.0 - smoothstep(base_el, base_el + 6.0, el));
	float v = clamp(voile * mix(1.0, 0.55, jour) + (0.35 * pied + 0.35 * bas_j) * (1.0 - voile) + 0.25 * prof_f, 0.0, 0.95);
	hz = mix(hz, hz * vec3(0.72, 0.88, 1.25), bas_j);
	// raccord (correctif lac_horizon) : le pied du plan se fond TOUT À FAIT dans la brume du monde (là où la vallée le
	// laisse voir au-dessus du sol noyé), sinon un bord sombre « flotte » sur la bande de brouillard
	float raccord = 1.0 - smoothstep(base_el - 1.0, base_el + 3.5, el);
	ALBEDO = mix(mix(col, hz, v * v_fact), mix(horizon, horizon_chaud, crep * k), raccord);
}
