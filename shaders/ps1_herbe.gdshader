// Variante « herbe sèche » du matériau PS1 (lot E) : même accroche des sommets sur une
// grille d'écran et même mapping affine que ps1.gdshader, mais double face et découpé
// par l'alpha de la texture (touffes en quads croisés). Éclairage doux : normale vers le haut.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D tex_base : source_color, filter_nearest, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform vec2 uv_echelle = vec2(1.0);
uniform float grille = 135.0;       // lignes de la grille d'accroche (0 = pas de tremblement)
uniform float affine = 1.0;         // 1 = déformation affine façon PS1

varying vec3 uv_aff;

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
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec4 t = texture(tex_base, uv);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb * teinte.rgb;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
}
