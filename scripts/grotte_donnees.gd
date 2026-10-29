class_name GrotteDonnees
extends RefCounted
## Données des grottes (kit « grotte ») : une grotte = une table de BRANCHES (lignes médianes avec profils et jonctions) et une liste de
## ZONES (modules thème/rôle qui posent décor et points d'accroche). Le générateur (grotte.gd) et les modules (grotte_modules.gd) ne
## contiennent aucune donnée propre à un lieu : une autre grotte = une autre table + une autre position monde (voir `repaire_hrafn`).
##
## ── BRANCHE ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
##  id          identifiant (clé des zones, des jonctions)
##  theme       libellé libre (documentation) ; les matières viennent de `matieres`
##  wp          points de passage (Vector2, repère local de la grotte, xz) : spline de Catmull-Rom. Le premier point d'une branche
##              qui part d'une jonction (pince_deb) et le dernier d'une branche qui arrive à une jonction (pince_fin) sont posés par
##              le générateur (sur l'anneau du parent) : les écrire quand même (lisibilité).
##  debut/fin   tangente de départ / d'arrivée (Vector2) si la branche n'est pas raccordée à une jonction à cette extrémité
##  profil      lignes [s, y, demi-largeur gauche, demi-largeur droite, hauteur, relief, amplitude des strates] (s en mètres le long
##              de la branche ; y = sol net, repère local de la grotte)
##  marches     [[s, part de paliers de 32 cm (0 = pente lisse, 1 = marches naturelles)]]
##  pas         [[s, espacement des anneaux]] (défaut 2 m ; 0,9 m près d'une jonction)
##  matieres    [[s_fin, "style"]] ; styles : neige, mousse, glace, strate, camp, goulot, cristaux, nu, roche
##  pince_deb   {"de": id du parent, "cote": +1 (la branche part à droite du parent) / -1}
##  pince_fin   {"vers": id du parent, "cote": +1 / -1}
##  cap_deb     "jour" : bouche ouverte sur le jour (la carte « jour ») ; cap_fin : "dome" : fond fermé
##  decalage    abscisse « globale » du début de la branche (monde_sol(s_global, lat) des captures et de l'accès)
##  lac / faille  [s0, s1, s2, s3] : montée (s0→s1) et descente (s2→s3) du lac gelé / de la faille de ciel (côté gauche)
##  graine      graine de la branche (bruit des parois) ; variante : {"largeur": [mini, maxi], "relief": [mini, maxi]} : multiplicateurs
##              tirés de la graine (identité conservée, parois et largeurs légèrement différentes d'une grotte à l'autre)
##
## ── ZONE (module) ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
##  id, branche, s: [s0, s1]       emprise
##  theme                          jeu de décor : entree, boyau, carrefour, mine, lac, repaire, cristaux, cache
##  role                           combat, repos, tresor, recit, ressources, secret, transition, calme, respiration
##  graine, densite                RNG propre au module (variante déterministe) et multiplicateur de densité (concrétions, cristaux…)
##  params                         réglages propres au module (voir grotte_modules.gd)
##  teinte                         [couleur mini, couleur maxi] des lumières de la zone (tirage par graine) ; n_lum : nombre de lumières
##  corniches   [{id, s, lat, longueur, largeur, haut, rampe: "debut"|"fin"}]    dalles praticables (rampe d'accès comprise)
##  ennemis     [{id, type, s, lat, face, tenue, archer, boss, patrouille: [[s, lat]…], options}]
##              « ia » (troll_givre, mage_nordique : monde.SCRIPTS_IA) = ennemi EnnemiBase créé par monde.creer_ennemi, `options` posées avant add_child
##  coffres     [{id, s, lat, lacet, nom, butin: {objet: n}}]
##  ressources  [{id, genre, s, lat, n}]    genres : minerai_fer, minerai_argent, cristal_givre, champignon_lumineux
##  interactions [{id, nom, verbe, texte: [..], evt, objet, s, lat, prop}]
##  meca        [{genre: "mur_fragile", id, s, lat, taille, evt}]
##  lieu        {"evt": "lieu:xxx", "rayon": m}      événement de quête signalé en approchant (centre de la zone)

const CLE_ENTREE := [
	[0.0, 5.5, 7.5, 7.5, 8.5, 0.5, 0.0],
	[5.0, 4.3, 7.0, 7.0, 8.0, 0.5, 0.0],
	[7.0, 3.55, 3.4, 3.6, 4.4, 0.4, 0.0],
	[9.0, 3.0, 3.6, 3.8, 4.8, 0.4, 0.0],
	[14.0, 0.9, 3.2, 3.4, 4.3, 0.35, 0.0],
	[18.0, 0.0, 1.9, 1.9, 3.0, 0.3, 0.0],
	[22.0, -0.6, 1.3, 1.5, 2.5, 0.28, 0.0],
	[24.5, -1.0, 1.5, 1.2, 2.2, 0.28, 0.0],
	[27.0, -1.4, 1.8, 1.6, 3.0, 0.3, 0.0],
	[29.5, -1.8, 3.4, 3.4, 4.8, 0.4, 0.0],
	[33.51, -2.2, 4.8, 4.8, 6.2, 0.5, 0.0],
]

const CLE_MINE := [
	[0.0, -2.2, 4.8, 4.8, 6.2, 0.5, 0.0],
	[6.0, -2.6, 3.4, 3.4, 4.6, 0.4, 0.0],
	[10.0, -3.0, 3.0, 3.0, 4.4, 0.35, 0.3],
	[32.0, -3.7, 3.2, 3.2, 4.6, 0.35, 0.3],
	[34.5, -3.8, 6.0, 6.0, 6.0, 0.4, 0.3],
	[50.0, -4.0, 6.0, 6.0, 6.2, 0.45, 0.3],
	[53.5, -4.1, 3.2, 3.4, 4.2, 0.4, 0.3],
	[55.5, -4.3, 5.8, 3.0, 3.8, 0.7, 0.3],
	[61.5, -4.6, 5.8, 3.0, 3.6, 0.7, 0.3],
	[63.5, -4.7, 3.0, 3.0, 3.8, 0.5, 0.3],
	[66.0, -4.9, 3.0, 3.0, 4.4, 0.35, 0.3],
	[67.0, -5.0, 3.4, 3.4, 4.6, 0.35, 0.3],
	[74.93, -5.5, 5.5, 5.5, 5.0, 0.3, 0.3],
]

const CLE_LAC := [
	[0.0, -2.2, 4.8, 4.8, 6.2, 0.5, 0.0],
	[5.0, -2.5, 3.4, 3.4, 4.6, 0.4, 0.0],
	[8.0, -2.7, 2.0, 2.2, 3.2, 0.3, 0.0],
	[11.0, -2.8, 1.5, 1.7, 3.0, 0.3, 0.0],
	[11.7, -2.9, 4.5, 3.4, 6.5, 0.5, 0.0],
	[12.4, -3.0, 12.0, 3.4, 9.0, 0.9, 0.0],
	[14.4, -3.1, 13.5, 3.6, 10.5, 1.0, 0.0],
	[22.0, -3.25, 14.0, 6.5, 12.5, 1.1, 0.0],
	[26.0, -3.3, 14.0, 7.0, 12.5, 1.1, 0.0],
	[36.0, -3.45, 14.0, 7.0, 11.5, 1.1, 0.0],
	[42.0, -3.5, 12.5, 7.0, 10.0, 1.0, 0.0],
	[44.8, -3.6, 11.0, 3.0, 8.5, 0.8, 0.0],
	[45.4, -3.7, 3.2, 3.0, 4.2, 0.3, 0.3],
	[47.0, -3.8, 2.8, 3.0, 4.0, 0.25, 0.35],
	[52.0, -4.4, 3.0, 3.0, 4.4, 0.25, 0.4],
	[58.0, -4.9, 3.2, 3.0, 4.8, 0.25, 0.4],
	[64.0, -5.0, 3.4, 3.2, 5.0, 0.25, 0.4],
	[66.0, -5.1, 3.4, 3.4, 4.8, 0.25, 0.35],
	[74.07, -5.5, 5.5, 5.5, 5.0, 0.3, 0.3],
]

const CLE_CAMP := [
	[0.0, -5.5, 5.5, 5.5, 5.0, 0.3, 0.3],
	[4.0, -5.5, 6.0, 6.0, 5.5, 0.35, 0.35],
	[10.5, -5.5, 6.0, 6.0, 5.5, 0.35, 0.35],
	[14.0, -5.5, 5.4, 5.4, 4.9, 0.3, 0.3],
	[17.0, -5.5, 5.0, 5.0, 4.6, 0.3, 0.3],
]

const CLE_GOULOT := [
	[0.0, -5.5, 5.0, 5.0, 4.6, 0.3, 0.0],
	[4.0, -5.6, 2.4, 2.4, 3.4, 0.3, 0.0],
	[7.0, -5.8, 2.4, 2.4, 3.6, 0.3, 0.0],
	[9.0, -6.4, 3.0, 3.0, 5.0, 0.4, 0.0],
	[11.0, -7.0, 5.5, 5.0, 8.0, 0.6, 0.0],
	[18.0, -7.6, 5.5, 5.0, 9.0, 0.6, 0.0],
	[22.0, -8.0, 5.0, 5.0, 8.0, 0.55, 0.0],
	[26.0, -8.4, 4.2, 4.2, 6.6, 0.5, 0.0],
	[29.14, -8.5, 3.2, 3.2, 5.5, 0.4, 0.0],
]

const CLE_CACHE := [
	[0.0, -5.5, 5.0, 5.0, 4.6, 0.3, 0.0],
	[3.0, -5.5, 2.2, 2.2, 3.4, 0.3, 0.0],
	[8.0, -5.4, 2.2, 2.2, 3.4, 0.3, 0.0],
	[10.0, -5.4, 4.0, 4.0, 4.2, 0.4, 0.0],
	[16.0, -5.4, 4.2, 4.2, 4.4, 0.4, 0.0],
	[19.89, -5.4, 3.4, 3.4, 4.0, 0.35, 0.0],
]

## Enveloppe d'une tenue de bandit (voir GrotteJeu.TENUES) : rien à régler ici, `tenue` est un indice.
static func repaire_hrafn() -> Dictionary:
	return {
		"id": "grotte",
		"nom": "Repaire de Hrafn",
		"pos_monde": Vector3(20.0, -220.0, 100.0),
		"graine": 2610,
		"bruit": 424,
		"lac_y": -4.7,
		"neige": {"branche": "T1", "s": 5.0},
		"ordre": ["T1", "T2", "A", "B", "C", "H"],
		"branches": [
			{
				"id": "T1", "theme": "entree", "graine": 0, "decalage": 0.0,
				"wp": [Vector2(0, 0), Vector2(0, -7), Vector2(0, -14), Vector2(2, -21), Vector2(1, -28), Vector2(0, -33)],
				"debut": Vector2(0, -1), "fin": Vector2(0, -1),
				"profil": CLE_ENTREE,
				"marches": [[0.0, 0.0], [17.0, 0.0], [20.0, 0.8], [28.0, 0.8], [30.0, 0.0]],
				"matieres": [[17.5, "neige"], [999.0, "mousse"]],
				"cap_deb": "jour",
			},
			{
				"id": "T2", "theme": "repaire", "graine": 5, "decalage": 300.0,
				"wp": [Vector2(0, -91), Vector2(0, -100), Vector2(0, -108)],
				"debut": Vector2(0, -1), "fin": Vector2(0, -1),
				"profil": CLE_CAMP,
				"marches": [[0.0, 0.0]],
				"matieres": [[999.0, "camp"]],
				"pas": [[0.0, 2.0]],
			},
			{
				"id": "A", "theme": "mine", "graine": 3, "decalage": 100.0,
				"wp": [Vector2(0, -33), Vector2(0.6, -38), Vector2(4.2, -44.5), Vector2(11.5, -52.5), Vector2(19, -62), Vector2(20, -72), Vector2(14, -79), Vector2(8, -82.5), Vector2(4.5, -84.3), Vector2(2.2, -86), Vector2(0.9, -88), Vector2(0.25, -89.5), Vector2(0, -91)],
				"profil": CLE_MINE,
				"marches": [[0.0, 0.0], [6.0, 1.0], [67.0, 1.0], [71.0, 0.0]],
				"matieres": [[999.0, "strate"]],
				"pince_deb": {"de": "T1", "cote": 1}, "pince_fin": {"vers": "T2", "cote": 1},
				"variante": {"largeur": [0.96, 1.06], "relief": [0.9, 1.15]},
				"pas": [[0.0, 1.8]],
			},
			{
				"id": "B", "theme": "lac", "graine": 7, "decalage": 200.0,
				"wp": [Vector2(0, -33), Vector2(-0.6, -38), Vector2(-4.2, -44.5), Vector2(-10.5, -52), Vector2(-18, -61), Vector2(-19.5, -72), Vector2(-14, -79.5), Vector2(-8.5, -83), Vector2(-4.5, -85.2), Vector2(-2.2, -86.8), Vector2(-0.9, -88.5), Vector2(-0.25, -89.7), Vector2(0, -91)],
				"profil": CLE_LAC,
				"marches": [[0.0, 0.0], [11.0, 0.0], [12.0, 0.0], [46.0, 0.0], [47.5, 1.0], [62.0, 1.0], [66.0, 0.0]],
				"matieres": [[11.4, "mousse"], [45.2, "glace"], [999.0, "strate"]],
				"pince_deb": {"de": "T1", "cote": -1}, "pince_fin": {"vers": "T2", "cote": -1},
				"lac": [12.0, 15.5, 38.5, 44.0], "faille": [23.0, 24.2, 28.6, 29.8],
				"variante": {"largeur": [0.97, 1.04], "relief": [0.95, 1.1]},
				"pas": [[0.0, 1.8], [12.0, 1.8], [45.4, 2.0]],
			},
			{
				"id": "C", "theme": "cristaux", "graine": 11, "decalage": 400.0,
				"wp": [Vector2(0, -108), Vector2(0.5, -113), Vector2(3, -120), Vector2(6, -128), Vector2(5, -136)],
				"fin": Vector2(-0.2, -1),
				"profil": CLE_GOULOT,
				"marches": [[0.0, 0.0], [9.0, 0.0], [10.0, 1.0], [29.14, 1.0]],
				"matieres": [[8.0, "goulot"], [999.0, "cristaux"]],
				"pince_deb": {"de": "T2", "cote": 1}, "cap_fin": "dome",
				"pas": [[0.0, 2.0], [9.0, 2.2]],
			},
			{
				"id": "H", "theme": "cache", "graine": 13, "decalage": 500.0,
				"wp": [Vector2(0, -108), Vector2(-0.5, -113), Vector2(-4, -119), Vector2(-9, -125)],
				"fin": Vector2(-1, -0.6),
				"profil": CLE_CACHE,
				"marches": [[0.0, 0.0]],
				"matieres": [[999.0, "nu"]],
				"pince_deb": {"de": "T2", "cote": -1}, "cap_fin": "dome",
				"pas": [[0.0, 2.0]],
			},
		],
		"zones": zones_hrafn(),
	}

static func zones_hrafn() -> Array:
	return [
		{"id": "entree", "branche": "T1", "s": [0.0, 14.0], "theme": "entree", "role": "respiration", "graine": 101, "densite": 1.0, "n_lum": 2,
			"teinte": [Color(0.7, 0.82, 1.0), Color(0.78, 0.88, 1.0)],
			"ennemis": [
				{"id": "bandit_4", "type": "sbire", "s": 11.0, "lat": -2.4, "face": "entree", "tenue": 2, "nom": "Guetteur"},
			]},
		{"id": "boyau", "branche": "T1", "s": [14.0, 28.0], "theme": "boyau", "role": "calme", "graine": 102, "densite": 1.0, "n_lum": 2,
			"teinte": [Color(0.5, 0.78, 0.64), Color(0.6, 0.84, 0.7)]},
		{"id": "carrefour", "branche": "T1", "s": [28.0, 33.5], "theme": "carrefour", "role": "repos", "graine": 103, "densite": 1.0, "n_lum": 1,
			"teinte": [Color(1.0, 0.56, 0.24), Color(1.0, 0.62, 0.3)]},
		# --- vieille mine (branche A, à droite)
		{"id": "mine_acces", "branche": "A", "s": [0.0, 10.0], "theme": "mine", "role": "transition", "graine": 201, "densite": 0.7, "n_lum": 1,
			"teinte": [Color(0.38, 0.8, 0.72), Color(0.5, 0.85, 0.7)]},
		{"id": "mine_galerie", "branche": "A", "s": [10.0, 32.0], "theme": "mine", "role": "combat", "graine": 202, "densite": 1.0, "n_lum": 3,
			"params": {"etais": [14.0, 19.5, 25.0, 30.0], "rails": [10.0, 32.0], "chariots": [17.0]},
			"teinte": [Color(0.38, 0.8, 0.72), Color(1.0, 0.6, 0.28)],
			"ennemis": [
				{"id": "bandit_7", "type": "sbire", "s": 14.0, "lat": 0.8, "tenue": 0, "nom": "Rôdeur", "patrouille": [[14.0, 0.8], [22.0, -0.8], [30.0, 0.8]]},
			],
			"ressources": [
				{"id": "fer_a", "genre": "minerai_fer", "s": 22.5, "lat": 3.1, "n": 1},
			]},
		{"id": "mine_chambre", "branche": "A", "s": [32.0, 52.0], "theme": "mine", "role": "ressources", "graine": 203, "densite": 1.0, "n_lum": 4,
			"teinte": [Color(1.0, 0.56, 0.24), Color(1.0, 0.64, 0.32)],
			"ennemis": [
				{"id": "bandit_5", "type": "sbire", "s": 40.0, "lat": 2.2, "tenue": 1, "nom": "Bandit"},
				{"id": "bandit_6", "type": "sbire", "s": 46.0, "lat": -2.6, "tenue": 0, "nom": "Bandit"},
			],
			"coffres": [
				{"id": "mine_a", "s": 48.0, "lat": 5.2, "lacet": -1.5, "nom": "Coffre des mineurs", "butin": {"pieces": 55, "minerai_fer": 2, "table": "coffre_mine", "zone": "grotte"}},
			],
			"ressources": [
				{"id": "fer_b", "genre": "minerai_fer", "s": 37.5, "lat": -5.4, "n": 1},
				{"id": "argent_a", "genre": "minerai_argent", "s": 50.5, "lat": -5.4, "n": 1},
			]},
		{"id": "mine_eboulis", "branche": "A", "s": [53.5, 63.5], "theme": "mine", "role": "secret", "graine": 204, "densite": 1.0, "n_lum": 2,
			"params": {"cote_baie": -1, "passage": 1.5},
			"teinte": [Color(0.38, 0.8, 0.72), Color(0.5, 0.8, 0.8)],
			"ressources": [
				{"id": "argent_rare", "genre": "minerai_argent", "s": 59.5, "lat": -5.2, "n": 3},
			],
			"coffres": [
				{"id": "mine_eboulis", "s": 61.5, "lat": -5.0, "lacet": 1.5, "nom": "Cassette des mineurs", "butin": {"pieces": 35, "amulette_givre": 1, "table": "coffre_mine", "zone": "grotte"}},
			]},
		{"id": "mine_retour", "branche": "A", "s": [63.5, 74.93], "theme": "mine", "role": "repos", "graine": 205, "densite": 0.8, "n_lum": 2,
			"params": {"etais": [67.5], "rails": [64.0, 72.0], "chariots": [69.8]},
			"teinte": [Color(0.38, 0.8, 0.72), Color(1.0, 0.6, 0.28)]},
		# --- caverne du lac (branche B, à gauche)
		{"id": "lac_acces", "branche": "B", "s": [0.0, 11.5], "theme": "lac", "role": "transition", "graine": 301, "densite": 0.8, "n_lum": 1,
			"teinte": [Color(0.5, 0.8, 0.68), Color(0.56, 0.8, 0.74)],
			"ressources": [
				{"id": "champi_a", "genre": "champignon_lumineux", "s": 9.0, "lat": 1.6, "n": 1},
			]},
		{"id": "lac_caverne", "branche": "B", "s": [11.7, 45.0], "theme": "lac", "role": "combat", "graine": 302, "densite": 1.0, "n_lum": 5,
			"teinte": [Color(0.5, 0.72, 1.0), Color(0.56, 0.78, 1.0)],
			"corniches": [
				{"id": "corniche_lac", "s": 23.0, "lat": 3.4, "longueur": 11.0, "largeur": 2.6, "haut": 2.1, "rampe": "fin"},
			],
			"ennemis": [
				{"id": "bandit_8", "type": "sbire", "s": 17.0, "lat": 0.5, "tenue": 1, "nom": "Bandit", "patrouille": [[17.0, 0.5], [30.0, 1.5], [41.0, 0.5]]},
				{"id": "bandit_archer_2", "type": "sbire", "archer": true, "s": 27.5, "lat": 4.6, "sur": "corniche_lac", "tenue": 3, "nom": "Archer bandit", "face": "centre"},
				# troll de givre (scripts/troll_givre_ia.gd) endormi au fond de la caverne, côté paroi : sol plat (±2 cm sur 1 m), à 1,3 m
				# de la patrouille de bandit_8 (capsule 0,75 m libre) ; le rivage (lat < 0) est en pente : il y glissait. Réveil à 9 m.
				{"id": "troll_lac", "ia": "troll_givre", "s": 37.5, "lat": 2.1, "face": "entree", "nom": "Troll de givre", "options": {"dort": true}},
			],
			"ressources": [
				{"id": "champi_b", "genre": "champignon_lumineux", "s": 25.0, "lat": 4.9, "sur": "corniche_lac", "n": 1},
				{"id": "champi_c", "genre": "champignon_lumineux", "s": 40.5, "lat": 2.9, "n": 1},
				{"id": "cristal_lac", "genre": "cristal_givre", "s": 41.5, "lat": -3.5, "n": 1},
			],
			"coffres": [
				{"id": "corniche", "s": 32.0, "lat": 5.35, "lacet": 3.14, "sur": "corniche_lac", "nom": "Coffre sur la corniche", "butin": {"pieces": 70, "poussiere_tombe": 2, "table": "coffre_bandit", "zone": "grotte"}},
			]},
		{"id": "lac_ilot", "branche": "B", "s": [30.0, 40.0], "theme": "lac", "role": "recit", "graine": 303, "densite": 0.6, "n_lum": 1,
			"params": {"ilot_s": 35.0, "ilot_lat": -9.0, "ilot_r": 3.1},
			"lieu": {"evt": "lieu:ilot_sigrun", "rayon": 4.0, "s": 35.0, "lat": -9.0},
			"teinte": [Color(0.5, 0.72, 1.0), Color(0.6, 0.8, 1.0)],
			"interactions": [
				{"id": "journal_sigrun", "nom": "Journal de Solveig", "verbe": "Lire le journal de Solveig", "s": 35.0, "lat": -9.5, "prop": "journal", "evt": "ramasse:journal_sigrun", "objet": "journal_sigrun",
					"texte_cle": "journal_sigrun",
					"texte": ["Journal de Solveig, cheffe des mineurs de Skarnholt.", "Elle y parle d’un filon rare derrière l’éboulement et de sa broche pour Grima."]},
			],
			"coffres": [
				{"id": "ilot", "s": 34.0, "lat": -8.2, "lacet": 0.6, "nom": "Sac de l’expédition", "butin": {"pieces": 30, "broche_sigrun": 1}},
			]},
		{"id": "lac_sortie", "branche": "B", "s": [45.4, 66.0], "theme": "mine", "role": "recit", "graine": 304, "densite": 0.9, "n_lum": 3,
			"params": {"etais": [52.0, 59.5], "rails": [], "chariots": []},
			"teinte": [Color(0.38, 0.8, 0.72), Color(0.4, 0.85, 0.7)]},
		{"id": "lac_approche", "branche": "B", "s": [66.0, 74.07], "theme": "repaire", "role": "transition", "graine": 305, "densite": 0.8, "n_lum": 1,
			"teinte": [Color(1.0, 0.56, 0.24), Color(1.0, 0.62, 0.3)]},
		# --- camp de Hrafn
		{"id": "camp", "branche": "T2", "s": [0.0, 17.0], "theme": "repaire", "role": "combat", "graine": 401, "densite": 1.0, "n_lum": 3,
			"teinte": [Color(1.0, 0.54, 0.22), Color(1.0, 0.62, 0.3)],
			"corniches": [
				{"id": "corniche_camp", "s": 6.5, "lat": 3.0, "longueur": 6.0, "largeur": 2.2, "haut": 1.6, "rampe": "debut"},
			],
			"lieu": {"evt": "lieu:camp_hrafn", "rayon": 9.0, "s": 8.0, "lat": 0.0},
			"ennemis": [
				{"id": "bandit_0", "type": "sbire", "s": 3.5, "lat": -1.4, "tenue": 0, "nom": "Bandit"},
				{"id": "bandit_1", "type": "sbire", "s": 6.2, "lat": 2.6, "tenue": 1, "nom": "Bandit", "casque": "casque_nasal"},
				{"id": "bandit_2", "type": "sbire", "s": 9.8, "lat": -2.4, "tenue": 2, "nom": "Bandit"},
				{"id": "bandit_3", "type": "sbire", "s": 12.0, "lat": 1.6, "tenue": 3, "nom": "Bandit"},
				{"id": "bandit_archer_0", "type": "sbire", "archer": true, "s": 8.5, "lat": 4.1, "sur": "corniche_camp", "tenue": 3, "nom": "Archer bandit", "face": "centre"},
				{"id": "bandit_archer_1", "type": "sbire", "archer": true, "s": 11.5, "lat": 4.1, "sur": "corniche_camp", "tenue": 1, "nom": "Archer bandit", "face": "centre"},
				{"id": "hrafn", "type": "guerrier", "boss": "hrafn", "s": 14.2, "lat": -0.2, "tenue": 4, "nom": "Hrafn, chef des bandits", "face": "entree"},
			],
			"coffres": [
				{"id": "camp_a", "s": 14.6, "lat": -3.6, "lacet": 0.3, "nom": "Coffre du butin", "butin": {"pieces": 90, "amulette_givre": 1, "table": "coffre_bandit", "zone": "grotte"}},
				{"id": "camp_b", "s": 15.0, "lat": 3.9, "lacet": -0.4, "nom": "Coffre du butin", "butin": {"pieces": 60, "os_draugr": 2, "poussiere_tombe": 1, "table": "coffre_bandit", "zone": "grotte"}},
			]},
		{"id": "goulot", "branche": "C", "s": [0.0, 9.0], "theme": "repaire", "role": "transition", "graine": 501, "densite": 0.6, "n_lum": 0,
			"params": {"rideau": 3.6}},
		{"id": "cristaux", "branche": "C", "s": [9.0, 29.14], "theme": "cristaux", "role": "tresor", "graine": 502, "densite": 1.0, "n_lum": 3,
			"teinte": [Color(0.36, 0.62, 1.0), Color(0.5, 0.8, 1.0)],
			"ressources": [
				{"id": "cristal_a", "genre": "cristal_givre", "s": 14.0, "lat": -3.4, "n": 1},
				{"id": "cristal_b", "genre": "cristal_givre", "s": 17.5, "lat": 3.2, "n": 1},
				{"id": "cristal_c", "genre": "cristal_givre", "s": 23.0, "lat": -3.2, "n": 1},
				{"id": "cristal_d", "genre": "cristal_givre", "s": 25.5, "lat": 2.6, "n": 1},
			],
			"coffres": [
				{"id": "fond", "s": 27.0, "lat": 2.2, "lacet": -0.5, "nom": "Coffre de l’explorateur", "butin": {"pieces": 120, "amulette_givre": 1, "table": "coffre_crypte_riche", "zone": "grotte"}},
			]},
		{"id": "cache", "branche": "H", "s": [3.0, 19.89], "theme": "cache", "role": "tresor", "graine": 601, "densite": 1.0, "n_lum": 2,
			"teinte": [Color(1.0, 0.6, 0.3), Color(1.0, 0.66, 0.36)],
			"meca": [
				{"genre": "mur_fragile", "id": "mur_cache", "s": 5.4, "lat": 0.0, "taille": Vector3(4.6, 3.4, 0.7), "evt": "grotte:mur_cache"},
			],
			"interactions": [
				{"id": "registre_hrafn", "nom": "Registre de Hrafn", "verbe": "Prendre le registre de Hrafn", "s": 14.0, "lat": 0.4, "prop": "registre", "evt": "ramasse:registre_hrafn", "objet": "registre_hrafn",
					"texte_cle": "registre_hrafn",
					"texte": ["Un registre aux pages grasses : les convois de Skarnholt, jour après jour.", "Rapportez-le au village."]},
			],
			"coffres": [
				{"id": "cache", "s": 16.5, "lat": -1.8, "lacet": 1.2, "nom": "Cachette de Hrafn", "butin": {"pieces": 200, "amulette_givre": 1, "lame_antique": 1}},
			],
			# L9 : objet unique exposé (GrotteJeu._uniques : chevalet + épée posés à part, hors du décor : rien d'autre ne bouge)
			"uniques": [
				{"objet": "epee_hrafn", "s": 18.4, "lat": 1.3, "presentoir": "presentoir_socle"},
			]},
	]

## Variante déterministe d'une table de grotte (kit) : mêmes branches, mêmes zones, mêmes accroches ; seules les GRAINES changent
## (bruit des parois, largeurs et reliefs dans une plage plus large, détails de décor, teinte des lumières) et la position monde.
## Les garanties (coque étanche, passages, accroches atteignables) doivent tenir pour toute variante : voir test_grotte.gd --variante=<k>.
static func variante(def: Dictionary, k: int, pos_monde := Vector3(-300.0, -220.0, 260.0)) -> Dictionary:
	var d: Dictionary = def.duplicate(true)
	d["pos_monde"] = pos_monde
	d["graine"] = int(d["graine"]) + k * 101
	d["bruit"] = int(d["bruit"]) + k * 17
	for b: Dictionary in d["branches"]:
		b["graine"] = int(b["graine"]) + k * 29 + 1
		b["variante"] = {"largeur": [0.9, 1.1], "relief": [0.8, 1.3]}
	for z: Dictionary in d["zones"]:
		z["graine"] = int(z["graine"]) + k * 13
	return d
