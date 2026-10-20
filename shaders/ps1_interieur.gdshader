// Intérieurs (lot « kit intérieur ») : copie de ps1_bati (mêmes textures, même grille d'accroche, même relief)
// SANS la lumière ambiante du ciel (`ambient_light_disabled`) : l'intérieur a sa propre ambiante `ambiant`, sombre et
// chaude, ajoutée à l'émission ; le soleil/la lune (ombres) n'y entrent que par les fenêtres, la porte et le trou à fumée.
// Lot 5 : matériau « bâti » (murs, pierre, bois, rochers). Dérivé de ps1.gdshader (même accroche des
// sommets sur la grille d'écran, même neige par l'alpha de sommet) avec ces différences :
// - coordonnées de texture = position d'OBJET en mètres (mise à l'échelle de l'instance comprise), choix du
//   plan par la normale locale (triplanaire dur) : densité constante, pas d'étirement ; `uv_metres` : UV du
//   maillage exprimés en mètres (rondins : fil du bois dans le sens de la longueur) ;
// - mipmaps nearest (mips « vote de couleur ») ; pas de mapping affine ;
// Lot 5, 2e passe :
// - textures à 32 texels/m, fondues par TRAMAGE de bruit vers le niveau 1 (16 texels/m) entre `proche.x` et
//   `proche.y` mètres de la caméra (même principe que le sol du lot 3) : gros plan fin, loin stable ;
// - `tex_relief` : gradient de hauteur de la texture, penche la normale (lumière rasante, torches) ;
// - la couleur de sommet (COLOR.rgb) porte l'occlusion ambiante peinte (pieds de mur, dessous de toit,
//   jonctions), COLOR.a = 0 → neige.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_relief : filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_neige : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_neige_relief : filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float texels_par_m = 32.0;
uniform float relief = 0.8;           // force du relief sur la normale (0 = aucun)
uniform vec2 proche = vec2(3.0, 10.0);// fondu tramé 32 → 16 texels/m (mètres de la caméra)
uniform vec2 decalage = vec2(0.0);    // décalage de la tuile (texels)
uniform bool uv_maillage = false;     // UV du maillage (0..1 sur la pièce) : vitrages
uniform bool uv_metres = false;       // UV du maillage en mètres (× texels_par_m / taille de la texture)
uniform float grille = 135.0;         // lignes de la grille d'accroche (0 = pas de tremblement)
uniform float affine = 0.0;           // ignoré (gardé pour Palette.regler_ps1)
uniform vec3 emission : source_color = vec3(0.0);
uniform bool emission_texture = false;
uniform float saturation = 1.0;
uniform vec3 ambiant : source_color = vec3(0.2, 0.17, 0.2);   // lumière ambiante PROPRE à l'intérieur (l'ambiante du ciel est coupée)
instance uniform float eclair = 0.0;

varying vec3 p_obj;
varying vec3 n_obj;
varying vec2 uv_m;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

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
	vec3 nl = normalize(n_obj);
	vec3 a = abs(nl);
	vec2 m;
	vec3 T;
	vec3 B;
	if (a.y >= a.x && a.y >= a.z) {
		m = vec2(p_obj.x, p_obj.z);
		T = vec3(1.0, 0.0, 0.0);
		B = vec3(0.0, 0.0, 1.0);
	} else if (a.x >= a.z) {
		m = vec2(p_obj.z * sign(nl.x), -p_obj.y);
		T = vec3(0.0, 0.0, sign(nl.x));
		B = vec3(0.0, -1.0, 0.0);
	} else {
		m = vec2(-p_obj.x * sign(nl.z), -p_obj.y);
		T = vec3(-sign(nl.z), 0.0, 0.0);
		B = vec3(0.0, -1.0, 0.0);
	}
	vec2 taille = vec2(textureSize(tex_base, 0));
	vec2 uv;
	if (uv_maillage) {
		uv = uv_m;
	} else if (uv_metres) {
		uv = (uv_m * texels_par_m + decalage) / taille;
	} else {
		uv = (m * texels_par_m + decalage) / taille;
	}
	// 32 → 16 texels/m : chaque cellule de 1/16 m choisit son niveau selon un seuil de bruit (tramage)
	float dist = length(VERTEX);
	float f = smoothstep(proche.y, proche.x, dist);
	float seuil = hash21(floor((uv_metres ? uv_m : m) * 16.0) + 7.0);
	float biais = f > seuil ? 0.0 : 1.0;
	vec3 base = texture(tex_base, uv, biais).rgb;
	vec3 neige = texture(tex_neige, uv, biais).rgb;
	vec2 rb = texture(tex_relief, uv, biais).rg * 2.0 - 1.0;
	vec2 rn = texture(tex_neige_relief, uv, biais).rg * 2.0 - 1.0;
	float est_base = step(0.5, COLOR.a);
	vec3 couleur = mix(neige, base, est_base);
	vec2 rg = mix(rn, rb, est_base);
	if (!uv_maillage && relief > 0.0) {
		// on ajoute à la normale du moteur le décalage dû au relief (juste même sous échelle non uniforme)
		vec3 d = -relief * (rg.x * T + rg.y * B);
		mat3 mm = mat3(normalize(MODEL_MATRIX[0].xyz), normalize(MODEL_MATRIX[1].xyz), normalize(MODEL_MATRIX[2].xyz));
		NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * (mm * d));
	}
	ALBEDO = couleur * COLOR.rgb * teinte.rgb;
	ALBEDO = mix(vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11))), ALBEDO, saturation);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = (emission_texture ? emission * couleur : emission) + vec3(0.6, 0.25, 0.2) * eclair + ALBEDO * ambiant;
	ROUGHNESS = 1.0;
}
