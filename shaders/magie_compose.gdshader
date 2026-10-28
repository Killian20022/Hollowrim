// Pose de la couche fine de la magie (scripts/magie/couche_magie.gd) sur le monde : texture du SubViewport en HDR
// LINÉAIRE prémultiplié (fond transparent ; les couches additives n'écrivent pas d'opacité, voir magie_part_add).
// Puis passage en sRVB (coupé à 1, comme le monde). Pixels nets : filtre au plus proche, une case de texture par pixel de l'écran (ou 2x2 en Moyen).
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float opacite = 1.0;   // 0 : amorçage au chargement (pipeline compilé, rien d'affiché)

vec3 vers_srvb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	float a = clamp(m.a, 0.0, 1.0);
	// dé-prémultiplier avant le passage en sRVB (sinon les paliers 1/3 et 2/3 des particules opaques pâlissent) ;
	// là où il n'y a que de l'additif (opacité nulle), la lumière est ajoutée telle quelle
	// pixel MIXTE (flux des jets : lumière + couverture partielle, rgb > a) : la part couvrante (rgb <= a) est
	// dé-prémultipliée, l'excédent est de la lumière ajoutée ; sans ce partage, la division saturait chaque canal
	// séparément (cœur blanc délavé et franges de couleurs fausses)
	vec3 couvre = min(m.rgb, vec3(a));
	vec3 lum = m.rgb - couvre;
	vec3 s = a > 0.004 ? vers_srvb(couvre / a) * a : vec3(0.0);
	s += vers_srvb(min(a > 0.004 ? lum : m.rgb, vec3(1.0)));
	COLOR = vec4(s, a) * opacite;
}
