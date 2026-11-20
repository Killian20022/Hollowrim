# Opti 2026-11-20 — domaine `cpu_scripts` (branche opti/cpu_scripts)

Temps CPU des scripts : `_process` / `_physics_process`, PNJ / Vie / IA, HUD, réseau en solo, minuteries au lieu du par-image.
Machine partagée (2 à 6 autres agents, 2 Godot max) : les chiffres absolus en ms sont bruités ; les comparaisons retenues sont
soit faites DANS LE MÊME LANCEMENT (`--bascule`), soit par groupe de scripts (sonde par groupe, indépendante de la charge GPU).

## Outils ajoutés / étendus

- `outils/mesure_cpu.sh <dossier> "<lieux>" "<heures>" <reps> "<variante>"…` : audit_mesure_lieu en série, variantes entrelacées, résumé.
- `outils/audit_mesure_lieu.gd` :
  - `--stab=N` (stabilisation, défaut 10 s) ; profil par groupes : coût physique **par pas** (les images lentes rattrapent plusieurs pas) ;
  - nœuds de priorité 0 (créés après la mise en place du profil, comptés dans le groupe #1) recensés à la fin ; scripts sans chemin nommés ;
  - `LIEU vie.tick` : durée de chaque tick de Vie (médiane, p95, max) ;
  - `--tranches` : image découpée en **A** (process_frame → frame_pre_draw : `_process`, animations, appels différés, `_draw` des Control),
    **B** (frame_pre_draw → frame_post_draw : rendu sur le fil principal, attente GPU comprise), **C** (reste : pas de physique, entrées, attente) ;
  - `--bascule=a,b,…` : dans UN lancement, segments de 3 s en boucle (normal, puis un segment par bascule), médianes par segment.
    Bascules : `anim` (AnimationMixer.active), `modif` (SkeletonModifier3D), `squelettes` (les deux), `pnj` (villageois, gardes, bêtes gelés),
    `pnj_ia` (leur `_physics_process` seul), `particules`, `hud`, `sans_opti` / `sans_etale` (interrupteurs de cette branche coupés à chaud).
- `outils/banc_micro_cpu.gd` : µs par appel de petites fonctions (accès réseau en solo, etc.).
- `outils/comparer_png.gd` : écart pixel à pixel de deux captures (zones) + planche côte à côte.

**Piège de lecture** : le moniteur `TIME_PROCESS` n'est pas « le process des nœuds » : `Main::iteration` y compte aussi le vidage des
appels différés (les `_draw`) ET `RenderingServer::draw` (rendu CPU + attente GPU). D'où « 24 ms de process dont 4 de scripts ».

## Postes mesurés (état f0c1b14b)

### Diagnostic par bascules (feu de camp, `--lieu=temoin --heure=12`, un seul lancement, 2 autres Godot actifs, GPU médian 10,3 ms)

| segment (3 s, en boucle) | dt méd. | A process+anim+UI | B rendu | C physique+attente |
|---|---|---|---|---|
| normal | 19,75 | 9,90 | 7,03 | 2,67 |
| `anim` (AnimationMixer.active=false) | 20,24 | 10,34 | 7,22 | 2,80 |
| `modif` (SkeletonModifier3D coupés) | 16,61 | 7,80 | 5,81 | 3,06 |
| `squelettes` (les deux) | 15,67 | 6,80 | 6,16 | 2,85 |
| `pnj` (villageois, gardes, bêtes gelés) | **12,33** | 5,30 | 5,01 | 1,61 |
| `pnj_ia` (leur `_physics_process` seul) | 18,06 | 10,16 | 6,97 | 1,30 |
| `hud` (CanvasLayer cachés) | 22,09 | 10,51 | 7,69 | 3,28 |

Lecture : **les PNJ coûtent ~7,4 ms par image** au feu de camp. ~4 ms viennent des squelettes (surtout les MODIFICATEURS : IK des pieds,
suivi de tête, orientation — l'évaluation des clips seule ne coûte presque rien), ~2 ms du côté rendu (mise à jour des 88 squelettes /
5 773 os), ~1,5 ms de leur IA physique. Le premier est le domaine `persos_anim` (relayé au coordinateur à 11 h 50) ; l'IA est ici.

### Profil par groupes de scripts (place, 21 h, `--profil=groupes`, référence f0c1b14b, machine chargée)

| poste | coût | remarque |
|---|---|---|
| `garde_village.gd` (14) `_physics_process` | 1,33-1,49 ms/pas | dont move_and_slide 97 µs/appel |
| `villageois.gd` (18) `_physics_process` | 1,10-1,36 ms/pas | dont move_and_slide 74 µs/appel |
| `joueur.gd` `_physics_process` | 0,63-0,66 ms/pas | dont move_and_slide **187 µs/appel** (collisions du village : domaine physique) |
| `_draw` de `HudCombat` | 0,96 ms/image | invisible aux sondes de process (vidage des appels différés) |
| `_draw` de `Hud` | 0,82 ms/image | boussole 0,39 (dont ~80 draw_rect fixes), aide de début de partie 0,35 |
| AnimationPlayer/Tree (87 mixers) | 1,4-1,75 ms/image | domaine `persos_anim` |
| groupe racine (AnimLod, autoloads) | 1,0-1,5 ms/image | surtout AnimLod (advance des PNJ hors champ) : `persos_anim` |
| `mains.gd` | 0,65-0,88 ms/image | mains en vue subjective (pose d'arme, passifs, magie) : non touché (combat validé) |
| `etal_marchand.gd` | 0,46 ms/image moyen | = tri du stock toutes les 3 s, plusieurs ms sur une image |
| `vie.gd` | 0,38 ms/image moyen | tick à 2 Hz : médiane ~0,5-0,8 ms, max 3-4 ms (avant filtre) |
| `corps_joueur.gd` | 0,30-0,40 ms/image | corps du joueur (ombre, 3e personne) : `persos_anim` |
| `impact_corps.gd` | 0,23-0,52 ms/image | « préparation » (lecture des maillages pour les sorts) 2,6 ms/image les 4 premières s puis ~0,1 |
| `musique.gd` | 0,15-0,19 ms/image | balayage du groupe « ennemis » (~100) à chaque image |
| `hud_combat.gd` (process) | 0,17-0,24 ms/image | lecture de l'état une image sur deux |
| `cassable.gd` (64-104 nœuds) | 0,06-0,11 ms/image | un `_process` par urne pour sonder « pillé » toutes les 0,75 s |
| mécanismes de crypte (5, classes internes de piege.gd) | 0,12 ms/pas | tournent même quand le joueur est au village (piste) |
