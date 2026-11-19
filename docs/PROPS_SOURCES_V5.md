# Props texturés PS1 « v5 » : nouvelles sources Quaternius (CC0)

Branche `props/sources_v5` (depuis ed5b92a7), 2026-11-19. Demande : « j'aime les props Quaternius, rajoutes-en plus et remplace un maximum
voire tous les props maison, notamment les tables ». Ce lot ÉLARGIT le catalogue `data/props_quaternius.json` (entrées `"lot": "v5"`) ;
il ne pose rien dans le jeu : les agents de remplacement (dehors / intérieurs / crypte+grotte) choisissent dans cette liste.

## Comment c'est fait (même rendu que les 95 pq_* du Fantasy Props MegaKit)

- Chaîne : `sources_blender/scripts/gen_props_sources_v5.py` (liste, échelles, matières) -> `props_sources_v5.py` (Blender, headless) ->
  `assets/modeles/props_quat/<catégorie>/<id>.glb` + `data/props_sources_v5_brut.json` -> `outils/props_sources_v5_catalogue.py`
  (fusion idempotente dans le catalogue). Relancer : `python3 -I gen_props_sources_v5.py`, `blender -b --python props_sources_v5.py
  [-- seulement=pq_a,pq_b]`, `python3 -I outils/props_sources_v5_catalogue.py`, `godot --headless --import`, puis
  `outils/export_props_quat_dat.gd` pour le .dat.
- Ces packs n'ont pas les « trims » du MegaKit (couleurs unies, ou trims propres au Medieval Village). Pour rester HOMOGÈNE et sans
  nouvel atlas (`PropsQuaternius.ATLAS_PQ` inchangé : toujours 8 matériaux au plus par lot), chaque matériau source est rangé dans une
  matière et ses faces sont RE-PROJETÉES (îlots par axe dominant, ~80 texels/m comme les pq_* existants) sur les atlas partagés :
  bois -> bande des planches de `pq_bois` (fil le long du grand côté) ; fer -> `pq_fer` ; pierre, os, cire, terre cuite, nourriture,
  verre -> `pq_fer_v` (luminance bruitée) x couleur de sommet accrochée sur la rampe de la bible ; tissus (tapis, coussin, tente, sacs,
  toiles d'araignée) -> zone des plis de `pq_tissu_v` x rampe. Flammes des sources (torches, bûchers) retirées : le jeu pose les siennes.
- Couleur de sommet = teinte x occlusion cuite x pied sombre, alpha 1 (pas de neige), comme `props_quaternius.py` (fonctions reprises
  par import ; son `main()` est maintenant derrière `if __name__ == "__main__"`, comportement inchangé).
- Décimation adaptative de `props_quaternius.reduire` (seulement au-dessus du budget, refusée si elle ouvre des trous) ; budget
  1 500 + 3 000 x plus grande dimension, plafonné à 10 000 tris. Une seule pièce réduite : `pq_coffre_or_2` (22 512 -> 6 603 tris, tas
  de pièces très dense ; silhouette gardée). Toutes les autres sont à leur compte source.
- `equivalent_q` = q_* des lots 2-4 issu du MÊME modèle, à la MÊME échelle (« ech » / « hauteur » repris de
  `sources_blender/quaternius/props.json`) : même emprise. Le champ `ancien` n'est PAS posé, donc PropsQuaternius ne remplace rien
  tout seul. Pour activer le remplacement automatique d'un q_* partout où le code le pose : copier `equivalent_q` dans `ancien`
  (ou l'ajouter à `PropsQuaternius.ALIAS_PQ`), puis relancer `outils/export_props_quat_dat.gd`. Attention aux kitbash reteints
  (`KITBASH_SI_MATS`) et aux alias existants (`q_tonneau_2`, `q_caisse_2`, `q_chaise_2`, `q_coffre_2`, `q_seau_2`, `q_vase_5`,
  `q_bouteille_1/2`, `q_sac_debout` : ils ont maintenant leur VRAI modèle texturé).
- Planches (hors dépôt) : `C:\Users\lopezk19\Jeux\rendus\props_v5\planche_sources.png` (tous les props v5, shader ps1 du jeu, contexte
  extérieur) ; sources brutes du tri : `src_uhi.png`.

## Sources

| Pack | Licence | Où | État |
|---|---|---|---|
| Ultimate Home Interior (Ultimate House Interior Pack) | CC0 1.0 (License.txt du pack ; https://quaternius.com/packs/ultimatehomeinterior.html) | `references/quaternius_props/ultimate_home_interior/telecharge_2026-11-19/` | **téléchargé le 2026-11-19** (Drive public, quota levé ; l'ancien dossier `FBX/` ne contient que des pages « Quota exceeded », laissé tel quel). 123 FBX, 20 gardés |
| Medieval Village MegaKit | CC0 | `references/quaternius_props/medieval_village_megakit/` | props, portes et volets convertis en pq_* (28) ; murs/toits/planchers/escaliers = bâti, hors périmètre |
| LowPoly Modular Dungeon (itch) | CC0 | `references/quaternius_props/lowpoly_modular_dungeon_itch/` | les 25 q_* du lot 3 + 2 pièces neuves |
| Medieval Dungeon, Survival, Ultimate Food | CC0 | `references/quaternius_props/{medieval_dungeon,survival,ultimate_food}/` | les q_* du lot 4 sans pq_* + 7 pièces neuves |

## Props ajoutés (première version : revue visuelle en cours, liste susceptible de baisser)
<!-- TABLE 137 props, 88257 tris -->

### Ultimate Home Interior (20)

| id | nom | source | tris (source -> jeu) | emprise X x Y x Z (m) | matière (atlas) | usage conseillé / remplace | q_* équivalent |
|---|---|---|---|---|---|---|---|
| `pq_table_ovale` | grande table ovale à tréteaux | Table_RoundLarge | 592 -> 592 | 2.58 x 0.78 x 1.35 | bois (bois) | tables de la halle / des maisons (table à tréteaux maison, pq_grande_table), tables de la crypte (table_a/b/c gardées : 2,7 m) | — |
| `pq_table_ronde` | table ronde à pied central | Table_RoundSmall | 592 -> 592 | 1.32 x 0.78 x 1.32 | bois (bois) | table de taverne / d'auberge, table de jeu des quartiers, table de Grima ou de Sigrun | — |
| `pq_chaise_echelle` | chaise à dossier à barreaux | Chair_1 | 216 -> 216 | 0.43 x 1.00 x 0.47 | bois (bois) | chaises autour des tables (pq_chaise, banc maison), halle, maisons | — |
| `pq_chaise_coussin` | chaise à coussin de laine | Chair_2 | 352 -> 352 | 0.45 x 1.00 x 0.49 | bois sombre + laine rouge (bois, tissu_v) | chaise du jarl / de maître de maison, halle | — |
| `pq_chaise_fuseaux` | chaise à dossier à fuseaux | Chair_4 | 264 -> 264 | 0.43 x 1.00 x 0.47 | bois (bois) | chaises de maisons et d'auberge (variante de pq_chaise_echelle) | — |
| `pq_chevet_tiroir` | table de chevet à tiroir | NightStand_1 | 172 -> 172 | 0.69 x 0.60 x 0.69 | bois + bouton de fer (bois, fer) | à côté des lits (lit maison, pq_lit), chambres de Sigrun, des chasseurs | — |
| `pq_chevet_etagere_2` | petite table à tiroir et tablette | NightStand_2 | 184 -> 184 | 0.62 x 0.62 x 0.62 | bois + fer (bois, fer) | petite table d'appoint, chevet, guéridon de la halle | — |
| `pq_coffre_tiroirs` | petit meuble à deux tiroirs | NightStand_3 | 272 -> 272 | 0.69 x 0.60 x 0.69 | bois + fer (bois, fer) | rangement bas des maisons (coffre maison), forge, archives | — |
| `pq_commode` | commode basse à tiroirs | Drawer_5 | 352 -> 352 | 1.78 x 0.85 x 0.74 | bois (trois tons) (bois) | dressoir maison, commode des chambres, buffet (pq_buffet en variante) | — |
| `pq_etagere_haute` | grande étagère ouverte | Bookshelf | 120 -> 120 | 1.04 x 2.00 x 0.34 | bois (bois) | étagère 4 niveaux maison (pq_etagere_arche), archives de la crypte (etagere_cadre_a/b gardées) | — |
| `pq_etagere_etroite` | étagère étroite | Shelf_1 | 96 -> 96 | 0.40 x 1.80 x 0.37 | bois (bois) | étagère d'angle, réserve, garde-manger | — |
| `pq_tapis_rect` | tapis tissé rectangulaire | Carpet_1 | 108 -> 108 | 1.65 x 0.03 x 2.40 | laine rouge, bordure ocre (tissu_v) | tapis / peaux au sol maison (peau_sol = toile de bannière couchée), halle | — |
| `pq_tapis_carre` | grand tapis tissé | Carpet_2 | 98 -> 98 | 2.53 x 0.03 x 2.60 | laine rouge, bordure ocre (tissu_v) | sol de la halle du jarl, devant le trône | — |
| `pq_tapis_rond` | tapis tissé rond | Carpet_Round | 128 -> 128 | 1.97 x 0.01 x 2.00 | laine rouge, bordure ocre (tissu_v) | devant un foyer, chambre, q_tapis de la crypte | — |
| `pq_piedestal_rond` | piédestal de pierre rond | Column_Round1 | 332 -> 332 | 0.87 x 1.10 x 0.91 | pierre (fer_v) | présentoirs, reliquaires de la crypte (piédestaux maison), offrandes | — |
| `pq_colonne_ronde` | colonne de pierre ronde | Column_Round2 | 556 -> 556 | 1.12 x 3.20 x 1.18 | pierre (fer_v) | colonnes de la crypte (q_colonne_1/2), salle du trône g4 | — |
| `pq_pilier_carre` | pilier de pierre carré | Column_SquareBig | 180 -> 180 | 0.70 x 3.20 x 0.70 | pierre (fer_v) | piliers de la crypte, entrée du tumulus | — |
| `pq_piedestal_carre` | piédestal de pierre carré | Column_SquareSmall | 148 -> 148 | 0.48 x 1.30 x 0.48 | pierre (fer_v) | présentoir de l'Épée, socle de statue, autel | — |
| `pq_ecuelle_creuse` | écuelle creuse en bois | Plate_3 | 136 -> 136 | 0.23 x 0.02 x 0.24 | bois (bois) | vaisselle des tables (assiette / bol maison, q_ecuelle) | — |
| `pq_cuillere_bois` | cuillère de bois | Spoon | 128 -> 128 | 0.04 x 0.01 x 0.20 | bois (bois) | q_cuillere_bois (gardé : pq_cuillere est en métal), tables, marmites | — |

### Medieval Village MegaKit (28)

| id | nom | source | tris (source -> jeu) | emprise X x Y x Z (m) | matière (atlas) | usage conseillé / remplace | q_* équivalent |
|---|---|---|---|---|---|---|---|
| `pq_chariot` | chariot de ferme | Prop_Wagon | 1672 -> 1672 | 1.21 x 0.95 x 2.50 | bois (bois) | charrette abandonnée des abords, marché (q_chariot gardé) | `q_chariot` |
| `pq_caisse_village` | caisse en planches du village | Prop_Crate | 230 -> 230 | 0.82 x 0.80 x 0.82 | bois (bois) | caisses du marché et des ruelles | `q_caisse_village` |
| `pq_barriere_bois` | barrière de bois (poteau) | Prop_WoodenFence_Single | 40 -> 40 | 2.06 x 0.84 x 0.12 | bois (bois) | enclos d'Ylva, abords (q_barriere_bois gardé) | `q_barriere_bois` |
| `pq_barriere_ext_1` | barrière de bois (travée) | Prop_WoodenFence_Extension1 | 32 -> 32 | 2.04 x 0.84 x 0.11 | bois (bois) | enclos, abords | `q_barriere_ext_1` |
| `pq_barriere_ext_2` | barrière de bois (travée longue) | Prop_WoodenFence_Extension2 | 28 -> 28 | 2.03 x 0.84 x 0.11 | bois (bois) | enclos, abords | `q_barriere_ext_2` |
| `pq_support_bois` | jambe de force en bois | Prop_Support | 16 -> 16 | 0.20 x 1.71 x 2.04 | bois (bois) | auvents, séchoirs, étais | `q_support_bois` |
| `pq_grille_fer` | grille de fer simple | Prop_MetalFence_Simple | 2744 -> 2744 | 1.22 x 1.80 x 0.10 | fer (fer) | grilles de la crypte, clôture du tumulus | `q_grille_fer` |
| `pq_grille_fer_ornee` | grille de fer ouvragée | Prop_MetalFence_Ornament | 3988 -> 3988 | 1.23 x 1.80 x 0.10 | fer (fer) | grille de la halle, enclos du cimetière | `q_grille_fer_ornee` |
| `pq_brique_1` | moellon 1 | Prop_Brick1 | 108 -> 108 | 0.35 x 0.21 x 0.25 | pierre (fer_v) | kitbash puits / foyers / couronne du feu de camp | `q_brique_1` |
| `pq_brique_2` | moellon 2 | Prop_Brick2 | 94 -> 94 | 0.40 x 0.24 x 0.22 | pierre (fer_v) | kitbash puits / foyers | `q_brique_2` |
| `pq_brique_3` | moellon 3 | Prop_Brick3 | 126 -> 126 | 0.38 x 0.25 x 0.22 | pierre (fer_v) | kitbash puits / foyers | `q_brique_3` |
| `pq_brique_4` | moellon 4 | Prop_Brick4 | 126 -> 126 | 0.26 x 0.25 x 0.22 | pierre (fer_v) | kitbash puits / foyers | `q_brique_4` |
| `pq_bordure_1` | dalle de bordure | Prop_ExteriorBorder_Straight1 | 16 -> 16 | 2.00 x 0.13 x 0.70 | pierre (fer_v) | margelle du puits, bordures | `q_bordure_1` |
| `pq_bordure_2` | dalle de bordure 2 | Prop_ExteriorBorder_Straight2 | 16 -> 16 | 2.00 x 0.13 x 0.70 | pierre (fer_v) | bordures, offrandes (dalle basse) | `q_bordure_2` |
| `pq_bordure_angle` | dalle de bordure d'angle | Prop_ExteriorBorder_Corner | 18 -> 18 | 0.70 x 0.13 x 0.70 | pierre (fer_v) | bordures | `q_bordure_angle` |
| `pq_planches_sol` | plancher de planches | Floor_WoodDark_Half1 | 32 -> 32 | 1.00 x 0.02 x 2.00 | bois (bois) | estrade de la halle, toit du puits, soufflet (kitbash) | `q_planches_sol` |
| `pq_porte_1_plate` | porte de planches 1 | Door_1_Flat | 314 -> 314 | 1.17 x 2.20 x 0.13 | bois (bois, fer) | portes des maisons closes (q_porte_*) | `q_porte_1_plate` |
| `pq_porte_1_ronde` | porte de planches 1 cintrée | Door_1_Round | 470 -> 470 | 1.06 x 2.20 x 0.12 | bois (bois, fer) | portes des maisons closes | `q_porte_1_ronde` |
| `pq_porte_2_plate` | porte de planches 2 | Door_2_Flat | 6032 -> 6032 | 1.17 x 2.20 x 0.27 | bois (bois, fer) | portes des maisons closes | `q_porte_2_plate` |
| `pq_porte_2_ronde` | porte de planches 2 cintrée | Door_2_Round | 6188 -> 6188 | 1.05 x 2.20 x 0.25 | bois (bois, fer) | portes des maisons closes | `q_porte_2_ronde` |
| `pq_porte_4_plate` | porte de planches 4 | Door_4_Flat | 1034 -> 1034 | 1.18 x 2.20 x 0.22 | bois (bois, fer) | portes des maisons closes | `q_porte_4_plate` |
| `pq_porte_4_ronde` | porte de planches 4 cintrée | Door_4_Round | 1218 -> 1218 | 1.06 x 2.20 x 0.20 | bois (bois, fer) | portes des maisons closes | `q_porte_4_ronde` |
| `pq_porte_8_plate` | porte ferrée 8 | Door_8_Flat | 986 -> 986 | 1.17 x 2.20 x 0.21 | bois + fer (bois, fer) | portes des maisons closes, halle | `q_porte_8_plate` |
| `pq_porte_8_ronde` | porte ferrée 8 cintrée | Door_8_Round | 1142 -> 1142 | 1.09 x 2.20 x 0.19 | bois + fer (bois, fer) | portes des maisons closes, halle | `q_porte_8_ronde` |
| `pq_volets_etroits_fermes` | volets étroits fermés | WindowShutters_Thin_Flat_Closed | 96 -> 96 | 0.85 x 1.42 x 0.14 | bois (bois) | volets des fenêtres (q_volets_*) | `q_volets_thin_flat_closed` |
| `pq_volets_etroits_ouverts` | volets étroits ouverts | WindowShutters_Thin_Flat_Open | 96 -> 96 | 1.35 x 1.42 x 0.38 | bois (bois) | volets des fenêtres | `q_volets_thin_flat_open` |
| `pq_volets_larges_fermes` | volets larges fermés | WindowShutters_Wide_Flat_Closed | 120 -> 120 | 1.35 x 1.42 x 0.14 | bois (bois) | volets des fenêtres | `q_volets_wide_flat_closed` |
| `pq_volets_larges_ouverts` | volets larges ouverts | WindowShutters_Wide_Flat_Open | 120 -> 120 | 2.48 x 1.42 x 0.46 | bois (bois) | volets des fenêtres | `q_volets_wide_flat_open` |

### LowPoly Modular Dungeon (27)

| id | nom | source | tris (source -> jeu) | emprise X x Y x Z (m) | matière (atlas) | usage conseillé / remplace | q_* équivalent |
|---|---|---|---|---|---|---|---|
| `pq_sac_pieces` | sac de pièces couché | Bag_Coins | 976 -> 976 | 0.44 x 0.12 x 0.22 | toile de jute + or (fer_v, tissu_v) | trésor de la crypte (sac_a/b) | `q_sac_pieces` |
| `pq_sac_debout` | sac debout ficelé | Bag_Standing | 456 -> 456 | 0.22 x 0.25 x 0.21 | toile de jute (fer_v, tissu_v) | sacs du marché, réserves (alias pq_sac aujourd'hui) | `q_sac_debout` |
| `pq_banniere_mur` | bannière murale | Banner_wall | 440 -> 440 | 1.64 x 2.85 x 0.59 | laine rouge, bois, fer (bois, fer, tissu_v) | halle, salle du trône, crypte | `q_banniere_mur` |
| `pq_tonneau_2` | tonneau cerclé de bois | Barrel2 | 1088 -> 1088 | 1.03 x 1.35 x 1.02 | bois (bois) | tonneau_b / tonneau_c (alias pq_tonneau aujourd'hui) | `q_tonneau_2` |
| `pq_seau_2` | seau de bois cerclé de fer | Bucket | 360 -> 360 | 0.38 x 0.53 x 0.40 | bois + fer (bois, fer) | seaux (alias pq_seau_bois aujourd'hui) | `q_seau_2` |
| `pq_chaise_2` | chaise à assise de laine | Chair | 1298 -> 1298 | 0.63 x 1.16 x 0.70 | bois + laine rouge (bois, tissu_v) | chaises de la crypte (alias pq_chaise aujourd'hui) | `q_chaise_2` |
| `pq_coffre_2` | coffre ferré bombé | Chest | 1676 -> 1676 | 1.18 x 0.90 x 0.82 | bois + fer (bois, fer) | coffres décor (alias pq_coffre_ferme aujourd'hui) | `q_coffre_2` |
| `pq_toile_araignee_1` | toile d'araignée | Cobweb | 1108 -> 1108 | 1.21 x 0.76 x 0.91 | écru (tissu_v) | angles de la crypte et de la grotte | `q_toile_araignee_1` |
| `pq_toile_araignee_2` | toile d'araignée 2 | Cobweb2 | 868 -> 868 | 1.34 x 0.84 x 1.03 | écru (tissu_v) | angles de la crypte et de la grotte | `q_toile_araignee_2` |
| `pq_colonne_donjon` | colonne de crypte | Column | 440 -> 440 | 1.30 x 4.07 x 1.30 | pierre (fer_v) | colonnes de la crypte | `q_colonne_1` |
| `pq_colonne_donjon_2` | colonne de crypte 2 | Column2 | 548 -> 548 | 1.30 x 4.07 x 1.30 | pierre (fer_v) | colonnes de la crypte | `q_colonne_2` |
| `pq_caisse_2` | caisse de planches cerclée | Crate | 2502 -> 2502 | 1.38 x 1.31 x 1.31 | bois (bois) | g_caisse_a (alias pq_caisse_fer aujourd'hui) | `q_caisse_2` |
| `pq_muret` | muret de pierre | Fence_Straight_Modular | 104 -> 104 | 2.00 x 1.29 x 0.78 | pierre (fer_v) | murets de la crypte, enclos | `q_palissade` |
| `pq_muret_bout` | muret de pierre (bout) | Fence_End_Modular | 102 -> 102 | 1.39 x 1.29 x 0.78 | pierre (fer_v) | murets | `q_palissade_bout` |
| `pq_muret_angle` | muret de pierre (angle) | Fence_90_Modular | 112 -> 112 | 1.39 x 1.29 x 1.39 | pierre (fer_v) | murets | `q_palissade_angle` |
| `pq_piedestal_1` | piédestal | Pedestal | 1844 -> 1844 | 1.95 x 2.19 x 1.96 | pierre (fer_v) | présentoirs, reliquaires | `q_piedestal_1` |
| `pq_piedestal_2` | piédestal 2 | Pedestal2 | 1182 -> 1182 | 1.74 x 2.31 x 1.74 | pierre (fer_v) | présentoirs, reliquaires | `q_piedestal_2` |
| `pq_crane` | crâne | Skull | 1392 -> 1392 | 0.60 x 0.46 x 0.44 | os (fer_v) | crane_a/b de la crypte et de la grotte (gardés : aucun pq_*) | `q_crane` |
| `pq_pieux` | pointes de fer | Spikes | 504 -> 504 | 1.76 x 1.18 x 1.76 | fer (fer) | pièges, défenses | `q_pieux` |
| `pq_epee_support` | épée sur support mural | Sword_WallMount | 2382 -> 2382 | 1.07 x 0.85 x 0.21 | fer + bois (bois, fer, fer_v) | trophée mural de la halle, armurerie | `q_epee_support` |
| `pq_table_grande_2` | grande table de planches ferrée | Table_Big | 916 -> 916 | 1.58 x 0.85 x 3.30 | bois + fer (bois, fer) | tables de la crypte (table_a/b/c), réfectoire | `q_table_grande_2` |
| `pq_table_petite_2` | petite table de planches ferrée | Table_Small | 804 -> 804 | 1.30 x 0.85 x 1.98 | bois + fer (bois, fer) | tables de la crypte, camp | `q_table_petite_2` |
| `pq_piege_pieux` | dalle à pointes (piège) | Trap_spikes | 2032 -> 2032 | 1.99 x 1.17 x 1.99 | fer (fer) | pièges de la crypte | `q_piege_pieux` |
| `pq_vase_5` | urne de terre cuite | Vase | 220 -> 220 | 0.31 x 0.36 x 0.31 | argile (fer_v) | urne_b (alias pq_vase_4 aujourd'hui) | `q_vase_5` |
| `pq_bucher` | bûcher (sans flamme) | Woodfire | 144 -> 144 | 0.78 x 0.45 x 0.83 | bois (bois) | foyers, feu de camp, forge de plein air (q_bucher gardé) | `q_bucher` |
| `pq_trappe` | trappe de bois ferrée | Trapdoor | 504 -> 504 | 1.74 x 0.21 x 1.70 | bois + fer (bois, fer) | sol de la crypte, cave, grenier | — |
| `pq_coffre_or_2` | coffre ferré doré | Chest_Gold | 22512 -> 6603 (collapse 0.30) | 1.18 x 0.90 x 1.48 | bois + or terni (bois, fer, fer_v) | trésor de la crypte | — |

### Medieval Dungeon (22)

| id | nom | source | tris (source -> jeu) | emprise X x Y x Z (m) | matière (atlas) | usage conseillé / remplace | q_* équivalent |
|---|---|---|---|---|---|---|---|
| `pq_os_tas` | tas d'os | Bones | 788 -> 788 | 0.43 x 0.21 x 0.37 | os (fer_v) | ossuaire, monticules d'os de la crypte (gardés) | `q_os_tas` |
| `pq_os_tas_2` | tas d'os 2 | Bones2 | 576 -> 576 | 0.29 x 0.14 x 0.37 | os (fer_v) | ossuaire, crypte | `q_os_tas_2` |
| `pq_roc_1` | gravats 1 | Rock1 | 24 -> 24 | 0.43 x 0.21 x 0.58 | pierre (fer_v) | gravats de la crypte et de la mine | `q_roc_1` |
| `pq_roc_2` | gravats 2 | Rock2 | 20 -> 20 | 0.54 x 0.21 x 0.53 | pierre (fer_v) | gravats | `q_roc_2` |
| `pq_roc_3` | gravats 3 | Rock3 | 28 -> 28 | 0.41 x 0.21 x 0.53 | pierre (fer_v) | gravats | `q_roc_3` |
| `pq_colonne_brisee` | colonne brisée | Column_Broken | 140 -> 140 | 0.61 x 0.62 x 1.11 | pierre (fer_v) | crypte en ruine, tumulus | `q_colonne_brisee` |
| `pq_colonne_brisee_2` | colonne brisée 2 | Column_Broken2 | 172 -> 172 | 0.90 x 1.28 x 0.90 | pierre (fer_v) | crypte en ruine | `q_colonne_brisee_2` |
| `pq_fiole_1` | fiole 1 | Potion | 444 -> 444 | 0.09 x 0.17 x 0.09 | verre sombre (bois, fer_v) | groupes de fioles (archives, alchimie) | `q_fiole_1` |
| `pq_fiole_2` | fiole 2 | Potion2 | 248 -> 248 | 0.07 x 0.16 x 0.07 | verre sombre (bois, fer, fer_v) | groupes de fioles | `q_fiole_2` |
| `pq_fiole_3` | fiole 3 | Potion3 | 478 -> 478 | 0.07 x 0.16 x 0.08 | verre sombre (fer, fer_v) | groupes de fioles | `q_fiole_3` |
| `pq_livre_d1` | gros livre relié | Book2 | 888 -> 888 | 0.24 x 0.10 x 0.25 | laine rouge + écru (fer, fer_v) | piles de livres de la crypte | `q_livre_d1` |
| `pq_livre_d2` | gros livre relié 2 | Book3 | 888 -> 888 | 0.24 x 0.13 x 0.20 | laine rouge + écru (fer, fer_v) | piles de livres | `q_livre_d2` |
| `pq_livre_ouvert` | livre ouvert | Book_Open | 888 -> 888 | 0.24 x 0.03 x 0.27 | laine rouge + écru (fer, fer_v) | lutrin, livre ouvert de la crypte (gardé : aucun pq_*) | `q_livre_ouvert` |
| `pq_tapis_crypte` | tapis long à franges | Carpet | 158 -> 158 | 1.27 x 0.15 x 3.21 | laine rouge + or terni (tissu_v) | q_tapis de la crypte | `q_tapis` |
| `pq_coffre_d` | coffre ferré de crypte | Chest | 336 -> 336 | 0.45 x 0.57 x 0.67 | bois + fer (bois, fer) | q_coffre_d (quartiers de la crypte) | `q_coffre_d` |
| `pq_coffre_or` | coffre au trésor | Chest_gold | 436 -> 436 | 0.47 x 0.69 x 0.67 | bois + fer + or (bois, fer, fer_v) | q_coffre_or (trésor) | `q_coffre_or` |
| `pq_candelabre_d` | candélabre haut de fer (éteint) | Candelabrum_tall | 988 -> 988 | 0.84 x 1.65 x 0.81 | fer + cire (fer, fer_v) | compositions éteintes de la crypte | `q_candelabre_d` |
| `pq_bougie_d` | bougie sur bougeoir de fer | Candle | 272 -> 272 | 0.09 x 0.27 x 0.11 | fer + cire (fer, fer_v) | autels, tables de la crypte | `q_bougie_d` |
| `pq_barreaux` | barreaux de cellule | Bars | 512 -> 512 | 0.12 x 2.20 x 1.41 | fer (fer) | cellules, grilles de la crypte et du repaire | — |
| `pq_candelabre_court` | candélabre de table (éteint) | Candelabrum | 636 -> 636 | 0.13 x 0.45 x 0.38 | fer + cire (fer, fer_v) | tables de la crypte, autels (candélabres maison : flamme à ajouter) | — |
| `pq_torche_murale_d` | torche murale de crypte (sans flamme) | Torch_wall | 404 -> 404 | 0.38 x 0.60 x 0.16 | fer + bois (bois, fer) | appliques de la crypte (flamme et lumière du jeu à garder) | — |
| `pq_tonneau_cercle` | tonneau cerclé de fer | Barrel | 476 -> 476 | 0.78 x 0.90 x 0.78 | bois + fer (bois, fer) | tonneaux de la crypte et de la grotte (variante de pq_tonneau) | — |

### Survival (13)

| id | nom | source | tris (source -> jeu) | emprise X x Y x Z (m) | matière (atlas) | usage conseillé / remplace | q_* équivalent |
|---|---|---|---|---|---|---|---|
| `pq_tente` | tente de toile | Tent | 788 -> 788 | 2.92 x 2.06 x 4.97 | toile de jute + bois (bois, fer, tissu_v) | camp de chasseur, camp des bandits (q_tente gardé) | `q_tente` |
| `pq_feu_bois` | feu de bois (bûches) | Bonfire | 616 -> 616 | 0.98 x 0.30 x 0.89 | bois (bois) | feu de camp, foyers (q_feu_bois gardé) | `q_feu_bois` |
| `pq_piege_ours` | piège à mâchoires ouvert | BearTrap_Open | 608 -> 608 | 0.39 x 0.09 x 0.46 | fer (fer) | camp de chasseur, enclos (q_piege_ours gardé) | `q_piege_ours` |
| `pq_piege_ours_ferme` | piège à mâchoires fermé | BearTrap_Closed | 608 -> 608 | 0.37 x 0.22 x 0.46 | fer (fer) | coins de chasseurs | `q_piege_ours_ferme` |
| `pq_marmite_camp` | marmite de camp | Pot | 326 -> 326 | 0.38 x 0.23 x 0.45 | fer (fer) | camp, foyer éteint (q_marmite_camp gardé) | `q_marmite_camp` |
| `pq_marmite_camp_petite` | petite marmite de camp | Pot_Small | 326 -> 326 | 0.26 x 0.09 x 0.31 | fer (fer) | camp | `q_marmite_camp_petite` |
| `pq_poele` | poêle à manche de bois | Pan | 246 -> 246 | 0.28 x 0.06 x 0.45 | fer + bois (bois, fer) | camp, cuisine | `q_poele` |
| `pq_hache_camp` | hache de bûcheron | Axe | 236 -> 236 | 0.32 x 0.81 x 0.05 | fer + bois (bois, fer) | billots, tas de bois (q_hache_camp gardé) | `q_hache_camp` |
| `pq_hachette` | hachette | Axe_Small | 176 -> 176 | 0.20 x 0.54 x 0.03 | fer + bois (bois, fer) | coins de chasseurs, camp | `q_hachette` |
| `pq_pelle` | pelle | Shovel | 322 -> 322 | 0.23 x 1.08 x 0.05 | fer + bois (bois, fer) | forge (caisse à charbon), mine, grange | `q_pelle` |
| `pq_couteau_camp` | couteau de chasse | Knife | 450 -> 450 | 0.04 x 0.25 x 0.01 | fer + bois (bois, fer) | camp, boucher | `q_couteau_camp` |
| `pq_rondin` | rondin | WoodLog | 202 -> 202 | 1.39 x 0.41 x 0.41 | bois (bois) | bûchers des abords, bancs du camp (q_rondin gardé) | `q_rondin` |
| `pq_torche_bois` | torche de bois (éteinte) | WoodenTorch | 448 -> 448 | 0.10 x 0.60 x 0.09 | bois + fer (bois, fer, fer_v) | torche tenue / plantée, râtelier de torches | — |

### Ultimate Food (27)

| id | nom | source | tris (source -> jeu) | emprise X x Y x Z (m) | matière (atlas) | usage conseillé / remplace | q_* équivalent |
|---|---|---|---|---|---|---|---|
| `pq_pomme` | pomme | Apple | 440 -> 440 | 0.08 x 0.09 x 0.08 | rouge (bois, fer_v) | étals, tables (nourriture gardée) | `q_pomme` |
| `pq_pomme_verte` | pomme verte | Apple_Green | 440 -> 440 | 0.08 x 0.09 x 0.08 | vert (bois, fer_v) | étals, tables | `q_pomme_verte` |
| `pq_pain` | miche de pain | Bread | 412 -> 412 | 0.17 x 0.21 x 0.30 | croûte brune (bois, fer_v) | étals, tables | `q_pain` |
| `pq_tranche_pain` | tranche de pain | Bread_Slice | 368 -> 368 | 0.17 x 0.21 x 0.03 | brun + mie (bois, fer_v) | tables | `q_tranche_pain` |
| `pq_carotte_f` | carotte | Carrot | 864 -> 864 | 0.07 x 0.20 x 0.07 | orange terni (fer_v) | étals, cageots | `q_carotte_f` |
| `pq_cuisse` | cuisse rôtie | ChickenLeg | 288 -> 288 | 0.18 x 0.08 x 0.08 | brun (fer_v) | tables du festin | `q_cuisse` |
| `pq_marmite_soupe` | marmite de soupe | CookingPot_Soup | 260 -> 260 | 0.51 x 0.23 x 0.42 | fer + soupe (fer, fer_v) | foyers des maisons, camp | `q_marmite_soupe` |
| `pq_marmite_soupe_2` | chaudron de soupe | CookingPot2_Soup | 260 -> 260 | 0.48 x 0.13 x 0.42 | fer + soupe (fer, fer_v) | foyers | `q_marmite_soupe_2` |
| `pq_oeuf` | œuf | Egg_Whole | 288 -> 288 | 0.05 x 0.06 x 0.05 | écru (fer_v) | cuisine, garde-manger | `q_oeuf` |
| `pq_poisson` | poisson | Fish | 438 -> 438 | 0.40 x 0.04 x 0.13 | gris-fer (fer, fer_v) | quai (matériel de pêche), étal, séchoir | `q_poisson` |
| `pq_aretes` | arêtes de poisson | FishBone | 588 -> 588 | 0.25 x 0.04 x 0.11 | os (fer_v) | restes du camp | `q_aretes` |
| `pq_jarre` | grande jarre | Jar_Large | 216 -> 216 | 0.30 x 0.30 x 0.28 | terre cuite (fer_v) | garde-manger, réserves | `q_jarre` |
| `pq_champignon` | champignon | Mushroom | 92 -> 92 | 0.05 x 0.06 x 0.06 | brun clair (fer_v) | cuisine, grotte | `q_champignon` |
| `pq_citrouille` | courge | Pumpkin | 644 -> 644 | 0.34 x 0.21 x 0.35 | orange sombre (bois, fer_v) | étals, grenier | `q_citrouille` |
| `pq_saucisse` | saucisse | Sausage_Cooked | 140 -> 140 | 0.03 x 0.03 x 0.18 | brun (fer_v) | viande séchée pendue (kitbash maison) | `q_saucisse` |
| `pq_viande` | pièce de viande | Steak | 412 -> 412 | 0.15 x 0.04 x 0.22 | rouge sombre (fer_v) | étal du boucher, séchoir | `q_viande` |
| `pq_navet` | navet | Turnip | 976 -> 976 | 0.11 x 0.21 x 0.11 | écru + vert (fer_v) | étals, cageots | `q_navet` |
| `pq_chou` | chou | Lettuce_Whole | 592 -> 592 | 0.20 x 0.16 x 0.20 | vert (fer_v) | étals de la place | `q_chou` |
| `pq_lard` | lard | Bacon_Uncooked | 564 -> 564 | 0.20 x 0.00 x 0.05 | écru + rouge (fer_v) | boucher, garde-manger | `q_lard` |
| `pq_bouteille_verte` | bouteille de verre vert | Bottle1 | 220 -> 220 | 0.09 x 0.30 x 0.09 | verre vert + bouchon (bois, fer_v) | tables, étagères (alias pq_bouteille aujourd'hui) | `q_bouteille_1` |
| `pq_bouteille_vin` | bouteille de vin | Bottle2 | 220 -> 220 | 0.09 x 0.31 x 0.09 | verre sombre (bois, fer, fer_v) | tables, cave | `q_bouteille_2` |
| `pq_ecuelle` | écuelle de bois | Plate | 156 -> 156 | 0.23 x 0.03 x 0.24 | bois (bois) | tables (bol maison) | `q_ecuelle` |
| `pq_ecuelle_2` | écuelle de terre cuite | Plate2 | 196 -> 196 | 0.27 x 0.03 x 0.28 | argile (fer_v) | tables | `q_ecuelle_2` |
| `pq_marmite_vide` | marmite de fer | CookingPot | 260 -> 260 | 0.67 x 0.30 x 0.56 | fer (fer) | foyers, cuisine (pq_marmite est en argile) | — |
| `pq_chaudron_anse` | chaudron à anse | CookingPot2 | 260 -> 260 | 1.18 x 0.32 x 1.02 | fer + bois (bois, fer) | foyer pendu, camp | — |
| `pq_poele_f` | poêle de fer | FryingPan | 214 -> 214 | 0.31 x 0.04 x 0.50 | fer + bois (bois, fer) | cuisine, foyers | — |
| `pq_lard_cuit` | tranche de lard grillé | Bacon_Cooked | 564 -> 564 | 0.17 x 0.00 x 0.04 | brun (fer_v) | tables du festin | — |

## Rejetés (avec la raison)

### Ultimate Home Interior (103 sur 123)

| Pièces | Raison |
|---|---|
| Bathroom_* (11 : baignoire, douche, lavabo, WC x2, papier, miroirs, serviette, lave-linge) | salle de bain moderne |
| Kitchen_* (10 : frigo, fours x2, évier, éléments 1-3 tiroirs, placards x3) | cuisine moderne (éléments laqués verts, électroménager) |
| Trashcan_* (5) | poubelles |
| Houseplant_1-8 | plantes en pot d'appartement (et la végétation reste maison) |
| Couch_* (8) | canapés modernes |
| Light_* sauf chandelier (19 : plafonniers, cubes, icosaèdres, lampes de bureau / sur pied / d'appoint) | luminaires électriques |
| Light_Chandelier | lustre à abat-jour sur bras courbes (rendu : moderne) ; `pq_lustre` du MegaKit reste le lustre |
| Window_* (8) | fenêtres vitrées modernes |
| Curtains_Single / Double | rideaux sur tringle |
| Bed_Bunk, Bed_Single, Bed_King | cadre TUBULAIRE de métal, matelas à drap housse (rendu) ; `pq_lit` / `pq_lit_2` restent les lits |
| Stool | tabouret de bar à coussin et repose-pieds de métal |
| Chair_3 | dossier à croisillons et assise rembourrée : salle à manger moderne |
| Table_RoundSmall2 | pied tripode à volutes (style XIXe) ; doublon de `pq_table_ronde` |
| Drawer_1-4 | pieds fuselés évasés (mobilier des années 1950) ; `pq_commode` (Drawer_5, sans pieds) gardée |
| Shelf_2, Shelf_Large, Shelf_Small1-3 | doublon de Shelf_1 ; penderie moderne ; meubles TV bas à casiers |
| Fireplace | cheminée classique à manteau mouluré (XVIIIe) ; les foyers sont de l'architecture gardée |
| Column_Round3 | doublon plus haut de Column_Round2 (`pq_colonne_ronde`, mise à l'échelle) |
| Door_1-9, Door_Double | portes d'appartement (panneaux moulurés, vitrage, poignées) ; les portes de planches du Medieval Village sont converties à la place |
| Plate_1, Plate_2, Fork, Knife | porcelaine décagonale / carrée, couverts modernes ; doublons de `pq_assiette`, `pq_fourchette`, `pq_couteau_table` |

### Medieval Village MegaKit

| Pièces | Raison |
|---|---|
| Wall_*, Roof_*, Floor_* (sauf Floor_WoodDark_Half1 = `pq_planches_sol`), Overhang_*, Corner_*, Balcony_*, HoleCover_*, Stairs_*, Stair_*, DoorFrame_*, Window_* (~140) | bâti modulaire : hors périmètre (remplacer revient à refaire le village) |
| Prop_Chimney, Prop_Chimney2 | cheminées de toit : bâti |
| Prop_Vine1-9 | végétation (règle : la nature reste maison) |
| WindowShutters_*_Round_* (4) | volets cintrés pour fenêtres en arc ; non convertis (aucune fenêtre cintrée maison) ; ajout en une ligne dans `gen_props_sources_v5.py` si besoin |

### Lots 2-4 non repris (q_* restants)

| q_* | Raison |
|---|---|
| q_roc_4, q_roc_5, q_fiole_4-6, q_oeuf_blanc, q_poele_petite | doublons (variantes très proches des pq_* v5 gardés) |
| q_saucisse_crue | saucisse rose type hot-dog (hors thème) |
| q_couteau_f, q_fourchette_f | doublons de `pq_couteau_table`, `pq_fourchette` |
| q_cheminee_1/2 | bâti |
| q_buche, q_poutre_ronde (kitbash OBJ maison) | pièces de construction sans texture source ; à faire si les kitbash passent en pq_* |

### Autres pièces des packs non convertis

| Pack | Pièces | Raison |
|---|---|---|
| Medieval Dungeon | Entrance*, Modular*, Stairs, Window, WallRocks | architecture de crypte |
| Medieval Dungeon | Torch (flamme), Column (doublon de colonne) | flamme du jeu ; doublon |
| Survival | armes à feu, batteries, conserves, téléphone, radio, trousses, propane, jerrican, bouteilles plastique, boussole, allumettes, sac à dos, bandages, poubelle, Torch (lampe) | moderne (tri thème du 2026-11-04) |
| Survival | Bonfire_Fire, WoodenTorch_Fire | flammes (le jeu pose les siennes) |
| Survival | Raft, Raft_Paddle | radeau : pas d'usage dans les lieux actuels |
| Ultimate Food | burgers, frites, pizzas, sushis, donuts, glaces, sodas, sauces, fruits exotiques, etc. | hors thème (tri du 2026-11-04) |
| Modular Dungeon (itch) | Arch*, Floor*, Wall*, Stairs*, Decorative_Wall, Trap_empty | architecture |
| Modular Dungeon (itch) | Banner, Barrel, Coin_Pile, Torch | doublons de pq_* existants ; flamme |
| Modular Dungeon (itch) | Statue_Horse | statue de cheval stylisée « jouet » |
