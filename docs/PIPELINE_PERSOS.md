# Pipeline commun des personnages (ÉTAPE 3) : créer un archétype sur la base Humain.creer

Référence validée par l'utilisateur : le **Guerrier nordique pilote** (`scripts/guerrier_nordique.gd`,
`scripts/guerrier_textures.gd`, `shaders/ps1_perso.gdshader`, `shaders/contour_perso.gdshader`, branche
`refonte/persos_guerrier`). Chaque nouvel archétype (chasseresse, mage, gardien, draugr, troll…) suit cette recette.
Les planches de référence sont dans `Desktop\Skyrim captures\refonte\persos\guerrier\finition\`.

Règles de direction artistique (rappel, voir `docs/BIBLE_VISUELLE.md`) : rendu PS1 640x360, tout passe par le shader
PS1 (accroche des sommets, mapping affine), réalisme 32 bits, **jamais de tramage Bayer** (bruit seulement), pas de
gros pixels « camouflage ».

---

## 1. Les étapes

1. **Nouvelle fabrique, jamais de PNJ modifié.** Créer `scripts/<archetype>.gd` (`class_name`, méthode statique
   `creer(options) -> Node3D`). Partir de `Humain.creer(app)` (corps, visage, squelette 65 os, animations, ragdoll) en
   passant des teintes BLANCHES pour la tenue (`"tenue": {"tunique": Color.WHITE, …}`) : la couleur vient des textures.
   Contrat identique à `Humain.creer` : racine -> `Skeleton3D` + `AnimationPlayer` « Animations », mêmes noms d'os
   (`Ragdoll.equiper`, `PiedsAuSol.equiper` marchent tels quels). Après ajout d'une `class_name` : `--headless --import`.
2. **Réhabiller les pièces existantes** (`tunique`, `pantalon`, `bottes`, `brassards`, `mante`, `cape`, `ceinture`) avec
   `materiau(tex)` : on garde le maillage et les UV métriques du lot 4, on change la texture et le shader.
3. **Peindre les textures par code** dans un fichier `<archetype>_textures.gd` (ou en réutilisant
   `GuerrierTextures`, §2) à **128 texels/m**, palettes de 4 à 7 tons (§3), mipmaps « pixel art »
   (`GuerrierTextures.mips_pixel`).
4. **Alléger** pour tenir le budget (§9) : sous-couche `SuperHero_Male` cachée, yeux Quaternius remplacés par 2 cartes
   peintes, peau sous les manches retirée (`_filtrer`), mains/nuque/mèches décimées (`_decimer`), sourcils retirés.
5. **Ajouter les pièces modelées** (§6) dans un objet `Accessoires` : 2 surfaces seulement (opaque + découpée), peau
   d'os du squelette au repos.
6. **Verser les petites pièces dans l'atlas** (`acc.integrer(mi, acc.op, uvmap, deforme)`) : plastron, ceinture, cape…
   rejoignent les 2 surfaces des accessoires (3 surfaces de moins).
7. **Précalculer les textures** (`outils/generer_<archetype>.gd`, modèle `outils/generer_guerrier.gd`) dans
   `assets/personnages/<archetype>/<clé>.res`.
8. **Captures en jeu + planches** (§10) : référence | passe précédente | passe actuelle, gros plans, casque, animations,
   nuit, scintillement.
9. **Test** (§11) ajouté à `outils/tous_les_tests.sh`.

---

## 2. Fonctions réutilisables de `GuerrierTextures` (`scripts/guerrier_textures.gd`)

Outils (statiques, appelables depuis un autre script : `GuerrierTextures._c(...)`, etc.) :

| Fonction | Rôle |
|---|---|
| `_c(pal, i)` | couleur `i` d'une palette (index borné) |
| `_h(x, y, g)` | hachage 0..1 (graine `g`) |
| `_n(x, y, w, h, cx, cy, g)` | bruit de valeurs PÉRIODIQUE (tuilable) sur `cx` x `cy` cellules |
| `_ton(l, n, x, y, g, jit)` | luminance 0..1 -> ton entier, seuil bruité (**jamais de damier**) |
| `_p(img, x, y, c)` | pixel avec bouclage |
| `_img(w, h, fond)` | image RGBA8 remplie |
| `mips_pixel(img)` | mipmaps par vote de couleur 2x2 (égalité : la plus sombre ; transparence si < 2 texels opaques) |
| `charger(clé)` / `sauver(clé, img)` / `tex(nom, args)` | précalcul `.res` versionné + cache `ImageTexture` |
| `_ton_cuir(x, y, W, H, base, g)` | cuir usé : grain, plaques frottées, crasse dans les creux |
| `_eraflures(img, rect, n, g)` | éraflures claires à liseré sombre |
| `_rivet(img, x, y)` | rivet 2x2 (rehaut + ombre portée) |
| `_copier(dst, rect, src, ox, oy)` | recopie d'une image dans une région d'atlas |
| `_touffe(img, x0, y0, w, h, pente, clair)` | touffe de fourrure pointue (racine sombre, arête claire, fente) |

Dessins complets réutilisables tels quels ou comme modèle : `mailles()` (anneaux 4x3 en quinconce, rouille dans les
creux), `plastron(v0, v1)` (panneaux cousus, bandes rivées), `pantalon()` (laine + bandes molletières + lanières croisées),
`bottes()` (cuir lacé + revers de fourrure), `brassards()`, `ceinture()`, `mante()` (fourrure en écailles), `meches()`
(4 cartes de fourrure 16x32), `meches_cheveux()` (8 cartes de mèches de cheveux 8x32), `cape()` (laine, ourlet effiloché
en alpha), `barbe()` (mèches peignées vers le bas), atlas `accessoires()` (régions `R_*` : bouclier, fer, umbo, lame,
poignée, tresse, œil, baudrier, anneau, bosse, plastron, ceinture) et `decoupes()` (`D_CAPE`, `D_MECHES`, `D_CHEV`).

Côté `GuerrierNordique` (statiques) : `materiau(tex, double_face, decoupe, avec_contour, clé)`, `contour()`,
`shader(double_face)`, `_filtrer(mi, garder)`, `_decimer(mi, cellule)`, `_centres_yeux(mi)`, `_uv_barbe(mi)`,
`_tex_cheveux(mi)` (texture Quaternius ramenée à 64² dans une palette), `_plastron(sq, tunique)`, `_bind_de`, `_os_de_bind`.
Classe interne `GuerrierNordique.Accessoires` : `_tri`, `_quad`, `_tube`, `_boite`, `_disque`, `fourrure_bord`,
`fourrure_surface`, `integrer`, `_projeter`, `baudrier`, `boucle`, `fibule`, `yeux`, `tresses`, `meches_cheveux`,
`bouclier`, `epee`, `construire`.

**Règle de partage** : on ne renomme ni ne déplace ces fichiers/fonctions publiques (5 archétypes en dépendent). Un
archétype qui a besoin d'une variante écrit sa propre fonction (ex. `ChasseresseTextures.carquois()`) plutôt que de
changer la signature d'une fonction commune.

---

## 3. Palettes (sombre -> clair)

Froides et désaturées sous le crépuscule, sauf les matières qui doivent se détacher (cuir clair, métal clair, peau).
4 à 7 tons par matière ; un ton réservé aux arêtes usées / reflets.

| Constante | Matière | Tons |
|---|---|---|
| `MAILLE` | cotte de mailles : fer **brun-gris** ; le ton 5 (froid) est réservé aux arêtes éclairées | `#19140f #32291f #4c4135 #685b4b #887a66 #a4a7a8` |
| `ROUILLE` | rouille (creux des mailles, fer) | `#24150e #3d2416 #5a3820 #74482a` |
| `CUIR` | cuir brun usé (6 = arête usée, couture) | `#1a130e … #b89d76` (7) |
| `CUIR_CLAIR` | baudrier, ceinture (se détache du plastron) | `#24170e … #dcbb88` (7) |
| `CUIR_SOMBRE` | bandes de bord, semelles | `#100c0b … #544537` (5) |
| `METAL_CLAIR` | boucle, fibule (gris chaud poli) | `#2a2723 … #ece7dc` (7) |
| `FER` | lame, cerclage, umbo, garde | `#0d0e12 … #c9ccd2` (7) |
| `FOUR` | fourrure gris-brun (pas blanche) | `#1d1b19 … #bab0a0` (6) |
| `LAINE_BLEUE` | cape | `#0f1422 … #687fa8` (6) |
| `LAINE_GRISE`, `BANDE` | pantalon, bandes molletières | 5 / 4 |
| `BOIS`, `BOIS_GRIS` | bois ; bouclier brun-gris délavé | 6 / 7 |
| `PEINT_DELAVE`, `PEINT_BLEU`, `PEINT_CREME` | peintures du bouclier | 4 / 5 / 4 |
| `CHEVEUX`, `BARBE` | cheveux ; barbe (même teinte, plus rousse et sombre) | 5 / 6 |

Peau : texture `Humain._peau` gardée, passée au shader du perso avec `teinte * (1.24, 1.13, 1.01)`, `appoint`
`(0.17, 0.145, 0.13)`, `contour_froid` `(0.22, 0.25, 0.34)` ; constante `PEAU = (0.97, 0.85, 0.76)`.
Œil (`_oeil`) : blanc ivoire TERNE `#9c9184` (coins `#7d6c62`), iris sombre `#4a4136`/`#3a342d`, pupille `#0f0d0c`,
ombre de paupière.

---

## 4. Densité : 128 texels/m

- Les UV des vêtements du lot 4 sont **métriques** : u = 2 m par unité, v = 1 m ; le BAS de l'image = l'ourlet.
  Une texture de vêtement fait donc 256 x 128 (bottes 128 x 128, ceinture 256 x 16, brassards 128 x 64).
- Les pièces modelées gardent la même densité (ex. bouclier de 0,80 m sur 128 texels de l'atlas ; mèche de cheveux de
  12 cm = 15 texels de haut).
- Un motif répété doit avoir une taille physique crédible : anneaux de maille 4 x 3 texels (3 cm), rivets 2 x 2,
  joints de planches 2 texels.
- Pas en dessous : à 64 texels/m le visage et les mailles redeviennent des « gros pixels ».

---

## 5. La fourrure en mèches

Jamais une fourrure peinte à plat : des **cartes découpées** (surface `dec`, matériau double face, `decoupe = true`,
seuil alpha 0,5 net, sans contour) portant 2-3 touffes pointues (`meches()`, atlas `D_MECHES`).
- `acc.fourrure_bord(mi, y0, y1, lg0, lg1, bas, elargi)` : une carte par arête LIBRE du maillage entre y0 et y1
  (franges d'épaules, revers de bottes) ; `bas` < 0 = les mèches se dressent (col).
- `acc.fourrure_surface(mi, y0, y1, lg0, lg1, nombre)` : touffes couchées sur la surface (dessus des épaules, dos).
- `acc.poitrine_libre` / `acc.col_libre` : zones laissées dégagées (poitrine, sous la barbe) pour que le plastron, le
  baudrier et la fibule se lisent.
- Poids d'os : ceux du sommet le plus proche du maillage porteur (`_poids_proche`) : la fourrure suit l'animation.
- Même principe pour les **mèches de cheveux détachées** (`acc.meches_cheveux(Hair_Long)`, atlas `D_CHEV`) : 2 segments
  par carte qui s'écartent de la tête, normales de chevelure (`(ext + 0,7 UP)`) sinon la carte fait une tache sombre à
  contre-jour, jamais devant les yeux (x >= 9 cm sur les tempes).

---

## 6. Les accessoires modelés

Tout est construit par code dans `Accessoires` (sommets dans le repère du modèle au repos, peau d'os du squelette au
repos : bind i = os i), en 2 surfaces : `op` (opaque, atlas `accessoires`, contour) et `dec` (découpée, atlas `decoupes`).
- Primitives : `_tri`, `_quad` (ordre des sommets corrigé par un point `dedans` : la face avant regarde vers l'extérieur,
  le contour par coque en dépend), `_tube` (tresses, poignée), `_boite` (garde, pommeau), `_disque` (boucle, fibule).
- Poids rigides (un os : `hand_r`, `lowerarm_l`, `Head`, `pelvis`) pour les objets durs ; poids copiés du maillage
  porteur (`_poids_proche`) pour ce qui suit la peau (baudrier, fibule, fourrure, mèches).
- `_projeter(mi, x, y, devant)` pose un objet SUR une surface (baudrier, fibule sur le plastron).
- Bouclier : `reglage_bouclier` (hauteur au-dessus de l'avant-bras, inclinaison, rotation) ; épée : `PRISE`, même prise
  que les draugrs. Les métadonnées `sq.set_meta("bouclier"|"epee", [os, transform])` servent au test des traversées.

---

## 7. Le contour par coque

`shaders/contour_perso.gdshader`, posé en `next_pass` des matériaux OPAQUES (`materiau(..., avec_contour = true)`) :
coque inversée (`cull_front`) d'épaisseur constante **à l'écran** (`epaisseur` = 1,2 px), accrochée à la même grille
que le shader PS1 (le contour ne glisse pas). Pas de contour sur les cartes découpées (fourrure, mèches, cape) ni sur
la barbe (§12).

---

## 8. Le liseré froid

Dans `shaders/ps1_perso.gdshader` :
- `contour_froid` : émission froide sur les bords de silhouette (`smoothstep` large sur 1 - N·V, proportionnelle à
  l'albédo + un peu de constant) : la silhouette se détache au crépuscule et la nuit, sans toucher l'éclairage de la scène.
- `ombre_froide` / `ombre_force` : appoint froid (ciel) sur la face à l'ombre du soleil ; `soleil_desat` : soleil en partie
  désaturé (tout ne vire pas au brun orangé) ; les lumières ponctuelles (torches) gardent leur couleur.
- `rehaut` : rehaut d'arête en palier net côté soleil (pas de dégradé qui scintille).
- `appoint` : lumière propre (la face à l'ombre ne tombe pas au noir), plus forte sur la peau.
Les réglages sont **par matériau** : la maille a une `ombre_froide` moins bleue `(0.34, 0.38, 0.50)` et un
`contour_froid` adouci `(0.13, 0.16, 0.24)`.

---

## 9. Le budget

- **7 500 triangles visibles, 10 surfaces visibles** par personnage (guerrier finition : 7 398 / 10).
- Mesure : `outils/test_guerrier.gd` (`_tris` : maillages visibles, indexés ou non) ; ventilation avec
  `GuerrierNordique.chrono = true` (temps par étape et triangles du baudrier/disques).
- Leviers, dans l'ordre : sous-couche cachée (3 768 tris), yeux en cartes (-544), peau sous les manches, décimation des
  mains (2,7 cm) / nuque (1,8 cm) / cheveux (3,2 cm), couches intérieures des cheveux et de la barbe, sourcils ; petites
  pièces versées dans les 2 surfaces des accessoires.
- Coût GPU/CPU en scène : `galerie_guerrier.gd --mode=cout` (ms GPU/CPU, draw calls, primitives, n exemplaires).

---

## 10. Les options de capture

Captures EN JEU (un seul lancement par fichier de poses ; elles ouvrent une fenêtre : passer par
`bash /tmp/godot_slot.sh`, jamais pendant une réunion de l'utilisateur) :

```
godot --path C:/…/<worktree> --disable-vsync -- --captures=outils/poses_guerrier.txt --sortie=C:/…/captures/<dossier> \
      --nouvelle --paisible --sans-particules --attente=200 --res=640x360 --guerrier-pilote [--guerrier-casque]
```

- `--guerrier-pilote[=x,z,lacet°]` : place le perso près de l'entrée du village (à brancher de la même façon pour un
  nouvel archétype dans `monde.gd`, `_guerrier_pilote`) ; `--guerrier-casque` ; `--guerrier-anim=Nom`.
- Ligne de pose : `nom pilote d,az°[,cible_y] heure=17.5 sans-mains [anim=Clip:t] [decal=m] [torche-eteinte]`
  (caméra à d m, az 0 = face, 180 = dos ; pose figée à la fraction t du clip ; caméra décalée pour le scintillement).
- Fichiers : `outils/poses_guerrier.txt` (complet : 2/4/8 m face/3/4/dos, nuit, scintillement, animations, gros plans,
  profil et nuque), `poses_guerrier_casque.txt` (lancer dans un **dossier à part** : ses `p17_*` portent aussi le casque),
  `poses_guerrier_rapide.txt`.
- Planches (headless) : `godot --headless --script res://outils/planche_guerrier.gd -- --captures=<dossier>
  --sortie=<dossier> --ref=<…/reference/personnages/persos_b.png> [--passe1=<planche précédente> --noms=passe2,finition]`
  -> référence | passe précédente | passe actuelle, gros plans, silhouette 8 m, animations, ambiances, sans/avec casque,
  « avec casque », scintillement (+ mesure : ~13 % des pixels de la bande du perso changent pour 2 cm de caméra).
- Itérations rapides hors du monde : `outils/galerie_guerrier.gd --mode=planche|anims|gros|stats|cout`.

---

## 11. Le test type (`outils/test_guerrier.gd`, à copier en `test_<archetype>.gd`)

1. Contrat : mêmes os que `Humain.creer` (65), `AnimationPlayer` « Animations » et clips (`Idle`, `Sword_Idle`, `Walk`,
   `Jog_Fwd`, `Sword_Attack`, `Hit_Chest`, `Death01`) ; temps de `creer`.
2. Budget : triangles visibles <= 7 500, surfaces visibles <= 10.
3. Toutes les surfaces au shader PS1 à accroche (paramètre `grille`).
4. `Humain.creer` (PNJ) non modifié.
5. Traversées bouclier / épée dans des capsules du corps sur les clips (Idle, garde, marche, course, sprint, attaque,
   coup) : bouclier < 2 cm, épée < 6 cm.
6. Ragdoll : 16 os physiques.
Puis l'ajouter à `TESTS` dans `outils/tous_les_tests.sh` (`"test_<archetype>|--nouvelle"`), toujours avec `-- --nouvelle`.

---

## 12. Pièges rencontrés

- **Dégagement du bouclier** : à 9 cm au-dessus de l'avant-bras, le bouclier traversait la cuisse de 5,2 cm en course.
  Réglé à `reglage_bouclier = (0.13, 15°, -12°)` : 0 cm sur tous les clips. Toujours mesurer avec le test des traversées
  (course ET sprint), jamais à l'œil sur une pose figée.
- **Barbe en contour noir** : avec le contour par coque et une décimation à 1,5 cm, la barbe se hérissait en pics noirs et
  se confondait avec la fourrure du col. Correction : décimation fine (8 mm), UV étalés (`_uv_barbe`) sur une texture
  de mèches peignées vers le bas, teinte des cheveux plus rousse, **sans contour**, col de fourrure dégagé sous la barbe.
- **Motifs « camouflage »** : taches de bruit à grosses cellules (peinture du bouclier écaillée par plaques, plaques de
  rouille) = camouflage militaire à 4 m. Les motifs suivent la STRUCTURE (planches, joints, anneaux, coutures) ; le
  bruit ne sert qu'à moduler finement un ton ; peinture en couche mince continue qui ne manque qu'aux joints.
- **Mailles bleues** : palette gris-bleu + ombre froide + liseré froid = cotte bleu franc au crépuscule. La maille est
  en fer brun-gris (palette chaude), rouille dans les creux, un seul ton froid réservé aux arêtes éclairées des
  anneaux, ombre propre et liseré moins bleus sur ce matériau. Règle générale : une matière qui doit rester neutre sous
  la lumière du crépuscule part d'une palette CHAUDE, le shader ajoute déjà le froid.
- **Textures précalculées périmées** : `GuerrierTextures.charger` renvoie le `.res` existant dès que sa VERSION
  correspond. Après toute modification d'un dessin : incrémenter `VERSION` (une seule fois par commit) ET supprimer les
  `.res` du dossier avant `generer_*.gd` si on itère plusieurs fois à la même version, sinon on regarde l'ancien dessin.
- **Mèches de cheveux sombres** : une carte à normale plate, à contre-jour, fait une tache noire sur l'oreille ; racines
  sombres et larges = aplat. Normales de chevelure, racine fine et claire (elle sort de la chevelure).
- **Casque** : `Humain.creer` cache `Hair_Long` sous un casque ; les mèches détachées (tempes, nuque) restent et sortent
  du casque, la barbe reste.
