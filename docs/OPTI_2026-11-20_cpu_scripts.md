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

## Gains en images par seconde (médiane, même lancement, interrupteurs coupés à chaud, machine partagée)

| lieu | sans mes optis | avec | gain | p95 sans → avec |
|---|---|---|---|---|
| feu de camp, 12 h | 16,88 ms = 59,2 i/s | 15,84 ms = **63,1 i/s** | +3,9 i/s (−1,0 ms) | 28,6 → 21,8 ms |
| place du village, 12 h | 34,87 ms = 28,7 i/s | 30,71 ms = **32,6 i/s** | +3,9 i/s (−4,2 ms) | 60,3 → 40,2 ms |
| combat (crypte, 6 ennemis + sorts), 21 h | 10,93 ms = 91,5 i/s | 10,33 ms = **96,8 i/s** | +5,3 i/s (−0,6 ms) | 17,3 → 17,8 ms (bruit) |

Non compris dans ces chiffres : cassables et bandeau de boussole (non basculables à chaud), pièges de crypte, et le cache du poids du sac
dans l'EXE (le sac de PERIODE_TEST_EQUIPEMENT n'existe pas en mode outil). Max refera le banc au calme.

## Ce qui est fait (une optimisation = un commit, interrupteur `--sans-opti-…` pour l'avant)

| optimisation | interrupteur | exact ? | mesure |
|---|---|---|---|
| PNJ (villageois, gardes) au-delà de 22 m (`lod` 1) : IA + move_and_slide 1 pas de physique sur 3, temps cumulé, vitesse mise à l'échelle le temps du move_and_slide ; aussi en lod 0 quand ils sont IMMOBILES (poste / pause / halte, sans rotation au pas précédent) à plus de 8 m du joueur local. Jamais en alerte, conversation, causerie, course. | `--sans-opti-pnj-etale` | trajet identique ; mise à jour de position à 20 Hz à > 22 m (≤ 6,5 cm, sous le pixel) | place 21 h : gardes 1,33 → 0,73 ms/pas, villageois 1,10 → 0,87 (avant l'extension « immobiles ») ; feu de camp, même lancement : −0,66 ms/image |
| `_regard_tete` : cible du regard cherchée seulement de près (ordre des conditions) | — | exact | — |
| Étals : tri du stock refait seulement si `Marchand.stock()` change (`hash`) | `--sans-opti-etal` | exact | 0,46 ms/image moyen (pic de plusieurs ms toutes les 3 s) → hors du classement |
| `Vie.tick` : menaces pré-filtrées par la boîte englobante des civils + 25 m pour `_annoncer` / `_danger_proche` | `--sans-opti-vie-menaces` | exact | vie.gd 0,38 → 0,07-0,09 ms/image ; tick médian 0,43-0,77 ms, max 2,8-4,1 ms |
| HudCombat : `queue_redraw` seulement si l'état affiché change (signature ; opacités à 1/512 près ; clignotements = chaque image ; au moins toutes les 0,25 s) | `--sans-opti-hud` | même image (planche) | `_draw` 0,96 → 0,16 ms/image |
| Hud : bandeau fixe de la boussole dans un nœud `FondBoussole` dessiné derrière, redessiné si taille / style changent | `--sans-opti-hud` | même image (planche) | ~80 draw_rect/textures de moins par image (boussole 0,39 ms) |
| Musique : balayage des ennemis en combat 10 fois/s | `--sans-opti-musique` | ≤ 0,1 s de retard sous un fondu | 0,15-0,19 → 0,07 ms/image |
| `Conteneur.poids()` et `EquipementCorps.effets_totaux()` gardés tant que le contenu ne change pas (`hash`) | `--sans-opti-cache-stats` | exact | le joueur relisait tout le sac à chaque pas (surcharge) et 3 fois les effets ; dans l'EXE (PERIODE_TEST_EQUIPEMENT : tout l'équipement dans le sac) c'est le plus gros gain |
| Cassables intacts sans `_process` : un seul balayage statique de l'état « pillé » toutes les 0,75 s | `--sans-opti-cassables` | mêmes appels, même période | 64-104 `_process` en moins (0,06-0,11 ms/image) |
| Pièges de crypte (dalles, souffles) endormis en SOLO quand la crypte est cachée ; souffle remis au calme (son coupé) en s'endormant | `--sans-opti-pieges` | rien à faire dehors en solo ; jamais en coop | 0,12 ms/pas au village (profil) |
| Nœud `Reseau` gardé dans `ReseauMondeVivant._r`, `PauseCoop.R`, `CombatCoop.R`, `ReseauLieux.reseau` | — | même nœud (recherché à nouveau s'il quitte l'arbre) | micro-banc : `en_ligne()` 1,3 µs, appelé 3-4 fois par pas et par PNJ |

### A/B dans le même lancement (feu de camp, `--lieu=temoin --heure=12 --bascule=sans_opti,sans_etale`, 60 s, 2 autres Godot)

| segment | dt méd. | dt p95 | A | B | C | physique (moniteur) |
|---|---|---|---|---|---|---|
| tout optimisé | **15,84** | **21,82** | 7,87 | 5,57 | 2,02 | 3,51 |
| `sans_opti` (tous mes interrupteurs à chaud, sauf cassables et boussole) | 16,88 | 28,64 | 7,87 | 5,33 | 3,25 | 4,48 |
| `sans_etale` | 16,50 | 21,67 | 7,32 | 5,53 | 3,17 | 4,30 |

### A/B dans le même lancement (place, `--lieu=place --heure=12 --bascule=sans_opti,sans_etale`, 60 s, 2 autres Godot)

| segment | dt méd. | dt p95 | A | B | C | physique (moniteur) |
|---|---|---|---|---|---|---|
| tout optimisé | **30,71** | **40,24** | 13,07 | 11,10 | 5,89 | 4,64 |
| `sans_opti` | 34,87 | 60,33 | 14,18 | 11,79 | 8,71 | 5,45 |
| `sans_etale` | 32,42 | 44,67 | 12,97 | 11,30 | 7,78 | 5,65 |

Sur la place (machine chargée, image ~30 ms : 2 pas de physique par image), chaque ms gagnée par pas compte double : −4,2 ms en médiane,
−20 ms au p95. Le gain en C (physique + attente : 8,71 → 5,89) est celui de la spirale « image lente → plus de pas de physique ».

### A/B dans le même lancement (combat : crypte, 6 ennemis + sorts, `--lieu=combat --heure=21 --bascule=sans_opti`, 48 s)

| segment | dt méd. | dt p95 | A | B | C | physique (moniteur) |
|---|---|---|---|---|---|---|
| tout optimisé | **10,33** | 17,76 | 5,95 | 3,22 | 1,28 | 2,56 |
| `sans_opti` | 10,93 | 17,30 | 6,51 | 3,22 | 1,30 | 2,34 |

Sous terre les PNJ du village sont gelés par le monde : le gain vient du HUD de combat (A −0,56 ms). Pas de régression.
Lancement entier : dt méd 10,62 / p95 17,37 / p99 23,11 ms, 10 images > 33 ms sur 4 226, GPU méd 5,3 ms.

## Planches (rendu identique)

`C:\Users\lopezk19\Jeux\rendus\opti_2026-11-20\cpu_scripts\` : `hud_avant.png` (`--sans-opti-hud`) / `hud_apres.png`, place, 12 h,
même pose ; `planche_boussole_x3.png` (boussole agrandie ×3, avant au-dessus) et `planche_barre_bas_x2.png` (raccourcis ×2) : identiques
à l'œil ; les écarts de pixels mesurés (outil Python pur `cmp_png.py`) sont le ciel, la neige et le pavé éclairé DERRIÈRE le HUD
(scène animée entre deux lancements), pas le HUD.
Les autres optimisations ne touchent pas l'image (calculs exacts, ou position de PNJ immobiles / lointains mise à jour à 20 Hz sous le pixel).

## Ce qui reste / pistes

Dans mon domaine (petits postes, < 0,1 ms chacun) : `objets_vivants._viser` (rayon caméra par image, ~0,05 ms), `hud_combat._lire_etat`
(raccourcis reconstruits une image sur deux, ~0,05 ms), `Hud._draw` hors bandeau (~0,2 ms en régime : graduations, lettres, marqueurs,
objectif ; un redessin sur changement demanderait de suivre le lacet, la position, les marqueurs, les chiffres de dégâts…), `faune._tour`
(2 Hz), `interieur.gd` (18 nœuds). `mains.gd` (0,65-0,88 ms) : coût réparti dans l'évaluation des poses de l'arme et des passifs — non
touché (combat validé, risque sur la sensation).

Hors domaine (relayé au coordinateur) :
- **persos_anim** : PNJ gelés = −7,4 ms/image au feu de camp ; modificateurs de squelette (PiedsAuSol, SuiviTete, orientation) −3,1 ms,
  squelettes complets −4,1 ms, ~2 ms dans la tranche rendu (mise à jour des os). AnimLod ne coupe pas les modificateurs hors champ.
  AnimationPlayer/Tree 1,4-1,75 ms/image (87 mixers) ; groupe racine (AnimLod) 1,0-1,5 ms ; `corps_joueur.gd` 0,3-0,4 ms.
- **physique_reseau_exe** : move_and_slide du joueur 187 µs/appel au village (gardes 97, villageois 74) ; rendu sur le fil principal
  (tranche B 3-11 ms en série avec le process : `rendering/driver/threads/thread_model` non réglé) ; spirale pas de physique / image lente
  (2 pas par image sur la place chargée) ; tests réseau à deux processus non lancés (ils exigent GODOT_MAX ≥ 2 simultanés sur la machine).
- **saccades** : premier `EtalMarchand.actualiser()` (modèles chargés à la volée : une image de 11 s avec un cache de shaders neuf et une
  machine saturée) ; `impact_corps` « préparation » 2,6 ms/image les premières secondes (lecture des maillages pour les sorts).
- **effets_lumieres** : `flamme_torche.gd` 20-40 µs par torche et par image (ressort + vacillement) ; vacillement des lumières des
  intérieurs (`interieur.gd`) et de la crypte (`tertre.gd` d.vaciller) à chaque image.

## Tests lancés (`bash outils/tous_les_tests.sh <nom>`, Godot via godot_slot, sortie réelle)

Lot 1 (après PNJ, étals, Vie) : OK test_gardes_village, test_villageois, test_vie, test_marchands, test_marche_pnj, test_pnj_village.
Lot 2 (après HUD, musique, caches, cassables, réseau, étalement « immobiles ») : OK test_hud_combat, test_hud_l7, test_musique,
test_cassables, test_stockage, test_rpg_objets, test_objets_monde, test_potions, test_progression, test_sommeil, test_crime,
test_crime_sommeil, test_gardes_village, test_villageois. Lot 3 (pièges) : OK test_mecanismes.
Non lancés : tests réseau à deux processus (`test_combat_coop.sh`, `test_resilience.sh`, `test_tout_reseau.sh`) — ils demandent
GODOT_MAX ≥ 2 Godot SIMULTANÉS pour un seul test, interdit aujourd'hui ; les changements réseau de cette branche se limitent au cache
du nœud Reseau (même résultat) et aux pièges endormis seulement HORS LIGNE.
