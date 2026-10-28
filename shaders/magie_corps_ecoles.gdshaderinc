// Écoles de l'agent B (électricité, glace, ténèbres) sur le VOILE partagé des corps (magie_corps.gdshader, inclus par lui).
// Mêmes règles que le feu : un seul matériau partagé, état par paramètres D'INSTANCE, paliers francs, motif en cases.
// Les index d'instance sont FIXÉS (instance_index) : sans eux, Godot numérote les paramètres d'instance de chaque shader à
// partir de 0 et ceux du voile écrasaient ceux du matériau du personnage (eclair du shader ps1_draugr, c_peau… de perso).
//
//   mc_ecoles (14) : x = givre (0..1), y = choc (0..1), z = ténèbres (0..1),
//                    w = 256 × arrondi(traces de choc × 255) + arrondi(pâleur × 255)   (deux octets tassés)
//   mc_pt     (15) : xyz = point du monde d'où part le givre / où les arcs ont frappé, w = rayon (m) couvert par le givre
instance uniform vec4 mc_ecoles : instance_index(14) = vec4(0.0);
instance uniform vec4 mc_pt : instance_index(15) = vec4(0.0);

float e_h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float e_bruit(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(e_h3(i), e_h3(i + vec3(1, 0, 0)), f.x), mix(e_h3(i + vec3(0, 1, 0)), e_h3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(e_h3(i + vec3(0, 0, 1)), e_h3(i + vec3(1, 0, 1)), f.x), mix(e_h3(i + vec3(0, 1, 1)), e_h3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

bool ecoles_actives() {
	return mc_ecoles.x + mc_ecoles.y + mc_ecoles.z + mc_ecoles.w > 0.002;
}

// Sortie prémultipliée : `add` = couleur ajoutée (déjà × son opacité), `a` = part du fond remplacée.
void voile_ecoles(vec3 p_monde, vec3 p_obj, vec3 n_monde, vec3 n_vue, float cases, float t, inout vec3 add, inout float a) {
	if (!ecoles_actives()) {
		return;
	}
	float bord = 1.0 - abs(normalize(n_vue).z);
	vec3 qc = floor(p_obj * cases * 0.5);                     // cases du motif (pixels francs)
	float w = mc_ecoles.w;
	float traces = floor(w / 256.0) / 255.0;
	float paleur = mod(w, 256.0) / 255.0;
	float di = length(p_monde - mc_pt.xyz);
	// ---------------------------------------------------------------- GIVRE : la texture blanchit depuis le point touché
	float gel = mc_ecoles.x;
	if (gel > 0.002) {
		float r = max(mc_pt.w, 0.001);
		// bord du givre irrégulier (bruit en cases) : il « gagne » la surface au lieu d'un disque net
		float ir = e_bruit(qc * 0.35) * 0.35 + e_bruit(qc * 0.9) * 0.15;
		float m = 1.0 - smoothstep(r * (0.55 + ir), r * (0.8 + ir), di);
		m *= gel;
		// (2026-10-28) plaques : zones bien prises / à peine givrées (même idée que la croûte de la coque)
		float pl = e_bruit(p_obj * 3.2 + vec3(1.7, 0.3, 4.1)) * 0.75 + e_bruit(p_obj * 7.5) * 0.25;
		m *= mix(0.35, 1.0, smoothstep(0.3, 0.6, pl + n_monde.y * 0.15));
		// dessus des formes (épaules, casque) plus blanc : le givre se dépose
		float dessus = clamp(n_monde.y * 0.5 + 0.5, 0.0, 1.0);
		// (2026-10-28, intensité) givre plus couvrant et plus clair, liseré blanc-bleu sur le bord de la silhouette
		float ag = m * (0.3 + 0.22 * dessus + 0.2 * step(0.7, bord));
		ag = floor(ag * 4.0 + 0.25) / 4.0;
		vec3 c = mix(vec3(0.46, 0.62, 0.78), vec3(0.8, 0.91, 1.0), step(0.5, dessus + bord * 0.4));
		// éclats de cristal : cases rares, blanc pur, qui scintillent
		float sc = e_h3(qc + floor(t * 3.0) * 0.37);
		float eclat_g = step(0.95, sc) * step(0.4, m);
		float liser = step(0.78, bord) * step(0.3, m) * 0.5;
		add += c * ag * 0.9 + vec3(0.85, 0.95, 1.0) * eclat_g * 0.85 + vec3(0.62, 0.84, 1.0) * liser * gel;
		a = max(a, ag * 0.85);
	}
	// ---------------------------------------------------------------- CHOC : contour qui crépite, veines bleues, traces
	float ch = mc_ecoles.y;
	if (ch > 0.002) {
		float f1 = step(0.38, e_h3(qc * 0.21 + floor(t * 26.0)));   // papillotement (par cases, 26 Hz)
		float contour = step(0.72, bord) * f1;
		// veines : crêtes fines d'un bruit qui défile (petites décharges qui parcourent le corps)
		float v = e_bruit(p_obj * 9.0 + vec3(0.0, t * 6.0, t * 4.0));
		float veine = step(0.93, 1.0 - abs(v * 2.0 - 1.0)) * step(0.5, e_h3(qc + floor(t * 18.0)));
		// petit cœur bleu-blanc au point touché (les arcs en partent), rongé par cases : pas une tache ronde
		float coeur_c = exp(-(di * di) / 0.012) * step(0.35, e_h3(qc + floor(t * 20.0)));
		float k = max(max(contour * 0.7, veine * 0.8), coeur_c) * ch;
		k = ceil(k * 3.0 - 0.05) / 3.0;
		add += mix(vec3(0.29, 0.23, 0.82), vec3(0.94, 0.95, 1.0), step(0.6, k)) * k * 1.2;
	}
	if (traces > 0.004) {
		// traces de choc : figures ramifiées sombres autour du point touché, qui s'estompent
		float rr = 1.0 - abs(e_bruit(p_obj * 14.0) * 2.0 - 1.0);
		float br = step(0.86, rr) * exp(-(di * di) / 0.18);
		float at = floor(traces * br * 3.0 + 0.3) / 3.0 * 0.55;
		add += vec3(0.02, 0.02, 0.05) * at + vec3(0.18, 0.16, 0.5) * at * step(0.6, traces) * 0.4;
		a = max(a, at);
	}
	// ---------------------------------------------------------------- TÉNÈBRES : contour violet, veines sombres, pâleur
	float om = mc_ecoles.z;
	if (om > 0.002) {
		float palp = 0.75 + 0.25 * sin(t * 5.0);
		// (2026-10-28, intensité) contour plus large et lueur violette DANS le corps (la vie qu'on arrache), en paliers
		float contour = (step(0.58, bord) * 0.7 + step(0.82, bord) * 0.3) * om * palp;
		contour = ceil(contour * 3.0 - 0.05) / 3.0;
		add += mix(vec3(0.42, 0.12, 0.66), vec3(0.86, 0.6, 1.0), step(0.85, bord)) * contour * 1.2;
		float interne = floor(om * palp * (0.35 + 0.4 * bord) * 3.0 + 0.2) / 3.0;
		add += vec3(0.2, 0.05, 0.34) * interne;
		// lueur violette au point d'où la vie est arrachée (paliers, palpite)
		// (bord rongé par le bruit en cases : jamais une tache ronde)
		float pres = exp(-(di * di) / 0.09) * om * palp * step(0.42, e_bruit(qc * 0.6 + vec3(0.0, -t * 2.0, 0.0)));
		float ap2 = floor(pres * 3.0) / 3.0;
		add += mix(vec3(0.42, 0.12, 0.7), vec3(0.86, 0.6, 1.0), step(0.6, ap2)) * ap2 * 0.9;
		float v = e_bruit(p_obj * 7.0 + vec3(0.0, -t * 1.5, 0.0));
		float veine = step(0.88, 1.0 - abs(v * 2.0 - 1.0)) * om;
		float av = floor(veine * 3.0 + 0.3) / 3.0 * 0.5;
		// veines : sombres, une sur deux luit (violet) — elles se voient sur la lueur interne
		float vl = step(0.5, e_bruit(p_obj * 2.0 + vec3(t * 0.7)));
		add += mix(vec3(0.05, 0.01, 0.08), vec3(0.55, 0.22, 0.9), vl) * av;
		a = max(a, av * (1.0 - vl * 0.5));
	}
	if (paleur > 0.004) {
		// la victime pâlit : mélange vers un gris froid (jamais un aplat : 40 % au plus)
		// (la sortie est prémultipliée : couleur × opacité, sur un fond × (1 − opacité))
		float ap = floor(paleur * 4.0 + 0.2) / 4.0 * 0.22;
		add += vec3(0.26, 0.25, 0.3) * ap;
		a = max(a, ap);
	}
}
