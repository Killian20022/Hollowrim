// Flocons de la neige qui tombe (monde.gd _neige) : chaque flocon est un CARRÉ DE PIXELS ENTIERS du monde, posé sur la
// grille des pixels, qui se déplace d'un pixel à la fois (comme l'accroche des sommets du ps1). Avant, un quad de 5 cm passait
// sous la taille d'un pixel au loin et scintillait (allumé/éteint selon qu'il couvrait un centre de pixel).
// Un flocon plus petit qu'un pixel reste visible avec la probabilité (taille en pixels)² — tirée une fois par flocon —
// pour garder la densité apparente d'avant sans aucun scintillement ; près de l'objectif (fondu_proche) les flocons s'éclaircissent
// un à un, tirés eux aussi par flocon (au sommet : aucun discard, voir outils/test_shaders_sans_discard.gd).
// Interrupteur : --neige-psx=0 rend l'ancien StandardMaterial3D.
//
// Projection en carré de pixels entiers reprise de dragthelake/godot-psx-shader
// (addons/tk_psx/shaders/psx_particles.gdshaderinc, tk_look/shaders/look_particles.gdshaderinc),
// MIT, Copyright (c) 2026 dragthelake — voir THIRD_PARTY.md.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, specular_disabled;

uniform vec3 couleur : source_color = vec3(0.85, 0.9, 1.0);
uniform float taille_m = 0.05;        // côté du quad à l'échelle 1 (m)
uniform float pixels_max = 3.0;       // plafond (un flocon tout près ne devient pas un pavé)
uniform vec2 fondu_proche = vec2(0.4, 1.5);   // près de l'objectif (m) : flocons retirés un à un (comme l'ancien distance_fade tramé)
global uniform float magie_pas;

float hash_u(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / 2147483647.0;
}

void vertex() {
	vec4 vue = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	float dist_cam = length(vue.xyz);
	vec4 clip = PROJECTION_MATRIX * vue;
	vec2 res = VIEWPORT_SIZE / max(magie_pas, 1.0);   // pixels du MONDE (couche fine de la magie : monde agrandi ×k)
	float metres = taille_m * length(MODEL_MATRIX[0].xyz);
	float px = clip.w > 0.0 ? metres * abs(PROJECTION_MATRIX[1][1]) * 0.5 * res.y / clip.w : 0.0;
	uint id = uint(INSTANCE_ID);
	bool garde = hash_u(id * 747796405u + 12345u) < px * px
			&& hash_u(id * 2891336453u + 777u) < smoothstep(fondu_proche.x, fondu_proche.y, dist_cam);
	if (clip.w <= 0.0 || !garde) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);   // trop petit cette fois-ci (ou derrière) : rien n'est dessiné
	} else {
		float cote = clamp(floor(px + 0.5), 1.0, pixels_max);
		vec2 centre = (clip.xy / clip.w * 0.5 + 0.5) * res;
		vec2 coin = floor(centre - cote * 0.5 + 0.5) + UV * cote;
		POSITION = vec4((coin / res * 2.0 - 1.0) * clip.w, clip.z, clip.w);
	}
}

void fragment() {
	ALBEDO = couleur;
}
