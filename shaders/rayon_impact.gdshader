// IMPACT du RAYON NOIR (scripts/magie/rayon_noir.gd, v3) : quad posé sur la surface touchée (ou face au lanceur sur un corps).
// Noyau clair qui pulse, trois anneaux qui s'élargissent en boucle (onde de choc), étincelles rayonnantes qui tournent,
// anneau de runes pointillé. Mélange alpha HDR ; pas de texture.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 bord : source_color = vec3(0.78, 0.13, 0.66);
uniform vec3 accent : source_color = vec3(0.89, 0.24, 0.77);
uniform vec3 filet : source_color = vec3(1.0, 0.77, 0.95);
uniform float ouv = 1.0;
uniform float t = 0.0;

float trait(float d, float e) { return 1.0 - smoothstep(e * 0.5, e, d); }
float h11(float x) { return fract(sin(x * 127.1 + 4.7) * 43758.5453); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	if (r > 1.0) { ALPHA = 0.0; ALBEDO = vec3(0.0); }
	else {
		vec3 c = vec3(0.0);
		float a = 0.0;
		// halo doux
		float halo = pow(1.0 - r, 2.2) * 0.45;
		c = bord; a = halo;
		// ondes de choc
		for (int i = 0; i < 3; i++) {
			float ph = fract(t * 0.9 + float(i) / 3.0);
			float rr = 0.12 + 0.82 * ph;
			float w = trait(abs(r - rr), 0.035 + 0.05 * ph) * (1.0 - ph) * (1.0 - ph);
			c = mix(c, mix(accent, filet, 1.0 - ph) * 1.5, w);
			a = max(a, w * 0.9);
		}
		// étincelles rayonnantes (traits qui s'allongent depuis le centre, tournent)
		float n = 14.0;
		float cell = floor(fract((ang + t * 0.5) / TAU) * n);
		float fa = fract((ang + t * 0.5) / TAU * n) - 0.5;
		float lon = 0.18 + 0.5 * h11(cell + floor(t * 6.0));
		float vive = step(0.35, h11(cell * 1.7 + floor(t * 6.0)));
		float ray = trait(abs(fa) * r * 0.45, 0.012) * step(0.14, r) * step(r, 0.14 + lon) * vive;
		c = mix(c, filet * 1.5, ray)   /* v5 : moins blanc */; a = max(a, ray * 0.85);
		// anneau de runes pointillé
		float dots = fract((ang - t * 0.7) / TAU * 20.0);
		float ann = trait(abs(r - 0.62), 0.03) * step(dots, 0.35);
		c = mix(c, accent * 1.6, ann * 0.8); a = max(a, ann * 0.7);
		// noyau clair
		float noy = (1.0 - smoothstep(0.04, 0.2, r)) * (0.8 + 0.2 * sin(t * 18.0));
		c = mix(c, filet * 2.0, noy); a = max(a, noy);
		ALBEDO = c * clamp(a * ouv * (1.0 - smoothstep(0.85, 1.0, r)), 0.0, 1.0);   // v4 : additif prémultiplié (couche fine)
		ALPHA = 0.0;
	}
}
