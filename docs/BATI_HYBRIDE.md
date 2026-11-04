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
- Vitrages : le vitrage du village (lot `_vitres`, lueur réglée par l'heure, même teinte que les autres fenêtres la nuit),
  découpé en carreaux de la taille de ceux des maisons de rondins (≈ 0,7 x 0,55 m).

## Maison par maison

« Kit » = pièces du Medieval Village MegaKit assemblées ; « props » = props Quaternius déjà validés (docs/PROPS_REMPLACEMENT.md) ;
« maison » = géométrie faite main d'origine, gardée.

| Bâtiment (x, z monde) | Avant | Quaternius (kit / props) | Gardé fait maison (identité nordique) |
|---|---|---|---|
| H1 (36, 53), bord de place | rondins, pignons à têtes de dragon | kit : murs plâtre (Wall_Plaster_*), baies Window_Wide/Thin, poteaux d'angle Corner_Exterior_Wood, toit Roof_RoundTiles_6x8, pignons Roof_Front_Brick6, cheminée Prop_Chimney2 ; props : vantail q_porte_*, volets q_volets_* | **têtes de dragon** croisées au faîte (Village._dragon), soubassement, neige du toit (dalle épaisse, rouleau de faîte, glaçons), torche, fumée |
| H2 (54, 55.5), auberge | rez de pierre, étage à colombages en encorbellement | kit : rez Wall_UnevenBrick, étage plâtre en encorbellement (Wall_BottomCover), baies, toit, pignons, cheminée Prop_Chimney ; props : vantail, volets | **colombage en croix** (poteaux, lisses, croix de Saint-André) sur les pans pleins de l'étage, enseigne « chope », soubassement, socle de pente, neige |
| H3 (35.5, 71), haute rue | planches, porte sur le pignon est, appentis | kit : murs plâtre, baies, toit, pignons ; props : vantail, volets | appentis à bois, soubassement, neige (le plâtre à pans de bois `Wall_Plaster_WoodGrid` a été essayé : grille trop chargée en PS1) |
| H4 (54, 77), haute rue | pierre, porte ouest | kit : Wall_UnevenBrick (embrasures en pierre), baies, toit, pignons, cheminée Prop_Chimney2 ; props : vantail, volets | soubassement, fumée, neige |
| Maison du moulin (25.5, 55.5) | pierre | kit : Wall_UnevenBrick, mur de berge plein (l'arbre de la roue y entre), baies, toit, pignons, cheminée Prop_Chimney ; props : vantail, volets | enseigne « roue », roue et arbre (C7c), neige |
| Ferme B (61, 3.5) | pierre, porte ouest | kit : Wall_UnevenBrick, baies, toit, pignons, cheminée Prop_Chimney2 ; props : vantail, volets | terrasse de la ferme, tas de bois (q_buche), fumée, neige |
| Halle du jarl (44, 21) | rondins | kit : cadre de porte DoorFrame_Flat_WoodDark | **tout en rondins** : lanterne de fumée, têtes de dragon, boucliers, bancs, porte sur charnière, intérieur |
| Sigrún (59.5, 47), chasseurs (63, 29), Grima (28, 47) | rondins, maisons visitables | kit : cadre de porte DoorFrame_Flat_WoodDark (autour du vantail sur charnière), cheminée Prop_Chimney2 | rondins vus des deux côtés, têtes de dragon, fenêtres et intérieurs, vantail sur charnière, collisions de coque |
| H5 (36, 85), haute rue | rondins, porche | kit : cheminée Prop_Chimney2 | rondins, porche, banc |
| H6, grenier sur pierres levées (60, 20.5) | stabbur de planches, escalier détaché | kit : escalier extérieur Stairs_Exterior_Straight (en bois sombre) | tout le grenier (pierres levées, étage en surplomb) |
| Ferme A (79.5, 24.5) | rondins, têtes de dragon | kit : cheminée Prop_Chimney2 | rondins, têtes de dragon, tas de bois |
| Granges A et B | planches, grandes portes | — | tout (le kit n'a pas de portes de grange) |
| Tour-clocher, moulin à vent, forge, palissade, crypte, grotte | — | — | inchangés |
