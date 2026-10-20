# Socle technique : règles obligatoires (monde ouvert 1 km²)

Ce document fixe les règles d'architecture et de performance que TOUT lot doit respecter (agents compris).
Il complète la bible visuelle (`docs/MISSION_GRAPHISME.md`) et les règles de level design (§ 5).
Cible : i5-1145G7 + Intel Iris Xe, renderer Mobile, 480×270, **< 8 ms GPU et < 16 ms CPU par image, sans à-coup**.

État mesuré le 2026-10-20 (branche biome/zone-temoin, c84c85e) : la base respecte déjà l'esprit des règles 1 et 2
(MultiMesh par cellules de 20 m dans `instanciation.gd`, une seule ombre dynamique : la lune) ; la règle 3 n'existe pas encore
(tout est généré au chargement, sur le thread principal).

---

## 1. Décor répétitif = MultiMesh par cellule

- Arbres, souches, branches, cailloux, touffes, congères en relief, ossements épars… : **toujours** via
  `Instanciation` (un `MultiMeshInstance3D` par (mesh, cellule de 20 m), avec `visibility_range_end` = portée).
- **Interdit** pour ces objets : un `MeshInstance3D` / `Node3D` par instance.
- Pourquoi par cellule et pas un MultiMesh géant : Godot culle un MultiMesh **en bloc** (une seule AABB). Un MultiMesh
  qui couvre 1 km serait toujours dessiné en entier. La cellule est l'unité de culling, de LOD et de streaming.
- Exceptions autorisées (`MeshInstance3D` individuel) : objets **uniques ou interactifs** (portes, leviers, coffres
  fouillables, sarcophage, stèles), pièces de bâtiments uniques, personnages. Les pièces répétées d'un kit modulaire
  (murs, poutres, piliers) passent par MultiMesh ou par un maillage fusionné par bâtiment.
- Ombres : proxy d'ombre opaque partagé (cartes alpha interdites dans la passe d'ombre : ~3 ms mesurées) ;
  `cast_shadow = OFF` pour les petits détails et au-delà de 50 m.
- Dette connue : quelques arbres morts / ornements en `MeshInstance3D` isolés (`cercle_runique.gd`, `abords_tumulus.gd`)
  → à convertir lors du passage aux chunks.

## 2. Budget lumière (renderer Mobile)

- Le renderer Mobile n'est pas « clusterisé » : chaque objet reçoit une liste limitée de lumières (8 omni + 8 spot
  par maillage). Le coût vient du **nombre de lumières qui touchent un même maillage** et des **ombres**.
- **Ombres dynamiques : seulement la lune / le soleil** (`DirectionalLight3D`, portée ≤ 50 m). Toutes les `OmniLight3D`
  et `SpotLight3D` : `shadow_enabled = false`, sans exception (une ombre omni = 6 rendus de la scène). Le feu de camp
  reste sans ombre ; si un jour on veut son ombre, ce sera une décision mesurée, pas un réglage par défaut.
- **Au plus 3 lumières locales visibles en extérieur**, en plus du ciel ; **au plus 4 à 6 par salle** en intérieur
  (crypte, longère, grotte), car un intérieur sans lumières pratiques est illisible : les lumières d'une salle ne
  doivent pas atteindre la suivante.
- Toutes les lumières locales : portée courte (3–10 m), atténuation forte, `distance_fade_enabled = true`
  (disparition progressive au-delà de ~25 m), et **désactivées avec leur chunk / leur salle**.
- Ambiance au-delà du budget : émissif dans la texture (fenêtres chaudes, braises, cristaux), lumière « peinte »
  dans les couleurs de sommet, halos en sprites. Pas de lumière dynamique pour de la décoration lointaine.

## 3. Streaming des chunks sans à-coup

Découpage : **chunks de 80 m** (4 × 4 cellules de 20 m, alignés sur la grille actuelle), carte de ~1 040 m → 13 × 13 chunks.
Anneaux autour du joueur : complet ≤ 1 chunk ; décor allégé (LOD, sans détails du sol) à 2 chunks ; horizon (silhouettes
et terrain grossier) au-delà ; déchargement avec hystérésis (on ne décharge qu'à +1 chunk de la limite de chargement).

Fils d'exécution (`WorkerThreadPool`) :
- **En tâche de fond** : tout le calcul pur — hauteurs, cartes de sol, placement des arbres/cailloux, tableaux de
  sommets, transforms des MultiMesh, données de collision (`PackedVector3Array`). Aucun accès à l'arbre de scène.
- **Sur le thread principal, au compte-gouttes** : création des nœuds, `add_child`, création des formes de collision,
  envoi des buffers au GPU. Budget **≤ 2 ms par image** (file d'attente traitée par tranches), jamais un chunk entier
  d'un coup.
- Au plus **3 tâches de fond** simultanées (le i5 a 4 cœurs / 8 fils : il faut laisser le jeu respirer).
- **Déterminisme** : chaque chunk a son RNG dérivé de `graine_monde + coordonnées du chunk`. Plus de RNG global
  partagé (piège connu : un seul RNG « 1234 » rend tout le monde dépendant de l'ordre de génération).
- **Shaders** : précompiler tous les matériaux à l'écran de chargement (sinon le premier affichage d'un matériau
  provoque un gel, même avec un streaming parfait).
- Ce qui ne se streame pas : le joueur, les quêtes, le cycle, l'HUD. Les PNJ et ennemis d'un chunk déchargé sont
  sérialisés (état minimal) et recréés au retour ; la sauvegarde enregistre ces états par chunk.
- Mesure obligatoire : un test de traversée de la carte en ligne droite à la vitesse de course qui enregistre la
  **pire image** (objectif : aucune image > 33 ms, 99 % des images < 16,7 ms).

## 3 bis. Brouillard = distance d'affichage

Le brouillard de distance (lot 7, fin à ~50-60 m, 25-30 m en tempête) fixe la distance utile d'affichage : rien de
détaillé n'est dessiné au-delà de la fin du brouillard + marge. Les portées de visibilité des cellules, le LOD d'horizon
et les anneaux de streaming se règlent sur cette valeur (et non l'inverse).

**Règle confirmée (lot 7, mesurée)** : brouillard Godot en mode PROFONDEUR (`fog_mode = DEPTH`, `fog_density = 1`, courbe 1,
`fog_sky_affect = 0`), réglé par `cycle.gd` (`appliquer_brume`). Il s'applique seul à TOUS les matériaux (ps1, ps1_bati, ps1_tronc,
ps1_rameau, ps1_herbe, sol) : aucun code dans les shaders, aucun surcoût. Net jusqu'à `fin × 0,36` (~21 m nuit, ~18 m jour),
effacement linéaire jusqu'à `fin`, brume seule au-delà. `fin` : nuit claire 60 m, jour gris 50 m ; facteur local
(`monde._brume_locale`, relevé toutes les 0,4 s, lissé) : creux −20 %, crête +25 %, forêt dense (≥ 24 arbres à 14 m) −15 % ;
tempête : `cycle.tempete` (0..1) ramène `fin` à 27 m (`FIN_TEMPETE`). Fin maximale `cycle.FIN_MAX = 75 m`.
Couleur du brouillard = horizon du ciel (`horizon_courant` du shader de ciel, même valeur) : aucun raccord à l'horizon.
Conséquences réglées sur cette valeur : `camera.far = 90`, ombres de la lune 62 m, arbres : mesh complet + ombres jusqu'à
`PORTEE_PLEINE = 48 m` (brouillard déjà à 60-80 %), silhouettes `lod_mesh` de 44 à `PORTEE_LOD = 80 m` (> 75), rochers 80 m.
Sous terre : brouillard exponentiel (mode rétabli par `_sous_terre`). Toute nouvelle portée de visibilité doit rester ≤ `FIN_MAX + 5`.

## 4. Contrôle à chaque lot

Chaque lot rend : GPU au feu `2.5,8.5,16,4` vsync off, nombre d'appels de dessin, primitives, temps de chargement,
et (dès que le streaming existe) la pire image du test de traversée. Mesures faites **avec un seul Godot ouvert**.

## 5. Règles de level design (Lead Technical Artist rétro 32 bits)

1. Géométrie modulaire sur grille 1 / 2 / 4 m ; éléments porteurs (poutres, contreforts, plinthes, arches brisées,
   cadres de porte épais, piliers octogonaux) ; grottes en low-poly facetté franc avec strates et dénivelés.
2. Jamais de pièce vide : Macro (structure), Méso (mobilier lourd), Micro (détails narratifs).
3. Textures 64² à 256² max, Nearest, ~16 texels/m uniformes, arêtes contrastées et usure dessinée.
4. Lumières intégrées à la scène (appliques, torches, braseros, rais de lumière), dans le budget du § 2.
5. Pour chaque lieu : description en 3 points (Murs/Structure, Mobilier, Éclairage) avant le code.

## 6. Journal « Précalcul et chargement » (branche outils/precalcul, 2026-10-20)

**Tout régénérer d'un coup** (≈ 25 s) :

```
godot --headless --path . --import          # worktree neuf seulement
godot --headless --path . --script res://outils/precalculer_tout.gd
godot --headless --path . --script res://outils/precalculer_tout.gd -- --verifier   # compare tout au calcul direct, octet par octet
```

Options : `-- --seulement=arbres,ecorces,sol,crypte,grotte,bati,carte_sol`. L'outil lance chaque générateur existant
(`generer_arbres`, `generer_ecorces`, `generer_sol`, `generer_crypte`, `generer_grotte`, `cuire_bati`) dans son propre Godot,
puis `generer_carte_sol` (le monde entier, car la carte de sol dépend du relief, des arbres, des rochers et des chemins).

**Règle** : après toute modification d'un générateur (`textures_arbres.gd`, `ecorces.gd`, `crypte_textures.gd`,
`grotte_textures.gd`, `peinture_bati.gd`, `sol_tuiles.gd`…), incrémenter sa constante `VERSION` quand elle existe
(`TexturesArbres`, `Ecorces`, `CrypteTextures`) puis relancer `precalculer_tout`. Un `.res` de mauvaise version est ignoré
(repli : calcul au lancement, donc jamais d'image fausse, seulement plus lent). Les `.res` des écorces n'avaient pas de
version : ajoutée (1) et fichiers régénérés.

**Mesurer** : `godot --headless --path . -- --nouvelle --chrono` affiche le temps de chaque étape de `monde._ready`
(`scripts/chrono.gd`, `Chrono.marque("étape")` ; inactif sans `--chrono`). `--sans-prechargement` coupe le préchargement.

| Étape (headless, médiane de 3, PC chargé par 4 agents) | Avant | Après |
|---|---|---|
| Arbres (atlas épicéa 413 ms, pin 31, bouleau 9 → fichiers) | 501 ms | 146 ms |
| Carte de sol 960² + empreintes (cache signé) | 501 ms | 100 ms |
| Joueur (1er corps humain `homme_vetu.glb` + cheveux) | 894 ms | 201 ms |
| Villageois (`femme_vetue.glb` 16 Mo + cheveux) | 934 ms | 101 ms |
| Terrain / village / tertre+crypte / rochers+sous-bois | 116 / 367 / 187 / 98 | inchangé |
| **Total de `monde._ready`** | **≈ 3,7 s** (3,5 à 4,1) | **≈ 1,2 à 1,6 s** |

Avant `_ready`, le moteur lit et compile la scène et ses scripts : ≈ 1,5 à 2 s (voir « Restant »).

**Ce qui a été fait**
- `assets/arbres/atlas_{epicea,pin,bouleau}.res` (`TexturesArbres.VERSION`, repli = calcul ; `outils/generer_arbres.gd`).
- `Ecorces.VERSION` + `DOSSIER`.
- Carte de sol : `assets/sol/carte_sol.res` + `carte_traces.res`, valides seulement si la **signature SHA-256** de leurs entrées
  est la même (relief échantillonné, positions des arbres, obstacles, chemins, code de `sol.gd`, `zone_biome.gd`, `chemins.gd`).
  Quiconque change le terrain, la forêt ou ces scripts invalide le cache tout seul : le jeu recalcule (~0,6 s), et
  `precalculer_tout` régénère. `Sol.cache_statut` dit « lu », « perime », etc.
- `scripts/prechargement.gd` : `ResourceLoader.load_threaded_request` des corps humains et cheveux, lancé par l'autoload
  Fenetre (avant la compilation de la scène) et par Monde. Même fichiers, même importeur : aucun effet sur le rendu.
- Vérification : 0 différence octet par octet sur les atlas, les écorces, la crypte (24), la grotte (18), le bâti (28), les
  tuiles de sol (5) et la carte de sol (carte + empreintes). Les générateurs existants (sol, crypte, grotte, bâti) ressortent
  identiques aux fichiers déjà commités.

**Restant (non fait, par ordre de gain)**
1. ~1,5 à 2 s avant `_ready` : compilation GDScript de toutes les scripts préchargés. Un export avec « binary tokens » la réduit ;
   en développement, rien à précalculer.
2. Géométrie du village (`village.gd`, 370 à 550 ms) : maillages `SurfaceTool` déterministes (graine 99), donc cuisibles en
   `ArrayMesh` `.res` ; gain attendu ~0,4 s, mais gros chantier (matériaux, collisions, lieux à ré-attacher).
3. Terrain (~120 ms), bras et torche du joueur (~130 ms), sous-bois (~55 ms), arbres (placement 25 ms, maillages 60 ms) : mettables
   en tâche de fond (thread) à condition de séparer calcul pur et création de nœuds ; gain faible, risque réel.
4. `Palette.tex()` sans RNG (matériaux des villageois, du joueur, du tertre) utilise un `RandomNumberGenerator` NON initialisé :
   le grain de ces textures change à chaque lancement (les captures ne sont donc pas identiques d'un lancement à l'autre,
   écart mesuré 0,05 à 5 %). Les graines fixer coûterait un léger changement de grain une fois ; à décider avec l'équipe graphisme.
   `randf()` global dans `_villageois()` (points de promenade) est aussi non déterministe.

## 7. Outils pour agents (captures groupées, sauvegarde de test, tests sans fenêtre)

Godot : `G=/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe` ; `W=$(wslpath -w <worktree>)`. Worktree neuf : `$G --headless --path "$W" --import` d'abord.

### 6.1 Captures groupées : `--captures=<fichier de poses>` (un seul lancement)
Avant : chaque vue relançait Godot (monde régénéré + shaders, 10-30 s). Maintenant le monde est construit une fois, puis chaque ligne
est placée, éclairée, attendue puis écrite en PNG. Mesure (7 vues : 4 monde, 2 crypte, 1 grotte, `--attente=200`) :
**92 s en lancements isolés → 14 s en un lot** (5 s une fois le monde construit). Pour 20 vues : environ 5 min → ~25 s.
```
$G --path "$W" --disable-vsync -- --captures="$W\poses.txt" --sortie="$W\captures\mon_lot" --nouvelle --paisible --sans-particules --attente=200
```
Fichier de poses, une vue par ligne, `#` = commentaire : `nom type coordonnées [option=valeur …]`
- `monde x,z,lacet°,tangage°` · `crypte x,z,lacet°,tangage°` (repère crypte) · `grotte s,décalage,lacet°,tangage°` · `scenario village|place|forge|dialogue|…`
- options par ligne : `heure=12` (jour ; sans option = heure de départ, nuit, éclairage identique à un lancement isolé), `sans-mains`, `torche-eteinte`, `attente=N`.
- sortie : `<--sortie>/<nom>.png` (par défaut à côté du fichier de poses) ; le journal affiche `CAPTURE nom …` puis `LOT : N captures en X s`.
- options globales (valent pour toutes les vues) : `--paisible`, `--sans-particules`, `--sans-mains`, `--nouvelle`, `--attente=` (1re vue : shaders, défaut 90), `--attente-suite=` (vues suivantes, défaut 20).
- ordre imposé : monde, scénarios, crypte, grotte (on ne ressort pas du sous-sol) ; une vue monde placée après le sous-sol est ignorée avec une erreur.
- fidélité : une vue seule dans un lot est identique à un lancement isolé (0,002 % de pixels > 8/255, grotte 0 %) ; dans un lot de plusieurs vues,
  l'aurore et les flammes (`TIME` des shaders) dépendent du moment de la prise : 0 à ~3 % de pixels de différence (ciel/flammes seulement, mesuré
  avec `--sans-mains`). Avec les mains visibles, l'épée et la torche bougent déjà d'environ 7 % d'un lancement isolé à l'autre.
- scripts adaptés (même usage qu'avant) : `outils/revue_visuelle.sh`, `outils/captures_arbres.sh`, `captures_bati.sh`, `captures_crypte.sh`, `captures_grotte.sh`.
  `LOT=0 bash outils/captures_xxx.sh …` revient à un lancement par vue. `revue_visuelle.sh` garde les lancements unitaires pour un dossier « avant » ancien (sans `--captures`).
- les anciens arguments `--capture= --pose= --cpose= --gpose= --scenario= --heure=` marchent toujours.

### 6.2 Sauvegarde de test séparée
`user://sauvegarde.json` = la vraie partie. Tout lancement avec arguments utilisateur (après `--`), en `--script`/`-s` ou en `--headless`
(tests, captures, `--nouvelle`…) lit et écrit `user://sauvegarde_test.json` (`Monde.fichier_sauvegarde()` dans `scripts/monde.gd`).
Seul un lancement « nu » (le jeu de l'utilisateur, F9 compris) touche la vraie partie. `outils/test_sauvegarde.gd` vise le fichier de test et
refuse de tourner si le jeu visait la vraie sauvegarde. Dossier Windows : `%APPDATA%\Godot\app_userdata\<nom du projet>\`.

### 6.3 Tests sans fenêtre : `bash outils/tous_les_tests.sh [motif]`
Enchaîne les `outils/test_*.gd` en `--headless` (avec `--nouvelle` / `--paisible` quand il le faut, `test_sauvegarde` en deux processus),
affiche `OK`/`ÉCHEC` + durée par test et un total ; code de sortie = nombre d'échecs ; journaux dans `captures/tests/<test>.log`.
Verdict : code 0, ni « SCRIPT ERROR » ni « ÉCHEC ». Les tests tournent en `--fixed-fps 60` (simulation accélérée : suite entière 581 s → ~170 s) sauf `test_ragdoll` et `test_mort_ragdoll` (résultat dépendant du pas de physique : temps réel, un 2e essai autorisé sous charge). `bash outils/tous_les_tests.sh dragon` n'en lance qu'une partie ; `TEMPS_MAX=…` règle le délai par test.
Exception : `test_biome.gd comparer` exige une fenêtre (MultiMesh vides en headless) → `AVEC_FENETRE=1 bash outils/tous_les_tests.sh biome`.
Fenêtre réservée aux captures (`--captures`) et à `outils/mesure_perf.gd` (GPU réel, sans `--headless`).
