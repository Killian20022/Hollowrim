shader_type canvas_item;
// Apparition du logo peint DÉTOURÉ (textures/menu_decor/logo_peint.png, décor animé) au lancement de l'écran titre :
// le logo se cristallise de proche en proche depuis le cristal, avec un liseré de givre bleu-blanc sur le front et un léger éclat.
// progres = 0 : rien ; 1 : logo complet (identique au logo du décor, qui prend alors le relais).

uniform float progres : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.483, 0.488);   // cristal, en UV du logo
uniform float aspect = 2.49;                // largeur / hauteur du logo
uniform float bord = 0.09;

float bruit(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = (UV - centre) * vec2(aspect, 1.0);
	float r = length(d) / (0.55 * aspect);
	float n = bruit(floor(UV * vec2(240.0, 96.0)));
	float seuil = r + (n - 0.5) * 0.12;
	float front_pos = progres * 1.25 - 0.05;
	float visible = 1.0 - smoothstep(front_pos - bord, front_pos, seuil);
	float front = clamp(1.0 - abs(seuil - front_pos) / bord, 0.0, 1.0) * (1.0 - smoothstep(0.9, 1.0, progres));
	vec3 rgb = c.rgb + vec3(0.55, 0.82, 1.0) * front * 0.9;
	// les pixels qui apparaissent naissent blancs-bleus puis prennent leur couleur
	float a = c.a * max(visible, front * 0.8);
	COLOR = vec4(rgb, a);
}
