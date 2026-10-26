# Décor animé du menu titre (`menu_decor.tscn`)

Scène autonome et plein écran : la peinture de référence, sans les boutons peints, animée par un seul shader et quelques particules.
Elle ne charge rien du monde ouvert.

## Utilisation

```gdscript
const DECOR := preload("res://scenes/menu_decor/menu_decor.tscn")
var decor: MenuDecor = DECOR.instantiate()
add_child(decor)            # à mettre SOUS l'interface (premier enfant d'un CanvasLayer ou d'un Control plein écran)
move_child(decor, 0)
```

La racine est un `Control` en plein écran (ancres 0-1, `mouse_filter = IGNORE`). Le cadrage est de type « cover » :
l'image n'est jamais déformée, elle est rognée sur les bords selon le format d'écran (16:9 de référence, 16:10, 4:3, 21:9).

### IMPORTANT : le stretch du projet

Le projet rend en 640×360 (`stretch/mode = viewport`, échelle entière, filtre `nearest`).
Si le décor est affiché tel quel, il est rendu en 640×360 puis agrandi : flou et pixelisé.
Pour un menu net, l'écran titre doit passer la fenêtre en rendu natif pendant le menu, puis remettre le réglage en entrant dans le jeu :

```gdscript
get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # menu
# ...
get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT   # en jeu (réglage d'origine du projet)
```

Autre solution : mettre le décor dans un `SubViewportContainer` dont le `SubViewport` a la taille de l'écran.
Les nœuds du décor forcent déjà un filtrage linéaire avec mipmaps (`texture_filter` du nœud `Cadre`), quel que soit le réglage par défaut du projet.

## API (`scripts/menu_decor/menu_decor.gd`, `class_name MenuDecor`)

| Appel | Effet |
|---|---|
| `pulse_cristal(force := 1.0)` | Fait pulser la lueur du cristal du logo peint (montée en 0,18 s, retombée en 1,1 s). À appeler au survol ou à la validation d'un bouton. |
| `set_logo_peint(visible: bool)` | `true` (par défaut) : le logo peint et la lueur du cristal sont affichés. `false` : ciel nu à la place du logo (l'UI pose son propre logo). Le ciel sous le logo n'est pas animé quand le logo est visible. |
| `is_logo_peint() -> bool` | État courant. |
| `fondu_sortie(duree := 0.8) -> Tween` | Fondu au noir par-dessus le décor. Émet `fondu_termine` à la fin. Exemple : `await decor.fondu_sortie(0.8).finished`. |
| `fondu_entree(duree := 0.8) -> Tween` | Fondu depuis le noir. Émet aussi `fondu_termine`. |
| `set_animations(actif: bool)` | `false` : image fixe (option « réduire les animations »). Le shader et les particules sont figés. Les lueurs restent à leur niveau moyen. |
| signal `fondu_termine` | Fin d'un fondu. |

Réglages exportés : `amplitude_px` (5 px de travelling au premier plan), `periode_s` (50 s), `marge` (1,2 % de rognage en plus), `ancrage` (point fixe du recadrage, `(0.5, 0.3)` : en 21:9 on garde plutôt le haut), `force_vent`.
Réglages du shader (matériau du nœud `Cadre/Fond`) : `force`, `force_eau`, `force_lumieres`, `force_brume`, `force_sapins`, entre 0 et 1.

## Ce qui bouge

Tout est volontairement discret.
- **Profondeur** : une carte de profondeur continue (`masques_b.r`, 8 plans du ciel au premier plan, recalée sur les contours) décale chaque pixel. Le travelling latéral est un sinus de 50 s, de 5 px au premier plan et d'environ 0,6 px pour le ciel. Il n'y a pas de calques découpés, donc ni trou ni effet « carton ».
- **Neige** : 3 couches (lointaine, moyenne, proche et floue), avec des rafales de vent lentes (somme de deux sinus de 13 s et 31 s, déphasées par couche).
- **Lumières** : vacillement des flammes (lanternes, brasero, lanternes du port, torches du pont) et vacillement plus faible des fenêtres, avec un halo additif.
- **Braises** : au brasero, plus quelques-unes à la lanterne.
- **Eau du lac** : ondulation horizontale d'environ 1,6 px sous masque, et scintillement doux des reflets.
- **Cascade** : défilement vertical et traînées claires.
- **Brume** : nappes qui dérivent dans la vallée, au pied du château et sur le lac.
- **Fumées** : 3 cheminées et tours du village.
- **Runes** : pulsation de 5 s.
- **Nuages** : dérive infime par déformation lente.
- **Sapins** : balancement d'environ 1 px aux cimes de 3 grands sapins.
- **Cristal** : respiration lente, plus `pulse_cristal()`.

## Textures (`textures/menu_decor/`)

Toutes sont fabriquées par `scripts/menu_decor/outils/preparer.gd` à partir de `textures/menu_decor/_source/reference.png`. Ce dossier est ignoré par Godot (`.gdignore`), donc la source n'est pas exportée.

```
godot --headless --path . --script res://scripts/menu_decor/outils/preparer.gd [-- --seulement=fond|masques|petites]
```

| Fichier | Contenu |
|---|---|
| `fond_sans_logo.png` | 1920×1080, boutons ET logo bouchés. C'est la texture de la scène (VRAM BPTC + mipmaps, environ 2,7 Mo). |
| `fond_avec_logo.png` | 1920×1080, boutons bouchés, logo peint conservé. Fourni pour l'UI, non chargé par la scène. |
| `logo_peint.png` | Logo peint détouré (RGBA), posé en (562, 9), taille 832×334, en px du fond 1920. |
| `masque_logo.png`, `masque_cristal.png` | Masques 1920×1080 en niveaux de gris. |
| `cristal_halo.png` | Lueur additive du cristal, centrée en (964, 172) en px du fond. |
| `masques_a/b/c.png` | 960×540, canaux d'animation (voir l'en-tête de `shaders/menu_decor/decor.gdshader`). |
| `bruit.png`, `flocon*.png`, `fumee.png` | Petites textures procédurales. |

Pour placer un élément d'UI sur un point précis de la peinture, ses coordonnées sont en px du fond 1920×1080, dans le nœud `Cadre` (mis à l'échelle).

## Vérification

```
bash /tmp/godot_slot.sh <godot> --path . --script res://scripts/menu_decor/outils/captures.gd -- --sortie=<dossier> [--film] [--perf]
```

Le script écrit des captures à t = 0, 5 et 10 s, les autres formats d'écran, une planche de comparaison avec la référence, un film (`--film`) et des mesures (`mesures.txt`).
`canaux.gd` produit une planche de contrôle des masques.
