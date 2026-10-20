// Flamme en sprite pixel art (atlas de 6 images 20x32, le MÊME que la torche tenue (flamme_sprite.gdshader)), plan toujours face à la caméra, sans éclairage.
// L'image change 10 fois par seconde, avec un décalage propre à chaque flamme (instance uniform).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 taille = vec2(0.30, 0.45);
uniform int images = 6;
uniform float cadence = 10.0;
uniform vec3 teinte : source_color = vec3(1.0);
uniform float phase_u = 0.0;      // flamme isolée (torche en main)
uniform float echelle_u = 1.0;
// en MultiMesh : INSTANCE_CUSTOM.x = phase, INSTANCE_CUSTOM.y = échelle (> 0)

varying float image;

void vertex() {
	// billboard vertical : le plan se tourne vers la caméra autour de l'axe Y seulement
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 vers = normalize(vec3(INV_VIEW_MATRIX[3].x - centre.x, 0.0, INV_VIEW_MATRIX[3].z - centre.z));
	vec3 droite = vec3(vers.z, 0.0, -vers.x);
	bool multi = INSTANCE_CUSTOM.y > 0.0;
	float sc = multi ? INSTANCE_CUSTOM.y : echelle_u;
	float ph = multi ? INSTANCE_CUSTOM.x : phase_u;
	float vacille = 1.0 + 0.05 * sin(TIME * 21.0 + ph * 5.0) + 0.04 * sin(TIME * 37.0);
	vec3 pos = centre + droite * VERTEX.x * taille.x * sc + vec3(0.0, VERTEX.y * taille.y * sc * vacille, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	// même séquence brouillée que la torche tenue, avec un décalage de phase par instance
	float n = floor(TIME * cadence + ph * 13.0);
	float k = float(images);
	image = mod(n * 5.0 + floor(n / k) * 2.0, k);
}

void fragment() {
	vec2 uv = vec2((UV.x + floor(image)) / float(images), UV.y);
	vec4 t = texture(atlas, uv);
	if (t.a < 0.5) discard;
	ALBEDO = t.rgb * teinte;
}
