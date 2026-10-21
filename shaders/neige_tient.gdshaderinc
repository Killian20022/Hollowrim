// Refonte « lumière » : NEIGE QUI TIENT sur les objets extérieurs (inclus par ps1.gdshader et ps1_bati.gdshader).
// Couche procédurale sur les faces tournées vers le haut (normale MONDE), découpée sur une grille de texels MONDE
// de 1/16 m (bible §3 : 16 texels/m) : bord irrégulier en amas de pixels, stable quand la caméra bouge (rien n'est
// calculé à l'écran), plus du givre en amas sur les faces inclinées.
// - `neige_objets` (uniforme GLOBAL, project.godot) : 1 dehors ; 0 sous terre (crypte, grotte), dans un intérieur, et
//   avec l'option --sans-neige-objets (A/B). Réglé par cycle.gd.
// - `neige_tient` (par matériau) : 0 = jamais (eau, vêtements, peaux…).
// - Les parties déjà neigées d'un matériau (alpha de sommet < 0,5 : toits, sapins) ne sont pas touchées.
global uniform float neige_objets;
uniform float neige_tient = 1.0;

float nt_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float nt_bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(nt_hash(i), nt_hash(i + vec2(1.0, 0.0)), f.x),
		mix(nt_hash(i + vec2(0.0, 1.0)), nt_hash(i + vec2(1.0)), f.x), f.y);
}

// Texel monde (1/16 m) du plan dominant de la normale : identifiant stable d'un « pixel » de neige.
vec2 nt_texel(vec3 pm, vec3 nm) {
	vec3 a = abs(nm);
	vec2 p = (a.y >= a.x && a.y >= a.z) ? pm.xz : ((a.x >= a.z) ? pm.zy : pm.xy);
	return floor(p * 16.0);
}

// Couverture de neige 0..1 d'un fragment (0 = rien, 1 = neige, 0,5 = bord / givre : ton plus sombre).
// nm : normale monde normalisée (géométrique, avant relief) ; pm : position monde ; dist : distance à la caméra (m).
float nt_couverture(vec3 nm, vec3 pm, float dist) {
	float k = neige_objets * neige_tient;
	if (k <= 0.0 || dist < 1.6) {
		return 0.0;  // mains et objets tenus (< 1,6 m) : jamais de neige
	}
	vec2 q = nt_texel(pm, nm);
	vec2 qc = (q + 0.5) / 16.0;
	// seuil irrégulier : grandes plaques (0,6 m) + amas (15 cm) + grain d'un texel
	float b = 0.55 * nt_bruit(qc * 1.6) + 0.30 * nt_bruit(qc * 6.5 + 13.1) + 0.15 * nt_hash(q + 41.7);
	float v = nm.y + (b - 0.5) * 0.55;
	float seuil = mix(1.2, 0.55, k);
	if (v > seuil + 0.07) {
		return 1.0;
	}
	if (v > seuil) {
		return 0.5;  // lèvre : un texel de neige plus sombre au bord de la couche
	}
	// givre : amas de quelques texels (jamais un pixel isolé, bible §4.2) sur les faces inclinées (pointes, biseaux,
	// rondins couchés) ; rien sur les faces verticales
	if (nm.y > 0.15) {
		float amas = nt_bruit(qc * 5.0 + 3.7) * 0.8 + nt_hash(q + 5.3) * 0.2;
		if (amas > mix(0.80, 0.62, smoothstep(0.15, 0.55, nm.y)) + (1.0 - k) * 0.3) {
			return 0.5;
		}
	}
	return 0.0;
}

// Applique la couverture à l'albédo : neige `neige_c` (texture de neige du matériau), bord légèrement plus sombre.
vec3 nt_appliquer(vec3 albedo, vec3 neige_c, float couv) {
	vec3 bord = neige_c * vec3(0.80, 0.83, 0.92);
	return couv > 0.75 ? neige_c : (couv > 0.25 ? bord : albedo);
}
