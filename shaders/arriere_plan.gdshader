// Arrière-plan lointain (montagnes, collines boisées, château) : voir scripts/arriere_plan.gd.
// Non affecté par le brouillard de Godot (fog_disabled), éclairé « à la main » (lune/soleil + ambiant lus chaque image)
// et avec SA PROPRE perspective atmosphérique : plus c'est loin ou bas, plus la couleur tend vers l'horizon du ciel.
// Profondeur truquée : tout est écrit juste devant le plan lointain (derrière le monde, devant le ciel) et sans
// être coupé par camera.far (90 m). z_ndc = k / w est linéaire à l'écran : le tri entre couches reste exact.
// Sommet : COLOR.r = densité de forêt (terrain) ; COLOR.g = grain ; COLOR.b = catégorie / 5
// (0 terrain, 1 sapin, 2 pierre, 3 glace, 4 roche massive, 5 fenêtre allumée).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

uniform vec3 horizon : source_color = vec3(0.05, 0.075, 0.13);
uniform vec3 horizon_chaud : source_color = vec3(0.05, 0.075, 0.13);
uniform vec3 dir_astre = vec3(-0.8, 0.0, 0.6);
uniform float crep = 0.0;
uniform vec3 haut : source_color = vec3(0.008, 0.012, 0.035);
uniform vec3 dir_lum = vec3(0.3, 0.6, -0.7);       // vers la lumière (lune ou soleil)
uniform vec3 col_lum : source_color = vec3(0.45, 0.54, 0.75);
uniform vec3 ambiant : source_color = vec3(0.18, 0.22, 0.34);
uniform float niveau0 = 0.0;                        // altitude du sol du village (m)
uniform float jour = 0.0;
uniform float dist_brume = 1000.0;                  // distance où la brume atteint ~63 %

varying vec3 wp;
varying vec3 wn;
varying vec4 vc;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 cp = PROJECTION_MATRIX * vp;
	cp.z = cp.w * (0.02 / max(cp.w, 40.0));
	POSITION = cp;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vc = COLOR;
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 vers_cam = normalize(CAMERA_POSITION_WORLD - wp);
	if (dot(n, vers_cam) < 0.0) {
		n = -n;  // cull_disabled : la normale regarde toujours le spectateur (solides fermés : face arrière jamais visible)
	}
	float cat = floor(vc.b * 5.0 + 0.5);
	if (cat != 1.0) {
		// facettes franches (low-poly lisible aux deux résolutions) mêlées à la normale lissée
		vec3 nf = normalize(cross(dFdx(wp), dFdy(wp)));
		if (dot(nf, n) < 0.0) {
			nf = -nf;
		}
		n = normalize(mix(n, nf, 0.45));  // facettes adoucies : arêtes lisibles sans « papier froissé »
	}
	float alt = wp.y - niveau0;
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float pente = 1.0 - n.y;
	// détails fins seulement tant qu'ils restent plus gros qu'un pixel (pas de scintillement au loin)
	float fin = 1.0 - smoothstep(500.0, 1300.0, dist);
	float na = vnoise(vec2(wp.x * 0.7 + wp.z, wp.y * 1.4) * 0.03);
	float nb = vnoise(wp.xz * 0.045 + 7.0);
	float nc = vnoise(vec2(wp.x * 0.8 + wp.z, wp.y * 1.5) * 0.13) * fin;
	float strie = vnoise(vec2((wp.x * 0.7 + wp.z) * 0.05, wp.y * 0.006));  // couloirs verticaux

	// --- neige (2e passe « lumière ») : la roche domine les pentes raides ; la neige tient sur les replats et les
	// épaules, et descend en COULÉES et COULOIRS étroits dans les faces raides ; au-dessus de la ligne de neige seulement
	float ligne = 110.0 + (nb - 0.5) * 70.0;
	float neige_alt = smoothstep(ligne - 40.0, ligne + 25.0, alt);
	float sol_pente = smoothstep(0.08 + na * 0.08, 0.17 + na * 0.10, pente);       // 1 = trop raide pour tenir
	// couloirs de neige en TRAITS FINS qui descendent les faces raides (bruit très étiré à la verticale)
	float strie_f = vnoise(vec2((wp.x * 0.7 + wp.z) * 0.16, wp.y * 0.008));
	float couloir = smoothstep(0.70, 0.74, strie_f) * smoothstep(70.0, 130.0, alt);
	float coulee = smoothstep(0.66, 0.72, vnoise(vec2((wp.x * 0.7 + wp.z) * 0.09, wp.y * 0.015))) * 0.8;
	if (cat > 3.5 && cat < 4.5) {
		neige_alt = smoothstep(0.78, 0.95, n.y) * 0.9;  // falaise : roche nue, neige sur les replats seulement
		sol_pente = 0.0;
		couloir = 0.0;
		coulee = 0.0;
	}
	float neige = clamp(neige_alt * ((1.0 - sol_pente) + sol_pente * max(couloir, coulee * fin)), 0.0, 1.0);
	neige = step(0.5, neige + (nc - 0.25) * 0.3);   // bord franc (pixel art), découpé par le bruit fin

	// --- matières : roche gris-bleu sombre en strates, neige blanc-gris bleuté
	float strates = 0.5 + 0.5 * sin(wp.y * 0.55 + na * 5.0 + nc * 2.0);
	vec3 roche = mix(vec3(0.028, 0.033, 0.048), vec3(0.085, 0.098, 0.13), clamp(na * 0.7 + strates * 0.3 + nc * 0.3, 0.0, 1.0));
	vec3 neige_c = mix(vec3(0.46, 0.51, 0.62), vec3(0.66, 0.71, 0.80), nb);  // blanc-gris bleuté (référence), jamais blanc pur
	vec3 foret = mix(vec3(0.022, 0.05, 0.05), vec3(0.06, 0.10, 0.08), clamp(vc.g * 0.8 + nc * 0.5, 0.0, 1.0));
	vec3 albedo;
	if (cat < 0.5 || cat > 3.5) {
		float f = (cat > 3.5 ? 0.0 : vc.r) * (1.0 - neige_alt * 0.8) * (1.0 - sol_pente);
		f = smoothstep(0.35, 0.6, f + (na - 0.5) * 0.3);
		albedo = mix(roche, neige_c, neige);
		albedo = mix(albedo, foret, f * (1.0 - neige * 0.7));
		albedo = mix(albedo, neige_c * 0.7, f * neige_alt * 0.25);
	} else if (cat < 1.5) {
		albedo = mix(foret, neige_c * 0.55, clamp(neige_alt * 0.5 + vc.g * 0.12, 0.0, 1.0) * (0.4 + 0.6 * n.y));
	} else if (cat < 2.5) {
		// château : pierre sombre (silhouette sur le ciel), neige sur les dessus seulement
		float pierre = h21(floor(vec2(wp.x + wp.z, wp.y * 2.0) * 0.45));
		albedo = mix(vec3(0.050, 0.054, 0.068), vec3(0.110, 0.115, 0.135), pierre);  // un ton au-dessus du socle : murailles lisibles
		albedo = mix(albedo, neige_c * 0.85, max(smoothstep(0.8, 0.95, n.y) * 0.85, step(0.5, vc.r)));  // toits enneigés
	} else {
		albedo = vec3(0.56, 0.70, 0.84) * (0.85 + 0.15 * nb);  // glace
	}

	// --- éclairage par face orientée vers l'astre : faces au soleil claires, faces à l'ombre sombres et froides
	float diff = max(dot(n, normalize(dir_lum)), 0.0);
	diff = floor(diff * 4.0 + 0.5) / 4.0;   // paliers : arêtes nettes entre face éclairée et face à l'ombre
	float ciel = 0.55 + 0.45 * n.y;
	float lum_dir = (cat > 1.5 && cat < 4.5) ? 0.35 : 0.85;
	vec3 col = albedo * (ambiant * ciel * 1.05 + col_lum * diff * lum_dir);
	if (cat < 0.5 || cat > 3.5 && cat < 4.5) {
		// neige lointaine : jamais blanc pur au soleil (rosée / dorée au crépuscule, plafonnée)
		float lc = dot(col, vec3(0.3, 0.55, 0.15));
		col *= min(1.0, 0.40 / max(lc, 0.001));
	}
	if (cat > 4.5) {
		col = mix(col, vec3(1.6, 0.9, 0.4), 0.95 * (1.0 - jour));  // fenêtre allumée au crépuscule et la nuit
		albedo = vec3(0.1);
	}

	// --- perspective atmosphérique EN COUCHES (refonte « lumière ») : chaque plan (collines < 450 m, montagnes
	// < 1 000 m, lointain) a son voile, presque constant, avec un saut net d'une couche à l'autre ; une nappe de
	// brume claire noie le pied de chaque plan (vallées) : les silhouettes se détachent l'une derrière l'autre.
	float couche = smoothstep(380.0, 520.0, dist) + smoothstep(900.0, 1150.0, dist);
	float hd = mix(0.18, 0.48, couche * 0.5) + 0.27 * smoothstep(1150.0, 2400.0, dist);  // le plan le plus lointain est le plus pâle
	// RACCORD AU SOL (correctif lac_horizon) : le brouillard du monde est TOTAL dès ~60 m (cycle.fin_brume) ; le relief
	// lointain commence à 150 m, 22 m au moins au-dessus du village. L'ancienne nappe (85 % au plus, bord à 7-30 m
	// d'altitude) laissait la forêt sombre posée net sur la bande de monde noyée : l'arrière-plan « flottait » sur une
	// bande blanche. Le pied de chaque plan est maintenant dans la brume du monde (couleur exacte, 100 %) et en sort
	// progressivement sur une cinquantaine de mètres de dénivelé : aucun bord.
	float pied0 = 18.0 + 22.0 * couche;
	float pied1 = pied0 + 55.0 + 35.0 * couche;
	float hb = 1.0 - smoothstep(pied0, pied1, alt + (nb - 0.5) * 8.0);
	float haze = hd;
	if (cat > 1.5) {
		haze *= (cat > 4.5) ? 0.25 : 0.45;  // château et falaise : silhouette sombre sur le ciel ; fenêtres nettes
	}
	vec3 dv = wp - CAMERA_POSITION_WORLD;
	vec2 dh = normalize(dv.xz + vec2(0.0001));
	float az = smoothstep(-0.2, 1.0, dot(dh, normalize(dir_astre.xz + vec2(0.0001))));
	vec3 hz = mix(horizon, horizon_chaud, crep * az);   // = couleur_horizon(dir) du cycle : aucun raccord avec le ciel
	vec3 brume = mix(hz, haut, 0.18 * smoothstep(10.0, 160.0, alt));
	// crépuscule : seulement les cimes enneigées côté couchant se dorent
	float cime = smoothstep(60.0, 150.0, alt) * ((cat > 1.5 && cat < 4.5) ? 0.0 : 1.0);  // pas sur le château
	col += neige * cime * crep * az * az * (0.3 + 0.7 * diff) * vec3(0.55, 0.36, 0.17) * (1.0 - haze) * (1.0 - hb);
	col = mix(col, brume, haze);
	col = mix(col, hz, hb);   // pied : couleur du brouillard du monde (= horizon dans cette direction)
	ALBEDO = col;
}
