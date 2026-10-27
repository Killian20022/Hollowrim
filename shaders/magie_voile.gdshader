// Couche ADDITIVE posée par-dessus un modèle (material_overlay) : statut d'une cible (gel, choc, corruption, brûlure) et
// enchantement d'arme. Ne remplace NI le modèle NI sa texture : on ajoute de la lumière en paliers (bord + motif).
// Sommets gonflés de `gonfle` le long de la normale et accrochés à la MÊME grille que le shader ps1 (`grille`, lue sur le
// matériau du modèle) : la couche reste collée au modèle sans scintiller.
// motif : 0 bord seul, 1 flammes qui montent, 2 givre (cristaux fixes qui scintillent), 3 arcs (éclairs qui sautent),
// 4 volutes (taches qui ondulent).
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 couleur : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform vec4 coeur : source_color = vec4(0.9, 0.96, 1.0, 1.0);
uniform float force = 0.6;
uniform float grille = 135.0;
uniform float gonfle = 0.006;
uniform int motif = 0;
uniform float cases = 24.0;     // cases du motif par mètre (repère de l'objet)
uniform vec3 axe = vec3(0.0, 1.0, 0.0);

varying vec3 p_obj;
varying vec3 n_vue;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	VERTEX += NORMAL * gonfle;
	p_obj = VERTEX;
	n_vue = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float bord = 1.0 - abs(normalize(n_vue).z);
	float a = step(0.55, bord) * 0.5 + step(0.8, bord) * 0.5;
	vec3 q = floor(p_obj * cases);
	float h = dot(p_obj, axe);
	float k = 0.0;
	if (motif == 1) {
		float n = h3(q + vec3(0.0, floor(-TIME * 10.0 + h * 2.0), 0.0));
		float f = step(0.62, n);
		a = max(a * 0.6, f);
		k = step(0.86, n);
	} else if (motif == 2) {
		float n = h3(q);
		float sc = step(0.9, fract(n * 7.0 + TIME * 0.5));
		a = max(a, step(0.8, n) * 0.6 + sc * step(0.8, n));
		k = sc * step(0.8, n);
	} else if (motif == 3) {
		float t = floor(TIME * 14.0);
		float n = h3(vec3(q.xy, floor(h * cases * 0.25)) + t);
		a = max(a * 0.4, step(0.93, n));
		k = step(0.97, n);
	} else if (motif == 4) {
		float n = h3(floor(p_obj * cases * 0.5 + vec3(0.0, -TIME * 1.5, 0.0)));
		a = max(a * 0.7, step(0.7, n) * 0.6);
	}
	a *= force;
	a = ceil(a * 3.0 - 0.05) / 3.0;
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = mix(couleur.rgb, coeur.rgb, k);
	ALPHA = clamp(a, 0.0, 1.0);
}
