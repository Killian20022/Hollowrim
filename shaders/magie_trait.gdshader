// Traits pixel de la magie (arcs électriques, chaînes d'éclairs, faisceau du drain) : chaque segment du maillage est
// élargi À L'ÉCRAN à une largeur en pixels ENTIERS (halo + cœur), quelle que soit la distance. Sommets :
//   VERTEX = extrémité, NORMAL = direction du segment, UV.x = couche (0 halo, 1 cœur), UV.y = côté (-1 / +1),
//   UV2.x = multiplicateur de largeur, COLOR.a = opacité (paliers).
// Additif, sans texture : compatible Mobile / Compatibility.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 halo : source_color = vec4(0.29, 0.23, 0.82, 1.0);
uniform vec4 coeur : source_color = vec4(0.94, 0.95, 1.0, 1.0);
uniform float largeur_halo = 3.0;
uniform float largeur_coeur = 1.0;
uniform float eclat = 1.6;

varying float couche;

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
	float w = floor(mix(largeur_halo, largeur_coeur, UV.x) * max(UV2.x, 0.0) + 0.5);
	vec2 p = floor(pa) + 0.5 + perp * UV.y * w * 0.5;
	POSITION = vec4((p / vp * 2.0 - 1.0) * a.w, a.z, a.w);
	couche = UV.x;
}

void fragment() {
	vec4 c = couche > 0.5 ? coeur : halo;
	float a = ceil(COLOR.a * c.a * 3.0 - 0.05) / 3.0;
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = c.rgb * eclat;
	ALPHA = a;
}
