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

## Disposition recommandée (écran 480x270, coin haut-gauche de chaque élément)
- Boussole : x=160, y=4 (centrée, 160..319). Repère : x=238, y=0 (colonne centrale 240). Lettres : y=6 (bandeau y + 2), visibles entre x=165 et x=314 : à clipper.
- Indicateur de dégât : x = 240 + décalage angulaire - 2, y=7 (centré verticalement dans le bandeau, 5 px : y=7..11).
- Vie (bas gauche) : cadre à x=16, y=256 ; remplissage à x=19, y=258 (74x3).
- Vigueur (bas droite) : cadre à x=384, y=256 ; remplissage à x=387, y=258 (cadre 384..463, marge de 16 px à droite comme la vie à gauche).
- Magie (centre, optionnelle) : cadre à x=200, y=256 ; remplissage à x=203, y=258. Si omise, laisser le centre libre.
- Réticule : x=238, y=133 (centre exact 240,135).
- Marge basse : 7 px (256+7=263 sur 270). Tout est sur des entiers : agrandissement x3/x4 sans flou.
