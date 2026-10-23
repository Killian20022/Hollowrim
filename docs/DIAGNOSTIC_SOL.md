# Diagnostic du sol : d'où viennent les « gros carrés » (2026-10-22)

Référence utilisateur : `references/exterieurs_v2_planche.png` + `exterieurs_v2_prompt.md` (sections 1 et 6). Base : biome/zone-temoin e6f0cf7.
Captures : `Desktop\Skyrim captures\refonte\exterieurs_v2\sol_temoin\` (voir fin). Outils : `--sol-debug=N` / option de pose `sol_debug=N`
(1 = grilles de 0,25 m en rouge et 1/16 m en cyan, 2 = décalage de ton, 3 = texels/pixel).

## Mesures (caméra 1,62 m, FOV vertical 72°, plein écran 640×360 = 2 pixels d'écran par pixel interne)
Taille d'un pixel interne au sol et nombre de pixels internes par texel de tuile (16 texels/m = 6,25 cm) :

| Sol à | pixel (large × profond) | 1 texel 6,25 cm @360 lignes | @270 (480×270) | @540 (960×540) |
|---|---|---|---|---|
| 2 m  | 1,0 × 1,7 cm | 6,0 px de large × 3,8 de haut | 4,5 × 2,8 | 9,0 × 5,7 |
| 5 m  | 2,1 × 6,9 cm | 2,9 × 0,9 | 2,2 × 0,7 | 4,4 × 1,4 |
| 15 m | 6,1 × 56,7 cm | 1,0 × 0,1 | 0,8 × 0,08 | 1,5 × 0,17 |

## Causes, par ordre d'importance
1. **Densité de texels trop basse pour 640×360** (cause n°1). La bible fixe 16 texels/m (calée sur 480×270). À 640×360 puis ×2 à l'écran, un texel de
   tuile fait 6 px internes (12 px écran) à 2 m : ce sont les « gros carrés » des plaques de neige (tons 3/4) et des empreintes. Le mode « proche »
   (`sol_proche` 3–11 m) double à 32 texels/m par Scale2x : mêmes formes, escaliers plus petits, et le fondu entre niveaux est tramé par texel.
2. **Données de matière à 0,25 m** (carte 960², 4 texels/m, lecture `filter_nearest`) : les limites terre/neige/aiguilles sont des blocs de 25 cm
   (6,25 cm ×4) décalés par un hachage par bloc de 12,5 cm (`carte_au`, `bloc`) → bords en marches de 12–25 cm, visibles de près (grille rouge de
   `diagnostic_grilles_0-25m_et_ton.png`). Le décalage de ton (`creux`/lèvre) ne touche que les bords (image « ton » : le reste est plat).
3. **Contenu des tuiles** : plaques de 2 tons lisses (`_fond_neige` + `filtre_mode`) bordées d'escaliers de 1 texel : aspect mécanique, pas de variation
   fine ni de couleur subtile ; une seule période de 8 m.
4. **Non-causes** : UV/projection (UV monde non affines, alignés sur la grille de texels : stables) ; filtrage (nearest voulu, mipmaps par vote de couleur au
   loin : 1 texel < 1,6 px à partir de ~8 m, pas d'aliasing) ; aimantation de sommets du shader PS1 (`grille` 135 : 1 pixel interne sur les sommets, sans effet sur
   le sol évalué par pixel) ; tramage final (bruit IGN, pas de Bayer, 32 niveaux : invisible sur le sol). Le flou n'est pas en cause et n'est pas la solution.
5. **Pixels artistiques voulus** : le pixel interne de 640×360 (agrandi ×2 en nearest), les texels de 1/16–1/32 m sur sentier, les bords nets terre/neige.
   **Artefacts** : points 1–3.

## Correction faite (zone témoin seulement, `SolV2.RECT` = x −22…−8, z −22…−8)
- `shaders/ps1.gdshader` : branche `sol2_rect` (zéro = désactivé ; fondu en bruit de 3 m vers l'ancien rendu ; au-delà de ~9 m on retombe sur l'ancien sol
  moyenné par mipmaps). Sol procédural évalué au centre de texels dont la taille suit la distance (1/48 m → 1/6 m, ≈1,6 pixel écran par texel à toute résolution) :
  neige à variations douces (dérive lente, rides dans le sens du vent, plaques plus froides/chaudes), chemin terre + pierres de tailles variées (voronoï à deux
  mailles) + gravier + neige mince, neige piétinée, aiguilles, lèvre claire/ombre aux limites terre/neige. Aucune nouvelle texture, aucun flou, pas de Bayer.
- `scripts/sol_v2.gd` : activation par zone (`--sol-v2=off`, option de pose `sol_v2=0|1`), 33 touffes d'herbe sèche (texture 48² avec neige au pied), 7 pierres/rochers.
- Blender : `sources_blender/scripts/roches_sol_v2.py` → 6 rochers organiques (160–330 triangles, couleurs de sommets AO + neige sur les replats), `assets/modeles/roches_sol_v2.{dat,glb}`.
- Ni `sol.gd` (cache de la carte de sol resté valide), ni résolution, ni filtrage global, ni collisions existantes ne sont modifiés (3 gros rochers neufs ont leur propre collision).

## Proposition globale (décision de l'utilisateur, NON appliquée)
`proposition_globale_resolution_640_vs_480_vs_960_ANCIEN_sol.png` (ancien sol, `--res=` existant). À 960×540 le texel de tuile passe de 6 à 9 px/texel : plus de carrés, mais
coût GPU ~2,25× ; la vraie réponse est de généraliser le sol v2 (texel lié à la distance, indépendant de la résolution) plutôt que de changer la résolution.

## Perf de la zone (mesure_sol_v2.gd, GPU partagé avec d'autres agents : bruit ±0,5 ms)
Voir le rapport : image 10,9–13,2 ms avant / 10,9–12,8 ms après au repos, GPU +0,3 à +0,7 ms ; marche 11,8 → 12,3 ms (0 image > 33 ms).
