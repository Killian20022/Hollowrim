// Teinte d'écran de la magie (scripts/magie/gestion_magie.gd) : pendant un jet, halo ADDITIF très léger de la couleur de
// l'école, plus marqué sur les bords (l'écran « baigne » dans le feu ou le violet). Cases de 4 px et paliers francs
// (pas de tramage) ; aucune lecture d'écran : compatible Mobile / Compatibility.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 teinte : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float force = 0.0;

void fragment() {
	vec2 uv = (floor(UV * vec2(160.0, 90.0)) + 0.5) / vec2(160.0, 90.0);
	vec2 d = (uv - 0.5) * vec2(1.7, 1.0);
	float bord = clamp(dot(d, d) * 1.8, 0.0, 1.0);
	float k = force * (0.3 + 0.7 * bord);
	k = floor(k * 32.0 + 0.5) / 32.0;
	COLOR = vec4(teinte.rgb * k, 1.0);
}
