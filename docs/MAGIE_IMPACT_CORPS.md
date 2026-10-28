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
ic.uniformes(f, "dir_jet", Vector3)      # uniformes communs aux 6 émetteurs : dir_jet, point_impact (relatif), rayon_jet,
                                          # k_jet, foyers (Array de 4 Vector4 : xyz relatif, w rayon), k_foyers, sol_y
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
| Planches | `bash outils/planches_impact_feu.sh` (référence \| avant \| après) |

## Coût et limites

Voir le rapport de la branche (mesures `outils/perf_magie_crypte.gd`). Limites : la tête coupée (corps rigide de
Decapitation) ne brûle pas ; la coque et le voile sont limités à 12 maillages par corps ; le répulseur est un ellipsoïde
(pas une capsule par os).
