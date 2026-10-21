# HUD nordique : éléments SVG (1 unité = 1 pixel, écran interne 480x270)

Tous les fichiers : uniquement des `<rect>` sur coordonnées entières, `shape-rendering="crispEdges"`. À importer avec filtre Nearest et sans mipmaps.

| Fichier | Taille | Rôle |
|---|---|---|
| barre_cadre.svg | 80x7 | Cadre de barre (vie, vigueur, magie) |
| boussole.svg | 160x11 | Bandeau de boussole, sans lettres |
| boussole_repere.svg | 5x4 | Pointe centrale (vers le bas) |
| lettres_boussole.svg | 23x7 | N E S O |
| reticule.svg | 5x5 | Réticule (4 traits, centre vide) |
| indicateur_degat.svg | 5x5 | Losange rouge d'ennemi/dégât |

## barre_cadre.svg (80x7, embouts inclus dans les 80 px)
- Intérieur transparent : x=3..76, y=2..4, soit **x=3, y=2, largeur 74, hauteur 3**.
- Remplissage : dessiner un rect de 74x3 à (3,2) sous le cadre (le cadre est au-dessus), largeur variable = 74 x ratio.
- Couleurs conseillées : vie #7a1c1c / #b8322a / #e0574a (ombre, base, reflet), vigueur #1f5a3a / #2f8a56 / #5fc27f, magie #1f3a7a / #2f5fb8 / #6f9be8. Ligne du haut du remplissage (y=2) = reflet, y=3 = base, y=4 = ombre. Fond vide conseillé : #0b0f1a.

## boussole.svg (160x11)
- Fenêtre utile entre les embouts : x=5..154 (150 px), y=1..9.
- Lettres 5x7 : les placer à y=2 (relatif au bandeau), donc 1 px de marge en haut et en bas.
- Fond en opacité 0,6 (fill-opacity) : un PNG importé conserve la transparence.

## boussole_repere.svg (5x4)
- Pointe vers le bas, posée juste au-dessus du bandeau. Colonne centrale = x=2.
- Pour centrer sur le milieu du bandeau (x=80), la placer à x=78 relatif au bandeau.

## lettres_boussole.svg (23x7), abscisses (coin gauche, chaque lettre fait 5 px, 1 px d'écart)
- N : x=0 (or #e8a64a)
- E : x=6
- S : x=12
- O : x=18 (Ouest)
- Pour faire défiler : découper en régions 5x7 (Rect2(x,0,5,7)) et répéter la séquence N E S O sur 360 degrés, avec un pas régulier (par ex. 40 px entre lettres, soit 160 px = 90 degrés visibles à ~2,25 px/degré) ; on peut ajouter des petits traits intermédiaires NE/SE/SO/NO en rect 1x3 si besoin.

## Mise en page réelle (refonte 640x360)
`hud.gd` et `dialogue.gd` placent tout en RELATIF à la taille logique de l'écran (centre, bas, droite), avec un facteur d'échelle ENTIER (`scripts/echelle_ui.gd`) : 480x270 et 640x360 → ×1, 960x540 → ×2 (écran logique 480x270). Les tailles des SVG ne changent pas. Les coordonnées ci-dessous restent celles de la maquette 480x270 (barres : 16 px des bords, 14 px du bas ; boussole centrée en y=4 ; réticule centré).

## Disposition recommandée (écran 480x270, coin haut-gauche de chaque élément)
- Boussole : x=160, y=4 (centrée, 160..319). Repère : x=238, y=0 (colonne centrale 240). Lettres : y=6 (bandeau y + 2), visibles entre x=165 et x=314 : à clipper.
- Indicateur de dégât : x = 240 + décalage angulaire - 2, y=7 (centré verticalement dans le bandeau, 5 px : y=7..11).
- Vie (bas gauche) : cadre à x=16, y=256 ; remplissage à x=19, y=258 (74x3).
- Vigueur (bas droite) : cadre à x=384, y=256 ; remplissage à x=387, y=258 (cadre 384..463, marge de 16 px à droite comme la vie à gauche).
- Magie (centre, optionnelle) : cadre à x=200, y=256 ; remplissage à x=203, y=258. Si omise, laisser le centre libre.
- Réticule : x=238, y=133 (centre exact 240,135).
- Marge basse : 7 px (256+7=263 sur 270). Tout est sur des entiers : agrandissement x3/x4 sans flou.

## Dialogue

| Fichier | Taille | Rôle |
|---|---|---|
| dialogue_cadre.svg | 24x24 | Cadre de boîte de dialogue, NinePatch |
| dialogue_nom.svg | 12x12 | Cartouche du nom, NinePatch |
| touche_e.svg | 11x11 | Touche E (invite d'interaction) |
| suite.svg | 5x3 | Flèche « suite » or, pointe vers le bas |

### Marges 9-slice (Godot : NinePatchRect, filtre Nearest, axes en mode Tile ou Stretch)
- **dialogue_cadre.svg** : gauche **8**, haut **8**, droite **8**, bas **8**. Coins ornés (plaque de fer + rivet or) 8x8 ; bords 8 px uniformes dans leur sens (mode Tile conseillé) ; centre 8x8 = #0b0f1a à 85 % d'opacité (transparence conservée à l'import). Les bords font 6 px de cadre visible (contour, reflet, bande de fer, ombre, filet #1a2233) ; les 2 px restants sont du fond.
- **dialogue_nom.svg** : gauche **4**, haut **4**, droite **4**, bas **4**. Fond #1a2233, contour #0b0f1a, liseré or (#e8a64a haut/gauche, #b8762a bas/droite). Centre plein, à étirer.
- Éviter les tailles de boîte non entières et les tailles inférieures à 16x16 (cadre) / 8x8 (cartouche).

### Disposition recommandée (écran 480x270, coin haut-gauche)
- **Boîte** : 320x58 à x=80, y=190 (couvre 80..399 x 190..247), soit 9 px au-dessus des barres (y=256).
- **Marges intérieures du texte** : 12 px à gauche et à droite, 10 px en haut, 8 px en bas. Zone de texte : x=92, y=200, largeur 296, hauteur 40 (3 lignes de 8-9 px d'interligne ou 4 lignes serrées).
- **Cartouche du nom** : hauteur 12, largeur = texte + 8 px (ex. 72x12), à x=92, y=184 : il chevauche le bord haut de la boîte (y=190) de 6 px, dessiné par-dessus. Le nom est centré dans le cartouche, parchemin #e8e0c8 (ou or #e8a64a).
- **Flèche « suite »** : x=374, y=236 (coin droit de la zone de texte, au-dessus du bord bas), clignotement 0,5 s ; masquée à la dernière réplique.
- **Invite « E  Parler »** : touche 11x11 + 4 px d'espace + texte (parchemin, ~36 px de large pour « Parler ») ; ensemble d'environ 51 px centré sur x=240, soit touche à x=214, y=150 (150..160), texte à x=229, aligné verticalement sur la touche. Le réticule occupe y=133..137 : l'invite reste bien dégagée dessous. Masquer l'invite pendant le dialogue.
