shader_type canvas_item;
// Livre de la direction A « parchemin et cuir enluminé » (maquette Desktop/Skyrim captures/maquettes_menu/A_parchemin,
// direction.js : livre()) : cuir à grain, couture, deux pages de vélin, ombre de reliure, bords brunis, taches, tranche.
// Peint par PIXEL LOGIQUE (taille = écran logique d'EchelleUi) : bruit de valeur + bruit fin, quantifié sur les rampes
// CUIR / VÉLIN ; jamais de tramage Bayer. Les plaques de fer des coins sont dessinées par LivreParchemin (GDScript).

uniform vec2 taille = vec2(640.0, 360.0);
uniform float graine = 7.0;

const vec3 CUIR[4] = vec3[4](vec3(0.078, 0.047, 0.024), vec3(0.227, 0.141, 0.078), vec3(0.353, 0.227, 0.125), vec3(0.541, 0.353, 0.196));
const vec3 VELIN[7] = vec3[7](vec3(0.573, 0.380, 0.227), vec3(0.733, 0.541, 0.325), vec3(0.800, 0.627, 0.400), vec3(0.804, 0.722, 0.557),
	vec3(0.847, 0.776, 0.620), vec3(0.878, 0.831, 0.706), vec3(0.910, 0.878, 0.784));

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + graine * 0.013);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// bruit de valeur lissé (bilinéaire, smoothstep), grille de `cel` pixels
float bruit(vec2 p, float cel, float decal) {
	vec2 f = p / cel;
	vec2 i = floor(f);
	vec2 t = f - i;
	t = t * t * (3.0 - 2.0 * t);
	float a = h21(i + decal);
	float b = h21(i + vec2(1.0, 0.0) + decal);
	float c = h21(i + vec2(0.0, 1.0) + decal);
	float d = h21(i + vec2(1.0, 1.0) + decal);
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

void fragment() {
	vec2 p = floor(UV * taille);
	float W = taille.x;
	float H = taille.y;
	float x = p.x;
	float y = p.y;
	float n1 = bruit(p, 9.0, 11.0);
	float n2 = bruit(p, 3.0, 37.0);
	float n3 = bruit(p, 23.0, 71.0);
	float r = h21(p + 0.5);
	float v = n1 * 0.55 + n2 * 0.25 + r * 0.2;
	float PX0 = 10.0;
	float PX1 = W - 11.0;
	float PY0 = 20.0;
	float PY1 = H - 21.0;
	float spine = floor(W * 0.5) - 0.5;
	vec3 col;
	bool page = x >= PX0 && x <= PX1 && y >= PY0 && y <= PY1;
	if (!page) {
		float k = v * 0.8 + n3 * 0.35;
		float bord = min(min(x, y), min(W - 1.0 - x, H - 1.0 - y));
		if (bord < 2.0) { k -= 0.5; } else if (bord < 4.0) { k -= 0.15; }
		int i = k < 0.32 ? 0 : (k < 0.62 ? 1 : (k < 0.86 ? 2 : 3));
		col = CUIR[i];
		// tranche des pages (épaisseur) sous le vélin, interrompue à la reliure
		if (x > PX0 && x < PX1 && abs(x - spine) >= 4.0) {
			if (y == PY1 + 1.0) { col = mod(x, 5.0) == 0.0 ? VELIN[1] : VELIN[3]; }
			else if (y == PY1 + 2.0) { col = mod(x, 7.0) == 0.0 ? VELIN[0] : VELIN[1]; }
			else if (y == PY1 + 3.0) { col = CUIR[1]; }
		}
		// couture en pointillés de 1 px
		if ((y == 4.0 || y == H - 5.0) && x >= 6.0 && x < W - 6.0 && mod(x, 4.0) < 2.0) { col = VELIN[0]; }
		if ((x == 4.0 || x == W - 5.0) && y >= 6.0 && y < H - 6.0 && mod(y, 4.0) < 2.0) { col = VELIN[0]; }
	} else {
		float t = 4.0 + (v - 0.5) * 3.2 + (n3 - 0.5) * 1.4;
		float ds = abs(x - spine);
		if (ds < 1.0) { t -= 3.4; } else if (ds < 3.0) { t -= 2.2; } else if (ds < 6.0) { t -= 1.3; } else if (ds < 11.0) { t -= 0.6; }
		float db = min(min(x - PX0, PX1 - x), min(y - PY0, PY1 - y));
		if (db < 1.0) { t -= 2.6; } else if (db < 3.0) { t -= 1.2; } else if (db < 6.0) { t -= 0.45; }
		// taches du vélin (positions relatives : la maquette 480x270 les met en (60,200) (395,64) (300,222) (160,40))
		vec3 taches[4] = vec3[4](vec3(0.125, 0.74, 16.0), vec3(0.82, 0.24, 12.0), vec3(0.625, 0.82, 9.0), vec3(0.333, 0.15, 7.0));
		for (int k = 0; k < 4; k++) {
			vec2 c = vec2(taches[k].x * W, taches[k].y * H);
			float dd = length(vec2(x - c.x, (y - c.y) * 1.3)) / taches[k].z;
			if (dd < 1.0 && n2 * 0.5 + 0.6 > dd) { t -= 0.9; }
		}
		col = VELIN[int(clamp(round(t), 0.0, 6.0))];
	}
	COLOR = vec4(col, 1.0);
}
