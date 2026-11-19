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

## Props TEXTURÉS PS1 partout (props/quaternius, 2026-11-10)

Les `q_*` (couleurs de face, sans texture) sont remplacés par leurs `pq_*` texturés (94 props + `pq_coffre_ferme`, catalogue
`data/props_quaternius.json`, champ `ancien`) PARTOUT où le code les pose, sans toucher aux sites d'appel :

- **Données** : `outils/export_props_quat_dat.gd` (headless, à relancer après toute régénération des glb) écrit
  `assets/modeles/props_quat/props_quat.dat` (« PQD1 » : par prop, surfaces = atlas + sommets position/normale/UV/couleur + index).
  `PropsQuaternius._charger_pq` le lit par FileAccess dans le fil qui en a besoin (aucun .glb chargé dans un fil) et ramène chaque
  `pq_*` à l'encombrement de son `q_*` (échelle uniforme, pied et centre de l'emprise alignés) : poses, plateaux, collisions inchangés.
- **API inchangée** : `morceaux / triangles / maillage_brut / boite / nb_triangles / village / crypte` renvoient le `pq_*` (matière
  d'un morceau = atlas `pq_bois`, `pq_fer`, `pq_fer_v`, `pq_tissu(_v)`, `pq_props(_v)`, `pq_page`) ; un matériau partagé par
  (atlas, contexte) : `PropsQuat.materiau` dehors (ps1, neige) et dedans (ps1_interieur), `CrypteDecor.mat` (shader de la crypte,
  atlas, sans neige) sous terre. Lots regroupés PAR ATLAS : 8 matériaux au plus par lot en plus de ceux déjà là.
  Crypte / grotte : modules versés sous « pq:<q_*> » dans `CrypteDecor._modeles` avec leurs UV (`_modele_cache` les garde).
- **Interrupteur** : `-- --props-quat-ancien` = les `q_*` d'avant (captures « avant », mesures A/B). Les `q_*` restent dans le .dat.
- **Exceptions** (le `q_*` reste) : kitbash reteint (`KITBASH_SI_MATS` : carotte = saucisson, bourse = jambon, toile de bannière =
  peau / tapis, sac = foin ou cuir, marmite d'argile, épée = fer de lance ; quand la pose change une matière) ; objets ramassables
  (`ObjetsVivants.morceaux_q` : leurs modèles relèvent de data/objets/, autre chantier).
- **Coffres** : `Interieurs.coffre` (décor, fermé par défaut) pose `pq_coffre_ferme` (pose « Chest_Closed » du pack,
  `props_quaternius.py` entrée `pose`) ; le `pq_coffre` ouvert reste pour les coffres ouverts.
- **Ajouts** : torches murales du village (`Village._torche_murale` : applique Torch_Metal, même flamme et même lumière), râtelier
  d'armes de la halle (`pq_rack_armes`), crypte : chaîne lovée et cage au crâne (salle de préparation), lutrin et candélabre éteint
  (archives), candélabre éteint et chaîne (salle de garde).
- **Perf** (`outils/mesure_perf.gd`, fenêtre, 2 tours alternés ancien/pq, moyenne des médianes GPU, machine chargée par d'autres
  agents) : village jour 16,00 → 16,24 ms (+1,5 %, +15 à +28 draw calls, +64 k à +78 k primitives) ; marché 15,50 → 14,50 ms
  (bruit, +10 draw calls) ; halle 11,23 → 11,23 ms (+12 à +16 draw calls) ; crypte 1,37 → 1,36 ms (±1 draw call). Sous le plafond
  de +5 %.

## Maximum de props texturés (props/maximum, 2026-11-11)

Base : biome/zone-temoin 28409609 + fusion de props/quaternius (pq_* fondus dans les lots, jamais fusionnée jusque-là). Tout ce qui suit
n'existe qu'avec les props texturés : `-- --props-quat-ancien` rend EXACTEMENT l'état de biome/zone-temoin (q_* d'avant, aucune
composition), c'est le « avant » des planches et des mesures. Poses : `outils/poses_props_max.txt`.

### Inventaire lieu par lieu (ce qui restait ancien, et ce qui le remplace)

« auto » = le q_* a son pq_* (catalogue `ancien`) : remplacé partout où le code le pose (fusion props/quaternius). « alias » = q_* sans pq_*
propre, servi par le pq_* du même objet (`PropsQuaternius.ALIAS_PQ`, nouveau). « gardé » = pas d'équivalent pq_* ou choix validé.

| Lieu | Ancien (q_* ou maison) | Équivalent pq_* | Décision |
|---|---|---|---|
| village extérieur | 64 q_* du MegaKit (tonneaux, caisses, sacs, étals, bannières, bancs, cageots, seaux, cordes, bourses…) | pq_* du même nom | auto |
| | q_tonneau_2 (1,34 m, POSES_D + tonneau_b), q_caisse_2 (caisse_b), q_sac_debout | pq_tonneau, pq_caisse_fer, pq_sac | alias |
| | nourriture (Ultimate Food : pains, choux, poissons, viandes…), q_jarre, q_marmite_camp, q_tente, q_rondin, q_feu_bois, q_hache_camp | aucun | gardé |
| | q_brique_*, q_buche, q_poutre_ronde, q_planches_sol, q_bordure_1, q_bucher (kitbash puits, foyers, tas de bois) | aucun | gardé (pièces de construction) |
| | portes, volets, briques du bâti (village_bati) | aucun | gardé (architecture) |
| | brasero, lanternes, enseignes, torches (luminaires validés), palissade, pieux bas, grilles d'eau | — | gardé (consigne) |
| | bivouac du feu de camp : rien à l'ouest de la tente | — | AJOUT : réserves (2 tonneaux, caisse + cageot, sac, seau, corde) |
| abords | barrières q_barriere_bois / _ext_2, chevaux de frise q_poutre_ronde, q_piege_ours | aucun pq_* (le MegaKit n'a pas de barrière) | gardé |
| | rochers, buissons, touffes, os, cairns, bordure du tumulus | — | gardé (consigne) |
| intérieurs | tables, bancs, tabourets, coffres, tonneaux, étagères, lits, vaisselle, bougies, livres, sacs (helpers d'Interieurs) | pq_* | auto (coffre décor fermé = pq_coffre_ferme) |
| | q_bouteille_1 / _2 | pq_bouteille | alias |
| | nourriture, q_couteau_f, q_cuillere_bois (pq_cuillere est en métal), kitbash reteints (KITBASH_SI_MATS : saucisson, jambon, peaux, soufflet) | — | gardé |
| crypte | tonneaux, tables, lits, étagères, râteliers, urnes, crânes de SUBST (via q_*) | pq_* | auto ; tonneau_c (q_tonneau_2) et urne_b (q_vase_5) → alias |
| | piles de livres des tables (q_livre_d1/d2 empilés), livres épars | pq_pile_livres / _2, pq_livre_7 / _5 | REMPLACÉ ; livre ouvert gardé (aucun pq_*) |
| | q_sac_pieces (sac couché), q_tas_pieces, q_crane, q_tapis, q_roc_*, q_coffre_d / q_coffre_or | — | gardé (pq_sac debout serait écrasé ; tas de pièces : disques ; crâne pq absent) |
| | coffres interactifs L1 (cuve + couvercle animé + or), sarcophages, statues, ossuaire, armes | pq_coffre_ferme d'un bloc | gardé : le couvercle pivote sur sa charnière (CoffreCouvercle) ; pq_coffre n'a pas de couvercle séparé |
| | luminaires L8 (lustres, candélabres, braseros, appliques) | pq_lustre, pq_chandelier_pied | gardé (validés, flammes et lumières) ; pq_* ajoutés éteints dans les compositions |
| | salles vides le long des murs | — | AJOUT : compositions (voir plus bas) |
| grotte / mine / camp | g_caisse_a (q_caisse_2), g_caisse_b, g_sac, g_tabouret, g_couchage, g_ratelier, tonneaux | pq_caisse_fer (alias), pq_caisse, pq_sac, pq_tabouret, pq_lit, pq_rack_armes, pq_tonneau | auto / alias |
| | camp lot 4 : tente, rondins, poêle, hachette, couteau, viande, arêtes, marmite pendue, piège à ours | aucun | gardé |
| | chariots, rails, étais, lanternes de mine, braseros de fer | — | gardé (architecture / luminaires) |
| | galerie, chambre de la mine et carrefour sans poste de travail | — | AJOUT : établi, réserve, halte |
| tumulus (extérieur) | pierres levées, stèle, dalles, butte | — | gardé (consigne) |

### Compositions ajoutées (scènes de vie, jamais un objet seul) — v2

Crypte : `CrypteDonjon._compo` (fin de `crypte_donjon.gd`, tables `C_*`) pose une composition d'un bloc et la REFUSE (rien de posé,
avertissement « composition refusée … » avec la raison de chaque essai) si un item au sol sort de la salle (soubassement + panneaux),
touche une voie de porte, une réserve de la table (ennemi, coffre, interaction, mécanisme), une ronde de gardien ou une emprise déjà
posée ; essais décalés le long du mur. `-- --compos-debug` imprime la carte des emprises de la salle refusée.
Ordre dans `DonjonKit.module` (seulement avec les props texturés) : récit de la salle → BRASEROS différés (`_emettre_differes(m,
["brasero"])` : ils ne bougent plus) → compositions (`_apres_module`) → gravats, détritus, givre différés et semis v2 (`CrypteV2.finir`)
qui s'écartent des compositions. Sans pq_* l'ordre d'avant est intact. Bougies ALLUMÉES seulement si chaque maillage de 8 m touché garde
6 lumières au plus (`lumiere_possible(..., 6)` : marge de 2 pour les lumières du semis ; test_crypte « 8 lumières par maillage » OK).
Collisions : boîtes des gros items, tonneaux et urnes par `CrypteDecor.tonneau / urne` (cassables, butin inchangé). Remplissage libéré
pour faire de la place : coffre décoratif q_coffre_d des quartiers, arme au sol de l'armurerie (sans valeur de jeu).

| Salle | Composition | Contenu |
|---|---|---|
| prep (préparation) | râtelier garni, mur nord | pq_rack_armes, pierre à aiguiser, caisse ferrée + bouclier, épée et hache dressées |
| antichambre | offrandes à la Dame, mur ouest | buffet, bougeoir triple, calice, assiette, bougie allumée |
| reliquaires | coin du gardien des reliques, mur nord | lutrin, bibliothèque, pile de livres + bougie, candélabre |
| quartiers | table de jeu sur tonneau ; caisses empilées entre les lits du mur sud | tonneau, 2 tabourets, chopes, pièces, bougie ; caisse + caisse ferrée + sac |
| armurerie | mannequin d'armurier, mur sud | mannequin, bouclier |
| g4 (trône) | 2 râteliers entre les statues et les coffres givrés | rack, caisse ferrée, bouclier, épée |
| lb1 (salle de garde) | garde-manger, mur sud | support à tonneaux, tonneau cassable, 2 caisses + cageot, 2 sacs, seau |
| lb2b (barricade) | bivouac de l'expédition, mur nord | 2 sacs, marmite, seau, corde |
| lb1 râtelier | — | refusé : mur nord pris par l'archer, les coffres et le brasero |

Pièces écrasées corrigées : avec les pq_*, `table_a/b/c`, `ratelier_cadre_a/b` (crypte) et `g_ratelier` (grotte) gardent leur pièce
maison (`CrypteDecor.SUBST_GARDE_PQ`) : la grande table de 2,7 m tassée à 1,1 x 0,65 m (x 0,4) et le râtelier SUR PIED aplati en râtelier
mural (17 cm de fond, z 0,13) étaient déformés, et aucun pq_* n'a la bonne forme.

Grotte : `GrotteModules.differer` met les compositions en attente ; `poser_differees` les pose EN DERNIER (`GrotteDecor.finir`, après
glaçons, givre, congères et cailloux) : le décor aléatoire est identique à celui d'avant (mêmes tirages, mêmes places), les compositions
s'en écartent (`Grotte.libre` + `GrotteDecor.pose_objet` vérifié pour chaque item au sol, essais à ±0,8 / ±1,6 m et candidats tous les
2,5 m des deux côtés). Établi des mineurs (chambre), réserves (galerie, sortie du lac), halte (carrefour, retour de la mine), poste de guet
(abords du repaire), râtelier garni et vivres (camp des bandits).

Village : réserves du bivouac du feu de camp (`MobilierVillage.BIVOUAC_PQ`, une boîte de collision) ; matériel de pêche au bout du quai
(`EauVillage.QUAI_PQ`, `PropsQuaternius.lot_pq` : UN maillage par atlas et UN corps statique pour le groupe) ; coin d'abreuvoir et de
grain dans l'enclos d'Ylva (`Village.ENCLOS_PQ`, fondu dans les lots du village). Forge, halle et marché : déjà pleins (lots 2 à 4).

Sous terre, les atlas pq_* passent par `CrypteDecor.mat` avec `PQ_SATURATION` 0,62 et `PQ_TEINTE` (0,78 ; 0,72 ; 0,68) : le bois orangé
et propre du pack jurait avec le bois patiné de la crypte et du camp (planches avant/après).

### Perf (avant = `--props-quat-ancien`, nuit 21 h) — v2

`outils/audit_mesure_lieu.gd`, 12 s de mesure, PC sur secteur, AUCUN autre Godot actif, 3 passes ALTERNÉES avant/après dans la même
fenêtre de temps (30 lancements, `/tmp/pm_banc.sh`). La machine refroidit d'une passe à l'autre (le GPU du témoin passe de 11 à 8 ms
dans les DEUX modes) : on lit les écarts PAR PAIRE (après − avant de la même passe), puis leur moyenne.

| Lieu | gpu_med avant -> après (médianes) | écarts gpu par paire (ms) | dt_med (CPU + GPU) écarts par paire | appels | primitives | images > 33 ms (3 passes) |
|---|---|---|---|---|---|---|
| témoin (feu de camp) | 9,21 -> 10,13 | -0,14 / +0,92 / +0,26 (moy. +0,35) | -4,5 / +1,4 / +0,5 | 500 -> 506 | +2,3 % | 26, 33, 28 -> 15, 38, 32 |
| halle | 14,20 -> 10,37 | -3,8 / -3,8 / -1,5 | +10,9 / -4,9 / -1,2 | 567 -> 567 | +2,9 % | 56, 62, 7 -> 175, 41, 35 |
| place | 15,20 -> 12,41 | -1,4 / -2,8 / -0,5 | -1,3 / -3,1 / +0,1 | 931 -> 985 | +7,0 % | 52, 33, 2 -> 85, 32, 1 |
| crypte (prep) | 2,98 -> 2,99 | +0,04 / +0,01 / 0,00 | -1,0 / +0,2 / +0,1 | 270 -> 275 | +9,3 % | 3, 4, 4 -> 5, 6, 6 |
| grotte | 3,41 -> 3,47 | 0,00 / +0,08 / +0,06 | +4,0 / -0,2 / +1,1 | 367 -> 377 | +6,8 % | 0 -> 0 |

Lecture : aucun lieu ne dépasse le budget de +0,5 ms GPU en moyenne (témoin +0,35 ms, une paire à +0,9 ms ; halle et place PLUS
légères : le matériau partagé ps1_interieur et les atlas pq_* coûtent moins que les matières reteintes des q_*). Le CPU (dt_med) n'a pas
d'écart stable : la 1re passe (machine pas encore refroidie) donne +10,9 ms à la halle mais -4,5 ms au témoin ; les deux passes suivantes
sont à ±1,5 ms. La hausse 19,8 -> 31,7 ms de la v1 venait de la charge (autres agents Godot). Images > 33 ms : même ordre de grandeur
avant/après, sauf la 1re passe de la halle (175, même passe que le +10,9 ms). Aucun nœud par prop : compositions fondues dans les
tampons (crypte, grotte, village), lot_pq du quai = 1 maillage + 1 corps statique ; +63 nœuds au total = MeshInstance3D des lots par
atlas des intérieurs (fusion props/quaternius), sans script.

## Props v3 : abords, restes, intérieurs (props/maximum, 2026-11-11)

Interrupteur A/B : `-- --sans-props-v3` (`PropsQuaternius.v3`) rend EXACTEMENT la v2 (mêmes refus, mêmes places) ; `--props-quat-ancien`
reste l'état d'avant tous les props texturés. Même esprit que la v2 : des scènes de vie lisibles, jamais un objet seul, fondues dans un
maillage par composition (aucun nœud par prop), le décor tiré au hasard ne bouge pas, tout reste nordique (pièces hors thème écartées).

### Abords du village et du monde (`scripts/abords_props.gd`, `AbordsProps.creer`, appelé par `monde.gd` après le dallage)

Une composition = UN `MeshInstance3D` + UN `StaticBody3D` (`PropsQuaternius.lot_pq`, qui admet maintenant les `q_*` du kit Medieval
Village sans équivalent pq_* — charrette, tente, rondins, souche, poutre — une surface par matière du village), visible jusqu'à 70 m
(brouillard). Chaque ancre est essayée telle quelle puis glissée de ±1 / ±2 m, puis sur des couronnes de 3, 5 et 7 m ; elle est refusée si
un item au sol touche un arbre, un chemin (marge 2 m, 0,4 m pour les poteaux indicateurs qui se tiennent AU BORD du chemin), une pente trop
forte (0,57 m sous un petit item ; 0,9 m sous un grand item solide, qui est alors INCLINÉ comme le terrain), un corps physique (rochers,
barrières, bâti) ou une autre composition. Une composition par image (l'écran de chargement reste animé). Nature maison non touchée.

| Lieu | Composition | Contenu |
|---|---|---|
| bord du champ nord (73, −6,5) | charrette abandonnée | q_chariot, sacs renversés, tonneau, pioche couchée, seau |
| champs est (83,5, 35 / 81, 46) | 2 épouvantails | perche + traverse (poutres), sac en tête, haillon de toile |
| portail des champs B et C | récolte rentrée | tonneau de pommes, sacs, cageots de carottes et de pommes, seau |
| fermes A et B, lisière du feu de camp | 3 bûchers | rondins en trois rangs, billot (souche) + hache plantée, bûches |
| lisière sud (7, −19) | campement de chasseur | tente, foyer éteint + marmite, rondin-banc, séchoir (viande, poisson), 2 pièges à ours, sac, corde, seau, hachette |
| cercle runique, tumulus | offrandes | dalle basse : crâne, calice, bougies, pain, pomme, pièces dessus ; vases, urne, pomme au pied |
| fourches (cercle, tumulus, grotte) | 3 poteaux indicateurs | poteau, deux planches en flèche, lanterne murale éteinte |
| devant la grotte (86,5, −21,5) | réserve des bandits | caisses empilées, caisse ferrée, tonneau, sac, bûches |

Retiré : la charrette du champ A (pente > 0,9 m partout autour, même inclinée). Outil de captures : `-- --abords-vues=<fichier>` écrit deux
points de vue DÉGAGÉS par composition (pas d'arbre, rayon libre jusqu'à elle, ni relief ni bâtiment entre) au format `--captures`
(`outils/poses_abords_auto.txt`, repris dans `outils/poses_abords_v3.txt` avec les vues de la crypte et de la grotte).

### Restes de la v2 (compositions refusées partout)

| Lieu | v2 | v3 |
|---|---|---|
| grotte, galerie de repos de la mine (A) | halte refusée (banc + tonneau trop larges) | repli ÉTROIT `G_HALTE_ETROITE` (tabouret, caisse + chope, seau, sac) aux mêmes places |
| grotte, poste de guet du repaire (B) | refusé : couloir d'accès trop étroit partout | passe à l'entrée du camp (T2), version étroite en repli |
| grotte, vivres du camp (T2) | refusés (3 places seulement) | + candidats tous les 2,5 m |
| grotte, objets longs (banc, support à tonneaux) | testés sur leur rayon | testés par trois cercles le long de leur flanc (la paroi ne les refuse plus pour rien) |
| crypte, salle de garde (lb1) | râtelier refusé (mur nord) | repli mur ouest puis mur est : râtelier garni au mur est ; le sac éventré passe au pied des tonneaux ; la statue encapuchonnée du semis qui s'y tenait s'en écarte (une de moins) |
| crypte, quartiers | caisse + caisse ferrée + sac | caisses empilées + cageot de carottes + sac |

Les replis de la crypte ne préviennent plus (`_compo(..., repli = true)`) : seul l'échec du dernier emplacement est un avertissement.

### Intérieurs : coins de métier (branche `props/maximum-interieurs`, `scripts/interieurs_metiers.gd`)

Après le mobilier de fonction des bâtiments ouverts (`BatimentsOuverts.amenager`), `InterieursMetiers.habiller` pose au plus 6 coins par
pièce contre les murs avec le même répartiteur (`Murs.poser_ou` : porte, vantail, fenêtres et meubles dégagés, milieu libre), fondus dans
les lots de la pièce ; aucune lumière, aucun tirage de `b.rng`. Chasseurs et trappeurs : séchoir à peau, peau + raquette au mur, pièges,
caisse + corde + hachette, bûches, sac. Paysans et fermes : sacs, cageot de carottes + choux, outils au mur (pioche, hache), support à
tonneaux, cageots, bûches. Moulins : sacs de farine, caisses + sac, tonneaux. Grenier : caisses, tonneau de pommes, cageots, sacs. Grange :
établi, outils, sacs, bûches, seau. Étable : seaux, sac. Tour du guet : caisse + bouclier, tonneau. Bûches empilées bouts sciés vers la
pièce (lisibles). `test_interieurs` : OK (1 087 s, machine chargée).

### Mesures v3 (`outils/audit_mesure_lieu.gd`, 21 h, 12 s, médiane GPU en ms, passes alternées v2 = `--sans-props-v3` / v3, machine chargée)

| Lieu | v2 | v3 | Appels / primitives |
|---|---|---|---|
| témoin (4 passes alternées) | 10,70 / 10,82 / 10,20 / 9,54 (moy. 10,32) | 9,18 / 10,84 / 9,22 / 10,79 (moy. 10,01) | 503-507 → 507-511 ; 520 k → 531-534 k (+2,6 %) |
| champs (86, 50), 4 passes | 14,11 / 14,56 / 12,39 / 11,45 | 13,21 / 13,32 / 12,51 / 11,82 | 1 138 → 1 136 ; 1,210 M → 1,218 M |
| grotte | 3,49 | 3,53 | 377 → 381 |
| crypte | 3,04 | 3,08 | — |
| ferme A (intérieur), 4 passes | 7,58 / 8,62 / 7,07 / 8,14 | 7,86 / 6,56 / 7,94 / 8,03 | ~438 → 442 ; 527 k → 540 k |

CPU médian témoin 1,80 → 1,70 ms (stable). Écart dans le bruit partout, sous le budget +0,5 ms. Chargement des abords ≈ 0,4 s, étalé sur
une image par composition. Planches avant/après : `Desktop/Skyrim captures/a_voir_2026-11-11/props/v3_*.png` (gauche avant, droite après).

## Props v5 : intérieurs (branche `props/interieurs_v5`, 2026-11-19)

Demande : « remplace-en un maximum voire tous, NOTAMMENT LES TABLES ». Périmètre : halle, Sigrun, chasseurs, Grima, forge et TOUS les
bâtiments ouverts générés (`BatimentsOuverts` : maisons h1-h5, auberge h2, fermes, grenier, moulins, tour, grange, étable). Interrupteur
A/B : `-- --sans-props-v5` (`Interieurs.v5()`) rend exactement l'état d'avant ; `--sans-remplacement` / `--props-quat-ancien` coupent
aussi la v5. Même méthode : fondu dans les lots de la pièce (aucun nœud par prop), helpers d'`interieurs.gd` à signature et collisions
inchangées. Nouveaux helpers : `perche` (poutre ronde de a à b), `toile_debout` / `toile_plate` (toile de bannière teinte), `qa` (prop
ajusté sans recalage au sol), `couche` (prop debout couché sur le flanc), `appuye` (outil penché), `modele_table` / `tables_v5`.

### Tables (vérifié par grep : plus AUCUNE table maison n'est posée avec les props texturés)

Toutes les tables passent par `Interieurs.table()` (halle x4, Sigrun, chasseurs, Grima, établi de la forge, `_table` des maisons /
fermes / auberge / tour, comptoir de l'auberge). Le module maison (plateau + tréteaux L6) ne sort plus qu'avec `--sans-remplacement`.
v5 : une table de plus de 3 m = plusieurs `pq_grande_table` bout à bout (halle : 4,2-4,8 m -> 2 tables de 2,1-2,4 m ; avant, une seule
Table_Large étirée x1,6 avec des pieds déformés) ; plan haut (> 0,83 m) = `pq_etabli`. `tables_v5` est la liste des modèles tirés au
sort par position : y ajouter les tables d'Ultimate Home Interior quand props/sources_v5 les aura dans le catalogue (voir plus bas).

### Remplacés en v5

| Objet maison | Remplaçant | Où |
|---|---|---|
| lit procédural du sommeil (`Lit`, cadre + paillasse + fourrure) | `pq_lit` / `pq_lit_2` texturé ajusté au cadre (largeur, longueur, dessus du matelas à `H_PAILLASSE` : poses couchée / assise inchangées), v2 : literie (drap et oreiller de l'atlas tissu, blancs et gris-bleu, effet « chambre d'hôtel ») passée à la laine écrue sale de l'intérieur (matière `jute`, mêmes UV, pas de nouvel atlas) et GRANDE fourrure de la peau demandée étalée du pied aux deux tiers du lit (kitbash toile), collisions identiques (chevet à la hauteur du modèle) | tous les lits à marqueur : Sigrun, chasseurs x2, Grima, maisons, fermes, auberge, moulin, tour |
| crâne (module L6) | `q_crane` (Skull) tourné face à la pièce | halle, Sigrun (x7) |
| os rongés au sol | `q_os_tas_2` réduit | halle (x7), chasseurs |
| peau tendue murale (boîte + cadre) | toile teinte + 4 perches | halle, Sigrun x2, chasseurs x3, Grima, maisons, coins de chasseurs |
| cadre à peaux (chasseurs, coins de métier) | 2 montants + 2 traverses (perches) + toile teinte | chasseurs x2, maisons de chasseurs |
| planche aux arcs | `pq_porte_manteau` | chasseurs |
| peau en raclage, couteau, pierre à aiguiser (table de dépeçage) | toile couchée, `q_couteau_camp` couché, `q_roc_2` | chasseurs |
| barres du séchoir à viande | perches | chasseurs |
| planchette du chevet | `pq_etagere_simple` | Sigrun |
| nappe de parchemin, mortier, pilon | toile couchée, `q_marmite` en pierre, perche | Sigrun |
| perche d'herbes | perche | Sigrun |
| peau du siège, quenouille | toile couchée, perche + `q_sac` (laine) | Grima |
| métier à tisser : montants, ensouples, pesons, panier | perches, `q_roc_1`, `pq_cageot_vide` | Grima |
| rouleau à pâtisserie | perche | Grima |
| tresses d'oignons (cylindres) | ficelle (perche) + `q_navet` pendus (fanes en haut) | Grima (9 tresses) |
| tisonnier, pelle de la hotte | perche de fer, `q_pelle` (Shovel) | forge |
| pelle à charbon (était une pioche) | `q_pelle` | forge |
| lame brute + garde (établi) | `pq_epee_mur` couchée | forge |
| pot de clous | `pq_seau_fer` réduit | forge |

Ajouts (garnir) : 2 `pq_chandelier_pied` à 4 bougies allumées (flammes, sans lumière en plus) de part et d'autre du haut-siège (halle) ;
une table de chevet `pq_chevet_etagere` + bougie + livre près de chaque lit des maisons et fermes générées (place prise par le
répartiteur `Murs`, passages et couloir d'entrée dégagés).

### Gardés (et pourquoi)

| Objet | Raison |
|---|---|
| appliques, lanterne de la halle, lanternes pendues et brasero (bâtiments ouverts) | luminaires validés (flamme, halo, lumière) |
| râtelier de l'Épée de Skarnholt (forge) | objet unique de quête (L9) |
| plate-forme de transe, pierres de rune, bâton de seiðr, mobile de runes (Sigrun) | objets uniques de la völva, runes émissives |
| tentures (halle, maisons, tour) | textures de la bible (motifs nordiques rouge / bleu / vert) ; la toile pq_* est gris-bleu sans motif |
| ramures de cerf | aucune ramure / bois de cerf dans les packs, kitbash non crédible |
| arcs, carquois, raquettes, bottes à sécher (chasseurs) | aucun arc, carquois, raquette ni botte dans les packs (règle : les arcs sont maison) |
| fers à cheval, étau, limes, clous, lingots, barres pendues, débris (forge) | pièces minuscules sans équivalent |
| nappes de lin et planches à pain (lot 4) | surfaces de tissu UV ; un q_* sans UV n'y montrerait qu'un texel (essai rejeté : nappe disparue sous l'éclairage) |
| paille, foin en tas / bottes (grange, étable), fromage, pâte | matières en vrac sans équivalent |
| alcôve du lit clos (cloison, ciel de lit, coffre-banquette), estrade, trône (déjà kitbash), meules et rouet des moulins, stalles, mangeoires, échelle | bâti / machines (hors périmètre) |
| foyers, crémaillères, poteaux, planchers, plafonds | architecture |

### Mesures v5

`outils/audit_mesure_lieu.gd`, nuit 21 h, 12 s, 2 passes alternées `--sans-props-v5` / v5, AVANT l'intégration du catalogue
props/sources_v5. Machine très chargée par d'autres agents (dt_med 33-60 ms) : seuls les écarts GPU par paire et les compteurs comptent.

| Lieu | gpu_med avant (P1 / P2) | gpu_med v5 (P1 / P2) | appels | primitives |
|---|---|---|---|---|
| halle | 10,90 / 10,82 | 10,64 / 10,92 | 543 -> 543 | 725 k -> 739 k (+1,8 %) |
| maison h1 (`--lieu=ferme --bat=h1`) | 13,65 / 13,26 | 11,99 / 13,31 | 950-956 -> 946-949 | 1,338 M -> 1,350 M (+0,9 %) |

Lecture : aucun écart GPU au-delà du bruit (halle -0,08 ms en moyenne, h1 dans le bruit), aucun appel de dessin en plus (tout est
fondu ; le lit pq_* = 3 surfaces + 2 faces de fourrure, autant de MeshInstance3D que le lit procédural). Non remesuré après le
catalogue v5 (tables ovale / ferrées : 592-916 tris contre 986, même ordre).

### Catalogue props/sources_v5 intégré (cherry-pick de fa026490, a8c19c55, 799ff092)

- Tables : `tables_v5` = `pq_grande_table` (q_grande_table), `pq_table_ovale` (tréteaux), `pq_table_grande_2` (planches ferrées) ;
  tables de 1,5 m ou moins : `pq_table_petite_2`, `pq_table_ronde`. Tirage stable par position ; modèles longs selon Z tournés d'un quart.
- Crâne `pq_crane`, os `pq_os_tas_2`, pelles `pq_pelle`, couteau de dépeçage `pq_couteau_camp` (texturés).
- Écartés (consigne « médiéval nordique ») : bouteilles verte / vin, commode, chevets à tiroir, coffre à tiroirs, tapis rouges,
  chaises (non posées : bancs et tabourets déjà là, passages étroits).
Planches avant | après (gauche avant, droite après) : `C:\Users\lopezk19\Jeux\rendus\props_v5\interieurs_*.png`.

## Props v5 : souterrains (crypte, tertre, grotte) (props/crypte_v5, 2026-11-19)

Demande : « remplace un maximum de props maison par des Quaternius, notamment les tables ». Interrupteur A/B : `-- --sans-props-v5`
(`PropsQuaternius.v5`) rend EXACTEMENT la v3 (captures « avant », mesures). Code : `CrypteDecor.SUBST_V5` (prioritaire sur `SUBST` et
`SUBST_GARDE_PQ`, 4e champ = facteur de hauteur, quart de tour 1 = +90°, 3 = −90°), `CrypteDecor._toile_v5`, `CrypteDecor.gravats` (briques),
`ObjPetitMobilier.coffre_force`, `CrypteDonjon._compos_v5` / `_compo_mur`, `GrotteModules.G5_*`. Poses : `outils/poses_props_v5_souterrain.txt`.

### Remplacés

| Module maison | Remplaçant | Endroit | Notes |
|---|---|---|---|
| coffre_a/b/c (coffre de décor d'une pièce) | pq_coffre_ferme (MegaKit, x 1,32 / 1,44 / 1,48) | niche d'Eirik (tertre) | seul coffre de décor d'une pièce |
| bouclier_a/b/c (boucliers muraux peints) | pq_bouclier_bois (rond, cerclé, umbo) | crypte (salle de garde, quartiers…) | la teinte peinte est perdue (le bouclier du pack se lit mieux à 480x270) |
| toile() (triangle peint) | q_toile_araignee_1/2 (Cobweb, fils en volume), coin d'accroche au coin du mur | crypte, tertre, grotte (7 toiles rares) | variante tirée de la position, aucun tirage de rng |
| coffre_force (boîtes) | pq_coffre (ouvert), x 1,3 | style « force » de DonjonKit.coffre | aucun coffre forcé dans la table actuelle de la crypte : prêt, non visible |
| gravats (crypte, lot 4 : rochers) | + 2 à 4 pq_brique_1..4 (q_brique si absent) au bord du tas (kitbash « maçonnerie effondrée ») | crypte | générateur à part (position) : le décor ne bouge pas |

### Ajouts (compositions de donjon, mêmes règles de refus que la v2/v3, ancre cherchée le long des murs)

| Lieu | Composition | Contenu |
|---|---|---|
| ossuaire | ossements + dépôt funéraire | q_os_tas, q_os_tas_2, urne brisée, vase cassable ; pq_coffre_ferme x 1,3, vases, bougie éteinte |
| tombeau, reliquaires, lb2a | dépôt funéraire | idem |
| arène | ossements (mur sud) | idem |
| trésor | coffre doré | pq_coffre_or, tas de pièces, bourse |
| grotte, mine (combat, récit) | mineur tombé | os, pioche, seau de fer |
| grotte, camp des bandits | butin | q_coffre_d, pièces, bourse, vase |

Coffres AJOUTÉS = décor sans butin (les coffres à butin restent ceux des tables de salles) ; urnes ajoutées = CrypteDecor.urne (cassables,
même logique que toutes les urnes). Rejetés sur planches : colonne brisée C5_RUINE (arène, lb3 : blocs gris illisibles, et elle chassait la
statue, le candélabre et les gravats du semis posés après) ; ossements de lb2 (chassaient une statue et un candélabre).

### Gardés (et pourquoi)

- Tables table_a/b/c (crypte, grotte) : la table rustique à pieds droits d'avant la v5 est gardée (plus médiévale) ; essayées et rejetées
  sur planches : pq_table_petite_2, pq_table_grande_2 (tréteaux en T trop fins à 1,10 x 0,65 m), pq_table_ovale (« table de salon sur pied »).
- Coffres qui s'OUVRENT (L1 : cuve + couvercle animé + or, coffre royal) : le couvercle pivote sur sa charnière (CoffreCouvercle, audit
  des couvercles levés) ; aucun pq_* n'a de couvercle séparé.
- Luminaires L8 (lustres, candélabres, braseros, appliques, cages, chaînes) : validés, flammes et lumières.
- Sarcophages, statues, socles, autels, trône, table d'embaumement, bassin, ossuaire v2 (crânes anatomiques, niches, monticules d'os) :
  pierre / anatomie validées ; pas d'équivalent Quaternius de la bonne forme (q_os_tas sert en compositions, pas comme monticule).
- Râteliers (ratelier_cadre_a/b de la crypte, g_ratelier de la grotte) : le seul remplaçant (pq_rack_armes, 1,3 m de fond) est un râtelier
  SUR PIED ; il est posé à part dans les compositions (v2), le râtelier mural garde ses armes arme_v_*.
- Barricade (planches, poteaux, table renversée) : pièces étirées à la largeur du passage, collision avec brèche ; modele() ne bascule pas
  une table sur le flanc (lacet seul).
- Armes au sol (arme_*), présentoirs (pièce unique de quête), étagère renversée, sacs éventrés (déjà q_sac_pieces), crâne (oss_crane
  anatomique), micro-objets du semis (éclats, planchettes, cire, chaînes, pièces : sans collision, échelle de 10-30 cm), tas de pièces de la
  grotte (g_pieces : agrandi à 45-55 cm, q_tas_pieces fait des pièces de 12 cm), caisses/tonneaux/urnes cassables (déjà Quaternius).
- Tumulus extérieur : pierres levées, stèle, dalles (consigne : nature/bâti).

### Catalogue props/sources_v5 (autre agent) : intégré

Cherry-pick de fa026490, a8c19c55, 799ff092 (props_quat.dat régénéré, 254 props) : les alias `PropsQuaternius.ALIAS_PQ` de la v5
(q_table_petite_2, q_toile_araignee_1/2, q_os_tas(_2), q_coffre_d -> pq_*) sont ACTIFS : toiles, os et coffre du butin sont
texturés (même modèle, même échelle). Posés en direct dans la crypte : pq_brique_1..4 (gravats ; pas d'alias car q_brique sert aussi au
village), pq_coffre_or (trésor), pq_bougie_d (dépôt). Captures après catalogue : `rendus/props_v5/brut/apres_cat`.

Consigne « univers médiéval nordique sombre » appliquée au catalogue : AUCUN de ces props n'est posé dans les souterrains : bouteilles
(pq_bouteille_verte/vin), meubles à tiroirs (pq_commode, pq_chevet_*, pq_coffre_tiroirs), fioles vives, tapis rouge (pq_tapis_crypte).
Pistes restantes (non faites, à juger en vue de jeu) : pq_crane (crane_a/b), pq_candelabre_d, pq_roc_*, pq_piege_pieux, pq_grille_fer.

### Perf (A/B `--sans-props-v5`, audit_mesure_lieu, nuit 21 h, 12 s, sur secteur)

2 passes alternées par lieu (sans v5 / v5), catalogue intégré. Logs : /tmp/pv5/perf (non conservés).

| Lieu | Mode | GPU méd (ms) | appels | primitives | dt méd (ms) | > 16,7 ms |
|---|---|---|---|---|---|---|
| crypte | sans v5 | 3,17 / 3,14 | 273 | 101 403 | 14,2 / 12,5 | 10,3 % / 0,6 % |
| crypte | v5 | 3,26 / 2,54 | 273 | 110 406 (+8,9 %) | 13,0 / 10,0 | 7,9 % / 0,9 % |
| grotte | sans v5 | 3,68 / 3,75 | 392 | 133 752 | 8,4 / 13,9 | 0,1 % / 13,9 % |
| grotte | v5 | 3,72 / 3,53 | 391 | 133 348 – 134 587 | 10,9 / 17,7 | 1,6 % / 76,1 % |

Lecture : appels de dessin identiques (fusion par case de CrypteDecor), +9 000 triangles dans la crypte, GPU dans le bruit (± 0,1 ms hors
passe atypique). Le temps réel par image (dt) varie AUTANT entre deux passes du même mode (grotte sans v5 : 0,1 % puis 13,9 % d'images
lentes) : machine partagée avec d'autres Godot, pas un effet des props. Mémoire vidéo ± 50 Mo selon la passe, même ordre.

## Props v5 : réalisme (intérieurs et souterrains) (branche `props/realisme_v5`, 2026-11-19)

Retour utilisateur sur les props Quaternius v5 : « certains font plus jouet qu'autre chose ; il faut que ça colle au décor, rajoute des
détails, que ce soit réaliste », « applique-le à la totalité ». Périmètre : intérieurs (halle, maisons nommées, bâtiments ouverts générés,
forge) et souterrains (crypte, tertre, grotte). L'EXTÉRIEUR n'est pas touché (contexte de matériau « exterieur » inchangé ; la neige des
pq_* dehors est traitée sur `props/exterieurs_v5`). Code : `scripts/props_realisme.gd` (`PropsRealisme`). Interrupteur A/B :
`-- --sans-realisme-v5` rend exactement la v5 d'avant ce lot ; `--sans-props-v5` rend toujours l'état d'avant la v5.

### 1. Anti-« jouet » : patine des matériaux partagés (aucun nouvel atlas, aucun appel de dessin en plus)

Les pq_* sont fondus dans les lots par atlas (`PropsQuat.materiau(atlas, contexte)`) : le réglage d'UN matériau par (atlas, contexte)
patine tous les props du lieu. Uniformes AJOUTÉS, neutres par défaut (le reste du décor ne change pas) :
- `shaders/ps1_interieur.gdshader` : `usure` (taches de crasse en volume, cases de 1/16 m : gros pixels PS1, assombrit et désature par
  plaques), `ao_gamma` (creuse l'occlusion cuite de la couleur de sommet : pieds, jonctions, dessous ; arêtes adoucies) ;
- `shaders/crypte.gdshader` : idem + `poussiere` (voile gris sur les faces tournées vers le haut) et `moisi` (plaques sombres verdâtres).

| Contexte | Réglage (`PropsRealisme.INTERIEUR` / `CRYPTE` / `GROTTE` / `SOUS_TERRE_ATLAS`) |
|---|---|
| intérieurs | bois teinte 0,80 / 0,72 / 0,66, saturation 0,74, usure 0,45, ao 1,2 (le pq_bois sortait plus clair et plus orangé que les planches et rondins de la pièce) ; fer 0,70 terni (sat. 0,5) ; pierre / os / cire 0,80 / 0,75 / 0,68 (les crânes n'ont plus le blanc « plastique ») ; tissus et pages légèrement salis |
| crypte | usure 0,6, poussière 0,55, moisi 0,18, ao 1,5 ; bois brun chaud (0,86 / 0,70 / 0,56, sat. 0,9) et fer sombre : la teinte grise de props/maximum + la patine faisait virer le bois au violet sous l'ambiante froide (« caisse bleue ») |
| grotte | usure 0,6, poussière 0,3, moisi 0,35 (humidité), ao 1,5 ; même bois / fer que la crypte |
| toiles d'araignée (pq_tissu_v sous terre) | usure et poussière x 0,5 |

La bande de crasse de pied (`crasse`) reste à 0 sur les pq_* : elle se cale sur le sol du niveau principal (y0) et noircirait les props
des étages inférieurs du donjon ; le contact au sol vient de l'occlusion cuite creusée (`ao_gamma`).

### 2. Retours à l'ancien (jugés sur planches, vue de jeu de nuit)

| Objet | Où | Pourquoi |
|---|---|---|
| lit : pq_lit / pq_lit_2 ajusté au cadre -> lit procédural d'avant la v5 (`Lit`, montants, chevet haut, paillasse, fourrure drapée) | tous les lits à marqueur (Sigrun, chasseurs, Grima, maisons, fermes, auberge, moulin, tour) | le Bed_Twin étiré au cadre restait une caisse lisse à bord bleuté, « jouet » à côté des PNJ, même patiné ; le lit procédural a des montants, un chevet et une fourrure lisibles. Collisions, poses couchée / assise inchangées (code d'avant) |
| coffre de décor coffre_a/b/c -> ancien coffre maison | niche d'Eirik (tertre) | le pq_coffre_ferme sortait en boîte lisse violacée sous la lumière de la crypte ; l'ancien a des planches brunes, des ferrures et un couvercle bombé |

Gardés en Quaternius (patinés) : tables de festin et de maison, étagères, chevets, crânes, os, boucliers ronds, coffres des dépôts
funéraires (dans une composition, seuls des q_*/pq_* sont posables), outils, toiles d'araignée. Les tables de la crypte étaient déjà
revenues au modèle d'avant (`props/crypte_v5`).

### 3. Détails ajoutés (avec mesure, rien de solide sur les passages, aucun tirage de `rng`)

- Foyers (bâtiments ouverts : cheminée et foyer ouvert ; maisons nommées ; long foyer de la halle) : `PropsRealisme.cendres` (6 flocons
  de cendre, 4 escarbilles de charbon, un tison noirci roulé hors du feu, au ras du sol). Rejeté sur planche : une « suie » en plaques
  sur la pierre au-dessus du linteau (texture de charbon trop claire et trop plate : un panneau collé sur la cheminée de Grima).
- Tables des maisons / fermes / auberge (`BatimentsOuverts._table`) : `table_entamee` (miettes et quignon, chope renversée au bout du
  plateau avec sa flaque, os rongé) et `peau_jetee` (fourrure en travers d'un banc).
- Bancs et coffres d'intérieur : biais de pose de ±2,5 à 3,5° (`PropsRealisme.biais`, bruit de position), plus rien de parfaitement
  d'équerre.
- Crypte : dépôt funéraire `C5_DEPOT_R` (ossuaire, tombeau, reliquaires, lb2a) : coffre de biais et décalé, vase renversé brisé, petit
  vase roulé, os glissés au pied (la v5 était symétrique vase / coffre droit / vase, effet vitrine) ; même emprise que le dépôt v5.

Planches (gauche : avant v5 `--sans-props-v5`, milieu : v5 actuelle `--sans-realisme-v5`, droite : v5 retravaillée), nuit 21 h :
`C:\Users\lopezk19\Jeux\rendus\props_v5\realisme_interieurs_*.png` et `realisme_souterrains_*.png` ; captures brutes
`rendus/props_v5/realisme/{avant,actuel,final}` ; poses `outils/poses_props_realisme.txt` (34 poses : 19 intérieures, 15 souterraines).
Vérification ciblée (dépôts funéraires, tables et foyers vus de haut) : `realisme_souterrains_3_depots_et_tables.png`, captures
`rendus/props_v5/realisme/verif_{avant,actuel,final}`, poses `outils/poses_props_realisme_verif.txt`.

Tests (worktree `props/realisme_v5`) : test_crypte TOUT OK, test_cassables ECHECS : 0, test_sommeil RESULTAT : OK, test_interieurs
TOUT OK, test_grotte OK. Godot rend le code 5 en fin de test_crypte / cassables / sommeil / interieurs : préexistant (même code
sur la base 16cf1e98 sans ce lot), à juger sur la sortie et non sur le code.

Limites : bruit d'usure en volume monde (un prop déplacé change de taches) ; la lame posée sur l'établi de la forge reste un peu claire ;
les flocons de cendre se lisent en petits carrés (peu visibles en jeu) ; pas de mesure d'IPS (quelques instructions de shader, aucun
appel de dessin en plus).

## Props v5 : extérieurs (branche `props/exterieurs_v5`, 2026-11-19)

Interrupteur A/B : `-- --sans-props-v5` (`PropsQuaternius.v5`, vrai seulement si `v3` et `remplace`) rend exactement l'état v3 ;
`--sans-remplacement` coupe toujours tout. Catalogue v5 (`props_quat.dat` à 254 props, 159 nouveaux pq_*, `docs/PROPS_SOURCES_V5.md`)
intégré par cherry-pick (24071bd7, 249d5d43, 21ab8e0b). Méthode inchangée : fondu dans les lots existants (aucun nœud par objet),
mêmes collisions, mêmes emprises, décor tiré au hasard inchangé. Univers médiéval nordique sombre : bouteilles vertes/de vin, commodes,
chevets et coffres à tiroirs, fioles vives, auvents rayés et tapis rouge NON posés (consigne utilisateur) ; aucun auvent recoloré.

### Remplacement central (`PropsQuaternius.ext_v5`, table `EXT_V5`)

Tout `q_*` (couleur de face) qui a un jumeau texturé passe par `ext_v5` dans `village()`, `MobilierVillage._poser_sub`/`poser_dans`/
`noeud_modules` et `AbordsProps._poser` : barrières (bois, ext 1/2), bordures, briques 1-4, bûcher, caisse, chariot, feu de bois,
hache de camp, hachette, marmite, piège à ours, planches de sol, rondin, support, tente, pelle, crâne, pain, pomme, viande, poisson
(+ portes et volets, préparés mais aucun appel dehors). Si l'appel impose des matières (`mats`), on garde le q_* (sauf tente, hache,
piège, dont la teinte imposée est celle du modèle). `buche_v5` : la bûche kitbash `q_buche` devient le rondin Quaternius ajusté à la
même boîte (`ajuste` : échelle par axe, pied et centre alignés).

| Type | Remplacés (1 monde) |
|---|---|
| bûches (tas de bois, bûchers, foyers) | 177 |
| barrières de bois | 24 |
| rondins | 21 |
| briques (foyers, murets) | 35 (7 + 13 + 9 + 6) |
| planches de sol | 6 |
| haches de camp | 5 |
| nourriture des abords (pain, pomme, viande, poisson) | 10 |
| marmites, tentes, chariots, pièges, crânes, bordures | 2 chacun |
| bûcher, feu de bois des bandits | 1 + 1 |
| tables d'étal (Brodd, Grima) : tréteaux maison 9 boîtes -> `pq_grande_table` | 2 |
| meules de foin -> 3 `pq_gerbe` chacune | 3 meules (9 gerbes) |
| couronne du feu de camp (briques + feu) -> `pq_foyer_pierres` | 1 (REVENU à l'ancien, voir « v5 retravaillé ») |
| cloche du beffroi (2 cylindres) -> `pq_cloche` | 1 |

### Compositions ajoutées (`AbordsProps.LIEUX_V5`, mêmes règles que la v3 + refus « ville »)

Refus supplémentaires dans le village (`_refus_ville`) : point non libre (`Village.point_libre`), pavé (`RuesVillage.profondeur_pave`
> 1 m), piste de la grotte, moins de r + 3 m d'une porte d'intérieur, moins de r + 1,4 m d'un poste de garde (`data/gardes.json`).
Pas de spirale de repli : ancres seulement, glissées de ±1 / ±2 m.

| Lieu (posé) | Composition |
|---|---|
| place (40, 47,5) | tablée : grande table, 2 bancs, chopes, assiettes, pain, bouteille, marmite, tonneau |
| portes SO (32,9, 26,1), N (59,5, 12), E (69, 29,5) | postes de garde : table rustique de planches (`pq_table_petite_2`, échelle 1 ; la table ronde sur pied faisait « salon »), 2 tabourets, seau, chopes, pièces, râtelier garni (épée, hache), bouclier, tonneau |
| ruelle du marché (56,5, 39) | table du marché : chaudron, marmites, vases, seau, caisse, ballot |
| devant la forge (28,5, 40,3) | établi : hache, petite enclume, chaîne, seau de trempe, caisse ferrée |
| fermes A (81,5, 19,8) et B (60, −0,8) | établi : pioche, corde, seau, sacs, billot + hache plantée ; chevalet de sciage en B (A : variante sans chevalet, faute de place) |
| devant la grotte (83,5, −33) | jeu des bandits : tonneau-table, 2 tabourets, chopes, mise, bouteille couchée |

Retiré : poste de la tour (aucune place libre hors pavé et portes).

### Gardés (avec la raison)

- Luminaires validés : braseros, lanternes, torches, enseignes (bâti).
- Interactifs dont la logique dépend de la géométrie : vantaux, puits (Tripo par défaut, validé).
- Torche éteinte des bandits : `pq_torche_bois` fait 0,6 m, pas de torche sur pied à l'échelle.
- Arme au sol, trophées `g_trophee` : règle armes = modèles maison, trophées validés.
- Nature maison (os et bois de cerf du cercle, rochers, souches, arbres) : interdit.
- `q_poutre_ronde` (hampes, poteaux indicateurs, séchoir, chevaux de frise) : aucune poutre ronde Quaternius.
- Kitbash reteints (séchoir de peaux), barrières d'`AbordsQ` (UV d'écorce, autre chaîne), nourriture des étals (objets vivants).

### Mesures v5 (`outils/mesure_perf.gd`, fenêtre hors écran, 2 passes alternées v3 = `--sans-props-v5` / v5)

| Lieu (pose) | v3 : médiane GPU (ms), passes 1 / 2 | v5 : médiane GPU (ms), passes 1 / 2 | Appels | Primitives |
|---|---|---|---|---|
| place (44, 31, 180°, −8°) | 16,89 / 16,77 | 13,82* / 17,03 | 1 231-1 236 → 1 227 | 1,816 M → 1,846 M (+1,7 %) |
| marché (46, 36, −56°, −9°) | 14,14 / 14,59 | 16,57 / 12,83 | 863-871 → 883 | 1,385 M → 1,461 M (+5,5 %) |

\* passe 1 v5 de la place : 570 appels seulement (chargement pas fini au moment de la mesure), écartée. CPU médian : place
6,18 / 8,51 → 6,62 ms, marché 3,95 / 4,77 → 4,79 / 3,50 ms. Écart GPU dans le bruit (GPU partagé, autres agents actifs) ; seuls
appels et primitives sont fiables : +12 à +20 appels au marché (compositions), +1,7 à +5,5 % de primitives. Pas de répétition
justifiant LOD/MultiMesh : chaque composition est déjà un seul maillage, les bûches restent fondues dans les lots du mobilier.

Planches avant/après (gauche avant, droite après) : `C:\Users\lopezk19\Jeux\rendus\props_v5\exterieurs_1_tables_postes.png`,
`exterieurs_2_marche_forge_etals.png`, `exterieurs_3_bois_enclos_feu.png`, `exterieurs_4_abords_bandits.png`, `exterieurs_5_cloche_foyers.png`,
`exterieurs_6_ferme_a_poste_e_tas_marche.png`.

Limites : la couronne de pierres du `pq_foyer_pierres` se lit peu sous les bûches ; le foyer des bandits disparaît sous la congère ;
neige sur le dessus des sacs et tissus (défaut connu du catalogue) ; MobilierVillage 83 532 -> 92 092 triangles.

### v5 retravaillé : neige, patine, contact au sol (retour « effet jouet », 2026-11-19)

Tous les morceaux pq_* posés dehors (lots `PropsQuaternius.lot_pq` en contexte « exterieur », `village()`, `MobilierVillage` via
`PropsQuaternius.brut_v5`) passent par `patine_v5` (copie non indexée, couleur de sommet seulement, aucun nouvel atlas) :

- **neige** : faces dont la normale monde y > 0,72 (et une partie des y > 0,4), tirées par hachage pour casser l'uniformité, en
  alpha 0, donc neige peinte du shader ps1, avec une occlusion douce ; la « neige qui tient » procédurale s'ajoute par-dessus ;
- **patine** (`PATINE_V5`) : bois assombri gris de gel, fer terni bleuté, tissus et objets grisés ; pied (15 cm) assombri (humidité) ;
- **petits objets** (< 35 cm : chopes, assiettes, pièces) : pas de calotte, givre bleuté sur les faces vers le haut ;
- **pas de neige** (`SANS_NEIGE_V5`) : cloche, luminaires muraux, bannières, volets, armes et outils accrochés, foyers et feux ;
  Brodd (étal sous l'auvent de la forge) sans neige ni congère ;
- **contact au sol** (`congere_v5`) : congère elliptique (12 segments, 3 anneaux) collée au terrain (`monde.hauteur`) au pied des
  objets posés au sol (marqués `true` ou Callable de hauteur dans les compositions), centre ombré (les lots n'ont pas d'ombre portée),
  bord fondu sous la neige du sol ; rien ne flotte.

Bug corrigé : les matériaux pq « exterieur » étaient créés avant que `monde.gd` ne pose `Palette.tex_neige` (la neige peinte prenait la
couleur du bois) ; `PropsQuat.neige_exterieur()` repose la texture de neige sur tous les matériaux « :exterieur » (v5 seulement).

Revenus à l'ancien (le maison était plus réaliste) :

- couronne du feu de camp : `pq_foyer_pierres` -> couronne de 9 briques + feu (la couronne Quaternius se lisait mal, effet jouet) ;
- foyer des bandits devant la grotte : bûches Bonfire noircies -> 3 prismes calcinés maison (les Bonfire disparaissaient sous la neige).

Pas posé : cape ou peau sur un tabouret (aucun pq adapté au thème), glaçons sur les props (non tentés : les toits en portent déjà, risque de surcharge).

`outils/test_props_village.gd` échoue à l'identique sur la base ed5b92a7 (sans catalogue v5) : 6 `Mobilier_pq_tissu_v` à 0,87 m
(x 50-54, z 31-44) et 1 maillage à 0,09 m, défaut antérieur, hors v5.

Planches v2 (gauche v3, droite v5 retravaillé) : `C:\Users\lopezk19\Jeux\rendus\props_v5\exterieurs_1_postes_tablee_v2.png`,
`exterieurs_2_marche_forge_etals_v2.png`, `exterieurs_3_fermes_bois_bandits_v2.png`, `exterieurs_4_enclos_champs_feu_v2.png`,
`exterieurs_5_nuit_v2.png` ; poste E table ronde -> table rustique : `exterieurs_7_postes_v2.png`.
