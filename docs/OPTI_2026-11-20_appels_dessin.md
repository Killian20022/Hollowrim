# Opti 2026-11-20 — domaine « appels de dessin » (branche opti/appels_dessin, depuis f0c1b14b)

Machine partagée (2 Godot au plus via godot_slot, souvent chargée), sur secteur (BatteryStatus 2). Les **appels de dessin et primitives**
sont relevés par `RenderingServer.viewport_get_render_info` (passe visible et passe d'ombres séparées) **monde figé** (`process_mode`
désactivé) : ils ne dépendent pas de la charge et se reproduisent à l'unité près. Les temps sont des médianes sur image figée, A/B
alterné dans le même lancement quand c'est possible (occlusion), sinon lancements entrelacés.

## Outils ajoutés
- `outils/audit_appels.gd` (hérite de `audit_mesure_lieu.gd`, mêmes lieux / `--heure` / `--pose`) : temps de rendu image figée (médianes
  sur 90 images), puis masque tour à tour chaque groupe de GeometryInstance3D (enfant du monde + script le plus proche) et chiffre ses
  appels et primitives, visibles et d'ombre ; détail par matière des plus gros groupes (`--fin=n`) ; `--lister=<motif>` : chaque GI
  (surfaces, triangles, ombre, portée, dans le champ, distance, taille).
- `outils/planche_occlusion.gd` : 8 poses (place, haute rue, devant h1, halle x2, h1, h4, ferme A), image + appels + temps CPU/GPU avec
  puis sans occlusion dans la MÊME image figée (planches `rendus/opti_2026-11-20/appels_dessin/planche_occ_*.png`, `diff_occ_*.png`).

## Postes mesurés (avant, f0c1b14b)
Place, 21 h, pose 35,30,221,-8 : **629 appels visibles + 386 d'ombres**, 870 k + 887 k primitives, 3 405 GI dans l'arbre.

| Groupe | appels visibles + ombres | remarque |
|---|---|---|
| bâti du village (village.gd) | 146 + 152 | déjà fondu par (bâtiment, matière) ; ~18 maillages par maison |
| gardes (garde_village.gd) | 205 + 66 | 40 à 48 GI par garde dont ~28 pièces de la torche |
| villageois | 112 + 93 | ~8-9 GI par PNJ (hors domaine : persos_anim) |
| mobilier du village | 47 + 40 | 1 maillage par matière pour tout le village (bois 37 k tris sur 72 m) |
| mains du joueur | 37 + 1 | dont ~28 pièces de la torche |

Place, 12 h : 520 + 253 appels, 828 k + 698 k primitives. Feu de camp (témoin), 12 h : 245 + 390 appels — le village, hors champ
(7 appels visibles), projette 186 appels d'ombre.
Halle, 21 h : 324 + 118 appels, 479 k prim. visibles, dont **le dehors derrière les murs** : végétation 94 + 43, autres bâtiments
103 + 31, entrée de la grotte 18, feu de camp 14, compositions 23.
Crypte (z −25) : 168 appels, 108 k prim. (déjà bon marché, portée ~30 m). Grotte : 289 appels, 132 k prim.

## Fait
| Commit | Optimisation | Gain mesuré | Interrupteur |
|---|---|---|---|
| e65cb7e0 | Torche : ~28 pièces fixes fondues en 1 maillage (1 surface par matière) — gardes de nuit, joueur 1re/3e personne | place 21 h : 619 → 537 appels visibles (−82, −13 %), prim. inchangées ; gardes 219 → 165, mains 38 → 11 | `--sans-opti-torche` |
| 7d82036d | Mur fragile de la grotte : ~42 traits de fissure fondus en 1 maillage | grotte 21 h : 289 → 248 appels visibles (−41, −14 %), prim. identiques | `--sans-opti-fissures` |
| f7c8129e + f38264b3 | Occlusion culling des 16 bâtiments enterables (ArrayOccluder3D : murs au milieu de l'épaisseur, porte + TOUS les vitrages découpés), **allumée seulement la caméra dans un intérieur** | halle vers la porte 706 → 471 appels, 1 081 k → 781 k prim., GPU 14,15 → 13,15 ms ; h4 306 → 177, GPU −0,70 ms ; h1 234 → 171, −0,48 ms ; halle table 313 → 239, −0,44 ms ; CPU de rendu ±0,1 ms. Dehors : coupée (y coûtait +0,35 à +0,86 ms CPU pour ≤ 0,36 ms GPU) | `--sans-opti-occlusion` |

Images : torche et occlusion identiques (écarts = flammes animées, scintillement de la neige, aurore) — `torche_place21_avant|apres.png`,
`planche_occ_*.png` (sans | avec), `diff_occ_*.png` (écart ×8).

## Essais mesurés puis écartés
- Fusion des lots des pivots fixes du village par cellule de 16 m : 100 lots → 85, mais appels du village 298 → 313 et +8 k prim.
  visibles (les maillages fusionnés échappent au tri hors champ).
- Découpe en cases de 24 m (piste de l'agent GPU) des groupes BatiV2 (jusqu'à 92 m), des pieux de la palissade (146 m) et du mobilier :
  place 12 h, ombres 698 k → 592 k prim. (−15 %), visibles 828 k → 807 k, mais +115 appels ; GPU image figée 11,90 / 11,95 ms contre
  12,40 / 11,88 ms sans (gain 0 à 0,5 ms, non concluant), CPU +0,07 à +0,28 ms ; cases de 32 m : 673 k prim. d'ombre, GPU 12,25 / 12,95.
  Le coût des ombres ne suit pas le nombre de primitives : écarté (bâti, palissade et mobilier ; le mobilier seul, −62 k prim. d'ombre
  pour +22 appels, n'a pas pu être mesuré à part avant l'échéance : piste à reprendre).

## Reste / pistes hors domaine
- **Personnages (persos_anim)** : ~45 % des appels de la place (gardes 40-48 GI chacun : armure, tabard 10 k tris, cuirasse 10 k tris ;
  villageois 8-9 GI), et ~450 k des 870 k primitives visibles. Fusion des pièces par matière, LOD des armures lointaines.
- **Ombres (gpu_rendu)** : le village hors champ projette 186 appels d'ombre depuis le feu de camp ; les ombres semblent limitées par
  le tramage (résolution, tranches, distance) plus que par les primitives.
- Mobilier : 6 bannières × 5 maillages (30 appels), étals : un MultiMesh par denrée et par étal — gains < 0,1 ms.
- Village : petites pièces qui projettent une ombre (ferrures, bouts de rondins : ~20 appels d'ombre) — < 0,1 ms.
