# Liste des props TEXTURÉS v5 (props/sources_v5, 2026-11-19) -> props_sources_v5_liste.json, lue par props_sources_v5.py.
#   python3 -I gen_props_sources_v5.py
# Trois familles :
#   1. Ultimate Home Interior (Quaternius, CC0, téléchargé le 2026-11-19 : references/quaternius_props/ultimate_home_interior/
#      telecharge_2026-11-19/) : SEULES les pièces qui passent en médiéval nordique (tri visuel sur planche, voir docs/PROPS_SOURCES_V5.md).
#   2. q_* déjà posés par les lots 2-4 (couleurs de face, sources/props.json) SANS équivalent pq_* : même modèle, même échelle (« ech » /
#      « hauteur » repris de props.json), donc même emprise -> « equivalent_q » (NON copié dans « ancien » : le remplacement automatique
#      reste à la main des agents d'intégration).
#   3. pièces jamais converties (Medieval Dungeon, Modular Dungeon, Survival, Ultimate Food).
# mats : sous-chaîne du nom de matériau source -> matière (bois[:f] | fer[:f] | v:<rampe> | tissu:<rampe> | suppr | auto ; voir props_sources_v5.py)
import json, os
ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
R = "C:/Users/lopezk19/Jeux/references/quaternius_props/"
UHI = R + "ultimate_home_interior/telecharge_2026-11-19/FBX/%s.fbx"
MD = R + "medieval_dungeon/FBX/%s.fbx"
DI = R + "lowpoly_modular_dungeon_itch/Updated_Modular_Dungeon_May2019/FBX/%s.fbx"
SV = R + "survival/FBX/%s.fbx"
UF = R + "ultimate_food/FBX/%s.fbx"
RPG = R + "ultimate_rpg/FBX/%s.fbx"     # Ultimate RPG Pack (CC0), téléchargé le 2026-11-19
MV19 = R + "medieval_village_pack_2019/Props/FBX/%s.fbx"     # Medieval Village Pack (2019, CC0), téléchargé le 2026-11-19

# matières de la bible (lots 2-4) -> matière texturée v5
BIBLE = {"bois": "bois", "fer": "fer", "noir": "fer:0.5", "or": "v:or", "os": "v:ecru", "lin": "v:ecru", "laine": "v:laine_rouge",
         "toile": "v:laine_bleue", "jute": "v:tourbe", "argile": "v:pin", "herbe": "v:aiguilles", "pierre": "v:pierre", "lame": "fer"}
# matériaux des packs unis (Modular Dungeon itch : pas de « mats » dans props.json)
DONJON = {"DarkWood": "bois", "LightWood": "bois", "Wood": "bois", "DarkMetal": "fer:0.6", "DarkSteel": "fer:0.6", "LightSteel": "fer",
          "Steel": "fer", "Metal": "fer", "Gold": "v:or", "Main": "tissu:laine_rouge", "Bag": "tissu:tourbe*0.7", "Thread": "v:cuir",
          "Grey_Floor": "v:pierre", "DarkGrey_Floor": "v:pierre*0.8", "Marble": "v:pierre*0.7", "Bone": "v:ecru", "Ceramic": "v:pin*0.8",
          "Cobweb": "tissu:ecru", "Fire": "suppr", "Rock": "v:pierre"}
# trims du Medieval Village MegaKit
VILLAGE = {"WoodTrim_Wear": "bois:0.85", "WoodTrim": "bois", "MetalOrnaments": "fer", "RockTrim": "v:pierre*0.6", "Brick": "v:pierre*0.6",
           "Plaster": "v:ecru", "WindowGlass": "fer:0.35"}

# (id, source, catégorie, échelle {hauteur|longueur|ech}, mats, nom FR, matière, usage conseillé)
UHI_L = [
 ("pq_table_ovale", "Table_RoundLarge", "mobilier", {"hauteur": 0.78}, {"Wood": "bois"}, "grande table ovale à tréteaux",
  "bois", "tables de la halle / des maisons (table à tréteaux maison, pq_grande_table), tables de la crypte (table_a/b/c gardées : 2,7 m)"),
 ("pq_table_ronde", "Table_RoundSmall", "mobilier", {"hauteur": 0.78}, {"Wood": "bois"}, "table ronde à pied central",
  "bois", "table de taverne / d'auberge, table de jeu des quartiers, table de Grima ou de Sigrun"),
 ("pq_chaise_echelle", "Chair_1", "mobilier", {"hauteur": 1.0}, {"Wood": "bois"}, "chaise à dossier à barreaux",
  "bois", "chaises autour des tables (pq_chaise, banc maison), halle, maisons"),
 ("pq_chaise_coussin", "Chair_2", "mobilier", {"hauteur": 1.0}, {"Wood_Dark": "bois:0.75", "Cushin": "tissu:laine_rouge*0.75"},
  "chaise à coussin de laine", "bois sombre + laine rouge", "chaise du jarl / de maître de maison, halle"),
 ("pq_chaise_fuseaux", "Chair_4", "mobilier", {"hauteur": 1.0}, {"Wood": "bois"}, "chaise à dossier à fuseaux",
  "bois", "chaises de maisons et d'auberge (variante de pq_chaise_echelle)"),
 ("pq_chevet_tiroir", "NightStand_1", "mobilier", {"hauteur": 0.6}, {"Wood": "bois", "Metal": "fer"}, "table de chevet à tiroir",
  "bois + bouton de fer", "à côté des lits (lit maison, pq_lit), chambres de Sigrun, des chasseurs"),
 ("pq_chevet_etagere_2", "NightStand_2", "mobilier", {"hauteur": 0.62}, {"Wood": "bois", "Metal": "fer"},
  "petite table à tiroir et tablette", "bois + fer", "petite table d'appoint, chevet, guéridon de la halle"),
 ("pq_coffre_tiroirs", "NightStand_3", "rangement", {"hauteur": 0.6}, {"Wood": "bois", "Metal": "fer"}, "petit meuble à deux tiroirs",
  "bois + fer", "rangement bas des maisons (coffre maison), forge, archives"),
 ("pq_commode", "Drawer_5", "rangement", {"hauteur": 0.85}, {"Wood_Dark": "bois:0.7", "Wood_Light": "bois", "Wood": "bois:0.85"},
  "commode basse à tiroirs", "bois (trois tons)", "dressoir maison, commode des chambres, buffet (pq_buffet en variante)"),
 ("pq_etagere_haute", "Bookshelf", "rangement", {"hauteur": 2.0}, {"White": "bois:0.8"}, "grande étagère ouverte",
  "bois", "étagère 4 niveaux maison (pq_etagere_arche), archives de la crypte (etagere_cadre_a/b gardées)"),
 ("pq_etagere_etroite", "Shelf_1", "rangement", {"hauteur": 1.8}, {"White": "bois:0.8"}, "étagère étroite",
  "bois", "étagère d'angle, réserve, garde-manger"),
 ("pq_tapis_rect", "Carpet_1", "mobilier", {"longueur": 2.4}, {"DarkRed": "tissu:laine_rouge", "LightOrange": "tissu:tourbe"},
  "tapis tissé rectangulaire", "laine rouge, bordure ocre", "tapis / peaux au sol maison (peau_sol = toile de bannière couchée), halle"),
 ("pq_tapis_carre", "Carpet_2", "mobilier", {"longueur": 2.6}, {"DarkRed": "tissu:laine_rouge", "LightOrange": "tissu:tourbe"},
  "grand tapis tissé", "laine rouge, bordure ocre", "sol de la halle du jarl, devant le trône"),
 ("pq_tapis_rond", "Carpet_Round", "mobilier", {"longueur": 2.0}, {"DarkRed": "tissu:laine_rouge", "LightOrange": "tissu:tourbe"},
  "tapis tissé rond", "laine rouge, bordure ocre", "devant un foyer, chambre, q_tapis de la crypte"),
 ("pq_piedestal_rond", "Column_Round1", "donjon", {"hauteur": 1.1}, {"Marble": "v:pierre*0.7"}, "piédestal de pierre rond",
  "pierre", "présentoirs, reliquaires de la crypte (piédestaux maison), offrandes"),
 ("pq_colonne_ronde", "Column_Round2", "donjon", {"hauteur": 3.2}, {"Marble": "v:pierre*0.7"}, "colonne de pierre ronde",
  "pierre", "colonnes de la crypte (q_colonne_1/2), salle du trône g4"),
 ("pq_pilier_carre", "Column_SquareBig", "donjon", {"hauteur": 3.2}, {"Marble": "v:pierre*0.7"}, "pilier de pierre carré",
  "pierre", "piliers de la crypte, entrée du tumulus"),
 ("pq_piedestal_carre", "Column_SquareSmall", "donjon", {"hauteur": 1.3}, {"Marble": "v:pierre*0.7"}, "piédestal de pierre carré",
  "pierre", "présentoir de l'Épée, socle de statue, autel"),
 ("pq_ecuelle_creuse", "Plate_3", "cuisine_table", {"longueur": 0.24}, {"White": "bois:0.9"}, "écuelle creuse en bois",
  "bois", "vaisselle des tables (assiette / bol maison, q_ecuelle)"),
 ("pq_cuillere_bois", "Spoon", "cuisine_table", {"longueur": 0.2}, {"LightMetal": "bois:0.9"}, "cuillère de bois",
  "bois", "q_cuillere_bois (gardé : pq_cuillere est en métal), tables, marmites"),
]

# q_* des lots 2-4 sans pq_* : (q, id pq, catégorie, nom FR, matière, usage, mats forcés éventuels)
Q_L = [
 # Medieval Village MegaKit (trims du village -> atlas du MegaKit)
 ("q_chariot", "pq_chariot", "exterieur_ferme", "chariot de ferme", "bois", "charrette abandonnée des abords, marché (q_chariot gardé)", None),
 ("q_caisse_village", "pq_caisse_village", "rangement", "caisse en planches du village", "bois", "caisses du marché et des ruelles", None),
 ("q_barriere_bois", "pq_barriere_bois", "exterieur_ferme", "barrière de bois (poteau)", "bois", "enclos d'Ylva, abords (q_barriere_bois gardé)", None),
 ("q_barriere_ext_1", "pq_barriere_ext_1", "exterieur_ferme", "barrière de bois (travée)", "bois", "enclos, abords", None),
 ("q_barriere_ext_2", "pq_barriere_ext_2", "exterieur_ferme", "barrière de bois (travée longue)", "bois", "enclos, abords", None),
 ("q_support_bois", "pq_support_bois", "exterieur_ferme", "jambe de force en bois", "bois", "auvents, séchoirs, étais", None),
 ("q_grille_fer", "pq_grille_fer", "donjon", "grille de fer simple", "fer", "grilles de la crypte, clôture du tumulus", None),
 ("q_grille_fer_ornee", "pq_grille_fer_ornee", "donjon", "grille de fer ouvragée", "fer", "grille de la halle, enclos du cimetière", None),
 ("q_brique_1", "pq_brique_1", "exterieur_ferme", "moellon 1", "pierre", "kitbash puits / foyers / couronne du feu de camp", None),
 ("q_brique_2", "pq_brique_2", "exterieur_ferme", "moellon 2", "pierre", "kitbash puits / foyers", None),
 ("q_brique_3", "pq_brique_3", "exterieur_ferme", "moellon 3", "pierre", "kitbash puits / foyers", None),
 ("q_brique_4", "pq_brique_4", "exterieur_ferme", "moellon 4", "pierre", "kitbash puits / foyers", None),
 ("q_bordure_1", "pq_bordure_1", "exterieur_ferme", "dalle de bordure", "pierre", "margelle du puits, bordures", None),
 ("q_bordure_2", "pq_bordure_2", "exterieur_ferme", "dalle de bordure 2", "pierre", "bordures, offrandes (dalle basse)", None),
 ("q_bordure_angle", "pq_bordure_angle", "exterieur_ferme", "dalle de bordure d'angle", "pierre", "bordures", None),
 ("q_planches_sol", "pq_planches_sol", "exterieur_ferme", "plancher de planches", "bois", "estrade de la halle, toit du puits, soufflet (kitbash)", None),
 ("q_porte_1_plate", "pq_porte_1_plate", "mobilier", "porte de planches 1", "bois", "portes des maisons closes (q_porte_*)", None),
 ("q_porte_1_ronde", "pq_porte_1_ronde", "mobilier", "porte de planches 1 cintrée", "bois", "portes des maisons closes", None),
 ("q_porte_2_plate", "pq_porte_2_plate", "mobilier", "porte de planches 2", "bois", "portes des maisons closes", None),
 ("q_porte_2_ronde", "pq_porte_2_ronde", "mobilier", "porte de planches 2 cintrée", "bois", "portes des maisons closes", None),
 ("q_porte_8_plate", "pq_porte_8_plate", "mobilier", "porte ferrée 8", "bois + fer", "portes des maisons closes, halle", None),
 ("q_porte_8_ronde", "pq_porte_8_ronde", "mobilier", "porte ferrée 8 cintrée", "bois + fer", "portes des maisons closes, halle", None),
 ("q_volets_thin_flat_closed", "pq_volets_etroits_fermes", "mobilier", "volets étroits fermés", "bois", "volets des fenêtres (q_volets_*)", None),
 ("q_volets_thin_flat_open", "pq_volets_etroits_ouverts", "mobilier", "volets étroits ouverts", "bois", "volets des fenêtres", None),
 ("q_volets_wide_flat_closed", "pq_volets_larges_fermes", "mobilier", "volets larges fermés", "bois", "volets des fenêtres", None),
 ("q_volets_wide_flat_open", "pq_volets_larges_ouverts", "mobilier", "volets larges ouverts", "bois", "volets des fenêtres", None),
 # Modular Dungeon (itch) : crypte, grotte
 ("q_sac_pieces", "pq_sac_pieces", "objets_petits", "sac de pièces couché", "toile de jute + or", "trésor de la crypte (sac_a/b)", None),
 ("q_sac_debout", "pq_sac_debout", "exterieur_marche", "sac debout ficelé", "toile de jute", "sacs du marché, réserves (alias pq_sac aujourd'hui)", None),
 ("q_banniere_mur", "pq_banniere_mur", "donjon", "bannière murale", "laine rouge, bois, fer", "halle, salle du trône, crypte", None),
 ("q_tonneau_2", "pq_tonneau_2", "rangement", "tonneau cerclé de bois", "bois", "tonneau_b / tonneau_c (alias pq_tonneau aujourd'hui)", None),
 ("q_seau_2", "pq_seau_2", "cuisine_table", "seau de bois cerclé de fer", "bois + fer", "seaux (alias pq_seau_bois aujourd'hui)", None),
 ("q_chaise_2", "pq_chaise_2", "mobilier", "chaise à assise de laine", "bois + laine rouge", "chaises de la crypte (alias pq_chaise aujourd'hui)", None),
 ("q_coffre_2", "pq_coffre_2", "rangement", "coffre ferré bombé", "bois + fer", "coffres décor (alias pq_coffre_ferme aujourd'hui)", None),
 ("q_toile_araignee_1", "pq_toile_araignee_1", "donjon", "toile d'araignée", "écru", "angles de la crypte et de la grotte", None),
 ("q_toile_araignee_2", "pq_toile_araignee_2", "donjon", "toile d'araignée 2", "écru", "angles de la crypte et de la grotte", None),
 ("q_colonne_1", "pq_colonne_donjon", "donjon", "colonne de crypte", "pierre", "colonnes de la crypte", None),
 ("q_colonne_2", "pq_colonne_donjon_2", "donjon", "colonne de crypte 2", "pierre", "colonnes de la crypte", None),
 ("q_caisse_2", "pq_caisse_2", "rangement", "caisse de planches cerclée", "bois", "g_caisse_a (alias pq_caisse_fer aujourd'hui)", None),
 ("q_piedestal_1", "pq_piedestal_1", "donjon", "piédestal", "pierre", "présentoirs, reliquaires", None),
 ("q_piedestal_2", "pq_piedestal_2", "donjon", "piédestal 2", "pierre", "présentoirs, reliquaires", None),
 ("q_crane", "pq_crane", "donjon", "crâne", "os", "crane_a/b de la crypte et de la grotte (gardés : aucun pq_*)", None),
 ("q_pieux", "pq_pieux", "donjon", "pointes de fer", "fer", "pièges, défenses", None),
 ("q_epee_support", "pq_epee_support", "armes_outils", "épée sur support mural", "fer + bois", "trophée mural de la halle, armurerie", None),
 ("q_table_grande_2", "pq_table_grande_2", "mobilier", "grande table de planches ferrée", "bois + fer", "tables de la crypte (table_a/b/c), réfectoire", None),
 ("q_table_petite_2", "pq_table_petite_2", "mobilier", "petite table de planches ferrée", "bois + fer", "tables de la crypte, camp", None),
 ("q_piege_pieux", "pq_piege_pieux", "donjon", "dalle à pointes (piège)", "fer", "pièges de la crypte", None),
 ("q_vase_5", "pq_vase_5", "donjon", "urne de terre cuite", "argile", "urne_b (alias pq_vase_4 aujourd'hui)", None),
 ("q_bucher", "pq_bucher", "exterieur_ferme", "bûcher (sans flamme)", "bois", "foyers, feu de camp, forge de plein air (q_bucher gardé)", None),
 # Medieval Dungeon
 ("q_os_tas", "pq_os_tas", "donjon", "tas d'os", "os", "ossuaire, monticules d'os de la crypte (gardés)", None),
 ("q_os_tas_2", "pq_os_tas_2", "donjon", "tas d'os 2", "os", "ossuaire, crypte", None),
 ("q_roc_1", "pq_roc_1", "donjon", "gravats 1", "pierre", "gravats de la crypte et de la mine", None),
 ("q_roc_2", "pq_roc_2", "donjon", "gravats 2", "pierre", "gravats", None),
 ("q_roc_3", "pq_roc_3", "donjon", "gravats 3", "pierre", "gravats", None),
 ("q_colonne_brisee", "pq_colonne_brisee", "donjon", "colonne brisée", "pierre", "crypte en ruine, tumulus", None),
 ("q_colonne_brisee_2", "pq_colonne_brisee_2", "donjon", "colonne brisée 2", "pierre", "crypte en ruine", None),
 ("q_fiole_1", "pq_fiole_1", "objets_petits", "fiole 1", "verre sombre", "groupes de fioles (archives, alchimie)", None),
 ("q_fiole_2", "pq_fiole_2", "objets_petits", "fiole 2", "verre sombre", "groupes de fioles", None),
 ("q_fiole_3", "pq_fiole_3", "objets_petits", "fiole 3", "verre sombre", "groupes de fioles", None),
 ("q_livre_d1", "pq_livre_d1", "livres", "gros livre relié", "laine rouge + écru", "piles de livres de la crypte", None),
 ("q_livre_d2", "pq_livre_d2", "livres", "gros livre relié 2", "laine rouge + écru", "piles de livres", None),
 ("q_livre_ouvert", "pq_livre_ouvert", "livres", "livre ouvert", "laine rouge + écru", "lutrin, livre ouvert de la crypte (gardé : aucun pq_*)", None),
 ("q_tapis", "pq_tapis_crypte", "mobilier", "tapis long à franges", "laine rouge + or terni", "q_tapis de la crypte", {"Red": "tissu:laine_rouge", "Gold": "tissu:tourbe"}),
 ("q_coffre_d", "pq_coffre_d", "rangement", "coffre ferré de crypte", "bois + fer", "q_coffre_d (quartiers de la crypte)", None),
 ("q_coffre_or", "pq_coffre_or", "rangement", "coffre au trésor", "bois + fer + or", "q_coffre_or (trésor)", None),
 ("q_candelabre_d", "pq_candelabre_d", "eclairage", "candélabre haut de fer (éteint)", "fer + cire", "compositions éteintes de la crypte", None),
 ("q_bougie_d", "pq_bougie_d", "eclairage", "bougie sur bougeoir de fer", "fer + cire", "autels, tables de la crypte", None),
 # Survival
 ("q_tente", "pq_tente", "exterieur_ferme", "tente de toile", "toile de jute + bois", "camp de chasseur, camp des bandits (q_tente gardé)", {"DarkWood": "bois", "Green": "tissu:tourbe", "Black": "fer:0.5"}),
 ("q_feu_bois", "pq_feu_bois", "exterieur_ferme", "feu de bois (bûches)", "bois", "feu de camp, foyers (q_feu_bois gardé)", None),
 ("q_piege_ours", "pq_piege_ours", "armes_outils", "piège à mâchoires ouvert", "fer", "camp de chasseur, enclos (q_piege_ours gardé)", None),
 ("q_piege_ours_ferme", "pq_piege_ours_ferme", "armes_outils", "piège à mâchoires fermé", "fer", "coins de chasseurs", None),
 ("q_marmite_camp", "pq_marmite_camp", "cuisine_table", "marmite de camp", "fer", "camp, foyer éteint (q_marmite_camp gardé)", None),
 ("q_marmite_camp_petite", "pq_marmite_camp_petite", "cuisine_table", "petite marmite de camp", "fer", "camp", None),
 ("q_poele", "pq_poele", "cuisine_table", "poêle à manche de bois", "fer + bois", "camp, cuisine", None),
 ("q_hache_camp", "pq_hache_camp", "armes_outils", "hache de bûcheron", "fer + bois", "billots, tas de bois (q_hache_camp gardé)", None),
 ("q_hachette", "pq_hachette", "armes_outils", "hachette", "fer + bois", "coins de chasseurs, camp", None),
 ("q_pelle", "pq_pelle", "armes_outils", "pelle", "fer + bois", "forge (caisse à charbon), mine, grange", None),
 ("q_couteau_camp", "pq_couteau_camp", "armes_outils", "couteau de chasse", "fer + bois", "camp, boucher", None),
 ("q_rondin", "pq_rondin", "exterieur_ferme", "rondin", "bois", "bûchers des abords, bancs du camp (q_rondin gardé)", None),
 # Ultimate Food
 ("q_pomme", "pq_pomme", "objets_petits", "pomme", "rouge", "étals, tables (nourriture gardée)", None),
 ("q_pomme_verte", "pq_pomme_verte", "objets_petits", "pomme verte", "vert", "étals, tables", None),
 ("q_pain", "pq_pain", "objets_petits", "miche de pain", "croûte brune", "étals, tables", None),
 ("q_tranche_pain", "pq_tranche_pain", "objets_petits", "tranche de pain", "brun + mie", "tables", None),
 ("q_carotte_f", "pq_carotte_f", "objets_petits", "carotte", "orange terni", "étals, cageots", None),
 ("q_cuisse", "pq_cuisse", "objets_petits", "cuisse rôtie", "brun", "tables du festin", None),
 ("q_marmite_soupe", "pq_marmite_soupe", "cuisine_table", "marmite de soupe", "fer + soupe", "foyers des maisons, camp", None),
 ("q_marmite_soupe_2", "pq_marmite_soupe_2", "cuisine_table", "chaudron de soupe", "fer + soupe", "foyers", None),
 ("q_oeuf", "pq_oeuf", "objets_petits", "œuf", "écru", "cuisine, garde-manger", None),
 ("q_poisson", "pq_poisson", "objets_petits", "poisson", "gris-fer", "quai (matériel de pêche), étal, séchoir", None),
 ("q_aretes", "pq_aretes", "objets_petits", "arêtes de poisson", "os", "restes du camp", None),
 ("q_jarre", "pq_jarre", "cuisine_table", "grande jarre", "terre cuite", "garde-manger, réserves", None),
 ("q_champignon", "pq_champignon", "objets_petits", "champignon", "brun clair", "cuisine, grotte", None),
 ("q_citrouille", "pq_citrouille", "objets_petits", "courge", "orange sombre", "étals, grenier", None),
 ("q_saucisse", "pq_saucisse", "objets_petits", "saucisse", "brun", "viande séchée pendue (kitbash maison)", None),
 ("q_viande", "pq_viande", "objets_petits", "pièce de viande", "rouge sombre", "étal du boucher, séchoir", None),
 ("q_navet", "pq_navet", "objets_petits", "navet", "écru + vert", "étals, cageots", None),
 ("q_chou", "pq_chou", "objets_petits", "chou", "vert", "étals de la place", None),
 ("q_lard", "pq_lard", "objets_petits", "lard", "écru + rouge", "boucher, garde-manger", None),
 ("q_bouteille_1", "pq_bouteille_verte", "cuisine_table", "bouteille de verre vert", "verre vert + bouchon", "tables, étagères (alias pq_bouteille aujourd'hui)", None),
 ("q_bouteille_2", "pq_bouteille_vin", "cuisine_table", "bouteille de vin", "verre sombre", "tables, cave", None),
 ("q_ecuelle", "pq_ecuelle", "cuisine_table", "écuelle de bois", "bois", "tables (bol maison)", None),
 ("q_ecuelle_2", "pq_ecuelle_2", "cuisine_table", "écuelle de terre cuite", "argile", "tables", None),
]

# pièces jamais converties (ni q_* ni pq_*)
NEUF_L = [
 ("pq_barreaux", MD % "Bars", "donjon", {"hauteur": 2.2}, {"Steel": "fer"}, "barreaux de cellule", "fer", "cellules, grilles de la crypte et du repaire"),
 ("pq_candelabre_court", MD % "Candelabrum", "eclairage", {"hauteur": 0.45}, {"Gold": "fer", "Candle": "v:ecru", "Black": "fer:0.5"},
  "candélabre de table (éteint)", "fer + cire", "tables de la crypte, autels (candélabres maison : flamme à ajouter)"),
 ("pq_torche_murale_d", MD % "Torch_wall", "eclairage", {"hauteur": 0.6}, {"DarkSteel": "fer:0.6", "Wood": "bois", "Fire": "suppr"},
  "torche murale de crypte (sans flamme)", "fer + bois", "appliques de la crypte (flamme et lumière du jeu à garder)"),
 ("pq_tonneau_cercle", MD % "Barrel", "rangement", {"hauteur": 0.9}, {"Wood": "bois", "Steel": "fer"}, "tonneau cerclé de fer",
  "bois + fer", "tonneaux de la crypte et de la grotte (variante de pq_tonneau)"),
 ("pq_trappe", DI % "Trapdoor", "donjon", {"longueur": 1.2}, DONJON, "trappe de bois ferrée", "bois + fer", "sol de la crypte, cave, grenier"),
 ("pq_coffre_or_2", DI % "Chest_Gold", "rangement", {"hauteur": 0.7}, DONJON, "coffre ferré doré", "bois + or terni", "trésor de la crypte"),
 ("pq_torche_bois", SV % "WoodenTorch", "eclairage", {"hauteur": 0.6}, {"DarkWood": "bois:0.7", "LightGrey": "fer", "Yellow": "v:tourbe"},
  "torche de bois (éteinte)", "bois + fer", "torche tenue / plantée, râtelier de torches"),
 ("pq_marmite_vide", UF % "CookingPot", "cuisine_table", {"hauteur": 0.3}, {"Grey": "fer"}, "marmite de fer", "fer",
  "foyers, cuisine (pq_marmite est en argile)"),
 ("pq_chaudron_anse", UF % "CookingPot2", "cuisine_table", {"longueur": 0.55}, {"Grey": "fer", "Brown": "bois"}, "chaudron à anse",
  "fer + bois", "foyer pendu, camp"),
 ("pq_poele_f", UF % "FryingPan", "cuisine_table", {"longueur": 0.5}, {"Grey": "fer", "DarkBrown": "bois"}, "poêle de fer",
  "fer + bois", "cuisine, foyers"),
 ("pq_lard_cuit", UF % "Bacon_Cooked", "objets_petits", {"longueur": 0.17}, {"Light": "v:ecru", "Meat": "v:laine_rouge*0.8"},
  "tranche de lard grillé", "brun", "tables du festin"),
]

# Medieval Village Pack (2019, Quaternius, CC0 ; Drive public, téléchargé le 2026-11-19) : props du village
V19 = {"DarkWood": "bois", "Wood_Side": "bois", "WoodSide": "bois", "Wood_Light": "bois", "Wood": "bois", "Bag_Inside": "v:tourbe*0.8",
       "Bag": "tissu:tourbe*0.7", "Stone_Dark": "v:pierre*0.75", "Stone_Light": "v:pierre*0.75", "Hay": "v:tourbe*0.85", "Leather": "v:cuir",
       "Metal": "fer", "DarkMetal": "fer:0.6", "RoofTiles_Red": "bois:0.65", "Plaster": "v:ecru*0.8"}
ETAL19 = dict(V19, RoofTiles_Red="tissu:laine_rouge*0.8", Red="tissu:laine_rouge*0.8", Beige="tissu:ecru*0.9")
NEUF_L += [
 ("pq_puits", MV19 % "Well", "exterieur_ferme", {"hauteur": 2.6}, V19, "puits couvert (margelle de pierre, toit de bardeaux)",
  "pierre + bois + toile", "puits de la place (kitbash maison : 8 dalles + briques + poutres + planches), puits des fermes"),
 ("pq_banc_dossier", MV19 % "Bench_1", "mobilier", {"hauteur": 0.85}, V19, "banc à dossier", "bois",
  "bancs de la place et des ruelles (banc maison / pq_banc), porche de la halle"),
 ("pq_banc_simple", MV19 % "Bench_2", "mobilier", {"hauteur": 0.45}, V19, "banc de planches", "bois",
  "bancs des intérieurs et du camp (helper banc maison)"),
 ("pq_tas_sacs", MV19 % "Bags", "exterieur_marche", {"hauteur": 0.55}, V19, "tas de trois sacs", "toile de jute",
  "sacs du marché (kitbash « sacs » maison : 2 q_sac + q_sac_debout), moulins, grenier"),
 ("pq_sac_couche", MV19 % "Bag", "exterieur_marche", {"longueur": 0.8}, V19, "sac de grain couché", "toile de jute",
  "réserves, meule de foin (kitbash de 6 q_sac), charrette"),
 ("pq_sac_ouvert", MV19 % "Bag_Open", "exterieur_marche", {"hauteur": 0.4}, V19, "sac de grain ouvert", "toile de jute + grain",
  "étals, moulin, grange"),
 ("pq_gerbe", MV19 % "Hay", "exterieur_ferme", {"hauteur": 1.1}, V19, "gerbe de paille liée", "paille",
  "meules de foin de l'enclos (kitbash maison), grange, épouvantails"),
 ("pq_etal_auvent", MV19 % "MarketStand_1", "exterieur_marche", {"hauteur": 2.5}, ETAL19, "étal à auvent rayé", "bois + toile rouge/écru",
  "étals de la place (étal maison 3 m = 2 pq_etal)"),
 ("pq_etal_etroit", MV19 % "MarketStand_2", "exterieur_marche", {"hauteur": 2.4}, ETAL19, "étal étroit à auvent", "bois + toile rouge/écru",
  "étals des ruelles"),
 ("pq_charrette_auvent", MV19 % "Cart", "exterieur_marche", {"hauteur": 2.0}, ETAL19, "charrette à bras à auvent",
  "bois + toile rouge/écru", "marchand ambulant, marché (charrette maison)"),
 ("pq_chaudron_pieds", MV19 % "Cauldron", "cuisine_table", {"hauteur": 0.65}, dict(V19, Stone="fer:0.7", Soup="v:tourbe*0.8", Orange="v:pin*0.8"),
  "chaudron à pieds (soupe)", "fer + soupe", "foyers des maisons, feu de camp, bivouac"),
 ("pq_ballot", MV19 % "Package_1", "exterieur_marche", {"longueur": 0.9}, V19, "ballot ficelé de cuir", "toile de jute + cuir",
  "réserves du marché, quai, charrette"),
 ("pq_ballot_2", MV19 % "Package_2", "exterieur_marche", {"hauteur": 0.55}, V19, "ballot cubique ficelé", "toile de jute + cuir",
  "réserves du marché, quai"),
 ("pq_cloche", MV19 % "Bell", "exterieur_ferme", {"hauteur": 0.6}, {"Bell": "v:or*0.7"}, "cloche de bronze terni", "or terni",
  "cloche d'alarme du guet, halle, temple"),
 ("pq_abri", MV19 % "Gazebo", "exterieur_marche", {"hauteur": 2.8}, V19, "abri à poteaux (toit de bardeaux)", "bois",
  "abri de marché, séchoir à peaux (kitbash maison), puits ouvert"),
 ("pq_barriere_lisses", MV19 % "Fence", "exterieur_ferme", {"hauteur": 1.0}, V19, "barrière à deux lisses", "bois",
  "enclos d'Ylva (pieux + lisses maison), abords"),
 ("pq_foyer_pierres", MV19 % "Bonfire", "exterieur_ferme", {"longueur": 1.4}, V19, "foyer : couronne de pierres et bûches (sans flamme)",
  "pierre + bois", "feu de camp (kitbash maison : 9 q_brique + q_bucher), foyers de plein air"),
 ("pq_caisse_planches", MV19 % "Crate", "rangement", {"hauteur": 0.8}, V19, "caisse de planches à croisillon", "bois",
  "caisses du marché (caisse_a/b/c maison)"),
 ("pq_tonneau_village", MV19 % "Barrel", "rangement", {"hauteur": 0.95}, dict(V19, Stone="fer:0.7"), "tonneau cerclé de fer", "bois + fer",
  "tonneaux du marché (tonneau_a/b/c maison)"),
 ("pq_porte_cave", MV19 % "Door_Straight", "mobilier", {"hauteur": 2.6}, V19, "porte ferrée sous encadrement de pierre (marches)",
  "bois + pierre", "entrée de cave, de crypte, de tumulus"),
 ("pq_porte_cave_ronde", MV19 % "Door_Round", "mobilier", {"hauteur": 2.6}, V19, "porte cintrée sous arc de pierre (marches)",
  "bois + pierre", "entrée de crypte, de cave"),
 ("pq_chevalet_scie", MV19 % "Sawmill_saw", "exterieur_ferme", {"longueur": 2.2}, V19, "chevalet de sciage (rondin et scie)",
  "bois + fer", "bûchers des fermes, scierie, tas de bois"),
]

# Ultimate RPG Pack (CC0) : seulement le trésor et l'ossuaire (le reste = objets d'inventaire, couronnes, cristaux violets : écartés)
RPG_M = {"DarkMetal": "fer:0.6", "Metal": "fer", "Wood": "bois", "Gold": "v:or*0.85", "DarkBrown": "v:cuir*0.8", "Brown": "v:cuir",
         "Beige": "v:ecru"}
NEUF_L += [
 ("pq_coffre_bombe", RPG % "Chest_Closed", "rangement", {"hauteur": 0.6}, RPG_M, "coffre bombé ferré (fermé)", "bois + fer",
  "coffres décor des maisons et de la crypte (variante de pq_coffre_ferme)"),
 ("pq_coffre_lingots", RPG % "Chest_Ingots", "rangement", {"hauteur": 0.75}, RPG_M, "coffre ouvert plein de lingots", "bois + fer + or terni",
  "trésor de la crypte (or_tas maison, q_coffre_or)"),
 ("pq_lingots", RPG % "Gold_Ingots", "objets_petits", {"longueur": 0.45}, RPG_M, "pile de lingots d'or", "or terni",
  "trésor (tas d'or maison or_tas_a/b/c)"),
 ("pq_grimoire", RPG % "Book3_Closed", "livres", {"hauteur": 0.32}, RPG_M, "grimoire à fermoir", "cuir + écru + or terni",
  "lutrin, archives, autel (livre maison)"),
 ("pq_os", RPG % "Bone", "donjon", {"longueur": 0.4}, RPG_M, "os long", "os", "os épars au sol de la crypte et de la grotte (os maison gardés)"),
]

# échelle RÉELLE (le q_* du lot 3 est à l'échelle brute du FBX, recadrée par le code de pose ; PropsQuaternius ramène de toute façon un
# pq_* à l'encombrement de son q_* quand « ancien » est posé) ; « sombre » = teintes assombries (lot 4 : pas de nourriture fluo)
ECH_Q = {"q_sac_debout": {"hauteur": 0.6}, "q_tonneau_2": {"hauteur": 0.9}, "q_seau_2": {"hauteur": 0.4}, "q_chaise_2": {"hauteur": 1.0},
         "q_coffre_2": {"hauteur": 0.6}, "q_colonne_1": {"hauteur": 3.2}, "q_colonne_2": {"hauteur": 3.2}, "q_caisse_2": {"hauteur": 0.8},
         "q_piedestal_1": {"hauteur": 1.1}, "q_piedestal_2": {"hauteur": 1.1}, "q_crane": {"hauteur": 0.2}, "q_pieux": {"hauteur": 0.6},
         "q_table_grande_2": {"hauteur": 0.8}, "q_table_petite_2": {"hauteur": 0.78}, "q_piege_pieux": {"longueur": 1.5},
         "q_banniere_mur": {"hauteur": 2.2}, "q_toile_araignee_1": {"longueur": 1.2}, "q_toile_araignee_2": {"longueur": 1.2}}
SOMBRE = {"q_citrouille": 0.72, "q_ecuelle_2": 0.78, "q_saucisse": 0.85, "q_carotte_f": 0.85, "q_jarre": 0.75, "q_cuisse": 0.88,
          "q_pomme": 0.85, "q_tapis": 0.85}
BUDGET_Q = {"q_porte_2_plate": 2500, "q_porte_2_ronde": 2500}


def charger_q():
    d = json.load(open(os.path.join(BASE, "sources_blender/quaternius/props.json"), encoding="utf8"))
    return {e["nom"]: e for e in d}


def mats_q(e, force):
    if force:
        return force
    src = e["src"]
    if "medieval_village" in src:
        return VILLAGE
    if e.get("mats"):
        return {k: BIBLE.get(v, "auto") for k, v in e["mats"].items()} | {"Fire": "suppr"}
    return DONJON


def pack(src):
    for k, v in (("ultimate_rpg", "Ultimate RPG Pack"), ("medieval_village_pack_2019", "Medieval Village Pack (2019)"), ("ultimate_home_interior", "Ultimate Home Interior"), ("medieval_village", "Medieval Village MegaKit"),
                 ("lowpoly_modular_dungeon", "LowPoly Modular Dungeon"), ("medieval_dungeon", "Medieval Dungeon"),
                 ("survival", "Survival"), ("ultimate_food", "Ultimate Food")):
        if k in src:
            return v
    return "?"


def main():
    q = charger_q()
    out = []
    for i, s, cat, ech, mats, nom, mat, usage in UHI_L:
        e = {"id": i, "src": UHI % s, "categorie": cat, "mats": mats, "nom": nom, "matiere": mat, "usage": usage}
        e.update(ech)
        out.append(e)
    for qn, i, cat, nom, mat, usage, force in Q_L:
        eq = q[qn]
        e = {"id": i, "src": eq["src"], "categorie": cat, "mats": mats_q(eq, force), "nom": nom, "matiere": mat, "usage": usage,
             "equivalent_q": qn}
        if qn in ECH_Q:
            e.update(ECH_Q[qn])
        elif eq.get("hauteur"):
            e["hauteur"] = eq["hauteur"]
        elif eq.get("ech"):
            e["ech"] = eq["ech"]
        if qn in SOMBRE:
            e["sombre"] = SOMBRE[qn]
        if qn in BUDGET_Q:
            e["budget"] = BUDGET_Q[qn]
        out.append(e)
    for i, src, cat, ech, mats, nom, mat, usage in NEUF_L:
        e = {"id": i, "src": src, "categorie": cat, "mats": mats, "nom": nom, "matiere": mat, "usage": usage}
        e.update(ech)
        out.append(e)
    for e in out:
        e["pack"] = pack(e["src"])
    ids = [e["id"] for e in out]
    assert len(ids) == len(set(ids)), "id en double"
    json.dump(out, open(os.path.join(ICI, "props_sources_v5_liste.json"), "w", encoding="utf8"), indent=1, ensure_ascii=False)
    print(len(out), "props v5")


main()
