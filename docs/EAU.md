# Eau (prototype de validation)

Système d'eau réutilisable, **non placé dans la carte du jeu**. Branche `eau/prototype`, worktree `nordique_eau`.

## Lancer
- Démo : `godot --path . scenes/demo_eau.tscn` (touches 1-5 heure, G/L glace, P PS1 ; args `--heure`, `--pose`, `--sans-eau`).
- Captures : `outils/captures_eau.gd` (`--sortie= --vues= --heures= --paires --perf --sans-eau`), planches `outils/planche_eau.gd`.
- Test sans fenêtre : `godot --headless --path . --script res://outils/test_eau.gd -- --nouvelle` (25 eaux : 5 préréglages x 5 variantes + cascade).
- Carte : `outils/carte_eau.gd` (analyse du relief, voir implantation).

## API
```gdscript
var eau := Eau.creer(&"riviere", Rect2(x, z, larg, prof), niveau_m, hauteur_fond: Callable(x,z)->float, options)
add_child(eau)
```
Options : `variante` (Eau.Variante : LIQUIDE, PARTIELLE, GLACE, BORDS_GELES, PLAQUES), `courant` Callable(x,z)->Vector2,
`turbulences` [[Vector2 centre, rayon, force]], `variantes` Callable(x,z)->Vector2(variante, intensité) (glace qui change le
long du cours), `brume`, `brume_zone`, `params` (écrase le préréglage), `resolution` (cases/m, 4).
Méthodes : `definir_variante(v, intensite)`, `regler(nom, val)`, `profondeur_en`, `contient`, `surface_m2`, `Eau.noms_presets()`, `Eau.reglages(nom)`.
Cascade : `Cascade.creer(hauteur, largeur)` ; origine = lèvre, l'eau coule vers +X local ; `zone_turbulence()` à passer au bassin d'arrivée.
Préréglages : riviere, ruisseau, lac (dérive lente, brume), bassin_souterrain, flaque.
Le ciel/lumière est lu sur le nœud `cycle` du parent (cycle.gd) ; le matériau est enregistré dans `Palette.materiaux` (réglage PS1).

## Principe
- Une texture « carte » 4 cases/m (courant, profondeur, turbulence) + une carte de glace, précalculées une fois ; le shader ne devine rien.
- Couleur par bandes de profondeur, ondes et courant par pas (`cadence`), texels de 1/16 m, grille de sommets calée comme ps1.
- Reflets : court raymarch d'écran (12 pas) avec repli sur le ciel du cycle ; écume de rive/contact/turbulence en tout-ou-rien ; transparence par hachage (jamais d'alpha instable) ; pas de tramage Bayer.
- Glace pixel-art : plaques voronoï, partielle (seuil de bruit), couverte, bords.
- Cascade : nappe Blender (`sources_blender/scripts/cascade_eau.py` -> `assets/modeles/eau/cascade.glb`) + shader de filets verticaux + gouttelettes, écume de pied, brume discrète.

## Coût (mesuré, machine chargée par d'autres agents donc BRUIT élevé)
- Scène de démo entière (forêt ~230 arbres comprise), GPU : 5,9 à 9,3 ms selon la vue (12,2 ms sur un pic), CPU 1,0-1,7 ms, 41-285 appels, 130-300 k primitives (`it4/perf.txt`).
- Coût de l'eau seule : comparaison avec/sans eau (`it4` vs `it4_sans_eau`) NON concluante : écarts de -5 à +1 ms (+4,4 sur un pic), dominés par la charge de la machine. À mesurer sur machine au repos avant d'affirmer un chiffre.
- Scintillement (même vue décalée de 5 cm, part des pixels d'eau qui changent de plus de 8 %), itération 5 (`it5/paires.txt`) : moyenne 15 % le jour, 11 % le crépuscule, 13 % la nuit, maximum 23 % (cascade, jour). Itération 4 : 9-29 %. Sol voisin : ~17-24 % (mesure du coordinateur).
  Cause isolée par `captures_eau.gd --ablation` (`it5_ablation/ablation.txt`, temps figé) : reflets d'écran (jusqu'à -8 points quand on les coupe), écume (-6 points en vue rasante), ondes (-3), puis un plancher de 9-16 % (eau toute coupée) dû à la parallaxe du fond vu à travers l'eau et aux bords de texels. Corrigés en it5 : reflet calé sur des blocs de 4 pixels et lu dans une version floue de l'écran, couleur d'écume et jitter de bande de profondeur par bruit lisse et non par hachage de texel.
- Lancer le prototype : `Desktop\Voir le prototype d'eau.bat` ou `godot --path . -- --demo-eau`.

## Proposition d'implantation (NON appliquée, à valider)
Analyse : `outils/carte_eau.gd` -> `Desktop\Skyrim captures\refonte\eau\prototype\carte\carte_relief.png` et `carte_eau.png`. La carte est une cuvette fermée (fond -3..+6 m, collines de rebord jusqu'à ~24-31 m). Le relief utilisé est l'ancien relief + aplatissement de la grotte, SANS les retouches de la zone témoin (zone X -58..4, Z -64..4 : interdite).
1. **Lac de la combe (sud-ouest)** : préréglage `lac`, niveau -0,8 m, ~3 280 m², centre (-20, 44), étendue x -65..19, z 7..85 ; à 48 m du feu, 64 m du village, hors zone témoin. Bords gelés ou plaques selon l'altitude.
2. **Rivière de l'ouest** : préréglage `riviere` ; descend du rebord ouest (-95,-29, h 19,6) -> (-85,-19, h 11,4) -> (-75,-9, h 3,1) -> (-75,1) -> (-71,11) -> (-67,21, h -0,2) ; ~21 m de dénivelé. **Cascade naturelle** entre (-85,-19) et (-75,-9) ; la rivière finit dans le lac. À 70 m du feu, 112 m du village, 54 m du tumulus.
3. **Ruisseau (option)** : préréglage `ruisseau`, drainage le plus net hors cuvettes en (-29, 21) (bassin versant ~1,1 ha), alimente le lac par le nord ; doit s'arrêter à la limite de la zone témoin.
Limites : le relief devra être creusé (lit, berges) par le système de terrain ; le sol sous l'eau (carte de sol v2) est à coordonner avec l'agent concerné ; aucune nage ni gameplay.
