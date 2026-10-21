# Audit graphique : refonte « Skyrim pixel art 32 bits », phase 1 (2026-10-21)

> Branche `refonte/audit` (base `refonte/base` 5f715ca). **Aucun code de jeu modifié** : seulement des outils (`outils/mesure_vues.gd`, `audit_resolutions.sh`, `planche_resolutions.gd`, `analyse_palette.gd`, poses `poses_audit_*.txt`) et ce document.
> Références : `Desktop\Skyrim captures\reference\` (skyrim_32bits_reference, reference_village_crypte, reference_entree_crypte_bleue, grottes_cryptes_2/3/5/6).
> Planches de l'audit : `Desktop\Skyrim captures\refonte\audit\` (`resolutions.png` pleine définition, `resolutions_apercu.png`, `etat_exterieurs_640.png`, `etat_interieurs_donjons_640.png`, `zoom_hud_480_640_960.png`, `zoom_crypte_480_640_960.png`).
> Décision de l'utilisateur prise pendant l'audit : **640x360 devient la résolution du jeu**. La suite (densités, règles) est écrite pour 640x360.

## 0. Résumé : les 5 écarts les plus graves

| # | Écart | Mesure | Cause technique | Priorité |
|---|---|---|---|---|
| 1 | **Grotte « bleu plastique »** : cristaux, lac et parois en bleu saturé, grands triangles plats, blanc pur | 67 % (cristaux) et 77 % (lac) de pixels bleus saturés, contre 1,6 à 12,6 % dans les références ; 14 % de pixels presque blancs `#d4ecf1` | Rampes `R_CRISTAL/R_CYAN/R_GLACE` qui finissent en `#ffffff` (`grotte_textures.gd:24, 412-413`) ; ambiance de la grotte (`grotte.gd:1026-1030`, ambiant (0.5,0.58,0.72)×1,15) qui bleuit toute la roche ; coques en grands triangles sans relief | **P0** |
| 2 | **Village au crépuscule plat et sans lumière** : contraste moitié moindre, neige sans hautes lumières, pas de sources chaudes | écart-type de luminance 0,093 contre 0,199 (référence image 1) ; centile 95 % 0,30 contre 0,64 ; 0,2 % de pixels chauds contre 0,7-2,5 % | Lumière principale trop faible au crépuscule sur le bâti (soleil à 10° de hauteur, masqué par la palissade), aucune lanterne de rue, ambiant bleu dominant (33 % de pixels bleus saturés) ; l'étalonnage (`cycle.ETAL`) resserre encore les tons | **P0** |
| 3 | **Géométrie primitive et lisse là où la référence est sculptée** : palissade en cylindres à 6 pans, butte du tertre en sphère, cercle en boîtes, mobilier en boîtes, mécanismes de crypte en `BoxMesh`, coques de grotte en grandes facettes | voir §3 ; `village.gd` : 58 `_boite`, 20 cylindres ; intérieurs : ≈190 boîtes + 63 cylindres | Les primitives `PrimGeo`/`BoxMesh` n'ont ni chanfrein, ni neige posée dessus, ni variation ; la neige « qui tient » n'existe que sur les toits (`dalle_neige`) | **P0** (village), P1 (intérieurs) |
| 4 | **Cinq générations de textures et huit générateurs de pierre** qui se touchent : neige de l'entrée de grotte ≠ neige du terrain ≠ neige du bâti ; mécanismes Palette v1 32 px 4 tons collés à des murs de crypte à 128 t/m | 8 générateurs de pierre, 8 de neige, 6 de fer (§4) | Pas de bibliothèque commune ; chaque lot a recopié ses rampes et son bruit ; `palette.gd` n'est pas aligné sur la bible | **P1** (structurel, conditionne tout le reste) |
| 5 | **Lumière et couleur incohérentes d'un lieu à l'autre** : intérieurs noyés d'orange (69 % de pixels presque noirs, saturation 0,74), crypte de l'arène teintée bleu nuit uniforme, feux de 6 couleurs différentes, aucune règle froid/chaud partagée | halle : sat 0,74 contre 0,29-0,43 dans les références ; crypte arène : 25 % de bleus saturés, 0 % de chaud | Préréglages de lumière codés en dur dans chaque script (`monde.gd`, `cycle.gd`, `village.gd`, `crypte_decor.gd`, `grotte.gd`, `interieurs.gd`) ; glow coupé sous terre ; pas de préréglages communs torche / lanterne / cristal | **P1** |

Juste derrière : HUD codé pour 480x270 (cassé à 640x360, voir §6), grille d'accroche des sommets qui ne suit pas la résolution, et caméra de dialogue qui traverse les rondins (capture `dialogue`).

---

## 1. La chaîne de rendu aujourd'hui

### 1.1 Résolution et post-traitement
- **Pas de SubViewport** : la fenêtre racine rend directement en `viewport_width/height` (480x270, `project.godot:23-29`), mode `viewport`, échelle entière, filtre nearest. `--res=WxH` change `content_scale_size` à la fin de `monde._ready` (`monde.gd:156-158`).
- **Une seule passe plein écran**, `shaders/ps1_post.gdshader` sur un `ColorRect` du `CanvasLayer` (`monde.gd:700-710`) :
  - quantification 32 niveaux par canal (15 bits) ;
  - tramage par **bruit IGN** (pas Bayer), par pixel interne, amplitude ±0,5 pas × `tramage` (1,0 dehors, 0,45 sous terre), réduit à ×0,3 sur les arêtes ;
  - vignette d'environ −17 % ; voile de dégâts ; fondu ;
  - étalonnage ombres / lumières / saturation / contraste, piloté chaque image par `cycle.ETAL`.
- **Pas de LUT.** L'interface (HUD, dialogue) est dessinée APRÈS le post : ni quantifiée ni étalonnée.

### 1.2 Shaders (19, tous dans `shaders/`)
| Famille | Shaders | Accroche | Affine | Remarque |
|---|---|---|---|---|
| Décor historique | `ps1` (terrain, sol, objets tenus, Palette v1) | grille 135 | 0,55 | textures sans mipmaps (scintillement) |
| Bâti | `ps1_bati`, copie `ps1_interieur` | 135 | 0 | triplanaire, `texels_par_m` 32/64, fondu 32→16 par bruit |
| Végétation | `ps1_tronc`, `ps1_rameau`, `ps1_herbe` | 135 | 0,55 | validés « parfaits » : ne pas toucher |
| Personnages | `perso` (atlas indexé), `Humain.shader_perso` (ps1 cloné) | 135 | 0,55 | double quantification 15 bits ; espace colorimétrique différent du décor |
| Donjons | `crypte`, `grotte` | **270** | 0 | non enregistrés dans `Palette.materiaux` (la touche P ne les bascule pas) |
| Fond | `arriere_plan`, `ciel_nuit` | aucune | — | éclairage et brume faits à la main ; nombreuses couleurs en dur |
| Effets | `flamme_sprite`, `crypte_flamme`, `halo_sprite`, `braise`, `ps1_rai`, `ps1_vitre` | — | — | plus ≈ 15 `StandardMaterial3D` (particules, rais, halos, givre de piège éclairé, débris) hors famille ps1 |

**Accroche des sommets** : `clip.xy = round(clip.xy/clip.w * g)/g * clip.w` avec `g = (grille·W/H, grille)`. Le pas vaut **H/(2·grille) pixels** : il ne suit pas la résolution (voir §6).

### 1.3 Palettes
- `scripts/palette.gd` : rampes v1 (NEIGE `#8796b2…#c9d3e5`, ROCHE, ECORCE… 4 tons), **pas alignées sur la bible** (`BIBLE_VISUELLE.md` §2, 22 rampes) malgré sa règle §8.
- Les rampes « vivantes » sont ailleurs, recopiées : `sol_tuiles.gd:30-39` (bible), `peinture_bati.gd` `K_*` (12 tons), `peinture_interieur.gd`, `ecorces.gd`, `grotte_textures.gd` `R_*`, `crypte_textures.gd`, `objets_textures.gd`, `personnages_textures.gd` (3e algorithme de rampe, gris purs pour « neutre »).
- Tramage Bayer 4×4 encore présent dans `peinture_bati.gd:20, 191-194` (versions 32 t/m), toléré par la bible §2 bis mais contraire à la règle « jamais de Bayer ».

### 1.4 Lumières, cycle, brouillard, fond
- **Une seule `DirectionalLight3D`** soleil/lune (ombre 2 cascades, 62 m) ; cycle de 40 min (`cycle.gd`), préréglages NUIT / JOUR / CRÉPUSCULE codés en dur (ambiant, énergie, brume, exposition, glow, ETAL).
- **Brouillard** : celui de Godot en DEPTH (dehors, fin 55-62 m) ou EXPONENTIAL (sous terre, 0,028 ; grotte 0,012). `arriere_plan` a sa propre brume.
- **Glow** : dehors seulement (seuil 0,88-1,3, niveaux 1-2) ; **coupé sous terre** → les torches de la grotte et de la crypte n'ont pas de halo d'atmosphère autre que les sprites `halo`.
- **Arrière-plan** (`arriere_plan.gd`) : 6 pics, château à 600 m, 4 200 sapins lointains, 5 appels ; bon, mais **trop discret** derrière la forêt proche (les montagnes de la référence occupent 25-30 % de l'image).
- **Lumières locales** : toutes sans ombre sauf le feu de camp ; couleur de feu en **6 variantes** (`(1,0.55,0.22)`, `(1,0.56,0.24)`, `(1,0.58,0.28)`, `(1,0.62,0.3)`, `(1,0.54,0.22)`…), cyan des runes en 4 variantes ; portées 4 à 14 m ; le feu de camp (14 m, sans fondu) et la torche (sans fondu) dérogent au SOCLE §2.
- **Doublons de valeurs** : ambiant de nuit (`monde.gd:256` contre `cycle.gd:23`), couleur de brume de nuit en 4 endroits, seuil de glow, ambiant intérieur en 3 valeurs (shader, `interieurs.gd:17`, bible).

---

## 2. Mesures couleur : références contre jeu

`outils/analyse_palette.gd` (6 000 pixels tirés au hasard par image ; « chauds » = teinte 10-50°, sat > 0,45, val > 0,45 ; « bleus saturés » = teinte 190-235°, sat > 0,45).

| Image | Lum. moy. | Écart-type | c95 | Sat. moy. | Chauds | Bleus sat. | Quasi noirs |
|---|---|---|---|---|---|---|---|
| **Réf.** image 1 (entrée de village) | 0,32 | **0,20** | **0,64** | 0,29 | 0,7 % | 1,2 % | 11 % |
| **Réf.** village + crypte | 0,28 | 0,19 | 0,63 | 0,29 | 2,5 % | 0,6 % | 13 % |
| **Réf.** entrée de crypte bleue | 0,29 | 0,19 | 0,65 | 0,28 | 0,0 % | 0,6 % | 9 % |
| **Réf.** crypte escalier (2) | 0,17 | 0,14 | 0,44 | 0,42 | 4,6 % | 3,2 % | 21 % |
| **Réf.** crypte autel (3) | 0,22 | 0,16 | 0,53 | 0,33 | 2,3 % | 3,4 % | 11 % |
| **Réf.** grotte rivière (5) | 0,21 | 0,17 | 0,56 | 0,35 | 0,6 % | 1,6 % | 16 % |
| **Réf.** grotte cristaux (6) | 0,19 | 0,17 | 0,54 | 0,43 | 2,1 % | **12,6 %** | 21 % |
| Jeu : entrée 17h30 (640) | 0,23 | 0,16 | 0,45 | 0,35 | 1,8 % | 1,7 % | 16 % |
| Jeu : village 17h30 (32,30) | 0,20 | **0,09** | **0,30** | 0,42 | 0,2 % | 33 % | 10 % |
| Jeu : halle (intérieur) | 0,07 | 0,11 | 0,22 | **0,74** | 3,2 % | 0 % | **69 %** |
| Jeu : crypte arène | 0,16 | 0,09 | 0,31 | 0,62 | **0 %** | 25 % | 3 % |
| Jeu : crypte salle (torche) | 0,13 | 0,13 | 0,28 | 0,44 | 1,9 % | 1,0 % | 25 % |
| Jeu : grotte carrefour | 0,16 | 0,14 | 0,37 | 0,41 | 1,6 % | 6,7 % | 15 % |
| Jeu : grotte cristaux | 0,37 | 0,27 | 0,93 | **0,67** | 0 % | **67 %** | 0,5 % |
| Jeu : grotte lac | 0,27 | 0,15 | 0,58 | **0,73** | 0,1 % | **77 %** | 1 % |
| Jeu : grotte camp | 0,11 | 0,09 | 0,25 | 0,43 | 2,1 % | 0,3 % | 18 % |

Lecture :
- **Les références sont peu saturées (0,28-0,43) et très étagées** (écart-type ≈ 0,19, hautes lumières à 0,55-0,65) : la couleur vient de petites touches (chaud 1-5 %, bleu 1-13 %) sur une base gris-bleu / brun-gris.
- **Le jeu est soit trop plat et sombre (village, crypte, camp : c95 0,25-0,31), soit saturé en masse (grotte bleue, intérieurs orange).** Les hautes lumières manquent partout : aucune neige ne monte au-dessus de 0,45 au crépuscule, alors que la neige de la référence est la plage la plus claire de l'image.
- Palettes de la référence image 1 (k-moyennes, triées) : `#090808 #1b191a #272931 #432d21 #393b47 #464e62 #55607b #9a6839 #697492 #8089a6 #98a1be #ceb9ac`. Grottes/cryptes : bruns `#1d120b #342319 #593a29 #88593b #c18f68` + gris-bleus `#23262c #3b4555 #586a82` + bleu froid `#4275b8 #70b9ed` (cristaux) en accent.

---

## 3. Scène par scène

### 3.1 Extérieur : entrée du village / village (P0)
**Existe** : maisons en rondins à 8 pans (`bati_geo.gd`), dalles de neige de toit épaisses et bosselées, cheminées en blocs, fenêtres chaudes (vitres `ps1_vitre`), sol écologique (validé), sapins (validés), arrière-plan avec château.
**Écarts à la référence (image 1)** :
- palissade en **cylindres à 6 pans, rings = 1**, cônes de pointe, liens en ruban plat (`village.gd:976-1051`) — la référence a une barrière basse en planches et poteaux équarris, neigée ;
- porte du village : poteaux lisses de 5,4 m, « tête de dragon » de 2 boîtes, linteau en boîte de neige ;
- **aucune neige posée sur les objets** (barrières, poteaux, rochers, caisses, tonneaux) ; la référence met un bourrelet de neige sur chaque arête haute ;
- pas de **chemin de dalles** (le sol est un grand aplat de neige piétinée) ;
- **pas de lanternes sur poteaux** ni de sources chaudes dans la rue ; fumée de cheminée à peine visible ;
- pas de pierre levée sculptée d'entrelacs, ni rochers coiffés de neige, ni buissons brun-rouge / herbes givrées au premier plan ;
- dessous de toit en boîte de 9 cm, chevrons en boîtes ; toits trop lisses vus de loin ;
- montagnes trop basses / trop cachées derrière la forêt et la palissade ;
- éclairage du crépuscule plat (§2).
**Causes** : primitives `PrimGeo` ; pas de système de « neige qui tient » générique ; pas de kit d'accessoires de rue ; lumière principale rasante masquée ; pas de préréglage lanterne.

### 3.2 Forêt (validée, à protéger)
Arbres et sol jugés « parfaits » par l'utilisateur. Écarts mineurs : souches et feu de camp en Palette v1 (`monde.tex_ecorce`, 32 px 4 tons), touffes `Palette.FOIN` ; ombres du soleil en grands polygones durs sur la neige à 10 h (capture `foret_10`) — c'est l'ombre de la lune/soleil à 2 cascades, pas les textures. **Ne rien changer aux arbres et au sol** ; remplacer seulement les restes de Palette v1.

### 3.3 Tumulus, cercle runique (P1)
- Butte du tertre = `SphereMesh` 12×6 écrasée ; dalles du sentier en `BoxMesh` ; pierres du cercle en `BoxMesh` hors zone biome ; bois de cerf et os en `BoxMesh`.
- Pierres levées sans entrelacs sculptés (la référence « entrée de crypte bleue » a des stèles à losanges nordiques, coiffées de neige).
- Runes en `StandardMaterial3D` non éclairé, couleur HDR (0.5,1.6,2.0) — bon accent, mais code dupliqué (`cercle_runique.gd:37-44` et 119-125).
- Matériaux morts créés pour rien : `tertre.gd:61-65`, `m_tronc` des arbres morts.

### 3.4 Entrée de la grotte (P1)
Bouche en grandes facettes de roche (`grotte_acces.gd`), **neige de GrotteTextures** différente de celle du terrain juste à côté ; brasero sur trépied lisible. Bonne base (torches, piste), manque givre/glaçons sur les arêtes et rochers enneigés.

### 3.5 Intérieurs des maisons (P1)
- Mobilier quasi entièrement en boîtes et cylindres à 8 pans (≈190 `bx`, 63 `cyl`).
- **Noyés d'orange** : saturation 0,74, 69 % de pixels presque noirs ; les murs proches montrent des texels énormes (rondins à 64 t/m vus à 0,5 m).
- Fer, cuir, foin restent à 32 t/m à côté du bois à 64 t/m.
- Pas de contre-lumière froide (rai du trou à fumée trop faible).
- Caméra de dialogue (scénario `dialogue`) qui traverse un rondin : à corriger côté placement (hors périmètre graphique, à signaler).

### 3.6 Grotte (P0 — retour utilisateur « aucun relief, ni détails »)
- **Bleu saturé « plastique »** dans les sections cristaux et lac (§2), cristaux qui finissent en blanc pur, grands triangles plats visibles, fissures blanches en traits répétés sur la glace.
- Roche de la section d'entrée : texture correcte de près, mais coques en grandes facettes, **mousse verte en confettis** sur le sol (rejet explicite du brief).
- Pas de glaçons, stalagmites givrées, toiles, étais de mine avec lanternes, brume au sol, sol mouillé sombre.
- Ambiance bleue globale (`grotte.gd:1026-1030`, ambiant ×1,15) qui écrase les ombres quasi noires de la référence.
- Grille d'accroche 270 (½ px à 270p) ≠ 135 dehors.
- Densités : roche 64 t/m (bien pour 640x360), neige/glace 32 t/m alors que la tuile vient de `SolTuiles` faite pour 16 t/m.

### 3.7 Crypte (P0/P1)
- Murs à **128 t/m** (512 px pour 4 m) : sur-échantillonnés (1 texel = 1 px seulement à 1,9 m en 640x360) → moiré et « bruit » au-delà de 4 m, détail perdu ; dalles et voûte à 64 t/m.
- Appareillage de briques régulier (bible §6 : « pas de briques régulières »), pas d'entrelacs, de niches à squelettes et urnes, de glaçons, de toiles, de chaînes et lustres de fer, d'arcs brisés.
- Arène teintée bleu nuit uniforme (0 % de chaud) ; salle d'entrée correcte mais sombre (c95 0,28 contre 0,44-0,53).
- **Mécanismes et pièges en Palette v1** (32 px, 4 tons, `BoxMesh`, shader ps1 affine) au milieu des murs 128 t/m : plus gros saut de style ; givre de piège en `StandardMaterial3D` éclairé.
- Rai de lumière : bon élément, mais en bande verticale lisse très saturée.

### 3.8 Personnages (hors périmètre de la refonte, pour mémoire)
Deux systèmes : `PersoAtlas` (indexé, 48-128 t/m, sans mipmap) et l'ancien `Humain` (`PersonnagesTextures`, 64 t/m, gris purs). Squelette guerrier à 32 t/m (2-4× moins dense que les vivants) ; draugr, dragon et épée vue de dos en Palette v1. L'utilisateur fournira des images : on ne touche pas, mais la bibliothèque commune devra exposer les rampes Fer / Cuir / Laine / Os pour eux.

### 3.9 Interface
HUD dessiné en coordonnées absolues pour 480x270 (`hud.gd` : `CENTRE := 240`, boussole (160,4), barres (16,256)/(384,256), panneaux `Rect2(0,0,480,270)`), police Kenney Pixel 16. Label d'aide en police par défaut à 8 px. Voir §6 pour l'impact.

---

## 4. Doublons à unifier (système commun)

| Matière | Générateurs indépendants (chemin:ligne) | Cible |
|---|---|---|
| **Pierre / roche** | `palette.gd:9` ROCHE (terrain, cailloux, mécanismes) · `sol_tuiles.gd:33` · `peinture_bati.gd:23-25` K_PIERRE* (`mur_pierre`, `roche`) · `peinture_interieur.gd:205-207` K_PIERRE_A/B/C · `grotte_textures.gd:15-19` R_ROCHE/B/ARDOISE/BRUN · `crypte_textures.gd:23-25` PIERRE_* · `tertre.gd:61-62` (morts) · `mecanisme.gd:71` | une famille Pierre (froide / chaude / verte) + un seul générateur de murs appareillés |
| **Neige** | `palette.gd:8` · `arbres.gd:28` · `sol_tuiles` · `textures_arbres` · `peinture_bati.gd:28` K_NEIGE 12 tons · `grotte_textures.gd:21, 268` · `crypte_textures.gd:464` (givre) · `piege.gd:203` | une rampe Neige 12 tons ; **priorité** : trois neiges se touchent à l'entrée de grotte, au tumulus, au village |
| **Glace / givre** | `sol_tuiles` GLACE · `textures_bati.gd:175-182` · `grotte_textures.gd:17,22` · `crypte_textures.gd:34-35` · `piege.gd:247` (StandardMaterial) | rampes Glace + Givre communes, **sans blanc pur** |
| **Bois travaillé** | `palette.gd:15` · `peinture_bati.gd:29-30` · `peinture_interieur.gd:372` · `crypte_textures.gd:28` · `objets_textures.gd:14` · `humain.gd` · `draugr.gd:281` · `piege.gd:50` | Bois + Bois gris ; une fonction planches |
| **Écorce** | `palette.gd:11` (feu de camp, souches) · `textures_arbres.gd:519-756` (32 px) · `ecorces.gd` (lot 2, validé) | garder `Ecorces` seul |
| **Fer / acier / rouille** | `palette.gd` ACIER · `peinture_bati.gd:31-32` · `objets_textures.gd:19-23` · `crypte_textures.gd:29-30` · `humain.gd` · `draugr.gd:236` · `personnages_textures.gd:220` | Fer + Rouille |
| **Terre / tourbe / chaume, mousse, cuir, fourrure, os** | 4 à 6 copies chacune (voir rapport d'inventaire) | une rampe chacune |
| **Flamme / braise / halo / rai** | `peinture_bati` K_BRAISE · `objets_textures` · `crypte_textures` (`flamme_atlas_image` remplacé) · `halo_image`/`rai_image` en double crypte/grotte | un module Effets |
| **Outils** | 6 fonctions de rampe, 7 bruits (`_hash`, `_vn`, `fbm`…), 4 tramages (dont Bayer), **5 versions des mipmaps « vote de couleur »**, 4 nettoyages de texels isolés, 3 variantes de shader par remplacement de texte | un module `TexturesCommun` (bruit, rampe, tramage bruit, mips, nettoyage) |

Code mort à retirer au passage : `palette.gd:83-123` + constantes l.19-22, `tertre.gd:61-65`, `vegetation.gd:98-102`, `textures_arbres.gd:624-756`, `mains.gd:100-125`, `m_tronc` de `abords_tumulus.gd:82` / `cercle_runique.gd:192`.

---

## 5. Test de résolution 480x270 / 640x360 / 960x540

**Méthode** : `bash outils/audit_resolutions.sh captures/audit_res` — un lancement par résolution (fenêtre, vsync coupé) ; `outils/mesure_vues.gd` lance la scène en mode `--captures`, chaque vue reste posée 400 images, on ignore les 60 premières, on moyenne GPU/CPU du viewport, appels de dessin et primitives. Vues (`outils/poses_audit_resolutions.txt`) : **entrée** = pose commune `21.80,19.82,-132.3,0.3` à 17h30 ; **crypte** = salle d'entrée `0,-19.5` (portes ouvertes) ; **grotte** = carrefour `29.5,0`. Torche tenue, HUD visible.
**Attention** : machine partagée avec 6-8 agents et jusqu'à 3 autres Godot ; une 1re passe à 640x360 a donné 6,63 ms à l'entrée, la 2e 7,54 ms. Ordre de grandeur fiable, ±15 %.

| Vue | 480x270 | 640x360 | 960x540 |
|---|---|---|---|
| Entrée, GPU moyen | 5,46 ms | 6,6 – 7,5 ms | 10,64 ms |
| Entrée, pire image | 20,6 ms | 25,8 ms | 55,9 ms |
| Entrée, appels / primitives | 453 / 357 k | 453 / 358 k | 453 / 360 k |
| Crypte, GPU moyen | 1,91 ms | 2,34 ms | 3,19 ms |
| Crypte, appels / primitives | 961 / 105 k | 960 / 106 k | 964 / 114 k |
| Grotte, GPU moyen | 1,51 ms | 1,97 ms | 2,73 ms |
| Grotte, appels / primitives | 456 / 68 k | 454 / 68 k | 457 / 69 k |
| CPU (toutes vues) | 1,6 – 2,8 ms | 1,2 – 2,6 ms | 1,4 – 2,7 ms |

- Coût GPU : **+38 % à +54 %** de 480 à 640 (×1,78 pixels), **+95 %** à 960 (×4 pixels) : une part fixe importante (ombres, géométrie : 358 k primitives à l'entrée) ; le coût par pixel reste dominant dehors.
- Les appels de dessin ne dépendent pas de la résolution (453 dehors, 960 dans la crypte — la crypte est le lieu le plus « bavard » en appels).
- **Budget 6,7 ms GPU** : 480 = 5,5 ms (marge 1,2 ms) ; **640 = 6,6-7,5 ms (au bord, sans marge pour la refonte)** ; 960 = 10,6 ms (hors budget). Les donjons ont une marge large à toutes les résolutions.

**Lisibilité du HUD** (`zoom_hud_480_640_960.png`) :
- 480x270 : correct (boussole centrée, police 16 px nette, ×3 à l'écran).
- 640x360 : **boussole et texte de quête décalés à gauche** (centrés sur x = 240 au lieu de 320), barres de vie à y = 256 au lieu du bas (360) ; police nette mais 1,33× plus petite à l'écran (×2 au lieu de ×3) — encore lisible.
- 960x540 : HUD dans le quart haut-gauche, police à ×1 à l'écran : **illisible**.
→ Le HUD doit être réécrit en coordonnées relatives (`size`), avec une police à 16 px internes à 640x360 (lisible) ; c'est un prérequis du passage à 640x360.

**Accroche des sommets** : pas = H/(2·grille) px. Grille 135 (dehors, persos) → 1 px à 270p, **1,33 px à 360p** (sautillement irrégulier : un sommet saute tantôt de 1, tantôt de 2 pixels), 2 px à 540p (effet PS1 deux fois plus grossier). Grille 270 (donjons) → 0,5 / 0,67 / 1 px. **À 640x360, il faut grille = 180** (= H/2) partout, idéalement calculée à partir de `VIEWPORT_SIZE.y` dans le shader (`g = VIEWPORT_SIZE * 0.5`), ce qui supprime le doublon 135/270.

**Tramage** : bruit IGN calculé par pixel interne → il s'adapte tout seul à la résolution (le grain fait toujours 1 pixel interne ; il paraît seulement plus fin à l'écran quand la résolution monte). Rien à changer. Les flammes et halos (sprites en texels fixes) restent cohérents.

**Textures** (`zoom_crypte_480_640_960.png`) : à 480x270 les murs de crypte 128 t/m moirent (sous-échantillonnage) ; à 640 ils sont plus lisibles ; à 960 ils paraissent « HD » et l'effet rétro disparaît.

**Recommandation chiffrée : 640x360** (décision confirmée par l'utilisateur). Conditions : (1) HUD relatif ; (2) grille d'accroche = 180 (ou H/2 calculée) ; (3) récupérer ≈ 1 ms GPU à l'entrée du village avant d'ajouter du décor (pistes : ombres de la lune 62 m → 45 m ou 1 cascade au-delà de 20 m, MultiMesh des accessoires, fondu des lumières), pour revenir à ≤ 6 ms et garder ~0,7 ms de marge pour la refonte. 960x540 est exclu (10,6 ms, HUD illisible, perte du grain). 480x270 reste le repli « performance ».

---

## 6. Priorités pour la phase 2-3

1. **P0** Prototype « entrée du village » (en cours, autres agents) : lanternes sur poteaux + barrière en planches neigée + dalles + neige posée + fumée + éclairage crépuscule (hautes lumières de neige ≥ 0,6).
2. **P0** Grotte : retirer le bleu saturé en masse (bleu = accents ≤ 10-13 % des pixels, cristaux seulement), ombres quasi noires, roche brun-gris granuleuse, glaçons/givre sur arêtes, plus de mousse en confettis.
3. **P1** Bibliothèque commune de matières (`TexturesCommun` + rampes de la bible étendues à 12 tons) → remplacer Palette v1 partout, puis unifier pierre / neige / glace.
4. **P1** Préréglages de lumière communs (`DIRECTION_ARTISTIQUE.md` §5) et une seule couleur de feu.
5. **P1** HUD relatif + grille d'accroche H/2 (prérequis 640x360).
6. **P2** Crypte : murs 128 → 64 t/m, appareillage irrégulier, entrelacs, niches, glaçons ; mécanismes repeints.
7. **P2** Intérieurs : désaturer, contre-jour froid, densités homogènes.
