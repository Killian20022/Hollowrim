# Passe d'optimisation 2026-11-20 — domaine physique_reseau_exe

Branche `opti/physique_reseau_exe` (depuis f0c1b14b). Machine partagée (2 à 3 Godot d'autres agents), secteur branché.

## 1. Banc FPS dans le jeu exporté (demande de Max)

- `scripts/banc_fps.gd` (autoload `BancFps`, nouveau fichier ; une ligne ajoutée à `[autoload]` de project.godot). Sans
  `--banc-fps`, il se retire à son premier `_ready` (coût nul en jeu).
- Lancement : `Hollowrim.exe --disable-vsync -- --nouvelle [--paisible] [--pose=…] --banc-fps=<lieu>,<heure>,<durée> --banc-sortie=<json>`
  (l'éditeur : `Godot_console.exe --path <projet> --disable-vsync -- mêmes arguments`). Le jeu suit son vrai chemin (écran titre →
  monde), le joueur est placé comme dans `outils/audit_mesure_lieu.gd` (temoin, place, foret, halle, ferme, grotte, crypte, combat),
  vsync coupée, 10 s de stabilisation, puis mesure. JSON : FPS moyen, FPS 1 % et 0,1 % bas (1000 / moyenne des images les plus
  lentes), dt méd/p95/p99/max, images > 16,7 et > 33 ms, CPU des scripts (sonde process + physics, et nombre de pas physiques),
  TIME_PROCESS / TIME_PHYSICS_PROCESS, rendu CPU/GPU du viewport, appels, primitives, objets, pipelines compilés pendant la mesure,
  mémoire, temps de chargement, exe/éditeur, pilote, carte.
- `outils/banc_fps_exe.sh <exe|editeur> [dossier]` : lieux x 12 h / 21 h x BANC_REPS (3) entrelacés via /tmp/godot_slot.sh (hors
  écran) ; BANC_DUREE (20 s), BANC_LIEUX, BANC_HEURES, BANC_SORTS (**eleve** par défaut = le réglage du joueur ; les outils
  mesurent en « retro » à cause de Jeu.mode_outil), BANC_EXTRA (arguments du jeu), BANC_MOTEUR (arguments moteur, ex.
  `--render-thread separate`), BANC_REP_DEBUT. Chaque `.charge` = nombre max d'autres Godot/Hollowrim pendant le lancement.
- `outils/compare_fps.sh <avant> [après]` : tableau markdown (médiane des répétitions).
- Exe « avant » de référence (f0c1b14b + banc seul, b88c879e) :
  `C:\Users\lopezk19\Jeux\rendus\opti_2026-11-20\physique_reseau_exe\exe_avant_banc\Hollowrim_avant_banc_b88c879e.exe`.

## 2. Mesures

### Exe contre éditeur (témoin, 12 h, 8 s, même commit, lancements successifs non entrelacés)
| | FPS moy | 1 % bas | dt méd | dt p99 | > 33 ms | GPU méd | TIME_PROCESS | physique/image | scripts process | scripts physics/pas |
|---|---|---|---|---|---|---|---|---|---|---|
| exe | 35,5 | 18,1 | 28,8 | 47,7 | 15 | 11,4 | 24,4 | 5,4 | 4,2 | 3,4 |
| éditeur | 26,3 | 14,6 | 36,6 | 54,8 | 190 | 12,8 | 30,7 | 7,4 | 5,1 | 4,1 |

L'exe est ~35 % plus rapide que l'éditeur (GDScript sans débogage) : pas de pénalité propre à l'exe. Le jeu est limité par le fil
principal (dt 28,8 ms pour un GPU à 11,4 ms) ; 1,7 pas physiques par image (60 Hz de physique à 35 i/s).

### Physique (outils/recensement_physique.gd, monde réel, headless)
- 257 StaticBody, 85 CharacterBody, 281 RigidBody (tous endormis ou hors de l'espace : réserves d'éclats d'os désactivées),
  aucune aire surveillante. Formes : 2 436 cylindres, 1 066 boîtes, 185 convexes, 84 capsules, 86 trimesh (177 951 faces,
  2 258 max : terrain 16 x 1 800, grotte, tertre).
- _physics_process actifs : 47 bêtes, 18 villageois, 14 gardes, 5 draugrs, joueur…
- Jolt lui-même est quasi gratuit (TIME_PHYSICS_PROCESS ≈ somme des scripts _physics_process).
- move_and_slide du joueur sur la place : 123-140 µs ; SANS le terrain : 22-24 µs ; terrain en HeightMapShape3D : 117-144 µs
  (pas mieux : ce n'est pas le maillage) ; Jolt `motion_queries/use_enhanced_internal_edge_removal=false` : 123 µs (sans effet) ;
  `motion_queries/recovery_iterations` 4 (défaut) → 2 : 114 µs ; → 1 : 68 µs. Le coût est la récupération (dépénétration) au
  contact du sol, refaite à chaque itération. Non appliqué : changer les itérations change la façon dont les corps sont repoussés
  (gameplay à garder identique) ; piste à valider par une comparaison de trajectoires.

### Réseau (hôte)
- 131 entités enregistrées dans le Replicateur même en solo (PNJ, gardes, bêtes, ennemis) ; un tick d'envoi (15 Hz) les encodait
  toutes : 2,99 ms en moyenne (max 3,7) dans le monde réel.

## 3. Fait (commits)
| SHA | Quoi | Mesure |
|---|---|---|
| b88c879e, b52ca9b6, 013952f8, fb74c9ef | banc FPS dans le jeu + scripts de banc/comparaison | — |
| cc3374bc | **Bug de l'exe** : 52 glb d'armures (cuir : armure, bottes, capuche, gants ; et la plupart des armures au sol) ne se chargeaient pas dans l'exe (textures exclues de l'export puis de nouveau référencées par la régénération v3 du 13/11) | verif_exclusions_export : 59 fautes → OK |
| 630c923f | Replicateur (hôte) : n'encode que les entités qu'un pair recevra à ce tick ; envois identiques | 2,99 → 2,03 ms par tick d'envoi, 131 → 59 entités encodées (1 pair au joueur local) ; interrupteur `--sans-opti-replication` |

## 4. Rendu en fil séparé (`--render-thread separate`)
Exe « avant », témoin 12 h, 15 s, UNE répétition par mode (non entrelacé, machine chargée) :

| mode | FPS moy | 1 % bas | dt p99 | > 33 ms | GPU méd | autres Godot |
|---|---|---|---|---|---|---|
| `--render-thread safe` (actuel) | 25,6 | 11,0 | 63,4 | 338 | 12,7 | inconnu (lancement interrompu puis repris) |
| `--render-thread separate` | 42,1 | 21,1 | 33,3 | 7 | 10,6 | 3 |

Gain très net (+65 % de FPS, images > 33 ms quasi supprimées) MAIS 4 « free_rid can only be called from the render thread » dans
le journal (à la fermeture du jeu, après la mesure ; RenderingDevice.free_rid appelé hors du fil de rendu) et le moteur l'indique « expérimental, plantages connus avec les
particules ». Tests de stabilité NON faits (délai de la journée) → **non activé**. À faire : banc entrelacé 3 x (témoin, place,
combat, grotte) avec `BANC_MOTEUR="--render-thread separate"` sur l'exe, puis stabilité (fils de fond qui créent des maillages,
entrées/sorties d'intérieurs, grotte, crypte, F5/F9, test_menus, test_tout_reseau coop_proto/rejoindre) et chasse des free_rid ;
s'il tient : `rendering/driver/threads/thread_model=2` dans project.godot, repli `--render-thread safe`.

## 5. Reste / pistes
- Fil principal : TIME_PROCESS 24 ms au témoin (exe) dont 4 ms de scripts (le reste inclut le dessin du serveur de rendu et
  l'attente) → cpu_scripts / persos_anim.
- Physique : itérations de récupération Jolt (ci-dessus) ; move_and_slide espacé pour le joueur immobile.
- `outils/banc_perf.sh` compte les autres Godot avec `grep -avic console` alors que la colonne Session de tasklist vaut
  « Console » : toujours 0 (corrigé dans banc_fps_exe.sh seulement).
- Tests réseau (test_integration6, test_monde_vivant) : échec à la connexion (« 2 joueurs en ligne » jamais atteint) sous 2
  créneaux Godot saturés — hôte et invité ne tournaient pas en même temps ; à relancer au calme (Max, test_tout_reseau).
- Shader baker (export non headless) : non essayé.
