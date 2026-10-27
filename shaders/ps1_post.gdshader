// Passe finale : étalonnage (ombres froides, hautes lumières chaudes, contraste), couleurs réduites (15 bits comme la PS1)
// avec tramage PAR BRUIT (jamais de damier Bayer), plus un léger vignettage.
shader_type canvas_item;

uniform sampler2D ecran : hint_screen_texture, filter_nearest;
uniform bool actif = true;
uniform float niveaux = 32.0;
uniform float tramage = 1.0;
uniform float vignette = 0.35;
uniform float degat = 0.0;  // voile rouge quand le joueur est touché
uniform float fondu = 0.0;  // fondu au noir (mort)
uniform float eclat_rouge = 0.0;  // voile rouge bref plein écran : gros coups, morts brutales, finishers (scripts/combat/retour_impact.gd)
// Lot 2 : étalonnage fixé par cycle.gd selon l'heure (sous terre, monde.gd baisse `etal_mix`)
uniform vec3 etal_ombre = vec3(0.88, 0.96, 1.14);
uniform vec3 etal_clair = vec3(1.06, 1.01, 0.93);
uniform float etal_sat = 0.92;
uniform float etal_contraste = 0.35;
uniform float etal_mix = 1.0;
// taille du pixel du MONDE en pixels de l'écran : 1 d'habitude (fenêtre en 640x360) ; k quand la couche fine de la magie
// est active (scripts/magie/couche_magie.gd : fenêtre à la résolution de l'écran, monde agrandi ×k) → grain identique
global uniform float magie_pas;

// bruit de gradient entrelacé (Jimenez) : grain fin sans motif en damier, stable d'une image à l'autre
float bruit_ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec3 etalonner(vec3 c) {
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	// ombres froides bleu-violet, hautes lumières chaudes
	float ombre = 1.0 - smoothstep(0.0, 0.55, l);
	float clair = smoothstep(0.35, 0.95, l);
	vec3 g = c * mix(vec3(1.0), etal_ombre, ombre) * mix(vec3(1.0), etal_clair, clair);
	// saturation maîtrisée
	float lg = dot(g, vec3(0.3, 0.55, 0.15));
	g = mix(vec3(lg), g, etal_sat);
	// contraste : courbe en S qui garde noir et blanc
	vec3 gc = clamp(g, 0.0, 1.0);
	g = mix(g, gc * gc * (3.0 - 2.0 * gc), etal_contraste);
	return mix(c, g, etal_mix);
}

void fragment() {
	vec3 c = etalonner(texture(ecran, SCREEN_UV).rgb);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v, v) * vignette;
	c = mix(c, vec3(0.45, 0.02, 0.02), degat * smoothstep(0.05, 0.5, dot(v, v) * 2.0));
	// éclat rouge : l'image vire au sang (les clairs gardent leur lecture), bords plus marqués
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, vec3(lum * 1.25 + 0.08, lum * 0.18, lum * 0.14), eclat_rouge * (0.55 + 0.45 * smoothstep(0.0, 0.5, dot(v, v) * 2.0)));
	c *= 1.0 - fondu;
	if (actif) {
		// Lot 7 : le tramage 15 bits reste (il casse les bandes des dégradés : brume, ciel), mais il s'efface sur
		// les arêtes franches (bords d'arbres, silhouettes sur l'aurore) où le grain crépitait.
		vec2 px = SCREEN_PIXEL_SIZE * magie_pas;
		float l0 = dot(texture(ecran, SCREEN_UV).rgb, vec3(0.3, 0.55, 0.15));
		float ec = 0.0;
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV + vec2(px.x, 0.0)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV - vec2(px.x, 0.0)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV + vec2(0.0, px.y)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV - vec2(0.0, px.y)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		float force = tramage * mix(1.0, 0.3, smoothstep(0.04, 0.16, ec));
		float b = bruit_ign(floor(FRAGCOORD.xy / magie_pas) + 0.5) - 0.5;
		c = floor(c * (niveaux - 1.0) + 0.5 + b * force) / (niveaux - 1.0);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
