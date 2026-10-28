# Magie : impact des sorts SUR LES CORPS (socle + feu) — branche magie/impact_feu

Cahier des charges : `references/magie/prompt_impact_sorts.md` ; référence visuelle : `references/magie/feu_fps_1100.jpg`.
Visuels seulement (aucune logique de jeu). Le jet en main est refait à part (magie/jets_continus) : ici, ce qui se passe
au contact et sur le corps.

## Principe

Un **foyer** = un corps touché par une école. Tout part de la **surface du corps** :

| Couche | Fichier | Rôle |
|---|---|---|
| Points de surface | `scripts/magie/surface_corps.gd` (`SurfaceCorps`) | ~250 points tirés sur les maillages visibles (pondérés par l'aire), rattachés à l'os dominant ; positions / normales recalculées chaque image par os (multiplication native d'un PackedVector3Array par os, ~30 os) → suivent animation, attaque, chute, **ragdoll** et **décapitation** (poses lues au signal `skeleton_updated`, donc APRÈS les modificateurs : PhysicalBoneSimulator3D, CouTranche, Raideur). |
| Émetteurs de surface | `shaders/magie_corps_part.gdshader` | shader de particules : chaque particule tire un point par rejet selon le POIDS de son mode (côté tourné vers le jet, bord de la silhouette, point d'impact, foyers de brûlure, bas du corps). Points dans 2 textures RGBA flottantes (xyz tassés : le RGB flottant n'est pas échantillonnable sur Iris Xe). Dessin : `magie_part_add` / `magie_part_mix` (carrés de pixels, traînées), comme le reste de la magie. |
| Coque | `shaders/magie_corps_coque.gdshader` | copie skinnée des maillages du corps (même maillage, même peau, même squelette ; pool de MeshInstance3D), gonflée, soulevée en langues et **entraînée dans le sens du jet sur le bord de la silhouette** ; dessinée dans la couche fine avec l'occlusion du monde : le corps reste lisible au centre, les flammes débordent de son contour. |
| Voile | `shaders/magie_corps.gdshader` | `material_overlay` partagé : lueur en paliers autour du point touché, contour rougeoyant, braises, carbonisation (mélange prémultiplié : éclaire ET assombrit). |
| Répulseur | `GPUParticlesAttractorSphere3D` (pool) | ellipsoïde du corps (d'après ses os) qui écarte les particules du JET : elles glissent autour au lieu de s'entasser devant. |
| Gestion | `scripts/magie/impact_corps.gd` (`ImpactCorps`) | pool de 4 foyers × (6 émetteurs, 12 coques, 1 répulseur, 2 textures), budget de particules, préchauffe, points d'accroche. |
| Comportement feu | `scripts/magie/feu_corps.gd` (`FeuCorps`) | réglages des 6 émetteurs + logique sous le jet / brûlure / extinction. |

**Rien n'est créé par impact** : tout est construit à la création du pool (préchauffe du chargement) ; un impact affecte
des textures (mise à jour), des paramètres d'instance et des `material_overlay` vers LE matériau partagé
(`outils/test_impact_corps.gd` vérifie compteurs du module, nœuds et ressources du moteur).

## Points d'accroche (une ligne chacun dans `gestion_magie.gd`)

| Où | Appel | Effet |
|---|---|---|
| `_jet_gerbe` (début) | `if ImpactCorps.jet_gerbe(self, j): return` | corps visé pris en charge : plus de gerbe en boîte ni d'enveloppe posée devant ; plus de « léchage » au centre du corps ; particules du jet prolongées de 15 % (elles passent autour du corps) |
| `statut_cible` (début) | `if ImpactCorps.statut(self, cible, statut, duree): return` | `brulure` rendue sur la surface (plus de boîte de particules ni de voile dupliqué par maillage) |
| `tout_arreter` | `ImpactCorps.arreter_tout()` | foyers éteints, réserve rendue |
| `vitrine_prechauffe` | `ImpactCorps.vitrine(self, v)` | crée le pool + émetteurs / coque / voile dans la vitrine (pipelines compilés au chargement) |

`ImpactCorps.actif = false` (ou `--sans-impact-corps` dans l'outil de captures) rend exactement le rendu d'avant.

## API pour les autres écoles (agent B)

```gdscript
# 1) un comportement = un script statique, enregistré dans ImpactCorps.COMPORTEMENTS (ex. "glace": preload(".../glace_corps.gd"))
const REGLAGES := [ {...}, ... ]          # 6 réglages, un par émetteur du foyer (ordre = index ; {} = émetteur éteint)
static func debut(ic: ImpactCorps, f: ImpactCorps.Foyer) -> void          # f.d = état initial
static func jet(ic, f, info: Dictionary) -> void      # chaque image où un jet touche : {o, dir, rayon, dbl, id}
static func statut(ic, f, nom: String, duree: float) -> bool              # duree 0 = retiré
static func embraser(ic, f, point: Vector3, dir: Vector3, force: float, duree: float) -> void   # impact ponctuel
static func maj(ic, f, dt: float) -> bool             # faux = fini (le foyer est rendu au pool)

# 2) outils du socle utilisables dans maj()
ic.regler_jet(f, dir, k_jet, point, rayon)          # (ajout 5215947) paramètres du jet pour les 6 émetteurs ; point relatif
ic.regler_foyers(f, k_foyers, sol_y, liste)         # (ajout 5215947) liste = jusqu'à 4 Vector4 (xyz relatif, w rayon)
ic.uniformes(f, "dir_jet", Vector3)      # API d1bb7c6, CONSERVÉE : dir_jet, k_jet, point_impact, rayon_jet, k_foyers, sol_y,
                                          # foyers sont redirigés vers les paramètres du foyer (texture, voir plus bas) ;
                                          # tout autre nom reste un set_shader_parameter sur les 6 matériaux (à éviter par image)
ic.activer(f.em[k], part)                # part active 0..1 (réserve dans le budget de GestionMagie, plafond respecté)
ic.voile(f, "mc_feu", Vector4(...))       # canaux du voile ET de la coque (paramètres d'instance)
ic.repousser(f, k)                        # répulseur du jet (0 = éteint)
ic.gm.lumiere(cle, pos, couleur, energie, portee, prio)
f.surface.pos / nor / nb / os_de / point_vise(o, dir) / foyers_pres_de(p, k, rng) / masse_centre / masse_demi / bas / haut
f.origine()                               # repère des points (relatifs à la position globale de la cible)

# 3) entrées publiques
ImpactCorps.jet_gerbe(gm, j) -> bool      # depuis _jet_gerbe : écoles présentes dans COMPORTEMENTS
ImpactCorps.statut(gm, cible, nom, duree) -> bool   # table statut → école dans statut() (brulure → feu ; ajouter gel, choc, corruption)
ImpactCorps.embraser(cible, ecole, point, direction, force := 1.0, duree := 3.0) -> bool   # projectiles, explosions
ImpactCorps.stats() -> {foyers, particules, crees, lectures}
```

Réglage d'émetteur (`ImpactCorps.configurer`) : `mode` (`langues`, `contour`, `eclabousse`, `escarbilles`, `fumee`, `sol`),
`n`, `vie`, `vitesse`, `gravite`, `amorti`, `ouvert`, `ecarte`, `turb`, `suit_jet`, `taille`, `courbe` (0 plat, 1 descend,
2 bosse, 3 monte), `alea`, `chaud`, `rampe`, `add`, `cap`, `eclat`, `etire` ; sous-dictionnaire `fin` (couche fine) qui
surcharge. **Nouveaux modes** : à ajouter À LA FIN de `poids()` / `start()` dans `magie_corps_part.gdshader` et dans
`ImpactCorps.MODES` (numéros 6, 7… ; ne pas renuméroter). **Nouveaux canaux** du voile / de la coque : `mc_autre.xyz`
est réservé (gel, choc, ténèbres) ; `mc_autre.w` = part du jet (déjà utilisé par la coque).

**Paramètres du foyer dans la texture des points** (depuis 5215947) : la texture `pts` fait `SurfaceCorps.TEXELS` texels =
192 texels de points (xyz tassés en RGBA) + 8 texels de paramètres, envoyés avec les points en UNE mise à jour par image
(plus aucun `set_shader_parameter` par image) : P+0 = dir_jet.xyz, k_jet ; P+1 = point_impact.xyz, rayon_jet ;
P+2 = k_foyers, sol_y, nb_pts ; P+3..P+6 = foyers ; P+7 réservé (libre pour B). Un mode de B lit ces texels avec
`lire1(P + i)` dans `magie_corps_part.gdshader`.

**Lecture des maillages** : `surface_get_arrays` est une lecture GPU synchrone (2 à 9 ms par maillage sur Iris Xe). Elle est
faite UNE fois par pièce (cache statique par signature nom|surfaces|sommets|taille), à l'avance (`_preparer` : corps à
≤ 30 m, une lecture toutes les 0,2 s, JAMAIS pendant un jet ou un projectile). Un corps pas encore lu passe en repli
(capsules par os) au lieu de lire au moment de l'impact.

**Préchauffe à blanc sur les vrais maillages** : la vitrine du chargement n'a que des boîtes ; le format de sommets d'un
corps skinné donne d'autres pipelines au voile et à la coque. Quand un corps préparé est à l'écran (≤ 30 m) et qu'aucun
sort n'est en cours, un foyer libre lui pose voile + coques à intensité nulle pendant 3 images, une fois par format de
maillage (`ImpactCorps._formats_chauds`, statique). Mesure (`--diag-embraser`) : le premier feu sur un corps compile
2 pipelines au lieu de 4. `--sans-chauffe-corps` la coupe (mesure).

**Lumières** : ImpactCorps passe après GestionMagie (process_priority 101) et tempère les lumières du pool à moins de
`RAYON_TEMPERE` d'un foyer (énergie ≤ `ENERGIE_MAX_CORPS`) : sinon le jet à bout portant aplatit le corps en blanc.

Pièges connus :
- un `PackedVector3Array` lu dans un `Dictionary` est une **copie** (append perdu) : relire, ajouter, réécrire ;
- `Skeleton3D.get_bone_global_pose()` hors du signal `skeleton_updated` ignore ragdoll et décapitation ;
- les foyers de B et de A sur un même corps partagent voile et coque (compteur par maillage) ;
- un maillage qui porte déjà un autre `material_overlay` (ancien voile de statut, enchantement) n'est pas voilé.

## Feu sur le corps (FeuCorps)

| Émetteur | Mode | Rôle |
|---|---|---|
| 0 | langues | flammes de surface côté impact, qui montent en collant au corps |
| 1 | contour | flux qui ressort par le bord de la silhouette et s'en écarte, dans le sens du jet |
| 2 | eclabousse | petit cœur blanc-jaune qui s'étale sur la surface au point touché |
| 3 | escarbilles | fines, s'échappent par les bords (additives) |
| 4 | fumee | légère, au-dessus des foyers de brûlure |
| 5 | sol | flammes au sol autour des pieds |

- Sous le jet : le corps prend feu en 0,15 s ; double incantation : plus chaud, plus large.
- Après l'arrêt (statut `brulure`, sa durée) : 3 foyers accrochés à des points de surface près du dernier impact
  (donc à des os : ils suivent la chute), petites flammes, braises, fumée ; puis braises qui s'éteignent (1,5 s),
  carbonisation tenue 3 s puis estompée en 4 s ; voile retiré, foyer rendu au pool.
- Lumière : celle du jet sous le jet ; pendant la brûlure, une lumière douce par corps (pool de GestionMagie).

## Outils

| Quoi | Commande |
|---|---|
| Test | `bash outils/tous_les_tests.sh test_impact_corps` |
| Captures | `bash /tmp/godot_slot.sh $G --path "$W" --script res://outils/captures_impact_feu.gd -- --plans=aucun --lieu=crypte --sortie=res://captures/impact_feu/apres [--cas=face,...] [--cote] [--sans-impact-corps] [--seul-corps]` |
| Planches | `bash outils/planches_impact_feu.sh [dossier_avant] [dossier_apres]` (référence \| avant \| après + zoom) |
| Perf (vraie crypte) | `bash /tmp/godot_slot.sh $G --path "$W" --disable-vsync --script res://outils/perf_impact_crypte.gd -- --nouvelle --detail-sorts=eleve --tours=4 [--premier=avant] [--diag-embraser] [--sans-chauffe-corps]` : 3 gardiens figés devant le joueur (direction dégagée), double jet qui balaie, phases module actif / coupé alternées ; une phase où le jet touche un gardien moins d'une image sur deux est écartée |

## Coût et limites

Mesures 2026-10-28 (`outils/perf_impact_crypte.gd`, Iris Xe, PC partagé avec d'autres rendus : charge 5 à 10, donc
bruit de plusieurs ms sur le temps d'image ; le GPU mesuré est plus stable) — voir la table du rapport de la branche.
Double jet sur 3 gardiens, phases alternées dans la même séance, 1er tour écarté :

| Détail | Charge du PC | Temps d'image après − avant | GPU après − avant | CPU du module |
|---|---|---|---|---|
| Élevé (6 tours) | ~0,2 (calme) | +1,01 ms | +0,38 ms | 0,48 ms |
| Élevé (4 tours) | ~9 | −0,38 ms | +0,36 ms | 0,94 ms |
| Moyen (4 tours) | ~1,4 | +1,11 ms | +0,27 ms | 0,66 ms |
| Rétro (4 tours) | ~2 | +1,10 ms | +0,32 ms | 0,55 ms |

Particules : plafond `MAX_PARTICULES_FIN` (4500) jamais dépassé (tests + mesures). 1er jet sur les corps, machine calme :
pire image 18,7 ms (module actif) contre 26,6 ms (module coupé).

Limites : la tête coupée (corps rigide de
Decapitation) ne brûle pas ; la coque et le voile sont limités à 12 maillages par corps ; le répulseur est un ellipsoïde
(pas une capsule par os) ; la lecture d'un maillage (une fois par pièce, hors sorts) coûte 2 à 9 ms d'image, et une
fois 411 ms observée sur PC très chargé (synchronisation GPU) ; la 1re accroche d'un corps coûte ~2 à 5 ms CPU ; la
prolongation du jet (×1,15) dépend de la marge de 18 % de `_jet_placer` (à revoir si le jet change) ; le voile ne se
pose pas sur un maillage qui porte déjà un autre `material_overlay`.
