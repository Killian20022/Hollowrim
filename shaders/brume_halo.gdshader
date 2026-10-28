// Halo de brume autour d'un brasero ou d'un lustre (lot C9) : carte face à la caméra (MultiMesh, INSTANCE_CUSTOM.x = intensité,
// .y = graine), additive, rampe Braise tons 1-2 ; anneaux en PALIERS dont le contour est cassé par un bruit fixé à la carte
// (rien d'animé, aucun Bayer). Le bas est fondu (la carte ne coupe pas le sol), la profondeur l'éteint comme la brume de la crypte.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 ton_1 : source_color = vec3(0.35, 0.10, 0.11);
uniform vec3 ton_2 : source_color = vec3(0.70, 0.20, 0.12);
uniform float force = 0.15;
uniform float paliers = 4.0;
uniform float debut_brume = 4.0;
uniform float fin_brume = 31.0;

varying float intensite;
varying float graine;
varying float dist;
varying float rayon;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float r = length(MODEL_MATRIX[0].xyz);
	vec3 cv = (VIEW_MATRIX * vec4(centre, 1.0)).xyz;
	// rapprochée de la caméra de 0,4 r : moins de coupures franches dans les murs et le mobilier voisins
	vec3 pv = cv + vec3(VERTEX.xy * r, 0.0) + normalize(-cv) * r * 0.4;
	POSITION = PROJECTION_MATRIX * vec4(pv, 1.0);
	intensite = INSTANCE_CUSTOM.x;
	graine = INSTANCE_CUSTOM.y * 37.0;
	dist = length(cv);
	rayon = r;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float n = bruit(c * 2.2 + graine) * 0.6 + bruit(c * 4.5 + graine + 9.1) * 0.4;
	float f = clamp(1.0 - r * (0.85 + 0.35 * n), 0.0, 1.0);
	f = f * f;
	f *= 1.0 - smoothstep(0.15, 0.95, c.y);                    // bas fondu (UV.y croît vers le bas)
	float lev = floor(f * paliers + 0.4) / paliers;
	vec3 col = mix(ton_1, ton_2, clamp(lev * 2.0, 0.0, 1.0));
	float voile = 1.0 - clamp((dist - debut_brume) / (fin_brume - debut_brume), 0.0, 1.0);
	voile *= smoothstep(0.6 * rayon, 1.8 * rayon, dist);      // caméra dans le halo : il s'efface (pas d'écran lavé)
	ALBEDO = col * lev * intensite * force * voile;
}
