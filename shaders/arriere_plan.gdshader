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
uniform vec3 haut : source_color = vec3(0.008, 0.012, 0.035);
uniform vec3 dir_lum = vec3(0.3, 0.6, -0.7);       // vers la lumière (lune ou soleil)
uniform vec3 col_lum : source_color = vec3(0.45, 0.54, 0.75);
uniform vec3 ambiant : source_color = vec3(0.18, 0.22, 0.34);
uniform float niveau0 = 0.0;                        // altitude du sol du village (m)
uniform float jour = 0.0;
uniform float dist_brume = 1300.0;                  // distance où la brume atteint ~63 %

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
		n = normalize(mix(n, nf, 0.7));
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

	// --- neige : altitude, pente douce ; les couloirs gardent la neige dans les pentes raides
	float ligne = 135.0 + (nb - 0.5) * 100.0;
	float neige_alt = smoothstep(ligne - 55.0, ligne + 35.0, alt);
	float sol_pente = smoothstep(0.20 + na * 0.18, 0.42 + na * 0.2, pente);
	float couloir = smoothstep(0.58, 0.68, strie) * 0.85 * smoothstep(110.0, 170.0, alt);
	if (cat > 3.5 && cat < 4.5) {
		neige_alt = smoothstep(0.78, 0.95, n.y) * 0.9;  // falaise : roche nue, neige sur les replats seulement
		sol_pente = 0.0;
		couloir = 0.0;
	}
	float neige = clamp(neige_alt * (1.0 - sol_pente) + neige_alt * sol_pente * couloir, 0.0, 1.0);

	// --- matières
	float strates = 0.5 + 0.5 * sin(wp.y * 0.55 + na * 5.0 + nc * 2.0);
	vec3 roche = mix(vec3(0.15, 0.145, 0.17), vec3(0.30, 0.26, 0.24), clamp(na * 0.8 + strates * 0.3 + nc * 0.3, 0.0, 1.0));
	vec3 neige_c = mix(vec3(0.74, 0.80, 0.94), vec3(0.93, 0.95, 1.0), nb);
	vec3 foret = mix(vec3(0.022, 0.05, 0.05), vec3(0.06, 0.10, 0.08), clamp(vc.g * 0.8 + nc * 0.5, 0.0, 1.0));
	vec3 albedo;
	if (cat < 0.5 || cat > 3.5) {
		float f = (cat > 3.5 ? 0.0 : vc.r) * (1.0 - neige_alt * 0.8) * (1.0 - sol_pente);
		f = smoothstep(0.35, 0.6, f + (na - 0.5) * 0.3);
		albedo = mix(roche, neige_c, neige);
		albedo = mix(albedo, foret, f * (1.0 - neige * 0.7));
		// lisières claires : un peu de neige sur les sapins
		albedo = mix(albedo, neige_c * 0.7, f * neige_alt * 0.25);
	} else if (cat < 1.5) {
		albedo = mix(foret, neige_c * 0.55, clamp(neige_alt * 0.5 + vc.g * 0.12, 0.0, 1.0) * (0.4 + 0.6 * n.y));
	} else if (cat < 2.5) {
		float pierre = h21(floor(vec2(wp.x + wp.z, wp.y * 2.0) * 0.45));
		albedo = mix(vec3(0.11, 0.11, 0.14), vec3(0.24, 0.23, 0.25), pierre);
		albedo = mix(albedo, neige_c * 0.95, smoothstep(0.7, 0.95, n.y) * 0.85);
	} else {
		albedo = vec3(0.56, 0.70, 0.84) * (0.85 + 0.15 * nb);  // glace
	}

	// --- éclairage
	float diff = max(dot(n, normalize(dir_lum)), 0.0);
	float ciel = 0.65 + 0.35 * n.y;
	vec3 col = albedo * (ambiant * ciel * 1.6 + col_lum * diff * 0.9);
	if (cat > 4.5) {
		col = mix(col, vec3(1.6, 0.9, 0.4), 0.9 * (1.0 - jour));  // fenêtre allumée la nuit
		albedo = vec3(0.1);
	}

	// --- perspective atmosphérique : distance + brume basse (vallées)
	float hd = 1.0 - exp(-pow(dist / dist_brume, 1.1));
	float hb = (1.0 - smoothstep(4.0, 60.0, alt)) * 0.88;
	float haze = 1.0 - (1.0 - hd * 0.92) * (1.0 - hb);
	vec3 brume = mix(horizon, haut, 0.22 * smoothstep(10.0, 220.0, alt));
	float chaud = clamp((horizon.r - horizon.b) * 3.0, 0.0, 1.0);   // crépuscule : le haut des cimes rosit
	col += neige * chaud * diff * vec3(0.5, 0.3, 0.2) * (1.0 - haze);
	col = mix(col, brume, haze);
	ALBEDO = col;
}
