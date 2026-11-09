shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// ESSAI Tripo (branche essai/puits) : conduit du puits. Dessiné sans lumière : la teinte (dégradé de couleur de sommet, du clair au
// noir) fait toute la profondeur, rien ne bouge (ni eau ni lueur). Look PS1 : texture au plus proche voisin, UV affines, sommets sur grille.
//
// Le terrain n'est PAS troué (voir ps1.gdshader, RELIEF_COUCHE : un `discard` coûte le test de profondeur précoce). Même astuce que le
// creux de neige : les sommets SOUS le plan du sol sont ramenés, pour la PROFONDEUR seule, sur ce plan le long de leur rayon de vue
// (- 1 cm). L'image est celle d'un conduit réellement creusé ; rien de ce qui est devant le sol (margelle, joueur) n'est caché par
// lui. Les faces du conduit sont orientées vers l'intérieur et la face arrière est écartée : un seul plan visible par pixel.
uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float sol_y = 0.0;          // hauteur monde du terrain sous le puits
uniform float biais = 0.3;          // le terrain rendu (relief fin, neige) dépasse le maillage : le plan de profondeur est relevé d'autant
uniform float haut = 0.81;           // hauteur de la margelle au-dessus du sol (ouverture du puits)
uniform float rayon = 0.64;          // rayon de l'ouverture
uniform float devant = 0.0;        // > 0 : objet pendu dans le conduit (seau, corde) : devant la paroi (plan - devant), mais l'ordre entre ses pièces est gardé
uniform float clair = 0.0;          // diagnostic : 1 = pas de dégradé vers le noir
uniform float grille = 135.0;
uniform float affine = 1.0;

varying vec3 uv_aff;
varying float prof;   // profondeur monde sous la margelle (m)

void vertex() {
	vec2 uv = UV;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * vec4(vp, 1.0);
	float yw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	if (yw < sol_y + biais) {
		vec3 rv = normalize(vp);
		vec3 g0 = (VIEW_MATRIX * vec4(0.0, sol_y + biais, 0.0, 1.0)).xyz;
		vec3 n = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		float t = dot(g0, n) / min(dot(rv, n), -0.02);
		float td = t - 0.01;
		if (devant > 0.0) {
			td = t - devant + max(length(vp) - t, 0.0) * 0.0015;
		}
		vec4 cb = PROJECTION_MATRIX * vec4(rv * td, 1.0);
		clip.z = cb.z / cb.w * clip.w;
	}
	if (grille > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec2 g = VIEWPORT_SIZE * (grille / 270.0);
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	prof = MODEL_MATRIX[3].y + haut - yw;
	POSITION = clip;
	float w = mix(1.0, clip.w, affine);
	uv_aff = vec3(uv * w, w);
}

void fragment() {
	// Le conduit n'existe que vu à travers l'ouverture : la profondeur ramenée au sol le ferait sinon déborder sur le terrain.
	vec3 fw = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 ctr = MODEL_MATRIX[3].xyz;
	if (fw.y < ctr.y + haut) {
		vec3 ro = INV_VIEW_MATRIX[3].xyz;
		vec3 rd = normalize(fw - ro);
		float t = (ctr.y + haut - ro.y) / rd.y;
		vec3 h = ro + rd * t;
		if (t < 0.0 || length(h.xz - ctr.xz) > rayon) discard;
	}
	vec2 uv = uv_aff.xy / uv_aff.z;
	// dégradé vers le noir : à peine plus sombre jusqu'à 0,5 m sous la margelle, quasi noir à 3 m
	float p = max(prof, 0.0);
	float k = p < 0.5 ? 1.0 - 0.25 * p / 0.5 : 0.75 * pow(clamp(1.0 - (p - 0.5) / 2.5, 0.0, 1.0), 2.0) + 0.015;
	ALBEDO = texture(tex_base, uv).rgb * COLOR.rgb * teinte.rgb * mix(k, 1.0, clair);
}
