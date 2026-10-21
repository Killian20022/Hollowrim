// Troncs et grosses branches (lot 2, « réalisme 32 bits ») : dérivé de ps1 (même accroche des sommets,
// même mapping affine), mais :
//  - écorce à 32 texels/m (tuile 64² = 2 m) près du joueur, fondu tramé par bruit vers le niveau 1 des
//    mipmaps (16 texels/m) au loin ; mipmaps nearest au-delà ;
//  - deux tuiles : `tex_haut` (fût) et `tex_pied` (écorce crevassée du bas), mélangées par UV2.x avec un
//    seuil bruité (transition irrégulière) ;
//  - alpha de la texture = hauteur : relief par normale (constante par texel), mousse (UV2.y, côté nord, sur
//    le haut des plaques) et neige plaquée (alpha de sommet < 1) qui s'accroche aux crêtes ;
//  - couleur de sommet = occlusion peinte (pied, sous la couronne).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_haut : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_pied : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float grille = 135.0;
uniform float affine = 1.0;
uniform float saturation = 1.0;
uniform vec2 proche = vec2(6.0, 16.0);   // m : fondu 32 -> 16 texels/m
uniform float relief = 1.4;
uniform float mousse_force = 1.0;

varying vec3 uv_aff;
varying vec2 aux;   // UV2 : x = poids de l'écorce du pied, y = poids de mousse

const vec3 MOUSSE[4] = vec3[4](vec3(0.05, 0.062, 0.032), vec3(0.08, 0.098, 0.04), vec3(0.115, 0.135, 0.058), vec3(0.16, 0.18, 0.085));
const vec3 NEIGE[4] = vec3[4](vec3(0.15, 0.2, 0.36), vec3(0.3, 0.38, 0.58), vec3(0.58, 0.66, 0.84), vec3(0.88, 0.9, 0.95));

float hs(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);  // grille exprimée pour 270 lignes : même pas en pixels à toute résolution
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(UV * w, w);
	aux = UV2;
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec2 tp = uv * 64.0;
	vec2 ix = floor(tp);
	vec2 dx = dFdx(tp);
	vec2 dy = dFdy(tp);
	float lod_nat = floor(max(0.0, 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-6))) + 0.5);
	float dist = length(VERTEX);
	float seuil = 0.25 * bruit(ix * 0.09) + 0.2 * bruit(ix * 0.31) + 0.55 * hs(ix + 17.0);
	float loin = smoothstep(proche.x, proche.y, dist) > seuil ? 1.0 : 0.0;
	float lod = max(lod_nat, loin);
	float pas = exp2(lod) / 64.0;
	// écorce du pied : seuil bruité sur le poids UV2.x
	float bp = (aux.x + (bruit(ix * 0.16) - 0.5) * 0.7 + (hs(floor(tp / exp2(lod)) + 3.0) - 0.5) * 0.25) > 0.5 ? 1.0 : 0.0;
	vec4 t0 = textureLod(tex_haut, uv, lod);
	vec4 t1 = textureLod(tex_pied, uv, lod);
	vec4 t = mix(t0, t1, bp);
	vec3 col = t.rgb;
	float h = t.a;
	float h0 = t.a;
	// relief : gradient de hauteur au texel voisin (constant par texel)
	float hx = mix(textureLod(tex_haut, uv + vec2(pas, 0.0), lod).a, textureLod(tex_pied, uv + vec2(pas, 0.0), lod).a, bp);
	float hy = mix(textureLod(tex_haut, uv + vec2(0.0, pas), lod).a, textureLod(tex_pied, uv + vec2(0.0, pas), lod).a, bp);
	// mousse : côté nord, haut des plaques, bords irréguliers
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	float m = aux.y * mousse_force + (bruit(ix * 0.12 + 5.0) - 0.5) * 0.9 + (0.45 - h) * 0.8 + (hs(ix + 41.0) - 0.5) * 0.25;
	if (m > 0.84) {
		int mi = clamp(int(lum * 5.0 + h * 1.5), 0, 3);
		col = MOUSSE[mi];
	}
	// neige plaquée : alpha de sommet < 1, s'accroche aux crêtes
	float s = 1.0 - COLOR.a;
	float sn = s + (h - 0.45) * 0.5 + (bruit(ix * 0.2 + 9.0) - 0.5) * 0.5 + (hs(ix + 7.0) - 0.5) * 0.2;
	if (s > 0.02 && sn > 0.55) {
		int ni = clamp(int(h * 3.2 + 0.7 * s), 0, 3);
		col = NEIGE[ni];
		h = max(h, 0.7);
	}
	ALBEDO = col * COLOR.rgb * teinte.rgb;
	ALBEDO = mix(vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11))), ALBEDO, saturation);
	// relief par normale (repère construit sur les dérivées)
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);
	vec3 n0 = normalize(NORMAL);
	vec3 dp2p = cross(dp2, n0);
	vec3 dp1p = cross(n0, dp1);
	vec3 T = dp2p * duv1.x + dp1p * duv2.x;
	vec3 B = dp2p * duv1.y + dp1p * duv2.y;
	float im = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
	vec3 nn = n0 - (T * im * (hx - h0) + B * im * (hy - h0)) * relief * 2.0;
	NORMAL = normalize(nn);
	ROUGHNESS = 1.0;
}
