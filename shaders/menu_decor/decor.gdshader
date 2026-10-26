shader_type canvas_item;
// Décor animé du menu titre : une seule passe sur la peinture (fond_sans_logo 1920×1080).
// Toutes les animations sont pilotées par des masques peints (masques_a/b/c, 960×540) :
//   a : R lac, G lumières chaudes (flammes 1, fenêtres ~0,45), B runes, A cascade
//   b : R profondeur (0 ciel → 1 premier plan), G cimes des sapins, B halo des lumières, A ciel
//   c : R brume, G halo des runes, B logo élargi, A reflets du lac
// Parallaxe : chaque pixel est décalé de decalage_px × profondeur (carte de profondeur continue → ni trou ni découpe).

uniform sampler2D masques_a : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D masques_b : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D masques_c : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D bruit : filter_linear, repeat_enable;

uniform vec2 decalage_px = vec2(0.0);      // décalage de caméra au premier plan, en px du fond (piloté par le script)
uniform float logo_peint = 1.0;            // 1 : logo peint visible par-dessus → on fige les nuages dessous
uniform float force = 1.0;                 // 0 : image fixe (réglage « réduire les animations »)
uniform float force_eau = 1.0;
uniform float force_lumieres = 1.0;
uniform float force_brume = 1.0;
uniform float force_sapins = 1.0;

const vec2 TAILLE = vec2(1920.0, 1080.0);

void fragment() {
	float t = TIME;
	vec2 uv = UV;

	// --- parallaxe (deux itérations : la profondeur est lue là où le pixel arrive)
	float p = texture(masques_b, uv).r;
	vec2 uvp = uv - decalage_px * p / TAILLE;
	p = texture(masques_b, uvp).r;
	uvp = uv - decalage_px * p / TAILLE;

	vec4 ma = texture(masques_a, uvp);
	vec4 mb = texture(masques_b, uvp);
	vec4 mc = texture(masques_c, uvp);

	vec2 d = vec2(0.0); // déformation en px du fond

	// --- lac : ondulation horizontale lente (≈1,6 px), très peu verticale
	float lac = ma.r * force_eau * force;
	if (lac > 0.001) {
		float n1 = texture(bruit, uvp * vec2(5.0, 30.0) + vec2(t * 0.011, t * 0.032)).r;
		float n2 = texture(bruit, uvp * vec2(9.0, 55.0) - vec2(t * 0.017, t * 0.021)).g;
		d += vec2((n1 + n2 - 1.0) * 1.6, (n2 - 0.5) * 0.5) * lac;
	}

	// --- cascade : l'eau descend (déformation verticale qui défile)
	float casc = ma.a * force;
	float trainee = 0.0;
	if (casc > 0.001) {
		trainee = texture(bruit, vec2(uvp.x * 70.0, uvp.y * 9.0 - t * 0.55)).g;
		float tr2 = texture(bruit, vec2(uvp.x * 120.0 + 0.3, uvp.y * 14.0 - t * 0.8)).b;
		d += vec2((tr2 - 0.5) * 0.8, (trainee - 0.5) * 3.0) * casc;
	}

	// --- nuages : dérive infime par déformation lente, figée sous le logo peint
	float ciel = mb.a * (1.0 - mc.b * logo_peint) * force;
	if (ciel > 0.001) {
		vec2 nn = texture(bruit, uvp * vec2(1.6, 2.4) + vec2(t * 0.0035, t * 0.0012)).ba - 0.5;
		d += nn * vec2(5.0, 2.0) * ciel;
	}

	// --- cimes des sapins : balancement d'environ 1 px au sommet
	float sap = mb.g * force_sapins * force;
	if (sap > 0.001) {
		float b = sin(t * 0.55 + uvp.x * 9.0) * 0.6 + sin(t * 0.93 + uvp.y * 4.0) * 0.4;
		d.x += b * 1.1 * sap;
	}

	vec2 uvd = clamp(uvp + d / TAILLE, vec2(0.0005), vec2(0.9995));
	vec3 col = texture(TEXTURE, uvd).rgb;

	// --- reflets du lac : scintillement doux des reflets chauds
	if (lac > 0.001) {
		float s = texture(bruit, uvp * vec2(14.0, 80.0) + vec2(t * 0.02, -t * 0.05)).a;
		col *= 1.0 + mc.a * (s - 0.5) * 0.45 * force_eau * force;
	}
	// --- cascade : traînées claires
	col += vec3(0.80, 0.86, 0.95) * casc * smoothstep(0.58, 0.85, trainee) * 0.10;

	// --- lumières chaudes : vacillement (cohérent par lampe : bruit de basse fréquence spatiale), halo additif
	float lum = ma.g * force_lumieres;
	float halo = mb.b * force_lumieres;
	if (lum + halo > 0.001) {
		float f1 = texture(bruit, uvp * 3.0 + vec2(t * 0.9, -t * 0.55)).r;
		float f2 = texture(bruit, uvp * 4.0 + vec2(-t * 1.7, t * 1.3)).b;
		float vac = ((f1 * 0.65 + f2 * 0.35) - 0.5) * force;
		float flamme = lum * lum; // 1 sur les flammes, ~0,2 sur les fenêtres
		col *= 1.0 + vac * (0.55 * flamme + 0.12 * lum) + 0.04 * lum;
		col += vec3(1.0, 0.52, 0.18) * halo * (0.055 + vac * 0.07);
	}

	// --- runes : pulsation lente (≈5 s), décalée selon la position
	float run = ma.b + mc.g * 0.6;
	if (run > 0.001) {
		float pul = 0.5 + 0.5 * sin(t * 1.25 + uvp.x * 6.0 + uvp.y * 3.0);
		col += vec3(0.30, 0.66, 1.0) * run * mix(0.5, pul, force) * 0.22;
	}

	// --- brume : nappes qui dérivent (mélange « écran »)
	float br = mc.r * force_brume * force;
	if (br > 0.001) {
		float b1 = texture(bruit, uvp * vec2(2.2, 5.5) + vec2(t * 0.0045, 0.0)).a;
		float b2 = texture(bruit, uvp * vec2(3.7, 8.0) + vec2(-t * 0.0028, t * 0.0009)).r;
		float m = br * smoothstep(0.35, 0.85, b1 * 0.6 + b2 * 0.4) * 0.16;
		col = 1.0 - (1.0 - col) * (1.0 - m * vec3(0.72, 0.78, 0.9));
	}

	COLOR = vec4(col, 1.0);
}
