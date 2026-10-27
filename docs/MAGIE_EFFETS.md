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
| `scripts/magie/galerie_magie.gd`, `scenes/galerie_magie.tscn` | galerie de validation |
| `outils/test_effets_magie.gd` | test sans fenêtre |

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

## Coût mesuré (GPU réel, vue FPS, 3 effets + 5 cibles avec statut)

| Lieu | Sans effet | Avec effets | Contenu actif |
|---|---|---|---|
| Crypte | 5,20 ms (60 draw calls) | 6,04 ms (77 draw calls) | 356 particules, 13 émetteurs, 4 lumières, 2 éclairs |
| Dehors | 5,42 ms | 7,39 ms | même contenu |

Mesure sans fenêtre : 2,15 ms par image, en CPU seul.

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
