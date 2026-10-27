uniform vec4 couleur : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 coeur : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform float anneau = 0.8;        // rayon de l'anneau (0..1 du demi-côté)
uniform float epaisseur = 0.08;
uniform float remplissage = 0.0;   // disque plein sous l'anneau
uniform float runes = 0.0;         // couronne de runes
uniform float spirale = 0.0;       // vortex (ténèbres)
uniform float opacite = 1.0;
uniform float eclat = 1.4;
uniform float texels = 48.0;
uniform float tourne = 0.0;        // vitesse de rotation (tours/s)
uniform bool face_camera = false;

float h1(float x) {
	return fract(sin(x * 91.345) * 47453.5453);
}

void vertex() {
	if (face_camera) {
		mat4 m = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * m * mat4(vec4(s, 0, 0, 0), vec4(0, s, 0, 0), vec4(0, 0, s, 0), vec4(0, 0, 0, 1));
	}
}

void fragment() {
	vec2 uv = (floor(UV * texels) + 0.5) / texels * 2.0 - 1.0;
	float r = length(uv);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(uv.y, uv.x) + TIME * tourne * 6.2831;
	float a = 0.0;
	float k = 0.0;   // 1 = ton de cœur
	float d = abs(r - anneau);
	if (d < epaisseur) {
		a = 1.0 - d / epaisseur * 0.6;
		k = d < epaisseur * 0.35 ? 1.0 : 0.0;
	}
	if (remplissage > 0.0 && r < anneau) {
		a = max(a, remplissage * (0.35 + 0.65 * r / max(anneau, 0.01)));
	}
	if (runes > 0.0 && r > anneau - 0.22 && r < anneau - 0.08) {
		float seg = floor((ang / 6.2831 + 0.5) * 24.0);
		float u = fract((ang / 6.2831 + 0.5) * 24.0);
		float v = (r - (anneau - 0.22)) / 0.14;
		float g = h1(seg);
		bool trait = (u > 0.3 && u < 0.45) || (g > 0.5 && abs(v - u) < 0.18) || (g < 0.35 && v > 0.45 && v < 0.6);
		if (trait && u < 0.8) {
			a = max(a, runes);
			k = 1.0;
		}
	}
	if (spirale > 0.0) {
		float s = fract(ang / 6.2831 * 3.0 + r * 2.2 - TIME * 0.6);
		float bras = smoothstep(0.55, 0.0, abs(s - 0.5)) * (1.0 - r);
		a = max(a, spirale * step(0.25, bras) * (0.5 + step(0.5, bras) * 0.5));
		k = r < 0.25 ? 1.0 : k;
	}
	a *= opacite;
	a = ceil(a * 3.0 - 0.05) / 3.0;
	if (a <= 0.0) {
		discard;
	}
	vec3 c = k > 0.5 ? coeur.rgb : couleur.rgb;
	ALBEDO = c * eclat;
	ALPHA = clamp(a, 0.0, 1.0);
}
