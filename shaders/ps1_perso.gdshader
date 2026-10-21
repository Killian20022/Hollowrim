// Matériau « PS1 » des personnages pilotes (guerrier nordique) : MÊME chaîne que ps1.gdshader
// (sommets accrochés à la grille d'écran, mapping affine, texels nets), sans le code du sol, plus :
//   - mipmaps pixel art (précalculées par vote de couleur : à distance, pas de moiré ni de fondu de teinte) ;
//   - découpe alpha nette (mèches de fourrure, bords dentelés de la cape) : seuil 0,5, jamais de fondu ;
//   - soleil en partie désaturé et ombres propres froides (sous la lumière orangée du crépuscule, tout ne vire pas au brun) ;
//     les lumières ponctuelles (torches, feux) gardent leur couleur chaude.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform vec2 uv_echelle = vec2(1.0);
uniform float grille = 135.0;       // lignes de la grille d'accroche (0 = pas de tremblement)
uniform float affine = 1.0;         // 1 = déformation affine façon PS1
uniform float gonfle = 0.0;         // décalage des sommets le long de la normale (m)
uniform vec3 emission : source_color = vec3(0.0);
uniform float saturation = 1.0;
uniform bool decoupe = false;
uniform float soleil_desat = 0.45;  // part de la couleur du soleil/lune ramenée au gris (0 = inchangée)
uniform vec3 ombre_froide : source_color = vec3(0.30, 0.42, 0.75); // teinte de la face non éclairée par le soleil
uniform float ombre_force = 0.75;   // intensité de cette teinte, relative à la lumière du soleil
uniform float rehaut = 0.9;
uniform vec3 appoint = vec3(0.035, 0.045, 0.07); // lumière propre froide (ciel) : la face à l'ombre ne tombe pas au noir         // rehaut d'arête : liseré de soleil sur la silhouette quand il est à contre-jour
instance uniform float eclair = 0.0;

varying vec3 uv_aff;

void vertex() {
	VERTEX += NORMAL * gonfle;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = vec2(grille * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, grille);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(UV * uv_echelle * w, w);
}

void fragment() {
	vec2 uv = uv_aff.xy / uv_aff.z;
	vec4 c = texture(tex_base, uv);
	if (decoupe && c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * COLOR.rgb * teinte.rgb;
	ALBEDO = mix(vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11))), ALBEDO, saturation);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.85, 0.8), eclair);
	EMISSION = emission + ALBEDO * appoint + vec3(0.6, 0.25, 0.2) * eclair;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 col = LIGHT_COLOR;
	if (LIGHT_IS_DIRECTIONAL) {
		float l = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(col, vec3(l), soleil_desat);
		// face à l'ombre du soleil : appoint froid (le ciel), proportionnel à la force du soleil
		DIFFUSE_LIGHT += ombre_froide * l * ombre_force * clamp(-ndl * 0.7 + 0.3, 0.0, 1.0) / PI;
		// rehaut d'arête (contre-jour) : bord de silhouette tourné vers le soleil, en palier net (pas de dégradé qui scintille)
		float bord = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float contre = clamp(dot(LIGHT, -VIEW) * 0.5 + 0.5, 0.0, 1.0);
		float r = step(0.55, bord) * step(0.0, ndl + 0.25) * contre;
		DIFFUSE_LIGHT += col * r * rehaut * ATTENUATION / PI;
	}
	DIFFUSE_LIGHT += clamp(ndl, 0.0, 1.0) * ATTENUATION * col / PI;
}
