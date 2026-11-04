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

(tableau rempli plus bas)
