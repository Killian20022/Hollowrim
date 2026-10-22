# Mesure de performance après fusion A+B (integration/AB, 57471c9)

Outil : `outils/audit_perf.gd --nouvelle --cible=crypte|grotte --vivant --disable-vsync` (fenêtre, parcours complets, ennemis actifs, Jolt).
2 passes par lieu, le 2026-10-22 vers 23 h. Journaux : /tmp/perf_{crypte,grotte}_{1,2}.log, CSV : captures/perf_*.csv (non suivis).
Conditions : aucun autre test lancé par moi, mais l'éditeur/jeu de l'utilisateur (PID 6872, `--path nordique`, inactif) et un
test_crypte pendu de nordique_fix_ennemis (PID 28764, inactif, ~77 s CPU en 1 h 40) étaient présents ; non tués.

## Résumé par lieu

| Lieu | Passe | Images | Moyenne | > 16,7 ms | > 33 ms | Pire image |
|---|---|---|---|---|---|---|
| Crypte | 1 | 12 171 | 7,02 ms (142 i/s) | 1,5 % | 11 | 80,7 ms (entrée) |
| Crypte | 2 | 11 432 | 7,47 ms (134 i/s) | 1,8 % | 13 | 87,0 ms (étage bas) |
| Grotte | 1 | 4 189 | 8,80 ms (114 i/s) | 6,1 % | 23 | 174,8 ms (entrée) |
| Grotte | 2 | 4 116 | 8,97 ms (112 i/s) | 6,6 % | 24 | 184,9 ms (entrée) |

## Temps de chargement
- Instanciation du monde : 8,1 à 8,5 s (4 passes).
- Crypte : donjon prêt (fil + pose en tranches) 9,6 à 10,4 s après l'instanciation ; entrée `_basculer` 15,8 / 22,4 ms.
- Grotte : `obtenir` (construction si pas prête) 6,3 à 6,5 s, bloquant ; c'est la cause des images de 175-185 ms du tronçon « entrée ».

## Détail par tronçon (moyenne ms ; % > 16,7 ; nb > 33), passe 1 / passe 2
Crypte : entrée 4,68 ; 0,6 % ; 1 / 5,35 ; 1,1 % ; 1 -- colonne 6,58 ; 1,2 % ; 0 / 6,83 ; 1,3 % ; 0 -- arène 6,40 ; 0,6 % ; 0 / 6,91 ; 0,8 % ; 0
-- tombeau 5,79 ; 0,6 % ; 0 / 6,13 ; 0,7 % ; 0 -- aile ouest 8,47 ; 1,4 % ; 0 / 8,53 ; 1,2 % ; 0 -- aile est 8,41 ; 1,5 % ; 1 / 9,27 ; 2,2 % ; 1
-- étage bas 6,85 ; 3,1 % ; 8 / 7,47 ; 3,8 % ; 11 -- combat arène 6,59 ; 0,9 % ; 0 / 6,99 ; 1,1 % ; 0 -- quartiers 8,61 ; 1,4 % ; 1 / 8,85 ; 1,4 % ; 0.
Grotte : entrée 23,05 ; 46,3 % ; 10 / 25,48 ; 65,6 % ; 9 -- T1 10,98 ; 23,9 % ; 2 / 10,65 ; 24,3 % ; 2 -- T2 12,21 ; 26,6 % ; 4 / 11,75 ; 24,9 % ; 0
-- A 8,60 ; 3,8 % ; 4 / 7,47 ; 3,5 % ; 6 -- B 8,33 ; 1,3 % ; 3 / 9,29 ; 1,5 % ; 3 -- C 7,16 ; 0,9 % ; 0 / 8,32 ; 0,8 % ; 4 -- H 6,95 ; 0,5 % ; 0 / 8,45 ; 0,6 % ; 0.

## Lecture
- Crypte : fluide (moyenne ~7 ms, ~98 % des images sous 16,7 ms). Points durs : « étage bas » (3-4 %, 8-11 images > 33 ms, pire 71-87 ms) --
  coïncide avec la construction de la grotte (`kit grotte`, `Ennemis : 17 modèles préparés`) déclenchée pendant ce parcours ; à vérifier en isolant.
- Grotte : le gros des mauvaises images vient du début (entrée + premières branches T1/T2 : 175-185 ms de blocage à la construction, puis 24-26 % > 16,7 ms
  pendant la montée en charge) ; ensuite 0,5 à 4 %. 24 images > 33 ms au total, dont ~10 à l'entrée.
- Variance passe 1 / passe 2 faible (< 7 % sur la moyenne) ; la présence des deux Godot inactifs ci-dessus n'a pas d'effet visible.
