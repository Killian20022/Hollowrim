// Cristaux de la magie (éclats et lance de glace, pics de la nova, épines obscures, cristaux corrompus) : facettes à plat
// éclairées par une lumière FIXE de la vue, 3 tons + reflet de bord (pas de dégradé lisse), lumineux par eux-mêmes
// (lisibles dans la crypte), sommets accrochés à la grille d'écran comme le shader ps1. Fonte (disparition) par cases
// de bruit (INSTANCE_CUSTOM.x en MultiMesh, sinon `fonte`), jamais de damier.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 c_ombre : source_color = vec4(0.11, 0.17, 0.35, 1.0);
uniform vec4 c_milieu : source_color = vec4(0.18, 0.37, 0.72, 1.0);
uniform vec4 c_clair : source_color = vec4(0.37, 0.62, 0.91, 1.0);
uniform vec4 c_reflet : source_color = vec4(0.91, 0.96, 1.0, 1.0);
uniform float eclat = 1.0;
uniform float grille = 135.0;
uniform float fonte = 0.0;
uniform bool multimesh = false;

varying vec3 n_vue;
varying vec3 p_obj;
varying float f_fonte;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	n_vue = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	p_obj = VERTEX;
	f_fonte = multimesh ? INSTANCE_CUSTOM.x : fonte;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	if (f_fonte > 0.0 && hash3(floor(p_obj * 10.0)) < f_fonte) {
		discard;
	}
	vec3 n = normalize(n_vue);
	float l = dot(n, normalize(vec3(-0.45, 0.65, 0.6)));
	float bord = 1.0 - abs(n.z);
	vec3 c = l < -0.05 ? c_ombre.rgb : (l < 0.45 ? c_milieu.rgb : c_clair.rgb);
	if (bord > 0.9 || l > 0.86) {
		c = c_reflet.rgb;
	}
	ALBEDO = c * eclat;
}
