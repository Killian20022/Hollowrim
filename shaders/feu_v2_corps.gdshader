// FEU v2 : CORPS de l'orbe de feu en trois COQUES emboîtées (maillage de sphère de rayon 1, mis à l'échelle par le nœud) :
//   coque 0 : CŒUR blanc-jaune plein, petit, qui pulse ;
//   coque 1 : gaine orange, bruit de flamme qui MONTE vers la queue (trous = langues) ;
//   coque 2 : peau rouge, rare, déchirée, qui s'étire derrière l'orbe (goutte) ;
// puis une couronne de distorsion de chaleur ne fait pas partie de ce shader (voir FeuV2). Bruit 3D valeur sur 3 octaves,
// paliers de couleur FRANCS (pas de dégradé continu), tout en pixels de la couche fine. Occlusion : magie_occ.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://shaders/magie_occ.gdshaderinc"
uniform int coque = 0;
uniform vec3 axe = vec3(0.0, 1.0, 0.0);   // sens de la queue (repère local)
uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);
uniform float vitesse = 1.6;
uniform float force = 1.35;
instance uniform float eclat = 1.0;     // 0 = éteint
instance uniform float etire = 0.0;     // goutte : 0 = ronde (assise), 1 = queue longue (en vol)
instance uniform float graine = 0.0;
instance uniform float age = 0.0;       // explosion : 0 = naissance, 1 = fin (le bruit se déchire, la coque s'ouvre)

varying vec3 v_n;       // direction sur la sphère unité
varying vec3 v_loc;

float hh(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float bruit3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hh(i), hh(i + vec3(1, 0, 0)), f.x), mix(hh(i + vec3(0, 1, 0)), hh(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hh(i + vec3(0, 0, 1)), hh(i + vec3(1, 0, 1)), f.x), mix(hh(i + vec3(0, 1, 1)), hh(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm3(vec3 p) {
	return bruit3(p) * 0.55 + bruit3(p * 2.03 + 7.1) * 0.3 + bruit3(p * 4.1 + 3.7) * 0.15;
}

void vertex() {
	v_n = normalize(VERTEX);
	float d = dot(v_n, normalize(axe));
	// goutte : l'arrière de la coque s'étire le long de l'axe (plus pour la peau), le devant reste rond
	float tire = etire * (coque == 0 ? 0.25 : (coque == 1 ? 0.9 : 1.6));
	VERTEX += normalize(axe) * tire * pow(max(d, 0.0), 1.3);
	// explosion : la coque gonfle avec l'âge
	VERTEX *= 1.0 + (coque == 2 ? 0.25 : 0.1) * age;
	v_loc = VERTEX;
}

void fragment() {
	bool cache = magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX);
	vec3 ax = normalize(axe);
	float d = dot(v_n, ax);                 // -1 devant, +1 derrière (côté de la queue)
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.4);
	// le bruit CHEMINE vers la queue (les flammes filent) et se déforme avec la graine
	vec3 p = v_loc * (coque == 0 ? 2.4 : (coque == 1 ? 2.8 : 2.2)) - ax * TIME * vitesse * (coque == 2 ? 1.6 : 1.0) + graine * 5.0;
	// étirement du motif le long de l'axe : langues allongées
	p -= ax * dot(p, ax) * 0.35 * (coque == 0 ? 0.0 : 1.0);
	float n = fbm3(p);
	float v;
	vec3 col;
	float pulse = 0.5 + 0.5 * sin(TIME * 13.0 + graine * 9.0) * sin(TIME * 5.3 + graine);
	if (coque == 0) {
		v = 1.0 - 0.55 * rim + 0.25 * (n - 0.5) + 0.06 * pulse - 0.85 * age;
		col = v > 1.02 ? c0.rgb : (v > 0.74 ? c1.rgb : c2.rgb);
		if (v < 0.4 + 0.3 * age) { discard; }
	} else if (coque == 1) {
		v = 0.95 * n + 0.45 * (1.0 - rim) - 0.12 * d - 0.55 - 0.65 * age;
		if (v < 0.0) { discard; }
		col = v > 0.34 ? c1.rgb : (v > 0.17 ? c2.rgb : c3.rgb);
	} else {
		v = 1.15 * n - 0.1 * (1.0 - rim) + 0.3 * max(d, 0.0) - 0.84 - 0.6 * age;
		if (v < 0.0) { discard; }
		col = v > 0.14 ? c3.rgb : c4.rgb;
	}
	float a = coque == 2 ? 0.85 : 1.0;
	// allumage / extinction (eclat 0..1) : la coque devient transparente avant de s'éteindre (jamais de boule sombre)
	a *= clamp(eclat * 4.0 - 0.1, 0.0, 1.0);
	ALBEDO = (cache) ? vec3(0.0) : col * force * clamp(eclat, 0.0, 1.6);
	ALPHA = cache ? 0.0 : a * (1.0 - smoothstep(0.5, 1.0, age));
}
