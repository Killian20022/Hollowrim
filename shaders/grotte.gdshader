// Roche, sol, glace et cristaux de la grotte vitrine. Dérivé de crypte.gdshader :
// - texels nets, mipmaps « nearest », UV fournis par le maillage en mètres (32 texels/m) ;
// - perspective correcte, accroche des sommets au pixel du rendu ;
// - COLOR du sommet : rgb = occlusion ambiante peinte (coins, plafond, pied de paroi), a = masque de la couche
//   superposée (neige, glace, mousse), comparé au SEUIL stocké dans l'alpha de tex_sup : bords déchiquetés au texel.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_sup : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float grille = 270.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emis_tex = 0.0;        // part de la texture réinjectée en émission (cristaux, mousse luisante)
uniform float echelle_sup = 0.77;
uniform float decoupe = 0.0;        // 1 : l'alpha de tex_base est un seuil de bruit comparé au masque du sommet (piste, bords tramés)

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec4 b = texture(tex_base, UV);
	if (decoupe > 0.5 && COLOR.a < b.a) {
		discard;
	}
	vec4 s = texture(tex_sup, UV * echelle_sup + vec2(0.37, 0.13));
	// deux niveaux : bord de plaque net au texel (pixel art), ni demi-teinte ni dégradé
	float d = COLOR.a - s.a;
	float amt = d > 0.0 ? 1.0 : 0.0;
	amt *= step(0.01, COLOR.a);
	vec3 c = mix(b.rgb, s.rgb, amt);
	ALBEDO = c * COLOR.rgb * teinte.rgb;
	EMISSION = emission + c * emis_tex;
	ROUGHNESS = 1.0;
}
