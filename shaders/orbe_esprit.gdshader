// ORBE DE L'ESPRIT en main (scripts/magie/orbe_esprit.gd) : sphère de verre-énergie irisée, cœur qui tourbillonne, anneaux
// orbitaux fins et éclats de pierre. Tout est quantifié en paliers francs (style PS1 / pixel art), sans texture.
//   mode 0 : sphère transparente (reflets irisés au bord, filets qui tournent à l'intérieur)
//   mode 1 : cœur bleu-blanc qui tourbillonne (carré face caméra)
//   mode 2 : anneau orbital (ruban : UV.x le long du tour) : tirets qui courent, quelques grains plus vifs
//   mode 3 : éclat de pierre (ombré en 3 paliers, liseré d'énergie, sommets accrochés à une grille d'écran)
// Calque de la couche fine de la magie (occlusion par le décor : magie_occ.gdshaderinc).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"

uniform int mode = 0;
uniform vec3 teinte : source_color = vec3(0.45, 0.75, 1.0);
uniform vec3 clair : source_color = vec3(0.9, 0.98, 1.0);
uniform vec3 iris : source_color = vec3(0.85, 0.55, 1.0);   // second reflet irisé (rose-violet)
uniform float eclat = 1.0;
uniform float sens = 1.0;          // sens de rotation (+1 / -1)
uniform float vitesse = 1.0;       // vitesse des tourbillons internes (suit l'effort)
uniform float texels = 28.0;
uniform float grille = 110.0;      // éclats : lignes de la grille d'accroche
instance uniform float defile = 0.0;
instance uniform float graine = 0.0;

varying vec3 v_loc;

// POSITION est écrit pour TOUS les modes : sans cela la couche fine ne dessine pas ces maillages (constaté au rendu).
void vertex() {
	v_loc = VERTEX;
	vec4 p = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (mode == 3) {
		p.xy = round(p.xy / p.w * grille) / grille * p.w;
	}
	POSITION = p;
}

float pal(float x, float n) {
	return floor(x * n + 0.5) / n;
}

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	vec3 c = vec3(0.0);
	float a = 0.0;
	if (mode == 0) {
		vec3 n = normalize(NORMAL);
		float ndv = clamp(abs(dot(n, normalize(VIEW))), 0.0, 1.0);
		float rim = pow(1.0 - ndv, 2.2);
		// irisation : le ton glisse selon l'angle et la hauteur, en 4 paliers
		float h = pal(fract(rim * 1.3 + v_loc.y * 0.9 + TIME * 0.05 * sens + graine), 4.0);
		vec3 ir = mix(mix(teinte, iris, h), clair, 0.25 + 0.4 * h * rim);
		// filets internes qui tournent (coques de verre) : latitude qui se tord autour de l'axe
		float ang = atan(v_loc.z, v_loc.x) * sens;
		float fil = fract(ang * 0.95 + v_loc.y * 2.6 - TIME * 0.35 * vitesse * sens);
		float trait = smoothstep(0.93, 1.0, fil) * (0.35 + 0.65 * ndv);
		float lat = smoothstep(0.96, 1.0, fract(v_loc.y * 4.2 + 0.5 * sin(ang * 2.0 + TIME * 0.5))) * 0.55;
		float reflet = step(0.86, dot(n, normalize(vec3(-0.45, 0.75, 0.5)))) * 0.45;   // reflet de verre en haut à gauche
		a = pal(clamp(rim * 0.55 + 0.05 + trait * 0.4 + lat * 0.25 + reflet, 0.0, 1.0), 6.0);
		c = (ir * (0.6 + rim) + clair * (trait + reflet)) * eclat;
		c *= a;
		ALPHA = a * 0.9;
		ALBEDO = c;
	} else if (mode == 1) {
		vec2 u = (floor(UV * texels) + 0.5) / texels * 2.0 - 1.0;
		float r = length(u);
		float ang = atan(u.y, u.x);
		float sp = ang * sens + r * 7.0 - TIME * 2.2 * vitesse + graine * 6.0;
		float bras = smoothstep(0.35, 0.9, 0.5 + 0.5 * sin(sp * 3.0)) * (1.0 - smoothstep(0.1, 0.95, r));
		float coeur = exp(-r * r * 15.0) * 0.8;
		float fin = smoothstep(0.88, 0.97, 0.5 + 0.5 * sin(sp * 7.0 - r * 12.0)) * (1.0 - r);   // filets fins
		float v = pal(clamp(coeur * 1.1 + bras * 0.55 + fin * 0.5, 0.0, 1.0), 5.0) * (1.0 - step(1.0, r));
		c = mix(teinte, clair, clamp(v * 1.2 - 0.25, 0.0, 1.0)) * v * 1.25 * eclat;
		a = v * 0.6;
		ALPHA = a;
		ALBEDO = c;
	} else if (mode == 2) {
		float u = fract(UV.x * 36.0 - defile * 36.0);
		float v = abs(UV.y - 0.5) * 2.0;
		float tiret = smoothstep(0.0, 0.12, u) * smoothstep(0.9, 0.5, u);
		float grain = step(0.955, fract(sin(floor(UV.x * 150.0) * 91.7 + graine * 13.0) * 4375.5));
		float a2 = ((0.3 + 0.7 * tiret) * (1.0 - v) * 0.7 + grain * (1.0 - v) * 1.4) * eclat;
		a = clamp(a2, 0.0, 1.0);
		c = mix(teinte, clair, 0.3 + 0.7 * grain) * a * 1.6;
		ALPHA = a;
		ALBEDO = c;
	} else {
		vec3 n = normalize(NORMAL);
		float l = pal(max(dot(n, normalize(vec3(-0.4, 0.7, 0.55))), 0.0), 3.0);
		float ndv = clamp(abs(dot(n, normalize(VIEW))), 0.0, 1.0);
		float rim = step(0.62, 1.0 - ndv);
		vec3 pierre = vec3(0.34, 0.35, 0.41) * (0.5 + 0.9 * l) + vec3(0.1, 0.12, 0.16) * graine;
		c = pierre + teinte * rim * 0.65 * eclat;
		ALPHA = 1.0;
		ALBEDO = c;
	}
}
