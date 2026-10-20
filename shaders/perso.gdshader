// Personnages « base unifiee » (graphisme/persos-base) : shader PS1 (sommets accroches, UV affines) + PALETTE A RAMPES.
// L'atlas 256x256 ne contient pas de couleurs mais des INDICES : R = ton (0-7) << 5, G = region << 4, A = 0 : texel decoupe (fourrure).
// Chaque region prend sa couleur de base dans un uniforme d'INSTANCE (un seul materiau partage par tous les PNJ), la rampe de 8 tons
// (ombres froides desaturees, lumieres chaudes : meme formule que PersonnagesTextures.rampe) est calculee ici, puis quantifiee en 15 bits (5 bits
// par canal, palette console). Regions : 0 peau, 1 tunique, 2 pantalon, 3 cuir, 4 surcouche, 5 cheveux, 6 fourrure, 7 iris, 8 fixe (fer, or, blancs).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;//CULL

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform float grille = 135.0;
uniform float affine = 1.0;
uniform float saturation = 1.0;
uniform vec3 emission_peau : source_color = vec3(0.05, 0.04, 0.04);
uniform float lueur_nuit = 0.0;   // reserve (yeux de draugr...)
instance uniform vec4 c_peau = vec4(0.93, 0.78, 0.68, 1.0);
instance uniform vec4 c_tun = vec4(0.6, 0.55, 0.42, 1.0);
instance uniform vec4 c_pan = vec4(0.36, 0.29, 0.22, 1.0);
instance uniform vec4 c_cuir = vec4(0.42, 0.27, 0.15, 1.0);
instance uniform vec4 c_sur = vec4(0.5, 0.2, 0.2, 1.0);
instance uniform vec4 c_cheveux = vec4(0.3, 0.2, 0.12, 1.0);
instance uniform vec4 c_four = vec4(0.55, 0.5, 0.45, 1.0);
instance uniform vec4 c_iris = vec4(0.25, 0.4, 0.6, 1.0);
instance uniform float eclair = 0.0;

varying vec3 uv_aff;

// couleurs fixes (sRGB) : fer sombre -> clair, or, blanc des yeux, os, noir
const vec3 FIXE[16] = vec3[16](
	vec3(0.133, 0.149, 0.180), vec3(0.227, 0.267, 0.345), vec3(0.337, 0.384, 0.478), vec3(0.541, 0.588, 0.678),
	vec3(0.725, 0.765, 0.839), vec3(0.50, 0.38, 0.14), vec3(0.72, 0.58, 0.24), vec3(0.88, 0.76, 0.40),
	vec3(0.80, 0.80, 0.78), vec3(0.93, 0.92, 0.88), vec3(0.10, 0.07, 0.06), vec3(0.04, 0.03, 0.03),
	vec3(0.42, 0.14, 0.12), vec3(0.62, 0.22, 0.18), vec3(0.18, 0.12, 0.08), vec3(1.0, 0.0, 1.0));

vec3 rampe(vec3 base, int ton) {
	float t = float(ton) / 7.0;
	vec3 c = base * mix(0.30, 1.35, t);
	float g = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(c, vec3(g), (1.0 - t) * 0.22);
	c = mix(c, vec3(0.55, 0.62, 0.85) * g * 1.2, (1.0 - t) * 0.22);
	c = mix(c, vec3(1.0, 0.9, 0.7) * max(g, 0.3) * 1.5, t * t * 0.18);
	return clamp(c, 0.0, 1.0);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(UV * w, w);
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec4 t = texture(atlas, uv);
//DECOUPE
	int ton = int(t.r * 255.0 + 0.5) / 32;
	int reg = int(t.g * 255.0 + 0.5) / 16;
	vec3 c;
	if (reg == 8) {
		c = FIXE[clamp(int(t.r * 255.0 + 0.5) / 16, 0, 15)];
	} else {
		vec3 b = c_peau.rgb;
		if (reg == 1) b = c_tun.rgb;
		else if (reg == 2) b = c_pan.rgb;
		else if (reg == 3) b = c_cuir.rgb;
		else if (reg == 4) b = c_sur.rgb;
		else if (reg == 5) b = c_cheveux.rgb;
		else if (reg == 6) b = c_four.rgb;
		else if (reg == 7) b = c_iris.rgb;
		// couleurs d'instance en sRGB brut (pas de hint source_color) : la rampe se calcule en sRGB comme les textures d'origine
		c = rampe(b, ton);
	}
	c = floor(c * 31.0 + 0.5) / 31.0;                 // palette 15 bits
	// pas de conversion sRGB -> lineaire : comme les textures du reste du jeu (ps1.gdshader), la valeur de la rampe est l'albedo
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, saturation);
	ALBEDO = mix(c, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = (reg == 0 ? emission_peau : vec3(0.0)) + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}
