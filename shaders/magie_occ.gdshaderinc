// Occlusion de la couche FINE de la magie (scripts/magie/couche_magie.gd) : son SubViewport ne dessine que les sorts,
// sans décor. La profondeur du monde (640x360) est copiée par ProfondeurMagie à l'image précédente ; on reprojette le
// fragment dans la vue de cette image-là (magie_vue_prec) et on le jette s'il est derrière le décor, les ennemis ou les
// mains. magie_occ = 0 (mode rétro, rendu Compatibility) : rien n'est fait, la profondeur du rendu principal suffit.
global uniform sampler2D magie_prof : filter_nearest;
global uniform mat4 magie_vue_prec;
global uniform float magie_occ;

// vrai si le fragment (coordonnées écran de CE rendu) est caché par le monde
bool magie_cachee(vec2 suv, float zfrag, mat4 inv_proj, mat4 inv_vue, mat4 proj) {
	if (magie_occ < 0.5) {
		return false;
	}
	vec4 v = inv_proj * vec4(suv * 2.0 - 1.0, zfrag, 1.0);
	v /= v.w;
	vec4 c = proj * (magie_vue_prec * (inv_vue * vec4(v.xyz, 1.0)));
	if (c.w <= 0.0001) {
		return false;
	}
	vec3 ndc = c.xyz / c.w;
	vec2 uv = ndc.xy * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return false;
	}
	float zm = texture(magie_prof, uv).r;
	vec4 w = inv_proj * vec4(ndc.xy, zm, 1.0);
	float d_monde = -w.z / w.w;
	// marge : quelques cm, un peu plus au loin (profondeur 640x360, 24 bits)
	return c.w > d_monde + 0.03 + 0.01 * d_monde;
}
