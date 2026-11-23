// FOUDRE v2 (docs/MAGIE_FOUDRE_V2.md) : traits d'éclair à largeur ENTIÈRE en pixels écran, comme magie_trait (même format
// de sommets, donc même constructeur de maillage), mais en TROIS tons nets :
//   halo  : bleu-violet sur les bords, bleu au milieu (le dégradé suit le travers du trait, quantifié en paliers) ;
//   cœur  : blanc-bleu, 1 à 2 pixels.
// Sommets : VERTEX = extrémité, NORMAL = direction du segment, UV.x = couche (0 halo, 1 cœur), UV.y = côté (-1 / +1),
//           UV2.x = multiplicateur de largeur (effilement), UV2.y = niveau (0 tronc, 1 branche, 2 filament),
//           COLOR.a = intensité du point.
// `eclat` (paramètre d'instance) : 1 à la régénération, puis retombe par paliers (CPU) ; la rémanence de l'ancienne forme
// est un second maillage au même matériau, eclat bas, une ou deux images.
// Additif prémultiplié, sans texture, tramage AUCUN (paliers seulement), occlusion de la couche fine (magie_occ).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;
uniform vec4 halo_bord : source_color = vec4(0.22, 0.16, 0.80, 1.0);
uniform vec4 halo_milieu : source_color = vec4(0.30, 0.45, 1.0, 1.0);
uniform vec4 coeur : source_color = vec4(0.86, 0.91, 1.0, 1.0);
uniform float largeur_halo = 5.0;
uniform float largeur_coeur = 2.0;
uniform float force = 1.6;
instance uniform float eclat = 1.0;

varying float couche;
varying float cote;
varying float niveau;

void vertex() {
	vec4 a = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec4 b = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX + normalize(NORMAL) * 0.05, 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float wa = max(a.w, 0.0001);
	vec2 pa = (a.xy / wa * 0.5 + 0.5) * vp;
	vec2 pb = (b.xy / max(b.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 d = pb - pa;
	if (dot(d, d) < 0.000001) {
		d = vec2(1.0, 0.0);
	}
	vec2 perp = normalize(vec2(-d.y, d.x));
	// loin de l'œil le halo s'amincit un peu (un trait de 5 px à 15 m couvrait tout le corps), jamais sous 1 px
	float loin = clamp(4.0 / wa, 0.55, 1.0);
	float base = mix(largeur_halo * loin, largeur_coeur, UV.x);
	float w = max(floor(base * max(UV2.x, 0.0) * max(magie_echelle, 1.0) + 0.5), UV.x > 0.5 ? 1.0 : 0.0);
	vec2 p = floor(pa) + 0.5 + perp * UV.y * w * 0.5;
	POSITION = vec4((p / vp * 2.0 - 1.0) * a.w, a.z, a.w);
	couche = UV.x;
	cote = UV.y;
	niveau = UV2.y;
}

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	float a = COLOR.a * eclat;
	vec3 c;
	if (couche > 0.5) {
		// cœur : blanc au tronc, bleuté sur les filaments
		c = mix(coeur.rgb, halo_milieu.rgb * 1.15, clamp(niveau * 0.45, 0.0, 1.0));
	} else {
		// halo : 2 paliers dans le travers (milieu bleu, bord violet), plus sombre sur les branches
		float x = abs(cote);
		c = x < 0.45 ? halo_milieu.rgb : halo_bord.rgb;
		a *= 0.85 - 0.25 * niveau;
	}
	// paliers d'intensité (pas de dégradé continu, pas de tramage) : quarts
	a = ceil(clamp(a, 0.0, 1.5) * 4.0 - 0.1) / 4.0;
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = c * force * a;   // additif en prémultiplié (voir magie_part_add)
	ALPHA = 0.0;
}
