// Bruit de valeur 2D léger pour les motifs procéduraux de la couche fine (magie_flux, magie_aura) : 3 octaves = 12
// lectures de hachage par appel (le bruit 3D à 4 octaves coûtait près de 3 fois plus, mesuré : docs/MAGIE_EFFETS.md).
float mh2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float mbruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mh2(i), mh2(i + vec2(1.0, 0.0)), f.x), mix(mh2(i + vec2(0.0, 1.0)), mh2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 2 octaves : motifs des grandes surfaces (flux, auras)
float mfbm2(vec2 p) {
	return (0.5 * mbruit(p) + 0.25 * mbruit(p * 2.03 + vec2(1.7, 9.2))) / 0.75;
}

float mfbm(vec2 p) {
	float v = 0.5 * mbruit(p);
	p = p * 2.03 + vec2(1.7, 9.2);
	v += 0.25 * mbruit(p);
	p = p * 2.03 + vec2(4.1, 2.3);
	v += 0.125 * mbruit(p);
	return v / 0.875;
}
