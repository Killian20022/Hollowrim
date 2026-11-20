# Opti 2026-11-20 — domaine « saccades » (images > 33 ms, pics)

Branche `opti/saccades` (worktree `nordique_opti_saccades`, base f0c1b14b). Aucun changement de rendu : tout ce qui suit déplace du
travail hors du fil principal ou l'étale sur plusieurs images ; rien n'est dessiné autrement (pas de planche nécessaire : aucune
optimisation visible).

## 1. Outils (nouveaux ou étendus)

- `outils/mesure_pics.gd` :
  - `--etale` : entrée du monde comme l'écran de chargement (arbre en pause, `Jeu.chargement_etale`, jusqu'à `pret`). Sans lui l'outil
    marchait pendant que donjon, ennemis et grotte se bâtissaient encore (pics qui n'existent pas en partie : faux coupables du 1er relevé) ;
  - « sauts » relatifs : une image > 33 ms ET > 2,2 × la médiane des 30 précédentes (machine partagée : quand toutes les images font
    30-90 ms, c'est la seule grandeur qui isole un vrai à-coup) ; `PICS … med= p99= sauts=` par tronçon ;
  - objets / nœuds créés pendant l'image, et la liste des nœuds ajoutés (classe < parent < grand-parent) sur chaque saut : c'est ce qui a
    désigné les objets vivants des intérieurs ;
  - cibles `village` (tour des 22 bâtiments enterables, entrée par la porte, `--passages=N`) et `combat` (crypte par le fondu, 6 gardiens,
    épée de feu, 1er sort de chaque raccourci, mises à mort).
- `outils/mesure_chargements_vol.gd` : 1er `load()` + instanciation, fichier par fichier, de ce que le jeu charge en pleine partie
  (musiques, bruitages, armes, armures portées) ; `--precharge=1` mesure le même `load()` après les demandes en fil (comme l'opti).
- `outils/mesure_sauvegarde.gd` : coût de l'autosauvegarde par phase, puis chemin du jeu synchrone / en fil en alternance
  (fichier de TEST de la copie seulement, jamais `user://sauvegarde.json`).

## 2. Postes mesurés (avant)

Machine chargée (6 agents, 2-3 Godot) : temps absolus gonflés ×2 à ×4 ; les grandeurs retenues sont les coûts propres d'appel
(chronométrés autour de l'appel), les objets/nœuds créés et les sauts relatifs.

| Poste | Quand en partie | Coût fil principal (avant) |
|---|---|---|
| Armure portée : `load()` du glb | clic « Porter » (menu figé) | 90-248 ms par pièce (62 pièces, 4,5 s cumulées) |
| Objets vivants d'un intérieur (`ObjetsVivants.peupler` en UNE tâche) | approche de chaque maison (pose de l'intérieur paresseux) | sauts 50-130 ms (méd. 23-75), +122 objets / +61 nœuds dans l'image |
| Musique : `load()` de la piste Ogg | entrée au village, début / fin de combat, crypte, grotte, forêt | 20-44 ms, à chaque changement (la piste quittée était libérée) |
| Autosauvegarde (écriture .tmp, relecture, renommage) | porte de maison (+1,5 s), crypte / grotte (+2,5 s), quête, 10 min | 15-25 ms (dont écriture 10-22) |
| Arme : `load()` du modèle | 1er équipement (raccourci 1-0) | 7-18 ms |
| Bruitages : `load()` au 1er son | 1er pas sur chaque sol, 1re porte, pièces, interface | 1-7 ms par sorte (98 fichiers, 470 ms cumulés) |
| Déchargement d'un intérieur (tout le contenu libéré dans une image) | en s'éloignant à 42 m | saut 54 ms (méd. 23), −62 objets |
| Pose des intérieurs sous budget de temps seul (add_child mesuré, pas le coût qui suit) | approche des maisons | 3 lits de 16-24 maillages, 36 maillages + 17 collisions par image : sauts 45-113 ms |
| Lits de Sommeil : tous les lits d'un intérieur dans le même balayage | idem | sauts 107-113 ms (+72 / +96 nœuds) |
| 1er équipement d'un modèle de lame : `SangLame.shader_de` fabrique et compile la variante « sang » du shader de lame | 1er équipement (raccourci) | Hrafn 199 ms, claymore 524 ms |
| Couche de neige en relief créée 1 s après le 1er effet au sol | 1re empreinte, 1er coup | image de 287-305 ms (A 224-233) |
| 1er sort tenu de chaque école (runes en orbite absentes de la vitrine) | 1er sort | 64 / 75-122 / 94 ms |

## 3. Ce qui est fait (commits)

| Commit | Opti | Interrupteur |
|---|---|---|
| 33458075 | Musiques gardées et lues en fil ; bruitages demandés en fil au chargement (`Sons.precharger`) | `--sans-opti-musique`, `--sans-opti-sons` |
| c9653d7e | Autosauvegarde : export + JSON sur le fil principal, écriture dans un fil (WorkerThreadPool), avis à la fin ; appel direct (tests) et invité coop synchrones ; sortie du monde attend la fin | `--sans-opti-sauvegarde` |
| 56446223 | Objets vivants d'un intérieur posés par lots de 4 sous le budget de pose (instances du MultiMesh montrées au fil des lots) | `--sans-opti-vivants` |
| 522e8d86 | Modèles des armes équipables demandés en fil à l'arrivée dans le monde et à chaque changement du sac | `--sans-opti-armes` |
| c08d9dd5 | Glb d'armure porté demandé en fil dès que la pièce est montrée dans le menu (fiche du Sac, liste « Changer ») | `--sans-opti-armures` |
| 407c1e0e | Déchargement d'un intérieur étalé (un enfant / 24 collisions par tâche) | `--sans-opti-decharge` |
| 0712a491 | Pose des intérieurs : plafond de 24 nœuds entrés dans l'arbre par image (signal node_added) en plus des 1,5 ms ; un MultiMesh d'objets vivants par tâche | `--sans-opti-pose` |
| 60337867 | Collisions d'un intérieur par paquets de 8 en partie (24 au chargement) | `--sans-opti-pose` |
| 5cbe4843 | Sommeil : un lit procédural posé par image (les 3 lits de la halle passaient dans la même) | `--sans-opti-lits` |
| dbb5d9ce | Couche de neige en relief (variante RELIEF_COUCHE du shader, 36 tuiles) créée au chargement | `--sans-opti-couche` |
| c84f4093 | Runes en orbite de chaque école dans la vitrine de préchauffage de la magie ; nœud des sons de magie au chargement | `--sans-opti-runes` |
| 9d75c03f | Variantes « sang sur la lame » des shaders de lame faites et compilées au chargement (PrechauffeCombat.caches) | `--sans-opti-sang-lame` |

Essai écarté : b53d96b4 (matières des armes au chargement) n'a rien gagné (131 / 135 ms : elles étaient déjà faites au chargement par
l'arme de départ) ; annulé par 59bbe66a.

## 4. Gains mesurés

Tous les A/B : même séance, lancements alternés avant (tous les interrupteurs `--sans-opti-*`) / après, `mesure_pics --etale`.

| Mesure | Avant | Après | Remarque |
|---|---|---|---|
| Village, tour des 22 bâtiments (sauts), lot 1 : vivants, sons, musique, sauvegarde, armes | 40 | 27 | pire image 677 → 120 ms ; méd. 28 / 27 ms (machine chargée) |
| Village, lot 2 : + plafond de pose, MultiMesh par tâche | 29 | 12 | méd. 27 / 26 ms |
| Autosauvegarde, appel sur le fil principal (3 essais alternés) | 18,2 / 25,2 / 20,4 ms | 4,1 / 4,8 / 3,4 ms | fichier écrit et valide après |
| Armure portée, `load()` au clic (62 pièces) | 2 600 ms cumulés, pire 127 | 30 ms cumulés, pire 0,8 | `mesure_chargements_vol --precharge=1` |
| Arme, `load()` du modèle (12) | 74 ms cumulés, pire 9,6 | 1,7 ms, pire 0,2 | |
| 1er `equiper()` : Hrafn / claymore / verre (`mesure_equiper`, même séance) | 199 / 524 / 25 ms | 11 / 19 / 18 ms | cause : SangLame.shader_de |
| Village, lot 3 : tout (+ lits un par image, collisions par 8) | 63 | 6 | pire 404 → 147 ms, >33 ms 1953 → 1222 ; méd. 31 / 25 ms |
| Combat, 1er sort 2 (runes) | 64,6 ms | 26,8 ms | abc2 |
| Couche de neige à la 1re empreinte | image de 287-305 ms | `creer()` 0,8 ms en partie | créée sous l'écran de chargement |
| Entrée dans la crypte (sous l'écran noir) | 282 / 325 ms | 179 / 207 ms | 6 gardiens posés d'un coup (outil téléporté : voir §5) |

Tests lancés (sans fenêtre, via godot_slot) : test_autosave OK (258 s), test_musique OK (133 s), test_sons_magie OK (31 s),
test_inventaire_mains OK (26 s), test_interieurs OK (747 s puis 1069 s avec la version finale), test_sommeil OK (235 s),
test_crime_sommeil OK (125 s), test_magie OK (173 s), test_effets_magie OK (30 s), test_epees_longues OK (999 s),
test_combat_epee OK (19 s), test_shaders_sans_discard OK (12 s). test_objets_vivants : ÉCHEC **identique sans l'opti**
(`--sans-opti-vivants` : « objet visé : Pain de seigle » et « lancé à 2,7 m/s », ECHECS : 1) → échec préexistant sur f0c1b14b.
Les préchargements en fil (sons, musique, armes, armures, couche, runes, variantes de sang) sont coupés en --headless (même règle
que Prechargement : fils de chargement + serveur de rendu factice) : les tests sans fenêtre ne passent que par l'ancien chemin.

## 5. Ce qui reste / pistes hors domaine

- **Entrée crypte / grotte** : 150-210 ms (crypte, 6 gardiens ajoutés d'un coup) et 140-170 ms (grotte, bandits préparés), PENDANT
  l'écran noir du fondu (invisible, mais le fondu marque l'arrêt). En partie, la marche jusqu'à la porte prépare déjà les modèles
  (`_preparer_gardiens`), l'outil téléporte : à étaler sur les images noires si l'on veut un fondu parfaitement fluide.
- **Morts** (persos_anim) : chaque mort crée son ragdoll (16-32 PhysicalBone3D) + gore : sauts de 40-75 ms au 1er coup fatal.
- **Crypte, couloir z = -4 à -8** (gpu_rendu / effets_lumieres) : GPU 35-70 ms soutenu, sur les deux passages, sans création de nœuds.
- **Village, sortie de l'écran de chargement** (appels_dessin / gpu_rendu) : quelques images GPU-bound (B 70-170 ms) en regardant le
  village depuis le moulin à vent (95, 13, -15).
- **Lame (combat)** : `trace_lame._volume_cible` construit parfois une enveloppe convexe dégénérée (Jolt « Hull building failed »,
  `jolt_shape` nul) : rien ne casse, mais c'est un balayage raté.
- **Chargement** : `EpeesLongues.materiaux()` (textures des armes peintes par code) coûte plusieurs secondes du chargement (4,8 s
  mesurées machine chargée) : à mettre en cache disque ou en fil.
- Les mesures `--paisible` mettent la faune en mode « complet » (tous les territoires d'un coup, 13 bêtes dans une image) : ne pas
  confondre avec la partie (un groupe toutes les 1,5 s).
- Machine partagée toute la journée (médiane des images 10-30 ms selon l'heure) : à refaire au calme (Max).
