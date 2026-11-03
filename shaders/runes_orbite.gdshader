// Runes en orbite autour de la magie tenue en main (scripts/magie/runes_orbite.gd) : petites runes nordiques lumineuses
// (cercle + signe), dessinées au pixel dans un quad face caméra, et le fil d'orbite (ruban fin, pointillé qui court).
// Mélange alpha en HDR (le glow de l'environnement fait le halo), sans éclairage ni profondeur écrite : compatible Compatibility / WebGL2 (pas de texture, pas de calcul).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 couleur : source_color = vec3(1.0, 0.45, 0.12);
uniform vec3 coeur : source_color = vec3(1.0, 0.86, 0.55);
uniform float texels = 30.0;          // texels par rune (pixel art)
uniform bool cercle_rune = false;      // true : ancien médaillon (cercle autour du signe)
uniform bool ligne = false;           // false = rune (quad), true = fil d'orbite (ruban, UV.x le long du tour)
instance uniform float symbole = 0.0; // 0..5 : signe dans le cercle
instance uniform float eclat = 1.0;   // luminosité (variations par rune, intensité du sort)
instance uniform float defile = 0.0;  // fil : avance du pointillé (tours)
instance uniform float arc = 1.0;     // fil : fraction du tour visible (arc partiel aux extrémités fondues)

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// distance au trait du signe `s` (p dans [-1, 1]²)
float signe(vec2 p, float s) {
	float d = 9.0;
	if (s < 0.5) {            // croix de visée (référence feu)
		d = min(seg(p, vec2(0.0, -0.95), vec2(0.0, 0.95)), seg(p, vec2(-0.95, 0.0), vec2(0.95, 0.0)));
	} else if (s < 1.5) {     // Kenaz : chevron
		d = min(seg(p, vec2(0.25, 0.55), vec2(-0.3, 0.0)), seg(p, vec2(-0.3, 0.0), vec2(0.25, -0.55)));
		d = min(d, seg(p, vec2(0.0, -0.95), vec2(0.0, -0.62)));
		d = min(d, seg(p, vec2(0.0, 0.62), vec2(0.0, 0.95)));
	} else if (s < 2.5) {     // Sowilo : éclair
		d = min(seg(p, vec2(0.25, 0.6), vec2(-0.25, 0.1)), seg(p, vec2(-0.25, 0.1), vec2(0.25, -0.1)));
		d = min(d, seg(p, vec2(0.25, -0.1), vec2(-0.25, -0.6)));
	} else if (s < 3.5) {     // croix et losange
		d = min(seg(p, vec2(0.0, -0.95), vec2(0.0, 0.95)), seg(p, vec2(-0.95, 0.0), vec2(0.95, 0.0)));
		d = min(d, abs(abs(p.x) + abs(p.y) - 0.42));
	} else if (s < 4.5) {     // Tiwaz : flèche
		d = min(seg(p, vec2(0.0, -0.6), vec2(0.0, 0.6)), seg(p, vec2(-0.35, 0.25), vec2(0.0, 0.6)));
		d = min(d, seg(p, vec2(0.35, 0.25), vec2(0.0, 0.6)));
	} else if (s < 5.5) {     // Ingwaz : losange et pointes (voir plus bas)
		d = abs(abs(p.x) + abs(p.y) * 0.8 - 0.4);
		d = min(d, min(seg(p, vec2(0.0, 0.5), vec2(0.0, 0.95)), seg(p, vec2(0.0, -0.5), vec2(0.0, -0.95))));
	} else if (s < 6.5) {     // Raidho : R
		d = seg(p, vec2(-0.3, -0.8), vec2(-0.3, 0.8));
		d = min(d, seg(p, vec2(-0.3, 0.8), vec2(0.3, 0.45)));
		d = min(d, seg(p, vec2(0.3, 0.45), vec2(-0.3, 0.05)));
		d = min(d, seg(p, vec2(-0.1, 0.1), vec2(0.35, -0.8)));
	} else if (s < 7.5) {     // Othala : losange aux jambes
		d = abs(abs(p.x) + abs(p.y + 0.15) - 0.45);
		d = min(d, min(seg(p, vec2(-0.45, -0.85), vec2(-0.1, -0.2)), seg(p, vec2(0.45, -0.85), vec2(0.1, -0.2))));
	} else if (s < 8.5) {     // Fehu : branches vers le haut
		d = seg(p, vec2(-0.25, -0.85), vec2(-0.25, 0.85));
		d = min(d, seg(p, vec2(-0.25, 0.4), vec2(0.35, 0.85)));
		d = min(d, seg(p, vec2(-0.25, -0.05), vec2(0.35, 0.4)));
	} else if (s < 9.5) {     // Thurisaz : épine
		d = seg(p, vec2(-0.25, -0.85), vec2(-0.25, 0.85));
		d = min(d, seg(p, vec2(-0.25, 0.5), vec2(0.4, 0.0)));
		d = min(d, seg(p, vec2(0.4, 0.0), vec2(-0.25, -0.5)));
	} else {                  // Dagaz : sablier
		d = min(seg(p, vec2(-0.5, -0.7), vec2(0.5, 0.7)), seg(p, vec2(-0.5, 0.7), vec2(0.5, -0.7)));
		d = min(d, min(seg(p, vec2(-0.5, -0.7), vec2(-0.5, 0.7)), seg(p, vec2(0.5, -0.7), vec2(0.5, 0.7))));
	}
	return d;
}

void fragment() {
	if (ligne) {
		// fil d'orbite : fin, pointillé lumineux qui court, quelques grains plus vifs
		float u = fract(UV.x * 40.0 - defile * 40.0);
		float v = abs(UV.y - 0.5) * 2.0;
		float tiret = smoothstep(0.0, 0.15, u) * smoothstep(0.85, 0.55, u);
		float grain = step(0.93, fract(sin(floor(UV.x * 160.0) * 91.7) * 4375.5));
		float fa = fract(UV.x - defile * 0.0);
		float partie = smoothstep(0.0, 0.18 * arc + 0.02, fa) * (1.0 - smoothstep(arc - 0.2 * arc, arc, fa)) * step(fa, arc);
		float a = ((0.35 + 0.65 * tiret) * (1.0 - v) * eclat * 0.55 + grain * 0.6 * eclat * (1.0 - v)) * partie;
		ALBEDO = mix(couleur, coeur, grain * 0.7) * 1.6;
		ALPHA = clamp(a, 0.0, 1.0);
	} else {
		// rune : quantifiée en `texels` (pixel art), cercle + signe, halo doux autour
		vec2 q = (floor(UV * texels) + 0.5) / texels * 2.0 - 1.0;
		float r = length(q);
		float px = 2.0 / texels;
		float cercle = abs(r - 0.58);
		float trait = cercle_rune ? min(cercle, signe(q, symbole)) : signe(q * 1.05, symbole);
		float plein = 1.0 - step(px * 0.6, trait);
		float halo = exp(-r * r * 3.2) * 0.3;
		vec3 c = mix(couleur, coeur, 0.2 * plein) * (1.1 + 0.6 * plein);
		ALBEDO = c;
		ALPHA = clamp(plein * eclat + halo * eclat, 0.0, 1.0);
	}
}
