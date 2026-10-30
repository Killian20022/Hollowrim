// VAGUE de flammes du jet de feu (couche fine) : dessin d'UNE bouffée (particule de magie_vague_process.gdshader).
// Carré tourné vers la caméra, rayon = échelle de la particule. Le motif est procédural et VIVANT : bruit fractal déformé
// par un second bruit qui dérive (domain warp : la matière roule et se tord), tourné avec la bouffée (rotation propre),
// des langues qui lèchent vers le HAUT du monde ; l'âge (INSTANCE_CUSTOM.y) pilote tout : naissance blanc-jaune dense et
// petite, puis orange qui gonfle, rouge sombre qui se troue en lambeaux, enfin fumée qui s'efface.
// Rendu ps1 : le motif est calculé par pixel du MONDE (la flamme a le grain du décor, pas un dégradé lisse), couleurs en
// paliers de la palette du feu, couverture tramée par un bruit qui bout (12 images/s), jamais une matrice de Bayer.
// Fusion PRÉMULTIPLIÉE « mixte » comme magie_flux : les parties chaudes éclairent (rgb > alpha), la fumée couvre.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

uniform float eclat = 1.0;
uniform float opacite = 1.0;     // couverture des flammes (0..1)
uniform float fumee = 0.55;      // couverture de la fumée en fin de vie
uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);   // chauffé à blanc
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);
uniform vec4 c5 : source_color = vec4(0.35, 0.10, 0.11, 1.0);
uniform vec4 c_fumee : source_color = vec4(0.11, 0.09, 0.09, 1.0);
// bruit fractal précalculé, périodique (GestionMagie._tex_bruit_vague : 64², 4 canaux indépendants, 3 octaves,
// 8 cases par période) : 2 lectures de texture au lieu de 7 bruits calculés (~28 hachages) par pixel
uniform sampler2D bruit : filter_linear, repeat_enable;
uniform sampler2D formes : filter_linear, repeat_disable;   // atlas 4×3 (Kenney Particle Pack, CC0)

varying vec2 v_px;      // position dans le carré, en pixels de la couche (0 = centre)
varying float v_rpx;    // rayon en pixels de la couche
varying vec2 v_haut;    // haut du monde à l'écran
varying vec4 v_c;       // graine, âge, rotation
varying vec2 v_ax;      // axe d'étirement à l'écran (sens de la vitesse)
varying float v_rl;     // demi-longueur en pixels le long de l'axe
varying float v_proche_d; // distance à l'œil (m)
varying float v_proche; // 0 tout contre l'œil (pas de voile pâle sur la main), 1 au-delà de ~0,8 m

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 axe = MODEL_MATRIX[1].xyz;   // sens de la vitesse × rayon × étirement
	vec4 cc = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
	vec4 ca = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre + axe, 1.0));
	vec4 ch = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre + vec3(0.0, 0.05, 0.0), 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float w = max(cc.w, 0.0001);
	vec2 pc = (cc.xy / w * 0.5 + 0.5) * vp;
	vec2 ph = (ch.xy / max(ch.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 hd = ph - pc;
	v_haut = dot(hd, hd) > 0.0001 ? normalize(hd) : vec2(0.0, 1.0);
	float m = max(magie_echelle, 1.0);
	float rpx = s * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	// trop près de l'œil (bouffée qui naît dans la paume) : pas de carré géant
	rpx = min(rpx, vp.y * 0.15);
	// étirement vu à l'écran : de face (vitesse vers l'œil) la bouffée reste ronde, de profil c'est une langue
	vec2 pa = (ca.xy / max(ca.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 da = ca.w > 0.0001 ? pa - pc : vec2(0.0);
	float la = length(da);
	vec2 ax = la > 0.001 ? da / la : vec2(0.0, 1.0);
	float rl = clamp(la, rpx, rpx * 5.2);
	// centre calé sur la grille des pixels du MONDE : le motif ne glisse pas d'un sous-pixel à l'autre
	vec2 c = (floor(pc / m) + 0.5) * m;
	vec2 off = vec2(-ax.y, ax.x) * VERTEX.x * 2.0 * (rpx + m) + ax * VERTEX.y * 2.0 * (rl + m);
	v_ax = ax;
	v_rl = max(rl, 0.5);
	POSITION = vec4(((c + off) / vp * 2.0 - 1.0) * cc.w, cc.z, cc.w);
	v_px = off;
	v_rpx = max(rpx, 0.5);
	v_c = INSTANCE_CUSTOM;
	v_proche = step(0.5, cc.w);
	v_proche_d = cc.w;
	// (et contre l'œil, où la bouffée serait de toute façon effacée : on n'en paie pas les pixels)
	if (s < 0.000001 || INSTANCE_CUSTOM.y >= 1.0 || cc.w < 0.5) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);   // particule inactive : hors du volume de vue
	}
}

#include "res://shaders/magie_bruit.gdshaderinc"

// dégradé c0 (h >= 1) → c5 (h <= 0), en paliers (3 par intervalle : palette resserrée, pas de dégradé lisse)
vec3 rampe(float h) {
	float x = clamp((1.0 - h) * 5.0, 0.0, 4.999);
	float i = floor(x);
	float f = floor(fract(x) * 3.0) / 3.0;
	vec3 a = i < 1.0 ? c0.rgb : (i < 2.0 ? c1.rgb : (i < 3.0 ? c2.rgb : (i < 4.0 ? c3.rgb : c4.rgb)));
	vec3 b = i < 1.0 ? c1.rgb : (i < 2.0 ? c2.rgb : (i < 3.0 ? c3.rgb : (i < 4.0 ? c4.rgb : c5.rgb)));
	return mix(a, b, f);
}

void fragment() {
	float m = max(magie_echelle, 1.0);
	// pixel du MONDE (grain ps1) : tout le motif est évalué au centre du gros pixel
	vec2 q = (floor(v_px / m) + 0.5) * m;
	float g = v_c.x;
	float age = clamp(v_c.y, 0.0, 1.0);
	float temp = fract(g * 0.618);
	// repère « haut du monde » (les langues montent même main penchée), puis rotation propre de la bouffée (elle roule)
	// coordonnées de la bouffée ramenée à un rond (étirement défait), dans le repère « haut du monde »
	vec2 qa = vec2(dot(q, vec2(-v_ax.y, v_ax.x)) / v_rpx, dot(q, v_ax) / v_rl);
	vec2 qr = vec2(-v_ax.y, v_ax.x) * qa.x + v_ax * qa.y;
	vec2 uw = vec2(dot(qr, vec2(v_haut.y, -v_haut.x)), dot(qr, v_haut));
	float cr = cos(v_c.z), sr = sin(v_c.z);
	vec2 ur = mat2(vec2(cr, sr), vec2(-sr, cr)) * uw;
	float r = length(uw);
	// hors du disque : rien (coins du carré, et la moitié des pixels ne paient pas le motif)
	if (r > 1.0) {
		discard;
	}
	float tt = TIME + g;
	// déformation qui dérive (la matière roule et se tord) : lue dans le bruit précalculé
	vec2 np = ur * (1.4 + age * 1.0) + vec2(g * 1.3, g * 0.7);
	vec2 w = texture(bruit, (np * 0.8 + vec2(0.0, tt * 1.6)) * 0.125).rg;
	float n = texture(bruit, (np * 1.2 + (w - 0.5) * 2.4 + vec2(tt * 0.6, -tt * 1.4 - age * 3.0)) * 0.125).b;
	// FORMES (atlas Kenney) : chaque bouffée enchaîne les volumes de flamme comme un flipbook (fondu d'une forme à la
	// suivante, ~5 par seconde, départ propre à chaque bouffée) ; jeune et rapide, c'est une LANGUE dont la pointe file
	// dans le sens de la vitesse ; en vieillissant elle passe à la fumée. Coordonnées déformées par le bruit : même une
	// forme donnée ne reste jamais figée.
	// (2026-10-30) images NETTES : chaque forme est tenue telle quelle puis bascule vite sur la suivante (l'ancien fondu
	// de 70 % du cycle mêlait deux formes en bouillie) ; déformation par le bruit réduite pour garder leur silhouette.
	vec2 dw = (w - 0.5) * (0.1 + 0.12 * age);
	vec2 up = clamp(ur * 0.5 * (1.0 + 0.12 * age) + 0.5 + dw, vec2(0.01), vec2(0.99));
	float fa = age * 5.5 + TIME * 1.5 + g * 3.0;
	float fi = floor(fa);
	float ff = smoothstep(0.82, 0.97, fract(fa));
	float ia = mod(fi, 4.0), ib = mod(fi + 1.0, 4.0);
	float flamme = mix(texture(formes, (up + vec2(ia, 0.0)) / vec2(4.0, 3.0)).r, texture(formes, (up + vec2(ib, 0.0)) / vec2(4.0, 3.0)).r, ff);
	// langue (jeune) et fumée (vieille) lues seulement quand elles comptent : l'âge est le même sur toute la bouffée,
	// la branche est cohérente (2 lectures de moins sur la plupart des pixels)
	float dens = flamme * 1.7;
	if (age < 0.16) {
		// langue : repère de la vitesse (pointe en avant), ondule
		vec2 ul = clamp(vec2(qa.x * 0.3 + 0.5 + (w.x - 0.5) * 0.2, 0.5 - qa.y * 0.5), vec2(0.01), vec2(0.99));
		float langue = texture(formes, (ul + vec2(mod(floor(g * 5.0), 2.0), 2.0)) / vec2(4.0, 3.0)).r;
		dens = mix(max(langue * 1.2, flamme * 0.9), dens, smoothstep(0.03, 0.16, age));
	}
	if (age > 0.55) {
		float fum = texture(formes, (up + vec2(mod(floor(g * 7.0), 4.0), 1.0)) / vec2(4.0, 3.0)).r;
		dens = mix(dens, fum * 1.3, smoothstep(0.55, 0.9, age));
	}
	// bouillonnement : le bruit ronge et creuse la forme (plus en vieillissant : lambeaux)
	float corps = (dens - 0.07 + (n - 0.5) * (0.3 + 0.35 * age)) * 3.0;
	corps -= max(0.0, 0.45 - n) * 2.0 * age * age;
	// à la sortie de la paume : seulement le cœur des langues (pas de voile pâle et tramé autour de la main)
	corps -= (1.0 - smoothstep(0.02, 0.09, age)) * 0.22;
	// naissance (apparaît dans la paume, pas de pop) et extinction (la fumée se dissipe)
	corps *= smoothstep(0.0, 0.012, age) * (1.0 - smoothstep(0.8, 1.0, age)) * v_proche;
	if (corps < 0.03) {
		discard;
	}
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	// température : blanc-jaune au cœur des bouffées jeunes, orange, rouge sombre au bord et en vieillissant, fumée
	// (le blanc ne tient que dans la paume et au creux des jeunes langues : le corps est jaune-orange saturé, veiné)
	// refroidit lentement en vol (la flamme porte loin), puis vite en fin de vie (rouge sombre, fumée)
	float h = 0.55 - age * 0.38 - smoothstep(0.5, 0.92, age) * 0.6 + (dens - 0.55) * 0.7 + (0.35 - r) * 0.2 + (n - 0.5) * 1.1 + (w.x - 0.5) * 0.35 + (temp - 0.5) * 0.3
		+ pow(1.0 - age, 8.0) * 0.1;
	// jeune : jaune d'or saturé (le blanc pur ne reste qu'au creux, sinon voile laiteux autour de la main)
	h = min(h, mix(0.58, 0.92, smoothstep(0.7, 1.05, dens)) + 0.25 * smoothstep(0.6, 2.5, v_proche_d));
	float k = clamp(corps, 0.0, 1.0);
	// couverture tramée par un bruit (pas de Bayer) qui « bout » à 12 images/s : 4 paliers
	vec2 cell = floor(FRAGCOORD.xy / m);
	float tr = mh2(cell + vec2(floor(TIME * 12.0) * 7.31, g));
	k = clamp(floor(k * 4.0 + tr) / 4.0, 0.0, 1.0);
	if (k <= 0.0) {
		discard;
	}
	vec3 c;
	float al;
	float lum;
	if (h > 0.0) {
		c = rampe(h);
		// lumière seulement sur le blanc-jaune (sinon les bouffées superposées saturent en un pâté blanc)
		al = opacite * clamp(0.6 + h * 0.3, 0.0, 1.0);
		lum = clamp(h - 0.7, 0.0, 1.0) * 0.5;
	} else {
		// fumée : rouge sombre qui noircit, couvrante mais légère, sans lumière
		float f = clamp(-h * 2.5, 0.0, 1.0);
		c = mix(c5.rgb, c_fumee.rgb, f);
		al = mix(opacite * 0.75, fumee, f) * (1.0 - 0.5 * f * age);
		lum = 0.0;
	}
	ALBEDO = c * (al + lum) * eclat * k;
	ALPHA = al * k;
}
