// Look-dev personnages (essai, PAS l'intégration) : partie « personnage » de ps1.gdshader
// (même accroche des sommets à la grille d'écran, même mapping affine, mêmes texels nets, éclairage lambert,
// couleur de sommet multipliée), sans le code du sol, plus trois options à tester :
//   mips   : texels nets AVEC mipmaps (réduction pixel art précalculée) contre le scintillement des textures denses ;
//   relief : carte de normales (constante par texel : facettes en pixels), force réglable ;
//   decoupe: découpe alpha (mèches, bords dentelés), seuil 0,5, jamais de fondu.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_base_mips : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_relief : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform bool mips = false;
uniform bool relief = false;
uniform float relief_force = 0.6;
uniform bool decoupe = false;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float grille = 180.0;   // 360 lignes / 2 : même pas d'accroche que le jeu (135 pour 270 lignes)
uniform float affine = 1.0;

varying vec3 uv_aff;

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
	vec4 c = mips ? texture(tex_base_mips, uv) : texture(tex_base, uv);
	if (decoupe && c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * COLOR.rgb * teinte.rgb;
	if (relief) {
		NORMAL_MAP = texture(tex_relief, uv).rgb;
		NORMAL_MAP_DEPTH = relief_force;
	}
	ROUGHNESS = 1.0;
}
