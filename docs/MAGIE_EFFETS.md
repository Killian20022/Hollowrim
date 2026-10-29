# Magie : effets visuels (branche magie/effets)

Visuels seulement : aucune logique de jeu (pas de dégâts, de mana ni de collision). La logique (branche magie/sorts)
appelle `EffetsMagie`. Références : `references/magie/prompt_magie.md` et les images `*_1100.jpg`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `scripts/magie/effets_magie.gd` | `EffetsMagie`, classe statique : le contrat |
| `scripts/magie/gestion_magie.gd` | `GestionMagie` (Node3D) : pools, plafonds, lumières, éclairs, pics, disques, voiles |
| `scripts/magie/presets_magie.gd` | `PresetsMagie` : ~70 réglages de particules et palettes par école |
| `shaders/magie_part.gdshaderinc` (+ `magie_part_add` / `magie_part_mix`) | particules carrées, taille arrondie au pixel |
| `shaders/magie_trait.gdshader` | éclairs à largeur fixe en pixels écran (déplacement du point milieu) |
| `shaders/magie_cristal.gdshader` | pics de glace et cristaux à facettes plates (MultiMesh), avec dissolution |
| `shaders/magie_sol.gdshaderinc` (+ `magie_sol` / `magie_sol_mix`) | disques au sol : anneau, runes, spirale |
| `shaders/magie_voile.gdshader` | couche additive (`material_overlay`) pour les statuts et les enchantements |
| `shaders/magie_teinte.gdshader` | teinte d'écran discrète (halo additif de la couleur de l'école sur les bords) pendant les jets |
| `scripts/magie/galerie_magie.gd`, `scenes/galerie_magie.tscn` | galerie de validation |
| `outils/test_effets_magie.gd` | test sans fenêtre |
| `scripts/magie/couche_magie.gd` | `CoucheMagie` : couche fine des sorts (option « Détail des sorts ») |
| `scripts/magie/profondeur_magie.gd` | `ProfondeurMagie` (CompositorEffect) : copie la profondeur du monde pour l'occlusion de la couche fine |
| `shaders/magie_occ.gdshaderinc`, `magie_compose.gdshader` | occlusion par la profondeur du monde ; pose de la couche sur le monde |
| `shaders/magie_flux.gdshader`, `magie_aura.gdshader`, `magie_bruit.gdshaderinc` | jets, auras, boules et bouffées procéduraux au pixel (couche fine) |
| `shaders/magie_vague.gdshader`, `magie_vague_process.gdshader`, `assets/magie/feu_kenney_atlas.png`, `bruit_vague.png` | jet de flammes (couche fine) : VAGUE de bouffées qui avancent dans l'espace |
| `shaders/magie_decharge.gdshader`, `magie_decharge_process.gdshader`, `assets/magie/elec_kenney_atlas.png` | arc électrique, chaîne d'éclairs et impact électrique (couche fine) : DÉCHARGE d'éclats d'éclair texturés |
| `shaders/magie_coeur*.gdshader*` | cœurs lumineux de la couche fine |
| `outils/perf_magie_crypte.gd` | mesure dans la vraie crypte (double jet de flammes) |
| `outils/planches_magie_detail.sh` | planches avant / après face aux références |

## Contrat

Pour le détail de chaque fonction, voir les commentaires de `effets_magie.gd`.

**Écoles :**
- `feu`, `glace`, `electricite`, `tenebres`, `soin`, `protection`.
- Une école inconnue retombe sur `feu`.

**Fonctions :**
- `aura_main(main, ecole, intensite)`
  - Persistante : 0 l'éteint, 1 = charge pleine, 1,5 = pic.
  - Suit la main sans retard, car le gestionnaire a `process_priority` 100 et passe donc après `mains.gd`.
- `jet(ecole, origine, direction, portee, largeur, actif)`
  - À appeler à chaque image.
  - S'éteint seul 0,2 s après le dernier appel.
- `projectile_visuel(ecole, forme) -> Node3D`
  - Formes : `boule`, `eclat`, `lance`, `trait`, `orbe`.
  - La logique ajoute le nœud, le déplace et le libère.
  - La traînée et la lumière s'éteignent seules.
- `impact(ecole, position, normale, force)` et `zone(ecole, position, rayon, duree)`.
- `chaine(ecole, points)` : arcs entre les points ; avec `tenebres`, les arcs sont violets.
- `statut_cible(cible, statut, duree)`
  - Statuts : `brulure`, `gel`, `choc`, `corruption`.
  - Rappeler la fonction prolonge le statut ; `duree <= 0` le retire.
- `enchant_arme(arme, ecole, actif)`
  - Ajoute un `material_overlay` additif et des particules.
  - Le modèle et son matériau ne sont jamais modifiés.
- `reaction(nom, position, rayon)`
  - Réactions : `vapeur`, `decharge`, `decharge_incendiaire`, `cristaux_corrompus`, `flammes_obscures`, `arcs_violets`.
- `double(ecole, actif)`
  - Élargit les jets et renforce les arcs et la lumière.
  - Ajoute un effet entre les deux mains qui portent une aura.
- Fonctions hors contrat :
  - `prechauffer()` : à appeler au chargement d'un niveau.
  - Dans le jeu (fusion combat/magie) : `PrechauffeCombat.vitrine()` inclut `GestionMagie.vitrine_prechauffe()` (un émetteur par réglage, cristaux, éclair, disques, voile, cœurs, teinte), rendue hors écran par PrechauffeRendu dehors et dans la crypte : le premier sort ne compile plus ses pipelines. `EffetsMagie.appels` / `muet` : compteur d'appels et coupure du rendu (tests de la logique, test_magie).
  - `stats()`.
  - `tout_arreter()`.

**Pourquoi une classe statique :**
- Il n'y a rien à ajouter dans `project.godot`.
- Le premier appel crée le nœud `GestionMagie` dans la scène courante.
- Ce nœud est libéré avec la scène.

## Plafonds (dans `gestion_magie.gd`)

| Élément | Plafond |
|---|---|
| Particules | `MAX_PARTICULES` 3000 |
| Émetteurs | `MAX_EMETTEURS` 64 |
| Lumières dynamiques | `MAX_LUMIERES` 4 (triées par priorité × énergie) |
| Éclairs | `MAX_ECLAIRS` 20 |
| Pics | `MAX_PICS` 48 par palette |
| Disques | `MAX_DISQUES` 16 |
| Statuts | `MAX_STATUTS` 12 |
| Projectiles | `MAX_PROJECTILES` 24 |
| Pool d'émetteurs recyclés | `POOL_GARDE` 24 |

Au-delà d'un plafond, l'effet est refusé et compté dans `stats().refus`.

## Passe « spectaculaire » (2026-10-27)

- **Jets** :
  - Partent de la paume : un petit foyer `*_paume` est collé aux doigts.
  - Remplissent tout le trajet : la durée de vie des particules est recalée sur la distance de la cible, sans la traverser.
  - Cône 2 à 3 fois plus large.
  - 3 couches : cœur clair additif, corps saturé, bord sombre. S'y ajoutent braises, éclats ou fumée.
- **Gerbe** :
  - Une émission en boîte sur la silhouette de la cible l'enveloppe.
  - La cible est celle que touche le rayon (corps non statique).
  - Sinon, c'est l'ennemi le plus proche de l'axe, cherché dans les groupes `ennemis`, `cibles_combat` et `cibles_magie`.
  - Les draugrs de la galerie n'ont pas de collision : ils sont dans le groupe `cibles_magie`.
- **Turbulence** :
  - Turbulence GPU (`turb`) seulement sur les particules LENTES : auras, gerbes, traînées.
  - Sur les jets rapides, elle ramène la vitesse vers celle du bruit : les particules s'entassent près de la main et le milieu du jet se vide.
- **Lumière** :
  - Une lumière forte un peu devant la main, une à l'arrivée du jet.
  - Lumières d'aura et d'impact renforcées.
  - Teinte d'écran discrète (`magie_teinte`, au plus 11 % sur les bords).
- **Près de la caméra** : la paume est à environ 0,45 m de l'œil. Tout ce qui s'écarte de plus de 8 cm de la paume couvre une grande partie de l'écran. Les auras restent donc compactes, et les plafonds en pixels (`cap` 12 à 14 pour les corps) évitent les gros pavés au premier plan.
- **Par école** :
  - Ténèbres : vortex en spirale dans la paume, filaments épais (4 px de cœur) qui ondulent, fumée violette et éclats noirs, cible corrompue avec éclats violets et lueur.
  - Glace : lance de 4 m à couronne d'éclats, souffle avec cristaux et poudre, cristaux qui jaillissent à l'impact.
  - Électricité : arcs de 3 px très ramifiés, éclat de paume, chaîne qui se propage saut par saut (0,06 s par saut).
  - Feu : grosse boule à 3 sphères, traînée, braises, explosion qui projette des braises.

## Détail des sorts : couche fine (2026-10-27)

Retour de l'utilisateur sur la passe précédente : « trop de gros pixels ». Les sorts sont maintenant dessinés à une
résolution plus fine que le monde, qui reste en 640x360.

- **Option** (`Options > Affichage > Détail des sorts`, clé `affichage.detail_sorts`) :
  - Élevé (2, par défaut) : un pixel de magie = un pixel de l'écran (1/2 pixel du monde en 1280x720, 1/3 en 1080p, au plus 1/4).
  - Moyen (1) : un pixel de magie = 1/2 pixel du monde.
  - Rétro (0) : rendu d'avant, tout en 640x360, couche éteinte.
  - Argument de mise au point : `--detail-sorts=retro|moyen|eleve`. Les outils (`--script`) sont en rétro par défaut ; la galerie impose Élevé.
- **Architecture :**
  - La fenêtre passe en `CONTENT_SCALE_MODE_CANVAS_ITEMS` (seulement si elle était en VIEWPORT : titre et chargement intacts) et sa 3D est rendue à 1/k en `SCALING_3D_MODE_NEAREST`. Le décor est identique au rendu rétro (écart moyen 0,011/255).
  - Les visuels de `GestionMagie` portent le calque de rendu 19 (`CoucheMagie.CALQUE`, posé par `node_added`). La caméra du monde l'exclut ; un SubViewport (`transparent_bg`, HDR) qui partage `world_3d` le dessine, sa caméra étant recalée sur celle du joueur à `frame_pre_draw`.
  - Pose sur le monde : TextureRect dans un CanvasLayer 0, sous `ps1_post` (CanvasLayer 1) ; la magie est donc étalonnée et réduite en 15 bits comme le reste. Les additifs sont écrits en `blend_premul_alpha` avec ALPHA = 0 (équivaut à `blend_add` sur le monde).
  - Occlusion : `ProfondeurMagie` (CompositorEffect, `POST_TRANSPARENT` car `POST_OPAQUE` n'est jamais appelé en Mobile) copie la profondeur 640x360 dans une texture R32F ; `magie_occ.gdshaderinc` reprojette avec la vue de l'image précédente.
  - Globales de shader (`project.godot`) : `magie_prof`, `magie_vue_prec`, `magie_occ`, `magie_pas`, `magie_echelle` (pixels de magie par pixel du monde).
  - Veille : le SubViewport s'arrête 0,5 s après le dernier visuel. Préchauffe : `amorcer()` dessine 4 images invisibles pendant la vitrine du chargement.
- **Effets multi-couches (couche fine seulement) :**
  - Jets : ruban procédural `magie_flux` (bruit fractal en pixels du monde, paliers de couleurs francs, bords rongés), particules par-dessus.
  - Auras de main, boules, bouffées d'impact, gerbe sur la cible : `magie_aura` (flammes montantes, givre tournant, filaments de plasma, vortex).
  - Particules : réglages `PresetsMagie.FIN` (nombre, taille, étirement) et émetteurs compagnons `R_FIN` (étincelles, flammèches, poudre, cristaux) ; traînées étirées dans le sens du mouvement ; taille plafonnée à 0,2 × le plafond rétro × échelle.
  - Éclairs : un niveau de subdivision de plus et des brindilles ; cœur 0,75 / halo 1,25 de la largeur rétro × échelle.
  - Plafonds propres : `MAX_PARTICULES_FIN` 4 500, `MAX_EMETTEURS_FIN` 110 (6 000 essayé : +3,5 ms par image en double jet, au-delà du budget de +2 ms).
- **Mise au point (galerie) :** `--sans-particules`, `--sans-procedural`, `--sans-post`, `--sans-flux`, `--sans-aura`, plan `vide`.
- **Planches :** `bash outils/planches_magie_detail.sh [crypte|dehors]` → `captures/magie_detail/planches/planche_<ecole>.png`. Par ligne : référence | zoom ×2 de l'après, puis avant | après pour la main, le jet, l'impact.
- **Coût :** voir le tableau « Détail des sorts » de la section Coût.

## Choix de style

- **Particules carrées :**
  - Taille arrondie au pixel du viewport 640x360, au minimum 1 px.
  - Le shader utilise `abs(PROJECTION_MATRIX[1][1])`, car l'axe Y est inversé sous Vulkan.
  - La couleur est convertie de sRGB en linéaire, ce qui évite le rose sur les rouges sombres.
- **Rendu par défaut :**
  - Les dégradés sont en paliers (`GRADIENT_INTERPOLATE_CONSTANT`).
  - Le mélange est opaque par défaut.
  - L'additif est réservé aux étincelles, reflets, braises et motes, car les rouges additifs virent au saumon.
- **Voile :**
  - Il est calé sur la même grille que le shader `ps1`.
  - Motif en cases dans l'espace objet et colonnes de flammes fines.
- **Contraintes :**
  - Pas de tramage Bayer.
  - Compatible avec les renderers Mobile et Compatibility : pas de calcul ni de texture lourde.

## Galerie

Commande de lancement :

```
godot --path . res://scenes/galerie_magie.tscn -- --lieu=crypte|dehors --vue=fps|cote [--plans=a,b] [--captures=dossier] [--perf] [--boucle] [--balayage]
```

- **Contenu :**
  - 33 plans.
  - La vraie main gauche de `joueur.gd` est utilisée en vue FPS.
  - La torche est masquée et les doigts sont ouverts.
  - La pose de la main est forcée par la galerie, sans modifier `mains.gd`.
- **Sorties (non versionnées, `captures/` est ignoré) :**
  - `captures/magie/galerie/` : 132 images.
  - `captures/magie/planches/` : comparaisons avec les 5 références, plus la mesure de coût.
  - `captures/magie/video/galerie_magie.mp4` : vidéo de 40 s.

## Coût mesuré (GPU réel Iris Xe, vue FPS, `--perf=pire`)

| Lieu | Sans effet | 3 effets + 5 statuts | Pire cas : double feu (2 jets, 2 auras) + explosion incendiaire + 5 statuts |
|---|---|---|---|
| Crypte | 2,26 ms (60 appels de dessin) | 3,03 ms (+0,77) | 3,29 ms (+1,03 ; 2 970 particules, au plafond) |
| Dehors | 4,13 ms | 5,59 ms (+1,46) | 4,91 ms (+0,78) |

- La référence sans effet varie d'une séance à l'autre selon la charge du PC (5,2 ms lors de la première mesure). Les écarts comptent plus que les valeurs absolues.
- Mesure sans fenêtre : 0,63 ms par image, en CPU seul.

### Détail des sorts (mesure du 2026-10-27, `outils/perf_magie_crypte.gd`, vraie crypte, double jet de flammes, fenêtre hors écran, PC chargé par d'autres Godot)

| Détail | Temps d'image, double jet (moyenne de 3) | GPU, double jet | Particules |
|---|---|---|---|
| Rétro | 8,87 ms | 1,91 ms | ~3 000 (plafond rétro) |
| Élevé, plafond 4 500 (retenu) | 8,96 ms (+0,1) | 3,55 ms (+1,6 : fenêtre 2,86 + couche 0,69) | 4 500 |
| Élevé, plafond 6 000 (écarté) | 13,74 ms (+3,6, moyenne de 4) | 4,10 ms (+1,8) | ~5 600 |

### Jet de flammes en spray (2026-10-28, `galerie --perf=jet`, crypte, vue FPS, 3 × 240 images, PC chargé)

Retour utilisateur : jet « transparent », « un rayon » → vagues de flamme couvrantes qui sortent de la paume.
`magie_flux` : `bouffees` > 0 (feu : 0,6) = le corps est une suite d'ovales transportés (taille, retard, dérive
latérale, température propres), fondus dans un cœur plein près de la paume ; feu couvrant (alpha 0,55-0,95), lumière
seulement sur les parties chaudes ; cône feu evase 0,8, r0 0,045, r1 ×2,4 (≤ 1,3 m ; double : ×1,08). Glace essayée
avec les bouffées : jet plus court et en deux paquets → laissée telle quelle. Particules inchangées (2 020).

| | GPU sans effet | GPU avec le jet (3 mesures) | Coût du jet |
|---|---|---|---|
| Avant (4cb99b6) | 2,38 ms | 2,98 / 2,96 / 3,32 ms | +0,71 ms (moyenne) |
| Après (spray) | 2,28 ms | 3,06 / 3,11 / 3,21 ms | +0,85 ms (moyenne) → +0,14 ms |

## Test

Commande :

```
godot --headless --path . --script res://outils/test_effets_magie.gd -- --nouvelle
```

- **Ce que le test vérifie :**
  - les signatures du contrat ;
  - toutes les fonctions, pour toutes les écoles, formes, statuts et réactions ;
  - les plafonds, y compris sous un déluge d'effets ;
  - l'extinction complète : aucun émetteur, particule, lumière ou effet persistant ne reste ;
  - le retrait des voiles.
- **Bruit connu :** le message `PagedAllocator` à la sortie vient du moteur et est sans conséquence.

## HUD de combat

Voir `scripts/hud_combat.gd`. Le contrat de données est décrit en tête de fichier : `mana`, `charge_*`, `statuts_actifs`, `raccourcis`, `recharges`, signal `etat_mains_change`. Le HUD a son propre test, `outils/test_hud_combat.gd`.

## Limites

- **Lumières :** au plus 4 lumières dynamiques au total. Au-delà, les effets sont visibles mais n'éclairent pas.
- **Couche additive :** elle suppose des `MeshInstance3D`, donc pas de skinning particulier. Un maillage qui porte déjà un `material_overlay` est laissé tel quel, sans voile.
- **Projectiles :** pas de collision, c'est la logique qui décide de l'impact.
- **Pose de la main :** la pose de main ouverte de la galerie est propre à la galerie. Le geste de lancer en jeu reste à faire dans `mains.gd`, hors périmètre.
- **Couche fine :**
  - Surcoût GPU d'environ 1 ms même sans sort, dû à la fenêtre en CANVAS_ITEMS (post-traitement à la résolution de l'écran). Le temps d'image n'en souffre pas sur la machine de test, limitée par le CPU.
  - Occlusion reprojetée avec une image de retard : un objet mobile qui passe devant un sort peut laisser déborder un pixel pendant une image.
  - Renderer Compatibility (pas de RenderingDevice) et mode sans fenêtre : retour automatique au rendu rétro.
  - Les voiles (`material_overlay`) restent dans le rendu du monde, en 640x360.
  - Il reste quelques carrés de taille moyenne dans le corps des particules (traînée de la boule de feu surtout).

## Jet de flammes : vague de bouffées (branche magie/flammes_vivantes, 2026-10-29)

Retour utilisateur : « jet un peu court et trop cheap … on dirait un screenshot ». En couche fine, le corps du jet de FEU n'est
plus le ruban `magie_flux` (motif qui glissait sur une forme fixe) mais un `GPUParticles3D` par jet (`_vague_creer`) :
- `magie_vague_process.gdshader` (particules, repère du MONDE) : sortie dans un cône étroit à ~17 m/s, freinage
  (`VAGUE_TRAINE` 1,25/s) réglé pour porter à `VAGUE_PORTEE` = 10,5 m, flottabilité croissante, turbulence dépendant de
  la position, rotation propre, étirement dans le sens de la vitesse (langues à la sortie, bouffées rondes au bout) ; plan
  d'arrêt au point touché : la vague s'écrase, s'étale, monte et vieillit 3 fois plus vite. Quand on tourne, les bouffées
  parties gardent leur route (jet « tuyau d'arrosage ») ; à l'arrêt du sort, elles finissent leur vie (extinction au bout).
- `magie_vague.gdshader` (dessin) : formes du Kenney Particle Pack (CC0, atlas 4×3 de 128² : flame_01-04 enchaînées en
  flipbook, flame_05-06 pour les langues jeunes, smoke_03-07 en fin de vie), déformées par un bruit précalculé
  (`bruit_vague.png`, `outils/generer_bruit_vague.gd`) ; couleur par l'âge et la densité (blanc-jaune → orange → rouge
  sombre → fumée), paliers de la palette, motif évalué par pixel du MONDE, couverture tramée par un bruit qui bout à
  12 images/s (pas de Bayer). Bouffées effacées à moins de ~0,5 m de l'œil (pas de voile sur la main).
- `jet_flammes.tres` : portée 5,5 → 9 m. Galerie : plan `jet_feu_loin` (jet dans le vide, portée entière).
- Coût mesuré (`--perf=jet`, crypte FPS, 1280×720 Élevé, PC partagé, A/B avec `--sans-flux`) : couche fine +0,5 ms GPU
  (1,0 contre 0,5 ms), fenêtre +0,1 à +0,4 ms (bruit de mesure) ; CPU : rien (simulation sur le GPU).
  Version d'essai sans atlas ni bruit précalculé, 110 bouffées : +1,6 ms ; c'est l'overdraw des bouffées proches de l'œil
  qui coûtait (plafond 0,2 × hauteur d'écran, bouffées à moins de 0,32 m non rasterisées).


### Passe 2 : un seul flot (2026-10-29)

Retour utilisateur : « on voit que c'est plusieurs petites flammes collées … compacter pour faire un vrai jet ».
- Sous-pas d'émission : `_vague_placer` passe au shader de particules la pose de l'émetteur à l'image précédente
  (`prec_o`, `prec_base`) et la durée de l'image (`pas`) ; chaque bouffée naît à un instant tiré dans l'image écoulée
  (position et direction interpolées, puis avancée de ce reste de temps). Plus de chapelet quand on tourne vite.
- Plus dense et plus soudé : `VAGUE_N` 66 → 88, bouffées plus étirées dans le sens de la vitesse (jusqu'à ×5,2 au lieu
  de ×3,6), grossissement plus précoce (exposant 0,6), taille finale 0,75 (0,8 en double) pour tenir le budget.
- Liseré jaune-vert autour de la paume : la teinte des bouffées peu denses est plafonnée (jaune-orange saturé, le blanc
  est réservé aux cœurs denses), plafond relâché avec la distance à l'œil.
- Coût (même protocole, 2 mesures chacune) : ~3,5-3,6 ms GPU avec la vague contre ~2,9-3,0 sans, soit +0,5 à +0,6 ms.

## Électricité : décharge vivante (branche magie/elec_vivante, 2026-10-29)

Même architecture que la vague de flammes. En couche fine, le corps de l'arc électrique n'est plus le ruban `magie_flux`
(tube violet uniforme) mais un `GPUParticles3D` par jet (`_decharge_creer`, `DECHARGE_N` 64 éclats, ×1,35 en double) :
- `magie_decharge_process.gdshader` : chaque éclat vit `DECHARGE_VIE` 0,13 s (3-5 images) et se RECALCULE à chaque image
  sur la courbe de Bézier actuelle (paume, contrôle, bout : uniformes posés par `_decharge_placer`, mêmes points que
  `_jet_courbe`), il colle donc à l'arc quand on tourne. Genres : traits d'éclair le long de l'arc (de travers, écartés au
  milieu ; dans le vide le bout s'effiloche), crépitement au bout touché et un peu dans la paume, étincelles renvoyées qui
  tombent, fourches qui sautent du bout sur le corps. Mode `eclatement` (impact sur une surface) : traits en étoile autour
  de la normale.
- `magie_decharge.gdshader` : quad à l'écran tendu entre les deux bouts projetés de l'éclat, forme du Kenney Particle Pack
  (CC0, atlas 4×2 de 128² : spark_05/06/07, trace_03 / spark_01/02/04, star_04). À chaque image (30 /s) chaque éclat change
  de forme (case suivante, miroir, glissement) et d'éclat (plein, moitié, éteint ~1 image sur 5). Intensité en paliers
  blanc → blanc-bleu → bleu → violet, grain au pixel du monde, tramage par bruit qui change à chaque image (pas de Bayer),
  additif. Éclats contre l'œil non dessinés, tailles plafonnées (paume à 0,45 m).
- Arc maître CPU (`_gen_jet_arc_vif`, remplace `_gen_jet_arc` en couche fine) : brin fin qui relie toujours la paume au
  point frappé (lisibilité), 2 brins (3 en double) refaits 30 fois/s, éclat variable, « hoquet » (un seul brin pâle) ~1 image
  sur 8, fourches vers l'avant, doigts sur la cible.
- `chaine()` : chaque saut crépite aussi (`_decharge_ponctuelle`, au moment où l'arc l'atteint) ; `impact("electricite")` :
  éclatement de 0,26 s. Rendu rétro (couche fine éteinte) : inchangé.
- Galerie : plan `impact_electricite` ; `--perf=jet --ecole=electricite`.
- Coût (`--perf=jet --ecole=electricite`, crypte FPS 1280×720 Élevé, A/B contre eb973fb, PC partagé, 3 séances) : couche
  fine 0,35-0,47 → 0,68-0,76 ms ; coût total du jet +0,2 à +0,5 ms GPU. Pas de simulation CPU (4 uniformes par image).
- Limites : de jour sur la neige (additif sur fond clair), l'arc tire vers le blanc et perd son bleu-violet ; les grandes
  branches CPU de `chaine()` près de la paume (déjà là avant) ne sont pas touchées.

## Correctif : triangle bleu au départ des éclats de glace (2026-10-29)

Symptôme : au lancer d'un éclat de glace (ou d'une lance de givre), un grand aplat bleu en triangle couvrait un coin de
l'écran pendant une image. Cause : le maillage du cristal (`_creer_eclat`, bipyramide) a sa queue à 0,25 × sa longueur
DERRIÈRE son origine ; né dans la paume (~0,5 m de l'œil), l'éclat (queue 0,43 m) ou la lance (1 m) traversait le plan
proche de la caméra (mesuré : sommet à 0,086 m de l'œil). Correctif : le projectile cristal naît à l'échelle 0,12 et
grandit à mesure qu'il avance (`_cristal_echelle` : la queue ne repasse jamais derrière le point de départ, pleine taille
après ~0,4 m / ~1 m) ; garde-fou dans `magie_cristal.gdshader` (aucun fragment à moins de 0,12 m de l'œil). Vérifié par
`outils/captures_glace.gd --rafale=<dossier> [--sort=lance_givre]` (journal `PROCHE` / `BILAN` : distance minimale
0,086 m → 0,46 m pour l'éclat, 0,235 m pour la lance ; plus aucune image à moins de 0,2 m).

## Jet de glace : souffle de givre (branche magie/glace_vivante, 2026-10-29)

Même architecture que la vague de flammes : en couche fine, le corps du jet de GLACE n'est plus le ruban `magie_flux` mais un
`GPUParticles3D` par jet (`_givre_creer`, rangé dans `j.vague` : sous-pas d'émission, plan d'arrêt et extinction au bout
communs avec le feu via `_vague_placer`). Fichiers propres à la glace : `shaders/magie_givre_process.gdshader`,
`shaders/magie_givre.gdshader`, `assets/magie/givre_kenney_atlas.png` (`outils/generer_atlas_givre.gd`, Kenney CC0).
- Deux familles dans un émetteur (`GIVRE_N` 120, `GIVRE_CRISTAUX` 25 %) : bouffées de souffle (cône 0,1 rad, ~16 m/s freinées
  pour porter à `GIVRE_PORTEE` 8,5 m, l'air froid retombe un peu, roulis propre, tourbillon twirl) ; cristaux (étoiles Kenney)
  moins freinés, qui tournoient et scintillent, puis S'ACCROCHENT au point touché (`_givre_placer` : à la surface d'une
  cible, contre un mur) et y scintillent jusqu'à leur fin.
- Couleur : cœur blanc → cyan → bleu profond au bord, brume froide pâle en fin de vie ; points de givre qui scintillent ;
  paliers de palette (`GIVRE_PAL`), motif au pixel du monde, couverture tramée par un bruit (pas de Bayer).
- Compagnons (`GIVRE_COMPAGNONS`) : poudre fine, éclats de cristal 3D, foyer de la paume (avant : 5 couches + flux).
- Impact sur une surface (couche fine) : `_givre_impact`, salve de 30 particules de la même simulation (brume qui éclate
  et retombe, cristaux qui fusent). Sur un corps : inchangé (ImpactCorps / GlaceCorps).
- Galerie : plans `souffle_givre_loin` et `eclat_glace_sol` ; `--perf=jet --ecole=glace`.
- Coût (`galerie --perf=jet --ecole=glace`, crypte FPS 1280×720 Élevé, PC partagé par 5 agents, 2 lancements × 3 mesures) :
  avant (flux) GPU 2,78 à 4,06 ms pour 2,33 à 2,83 sans effet (+0,45 à +1,2 ms) ; après 3,11 à 3,53 ms pour 2,31 à 2,45
  (+0,8 à +1,1 ms) : écart dans le bruit de mesure (≈ 0 ± 0,3 ms), particules 1 675 → 977, émetteurs 13 → 9.
