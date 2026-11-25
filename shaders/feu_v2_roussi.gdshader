// FEU v2 : trace de roussi discrète laissée par un jet de flammes sur une surface (mur, sol) : tache irrégulière brun-noir,
// bord déchiré, qui s'efface en quelques secondes (paramètre d'instance `age` 0..1). Dessinée dans le monde (pixel du monde).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
instance uniform float age = 0.0;
instance uniform float graine = 0.0;
uniform vec4 couleur : source_color = vec4(0.045, 0.032, 0.03, 1.0);
varying vec2 v_uv;
float hh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hh(i), hh(i + vec2(1, 0)), f.x), mix(hh(i + vec2(0, 1)), hh(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	v_uv = VERTEX.xz;
}
void fragment() {
	// traînée allongée (le maillage est déjà étiré dans le sens du jet) : bord très déchiré, jamais un disque net
	vec2 q = v_uv * 1.7;
	float r = length(q * vec2(0.8, 1.0));
	float n = bruit(q * 4.0 + graine) * 0.5 + bruit(q * 9.0 + graine * 2.0) * 0.5;
	float v = (0.85 - r) + (n - 0.5) * 1.5;
	// 3 paliers : cœur sombre, bord brun, rien ; apparition progressive (0,8 s) puis effacement
	float a = v > 0.3 ? 0.24 : (v > 0.12 ? 0.1 : 0.0);
	a *= smoothstep(0.0, 0.1, age) * (1.0 - smoothstep(0.5, 1.0, age));
	if (a <= 0.0) { discard; }
	ALBEDO = v > 0.32 ? couleur.rgb : couleur.rgb * 1.8 + vec3(0.02, 0.01, 0.0);
	ALPHA = a;
}
