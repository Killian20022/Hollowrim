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

### Lot B : corrections (collisions + exclusions des rochers)
- `scripts/tertre.gd` : la collision de la butte est une `ConcavePolygonShape3D` (`backface_collision`) bâtie sur `SphereMesh.get_faces()` transformées par `Transform3D(scale (1, 0.42, 1), position (0, -0.6, -6.5))`, exactement le maillage affiché (sommet = sol + 2,55 m). Plus de cylindre de 6,8 m ; les boîtes de façade sont inchangées. L'interactif de l'entrée (portée 2,3 m) est à 6,8 m du sommet : il ne se déclenche pas depuis le haut.
- `scripts/rochers.gd` : `COLLISION_MIN 0.6` (échelle sous laquelle un rocher n'a pas de collision), `R_CERCLE 11` autour de `CENTRE_CERCLE (-38,-34)`, `ELLIPSE_TUMULUS` centre (-38,-54.5) rayons `RAYON_ELLIPSE (10, 12)`, `MARGE_CHEMIN 2.5` (via `monde.chemins.distance`), disques `ZoneBiome.OCCUPATIONS` ([centre Vector2, rayon]). `Rochers.exclu_zone(monde, x, z)` n'agit que si `ZoneBiome.masque > 0`, et le filtrage est fait APRÈS les tirages de chaque rocher (l'ordre du RNG ne change pas ; `echelles` est une liste parallèle à `parts`). Collision : une `ConvexPolygonShape3D` par rocher, points du modèle × basis, `CollisionShape3D` à translation seule.
- `scripts/vegetation.gd` (colliders de `instancier` seulement) : dans la zone (`masque > 0`), cylindre de rayon `max(0.15, 0.35 × échelle x)` et hauteur `4 × échelle y`, centré à mi-hauteur ; hors zone, le cylindre partagé 0,35 × 4 d'avant.
- Test : `outils/test_collisions_biome.gd` (`--script outils/test_collisions_biome.gd`). `test_biome.gd` ne compte pas les formes de collision : aucune adaptation nécessaire. `--sans-zone` et `--biome=ancien` identiques à `ref_ancien.sig` (8 pierres du cercle comprises) ; sans `--sans-zone`, seuls les MultiMesh de rochers diffèrent (rochers retirés de la zone).

### Lot C : relief local et chemins (`scripts/chemins.gd`, `monde.gd` `hauteur()`)
- Deux polylignes Catmull-Rom (24 pas par intervalle, rééchantillonnées à 1 m, 46 points au total) ; décalage latéral bruité ±1,2 m (`FastNoiseLite`, graine `ZoneBiome.graine("chemin")`, 1D le long de l'abscisse, nul aux 3 derniers mètres de chaque bout).
  - feu → cercle : (-6,-6.5) (-10.5,-9) (-13.5,-13) (-18.5,-16.5) (-22,-21.5) (-26.5,-23) (-29.5,-26) (-33.2,-29.4). Les 7 pierres sont à r 6,5 aux angles 17,2° + k·51,4° ; (-33.2,-29.4) est à 43,8°, au milieu de la brèche 17,2°/68,6° (≈ 4,8 m libres entre deux pierres) : points inchangés.
  - cercle → tumulus : (-34.8,-39.8) (-35.8,-43) (-38,-45.2) ; départ à 298,9°, au milieu de la brèche 274,3°/325,8° ; `porte_dehors` = (-38, -45.2) (tertre.position + (0,0,2.8)) : le sentier s'arrête exactement devant la porte.
  - `points` = les deux polylignes mises bout à bout, `debuts` = indices de départ (le saut entre les deux n'est pas un segment).
- `distance(x,z)` : seaux de 8 m (Dictionary), 9 seaux voisins, O(1) ; renvoie INF au-delà de ~7 m. `profil(x,z)` = poids 0..1 (smoothstep(4, 1.2, dist)), pour le sol du lot D. `hauteur_axe(x,z)` = hauteur lissée de l'axe.
- Profil de l'axe : hauteur `hauteur_sans_chemin` tous les mètres, moyenne glissante ±4 (9 m), pente plafonnée à 12° (passes aller/retour). Dans `hauteur()` : `w = smoothstep(4, 1.2, dist) * masque * 0.85`, `h = lerp(h, axe, w)`, puis ornière `-0,10 m * smoothstep(1, 0.2, dist) * masque`. Les 15 % restants font que la pente réelle atteint ~16° par endroits (mesure).
- Bords de plateaux (feu, cercle) : `d' = d + 3,5 * bruit(x*0,08, z*0,08) * smoothstep(11, 15, d) * masque` (`BORD_NIVEAU 11`, `BORD_AMPLITUDE 3,5`, `BORD_FREQ 0,08`, bruit graine "chemin"+1) : rien ne bouge jusqu'à 11 m du centre (pierres r 6,5, draugrs endormis, feu, `h_cercle`).
- Tumulus : `monde.h_tumulus` = hauteur (sans l'aplanissement) en TUMULUS (-38,-48) ; disque centré (-38,-54.5), plat jusqu'à r 8, raccord smoothstep jusqu'à r 14, pondéré par le masque, appliqué après chemins. La façade et la porte gardent exactement leur hauteur.
- Cône de vue : axe (-18.5,-16.5) → stèle (-38,-34), demi-angle 7°, à 4-24 m de (-18.5,-16.5) (l'origine du cône), ou couloir de 1,5 m autour du segment axe (`dans_cone_vue`).
- Invariance : `hauteur()` commence par `if m <= 0.0: return _hauteur_ancienne(x,z)` (copie verbatim de l'ancien calcul). `test_biome -- comparer ref_ancien.sig --sans-zone` : identique.
- Test : `outils/test_chemin_biome.gd -- --paisible [--sans-arbres]` (capsule suivant les points, traversée du cercle par (-33.5,-34)).

### Lot D : sol écologique (`scripts/sol.gd`, `shaders/ps1.gdshader`, `scripts/palette.gd`)
- `Sol.appliquer(mat_terrain, monde, arbres)` (no-op si `ZoneBiome.actif` faux) précalcule une `Image` 480×480 RGBA8 (0,5 m/texel, origine -120) et la passe au matériau du terrain seulement (`carte_sol`, `carte_rect` = (-120, -120, 1/240), `sol_carte = true`). Calcul uniquement pour les texels de la zone ; ailleurs B = 0 → ancien rendu.
- Canaux : R = matière × 32 (0 neige, 1 neige piétinée, 2 terre, 3 aiguilles, 4 mousse, 5 roche) ; G = clarté (128 neutre, ×(0,5+G) dans le shader) ; B = 255 si texel de la zone. Le masque de zone est tramé Bayer 4×4 (`masque > bayer`) : dans la bande de fondu, les texels non retenus gardent l'ancien rendu, en pixels.
- Hauteurs : grille de 1 m (`monde.hauteur()` un texel sur deux, marge 5 m), normale (±1 m) / creux (4 m) calculés aux nœuds puis interpolés. Mesuré : ~140 ms en headless (207 ms avec la grille pleine à 0,5 m, abandonnée).
- Règles, par priorité :
  1. roche : `normale.y < PENTE_ROCHE (0,80) + bruit_roche × BRUIT_ROCHE (0,08)` ; pierre affleurante `< PENTE_AFFLEURE (0,88)` tramée à `PART_AFFLEURE` 35 %. `bruit_roche` : FastNoiseLite graine `ZoneBiome.graine("sol")`, fréquence 0,18, 2 octaves.
  2. chemin (`monde.chemins.distance`) : terre clairsemée (`CHEMIN_TERRE` 1,0 m : pleine sous 0,4 m, tramée jusqu'à 1 m), neige piétinée jusqu'à `CHEMIN_NEIGE` 1,8 m (bande tramée ±0,3 m) ; neige piétinée autour de la stèle (`RAYON_STELE` 3,5), devant la porte du tertre (`RAYON_PORTE` 3, point = TUMULUS + (0,0,2,8)), sur le plateau du feu (`RAYON_FEU` 5), avec bande tramée de 0,8 m.
  3. sous les arbres (`monde.arbres`, ceux dont `masque > 0`) : aiguilles à 70 % jusqu'à `AIGUILLES_PLEIN` 1,2 × échelle, 30 % jusqu'à `AIGUILLES_BORD` 2,0 × échelle ; rayon bruité (±25 %) pour éviter les disques ; seulement sur la neige (0).
  4. mousse (sur la neige seulement, tramée à `MOUSSE_PART` 40 %) : creux (moyenne des 4 voisins à 4 m − hauteur > `CREUX_SEUIL` 0,05 m) ET `normale.z < MOUSSE_NORD` (-0,2) ; ou texel dont une roche est 1-3 texels plus au sud (pied de roche côté nord).
- Shader : `uniform bool sol_carte` (faux par défaut → code d'avant, au pixel près), `carte_sol` (nearest, sans répétition), `tex_terre/tex_mousse/tex_aiguilles_sol/tex_neige_pietinee` (`filter_nearest_mipmap`, répétition). Varying `pos_monde` (non affine, indépendant de `affine`/touche P). UV : `pos × 0,25` pour les textures 32 px (8 texels/m) et la roche (`tex_base`), `pos × 0,125` pour la neige 64 px. Les 6 textures sont lues sans condition dans le bloc `if (sol_carte)` (dérivées définies pour les mipmaps) ; 8 samplers au total (limite Mobile : 16).
- Textures (`Palette`, 32 px, RNG propre chacune, mipmaps via `texture_mip`) : TERRE `#2a201a #382b22 #4a392b #5d4936` (cailloux ; éclaircie par rapport à la consigne `#1f1712…`, trop noire en jour), NEIGE_PIETINEE `#6f7c95 #7f8ca5 #909db5 #a3afc5` (traces), AIGUILLES_SOL `#2a1e15 #3a2a1b #4d3822 #5e472c` (paillettes), MOUSSE `#1c2a20 #25372a #304433 #3d5240` (paillettes).
- Limite connue : roche et mousse sont rares dans la zone (381 et 214 texels sur ~13 000) car le relief y est doux.
