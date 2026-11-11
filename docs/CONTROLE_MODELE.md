# Contrôle automatique des modèles rigués

À lancer **avant** de montrer un PNJ / une armure Tripo à l'utilisateur : le contrôle refuse (`CONTROLE ECHEC`, code de sortie 1) un modèle
qui a un des défauts récents : avant-bras réduit à une tige, main détachée ou arrachée, éclats flottants près du poignet, trous,
triangles hors budget. Aucune fenêtre, aucun rendu : tout est calculé sur le CPU à partir du `Skeleton3D` (≈ 2 s par modèle).

Fichiers : `outils/controle_modele.gd` (ligne de commande), `outils/controle_modele_lib.gd` (`ControleModele`, la logique),
`outils/test_controle_modele.gd` (test), `sources_blender/scripts/controle_modele.py` (complément Blender).

## Usage

```bash
G=/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe ; W=$(wslpath -w <worktree>)
bash /tmp/godot_slot.sh $G --headless --path "$W" --script res://outils/controle_modele.gd -- \
     --modele=<.glb | res://scène | garde:<id> | dore> [--clips=Idle,Walk,Sword_Idle,Sword_Attack] [--images=5] [--budget=12000] \
     [--json=<rapport.json>] [--planche=<png>] [--seuil.<nom>=<valeur>]
```

- `--modele` : chemin Windows d'un `.glb` (lu **sans import**, n'importe où sur le disque : sert à figer une version avec
  `git show <sha>:assets/pnj/x.glb > fichier`), une ressource `res://`, `garde:<id>` (`GardeTripo.creer`, avec arme et poing rapportés :
  `garde:tripo_garde_epee`, `garde:tripo_garde_verre`...) ou `dore` (garde en armure dorée v10, `GardesVillage.creer_modele_dore`).
  Plusieurs modèles : les séparer par `;`.
- `--clips` : clips de `Humain.bibliotheque()` (ou de l'`AnimationPlayer` du modèle) échantillonnés sur `--images` instants chacun
  (défaut : Idle, Walk, Sword_Idle, Sword_Attack, 5 images). Le repos (T-pose du GLB) est toujours mesuré.
- `--seuil.<nom>=x` remplace un seuil (tableau ci-dessous), ex. `--seuil.ecart_max=0.04`.
- `--planche=f.png` : planche de gros plans des bras (colonnes face | dessus ; lignes : bras gauche repos, bras droit repos, puis les deux
  au milieu du premier clip). Seul volet qui rend une image : **lancer sans `--headless`** (`godot_slot.sh` ouvre alors la fenêtre hors écran).
- Sortie : lignes de détail chiffré, puis `CONTROLE OK  <modèle>` ou `CONTROLE ECHEC  <modèle>` précédé des lignes `ECHEC : ...`.
  `--json` écrit le rapport complet (poses échantillonnées, composantes, éclats avec leur position dans le repère du squelette).
  Code de sortie : 0 = tous OK, 1 = au moins un échec, 2 = usage.
- Test : `godot --headless --path . --script res://outils/test_controle_modele.gd` (cas du jeu, sensibilité, cas connus mauvais).
  Les cas connus mauvais sont lus dans le dossier voisin du worktree `../nordique_controle_essais/` (sautés s'il est absent) ; le recréer :
  `mkdir -p ../nordique_controle_essais && git show 52855e04:assets/pnj/tripo_garde_epee_rig.glb > ../nordique_controle_essais/epee_v2b.glb && git show 919c26e5:assets/pnj/tripo_garde_verre_rig.glb > ../nordique_controle_essais/verre_919c.glb`.
- Blender, INVENTAIRE non bloquant (composantes, éclats, arêtes ouvertes / non-manifold, petits trous, sans squelette ni zone : le garde
  validé y a 11 éclats < 12 faces ; seul l'outil Godot donne le verdict ; `--strict` pour un code de sortie 1 s'il trouve un éclat) :
  `blender.exe -b --python sources_blender/scripts/controle_modele.py -- --glb=<f.glb> [--eclat=12] [--soudure=0.0005] [--trou=0.03]`.

## Ce qui est mesuré

| Volet | Méthode | Échec si |
|---|---|---|
| Triangles | somme des triangles des pièces **visibles** (corps masqué de l'armure dorée exclu, armes exclues) | `> budget_tris` |
| Éclats | sommets soudés (0,5 mm) puis composantes connexes de faces, au repos ; position = centre, os dominant | composante `< eclat_faces` faces **dans la zone poignet** (voir plus bas) ; ailleurs : seulement listé |
| Trous | boucles d'arêtes ouvertes (une seule face) de périmètre `< trou_perimetre` | plus de `trous_max` |
| Étirement des os | longueur épaule-coude, coude-poignet, poignet-base du majeur, pose / repos | `> etirement_max` |
| Étirement de la géométrie | peau recalculée sommet par sommet (poids x matrices d'os) ; rapport pose / repos des **arêtes internes** à chaque segment (sommets dominés par le même os) : médiane à l'épaule, 75e centile à l'avant-bras et à la paume | `> etirement_max` |
| Largeur main / avant-bras | diamètre de Feret (12 directions) de la paume (ou, sans géométrie sur l'os de main, des 6 derniers cm du bras) / de l'avant-bras à mi-longueur | hors `[largeur_min ; largeur_max]` ; hors `[cible_min ; cible_max]` : avertissement |
| Continuité | couverture 1D des triangles avant-bras + main le long de l'axe coude -> poignet -> doigts, sur toutes les images : plus grand intervalle sans géométrie | `> ecart_max` |
| Arme tenue | `BoneAttachment3D` portant un nœud `Epee*` : distance milieu de poignée -> paume (centre des sommets de la main, ou du poing fermé rapporté), angle lame / avant-bras (0-90°), au repos et sur les clips | distance `> arme_paume_max` ou angle `> arme_angle_max` |

Zone poignet (éclats) : de la moitié de l'avant-bras à 0,8 longueur de paume après le poignet, à moins de `eclat_rayon` de l'axe
coude -> poignet -> base du majeur. Le coude (pli) et le bout des doigts (capuchons de 5-6 faces des gantelets) sont exclus.

## Seuils (calibrés sur les modèles validés)

| Seuil | Valeur | Mesuré sur les modèles validés | Mesuré sur les cas mauvais |
|---|---|---|---|
| `budget_tris` | 12 000 | 5 583 (garde épée) ; 8 905 (verre v2) ; 10 926 (dorée v10) | 6 172 ; 10 283 |
| `eclat_faces` | 12 | aucun éclat en zone poignet (éclats hors zone : tête, tabard, coude : 3 à 11 faces) | verre 919c : 6 faces à 3,8 cm du poignet droit ; v2b : 1, 2 et 10 faces autour de `hand_l` / `lowerarm_l` |
| `eclat_rayon` | 0,15 m | – | piste 919c à 10,4 cm de l'axe |
| `etirement_max` | 0,15 | os 0 % ; géométrie 0 à 4,5 % (jusqu'à 5,7 % sur 919c et 4,4 % sur v2b) | piste de test : avant-bras mis à l'échelle 1,35 : os 35 %, géométrie 18 % ; main arrachée : os 85 % |
| `largeur_min` / `largeur_max` | 0,6 / 1,4 | 0,71 (dorée) à 0,94 (poing du garde épée) | v2b main gauche : 1,39 (juste sous le seuil : avertissement) |
| `cible_min` / `cible_max` | 0,75 / 0,80 | seuls verre v2 droit (0,79) y est ; les autres sont en avertissement | – |
| `ecart_max` | 0,025 m | 0,0 cm partout | v2b : 11,7 cm (main gauche), 3,8 cm (droite) ; au repos 3,1 à 3,6 cm |
| `trou_perimetre` | 0,03 m | – | – |
| `trous_max` | 250 | verre v2 : **188** petits trous (maillage non soudé, validé par l'utilisateur) ; autres 0 | verre 919c (v3c, rebouché) : 1 |
| `soudure` | 0,0005 m | – | – |
| `arme_paume_max` | 0,10 m | 3,3 cm (garde épée) ; 5,2 cm (verre) | – |
| `arme_angle_max` | 85° | garde épée 12° ; verre 6° à 78° (poignet fléchi de 75° hors clips d'épée) | – |

Réglages à connaître : `trous_max` est volontairement haut (le verre v2 validé en a 188) : il ne repère qu'un maillage nettement troué ;
`arme_angle_max` est lâche (il ne détecte qu'une lame perpendiculaire au bras) ; la cible 0,75-0,80 n'est qu'un avertissement car aucun
des modèles validés ne la respecte partout (la règle « armure = 1,1 à 1,25 x main nue » n'est pas automatisée).

## Résultats de validation

| Modèle | Résultat | Détail |
|---|---|---|
| `tripo/epee_gardes` 52855e04 (v2b), GLB figé par `git show` | **ECHEC** (attendu) | 11,7 cm sans géométrie entre brassard et main gauche, 3,8 cm à droite ; 3 éclats autour de la main gauche (1, 2 et 10 faces) |
| `tripo/armure_verre` 919c26e5 | **ECHEC** (attendu) | éclat de 6 faces en [-0,668 ; 1,437 ; 0,029] près de `lowerarm_r` |
| garde Tripo à l'épée (`garde:tripo_garde_epee` et GLB du jeu) | OK | poing mesuré à l'extrémité de l'avant-bras (avertissement), arme à 3,3 cm de la paume |
| armure de verre v2 (`garde:tripo_garde_verre` et GLB) | OK | arme à 5,2 cm de la paume, lame 6°-78° |
| armure dorée v10 (`dore`) | OK | rapport main / avant-bras 0,71 (avertissement) |

## Limites

- Les clips sont posés os par os depuis les pistes de l'`Animation` ; seul `PoignetRepos` (armure de verre) est rejoué. Ressorts du
  tabard, IK des pieds, `LanceDroite`, `SuiviTete`, ragdoll ne le sont pas.
- La peau est calculée sans les formes de mélange et sans la matière (double face, shader PS1) ; le contrôle ne juge pas la texture.
- Un « défaut visuel » sans signature géométrique n'est pas vu : la v2b a un avant-bras fin au coude (0,169 / 0,091 m au poignet) qui
  n'est pas distinct de celui du garde validé ; elle est refusée pour la main détachée et les éclats, pas pour la « tige ». Le contrôle
  complète la vérification sur images (planche `--planche`), il ne la remplace pas.
- L'étirement de géométrie utilise des centiles d'arêtes (le mélange de poids clavicule / bras étire de 100 % les arêtes extrêmes de
  l'épaule des modèles validés) : un étirement très localisé (< 25 % des arêtes d'un segment) passe.
- Le garde brut (GLB seul) n'a ni épée ni poing rapportés : pour juger l'arme et la main du garde à l'épée, utiliser `garde:<id>`.
- Le repère de sortie est celui du `Skeleton3D` (sans l'échelle du nœud racine) ; les distances sont en mètres du modèle de base.
- Éclat : seuil de faces et soudure à 0,5 mm ; un modèle dont les sommets ne sont pas soudés par position (UV éclatées) peut produire
  de faux éclats : ajuster `--seuil.soudure`.
- Windows : `godot_slot.sh` impose un délai quand 3 Godot tournent déjà ; l'outil lui-même ne tue aucun processus.
