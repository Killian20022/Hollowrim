// Pierre, bois, fer de la crypte (lot 7a, 2e passe). Dérivé de ps1.gdshader, réglé pour ne PAS fatiguer l'œil :
// - texels nets avec mipmaps « nearest » (pas de scintillement au loin), UV fournis par le maillage en
//   mètres (densité de texels uniforme) ;
// - mapping perspective correct (affine = 0 : les grands murs ne se tordent plus) ;
// - accroche des sommets à la grille d'écran seulement au pixel du rendu (aucun tremblement visible) ;
// - RELIEF : une carte de pentes (tex_nm, tirée de la carte de hauteur de la texture) perturbe la normale dans un repère
//   tangent déduit de l'axe dominant de la face (comme les UV du maillage) : la torche, en lumière rasante, sculpte les
//   joints creux, les biseaux, les dalles inégales et les gravures, sans tangentes ni sommets en plus ;
// - une occlusion de pied de mur en dégradé (le reste, coins, plafond, bord des sols, est cuit dans la couleur des sommets).
// - C1 matières (2026-10-28) : `saturation` (bois moins orange) ; variante BRILLANTE (fer, lame, or, os, givre) : le code de ce fichier
//   avec « specular_schlick_ggx » et « #define BRILLANT » à la place de specular_disabled (CrypteDecor.shader_brillant : un seul Shader de plus, partagé, aucun matériau dupliqué) ;
//   elle remplace l'éclairage direct par light() : Lambert identique + reflet NET (Blinn-Phong seuillé, une tache de quelques pixels,
//   pas de dégradé) + un lustre doux. La pierre et le bois gardent la variante sans light() (coût inchangé).
// - C3 murs (2026-10-28) : GRAIN PROCHE (surfaces à relief seulement) : bruit de valeur à 256 cellules/m (le double des textures de
//   pierre, 128 t/m) dans le plan de la face, +-1 ton (x 0,88 / x 1,12, une cellule sur deux neutre), qui casse les texels de 6-10 px
//   vus à bout de bras ; fondu par la TAILLE À L'ÉCRAN d'une cellule (absent sous 1,5 px : aucun scintillement, rien en vue rasante)
//   et par la distance (plein à 0,5 m, nul à 1,5 m). Bruit seulement (hachage entier par cellule), jamais de tramage ordonné.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_nm : filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float grille = 270.0;        // 0 = pas d'accroche ; 270 = un pixel du rendu (exprimé pour 270 lignes, mis à la hauteur interne)
uniform float y0 = -140.0;           // sol de la crypte (m, monde)
uniform float crasse = 1.0;          // 0 = sans occlusion de pied de mur
uniform float relief = 0.0;          // 0 = pas de carte de pentes
uniform vec3 emission : source_color = vec3(0.0);
uniform float decoupe = 0.0;         // > 0 : découpe alpha (toiles), double face utile
uniform float ambiant = 1.0;         // < 1 : n'assombrit QUE la lumière ambiante (sortie AO) ; torches et braseros intacts
// C4b : lueur d'hémisphère sans lumière (statues) : froide vers le haut, tiède vers le bas, x albédo ; 0 = inactive
uniform vec3 lueur_haut = vec3(0.0);
uniform vec3 lueur_bas = vec3(0.0);
instance uniform float eclair = 0.0;
// C1 matières : 1 = couleur inchangée ; < 1 rapproche la couleur de sa luminance (bois de la crypte moins orange)
uniform float saturation = 1.0;
// C1 matières, variante BRILLANT seulement (sans effet ailleurs) : reflet net (brillance, durete = exposant, seuil de la tache),
// lustre = reflet doux large (fer patiné), couleur du reflet ; le reflet suit la clarté de l'albédo (creux et joints sombres : rien)
uniform float brillance = 0.0;
uniform float durete = 32.0;
uniform float seuil_reflet = 0.35;
uniform float lustre = 0.0;
uniform vec3 reflet : source_color = vec3(1.0);
// C3 murs : force du grain proche (0 = éteint) ; densité en cellules par mètre
uniform float grain_proche = 1.0;
uniform float grain_densite = 256.0;

varying vec3 pos_m;
varying vec3 n_m;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// pas d'accroche près du plan de la caméra (w petit ou négatif) : xy/w explose et le sommet part dans le décor (murs « disparus »)
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5 && clip.w > 0.6) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);  // grille exprimée pour 270 lignes : même pas en pixels à toute résolution
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	pos_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_m = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec4 t = texture(tex_base, UV);
	if (decoupe > 0.0 && t.a < decoupe) discard;
	vec3 c = t.rgb * COLOR.rgb * teinte.rgb;
	vec3 nw = normalize(n_m);
	if (grain_proche > 0.0 && relief > 0.0) {         // condition uniforme : les dérivées restent valides
		float dist = length(pos_m - CAMERA_POSITION_WORLD);
		vec3 an = abs(nw);
		vec2 q = an.y >= max(an.x, an.z) ? pos_m.xz : (an.x >= an.z ? pos_m.zy : pos_m.xy);
		vec2 g = q * grain_densite;
		float cpp = max(length(dFdx(g)), length(dFdy(g)));           // cellules par pixel
		float w = (1.0 - smoothstep(1.0 / 2.5, 1.0 / 1.5, cpp)) * (1.0 - smoothstep(0.5, 1.5, dist)) * grain_proche;
		uvec2 k = uvec2(ivec2(floor(g)) + ivec2(65536));
		uint h = (k.x * 1597334677u) ^ (k.y * 3812015801u);
		h = (h ^ (h >> 15u)) * 2246822519u;
		h ^= h >> 13u;
		uint v = h & 3u;                                             // 0, 1, 2, 3 -> -1, 0, 0, +1 ton
		c *= 1.0 + 0.12 * w * (v == 0u ? -1.0 : (v == 3u ? 1.0 : 0.0));
	}
	if (relief > 0.0) {
		vec2 s = (texture(tex_nm, UV).rg * 2.0 - 1.0) * relief;
		vec3 a = abs(nw);
		vec3 T = vec3(1.0, 0.0, 0.0);
		vec3 B = vec3(0.0, 0.0, 1.0);
		if (a.y < a.x || a.y < a.z) {
			B = vec3(0.0, -1.0, 0.0);
			if (a.x >= a.z) T = vec3(0.0, 0.0, 1.0);
		}
		vec3 wn = normalize(nw + s.x * T + s.y * B);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
	// sol sous le sommet : y0 pour les sommets blancs (alpha 1), plus bas de (1 - alpha) x 20 m pour les étages et les escaliers du donjon
	float h = pos_m.y - (y0 - (1.0 - COLOR.a) * 20.0);
	float mur = 1.0 - abs(nw.y);
	float pied = mix(0.5, 1.0, smoothstep(0.0, 1.15, h));
	c *= mix(1.0, pied, crasse * mur);
	if (saturation != 1.0) c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, saturation);
	c = mix(c, vec3(1.0, 0.85, 0.8), eclair);
	ALBEDO = c;
	vec3 nh = nw;
	if (relief > 0.0) nh = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float hemi = nh.y * 0.5 + 0.5;
	EMISSION = emission + c * mix(lueur_bas, lueur_haut, hemi * hemi);
	ROUGHNESS = 1.0;
#ifdef BRILLANT
	SPECULAR = 0.0;      // pas de reflet de l'ambiante (comme specular_disabled) : seul light() fait briller
#endif
	AO = ambiant;
	AO_LIGHT_AFFECT = 0.0;
}

#ifdef BRILLANT
void light() {
	float nl = max(dot(NORMAL, LIGHT), 0.0);
	vec3 l = ATTENUATION * LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += nl * l;                                  // = diffuse_lambert
	float nh = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
	float p = pow(nh, durete);
	float tache = smoothstep(seuil_reflet, seuil_reflet + 0.1, p);      // bord net : une tache, pas un dégradé
	float clair = smoothstep(0.004, 0.05, dot(ALBEDO, vec3(0.3, 0.59, 0.11)));      // albédo LINÉAIRE (fer sombre ≈ 0,05) : creux cuits éteints
	SPECULAR_LIGHT += reflet * ((brillance * tache + lustre * pow(nh, durete * 0.2)) * clair * step(0.001, nl)) * l;
}
#endif
