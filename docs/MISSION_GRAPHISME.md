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
