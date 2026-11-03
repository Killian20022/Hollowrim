// AURAS et BOULES procédurales de la couche fine (scripts/magie/gestion_magie.gd, _aura_fine / _boule_fine) : carré
// tourné vers la caméra, centré sur la paume (ou le projectile), rayon `rayon` m. Le motif est calculé AU PIXEL de la
// couche fine, en pixels du monde (même taille de motif de près comme de loin) puis seuillé en paliers francs :
//   feu        : langues qui montent (cœur blanc, jaune, orange, rouge, bord sombre)
//   glace      : brume de givre qui tourne, paillettes blanches, aiguilles de givre
//   électricité: filaments de plasma (crêtes fines d'un bruit), éclat blanc au centre
//   ténèbres   : vortex (spirale noire aux bras violets), aspiré vers le centre
//   soin / protection : halo doré / bleu pâle qui ondule
// `forme` 1 = boule (projectile, explosion) : masque rond bouillonnant au lieu des flammes montantes.
// `forme` 2 = FLAMME TENUE (cœur de l'aura de feu, sort prêt) : goutte vivante, langues, braises et fumée au sommet.
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
			// FLAMME TENUE au creux de la main (sort de feu prêt, retour « elle fait trop plastique », 2026-11-02) : plus de
			// sphère lisse, une flamme VIVANTE en paliers francs. Repère normalisé u (1 = rayon du carré) ; la flamme est
			// assise sous le centre (la paume), ses langues montent, la fumée passe au-dessus.
			//   - goutte qui ondule (la colonne se tord, plus fort vers la pointe), largeur qui respire ;
			//   - langues : bruit qui MONTE vite, déchiré au bord (trous, pointes qui se détachent) ;
			//   - cœur blanc-jaune petit (palier c0), orange et rouge francs, liseré sombre ;
			//   - braises : pixels isolés qui montent en zigzag ; fumée : volutes sombres au sommet, 2 paliers d'opacité.
			// FLAMME RUNIQUE (brief 2026-11-03, référence flamme_runique.png) : colonne VERTICALE qui se tord (pas une boule) ;
			// 4 langues qui s'enroulent en spirale autour d'un axe qui ondule, une petite spirale vive à la base, fils fins
			// qui s'échappent en volutes, braises. Tout en paliers francs au pixel du monde.
			vec2 u = q / rp;
			float h = clamp((u.y + 0.62) / (1.3 * (0.84 + 0.22 * clamp(force, 0.0, 1.3))), 0.0, 1.0);   // 0 base, 1 pointe (plus haute en charge)
			float sv = 1.0 + 0.05 * sin(tt * 7.0) * sin(tt * 2.9 + graine);             // respiration
			// axe : S ample qui ondule et dérive, la pointe se détache et flotte
			float sway = ((mbruit(vec2(h * 1.6 - tt * 0.8, graine * 3.0)) - 0.5) * 0.6 + 0.12 * sin(tt * 1.7 + h * 3.0 + graine)) * h * (0.3 + 0.7 * h);
			// enveloppe : base LARGE et ronde, qui monte et s'effile en pointe
			float renv = (0.26 + 0.26 * sin(3.14159 * pow(h, 0.7))) * (1.0 - 0.45 * h) * sv;
			float pied = smoothstep(-0.66, -0.56, u.y);
			float best = 0.0;
			float lum = 0.0;
			float filet = 0.0;
			// 3 grandes volutes qui s'enroulent l'une dans l'autre
			for (int k = 0; k < 3; k++) {
				float fk = float(k);
				float lk = 0.72 + 0.28 * mh2(vec2(fk * 7.3, floor(graine) + 2.0 + floor(tt * 0.3 + fk * 2.1)));
				float hk = min(h / lk, 1.0);
				float ang = fk * 2.0944 + graine * 2.0 + h * 4.2 - tt * (1.7 + 0.25 * fk);
				float zf = cos(ang);
				float xk = sway + renv * 0.95 * sin(ang) * (1.0 - 0.45 * hk);
				float wk = renv * (0.46 + 0.16 * zf) * pow(1.0 - hk, 0.7) * lk + 0.01;
				float dn = (mbruit(vec2(xk * 5.0 + fk * 3.1 + graine, h * 4.0 - tt * (2.6 + fk * 0.4))) - 0.5) * 0.28 * (0.3 + h) * renv;
				float dx = abs(u.x - xk + dn);
				float it = 1.0 - dx / wk;
				float arete = smoothstep(0.4, 0.95, it) * (0.5 + 0.5 * zf);
				float v = clamp(it, 0.0, 1.0) * (0.8 + 0.2 * zf) + arete * 0.2;
				if (v > best) {
					best = v;
					lum = arete;
				}
				// filets fins orange qui longent la volute, de chaque côté
				float fo = wk * 1.5 + 0.02;
				float f1 = 1.0 - smoothstep(0.0, 0.012, abs(dx - fo));
				filet = max(filet, f1 * smoothstep(0.08, 0.3, h) * (1.0 - smoothstep(0.75, 1.0, hk)) * (0.6 + 0.3 * zf));
			}
			// corps : masse orange ronde au pied, qui relie les volutes (une seule flamme)
			float cx = abs(u.x - sway * 0.5 + (mbruit(vec2(h * 5.0 - tt * 2.4, graine + 4.0)) - 0.5) * 0.16) / (renv * 1.0 + 0.02);
			float corps = clamp(1.0 - cx, 0.0, 1.0) * pow(1.0 - h, 1.3) * 0.8 * (0.7 + 0.4 * mbruit(vec2(u.x * 7.0, h * 5.0 - tt * 3.4 + graine)));
			best = max(best, corps);
			best *= pied;
			lum *= pied;
			filet *= pied;
			// cœur blanc-jaune en bas-centre : point chaud rond, quelques bras de spirale sur son pourtour
			vec2 bq = vec2(u.x - sway * 0.2, (u.y + 0.40) * 1.1);
			float rb = length(bq);
			float ab = atan(bq.y, bq.x);
			float bras = 0.5 + 0.5 * sin(ab * 2.0 + rb * 16.0 - tt * 5.0);
			float base = (1.0 - smoothstep(0.0, 0.24, rb)) * (0.92 + 0.1 * bras);
			float gr = mbruit(vec2(q.x / 1.6, (q.y - tt * rp * 2.4) / 1.3) + graine * 5.0) - 0.5;
			i = max(best * (0.98 - 0.4 * h) + lum * 0.1, max(base * 1.2, filet * 0.8)) + gr * 0.16 * (0.4 + h);
			i *= force * (0.93 + 0.09 * sin(tt * 15.0 + graine) * sin(tt * 5.3));
			i *= 1.0 - smoothstep(0.72, 0.94, carre);        // fondu avant le bord du carré : jamais de langue tranchée
			if (i > 0.32) {
				c = i > 1.2 ? c0.rgb : palier(min(i, 1.14));
			} else {
				// braises : petites, éparses, qui montent autour de la flamme
				vec2 qb = vec2(q.x + sin(q.y * 0.35 + tt * 4.0) * 1.2, q.y - tt * rp * 0.75);
				vec2 cb = floor(qb);
				float hb = mh2(cb + floor(graine * 13.0));
				float zone_b = smoothstep(-0.2, 0.2, u.y) * (1.0 - smoothstep(0.65, 0.9, u.y)) * (1.0 - smoothstep(0.3, 0.7, abs(u.x)));
				if (hb > 1.0 - 0.008 * zone_b * force) {
					c = mh2(cb + 3.1) > 0.5 ? c1.rgb : c2.rgb;
				} else {
					discard;
				}
			}
			if (carre > 0.97) {
				discard;
			}
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
		if (forme != 2) {
			i *= force * garde;
			if (i < 0.3) {
				discard;
			}
			c = palier(i);
		}
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
