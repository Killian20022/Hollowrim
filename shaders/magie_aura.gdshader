// AURAS et BOULES procédurales de la couche fine (scripts/magie/gestion_magie.gd, _aura_fine / _boule_fine) : carré
// tourné vers la caméra, centré sur la paume (ou le projectile), rayon `rayon` m. Le motif est calculé AU PIXEL de la
// couche fine, en pixels du monde (même taille de motif de près comme de loin) puis seuillé en paliers francs :
//   feu        : langues qui montent (cœur blanc, jaune, orange, rouge, bord sombre)
//   glace      : brume de givre qui tourne, paillettes blanches, aiguilles de givre
//   électricité: filaments de plasma (crêtes fines d'un bruit), éclat blanc au centre
//   ténèbres   : vortex (spirale noire aux bras violets), aspiré vers le centre
//   soin / protection : halo doré / bleu pâle qui ondule
// `forme` 1 = boule (projectile, explosion) : masque rond bouillonnant au lieu des flammes montantes.
// `forme` 2 = boule de feu TENUE (cœur de l'aura de feu) : sphère lisse et lumineuse, langues au bord.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_occ.gdshaderinc"
global uniform float magie_echelle;

instance uniform float rayon = 0.12;
instance uniform float force = 1.0;
instance uniform float graine = 0.0;
instance uniform float avance = 0.0;   // m vers l'œil : l'aura passe devant le dos de la main (flammes qui l'enveloppent)
uniform int ecole = 0;
uniform int forme = 0;
uniform float eclat = 1.4;
uniform vec4 c0 : source_color = vec4(1.0, 0.98, 0.91, 1.0);
uniform vec4 c1 : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 c2 : source_color = vec4(0.99, 0.71, 0.23, 1.0);
uniform vec4 c3 : source_color = vec4(0.93, 0.42, 0.12, 1.0);
uniform vec4 c4 : source_color = vec4(0.70, 0.20, 0.12, 1.0);
uniform vec4 c5 : source_color = vec4(0.35, 0.10, 0.11, 1.0);

varying vec2 v_px;      // position dans le carré, en pixels de la couche (0 = centre)
varying float v_rpx;    // rayon en pixels de la couche
varying vec2 v_haut;    // « haut » du monde projeté à l'écran (les flammes montent même main penchée)

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 vers_oeil = normalize(INV_VIEW_MATRIX[3].xyz - centre);
	centre += vers_oeil * avance;
	vec4 cc = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
	vec4 ch = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre + vec3(0.0, 0.05, 0.0), 1.0));
	vec2 vp = VIEWPORT_SIZE;
	float w = max(cc.w, 0.0001);
	vec2 pc = (cc.xy / w * 0.5 + 0.5) * vp;
	vec2 ph = (ch.xy / max(ch.w, 0.0001) * 0.5 + 0.5) * vp;
	vec2 hd = ph - pc;
	v_haut = dot(hd, hd) > 0.0001 ? normalize(hd) : vec2(0.0, 1.0);
	float rpx = rayon * abs(PROJECTION_MATRIX[1][1]) / w * vp.y * 0.5;
	vec2 p = floor(pc) + 0.5 + VERTEX.xy * 2.0 * (rpx + 1.0);
	POSITION = vec4((p / vp * 2.0 - 1.0) * cc.w, cc.z, cc.w);
	v_px = VERTEX.xy * 2.0 * (rpx + 1.0);
	v_rpx = rpx;
}

#include "res://shaders/magie_bruit.gdshaderinc"

vec3 palier(float i) {
	return i > 1.15 ? c0.rgb : (i > 0.95 ? c1.rgb : (i > 0.78 ? c2.rgb : (i > 0.6 ? c3.rgb : (i > 0.45 ? c4.rgb : c5.rgb))));
}

void fragment() {
	float m = max(magie_echelle, 1.0);
	// repère : y = haut du monde à l'écran ; tout en pixels du MONDE (motif de taille constante à l'écran)
	vec2 hx = vec2(v_haut.y, -v_haut.x);
	vec2 q = vec2(dot(v_px, hx), dot(v_px, v_haut)) / m;
	float rp = max(v_rpx / m, 1.0);
	float r = length(q) / rp;        // 0 centre, 1 bord du carré
	float tt = TIME + graine * 11.0;
	// le motif s'éteint avant le bord du carré (jamais de bord droit)
	float carre = max(abs(q.x), abs(q.y)) / rp;
	float garde = 1.0 - smoothstep(0.72, 0.97, carre);
	float i = 0.0;
	float al = 1.0;
	vec3 c = vec3(0.0);
	if (ecole == 0) {
		// FEU
		vec2 f = q;
		float n;
		if (forme == 2) {
			// boule TENUE au creux de la main (avant-bras « runes », bras_feu_1100.jpg) : sphère lisse et lumineuse, cœur
			// blanc-jaune, orange franc, petites langues qui lèchent le bord vers le haut ; peu de bruit (pas de taches)
			float hy = f.y / rp;
			float lang = mfbm2(vec2(f.x / 2.5 + tt * 0.15, (f.y - tt * rp * 1.3) / 6.0) + graine) - 0.5;
			float rr = r - max(hy, 0.0) * 0.18 * (1.0 + lang * 2.0);
			if (rr > 1.0) {
				discard;
			}
			n = mfbm2(f / 7.0 + vec2(tt * 0.35, -tt * 0.55) + graine);
			// cœur blanc-jaune large et LISSE qui domine (bruit faible), orange franc puis langues au bord seulement
			i = (1.0 - rr) * 1.95 + (n - 0.5) * 0.16 * smoothstep(0.25, 0.6, rr) + lang * 0.35 * smoothstep(0.5, 0.9, rr);
		} else if (forme == 1) {
			if (r > 1.0) {
				discard;
			}
			n = mfbm2(f / 5.0 + vec2(tt * 0.9, -tt * 1.3) + graine);
			float n2 = mbruit(f / 2.0 + vec2(-tt * 1.7, tt * 1.1) + 7.0);
			i = (1.0 - r * 1.15) * 1.2 + (n - 0.5) * 1.3 + (n2 - 0.5) * 0.5;
		} else {
			// flammes qui montent : le bruit défile vers le haut, s'étire en hauteur ; plus large en bas
			float hy = f.y / rp;                       // -1 bas, 1 haut
			float larg = 1.0 - smoothstep(-0.7, 1.0, hy) * 0.75;   // goutte : large en bas, pointue en haut
			float d = length(vec2(f.x / (rp * larg * 0.85), (hy + 0.2) * 0.75));
			if (d > 1.5) {
				discard;   // hors de portée même du bruit le plus fort : pas de calcul
			}
			// langues : bruit étiré en hauteur, plus fort vers le haut (les pointes se détachent)
			n = mfbm2(vec2(f.x / 3.0 + tt * 0.2, (f.y - tt * rp * 1.6) / 10.0) + graine);
			float n2 = mbruit(vec2(f.x / 1.4, (f.y - tt * rp * 2.4) / 4.0) + graine * 3.0);
			i = (1.0 - d) * 1.35 + (n - 0.5) * (1.3 + max(hy, 0.0) * 1.2) + (n2 - 0.5) * 0.55 - max(hy, 0.0) * 0.2;
		}
		i *= force * garde;
		if (i < 0.3) {
			discard;
		}
		c = palier(i);
	} else if (ecole == 1) {
		// GLACE : brume qui tourne lentement + paillettes + aiguilles de givre (crêtes fines)
		if (r > 1.05) {
			discard;
		}
		float a = atan(q.y, q.x);
		vec2 tq = vec2(cos(a + tt * 0.6), sin(a + tt * 0.6)) * length(q);
		float n = mfbm(tq / 5.0 + vec2(tt * 0.3, 0.0) + graine);
		float n2 = mh2(floor(q / 1.3) + floor(tt * 6.0) * 7.31);
		float cr = 1.0 - abs(mbruit(tq / 3.0 + 3.0 + graine) * 2.0 - 1.0);
		i = (1.0 - r * 1.2) * 1.1 + (n - 0.5) * 1.2;
		i *= force * garde;
		if (cr > 0.93 && r < 0.85) {
			c = c0.rgb;
		} else if (n2 > 0.93 && r < 0.9 && force > 0.2) {
			c = c0.rgb;
		} else {
			if (i < 0.32) {
				discard;
			}
			c = palier(i + 0.1);
			al = i > 0.7 ? 1.0 : (i > 0.5 ? 0.66 : 0.33);
		}
	} else if (ecole == 2) {
		// ÉLECTRICITÉ : filaments de plasma = crêtes très fines d'un bruit qui change vite, éclat blanc au centre
		if (r > 1.0) {
			discard;
		}
		float n = mfbm(q / 6.0 + floor(tt * 14.0) * 3.7 + graine);
		float fil = 1.0 - abs(n * 2.0 - 1.0);
		float n2 = mbruit(q / 3.0 + 5.0 + floor(tt * 20.0) * 5.3);
		float fil2 = 1.0 - abs(n2 * 2.0 - 1.0);
		float pres = 1.0 - r;
		if (r < (0.07 + (n - 0.5) * 0.08) * force + 0.02) {
			c = r < 0.04 ? c0.rgb : c1.rgb;
		} else if (fil > 0.94 - pres * 0.06 && pres > 0.05) {
			c = fil > 0.975 ? c0.rgb : c2.rgb;
		} else if (fil2 > 0.95 && pres > 0.25) {
			c = c3.rgb;
		} else if (pres > 0.55 && n > 0.62) {
			c = c4.rgb;
			al = 0.33;
		} else {
			discard;
		}
		if (force < 0.05) {
			discard;
		}
	} else if (ecole == 3) {
		// TÉNÈBRES : vortex, bras en spirale aspirés vers le centre, cœur noir, rehauts violets
		if (r > 1.05) {
			discard;
		}
		float a = atan(q.y, q.x);
		float sp = fract(a / 6.2831 * 3.0 + r * 2.6 + tt * 0.9);
		float n = mfbm(q / 4.0 + vec2(tt * 0.5, -tt * 0.4) + graine);
		float bras = 1.0 - abs(sp - 0.5) * 2.0;           // 1 sur l'axe d'un bras
		i = bras * (1.0 - r) * 1.5 + (n - 0.5) * 0.9 + (1.0 - r) * 0.3;
		i *= force * garde;
		if (r < 0.2 * force) {
			c = c5.rgb;                                    // cœur noir
		} else if (i > 0.95) {
			c = c0.rgb;
		} else if (i > 0.78) {
			c = c1.rgb;
		} else if (i > 0.62) {
			c = c2.rgb;
		} else if (i > 0.48) {
			c = c3.rgb;
		} else if (i > 0.36) {
			c = c4.rgb;
		} else {
			discard;
		}
	} else {
		// SOIN / PROTECTION : halo qui ondule, paillettes
		if (r > 1.0) {
			discard;
		}
		float n = mfbm(q / 5.0 + vec2(tt * 0.4, tt * 0.3) + graine);
		i = (1.0 - r * 1.3) * 1.1 + (n - 0.5) * 1.0;
		i *= force * garde;
		if (i < 0.35) {
			discard;
		}
		c = palier(i);
		al = i > 0.7 ? 1.0 : 0.66;
	}
	// occlusion en dernier : les pixels déjà jetés par le motif ne la paient pas
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
	ALBEDO = c * eclat;
	ALPHA = al;
}
