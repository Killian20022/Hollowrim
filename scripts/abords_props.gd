class_name AbordsProps
## props/maximum v3 (2026-11-11) : compositions des abords (champs, fermes, lisières, chemins, cercle runique, tumulus, entrée de la
## grotte). Props texturés pq_* et, quand le MegaKit n'a pas la pièce (charrette, tente, rondins, souche, poutre), les q_* du kit
## Medieval Village, tous fondus en UN maillage + UN corps statique par composition (PropsQuaternius.lot_pq) : aucun nœud par prop.
## La nature maison (rochers, buissons, touffes, cairns, os) n'est pas touchée : les compositions s'en écartent.
## Mode pq seulement : `-- --props-quat-ancien` rend exactement l'état d'avant.
##
## Une composition : [nom, items, ancres] ; ancre [x, z, lacet°] en monde ; chaque ancre est essayée telle quelle puis glissée de
## ±1 et ±2 m (le long de son axe X puis Z). Item : [id, droite, devant, lacet°, hauteur, solide, échelle, tangage°, roulis°]
## (repère de la composition, l'avant des props regarde +Z). Échelle : nombre (uniforme) ; Vector3 seulement pour le bois de charpente
## (poutre, planches) mis à longueur comme les travées de barrière (AbordsQ.base_segment). hauteur > 0.05 : posé à cette hauteur au-dessus de l'item au sol le plus
## proche (pas de contrôle d'emprise). Une ancre est refusée si un item au sol touche un arbre, un chemin, une pente trop forte, un corps
## physique (rochers, barrières, bâti, autres compositions) ou une composition déjà posée.

const PORTEE := 70.0          # les lots disparaissent au-delà (brouillard)
const PENTE_MAX := 0.57       # écart de sol maximal sous un petit item (m) : il est posé à mi-pente, flotte ou s'enfonce de ~0,1 m au plus
const PENTE_GRAND := 0.9      # sous un grand item solide (charrette, tente) : il est incliné comme le terrain (≤ ~15°)

## Charrette abandonnée au bord d'un champ : roue côté champ, sacs de grain renversés, tonneau, pioche couchée dans la neige.
const CHARRETTE := [["q_chariot", 0.0, 0.0, 0.0, 0.0, true], ["pq_sac", 1.05, 0.55, 30.0, 0.0, false], ["pq_sac", 1.25, -0.2, -60.0, 0.0, false, 1.0, 0.0, 80.0],
	["pq_tonneau", -1.15, 0.9, 0.0, 0.0, true], ["pq_pioche", -1.1, -0.6, 70.0, 0.0, false, 1.0, 90.0], ["pq_seau_bois", 0.9, 1.25, 0.0, 0.0, false]]
## Épouvantail : perche, traverse, sac en tête, haillon de toile.
const EPOUVANTAIL := [["q_poutre_ronde", 0.0, 0.0, 0.0, 0.0, true, Vector3(2.15, 1, 1), 0.0, 90.0], ["q_poutre_ronde", 0.0, 0.0, 0.0, 1.45, false, Vector3(1.36, 1, 1)],
	["pq_sac", 0.0, 0.0, 15.0, 1.72, false, 0.62], ["pq_banniere_2_toile", 0.0, 0.08, 0.0, 0.42, false, 0.56]]
## Bûcher de bois de chauffage contre une lisière : rondins empilés en trois rangs, billot (souche) et hache plantée, bûches.
const BUCHER := [["q_rondin", 0.0, 0.0, 0.0, 0.0, true], ["q_rondin", 0.0, 0.42, 4.0, 0.0, false], ["q_rondin", 0.0, -0.42, -3.0, 0.0, false],
	["q_rondin", 0.05, 0.21, 2.0, 0.36, false], ["q_rondin", -0.05, -0.21, -2.0, 0.36, false], ["q_rondin", 0.0, 0.0, 6.0, 0.72, false],
	["q_souche", 1.75, 0.55, 30.0, 0.0, true, 0.62], ["q_hache_camp", 1.78, 0.55, 75.0, 0.38, false, 1.0, 0.0, 12.0],
	["q_buche", 1.3, 1.25, 50.0, 0.0, false], ["q_buche", 1.6, 1.15, -20.0, 0.0, false], ["q_buche", 2.2, 0.95, 80.0, 0.0, false]]
## Campement de chasseur : tente, foyer éteint et marmite, rondin-banc, séchoir (deux perches et traverse) et prises, pièges, sac, corde.
const CAMP_CHASSEUR := [["q_tente", 0.0, 0.0, 0.0, 0.0, true, 0.8], ["q_feu_bois", 0.3, 3.0, 0.0, 0.0, false], ["q_marmite_camp", 0.35, 3.05, 20.0, 0.12, false],
	["q_rondin", -1.25, 3.3, 75.0, 0.0, true], ["q_poutre_ronde", 2.2, 1.0, 0.0, 0.0, true, Vector3(1.65, 1, 1), 0.0, 90.0], ["q_poutre_ronde", 2.2, 2.6, 0.0, 0.0, true, Vector3(1.65, 1, 1), 0.0, 90.0],
	["q_poutre_ronde", 2.2, 1.8, 90.0, 1.5, false, Vector3(1.75, 1, 1)], ["q_viande", 2.2, 1.5, 0.0, 1.32, false, 1.6, 90.0], ["q_viande", 2.2, 2.0, 0.0, 1.3, false, 1.6, 90.0],
	["q_poisson", 2.2, 2.3, 90.0, 1.28, false, 1.4, 0.0, 90.0], ["q_piege_ours", -1.8, 1.4, 20.0, 0.0, false], ["q_piege_ours", -2.0, 0.6, -35.0, 0.0, false],
	["pq_sac", 1.15, -0.6, 25.0, 0.0, false], ["pq_corde_3", -0.9, 2.2, 0.0, 0.0, false], ["pq_seau_bois", 1.0, 3.4, 0.0, 0.0, false],
	["q_hache_camp", -0.7, 3.65, 0.0, 0.0, false, 1.0, 90.0]]
## Récolte rentrée au portail d'un champ : sacs debout, cageots de carottes et de pommes, seau, tonneau de pommes.
const RECOLTE := [["pq_tonneau_pommes", 0.0, 0.0, 0.0, 0.0, true], ["pq_sac", 0.8, 0.1, 20.0, 0.0, false], ["pq_sac", 1.3, -0.15, -30.0, 0.0, false],
	["pq_cageot_carottes", -0.85, 0.15, 10.0, 0.0, false], ["pq_cageot_pommes", -0.85, 0.15, -5.0, 0.32, false], ["pq_seau_bois", 0.45, 0.75, 0.0, 0.0, false],
	["pq_cageot_vide", -0.4, 0.85, 40.0, 0.0, false]]
## Offrandes au pied de la stèle du cercle runique et devant le tertre, sur une dalle de pierre posée à plat (lisible de loin) :
## crâne, calice, bougies éteintes, pain, pomme, pièces sur la dalle ; grand vase, urne brisée, petit vase et pomme au pied.
const OFFRANDES := [["q_bordure_1", 0.0, 0.15, 0.0, 0.0, true, Vector3(0.62, 1.4, 0.75)], ["pq_vase_2", -1.15, 0.35, 0.0, 0.0, false, 0.8],
	["pq_urne_brisee", 1.1, 0.4, 30.0, 0.0, false, 0.7], ["pq_vase_4", -0.6, 0.75, 0.0, 0.0, false], ["q_pomme", 0.65, 0.75, 0.0, 0.0, false],
	["q_crane", 0.0, 0.17, 10.0, 0.19, false, 0.42], ["pq_calice", -0.35, 0.2, 0.0, 0.19, false, 1.3], ["pq_bougie_1", -0.5, 0.05, 0.0, 0.19, false, 1.3],
	["pq_bougie_2", 0.4, 0.05, 0.0, 0.19, false, 1.6], ["pq_bougie_2", 0.48, 0.25, 0.0, 0.19, false, 1.6], ["q_pain", 0.28, 0.3, 70.0, 0.19, false],
	["q_pomme", -0.15, 0.34, 0.0, 0.19, false], ["pq_tas_pieces", 0.14, 0.02, 0.0, 0.19, false, 1.2]]
## Poteau indicateur à la fourche des chemins : poteau, deux planches clouées en flèche, lanterne murale éteinte.
const POTEAU := [["q_poutre_ronde", 0.0, 0.0, 0.0, 0.0, true, Vector3(2.2, 1, 1), 0.0, 90.0], ["q_planches_sol", 0.3, 0.1, 90.0, 1.72, false, Vector3(0.2, 1, 0.34), 0.0, 90.0],
	["q_planches_sol", -0.28, 0.1, 96.0, 1.4, false, Vector3(0.18, 1, 0.3), 0.0, 90.0], ["pq_lanterne_murale", 0.0, 0.1, 0.0, 0.95, false]]
## Réserve des bandits devant la grotte : caisses empilées, tonneau, sacs, bûches.
const RESERVE_BANDITS := [["pq_caisse", 0.0, 0.0, 8.0, 0.0, true], ["pq_caisse_fer", 0.72, 0.05, -10.0, 0.0, true], ["pq_caisse", 0.3, 0.0, -20.0, 0.71, false],
	["pq_tonneau", -0.85, 0.15, 0.0, 0.0, true], ["pq_sac", 0.4, 0.75, 35.0, 0.0, false], ["q_buche", -0.4, 0.9, 70.0, 0.0, false], ["q_buche", -0.2, 1.05, 20.0, 0.0, false]]

## Lieux : [nom, composition, ancres [x, z, lacet°], marge aux chemins (facultative, 2 m)].
const LIEUX := [
	["charrette_champ_c", CHARRETTE, [[72.0, -6.5, 180.0], [71.8, -9.5, 170.0], [63.0, -13.0, 90.0], [63.0, -0.8, 90.0]]],
	["epouvantail_a", EPOUVANTAIL, [[83.5, 35.2, 20.0], [82.0, 34.0, 20.0]]],
	["epouvantail_b", EPOUVANTAIL, [[81.0, 45.8, -15.0], [79.5, 45.0, -15.0]]],
	["recolte_champ_b", RECOLTE, [[74.4, 45.5, 90.0], [74.4, 47.5, 90.0], [81.0, 51.6, 0.0]]],
	["recolte_champ_c", RECOLTE, [[55.6, -8.6, -90.0], [55.6, -5.5, -90.0], [64.0, -12.8, 180.0]]],
	["bucher_ferme_b", BUCHER, [[64.5, 6.5, 0.0], [58.5, 8.5, 30.0], [65.5, 1.0, 90.0], [57.0, 0.5, 0.0]]],
	["bucher_ferme_a", BUCHER, [[75.0, 21.5, 0.0], [83.0, 20.0, 0.0], [75.5, 26.5, 90.0]]],
	["bucher_feu", BUCHER, [[8.5, -7.5, 30.0], [-9.0, 6.5, -40.0], [6.0, 9.5, 150.0]]],
	["camp_chasseur", CAMP_CHASSEUR, [[-14.0, -27.0, 45.0], [-10.0, -24.0, 40.0], [-24.5, -13.5, 60.0], [6.0, -19.0, 0.0], [-20.0, 4.0, 90.0]]],
	["offrandes_cercle", OFFRANDES, [[-38.0, -32.4, 180.0], [-36.5, -32.8, 160.0], [-39.5, -32.8, 200.0], [-38.0, -35.6, 0.0]]],
	["offrandes_tumulus", OFFRANDES, [[-36.2, -46.4, 170.0], [-39.8, -46.4, 190.0], [-35.6, -45.2, 160.0], [-40.4, -45.2, 200.0]]],
	["poteau_cercle", POTEAU, [[-6.0, -4.2, 225.0], [-8.5, -5.0, 220.0], [-4.0, -8.5, 225.0]], 0.4],
	["poteau_tumulus", POTEAU, [[-32.6, -38.8, 200.0], [-33.6, -41.6, 200.0], [-36.8, -38.4, 160.0]], 0.4],
	["poteau_grotte", POTEAU, [[79.0, 26.6, 150.0], [74.5, 29.5, 120.0], [82.5, 26.0, 160.0]], 0.4],
	["reserve_grotte", RESERVE_BANDITS, [[86.5, -21.5, 120.0], [88.0, -32.5, 60.0], [85.5, -30.0, 90.0], [97.0, -21.0, 210.0]]],
]

# ------------------------------------------------------------------ props/exterieurs_v5 (2026-11-19) : tables et postes de vie
## Posés APRÈS LIEUX (les compositions v3 ne bougent pas : `--sans-props-v5` les rend à l'identique), seulement aux ancres données et à
## leurs glissements de ±1/±2 m (pas de couronnes de repli : dans le village, une table « trouvée » à 7 m pourrait barrer une ruelle).
## Contrôles en plus de ceux des abords (`_essai(..., ville = true)`) : ni dans un bâtiment, l'eau ou la palissade (Village.point_libre),
## pas au milieu d'une rue ou de la place (au plus 1 m dans le pavé : contre les bords), à 3 m au moins d'une porte d'intérieur et à
## 1,4 m d'un poste de garde (data/gardes.json).

## Tablée de plein air (place, porche de la halle) : grande table, deux bancs, chopes, assiettes, pain, bouteille, marmite, tonneau.
const TABLEE := [["pq_grande_table", 0.0, 0.0, 0.0, 0.0, true], ["pq_banc", 0.0, 0.85, 0.0, 0.0, true, 0.9], ["pq_banc", 0.0, -0.85, 180.0, 0.0, true, 0.9],
	["pq_chope", -0.7, 0.25, 20.0, 0.76, false], ["pq_chope", 0.3, -0.3, -40.0, 0.76, false], ["pq_chope", 0.9, 0.2, 80.0, 0.76, false],
	["pq_assiette", -0.3, 0.25, 0.0, 0.76, false], ["pq_assiette", 0.55, -0.25, 0.0, 0.76, false], ["q_pain", -0.3, 0.25, 30.0, 0.775, false],
	["pq_bouteille", 0.05, 0.05, 0.0, 0.76, false], ["pq_marmite", -1.0, -0.2, 0.0, 0.76, false], ["pq_tonneau", 1.85, 0.1, 0.0, 0.0, true]]
## Poste de garde : table ronde (Table_RoundSmall, catalogue v5), deux tabourets, chopes et dés (tas de pièces), râtelier, bouclier, tonneau.
const POSTE_GARDE := [["pq_table_ronde", 0.0, 0.0, 0.0, 0.0, true], ["pq_tabouret", -0.2, 0.9, 0.0, 0.0, false],
	["pq_tabouret", 0.75, -0.6, 30.0, 0.0, false], ["pq_chope", -0.25, 0.2, 0.0, 0.78, false], ["pq_chope", 0.3, -0.15, 60.0, 0.78, false],
	["pq_tas_pieces", 0.0, 0.05, 0.0, 0.78, false, 1.3], ["pq_rack_armes", 1.95, -0.1, 0.0, 0.0, true], ["pq_bouclier_bois", 1.95, 0.6, 0.0, 0.0, false, 1.0, -14.0],
	["pq_epee_mur", 1.55, -0.1, 0.0, 0.06, false, 1.0, -8.0], ["pq_hache_outil", 2.35, -0.1, 0.0, 0.06, false, 1.0, -8.0], ["pq_tonneau", -1.35, -0.3, 0.0, 0.0, true]]
## Table du chaudronnier au marché : chaudron, marmites, vase sur la table ; caisse, seau, grand vase et ballot au pied.
const TABLE_MARCHE := [["pq_grande_table", 0.0, 0.0, 0.0, 0.0, true, Vector3(0.75, 1.0, 1.0)], ["pq_chaudron", -0.6, 0.0, 0.0, 0.76, false, 0.55],
	["pq_marmite", 0.05, 0.15, 0.0, 0.76, false], ["pq_marmite_couverte", 0.1, -0.2, 30.0, 0.76, false], ["pq_vase_4", 0.65, 0.0, 0.0, 0.76, false, 0.7],
	["pq_seau_fer", 1.4, 0.25, 0.0, 0.0, false], ["pq_caisse", -1.45, -0.1, 10.0, 0.0, true], ["pq_vase_2", -1.4, 0.65, 0.0, 0.0, false, 0.7],
	["pq_ballot", 1.5, -0.45, 15.0, 0.0, false]]
## Établi du forgeron dehors : hache couchée, petite enclume, chaîne lovée, seau de trempe, caisse ferrée.
const ETABLI_FORGE := [["pq_etabli", 0.0, 0.0, 0.0, 0.0, true], ["pq_hache_outil", -0.5, 0.05, 90.0, 0.85, false, 1.0, 90.0],
	["pq_enclume", 0.4, 0.0, 10.0, 0.85, false, 0.7], ["pq_chaine", -1.55, 0.45, 0.0, 0.0, false, 0.8], ["pq_seau_fer", 1.3, 0.45, 0.0, 0.0, false],
	["pq_caisse_fer", 1.4, -0.35, 15.0, 0.0, true, 0.8]]
## Coin de travail d'une ferme : établi, pioche couchée et corde dessus, seau, sacs, billot (souche) et hache plantée, chevalet de sciage.
const ETABLI_FERME := [["pq_etabli", 0.0, 0.0, 0.0, 0.0, true], ["pq_pioche", -0.3, 0.1, 90.0, 0.85, false, 1.0, 90.0], ["pq_corde_2", 0.45, 0.15, 0.0, 0.85, false],
	["pq_seau_bois", 1.35, 0.4, 0.0, 0.0, false], ["pq_sac", -1.4, 0.25, 20.0, 0.0, false], ["pq_sac", -1.35, -0.35, -30.0, 0.0, false],
	["q_souche", 2.25, -0.2, 0.0, 0.0, true, 0.55], ["pq_hache_outil", 2.25, -0.2, 75.0, 0.34, false, 1.0, 0.0, 12.0],
	["pq_chevalet_scie", -2.65, 0.1, 0.0, 0.0, true]]
## Variante sans chevalet (plus courte de 2,6 m) pour la ferme A, où la version complète ne trouve pas de place.
const ETABLI_FERME_A := [["pq_etabli", 0.0, 0.0, 0.0, 0.0, true], ["pq_pioche", -0.3, 0.1, 90.0, 0.85, false, 1.0, 90.0], ["pq_corde_2", 0.45, 0.15, 0.0, 0.85, false],
	["pq_seau_bois", 1.35, 0.4, 0.0, 0.0, false], ["pq_sac", -1.4, 0.25, 20.0, 0.0, false], ["pq_sac", -1.35, -0.35, -30.0, 0.0, false],
	["q_souche", 2.25, -0.2, 0.0, 0.0, true, 0.55], ["pq_hache_outil", 2.25, -0.2, 75.0, 0.34, false, 1.0, 0.0, 12.0]]
## Table de jeu des bandits devant la grotte : tonneau en guise de table, deux tabourets, chopes, mise (pièces), bouteille vide au pied.
const JEU_BANDITS := [["pq_tonneau", 0.0, 0.0, 0.0, 0.0, true], ["pq_tabouret", 0.75, 0.05, 0.0, 0.0, false], ["pq_tabouret", -0.1, 0.75, 20.0, 0.0, false],
	["pq_chope", 0.15, 0.1, 0.0, 0.95, false], ["pq_chope", -0.15, -0.1, 90.0, 0.95, false], ["pq_tas_pieces", 0.05, -0.15, 0.0, 0.95, false, 1.3],
	["pq_bouteille", -0.6, -0.35, 0.0, 0.0, false, 1.0, 0.0, 90.0]]

## [nom, composition, ancres [x, z, lacet°], marge aux chemins].
const LIEUX_V5 := [
	["tablee_place", TABLEE, [[36.5, 44.5, 0.0], [34.8, 35.0, 90.0], [47.0, 43.8, 0.0], [38.0, 47.5, 0.0]], 1.0],
	["poste_porte_so", POSTE_GARDE, [[31.5, 27.5, 45.0], [25.0, 31.5, 45.0], [30.5, 31.0, 45.0]], 1.0],
	["poste_porte_n", POSTE_GARDE, [[59.5, 18.5, 0.0], [51.5, 11.0, 180.0], [59.5, 11.0, 180.0], [60.5, 21.0, -90.0]], 1.0],
	["poste_porte_e", POSTE_GARDE, [[69.0, 30.5, -90.0], [69.0, 42.0, -90.0], [68.0, 29.0, -90.0]], 1.0],
	["table_marche", TABLE_MARCHE, [[56.5, 38.0, -90.0], [48.5, 40.0, 0.0], [56.5, 29.0, 180.0]], 1.0],
	["etabli_forge", ETABLI_FORGE, [[28.5, 40.3, 180.0], [28.5, 31.7, 0.0], [31.5, 41.5, 90.0], [25.5, 40.0, 180.0]], 1.0],
	["etabli_ferme_a", ETABLI_FERME_A, [[82.5, 19.8, 180.0], [80.0, 19.6, 180.0], [84.0, 19.4, 180.0], [77.0, 29.5, 0.0], [84.5, 28.8, 0.0]], 1.0],
	["etabli_ferme_b", ETABLI_FERME, [[58.0, 7.8, 0.0], [66.8, 3.5, 90.0], [60.0, -0.8, 180.0]], 1.0],
	["jeu_bandits", JEU_BANDITS, [[83.5, -32.0, 90.0], [82.5, -21.0, 90.0], [84.5, -33.5, 60.0]]],
]

static func creer(monde: Node3D) -> void:
	if not PropsQuaternius.v3 or monde.village == null:      # `--sans-props-v3` : les abords de la v2 (A/B)
		return
	var tree := monde.get_tree()
	await tree.physics_frame      # les corps posés pendant la construction entrent dans l'espace physique
	await tree.physics_frame
	if not is_instance_valid(monde) or not monde.is_inside_tree():   # monde libéré pendant l'attente (tests : test_vegetation_biome)
		return
	var racine := Node3D.new()
	racine.name = "AbordsProps"
	monde.add_child(racine)
	var posees: Array = []      # disques [Vector2, rayon] des items au sol déjà posés
	var nb := 0
	var t0 := Time.get_ticks_msec()
	var n_v3 := LIEUX.size()
	var tous: Array = LIEUX + (LIEUX_V5 if PropsQuaternius.v5 else [])
	for il in tous.size():
		var l: Array = tous[il]
		var v5 := il >= n_v3
		var fait := false
		for a: Array in l[2] + ([] if v5 else _spirale(l[2][0])):
			for gl: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
				var lac := deg_to_rad(float(a[2]))
				var b := Basis(Vector3.UP, lac)
				var o := Vector3(float(a[0]), 0, float(a[1])) + b * Vector3(gl.x, 0, gl.y)
				var raison := _essai(monde, l[1], o, lac, posees, float(l[3]) if l.size() > 3 else 2.0, v5)
				if raison == "":
					_poser(monde, racine, String(l[0]), l[1], o, lac, posees)
					if v5:
						PropsQuaternius.compter("exterieurs_v5", (l[1] as Array).size())
					print("PropsMax : abords, composition posée %s (%.1f, %.1f) lacet %.0f sol %.2f" % [l[0], o.x, o.z, float(a[2]), monde.hauteur(o.x, o.z)])
					fait = true
					nb += 1
					break
				elif "--compos-debug" in OS.get_cmdline_user_args():
					print("PropsMax debug abords : %s (%.1f, %.1f) %s" % [l[0], o.x, o.z, raison])
			if fait:
				break
		if not fait:
			push_warning("PropsMax : abords, composition refusée partout : " + String(l[0]))
		if Jeu.chargement_etale:      # une composition par image : l'écran de chargement reste animé (pas en test : chargement d'un bloc, comme Monde._souffle)
			await tree.process_frame
			if not is_instance_valid(monde) or not monde.is_inside_tree():
				return
	print("PropsMax : abords, %d compositions en %d ms" % [nb, Time.get_ticks_msec() - t0])
	if PropsQuaternius.v5:
		print("PropsQuaternius v5 : remplacements ", PropsQuaternius.compte)
	var f := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--abords-vues="):
			f = a.substr(14)
	if f != "":
		await tree.physics_frame
		_ecrire_vues(monde, racine, f)

## Outil de captures (`-- --abords-vues=<fichier>`) : pour chaque composition posée, un gros plan et deux vues DÉGAGÉS (pas d'arbre, rayon
## libre jusqu'à elle, terrain compris) parmi 16 directions à 3, 5,5 puis 7,5 m ; écrit au format --captures (type monde, y des pieds).
## Le fichier peut être celui de --captures du même lancement (lu après les abords) : sa partie « # suite » est conservée.
static func _ecrire_vues(monde: Node3D, racine: Node3D, chemin: String) -> void:
	var espace: PhysicsDirectSpaceState3D = monde.get_world_3d().direct_space_state
	var lignes := PackedStringArray(["# PropsMax v3 abords : vues dégagées choisies par AbordsProps._ecrire_vues"])
	for mi: Node in racine.get_children():
		if not mi is MeshInstance3D:
			continue
		var ab := (mi as MeshInstance3D).get_aabb()
		var c := (mi as MeshInstance3D).global_transform * ab.get_center()
		var cible := Vector3(c.x, float(monde.hauteur(c.x, c.z)) + 0.5, c.z)
		var n := 0
		for d: float in [3.0, 5.5, 7.5]:      # un gros plan à 3 m, puis deux vues d'ensemble
			for k in 16:
				if n >= 3 or (d < 4.0 and n >= 1):
					break
				var t := TAU * float(k) / 16.0
				var cam := Vector3(c.x + cos(t) * d, 0, c.z + sin(t) * d)
				var pied: float = float(monde.hauteur(cam.x, cam.z)) + 1.2
				cam.y = pied + 1.62
				if monde.arbres_autour(cam, 2.0) > 0:
					continue
				var libre := true
				for u: float in [0.25, 0.5, 0.75]:      # le relief ne coupe pas la vue
					var q := cam.lerp(cible, u)
					if float(monde.hauteur(q.x, q.z)) > q.y - 0.2:
						libre = false
				var rq := PhysicsRayQueryParameters3D.create(cam, cible)
				var hit := espace.intersect_ray(rq)
				if not hit.is_empty() and (hit["position"] as Vector3).distance_to(cible) > 1.8:
					libre = false
				var dedans := PhysicsPointQueryParameters3D.new()      # pas dans un bâtiment
				dedans.position = cam
				if not espace.intersect_point(dedans, 1).is_empty():
					libre = false
				if not libre:
					continue
				var dv := cible - cam
				var lacet := rad_to_deg(atan2(-dv.x, -dv.z))
				var tang := rad_to_deg(atan2(dv.y, Vector2(dv.x, dv.z).length()))
				lignes.append("v3a_%s_%d monde %.2f,%.2f,%.1f,%.1f y=%.2f heure=12" % [mi.name, n, cam.x, cam.z, lacet, tang, pied])
				n += 1
		if n == 0:
			push_warning("PropsMax : abords, aucune vue dégagée pour " + String(mi.name))
	var ancien := FileAccess.get_file_as_string(chemin)      # ce qui suit « # suite » (vues de la crypte, de la grotte) est gardé
	var k := ancien.find("# suite")
	var fa := FileAccess.open(chemin, FileAccess.WRITE)
	fa.store_string("\n".join(lignes) + "\n" + (ancien.substr(k) if k >= 0 else ""))
	print("PropsMax : abords, %d vues écrites dans %s" % [lignes.size() - 1, chemin])

## Dernier recours (terrain en pente autour des ancres choisies) : couronnes de 3, 5 et 7 m autour de la première ancre, même lacet.
## Les glissements de ±1/±2 m s'y appliquent aussi : chaque essai est bon marché (quelques requêtes), l'ordre reste déterministe.
static func _spirale(a: Array) -> Array:
	var r: Array = []
	for d: float in [3.0, 5.0, 7.0]:
		for k in 8:
			var t := TAU * float(k) / 8.0 + d * 0.3
			r.append([float(a[0]) + cos(t) * d, float(a[1]) + sin(t) * d, float(a[2])])
	return r

## Repère monde d'un item (pied), sans la hauteur.
static func _xf_item(it: Array, o: Vector3, lac: float) -> Transform3D:
	var e := Vector3.ONE
	if it.size() > 6:
		e = it[6] if it[6] is Vector3 else Vector3.ONE * float(it[6])
	var b := Basis(Vector3.UP, lac) * Basis(Vector3.UP, deg_to_rad(float(it[3])))
	if it.size() > 7 and float(it[7]) != 0.0:
		b = b * Basis(Vector3.RIGHT, deg_to_rad(float(it[7])))
	if it.size() > 8 and float(it[8]) != 0.0:
		b = b * Basis(Vector3.BACK, deg_to_rad(float(it[8])))
	var p := o + Basis(Vector3.UP, lac) * Vector3(float(it[1]), 0, float(it[2]))
	return Transform3D(b * Basis.from_scale(e), p)

## Coins (x, z) de la boîte de l'item en monde.
static func _coins(id: String, xf: Transform3D) -> Array:
	var bb := PropsQuaternius.boite(id)
	var r: Array = []
	for cx: float in [bb.position.x, bb.end.x]:
		for cy: float in [bb.position.y, bb.end.y]:
			for cz: float in [bb.position.z, bb.end.z]:
				var w := xf * Vector3(cx, cy, cz)
				r.append(Vector2(w.x, w.z))
	return r

## `marge` : écart aux chemins (m, au-delà du rayon de l'item) ; 2 par défaut, ~0,4 pour ce qui se tient AU BORD du chemin (poteau).
static func _essai(monde: Node3D, items: Array, o: Vector3, lac: float, posees: Array, marge := 2.0, ville := false) -> String:
	var espace: PhysicsDirectSpaceState3D = monde.get_world_3d().direct_space_state
	var terrain: Object = monde.get_meta("corps_terrain", null)
	if ville:
		var r := _refus_ville(monde, items, o, lac)
		if r != "":
			return r
	for it: Array in items:
		if float(it[4]) > 0.05:
			continue
		var id := String(it[0])
		if not PropsQuaternius.existe(id):
			return "absent " + id
		var xf := _xf_item(it, o, lac)
		var cs := _coins(id, xf)
		var mn := Vector2(INF, INF)
		var mx := -mn
		for c: Vector2 in cs:
			mn = mn.min(c)
			mx = mx.max(c)
		var centre := (mn + mx) * 0.5
		var r := maxf((mx - mn).length() * 0.5, 0.15)
		var hmin := INF
		var hmax := -INF
		for c: Vector2 in [mn, mx, Vector2(mn.x, mx.y), Vector2(mx.x, mn.y), centre]:
			var h: float = monde.hauteur(c.x, c.y)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
		if hmax - hmin > (PENTE_GRAND if _grand(it, r) else PENTE_MAX):
			return "pente %s %.2f (r %.1f)" % [id, hmax - hmin, r]
		if monde.arbres_autour(Vector3(centre.x, 0, centre.y), r + 0.8) > 0:
			return "arbre " + id
		if monde.chemins != null and monde.chemins.distance(centre.x, centre.y) < r + marge:
			return "chemin " + id
		if monde._pres_du_chemin(centre.x, centre.y, r + marge + 0.2):
			return "sentier " + id
		for ct: Array in RuesVillage.CHEMINS_TERRE:
			if RuesVillage._d_polyligne(centre, ct[0]) < float(ct[1]) * 0.5 + r + minf(0.6, marge):
				return "chemin de terre " + id
		for pd: Array in posees:
			if centre.distance_to(pd[0]) < r + float(pd[1]) - 0.1:
				return "composition " + id
		var q := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		var bb := PropsQuaternius.boite(id)
		bs.size = Vector3(mx.x - mn.x + 0.2, maxf(bb.size.y * xf.basis.get_scale().y, 0.3), mx.y - mn.y + 0.2)
		q.shape = bs
		q.transform = Transform3D(Basis(), Vector3(centre.x, hmax + 0.15 + bs.size.y * 0.5, centre.y))
		q.collide_with_areas = false
		if terrain != null:
			q.exclude = [(terrain as CollisionObject3D).get_rid()]
		for hit: Dictionary in espace.intersect_shape(q, 8):
			if hit.get("collider") is CharacterBody3D or hit.get("collider") is RigidBody3D:
				continue
			return "corps %s %s" % [id, str(hit.get("collider").name) if hit.get("collider") != null else "?"]
	return ""

static var _postes_gardes: Array = []
## v5 (tables et postes dans le village) : raison du refus, "" si libre. Chaque coin et le centre de chaque item au sol : hors des
## bâtiments, de l'eau et de la palissade (Village.point_libre, marge 0,3 m) ; centre au plus 1 m dans le pavé (bord de rue / de place) ;
## à 3 m au moins d'une porte d'intérieur et à 1,4 m d'un poste de garde.
static func _refus_ville(monde: Node3D, items: Array, o: Vector3, lac: float) -> String:
	var v: Object = monde.village
	if _postes_gardes.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gardes.json"))
		if d is Dictionary:
			for g: Dictionary in ((d as Dictionary).get("gardes", []) as Array):
				if g.has("pos"):
					_postes_gardes.append(Vector2(float(g["pos"][0]), float(g["pos"][1])))
		_postes_gardes.append(Vector2.INF)      # lu une fois, même vide
	var portes: Array = []
	for ip: Variant in v.get("interieurs"):
		if ip is Node3D and (ip as Node3D).is_inside_tree():
			var pg: Vector3 = (ip as Node3D).to_global(ip.get("porte_locale"))
			portes.append(Vector2(pg.x, pg.z))
	for it: Array in items:
		if float(it[4]) > 0.05:
			continue
		var id := String(it[0])
		var xf := _xf_item(it, o, lac)
		var cs := _coins(id, xf)
		var mn := Vector2(INF, INF)
		var mx := -mn
		for c: Vector2 in cs:
			mn = mn.min(c)
			mx = mx.max(c)
		var centre := (mn + mx) * 0.5
		for c: Vector2 in [mn, mx, Vector2(mn.x, mx.y), Vector2(mx.x, mn.y), centre]:
			if not v.point_libre(c.x, c.y, 0.3):
				return "bâti/eau/palissade " + id
		if RuesVillage.profondeur_pave(centre) > 1.0:
			return "milieu de rue " + id
		if centre.x > 66.0 and centre.x < GrotteAcces.SITE.x + 1.0 and absf(centre.y - GrotteAcces.piste_z(centre.x)) < maxf((mx - mn).length() * 0.5, 0.15) + 3.5:
			return "piste de la grotte " + id
		var r := maxf((mx - mn).length() * 0.5, 0.15)
		for p: Vector2 in portes:
			if centre.distance_to(p) < r + 3.0:
				return "porte " + id
		for p: Vector2 in _postes_gardes:
			if centre.distance_to(p) < r + 1.4:
				return "poste de garde " + id
	return ""

static func _poser(monde: Node3D, racine: Node3D, nom: String, items: Array, o: Vector3, lac: float, posees: Array) -> void:
	var poses: Array = []
	var pieds: Array = []      # [centre (x, z), y du dessus] des items au sol, pour les items posés dessus
	for it: Array in items:
		if float(it[4]) > 0.05:
			continue
		var id := String(it[0])
		var xf := _xf_item(it, o, lac)
		var cs := _coins(id, xf)
		var mn := Vector2(INF, INF)
		var mx := -mn
		for c: Vector2 in cs:
			mn = mn.min(c)
			mx = mx.max(c)
		var centre := (mn + mx) * 0.5
		var h := INF
		for c: Vector2 in [mn, mx, Vector2(mn.x, mx.y), Vector2(mx.x, mn.y), centre]:
			h = minf(h, monde.hauteur(c.x, c.y))
		var ht: float = monde.hauteur(centre.x, centre.y)
		var y := lerpf(h, ht, 0.5) - 0.03     # à moitié de la pente : un coin s'enfonce, aucun ne flotte de plus de quelques cm
		if _grand(it, maxf((mx - mn).length() * 0.5, 0.15)):
			xf = _incline(monde, id, xf)      # grand item : suit le terrain, posé par le milieu de son dessous
			var bb := PropsQuaternius.boite(id)
			var dessous := xf * Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
			y = monde.hauteur(dessous.x, dessous.z) - 0.04
			xf.origin.y += y - dessous.y
		else:
			xf.origin.y = y - _bas(id, xf)
		var bv := PropsQuaternius.buche_v5(id)      # v5 : bûche kitbash maison -> rondin Quaternius, même boîte
		poses.append([PropsQuaternius.ext_v5(bv[0]), xf * (bv[1] as Transform3D), bool(it[5])])
		pieds.append([Vector2(xf.origin.x, xf.origin.z), y])
		posees.append([centre, maxf((mx - mn).length() * 0.5, 0.15)])
	for it: Array in items:
		if float(it[4]) <= 0.05:
			continue
		var xf := _xf_item(it, o, lac)
		var q := Vector2(xf.origin.x, xf.origin.z)
		var y0 := 0.0
		var dmin := INF
		for pd: Array in pieds:
			var dd: float = q.distance_to(pd[0])
			if dd < dmin:
				dmin = dd
				y0 = float(pd[1])
		xf.origin.y = y0 + float(it[4]) - _bas(String(it[0]), xf)
		var bw := PropsQuaternius.buche_v5(String(it[0]))
		poses.append([PropsQuaternius.ext_v5(bw[0]), xf * (bw[1] as Transform3D), bool(it[5])])
	var mi := PropsQuaternius.lot_pq(racine, nom, poses, "exterieur", monde.village)
	if mi != null:
		mi.visibility_range_end = PORTEE
		mi.visibility_range_end_margin = 4.0

## Grand item solide (charrette, tente, rondin-banc) : incliné comme le terrain au lieu d'être posé à plat à mi-pente.
static func _grand(it: Array, r: float) -> bool:
	return bool(it[5]) and r > 1.0

## Incline le repère de l'item selon la pente du terrain mesurée aux bouts de ses deux axes (normale du plan moyen).
static func _incline(monde: Node3D, id: String, xf: Transform3D) -> Transform3D:
	var bb := PropsQuaternius.boite(id)
	var c := xf * bb.get_center()
	var ax := xf.basis.x * (bb.size.x * 0.5)
	var az := xf.basis.z * (bb.size.z * 0.5)
	ax.y = 0.0
	az.y = 0.0
	var lx := maxf(ax.length(), 0.2)
	var lz := maxf(az.length(), 0.2)
	var gx := (float(monde.hauteur(c.x + ax.x, c.z + ax.z)) - float(monde.hauteur(c.x - ax.x, c.z - ax.z))) / (2.0 * lx)
	var gz := (float(monde.hauteur(c.x + az.x, c.z + az.z)) - float(monde.hauteur(c.x - az.x, c.z - az.z))) / (2.0 * lz)
	var n := (Vector3.UP - ax / lx * gx - az / lz * gz).normalized()
	var q := Quaternion(Vector3.UP, n)
	return Transform3D(Basis(q) * xf.basis, xf.origin)

## Point le plus bas de la boîte de l'item sous son origine (une poutre dressée, une planche tournée) : posé sur ce point.
static func _bas(id: String, xf: Transform3D) -> float:
	var bb := PropsQuaternius.boite(id)
	var lo := INF
	for cx: float in [bb.position.x, bb.end.x]:
		for cy: float in [bb.position.y, bb.end.y]:
			for cz: float in [bb.position.z, bb.end.z]:
				lo = minf(lo, (xf.basis * Vector3(cx, cy, cz)).y)
	return lo
