// Pierre, bois, fer de la crypte (lot 7a). Dérivé de ps1.gdshader, réglé pour ne PAS fatiguer l'œil :
// - texels nets avec mipmaps « nearest » (pas de scintillement au loin), UV fournis par le maillage en
//   mètres (densité de texels uniforme) ;
// - mapping perspective correct (affine = 0 : les grands murs ne se tordent plus) ;
// - accroche des sommets à la grille d'écran seulement au pixel du rendu (aucun tremblement visible) ;
// - une bande de crasse au pied des murs, par paliers de 3 tons (pas de dégradé), et une atténuation sous le plafond.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float grille = 270.0;        // 0 = pas d'accroche ; 270 = un pixel du rendu 480x270
uniform float y0 = -140.0;           // sol de la crypte (m, monde)
uniform float crasse = 1.0;          // 0 = sans bande de crasse
uniform vec3 emission : source_color = vec3(0.0);
uniform float decoupe = 0.0;         // > 0 : découpe alpha (toiles), double face utile
instance uniform float eclair = 0.0;

varying vec3 pos_m;
varying vec3 n_m;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	pos_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_m = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec4 t = texture(tex_base, UV);
	if (decoupe > 0.0 && t.a < decoupe) discard;
	vec3 c = t.rgb * COLOR.rgb * teinte.rgb;
	float h = pos_m.y - y0;
	float mur = 1.0 - abs(normalize(n_m).y);
	// pied du mur : 3 paliers (0,0-0,2 m : sombre, 0,2-0,5 : moyen, 0,5-0,9 : léger) ; tête : 0,35 m sous le plafond
	float pied = 0.62 + 0.14 * step(0.2, h) + 0.12 * step(0.5, h) + 0.12 * step(0.9, h);
	c *= mix(1.0, pied, crasse * mur);
	c = mix(c, vec3(1.0, 0.85, 0.8), eclair);
	ALBEDO = c;
	EMISSION = emission;
	ROUGHNESS = 1.0;
}
