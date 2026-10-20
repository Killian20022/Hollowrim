// Passe finale : couleurs réduites (15 bits comme la PS1) avec tramage Bayer 4x4,
// plus un léger vignettage.
shader_type canvas_item;

uniform sampler2D ecran : hint_screen_texture, filter_nearest;
uniform bool actif = true;
uniform float niveaux = 32.0;
uniform float tramage = 1.0;
uniform float vignette = 0.35;
uniform float degat = 0.0;  // voile rouge quand le joueur est touché
uniform float fondu = 0.0;  // fondu au noir (mort)

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 c = texture(ecran, SCREEN_UV).rgb;
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v, v) * vignette;
	c = mix(c, vec3(0.45, 0.02, 0.02), degat * smoothstep(0.05, 0.5, dot(v, v) * 2.0));
	c *= 1.0 - fondu;
	if (actif) {
		// Lot 7 : le tramage Bayer 15 bits reste (il casse les bandes des dégradés : brume, ciel), mais il s'efface sur
		// les arêtes franches (bords d'arbres, silhouettes sur l'aurore) où le motif fixe crépitait.
		vec2 px = SCREEN_PIXEL_SIZE;
		float l0 = dot(texture(ecran, SCREEN_UV).rgb, vec3(0.3, 0.55, 0.15));
		float ec = 0.0;
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV + vec2(px.x, 0.0)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV - vec2(px.x, 0.0)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV + vec2(0.0, px.y)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		ec = max(ec, abs(dot(texture(ecran, SCREEN_UV - vec2(0.0, px.y)).rgb, vec3(0.3, 0.55, 0.15)) - l0));
		float force = tramage * mix(1.0, 0.3, smoothstep(0.04, 0.16, ec));
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		float b = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
		c = floor(c * (niveaux - 1.0) + 0.5 + b * force) / (niveaux - 1.0);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
