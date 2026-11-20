# Optimisation persos_anim (2026-11-20)

Branche `opti/persos_anim` (depuis f0c1b14b). Machine partagée (2 à 6 autres Godot actifs pendant toutes les mesures) : les dt sont bruités,
les appels de dessin / primitives (audit_appels) sont exacts.

## Postes mesurés au départ
- Feu de camp 12 h (`_audit_cpu.gd` = audit_mesure_lieu de opti/cpu_scripts, `--tranches --bascule=pnj,modif`, base sans les optis) :
  normal 22,7 / 27,6 ms par image ; PNJ gelés 12,4 / 12,7 ms (-10 à -15 ms, IA + physique + squelettes) ; modificateurs coupés 21,0 / 17,4 ms.
- Constat moteur (vérifié en script, Godot 4.7) : un SkeletonModifier3D ACTIF tourne à chaque image même si l'AnimationPlayer est figé, et
  même à influence 0 (30 appels en 30 images). AnimLod ralentissait donc l'animation des PNJ hors champ mais pas leurs pieds au sol (2 rayons
  + ~70 remontées d'os en GDScript), leur tête ni leurs ressorts.
- Place nuit (audit_appels) : 618 appels visibles + 385 d'ombre. Un garde de ronde = 48 appels visibles, dont 26 pour sa torche (26 petites
  pièces ps1) ; 4 à 6 pièces du corps entièrement recouvertes par l'armure gardaient un triangle sans aire = 1 appel chacune ; chaque pièce
  projetait sa propre ombre (10 à 19 appels d'ombre par garde, 6 à 9 par villageois).

## Fait (un interrupteur par opti)
| Opti | Fichier | Interrupteur |
|---|---|---|
| Squelette des PNJ hors champ en mode MANUEL, avancé avec l'animation (1 image sur 4) : modificateurs payés 1 fois sur 4 | anim_lod.gd | `--sans-opti-squelettes` |
| Dans le champ : pieds/tête/ressorts effacés de 10 à 12 m (fondu linéaire), au-delà squelette gelé (plus aucun modificateur) ; jamais si d'autres modificateurs sont actifs (ragdoll, coupe, lance, arc, poignet) | anim_lod.gd | `--sans-opti-squelettes` |
| Pieds, orienteur, suivi de tête : sortie immédiate à influence 0 (gardes à l'épée non gelables) | pieds_au_sol.gd, villageois.gd (SuiviTete) | (idem) |
| PNJ lointains dans le champ animés 1 image sur 2 (> 25 m, ~13 px de haut) et 1 sur 3 (> 50 m) | anim_lod.gd | `--sans-opti-anim-distance` |
| Bêtes (faune) inscrites dans AnimLod (leur logique lit des minuteries, pas l'animation) | bete_quat.gd | `--sans-opti-anim-betes` |
| PiedsAuSol : poses de la chaîne bassin -> pieds calculées une fois par image (même calcul) | pieds_au_sol.gd | `--sans-opti-pieds` |
| Torche : 26 pièces fixes fusionnées en 5 (une par matière) — joueur et gardes | torche.gd | `--sans-opti-torche` |
| Pièces du corps entièrement recouvertes cachées tant qu'elles sont vides | rpg/armure_visible.gd | `--sans-opti-pieces-vides` |
| Une ombre par personnage : maillage « ombre seule » skinné réunissant les pièces opaques (une surface par faces × contour) ; défait à la mort | fusion_ombre.gd (+ hooks ragdoll, démembrement, décapitation) | `--sans-opti-ombre-fusion` |

## Gains mesurés
Appels de dessin, place nuit, pose 35,30,221,-8 (exacts) :
| | appels visibles | appels d'ombre | prims visibles | prims d'ombre |
|---|---|---|---|---|
| base f0c1b14b | 618 | 385 | 855 079 | 895 566 |
| + torche + pièces vides (7f2e6fd8) | 528 | 374 | 855 039 | 895 542 |
| + une ombre par perso (24e9cc06) | 534 | 299 | 880 374 (*) | 892 699 |
(*) +25 k primitives visibles non expliquées à l'heure du rapport (le maillage d'ombre est SHADOWS_ONLY ; probablement l'état des PNJ, à revérifier
par `audit_appels -- --sans-opti-ombre-fusion` dans le même état).

CPU, feu de camp 12 h, pose 2.5,8.5,16,4 (`_audit_cpu.gd --tranches --bascule=pnj,modif`, médianes par segment ; machine chargée) :
| | normal dt_med | A (process+anim) | PNJ gelés dt_med | coût restant des PNJ | dt_p99 | images > 33 ms | appels |
|---|---|---|---|---|---|---|---|
| avant (tous les --sans-opti-*), lancement 1 | 22,71 | 10,47 | 12,37 | 10,3 | 54,3 | 72 | 760 |
| avant, lancement 2 | 27,60 | 12,64 | 12,65 | 15,0 | 88,3 | 130 | 759 |
| après (toutes les optis) | 16,82 | 7,47 | 14,97 | 1,9 | 68,1 | 64 | 721 |
Soit ~44 -> ~59 i/s en médiane au feu de camp (bruit de la machine partagée : à rebancher au calme).

## Vérifications
- `outils/test_pieds_opti.gd` : OK (opti vs ancienne version côte à côte ; écarts ≤ 0,3 mm, le témoin --controle montre l'écart propre à la scène).
- `outils/test_pieces_vides.gd` : OK, 56 pièces vides cachées, 0 pièce avec de l'aire cachée.
- Planches (C:\Users\lopezk19\Jeux\rendus\opti_2026-11-20\persos_anim\) : garde de ronde à la torche face/profil/dos/loin (identiques hors
  suivi de tête vivant), garde à 13 m (cosmétiques coupés : rien de visible), ombres à midi (zoom : identiques).

## Reste / pistes
- Villageois : 6 à 9 pièces, une texture chacune : fusionner les appels visibles demande un atlas de textures (non fait : rendu à prouver).
- Gardes : l'épée a 4 maillages (2 partagent la matière fer) ; armures à 2-3 surfaces de matières différentes (inévitables sans atlas).
- `lod_bias = 64` sur les armures (ArmureVisible) : LOD de maillage coupés partout ; un lod_bias plus faible au-delà de 22 m allégerait
  ~10 k triangles par garde lointain (à vérifier en planche).
- Hors domaine : la physique des PNJ (move_and_slide, C de 4,5 à 1,5 ms quand ils sont gelés) et leur IA restent le plus gros poste des
  « PNJ gelés » (cpu_scripts / physique).
- La cadence réduite > 25 m n'a pas été filmée (vérifiée seulement par la taille à l'écran) : à couper avec `--sans-opti-anim-distance` si
  l'utilisateur voit une saccade.
