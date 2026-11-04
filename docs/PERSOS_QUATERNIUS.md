# Personnages Quaternius en PS1 (essai/persos_quaternius 2026-11-03, BRANCHÉ en jeu sur persos/quaternius_jeu 2026-11-04)

L'essai (§1-5) a converti 11 modèles ; la branche persos/quaternius_jeu les BRANCHE en jeu (§6). Ce document : la chaîne, le mapping rôles -> modèles, ce qui est en jeu, l'interrupteur avant/après.
Catalogue des packs (licences, rigs, manquants) : `Jeux/references/quaternius_persos/CATALOGUE.md`. Captures : `Desktop/Skyrim captures/persos_quaternius/`.

## 1. La chaîne (une seule commande par lot)

```
blender.exe -b --python sources_blender/scripts/pq_convertir.py -- liste=sources_blender/persos_quaternius/persos.json sortie=assets/modeles/persos_quat [seulement=pq_loup,pq_geant]
```

`persos.json` décrit chaque personnage (source, hauteur cible, budget de triangles, pièces annexes, réglages de couleur). Étapes (sur le modèle de `importer_quaternius.py`) :

1. import glb/gltf (la « Icosphere » que l'importeur crée comme forme d'os est supprimée) ; pièces annexes rattachées au squelette principal (têtes UBC `Superhero_*` coupées au cou, cheveux, barbe) ; maillages rigides accrochés à un os (bois du cerf) transformés en maillages skinnés ;
2. mise à l'échelle réelle (hauteur en m mesurée en pose de repos, appliquée à l'armature ; translations des clips mises à l'échelle aussi) ;
3. réduction « collapse » au budget (la tête garde son quota : 1 000 triangles pour le visage, 380 pour les cheveux) ;
4. couleur : une couleur par FACE (texture échantillonnée au centre UV d'une copie 256 px, sinon couleur du matériau) -> « virage nordique » (désaturation, assombrissement, pointe de bleu froid) -> ACCROCHE à la palette de la bible (les 100 couleurs de `importer_quaternius.PALETTE`, distance OKLab) -> pied plus sombre -> couleur de sommet (COLOR_0 linéaire) : aplats nets façon PS1, aucune texture ;
5. UN maillage, UN matériau, SQUELETTE conservé ;
6. clips conservés et renommés `Idle / Walk / Run / Attack / Death / Hit` (pistes NLA -> animations glb). Les humains (rig UBC = rig UAL, 65 os, mêmes noms) n'ont pas de clips : ils prennent `Humain.bibliotheque()` (UAL du jeu).

Côté Godot : `scripts/persos_quat.gd` (`PersosQuat.creer("pq_loup")`) pose `shaders/ps1_perso.gdshader` (grille d'écran 135, affine, liseré froid) sur le maillage, crée l'AnimationPlayer « Animations » (contrat des ennemis) et ajoute les alias `Jog_Fwd`/`Sprint` (= Run), `Sword_Idle` (= Idle), `Death01` (= Death), `Hit_Chest` (= Hit) que demandent `EnnemiBase._bouger` / `_jouer` et `Humain`.

## 2. Convertis (11)

| id | Source (licence) | Rôle proposé | Triangles | Hauteur | Clips |
|---|---|---|---|---|---|
| pq_villageois | Peasant homme (Outfits Fantasy, CC0) + tête UBC + cheveux/barbe | villageois, fermier, forgeron (variantes) | ≈3 600 | 1,84 m | UAL (Idle, Walk, Sword_Attack, Death01…) |
| pq_villageoise | Peasant femme | villageoise, aubergiste | ≈3 600 | 1,80 m | UAL |
| pq_chasseur | Ranger homme (capuche, épaulière) | chasseur, éclaireur, bandit sans capuche | ≈3 800 | 1,87 m | UAL |
| pq_chasseresse | Ranger femme | chasseresse, pisteuse, bandite | ≈3 800 | 1,80 m | UAL |
| pq_loup | Wolf (Poly Pizza, CC0), AnimalArmature 51 os | loup (meute), loup-garou plus tard | ≈2 000 | 0,9 m au garrot | Idle Walk Run Attack Death |
| pq_araignee | Spider (CC0) | araignée de grotte/crypte | ≈2 700 | 1,1 m (envergure ≈3 m) | Idle Walk Attack Death |
| pq_geant | Giant (CC0), EnemyArmature 12 os | géant / troll des collines (le troll de givre existant reste le boss) | ≈3 800 | 3,3 m | Idle Walk Run Attack Death Hit |
| pq_demon | Demon (CC0), 43 os | démon / ombre des profondeurs (yeux or) | ≈4 200 | 2,3 m | idem + Hit |
| pq_squelette | Skeleton (CC0), 12 os | squelette alternatif (os nus, vs draugr) | ≈3 800 | 1,85 m | idem + Hit |
| pq_cerf | Stag (CC0), AnimalArmature | faune : cerf (pas hostile : fuite) | ≈2 600 | 1,9 m bois compris | Idle Walk Run Attack Death |
| pq_spectre | Ghost (CC0), vol | spectre / âme errante de la crypte | ≈2 600 | 1,9 m | Idle Walk(vol) Attack Death Hit |

## 3. Mapping des rôles du jeu -> modèles Quaternius

| Rôle | Modèle(s) | Remarque |
|---|---|---|
| PNJ villageois variés | Peasant H/F x 7 coupes de cheveux (Hair_*.gltf du jeu) x 3-4 palettes de tunique (`mats` de persos.json) | ~40 combinaisons possibles à coût nul ; même rig que les PNJ actuels : clips UAL, `Humain.creer` interchangeable |
| Chasseurs, éclaireurs, pisteurs | Ranger H/F (capuche) | nordique sombre : virage plus froid (`sat` 0,5) ; garde l'arc/carquois du jeu (BoneAttachment3D) |
| Bandits / maraudeurs | Ranger sans capuche (pièce `Head_Hood` retirable via `retirer`), Peasant « haillons » | variantes sales : `val` 0,7 ; armes du jeu |
| Gardes | RIEN de convenable dans le pack gratuit (pas de chevalier/guerrier) | garder les gardes actuels ; ou pack payant Outfits [Source] |
| Mages | RIEN (les « Wizard » Quaternius libres sont chibi ou CC-BY) | garder le mage nordique actuel |
| Troll / géant | Giant (échelle 3,3 m) ; Yeti (CC0, Poly Pizza `xtMYEVzyw0`, à convertir) pour un troll de givre mineur | le troll de givre existant garde le rôle de boss |
| Goule / mort-vivant lent | Zombie CC0 (`JoBvxIUpZP`, `VlXjG0N8Eg`) | à convertir (même chaîne) ; en doublon avec le draugr zombie Mixamo : seulement hors crypte |
| Araignée | Spider | grottes, crypte (toiles) |
| Loup | Wolf (deux modèles CC0 : `P1gU3Qkr9r` 51 os, `XU7oNeKShV` 16 os) | meutes, hiver |
| Ours | MANQUANT (Ultimate Animated Animals sur Drive, quota) | à télécharger à la main |
| Élémentaire | Goleling / Goleling Evolved (CC0, golems), Hywirl | rocheux = golem de pierre ; givre : recolorer en bleu glacé |
| Démon / ombre | Demon, Blue Demon, Ghost, Ghost Skull | ombres de la crypte : Ghost ; démons : seulement boss/zone maudite |
| Squelettes alternatifs | Skeleton (3 variantes CC0) | os nus ; contraste avec les draugrs en armure |
| Faune | Stag, Deer, Fox, Husky/Dog, Horse, Sheep, Bunny, Raccoon, Birb, Chicken | tous AnimalArmature : mêmes clips, une seule IA de faune |

## 4. Plan d'intégration (essai -> jeu)

1. **Valider le style** (cet essai) : vue de jeu à côté du héros et d'un draugr ; décider quels rôles prennent Quaternius.
2. **Humains** : `Humain.creer` accepte déjà `corps`; ajouter `"modele": "pq_villageois"` qui charge `PersosQuat.creer` (même contrat : Skeleton3D 65 os + « Animations » avec la bibliothèque UAL, donc PiedsAuSol, armes en BoneAttachment3D, dialogue, assis, torche… fonctionnent sans changement). Variantes = cheveux/teinte/palette dans `persos.json` (nouvelles entrées : un `bun`-like script suffit) ou teinte runtime sur `PersosQuat.materiau().duplicate()` (le shader multiplie par `teinte`).
3. **Monstres/animaux** : un seul nouveau script `scripts/bete_quat.gd` (`extends EnnemiBase`) paramétré par une table `{id, vie, degats, vitesse, rayon, haut, profil}` : `_equiper(PersosQuat.creer(id), ProfilCible.pour(...), rayon, haut, false)` (pieds=false : pas de PiedsAuSol hors humanoïdes), IA = `_vers_joueur` / `_bouger(dt, dir, vitesse, "Walk"|"Jog_Fwd", ...)` / attaque = `_jouer("Attack")` + fenêtre de touche à la mi-clip ; mort = clip `Death` puis `_sur_mort`. Profils de dégâts à créer : `cible_loup`, `cible_araignee`, `cible_geant`, `cible_demon` (chair/os/pierre, résistances).
4. **Faune non hostile** (futur système animaux/PNJ par biome) : `faune_quat.gd` : états `paître` (clip Eating/Idle_2), `errer` (Walk), `fuir` (Run/Gallop) quand le joueur < 12 m ; cerf/renard/lièvre/corbeau ; chaque biome déclare une table d'apparition `{id, poids, densité, heure}` lue par `ZoneBiome` (graine propre `ZoneBiome.graine("faune")` : aucun tirage sur `monde.rng`). Meutes de loups (3-5) en forêt de nuit, araignées dans grottes/crypte, corbeaux au tumulus.
5. **Apparition PNJ par biome** : village = Peasant (pondéré), route/forêt = Ranger, ruines = bandits ; cache de modèles via `Humain.scene`-like (`PersosQuat._scenes`) et préchauffage dans `Prechargement`, comme les archétypes.
6. **Budget** : ≈3 600 triangles par humain (les humains actuels ?), 2 000-4 200 par monstre, UN draw call par personnage (un maillage, un matériau partagé `PersosQuat.materiau()`), pas de texture : plus léger que les archétypes à textures.

## 5. Avis et limites constatées (captures du 2026-11-04)

- **Humains (Peasant / Ranger)** : bon. Proportions réalistes, même échelle que le héros et le draugr (1,80-1,87 m), clips UAL qui fonctionnent sans adaptation, 3 600-3 800 triangles, un seul matériau. Un peu « propres » et pâles à côté des draugrs crasseux : prévoir un `val` plus bas et des haillons.
- **Animaux (loup, cerf, araignée)** : bons, silhouettes crédibles et animations complètes (Idle/Walk/Run/Attack/Death).
- **Monstres « Ultimate Monsters » (géant, squelette, spectre)** : style jouet/cubique (le géant est un golem de pierre, le squelette a une tête en cube, le spectre est mignon). L'aplat PS1 aide mais la silhouette détonne avec l'univers sombre et réaliste : à n'utiliser qu'en fond ou après retouche (géant -> golem de pierre / élémentaire, pas troll).
- **Démon (pq_demon)** : NON MONTRÉ. L'export glTF de Blender fait coucher ce rig (CharacterArmature, aussi un aller-retour import/export sans traitement) : le Root perd sa rotation de 90°. À régler (autre importeur, ou éditer le glb) avant usage ; le fichier est conservé.
- **Idle du géant et du squelette** : dans le pack d'origine c'est la pose en T ; `PersosQuat.clip` joue la marche à la place (à remplacer par un vrai idle).
- Les originaux de la planche sont à l'échelle native du fichier (non normalisée) : seule la comparaison de rendu compte, pas de taille.

## 6. En jeu (persos/quaternius_jeu, 2026-11-04)

Interrupteur avant/après : `-- --persos-anciens` (habitants aux mêmes postes avec les corps `Humain.creer`, aucune bête Quaternius) ;
`--sans-habitants`, `--sans-betes` pour les retirer.

### Habitants anonymes du village (10)
- `data/habitants.json` : id `hab_*`, type (paysan, paysanne, chasseur, chasseresse : répliques communes dans `roles`), `pq` (modèle),
  `pos` (x, z monde), `cap`, `activite` (Idle_Talking, Fixing_Kneeling…), `sedentaire`, `ancien` (apparence Humain pour l'avant/après).
- Chargés par `Villageois.charger()` APRÈS les PNJ nommés (`Villageois.habitants()`) : même script `villageois.gd`, donc mêmes routines
  (poste, promenade, regard, interpellation), même dialogue (`parler()`), même sauvegarde (`villageois_parles` par id), même gel sous terre.
  Les tirages de promenade des PNJ nommés sont inchangés (habitants tirés après).
- Postes : place (deux paysans qui causent au brasero), puits, pont (le vieux), quai (lavandière à genoux), rue est, maison des
  chasseurs (2), abords de l'enclos d'Ylva, porte nord de la place (pisteuse).
- PNJ nommés, gardes, mages : INCHANGÉS (archétypes nordiques, plus riches que les Quaternius ; rien de convenable pour garde/mage).

### Variantes salies (`sources_blender/persos_quaternius/habitants.json`, ids `pq_hab_*`)
Peasant H/F x 3, Ranger H/F x 2 (avec / sans capuche), 6 coupes et teintes de cheveux, 10 tuniques. Nouveautés de `pq_convertir.py` :
- `accroche: "pnj"` : étoffes, cuirs, fourrures, cheveux accrochés aux couleurs des PNJ EN JEU (`palette_pnj.json`, 62 couleurs
  + 6 teints, tirées des tenues teintes `assets/pnj/*.res` par `outils/pq_palette_pnj.gd` ; à relancer si les tenues changent) ;
  peau et yeux : teints des PNJ, SANS le virage froid (visages bleus sinon) ;
- `parts` : teinte par pièce / matériau / clarté (la chemise crème devient laine teinte terne, à la luminance de la cible) ;
- `boue` : boue brune au bas (jambes, bottes) + éclaboussures ; `usure` : variation de valeur par face ;
- import FBX (packs « Ultimate ») et clips en plus `Eat`, `Idle_2`, `Jump`.
Commande : `blender.exe -b --python sources_blender/scripts/pq_convertir.py -- liste=sources_blender/persos_quaternius/habitants.json sortie=assets/modeles/persos_quat [seulement=…]`

### Bêtes et faune (`scripts/bete_quat.gd`, `BeteQuat extends EnnemiBase`)
- `ESPECES` : loup (`pq_loup2`, Wolf FBX du pack Ultimate Animated Animals, 67 os, 9 clips), araignée (`pq_araignee`), cerf (`pq_cerf2`),
  biche (`pq_biche`), renard (`pq_renard`) : vie, dégâts, vitesses, références de clip, détection, portée, et pour le FUTUR système
  d'apparition `biomes`, `heures`, `groupe` (non codé : un générateur tirera dans cette table et appellera `monde.creer_ennemi`).
- Contrat des ennemis : groupe `ennemis`, `CombatEnnemi` (profils `loup`, `araignee`, `gibier` dans `ProfilCible._defaut`), signal `mort`
  (sauvegarde `draugrs_morts`), gel, butin ; `monde.SCRIPTS_IA` (« ia »: "loup"…) et `EnnemisNordiques._fabriquer_ia` (préchauffage) ;
  AnimationPlayer « Animations » + alias `Jog_Fwd`/`Death01`/`Hit_Chest`. Pas de PiedsAuSol ni de ragdoll (squelettes d'animaux) : la mort
  joue le clip `Death` ; pas de finisher.
- IA : loup = traque, MEUTE (une alerte réveille la meute ; chacun tient un angle autour du joueur à 3,2 m et bondit à son tour) ;
  araignée = embuscade (voit à 60 % de sa portée) ; faune (groupe `faune`) = broute (`Eat`) / erre / FUIT, jamais en combat.
  L'IA attend au repos tant que le monde charge (`monde.pret`).
- Placement (`monde.BETES`, `_betes()`) : meute de 3 loups dans le bois entre le feu et le cercle (≈ -14, -28) ; cerf + 2 biches au champ
  nord F3 (lisière, ≈ 61, -8) ; renard au bord du champ de la ferme A (75, 29) ; 2 araignées en embuscade dans la galerie du retour de la
  vieille mine (`grotte_donnees`, zone `mine_retour`).
- NON placés : géant, squelette, spectre (style jouet), démon (rig cassé).

### Tests et captures
- `outils/test_betes_quat.gd` (28 vérifications : modèles, contrat, meute, morsure, mort, fuite du cerf, embuscade, rig des habitants).
- `outils/poses_persos_jeu.txt` : lot de captures (place, puits, chasseurs, enclos, pont, quai, loups, cerfs, renard, araignées, gros plans,
  jour 12 h / nuit 22 h) ; `Desktop/Skyrim captures/persos_jeu/` (avant/ = `--persos-anciens`, apres/, planches, film).
