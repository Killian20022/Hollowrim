// Carte du monde (onglet Carte du menu, scripts/menu/carte_monde.gd) : relief vu de haut, PS1.
// - albédo : carte_couleur (1 m/texel, générée depuis le sol, l'eau, les forêts, les chemins) dans l'aire de jeu ;
//   au-delà : neige / roche / forêt procédurales (le pourtour de la cuvette), noyés dans la brume ;
// - courbes de niveau à l'encre (tous les `courbes_pas` m, maîtresse tous les 5) : la touche « carte » ;
// - ombres des nuages qui glissent (même bruit que la couche de nuages), brume de bord, grain de bruit (jamais de Bayer) ;
// - sommets accrochés à une grille d'écran (tremblement PS1), comme ps1.gdshader.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D carte_couleur : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 rect = vec4(-120.0, -120.0, 0.0041666667, 120.0);   // x0, z0, 1/taille, demi-côté de l'aire de jeu
uniform sampler2D nuages : filter_linear, repeat_enable;
uniform vec2 vent = vec2(0.0035, 0.0012);
uniform float echelle_nuages = 0.0042;
uniform float ombre_nuages = 0.22;
uniform vec3 brume_couleur : source_color = vec3(0.82, 0.85, 0.87);
uniform vec2 brume_dist = vec2(112.0, 205.0);
uniform float courbes = 0.32;
uniform float courbes_pas = 4.0;
uniform vec3 encre : source_color = vec3(0.17, 0.10, 0.12);
uniform float grille = 150.0;
uniform float temps = 0.0;   // posé par l'onglet (le jeu est en pause : TIME suffirait, mais on garde la main)

varying vec3 pm;
varying vec3 nm;

float h21(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0) * 0.5;
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec2 uv = (pm.xz - rect.xy) * rect.z;
	float bord = max(abs(pm.x), abs(pm.z));
	vec3 c;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		c = texture(carte_couleur, uv).rgb;
	} else {
		// pourtour : neige, roche sur les pentes, forêts sombres en taches
		float pente = 1.0 - nm.y;
		float foret = smoothstep(0.52, 0.66, vnoise(pm.xz * 0.045) * 0.7 + vnoise(pm.xz * 0.19) * 0.3) * (1.0 - smoothstep(0.18, 0.3, pente));
		c = mix(vec3(0.86, 0.89, 0.92), vec3(0.16, 0.24, 0.2), foret * 0.85);
		c = mix(c, vec3(0.42, 0.42, 0.45), smoothstep(0.22, 0.38, pente));
	}
	// courbes de niveau (dans l'aire de jeu seulement)
	if (courbes > 0.0) {
		float hcourbe = pm.y / courbes_pas;
		float f = abs(fract(hcourbe + 0.5) - 0.5) / max(fwidth(hcourbe), 1e-4);
		float ligne = 1.0 - smoothstep(0.4, 1.2, f);
		float maitresse = step(abs(mod(round(hcourbe), 5.0)), 0.5);
		ligne *= mix(0.55, 1.0, maitresse) * (1.0 - smoothstep(rect.w - 6.0, rect.w + 4.0, bord));
		c = mix(c, encre, ligne * courbes);
	}
	// ombre des nuages
	float n = texture(nuages, pm.xz * echelle_nuages + vent * temps).r;
	c *= 1.0 - ombre_nuages * smoothstep(0.5, 0.75, n);
	// grain
	c *= 0.97 + 0.06 * h21(floor(pm.xz * 2.0));
	// brume de bord
	float b = smoothstep(brume_dist.x, brume_dist.y, bord);
	ALBEDO = c;
	// la brume « éclaire » : on mélange vers la couleur de brume, en émission pour qu'elle ne soit pas ombrée
	ALBEDO = mix(c, vec3(0.0), b);
	EMISSION = brume_couleur * b;
}
