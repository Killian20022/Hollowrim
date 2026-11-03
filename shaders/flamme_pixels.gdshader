// Flamme de torche en GROS PIXELS (remplace le sprite lisse de flamme_sprite.gdshader pour la torche tenue).
// Un seul quad par flamme, plan écran accroché au pied de la flamme. La flamme est calculée par CASES : chaque case est un carré de
// `cellpx` pixels d'écran entiers (grille accrochée aux pixels, taille bornée comme les gerbes de gerbe_pixels.gdshaderinc), palette de
// 5 tons FRANCS (cœur blanc-jaune, jaune, orange, rouge, braise sombre), aucun dégradé ni flou. Le bruit défile vers le haut à 12 i/s.
// INERTIE : `pointe` = vecteur monde pied → pointe de la flamme (calculé par scripts/flamme_torche.gd à partir de la vitesse réelle,
// ressort amorti). Il est PROJETÉ à l'écran : la flamme se couche, s'étire et se courbe exactement comme la perspective le montre
// (vers l'arrière de la marche, aussi en 3e personne). `agitation` (0..1) : vacillement, secousses de saut/atterrissage.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform vec3 c_coeur : source_color = vec3(1.0, 0.96, 0.69);
uniform vec3 c_jaune : source_color = vec3(1.0, 0.78, 0.23);
uniform vec3 c_orange : source_color = vec3(0.94, 0.45, 0.10);
uniform vec3 c_rouge : source_color = vec3(0.77, 0.19, 0.08);
uniform vec3 c_braise : source_color = vec3(0.33, 0.09, 0.06);
uniform vec3 pointe = vec3(0.0, 0.196, 0.0);   // monde, depuis le pied
uniform float cell_m = 0.014;                  // taille d'une case au repos (m)
uniform float cases_h = 14.0;                  // hauteur nominale de la flamme (cases)
uniform float agitation = 0.0;
uniform float phase = 0.0;
uniform float pos_biais = 0.015;               // recul vers la caméra (m) : faible, la tête bombée de la torche cache le pied de la flamme
uniform float base_cases = 4.5;                // hauteur (cases) de l'arrondi du pied
const float CX = 24.0;
const float CY = 34.0;

varying flat float v_cell;
varying flat vec2 v_tip;   // pointe en cases, depuis le pied

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 vp = VIEWPORT_SIZE;
	float k = vp.y / 270.0;
	vec3 vo = (VIEW_MATRIX * vec4(o, 1.0)).xyz;
	vec4 c0 = PROJECTION_MATRIX * vec4(vo, 1.0);
	float w = max(c0.w, 0.0001);
	float pxm = abs(PROJECTION_MATRIX[1][1]) * vp.y * 0.5 / w;
	float cell = floor(clamp(cell_m * pxm, 2.0 * k, 6.0 * k) + 0.5);
	vec2 p0 = (c0.xy / w * 0.5 + 0.5) * vp;
	p0 = floor(p0 + 0.5);
	vec4 c1 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(o + pointe, 1.0));
	vec2 p1 = (c1.xy / max(c1.w, 0.0001) * 0.5 + 0.5) * vp;
	float sy = PROJECTION_MATRIX[1][1] < 0.0 ? -1.0 : 1.0;   // axe Y de l'écran retourné selon le rendu
	vec2 d = c1.w > 0.0001 ? (p1 - p0) / cell * vec2(1.0, sy) : vec2(0.0, cases_h);
	// bornes : la pointe reste dans le quad, la flamme garde au moins quelques cases de haut
	d.x = clamp(d.x, -CX * 0.46, CX * 0.46);
	d.y = clamp(d.y, 3.0, CY * 0.92);
	v_cell = cell;
	v_tip = d;
	vec2 p = p0 + vec2(VERTEX.x * CX * cell, sy * VERTEX.y * CY * cell);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec4 cb = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(o + normalize(cam - o + vec3(0.0, 0.0001, 0.0)) * pos_biais, 1.0));
	POSITION = vec4((p / vp * 2.0 - 1.0) * w, cb.z / max(cb.w, 0.0001) * w, w);
}

void fragment() {
	float f = floor(TIME * 12.0 + phase * 7.0);
	float u = UV.x * CX;
	float v = (1.0 - UV.y) * CY;
	float cx = floor(u);
	float cy = floor(v);
	float x = cx + 0.5 - CX * 0.5;
	float y = cy + 0.5;
	float H = v_tip.y;
	float t = y / H;
	float a = clamp(agitation, 0.0, 1.5);
	// ligne médiane : courbe vers la pointe (inertie) + ondulation par paliers (vacille à l'arrêt)
	float ond = sin(f * 0.9 + t * 5.5 + phase * 3.0) * (0.55 + 0.9 * a) * t + sin(f * 1.7 + t * 9.0) * 0.3 * t * (0.4 + a);
	float c = v_tip.x * pow(clamp(t, 0.0, 1.5), 1.6) + floor(ond * 2.0 + 0.5) * 0.5;
	// bruit qui monte (une case par image) et bruit de contour
	float n1 = h21(vec2(cx, cy - f));
	float n2 = h21(vec2(cx + f * 3.0, cy * 1.7));
	float lie = clamp(length(v_tip) / (cases_h * 1.0) - 1.0, 0.0, 1.0);   // étirement : plus de langues détachées
	float larg = (4.4 + 0.6 * lie) * pow(max(1.0 - t, 0.0), 0.75) * (0.9 + 0.22 * h21(vec2(cy, floor(f * 0.5))));
	// pied ARRONDI (arc d'ellipse) : la flamme naît dans la tête bombée de la torche, elle ne repose pas sur une ligne droite
	float k0 = clamp(y / base_cases, 0.0, 1.0);
	larg *= sqrt(max(1.0 - (1.0 - k0) * (1.0 - k0), 0.0)) * (1.0 + 0.25 * (1.0 - k0));
	float dx = abs(x - c);
	float bord = (n1 - 0.5) * (1.4 + 1.2 * a) * smoothstep(0.05, 0.45, t);
	bool dedans = t < 1.0 + (n2 - 0.5) * 0.3 && dx < larg + bord && y > 0.0;
	// braises détachées au-dessus de la pointe (et en traînée quand elle est étirée)
	bool detache = false;
	if (!dedans) {
		float tt = t - 1.0;
		float seuil = 0.86 - 0.12 * lie - 0.05 * a;
		detache = tt > 0.0 && tt < 0.45 + 0.4 * lie && dx < 1.6 + 2.0 * lie && n1 > seuil && n2 > 0.35;
	}
	if (!dedans && !detache) {
		discard;
	}
	float d = dx / max(larg, 0.5);
	float s = d * 0.9 + t * 0.85 + (n2 - 0.5) * 0.3;
	vec3 col;
	if (detache) {
		col = n2 > 0.7 ? c_orange : c_rouge;
	} else if (s < 0.30) {
		col = c_coeur;
	} else if (s < 0.58) {
		col = c_jaune;
	} else if (s < 0.88) {
		col = c_orange;
	} else if (s < 1.12) {
		col = c_rouge;
	} else {
		if (n1 < 0.45) {
			discard;
		}
		col = c_braise;
	}
	ALBEDO = col;
}
