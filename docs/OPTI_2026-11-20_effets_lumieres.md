# Optimisation 2026-11-20 : domaine `effets_lumieres` (lumières, feux, particules, transparents, eau, halos)

Branche `opti/effets_lumieres` (depuis f0c1b14b). Machine : Iris Xe, rendu Mobile, 640x360 interne. Mesures prises sur machine
PARTAGÉE (2 à 3 autres Godot, 7 agents) : le GPU absolu est bruité (jusqu'à ±3 ms entre deux passages identiques) ; seuls les
ÉCARTS APPARIÉS (coupe / base alternés dans le même lancement) et les compteurs (appels, primitives, nœuds) sont exploitables.

## Outils ajoutés

- `outils/audit_effets.gd` (hérite de `audit_mesure_lieu.gd`, mêmes lieux et arguments) :
  - inventaire au moment de la mesure : lumières (dans le champ, ombres, somme lumière × instance touchée, par script d'origine),
    particules (par origine, dans le champ, qui émettent, qui projettent une ombre, restées à la racine du monde), transparents ;
  - `--series="base;X;base;Y…"` : configurations mesurées tour à tour dans UN lancement (même monde, même charge), avec écart
    apparié (médiane de chaque passage moins la moyenne des deux « base » voisins) : ligne `ECART` ;
  - coupes de diagnostic (rien n'est changé au jeu, tout est rétabli) : `lumieres`, `lum:<script>` (ex. `lum:interieur`), `neige`,
    `neige_turb0`, `neige_fps15`, `neige_moitie`, `neige_petite`, `neige_ombre0`, `neige_fige`, `particules`, `feux`, `halos`,
    `transparents`, `eau` ;
  - `--png-series=<dossier>` : une capture par passage (planches avant | après) ; compteurs de la passe d'OMBRE seule
    (`ombre_appels`, `ombre_prims`, indépendants de la charge).
- `outils/banc_neige.gd` : micro-banc de la neige seule (scène minimale). Résultat : la scène entière (5000 flocons + sol) coûte
  0,12 ms de GPU sans lumière à ombre ; c'est ce qui a orienté vers le coût de la neige dans les cartes d'ombre (ci-dessous).
  (Limite : la lecture du temps GPU retombe à 0 après le préchauffage dans cette scène nue ; non creusé, faute de temps.)

## Postes mesurés (écarts appariés, GPU, nuit sauf mention ; 3 passages)

| Lieu | Lumières (toutes coupées) | Particules | Neige seule | Transparents | Feux / halos |
|---|---|---|---|---|---|
| Feu de camp (témoin) | ≈ 0 (7,45 → 7,50 ms) | −0,29 ms | −0,16 ms | −0,06 | −0,03 / −0,02 |
| Place du village | **−1,21 ms** (9 lumières dans le champ, 2 495 paires lumière × objet) | non concluant (±1 ms) | **−0,52 ms** | non concluant | — |
| Crypte | 0,00 ms (7 dans le champ) | 0,00 | — | −0,28 ms (nappes de brume au sol) | halos 0,00 |
| Combat (6 ennemis + sorts) | non concluant | non concluant | — | **−0,74 ms** (effets de sorts) | halos non concluant |

Inventaires : place la nuit 9 lumières dans le champ (torche du joueur 482 objets touchés, 3 torches de gardes 225-301 chacune,
2 lumières d'intérieurs qui « fuient » dehors, brasero/torche du village, mobilier) ; 22 systèmes de particules dans le champ dont la
neige = 5 000 des 5 476 particules ; 18 transparents. Le terrain est déjà découpé en morceaux (chacun ses 8 lumières) : pas de piste
« grand maillage » de ce côté.

## Ce qui est fait

| Commit | Optimisation | Avant → après | Interrupteur |
|---|---|---|---|
| b55a1626 | Giclées de sang (`Sang._burst`) et bouffées du dragon libérées par minuteur en plus du signal `finished`, qui n'est pas toujours émis | combat ~70 s : **101 giclées finies restées dans la scène → 0** ; GPUParticles3D 251 → 154 (dans le champ 125 → 21). Fuite sans borne sur un long combat (2 giclées par coup) | `--sans-opti-sang-liberation` |
| (commit suivant) | Neige : `cast_shadow = OFF` (les 5 000 flocons, matériau opaque à fondu tramé, étaient redessinés dans les 2 découpes de l'ombre de la lune / du soleil) | voir § Neige | `--sans-opti-neige-ombre` |
| e52104ea | Neige sortie dans `scripts/neige.gd` (réglages identiques) pour la mesurer seule | refactorisation sans effet | — |

### Neige sans ombre

Vérification visuelle : mêmes flocons FIGÉS (`speed_scale = 0`) capturés avec puis sans leur ombre dans le même lancement, jour (place,
12 h) et nuit (feu de camp, 21 h), planches pleine image et zoom ×4 du sol :
`C:\Users\lopezk19\Jeux\rendus\opti_2026-11-20\effets_lumieres\neige_ombre\{temoin_nuit,place_jour}\planche_*.png`. Aucune différence
visible (les seules différences de la planche pleine image sont les gardes qui marchent, les flammes et l'aurore, animées).
Gain mesuré (place, 21 h, 6 paires, compteurs de la passe d'ombre, indépendants de la charge) : **−1 appel et −20 000 primitives
par image dans les cartes d'ombre** (5 000 quads × 2 triangles × 2 découpes ; ex. 916 921 → 896 990, −2,2 % de la passe d'ombre).
Le gain GPU en ms n'a PAS pu être chiffré : A/B pris sur machine saturée (base 13 à 24 ms, écarts appariés ±3 ms) ; à refaire au calme
(`audit_effets.gd --series="base;neige_ombre0;…" --sans-opti-neige-ombre`). Estimation d'ordre de grandeur seulement : la neige
entière coûtait −0,16 à −0,52 ms dans le monde contre ~0,1 ms hors ombres au micro-banc.

## Tests lancés

- `test_sang_v2` OK (590 s, file d'attente des créneaux comprise), `test_dragon` OK, `test_dragon_monde` OK.

## Ce qui reste / pistes

- **Lumières de la place la nuit (−1,2 ms si toutes coupées)** : aucune réduction « à rendu identique » trouvée. Les lumières des
  intérieurs n'ont pas de masque de calques : elles éclairent aussi la neige dehors à travers les murs (allumées à < 8 m de l'emprise).
  Les éteindre dehors porte-fermée changerait la lueur autour des maisons : à faire juger à l'utilisateur sur planche (non fait).
- Combat : les effets de sorts transparents coûtent ~0,7 ms ; les runes en orbite (`runes_orbite.gd`) sont 39 petits quads séparés
  (39 appels) : un MultiMesh les réduirait à 2-3 appels (gain CPU estimé < 0,1 ms, effet validé à ne pas retoucher sans planche).
- Projectiles (`projectile.gd`) : la traînée projette une ombre (matériau opaque) ; transitoire, non mesuré.
- Hors domaine (gpu_rendu) : la distance des ombres de la lune (62 m, 2 découpes) détermine le coût de tout ce qui projette ; le
  micro-banc montre que la neige elle-même ne coûte que ~0,1 ms hors ombres.
