// Lot 5 : matériau « bâti » (murs, pierre, bois, rochers). Dérivé de ps1.gdshader (même accroche des
// sommets sur la grille d'écran, même neige par l'alpha de sommet) avec trois différences :
// - coordonnées de texture = position d'OBJET en mètres (mise à l'échelle de l'instance comprise), choix du
//   plan par la normale locale (triplanaire dur) : 16 texels/m partout, pas d'étirement sur les grandes
//   boîtes, les sphères déformées (rochers) ni les MultiMesh à échelle verticale (palissade) ;
// - mipmaps nearest (la texture porte des mips « vote de couleur », voir TexturesBati) : plus de
//   scintillement ni de moiré des joints à distance ;
// - pas de mapping affine : le gauchissement des textures sur les grands triangles (AFFINE du jeu) faisait
//   « nager » joints et planches.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_neige : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float texels_par_m = 16.0;
uniform vec2 decalage = vec2(0.0);  // décalage de la tuile (texels)
uniform bool uv_maillage = false;   // UV du maillage (0..1 sur la pièce) au lieu des coordonnées d'objet : vitrages
uniform float grille = 135.0;       // lignes de la grille d'accroche (0 = pas de tremblement)
uniform float affine = 0.0;         // ignoré (gardé pour Palette.regler_ps1)
uniform vec3 emission : source_color = vec3(0.0);
uniform bool emission_texture = false;  // l'émission suit la clarté de la texture (fenêtres, braises)
uniform float saturation = 1.0;
instance uniform float eclair = 0.0;

varying vec3 p_obj;
varying vec3 n_obj;
varying vec2 uv_m;

void vertex() {
	vec3 echelle = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	p_obj = VERTEX * echelle;
	n_obj = NORMAL;
	uv_m = UV;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 a = abs(n_obj);
	vec2 m;
	if (a.y >= a.x && a.y >= a.z) {
		m = vec2(p_obj.x, p_obj.z);
	} else if (a.x >= a.z) {
		m = vec2(p_obj.z * sign(n_obj.x), -p_obj.y);
	} else {
		m = vec2(-p_obj.x * sign(n_obj.z), -p_obj.y);
	}
	vec2 uv = uv_maillage ? uv_m : (m * texels_par_m + decalage) / vec2(textureSize(tex_base, 0));
	vec3 base = texture(tex_base, uv).rgb;
	vec3 neige = texture(tex_neige, uv).rgb;
	vec3 couleur = mix(neige, base, step(0.5, COLOR.a));
	ALBEDO = couleur * COLOR.rgb * teinte.rgb;
	ALBEDO = mix(vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11))), ALBEDO, saturation);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = (emission_texture ? emission * couleur : emission) + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}
