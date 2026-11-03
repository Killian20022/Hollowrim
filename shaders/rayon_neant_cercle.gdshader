// GRAND CERCLE RUNIQUE du « rayon du néant » (scripts/magie/cercle_neant.gd) : un anneau vertical fin devant la main, face à la
// visée. Il se TRACE progressivement (`trace` 0..1 le long de la circonférence), ses runes de ténèbres s'allument une à une
// (`allumees`) et tournent lentement (`rot`). Le centre reste vide (transparent) pour ne pas masquer la cible. Un liseré sombre
// double chaque trait : lisible aussi sur un fond clair. Dessiné au pixel (`texels`), mélange alpha, occlusion de la couche fine.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
#include "res://shaders/magie_bruit.gdshaderinc"

uniform vec3 couleur : source_color = vec3(0.64, 0.24, 1.0);
uniform vec3 coeur : source_color = vec3(0.91, 0.72, 1.0);
uniform vec3 ombre : source_color = vec3(0.03, 0.01, 0.06);
uniform float texels = 230.0;
uniform float trace = 1.0;       // fraction de l'anneau déjà tracée (0..1)
uniform float allumees = 8.0;    // nombre de runes allumées (fractionnaire : la dernière monte en éclat)
uniform float rot = 0.0;         // rotation des runes (rad)
uniform float eclat = 1.0;       // luminosité globale
uniform float flash = 0.0;       // 0..1 : le rayon traverse le cercle (traits épaissis, onde)
uniform float fondu = 1.0;       // opacité globale

const int NB_RUNES = 8;
const float R_EXT = 0.90;
const float R_INT = 0.66;
const float R_RUNE = 0.78;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// signes de ténèbres (mêmes tracés que shaders/runes_orbite.gdshader : Kenaz, Tiwaz, Ingwaz, Othala, Raidho, croix)
float signe(vec2 p, int s) {
	float d = 9.0;
	if (s == 0) {         // Kenaz : chevron
		d = min(seg(p, vec2(0.25, 0.55), vec2(-0.3, 0.0)), seg(p, vec2(-0.3, 0.0), vec2(0.25, -0.55)));
		d = min(d, seg(p, vec2(0.0, -0.95), vec2(0.0, -0.62)));
		d = min(d, seg(p, vec2(0.0, 0.62), vec2(0.0, 0.95)));
	} else if (s == 1) {  // Tiwaz : flèche
		d = min(seg(p, vec2(0.0, -0.6), vec2(0.0, 0.6)), seg(p, vec2(-0.35, 0.25), vec2(0.0, 0.6)));
		d = min(d, seg(p, vec2(0.35, 0.25), vec2(0.0, 0.6)));
	} else if (s == 2) {  // Ingwaz : losange et pointes
		d = abs(abs(p.x) + abs(p.y) * 0.8 - 0.4);
		d = min(d, min(seg(p, vec2(0.0, 0.5), vec2(0.0, 0.95)), seg(p, vec2(0.0, -0.5), vec2(0.0, -0.95))));
	} else if (s == 3) {  // Othala : losange aux jambes
		d = abs(abs(p.x) + abs(p.y + 0.15) - 0.45);
		d = min(d, min(seg(p, vec2(-0.45, -0.85), vec2(-0.1, -0.2)), seg(p, vec2(0.45, -0.85), vec2(0.1, -0.2))));
	} else if (s == 4) {  // Raidho : R
		d = seg(p, vec2(-0.3, -0.8), vec2(-0.3, 0.8));
		d = min(d, seg(p, vec2(-0.3, 0.8), vec2(0.3, 0.45)));
		d = min(d, seg(p, vec2(0.3, 0.45), vec2(-0.3, 0.05)));
		d = min(d, seg(p, vec2(-0.1, 0.1), vec2(0.35, -0.8)));
	} else if (s == 5) {  // croix et losange
		d = min(seg(p, vec2(0.0, -0.95), vec2(0.0, 0.95)), seg(p, vec2(-0.95, 0.0), vec2(0.95, 0.0)));
		d = min(d, abs(abs(p.x) + abs(p.y) - 0.42));
	} else if (s == 6) {  // Dagaz : sablier
		d = min(seg(p, vec2(-0.5, -0.7), vec2(0.5, 0.7)), seg(p, vec2(-0.5, 0.7), vec2(0.5, -0.7)));
		d = min(d, min(seg(p, vec2(-0.5, -0.7), vec2(-0.5, 0.7)), seg(p, vec2(0.5, -0.7), vec2(0.5, 0.7))));
	} else {              // Thurisaz : épine
		d = seg(p, vec2(-0.25, -0.85), vec2(-0.25, 0.85));
		d = min(d, seg(p, vec2(-0.25, 0.5), vec2(0.4, 0.0)));
		d = min(d, seg(p, vec2(0.4, 0.0), vec2(-0.25, -0.5)));
	}
	return d;
}

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	vec2 q = (floor(UV * texels) + 0.5) / texels * 2.0 - 1.0;
	q.y = -q.y;
	float r = length(q);
	float px = 2.0 / texels;
	float f = fract(atan(q.x, q.y) / TAU + 1.0);          // 0 en haut, croît dans le sens horaire
	float ep = px * (0.75 + 1.1 * flash);                  // demi-épaisseur des traits

	float lum = 0.0;      // trait lumineux
	float ang_tete = 0.0;

	// anneau extérieur : tracé de f = 0 à f = trace ; la tête du tracé brille
	float d_ext = abs(r - R_EXT);
	float vis_ext = step(f, trace);
	float tete = exp(-max(trace - f, 0.0) * 22.0) * step(f, trace);
	lum = max(lum, (1.0 - step(ep, d_ext)) * vis_ext * (0.7 + 0.5 * tete));
	// double filet : trait fin juste à l'intérieur, tracé en sens inverse
	float d_fin = abs(r - (R_EXT - 0.045));
	float vis_fin = step(1.0 - f, trace);
	lum = max(lum, (1.0 - step(px * 0.55, d_fin)) * vis_fin * 0.55);
	// anneau intérieur en tirets qui défilent
	float d_int = abs(r - R_INT);
	float tiret = step(0.5, fract(f * 48.0 - rot * 3.0));
	lum = max(lum, (1.0 - step(px * 0.6, d_int)) * tiret * step(f, trace) * 0.6);
	// graduations entre les deux anneaux (24), allumées au fil du tracé
	float gr = fract(f * 24.0 + rot * 0.0);
	float d_gr = min(gr, 1.0 - gr) * TAU * r / 24.0;
	float dans_gr = step(R_INT + 0.03, r) * step(r, R_INT + 0.075);
	lum = max(lum, (1.0 - step(px * 0.55, d_gr)) * dans_gr * step(f, trace - 0.02) * 0.5);

	// runes : une par secteur de 45°, tournantes ; chacune s'allume quand `allumees` dépasse son rang
	float secteur = TAU / float(NB_RUNES);
	float a = atan(q.x, q.y) - rot;
	float idx = floor(a / secteur + 0.5);
	float a0 = idx * secteur + rot;
	vec2 ctr = vec2(sin(a0), cos(a0)) * R_RUNE;
	vec2 tang = vec2(cos(a0), -sin(a0));
	vec2 rad = vec2(sin(a0), cos(a0));
	vec2 loc = vec2(dot(q - ctr, tang), dot(q - ctr, rad)) / 0.085;
	int rang = int(mod(idx + 64.0, float(NB_RUNES)));
	float on = clamp(allumees - float(rang), 0.0, 1.0);
	int sig = int(mod(float(rang) * 3.0 + 1.0, 7.0));
	float dr = signe(loc * 1.05, sig);
	float trait_r = 1.0 - step(0.2 + 0.05 * flash, dr);
	float cadre = 1.0 - step(0.06, abs(max(abs(loc.x), abs(loc.y)) - 1.12));  // cadre ténu autour de la rune
	float halo_r = exp(-dot(loc, loc) * 1.1) * 0.22;
	float rune = max(trait_r, cadre * 0.35) * on;
	float flick = 0.8 + 0.2 * sin(TIME * 5.0 + float(rang) * 1.7);
	float vif_rune = (rune * flick + halo_r * on) * (0.8 + 0.8 * (1.0 - on * 0.0));
	// la rune qui vient de s'allumer éclate d'abord
	float neuve = on > 0.0 && on < 1.0 ? 1.0 : 0.0;
	vif_rune += neuve * rune * 0.8;

	// halo doux autour des anneaux (le glow de l'environnement fait le reste), jamais au centre
	float halo = (exp(-d_ext * 14.0) * vis_ext * 0.32 + exp(-d_int * 18.0) * 0.1 * step(f, trace)) * step(R_INT - 0.1, r);
	// onde du tir : un anneau lumineux qui s'élargit
	float onde = flash > 0.0 ? exp(-abs(r - mix(0.2, 1.05, 1.0 - flash)) * 30.0) * flash * 0.6 : 0.0;

	float tout = max(max(lum, vif_rune), 0.0);
	// liseré sombre (1 pixel) autour des traits : lisible sur fond clair
	float bord = 0.0;
	if (tout < 0.05) {
		float proche = min(min(d_ext, d_int), abs(r - (R_EXT - 0.045)));
		bord = (1.0 - step(px * 2.2, proche)) * vis_ext * 0.55;
		bord = max(bord, (1.0 - step(0.3, dr)) * on * 0.45);
	}
	float lueur = (halo + halo_r * on * 0.6 + onde) * eclat;
	float a_tot = clamp(tout * 0.95 * eclat + lueur, 0.0, 1.0);
	vec3 c = mix(couleur, coeur, clamp(tout * 0.55 + tete * 0.6 + flash * 0.4, 0.0, 1.0)) * (1.15 + 0.7 * tout);
	if (a_tot < 0.04 && bord < 0.05) {
		discard;
	}
	if (tout < 0.05 && lueur < 0.08) {
		ALBEDO = ombre;
		ALPHA = bord * fondu;
	} else {
		ALBEDO = c;
		ALPHA = a_tot * fondu;
	}
}
