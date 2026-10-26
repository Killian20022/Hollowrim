shader_type canvas_item;
// Apparition du logo peint de l'écran titre (scripts/ecran_titre.gd) : le recadrage du logo (TEXTURE, net) sort d'une brume
// (flou : la même zone très floutée, les lettres y sont fondues dans le ciel), de proche en proche depuis le cristal, avec un liseré de
// givre bleu-blanc sur le front. progres = 0 : brume seule ; 1 : logo net (identique au fond, le calque peut alors être caché).
// Les bords du recadrage sont fondus (côtés et bas), le haut touche le bord de l'image.

uniform sampler2D flou : filter_linear, repeat_disable;
uniform float progres : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.44);   // cristal, en UV du recadrage
uniform float aspect = 2.47;             // largeur / hauteur du recadrage
uniform float bord = 0.10;               // largeur du front de givre

float bruit(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 net = texture(TEXTURE, UV);
	vec4 b = texture(flou, UV);
	vec2 d = (UV - centre) * vec2(aspect, 1.0);
	float r = length(d) / (0.62 * aspect);
	float n = bruit(floor(UV * vec2(210.0, 85.0)));
	float seuil = r + (n - 0.5) * 0.10;
	float front_pos = progres * 1.3 - 0.05;
	float m = smoothstep(front_pos - bord, front_pos, seuil);    // 1 = encore dans la brume
	vec3 c = mix(net.rgb, b.rgb, m);
	float lum = dot(net.rgb, vec3(0.299, 0.587, 0.114));
	float front = clamp(1.0 - abs(seuil - front_pos) / bord, 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, progres));
	c += vec3(0.55, 0.82, 1.0) * front * smoothstep(0.30, 0.75, lum) * 1.1;
	float a = smoothstep(0.0, 0.07, UV.x) * smoothstep(0.0, 0.07, 1.0 - UV.x) * smoothstep(0.0, 0.14, 1.0 - UV.y);
	COLOR = vec4(c, a * net.a);
}
