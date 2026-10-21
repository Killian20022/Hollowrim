// Surface lumineuse du Mage nordique (orbe du bâton, yeux sous la capuche, étincelles et runes qui flottent) : MÊME chaîne que
// ps1_perso.gdshader (sommets accrochés à la grille d'écran, mapping affine, texels nets, découpe alpha à 0,5) et :
//   - lueur portée par la texture (emission + tex * eclat) : l'orbe est lumineux par lui-même, de jour comme de nuit ;
//   - particules SANS nœud ni surface en plus : chaque étincelle / rune est un petit quad du maillage (4 sommets au même point,
//     COLOR.g = genre, COLOR.r = phase, UV2 = coin) déplacé et tourné face à la caméra ici (coût GPU négligeable) ;
//     genre 1 = étincelle qui monte et s'éteint, genre 2 = rune qui tourne autour de l'orbe. Genre 0 = géométrie fixe.
// Aucun halo plein écran : seule la lueur HDR de l'orbe passe le seuil du glow de la scène (comme une flamme).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform vec2 uv_echelle = vec2(1.0);
uniform float grille = 135.0;
uniform float affine = 1.0;
uniform float gonfle = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float saturation = 1.0;
uniform bool decoupe = true;
uniform float eclat = 0.92;          // lueur de la texture (orbe, yeux)
uniform float eclat_particules = 1.1;
uniform vec3 teinte_lueur = vec3(0.34, 0.66, 1.10); // la lueur reste BLEU glacé (sinon le glow la blanchit)
uniform float pulsation = 0.12;      // respiration lente de l'orbe
uniform float rayon_runes = 0.13;    // orbite des runes (m)
uniform float montee = 0.34;         // hauteur de montée des étincelles (m)
instance uniform float eclair = 0.0;

varying vec3 uv_aff;
varying float genre;

void vertex() {
	genre = COLOR.g;
	vec4 clip;
	if (COLOR.g > 0.25) {
		float ph = COLOR.r;
		vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float taille;
		if (COLOR.g > 0.75) {
			// rune : orbite horizontale (repère du monde) autour du centre de l'orbe, léger flottement vertical
			float a = TIME * 0.7 + ph * 6.2831;
			c += vec3(cos(a) * rayon_runes, sin(TIME * 1.3 + ph * 9.0) * 0.025, sin(a) * rayon_runes);
			taille = 1.0;
		} else {
			// étincelle : monte en spirale lâche et rapetisse jusqu'à disparaître
			float t = fract(TIME * (0.30 + COLOR.b * 0.35) + ph);
			float a = ph * 40.0 + t * 5.0;
			c += vec3(cos(a) * (0.03 + 0.07 * t), t * montee, sin(a) * (0.03 + 0.07 * t));
			taille = (1.0 - t) * smoothstep(0.0, 0.08, t);
		}
		vec4 vc = VIEW_MATRIX * vec4(c, 1.0);
		vc.xy += UV2 * taille;
		clip = PROJECTION_MATRIX * vc;
		NORMAL = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
	} else {
		VERTEX += NORMAL * gonfle;
		clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(UV * uv_echelle * w, w);
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec4 c = texture(tex_base, uv);
	if (decoupe && c.a < 0.5) {
		discard;
	}
	vec3 col = c.rgb * teinte.rgb;
	col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, saturation);
	float k = genre > 0.25 ? eclat_particules : eclat * (1.0 + pulsation * sin(TIME * 2.1));
	ALBEDO = col * 0.25;
	EMISSION = emission + col * teinte_lueur * k + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}
