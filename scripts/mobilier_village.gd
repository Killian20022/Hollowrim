class_name MobilierVillage
extends Node3D
## Lot C7a : mobilier du village v2 (modules Blender sources_blender/scripts/mobilier_village.py → assets/modeles/mobilier_village.dat).
## Référence : references/village_v2_planche.png (vues 1-3, vignettes « éléments de décoration »). Positions : docs/PLAN_VILLAGE_V2.md.
## Toutes les pièces d'une même matière sont FUSIONNÉES en un seul maillage (≈ 10 appels de dessin) ; seuls les tissus des
## bannières restent des nœuds (balancement au vent). Lumière réelle : le brasero de la place seulement ; les braseros des
## terrasses et les flammes sont émissifs. Collisions simples (cylindres, boîtes) sur tout ce qui se heurte.

const DAT := "res://assets/modeles/mobilier_village.dat"
const ACCROCHE_TISSU := Vector3(0.55, 3.72, 0.0)   # haut du tissu dans le repère du mât (rapport Blender)
const BRAISES_Y := 1.05
const PORTEE := 55.0

## [module, x, z, lacet° (0 = l'avant regarde le nord, -Z), échelle]
const POSES := [
	["puits", 42.0, 38.0, 15.0, 1.0],
	["etal", 51.5, 30.5, 180.0, 1.0], ["etal", 54.2, 33.4, 90.0, 1.0], ["etal", 52.5, 42.5, 60.0, 1.0],
	["banniere", 38.0, 28.5, 180.0, 1.0], ["banniere", 50.0, 28.5, 180.0, 1.0], ["banniere", 36.0, 46.0, 0.0, 1.0],
	["banniere", 48.0, 47.5, 0.0, 1.0], ["banniere", 23.5, 25.8, 48.0, 1.12], ["banniere", 41.0, 65.4, 0.0, 1.0],
	["brasero", 36.0, 39.0, 0.0, 1.0], ["brasero", 39.6, 71.2, 0.0, 1.0], ["brasero", 39.5, 77.0, 0.0, 1.0],
	["banc", 32.8, 40.5, -90.0, 1.0], ["banc", 47.5, 46.6, 0.0, 1.0], ["banc", 40.6, 29.6, 180.0, 1.0], ["banc", 50.2, 86.0, 90.0, 1.0],
	["tonneau_a", 49.4, 31.3, 20.0, 1.0], ["caisse_a", 49.5, 30.1, 35.0, 1.0], ["caisse_b", 53.6, 31.7, -10.0, 1.0],
	["tonneau_b", 55.4, 35.4, 140.0, 1.0], ["tonneau_a", 54.7, 40.5, 0.0, 1.0], ["caisse_b", 50.4, 44.6, 25.0, 1.0],
	["tonneau_a", 46.6, 54.2, 0.0, 1.0], ["tonneau_b", 47.3, 53.5, 70.0, 1.0], ["caisse_a", 41.3, 54.4, -20.0, 1.0],
	["tonneau_a", 28.3, 51.71, 0.0, 1.0], ["caisse_b", 27.25, 51.71, 0.0, 1.0],   # passe D : sortis du mur de la maison de pierre (25,5 ; 55,5), ruelle vers Grima
	["tonneau_a", 39.3, 69.3, 0.0, 1.0], ["caisse_a", 38.9, 70.3, 15.0, 1.0], ["tonneau_b", 50.0, 79.2, 200.0, 1.0],
	["charrette", 57.0, 26.5, 8.0, 1.0],
	["tas_bois", 58.0, 51.6, 0.0, 1.0], ["tas_bois", 53.5, 88.5, 90.0, 1.0],
	# L7 : densité (petits groupes contre les tonneaux et caisses d'avant : rien sur les passages)
	["caisse_c", 50.3, 29.6, 50.0, 1.0], ["sacs", 53.7, 30.6, 15.0, 1.0], ["tonneau_c", 55.9, 36.2, 0.0, 1.0],
	["caisse_c", 55.3, 41.2, -25.0, 1.0], ["sacs", 51.4, 44.9, 80.0, 1.0], ["caisse_c", 46.4, 55.0, 10.0, 1.0],
	["sacs", 40.4, 54.6, -60.0, 1.0], ["caisse_c", 40.0, 68.8, 30.0, 1.0], ["tonneau_c", 49.3, 79.9, 0.0, 1.0],
]
## Bâti hybride (bati/hybride) : poses déplacées quand le bâti Quaternius est actif (« module x z » -> nouvelle position x, z) :
## le brasero de la haute rue était juste devant la porte est de H3 (porte du kit sur le pignon, marches comprises).
const DEPLACES_Q := {"brasero 39.6 71.2": Vector2(39.9, 73.6), "caisse_a 38.9 70.3": Vector2(39.1, 69.7)}
## Lot 3 (props/placement) : props Quaternius du marché, dans le repère d'un étal de POSES (indice parmi les « etal », 0 = 51,5 ; 30,5) :
## [prop, étal, position locale (y 0 = au sol, recalé sur le relief ; 0,9 = sur la planche avant du comptoir), lacet° local, collision].
## Repère de l'étal : comptoir z -0,96 .. -0,14, dessus 0,9 / 0,83 (côté client, au nord pour lacet 0), marchand entre le comptoir et les poteaux arrière (z 0,95).
## Rien devant le comptoir (z < -0,9) : le client y passe ; réserves derrière ou au bout du comptoir.
const POSES_Q := [
	# étal 0 : primeurs (pommes, carottes) ; marchandises d'avant sur le comptoir : caisse x -1,33..-1,03, peaux x 0,1..0,6
	["q_cageot_pommes", 0, Vector3(-0.5, 0.9, -0.62), 4.0, false], ["q_cageot_carottes", 0, Vector3(1.05, 0.9, -0.62), -3.0, false],
	["q_carotte", 0, Vector3(0.75, 0.9, -0.88), 70.0, false],
	["q_tonneau", 0, Vector3(-0.95, 0.0, 0.45), 30.0, true],
	["q_cageot_vide", 0, Vector3(0.75, 0.0, 0.45), 85.0, false], ["q_cageot_vide", 0, Vector3(0.78, 0.24, 0.47), 95.0, false],
	# étal 1 : cordier et sacs
	["q_corde_2", 1, Vector3(-0.5, 0.9, -0.6), 10.0, false], ["q_bourse", 1, Vector3(0.95, 0.9, -0.62), 200.0, false],
	["q_sac", 1, Vector3(-0.9, 0.0, 0.45), 15.0, true], ["q_sac", 1, Vector3(-0.35, 0.0, 0.5), -40.0, true],
	["q_corde_3", 1, Vector3(0.75, 0.0, 0.45), 30.0, false], ["q_corde_1", 1, Vector3(0.9, 0.11, 0.42), 80.0, false],
	# étal 2 : réserve et cageots
	["q_cageot_carottes", 2, Vector3(-0.5, 0.9, -0.62), 0.0, false], ["q_cageot_vide", 2, Vector3(1.05, 0.9, -0.62), 3.0, false],
	["q_carotte", 2, Vector3(1.0, 0.94, -0.6), 20.0, false], ["q_carotte", 2, Vector3(1.15, 0.94, -0.66), 110.0, false],
	["q_caisse", 2, Vector3(-0.85, 0.0, 0.45), 12.0, true], ["q_tonneau", 2, Vector3(0.85, 0.0, 0.45), 0.0, true],
	["q_caisse", 2, Vector3(1.95, 0.0, -0.4), -20.0, true], ["q_cageot_pommes", 2, Vector3(1.95, 0.7, -0.4), -15.0, false],
]
## props/remplacement : DENSIFICATION du marché et des ruelles (props Quaternius supplémentaires, coordonnées MONDE : étal = -1 ; y = hauteur
## au-dessus du sol), en petits groupes contre les tas existants (rien sur les passages). [prop, -1, Vector3(x, y, z), lacet°, collision]
const POSES_D := [
	["q_tonneau", -1, Vector3(51.0, 0.0, 45.9), 0.0, true], ["q_tonneau_2", -1, Vector3(40.2, 0.0, 55.4), 30.0, true],
	["q_cageot_vide", -1, Vector3(55.7, 0.0, 42.3), 10.0, false], ["q_cageot_vide", -1, Vector3(55.7, 0.24, 42.3), 40.0, false],
	["q_corde_2", -1, Vector3(49.1, 0.0, 32.4), 40.0, false], ["q_bourse", -1, Vector3(52.0, 0.0, 44.0), 30.0, false],
	["q_sac_debout", -1, Vector3(47.3, 0.0, 55.2), 0.0, false], ["q_sac", -1, Vector3(46.0, 0.0, 55.0), 60.0, false],
	["q_souche", -1, Vector3(56.2, 0.0, 49.6), 0.0, true], ["q_hache_outil", -1, Vector3(56.2, 0.6, 49.6), 70.0, false],
	["q_tronc", -1, Vector3(55.6, 0.0, 47.2), 80.0, false],
	["q_seau_bois", -1, Vector3(41.6, 0.0, 55.4), 0.0, false], ["q_caisse", -1, Vector3(38.4, 0.0, 70.0), 20.0, true],
	["q_corde_1", -1, Vector3(50.6, 0.0, 80.4), 100.0, false],
]
## Lot 4 (props/lot4) : NOURRITURE des étals, mêmes conventions que POSES_Q (étal i, position locale dans le repère de l'étal ; les hauteurs 0,9
## sont ramenées à 0,8 comme les autres) : étal 0 = maraîcher, étal 1 = boucher/cordier, étal 2 = poissonnier. Posé seulement si PropsQuaternius.lot4.
const POSES_L4 := [
	# étal 0 : maraîcher, v3 en TAS lisibles devant le poteau : choux au fond (3 + 1 dessus), navets (4 + 1), pommes en pyramide devant (6 + 3)
	["q_chou", 0, Vector3(0.3, 0.9, -0.52), 20.0, false], ["q_chou", 0, Vector3(0.5, 0.9, -0.54), 80.0, false],
	["q_chou", 0, Vector3(0.4, 0.9, -0.68), 140.0, false], ["q_chou", 0, Vector3(0.4, 1.04, -0.58), 50.0, false],
	["q_navet", 0, Vector3(0.66, 0.9, -0.5), 0.0, false], ["q_navet", 0, Vector3(0.77, 0.9, -0.6), 40.0, false],
	["q_navet", 0, Vector3(0.66, 0.9, -0.7), 110.0, false], ["q_navet", 0, Vector3(0.62, 0.9, -0.84), 200.0, false],
	["q_navet", 0, Vector3(0.71, 0.97, -0.62), 70.0, false],
	["q_pomme", 0, Vector3(0.12, 0.9, -0.84), 0.0, false], ["q_pomme", 0, Vector3(0.22, 0.9, -0.84), 60.0, false],
	["q_pomme_verte", 0, Vector3(0.32, 0.9, -0.84), 0.0, false], ["q_pomme", 0, Vector3(0.12, 0.9, -0.95), 120.0, false],
	["q_pomme", 0, Vector3(0.22, 0.9, -0.95), 200.0, false], ["q_pomme", 0, Vector3(0.32, 0.9, -0.95), 30.0, false],
	["q_pomme", 0, Vector3(0.17, 0.98, -0.895), 90.0, false], ["q_pomme_verte", 0, Vector3(0.27, 0.98, -0.895), 10.0, false],
	["q_pomme", 0, Vector3(0.22, 1.05, -0.895), 150.0, false],
	["q_jarre", 0, Vector3(-0.55, 0.0, 0.5), 10.0, false], ["q_bouteille_1", 0, Vector3(-0.2, 0.0, 0.5), 0.0, false],
	# étal 1 : boucher (viande, lard, saucisses, cuisses) à côté des cordes
	["q_viande", 1, Vector3(0.15, 0.9, -0.55), 15.0, false], ["q_viande", 1, Vector3(0.38, 0.9, -0.6), -30.0, false],
	["q_lard", 1, Vector3(0.2, 0.9, -0.8), 5.0, false], ["q_cuisse", 1, Vector3(0.55, 0.92, -0.78), 70.0, false, {"argile": "cuir"}],
	["q_saucisse", 1, Vector3(0.45, 0.9, -0.38), 20.0, false, {"argile": "peau"}], ["q_saucisse_crue", 1, Vector3(0.58, 0.9, -0.4), -10.0, false],
	["q_jarre", 1, Vector3(1.2, 0.0, 0.5), 0.0, false],
	["q_viande", 1, Vector3(0.26, 0.93, -0.58), 60.0, false], ["q_viande", 1, Vector3(0.0, 0.9, -0.62), 100.0, false],      # v3 : pile de pièces
	["q_lard", 1, Vector3(0.05, 0.92, -0.82), -15.0, false], ["q_saucisse", 1, Vector3(0.5, 0.9, -0.35), 25.0, false, {"argile": "peau"}],
	# étal 1 : barre sous l'auvent, côté clients, avec quatre cuisses fumées et quatre grappes de saucisses PENDUES (6e = matières, 7e = pré-rotation, 8e = échelle avant le x1,3)
	["q_poutre_ronde", 1, Vector3(0.0, 1.87, -0.62), 0.0, false, {"bois": "cuir"}, Basis.IDENTITY, Vector3(2.15, 0.5, 0.5)],
	["q_cuisse", 1, Vector3(-1.1, 1.66, -0.62), 0.0, false, {"argile": "laine_q"}, Basis(Vector3.BACK, -PI * 0.5), Vector3.ONE * 2.0],
	["q_cuisse", 1, Vector3(-0.4, 1.66, -0.62), 0.0, false, {"argile": "laine_q"}, Basis(Vector3.BACK, -PI * 0.5), Vector3.ONE * 2.0],
	["q_cuisse", 1, Vector3(0.3, 1.66, -0.62), 0.0, false, {"argile": "laine_q"}, Basis(Vector3.BACK, -PI * 0.5), Vector3.ONE * 2.0],
	["q_cuisse", 1, Vector3(1.0, 1.66, -0.62), 0.0, false, {"argile": "laine_q"}, Basis(Vector3.BACK, -PI * 0.5), Vector3.ONE * 2.0],
	["q_saucisse", 1, Vector3(-0.79, 1.64, -0.62), -24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	["q_saucisse_crue", 1, Vector3(-0.71, 1.64, -0.62), 24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	["q_saucisse", 1, Vector3(-0.09, 1.64, -0.62), -24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	["q_saucisse_crue", 1, Vector3(-0.010000000000000002, 1.64, -0.62), 24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	["q_saucisse", 1, Vector3(0.61, 1.64, -0.62), -24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	["q_saucisse_crue", 1, Vector3(0.6900000000000001, 1.64, -0.62), 24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	["q_saucisse", 1, Vector3(1.26, 1.64, -0.62), -24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	["q_saucisse_crue", 1, Vector3(1.34, 1.64, -0.62), 24.0, false, {"argile": "laine_q"}, Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.7],
	# étal 2 : poissonnier (poissons et arêtes sur la planche, jarres de saumure derrière)
	["q_poisson", 2, Vector3(0.1, 0.9, -0.55), 10.0, false], ["q_poisson", 2, Vector3(0.3, 0.9, -0.72), -15.0, false],
	["q_poisson", 2, Vector3(0.15, 0.9, -0.9), 170.0, false], ["q_aretes", 2, Vector3(0.6, 0.9, -0.5), 20.0, false],
	["q_poisson", 2, Vector3(0.2, 0.93, -0.63), 30.0, false], ["q_poisson", 2, Vector3(0.0, 0.9, -0.72), -40.0, false],      # v3 : tas de poissons
	["q_poisson", 2, Vector3(0.12, 0.95, -0.7), 160.0, false], ["q_poisson", 2, Vector3(0.35, 0.92, -0.85), 5.0, false],
	["q_jarre", 2, Vector3(-0.2, 0.0, 0.5), 20.0, false], ["q_jarre", 2, Vector3(0.1, 0.0, 0.55), 100.0, false],
]
## Matières du lot 4 -> matières du mobilier (la laine des viandes et pommes = rouge sourd ; l'herbe des légumes = foin teinté vert).
const MATS_L4 := {"laine": "laine_q", "herbe": "herbe", "argile": "argile"}
## Matières des props Quaternius -> matières du mobilier (fer MAT : fer du village, déjà terne ; voir _materiau pour lin et os).
## Même table pour les props posés par substitut() dans le village (matière du prop -> matière de PropsQuaternius.mats_village).
const MATS_Q_V := {"fer": "fer", "bois": "bois", "jute": "jute", "lin": "lin", "os": "os", "pierre": "pierre", "or": "fer", "noir": "fer", "toile": "lin", "laine": "lin", "argile": "argile"}
const MATS_Q := {"bois": "planches_h", "fer": "fer", "jute": "foin", "lin": "lin", "os": "os", "pierre": "pierre_brute", "or": "fer", "noir": "fer"}
## Primeurs : les fruits et légumes du pack Standard sont blancs à l'origine et sortaient en « fer » bleu-noir : terre cuite orangée.
const PRIMEURS := ["q_cageot_pommes", "q_cageot_carottes", "q_carotte", "q_tonneau_pommes"]

## Collisions par module : ["cyl", rayon, hauteur, centre] ou ["boite", taille, centre] (repère du module).
const COLLISIONS := {
	"puits": [["cyl", 1.72, 0.85, Vector3(0, 0.42, 0)], ["cyl", 0.1, 3.0, Vector3(1.3, 1.5, 1.3)], ["cyl", 0.1, 3.0, Vector3(-1.3, 1.5, 1.3)],
		["cyl", 0.1, 3.0, Vector3(1.3, 1.5, -1.3)], ["cyl", 0.1, 3.0, Vector3(-1.3, 1.5, -1.3)]],
	"etal": [["boite", Vector3(3.1, 1.0, 0.9), Vector3(0, 0.5, -0.45)], ["cyl", 0.09, 2.3, Vector3(-1.5, 1.15, 0.95)], ["cyl", 0.09, 2.3, Vector3(1.5, 1.15, 0.95)]],
	"banniere": [["cyl", 0.12, 4.0, Vector3(0, 2.0, 0)]],
	"brasero": [["cyl", 0.46, 1.1, Vector3(0, 0.55, 0)]],
	"banc": [["boite", Vector3(1.8, 0.48, 0.38), Vector3(0, 0.24, 0)]],
	"tonneau_a": [["cyl", 0.31, 0.86, Vector3(0, 0.43, 0)]],
	"tonneau_b": [["cyl", 0.25, 0.71, Vector3(0, 0.355, 0)]],
	"caisse_a": [["boite", Vector3(0.66, 0.65, 0.66), Vector3(0, 0.325, 0)]],
	"caisse_b": [["boite", Vector3(0.88, 0.6, 0.68), Vector3(0, 0.3, 0)]],
	"charrette": [["boite", Vector3(1.5, 1.0, 2.2), Vector3(0, 0.5, 0.25)]],
	"tas_bois": [["boite", Vector3(1.95, 1.1, 1.05), Vector3(0, 0.55, 0)]],
	"tonneau_c": [["cyl", 0.31, 0.81, Vector3(0, 0.405, 0)]],
	"caisse_c": [["boite", Vector3(0.48, 0.45, 0.43), Vector3(0, 0.225, 0)]],
	"sacs": [["boite", Vector3(0.8, 0.55, 0.6), Vector3(0, 0.275, -0.1)]],
}

## props/remplacement (2026-11-03) : chaque module maison remplacé par des props Quaternius (Fantasy Props, Medieval Village, Modular Dungeon,
## Ultimate Nature), à la même emprise : [prop, taille cible (X, Y, Z du prop ; 0 = libre)]. Les composites (étal, puits, tas de bois…)
## sont assemblés dans substitut() (KITBASH). `--sans-remplacement` : anciens modules.
const SUBST_FIT := {
	"banc": ["q_banc", Vector3(1.8, 0.46, 0.4)],
	"tonneau_a": ["q_tonneau", Vector3(0.62, 0.86, 0.62)], "tonneau_b": ["q_tonneau_2", Vector3(0.5, 0.71, 0.5)], "tonneau_c": ["q_tonneau", Vector3(0.6, 0.81, 0.6)],
	"caisse_a": ["q_caisse", Vector3(0.66, 0.65, 0.66)], "caisse_b": ["q_caisse_2", Vector3(0.88, 0.6, 0.68)], "caisse_c": ["q_caisse", Vector3(0.48, 0.45, 0.43)],
	"charrette": ["q_chariot", Vector3(1.1, 0.9, 2.3)],
	"forge_billot": ["q_billot_enclume", Vector3(0.6, 0.65, 0.55)], "forge_meule": ["q_pierre_aiguiser", Vector3(0.9, 1.0, 0.65)],
	"tronc_banc": ["q_tronc", Vector3(0.46, 0.45, 2.4)],
}
## Parties des anciens modules gardées avec leur remplaçant (braises émissives des foyers : aucun équivalent Quaternius lumineux).
const SUBST_GARDE := {"forge_foyer": ["braises"], "feu_camp": ["braises"]}

static func _fit(nom: String, pos: Vector3, lacet: float, taille: Vector3) -> Transform3D:
	var bb := PropsQuaternius.boite(nom)
	var sc := Vector3.ONE
	var somme := 0.0
	var n := 0
	for a in 3:
		if taille[a] > 0.0:
			sc[a] = taille[a] / maxf(bb.size[a], 0.001)
			somme += sc[a]
			n += 1
	for a in 3:
		if taille[a] <= 0.0:
			sc[a] = somme / maxf(n, 1)
	return Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(sc), pos)

## Remplaçants Quaternius d'un module : [[prop, Transform3D dans le repère du module, mats], …] ; vide = pas de remplacement.
static func substitut(mod: String) -> Array:
	if not PropsQuaternius.remplace:
		return []
	if SUBST_FIT.has(mod):
		var e: Array = SUBST_FIT[mod]
		if not PropsQuaternius.existe(e[0]):
			return []
		return [[e[0], _fit(e[0], Vector3.ZERO, 0.0, e[1]) if mod != "tronc_banc" else _fit(e[0], Vector3(0, 0.0, 0), PI * 0.5, Vector3(0.46, 0.45, 2.4)), {}]]
	var r := []
	match mod:
		"sacs":
			r = [["q_sac", _fit("q_sac", Vector3(-0.2, 0, 0.0), 0.4, Vector3(0.45, 0.5, 0.4)), {}], ["q_sac", _fit("q_sac", Vector3(0.22, 0, -0.1), -0.5, Vector3(0.42, 0.45, 0.38)), {}],
				["q_sac_debout", _fit("q_sac_debout", Vector3(0.0, 0, 0.2), 0.0, Vector3(0.0, 0.5, 0.0)), {}]]
		"tas_bois":      # KITBASH : 8 colonnes x 4 rangs de bûches Quaternius/kitbash, couchées le long de Z
			for rg in 4:
				for c in 8 - (rg % 2):
					var x := -0.88 + c * 0.25 + (rg % 2) * 0.125
					r.append(["q_buche", Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.04 * ((c + rg) % 3)) * Basis.from_scale(Vector3(1.7, 1.15, 1.15)), Vector3(x, 0.12 + rg * 0.22, 0.0)), {}])
		"etal":      # deux étals Quaternius côte à côte (3,1 m de comptoir), clients côté -Z
			for sx in [-0.78, 0.78]:
				r.append(["q_etal", _fit("q_etal", Vector3(sx, 0, -0.45), 0.0, Vector3(1.55, 2.4, 1.1)), {"bois": "planches_l4", "lin": "lin_l4"} if PropsQuaternius.lot4 else {}])
		"banniere":
			r = [["q_banniere", _fit("q_banniere", Vector3.ZERO, 0.0, Vector3(1.8, 3.95, 0.4)), {}]]
		"puits":      # KITBASH : margelle = 8 dalles de bordure Quaternius debout + chapiteaux de briques, 4 poteaux et poutres rondes, toit de planches, seau et corde
			for i in 8:
				var a := i * TAU / 8.0
				var phi := -(a + PI * 0.5)
				var rad := Vector3(cos(a), 0, sin(a))
				r.append(["q_bordure_1", Transform3D(Basis(Vector3.UP, phi) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.66, 2.3, 1.21)), rad * 1.62 + Vector3(0, 0.425, 0)), {}])
				r.append(["q_brique_" + str(1 + i % 4), Transform3D(Basis(Vector3.UP, phi) * Basis.from_scale(Vector3(1.9, 0.8, 1.4)), rad * 1.5 + Vector3(0, 0.82, 0)), {}])
			for sx in [-1.3, 1.3]:
				for sz in [-1.3, 1.3]:
					r.append(["q_poutre_ronde", Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(3.0, 0.7, 0.7)), Vector3(sx, 1.5, sz)), {}])
			r.append(["q_poutre_ronde", Transform3D(Basis.from_scale(Vector3(2.9, 0.9, 0.9)), Vector3(0, 2.9, 0)), {}])
			r.append(["q_poutre_ronde", Transform3D(Basis.from_scale(Vector3(2.9, 0.6, 0.6)), Vector3(0, 1.9, 0)), {}])
			for sg in [-1.0, 1.0]:
				r.append(["q_planches_sol", Transform3D(Basis(Vector3.RIGHT, sg * 0.62) * Basis.from_scale(Vector3(3.2, 1.0, 0.95)), Vector3(0, 3.25 - 0.0, sg * 0.5)), {}, Vector3(1, -1, 1)])
			r.append(["q_seau_bois", _fit("q_seau_bois", Vector3(0.55, 0.88, 0.7), 0.5, Vector3(0.43, 0.29, 0.39)), {}])
			r.append(["q_corde_1", _fit("q_corde_1", Vector3(-0.85, 0.88, -0.9), 0.0, Vector3(0.6, 0, 0.6)), {}])
		"enclos_poteau":
			r = [["", Transform3D.IDENTITY, {}]]      # les barrières Quaternius portent leurs poteaux
		"enclos_lisse":
			r = [["", Transform3D.IDENTITY, {}]]
		"meule_foin":      # KITBASH : pile de sacs de foin (sac Quaternius, jute -> foin), 3 + 2 + 1
			for k in 6:
				var rang := 0 if k < 3 else (1 if k < 5 else 2)
				var idx := k if k < 3 else (k - 3 if k < 5 else 0)
				var nb := 3 if rang == 0 else (2 if rang == 1 else 1)
				var x := (idx - (nb - 1) * 0.5) * 0.62
				r.append(["q_sac", _fit("q_sac", Vector3(x, rang * 0.38, 0.0), 0.4 * k, Vector3(0.7, 0.62, 0.55)), {}])
		"sechoir_peaux":      # KITBASH : deux poteaux (poutre ronde), traverse, peaux = tissu de bannière Quaternius teinté lin
			for sx in [-1.2, 1.2]:
				r.append(["q_poutre_ronde", Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(1.9, 0.8, 0.8)), Vector3(sx, 0.95, 0)), {}])
			r.append(["q_poutre_ronde", Transform3D(Basis.from_scale(Vector3(2.7, 0.7, 0.7)), Vector3(0, 1.75, 0)), {}])
			for k in 3:
				r.append(["q_banniere_toile", Transform3D(Basis(Vector3.UP, 0.15 * (k - 1)) * Basis.from_scale(Vector3(0.7, 0.45, 1.0)), Vector3(-0.8 + k * 0.8, 0.7, 0.04)), {"toile": "jute"}, Vector3(1, 1, -1)])
		"feu_camp":      # KITBASH : couronne de briques Quaternius (9) + bûcher Woodfire ; braises de l'ancien module gardées
			for i in 9:
				var a := i * TAU / 9.0
				r.append(["q_brique_" + str(1 + i % 4), Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(1.5, 1.2, 1.3)), Vector3(cos(a), 0, sin(a)) * 0.85), {}])
			if PropsQuaternius.lot4 and PropsQuaternius.existe("q_feu_bois"):      # lot 4 : bûches de feu de camp Quaternius (Survival) à la place du bûcher
				r.append(["q_feu_bois", _fit("q_feu_bois", Vector3.ZERO, 0.6, Vector3(0.95, 0.5, 0.95)), {}])
				# marmite de camp posée contre la couronne, tas de rondins et hache plantée dans un rondin (sobre : 3 pièces + la tente un peu plus loin)
				r.append(["q_marmite_camp", Transform3D(Basis(Vector3.UP, 2.2), Vector3(-1.35, 0, 0.55)), {}])
				r.append(["q_rondin", Transform3D(Basis(Vector3.UP, 0.5), Vector3(1.35, 0, 1.15)), {}])
				r.append(["q_rondin", Transform3D(Basis(Vector3.UP, 0.35), Vector3(1.4, 0.3, 1.15)), {}])
				r.append(["q_hache_camp", Transform3D(Basis(Vector3.UP, 0.9) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(1.2, 0.68, 1.3)), {"laine": "cuir"}])
				r.append(["q_tente", Transform3D(Basis(Vector3.UP, 0.0), Vector3(0.5, 0, -5.4)), {"jute": "lin"}])      # tente de toile, entrée vers le feu
			else:
				r.append(["q_bucher", _fit("q_bucher", Vector3.ZERO, 0.6, Vector3(0.9, 0.55, 0.9)), {}])
		"forge_foyer":      # KITBASH : muret de briques Quaternius (deux rangs), braises de l'ancien module gardées
			for rg in 2:
				for i in 7:
					var x := -0.45 + i * 0.15
					r.append(["q_brique_" + str(1 + (i + rg) % 4), Transform3D(Basis(Vector3.UP, 0.1 * i) * Basis.from_scale(Vector3(0.7, 0.9, 0.6)), Vector3(x, rg * 0.2, -0.38 if i % 2 == 0 else -0.4)), {}])
					r.append(["q_brique_" + str(1 + (i + rg) % 4), Transform3D(Basis(Vector3.UP, 0.1 * i) * Basis.from_scale(Vector3(0.7, 0.9, 0.6)), Vector3(x, rg * 0.2, 0.38)), {}])
				for sx in [-0.5, 0.5]:
					r.append(["q_brique_2", Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(0.9, 0.9, 0.7)), Vector3(sx, rg * 0.2, 0.0)), {}])
			r.append(["q_bucher", _fit("q_bucher", Vector3(0, 0.1, 0), 0.3, Vector3(0.6, 0.35, 0.6)), {}])
	return r

var monde: Node
var _corps: StaticBody3D
var _tissus: Array = []      # [Node3D, phase]
var _lumieres: Array = []    # [OmniLight3D, énergie, phase]
var _t := 0.0

static func creer(monde_: Node) -> MobilierVillage:
	var m := MobilierVillage.new()
	m.name = "MobilierVillage"
	m.monde = monde_
	monde_.add_child(m)
	m._construire()
	return m

static func _materiau(nom: String) -> Material:
	match nom:
		# E/pierre_chaude : margelle du puits, socle du brasero en pierre chaude comme le bâti (étaient gris-bleu (0.9, 0.92, 0.98), (0.92, 0.94, 1.0))
		"pierre_brute": return TexturesBati.m_pierre_brute_e(Color(1.0, 0.95, 0.86))
		"pierre_fine": return TexturesBati.m_pierre_fine_e(Color(1.03, 0.97, 0.88))
		# L7 : bois plus clair (était (0.85, 0.8, 0.75) : tonneaux presque noirs à distance de jeu), proche des planches du bâti
		"planches_h": return TexturesBati.m_planches_e(Color(1.0, 0.95, 0.88))
		"planches_v": return TexturesBati.m_bois_debout_e(Color(1.0, 0.95, 0.88))
		"planches_l4": return TexturesBati.m_planches_e(Color(1.75, 1.6, 1.4))      # lot 4 : comptoir et montants des étals plus clairs (sans lumière en plus)
		"fer": return TexturesBati.m_fer_e(Color(0.7, 0.7, 0.75))
		"cuir": return TexturesBati.m_cuir_e()
		"foin": return TexturesBati.m_foin_e()
		"braises": return TexturesBati.m_braises()
		"lin", "os", "argile":      # props Quaternius : textures de la crypte sur le shader du bâti (comme les intérieurs)
			if not TexturesBati._cache.has(nom):
				var img: Image = ResourceLoader.load("res://assets/crypte/%s.res" % nom)
				TexturesBati._cache[nom] = [ImageTexture.create_from_image(img), TexturesBati.relief_neutre()]
			var ml := TexturesBati.materiau(nom, Color(1.35, 1.1, 0.92) if nom == "argile" else Color(1.0, 0.96, 0.9), 64.0, 0.4, "neige_e")      # primeurs plus vives à l'ombre de l'auvent
			ml.set_shader_parameter("proche", Vector2(4.0, 14.0))
			return ml
		"lin_l4":      # lot 4 : toile des auvents plus claire (même texture que « lin », teinte relevée, sans lumière)
			if not TexturesBati._cache.has("lin"):
				TexturesBati._cache["lin"] = [ImageTexture.create_from_image(ResourceLoader.load("res://assets/crypte/lin.res")), TexturesBati.relief_neutre()]
			var mc := TexturesBati.materiau("lin", Color(1.3, 1.24, 1.14), 64.0, 0.4, "neige_e")
			mc.set_shader_parameter("proche", Vector2(4.0, 14.0))
			return mc
		"laine_q":      # lot 4 : viande, pommes, lard (laine rouge sourde de la crypte, comme les intérieurs)
			if not TexturesBati._cache.has("laine"):
				TexturesBati._cache["laine"] = [ImageTexture.create_from_image(ResourceLoader.load("res://assets/crypte/laine.res")), TexturesBati.relief_neutre()]
			var mw := TexturesBati.materiau("laine", Color(1.6, 1.2, 1.05), 64.0, 0.4, "neige_e")
			mw.set_shader_parameter("proche", Vector2(4.0, 14.0))
			return mw
		"herbe":      # lot 4 : légumes (foin teinté vert, comme les bouquets des intérieurs)
			return TexturesBati.m_foin_e(Color(0.55, 0.78, 0.45))
		"tenture_rouge", "peau":
			return TexturesBati.materiau(nom, Color.WHITE, 32.0, 0.6)   # tissus modélisés double face
	return TexturesBati.m_planches_e()

## Lit le .dat : {"module/matiere": [PackedVector3Array positions, PackedColorArray couleurs]} (ordre Godot des sommets).
## L7 : lu une fois (cache) et d'un bloc par entrée (était un get_buffer par sommet) ; le poste de forge, l'enclos et le feu de
## camp réutilisent le même cache (poser_dans / noeud_modules).
static var _cache := {}
static func charger() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var res := {}
	var f := FileAccess.open(DAT, FileAccess.READ)
	if f == null:
		push_error("MobilierVillage : %s introuvable" % DAT)
		return res
	var n := f.get_32()
	for _i in n:
		var ln := f.get_8()
		var nom := f.get_buffer(ln).get_string_from_utf8()
		var nv := f.get_32()
		var pos := PackedVector3Array()
		var col := PackedColorArray()
		pos.resize(nv)
		col.resize(nv)
		var d := f.get_buffer(nv * 28).to_float32_array()
		for k in nv:
			var o := k * 7
			pos[k] = Vector3(d[o], d[o + 1], d[o + 2])
			col[k] = Color(d[o + 3], d[o + 4], d[o + 5], d[o + 6])
		# Godot : face avant = sens horaire → on inverse chaque triangle (comme SolV2)
		for t in range(0, nv, 3):
			var p := pos[t + 1]
			pos[t + 1] = pos[t + 2]
			pos[t + 2] = p
			var c := col[t + 1]
			col[t + 1] = col[t + 2]
			col[t + 2] = c
		res[nom] = [pos, col]
	_cache = res
	return res

## Tableaux indexés (sommets dédoublonnés, normales plates) d'une entrée « module/matière », pour Village._ajouter : cache.
static var _indexes := {}
static func arrays_de(nom: String) -> Array:
	if _indexes.has(nom):
		return _indexes[nom]
	var d: Array = charger()[nom]
	var pos: PackedVector3Array = d[0]
	var col: PackedColorArray = d[1]
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var cc := PackedColorArray()
	var ii := PackedInt32Array()
	var vus := {}
	for t in range(0, pos.size(), 3):
		var nf := (pos[t + 2] - pos[t]).cross(pos[t + 1] - pos[t])   # sens horaire (Godot) : normale sortante
		if nf.length_squared() < 1e-14:
			continue
		nf = nf.normalized()
		for j in 3:
			var cle := [pos[t + j], nf, col[t + j]]
			var k: int = vus.get(cle, -1)
			if k < 0:
				k = v.size()
				vus[cle] = k
				v.append(pos[t + j])
				nn.append(nf)
				cc.append(col[t + j])
			ii.append(k)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nn
	a[Mesh.ARRAY_COLOR] = cc
	a[Mesh.ARRAY_INDEX] = ii
	_indexes[nom] = a
	return a

## Matières de mobilier_village.py → matières du village (même lot de fusion que le bâti : aucun appel de dessin en plus).
static func mats_village(v) -> Dictionary:
	return {"planches_h": v.m_poutres_h, "planches_v": v.m_poutres, "fer": v.m_fer, "pierre_brute": v.m_brute, "pierre_fine": v.m_pierre_fine,
		"cuir": v.m_cuir, "peau": v.m_cuir, "foin": v.m_foin, "braises": v.m_braises}

## Pose un module dans un nœud du village (Village._ajouter : fusionné par matière avec le bâti). `xf` dans le repère de `parent`.
static func poser_dans(v, parent: Node3D, mod: String, xf: Transform3D, mats := {}) -> void:
	if mats.is_empty():
		mats = mats_village(v)
	var pre := mod + "/"
	var sub := substitut(mod)
	var garde: Array = SUBST_GARDE.get(mod, [])
	if mod == "enclos_lisse" and xf.origin.y > 0.75:
		return      # les deux lisses d'une barrière Quaternius n'en font qu'une
	var ents: Array = sub
	if mod == "enclos_lisse" and not sub.is_empty():      # barrière Quaternius en tronçons de ~2 m (poteaux non étirés)
		var l := xf.basis.get_scale().x
		var nseg := maxi(1, roundi(l / 2.0))
		ents = []
		for i in nseg:
			ents.append(["q_barriere_bois", _fit("q_barriere_bois", Vector3((i + 0.5) * l / nseg - l * 0.5, 0.0, 0.0), 0.0, Vector3(l / nseg, 1.0, 0.14)), {}])
		xf = Transform3D(xf.basis.orthonormalized(), Vector3(xf.origin.x, 0.0, xf.origin.z))
	for e: Array in ents:
		if e[0] == "" or not PropsQuaternius.existe(e[0]):
			continue
		var mv := PropsQuaternius.mats_village(v)
		for m: Array in PropsQuaternius.morceaux(e[0]):
			var cible: String = (e[2] as Dictionary).get(m[0], MATS_Q_V.get(m[0], m[0]))
			v._ajouter(parent, m[1], xf * (e[1] as Transform3D), mv[cible] if mv.has(cible) else mv["bois"])
			if e.size() > 3:      # pièce plane : seconde face (même plan, orientation inverse)
				v._ajouter(parent, m[1], xf * (e[1] as Transform3D) * Transform3D(Basis.from_scale(e[3]), Vector3.ZERO), mv[cible] if mv.has(cible) else mv["bois"])
	for nom: String in charger():
		if nom.begins_with(pre):
			if not sub.is_empty() and not (nom.substr(pre.length()) in garde):
				continue
			v._ajouter(parent, arrays_de(nom), xf, mats[nom.substr(pre.length())])

## Nœud autonome (hors du village : feu de camp du cercle) : poses [module, Transform3D] fusionnées par matière, matières C7a.
static func noeud_modules(poses: Array, nom_noeud: String) -> Node3D:
	var racine := Node3D.new()
	racine.name = nom_noeud
	var st_par := {}
	var donnees := charger()
	for p: Array in poses:
		var pre: String = String(p[0]) + "/"
		var sub := substitut(String(p[0]))
		var garde: Array = SUBST_GARDE.get(String(p[0]), [])
		for e: Array in sub:
			if e[0] == "" or not PropsQuaternius.existe(e[0]):
				continue
			for t: Array in PropsQuaternius.triangles(e[0]):
				var mq: String = (e[2] as Dictionary).get(t[0], MATS_Q.get(t[0], "planches_h"))
				if not st_par.has(mq):
					var stq := SurfaceTool.new()
					stq.begin(Mesh.PRIMITIVE_TRIANGLES)
					st_par[mq] = stq
				(st_par[mq] as SurfaceTool).append_from(PropsQuaternius.maillage_brut(e[0], t[0]), 0, (p[1] as Transform3D) * (e[1] as Transform3D))
				if e.size() > 3:
					(st_par[mq] as SurfaceTool).append_from(PropsQuaternius.maillage_brut(e[0], t[0]), 0, (p[1] as Transform3D) * (e[1] as Transform3D) * Transform3D(Basis.from_scale(e[3]), Vector3.ZERO))
		for nom: String in donnees:
			if not nom.begins_with(pre):
				continue
			if not sub.is_empty() and not (nom.substr(pre.length()) in garde):
				continue
			var mat := nom.substr(pre.length())
			if not st_par.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st_par[mat] = st
			var d: Array = donnees[nom]
			var pos: PackedVector3Array = d[0]
			var col: PackedColorArray = d[1]
			var xf: Transform3D = p[1]
			for k in pos.size():
				(st_par[mat] as SurfaceTool).set_color(col[k])
				(st_par[mat] as SurfaceTool).add_vertex(xf * pos[k])
	for mat: String in st_par:
		var st: SurfaceTool = st_par[mat]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Mobilier_" + mat
		mi.mesh = st.commit()
		mi.material_override = _materiau(mat)
		racine.add_child(mi)
	return racine

func _sol(x: float, z: float) -> float:
	return DetailsSol.hauteur_maillage(monde, x, z)

## Hauteur de pose : le plus bas des 5 points de l'emprise (rien ne flotte), un peu enfoncé.
func _sol_bas(x: float, z: float, r: float) -> float:
	var h := _sol(x, z)
	for d: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		h = minf(h, _sol(x + d.x, z + d.y))
	return h - 0.03

func _construire() -> void:
	var t0 := Time.get_ticks_msec()
	var donnees := charger()
	if donnees.is_empty():
		return
	_corps = StaticBody3D.new()
	_corps.name = "CollisionsMobilier"
	add_child(_corps)
	var fusion := {}   # matière → SurfaceTool
	var tris := 0
	var num := 0
	for pose: Array in POSES:
		num += 1
		var mod: String = pose[0]
		var x: float = pose[1]
		var z: float = pose[2]
		var cle_q := "%s %s %s" % [mod, x, z]
		if VillageBatiQ.actif and DEPLACES_Q.has(cle_q):   # bâti hybride : objet sorti d'une porte du kit
			x = DEPLACES_Q[cle_q].x
			z = DEPLACES_Q[cle_q].y
		var s: float = pose[4]
		var r_emprise: float = {"puits": 1.6, "etal": 1.4, "charrette": 1.2, "tas_bois": 0.9, "banc": 0.8, "sacs": 0.4}.get(mod, 0.3)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(pose[3])).scaled(Vector3.ONE * s), Vector3(x, _sol_bas(x, z, r_emprise), z))
		var sub := substitut(mod)
		var garde: Array = SUBST_GARDE.get(mod, [])
		if not sub.is_empty():
			tris += _poser_sub(fusion, sub, xf, mod)
		for nom: String in donnees:
			var morceaux := nom.split("/")
			if morceaux[0] != mod:
				continue
			if not sub.is_empty() and not (morceaux[1] in garde):
				continue
			if not fusion.has(morceaux[1]):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				fusion[morceaux[1]] = st
			_ajouter(fusion[morceaux[1]], donnees[nom], xf)
			tris += (donnees[nom][0] as PackedVector3Array).size() / 3
		if mod == "banniere":
			var piv := Node3D.new()
			piv.name = "Tissu"
			piv.transform = xf * Transform3D(Basis(), ACCROCHE_TISSU)
			add_child(piv)
			if not sub.is_empty() and PropsQuaternius.existe("q_banniere_toile"):      # tissu Quaternius (Banner_1_Cloth) : même balancement
				var xt := _fit("q_banniere_toile", Vector3.ZERO, 0.0, Vector3(1.0, 3.7, 0.0))
				piv.transform = xf * Transform3D(Basis(), Vector3(0, 3.82, 0.0))
				for t: Array in PropsQuaternius.triangles("q_banniere_toile"):
					var stq := SurfaceTool.new()
					stq.begin(Mesh.PRIMITIVE_TRIANGLES)
					stq.append_from(PropsQuaternius.maillage_brut("q_banniere_toile", t[0]), 0, Transform3D(xt.basis, Vector3(0, -3.7, 0.0)))
					stq.append_from(PropsQuaternius.maillage_brut("q_banniere_toile", t[0]), 0, Transform3D(xt.basis * Basis.from_scale(Vector3(1, 1, -1)), Vector3(0, -3.7, 0.0)))
					stq.generate_normals()
					var mq := MeshInstance3D.new()
					mq.mesh = stq.commit()
					mq.material_override = _materiau("tenture_rouge")
					mq.visibility_range_end = PORTEE
					piv.add_child(mq)
					tris += (t[1] as PackedVector3Array).size() / 3
				_tissus.append([piv, randf() * TAU, piv.rotation])
			for nom: String in donnees:
				if sub.is_empty() and nom.begins_with("banniere_tissu/"):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					_ajouter(st, donnees[nom], Transform3D.IDENTITY)
					st.generate_normals()
					var mi := MeshInstance3D.new()
					mi.mesh = st.commit()
					mi.material_override = _materiau(nom.split("/")[1])
					mi.visibility_range_end = PORTEE
					piv.add_child(mi)
					tris += (donnees[nom][0] as PackedVector3Array).size() / 3
			if sub.is_empty():
				_tissus.append([piv, randf() * TAU, piv.rotation])
		if mod == "brasero":
			var haut := xf * Vector3(0, BRAISES_Y, 0)
			Torche.flamme_fixe(self, haut, 2.4, x * 0.37)
			if _lumieres.is_empty():   # une seule vraie lumière : le brasero de la place (premier de la liste)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.55, 0.22)
				l.light_energy = 2.2
				l.omni_range = 8.0
				l.omni_attenuation = 1.3
				l.shadow_enabled = false
				l.distance_fade_enabled = true
				l.distance_fade_begin = 12.0
				l.distance_fade_length = 6.0
				l.position = haut + Vector3(0, 0.35, 0)
				add_child(l)
				_lumieres.append([l, l.light_energy, x])
		var cols: Array = COLLISIONS.get(mod, [])
		if mod == "etal" and not sub.is_empty():      # deux étals Quaternius : un seul volume plein (comptoirs et poteaux)
			cols = [["boite", Vector3(3.1, 1.0, 1.15), Vector3(0, 0.5, -0.45)]]
		for c: Array in cols:
			var forme := CollisionShape3D.new()
			forme.set_meta("objet", "%s#%d" % [mod, num])   # audit_interpenetrations : pièces d'un même module
			if c[0] == "cyl":
				var cy := CylinderShape3D.new()
				cy.radius = c[1] * s
				cy.height = c[2] * s
				forme.shape = cy
				forme.position = xf * (c[3] as Vector3)
			else:
				var bx := BoxShape3D.new()
				bx.size = (c[1] as Vector3) * s
				forme.shape = bx
				forme.transform = Transform3D(xf.basis.orthonormalized(), xf * (c[2] as Vector3))
			_corps.add_child(forme)
	var nq := _props_q(fusion)
	tris += nq.x
	for mat: String in fusion:
		var st: SurfaceTool = fusion[mat]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Mobilier_" + mat
		mi.mesh = st.commit()
		mi.material_override = _materiau(mat)
		mi.visibility_range_end = PORTEE
		add_child(mi)
	print("MobilierVillage : %d props Quaternius (%d triangles)" % [nq.y, nq.x])
	print("PropsQuaternius : remplacements ", PropsQuaternius.compte)
	print("MobilierVillage : %d poses, %d triangles, %d matières, %d tissus, %d collisions, %d ms" % [POSES.size(), tris, fusion.size(), _tissus.size(), _corps.get_child_count(), Time.get_ticks_msec() - t0])

## Pose les remplaçants Quaternius d'un module (substitut()) dans les SurfaceTool par matière, sous la transformation `xf` du module.
func _poser_sub(fusion: Dictionary, sub: Array, xf: Transform3D, _mod: String) -> int:
	var tris := 0
	for e: Array in sub:
		if e[0] == "" or not PropsQuaternius.existe(e[0]):
			continue
		PropsQuaternius.compter("village_marche")
		for t: Array in PropsQuaternius.triangles(e[0]):
			var mat: String = (e[2] as Dictionary).get(t[0], MATS_Q.get(t[0], "planches_h"))
			if not fusion.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				fusion[mat] = st
			(fusion[mat] as SurfaceTool).append_from(PropsQuaternius.maillage_brut(e[0], t[0]), 0, xf * (e[1] as Transform3D))
			if e.size() > 3:
				(fusion[mat] as SurfaceTool).append_from(PropsQuaternius.maillage_brut(e[0], t[0]), 0, xf * (e[1] as Transform3D) * Transform3D(Basis.from_scale(e[3]), Vector3.ZERO))
			tris += (t[1] as PackedVector3Array).size() / 3
	return tris

## Lot 3 : props Quaternius du marché (POSES_Q), fondus dans les mêmes SurfaceTool par matière (aucun maillage en plus si la matière
## existe déjà) ; collisions boîtes de l'emprise sur les gros. Renvoie (triangles, poses).
func _props_q(fusion: Dictionary) -> Vector2i:
	if not PropsQuaternius.actif:
		return Vector2i.ZERO
	var etals: Array = []
	for pose: Array in POSES:
		if pose[0] == "etal":
			etals.append(Transform3D(Basis(Vector3.UP, deg_to_rad(pose[3])), Vector3(pose[1], _sol_bas(pose[1], pose[2], 1.4), pose[2])))
	var tris := 0
	var num := 0
	var liste: Array = POSES_Q + (POSES_D if PropsQuaternius.remplace else []) + (POSES_L4 if PropsQuaternius.lot4 else [])
	var n_l4 := POSES_Q.size() + (POSES_D.size() if PropsQuaternius.remplace else 0)
	var idx := -1
	for e: Array in liste:
		idx += 1
		var nom: String = e[0]
		if not PropsQuaternius.existe(nom):
			continue
		var est_l4 := idx >= n_l4
		num += 1
		var xe: Transform3D = Transform3D.IDENTITY if e[1] < 0 else etals[e[1]]
		var lp: Vector3 = e[2]
		if PropsQuaternius.remplace and e[1] >= 0:      # comptoir des étals Quaternius : dessus à 0,8 (au lieu de 0,9), z -0,45 à -0,75 ; réserve derrière inchangée
			if lp.y > 0.5:
				lp = Vector3(lp.x, lp.y - 0.1, -0.45 + (lp.z + 0.62) * 0.9)
			elif lp.z < 0.3:
				lp = Vector3(lp.x, lp.y, lp.z)
		var p := xe * lp
		if e[1] < 0:      # densification : hauteur au-dessus du sol réel
			p.y = _sol_bas(p.x, p.z, 0.3) + lp.y
		elif lp.y < 0.01:      # au sol : recalé sur le relief (le plus bas de l'emprise, rien ne flotte)
			p.y = _sol_bas(p.x, p.z, 0.3)
		var xf := Transform3D(xe.basis * Basis(Vector3.UP, deg_to_rad(e[3])), p)
		if est_l4:
			if e.size() > 7:      # pose suspendue : rotation propre à la pièce (os en haut…) et échelle avant le x1,3
				xf.basis = xf.basis * (e[6] as Basis) * Basis.from_scale(e[7] as Vector3)
			xf.basis = xf.basis.scaled(Vector3.ONE * 1.3)      # lot 4 : nourriture des étals un peu plus grosse (lisible en vue de jeu)
		for t: Array in PropsQuaternius.triangles(nom):
			var mat: String = "argile" if t[0] == "fer" and nom in PRIMEURS else MATS_Q.get(t[0], "planches_h")
			if est_l4:
				mat = MATS_L4.get(t[0], mat)
				if e.size() > 5:      # matière imposée par la pose (ex. {"argile": "cuir"} : viande fumée, pas de terre cuite orangée)
					mat = (e[5] as Dictionary).get(t[0], mat)
			if not fusion.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				fusion[mat] = st
			(fusion[mat] as SurfaceTool).append_from(PropsQuaternius.maillage_brut(nom, t[0]), 0, xf)
			tris += (t[1] as PackedVector3Array).size() / 3
		if e[4]:
			var bb := PropsQuaternius.boite(nom)
			var forme := CollisionShape3D.new()
			forme.set_meta("objet", "%s#q%d" % [nom, num])
			var bs := BoxShape3D.new()
			bs.size = bb.size
			forme.shape = bs
			forme.transform = Transform3D(xf.basis, xf * bb.get_center())
			_corps.add_child(forme)
	return Vector2i(tris, num)

func _ajouter(st: SurfaceTool, d: Array, xf: Transform3D) -> void:
	var pos: PackedVector3Array = d[0]
	var col: PackedColorArray = d[1]
	for k in pos.size():
		st.set_color(col[k])
		st.add_vertex(xf * pos[k])

func _process(dt: float) -> void:
	_t += dt
	for t: Array in _tissus:
		var n: Node3D = t[0]
		var ph: float = t[1]
		var r0: Vector3 = t[2]
		n.rotation = r0 + Vector3(sin(_t * 1.3 + ph) * 0.05, sin(_t * 0.7 + ph * 1.7) * 0.06, 0.0)
	var cyc = monde.get("cycle") if monde != null else null
	var nuit := 1.0 - (float(cyc.clarte()) if cyc != null else 0.0)
	for l: Array in _lumieres:
		var k: float = l[2]
		(l[0] as OmniLight3D).light_energy = float(l[1]) * lerpf(0.45, 1.0, nuit) * (1.0 + sin(_t * 9.0 + k) * 0.05 + sin(_t * 23.0 + k) * 0.03)
