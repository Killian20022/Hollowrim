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

---

# Électricité, glace, ténèbres et projectiles sur le corps (agent B, branche magie/impact_ecoles)

Même socle, mêmes exigences que le feu : rien n'est posé devant l'ennemi, tout part de sa SURFACE et suit ses os ;
persistances après l'arrêt. Références : `references/magie/electricite_fps_1100.jpg`, `glace_fps_1100.jpg`,
`tenebres_fps_1100.jpg` ; Ignite the Depths (gerbes de gros pixels carrés par école) : évalué, retenu seulement en petit
(éclats tangents de 1 à 3 pixels de la couche fine aux impacts) — les gros carrés vont contre le retour « trop de gros pixels ».

## Par école

| École | Fichier | Sous le sort | Après |
|---|---|---|---|
| Électricité (arc électrique, chaîne d'éclairs, tempête, lames) | `scripts/magie/elec_corps.gd` | le faisceau finit SUR la surface et s'y divise (2-3 fourches qui saisissent d'autres points du corps) ; arcs qui RAMPENT de point en point, SAUTENT d'un os à l'autre (bras ↔ torse, bouclier) et descendent au sol ; petit cœur bleu-blanc au point touché, contour qui crépite et veines (voile) ; étincelles tangentes, crépitements aux points d'accroche, étincelles au sol | statut **choc** : petites décharges qui papillotent sur tout le corps ; puis **traces de choc** (figures sombres autour du point touché, fumée légère, arcs de plus en plus rares) en 3,5 s |
| Glace (éclat, lance, nova, lame) | `scripts/magie/glace_corps.gd` | le givre se DÉPOSE depuis le point touché et gagne la surface (front à 1,6 m/s, bord irrégulier) : texture qui blanchit (voile), croûte de cristaux à facettes (coque, sommets poussés le long de la normale, plus grands près de l'impact), scintillements, buée qui tombe, brume au sol quand le corps est couvert ; projectile : éclats et poudre TANGENTS | couverture selon la puissance du gel (`Statuts.puissance`, lu seulement) et les coups répétés (éclat ~0,5 m, lance ~0,75 m, +0,35 m par nouveau coup, nova = tout le corps, depuis les pieds) ; le givre **fond** en 2,5 s (croûte qui se troue et rentre, gouttes) |
| Ténèbres (drain de vie, trait d'ombre, lame) | `scripts/magie/ombre_corps.gd` | drain : 5 filaments (4 en rétro) ARRACHÉS à des points de la surface côté lanceur, en spirale jusqu'à la paume (renouvelés un à un) ; fragments sombres et lueurs violettes ASPIRÉS vers la main ; volutes de la coque entraînées vers la main ; lueur violette rongée au point d'où la vie est arrachée, contour violet, veines ; la victime PÂLIT ; trait d'ombre : éclaboussure sombre tangente | statut **corruption** : volutes qui montent, motes violettes, contour qui palpite ; puis les ténèbres **se dissipent** en 1,5 s (pâleur qui revient en 2 s) |
| Boule de feu (projectile) | `ImpactCorps.impact` → `FeuCorps` (API de A) | « souffle qui entoure la silhouette » = **impulsion** : un jet virtuel de 0,16-0,28 s le long de la trajectoire (même rendu que le jet : flux qui contourne le corps, langues, cœur), puis `FeuCorps.embraser` ; l'explosion (zone) ne pose plus sa boule devant le corps (anneau et flammes au sol gardés) | brûlure de A |

## Extensions du socle (additives, à fusionner avec la suite de A)

- **Correctif d'index d'instance** (`shaders/magie_corps.gdshader`) : les `instance uniform` sans `instance_index` sont
  numérotés à partir de 0 par shader ; le voile étant un `material_overlay`, `mc_feu` (0) occupait le même emplacement que
  `eclair` (0) de `ps1_draugr` / `c_peau` (0) de `perso` (`servers/rendering/instance_uniforms.cpp` : même index = même case).
  Les canaux du voile sont maintenant fixés en 10..15.
- **Canaux des écoles B** (`shaders/magie_corps_ecoles.gdshaderinc`, inclus par le voile) : `mc_ecoles` (14 : givre, choc,
  ténèbres, traces×256 + pâleur), `mc_pt` (15 : point, rayon du givre). Ils sont FUSIONNÉS par corps à la fin de l'image
  (`ecoles(f, …)` puis `_ecrire_ecoles`) : un corps gelé et électrifié garde les deux ; réécrits seulement s'ils changent.
- **Arcs sur le corps** (`shaders/magie_corps_arcs.gdshader`) : maillage FIXE de `MAX_SEGMENTS` (160) sous-segments partagé
  par tous les foyers ; le comportement écrit leur forme (index de points, genre, zigzag) dans une texture de 320 texels
  ~15 fois par seconde (`arcs_debut` / `arc` / `arcs_fin`), le shader lit les POINTS DU CORPS de l'image (`pts`/`nrm`, les
  textures des émetteurs) : les arcs suivent les os à chaque image sans calcul par sommet côté CPU. Genres : rampe, sol,
  brindille, main (filament du drain vers `point_main`), saut. Couleurs par école : constante `ARCS` du comportement.
- **Coque par école** : constante `COQUE` du comportement (−1 = pas de coque) → matériau partagé de
  `shaders/magie_corps_coque_ecoles.gdshader` (uniforme `ecole` : 0 givre, 1 volutes, 2 contour électrique) créé avec le pool ;
  `mc_vers` (instance de la coque) : direction du tir (glace) ou de la main (ténèbres). L'électricité n'a pas de coque (perf).
- **Modes de particules** 6 `aspire` (vers `point_main`, en spirale, meurent dans la paume), 7 `givre` (zone gelée :
  `point_impact` + `rayon_jet`), 8 `fonte` (gouttes) : `shaders/magie_corps_part_ecoles.gdshaderinc`.
- **Points d'accroche** (une ligne chacun dans `gestion_magie.gd`) : `impact` → `ImpactCorps.impact(gm, …)` (impact DANS
  une colonne de corps, comme ProjectileSort : rendu sur la surface ; décor : inchangé) ; `zone` (feu) →
  `ImpactCorps.zone_sur_corps` ; `chaine` → `ImpactCorps.points_sur_corps` (les arcs se posent sur la surface d'un corps
  qui a déjà un foyer, moins de ramifications sur ce lien).
- **API** : `impulsion(f, info, duree)` (jet virtuel bref), `point_vise(f, o, d)` (SurfaceCorps.point_vise mis en cache
  0,08 s), `surface_changee(f)` + `plus_proche(s, p)` (la surface passe du repli en capsules aux vrais maillages : les index
  gardés par un comportement sont à retrouver — vaut aussi pour `FeuCorps.imp_i`), `corps_en(gm, p)`, `arcs_regler(f, main)`,
  `jet()` reçoit le dictionnaire du jet (`info.j` : faisceau / drain remplacés tant que le corps est visé).
- **Pool** : 8 foyers (4) ; un foyer libre déjà réglé pour l'école est repris en priorité ; matériaux de dessin et rampes de
  TOUTES les écoles créés avec le pool. **Statuts** : `STATUTS` (brulure → feu, gel → glace, choc → électricité, corruption
  → ténèbres).
- **Perf du socle** : `uniformes()` ne pose une valeur que si elle change et seulement sur les émetteurs qui émettent (les
  autres la reçoivent à l'allumage) ; positions des émetteurs / transformées des coques réécrites seulement si elles changent ;
  `SurfaceCorps` partage ses groupes entre maillages (squelette + os + transformée : 60 → 30 groupes pour un draugr,
  `actualiser` 172 → 78 µs mesuré sans fenêtre). Chronomètre : `ImpactCorps.duree_maj_us` / `images_maj`.
- **Préchauffe** : la vitrine porte aussi un VRAI corps de draugr (maillages skinnés) avec le voile et la coque de chaque
  école, et les arcs dans la couche fine.

## Outils

| Quoi | Commande |
|---|---|
| Test (étendu aux écoles B) | `bash outils/tous_les_tests.sh test_impact_corps` |
| Captures (24 cas, 69 images) | `bash /tmp/godot_slot.sh $G --path "$W" --script res://outils/captures_impact_ecoles.gd -- --plans=aucun --lieu=crypte --sortie=res://captures/impact_ecoles/apres [--cas=…] [--cote] [--sans-impact-corps] [--film=<cas>]` |
| Planches | `bash outils/planches_impact_ecoles.sh` (référence de l'école \| avant \| après, zoom ×2) |
| Perf, vraie crypte, 3 gardiens | `$G --path "$W" --disable-vsync --script res://outils/perf_impact_ecoles.gd -- --nouvelle --detail-sorts=eleve [--ecoles=…] [--tours=3]` (avant / après alternés) |
| Coût CPU sans fenêtre | `--headless --script res://outils/bench_impact_ecoles.gd -- --nouvelle` |

## Limites

- « Gel complet = pose figée » : le corps est recouvert, mais la pose n'est pas figée (la vitesse est réglée par la logique
  du gel, ×(1 − puissance) ; figer l'animation serait de la logique de jeu).
- Réactions entre écoles (vapeur, décharge…) : pas encore rendues sur le corps (rendu d'avant).
- Les arcs changent de forme ~15 fois par seconde (entre deux, ils restent accrochés aux mêmes points) ; une arête de la
  croûte de givre suit les sommets du maillage (facettes PS1, pas de vrais cristaux séparés).
- Mesures de perf sur un PC partagé par d'autres agents : les temps d'image varient de ±3 ms d'une passe à l'autre ;
  les écarts GPU et le CPU du module sont plus stables (rapport de la branche).
