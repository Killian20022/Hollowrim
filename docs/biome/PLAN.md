# Amélioration du biome — plan validé (2026-10-19)

Référence : tag `biome-avant` (= ba70c94). Branche d'intégration : `biome/zone-temoin`.
Rien n'arrive sur master avant validation des captures par l'utilisateur.

## Contraintes utilisateur (non négociables)
- Améliorer l'existant, ne pas recréer la carte ; conserver l'identité (nuit + aurore + neige = DA validée).
- Ne pas déplacer quêtes, bâtiments importants, points d'apparition, zones jouables sans raison expliquée.
- Ne supprimer aucun fichier/asset sans vérifier qu'il est inutilisé. Aucune dépendance externe.
- Non destructif : tout se compare avec `--biome=ancien|nouveau`.

## Zone témoin
`ZoneBiome` : x ∈ [-58, +4], z ∈ [-64, +4], bande de fondu 8 m (feu → rôdeur (-16,-15) → cercle (-38,-34) → tumulus (-38,-48)).
`ZoneBiome.masque(x, z)` = 0 hors zone ou si `--biome=ancien`, 1 au cœur, smoothstep dans la bande.

## Pièges de déterminisme (à respecter absolument)
1. `monde.rng` (graine 1234) est consommé dans l'ordre : 4 textures (monde.gd ~l.89-93), `_foret` (positions puis transformations),
   `_couvre_sol`, `_rochers`, `_cercle_runique` (hauteurs et inclinaisons des 7 pierres). Ne jamais ajouter/retirer un tirage sur ce RNG.
2. Dans `_rochers`, les `continue` d'exclusion sont AVANT les tirages d'échelle/rotation : toute nouvelle exclusion se fait APRÈS les tirages (filtrage a posteriori).
3. `Palette.texture(..., rng = null)` utilise un RNG statique partagé (textures du village) : toute nouvelle texture reçoit son propre RNG.
4. `bruit_detail` entre dans le relief global : ne pas changer ses réglages en phase 2 (nouveau bruit `bruit_roche` dans la zone seulement).
5. Nouveaux systèmes = RNG propres : `ZoneBiome.graine("foret_zone"|"sous_bois"|"rochers_zone"|"sol"|"chemin"|"composition")`.
6. Hors zone : `hauteur()` renvoie exactement l'ancienne valeur (branche explicite, pas de lerp) ; les arbres anciens sont générés à l'identique puis filtrés après coup dans la zone par `alea_pos(x,z) >= masque` (hachage de position, aucun RNG).

## Lots
| Lot | Contenu | Fichiers (exclusifs) |
|---|---|---|
| 0 | Extraction SANS changement de comportement : `vegetation.gd` (forêt + couvre-sol, placement séparé de l'instanciation), `instanciation.gd` (point unique de création des MultiMesh), `rochers.gd`, `cercle_runique.gd`, stubs `chemins.gd` / `sol.gd`, `zone_biome.gd`, drapeau `--biome`, suppression du code mort `_cone`/`_tri`/`_sapin` (vérifier qu'il est inutilisé), `--sans-particules`, `--paisible` (draugrs/dragon figés, pas de dégâts), cycle figé en capture même avec `--heure`, outils `test_biome.gd` (signature d'invariance) et `comparer_images.gd`. | monde.gd + nouveaux fichiers |
| A | Perf sans changement visuel (toute la carte) : MultiMesh découpés en cellules de 20 m, `visibility_range_end` 80-100 m (marge 10, pas de fondu), ombres seulement sur les cellules proches, genévriers/rochers en cellules avec portée. Mesuré sur copie : GPU 15,5 → 6,7 ms. | instanciation.gd, arbres.gd |
| B | Corrections : collision du tumulus en ConcavePolygonShape3D (faces de la sphère ×(1,0.42,1)), collision des rochers sans échelle non uniforme (points transformés), exclusions des rochers (cercle 11 m, ellipse du tumulus, chemin 2,5 m) dans la zone, filtrées après les tirages ; collision des arbres de la zone ∝ échelle. | tertre.gd, rochers.gd |
| C | Relief local + chemins : polylignes Catmull-Rom feu→cercle (-6,-6.5)(-10.5,-9)(-13.5,-13)(-18.5,-16.5)(-22,-21.5)(-26.5,-23)(-29.5,-26)(-33.2,-29.4) et cercle→tumulus (-34.8,-39.8)(-35.8,-43)(-38,-45.2), décalage bruité ±1,2 m ; profil lissé (pente ≤ 12°) appliqué dans `hauteur()` sur 4 m + ornière 10 cm ; bords de plateaux bruités (intérieur intact) ; aplanissement du tumulus ; cône de vue vers le cercle depuis (-18.5,-16.5). | chemins.gd, monde.gd `hauteur()` |
| D | Sol écologique : carte de sol 480² (0,5 m/texel) — R = matière (neige, neige piétinée, terre, aiguilles, mousse, roche), G = clarté, B = masque ; règles pente/chemin/sous les arbres/creux au nord, transitions tramées Bayer ; uniform `sol_carte` dans ps1.gdshader (terrain seulement), textures 32 px à 8 texels/m, mipmaps nearest pour le sol. | sol.gd, ps1.gdshader, palette.gd, lignes matériau de `_terrain` |
| E | Végétation écologique dans la zone : amas + vraies clairières + distance minimale (même nombre d'arbres qu'avant), jeunes arbres en lisière, arbres morts sur hauteurs/près des ruines, inclinaison sur axe aléatoire, ancrage sur pente (min de 4 points) ; sous-bois en MultiMesh sans ombre ni collision (souches, branches, touffes sèches double face via `ps1_herbe.gdshader`, semis), portée 30-50 m. Budget zone : ≤ +15 k triangles visibles, ≤ +20 draw calls. | vegetation.gd (placement), sous_bois.gd, ps1_herbe.gdshader |
| F | Composition : cercle (neige sur les pierres sans changer leurs tirages, 2 menhirs couchés, rochers bas, 3 arbres morts), abords du tumulus (dalles, borne runique, arbres morts, rochers). Hors des anneaux r = 9±0,8 et 14±0,8 et des diamètres utilisés par test_degats_sanctuaire. | cercle_runique.gd, abords_tumulus.gd |

Ordre : 0 → (A, B, C en parallèle) → (D, E en parallèle) → F → captures après + tous les tests.

## Protocole de comparaison
Poses (`--pose=x,z,lacet,tangage`, lacet 0 = nord) :
P1 `-4,-3,48,-2` · P2 `-18.5,-16.5,48,0` · P3 `-10,-9,45,-4` · P4 `-29.5,-26,47,0` · P5 `-38,-31,0,4` · P6 `-38,-45,180,-3` · P7 `-28,-50,66,0` · P8 `-2,-20,90,0` (couture) · P9 `-20,10,180,0` (couture) · P10 `30,-30,-90,0` (témoin hors zone, doit rester identique).
Jour `--heure=12`, nuit sans heure. Captures dans `captures/biome/` (`avant_*`, `apres_*`). FPS : `--print-fps --disable-vsync --quit-after 1500 -- --nouvelle --pose=…`.

Tests à relancer après chaque lot : `test_quetes.gd -- --nouvelle`, `test_sauvegarde.gd -- ecrire` puis `-- verifier`, `test_dragon_monde.gd`, `test_marche_pnj.gd`, `test_mort_ragdoll.gd`, `test_degats_sanctuaire.gd`, `test_biome.gd`.

## Paramètres modifiables (à compléter par chaque lot)
_(chaque lot documente ici ses constantes : nom, fichier, valeur, effet)_

### Lot 0 : fichiers et rôle
- `scripts/zone_biome.gd` (ZoneBiome) : `X0 -58, X1 4, Z0 -64, Z1 4, FONDU 8` ; `actif` (posé par `--biome=ancien|nouveau`, défaut nouveau) ; `masque(x,z)` ; `graine(nom)` ; `alea_pos(x,z,sel)` ; `OCCUPATIONS` (disques réservés, vide).
- `scripts/vegetation.gd` (Vegetation) : `placer_foret`, `placer_couvre_sol` (RNG `monde.rng`) puis `instancier` ; `NB_SAPINS 1500`, `NB_BUISSONS 900`.
- `scripts/instanciation.gd` (Instanciation) : `repartir(parent, mesh, transforms, reglages)`, point unique de création des MultiMesh (réglage `ombre`).
- `scripts/rochers.gd` (Rochers) : `creer`, `rocher_mesh` ; `NB_ROCHERS 160`.
- `scripts/cercle_runique.gd` (CercleRunique) : `creer`, `texture_runes`.
- `scripts/chemins.gd` (Chemins) : API figée `distance`, `profil`, `points`, `dans_cone_vue` (stub). `monde.chemins`.
- `scripts/sol.gd` (Sol) : `appliquer(mat_terrain, monde, arbres)` (stub). `monde.mat_terrain`, `monde.arbres`.
- Options de lancement : `--biome=ancien|nouveau` (ou `set_meta("biome", …)`), `--sans-particules`, `--paisible` (draugrs/dragon figés, pas de dégâts), cycle figé en `--capture` même avec `--heure`.
- Outils : `outils/test_biome.gd` (`-- ecrire|comparer <fichier> [--sans-zone] [--biome=…]`, signature hauteurs + MultiMesh + pierres), `outils/comparer_images.gd` (`-- a.png b.png`, % de pixels > 8/255).
- Références Lot 0 : `captures/biome/ref_ancien.sig` (état `biome-avant`), non versionnée.

### Lot A : performances (instanciation.gd, arbres.gd, appels dans vegetation.gd et rochers.gd)
- `Instanciation.CELLULE = 20.0` : côté des cellules (grille alignée sur l'origine du monde) ; un MultiMeshInstance3D par (mesh, cellule), nœud posé au centre de la cellule, transforms en local.
- Réglages de `Instanciation.repartir` : `portee` (0 = illimitée), `marge` (10, hystérésis, fade DISABLED), `ombre_proche` (distance des ombres : l'affichage est alors sans ombre et un MMI « ombre seule » couvre cette distance), `lod_mesh` / `lod_debut` (85) / `lod_portee` (250). Les MMI ajoutés portent la méta `lod` (`"ombre"` ou `"loin"`) : le test d'invariance les ignore.
- Valeurs (vegetation.gd `instancier`) : épicéas et arbres morts `portee 90`, `marge 10`, `ombre_proche 50` ; genévriers `portee 60` (sans ombre) ; rochers (rochers.gd) `portee 120`.
- LOD lointain : `Arbres.epicea_lointain(forme, graine, mats)` (moitié des étages, 5 pointes, tronc 3 pans, ~100 triangles) de 85 à 250 m, sans ombre ; les arbres morts réutilisent leur mesh complet (peu nombreux). Nécessaire pour garder l'horizon boisé de jour (sans lui, la forêt disparaît au-delà de 90 m, la brume ne la cache pas assez).
- Invariance : `test_biome.gd` compare désormais à 1e-4 près (coordonnées locales) ; il faut le lancer AVEC fenêtre (`--resolution 160x90`, pas `--headless` : le MultiMesh ne relit pas ses transforms en headless, l'ancienne signature était donc vide de sens pour les MultiMesh). Référence réelle : `captures/biome/ref_ancien_fenetre.sig` (générée sur le tag `biome-avant`).
- Mesure : `outils/mesure_perf.gd` (fenêtre ; 10 s de stabilisation puis moyenne sur 20 s).
