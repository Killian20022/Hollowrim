// Matériau « PS1 » commun à tout le décor :
// sommets accrochés à une grille d'écran (tremblement), textures en mapping affine,
// texels nets. La neige (tex_neige) et la matière de base (tex_base) sont
// mélangées selon l'alpha de la couleur de sommet : 0 = neige, 1 = base.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_neige : source_color, filter_nearest, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform vec2 uv_echelle = vec2(1.0);
uniform bool uv_monde = false;      // terrain : UV tirés de la position monde
uniform float monde_echelle = 0.25;
uniform float grille = 135.0;       // lignes de la grille d'accroche (0 = pas de tremblement)
uniform float affine = 1.0;         // 1 = déformation affine façon PS1
uniform vec3 emission : source_color = vec3(0.0);
uniform float saturation = 1.0;    // < 1 : couleurs ternies (morts-vivants…)
instance uniform float eclair = 0.0; // flash quand l'objet est touché (par instance)

varying vec3 uv_aff;

void vertex() {
	vec2 uv = UV * uv_echelle;
	if (uv_monde) {
		uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * monde_echelle;
	}
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Pas d'accroche dans la passe d'ombre (projection orthographique) : sinon acné.
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	// UV multipliés par w puis redivisés au fragment = interpolation affine.
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(uv * w, w);
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec3 base = texture(tex_base, uv).rgb;
	vec3 neige = texture(tex_neige, uv).rgb;
	ALBEDO = mix(neige, base, step(0.5, COLOR.a)) * COLOR.rgb * teinte.rgb;
	ALBEDO = mix(vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11))), ALBEDO, saturation);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = emission + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}
