// Lot 2 : cartes de rameaux des arbres. Dérivé de ps1_herbe.gdshader (même accroche des sommets sur
// une grille d'écran, même mapping affine, double face, découpe nette par l'alpha), plus :
// - mipmaps « pixel art » de la texture (filter_nearest_mipmap) : pas de scintillement à distance ;
// - normale de feuillage fournie par le maillage (volume doux de la couronne), identique des deux côtés ;
// - dessous des rameaux (face arrière) : plus sombre et sans neige (la neige est posée dessus).
//   COLOR.a < 0.5 = carte sans dessous distinct (crêtes de neige, flèche vue de côté).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform vec4 teinte_neige : source_color = vec4(1.0);
uniform vec3 couleur_dessous : source_color = vec3(0.102, 0.239, 0.196);  // EPICEA AIGUILLES 2
uniform float dessous = 0.7;       // assombrissement de la face arrière
uniform vec2 uv_echelle = vec2(1.0);
uniform float grille = 135.0;       // lignes de la grille d'accroche (0 = pas de tremblement)
uniform float affine = 1.0;         // 1 = déformation affine façon PS1
uniform float enroule = 0.18;       // éclairage enveloppant : la face opposée à la lumière n'est jamais noire

varying vec3 uv_aff;
varying vec3 n_vue;

void vertex() {
	vec2 uv = UV * uv_echelle;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Pas d'accroche dans la passe d'ombre (projection orthographique) : sinon acné.
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(uv * w, w);
	n_vue = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec4 t = texture(tex_base, uv);
	if (t.a < 0.5) {
		discard;
	}
	vec3 c = t.rgb;
	bool neige = c.b > c.r + 0.05 && dot(c, vec3(0.3, 0.59, 0.11)) > 0.33;
	if (!FRONT_FACING && COLOR.a > 0.5) {
		if (neige) {
			c = couleur_dessous;
			neige = false;
		}
		c *= dessous;
	}
	ALBEDO = c * COLOR.rgb * (neige ? teinte_neige.rgb : teinte.rgb);
	NORMAL = normalize(n_vue);
	ROUGHNESS = 1.0;
}

// Lambert « enveloppant » : les touffes restent lisibles côté ombre (surtout à la lune), sans éclaircir l'albédo.
void light() {
	float nl = clamp((dot(NORMAL, LIGHT) + enroule) / (1.0 + enroule), 0.0, 1.0);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * nl;
}
