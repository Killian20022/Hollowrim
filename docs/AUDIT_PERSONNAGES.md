# Audit du système de personnages (étape 1 de la refonte des persos, branche `refonte/persos_audit`)

Base : `refonte/base` 5f715ca. Aucun fichier du jeu modifié. Outils ajoutés : `outils/galerie_audit_persos.gd` (galerie 640x360 + mesures),
`outils/capture_audit_jeu.gd` (captures en jeu devant une cible), `outils/planche_audit_persos.gd` (planches de comparaison),
`outils/poses_audit_persos.txt` (lot `--captures`, essai, voir § 7).
Captures et planches : `C:\Users\lopezk19\Desktop\Skyrim captures\refonte\persos\audit\` (`galerie\`, `jeu\`, `planche_*.png`).

Chiffres : **mesurés** (galerie, en-têtes glTF, code) sauf mention contraire.

---

## 1. Structure : qui construit quoi

Trois fabriques, un seul contrat : nœud racine → `Armature/Skeleton3D` + `AnimationPlayer` nommé **`Animations`** (root_node `..`),
modèle tourné vers **+Z**, animations résolues **par nom d'os** (pas de retarget, pas de BoneMap).

| Type | Construction | Géométrie | Triangles (mesurés, tout compris) | Os | Textures | Animations | Ragdoll | Comportement |
|---|---|---|---|---|---|---|---|---|
| Joueur 3e pers. | `corps_joueur.gd:51` `Personnage.creer(PersoDefs.joueur())` | `assets/modeles/persos/kit_homme.glb` (Blender `base_persos.py`) | 1 318 | 26 | atlas indices 256² (`perso.gdshader`) | bibliothèque commune ; Sword_Idle, Sword_Attack, Walk/Jog_Fwd/Sprint, Jump_*, Hit_Chest, Idle_Torch, Death01 | oui | joueur.gd |
| Bras FPS | `mains.gd:174` | `assets/modeles/joueur/bras_fps.glb` (2 436 tris, 65 os) | — | 65 | ObjetsTextures + Palette | procédural (TwoBoneIK3D), poing = 1re image de Punch_Cross | — | mains.gd |
| Villageois (chef, forgeron, chasseuse, völva, garde, ancienne) | `villageois.gd:144` `Personnage.creer(PersoDefs.villageois(id))` | kit_homme / kit_femme | chef 1 346, forgeron 1 230, chasseuse 1 270 | 26 | atlas 256² | Idle, Walk, Idle_Talking, Interact, PickUp_Table, Fixing_Kneeling, Spell_Simple_Idle + `SuiviTete` (cou/tête) | **non** | villageois.gd |
| Garde (Haldor) | villageois + `casque_nasal.glb` (600 tris) + `bouclier_rond.glb` (748 tris) **dans le dos** | kit_homme | 2 540 | 26 | atlas 256² + casque/bouclier `Palette` 32² | idem villageois | non | villageois.gd |
| Bandits (grotte) | `grotte_jeu.gd` → `monde.creer_draugr("sbire", {"apparence": {"perso": PersoDefs.bandit(k)}})` → `draugr.gd:173` | kit_homme + épée `epee_nordique.glb` (1 490 tris) | bandit casqué 3 368 | 26 | atlas + Palette | animations de draugr.gd | oui | **draugr.gd** |
| Bandit archer | idem + `_armer_arc` (maillage « arc » du squelette re-skinné) | kit_homme | 1 298 | 26 | + `bois_arc` | Pistol_Aim_Neutral, Pistol_Shoot | oui | draugr.gd |
| Hrafn (boss bandit) | `grotte_jeu.gd` + `boss: "hrafn"` (×1,08) | kit_homme + casque | non mesuré (≈ bandit casqué) | 26 | atlas | draugr.gd | oui | draugr.gd |
| Draugr sbire | `draugr.gd:177` `Humain.creer({"draugr": true …})` | `assets/modeles/humains/homme_vetu.glb` (corps Quaternius « Superhero » 3 768 tris + vêtements lot 4) | **8 509** | **65** | PersonnagesTextures 64 tx/m : 128x64, 128x8, 64x32, 128², peau 256² | Sword_Idle, Sword_Attack, Punch_Cross, Walk, Jog_Fwd, Idle, Death01 (et à l'envers pour le réveil), Hit_Chest/Head, Interact, Spell_* | oui | draugr.gd |
| Draugr guerrier | idem + cotte `mailles_rouille`, épaulières, ptéruges, cape courte, `casque_draugr.glb` (572 tris) + épée | homme_vetu.glb | **10 845** | 65 | idem (18 surfaces) | idem | oui | draugr.gd |
| Jarl Kolbeinn (boss) | guerrier + `boss: "jarl"` (×1,12) | homme_vetu.glb | 10 845 | 65 | idem | idem | oui | draugr.gd |
| Svanhild (boss) | `tertre.gd:670` guerrier + apparence femme, `couronne_givre`, cheveux `Hair_Long` | femme_vetue.glb | **14 004** | 65 | idem + **une texture 2048²** (cheveux Quaternius) | idem | oui | draugr.gd |
| Eirik (cadavre) | `tertre.gd:500` `Humain.creer` | homme_vetu.glb | — | 65 | idem | Death01 figé | non | aucun |
| Squelette / squelette archer | `draugr.gd:175` `SqueletteGuerrier.creer({"arme"})` | `assets/modeles/squelettes/squelette_guerrier.glb` (Blender `squelette_guerrier.py`) | 590 / 596 | 25 | atlas 256², **32 tx/m**, `ps1.gdshader` | idem draugr, attaque = Sword_Attack seule | oui | draugr.gd |
| Dragon de givre | `monde.gd:586`, script `dragon.gd` | **100 % procédural** (SurfaceTool, troncs à 6 pans, ailes reconstruites à chaque image) | 912 au repos (65 surfaces) | 0 | Palette 32² (écailles, corne, membrane) | procédural (`_animer`, IK de genou) | non (squelette au sol à la mort) | dragon.gd |
| Troll / animaux | **n'existent pas** | — | — | — | — | — | — | — |

Effectifs : crypte 21 guerriers, 11 sbires, 2 squelettes, 6 squelettes archers ; grotte 12 sbires (bandits) + 1 guerrier ; monde 2 guerriers + 3 sbires.
**Les draugrs sont l'ennemi le plus nombreux et ils tournent encore sur l'ancien corps Quaternius** (8,5 à 14 k triangles, 65 os, 11 à 18 surfaces),
alors que les vivants sont passés à la base unifiée (1,2 à 1,4 k triangles, 26 os, 6 à 8 surfaces, 2 matériaux partagés).

Restes morts : `Superhero_*_FullBody.gltf`, `assets/modeles/joueur/mains.glb`, modèles KayKit (`villageois/*.glb`, `squelettes/Skeleton_*`) : plus référencés.
Les en-têtes de `draugr.gd` et `villageois.gd` parlent encore de « KayKit » (faux).

## 2. Géométrie, squelette, animations

- **Géométrie** : rien n'est « primitive Godot » chez les humanoïdes. Base unifiée = anneaux d'ellipses modelés par script Blender
  (`sources_blender/scripts/base_persos.py` + `persos_lib.py`), skin rigide 1-2 os/sommet, pièces optionnelles libérées à l'instanciation.
  Draugrs = maillage Quaternius importé (lisse, musculature « super-héros »). Squelette = prismes à 4 pans modelés par script Blender. Dragon = code.
- **Squelette** : `Skeleton3D` partout (sauf dragon). Noms d'os Quaternius : `root, pelvis, spine_01..03, neck_01, Head, clavicle_*, upperarm_*, lowerarm_*, hand_*, thigh_*, calf_*, foot_*`
  (RIG18, `sources_blender/rig18.txt`, 21 os) + secondaires `cape_1, cape_2, capuche_1, pan_av_1, pan_ar_1` (kits, 26 os) ou feuilles `ball_*, middle_01_*` (squelette, 25 os).
- **Animations** : une seule source, `assets/modeles/humains/animations.glb` (43 clips Quaternius, 30 i/s, suffixes `_Loop` retirés à l'import),
  dupliquée par `Humain.bibliotheque()` et partagée par les 3 fabriques. Pistes vers des os absents ignorées. Pas d'AnimationTree.
  Procédural par-dessus : `PiedsAuSol` (TwoBoneIK3D jambes, rayon au sol), `SuiviTete` (villageois), `PersoRessorts` (SpringBoneSimulator3D : cape, capuche ; coupé > 15 m).
  Vitesse de lecture calée sur la vitesse réelle (Walk réf. 1,03 m/s, Jog 6,0 ; joueur 1,3 / 3,0 / 5,2).
- **Ragdoll** (`scripts/ragdoll.gd`) : `PhysicalBoneSimulator3D` créé sous le squelette, 16 corps nommés comme les os (table `DEFS` : pelvis, spine_01, spine_03, Head,
  upperarm/lowerarm/hand, thigh/calf/foot ×2), longueurs lues sur la pose de repos (os enfant : neck_01, middle_01, ball… avec replis si absents),
  rayons fixes (Head 0,10, thigh 0,085, calf 0,06, upperarm 0,045…), 70 kg, calque 16, masque 1. Joueur + tous les ennemis, pas les villageois.

**À ne pas casser** (dépendances par nom) :
1. noms des os ci-dessus, `Head` et `spine_03` codés en dur (impact du ragdoll, casque, bouclier) ; un os renommé = PhysicalBone perdu **sans erreur** ;
2. nœuds `Skeleton3D` (trouvé par `find_child`) et `Animations` ; pose de repos et proportions du rig Quaternius (les 43 clips sont cuits dessus) ;
3. noms de maillages `corps`, `bagues` (test_persos_base), `squelette`, `epee`, `arc` (squelette + `_armer_arc`) ;
4. orientation +Z, pieds à y = 0, hauteur ≈ 1,83 m (humain) / 1,91 m (squelette).
Le bandit archer produit déjà 4 erreurs « Skin bind … `middle_01_l` / `ball_l` … no bone » (skin de l'arc pris sur le squelette 25 os, posé sur un rig 26 os sans feuilles) : bénin mais à corriger dans la refonte.

## 3. Matériaux et textures

| Famille | Shader | Texture | Densité | Couleur |
|---|---|---|---|---|
| Base unifiée | `shaders/perso.gdshader` (copie PS1 : accroche des sommets `grille`, UV affines, + palette à rampes) | 2 atlas 256² RGBA8 d'**indices** (R = ton 0-7, G = région) | 48 tx/m (crâne 128, nez/barbe 96, oreilles 64) ; visage ≈ 22×22 texels | 8 paramètres d'instance (`c_peau`, `c_tun`… `c_iris`), rampe 8 tons calculée, quantifiée 15 bits |
| Draugrs (Humain) | `ps1.gdshader` via `Humain.shader_perso` (nearest + mipmaps) | une texture par pièce, 64 tx/m (8 à 128 px) + peau 256² + cheveux 2048² chez Svanhild | 64 | peinte par `personnages_textures.gd` |
| Squelette | `ps1.gdshader` via `Humain.shader_perso` | atlas 256² (16 % utilisé) | **32** | peint par le script Blender |
| Casques, bouclier, épée, arc, dragon | `ps1.gdshader` via `Palette.materiau` | textures `Palette.tex` 32² en 4 tons | — | 4 tons |

Tout passe bien par la chaîne PS1 (accroche de sommets + affine + post `ps1_post.gdshader`), mais **par deux shaders** (`perso` et `ps1`).
Sur `refonte/base`, la grille d'accroche vaut 135 lignes ; le commit c17e4c8 (branches refonte/lumiere, refonte/village) la rend proportionnelle à la hauteur interne,
`perso.gdshader` compris. `docs/DIRECTION_ARTISTIQUE.md` (refonte/audit) fixe **64 tx/m pour les personnages** : à ce jour seuls les draugrs y sont ; base unifiée 48, squelette 32.

## 4. Contraintes gameplay à préserver

- **Collisions** : capsules CharacterBody3D centrées y = 0,9, hauteur 1,8 : draugr r 0,38 (tous types, boss compris : l'échelle du modèle ne change pas la capsule), villageois et joueur r 0,35 ; `floor_snap_length` 0,4. Dragon : boîte 2,2×3,2×4,4.
- **Coups** : pas de hitbox de maillage. Épée du joueur = distance caméra → `point_impact()` ou position + (0, 1,0, 0), portée 2,3 / 2,7 (+0,4), cône dot ≥ 0,5 ; coups ennemis : distance < 1,9 + 0,6, dot > 0,4. **La forme du modèle n'intervient pas dans le combat** : on peut changer la silhouette librement.
- **Hauteurs** : œil joueur 1,62 ; invite de dialogue à +1,4 ; flèche part de 1,4 × échelle ; ragdoll : impact à 1,5 (tête) ou 1,15.
- **Attaches** : épée = BoneAttachment3D sur `hand_r` avec la transformation `prise` (draugr.gd:25 = corps_joueur.gd:8) ; torche `hand_l` (`PRISE_GAUCHE`) ;
  casque = repos de `Head` (Personnage : ×1,07, +3,2 cm) ; bouclier humain **dans le dos** sur `spine_03`, `Transform3D(Basis(UP, PI), (0, 1,3, -0,2))` ; bouclier du squelette skinné sur `lowerarm_l`.
  Le draugr guerrier « porte un bouclier » dans le commentaire de draugr.gd et le Jarl a `_bouclier = 0,6` (parade) : **aucun bouclier n'est visible sur eux**.
- **Tests** (seuils exacts) :
  - `test_persos_base` : os ≤ 26 et tous ceux de rig18.txt ; corps + bagues ≤ 800 tris ; variante ≤ 1 500 ; atlas 256² ; 5 PNJ de plus = 0 matériau créé ; 9 clips sans piste orpheline ; Sprint 4,5 m/s : `cape_2` à > 0,10 m de l'axe spine_01-spine_03, `pan_av_1` à > 0,04 m des cuisses.
  - `test_ragdoll` (Humain.creer, pente 15°) : cheville Idle 0,03-0,10 m, saut de pose < 0,05 m, os > -0,05 m, bassin < 0,4 m, genou > -10° au repos, recul fort > 0,8 m, faible < 0,6 × fort.
  - `test_mort_ragdoll` : capsule à 0 après la mort, coup puissant dx > 1,0 et |dz| < dx, léger 0 < dx < 0,7 × fort, aucun os < -0,05 m.
  - `test_squelette` : `hand_r` et `ball_l` présents, os ≤ 26, **450-600 triangles**, 70 PV, tas d'os < 0,7 m, étalement < 2,2 m ; `test_squelette_traversees` : volumes du corps **codés en dur** (cuisse, cage y 1,22-1,46 r 0,11, tête y 1,72 r 0,10), 0 traversée à 0,015 m sur 8 clips → casse si les proportions changent.
  - `test_marche_pnj` : vitesses/orientation, tête ±60° (os `Head` > 40°), draugr bassin -0,1..0,35 m après la mort.
  - `test_archer`, `test_patrouille`, `test_boss_phases` : comportement uniquement (PV, dégâts, distances), indépendants du modèle. `test_villageois` : aucune assertion. `test_dragon` : < 3 000 triangles.

## 5. Blender

- **Installé** : `C:\Users\lopezk19\Outils\blender\blender.exe`, version **5.2** (rien sous `C:\Program Files`). Le MCP Blender est aussi disponible dans la session.
- **Pipeline existant et rejouable** : `blender -b --python sources_blender/scripts/base_persos.py -- homme|femme` → `kit_<sexe>.glb` + `mise_en_page_<sexe>.json` ;
  `squelette_guerrier.py` → `squelette_guerrier.glb` + atlas PNG (`outils/blender.sh` pointe un worktree en dur, `nordique_squelette-guerrier`) ;
  puis `godot --headless --import` et précalcul (`generer_atlas_persos.gd`, `generer_squelette.gd`).
- Fichiers : `sources_blender/{homme_vetu,femme_vetue,bras_fps,equipement,mains_et_epee}.blend`, `*_lot1.glb` (squelettes sources), `rig18.txt`.
  Aucun script ne régénère les .glb d'équipement (casques, bouclier) : seulement `equipement.blend`.

## 6. Mesure clé : taille à l'écran à 640x360 (FOV 72° vertical, `keep_aspect` = hauteur)

Formule : pixels par mètre = 360 / (2 · d · tan 36°) = **247,8 / d**. Vérifié par la galerie (boîte des pixels non magenta, caméra horizontale à 0,9 m ; le léger excès à 2 m vient de la perspective et du casque).

| Distance | px/m | Humain 1,83 m (théorie) | Mesuré (garde / forgeron / draugr guerrier / squelette) | Tête 0,21 × 0,23 m | Bouclier Ø 0,79 m | Densité texture « 1 texel = 1 px » |
|---|---|---|---|---|---|---|
| 2 m | 124 | 227 px | 265 / 255 / 237 / 249 | 26 × 28 px | 98 px | 124 tx/m |
| 4 m | 62 | 113 px | 127 / 120 / 111 / 114 | 13 × 14 px | 49 px | 62 tx/m |
| 8 m | 31 | 57 px | 61 / 59 / 54 / 55 | 6-7 × 7 px | 24 px | 31 tx/m |
| 15 m | 16,5 | 30 px | 33 / 32 / 28 / 28 | 3-4 px | 13 px | 16,5 tx/m |

Largeur de silhouette au niveau des yeux (cheveux/casque compris), mesurée : ≈ 24 px à 2 m, 12 à 4 m, 7 à 8 m, 3-4 à 15 m.

**Budget de détail réaliste** :
- La référence draugr (`persos_b.png`, 1024×1536) a un grain estimé à l’œil à ≈ 6 px source (pas mesuré) : le personnage y fait donc ≈ 210-230 « pixels » de haut, **soit exactement notre draugr vu à 2 m**.
  À 4 m (distance de combat la plus fréquente, portée d'épée 2,3-2,7 m + recul), le jeu n'a que la moitié de cette résolution ; à 8 m, le quart.
- Visage : 26×28 px à 2 m, 13×14 à 4 m → un visage peint sur **16×16 à 32×32 texels** suffit ; au-delà rien ne se voit. Les yeux lumineux (2 px) restent lisibles jusqu'à 8 m **seulement s'ils sont émissifs**.
- Bouclier : 98 px à 2 m, 49 à 4 m → texture utile **64×64** (≈ 80 tx/m), 128² au maximum pour les gros plans ; le cerclage de fer et l'umbo doivent faire ≥ 2 px à 4 m (≥ 3-4 cm réels) ou être en géométrie.
- Corps : **64 tx/m** = 1 texel/px vers 3,9 m, 2 px/texel à 2 m (règle de la DA respectée) ; 48 tx/m (base actuelle) = 1 texel/px à 5,2 m, 2,6 px/texel à 2 m (pâté à 2 m) ; 32 tx/m (squelette) = 3,9 px/texel à 2 m (gros pixels).
- Silhouette : à 8 m le personnage fait 57 px ; ce qui se lit à cette distance = masses (épaulières de fourrure, bouclier, casque, cape), pas les matières. La silhouette doit porter l'identité.

## 7. Captures (dans `...\refonte\persos\audit\`)

- `galerie\<perso>_planche.png` : 3 colonnes (face, 3/4 avant à 35°, dos) × 4 lignes (jour 2 m, jour 4 m, « crypte » 2 m, « crypte » 4 m), 640x360 chacune,
  pour garde, chef, forgeron, chasseuse, joueur_3e, bandit_casque, bandit_archer, draugr_sbire, draugr_guerrier, boss_jarl, boss_svanhild, squelette, squelette_archer, dragon.
  « Crypte » = galerie (ambiance bleue sombre + torche à côté de la caméra), pas la vraie crypte. `<perso>_visage.png` = visage 2 m ×4 ; `<perso>_mesure_2m.png` ; `mesures.csv`.
- `jeu\` : captures dans le vrai monde à 640x360 (`--res=640x360`) : garde 2 / 4 / 8 m (face, 3/4, dos), chasseuse et völva à 4 m de jour ;
  dans la crypte avec la torche du joueur : draugr guerrier `cr_ossuaire_2` à 2 / 4 / 8 m (face) et 3/4 / dos sans torche, squelette 3 m et 6 m, sbire (allongé, il dort).
  Le Jarl n'est pas créé tant qu'on n'est pas entré dans sa salle (pas de capture). Forgeron (dans la forge) et cheffe (derrière un mur) : vues bouchées, supprimées.
  Le lot `outils/poses_audit_persos.txt` (repère crypte deviné) tombait sur des piliers : remplacé par `capture_audit_jeu.gd`, qui vise la cible par son identifiant.
- Planches : `planche_ref_draugr__jeu_crypte__galerie_crypte__galerie_jour.png`, `planche_ref_draugr__squelette_jeu__sbire_jeu.png`,
  `planche_ref_ambiance__garde_jeu__ref_crypte__draugr_jeu.png`, `planche_ref_ambiance__villageois_4m_x2.png`, `planche_echelle_garde_2_4_8m_natif.png` (à 15 m la palissade cache le garde).

## 8. Écarts visuels vs références

**Draugr (réf. `persos_b`) vs draugr guerrier actuel** :
- Silhouette : réf. massive en triangle inversé (épaulières de fourrure en lambeaux qui débordent, bouclier rond Ø ≈ 0,8 m tenu **devant**, épée large, jambes écartées) ;
  actuel = corps athlétique lisse, épaules étroites, cape courte plaquée, **aucun bouclier**, épée longue et fine tenue à l'horizontale (Sword_Idle), casque petit et rond.
- Proportions : réf. décharnée (os des avant-bras et tibias visibles, crâne) ; actuel = muscles Quaternius « super-héros », peau bleu lavande, membres pleins.
- Matières : réf. = cotte de mailles grise dominante (motif d'anneaux lisible), cuir brun (baudrier, ceinture à fibule ronde), fourrure blanc cassé déchiquetée, bois fendu cerclé de fer, os ;
  actuel = tunique beige claire unie, jupe en damier rouge/orange/bleu qui se lit comme un **tartan** (la « maille rouillée » est trop saturée et trop régulière), brassards orange.
- Palette : réf. froide et désaturée (gris-bleu, brun, blanc cassé, accents : yeux bleus, feu) ; actuel = beiges et orangés chauds, valeurs moyennes, peu de contraste.
- Détail : réf. = bords en dents de scie (haillons, fourrure), rehauts d'arête d'1 px, ombres internes fortes ; actuel = bords lisses, éclairage doux, aucun bord découpé. Les yeux bleus lumineux, eux, existent déjà et se lisent.
- Le squelette guerrier est le plus proche de la réf. par l'accessoire (bouclier rond au bras, casque conique) mais il est grêle (os de 4 pans), ivoire saturé, sans étoffe ni fourrure, texture à 32 tx/m.

**Troll de givre (réf. `persos_a`)** : aucun troll ni aucune créature quadrupède/velue dans le jeu. Rien à réutiliser hormis le rig (proportions humaines : la réf. a des bras jusqu'aux genoux → animations à refaire ou rig dédié).

**Ambiance (réf. `skyrim_32bits_reference`, `grottes_cryptes_*`) vs garde / villageois** :
- Les vivants sont propres et lisibles, mais : couleurs franches et uniformes (tunique rouge du garde, violet de la völva), peu de micro-contraste ; les réfs ont des clusters de pixels, des rehauts froids sur le haut des volumes et de la **neige sur les épaules/capuches** (absente).
- Lumière : les persos prennent la lumière douce (lambert sans spéculaire) et paraissent « plâtre » ; la réf. lit chaque matière par une arête claire et un fort noir d'occlusion.
- Proportions : têtes à 1/8, mains et pieds simples, silhouettes en tubes : correct à 8 m, pauvre à 2 m (226 px de haut disponibles, la géométrie n'en remplit pas le détail).

## 9. Réutilisable tel quel / à remplacer

**Réutilisable** : rig RIG18 + noms d'os ; les 43 clips d'animation ; `PiedsAuSol`, `SuiviTete`, `PersoRessorts` ; `ragdoll.gd` (si noms d'os et proportions gardés) ;
attaches (`prise` de `hand_r`, `PRISE_GAUCHE`, casque sur `Head`) ; capsules et logique de combat (indépendantes du maillage) ; le contrat de fabrique
(racine + Skeleton3D + `Animations`) ; le pipeline Blender scripté (`persos_lib.py` : anneaux, poids vérifiés, UV métriques, contrôle des bords) ; `PersoDef` pour décrire les variantes ;
le principe « atlas d'indices + rampe dans le shader » (couleurs par instance sans nouveau matériau).

**À remplacer** : la géométrie des draugrs (ancien corps Quaternius, 8,5-14 k tris, 65 os, 11-18 surfaces) ; leurs textures `PersonnagesTextures` ; la texture 2048² des cheveux de Svanhild ;
la « maille » en damier ; le squelette guerrier (32 tx/m, os grêles) ; textures casque/bouclier en 32² 4 tons ; à terme la densité 48 tx/m de la base unifiée → 64.
**À ajouter** : bouclier tenu au bras (accroche `lowerarm_l` ou `hand_l` + pose), un vrai cerclage/umbo, géométrie déchiquetée (fourrure, haillons) en texels découpés double face.

## 10. Risques

1. Proportions : changer la morphologie (draugr décharné, épaules plus larges) fait traverser les bras dans le torse avec les clips Quaternius → vérifier avec `galerie_trous.gd`, et `test_squelette_traversees` a des volumes codés en dur.
2. Ragdoll : rayons fixes calibrés pour un humain moyen ; épaulières/bouclier volumineux pas pris en compte (traversée du sol visuelle possible, pas d'échec de test).
3. Bouclier tenu en main = pas d'animation de garde au bouclier dans la bibliothèque Quaternius (Sword_Idle tient l'épée seule) → pose additionnelle ou bras gauche figé par IK.
4. Perf : remplacer 40 draugrs à 8,5-10,8 k tris par ~1,5-2 k = gain net ; les fourrures en double face découpée coûtent en surdessin, pas en triangles.
5. Deux shaders PS1 (`perso` et `ps1`) : toute nouvelle règle (grille 180, quantification) doit être faite dans les deux.
6. Sauvegarde : aucune donnée de modèle n'y est ; les identifiants fixes des ennemis (`cr_…`) ne doivent pas changer.
7. Le bandit archer émet déjà 4 erreurs de skin (voir § 2).

## 11. Options pour le guerrier pilote

| | A. Procédural Godot enrichi + textures peintes par code | B. Bas-poly modelé dans Blender (à la main/MCP) + texture pixel art peinte, réattaché au rig | C. Hybride : kit Blender **scripté** (`persos_lib.py`) + texture pixel art peinte (ou générée puis retouchée) |
|---|---|---|---|
| Principe | SurfaceTool/ArrayMesh dans un script GDScript, skin calculé, textures `Image` générées | maillage modelé librement, UV dépliées, texture 128-256² peinte texel par texel, skin sur RIG18, export glb | même chaîne que la base unifiée (anneaux, poids vérifiés, UV métriques) mais avec pièces nouvelles (épaulières de fourrure, bouclier tenu, cotte) et une texture **couleur** pixel art à 64 tx/m au lieu de l'atlas d'indices |
| Fidélité à la réf. | faible-moyenne : le code produit des formes régulières, la « main » du pixel art (clusters, rehauts) est difficile à générer | **la meilleure** : silhouette et texels contrôlés un à un | bonne : formes contrôlées par script, texels peints à la main sur la zone utile |
| Coût | élevé pour un résultat moyen (skin à la main dans le code, pas d'outil de visualisation) | élevé par perso (modelage + peinture), faible réutilisation | moyen : le pipeline, les poids et les contrôles existent déjà ; on ajoute des pièces et une couche de peinture |
| Perf | bonne | bonne (budget visé 1,5-2 k tris, 1 atlas 256², 1-2 matériaux) | bonne, identique à B |
| Réversibilité | totale (code) | bonne (un glb remplaçable, rig inchangé) mais peinture non rejouable | **totale** : régénérable par commande, la peinture est un PNG versionné |
| Compatibilité rig/anims/ragdoll | à recoder | oui si RIG18 + noms + proportions gardés | oui par construction (même squelette source `*_lot1.glb`) |

**Recommandation : C**, en démarrant par le guerrier sur `kit_homme` (même rig que le joueur, déjà testé par `test_persos_base`) :
1. pièces nouvelles dans `base_persos.py` (épaulières de fourrure à bord découpé, cotte de mailles, bouclier tenu au bras gauche, cape bleue plus large) ;
2. densité portée à 64 tx/m et **texture couleur peinte** pour les zones lisibles (visage 32², bouclier 64², fourrure, mailles), en gardant la rampe d'instance pour les teintes de tissu si possible ;
3. vérifier à 640x360 avec `galerie_audit_persos.gd` à 2 / 4 / 8 m contre la réf., puis faire du draugr une variante du même kit (os/peau décharnés, haillons), ce qui supprime l'ancien corps Quaternius.
Garder B en réserve pour les créatures sans équivalent humain (troll de givre : rig et animations à créer).
