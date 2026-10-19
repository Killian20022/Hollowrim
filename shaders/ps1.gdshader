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
// sol écologique (terrain seulement, lot D) : carte 480² RGBA8, R = matière × 32, G = clarté, B = zone
uniform bool sol_carte = false;
uniform sampler2D carte_sol : filter_nearest, repeat_disable;
uniform vec3 carte_rect = vec3(-120.0, -120.0, 0.0041666667); // x0, z0, 1/taille
uniform sampler2D tex_terre : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_mousse : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_aiguilles_sol : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_neige_pietinee : source_color, filter_nearest_mipmap, repeat_enable;
instance uniform float eclair = 0.0; // flash quand l'objet est touché (par instance)

varying vec3 uv_aff;
varying vec2 uv_macro;
varying vec2 pos_monde;  // position monde (interpolation normale, non affine)

void vertex() {
	VERTEX += NORMAL * gonfle;
	vec2 uv = UV * uv_echelle;
	if (uv_monde) {
		uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * monde_echelle;
	}
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
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
	if (sol_carte) {
		// zone témoin : matière lue dans la carte, UV monde non affines (8 texels/m).
		// Toutes les textures sont lues sans condition (dérivées définies pour les mipmaps).
		vec4 carte = texture(carte_sol, (pos_monde - carte_rect.xy) * carte_rect.z);
		vec2 p4 = pos_monde * 0.25;
		vec3 s_neige = texture(tex_neige, pos_monde * 0.125).rgb;
		vec3 s_piet = texture(tex_neige_pietinee, p4).rgb;
		vec3 s_terre = texture(tex_terre, p4).rgb;
		vec3 s_aig = texture(tex_aiguilles_sol, p4).rgb;
		vec3 s_mousse = texture(tex_mousse, p4).rgb;
		vec3 s_roche = texture(tex_base, p4).rgb;
		if (carte.b > 0.5) {
			int m = int(carte.r * 255.0 / 32.0 + 0.5);
			vec3 sol = s_roche;
			if (m == 0) sol = s_neige;
			else if (m == 1) sol = s_piet;
			else if (m == 2) sol = s_terre;
			else if (m == 3) sol = s_aig;
			else if (m == 4) sol = s_mousse;
			ALBEDO = sol * (0.5 + carte.g) * COLOR.rgb * teinte.rgb;
		}
	}
	if (macro_force > 0.0) {
		float m = texture(tex_macro, uv_macro).r;
		ALBEDO *= mix(1.0, 0.8 + m * 0.36, macro_force);
	}
	ALBEDO = mix(vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11))), ALBEDO, saturation);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = emission + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}
