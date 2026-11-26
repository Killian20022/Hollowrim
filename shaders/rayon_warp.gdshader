// STRIES DE VITESSE LUMIÈRE plein écran du RAYON NOIR (scripts/magie/rayon_noir.gd, v4) : quad face à la caméra, posé juste devant l'œil
// (vue joueur seulement) et plus grand que l'écran. Des traits de lumière filent radialement depuis le POINT DE FUITE du tir (là où
// pointe le rayon) vers les bords de l'écran, comme un saut hyperespace : très nombreux au déclenchement (`elan` 1 → 0), puis continus
// et plus discrets tant que le rayon est tenu. ADDITIF (ne peut pas assombrir), centre dégagé (le tir et la main restent lisibles).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 bord : source_color = vec3(0.78, 0.13, 0.66);
uniform vec3 filet : source_color = vec3(1.0, 0.77, 0.95);
uniform vec2 fuite = vec2(0.5, 0.5);   // point de fuite (UV du quad)
uniform vec2 taille = vec2(1.78, 1.0); // côtés du quad rapportés à sa hauteur
uniform float elan = 0.0;
uniform float force = 0.0;             // 0 (rien) → 1 (plein)
uniform float graine = 0.0;

float h11(float x) { return fract(sin(x * 127.1 + graine * 3.7) * 43758.5453); }

void fragment() {
	do {
		if (force <= 0.003) {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
			break;
		}
		vec2 q = (UV - fuite) * taille;   // en hauteurs d'écran, y vers le bas
		float r = length(q);
		float ang = atan(q.y, q.x);
		float n = 110.0 + 70.0 * elan;
		float cell = floor(fract(ang / TAU) * n);
		float h1 = h11(cell), h2 = h11(cell + 13.0), h3 = h11(cell + 29.0), h4 = h11(cell + 53.0);
		float lat = abs(fract(ang / TAU * n) - 0.5) * TAU * r / n;   // distance latérale au trait (hauteurs d'écran)
		float larg = (0.0016 + 0.0016 * h4) * (1.0 + 0.8 * elan);
		float on = step(h1, 0.5 + 0.35 * elan);
		float vit = (1.7 + 2.3 * h2) * (1.0 + 1.1 * elan);
		float tete = 0.1 + fract(h3 * 7.0 + TIME * vit) * 1.25;
		float lon = (0.18 + 0.55 * h2) * (1.0 + 0.6 * elan);
		float u = (r - (tete - lon)) / lon;
		float tr = step(0.0, u) * step(u, 1.0) * pow(clamp(u, 0.0, 1.0), 1.6);
		float ligne = 1.0 - smoothstep(larg * 0.4, larg, lat);
		float cache = smoothstep(0.1, 0.3, r);    // centre dégagé
		float b = tr * ligne * on * cache;
		vec3 c = mix(bord * 1.4, mix(bord, filet, 0.4) * 2.0, smoothstep(0.55, 1.0, u));   // v5 : stries violettes, têtes moins blanches (v4 : filet × 3)
		ALBEDO = c * b * force * (0.7 + 0.56 * elan);   // v5b : pic -30 % (1,8 -> 1,26), la retombée garde la vitesse lumière
		ALPHA = 0.0;
	} while (false);
}
