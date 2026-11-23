// Lumière intérieure v2 (2026-11-23) : rai de soleil / de lune / de jour qui entre par une ouverture (fenêtre, volets, porte,
// trou à fumée), rendu comme un VOLUME (pas des panneaux) :
// - le maillage est un cube unité [0,1]³ ; la matrice du nœud est CISAILLÉE : X = largeur de l'ouverture, Y = sa hauteur,
//   Z = direction de la lumière × longueur du rai. Dans ce repère le rai est une boîte alignée : intersection exacte du rayon de
//   vue (méthode des dalles), coupée par la PROFONDEUR de la scène (meubles, sol, murs : le rai s'arrête où il touche) ;
// - densité intégrée sur 7 échantillons (décalage de bruit d'écran par pixel, jamais de Bayer) : motif de l'ouverture
//   (meneau en croix, interstices des volets), bords adoucis, décroissance le long du rai, volutes de poussière lentes ;
// - TACHE au sol/au mur : si la surface vue est dans la boîte, elle reçoit la lumière du rai (motif net de l'ouverture, ombres
//   des montants), multipliée par la couleur de la surface (lecture de l'écran) : la tache garde le grain des planches ;
// - poussière en suspension : grains de la taille d'un pixel posés sur 4 tranches fixes du volume (parallaxe juste), qui
//   dérivent lentement et scintillent quand ils traversent la lumière.
// Dessiné une seule fois par pixel : seules les faces de SORTIE de la boîte comptent (test géométrique, robuste au cisaillement).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

uniform sampler2D tex_profondeur : hint_depth_texture, filter_nearest;
uniform sampler2D tex_ecran : hint_screen_texture, filter_nearest;
uniform float densite = 0.075;          // voile du volume par mètre traversé
uniform float tache = 1.4;             // force de la tache au sol (× couleur de la surface)
uniform float grains = 0.5;            // force des grains de poussière
instance uniform vec3 couleur = vec3(1.0, 0.9, 0.7);
instance uniform float force = 0.0;     // 0 = éteint
instance uniform float voile_k = 1.0;   // part du volume (le ciel diffus : surtout une tache, peu de rai)
instance uniform int motif = 0;         // 0 ouvert (porte, trou), 1 fenêtre à meneau en croix, 2 volets de planches (interstices)
instance uniform vec3 dims = vec3(1.0, 1.0, 4.0);   // largeur, hauteur de l'ouverture, longueur du rai (m)

varying vec3 cam_l;
varying vec3 pos_l;
varying vec3 pos_w;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float bruit3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// transmission de l'ouverture au point (u, v) de son plan : 1 = lumière, 0 = montant / planche
float masque(vec2 uv) {
	if (motif == 1) {
		float mx = abs(uv.x - 0.5) * dims.x;            // meneau vertical (4,5 cm de demi-largeur)
		float my = abs(uv.y - 0.56) * dims.y;           // traverse
		return step(0.035, mx) * step(0.03, my);
	} else if (motif == 2) {
		float k = uv.x * 4.0;                           // 4 planches : 3 joints + jours le long des montants
		float joint = abs(fract(k + 0.5) - 0.5) / 4.0 * dims.x;
		float fente = 1.0 - step(0.012, joint);
		float haut = 1.0 - step(0.018, (1.0 - uv.y) * dims.y);   // jour sous le linteau
		return max(fente * step(0.08, uv.y), haut);
	}
	return 1.0;
}

// bords adoucis (pénombre de quelques cm) et décroissance le long du rai
float profil(vec3 p) {
	vec2 b = min(p.xy, 1.0 - p.xy) * dims.xy;
	vec2 doux = max(vec2(0.05), dims.xy * 0.16);
	float bord = smoothstep(vec2(0.0), doux, b).x * smoothstep(vec2(0.0), doux, b).y;
	float z = p.z * dims.z;
	float entree = smoothstep(0.0, 0.25, z);
	float fin = 1.0 - smoothstep(0.7, 1.0, p.z);
	return bord * entree * fin * (0.35 + 0.65 * exp(-z * 0.32));
}

void vertex() {
	cam_l = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	pos_l = VERTEX;
	pos_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (force <= 0.001) {
		discard;
	}
	vec3 ro = cam_l;
	vec3 rd = pos_l - cam_l;              // s = 0 à la caméra, s = 1 au fragment
	vec3 inv = 1.0 / (abs(rd) + 1e-6) * sign(rd + 1e-7);
	vec3 t0 = -ro * inv;
	vec3 t1 = (1.0 - ro) * inv;
	vec3 tn = min(t0, t1);
	vec3 tf = max(t0, t1);
	float sa = max(max(tn.x, tn.y), max(tn.z, 0.0));
	float sb = min(min(tf.x, tf.y), tf.z);
	if (sb < 0.995) {
		discard;                          // face d'entrée : le volume est compté une seule fois, à la face de sortie
	}
	float prof_frag = -VERTEX.z;
	float zs = texture(tex_profondeur, SCREEN_UV).x;
	vec4 vs = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zs, 1.0);
	float prof_scene = -vs.z / vs.w;
	float s_scene = prof_scene / max(prof_frag, 1e-4);
	float se = min(sb, s_scene);
	float lg = length(VERTEX);            // distance caméra → fragment (m)
	vec3 cw = CAMERA_POSITION_WORLD;
	float voile = 0.0;
	if (se > sa) {
		// décalage par pixel : bruit à gradient entrelacé (bruit, pas de grille de Bayer)
		float j = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		const int N = 12;
		for (int i = 0; i < N; i++) {
			float s = mix(sa, se, (float(i) + j) / float(N));
			vec3 p = ro + rd * s;
			float proche = smoothstep(0.5, 2.4, s * lg);   // dans le rai, pas d'écran de brume collé à l'œil
			voile += masque(p.xy) * profil(p) * proche;
		}
		// volutes de poussière : une valeur de bruit au milieu du segment (lente)
		vec3 wm = mix(cw, pos_w, (sa + se) * 0.5);
		float vol = 0.55 + 0.9 * bruit3(wm * 1.4 + vec3(0.0, TIME * 0.04, TIME * 0.025));
		voile *= (se - sa) * lg / float(N) * densite * vol * voile_k;
	}
	// tache : la surface vue est dans le rai
	float t = 0.0;
	vec3 surf = vec3(0.0);
	if (s_scene > sa && s_scene < sb) {
		vec3 ps = ro + rd * s_scene;
		t = masque(ps.xy) * profil(ps) * tache;
		surf = texture(tex_ecran, SCREEN_UV).rgb;
	}
	// grains de poussière : 4 tranches fixes du volume (x = 1/8, 3/8, 5/8, 7/8), cases de 7 cm sur la tranche
	float g = 0.0;
	if (se > sa) {
		for (int k = 0; k < 4; k++) {
			float xk = (float(k) + 0.5) / 4.0;
			float s = (xk - ro.x) * inv.x;
			if (s > sa && s < se) {
				vec3 p = ro + rd * s;
				vec2 q = vec2(p.y * dims.y, p.z * dims.z) / 0.07;
				q.x += TIME * (0.06 + 0.03 * float(k));          // lente descente
				vec2 c = floor(q);
				float hc = h21(c + float(k) * 17.3);
				if (hc > 0.93) {
					vec2 centre = c + vec2(h21(c + 3.1), h21(c + 7.7)) * 0.6 + 0.2;
					centre.y += 0.25 * sin(TIME * 0.4 + hc * 40.0);
					float d = length((q - centre) * 0.07);
					float r = 0.0026 * s * lg + 0.001;                  // ≈ un pixel à toute distance
					float sc = 0.5 + 0.5 * sin(TIME * (1.5 + 3.0 * hc) + hc * 60.0);
					g += step(d, r) * sc * sc * masque(p.xy) * profil(p) * smoothstep(0.4, 1.2, s * lg);
				}
			}
		}
	}
	vec3 col = couleur * force;
	vec3 sortie = col * (voile + g * grains) + surf * col * t;
	sortie += (h21(FRAGCOORD.xy * 1.37) - 0.5) / 255.0;     // grain 32 bits contre les paliers du dégradé
	ALBEDO = max(sortie, vec3(0.0));
	ALPHA = 1.0;
}
