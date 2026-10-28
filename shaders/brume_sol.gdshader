// Brume au ras du sol de la crypte (lot C9) : nappes horizontales additives en PALIERS de densité découpés par un bruit de valeur
// fixé au monde (jamais de Bayer, rien d'animé, aucun grain au pixel : cellules de bruit de ~0,7 m). Couleur et épaisseur par salle
// en couleur de sommet (Lumieres._brume_sol : rgb = teinte, a = épaisseur). Fondue avec la profondeur comme la brume de BrumePortee.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform float force = 0.14;          // densité additive au cœur d'une nappe (avant paliers)
uniform float paliers = 4.0;
uniform float debut_brume = 4.0;     // brume de profondeur de la crypte (monde.gd : BrumePortee.appliquer(e, 4.0, 1.0))
uniform float fin_brume = 31.0;

varying vec3 pm;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float bord = 1.0 - smoothstep(0.2, 1.0, r);
	bord *= bord;
	float n = bruit(pm.xz * 0.7) * 0.65 + bruit(pm.xz * 1.6 + 17.3) * 0.35;
	// paliers sur le BRUIT seulement (taches de brume à bords nets, aucun anneau concentrique) ; le bord de la nappe reste fondu
	float dens = floor(smoothstep(0.3, 0.85, n) * paliers + 0.25) / paliers;
	dens *= bord;
	float dist = length(VERTEX);
	float voile = 1.0 - clamp((dist - debut_brume) / (fin_brume - debut_brume), 0.0, 1.0);
	ALBEDO = COLOR.rgb * (dens * COLOR.a * force * voile);
}
