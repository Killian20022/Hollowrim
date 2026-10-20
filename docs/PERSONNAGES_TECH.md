# Personnages — fiche technique

## Vivants (humains : joueur, villageois, bandits) — branche `graphisme/persos-base`

### Les 3 points (décrits AVANT le code)
- **Macro (silhouette)** : un seul corps de base par morphologie (homme 1,81 m, femme 1,72 m ; squelette Quaternius conservé), **fermé**, 668 triangles + 96 de bagues,
  skinné **rigide (1-2 os par sommet)** sur RIG18. Épaules larges, taille marquée, mains et pieds un peu grands. Tête séparée (3 volumes de visage), coiffure (3), barbe (2).
  Les rôles se lisent à 20 m par la silhouette : robe longue + mante, tablier + bras nus, capuche + carquois, cape longue, casque + bouclier, capuche + fourrure dépareillée.
- **Méso (vêtements en couches)** : chaque couche est calculée sur les anneaux du corps à une marge de 1-4 cm (gilet +2,2 cm, tablier +3-4 cm, cape +4 cm, bagues +1,2-1,4 cm) :
  aucun vêtement « peint sur la peau ». Robes et jupes : **panneaux** (deux côtés pondérés sur la cuisse et le mollet du côté, avant et arrière internes sur ressort) ;
  capes, tablier, capuche : **5 os secondaires** hors RIG18 animés par ressort (`PersoRessorts`). Bagues de recouvrement aux jointures : ceinture, collet, bracelets, revers de bottes.
- **Micro (textures)** : atlas **256×256 par morphologie**, **48 texels/m** (constante unique `densite` dans `mise_en_page_<sexe>.json`, visage = tunique), **indices** (ton 0-7 + région) et non des couleurs :
  une rampe de 8 tons (ombres froides, lumières chaudes) est calculée dans le shader à partir de la couleur de base de la région (**paramètre d'instance**), quantifiée en **15 bits**.
  Arêtes claires peintes (ourlets, cols, nez, pommettes), broderies au fil d'or, coutures, cuir cloué ; bruit à seuil, jamais Bayer.

### Chaîne de fabrication (rejouable)
1. `sources_blender/rig18.txt` : les 21 os gardés (noms réels du squelette Quaternius, `root` + 20 os déformants : bassin, 3 vertèbres, cou, tête, 2 × [clavicule, bras, avant-bras, main], 2 × [cuisse, mollet, pied]).
   Doigts, orteils et feuilles supprimés (poids reportés sur le parent). Les animations existantes n'ont rien à changer : leurs pistes sur les os supprimés sont ignorées par Godot.
2. `blender -b --python sources_blender/scripts/base_persos.py -- homme|femme [--apercu=<dossier> --montrer=corps,gilet --zoom=tete]`
   lit `homme_vetu_lot1.glb` / `femme_vetue_lot1.glb` (squelette seulement), écrit `assets/modeles/persos/kit_<sexe>.glb` et `assets/personnages/mise_en_page_<sexe>.json`.
   `persos_lib.py` = bibliothèque de modelage : anneaux (ellipses de N sommets) reliés en tubes **fermés**, poids 1-2 os par sommet vérifiés, UV métriques posées dans l'atlas, contrôle « UV hors rectangle » (0) et liste des arêtes de bord par partie.
3. `godot --headless --import` puis, facultatif, `godot --headless --script res://outils/generer_atlas_persos.gd` (atlas précalculés `assets/personnages/atlas_<sexe>.res`, repli par calcul direct : 150 ms par atlas).
4. `Personnage.creer(PersoDef)` : instancie le kit, libère les pièces inutiles, matériau partagé + paramètres d'instance, bibliothèque d'animations, ressorts.

### Budgets par variante (mesurés par `outils/test_persos_base.gd`)
| Pièce | Triangles | Remarque |
|---|---|---|
| corps (668 → 660) + bagues (88) | **748** (budget 600-750) | torse, cou, 2 manches, 2 mains + pouces, 2 jambes, 2 bottes ; ceinture, collet, 2 bracelets, 2 revers |
| tête 1 / 2 / 3 | 196 | crâne 10 faces, nez, 2 oreilles |
| cheveux 1 / 2 / 3 | 110 / 150 / 188 | calotte, mi-longs jusqu'à l'épaule, chignon + natte |
| barbe 1 / 2 | 48 / 78 | courte, tressée (+ natte) |
| gilet / tablier / robe | 96 / 48 / 160 | robe = 2 panneaux de côté + panneaux avant / arrière |
| cape courte / longue | 40 / 64 | collet de fourrure + panneau dorsal |
| capuche / épaulières / lanières | 170 / 84 / 32 | |
| sacoche / carquois | 36 / 36 | |
| **variantes complètes** | **1 148 (garde) à 1 338 (völva)** | contre ≈ 7 000 pour l'ancien corps vêtu (3 768 de corps + vêtements) |

Os : **26** (21 de RIG18 + 5 secondaires `cape_1`, `cape_2`, `capuche_1`, `pan_av_1`, `pan_ar_1`). Matériaux : **2 par morphologie** (un à faces cullées, un double face avec texels découpés), partagés par tous les PNJ ;
8 paramètres d'instance (`c_peau`, `c_tun`, `c_pan`, `c_cuir`, `c_sur`, `c_cheveux`, `c_four`, `c_iris`) + `eclair`. Textures : 2 atlas 256² RGBA8 (256 Ko chacun, indices), 48 texels/m.
Étanchéité : toutes les extrémités ouvertes du corps sont recouvertes par une pièce voisine (haut des jambes dans le torse, bas des jambes dans les bottes, poignets dans les manchettes, bas des manches sous les bracelets, haut des bottes sous les revers, cou sous le collet et sous la tête) ; les panneaux d'étoffe ouverts sont rendus **double face**.

### Créer une variante (aucune scène à dupliquer)
1. Dans `scripts/perso_defs.gd`, ajouter un dictionnaire (`VILLAGEOIS`, `BANDITS`) ou un nouveau `static func` :
   `{"corps": "femme", "tete": 2, "cheveux": 3, "barbe": 0, "tunique": "mousse", "sur": "bordeaux", "pantalon": "brun", "cuir": "cuir_a", "fourrure": "gris", "accessoires": ["gilet", "cape_courte"], "casque": "", "bouclier": false}`.
2. Champs de `PersoDef` : `corps` homme|femme, `tete` 1-3, `cheveux` 0-3, `barbe` 0-2 (hommes), couleurs (`peau`, `couleur_cheveux`, `iris`, `tunique`, `pantalon`, `cuir`, `sur`, `fourrure` : nom de palette ou `Color`),
   `accessoires` parmi `gilet, tablier, cape_courte, cape_longue, capuche, robe, epaulieres, pteruges, sacoche, carquois`, `casque` (`casque_nasal`, `couronne_givre`, `casque_draugr`), `bouclier`, `ressorts`, `echelle`.
3. Palettes de tunique : `lin` (écru), `cuir` (tanné), `mousse` (vert), `bordeaux` (laine), + `bleu, gris, violet, brun`. Autre couleur : passer une `Color` (la rampe de 8 tons et la palette 15 bits sont recalculées dans le shader).
4. `var n := Personnage.creer(PersoDefs.villageois("chef"))` ; `add_child(n)` ; `n.get_node("Animations").play("Idle")`. Vérifier : `outils/galerie_base.gd -- --perso=<nom>` (statique) et `-- --anim=Walk --images=8` (bande animée).
5. Ajouter une pièce de vêtement : une fonction dans `base_persos.py` (anneaux du corps + marge), relancer Blender pour les deux sexes, ajouter son nom dans `Personnage.pieces_de` si elle a un test, éventuellement ses chaînes dans `PersoRessorts.PAR_ACCESSOIRE`.

### Ressorts (`scripts/perso_ressorts.gd`)
SpringBoneSimulator3D (Godot 4.7) : cape (2 os), capuche (1), pan avant (1), pan arrière (1) ; **7 capsules de collision** (colonne, haut du dos, bassin, 2 cuisses, 2 mollets) ; coupés au-delà de **15 m** de la caméra (reprise à 13,5 m, os revenus au repos).
Réglages trouvés à la galerie animée (`outils/galerie_base.gd -- --anim=Walk --live --vit=1.3`, le personnage avance : inertie réelle) :
- **cape : rigidité basse (0,12), gravité forte (5)** : elle pend d'aplomb au lieu de suivre le buste penché (rigidité 0,55 : la cape s'écartait de 40° du dos à la marche, car ses os sont rigidement liés à `spine_03`) ;
- **pans : rigidité 1,2, gravité 2, rayon 0,015** ; **direction du bout d'os = +Y local** (`BONE_DIRECTION_PLUS_Y`) : avec `FROM_PARENT` la direction « du bassin vers le pan » est l'horizontale et les pans se couchaient en planche à 90° (constaté en galerie).
`outils/test_persos_base.gd` vérifie en course (Sprint à 4,5 m/s) que l'os de cape reste hors de la capsule du dos (0,150 m mesuré pour un rayon de 0,150 m) et que le pan avant reste à > 0,04 m des hanches.
Coût mesuré (`outils/mesure_ressorts.gd`, 12 volvas qui marchent, 4 chaînes chacune) : **≈ 0,02-0,03 ms par PNJ et par image** (temps de process, bruit de mesure ≈ ±0,3 ms sur 12 PNJ) ; option `--sans-ressorts` pour les mesures A/B.

### Perf (outils/mesure_perf.gd, vsync coupé, 4 agents actifs sur la machine : indicatif ; A/B alternés avec une copie de la base 8b6c2a6)
| Pose | Base 8b6c2a6 | Cette branche |
|---|---|---|
| village `--pose=32,30,-125,0` | 7,43 / 6,90 / 6,87 ms GPU (moy. 7,07) ; 503-513 appels ; 366-373 k primitives | 6,64 / 6,75 / 6,48 ms GPU (moy. 6,62) ; 440-444 appels ; 305-306 k primitives |
| camp des bandits `--grotte=93.5,0.5,0,-4` | 1,56 / 2,15 ms GPU (moy. 1,86) ; 188 appels ; 52,9 k primitives | 1,71 / 1,85 ms GPU (moy. 1,78) ; 164 appels ; 24,5 k primitives |

### Défauts restants (honnêtes)
- Les panneaux de robe (côtés sur cuisse / mollet, avant / arrière sur ressort) se voient **par la tranche** en profil strict à certaines images de Course (trait fin du bassin au genou) ; pas de dalle, pas de trou, mais ce n'est pas un tissu simulé.
- Le tablier et les pans restent des plaques d'un seul os de ressort (budget 26 os) : pas de pli.
- Pas de gants de cuir en 3e personne (mains nues + bracelets) ; les bras FPS gardent gants et manches du lot 6 (palette alignée : tunique bleue = laine des manches, cuir sombre).
- Les visages sont petits (têtes à 1/8 de la hauteur, atlas à 48 texels/m : un visage fait ≈ 9 × 11 texels) : lisibles à 2 m, un simple pixel de couleur à 8 m.
- Les anciens corps (`Humain.creer`) restent utilisés par les draugrs, Eirik et le scénario `galerie` de `monde.gd` (hors périmètre) ; `villageois.gd` garde `APPARENCES` pour ce scénario.
