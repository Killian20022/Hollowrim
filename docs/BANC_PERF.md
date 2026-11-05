# Banc de perf avec seuils (lot P2 de l'audit 2026-11-04)

But : qu'une régression comme celle du `discard` du terrain (×1,9 de GPU dehors, corrigée en 6a8b2348) ne passe plus jamais inaperçue.

## Les trois garde-fous

| Garde-fou | Fichier | Fenêtre | Machine-indépendant | Dans la suite |
|---|---|---|---|---|
| Aucun `discard` dans le shader commun hors `RELIEF_COUCHE`, aucun shader ne GAGNE de `discard` (liste versionnée) | `outils/test_shaders_sans_discard.gd` (+ `test_terrain_sans_discard.gd`) | non | oui | `bash outils/tous_les_tests.sh` |
| Appels de dessin + primitives par lieu, tolérance serrée | `outils/banc_perf.sh` + `outils/banc_perf.gd` | oui (hors écran) | oui | `AVEC_BANC=1 bash outils/tous_les_tests.sh banc_perf` |
| GPU médian et p95 par lieu | idem | oui | non (iGPU) | idem |

## Mesure
`outils/banc_perf.sh` lance `audit_mesure_lieu.gd` (via `/tmp/godot_slot.sh`, fenêtre hors écran, vsync coupé) pour 6 lieux x jour (12 h) / nuit (21 h) x 3 répétitions entrelacées (36 lancements, ~60-110 min selon la file des créneaux Godot (godot_slot) ; mesuré 36 lancements en 75 min) :
`temoin` (feu de camp `--pose=2.5,8.5,16,4`), `place` (`35,30,221,-8`), `foret` (point le plus dense en arbres), `grotte`, `crypte`, `combat` (6 ennemis + sorts 1-2-3).
10 s de stabilisation puis `BANC_DUREE` (12) s de mesure. `banc_perf.gd` (headless) prend la MÉDIANE des répétitions et écrit `captures/perf/banc_<date>.json` (gpu_med, gpu_p95, appels, prims, dispersion entre répétitions, nombre maximal d'AUTRES Godot actifs avant/pendant/après chaque lancement).

## Seuils (constantes en tête de `banc_perf.gd`)
- Appels et primitives (toujours jugés) : avertissement > ±4 %, ÉCHEC > ±8 %. `foret` : 6 / 12 %. `combat` : 15 / 30 % (contenu variable).
- GPU : avertissement > +10 %, ÉCHEC > +25 % (gpu_med ou gpu_p95).
- Machine chargée (au moins un autre Godot actif pendant une mesure) ou répétitions divergentes de plus de 20 % : le verdict GPU devient « NON CONCLUANT » (jamais un faux échec) ; appels/primitives restent jugés.
- Code de sortie de `banc_perf.gd` = nombre d'ÉCHECS ; `banc_perf.sh` ne juge rien.

## Lancer
```
bash outils/tous_les_tests.sh                       # inclut test_shaders_sans_discard (sans fenêtre)
AVEC_BANC=1 bash outils/tous_les_tests.sh banc_perf # le banc complet (~60-110 min selon la file des créneaux Godot (godot_slot) ; mesuré 36 lancements en 75 min)
# ou à la main :
bash outils/banc_perf.sh captures/perf/banc_logs
godot --headless --path . --script res://outils/banc_perf.gd -- --logs=<dossier Windows des journaux>
```
Variables de `banc_perf.sh` : `BANC_REPS`, `BANC_DUREE`, `BANC_LIEUX`, `BANC_HEURES`, `GODOT`. Un seul lieu : `BANC_LIEUX=temoin BANC_HEURES=21 BANC_REPS=1` (les autres cases sont alors « mesure absente »).

## Régénérer la référence (`outils/banc_perf_reference.json`)
À faire quand un changement VOULU modifie le coût (nouveau contenu, optimisation) ou pour rétablir le GPU au calme, et à dire dans le commit :
1. Fermer les autres Godot (le JSON de sortie doit indiquer `autres_godot_max: 0`).
2. `bash outils/banc_perf.sh captures/perf/banc_logs`
3. `godot --headless --path . --script res://outils/banc_perf.gd -- --logs=<dossier> --ecrire-reference` (option `--annotation="…"`). La clé `discards` est conservée.
4. Liste des `discard` autorisés : `godot --headless --path . --script res://outils/test_shaders_sans_discard.gd -- --maj` (après avoir vérifié que le nouveau `discard` n'est pas sur une surface plein écran / terrain).
5. Relire le diff du JSON, commiter.

## Limites connues
- La référence GPU initiale a été prise sur machine chargée (voir `annotation_gpu`) : les seuils GPU ne valent qu'une fois rétablie au calme ; en attendant, un dépassement sera « non concluant » tant qu'un autre Godot tourne.
- `combat` a un contenu variable (placement et sorts) : tolérance large.

## Référence initiale (2026-11-05, médiane de 3, 12 s de mesure)
GPU indicatif (machine partagée, dispersion jusqu'à 26 % entre répétitions) ; appels/primitives exacts.

| Lieu | gpu_med jour / nuit (ms) | gpu_p95 jour / nuit | appels jour / nuit | primitives jour / nuit |
|---|---|---|---|---|
| témoin (feu) | 9,65 / 9,50 | 11,70 / 11,34 | 755 / 512 | 815 993 / 551 524 |
| place | 10,30 / 13,11 | 11,97 / 15,56 | 601 / 766 | 1 083 444 / 1 216 048 |
| forêt | 6,33 / 6,24 | 6,67 / 6,76 | 261 / 193 | 282 394 / 249 908 |
| grotte | 3,33 / 3,33 | 3,38 / 3,38 | 338 / 338 | 105 353 / 105 353 |
| crypte | 2,89 / 2,88 | 2,95 / 2,95 | 245 / 246 | 74 285 / 74 403 |
| combat | 5,47 / 5,30 | 6,09 / 6,30 | 436 / 401 | 272 165 / 230 783 |

Vérifié : la même mesure rejugée 2× passe (0 échec) ; une référence falsifiée (primitives -17 %, GPU /1,4) donne 3 ÉCHECS et un « non concluant » là où la dispersion dépasse 20 %.
Attention : le bruit GPU (jusqu'à 26 %) est de l'ordre du seuil d'échec (+25 %) : sur machine partagée, seules les cases à faible dispersion (grotte, crypte) jugent vraiment le GPU ; rétablir la référence au calme.
