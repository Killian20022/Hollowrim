# Bible visuelle : Nordique

> Étape §1 de `docs/MISSION_GRAPHISME.md`. Document de référence, à valider AVANT toute texture.
> Planche : `captures/bible/planche_palette.png`, générée par `outils/planche_bible.gd` (headless).
> Rien dans le jeu n'est modifié ; `scripts/palette.gd` sera aligné sur cette bible lot par lot.

## 1. Ce qu'on garde de la nuit actuelle (direction validée)

La nuit est LA référence (captures `captures/biome/final/planche2_recap_nuit.png`) :
- ciel presque noir bleu (`ciel_nuit.gdshader` : haut ≈ `#02030a`, horizon ≈ `#0b121f`), **aurore** vert `#26ff8c` en bas, violet `#8c33f2` en haut, étoiles fines ;
- **neige bleue** (ambiant ≈ `(0.32, 0.40, 0.62)`, lune `(0.62, 0.72, 1.0)`), ombres bleu-violet, brume bleu nuit `#1a2438` ;
- **sources chaudes** (torche, braise, feu) comme seuls points orangés, **runes cyan** comme seul accent froid saturé ;
- palette sombre en volume, grands aplats calmes, peu de contraste fin.

À corriger (jour) : moins délavé ; l'ambiant jour `(0.62, 0.66, 0.74)` et la brume `(0.5, 0.54, 0.62)` sont trop grises.
Les rampes existantes de `palette.gd` (NEIGE `#8796b2`→`#c9d3e5`, ROCHE, AIGUILLES `#0b1814`→`#274a33`, ECORCE, PLANCHES…) sont conservées dans l'esprit (même familles de teintes) mais étendues à 4-6 tons avec un vrai glissement de teinte.

## 2. Palette maîtresse (22 rampes, 102 couleurs)

Chaque rampe va de l'ombre (plus **froide et violette**) à la lumière (plus **chaude**, un peu plus saturée au milieu). Les ombres ne sont jamais du noir pur ni un simple assombrissement : on tourne la teinte vers le bleu-violet. Les lumières tournent vers le jaune-rose.
Les « ~48 couleurs » de la mission correspondent aux **tons moyens et clairs actifs en jeu** (tons 1 à 3 de chaque rampe, soit environ 60) ; les tons 0 (ombres) et derniers (reflets) sont réservés aux creux, arêtes et contours sélectifs.
Toute texture n'utilise que ces valeurs (quantification obligatoire sur la rampe, aucune couleur libre).

| Rampe | Tons (0 = ombre → dernier = lumière) | Usage |
|---|---|---|
| Neige | `#4a557f` `#6877a3` `#8898bf` `#aab8d6` `#cdd7ec` `#f0eff4` | neige au sol et sur les branches ; 0-1 ombres creuses, 5 reflets rares |
| Glace | `#33577f` `#4f86ae` `#86bfd3` `#cfeef0` | plaques de glace, stalactites, eau gelée |
| Epicea Aiguilles | `#08161a` `#10272a` `#1a3d32` `#2c5a41` `#5b866f` `#6e9172` | feuillage d'épicéa ; 4-5 = givre sur les bouts |
| Epicea Ecorce | `#241a22` `#3a2a2a` `#54402f` `#735b43` `#947c5e` | troncs d'épicéa, branches (brun-gris froid) |
| Pin Ecorce | `#3b1f24` `#6a3524` `#9c5129` `#cf7b3c` `#ecaa62` | pin sylvestre : tronc orangé |
| Bouleau | `#17151d` `#3f3d4c` `#787f9e` `#a9aec4` `#d6d8e2` `#f4f0e8` | tronc blanc (2-5) et marques noires (0-1) |
| Bois Mort | `#3d3c4a` `#5b5a66` `#7f7d82` `#a7a19b` | arbres morts, souches, clôtures vieillies |
| Pierre | `#262a3b` `#3a4057` `#565b72` `#787d8e` `#a0a2ab` | soubassements, menhirs, tertre |
| Bois Travaille | `#2b1a1e` `#472a21` `#6a4229` `#92613a` `#bb8a53` | planches, poutres, portes, meubles |
| Tourbe Chaume | `#211e1c` `#3b3322` `#5c4e2d` `#82723f` `#b39d5d` | toits de tourbe, chaume, foin, paille |
| Peau Claire | `#9a6266` `#cf9879` `#efc7a2` `#f8e0c4` | carnation 1 |
| Peau Moyenne | `#7a4747` `#ad7658` `#d6a27a` `#ecc79f` | carnation 2 |
| Peau Foncee | `#432a30` `#70473b` `#9d6b50` `#c18f6c` | carnation 3 |
| Cuir | `#1f1418` `#3a261b` `#5b3d27` `#86603a` | ceintures, bottes, gants, fourreaux |
| Laine Bleue | `#1b2a52` `#2a4382` `#4468ac` `#7b9ad0` | vêtements bleus (teinture guède) |
| Laine Rouge | `#351520` `#5c1f2b` `#8a2f35` `#b9504a` | vêtements rouge sombre (garance) |
| Ecru | `#8e8688` `#b9ae9f` `#dbd0b6` `#efe7d0` | lin et laine non teints |
| Fourrure | `#25262f` `#3d3e4a` `#5c5d68` `#85848c` `#b3b0b4` | cols, doublures, peaux (gris froid) |
| Fer | `#20252f` `#3a4256` `#5b6680` `#8a96ae` `#bcc6d8` | lames, clous, armures, rivets |
| Or Terni | `#4a3419` `#7b5a26` `#a98638` `#d3b25c` | broches, ornements (jamais brillant) |
| Braise Flamme | `#5a1a1c` `#b3341f` `#ec6a1f` `#fcb53a` `#fff0a8` | feu, torches, fenêtres chaudes |
| Runes Cyan | `#0c4a5e` `#14899b` `#3fd0d0` `#b6fbf0` | runes, sanctuaire, magie |

Règles d'usage de la palette :
- **3 à 5 tons par texture**, jamais les 6 : le ton le plus clair et le plus sombre sont des accents rares (< 8 % des pixels).
- **Glissement de teinte** : ombre = 15-25° vers le violet/bleu, lumière = 10-15° vers le jaune ; ne pas monter la luminosité en désaturant seulement.
- Les rampes se croisent peu : une écorce ne porte que sa rampe + `NEIGE` (givre) ; le fer n'emprunte que `FER` + `BRAISE FLAMME` près du feu.
- Hors palette interdits : noir `#000000`, blanc `#ffffff`, gris neutres purs.

## 3. Densité de pixels (une seule, partout)

| Catégorie | Densité | Conséquence |
|---|---|---|
| Décor (sol, arbres, murs, rochers, bâtiments) | **16 texels / m** | tuile 32 px = 2 m ; rameau 64 px = 4 m |
| Personnages, objets tenus, mains | **32 texels / m** | texture 32 px = 1 m ; une botte (30 cm) fait ≈ 10 px |

Filtrage « plus proche » ; mipmaps « nearest » seulement si le scintillement l'exige. Jamais de texture redimensionnée en lissage. Le même rameau ne se met pas à deux échelles différentes sans régénérer la carte à la bonne taille.

## 4. Règles de pixel art

1. **Amas (clusters)** : un ton se pose en paquets de 3 pixels ou plus, orientés selon la forme (aiguilles groupées, sillons verticaux, planches horizontales, crête de congère).
2. **Pas de bruit « sel et poivre »** : aucun pixel de ton différent isolé de ses 4 voisins ; l'outil applique un filtre « mode » après le dessin. Les grains de reflet sont des amas de 2-3 px alignés.
3. **Pas de pixel orphelin** (sprites) : un pixel opaque sans voisin dans ses 8 cases est supprimé ; les petits trous (≥ 3 voisins opaques) sont bouchés.
4. **Contours sélectifs** : un contour sombre seulement là où la forme se détache sur le fond ou sur le dessous (bas des branches), jamais autour de tout. Pas de contour noir.
5. **Anti-alias manuel limité** : au plus un pixel de ton intermédiaire pour adoucir une pente à 2:1 ; jamais de dégradé lissé, jamais de tramage en damier.
6. **Ombre douce intégrée seulement** : occlusion et creux (dessous des branches, joints, bas d'une pierre). **Pas de lumière directionnelle peinte** (pas de côté éclairé fixe) : la lumière vient du jeu. Seuls les petits biseaux (arête haute un ton plus claire, arête basse un ton plus sombre) sont tolérés, car ils lisent la forme.
7. **Silhouette d'abord** : un arbre, une maison, un personnage se reconnaissent en ombre chinoise à 30 m. Le détail ne doit jamais changer la silhouette ; la silhouette est dessinée par la géométrie et les bords des cartes.
8. **Tuiles** : bouclage parfait sur les 4 bords (vérifié par la mosaïque 3×3), pas d'élément unique dominant qui trahisse la répétition ; deux variantes par matière.
9. **Bords des cartes** (feuillage) : alpha 0 ou 255 uniquement (alpha-scissor), bord découpé net.

## 5. Règles de lumière

- **Principale** : froide, en hauteur (lune/ciel) : teinte `(0.62, 0.72, 1.0)`. Les ombres tombent vers le bleu-violet (`ambiant (0.32, 0.40, 0.62)`), jamais vers le gris ni le noir.
- **Sources chaudes** (feu, torche, fenêtres, braise) : seules sources orangées ; elles « réchauffent » les rampes proches (neige proche du feu → `NEIGE` 3-4 tirée vers `BRAISE FLAMME` 2-3), pas les rampes lointaines.
- **Accents** : runes cyan, aurore verte/violette ; rien d'autre de saturé.
- **Brume** : bleu nuit, qui désature et fond l'horizon ; elle fait la profondeur, pas les textures.
- Les textures ne portent qu'une ombre douce (§4.6) ; **aucun visage noir** de nuit (appoint léger, lot 4).

## 6. À faire / à ne pas faire (voir la planche)

| À faire | À ne pas faire |
|---|---|
| Aiguilles en traits orientés groupés ; neige en paquets sur le dessus ; bord découpé (échantillon A) | Triangle vert plein à facettes ; bruit de pixels pour « simuler » des aiguilles |
| Neige = grandes plaques calmes de 2 tons proches + quelques croissants de congère (B) | Vagues régulières en sinusoïde (aspect eau) ; blanc pur sur toute la tuile |
| Traces nettes : creux sombre en haut-gauche, lèvre claire en bas-droite (C) | Taches floues ; traces qui se répètent en ligne de tuile à tuile |
| Écorce en plaques verticales, cassures décalées, un ton de givre (D) | Rayures parfaitement régulières ; bruit uniforme |
| Planches : joint sombre, arête claire, veines en courbes, nœud, clous (E) | Planches identiques ; joints alignés qui forment une grille |
| Pierre : assises irrégulières, arêtes claires, joints de 1 px (F) | Briques régulières ; joints épais ; trous noirs carrés |
| Ombres plus froides/violettes, lumières plus chaudes | Éclaircir/assombrir sans tourner la teinte |
| Accent chaud ou cyan rare et franc | Plusieurs sources de couleur vive dans la même vue |

## 7. Échantillons de référence (planche)

A rameau d'épicéa enneigé 64×64 (carte alpha, 5 tons + neige, 3×3 en mosaïque) ; B neige fraîche ; C neige piétinée + traces ; D écorce d'épicéa ; E planches de maison ; F pierre sèche ; plus une mise en situation de nuit (3 cartes A sur la tuile B, sous teinte de lune). Chaque tuile est montrée ×8, en mosaïque 3×3 ×3 et en taille réelle ×1.
Les cartes et tuiles sont reproductibles : `godot --headless --path . --script outils/planche_bible.gd` (fonctions `echantillon_a`, `tuile_neige`, `tuile_pietinee`, `tuile_ecorce`, `tuile_planches`, `tuile_pierre`), que les lots 2, 3 et 5 pourront reprendre comme point de départ.

## 8. Validation

Les valeurs de ce document font foi. Une modification de palette passe par ce fichier, puis par la planche, puis par `palette.gd`.
