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
