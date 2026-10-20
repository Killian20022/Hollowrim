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
uniform vec2 sol_proche = vec2(4.0, 8.0);
instance uniform float eclair = 0.0; // flash quand l'objet est touché (par instance)

varying vec3 uv_aff;
varying vec2 uv_macro;
varying vec2 pos_monde;  // position monde (interpolation normale, non affine)
varying vec3 normale_monde;

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
	vec2 j2 = vec2(bruit_sol(p * 7.0 + 5.3), bruit_sol(p * 7.0 + 17.9)) - 0.5;
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

void vertex() {
	VERTEX += NORMAL * gonfle;
	vec2 uv = UV * uv_echelle;
	if (uv_monde) {
		uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * monde_echelle;
	}
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	normale_monde = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	uv_macro = pos_monde * 0.03;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Pas d'accroche dans la passe d'ombre (projection orthographique) : sinon acné.
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
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
	vec2 zone_min = traces_rect.xy - 1.0;
	vec2 zone_max = traces_rect.xy + traces_rect.zw / 32.0 + 1.0;
	if (sol_carte && all(greaterThan(pos_monde, zone_min)) && all(lessThan(pos_monde, zone_max))) {
		// zone témoin : tuiles pixel art 16 texels/m, UV monde non affines, alignées sur une grille
		// de texels de sol (q). Hors du rectangle de la zone, rien n'est lu (coût nul).
		vec2 q = floor(pos_monde * 16.0);
		vec2 dq = max(abs(ddx_sol), abs(ddy_sol)) * 16.0;
		float texels_par_px = max(dq.x, dq.y);
		// près du joueur : texels de 1/32 m ; le fondu est tramé par texel de 1/16 m (bruit lisse + grain)
		float dist = length(VERTEX);
		float seuil_fin = 0.6 * bruit_sol(q * 0.21) + 0.4 * hash_sol(q + 71.3);
		float fin = (smoothstep(sol_proche.y, sol_proche.x, dist) > seuil_fin) ? 1.0 : 0.0;
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
			int n0 = niveau_de(carte_au(pc + vec2(pas, 0.0), fin));
			int n1 = niveau_de(carte_au(pc - vec2(pas, 0.0), fin));
			int n2 = niveau_de(carte_au(pc + vec2(0.0, pas), fin));
			int n3 = niveau_de(carte_au(pc - vec2(0.0, pas), fin));
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
			ton = ton + clamp(creux + bord + trace, -2, 1);
			if (rampe == 0) ton = max(ton, 1);  // neige : le ton 0 reste un accent (bible §2)
			if (givre) {
				ton = 3;
				rampe = 0;
			}
			// détails épars (période 5 m) selon la densité de la carte
			vec3 d;
			if (fin > 0.5) {
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
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = emission + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}
