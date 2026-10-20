// Lot 6 : flamme de la torche tenue, sprite pixel art (atlas de `images` images côte à côte), plan vertical tourné vers la caméra
// autour de l'axe Y du monde (la flamme monte toujours droit, même quand la torche est penchée), sans éclairage.
// L'ordre des images est brouillé (jamais 0-1-2-3 en boucle) et la hauteur vacille un peu.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform int images = 6;
uniform vec2 taille = vec2(0.18, 0.29);
uniform float cadence = 10.0;
uniform vec3 teinte : source_color = vec3(1.0);
uniform float phase = 0.0;

varying float image;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 vers = normalize(vec3(INV_VIEW_MATRIX[3].x - centre.x, 0.0, INV_VIEW_MATRIX[3].z - centre.z));
	vec3 droite = vec3(vers.z, 0.0, -vers.x);
	float n = floor(TIME * cadence + phase * 13.0);
	float vacille = 1.0 + 0.05 * sin(TIME * 21.0 + phase * 5.0) + 0.04 * sin(TIME * 37.0);
	float echelle = 1.0;
	vec3 pos = centre + droite * VERTEX.x * taille.x * echelle + vec3(0.0, VERTEX.y * taille.y * echelle * vacille, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	float k = float(images);
	image = mod(n * 5.0 + floor(n / k) * 2.0, k);
}

void fragment() {
	vec2 uv = vec2((UV.x + floor(image)) / float(images), UV.y);
	vec4 t = texture(atlas, uv);
	if (t.a < 0.5) discard;
	ALBEDO = t.rgb * teinte;
}
