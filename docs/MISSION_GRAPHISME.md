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
