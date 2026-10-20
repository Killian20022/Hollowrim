# Mission : refonte graphique sérieuse (avant les phases 3 et 4 du biome)

> Script de travail à donner tel quel à Claude (« lance la mission graphisme »).
> Objectif : que chaque élément vu à l'écran — arbres, sol, personnages, mains, bâtiments, décor — soit
> un VRAI bel asset de pixel art « 32 bits », net, sans trou, cohérent avec les autres.
> On améliore l'existant ; on ne recrée pas le jeu. La nuit (aurore, neige, feu) reste la référence d'ambiance.

---

## 0. Règles du jeu (non négociables)

1. **Rien sans preuve visuelle.** Chaque changement est jugé sur des captures AVANT | APRÈS
   (`bash outils/revue_visuelle.sh <iteration>` + gros plans dédiés, voir §6). Pas de « ça devrait être mieux ».
2. **Zéro trou, zéro clignotement.** Aucun personnage, main, vêtement ou bâtiment ne doit montrer le
   vide, l'intérieur d'un maillage, des faces qui disparaissent selon l'angle ou des fissures entre pièces.
3. **Du pixel art, pas du bruit.** Les textures sont faites d'**amas de pixels** (clusters) avec des rampes
   de 3 à 6 tons, un léger glissement de teinte (ombres plus froides, lumières plus chaudes), des formes
   lisibles. Interdit : bruit aléatoire « sel et poivre », dégradés lisses, flou, damier de tramage.
4. **Une seule densité de pixels.** Décor : **16 texels par mètre** (une texture de 32 px couvre 2 m).
   Personnages et objets tenus : **32 texels par mètre**. Tout écart doit être justifié.
5. **Une seule palette maîtresse** (§1), filtrage au plus proche, mipmaps « nearest » seulement si le
   scintillement le justifie. Pas d'antialiasing, pas de flou de post-traitement.
6. **Performances tenues.** Sur ce PC (Iris Xe) au feu de camp de nuit : GPU ≤ 8 ms (mesure
   `outils/mesure_perf.gd`), chargement +0,5 s maximum au total. Mesurer avant/après chaque lot.
7. **Non destructif.** Branche `graphisme/<lot>` par lot depuis `biome/zone-temoin`, tag avant/après,
   tests relancés (`test_quetes`, `test_sauvegarde`, `test_dragon_monde`, `test_marche_pnj`,
   `test_mort_ragdoll`, `test_degats_sanctuaire`, tests biome). Aucun asset supprimé sans vérifier qu'il est
   inutilisé. Aucune dépendance externe ni téléchargement sans accord de l'utilisateur.
8. **Agents à fond, sans conflit.** Un agent par lot, fichiers attribués, worktree dédié, fusion par moi
   après revue des planches. Un seul Godot à fenêtre à la fois pendant les mesures.

---

## 1. Bible visuelle (à écrire en premier : `docs/BIBLE_VISUELLE.md`)

- **Palette maîtresse** de ~48 couleurs, rangées par rampes : neige (bleus froids → blanc cassé),
  aiguilles (vert-noir → vert-gris givré), écorce (brun-gris), pierre (gris bleutés), bois travaillé
  (bruns chauds), chaume/tourbe, peaux (3 carnations), cuir, laine (bleu, rouge sombre, écru), fer,
  or terni, flammes, runes (cyan). Chaque rampe : 4 à 6 tons avec glissement de teinte.
- **Lumière de référence** : lumière principale froide en hauteur, ombres bleu-violet, sources chaudes
  (feu, torches, fenêtres) qui « réchauffent » les rampes. Les textures ne portent qu'une ombre douce
  intégrée (occlusion, creux), jamais une direction de lumière forte.
- **Lisibilité à distance** : silhouette d'abord (un arbre, une maison, un personnage se reconnaissent en
  ombre chinoise à 30 m), détail ensuite.
- **Planche de référence** : générer une image `captures/bible/planche_palette.png` (rampes + exemples
  d'amas) et la faire valider avant de texturer quoi que ce soit.

---

## 2. LOT 1 — Trous et défauts de maillage (priorité absolue : personnages, mains, vêtements)

Symptômes signalés : « personnages qui ont des trous », « ma main toute trouée ».

**Diagnostic à faire d'abord (preuves en gros plan, 8 angles) :**
- `--mains=repos|garde|frappe --camera-main=d|g,dehors|dedans|dessus|dessous|joueur,0.5` (bras FPS) ;
- `--scenario=galerie` / `village` / `forge` + caméras tournantes autour de chaque PNJ et draugr ;
- vue 3e personne (`--vue=3`) du corps du joueur.
Causes probables à vérifier une par une :
1. **Faces simples vues de l'intérieur** : vêtements, manches, gants et cheveux ont été découpés dans le
   corps (bords ouverts) et le shader ps1 est en `cull_back` → on voit à travers. Remède : refermer les
   maillages dans Blender (fond de manche, intérieur des gants, col) ou rendre ces pièces double face
   (`cull_disabled` sur un matériau dédié) ; jamais les deux à l'aveugle.
2. **Fissures du tremblement de sommets** (snapping PS1) entre pièces séparées (gant/brassard/manche,
   tête/cou, corps/vêtement) : les sommets de deux pièces voisines ne tombent pas sur la même grille.
   Remède : chevauchement de 1 à 2 cm entre pièces, ou souder les jonctions, ou snapping plus fin sur les
   personnages (uniform par matériau).
3. **Corps qui traverse les vêtements** pendant les animations (pieds au sol, IK, ragdoll) : masquer les
   parties du corps cachées sous les vêtements (suppression des faces sous la tunique/pantalon/bottes).
4. **Normales inversées / faces manquantes** à l'export Blender, **z-fighting** entre peau et vêtement.
5. **Mains FPS** : vérifier la peau sous les gants, les doigts repliés (Punch_Cross) qui écartent les
   phalanges, la jonction poignet/brassard quand le poignet tourne (orientation_main.gd).
**Critère de sortie :** une « galerie de contrôle » (script outils/galerie_trous.gd : chaque personnage en
T et en 4 poses d'animation, 8 angles, 2 distances) sans aucun trou visible ; mains FPS nettes dans les
5 poses et en 3e personne.

---

## 3. LOT 2 — Vrais beaux arbres en pixel art

Constat : épicéas procéduraux (arbres.gd) à grandes facettes, aiguilles en texture de traits, silhouette
correcte mais « polygonale ». Objectif : un sapin nordique qu'on aurait envie de peindre.
- **Feuillage en cartes pixel art** : remplacer les grands triangles verts par des **cartes de branches**
  (quads en alpha-scissor, double face, matériau `ps1_herbe` ou dérivé) portant une texture 64×64 de
  rameau d'épicéa dessinée en amas (aiguilles groupées, 4-5 tons, neige posée en paquets sur le dessus,
  bord découpé net). Garder les étages et la silhouette actuels comme squelette de placement.
- **3 essences** cohérentes avec le biome : épicéa (dominant), pin sylvestre (tronc orangé, couronne haute,
  sur les buttes sèches), bouleau d'hiver (tronc blanc à marques noires, branches nues) en zones humides.
  Plus l'arbre mort retravaillé (branches tordues lisibles, écorce grise, givre).
- **Écorce** en pixel art (sillons verticaux en amas, mousse au pied côté nord, neige accumulée au pied).
- **Variété** : 2-3 graines par forme, échelles, inclinaisons ; LOD d'horizon redessiné dans le même style
  (cartes plus grosses, moins nombreuses).
- **Budget** : comparer triangles/draw calls (les cartes coûtent peu en triangles mais l'alpha-scissor a un
  coût) ; tenir GPU ≤ 8 ms.
**Critère :** gros plan d'un arbre (2 m), plan moyen (10 m), lisière (30 m), horizon (90 m), jour et nuit :
beau à chaque distance, pas de scintillement des cartes en mouvement.

---

## 4. LOT 3 — Vrai sol

Constat : sol de zone témoin correct (chemin, aiguilles, mousse) mais textures encore « procédurales » et
grands triangles de 2 m visibles.
- **Tuiles pixel art 32×32 dessinées** (pas du bruit) : neige fraîche (vagues de vent, sastrugi, reflets
  en amas), neige piétinée (traces de pas, ornières), terre gelée, roche affleurante (fissures, lichen),
  mousse givrée, tapis d'aiguilles. Chacune avec 2 variantes pour casser la répétition.
- **Transitions dessinées** entre matières (bords en amas irréguliers) plutôt que seuils sur la carte.
- **Relief fin** : congères contre les rochers, troncs et palissades ; petites bosses ; grille du terrain
  plus fine dans la zone visible si le budget le permet (ou relief simulé par la texture).
- **Petits détails au sol** en MultiMesh : cailloux, brindilles, traces d'animaux, plaques de glace.
**Critère :** vue au ras du sol à 1,6 m de haut, jour et nuit, sans répétition visible ni flou ni damier.

---

## 5. LOT 4 — Personnages nets (PNJ, draugrs, joueur 3e personne)

- Textures de vêtements refaites en pixel art 32 texels/m : tissages, coutures, ceintures, broderies
  nordiques simples, fourrure en mèches, cuir avec usure ; visages lisibles (yeux, sourcils, barbe) sans
  bruit ; 3 carnations de la palette.
- Draugrs : chair desséchée (rampes gris-bleu), haillons déchirés en silhouette, armures rouillées.
- Silhouettes distinctes par rôle (chef, forgeron, chasseuse, völva, garde, ancienne).
- Vérifier les ombres et l'éclairage des personnages (pas de visages noirs de nuit : léger éclairage
  d'appoint ou émission minimale sur les yeux et le visage si nécessaire).
**Critère :** galerie de contrôle de face, de profil et de dos à 2 m et 8 m, jour/nuit, sans trou.

---

## 6. LOT 5 — Bâtiments et décor du village (et du tertre)

- **Longue maison et maisons** : murs en planches ou rondins texturés en pixel art (veines, nœuds,
  joints), soubassements en pierres sèches, toits en tourbe/chaume avec **neige épaisse** dessus et
  stalactites, pignons sculptés (têtes de dragon), portes renforcées de fer, fenêtres chaudes la nuit.
- **Palissade** : pointes taillées, liens de corde, neige accumulée au pied côté vent.
- **Forge, puits, enclos, tonneaux, caisses, tas de bois, râteliers, peaux qui sèchent** : chaque objet
  retexturé dans la palette, proportions crédibles depuis la caméra (vérifier hauteurs de portes 2 m,
  marches, tables).
- **Tertre** : façade de pierres runiques retravaillée, intérieur de la crypte (pierres, ossements,
  sarcophages) dans la même qualité.
**Critère :** tour du village à hauteur d'yeux (8 poses), jour/nuit ; chaque bâtiment reconnaissable en
silhouette, aucun mur « plat » sans texture lisible, aucune pièce flottante.

---

## 7. LOT 6 — Objets tenus et premier plan

Épée, torche, mains : ce sont les pixels les plus vus du jeu.
- Épée nordique : lame avec gorge et fil lisibles, garde et pommeau en fer forgé, poignée en cuir tressé.
- Torche : manche, chiffons goudronnés, braises ; flamme pixel art (sprites de flamme animés en 4-6
  images plutôt que des particules floues), lumière vacillante.
- Gants et manches : coutures, rivets, fourrure au poignet ; aucune fissure au poignet (lot 1).

---

## 8. LOT 7 — Lumière, post-traitement et cohérence finale

- Jour moins délavé (ambiant, horizon du ciel accordé à la brume, exposition, soleil un peu plus haut),
  halos de flammes nets (glow réglé), crépuscule distinct ; nuit inchangée dans son esprit.
- Tramage du post-traitement : vérifier qu'il ne crée pas de bruit sur l'aurore et les bords d'arbres.
- Passe de cohérence : densités de pixels, palette, contours ; liste des assets qui « jurent ».
- **Brouillard de distance (demande utilisateur du 2026-10-20)** : le joueur ne doit jamais voir le bout du monde, pour que
  la carte paraisse gigantesque (esprit Silent Hill / Daggerfall). Brouillard en profondeur avec une vraie limite : net
  jusqu'à ~20 m, effacement entre 20 et 50-60 m, au-delà la brume seule. Distance variable : nuit claire ~60 m, jour gris
  ~50 m, tempête de neige 25-30 m ; plus dense dans les creux et les forêts, plus dégagé sur les crêtes (récompense
  d'exploration). Le ciel reste lisible (aurore, lune : `fog_sky_affect` bas). Les arbres lointains sortent de la brume en
  silhouettes, jamais de « pop » : les portées de visibilité (`visibility_range_end`, LOD d'horizon) sont recalées juste
  au-delà de la fin du brouillard, ce qui rend du budget GPU à réinvestir près du joueur. Couleur du brouillard accordée à
  l'horizon du ciel. Captures avant/après jour, nuit, tempête ; mesure GPU avant/après.

---

## 9. Méthode, pour chaque lot

1. **Constat** : captures AVANT dédiées (gros plans + poses de revue) et liste précise des défauts.
2. **Référence** : décrire en mots la cible (formes, rampes, amas) et produire une mini-planche de
   texture en isolation (image de la texture agrandie ×8) avant de l'appliquer en jeu.
3. **Réalisation** dans le worktree du lot ; textures soit générées par code avec des motifs d'amas
   délibérés (pas de bruit), soit modélisées/peintes via Blender (sources dans `sources_blender/`).
4. **Revue** : `bash outils/revue_visuelle.sh <lot>_<n>` + gros plans du lot ; je regarde chaque planche
   et note sur la grille : silhouette, lisibilité, pixel art propre (amas, pas de bruit), cohérence
   palette/densité, trous, scintillement, nuit, performance. Itérer (3 à 5 fois) jusqu'à ce que tout soit
   « mieux », jamais « pareil ».
5. **Validation** : planche récapitulative montrée à l'utilisateur ; fusion seulement après son accord.

## 10. Ordre recommandé

Bible (§1) → Lot 1 trous (bloquant) → Lot 6 objets tenus (toujours à l'écran) → Lot 2 arbres → Lot 3 sol
→ Lot 4 personnages → Lot 5 bâtiments → Lot 7 lumière et cohérence. Les lots 2-3 et 4-5 peuvent avancer
en parallèle (fichiers différents). Ensuite seulement : phase 3 (généraliser le biome) et phase 4 (faune,
sons, ambiance).

## Outils disponibles
- `bash outils/revue_visuelle.sh <etiquette> [poses...]` : captures jour/nuit, planches avant|après,
  perf, invariance, tests ; poses dans `outils/poses_biome.txt` (ajouter des poses par lot).
- `outils/planche.gd`, `outils/comparer_images.gd`, `outils/mesure_perf.gd`, `outils/test_biome.gd`.
- Captures : `--capture= --pose=x,z,lacet,tangage --heure=12 (après --) --paisible --sans-particules
  --mains=<pose> --camera-main=d|g,<angle>,<distance> --camera-debug --vue=3 --scenario=<nom>`.

---

## Journal — Lot 1 (trous et défauts de maillage), branche `graphisme/lot1-trous`

### Outils ajoutés
- `outils/galerie_trous.gd` : galerie de contrôle (fenêtre nécessaire, rendu dans un SubViewport 256x256 comme le jeu).
  `godot --path . --resolution 320x180 --script res://outils/galerie_trous.gd -- --sortie=res://captures/trous/apres [--perso=homme,femme,pnj_*,draugr_sbire,draugr_guerrier,svanhild,joueur_3e] [--pose=T,Idle,Walk,Attaque,Parle,Genoux] [--dist=2.2,6.0] [--haut=1.0] [--cote=256] [--angles=face,dos,dessous,...]`.
  Chaque feuille = 8 angles (face, 3/4, profils, 3/4 dos, dos, dessus, dessous) x 4 lignes (normal 2 m, debug 2 m, normal 6 m, debug 6 m) ;
  rendu « normal » sur fond magenta (le vide se voit), rendu « debug » = `shaders/debug_faces.gdshader` qui peint les FACES ARRIÈRE visibles
  (une couleur par maillage) : du coloré visible = on regarde l'intérieur d'un maillage. `metriques.csv` / `metriques_mesh.csv` : pixels de faces
  arrière (par maillage) et pixels de fond enclos. Godot a parfois bloqué en milieu de longue série : lancer un personnage par processus.
- `outils/rogner.gd` (rogner/agrandir une zone) et `outils/montage.gd` (grille d'images) pour les planches.
- `sources_blender/scripts/` : `inspecter.py` (arêtes de bord, composantes), `decalage.py` (distance vêtement-corps), `iles.py` (îlots d'une pièce),
  `bras_sous_couche.py` et `femme_sans_volants.py` (les deux corrections Blender, rejouables).
- Bras FPS : captures `--mains=<pose> --camera-main=...` (5 poses x 7 vues + vue joueur).

### Trous constatés et cause prouvée
| # | Où | Quand | Cause (preuve) |
|---|----|-------|----------------|
| 1 | Bras FPS : manches, brassards, gants | tout angle hors vue normale, surtout dessus/dessous/dedans ; on voit le ciel à travers la manche et le dos du gant | **Coques ouvertes + `cull_back`** : `bras_fps.glb` ne contient que 3 maillages d'étoffe (manches 101, brassards 76, gants 414 arêtes de bord) et AUCUN avant-bras : rien derrière l'étoffe (mesure `inspecter_glb.py`) |
| 2 | Bras FPS : liseré clair entre manche, brassard et gant | vue joueur normale incluse | **Fissures entre pièces** (pièces séparées, aucun recouvrement, tremblement des sommets) : le ciel passe dans l'interstice |
| 3 | Tunique (jupe, bas de manche, col), mante, bottes, brassards | de dos, dessous, 3/4, en Attaque/Genoux surtout : jupe en lambeaux, intérieur de la jupe vu | **Faces simples vues de l'intérieur** : 347 (homme) / 461 (femme) arêtes de bord sur la tunique, 258 la mante, 248 les bottes ; rendu debug : jusqu'à 1 938 px de faces arrière visibles sur la seule tunique de la femme en Attaque à 2 m |
| 4 | Entre tunique/ceinture/pantalon/bottes (taille, dos, mollets) | de dos et 3/4 dos surtout, fine ligne magenta | **Fissures de snapping** + pièces découpées sans recouvrement : le corps entier est masqué pour les civils (`mi.visible = draugr`), donc le vide apparaît dans la moindre fente |
| 5 | Tunique de la femme : deux « volants » plats à hauteur de mollet | toutes poses, tous angles, 6 PNJ/Svanhild | **Îlots détachés** dans le maillage (`iles.py` : îlots n°6 et 7 de `tunique`, 69 sommets chacun, z 0,34-0,53 m, jusqu'à 41 cm de côté), absents chez l'homme |
| 6 | Cheveux, casques, bouclier, couronne | vues de côté | faces simples (casques 56-60 arêtes de bord, bouclier 56) : même cause que 3 |

Causes **écartées** par mesure : normales inversées (aucune face retournée visible hors bord ouvert), z-fighting peau/vêtement (les pièces sont à 1-5 cm du corps ; `decalage.py` : médiane 1,1 cm pantalon, 2 cm tunique/bottes, 5 cm mante, 0,6 cm gants),
doigts du poing qui s'écartent (les poings sont fermés sur l'épée dans les 5 poses), jonction poignet/brassard quand `orientation_main` tourne la main (seule la fissure du point 2 est visible). Corps traversant le vêtement : 12 à 48 sommets de tunique à l'intérieur du corps (jusqu'à -3 cm) mais le corps est masqué ; voir « sous-couche » ci-dessous (rentrée de 1,6 cm).

### Corrections (par cause)
1. **Matériau double face** (causes 1, 3, 6) : `Palette.shader_double_face()` = `ps1.gdshader` avec `cull_disabled` (même source, remplacé à l'exécution : un seul fichier à maintenir) ;
   `Palette.materiau(..., double_face := true)`. Appliqué aux étoffes des civils (`humain.gd`), cheveux greffés, équipements accrochés (casques, bouclier, couronne) et à tout le matériel des bras FPS (`mains.gd`). Refermer ces maillages dans Blender n'a pas de sens pour de l'étoffe fine ouverte (jupe, manche) ; l'envers montre la même étoffe.
2. **Sous-couche** (causes 2, 4) : le corps entier (déjà dans les glb, masqué) est affiché sous les vêtements des civils, rentré de 1,6 cm (`ps1.gdshader` : uniform `gonfle` = décalage le long de la normale, 0 par défaut, donc décor inchangé), teinte du pantalon x 0,6. Toute fissure laisse voir une étoffe sombre au lieu du vide. Pour les draugrs le corps est déjà visible.
   Bras FPS : `sources_blender/scripts/bras_sous_couche.py` ajoute à `bras_fps.glb` un maillage `peau_bras` (bras, avant-bras et paume pris sur le corps `homme_vetu.blend`, mêmes os/poids ; rentré de 1,6 cm sous la manche, 0,8 cm sous le gant ; doigts exclus : trop fins, le gant creux suffit). Matériau `sous_couche` (cuir sombre) dans `mains.gd`. Source : `sources_blender/bras_fps.blend` ; état d'avant : `sources_blender/bras_fps_original.glb`.
3. **Îlots détachés** (cause 5) : `sources_blender/scripts/femme_sans_volants.py` supprime ces deux îlots de `tunique` dans `femme_vetue.blend` et ré-exporte `assets/modeles/humains/femme_vetue.glb` (structure Godot identique, vérifiée).
4. Rien changé aux textures (lot 4) ni aux proportions.

### Preuves
- Avant : `captures/trous/avant/` (12 personnages x 6 poses) et `captures/trous/fps_avant/` ; après : `captures/trous/apres/`, `captures/trous/fps_apres/`.
- Planches avant (haut) / après (bas) : `captures/trous/planches/avant_apres_<perso>.png` (Attaque, Genoux, Walk, 8 angles à 2,2 m), `fps_avant_apres_d_dessous|d_dessus|d_dedans|vue_joueur.png` (5 poses), `jeu_galerie_avant_apres.png` (en jeu, volants de la femme disparus).
- Pixels de fond magenta enclos (poches vues à travers le personnage, somme de 8 angles x 6 poses à 2 m) : 23 907 avant, 9 234 après (femmes 2 100-2 300 → 400-570 ; hommes ~2 200 → ~970, le reste = espaces légitimes entre bras et torse ; draugrs 1 500-1 700 → 1 000-1 400 : corps toujours visible dessous, seul le fond bouge). Aucun trou visible à l'œil sur les planches après, sous aucun angle ni pose.
- Reste visible mais hors périmètre « trou » : la jupe de la femme et les manches s'étirent en pointes dans certaines poses extrêmes (poids de peau du maillage Quaternius) ; petites dents sombres sur les jointures des gants FPS (détail du modèle de gant d'origine).

### Tests et perf
- Tests headless : test_quetes (--nouvelle), test_sauvegarde (ecrire puis verifier), test_dragon_monde, test_marche_pnj, test_degats_sanctuaire : OK. test_mort_ragdoll : OK (sortie 5 une fois pendant que le test du sanctuaire tournait en parallèle ; relancé seul : OK, code 0).
- `outils/mesure_perf.gd` au feu (`--nouvelle --paisible --pose=2.5,8.5,16,4`, vsync off) : avant 6,88 / 6,67 ms GPU, après 6,87 / 6,95 ms (moyenne 6,78 → 6,91, +0,13 ms), 631 → 632 appels de dessin, primitives 330 k → 335 k.

## Journal — Lot 2 (vrais beaux arbres en pixel art), branche `graphisme/lot2-arbres`

Retour utilisateur visé : « ça fait toujours des paquets… faudrait vraiment des branches avec des feuilles ». Les épicéas ne sont plus des étoiles
de triangles pleins : chaque branche est une carte de rameau dessinée en pixel art, posée le long de la branche, avec du ciel entre les étages.

### Fichiers
- `scripts/textures_arbres.gd` (nouveau, `TexturesArbres`) : toutes les textures générées en code, RNG propres (aucun tirage du RNG monde).
  Palettes tirées de la bible : `AIGUILLES` (6 verts), `ECORCE`, `PIN` (écorce orangée), `BOULEAU`, `BOIS_MORT`, `NEIGE`.
  Mipmaps « pixel art » maison (`avec_mips`) : chaque niveau vote la couleur majoritaire d'un bloc 2x2 et reste opaque si ≥ `seuil` pixels
  sur 4 le sont → pas de bouillie ni de scintillement des cartes à distance.
  Atlas épicéa 128x128 : rameaux longs A/B (64x64), courts A/B (32x32), flèche, cœur, 8 crêtes de neige (64x8). Rameau `rameau_epicea` =
  arête de poisson : tige centrale, rameaux secondaires alternés, aiguilles en traits courts (dessus clair, dessous sombre), bois au cœur,
  un paquet de neige par rameau posé côté dessus, contour sombre sélectif. Atlas pin (touffes + calottes de neige), bouleau (ramilles
  pendantes), écorces épicéa/pin/bouleau (lenticelles, bandes sombres), bois mort.
- `shaders/ps1_rameau.gdshader` (nouveau) : dérivé de `ps1_herbe` (même accroche à la grille de 135 lignes, même affine, nearest),
  double face, découpe alpha ≥ 0,5, `filter_nearest_mipmap`. Normale de feuillage fournie par le maillage (radiale + haut : volume doux
  de la couronne). Face arrière : assombrie (`dessous` 0,7) et neige remplacée par `couleur_dessous` (la neige est sur le dessus) ;
  `COLOR.a < 0,5` désactive ce traitement (crêtes de neige, flèche).
- `scripts/arbres.gd` : nouveaux modèles. `epicea(forme, graine, materiaux, lod)` : tronc à écorce texturée (pied neigeux par l'alpha
  de sommet, mousse au nord, plus sombre sous 1,5 m), 6-10 étages, 5-11 branches par étage. Une branche (`_rameau`) = tige en 2
  segments qui retombe puis remonte au bout (`chute` 0,42 L en bas → -0,05 L en haut), carte pliée en toit (deux ailes inclinées de
  `pli` ≈ 0,62 rad sous l'horizontale, texture coupée le long de la tige dessinée), crête de neige verticale sur les branches > 0,8 m.
  Réglages dans `REGLAGES_EPICEA` (teinte, pli, aile, crête). Flèche = 2 cartes croisées. Version lointaine (`lod`) : moins de branches,
  plus longues, sans crête. `epicea_ombre` : proxy OPAQUE (étoiles d'étages + tronc à 3 pans, ~130 triangles) utilisé seul pour les
  ombres. `pin()` (tronc sinueux nu, couronne haute de touffes), `bouleau()` (tronc blanc penché, branches en arc, ramilles pendantes),
  `arbre_mort()` (tronc tordu cassé, branches nues dont 20 % brisées), `buisson()`/`semis()` refaits en rameaux.
- `scripts/vegetation.gd` : modèles et matériaux construits une fois (« Lot 2 : textures et modèles d'arbres en ~185 ms »).
  Deux graines par forme d'épicéa (choix par `ZoneBiome.alea_pos(x,z,11)`) pour casser la répétition ; ombre et LOD partagés.
  Essences dans la zone témoin seulement : `ZoneBiome.alea_pos(x,z,7)` décide ; pin sur butte (`h - hm > PIN_BUTTE` 0,3, part 0,75),
  bouleau au creux (`h - hm < BOULEAU_CREUX` -0,4, part 0,4) → 10 pins, 10 bouleaux. Aucun arbre ajouté ni déplacé.
- `scripts/instanciation.gd` : réglages `ombre_mesh` (maillage de la MMI d'ombre seule) et `principal` (false = pas de MMI principale).
- `scripts/monde.gd` : `--sans-mains` pour les captures. `outils/test_biome.gd` : `--sans-cles` (fusionne les transformées de toutes
  les clés : compare le placement indépendamment des modèles). `outils/revue_visuelle.sh` compare désormais avec `--sans-cles`.
- Outils : `outils/captures_arbres.sh <dossier> [poses]` (jour+nuit, `PHASES=jour`), `outils/poses_arbres.txt` (A2 gros plan,
  A10, A30 lisière, A90 horizon, M10 arbre mort, B5 bouleau, C5 pin, D6, S30 = A30 décalé de 12 cm pour le scintillement),
  `outils/planche_arbres.gd` (textures x8 + mips dans `captures/arbres/textures/`), `outils/trouver_arbres.gd`, `outils/planche.gd`
  (4e argument : liste des poses).

### Invariance hors zone (justifiée)
Le placement est identique partout : `test_biome comparer ref_ancien_fenetre.sig --sans-zone --sans-cles` → OK, et
`comparer ref_lot2_avant_fenetre.sig --sans-cles` (carte entière, état d'avant le lot) → OK. Les MODÈLES changent hors zone aussi
(tous les épicéas, arbres morts, genévriers) : garder les anciens « paquets » hors zone aurait donné deux forêts incohérentes ; la
référence sans `--sans-cles` diffère donc forcément (clés = AABB/sommets des maillages). Pins et bouleaux restent dans la zone.

### Perf (feu, `--nouvelle --paisible --pose=2.5,8.5,16,4`, vsync off, seul)
- HEAD avant lot : 6,87 ms GPU, 632 appels, 335 k primitives. Après : 7,36 / 7,47 / 7,50 ms (mesures précédentes 7,0-7,1), 661 appels,
  366 k primitives (budget 8 ms tenu).
- Les cartes alpha dans la passe d'ombre coûtaient ~3 ms (9,7 ms) → proxy d'ombre opaque. Des MMI séparées par graine coûtaient
  ~0,8 ms → ombre et LOD partagés entre graines.
- Chargement : +~185 ms (textures + modèles), sous les +0,5 s.
- Scintillement (proxy) : A30 vs S30 (caméra décalée de 12 cm), pixels changés 25,1 → 27,9 % le jour, 31,6 → 33,1 % la nuit : faible hausse.

### Tests
test_quetes OK, test_vegetation_biome conforme, test_chemin_biome 0 échec, test_collisions_biome TOUT OK ; aussi test_sauvegarde,
test_dragon_monde, test_marche_pnj, test_mort_ragdoll, test_degats_sanctuaire OK.

### Preuves
`captures/arbres/planches/` : `planche_recap_jour.png`, `planche_recap_nuit.png` (avant/après A2, A10, A30, A90),
`planche_<pose>.png` par pose (A2, A10, A30, A90, M10, B5, C5, D6 ; jour et nuit), images `avant_*`/`apres_*`.
Textures : `captures/arbres/textures/`.

### Défauts restants
- Gros plan (2 m) : les ailes du rameau du bas montrent leur pli et les gros pixels des aiguilles (le grossissement x16 d'une texture
  64 px) ; quelques « rayons » de rameaux qui partent du tronc se lisent sous l'arbre.
- Ramilles du bouleau presque invisibles au-delà de ~40 m (mips à seuil 2) ; arbre mort assez maigre.
- Les matériaux cercle/tumulus de l'ancien arbre mort sont encore créés dans `vegetation.gd` mais plus utilisés par `arbre_mort`.

### Lot 2, 3e passe (silhouette d'épicéa, nuit lisible, neige posée)
Retour utilisateur : conifères « en saules », nuit trop noire sur les arbres, neige à poser sur les rameaux.
- `scripts/arbres.gd` (`REGLAGES_EPICEA`) : branches presque horizontales à mi-longueur (`milieu` 0,3) dont le bout seul retombe, flèche
  au sommet, jupe basse plus courte (0,4-0,62 au lieu de 0,5-0,78), crête de neige 0,10 m, teinte du feuillage éclaircie.
- `scripts/textures_arbres.gd` : rampe d'aiguilles remontée côté lumière (fond = ton 2, lumière = ton 3), neige en amas irréguliers
  (taille propre, bords qui ondulent, interruptions, ombre portée seulement sous le débord) sur les faces tournées vers le haut,
  crêtes de neige 64x8 sans « gélules » régulières, contour du bas en ton 1 (non plus le plus sombre) ; neige 0,75-0,95 selon le rameau.
- `shaders/ps1_rameau.gdshader` : `light()` à éclairage enveloppant (`enroule` 0,18) : la face opposée à la lune n'est plus noire, sans
  toucher à l'albédo ni à la palette nuit.
- Perf feu (`2.5,8.5,16,4`, vsync off) : 5,67 ms (661 appels, 383 k primitives) et 6,10 ms (852 appels, 417 k) : < 8 ms.
- Tests : test_quetes OK, test_vegetation_biome conforme, test_collisions_biome TOUT OK.
- Planches : `captures/arbres/planches_v3/` (avant = HEAD 713cf2b | après ; A2, A10, A30, M10 jour+nuit, plus A90 et C5 en « apres »).
- Défauts restants : la nuit reste sombre dans les sous-bois profonds (volontaire, palette bible) ; le gain de lisibilité nocturne est
  modeste ; les cartes de rameau proches montrent encore de gros pixels ; le sol n'a pas été touché (lot 3).

---

## Journal — Lot 3 (vrai sol), branche `graphisme/lot3-sol`

Retour utilisateur : « même chose pour le sol avec la neige » (détail pixel art lisible au ras du sol).

### Constat (captures `captures/sol/avant/`, poses ras, chemin, lisière, cercle, pied, jour/nuit)
- Neige faite de grandes plaques floues de 2-3 m (texture 64 px de bruit périodique à 8 texels/m, quantifiée) + paillettes de 1 px isolées (sel et poivre).
- Limites de matières en carrés de 25 cm tramés au bruit blanc (« pavés ») ; terre/aiguilles/mousse en bruit procédural.
- Couleurs de sommet du maillage (clarté, chemin du village) interpolées sur les triangles de 2 m : triangles visibles.
- Chemin : neige piétinée uniforme, pas d'empreinte ; aucun relief fin (congère, cuvette au pied des troncs).
- Constat annexe (hors lot) : les grands aplats sombres en escalier sous certains arbres sont les branches basses du lot 2 vues de dessus (vérifié en coupant les ombres : ils restent).

### Réalisation
- **`scripts/sol_tuiles.gd` (SolTuiles)** : 8 matières × 2 variantes, tuiles 128² à **16 texels/m** (8 m, période longue = pas de répétition visible), dessinées par code en amas et filtre « mode » (aucun pixel isolé) : neige fraîche (plaques calmes allongées dans le vent, familles de rides/croissants à crête claire et ombre froide, micro-rides, creux, grains de reflet en paires), neige piétinée (bosses tassées, vieilles empreintes, saletés), terre gelée (mottes à biseau, givre dans les creux, cailloux, aiguilles rousses), tapis d'aiguilles (traits orientés groupés, cônes, brindilles, paquets de neige tombés), mousse givrée (coussins à sommet givré, poches de neige), roche affleurante (dalles Voronoï, joints 1 px, arête haute claire, lichen, neige dans les joints), glace (reflets en bandes, fissures blanches, poudre de neige), neige croûtée (sastrugi, fissures à lèvre claire). Tuiles = **cartes d'index (ton, rampe)** dans les rampes de la bible (`lut()` 8×8) : tout reste dans la palette, y compris les décalages de ton. Détails épars (texture 80² = 5 m, période décalée) : scintillements en amas, cailloux à chapeau de neige, brindilles, touffes d'herbes sèches vues de dessus.
- Précalcul : `godot --headless --path . --script res://outils/generer_sol.gd` → `assets/sol/sol_index.res`, `sol_couleur.res` (atlas Image ; les Texture2DArray ne se sérialisent pas), `sol_details.res`, et planches `captures/sol/textures/` (×3, mosaïques). À relancer après toute modification de SolTuiles (sinon `charger()` recalcule au lancement : ~3 s).
- **`shaders/ps1.gdshader`** (branche `sol_carte`, terrain seulement, rien n'est lu hors du rectangle de la zone + 1 m) : grille de texels de sol 1/16 m ; matière lue dans la carte avec un **décalage bruité lisse (±17 cm) + grain de 2 px** → bords en amas irréguliers au lieu de carrés ; **bord dessiné** entre matières de niveaux différents (`NIVEAU` : roche 4 > neige/croûte 3 > piétinée 2 > aiguilles/mousse 1 > terre/glace 0) : lèvre +1 côté haut, ombre −1 côté bas ; creux de la carte (−2..+1) ; empreintes ; détails selon la densité ; décalages cumulés bornés à [−2, +1], ton 0 de la neige interdit (accent) ; couleur = `texelFetch(sol_lut, ton, rampe)`. Au loin (texel < 1/1,6 px) : atlas couleur avec mipmaps nearest (`textureGrad`, dérivées hors branche). **Relief fin** : normale perturbée par le gradient du canal G (bilinéaire, constante par texel), `relief_force` 2. Couleur de sommet ignorée dans la zone (plus de triangles de 2 m), macro ×0,5.
- **`scripts/sol.gd`** : carte 960² inchangée en taille ; R = matière × 16 (+ GLACE dans les creux plats marqués loin des chemins et quelques flaques gelées dans les plaques du chemin, CROÛTE sur les bosses exposées et en plaques), G = relief (bosses allongées dans le vent, **congères** sous le vent (+z) des rochers, pierres du cercle, occupations, troncs et souches, douve de vent autour de la base, **cuvettes au pied des arbres** avec bourrelet), B = 128 | variante | densité de détails | creux (laplacien du relief). Tramage : bruit lisse à 80 % (au lieu de 55 %) + filtre de majorité 3×3 (sauf ornières). **Carte d'empreintes 1/16 m** (992×1088 R8) : 11 pistes de bottes orientées le long des deux chemins (foulée 0,62-0,78 m, pied gauche/droit, trous), piétinement en tous sens au feu, à la stèle et devant la porte, 3 pistes de renard et 2 de lièvre ; creux −2/−1, lèvre claire en bas à droite. Tampons précalculés (32 orientations). RNG/graines propres : `ZoneBiome.graine("sol")+0..8`, `graine("traces")`. `SOL_DEBUG=<dossier>` écrit `carte_debug.png` (matières | relief | creux/densité) et les temps par étape.
- **`scripts/details_sol.gd` (DetailsSol)** : 300 cailloux 3D (10 triangles, double face, calotte de neige sur 2 modèles sur 4) au bord des chemins, en couronne au pied des rochers/pierres, épars ; posés sur la hauteur EXACTE du maillage (`hauteur_maillage`), MultiMesh sans ombre ni collision, portée 32 m, RNG `graine("details_sol")`, tirages avant filtrage. Appelé par `monde.gd` après `Sol.appliquer` (1 ligne).
- Jouabilité inchangée : `hauteur()`, collisions et chemins non modifiés (le relief fin n'est que visuel).

### Résultats
- Planches avant (gauche) | après (droite), jour en haut, nuit en bas : `captures/sol/planches/avant_apres_{ras,chemin,lisiere,cercle,pied}.png` ; gros plans ras du sol de nuit : `gros_plan_{ras,chemin,pied}_nuit.png` ; tuiles : `planche_tuiles.png`, `details_x8.png`.
- Perf au feu (`2.5,8.5,16,4`, vsync off) : base 6,78 / 6,88 ms GPU → après 7,19 / 6,87 ms (≈ +0,2 ms, < 8 ms), 632 appels de dessin (inchangé), primitives 334,7 k (inchangé à cette pose).
- Chargement : `Sol.appliquer` ~300 ms → ~420-500 ms (+0,15 s ; carte d'empreintes 57 ms, relief 80 ms, majorité 40 ms, chargement des tuiles ~45 ms) ; cailloux négligeables.
- Tests : test_quetes, test_vegetation_biome, test_chemin_biome (0 échec), test_collisions_biome, test_sauvegarde (écrire/vérifier), test_degats_sanctuaire (~10 min) OK ; invariance `test_biome --sans-zone` : signature identique. Capture hors zone P10 : 5,9 % de pixels différents, mais deux captures de la base entre elles diffèrent déjà de 6,7 % (capture non déterministe) : pas de différence attribuable.

### Défauts restants
- À 1,6 m, un texel de sol (6 cm) fait ~13 px du rendu 480×270 au pied du joueur : le sol reste « gros pixels » tout près (densité 16 texels/m imposée par la bible) ; le détail se lit surtout entre 2 et 15 m.
- Les cailloux 3D sont un peu sombres et plats de nuit ; la calotte de neige se voit peu.
- Les congères (relief par normale) sont discrètes sous la lumière rasante ; un maillage plus fin n'a pas été fait (hauteurs/collisions inchangées).
- Brume de jour et tramage Bayer du post-traitement (lot 7) aplatissent le contraste du sol.

### Lot 3, 2e passe (proximité à 32 texels/m, glace, empreintes)
- **Couche de proximité 32 texels/m** : chaque tuile 128² est agrandie en Scale2x (256², `SolTuiles.scale2x`, aucune couleur nouvelle) puis affinée (`affiner`) : vagues de vent fines (`_rides_fines` : lignes de niveau d'un champ de phase gauchi, crête claire + ombre froide d'un texel, par plaques, perpendiculaires au vent), grains et fissures capillaires groupés en plaques, aiguilles/cailloux/givre selon la matière. Shader : texels de 1/32 m près du joueur, fondu **entre 4 et 8 m** (`sol_proche`) tramé par bruit lisse + grain (jamais Bayer) vers la couche 16 texels/m ; bords dessinés et bruit de bord adaptés au pas courant. Ressources : `sol_index2.res`, `sol_details2.res` (`outils/generer_sol.gd`, qui écrit aussi `planche_proximite.png`).
- **Glace** : plus de bandes sombres ni d'éclats : nappes de 2 tons proches, 5 longues fissures claires, voile de givre ; plaques seulement dans les grands creux plats (seuil lisse, pas de bruit blanc), éclats < 5 voisins supprimés, bord givré (neige claire) au lieu d'une ombre.
- **Empreintes** : carte portée à **1/32 m** (4,3 Mo, calculée au chargement) ; tampon de botte avec bord haut-gauche profond et intérieur peu creusé ; une empreinte qui en recouvre une autre (> 15 %) est omise. Cause prouvée du « damier » au pied du joueur sur les chemins : superposition de pistes à 1/16 m qui formait des losanges clair/sombre (vu par désactivation successive du relief, des creux, de la carte, puis visualisation des composantes).
- Perf au feu (`2.5,8.5,16,4`, vsync off, GPU) : 5cad5ef 5,26 ms (2 mesures 5,27 / 5,26) → 6,40 à 6,91 ms (2 mesures), < 8 ms ; 632 appels de dessin (inchangé), primitives 334 k.
- Planches : `captures/sol/planches/*_v2.png` (avant | v1 | v2 pour les gros plans).

### Lot 3, 3e passe (rides organiques, glace, fondu invisible)
- **Rides de vent** : plus de lignes de niveau parallèles. Primitive `_ride_libre` (croissant d'axe incliné, courbure signée, crête interrompue par un bruit, corps + ombre froide qui s'effile) ; orientation = champ de vent lent commun aux deux couches (`_flux`, ±55°), longueurs 5-30 texels, épaisseurs 0-2, 2e crête décalée non parallèle, quelques congères longues et basses (32-54 texels). Couche proche : mêmes rides à échelle fine, par plaques de densité variable (neige lisse entre elles).
- **Glace** : retour à la rampe GLACE de la bible (4 tons ; l'essai à 6 tons est abandonné). Fond uni ton 2, reflets en bandes ton 3 effilées et interrompues, 2 fissures fines à dérive lente avec lèvre claire par tronçons, quelques bulles ; plus aucun grain en proximité. Shader : sur la glace, ni creux sombre ni ombre de bord (c'étaient eux, les « taches » bleu foncé) ; bord givré conservé.
- **Fondu 32/16 texels** : plage 3-11 m (au lieu de 4-8) et seuil = grain 45 % + bruits lisses 25 %/30 % de deux échelles : plus de bande ni de cercle (vue `zone_fondu_v3.png`).
- Perf au feu (`2.5,8.5,16,4`, vsync off) : 3,2-3,7 ms GPU (2 mesures), 420 appels de dessin ; la base du journal (6-7 ms) a été mesurée dans un autre état du monde, comparaison directe non faite.
- Tests : test_quetes, test_chemin_biome (0 échec), test_collisions_biome OK ; test_vegetation_biome plante sur `arbre_mort` introuvable (script d'arbres, hors périmètre, fichier non modifié).
- Planches : `captures/sol/planches/*_v3.png` (avant | après, jour en haut, nuit en bas ; gros plans de nuit ; `zone_fondu_v3.png` jour | nuit).
- Défaut restant : en plein jour la brume écrase les rides fines ; à 1,6 m les texels restent gros.

---

## Journal — Lot 5 (pierre et bâtiments), branche `graphisme/lot5-pierre`

Retour utilisateur : « la qualité pourrie des murs, de la pierre et autres, ça fait trop pixélisé, ça fait mal aux yeux ».
Règles ajoutées par l'utilisateur (Lead Technical Artist rétro 32 bits) et `docs/SOCLE_TECHNIQUE.md` § 1-2 : géométrie modulaire sur grille de 1/2/4 m avec éléments porteurs
(poutres, contreforts, plinthes, cadres de porte épais, poteaux octogonaux), 3 niveaux de lecture, texel density uniforme ~16 texels/m, usure et arêtes dessinées,
lumières intégrées dans le budget (au plus 3 locales visibles, pas d'ombre omni, fenêtres chaudes émissives), pièces répétées fusionnées ou en MultiMesh.
Pas d'intérieur de maison (autre agent : `../nordique_kit`), pas de crypte (autre agent : `nordique_lot7`).

### Constat et causes prouvées (captures `captures/batiments/avant/`, planches `captures/batiments/planches/`)
| # | Cause | Preuve |
|---|-------|--------|
| 1 | **Densité de texels incohérente et anisotrope** : `BoxMesh` donne des UV 0..1 PAR FACE, donc une texture de 32 px est étirée sur toute la face, quelle que soit sa taille | Murs de la longue maison (14 × 2,2 m, uv 3 × 0,6) : 6,9 × 8,7 texels/m ; plinthe (14,3 × 0,45 m, uv 2 × 1) : **4,5 × 71 texels/m (étirement ×16)** ; dessous de toit (15,3 × 4,4 m, uv 0,5 × 2) : 1,0 × 14,5 ; menhirs : 32 × 64 ; rochers : sphère à UV ×2, pôles pincés ; bible : 16 partout. Vu dans `gros_plan_pierre_mur.png`, `gros_plan_maison.png` : plinthe en traînées horizontales, murs en gros carreaux |
| 2 | **Bruit « sel et poivre »** : `Palette.texture()` = bruit de valeur quantifié en 4 tons + grain aléatoire (`rng.randf()`), et `pailleter()` pour la neige (pixels blancs isolés) | `outils/stat_textures.gd` : texels isolés **13,96 % (roche), 16,80 % (planches), 12,01 % (écorce), 4,79 % (neige paillettes)** ; amas moyens de 3,5 à 4,9 texels. Après : **0,00 à 0,01 %**, amas de 23 à 431 texels |
| 3 | **Pas de mipmaps** (`filter_nearest` seul) + **mapping affine** (AFFINE 0,55) | Joints et planches « nagent » sur les grands pans et scintillent dès que le texel passe sous le pixel. Cure : mipmaps nearest « vote de couleur » + coordonnées perspective-correctes |
| 4 | **Bugs de géométrie découverts en regardant de près** | (a) la neige des toits était ENFOUIE sous les planches (la normale `rot * UP` regarde vers le bas pour ces rotations) : toits noirs sans neige ; (b) les petites maisons avaient des murs de 1,9-2,0 m pour une porte de 1,95 m : le linteau perçait le toit ; (c) boucliers et lanterne se recouvraient |
| 5 | Fond de palette : tons moyens sombres sans arête ni joint lisible, neige de toit identique au bruit | planches avant/après `planche_V*.png` |

Scintillement (proxy : caméra décalée de 12 cm, part de pixels changés) : S2 jour 13,8 → 15,0 %, S2 nuit 22,5 → 17,9 %, S1 nuit 21,5 → 19,8 % (S1 jour invalide : vue différente). La mesure est dominée par le sol et les arbres :
non concluante, la preuve reste visuelle (planches) ; les mipmaps sont en place.

### Structure des lieux (3 points, règle de l'utilisateur)
**Maisons (longue maison 14 × 7 m de la cheffe, 3 maisons 8 × 5,5 / 8 × 5,5 / 7 × 5 m, murs ≥ 2,3 m)**
- Murs/Structure : plinthe de pierre sèche (saillie 10 cm, dessus à 0,4 m), murs de planches à clin, sablière en saillie, poteaux d'angle, bouts de solives tous les 2 m (grille de 2 m, hors porte), contreforts à (L/2 − 1) sur les longs pans (pierre à petits moellons, chaperon), cadre de porte épais (jambages 0,24 × 2,1 m, linteau 0,3 m), deux marches de pierre, toit à 2 pans (neige de 30 cm, faîtage enneigé, stalactites, cornes), cheminée de pierre, pignons de planches.
- Mobilier : porte debout à bandes de fer et anneau, boucliers peints (cheffe), deux bancs devant la longue maison, tas de bois, tonneaux cerclés de fer, coffres ferrés.
- Éclairage : fenêtres encadrées à vitrage ÉMISSIF dessiné (2 carreaux, tuile 9 × 6 texels, aucune OmniLight), torche murale à flamme émissive à droite de chaque porte ; une seule vraie lumière par maison : la lanterne de la longue maison (celle d'avant), fumée des cheminées.

**Palissade et porte** : rondins hexagonaux à pointes taillées (2 MultiMesh, 329 pieux), deux rubans de corde (liens) à 1,0 et 2,3 m ; porte à poteaux OCTOGONAUX sur socles de pierre, contrefiches, poutre, têtes de dragon, poutre sommitale enneigée ; éclairage : les deux torches du portail (lumières d'avant, maintenant sans ombre et avec fondu de distance).

**Forge** : appentis à 4 poteaux octogonaux, sablières, mur de fond de pierre sèche avec contreforts, foyer + hotte + cheminée en pierre à petits moellons, enclume sur billot (4 pièces), tonneau d'eau, soufflet de cuir, établi avec outils et lingots, lames ; éclairage : foyer (OmniLight d'avant + braises émissives), fumée.

**Place** : puits à 8 pans (margelle, toit enneigé, corde et seau), brasero (socle de pierre, coupe de fer, poteau sculpté octogonal sur socle), enclos (poteaux, lisses, meules de foin, séchoir à peaux de cuir) ; **Cercle / tertre** : pierres du cercle, stèle, menhirs couchés, bordure, rochers et pierres du feu en roche fracturée ; façade du tertre (deux piliers, linteau, dalle) en roche fracturée, butte en neige de toit.

### Réalisation
- **`scripts/textures_bati.gd` (TexturesBati, nouveau)** : toiles d'index (ton, rampe) dans les rampes de la bible, filtre « mode » (aucun texel isolé), RNG propres, tuiles qui bouclent.
  `pierre_seche` (assises de 8-12 texels, pierres de 11-22 dont les joints verticaux ne se superposent pas, joint de 1 texel, arête haute claire, pied dans l'ombre, coins arrondis, fissures, lichen gris-vert, neige dans les joints et en calottes) et sa variante `pierre_fine` (assises de 5-8, pour puits, foyers, marches, contreforts) ;
  `roche_brute` (douze dalles Voronoï périodiques à strates inclinées, joints, arête haute, grain en amas, lichen, neige sur les replats) ; `planches` (planches de 7-9 texels, joint, arête, veines, abouts décalés, nœuds ; version transposée pour le bois debout) ; `fer`, `cuir`, `foin`, `braises`, `fenetre` (9 × 6) ; `neige_toit` (plaques calmes de 2 tons proches, congères) ; écorce de la palissade = celle des arbres (lot 2).
  Mipmaps maison (vote 2×2, à égalité le ton le plus sombre, côtés non carrés permis). Génération ~320 ms au total (headless, mesuré).
- **`shaders/ps1_bati.gdshader` (nouveau)** : même accroche des sommets que `ps1` (grille 135, désactivée dans la passe d'ombre), même neige par l'alpha de sommet, mais coordonnées de texture = position d'OBJET en mètres × échelle de l'instance (triplanaire dur par la normale locale) : 16 texels/m partout, sans étirement sur les boîtes, les sphères déformées ni les MultiMesh à échelle ; `filter_nearest_mipmap` ; pas d'affine ; `uv_maillage` pour les vitrages ; `emission_texture` (l'émission suit la clarté de la texture : fenêtres, braises).
- **`scripts/village.gd`** : toutes les matières remplacées ; **lots fusionnés** (`_ajouter` / `_finaliser`) : un maillage par (pivot, matériau) au lieu d'un MeshInstance3D par pièce (socle technique § 1) ; géométrie et mobilier décrits plus haut ; murs des petites maisons portés à 2,3 m ; toit corrigé (neige au-dessus) ; boucliers et lanterne déplacés ; `_feu` : `shadow_enabled = false`, `distance_fade` 22 + 8 m. Aucune lumière ajoutée.
- `scripts/rochers.gd`, `cercle_runique.gd`, `abords_tumulus.gd` : `Palette.materiau(monde.tex_roche…)` → `TexturesBati.m_roche()` (1 ligne chacun). `scripts/monde.gd` : pierres du feu de camp (1 ligne) et `TexturesBati.vider()` à la fermeture (1 ligne) ; `tex_roche` reste utilisé par le TERRAIN, intact. `scripts/tertre.gd` : seulement `_tumulus()` (façade, dalle, butte) ; la crypte et `_ready` ne sont pas touchés.
- Outils : `outils/captures_bati.sh` + `outils/poses_bati.txt` (V1-V12 : tour du village à hauteur d'yeux ; Z1-Z5 : cercle, tertre, rochers ; T1-T2 : façade du tertre ; D1 : maison ; S* : décalages de 12 cm), `outils/planche_bati.gd` (textures ×4-6 et mosaïques), `outils/stat_textures.gd` (statistiques de bruit).
- **Fichiers partagés** : aucune fonction partagée modifiée (`palette.gd`, `ps1.gdshader`, `sol*.gd`, `arbres.gd`, `tertre.gd` hors façade intacts). `TexturesBati.materiau` lit les membres « privés » `Palette._appliquer`, `Palette._ps1_actif` et `Palette.materiaux` (pour que `--sans-ps1` s'applique aussi à ces matériaux) : ne pas les renommer.

### Résultats
- Planches avant (gauche) | après (droite), jour en haut, nuit en bas : `captures/batiments/planches/planche_<pose>.png` (V1-V12, Z1-Z5, T1, T2, D1), `planche_recap_jour.png` et `planche_recap_nuit.png` ; gros plans `gros_plan_pierre_mur.png`, `gros_plan_maison.png`, `gros_plan_puits.png`, `gros_plan_menhir.png`, `gros_plan_tertre.png` ; textures ×4-6 et mosaïques 3 × 3 : `captures/batiments/textures/planche_textures.png`.
- Perf au feu (`2.5,8.5,16,4`, vsync off, un seul Godot, avant/après alternés) : avant 6,02 / 6,48 ms GPU, après 6,04 / 5,76 ms ; 661 appels de dessin (inchangé), 383 k primitives. Au village (V1) : avant 5,06 / 4,85 ms, 414 / 404 appels ; après 4,98 / 5,38 ms, **275 / 300 appels** (lots fusionnés). Forge (V3) : avant 5,54 / 5,36, après 5,36 / 5,28 (347 → 304 appels).
- Chargement : +~320 ms (mesure headless des matières du lot 5, sans cache), sous les +0,5 s.
- Tests headless : test_quetes (--nouvelle) OK, test_collisions_biome TOUT OK, test_chemin_biome 0 échec, test_vegetation_biome conforme ; en plus test_villageois OK et test_marche_pnj OK.

### Défauts restants
- À 1,6 m de distance un texel de pierre ou de planche fait ~13 px du rendu 480 × 270 (densité 16 texels/m de la bible) : plus net et lisible qu'avant, mais toujours « gros pixels » en gros plan ; une couche proche à 32 texels/m (comme le sol, lot 3) n'a pas été faite.
- Les 7 pierres du cercle, la stèle et les menhirs restent des boîtes à neige en calotte (`boite_neige`) : silhouette inchangée ; la roche fracturée donne des dalles lisibles mais un peu « pavage » en gros plan.
- Les pièces répétées du village (contreforts, marches, poteaux, lisses) sont fusionnées par bâtiment et par matière (pas en MultiMesh) ; les arbres morts des abords du tumulus restent des MeshInstance isolés (dette connue du socle technique).
- La neige de toit a une période de 8 m (répétition discrète sur la longue maison) ; les stalactites sont des pyramides plates, bleutées.
- Jour : le bois (rampe « bois travaillé » désaturée à 0,78) reste un peu plus chaud que le reste de la scène ; de nuit, l'ombre portée des contreforts est dure.
- La mesure de scintillement par décalage de caméra n'est pas concluante (voir constat).

## Journal — Lot 5, 2e passe « réalisme 32 bits » (maisons, village, façade du tertre, pierres du cercle), branche `graphisme/lot5-pierre`

Retour utilisateur du 2026-10-20 : « c'est beau mais ça fait un peu DESSIN D'ENFANT ; pousse plus loin les traits, la PROFONDEUR, pour quelque chose de plus RÉEL, toujours en 32 bits » (arbres et sol : intouchés).
Cible : Thief / Silent Hill / Daggerfall / King's Field IV (textures photo réduites et retouchées). Demande complète : `/tmp/realisme_32bit.md` (5 pistes : tons, profondeur peinte, profondeur géométrique, arêtes, lumière).

### Diagnostic (lot 5 initial)
Rampes à 4-5 tons posées en amas (« coloriage »), murs = boîtes de planches lisses, plinthe = une boîte, toit = deux dalles plates, menhirs et façade = boîtes, aucune occlusion, aucun relief sous la lumière.

### Structure des lieux (3 points)
**Maisons (4, murs de 2,3 m, 9 lits de rondins)** : Murs/Structure : soubassement de pierres brutes chanfreinées en saillie de 2 à 15 cm (dessus à 0,38-0,5 m) sur remplissage en retrait, murs de rondins de 30 cm à 8 pans empilés tous les 25 cm (lits alternés : bouts de 28 cm qui se croisent aux angles, bouts visibles à cernes, affaissement de 2 cm par rondin) sur une âme sombre, 4 contreforts de moellons à chaperon, cheminée en petits moellons avec chaînages d'angle alternés et chapeau enneigé, toit à épaisseur (planches, chevrons tous les 90 cm qui dépassent, dalle de neige de 18-26 cm à bord irrégulier, lèvre de tourbe sombre, rives en cornes, faîtière en rondin dont les bouts sortent des pignons + rouleau de neige, stalactites), pignons de planches debout. Mobilier : porte de planches debout dans l'ouverture des rondins (1,2 × 2 m) avec cadre épais, bandes de fer rivetées, anneau, deux marches de 20 cm, fenêtres à linteau/appui en pente/jambages/meneau/volet entrouvert, boucliers, bancs, torche. Éclairage : inchangé (vitrage émissif, torche murale, une OmniLight, fumée).
**Forge** : poteaux octogonaux, toit à une pente en dalle de neige, mur de fond et contreforts en piles de moellons, foyer, hotte et cheminée en moellons. **Puits** : margelle de 22 moellons en deux rangs, toit à deux pans en neige. **Porte du village / brasero** : socles en blocs irréguliers. **Enclos** : poteaux à 8 pans.
**Cercle et façade du tertre** : pierres levées taillées (7 anneaux, section irrégulière, fût effilé et penché, pointe asymétrique, neige sur la pointe) ; stèle à faces ±Z planes (runes plaquées) ; façade (`FacadeTertre`) : deux pierres levées + assises de calage, linteau en gros bloc enneigé, cales, dalle de porte enfoncée, seuil ; collisions d'origine.

### Réalisation
- **`scripts/peinture_bati.gd` (PeintureBati, nouveau)** : chaque matière est d'abord un CHAMP DE HAUTEUR (pierres bombées aux joints creux et irréguliers, éclats facettés, rondins fibreux à fentes de séchage et nœuds, planches à chanfrein et clous, facettes de granite de Voronoï déformées…), éclairé par une lumière rasante (haut gauche), avec OMBRES PORTÉES (marche de 8 texels), OCCLUSION AMBIANTE (hauteur − hauteur floutée), dégradé haut clair / bas sombre dans chaque pierre, clarté et teinte propres à chaque pierre / planche, coulures, lichen gris-vert et ocre, neige sur les replats et dans les calottes, puis lu dans une rampe de 12 tons avec tramage de Bayer d'amplitude 0,55 ton. Produit aussi une carte de RELIEF (gradient de hauteur). Textures CUITES hors ligne (`outils/cuire_bati.gd` → `assets/bati/*.res`, mipmaps « vote de couleur » 2×2 : aucune couleur nouvelle) ; chargement de 14 matières : **128 ms** (le lot 5 initial en demandait ~320 ms de génération).
- **`shaders/ps1_bati.gdshader`** : 32 texels/m (tuiles ×2 en résolution : pierre 256 × 128 = 8 × 4 m), **couche proche** : chaque cellule de 1/16 m choisit par seuil de bruit (tramage, comme le sol du lot 3) entre le niveau 0 (32 texels/m) et le niveau 1 (16 texels/m) selon la distance (plein détail < 3 m, 16 texels/m > 10 m) ; `tex_relief` penche la normale (on ajoute à la normale du moteur le décalage du relief : juste même sous échelle non uniforme) → le soleil bas et les torches sculptent la pierre ; `uv_metres` (rondins) ; couleur de sommet = occlusion peinte.
- **`scripts/bati_geo.gd` (BatiGeo, nouveau)** : `bloc` (chanfreiné, 24 sommets irréguliers, facettes plates, neige au dessus), `pierre_levee` (7 anneaux × 8), `rondin` (octogone, fût + bouts), `dalle_neige` (grille bosselée, faîte qui ondule et s'affaisse, lèvre d'égout et rives à bord irrégulier, tourbe dessous). Normales plates (facettes franches) sauf la neige (lissée).
- **`scripts/village.gd`** : `_ajouter` porte les couleurs de sommet et applique une OCCLUSION DE PIED à tout ce qui touche le sol (0,66 → 1 sur 0,8 m) ; nouvelles fonctions `_maison` (refaite), `_soubassement`, `_murs_rondins`, `_toit`/`_pan`, `_cheminee`, `_fenetre_cadre`, `_bloc`, `_rondin`, `_pile` ; forge, puits, porte, brasero, enclos améliorés. Lots fusionnés conservés.
- **`scripts/textures_bati.gd`** : réécrit (chargement des textures cuites, mêmes noms `m_*` + `m_rondins`, `m_bout_rondin`, `m_tourbe`, `m_glace`) ; les anciens générateurs d'amas sont supprimés.
- `scripts/facade_tertre.gd` (nouveau) ; `scripts/tertre.gd` : seul `_tumulus()` (façade → 1 appel, quad des runes avancé de 5 cm) ; `scripts/cercle_runique.gd` : `boite_neige` réécrit (même signature + `plat`), utilisé aussi par `abords_tumulus.gd` (borne, bordure).
- Outils : `outils/cuire_bati.gd` (cuit les textures + aperçus dans `captures/batiments/textures_v2/`), `outils/mesure_chargement_bati.gd`, poses G1-G8 (gros plans à 1,5 m et 4 m : mur, soubassement, angle, avant-toit, porte, menhir) et T3-T4 dans `outils/poses_bati.txt`, `captures_bati.sh` passe maintenant `--nouvelle`.

### Nouvelles rampes (bible §2 étendue : on garde les teintes, 12 tons par matière, ombre froide et violette → lumière chaude)
Clés interpolées linéairement en 12 tons (dans `PeintureBati`) ; la rampe de la bible reste le squelette (ses 5 tons y figurent).
| Rampe | Clés (ombre → lumière) |
|---|---|
| Pierre froide | `#12141d #1e2230 #2c3145 #3f455c #565c73 #6f758a #8a8d9e #a3a5af #bbbab9` |
| Pierre chaude | `#16141a #242024 #383037 #4f434a #67595d #826f6d #9d8b85 #b7a89f` |
| Pierre verdâtre | `#11161a #1c2429 #2b373b #3f4e4f #566763 #6f8077 #8c9a8d #a7b0a2` |
| Lichen gris-vert / ocre | `#10191a … #97a88f` / `#2a1e20 … #cba66f` (7 clés) |
| Neige (12 tons) | `#3a4469 #4a557f #5d6a95 #6877a3 #7b8bb3 #8898bf #99a9cb #aab8d6 #bcc8e1 #cdd7ec #e0e6f2 #f0eff4` |
| Bois | `#150d10 #2b1a1e #3a2320 #472a21 #58361f #6a4229 #7e4f31 #92613a #a87546 #bb8a53 #cca066` ; gris argenté `#14151b … #a9a4a6` (mélangé planche par planche) |
| Fer / rouille | `#12151c … #bcc6d8` (10 clés) / `#2a1a1e … #b0662f` |
| Chaume / tourbe | `#16130f … #c9b574` (11 clés) / `#0f0d0f … #6e5f4e` |
| Cuir, braises | `#140c10 … #9b7347` ; `#2a0e12 … #fff0a8` (10 clés) |

### Réglages et pièges
- Une jointure creuse trop large (rayon du biseau, AO fort) donne des « contours épais » : AO ramené à 0,6 × (hauteur − flou), ombre portée à 0,1, joints de 0,3-0,75 texel de demi-largeur. Les textures contiennent du GRAIN (tramage, ±1 ton) : `stat_textures` annonce ~25 % de texels « isolés » (c'était 0 % au lot 5 initial) ; c'est voulu (texture photo réduite), mais c'est le point à surveiller si le « sel et poivre » revient dans les retours.
- Neige : ne pas mettre de calotte sur chaque pierre (effet zèbre) : 12 % de la pierre sèche, 6 % de la fine.
- Les captures doivent passer `--nouvelle` (sinon la sauvegarde rechargée fausse les poses).
- `Palette._appliquer`, `Palette._ps1_actif`, `Palette.materiaux` toujours lus par `TexturesBati.materiau` : ne pas les renommer.

### Résultats
- Planches avant (1fff394, à gauche) | après (à droite), jour en haut, nuit en bas : `captures/batiments/planches/planche_<pose>_v2.png` (V1-V12, D1, T1-T4, Z1-Z5, gros plans G1-G8 : mur à 1,5 m / 4 m, soubassement, angle croisé, avant-toit, porte, menhir à 1,5 m / 4 m) ; récapitulatifs `planche_recap_jour_v2.png` et `planche_recap_nuit_v2.png` (paires avant | après des 12 poses) ; « après » brutes dans `captures/batiments/apres_v2/`, « avant » dans `captures/batiments/base1fff/` ; textures cuites en aperçu (×2, zoom ×6) dans `captures/batiments/textures_v2/`. Outil : `outils/planches_bati_v2.sh`.
- Perf (machine très chargée par d'autres Godot : TOUS les chiffres sont ~3 × le niveau habituel, avant et après alternés pour la comparaison) : feu `2.5,8.5,16,4` vsync off, avant 22,5 / 25,8 ms GPU, après 19,7 / 23,0 ms ; 661 → 679 appels de dessin ; 383 k → 385 k primitives. Village V1 : avant 17,6 / 21,0, après 18,3 / 21,3 ms ; 284-289 → 294-298 appels ; 347-354 k → 418-423 k primitives (+20 %). Forge V3 : avant 23,6 / 19,2, après 19,1 / 23,4 ms ; 297 → 318-322 appels ; 374 k → 467 k primitives (+25 %). Le coût en images est dans le bruit de mesure (< 8 ms habituel : à re-mesurer sur machine au repos) ; le surcoût mesurable est géométrique (≈ +70 000 à +90 000 triangles dans le village : rondins, pierres, dalles) et 4 textures par pixel dans le shader.
- Chargement : 14 matières cuites chargées en **128 ms** (headless, `outils/mesure_chargement_bati.gd`) contre ~320 ms de génération au lot 5 initial : −190 ms.
- Tests headless : `test_quetes -- --nouvelle` OK, `test_collisions_biome` TOUT OK, `test_chemin_biome -- --paisible` 0 échec, `test_vegetation_biome` conforme, `test_villageois` OK.

### Défauts restants
- Le grain (tramage ±1 ton) donne ~25 % de texels « isolés » : à surveiller (retour « sel et poivre » du lot 5). Les blocs de pierre brute vus à 1,5 m restent bruités (« camouflage ») : la tuile de 4 m ne contient que trois facettes.
- Les contours des arbres, le sol, les personnages sont ceux d'avant : le village est maintenant plus réel que son entourage immédiat (rochers du sous-bois = sphères aplaties, palissade = rondins hexagonaux de l'écorce du lot 2).
- Vitrages : 18 × 12 texels, deux carreaux émissifs plats ; boucliers (cuir) en disques à bossage sans relief propre ; tonneaux, caisses et bancs gardent leurs boîtes/cylindres (non refaits).
- Les rondins se traversent aux angles (pas de vraie encoche) ; les pignons sont des triangles de planches debout sans chevrons visibles.
- La neige des toits répète à 8 m (tuile 256 × 256) ; les stalactites sont toujours des pyramides plates.
- Mesure de perf non concluante en valeur absolue (voir plus haut) ; à refaire machine au repos.

## Journal — Lot 7a (intérieur de la crypte), branche `graphisme/lot7-crypte`

Retour utilisateur : « l'effet de lumière dans le tombeau est raté », « murs et pierre trop pixélisés, ça fait mal aux yeux ».
Règles ajoutées par l'utilisateur (modules 1/2/4 m, Macro/Méso/Micro, texel density uniforme, edge highlighting, lumières courtes) et
`docs/SOCLE_TECHNIQUE.md` § 2 (aucune ombre omni, 4 à 6 lumières par salle, `distance_fade`, fusion des pièces répétées) appliqués.

### Diagnostic (avant : `captures/crypte/avant/`)
1. **Densité de texels incohérente et étirée** : murs et sol étaient des `BoxMesh` dont les UV couvrent chaque face de 0 à 1, avec une
   texture de 32 px × `uv_echelle` 2 : un mur de 14 m x 4,6 m portait 64 texels sur 14 m (4,5 texels/m) et 64 sur 4,6 m (14 texels/m),
   soit des pixels de 22 cm étirés en bandes, 3 à 10 fois plus gros que le bois ou le fer voisins (la herse, elle, était à 40 texels/m).
2. **Mapping affine (`affine` 0,55) sur de grands quads** : chaque grand mur se tordait en « éclats » triangulaires ; l'accroche des sommets à
   la grille de 135 lignes faisait trembler les arêtes.
3. **Textures = bruit quantifié** (`Palette.tex`, 32 px, 4 tons) sans joints ni arêtes : du sel et poivre bleu nuit ; **aucune mipmap** dans
   `ps1.gdshader` (`filter_nearest`) : scintillement dès qu'on s'éloigne.
4. **Contraste nul** : pierre #1c1f26…#3f4553 (albédo 0,1 à 0,25) sous un ambiant bleu 0,26/0,32/0,48 : aucune différence de ton lisible, 32 niveaux
   + tramage Bayer 4x4 pleine force qui grésille dans le sombre.
5. **Lumière ratée** : seules flammes bleues (particules additives molles, HDR > 1 donc blanches et baveuses), brasero en cylindre de 7 pans,
   `glow` actif (bavure), halo nul, pas de lumière chaude : tombe, couloirs et salle = noir uniforme ; la torche du joueur (grosses particules
   additives en carré sans glow, fumée en blocs gris) faisait une tache blanche carrée.
6. Décor : boîtes nues (piliers carrés, niches = dalles plates), escalier de l'entrée qui bouchait la vue (et aucun mobilier, aucun objet).

### Réalisation
Fichiers nouveaux : `scripts/crypte_textures.gd`, `scripts/crypte_decor.gd`, `shaders/crypte.gdshader`, `shaders/crypte_flamme.gdshader`,
`outils/captures_crypte.sh`, `outils/planche_crypte.gd`, `outils/test_crypte.gd`. Modifiés : `scripts/tertre.gd` (la construction de la crypte est
réécrite ; façade et butte du tumulus INCHANGÉES : `_tumulus`, `m_pierre`, `m_dalle`, `_boite` intacts), `scripts/monde.gd` (voir « Fichiers partagés »).
Aucune fonction de `palette.gd` n'est touchée.
- **Textures** (`CrypteTextures`) : amas de pixels, pas de bruit. Pierre en assises de 0,5 m (blocs 0,75 à 1,5 m, joints décalés), joint sombre de 1 px,
  arête haute et gauche claires, ombre basse, coins épaufrés, amas de relief, fissures en escalier, mousse sur les arêtes hautes, coulures de salpêtre
  (3 variantes de mur : sain, mousse + salpêtre, humide) ; dalles de 1 m (biseau, usure au centre, poussière dans les joints, tuile de 8 m) ; voûte en
  petites briques suiffées ; planches de bois avec fil, nœuds, clous ; fer riveté + rouille ; lame rouillée ; gravure runique (cadre, frises, serpent) ;
  argile à frise ; os ; parchemin ; toile d'araignée (alpha) ; atlas de flamme 4 images ; halo à 4 anneaux posterisés ; rai de lumière en paliers.
  Rampes de la bible (pierre bleu-gris, mousse, salpêtre, bois, fer), glissement de teinte conservé. **Densité : 32 texels/m pour la pierre** (K = 2 : tuile
  de mur 128 px = 4 m, dalles 256 px = 8 m) et 32 texels/m pour le bois/fer/objets : dans un couloir de 2,6 m on voit la pierre à 1-1,5 m, où 16 texels/m
  font des pixels de 8 px d'écran ; écart à la bible (16 texels/m) justifié par ce point de vue, et uniforme dans toute la crypte.
  Mipmaps « nearest » par vote de couleur 2x2 (peintes en fils d'exécution, `WorkerThreadPool`, pendant que le plan se construit).
- **Shader `crypte.gdshader`** : `filter_nearest_mipmap`, UV en mètres/tuile, perspective correcte (`affine` 0), accroche des sommets au PIXEL du rendu
  (grille 270 : plus de tremblement), bande de crasse au pied des murs en 3 paliers (pas de dégradé).
- **Géométrie** (`CrypteDecor`) : quads par morceaux ≤ 4 m, UV = position monde / tuile ; fusion par cellule de 8 m et par matériau (une quarantaine de
  maillages, culling par cellule, < 8 lumières par maillage) ; embrasures, cadres de porte, plinthes et corniches ; collisions d'origine refaites à
  l'identique (sol, plafond, murs, linteaux, piliers, estrade, sarcophage, herse).
- **Éclairage** : sprites de flamme pixel art animés (MultiMesh par cellule, 9 images/s), halos de mur et flaques de sol (cartes additives à anneaux nets),
  `OmniLight3D` courtes et fortement atténuées (appliques 4,2-5,5 m, braseros 5,8 m), `shadow_enabled = false`, `distance_fade`, vacillement à trois
  fréquences + tirage par pas de 1/12 s ; `glow` coupé sous terre, ambiant 0,95 bleu-gris, brume 0,028, tramage du post-traitement ramené à 0,45 sous
  terre ; flaque et rai de lumière froids (tombeau, salle des piliers) ; `crypte.visible = false` tant qu'on est dehors (ni rendu ni lumières).
- **Torche tenue** : sous terre uniquement, ses particules (cœur, corps, langues, fumée) sont masquées et remplacées par le même sprite de flamme ; dehors, rien ne change.

### Description par lieu (Murs/Structure · Mobilier · Éclairage)
- **Entrée** (6 x 10 x 3,6 m) : assises de pierre, plinthe, corniche, cadre épais de la porte nord, 4 poutres de bois ferrées, escalier de 4 marches contre le mur sud avec
  passage sombre encadré (décor) · urnes, ossements, épée rouillée, toiles aux 4 coins · 2 braseros + 2 appliques (4 lumières).
- **Couloir des niches** (3,2 x 12 m, 3 m) : 3 arches brisées (ogives) sur pilastres, 4 niches à encadrement épais, tablette, crâne et urne · armes, ossements, toiles · 2 appliques.
- **Salle des piliers** (14 x 14 m, 4,6 m) : 4 piliers OCTOGONAUX (base et chapiteau évasés, bague), arcs doubleaux dans les deux sens, 4 contreforts engagés, voie
  processionnelle gravée (modules de 4 m), oculus au plafond · 2 sarcophages gravés, coffre ferré, urne, tas d'os, armes, crânes · 3 braseros + 2 appliques avec lumière
  (+ 2 appliques sans lumière) + flaque et rai froids (6 lumières).
- **Alcôve d'Eirik** (4 x 4 m) : murs humides · table (parchemin, plats d'étain), étagère (rouleaux, grimoires, urne), coffre ferré, arme, ossements · bougie sur la table
  + applique (2 lumières).
- **Couloir de la herse** (3,2 x 10 m) : 4 poutres, herse et levier (maillages UV en mètres) · prisonnier (os), arme, 2 urnes · 1 applique.
- **Tombeau** (16 x 16 m, 6 m) : 4 piliers octogonaux de 6 m, arcs surbaissés, 4 contreforts, voie gravée, estrade (collision d'origine) à marche, sarcophage à soubassement
  et couvercle gravé (bande runique cyan inchangée), oculus + rai et flaque cyan · 2 urnes, 2 crânes sur l'estrade, ossements, armes · 2 braseros + 2 appliques avec lumière
  (+ 2 sans) + lueur froide du sarcophage (portée 14 → 10 m) : 5 lumières.

### Fichiers partagés touchés (à signaler au fusionneur)
- `scripts/monde.gd` : `_sous_terre` (ambiant, brume, glow, tramage du post), `--cpose=x,z,lacet,tangage` + `--torche-eteinte` dans le scénario `crypte` (le drapeau
  `--sans-torche` ne marchait pas : voir plus bas), `--crypte=x,z,lacet,tangage` (descend dans la crypte hors capture, pour les mesures), position/vue joueur dans le journal FPS de capture.
- `scripts/tertre.gd` : tout le bloc « crypte » (hors `_tumulus` et `_boite`) ; `m_poutre` et `m_fer` restent déclarés mais ne servent plus.
- Aucun changement à `palette.gd`, `ps1.gdshader`, `torche.gd`, `mains.gd`.

### Outils et pièges
- `bash outils/captures_crypte.sh <dossier> [poses]` (12 poses, torche et torche éteinte), `outils/planche_crypte.gd` (textures x6/x8 dans `captures/crypte/textures/`),
  `outils/test_crypte.gd` (rayons le long du chemin, sol, herse).
- PIÈGE capture : sans `--nouvelle`, la sauvegarde (herse levée, position) est rechargée au 2e lancement et fausse les poses ; toujours `--nouvelle`. Les captures « avant » sans torche
  de `captures/crypte/avant/` (prises avec l'ancien drapeau) sont parfois à la mauvaise pose : ne comparer que les colonnes « torche ».
- `captures/` est ignoré par git : planches seulement sur disque (`captures/crypte/planches/avant_apres_<pose>.png`, `recap_avant_apres.png`).

### Perf et chargement
- Crypte, GPU (`mesure_perf.gd --crypte=…`, vsync off) : 1,12 ms (salle, 272 appels, 36 k primitives), 1,21 ms (tombeau, 116 appels), 1,24 ms (retour vers l'entrée, 146 appels) : très en dessous de 8 ms.
- Feu `2.5,8.5,16,4` (vsync off) : 6,01 ms GPU, 661 appels, 383 k primitives (la crypte masquée dehors ne coûte plus rien).
- Chargement : `_construire_crypte` 390-420 ms au total dont ~250 ms d'apparition des 7 draugrs et du corps d'Eirik (inchangé) ; surcoût du décor ≈ 150 ms (textures peintes en parallèle).

### Tests
`test_crypte` TOUT OK (14 segments du parcours dégagés à 0,5 et 1,4 m, sol à y=0 sous chaque point, herse baissée bloquante, 67 collisions) ; `test_quetes -- --nouvelle` OK ;
`test_collisions_biome` TOUT OK ; `test_dragon_monde` OK ; `test_sauvegarde` écrire/vérifier OK.

### Défauts restants
- À 1-1,5 m d'un mur le texel (3 cm) fait encore ~4 px d'écran : ce sont de vrais pixels, mais nets et ordonnés (plus de bandes ni d'étirement).
- Le tombeau reste très bleu-nuit en dehors des appliques : le sarcophage n'a pas de lumière chaude propre ; les gardiens debout sont figés en T sous `--paisible`.
- Les appliques vues de loin se lisent comme un anneau orange à centre sombre (la torche) ; le halo est volontairement discret.
- Sprite de flamme et lumière de la torche tenue : seulement sous terre (le lot 6 refera la torche partout).
- Pas de collision sur la plupart des petits objets (urnes, os, armes) : on les traverse ; seuls sarcophages, coffres, contreforts et piliers sont solides.

### Lot 7a, 2e passe — « réalisme 32 bits » de la crypte (retour : « ça fait dessin d'enfant »)
Planches : `captures/crypte/planches/avant_apres_<pose>_v2.png` (avant = 1fff394 | après) et `recap_avant_apres_v2.png`.
- **Textures** (`crypte_textures.gd` réécrit) : chaque matière naît d'une carte de hauteur (joints creux, biseau arrondi, ondulation, éclats, fissures)
  d'où l'on tire l'albédo (éclairage peint haut-gauche, AO de joint, ombre portée d'une pierre sur sa voisine, dégradé haut clair/bas sombre dans chaque pierre,
  teinte par pierre entre rampe froide et chaude, coulures, salpêtre, mousse) et une carte de pentes. Rampes ÉTENDUES, interpolées puis quantifiées à 26 niveaux
  par tramage 4x4 : `PIERRE_FROID`/`PIERRE_CHAUD`/`PIERRE_SOMBRE_F` (10 tons), `BOIS` (10), `FER` (8), `MOUSSE`/`SALPETRE` (6), `OSSE`/`ARGILE`/`PARCHEMIN` (6), `ROUILLE` (5).
  Toujours 32 texels/m ; la dalle passe à une tuile de 4 m (128 px) pour tenir le temps de peinture. Mipmaps : égalité du vote 2x2 départagée vers la moyenne.
- **Shader `crypte.gdshader`** : `tex_nm` + `relief` perturbent la normale dans un repère déduit de l'axe dominant de la face (sans tangentes) : la torche en rasant
  sculpte joints, dalles, gravures. Pied de mur en dégradé lisse ; AO des coins, du haut des murs et du bord des sols cuite dans les couleurs de sommet (`plan_v`, `plan_h`).
- **Géométrie** (`_relief_mur`) : soubassement en deux assises de profondeur irrégulière, corniche à trois ressauts sur corbeaux, pierres d'assise en saillie.
- **Lumière** : ambiant sous terre moins saturé (0,40/0,45/0,62 ; `monde.gd`), lueur du sarcophage froide, basse, devant lui (rase les flancs), halo d'applique en
  dégradé sans centre sombre et décollé du mur, flammes d'appliques plus grandes.
- **Test** : `test_crypte.gd` exclut les CharacterBody3D (draugrs/PNJ selon la sauvegarde) ; la cause était un vivant sur le parcours, pas un défaut du décor.
- **Défauts restants** : coût de chargement de la crypte à mesurer au calme (peinture ~120 ms par texture de pierre en parallèle, mesures faussées par d'autres Godot) ;
  joints du sol encore marqués en rasant ; le tombeau reste froid hors des braseros ; pas de nervures de voûte en relief supplémentaires.

#### Lot 7a, 2e passe — corrections (v3)
- **Murs « disparus » (aplat noir sur un tiers de l'image)** : l'accroche des sommets du shader divisait par `clip.w` ; un sommet proche du plan de la caméra
  (w ≈ 0, rendu fréquent depuis que les murs sont découpés tous les 0,7 m pour l'AO cuite) part dans le décor et emporte le pan. Correctif : pas d'accroche si `clip.w <= 0,6`.
- **Pixel art net** : grain de pierre en amas de ~3 texels (bruit sans lissage, posterisé), biseau en 3 marches, joints de 1 à 2 texels sombres avec lèvre claire
  nette côté éclairé, rampes conservées (10 tons). Le tramage 4x4 de Bayer (interdit par la bible) est remplacé par une quantification à 18 niveaux avec tirage
  de bruit seulement près des seuils.
- **Chargement** : textures précalculées dans `assets/crypte/*.res` par `outils/generer_crypte.gd` (albédo avec mipmaps + `_nm`), chargées si `CrypteTextures.VERSION`
  correspond, sinon recalculées (repli). Après toute modif de `crypte_textures.gd` : incrémenter `VERSION` puis relancer l'outil.
- **GPU** : mesuré à conditions égales (3 à 4 Godot ouverts) : 1fff394 = 3,83 ms, après = 4,35 à 4,5 ms (salle) ; le 1,1 ms du premier lot datait d'une machine au calme.

## Journal — Grotte vitrine, branche `graphisme/grotte`

Grotte de ~124 m (parcours entrée → fond), construite à la demande sous le monde (origine `POS_MONDE = (20, -220, 100)`), **sans entrée câblée** dans le monde. Nouveaux fichiers : `scripts/grotte.gd`, `scripts/grotte_decor.gd` (étend `CrypteDecor`, non modifié), `scripts/grotte_textures.gd`, `shaders/grotte.gdshader`, `outils/test_grotte.gd`, `outils/captures_grotte.gd|.sh`, `outils/planche_grotte.gd`.

### Principe
- Un TUBE fermé : anneaux de 18 sommets le long d'une ligne médiane (cap + altitude en terrasses), facettes plates, couleur de sommet : rgb = AO peinte, a = masque de recouvrement (neige / glace / mousse) comparé au seuil stocké dans l'alpha de la texture de recouvrement. Aucune fuite de ciel possible (test d'étanchéité par rayons).
- Collisions : trimesh de la coque (4068 triangles) + cylindres/boîtes pour les accessoires (81 formes).
- Textures 128 px = 4 m (32 texels/m), rampes de 8-12 tons (roche, strate, sol, neige, glace, mousse, cristal, peau, paille, bois via la crypte). Épaulement/AO peints, arêtes discrètes.
- Lumières : OmniLight courtes, sans ombre, 19 au total, 4-6 par salle, `distance_fade`. Chaud au camp, vert mousse / bleu glacier ailleurs ; cristaux émissifs ; rai de lumière oblique par la faille ; jamais de noir total.

### Description en trois points, par lieu
**1. Pente d'entrée** — Murs/Structure : pente de neige soufflée entre deux parois, lèvre de roche, ciel peint fermant l'entrée (carte « jour » non éclairée). Mobilier : rochers, cailloux, quelques sapins en fond. Éclairage : jour froid bleuté, flocons.
**2. Boyau** — Murs : tube étroit en facettes, roche humide et mousse, étais. Mobilier : crâne sur pique, cailloux. Éclairage : vert mousse faible, lueur bleue au loin.
**3. Grande caverne / lac gelé** — Murs : voûte haute avec faille au plafond fermée par une bande émissive, lac gelé (`LAC_Y = -4.7`), colonnes, stalactites/stalagmites repères. Mobilier : blocs de glace, cristaux en grappes sur les sommets d'anneau. Éclairage : bleu glacier, rai oblique, flaque lumineuse au sol.
**4. Galerie à strates** — Murs : strates marquées, marches naturelles, ruptures de pente (≤ 27,8°), boisage. Mobilier : caisses, os. Éclairage : torches chaudes éparses, bleu sourd.
**5. Camp de bandits** — Murs : salle élargie, roche nue au goulet. Mobilier : feu de camp (MultiMesh), couchages, caisses, tonneaux, râtelier d'armes, coffre ouvert, butin (pièces, sacs), crânes. Éclairage : feu orange vacillant + torches, ambiance chaude.
**6. Fond de cristaux** — Murs : cul-de-sac à cristaux bleu glacier. Mobilier : grappes de cristaux. Éclairage : émission des cristaux.

### Lignes partagées touchées : `scripts/monde.gd` (+19 lignes)
- `var grotte: Node` et `_aller_grotte(pose)` (crée la grotte, `_sous_terre(true)`, `grotte.ambiance(_env)`, place le joueur).
- `_ready` : après `_aller_crypte()`, `--grotte=s,décalage,lacet°,tangage°` (hors `--capture`).
- `_scenario` : cas `"grotte"` (`--scenario=grotte --gpose=…`).
- Convention : lacet positif = tourner à gauche ; `s` = mètres le long du parcours (0-124).

### Pièges
- Le joueur est borné à `LIMITE = 108` : l'origine de la grotte doit rester dans ±108 (d'où x=20, z=100).
- `captures/` est ignoré par git : les planches (`captures/grotte/planche_*.png`, `textures/`) n'existent que sur disque.
- `GrotteDecor` dépend des internes de `CrypteDecor` (`_buf`, `_tri`, `quad`, `TUILE`, `mat`, `_mats`…) : si la crypte est refactorée, vérifier `test_grotte`.
- Outils : `outils/captures_grotte.gd` (multi-poses, `--mains`, `--x2`), `outils/test_grotte.gd`.

### Mesures (indicatives, 3 autres agents actifs)
- Construction : ~890 ms à vide (15 141 facettes, 112 anneaux).
- Fenêtre, vsync off : caverne (s=50) GPU 0,94 ms, 170 appels, 20 544 primitives ; camp (s=100) GPU 0,86 ms, 121 appels, 13 440 primitives (budget 8 ms).
- Test : étanchéité 4480 rayons, 0 sans impact ; capsule arrive au fond en 30,5 s ; `test_quetes -- --nouvelle` OK.

### Défauts restants
- Léger halo bleu (« portail ») au goulet du camp ; bruit « fourrure » sur la voûte de la caverne ; couchages bas ; blocs de texels visibles à 1-1,5 m des parois ; petits accessoires sans collision ; monochromie bleue au fond ; plaques de neige un peu « camouflage » ; motif en étoile au bouchon de fin ; construction synchrone (~1-2,7 s sous charge), à passer en thread si l'entrée est câblée.

### Grotte vitrine — 2e passe (pixel art net, textures précalculées)
- **Roche** (`GrotteTextures.roche_image`, 3 variantes : ardoise, gris, **roche givrée** pour l'entrée) : réécrite en aplats. Grandes facettes (~1,5 m) d'UN ton, bancs horizontaux décalant le ton d'un cran, fractures de 1 px (ligne sombre, lèvre claire / creux sombre), amas d'éclats ; plus aucun grain. 10 tons utilisés de 1 à 8. Fini le bruit « fourrure ».
- **Neige** : couleurs et rides du sol du lot 3 (`SolTuiles.tuile_neige`, dépendance : le lot 3 doit être présent). Deux textures : `neige` (parois ; seuil en BANCS horizontaux : la neige s'accroche en haut des strates) et `neige_sol` (plaques irrégulières, tons resserrés). Glace et mousse utilisent le même seuil en bancs. Le shader `grotte.gdshader` n'a plus que deux niveaux (net / pas de demi-teinte).
- **Entrée** : congères basses (`GrotteDecor.congere`, sans collision, ≤ 0,5 m) à la place des gros blocs lisses ; parois de roche givrée. Vue vers l'extérieur : brume blanche de tempête (rubans de vent par paliers, masses lointaines à peine visibles) au lieu des sapins plats.
- **Goulet du camp** : portique de bois + rideau de peaux à deux panneaux décalés (sans collision) : il ferme la vue sur le bleu des cristaux (le « portail »). La pose `fond` est maintenant à s = 112,5.
- **Camp** : couchages sur châlit (0,6 m, collision recalée). **Fond** : bouchon en anneaux concentriques décalés (plus d'étoile), AO uniforme. **Cristaux** : 4 familles de couleurs (bleu, cyan, violet froid, blanc), bandes obliques nettes, arêtes claires, reflets d'un pixel ; teintes de sommet cyan/violet.
- **Précalcul** : `outils/generer_grotte.gd` écrit `assets/grotte/*.res` (18 images avec mipmaps, ~255 Ko). `GrotteDecor` les charge si elles existent et repeint dans des fils sinon (repli). **Relancer l'outil après toute modif de `grotte_textures.gd`** : `godot --headless --path . --script res://outils/generer_grotte.gd`. Construction de la grotte : ~890 ms → ~275-520 ms (le reste est le maillage, inchangé).
- Mesures (fenêtre, vsync off) : s=50 GPU 0,89 ms, 171 appels, 21 017 primitives ; s=100 GPU 0,85 ms, 101 appels, 11 256 primitives. Tests : `test_grotte` (étanchéité 4480 rayons, capsule au fond en 30,4 s), `test_quetes -- --nouvelle`, `test_collisions_biome` : OK.
- Planches : `captures/grotte/planche_v2_*.png` (avant = 9ce611e sans mains | après avec mains/torche), `planche_v2_montage.png`.
- Défauts restants : les parois de glace gardent des « éclats » de fissure blancs un peu rayés ; bruit de bancs encore perceptible en très gros plan ; mousse du boyau encore vive ; le sol de neige à l'entrée garde un aspect de mosaïque de plaques (même rendu que le terrain) ; le rideau se traverse sans collision.

### Lot 2, troncs (« réalisme 32 bits » des fûts et grosses branches)
- `scripts/ecorces.gd` (`Ecorces`) : 8 tuiles 64² = 2 m (32 texels/m) : `epicea|pin|bouleau|mort` × `haut|pied`. Champ de hauteur (Voronoï périodique à crevasses, fibres, lenticelles) → éclairage rasant → 10 tons par essence (rampes étendues) + 3 tons de lichen, filtre « mode » (aucun texel isolé), alpha = hauteur. Mipmaps nearest « vote 2×2 ». Précalculées dans `assets/ecorces/*.res` (`outils/generer_ecorces.gd`, à relancer après toute modif d'`ecorces.gd` ; sinon repli sur génération au lancement ≈ 1 s). Planche : `outils/planche_ecorces.gd`.
- `shaders/ps1_tronc.gdshader` : dérivé de ps1 ; écorce 32 texels/m avec fondu tramé PAR BRUIT (6→16 m) vers 16 texels/m ; tuile du pied mêlée à seuil bruité (UV2.x) ; relief par normale depuis la hauteur ; mousse côté nord (UV2.y, sommets des plaques) ; neige plaquée côté vent (alpha de sommet) ; AO peinte en couleur de sommet.
- `scripts/arbres.gd` : `_fut` (8 pans, section irrégulière, normales lissées, 4 pans au loin), `_racines`, `_chicots`, `_fut_epicea/pin/bouleau/mort`, `materiau_tronc`. Grosses branches à 6 pans (pin, mort), UV en miroir sans couture. RNG de l'arbre inchangé (silhouette, rameaux, placement identiques ; le fût a son propre RNG).
- Mesures (2.5,8.5,16,4) : GPU 7,05–7,26 ms avant → 7,30–7,67 ms après (autres agents actifs) ; primitives 382 k → 430 k ; chargement arbres ≈ égal (bruit 630–1010 ms des deux côtés).
- Planches : `captures/arbres/planches_troncs/planche_troncs_avant_apres_{jour,nuit}.png` (avant | après, 11 poses : Te/Tp/Tb/Tm 1 m et 3 m, A2, A10, M10).
- Défauts restants : à 1 m le texel (≈ 3 cm) reste visible (inhérent à 32 texels/m) ; mousse du pied un peu verte/patchée sur le pin ; fût de l'arbre mort peu contrasté dans la brume ; pin de nuit encore sombre au pied.

### Lot 2, troncs, 2e passe (fin du « camouflage »)
- Textures : `_plaques()` générique dans `ecorces.gd` (contraste faible entre plaques, contraste fort réservé aux fissures fines et courtes). Épicéa : écailles 2-5 cm, gris-brun, rampe resserrée. Pin haut : plaquettes orangées fines ; pin pied : plaques allongées verticalement (16×3 cellules, rapport ≈ 1:5), crevasses longues. Bouleau pied : moins de papier blanc. `_finir` quantifie sur la taille de la rampe. `.res` régénérés (`outils/generer_ecorces.gd`).
- Mousse (shader) : ton olive sombre, uniquement dans les creux (liserés) ; pin ×0,25.
- Géométrie : épicéa proche 6 pans (5 anneaux), 3 racines à un seul tronçon, plus de chicots ; pin/bouleau/mort 6 pans proches ; versions lointaines (`lod`) 4 pans sans racines ni chicots pour pin/bouleau/mort (utilisées comme `lod_mesh`).
- Mesures (2.5,8.5,16,4) : primitives 382,8 k → 401,9 k (+19 k) ; GPU 6,1-6,5 ms contre 6,0-6,8 avant (indiscernable du bruit).
- Planches : `captures/arbres/planches_troncs/planche_troncs_avant_apres_v2_{jour,nuit}.png`.
