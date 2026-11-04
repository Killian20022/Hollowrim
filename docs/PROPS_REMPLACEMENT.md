# Remplacement des props faits maison par les props Quaternius (CC0)

Branche `props/remplacement` (depuis e5c50e8f), 2026-11-03. Interrupteur A/B : `-- --sans-remplacement` rend les ANCIENS props
(captures « avant », mesures) ; `-- --sans-props-q` n'affiche aucun Quaternius (états d'avant le lot 3). Code : `scripts/props_quaternius.gd`
(`remplace`, `compter`), `Interieurs.qf/_q_xf/rempl`, `MobilierVillage.substitut`, `CrypteDecor.SUBST` / `_modele_subst`.
Méthode inchangée : fondu dans les lots existants (SurfaceTool par matière du mobilier, `Village._ajouter` par (pièce, matière), tampons
de la case de 8 m de la crypte) ; aucun nœud par objet ; collisions et emprises conservées (ou recalculées sur l'emprise du prop).

## Sources utilisées

| Pack | Licence | Utilisé pour | État |
|---|---|---|---|
| Fantasy Props MegaKit (94 objets) | CC0 | mobilier, vaisselle, outils, forge, marché | 100 % des pièces utilisables converties (lots 2 et 3) |
| Medieval Village MegaKit | CC0 | caisse, chariot, barrières, briques, portes, volets, fenêtres, bordures, marches, planches | props convertis (36 + 6) ; ~110 pièces modulaires de bâti (murs, toits, planchers) NON converties : architecture, pas props |
| LowPoly Modular Dungeon (itch.io, mai 2019) | CC0 | crypte / grotte : crâne, tonneau 2, caisse 2, chaise 2, coffre 2, colonnes, piédestaux, palissade, pieux, toiles d'araignée, bûcher, tables, vase, sacs | **récupéré le 2026-11-03** (`references/quaternius_props/lowpoly_modular_dungeon_itch/`), 26 convertis |
| Ultimate Nature (itch.io) | CC0 | bûche/tronc (WoodLog), souche (TreeStump) | **récupéré**, 2 convertis (`references/quaternius_props/ultimate_nature_itch/`) |
| Medieval Dungeon / Survival / Ultimate Food / Ultimate Home Interior (Google Drive) | CC0 | — | **toujours inaccessibles** : fichiers = pages « Quota exceeded » (2 040 octets), `drive_dl.py` renvoie 404 sur Survival et ne récupère que des pages d'erreur pour les trois autres (2026-11-03). Aucun miroir direct trouvé (itch.io ne les publie pas ; poly.pizza n'a pas de lot). À refaire quand le quota Drive sera levé : `drive_dl.py <id> <dossier>` puis `gen_props_lot3.py`. Le pack « LowPoly Modular Dungeon » d'itch est une version proche du « Medieval Dungeon » Drive. |
| KITBASH maison (`sources_blender/quaternius/kitbash/*.obj`) | — | bûche, poutre ronde | OBJ simples (8 pans, bouts chanfreinés) recolorés par la même chaîne (palette bible, couleurs de sommet, arêtes) |

Nouveaux props (lot 3, `sources_blender/scripts/gen_props_lot3.py`, 133 → 160 entrées de `props.json`, .dat 250 → 277 modèles) : q_coffre, q_hache_outil,
q_pioche, q_bouclier_bois, q_epee_mur, q_chandelier_table, q_chaine, q_bordure_1/2/angle, q_marches_ext, q_planches_sol, q_banniere_toile,
q_banniere_2_toile, q_buche, q_poutre_ronde, q_sac_pieces, q_sac_debout, q_banniere_mur, q_tonneau_2, q_seau_2, q_chaise_2, q_coffre_2,
q_toile_araignee_1/2, q_colonne_1/2, q_caisse_2, q_palissade(+bout, angle), q_piedestal_1/2, q_crane, q_pieux, q_epee_support, q_table_grande_2,
q_table_petite_2, q_piege_pieux, q_vase_5, q_bucher, q_tronc, q_souche.

## Tableau de remplacement

« Kitbash » = pas d'équivalent direct : le remplaçant est ASSEMBLÉ avec des pièces Quaternius.

### Village (dehors)

| Prop maison | Remplaçant Quaternius | Kitbash (pièces) | Endroit | Nombre |
|---|---|---|---|---|
| banc (module) | q_banc (Bench), ajusté 1,8 x 0,46 x 0,4 | — | place, ruelles | 4 |
| bancs du porche de la halle (`_banc`, boîtes) | q_banc | — | halle | 2 |
| tonneau_a / tonneau_b / tonneau_c | q_tonneau / q_tonneau_2 (Barrel2 dungeon) / q_tonneau | — | marché, ruelles, forge, camp | 5 / 3 / 2 (+1 forge) |
| caisse_a / caisse_b / caisse_c | q_caisse (Crate_Wooden) / q_caisse_2 (Crate dungeon) / q_caisse | — | marché, ruelles | 3 / 3 / 4 |
| sacs | 2 x q_sac + q_sac_debout | oui (groupe) | marché | 3 |
| charrette | q_chariot (Prop_Wagon) | — | marché | 1 |
| étal (3 m) | 2 x q_etal (Stall_Empty) côte à côte | oui (juxtaposition) | marché | 3 étals = 6 pièces |
| bannière (mât + tissu animé) | q_banniere (cadre) + q_banniere_toile (tissu, balancement conservé) | oui | place, ruelles | 6 |
| puits | — | **oui** : 8 dalles q_bordure_1 debout (margelle) + 8 q_brique + 4 q_poutre_ronde (poteaux) + 2 poutres + 2 q_planches_sol (toit) + q_seau_bois + q_corde_1 | place | 1 |
| tas de bois | — | **oui** : 30 q_buche (8 colonnes x 4 rangs) | marché sud, ruelle | 2 |
| meule de foin | — | **oui** : 6 q_sac (jute → foin) en pyramide | enclos d'Ylva | 3 |
| séchoir à peaux | — | **oui** : 2 q_poutre_ronde (poteaux) + traverse + 3 q_banniere_toile (peaux, lin) | enclos | 1 |
| enclos : pieux + lisses | q_barriere_bois (Prop_WoodenFence_Single) | — | enclos | 1 enclos (lisses ~11 segments) |
| forge : billot | q_billot_enclume (Anvil_Log) | — | forge ouverte | 1 |
| forge : meule | q_pierre_aiguiser (Whetstone) | — | forge ouverte | 1 |
| forge : foyer de plein air | — | **oui** : murets de q_brique (2 rangs) + q_bucher ; braises émissives de l'ancien module gardées (aucune pièce lumineuse Quaternius) | forge ouverte | 1 |
| feu de camp : couronne, bûches | — | **oui** : 9 q_brique + q_bucher (Woodfire) ; braises gardées | camp | 1 |
| troncs-bancs du camp | q_tronc (WoodLog, Ultimate Nature) | — | camp | 2 |
| tas de bûches des maisons (cylindres d'écorce) | q_buche | oui | murs des maisons | 2 tas |
| porte de maison close (vantail, bandes, loquet) | q_porte_1/4/8/2_plate (Door_* Medieval Village) | — | maisons closes | selon le village |
| volets des fenêtres (boîtes) | q_volets_thin_flat_open (WindowShutters) | — | maisons closes | selon le village |
| boucliers du porche (cylindres) | q_bouclier_bois (Shield_Wooden) | — | halle | 4 |
| densification marché/ruelles | q_tonneau_pommes x2, q_cageot_vide + q_cageot_pommes, q_corde_2, q_bourse, q_sac_debout, q_sac, q_support_tonneau, q_souche + q_hache_outil, q_tronc, q_seau_bois, q_caisse, q_cageot_carottes, q_corde_1 | — | marché, ruelles | **+14 entrées de POSES_D** (allégé après mesure) |
| brasero (3) | **gardé** | — | luminaire validé (feu, lumière) | 3 |
| vantaux des portes ouvrables (`_vantail`) | **gardés** | — | objet interactif (charnière) : logique inchangée | — |
| lanternes pendues, enseignes, torches murales | **gardés** | — | luminaires / architecture (émissif réglé par l'heure) | — |
| palissade (pieux taillés), escaliers, murs de soutènement, pavés (rues_village.gd) | **gardés** | — | architecture du terrain | — |
| `village.gd` `_puits`, `_brasero`, `_accessoires` | **code mort** (jamais appelé) : non touché | — | — | 0 |

### Intérieurs (halle, Sigrun, chasseurs, Grima, forge) : helpers d'`interieurs.gd`

Chaque helper garde sa signature et ses collisions ; seul le visuel change. Mêmes remplaçants dans les cinq maisons.

| Helper maison | Remplaçant | Kitbash | Appels (sites) |
|---|---|---|---|
| table (tréteaux) | q_grande_table (Table_Large) ; plan de travail haut (> 0,83 m) → q_etabli (Workbench) | — | 7 |
| banc | q_banc | — | 7 |
| tabouret | q_tabouret (Stool) | — | 6 |
| coffre (décor) | q_coffre (Chest_Wood, lot 3) | — | 9 |
| tonneau | q_tonneau | — | 9 |
| étagère 4 niveaux | q_etagere_arche (Shelf_Arch) ; hauteurs des objets rangés = `niv(i)` | — | 3 |
| lit | q_lit / q_lit_2 (Bed_Twin) | — | 5 |
| bouclier mural | q_bouclier_bois (teinté par la matière demandée) | — | 3 |
| assiette / chope / chaudron / bol / cruche | q_assiette / q_chope / q_chaudron / q_marmite (argile) / q_vase_4 ou q_vase_2 | — | 4 / 3 / 2 / 3 / 7 |
| livre / parchemin | q_livre_7 / q_parchemin | — | 1 / 2 |
| sac | q_sac | — | 5 |
| bougie | q_bougie_1 (flamme et lumière inchangées) | — | 11 |
| hache / épée / lance (décor mural) | q_hache_outil / q_epee_mur / lance = q_poutre_ronde + q_epee_mur réduit | oui (lance) | 3 / 2 / 1 |
| bûches (tas, foyers, `rondin` court) | q_buche (kitbash) | oui | 2 tas + foyers |
| tapis / peaux au sol (`peau_sol`) | tissu de bannière q_banniere_toile couché | **oui** | 8 |
| viande séchée | jambons = q_bourse, saucissons = q_carotte retournée, ficelle = q_poutre_ronde | **oui** | 6 |
| bouquets d'herbes | 5 q_carotte retournées (matières herbe/foin) + barre | **oui** | 3 |
| balance de marchand | q_assiette (plateaux) + q_poutre_ronde (fût, fléau) | **oui** | 1 |
| halle : estrade | caisson de q_planches_sol (dessus, face avant, côtés) | **oui** | 1 |
| halle : trône | q_chaise agrandie + q_bouclier_bois au dossier | **oui** | 1 |
| halle : dressoir d'angle | q_etabli_tiroirs (Workbench_Drawers) | — | 1 |
| halle : râtelier d'armes | 2 q_porte_manteau (Peg_Rack) + haches/lances Quaternius | oui | 2 |
| forge : enclume + billot | q_billot_enclume (Anvil_Log) + q_hache_outil couchée | — | 1 |
| forge : soufflet | — | **oui** : q_banc (tréteau) + 2 q_planches_sol + q_sac (cuir) + q_poutre_ronde (buse) | 1 |
| forge : bac de trempe | — | **oui** : q_cageot_vide + eau noire + q_seau_bois | 1 |
| forge : caisse à charbon | q_cageot_vide (charbon dedans) + q_pioche (pelle) | oui | 1 |
| forge : meule | q_pierre_aiguiser | — | 1 |
| forge : râtelier d'outils / de lames | 2 q_porte_manteau + 3 q_hache_outil + q_pioche + q_chaine | oui | 2 |
| densification | halle : q_chandelier_table sur chaque table (+4) ; forge : q_chaine (rouleau au sol), q_marmite sur le foyer (+2) | — | +6 |
| crâne, ramure de cerf, os au sol, carquois, arc, fers à cheval, paille | **gardés** : organique / pièces minuscules sans équivalent (Quaternius n'a ni ramure, ni arc, ni fers) | — | ~25 |
| râtelier de l'Épée unique, applique, lanterne de halle | **gardés** : objet unique L9 / luminaires validés | — | — |
| fourrure froissée du lit défait | **gardée** (une seule pièce) | — | 1 |
| poteaux, plancher, plafond, entraits, foyers de pierre (`pile`) | **gardés** : architecture | — | — |

### Crypte et grotte : remplacement central dans `CrypteDecor.modele()` (table `SUBST`)

Le module maison est remplacé par le prop, ajusté aux bornes de l'ancien module (même emprise, même échelle `ech`). Les cassables
(tonneaux, urnes, caisses de la grotte) gardent `cassable_debut/fin` : la logique n'est pas touchée. Les corps fouillables ne sont pas touchés.

| Module maison | Remplaçant | Endroit |
|---|---|---|
| tonneau_a/b/c | q_tonneau / q_tonneau_2 | crypte, grotte |
| table_a/b/c | q_grande_table | crypte |
| lit_a/b | q_lit / q_lit_2 (quart de tour) | casernes de la crypte |
| g_couchage_a/b | q_lit / q_lit_2 | camp de la grotte |
| etagere_cadre_a/b (+ contenu retiré : le prop porte ses livres) | q_bibliotheque | archives |
| ratelier_cadre_a/b, g_ratelier | q_rack_armes (WeaponStand) | armureries, grotte |
| sac_a/b | q_sac_pieces | crypte |
| urne_a/b/c | q_vase_4 / q_vase_5 / q_vase_2 | crypte (cassables) |
| crane_a/b | q_crane (Skull, Modular Dungeon) | crypte, grotte |
| or_tas_a/b/c | q_tas_pieces / q_tas_pieces_2 (matière or) | trésor |
| g_caisse_a/b, g_sac_a/b/c, g_tabouret_a/b | q_caisse_2 / q_caisse, q_sac, q_tabouret | grotte (mine, camp) |

Gardés dans la crypte : coffres L1 (cuve/couvercle/royal), sarcophages, statues, luminaires L8 (lustres, candélabres, braseros, appliques,
cages), ossuaire v2 (crânes anatomiques, niches), armes (arme_*, hache de Kolbeinn), présentoirs uniques, gravats et monticules d'os
(roche / os en tas : pas d'équivalent ; à refaire en briques cassées Quaternius si on veut), planches, poteaux et chaînes micro, garnitures de table.

## Pièces Quaternius non (encore) posées

Les ~110 pièces de bâti du Medieval Village (murs, toits, planchers, balcons, escaliers) sont de l'architecture : les remplacer revient à refaire
tout le bâti (non demandé). `q_marches_ext`, `q_bordure_*`, `q_palissade*`, `q_colonne_*`, `q_piedestal_*`, `q_pieux`, `q_piege_pieux`,
`q_epee_support`, `q_banniere_mur`, `q_toile_araignee_*`, `q_table_*_2`, `q_chaise_2`, `q_coffre_2`, `q_seau_2`, `q_sac_debout` sont convertis et
disponibles dans le .dat (utilisés : voir ci-dessus ; les autres sont prêts pour les prochains décors).

## Mesures (outils/mesure_perf.gd, 2 répétitions avant/après, GPU partagé donc bruité)

Compteurs : village_marche = 132 remplacements ; MobilierVillage 26 701 -> 49 356 triangles (construction 133 -> 305 ms).
Les « Appels (sites) » ci-dessus sont des estimations par grep, pas des comptes d'exécution.

| Zone | GPU médian avant -> après (ms) | Primitives | Draw calls |
|---|---|---|---|
| place | 10,8 -> 10,9 / 10,8 -> 11,7 | 938k -> 1,06M | 750 -> 736 |
| marché | 10,5 -> 10,4 / 10,3 -> 10,6 | 878k -> 1,0M (+14 %) | 674 -> 666 |
| forge | 8,8 -> 10,4 / 8,5 -> 8,5 | 527k -> 533k | 501 -> 500 |
| halle | 8,6 -> 8,5 / 8,6 -> 10,1 | 527k -> 533k | 501 -> 500 |
| crypte | 1,36 -> 1,36 / 1,35 -> 1,34 | 50,8k -> 50,8k | 123 -> 123 |

Lecture : les écarts de +1,5 ms isolés sont du bruit de GPU partagé (un run « après » seul, l'autre identique à l'avant). Sur la 2e série, marché
+0,0 à +0,3 ms, place +0,1 à +0,9 ms (budget +0,5 ms tenu en moyenne, pas garanti). Limite : forge, halle et crypte mesurent un cadrage
dont le contenu remplacé est peu visible (primitives quasi identiques) ; le coût réel de ces intérieurs est donc sous-mesuré.

## Lot 4 (props/lot4)

Sources : Medieval Dungeon, Survival et Ultimate Food (Quaternius, CC0), matières de nourriture MATS_NOURRITURE passées par le shader ps1.

- **Crypte** (`CrypteDecor`, table `SUBST` + nouveaux groupes) : os épars maison d'origine gardés (pas de squelette entier) avec un crâne en plus, piles de livres et groupes de fioles à l'échelle x1,3, toiles/gravats inchangés. Le module `assets/crypte/modules/props_quaternius.dat` est régénéré.
- **Village** : étal du boucher avec viandes pendues, miches groupées, étals de la place éclaircis (légumes, choux), tables de la halle, de Sigrun, des chasseurs et de Grima garnies de nourriture et vaisselle (`interieurs.gd`, `interieur_halle.gd`, helper nourriture/vaisselle posée sur `pos`), tente du camp tournée vers le feu.
- **Grotte** (`grotte_decor.gd`, `grotte_modules.gd`) : camp (tente, rondins, ustensiles), mine et repaire ; les rondins du camp n'ont pas de collision (ils barraient la capsule de test), les autres pièces ont une boîte `solide_b`.
- **Interrupteur** : `-- --sans-lot4` (exe 3 = lot 3 seul), lu dans `PropsQuaternius.lot4` ; `--sans-remplacement` coupe tout.
- **Perf** : non remesurée sur ce lot (marché/place/intérieurs mesurés au lot 2 seulement) ; la nourriture ajoute des dizaines de petites instances par table, à surveiller en intérieur.
- **Limites** : sous l'éclairage sombre des intérieurs et à distance, la nourriture est peu lisible (silhouettes brunes sur bois brun) ; plusieurs pièces de la crypte (livres) restent petites et grisâtres comparées à l'ancien décor brun ; mêmes tests headless OK (crypte, cassables, butin, interieurs, grotte). Planches : `Skyrim captures/props_lot4/planches_v2/{crypte_v2,village_v2,grotte}`.
