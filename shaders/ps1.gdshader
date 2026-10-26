// Matériau « PS1 » commun à tout le décor :
// sommets accrochés à une grille d'écran (tremblement), textures en mapping affine,
// texels nets. La neige (tex_neige) et la matière de base (tex_base) sont
// mélangées selon l'alpha de la couleur de sommet : 0 = neige, 1 = base.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_neige : source_color, filter_nearest, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform vec2 uv_echelle = vec2(1.0);
uniform bool uv_monde = false;      // terrain : UV tirés de la position monde
uniform float monde_echelle = 0.25;
uniform float grille = 135.0;       // lignes de la grille d'accroche (0 = pas de tremblement)
uniform float gonfle = 0.0;         // décalage des sommets le long de la normale (m) : négatif = sous-couche rentrée
uniform float affine = 1.0;         // 1 = déformation affine façon PS1
uniform vec3 emission : source_color = vec3(0.0);
uniform float saturation = 1.0;
// grandes variations du sol (congères, zones plus grises) pour casser la répétition
uniform sampler2D tex_macro : filter_linear, repeat_enable;
uniform float macro_force = 0.0;    // < 1 : couleurs ternies (morts-vivants…)
// sol écologique (terrain seulement, lots D et 3) : carte 960² RGBA8 à 0,25 m/texel
// R = matière × 16, G = relief (128 + h × 400 m), B = 128 (zone) | variante << 5 | détails << 3 | (creux + 4)
uniform bool sol_carte = false;
uniform sampler2D carte_sol : filter_nearest, repeat_disable;
uniform sampler2D carte_relief : filter_linear, repeat_disable;   // même image, lue en bilinéaire (G)
uniform vec3 carte_rect = vec3(-120.0, -120.0, 0.0041666667); // x0, z0, 1/taille
// tuiles pixel art 128² à 16 texels/m (SolTuiles) : index (ton, rampe) + couleurs avec mipmaps (lointain)
uniform sampler2DArray sol_index : filter_nearest;
uniform sampler2DArray sol_couleur : source_color, filter_nearest_mipmap;
uniform sampler2D sol_lut : source_color, filter_nearest;          // rampes de la bible (ligne = rampe)
uniform sampler2D sol_details : filter_nearest, repeat_enable;     // 80² : ton, rampe, classe
uniform sampler2D sol_traces : filter_nearest, repeat_disable;     // empreintes 1/32 m : décalage de ton + 128
uniform vec4 traces_rect = vec4(-58.0, -64.0, 992.0, 1088.0);      // x0, z0 (m), largeur, hauteur (texels)
uniform float relief_force = 2.0;
// proximité (lot 3, 2e passe) : tuiles agrandies ×2 (Scale2x + détail fin) à 32 texels/m près du joueur,
// fondu tramé par bruit entre PROCHE.x et PROCHE.y mètres de la caméra
uniform sampler2DArray sol_index2 : filter_nearest;
uniform sampler2D sol_details2 : filter_nearest, repeat_enable;   // 160² (Scale2x des détails)
uniform vec2 sol_proche = vec2(3.0, 11.0);
uniform int sol_debug = 0;   // diagnostic du sol (--sol-debug=N) : 1 = grilles 0,25 m / 1/16 m, 2 = décalage de ton, 3 = texels par pixel
instance uniform float eclair = 0.0; // flash quand l'objet est touché (par instance)
#include "res://shaders/neige_tient.gdshaderinc"

varying vec3 uv_aff;
varying vec2 uv_macro;
varying vec2 pos_monde;  // position monde (interpolation normale, non affine)
varying vec3 normale_monde;
varying vec3 pos_monde3; // position monde 3D (neige qui tient)
varying float peau;      // 1 = maillage animé par un squelette (personnages) : pas de neige posée

// niveau de chaque matière du sol (un bord se dessine entre niveaux différents : lèvre claire en haut,
// ombre en bas) : neige, piétinée, terre, aiguilles, mousse, roche, glace, croûte
const int NIVEAU[8] = int[8](3, 2, 0, 1, 1, 4, 0, 3);

float hash_sol(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float bruit_sol(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_sol(i), hash_sol(i + vec2(1.0, 0.0)), f.x),
		mix(hash_sol(i + vec2(0.0, 1.0)), hash_sol(i + vec2(1.0)), f.x), f.y);
}

// carte lue au centre `p` (m) d'un texel de sol, décalée par un bruit lisse + un grain de 2 texels :
// les limites entre matières deviennent des bords en amas irréguliers au lieu de carrés de 25 cm.
// `fin` = 1 près du joueur (texels de 1/32 m) : un second bruit plus fin découpe les bords à cette échelle.
vec4 carte_au(vec2 p, float fin) {
	vec2 j = vec2(bruit_sol(p * 2.24), bruit_sol(p * 2.24 + 31.7)) - 0.5;
	vec2 bloc = floor(p * mix(8.0, 16.0, fin));
	vec2 g = vec2(hash_sol(bloc), hash_sol(bloc + 9.1)) - 0.5;
	vec2 j2 = fin > 0.0 ? vec2(bruit_sol(p * 7.0 + 5.3), bruit_sol(p * 7.0 + 17.9)) - 0.5 : vec2(0.0);
	vec2 pp = p + j * 0.34 + g * mix(0.09, 0.05, fin) + j2 * 0.10 * fin;
	return texture(carte_sol, (pp - carte_rect.xy) * carte_rect.z);
}

int niveau_de(vec4 c) {
	int b = int(c.b * 255.0 + 0.5);
	if (b < 128) return 3;
	return NIVEAU[clamp(int(c.r * 255.0 + 0.5) >> 4, 0, 7)];
}

float relief_au(vec2 p) {
	return (texture(carte_relief, (p - carte_rect.xy) * carte_rect.z).g * 255.0 - 128.0) / 400.0;
}


// ---------------------------------------------------------------------------------------------
// SOL V2 (extérieurs v2, zone témoin seulement : `sol2_rect` = x0, z0, x1, z1 ; zéro = désactivé)
// Sol procédural ancré dans le monde, évalué au centre d'un texel dont la taille suit la distance
// (1/48 m près des pieds, jusqu'à 1/6 m ; ~1,6 pixel d'écran par texel, à toute résolution) :
// plus de gros carrés de 6 cm vus à 6 pixels. Neige à variations douces, terre, pierres de tailles
// variées, gravier, plaques de neige, aiguilles ; transitions par seuils bruités (pas de tramage Bayer).
// ---------------------------------------------------------------------------------------------
uniform vec4 sol2_rect = vec4(0.0);
uniform float sol2_fondu = 3.0;   // largeur (m) du fondu vers l'ancien rendu au bord du rectangle

vec4 s2_ind(vec4 c) {
	int b = int(c.b * 255.0 + 0.5);
	if (b < 128) return vec4(0.0);
	int m = clamp(int(c.r * 255.0 + 0.5) >> 4, 0, 7);
	return vec4(float(m == 1 || m == 2), float(m == 2), float(m == 3), float(m == 7));
}

// poids (bilinéaires sur la carte 0,25 m) : x chemin (piétinée + terre), y terre, z aiguilles, w croûte
vec4 s2_poids(vec2 p) {
	vec2 t = (p - carte_rect.xy) * carte_rect.z * float(textureSize(carte_sol, 0).x) - 0.5;
	ivec2 i0 = ivec2(floor(t));
	vec2 f = fract(t);
	vec4 a = s2_ind(texelFetch(carte_sol, i0, 0));
	vec4 b = s2_ind(texelFetch(carte_sol, i0 + ivec2(1, 0), 0));
	vec4 c = s2_ind(texelFetch(carte_sol, i0 + ivec2(0, 1), 0));
	vec4 d = s2_ind(texelFetch(carte_sol, i0 + ivec2(1, 1), 0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// poids bilinéaires (carte 0,25 m) des matières roche (x), mousse (y), glace (z)
vec3 s2_m3(vec4 c) {
	int m = int(c.r * 255.0 + 0.5) >> 4;
	return vec3(float(m == 5), float(m == 4), float(m == 6));
}
// les deux jeux de poids en une seule lecture des 4 texels (C1 : économie de 4 lectures par pixel)
void s2_carte4(vec2 p, out vec4 w, out vec3 rmg) {
	float n = float(textureSize(carte_sol, 0).x);
	vec2 t = (p - carte_rect.xy) * carte_rect.z * n - 0.5;
	ivec2 i0 = clamp(ivec2(floor(t)), ivec2(0), ivec2(int(n) - 2));
	vec2 f = clamp(t - vec2(i0), 0.0, 1.0);
	vec4 ca = texelFetch(carte_sol, i0, 0);
	vec4 cb = texelFetch(carte_sol, i0 + ivec2(1, 0), 0);
	vec4 cc = texelFetch(carte_sol, i0 + ivec2(0, 1), 0);
	vec4 cd = texelFetch(carte_sol, i0 + ivec2(1, 1), 0);
	w = mix(mix(s2_ind(ca), s2_ind(cb), f.x), mix(s2_ind(cc), s2_ind(cd), f.x), f.y);
	rmg = mix(mix(s2_m3(ca), s2_m3(cb), f.x), mix(s2_m3(cc), s2_m3(cd), f.x), f.y);
}
vec3 s2_rmg(vec2 p) {
	float n = float(textureSize(carte_sol, 0).x);
	vec2 t = (p - carte_rect.xy) * carte_rect.z * n - 0.5;
	ivec2 i0 = clamp(ivec2(floor(t)), ivec2(0), ivec2(int(n) - 2));
	vec2 f = clamp(t - vec2(i0), 0.0, 1.0);
	vec3 a = s2_m3(texelFetch(carte_sol, i0, 0));
	vec3 b = s2_m3(texelFetch(carte_sol, i0 + ivec2(1, 0), 0));
	vec3 c = s2_m3(texelFetch(carte_sol, i0 + ivec2(0, 1), 0));
	vec3 d = s2_m3(texelFetch(carte_sol, i0 + ivec2(1, 1), 0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float s2_fbm(vec2 p) {
	return 0.5 * bruit_sol(p) + 0.3 * bruit_sol(p * 2.03 + 7.1) + 0.2 * bruit_sol(p * 4.1 + 13.7);
}

// voronoï (3x3) à cellules de côté S : f1 / f2 en unités de cellule, id et centre (m) du plus proche
void s2_vor(vec2 p, float S, out float f1, out float f2, out vec2 cid, out vec2 ctr) {
	vec2 g = p / S;
	vec2 gi = floor(g);
	f1 = 1e9;
	f2 = 1e9;
	cid = gi;
	ctr = p;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = gi + vec2(float(i), float(j));
			vec2 q = c + vec2(0.18) + 0.64 * vec2(hash_sol(c), hash_sol(c + 19.7));
			float d = length(g - q);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				cid = c;
				ctr = q * S;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
}

float s2_terre(vec2 p) {
	vec4 w = s2_poids(p);
	return max(w.y, 0.62 * w.x) + (s2_fbm(p * 5.0 + 11.0) - 0.5) * 0.9 + (bruit_sol(p * 19.0) - 0.5) * 0.2;
}

// C1 : roche (dalles en strates, joints sombres, neige dans les replats), mousse (coussins, poches de neige), glace (lisse, reflets en bandes)
void s2_roche(vec2 p, out int ton, out int rampe, out int niv, out vec2 pente) {
	float f1;
	float f2;
	vec2 cid;
	vec2 ctr;
	float S = 0.9;
	// dalles irrégulières : maille déformée par un bruit (pas de losanges réguliers), étirée en strates
	vec2 q = p + 0.7 * vec2(bruit_sol(p * 0.9 + 41.0) - 0.5, bruit_sol(p * 0.9 + 57.0) - 0.5);
	q = vec2(q.x * 0.8 + q.y * 0.35, q.y * 1.25);
	s2_vor(q, S, f1, f2, cid, ctr);
	vec2 vv = (q - ctr) / (S * 0.55);
	float l = dot(vv, vec2(-0.7071, -0.7071));
	float bord = smoothstep(0.32, 0.55, f1);                                    // arrondi seulement près du bord de la dalle
	rampe = 2;
	niv = 4;
	float m = bruit_sol(p * 3.1 + float(int(hash_sol(cid) * 7.0)));                // grain de la pierre, propre à chaque dalle
	ton = 1 + int(hash_sol(cid + 3.3) * 1.8 + m * 1.6);
	if (bord > 0.5 && l > 0.25) ton += 1;                                        // lèvre éclairée
	else if (bord > 0.5 && l < -0.35) ton -= 1;                                  // lèvre à l'ombre
	if (bruit_sol(vec2(q.x * 1.4, q.y * 8.0) + 17.0) > 0.82) ton -= 1;          // strates
	if (hash_sol(floor(p * 24.0) + 77.0) > 0.95) ton += 1;                       // grain, lichens
	bool joint = (f2 - f1) < 0.06 + 0.04 * bruit_sol(p * 6.0);
	if (joint) ton = 0;
	float n = s2_fbm(p * 2.2 + 5.0);
	if (n > (joint ? 0.50 : 0.63) && (l > -0.35 || bord < 0.5)) {               // neige dans les replats et les joints
		rampe = 0;
		ton = joint ? 2 : (n > 0.73 ? 4 : 3);
		niv = 3;
	}
	ton = clamp(ton, 0, 5);
	pente = vv * 0.45 * bord;
}

void s2_mousse(vec2 p, out int ton, out int rampe, out int niv, out vec2 pente) {
	// herbes sèches et lichen sous la neige (vert éteint, pas d'aplat saturé), poches de neige
	pente = vec2(0.0);
	niv = 1;
	float m = s2_fbm(p * 4.0 + 2.0);
	rampe = 5;
	ton = 1 + int(m * 2.6);
	float h = hash_sol(floor(p * 24.0) + 12.0);
	if (s2_fbm(p * 7.0 + 60.0) > 0.58 || h < 0.10) {
		rampe = 4;                                                               // lichen gris-vert
		ton = 3 + int(h < 0.05);
	}
	if (s2_fbm(p * 3.2 + 40.0) + (bruit_sol(p * 15.0) - 0.5) * 0.25 > 0.52) {
		rampe = 0;
		ton = bruit_sol(p * 14.0) > 0.6 ? 4 : 3;
		niv = 3;
	}
	ton = clamp(ton, 0, 5);
}

void s2_glace(vec2 p, out int ton, out int rampe, out int niv, out vec2 pente) {
	pente = vec2(0.0);
	rampe = 1;
	niv = 3;
	ton = 2;
	if (bruit_sol(vec2(p.x * 0.9, p.y * 7.0) + 3.0) > 0.72) ton = 3;            // reflets en bandes
	float f1;
	float f2;
	vec2 cid;
	vec2 ctr;
	s2_vor(p, 1.4, f1, f2, cid, ctr);
	if ((f2 - f1) < 0.03) ton = 1;                                              // fissures fines
}

// matière du sol au centre de texel `p` : ton + rampe (SolTuiles), niveau (pour les lèvres/ombres), pente de pierre
// `tf` >= 0 : ton CONTINU de la neige (mélange de deux tons voisins de la rampe) ; < 0 : ton entier `ton`.
void s2_sol(vec2 p, float trace, out int ton, out int rampe, out int niv, out vec2 pente, out float terre_o, out float wt, out float tf) {
	terre_o = 0.0;
	wt = 0.0;
	tf = -1.0;
	// matière dominante : roche / mousse / glace pondérées en bilinéaire sur la carte 0,25 m, seuil bruité (bords organiques, pas de marches)
	vec4 w;
	vec3 rmg;
	s2_carte4(p, w, rmg);
	float rmax = max(rmg.x, max(rmg.y, rmg.z));
	float nb = rmax > 0.0 ? (s2_fbm(p * 2.3 + 3.0) - 0.5) * 0.55 + (bruit_sol(p * 9.0 + 1.0) - 0.5) * 0.18 : 0.0;
	if (rmg.x + nb > 0.5 && rmg.x >= rmg.y && rmg.x >= rmg.z) { s2_roche(p, ton, rampe, niv, pente); return; }
	if (rmg.y + nb > 0.5 && rmg.y >= rmg.z) { s2_mousse(p, ton, rampe, niv, pente); return; }
	if (rmg.z + nb * 0.6 > 0.5) { s2_glace(p, ton, rampe, niv, pente); return; }
	pente = vec2(0.0);
	float derive = s2_fbm(p * 0.8);
	float ondes = bruit_sol(vec2(p.x * 7.0, p.y * 1.8) + 9.0);   // rides allongées dans le sens du vent (+z)
	float v = 0.5 * derive + 0.3 * ondes + 0.2 * bruit_sol(p * 21.0 + 4.0);
	float tb = max(w.y, 0.62 * w.x);
	float terre = tb > 0.0 ? tb + (s2_fbm(p * 5.0 + 11.0) - 0.5) * 0.9 + (bruit_sol(p * 19.0) - 0.5) * 0.2 : -0.5;   // loin des chemins : pas de bruit à évaluer
	terre_o = terre;
	wt = max(w.y, w.x);
	if (terre > 0.5) {
		float prof = terre - 0.5;                       // 0 au bord, ~0,3 au cœur
		float m1 = s2_fbm(p * 6.0 + 3.7);
		rampe = 3;
		ton = clamp(2 + int(m1 * 2.6), 2, 4);
		niv = 0;
		bool pierre = false;
		float f1;
		float f2;
		vec2 cid;
		vec2 ctr;
		float S = 0.5;
		s2_vor(p, S, f1, f2, cid, ctr);
		float dens = 0.42 + 2.2 * prof;
		if (hash_sol(cid + 7.7) >= dens) {
			// pas de grosse pierre ici : petites pierres sur une maille plus fine
			S = 0.21;
			s2_vor(p, S, f1, f2, cid, ctr);
			dens = 0.30 + 2.0 * prof;
			if (hash_sol(cid + 13.1) >= dens) f1 = 9.0;
		}
		float R = 0.36 + 0.24 * hash_sol(cid + 2.2);
		if (f1 < R && (f2 - f1) > 0.09) {
			pierre = true;
			vec2 vv = (p - ctr) / (S * R);
			float l = dot(vv, vec2(-0.7071, -0.7071));
			rampe = 2;
			ton = 2 + int(hash_sol(cid + 4.4) * 2.4);
			if (l > 0.30) ton += 1;
			else if (l < -0.45) ton -= 1;
			ton = clamp(ton, 0, 4);
			niv = 4;
			pente = vv * clamp(f1 / R, 0.0, 1.0);
			// calotte de neige sur le dessus de certaines pierres
			if (hash_sol(cid + 9.9) < 0.20 && l > 0.05 && f1 < R * 0.7) {
				rampe = 0;
				ton = l > 0.35 ? 5 : 4;
			}
		}
		if (!pierre) {
			float hp = hash_sol(floor(p * 24.0) + 5.0);      // gravier : texels de 4 cm, par plaques
			float dg = 0.30 * smoothstep(0.30, 0.65, bruit_sol(p * 2.7 + 21.0));
			if (hp < dg) {
				rampe = 2;
				ton = 2 + int(hash_sol(floor(p * 24.0) + 8.0) * 3.0);
				niv = 1;
			} else if (s2_fbm(p * 9.0 + 30.0) > 0.70 + prof * 1.4) {
				rampe = 0;                                   // neige mince dans la terre
				ton = 3;
				niv = 2;
			}
		}
	} else {
		rampe = 0;
		niv = 3;
		// neige v3 (D/neige_murs) : plus de trois aplats 3/4/5 à seuils (taches « camouflage » de près) ; ton continu
		// entre 3,75 et 4,9 (le ton 3, bleu, reste aux creux, à la neige piétinée et aux ombres) + grain fin par texel
		// (bruit blanc de ±0,15 ton, pas de tramage ordonné) + bruit lisse moyen
		float grain = hash_sol(floor(p * 48.0) + 17.3) - 0.5;
		tf = 3.75 + 1.15 * smoothstep(0.28, 0.76, v) + grain * 0.3 + (bruit_sol(p * 9.0 + 2.0) - 0.5) * 0.3;
		ton = int(tf + 0.5);
		float piet = w.x > 0.0 ? w.x + (s2_fbm(p * 7.0 + 2.0) - 0.5) * 0.7 : 0.0;
		if (piet > 0.55) {                                   // neige piétinée : plus grise, rides cassées (continues aussi)
			tf = 2.55 + 0.9 * smoothstep(0.30, 0.80, 1.0 - ondes) + grain * 0.25;
			ton = int(tf + 0.5);
			niv = 2;
		} else if (terre > 0.36 && bruit_sol(p * 31.0) > 0.55) {
			rampe = 2;                                       // gravier qui perce la neige
			ton = 2 + int(bruit_sol(p * 13.0) * 2.0);
			niv = 1;
			tf = -1.0;
		}
		if (w.z > 0.2 && w.z + (s2_fbm(p * 8.0 + 1.0) - 0.5) * 0.7 > 0.55) {
			rampe = (bruit_sol(p * 17.0) > 0.78) ? 7 : 3;    // tapis d'aiguilles
			ton = rampe == 7 ? 2 : 1 + int(bruit_sol(p * 12.0 + 6.0) * 2.5);
			niv = 1;
			tf = -1.0;
		}
		if (tf >= 0.0 && niv == 3 && hash_sol(floor(p * 24.0) + 61.0) > 0.994) tf = 5.0;   // éclats isolés
		if (rampe == 0 && trace != 0.0) {
			ton += int(trace);
			tf += trace;
		}
	}
}

void vertex() {
	VERTEX += NORMAL * gonfle;
	vec2 uv = UV * uv_echelle;
	if (uv_monde) {
		uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * monde_echelle;
	}
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	normale_monde = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	pos_monde3 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	peau = step(0.001, BONE_WEIGHTS.x + BONE_WEIGHTS.y + BONE_WEIGHTS.z + BONE_WEIGHTS.w);
	uv_macro = pos_monde * 0.03;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Pas d'accroche dans la passe d'ombre (projection orthographique) : sinon acné.
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);  // grille exprimée pour 270 lignes : même pas en pixels à toute résolution
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	// UV multipliés par w puis redivisés au fragment = interpolation affine.
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(uv * w, w);
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec3 base = texture(tex_base, uv).rgb;
	vec3 neige = texture(tex_neige, uv).rgb;
	ALBEDO = mix(neige, base, step(0.5, COLOR.a)) * COLOR.rgb * teinte.rgb;
	float macro_sol = 1.0;
	// dérivées calculées hors de toute branche (textureGrad plus bas)
	vec2 ddx_sol = dFdx(pos_monde);
	vec2 ddy_sol = dFdy(pos_monde);
	vec2 zone_min = carte_rect.xy;   // C1 : la carte de sol couvre toute la carte (240 m)
	vec2 zone_max = carte_rect.xy + 1.0 / carte_rect.z;
	// sol v2 : dans le rectangle activé et assez près (texel < 0,10 m d'empreinte), fondu en bruit vers l'ancien rendu
	bool v2 = false;
	float pxm = sqrt(abs(ddx_sol.x * ddy_sol.y - ddx_sol.y * ddy_sol.x));
	if (sol_carte && sol2_rect.z > sol2_rect.x && all(greaterThan(pos_monde, sol2_rect.xy)) && all(lessThan(pos_monde, sol2_rect.zw))) {
		vec2 dr = min(pos_monde - sol2_rect.xy, sol2_rect.zw - pos_monde);
		float wz = smoothstep(0.0, sol2_fondu, min(dr.x, dr.y)) * (1.0 - smoothstep(0.085, 0.115, pxm));
		v2 = wz > hash_sol(floor(pos_monde * 24.0) + 3.1);
	}
	if (v2) {
		float lv = clamp(log2(max(pxm, 0.0001) * 1.6 * 48.0), 0.0, 3.0);
		vec2 q0 = floor(pos_monde * 48.0);
		float niveau_l = floor(lv) + (hash_sol(q0 + 41.7) < fract(lv) ? 1.0 : 0.0);
		float pas = exp2(min(niveau_l, 3.0)) / 48.0;
		vec2 pc = (floor(pos_monde / pas) + 0.5) * pas;
		// empreintes (carte à 1/32 m)
		float trace = 0.0;
		ivec2 tq = ivec2(floor((pc - traces_rect.xy) * 32.0));
		if (tq.x >= 0 && tq.y >= 0 && float(tq.x) < traces_rect.z && float(tq.y) < traces_rect.w) {
			trace = clamp(float(int(texelFetch(sol_traces, tq, 0).r * 255.0 + 0.5) - 128), -2.0, 1.0);
		}
		int ton;
		int rampe;
		int niv;
		vec2 pente;
		float terre_c;
		float wt;
		float tf;
		s2_sol(pc, trace, ton, rampe, niv, pente, terre_c, wt, tf);
		// lèvre claire / ombre aux limites terre ↔ neige (champ de terre évalué au texel voisin en haut à gauche)
		// C1 : voisin évalué seulement près d'un chemin (poids de terre non nul) ; roche/mousse/glace : pas de lèvre
		int lev = 0;
		bool terre_moi = terre_c > 0.5;
		bool terre_ul = wt > 0.0 ? s2_terre(pc + vec2(-pas, -pas)) > 0.5 : false;
		if (!terre_moi && terre_ul && rampe == 0) lev = 1;
		else if (terre_moi && !terre_ul && niv <= 1) lev = -1;
		ton = ton + lev;
		if (rampe == 0) ton = max(ton, 1);
		ton = clamp(ton, 0, 7);
		vec3 sol = texelFetch(sol_lut, ivec2(ton, rampe), 0).rgb;
		vec2 congere = vec2(0.0);
		if (tf >= 0.0) {    // neige à ton continu : mélange des deux tons voisins (pas d'aplat à bord net)
			tf = clamp(tf + float(lev), 1.0, 5.0);
			int t0 = int(tf);
			sol = mix(texelFetch(sol_lut, ivec2(t0, 0), 0).rgb, texelFetch(sol_lut, ivec2(min(t0 + 1, 5), 0), 0).rgb, tf - float(t0));
			// congères douces : petites ondulations allongées dans le sens du vent (+z), pente seulement (éclairage)
			vec2 cg = vec2(pc.x * 0.6, pc.y * 1.7);
			float c0 = bruit_sol(cg + 3.0) + 0.35 * bruit_sol(cg * 2.6 + 8.0);
			float cx = bruit_sol(cg + vec2(0.06, 0.0) + 3.0) + 0.35 * bruit_sol((cg + vec2(0.06, 0.0)) * 2.6 + 8.0);
			float cz = bruit_sol(cg + vec2(0.0, 0.17) + 3.0) + 0.35 * bruit_sol((cg + vec2(0.0, 0.17)) * 2.6 + 8.0);
			congere = vec2(cx - c0, cz - c0) * 1.6;
		}
		if (rampe == 0) {   // variation douce et subtile de la neige : plaques plus froides / plus chaudes
			float c = bruit_sol(pc * 0.35 + 5.0);
			sol *= mix(vec3(0.965, 0.985, 1.03), vec3(1.03, 1.0, 0.97), c);
		}
		ALBEDO = sol * teinte.rgb;
		macro_sol = 0.5;
		float h0 = relief_au(pc);
		float gx = (relief_au(pc + vec2(pas, 0.0)) - h0) / pas;
		float gz = (relief_au(pc + vec2(0.0, pas)) - h0) / pas;
		vec3 n = normalize(normalize(normale_monde) + vec3(-gx, 0.0, -gz) * relief_force + vec3(pente.x, 0.0, pente.y) * 0.45 - vec3(congere.x, 0.0, congere.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
	if (!v2 && sol_carte && all(greaterThan(pos_monde, zone_min)) && all(lessThan(pos_monde, zone_max))) {
		// zone témoin : tuiles pixel art 16 texels/m, UV monde non affines, alignées sur une grille
		// de texels de sol (q). Hors du rectangle de la zone, rien n'est lu (coût nul).
		vec2 q = floor(pos_monde * 16.0);
		vec2 dq = max(abs(ddx_sol), abs(ddy_sol)) * 16.0;
		float texels_par_px = max(dq.x, dq.y);
		// près du joueur : texels de 1/32 m ; le fondu est tramé par texel de 1/16 m (bruit lisse + grain)
		float dist = length(VERTEX);
		float fin = 0.0;
		if (dist < sol_proche.y) {   // au-delà, jamais de texels fins : bruit du seuil inutile
			float seuil_fin = 0.3 * bruit_sol(q * 0.07) + 0.25 * bruit_sol(q * 0.21) + 0.45 * hash_sol(q + 71.3);
			fin = (smoothstep(sol_proche.y, sol_proche.x, dist) > seuil_fin) ? 1.0 : 0.0;
		}
		float pas = fin > 0.5 ? 1.0 / 32.0 : 1.0 / 16.0;
		vec2 qf = floor(pos_monde / pas);
		vec2 pc = (qf + 0.5) * pas;
		vec4 c = carte_au(pc, fin);
		int b = int(c.b * 255.0 + 0.5);
		int m = clamp(int(c.r * 255.0 + 0.5) >> 4, 0, 7);
		int couche = m * 2 + ((b >> 5) & 1);
		vec3 loin = textureGrad(sol_couleur, vec3(pos_monde * 0.125, float(couche)), ddx_sol * 0.125, ddy_sol * 0.125).rgb;
		if (b >= 128) {
			int ton;
			int rampe;
			vec2 ir;
			if (fin > 0.5) {
				ir = texelFetch(sol_index2, ivec3(ivec2(mod(qf, 256.0)), couche), 0).rg;
			} else {
				ir = texelFetch(sol_index, ivec3(ivec2(mod(q, 128.0)), couche), 0).rg;
			}
			ton = int(ir.x * 255.0 + 0.5);
			rampe = int(ir.y * 255.0 + 0.5);
			int creux = (b & 7) - 4;
			// bord dessiné : lèvre claire côté haut, ombre côté bas (4 voisins, au pas courant)
			int nv = NIVEAU[m];
			// C1 : au loin (texel < 1,6 px, couleurs moyennées par mipmaps), ni voisins ni détails : seul `loin` est affiché
			bool pres = texels_par_px < 1.6;
			int n0 = pres ? niveau_de(carte_au(pc + vec2(pas, 0.0), fin)) : nv;
			int n1 = pres ? niveau_de(carte_au(pc - vec2(pas, 0.0), fin)) : nv;
			int n2 = pres ? niveau_de(carte_au(pc + vec2(0.0, pas), fin)) : nv;
			int n3 = pres ? niveau_de(carte_au(pc - vec2(0.0, pas), fin)) : nv;
			int plus_haut = int(n0 > nv) + int(n1 > nv) + int(n2 > nv) + int(n3 > nv);
			int plus_bas = int(n0 < nv) + int(n1 < nv) + int(n2 < nv) + int(n3 < nv);
			int bord = plus_haut > 0 ? -1 : (plus_bas > 0 ? 1 : 0);
			// glace : bord givré (neige claire) au lieu d'une ombre
			bool givre = m == 6 && plus_haut > 0;
			// empreintes (pas, pattes) : carte à 1/32 m
			ivec2 tq = ivec2(floor((pc - traces_rect.xy) * 32.0));
			int trace = 0;
			if (tq.x >= 0 && tq.y >= 0 && float(tq.x) < traces_rect.z && float(tq.y) < traces_rect.w) {
				trace = int(texelFetch(sol_traces, tq, 0).r * 255.0 + 0.5) - 128;
			}
			if (m == 5 || m == 6) trace = 0;
			// décalages cumulés bornés : jamais plus de 2 tons plus sombre (pas de trou noir)
			if (m == 6) {
				creux = 0;  // glace : surface lisse, ni creux sombres ni ombre de bord (le givre est dessiné)
				bord = max(bord, 0);
			}
			ton = ton + clamp(creux + bord + trace, -2, 1);
			if (rampe == 0) ton = max(ton, 1);  // neige : le ton 0 reste un accent (bible §2)
			if (givre) {
				ton = 3;
				rampe = 0;
			}
			// détails épars (période 5 m) selon la densité de la carte
			vec3 d = vec3(0.0);
			if (!pres) {
			} else if (fin > 0.5) {
				d = texelFetch(sol_details2, ivec2(mod(qf + vec2(26.0, 114.0), 160.0)), 0).rgb;
			} else {
				d = texelFetch(sol_details, ivec2(mod(q + vec2(13.0, 57.0), 80.0)), 0).rgb;
			}
			int classe = int(d.b * 255.0 + 0.5);
			int dens = (b >> 3) & 3;
			bool neigeuse = m == 0 || m == 7;
			bool poser = false;
			if (classe == 1) poser = neigeuse && trace == 0 && creux >= 0;
			else if (classe == 2) poser = dens >= 1 && m != 5 && m != 6;
			else if (classe == 3) poser = dens >= 2 && m != 5 && m != 6 && m != 2;
			else if (classe == 4) poser = dens == 3 && (neigeuse || m == 4 || m == 2);
			if (poser && trace == 0 && !givre) {
				ton = int(d.r * 255.0 + 0.5) + (classe == 1 ? 0 : min(creux, 0));
				rampe = int(d.g * 255.0 + 0.5);
			}
			vec3 proche = texelFetch(sol_lut, ivec2(clamp(ton, 0, 7), rampe), 0).rgb;
			// au loin (un texel de sol plus petit qu'un demi-pixel) : couleurs moyennées (mipmaps)
			vec3 sol = texels_par_px < 1.6 ? proche : loin * (1.0 + 0.1 * float(creux));
			ALBEDO = sol * teinte.rgb;
			if (sol_debug == 1) {
				float px = max(max(abs(ddx_sol.x), abs(ddx_sol.y)), max(abs(ddy_sol.x), abs(ddy_sol.y)));
				vec2 f4 = fract(pos_monde * 4.0);
				vec2 f16 = fract(pos_monde * 16.0);
				if (min(f4.x, f4.y) < px * 4.0 * 1.2) ALBEDO = vec3(1.0, 0.0, 0.0);
				else if (texels_par_px < 1.0 && min(f16.x, f16.y) < px * 16.0 * 1.2) ALBEDO = mix(ALBEDO, vec3(0.0, 0.8, 0.9), 0.7);
			} else if (sol_debug == 2) {
				float dt = float(clamp(creux + bord + trace, -2, 1));
				ALBEDO = vec3(0.5 + 0.25 * dt) * vec3(dt < 0.0 ? 0.6 : 1.0, 0.5, dt > 0.0 ? 0.6 : 1.0);
				if (dt == 0.0) ALBEDO = vec3(0.5);
			} else if (sol_debug == 3) {
				ALBEDO = vec3(clamp(texels_par_px / 4.0, 0.0, 1.0), clamp(1.0 - texels_par_px / 4.0, 0.0, 1.0), fin);
			}
			macro_sol = 0.5;
			// relief fin (congères, cuvettes au pied des arbres, bosses) : normale perturbée,
			// constante par texel de sol (facettes en pixels)
			vec2 qc = pc;
			float e = pas;
			float h0 = relief_au(qc);
			float gx = (relief_au(qc + vec2(e, 0.0)) - h0) / e;
			float gz = (relief_au(qc + vec2(0.0, e)) - h0) / e;
			vec3 n = normalize(normalize(normale_monde) + vec3(-gx, 0.0, -gz) * relief_force);
			NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		}
	}
	if (macro_force > 0.0) {
		float m = texture(tex_macro, uv_macro).r;
		ALBEDO *= mix(1.0, 0.8 + m * 0.36, macro_force * macro_sol);
	}
	ALBEDO = mix(vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11))), ALBEDO, saturation);
	// neige qui tient (objets dehors) : jamais sur le terrain (sol validé), ni sur les parties déjà neigées, ni sur les personnages
	if (!sol_carte && !uv_monde && COLOR.a >= 0.5 && peau < 0.5) {
		vec3 nm = normalize(normale_monde);
		float couv = nt_couverture(nm, pos_monde3, length(VERTEX));
		if (couv > 0.0) {
			vec2 tq = nt_texel(pos_monde3, nm);
			vec3 nc = texture(tex_neige, (tq + 0.5) / vec2(textureSize(tex_neige, 0))).rgb;
			ALBEDO = nt_appliquer(ALBEDO, nc, couv);
		}
	}
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = emission + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}
