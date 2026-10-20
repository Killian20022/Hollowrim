// Lumière volumétrique des intérieurs : rai du trou à fumée et halos des feux (cartes additives sans ARÊTE visible).
// - mode 0, « rai » : plusieurs plans verticaux croisés (voir `Interieurs.finir`) ; chaque plan s'efface quand on le voit
//   de biais (facteur cos², la somme de quatre plans à 45° est uniforme : le rai est un volume, pas un panneau), fondu
//   doux sur les bords, en haut et en bas, fondu de PROFONDEUR contre la charpente/le plancher/les meubles, poussière
//   qui monte lentement ;
// - mode 1, « halo » : lueur radiale calculée (pas de texture, pas de paliers), fondu de profondeur et d'angle pour
//   les cartes verticales (appliques) ; les halos au sol ne sont pas fondus en profondeur (le sol est juste dessous).
// Tramage par bruit d'écran (jamais de Bayer) pour garder le grain 32 bits.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform int mode = 0;
uniform float intensite = 1.0;
uniform float fondu_profondeur = 0.35;   // m : distance de fondu contre la géométrie (0 = désactivé)
uniform float angle_fondu = 1.0;         // 1 = cos² (rai, halo vertical), 0 = aucun (halo au sol)
uniform sampler2D tex_profondeur : hint_depth_texture, filter_nearest;
uniform float grille = 135.0;

varying vec3 pw;
varying vec3 nw;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 v = normalize(CAMERA_POSITION_WORLD - pw);
	float facing = abs(dot(nw, v));
	float a;
	float dust = 0.0;
	vec3 col;
	if (mode == 0) {
		float u = abs(UV.x * 2.0 - 1.0);
		float prof_u = pow(clamp(1.0 - u, 0.0, 1.0), 1.6);
		float haut = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.7, UV.y);     // UV.y : 0 en haut, 1 en bas
		a = prof_u * haut * mix(0.7, 1.0, UV.y) * 0.2;
		col = mix(vec3(0.62, 0.74, 0.95), vec3(0.95, 0.9, 0.78), UV.y * 0.6);
		// poussière : quelques grains nets et épars qui montent
		vec3 cell = floor(pw * vec3(26.0, 20.0, 26.0) + vec3(0.0, TIME * 1.4, 0.0));
		if (hash31(cell) > 0.9985) {
			dust = 0.5 * step(0.15, prof_u);
		}
	} else {
		vec2 c = UV * 2.0 - 1.0;
		float d = length(c);
		float f = clamp(1.0 - d, 0.0, 1.0);
		a = pow(f, 2.2) * 0.34;
		float k = clamp(d * 1.15, 0.0, 1.0);
		col = mix(vec3(1.0, 0.89, 0.66), vec3(0.72, 0.26, 0.06), k);
		col *= COLOR.rgb;
	}
	a *= mix(1.0, facing * facing, angle_fondu);
	if (fondu_profondeur > 0.0) {
		float zs = texture(tex_profondeur, SCREEN_UV).x;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, zs);
		vec4 vs = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float prof_scene = -vs.z / vs.w;
		float prof_frag = -(VIEW_MATRIX * vec4(pw, 1.0)).z;
		a *= clamp((prof_scene - prof_frag) / fondu_profondeur, 0.0, 1.0);
	}
	if (mode == 0) {
		a *= smoothstep(0.5, 2.2, length(CAMERA_POSITION_WORLD - pw));   // dans le rai, on ne voit pas un écran de brume
	}
	a *= intensite;
	if (mode == 0) {
		a = floor(a / 0.2 * 4.0 + 0.5) / 4.0 * 0.2 + dust * step(0.5, smoothstep(0.5, 2.2, length(CAMERA_POSITION_WORLD - pw)));   // 4 paliers doux + grains de poussière nets
	} else {
		a = floor(a * 28.0 + hash21(floor(FRAGCOORD.xy))) / 28.0;
	}
	ALBEDO = col;
	ALPHA = a;
}
