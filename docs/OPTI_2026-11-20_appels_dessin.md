# Opti 2026-11-20 — domaine « appels de dessin » (branche opti/appels_dessin, depuis f0c1b14b)

Machine partagée (2 Godot au plus via godot_slot), sur secteur (BatteryStatus 2). Toutes les grandeurs ci-dessous sont des **appels de
dessin et primitives** relevés par `RenderingServer.viewport_get_render_info` (passe visible et passe d'ombres séparées), **monde figé**
(`process_mode` désactivé pendant la mesure) : elles ne dépendent pas de la charge de la machine et se reproduisent à l'unité près.

## Outils ajoutés
- `outils/audit_appels.gd` (hérite de `audit_mesure_lieu.gd`, mêmes lieux / `--heure` / `--pose`) : masque tour à tour chaque groupe de
  GeometryInstance3D (enfant du monde + script le plus proche) et chiffre ses appels et primitives, visibles et d'ombre ; détail par
  matière des plus gros groupes (`--fin=n`) ; `--lister=<motif>` : chaque GI (surfaces, triangles, ombre, portée, dans le champ, distance).
- `outils/planche_occlusion.gd` : 8 poses (place, haute rue, devant h1, halle x2, h1, h4, ferme A), image + appels avec puis sans
  occlusion dans la MÊME image figée (A/B exact, planches `rendus/opti_2026-11-20/appels_dessin/planche_occ_*.png`).

## Postes mesurés (avant, f0c1b14b)
Place, 21 h, pose 35,30,221,-8 : **629 appels visibles + 386 d'ombres**, 870 k + 887 k primitives, 3 405 GI dans l'arbre.

| Groupe | appels visibles + ombres | remarque |
|---|---|---|
| bâti du village (village.gd) | 146 + 152 | déjà fondu par (bâtiment, matière) ; ~18 maillages par maison |
| gardes (garde_village.gd) | 205 + 66 | 40 à 48 GI par garde dont ~28 pièces de la torche |
| villageois | 112 + 93 | ~8-9 GI par PNJ (hors domaine : persos_anim) |
| mobilier du village | 47 + 40 | 6 bannières × 5 maillages, étals (MultiMesh par denrée) |
| mains du joueur | 37 + 1 | dont ~28 pièces de la torche |
| eau / rues | 21+7 / 19+6 | |

Halle (intérieur), 21 h : 324 + 118 appels, 479 k primitives visibles — dont **le DEHORS derrière les murs** : végétation (MultiMesh du
monde) 94 + 43, autres bâtiments 103 + 31, entrée de la grotte 18, feu de camp 14, compositions 23.
Crypte (z −25) : 168 appels, 108 k prim. (déjà bon marché). Grotte (milieu de la plus longue route) : 289 appels, 132 k prim.

## Fait
| Commit | Optimisation | Gain mesuré | Interrupteur |
|---|---|---|---|
| e65cb7e0 | Torche : ~28 pièces fixes fondues en 1 maillage (1 surface par matière) | place 21 h : 619 → 537 appels visibles (−82), prim. inchangées ; gardes 219 → 165, mains 38 → 11 | `--sans-opti-torche` |
| f7c8129e | Occlusion culling des 16 bâtiments enterables (murs au milieu de l'épaisseur, porte + tous les vitrages découpés) | halle vers la porte 707 → 471 appels, 1 081 k → 781 k prim. ; h4 303 → 177 ; h1 234 → 171 ; halle table 313 → 239 ; devant h1 901 → 815 ; place 544 → 541 | `--sans-opti-occlusion` |

## Essais écartés
- Fusion des lots des pivots fixes du village par cellule de 16 m et par matière : 100 lots → 85, mais appels du village 146+152 →
  159+154 et +8 k primitives visibles (les maillages fusionnés échappent au tri hors champ). Non commité.
