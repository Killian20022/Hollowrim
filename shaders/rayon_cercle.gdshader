// CERCLE RUNIQUE au départ du RAYON NOIR (scripts/magie/rayon_noir.gd, v3) : dessiné par calcul dans un quad perpendiculaire au rayon.
// Anneau extérieur fin + liseré, couronne de 12 runes qui tourne et s'allume une à une, anneau pointillé qui tourne en sens inverse,
// hexagramme intérieur, graduations. `ouv` (0..1) : le cercle s'ouvre en tournant (du centre vers l'extérieur) et se ferme de même.
// Mélange alpha en HDR (le glow fait la lueur). Aucune texture, aucun tramage.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 noir : source_color = vec3(0.01, 0.0, 0.03);
uniform vec3 bord : source_color = vec3(0.78, 0.13, 0.66);
uniform vec3 accent : source_color = vec3(0.89, 0.24, 0.77);
uniform vec3 filet : source_color = vec3(1.0, 0.77, 0.95);
uniform float ouv = 1.0;
uniform float t = 0.0;

const float NB = 12.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float h11(float x) { return fract(sin(x * 127.1 + 4.7) * 43758.5453); }
mat2 rot(float a) { return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))); }

// glyphe pseudo-runique : hampe + deux branches tirées au sort (p dans [-1,1]²)
float glyphe(vec2 p, float id) {
	float d = seg(p, vec2(0.0, -0.8), vec2(0.0, 0.8));
	float a = h11(id), b = h11(id + 9.3), c = h11(id + 3.1);
	vec2 p0 = vec2(0.0, mix(0.8, 0.1, a));
	vec2 p1 = vec2(mix(0.55, -0.55, b), mix(p0.y + 0.1, p0.y - 0.5, c));
	d = min(d, seg(p, p0, p1));
	if (c > 0.4) {
		vec2 q0 = vec2(0.0, mix(-0.1, -0.8, a));
		vec2 q1 = vec2(mix(-0.55, 0.55, b), q0.y + mix(0.55, 0.15, c));
		d = min(d, seg(p, q0, q1));
	}
	return d;
}

float trait(float d, float e) { return 1.0 - smoothstep(e * 0.6, e, d); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 col = vec3(0.0);
	float al = 0.0;
	float re = ouv * 1.02;                       // rayon d'ouverture : tout ce qui est au-delà n'existe pas encore
	float fen = 1.0 - smoothstep(re - 0.08, re, r);
	// fond sombre translucide, plus dense au centre (le rayon sort du noir), vide au milieu pour voir le tir
	float fond = smoothstep(0.98, 0.35, r) * (1.0 - smoothstep(0.30, 0.0, r)) * 0.3;
	col = bord * 0.35; al = fond * fen * 0.6;   // v4 : fond violet lumineux (additif), plus de disque sombre
	float pix = 0.012;
	// anneau extérieur double + graduations
	float a1 = trait(abs(r - 0.96), 0.02 + pix);
	float a2 = trait(abs(r - 0.90), 0.008 + pix);
	float grad = trait(abs(fract((ang + t * 0.06) / TAU * 72.0) - 0.5) * r * 0.087, 0.004) * step(0.905, r) * step(r, 0.94);
	// anneau pointillé, sens inverse
	float seg_n = fract((ang - t * 0.55) / TAU * 36.0);
	float pointille = trait(abs(r - 0.52), 0.014 + pix) * step(seg_n, 0.55);
	// couronne de runes : 12 glyphes, rotation lente ; allumage en vague
	float turn = t * 0.35;
	float cell = floor(fract((ang - turn) / TAU) * NB);
	float ca = (cell + 0.5) / NB * TAU + turn;
	vec2 cen = vec2(cos(ca), sin(ca)) * 0.73;
	vec2 loc = (p - cen) / 0.1;
	loc = rot(-(ca - 1.5707963)) * loc;
	float gd = glyphe(loc, cell + floor(t * 0.0));
	float lum = pow(0.5 + 0.5 * sin(t * 4.0 - cell * 1.1), 3.0);      // la vague d'allumage
	float runes = trait(gd * 0.1, 0.012 + pix * 0.6) * step(abs(loc.x), 1.2) * step(abs(loc.y), 1.2);
	float lisere_c = trait(abs(r - 0.73), 0.075) * 0.18;                 // sillon sous les runes
	// triskèle intérieur (3 bras spiralés qui tournent), motif nordique sobre
	float a3 = fract((ang - t * 0.8) / TAU * 3.0);
	float rc = 0.07 + 0.31 * a3;
	float tris = trait(abs(r - rc) * 0.8, 0.014 + pix) * step(r, 0.42) * step(0.06, r);
	float hexa = tris;
	float noyau = trait(abs(r - 0.18), 0.012 + pix) * (0.6 + 0.4 * sin(t * 6.0));
	// vue de face (depuis le lanceur) : le fond et le triskèle s'effacent, anneau et runes restent
	float face = abs(dot(normalize(VIEW), NORMAL));
	float leger = mix(1.0, 0.12, smoothstep(0.55, 0.95, face));
	al *= leger;
	hexa *= leger;
	noyau *= leger;
	// composition HDR
	vec3 c = col;
	float aa = al;
	float lisere = max(a1, max(a2 * 0.8, grad * 0.8));
	vec3 cl = mix(bord, filet, a1 * 0.3) * (0.75 + 0.25 * sin(t * 3.0));   // v5 : cercle plus sombre et discret   // v5 : moins blanc
	c = mix(c, cl, lisere); aa = max(aa, lisere * 0.95);
	c = mix(c, accent * 1.6, pointille * 0.9); aa = max(aa, pointille * 0.85);
	c = mix(c, bord * 0.9, lisere_c); aa = max(aa, lisere_c * 0.6);
	vec3 cr = mix(bord * 1.1, filet * 1.3, lum);
	c = mix(c, cr, runes * (0.45 + 0.55 * lum)); aa = max(aa, runes * (0.55 + 0.45 * lum));
	c = mix(c, accent * 1.8, hexa * 0.8); aa = max(aa, hexa * 0.75);
	c = mix(c, filet * 1.6, noyau); aa = max(aa, noyau * 0.9);
	// naissance : le front d'ouverture est un anneau vif
	float front = trait(abs(r - re), 0.05) * (1.0 - smoothstep(0.9, 1.0, ouv));
	c = mix(c, filet * 2.2, front); aa = max(aa, front);
	aa *= fen * smoothstep(0.0, 0.15, ouv);
	aa *= mix(1.0, 0.5, smoothstep(0.55, 0.95, face));   // v3f : cercle discret quand on le regarde de face (1re personne)
	ALBEDO = c * clamp(aa, 0.0, 1.0);   // v4 : additif prémultiplié (couche fine : aucune opacité, donc aucun aplat sombre)
	ALPHA = 0.0;
}
