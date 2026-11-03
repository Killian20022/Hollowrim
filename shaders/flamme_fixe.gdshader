// Flamme FIXE en GROS PIXELS (feux de camp, foyers, forge, braseros, appliques, torches murales de la crypte) : même langage que
// flamme_pixels.gdshader (torche tenue, validée) — cases carrées de pixels d'écran entiers, 5 tons francs, pied arrondi enfoncé dans le
// support, bruit qui monte à 12 i/s — mais SANS inertie : pointe verticale + souffle du vent (`vent` = vecteur monde, projeté à l'écran,
// rafales lentes) + petit mouvement vivant. Un seul shader pour un MeshInstance3D (uniforms) ET pour un MultiMesh (INSTANCE_CUSTOM.x =
// phase, .y = échelle > 0). Plan écran accroché au pied de la flamme, taille d'une case = `cell_m` × échelle (m), bornée en pixels.
// `large` / `braises` : langues de feu de camp (plus larges, plus de braises détachées). `cuit` : feu enfermé (tons plus rouges : forge / four).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform vec3 c_coeur : source_color = vec3(1.0, 0.96, 0.69);
uniform vec3 c_jaune : source_color = vec3(1.0, 0.78, 0.23);
uniform vec3 c_orange : source_color = vec3(0.94, 0.45, 0.10);
uniform vec3 c_rouge : source_color = vec3(0.77, 0.19, 0.08);
uniform vec3 c_braise : source_color = vec3(0.33, 0.09, 0.06);
uniform float cell_m = 0.032;                  // taille d'une case (m) pour l'échelle 1 ; flamme = 14 cases de haut (0,45 m)
uniform float cases_h = 14.0;
uniform float cell_min_px = 1.0;               // borne basse de la case (px d'un rendu 270 de haut) : une bougie reste petite de loin
uniform float cell_max_px = 6.0;               // borne haute de la case (px d'un rendu 270 de haut)
uniform float agitation = 0.35;
uniform float phase_u = 0.0;
uniform float echelle_u = 1.0;
global uniform vec3 vent_monde;                // monde : direction * force (0..1), rafales comprises (monde.gd ; 0 sous terre)
uniform float vent_k = 1.0;                    // 0 : feu abrité (intérieurs, crypte, grotte)
uniform float pos_biais = 0.0;                 // recul vers la caméra (m)
uniform float base_cases = 4.5;
uniform float large = 1.0;                     // multiplicateur de largeur (feu de camp : 1,25)
uniform float braises = 0.0;                   // 0..1 : braises détachées en plus
uniform float cuit = 0.0;                      // 0..1 : tons plus rouges (flamme enfermée)
const float K_CX = 0.9;
const float K_CY = 1.62;

varying flat float v_cell;
varying flat vec2 v_tip;
varying flat vec2 v_dim;
varying flat float v_ph;
varying flat float v_cuit;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	bool multi = INSTANCE_CUSTOM.y > 0.0;
	float sc = multi ? INSTANCE_CUSTOM.y : echelle_u;
	float ph = multi ? INSTANCE_CUSTOM.x : phase_u;
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 vp = VIEWPORT_SIZE;
	float k = vp.y / 270.0;
	vec3 vo = (VIEW_MATRIX * vec4(o, 1.0)).xyz;
	vec4 c0 = PROJECTION_MATRIX * vec4(vo, 1.0);
	float w = max(c0.w, 0.0001);
	float pxm = abs(PROJECTION_MATRIX[1][1]) * vp.y * 0.5 / w;
	float cell = floor(clamp(cell_m * sc * pxm, cell_min_px * k, cell_max_px * k) + 0.5);
	vec2 p0 = (c0.xy / w * 0.5 + 0.5) * vp;
	p0 = floor(p0 + 0.5);
	float sy = PROJECTION_MATRIX[1][1] < 0.0 ? -1.0 : 1.0;
	// vent : rafales lentes, projetées sur la droite écran (la flamme se couche du côté où le vent souffle)
	float lat = dot(vent_monde, normalize(INV_VIEW_MATRIX[0].xyz)) * vent_k;
	float dx = lat * 3.4 + sin(TIME * 2.3 + ph * 4.0) * 0.5;
	float CX = ceil(cases_h * K_CX * max(large, 1.0));
	float CY = ceil(cases_h * K_CY);
	CX += mod(CX, 2.0);
	v_cell = cell;
	v_tip = vec2(clamp(dx, -CX * 0.4, CX * 0.4), cases_h * (1.0 - 0.08 * abs(lat)));
	v_dim = vec2(CX, CY);
	v_ph = ph;
	v_cuit = multi ? INSTANCE_CUSTOM.z : cuit;
	vec2 p = p0 + vec2(VERTEX.x * CX * cell, sy * VERTEX.y * CY * cell);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec4 cb = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(o + normalize(cam - o + vec3(0.0, 0.0001, 0.0)) * pos_biais, 1.0));
	POSITION = vec4((p / vp * 2.0 - 1.0) * w, cb.z / max(cb.w, 0.0001) * w, w);
}

void fragment() {
	float f = floor(TIME * 12.0 + v_ph * 7.0);
	float phase = v_ph;
	float CX = v_dim.x;
	float CY = v_dim.y;
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
	float larg = 4.4 * large * pow(max(1.0 - t, 0.0), 0.75) * (0.9 + 0.22 * h21(vec2(cy, floor(f * 0.5))));
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
		float seuil = 0.86 - 0.22 * braises - 0.05 * a;
		detache = tt > 0.0 && tt < 0.45 + 0.5 * braises && dx < 1.6 + 2.0 * braises && n1 > seuil && n2 > 0.35;
	}
	if (!dedans && !detache) {
		discard;
	}
	float d = dx / max(larg, 0.5);
	float s = d * 0.9 + t * 0.85 + (n2 - 0.5) * 0.3 + v_cuit * 0.22;
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
