# Bâti hybride du village (Quaternius + rondins)

Branche `bati/hybride` (depuis e344761f, exe 3), 2026-11-04. Reprend l'essai `essai/bati_quaternius` (323e551a, 36d2535f :
3 façades témoins) et le généralise au village. **Mode par défaut.** Interrupteur avant/après : `-- --bati-ancien` rend le bâti
d'avant (VillageBati.maison et Village._maison reprennent leur code d'origine). L'ancienne option `--bati-quaternius` ne sert plus.

## Méthode

- Assemblage Blender (`sources_blender/scripts/assembler_bati_quaternius.py`, liste `sources_blender/quaternius/bati.json`) :
  pièces MODULAIRES du Medieval Village MegaKit (CC0) étirées à l'emprise du bâtiment d'origine (modules de 2 m, hauteur
  x0,8 pour des portes de 1,9 m), puis chaîne `importer_quaternius.py` (palette de la bible, ton x occlusion, matière par face)
  → `assets/modeles/bati_quaternius.dat` (+ `.json` : cotes, vitrages, portes, cheminée). Relance :
  `blender.exe -b --python assembler_bati_quaternius.py -- liste=<bati.json>` (~1 min).
- Jeu (`scripts/village_bati_q.gd`) : comme docs/PROPS_REMPLACEMENT.md, **fondu dans les lots existants** (`Village._ajouter`
  par (pièce, matière) du groupe de fusion), **aucun nœud par objet** ; les matières sont CELLES DU VILLAGE (torchis,
  roche, poutres, fer) : les couleurs de sommet ne portent que le ton. Collision, emprise, soubassement, socle de pente,
  neige des toits (dalle épaisse + rouleau de faîte + glaçons), fumée, torche, enseigne, appentis, tas de bois : ceux du
  bâtiment d'origine.
- Vantaux : pas celui du kit (il sortait en trou noir) ; le vantail de planches des props déjà validés (`q_porte_*`, ronds
  ou plats selon l'ouverture) est posé dans l'ouverture.
- Fenêtres (passe v2) : dans chaque baie du kit, la fenêtre des maisons d'avant (`VillageBati.fenetre` : vitrage du lot `_vitres`
  à 4 carreaux, cadre, linteau, appui, jambages et meneau en bois sombre), un panneau de planches sombres dans le reste de la baie, deux volets de planches sombres entrouverts.

## Maison par maison

« Kit » = pièces du Medieval Village MegaKit assemblées ; « props » = props Quaternius déjà validés (docs/PROPS_REMPLACEMENT.md) ;
« maison » = géométrie faite main d'origine, gardée.

| Bâtiment (x, z monde) | Avant | Quaternius (kit / props) | Gardé fait maison (identité nordique) |
|---|---|---|---|
| H1 (36, 53), bord de place | rondins, pignons à têtes de dragon | kit : murs plâtre (Wall_Plaster_*), baies Window_Wide/Thin, poteaux d'angle Corner_Exterior_Wood, toit Roof_RoundTiles_6x8, pignons Roof_Front_Brick6, cheminée Prop_Chimney2 ; props : vantail q_porte_*, volets q_volets_* | **têtes de dragon** croisées au faîte (Village._dragon), soubassement, neige du toit (dalle épaisse, rouleau de faîte, glaçons), torche, fumée |
| H2 (54, 55.5), auberge | rez de pierre, étage à colombages en encorbellement | kit : rez Wall_UnevenBrick, étage plâtre en encorbellement (Wall_BottomCover), baies, toit, pignons, cheminée Prop_Chimney ; props : vantail | **colombage en croix** (poteaux, lisses, croix de Saint-André) sur les pans pleins de l'étage, enseigne « chope », soubassement, socle de pente, neige |
| H3 (35.5, 71), haute rue | planches, porte sur le pignon est, appentis | kit : murs plâtre, baies, toit, pignons ; props : vantail | appentis à bois, soubassement, neige (le plâtre à pans de bois `Wall_Plaster_WoodGrid` a été essayé : grille trop chargée en PS1) |
| H4 (54, 77), haute rue | pierre, porte ouest | kit : Wall_UnevenBrick (embrasures en pierre), baies, toit, pignons, cheminée Prop_Chimney2 ; props : vantail | soubassement, fumée, neige |
| Maison du moulin (25.5, 55.5) | pierre | kit : Wall_UnevenBrick, mur de berge plein (l'arbre de la roue y entre), baies, toit, pignons, cheminée Prop_Chimney ; props : vantail | enseigne « roue », roue et arbre (C7c), neige |
| Ferme B (61, 3.5) | pierre, porte ouest | kit : Wall_UnevenBrick, baies, toit, pignons, cheminée Prop_Chimney2 ; props : vantail | terrasse de la ferme, tas de bois (q_buche), fumée, neige |
| Halle du jarl (44, 21) | rondins | kit : cadre de porte DoorFrame_Flat_WoodDark | **tout en rondins** : lanterne de fumée, têtes de dragon, boucliers, bancs, porte sur charnière, intérieur |
| Sigrún (59.5, 47), chasseurs (63, 29), Grima (28, 47) | rondins, maisons visitables | kit : cadre de porte DoorFrame_Flat_WoodDark (autour du vantail sur charnière), cheminée Prop_Chimney2 | rondins vus des deux côtés, têtes de dragon, fenêtres et intérieurs, vantail sur charnière, collisions de coque |
| H5 (36, 85), haute rue | rondins, porche | kit : cheminée Prop_Chimney2 | rondins, porche, banc |
| H6, grenier sur pierres levées (60, 20.5) | stabbur de planches, escalier détaché | kit : escalier extérieur Stairs_Exterior_Straight (en bois sombre) | tout le grenier (pierres levées, étage en surplomb) |
| Ferme A (79.5, 24.5) | rondins, têtes de dragon | kit : cheminée Prop_Chimney2 | rondins, têtes de dragon, tas de bois |
| Granges A et B | planches, grandes portes | gen/bati2 : essayées puis rejetées (voir plus bas) | — |
| Tour-clocher, moulin à vent, forge ouverte | — | **gen/bati2** : voir plus bas | — |
| Palissade, crypte, grotte | — | — | inchangés |

## Accord des couleurs (retour utilisateur du 2026-11-04 sur l'essai)

Principe : les pièces Quaternius ne gardent PAS leurs teintes ; elles prennent les matières du village et, quand une pièce
équivalente a déjà été validée, c'est cette pièce-là qui est posée.

| Point | Essai (essai/bati_quaternius) | Bâti hybride |
|---|---|---|
| Vantaux | Door_1 du kit, fondu dans le bois sombre : trou noir | vantail de planches q_porte_* des props validés (mêmes que les maisons closes d'avant) + deux marches de pierre |
| Volets | WindowShutters du kit en bois sombre : plaques noires | v1 : q_volets_* (grands, gris-vert) ; **v2** : deux volets de planches sombres (`m_poutres`) de la taille de la fenêtre, comme les fenêtres faites maison |
| Fenêtres | un grand vitrage étiré : gros cadre orange | v1 : carreaux de 0,7 x 0,55 m (12 carreaux par baie), cadre teinté ; **v2** : UNE fenêtre des maisons d'avant par baie (4 carreaux, même vitrage, même cadre sans teinte, jambages/linteau/appui/meneau en bois sombre), panneau de planches sombres autour ; lueur de nuit = même matière que toutes les fenêtres du village |
| Pierre | roche du village | inchangé (mesuré à l'écran : rez de H2 L=68 contre 66 pour le mur de pierre d'avant ; H4 L=51 contre 60 pour le mur voisin) ; embrasures en plâtre du kit passées en pierre sur les maisons de pierre |
| Bois du bâti | poutres du village | inchangé ; planches de rive sombres ajoutées aux pignons (le kit laissait un fil de ciel blanc sous la neige) |
| Colombage | perdu sur H2 | croix de Saint-André sur les pans pleins de l'étage de H2 ; **v2** : étage +Z/-Z en plein / baie / plein (deux croix comme avant), pièces plus fortes (0,2 m) et en saillie, toit et pignons relevés de 0,55 m (`toit_dz`) avec une sablière haute sombre : l'égout du kit couvrait le haut de l'étage |
| Neige des toits | celle du village | inchangé (dalle épaisse, rouleau de faîte, glaçons) |
| Pignons | pierre unie du kit | **v2** : colombage de bois sombre sur chaque pignon (entrait, poinçon, croix de Saint-André : `colombage_pignon`) |
| Portes dégagées | — | **v2** : brasero de la haute rue (39,6 ; 71,2) -> (39,9 ; 73,6) et caisse voisine décalés (`MobilierVillage.DEPLACES_Q`, mode hybride seul) ; tas de bois de la ferme B poussé vers l'angle sud-ouest (z -2,55..-1,15, porte au milieu du pignon) |
| Escalier du grenier | — | Stairs_Exterior_Straight du kit en bois sombre (la pierre du kit, enneigée, sortait blanche) |
| Vue à travers | — | âme sombre dans chaque façade (de près, on voyait à travers les vitrages translucides) |

Planche dédiée : `Desktop/Skyrim captures/bati_hybride/planches_v2/recap_accord_couleurs_jour.png` et `_crepuscule.png` (v1 : `planches/`).

## Mesures de perf

`outils/perf_bati_hybride.sh` (outils/mesure_perf.gd, Iris Xe, 3 poses, avant `--bati-ancien` / après alternés). GPU partagé
avec d'autres agents pendant la mesure : bruit de ±1 ms, lire les médianes et la tendance plutôt que l'écart brut.

| Pose | Série | Avant gpu moy / méd (ms) | Après gpu moy / méd (ms) | Draw calls | Primitives |
|---|---|---|---|---|---|
| place | 1 | 15.60 / 15.16 | 15.85 / 15.80 | 566 → 555 | 911 k → 932 k |
| place | 2 | 15.72 / 15.39 | 14.41 / 14.41 | 572 → 552 | 909 k → 928 k |
| rue | 1 | 16.22 / 15.88 | 16.26 / 16.61 | 417 → 408 | 707 k → 736 k |
| rue | 2 | 15.06 / 15.11 | 15.38 / 14.99 | 417 → 410 | 707 k → 735 k |
| haute_rue | 1 | 18.82 / 18.78 | 17.81 / 17.89 | 325 → 320 | 616 k → 652 k |
| haute_rue | 2 | 16.37 / 16.51 | (mesure non sortie) | — | — |

Bilan : moins de draw calls (−5 à −20, les façades sont fondues dans les lots), +3 à +6 % de primitives ; écart GPU entre
−1,3 et +0,7 ms selon la série, dans le bruit, en moyenne ≈ 0 à +0,3 ms : dans le budget de +0,5 ms. CPU inchangé.

## Limites

- (v1 -> v2 : volets, fenêtres à 12 carreaux, pignons unis, croix de H2 cachée, brasero de H3 et tas de bois de la ferme B : corrigés.)
- Le cadre intérieur du vitrage est celui des rondins, à l'identique (même texture, même matière) : il garde son brun clair
  d'origine ; le bois sombre et froid est celui des jambages, linteau, appui, meneau, volets et panneau de baie.
- Les vantaux q_porte_* (props validés) gardent leur teinte mousse/vert sombre.
- La baie du kit reste plus large que la fenêtre (panneau de planches sombres autour).
- Halle, maisons visitables, H5, fermes à rondins : seulement cheminée et cadre de porte du kit (choix : identité nordique).
- Film : quelques images frôlent un mur ou la neige (vers (44, 61) avant les escaliers, et à la fin devant H5).
- Le jeu de test `test_menus` (fenêtre requise) n'a pas été lancé.

## Lot bâti restant (branche gen/bati2, depuis f90d3756)

Même méthode (pièces du kit converties dans `bati_quaternius.dat`, fondues dans les lots du village, matières du village,
aucun nœud par objet, collisions d'origine). Interrupteur : `--bati-ancien` rend aussi ces quatre bâtiments d'avant (chaque
branche teste `VillageBatiQ.actif` / `VillageBatiQ.detail(<pièce>)`). Nouvelles entrées du .dat : `b_grange_a`, `b_grange_b`,
`bq_toit_tour`, `bq_planches`, `bq_poteau`, `bq_aisselier`, `bq_auvent`, `bq_garde_corps`, `bq_claire_voie`, `bq_poutre`,
`bq_cadre_rond_pierre` (relance rapide : liste réduite à ces entrées, l'assembleur garde les autres du .dat).

| Bâtiment | Kit (kitbash) | Gardé fait maison |
|---|---|---|
| Tour-clocher (45, 87), ~31 m | flèche `Roof_Tower_RoundTiles` (étirée en hauteur x1,35, tuiles en bois sombre des essentes, son épi de fer remplace l'ancien) sur le coyau carré enneigé d'avant ; garde-corps du beffroi `Balcony_Cross_Straight` (croix de Saint-André, bois sombre) sur un muret bas ; aisseliers `Roof_Support2` sous les linteaux ; encadrement cintré `DoorFrame_Round_Brick` (pierre brute) à la place des claveaux | fût de pierre, chaînages, cordons enneigés, meurtrières éclairées, cloche, collision |
| Moulin à vent (95.5, 13) | **rejeté** : calotte `Roof_Tower_RoundTiles` + ailes en `Roof_Log` / `Prop_WoodenFence_Single` (code gardé derrière `VillageBati.MOULIN_KIT = false`) — la calotte évasée à épi faisait pagode, moins nordique que le cône enneigé | tout (moulin d'origine, ailes animées) |
| Granges A (87.5, 24.5) et B (67.5, 6) | **rejetées** : l'assemblage `b_grange_a/_b` (bardage `Floor_WoodDark`, toit `Roof_RoundTiles_6x8`, portes du kit, `VillageBatiQ.portes_grange`) reste dans le .dat et le code, mais n'est pas branché dans `MODELES` — ses planches horizontales sont moins naturelles que les planches verticales d'origine | tout (granges d'origine) |
| Forge ouverte (27, 36) | auvent : 4 poteaux `Corner_Exterior_Wood`, aisseliers `Roof_Support2`, 3 pans de bardeaux `Roof_Wooden_2x1` sous la neige épaisse du village (dalle + glaçons), rives sombres | **enseigne à l'enclume**, sablières, dés de pierre, poste de travail (billot, foyer, meule, props), collisions des poteaux (boîtes 0,28 m) |

Corrections de la v2 :
- Vantaux de porte (`q_porte_*`) : la teinte mousse des couleurs de sommet est ramenée à sa luminance, sur le bois sombre
  (`VillageBatiQ.vantail`) — maisons du kit, et en mode hybride toutes les portes `VillageBati.porte` (tour, moulin…).
- Fils de ciel le long des rives de pignon : les tuiles du kit, vues d'en dessous, laissaient passer le ciel ; une sous-face
  de planches sombres (1,15 m) suit chaque rive dans le plan du toit.

Captures : `Desktop/Skyrim captures/gen_bati2/planches/`. Règle appliquée : un remplacement moins beau ou moins nordique que
l'original est rejeté ; seuls la tour-clocher et la forge passent au kit (moulin et granges rejetés).
