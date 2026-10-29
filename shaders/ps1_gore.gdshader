// Matériau « PS1 » des pièces de gore (Demembrement) : capuchons de moignon, boyaux. Même accroche des sommets à la grille
// d'écran que ps1_draugr (pas de tremblement différent du corps), couleurs PLATES (aucun dégradé lissé), aspect mouillé.
//   par_canal = vrai : la couleur de sommet choisit un aplat (R : chair, G : lèvre sombre, B : os) — capuchons ;
//   par_canal = faux : couleur de sommet (palette peinte dans Blender) × teinte — boyaux.
shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

uniform float grille = 135.0;
uniform bool par_canal = false;
uniform vec3 c_chair : source_color = vec3(0.54, 0.10, 0.08);
uniform vec3 c_levre : source_color = vec3(0.23, 0.02, 0.02);
uniform vec3 c_os : source_color = vec3(0.94, 0.91, 0.82);
uniform vec3 teinte : source_color = vec3(1.0);
uniform float mouille = 0.6;
uniform vec3 appoint = vec3(0.035, 0.045, 0.07);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = COLOR.rgb * teinte;
	float os = 0.0;
	if (par_canal) {
		vec3 w = COLOR.rgb;
		c = c_chair;
		if (w.g > w.r && w.g > w.b) { c = c_levre; }
		if (w.b > w.r && w.b > w.g) { c = c_os; os = 1.0; }
	}
	ALBEDO = c;
	EMISSION = c * appoint;
	ROUGHNESS = mix(0.35, 0.85, os);
	SPECULAR = mouille * (1.0 - os * 0.6);
}
