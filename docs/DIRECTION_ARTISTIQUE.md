# Direction artistique : guide de style commun (ÉBAUCHE, phase 3 de la refonte)

> Ébauche issue de l'audit (`docs/AUDIT_GRAPHIQUE.md`, 2026-10-21). **Écrite pour la résolution du jeu : 640x360** (décision de l'utilisateur).
> Elle complète `docs/BIBLE_VISUELLE.md` (qui reste la source des rampes) : en cas de conflit, la bible fait foi tant que ce guide n'est pas validé.
> Cible : les images de `Desktop\Skyrim captures\reference\`. Règles fixes : tout passe par le shader ps1, filtrage nearest, **jamais de Bayer** (bruit seulement), pas d'effet sur l'eau (glace permise), réalisme 32 bits (pas de cartoon 4 tons), arbres et sol actuels intouchables.

## 1. Critères mesurables (contrôle de chaque scène)

Mesurer chaque capture en 640x360 avec `outils/analyse_palette.gd`. Valeurs tirées des 7 références :

| Indicateur | Extérieur (crépuscule) | Donjon (grotte, crypte) | Intérieur |
|---|---|---|---|
| Luminance moyenne | 0,26 – 0,34 | 0,16 – 0,23 | 0,14 – 0,22 |
| Écart-type de luminance (contraste) | **≥ 0,17** | ≥ 0,13 | ≥ 0,13 |
| Centile 95 % (hautes lumières) | **0,58 – 0,68** (la neige est le plus clair de l'image) | 0,44 – 0,58 | 0,45 – 0,60 |
| Saturation moyenne | 0,26 – 0,36 | 0,32 – 0,44 | 0,32 – 0,45 |
| Pixels chauds (teinte 10-50°, sat > 0,45) | 0,5 – 3 % | 1 – 5 % | 3 – 10 % |
| Pixels bleus saturés | ≤ 2 % | ≤ 4 % (zones de cristaux : ≤ 13 %) | ≤ 1 % |
| Pixels quasi noirs (lum < 0,06) | 8 – 14 % | 10 – 22 % | 10 – 25 % |

Aujourd'hui : village au crépuscule écart-type 0,09 et c95 0,30 ; grotte lac 77 % de bleus saturés ; halle 69 % de quasi noirs et saturation 0,74 (voir audit §2).

## 2. Palette commune

Principe (bible §2) : ombres froides et violettes, lumières chaudes ; aucune couleur libre ; ni `#000000`, ni `#ffffff`, ni gris neutres. Les rampes ci-dessous sont **mesurées sur les références** (k-moyennes) et servent de clés aux rampes 12 tons (interpolation, comme `peinture_bati.gd`).

| Rampe commune | Clés (ombre → lumière) | Usage | Source actuelle à remplacer |
|---|---|---|---|
| **Ombre** | `#030303` `#090808` `#0f0b08` `#14161a` | creux, fond de donjon, nuit profonde | noir `(0.015,0.02,0.03)` de la crypte |
| **Neige crépuscule** | `#393b47` `#464e62` `#55607b` `#697492` `#8089a6` `#98a1be` `#cdd7ec` + reflet chaud `#ceb9ac` | sol, toits, neige posée | `Palette.NEIGE`, `K_NEIGE`, `R_NEIGE`, givre crypte |
| **Pierre froide** (dehors) | `#101214` `#1c1c1f` `#303035` `#444c5b` `#626c86` `#8a94ad` `#a7adbf` | stèles, rochers, falaises, tertre | `Palette.ROCHE`, `K_PIERRE`, `tex_roche` |
| **Pierre de donjon** (brun-gris granuleux) | `#0f0b08` `#1d1919` `#2c2424` `#393130` `#4a3a30` `#593a29` `#88593b` (près du feu) `#c18f68` (arête éclairée) | grotte, crypte, murs intérieurs | `R_ROCHE*`, `PIERRE_*`, `K_PIERRE_A/B/C` |
| **Bois** | bible « Bois travaillé » `#2b1a1e` `#472a21` `#6a4229` `#92613a` `#bb8a53` (+ ton `#150d10`, `#cca066`) | barrières, poteaux, étais, mobilier | `K_BOIS`, `Palette.PLANCHES`, `CrypteTextures.BOIS`… |
| **Bois gris** (vieilli, neigé) | bible « Bois mort » `#3d3c4a` `#5b5a66` `#7f7d82` `#a7a19b` | barrière de l'entrée, palissade | `K_BOIS_GRIS` |
| **Glace / givre** | `#29354a` `#33577f` `#4f86ae` `#86bfd3` `#b6dde8` (jamais `#ffffff`) | glaçons, cascades gelées, givre des arêtes | `R_GLACE`, `R_CRISTAL`, `GLACE`, `m_glace` |
| **Cristal bleu** (accent) | `#1f2a44` `#3a4f74` `#4275b8` `#70b9ed` `#b6e4f8` | cristaux lumineux seulement | `R_CRISTAL`, `R_CYAN`, `R_VIOLET` |
| **Braise / flamme** | bible `#5a1a1c` `#b3341f` `#ec6a1f` `#fcb53a` `#fff0a8` | feux, lanternes, fenêtres | 6 variantes en dur |
| **Runes cyan** | bible `#0c4a5e` `#14899b` `#3fd0d0` `#b6fbf0` | runes, magie | 4 variantes en dur |
| **Végétation sèche** | `#351520` `#5c1f2b` `#7a3a2a` `#8a5a2a` `#a06a32` + givre `#98a1be` | buissons brun-rouge, herbes givrées | `Palette.FOIN` des touffes |
| **Ciel crépuscule** | nuages `#1b191a` `#272931` `#393b47` `#55607b` ; trouée `#9a6839` `#e0a060` `#f4c88a` (fine, ≤ 3 % du ciel) | ciel, rim des nuages | déjà proche (`ciel_nuit.gdshader`) |

À coder une seule fois : `scripts/palette_commune.gd` (constantes + `rampe(cles, n)`), lu par tous les générateurs ; `palette.gd` v1 disparaît du décor.

## 3. Échelle de détail (640x360)

Caméra : fov vertical 72°. À 640x360, **un mètre à la distance d occupe 248 / d pixels** (1 m à 4 m = 62 px).
Règle : un texel doit couvrir **1 à 2 pixels à la distance de lecture habituelle** de l'objet. Plus dense = moiré et grain « HD » ; moins dense = gros pixels « camouflage ».

| Catégorie | Distance de lecture | Densité (texels/m) | Fondu (par bruit, jamais Bayer) |
|---|---|---|---|
| Objets tenus, mains | 0,3 – 0,8 m | 128 – 256 (actuel, garder) | — |
| Personnages | 2 – 6 m | **64** (squelette à remonter de 32 à 64) | — |
| Décor proche : bâti, murs de donjon, rochers, accessoires, mobilier | 2 – 8 m | **64** | 64 → 32 entre 6 et 14 m |
| Sol (validé) | 3 – 11 m | 32 (proche) / 16 | actuel (`sol_proche`) |
| Arbres (validés) | — | actuel (32 tronc, rameaux 64 px = 4 m) | actuel |
| Grand décor : falaises, toits vus de loin, butte du tertre | 10 – 40 m | 16 – 32 | 32 → 16 au-delà de 15 m |
| Arrière-plan (> 150 m) | — | sans texture, couleur + brume | — |

Conséquences : murs de crypte **128 → 64 t/m** ; neige/glace de la grotte 32 → 64 (tuile redessinée, pas agrandie) ; fer/cuir/foin des intérieurs 32 → 64. Géométrie : un détail de forme doit faire ≥ 3 px à sa distance de lecture (≥ 5 cm à 4 m) pour être modélisé ; en dessous, il va dans la texture.

**Accroche des sommets** : grille = H/2 = **180** à 640x360, la même partout (dehors, donjons, personnages) ; idéalement calculée dans le shader (`g = VIEWPORT_SIZE * 0.5`).

## 4. Règles de texture

1. **Champ de hauteur → éclairage rasant doux → rampe** (méthode de `peinture_bati`), avec **tramage par bruit** entre deux tons (±1 ton), jamais de Bayer, jamais de damier.
2. **Granuleux, pas bruité** : moucheté fin en amas de 2-3 px (références : pierre « granit » de la crypte), 6 à 10 tons actifs par matière, filtre « mode » contre les pixels isolés.
3. **Arête haute claire, pied sombre** : chaque bloc, planche, pierre a un biseau (1 px clair en haut, 1-2 px sombres en bas) ; joints de 1 px. Pas de contour noir.
4. **La neige et le givre se posent en haut** : toute surface dont la normale monte (> 0,6) reçoit la rampe Neige dans le shader (masque par la normale du monde + bruit de bord), avec un bourrelet géométrique sur les arêtes horizontales des objets dehors (barrières, poteaux, rochers, lanternes, stèles). Dans les donjons : givre sur les arêtes hautes, glaçons dessous.
5. **Motifs nordiques** (entrelacs en losanges) : gravés dans la texture avec carte de relief (comme la gravure de la crypte), jamais en couleur plate ; réservés aux stèles, piliers, urnes, autel, linteaux.
6. **Pas de blanc pur ni de bleu saturé en grandes plages** ; le bleu vit dans les cristaux, la magie, le jour au loin.
7. **Mipmaps « vote de couleur »** pour toute texture vue à plus de 8 m (un seul module, au lieu de cinq copies).
8. Densité selon §3 ; tuile bouclée et deux variantes par matière (bible §4.8).

## 5. Matériaux réutilisables (bibliothèque cible)

Une fabrique par matière, densité en paramètre (32 / 64), version cuite dans `assets/` comme aujourd'hui :

| Matière | Variantes | Shader |
|---|---|---|
| Pierre appareillée | sèche dehors, donjon (brun-gris), dalle de sol, voûte, intérieure | `ps1_bati` (triplanaire) |
| Roche brute | rocher dehors (neige posée), paroi de grotte, stalagmite | `ps1_bati` / `grotte` |
| Pierre sculptée | stèle à entrelacs, pilier, urne, autel | `ps1_bati` + relief |
| Bois | planches, poteau équarri, rondin, étai de mine, bois gris neigé | `ps1_bati` |
| Neige | sol (existant), toit, bourrelet posé | `ps1` / masque normale |
| Glace / givre | glaçon, cascade gelée, plaque, givre d'arête | `ps1_bati` (jamais d'effet d'eau) |
| Cristal | cristal lumineux (émission faible, rampe Cristal) | `grotte` |
| Fer / rouille | chaîne, lustre, ferrure, lanterne | `ps1_bati` |
| Végétation sèche | buisson brun-rouge, herbe givrée (cartes alpha) | `ps1_herbe` |
| Toile, os, urne, parchemin | (crypte, déjà partiellement communs) | `crypte` |

Accessoires « kit » à construire une fois (MultiMesh si répétés, SOCLE §1) : lanterne sur poteau, barrière basse en planches, dalles de chemin, rocher enneigé (3 tailles), stèle à entrelacs, buisson sec, touffe d'herbe givrée, glaçons (rangée), stalagmite givrée, étai de mine + lanterne, niche à squelette + urne, chaîne + lustre, toile d'araignée, brume au sol (carte additive en paliers de bruit).

## 6. Préréglages de lumière (une constante partagée, `scripts/lumieres.gd`)

Toutes les lumières locales : sans ombre (sauf exception justifiée), portée 3-10 m, fondu à distance obligatoire (SOCLE §2). Couleurs en linéaire Godot.

| Préréglage | Couleur | Énergie | Portée | Atténuation | Vacillement | Notes |
|---|---|---|---|---|---|---|
| **Torche** (murale, tenue) | (1,0 ; 0,56 ; 0,24) | 1,6 | 8 m | 1,5 | ±0,25 à 6-9 Hz, bruit | sprite flamme + halo additif doux |
| **Lanterne** (poteau, étai) | (1,0 ; 0,62 ; 0,32) | 1,1 | 6 m | 1,6 | ±0,06, lent | vitre émissive `#fcb53a` ; 1 lanterne tous les 12-15 m dans le village |
| **Brasero / feu** | (1,0 ; 0,52 ; 0,20) | 2,4 | 10 m | 1,4 | ±0,35 | feu de camp : ramener à 10 m + fondu |
| **Bougie** | (1,0 ; 0,66 ; 0,36) | 0,6 | 3 m | 1,8 | ±0,08 | |
| **Cristal bleu** | (0,36 ; 0,62 ; 1,0) | 0,7 | 4 m | 1,6 | aucun (pulsation ±0,05 sur 4 s possible) | émission de la texture ≤ ton 3 de la rampe Cristal |
| **Rune / magie** | (0,35 ; 0,80 ; 1,0) | 0,9 | 5 m | 1,5 | aucun | |
| **Lune** (directionnelle) | (0,62 ; 0,72 ; 1,0) | 0,75 | — | — | — | actuel ; ambiant (0,34 ; 0,41 ; 0,60)×0,58 |
| **Crépuscule** (directionnelle) | (1,0 ; 0,60 ; 0,32) | 1,3 | — | — | — | hauteur min. du soleil **12°** pour qu'il touche les façades ; ambiant (0,42 ; 0,45 ; 0,58)×0,52 ; trouée orange fine au ciel ; neige éclairée ≥ 0,6 de luminance |
| **Ambiance donjon** | ambiant (0,30 ; 0,33 ; 0,40)×0,55 (au lieu de (0,5 ; 0,58 ; 0,72)×1,15 dans la grotte) | — | — | — | — | ombres quasi noires ; les torches font la lumière ; le froid vient des cristaux et du « jour au loin » |

Règle de composition : dans une vue, **une dominante froide + 1 à 3 sources chaudes** ; jamais plusieurs couleurs vives concurrentes (bible §6). Glow sous terre : à réactiver avec seuil élevé (≥ 1,2) et intensité ≤ 0,5 pour un léger halo des flammes, sans bloom.

## 7. Plan de déploiement par scène

| Ordre | Scène | Contenu | Dépend de | Contrôle |
|---|---|---|---|---|
| 0 | Socle | `palette_commune.gd`, `lumieres.gd`, module `TexturesCommun` (bruit, rampe, mips, nettoyage) ; HUD relatif ; grille 180 | — | tests verts, empreintes identiques hors rendu |
| 1 | **Entrée du village** (prototype, en cours) | lanternes, barrière en planches neigée, dalles, rochers enneigés, stèle à entrelacs, buissons secs, fumée, crépuscule | 0 (peut précéder en local) | pose commune `poses_refonte.txt` à 10 h / 17h30 / 21 h / 6 h ; §1 ; ≤ 6,7 ms GPU |
| 2 | Village entier | remplacer palissade (rondins équarris + neige), porte sculptée, accessoires de rue en kit, toits (rives, dessous) | 1 | poses V1-V12 |
| 3 | Grotte | rampe Pierre de donjon, cristaux en accent, glaçons, stalagmites, étais + lanternes, brume au sol, ambiance donjon | 0 | `captures_grotte.sh` ; tests grotte verts |
| 4 | Crypte | murs 64 t/m appareillage irrégulier, entrelacs, niches, urnes, chaînes/lustres, glaçons, mécanismes repeints | 0, kit de 3 | `captures_crypte.sh` ; tests crypte/mécanismes verts |
| 5 | Tumulus, cercle, entrée de grotte | butte sculptée, stèles, neige unique (fin des trois neiges) | 0, 1 | poses Z*, T* |
| 6 | Intérieurs | désaturation, contre-jour froid, densités 64, mobilier chanfreiné | 0 | `poses_interieurs.txt` |
| 7 | Reste de la carte, puis 1 km² | application du kit (MultiMesh par cellule) | 1-6 | SOCLE §4 |

Chaque étape : capture 640x360 (et 480x270 pour comparaison), planche avant/après + référence, mesure §1 et perf (`outils/audit_resolutions.sh` / `mesure_vues.gd`), option `--sans-xxx` pour l'A/B.
