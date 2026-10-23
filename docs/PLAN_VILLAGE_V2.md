# Plan de masse — Skarnholt v2 (lot C7-PLAN, À VALIDER par l'utilisateur)

Référence : `references/village_v2_planche.png` + `references/village_v2_prompt.md`, avec la MISE À JOUR C7 du brief
(« fie-toi vraiment à la photo » : réorganiser et agrandir le village est autorisé). Rien n'est construit dans le jeu :
ce document et le plan servent de cahier des charges aux lots C7a / C7b / C7c.

- Plan annoté : `docs/plan_village_v2.png` (copie : `Desktop\Skyrim captures\refonte\C\C7plan\plan_village_v2.png`).
- Outils (régénérables) : `outils/plan_village_relief.gd` (export du relief 1 m, toute la cuvette) puis
  `bun outils/plan_village_dessin.mjs captures/relief_c7_carte.txt docs/plan_village_v2.png` (toutes les coordonnées
  du plan sont dans ce script : c'est la source à reprendre pour construire).
- Repère : mètres monde, **x vers l'est, z vers le SUD** (le nord est -Z, comme la quête : « cercle au nord-ouest »).
  Hauteurs = relief réel du jeu hors zone témoin (`_hauteur_ancienne` + aplanissement de la grotte).

## 1. Idée générale

Le village actuel est un disque de 22 m (palissade de 138 m, ~1 520 m²) posé sur un plateau plat à 3,6 m, centré en
(44 ; 40). Le relief autour se prête exactement à la planche :
- au **sud** du plateau, une pente raide (4 → 15 m en 20 m) : la **rue en pente à escaliers** (vue 3) monte vers une
  terrasse qui porte la **tour-clocher**, visible de toute la cuvette comme sur les vues 1, 2, 4 et 5 ;
- au **pied de cette pente**, un couloir naturel où faire passer la **rivière** (vue 4) d'est en ouest, qui tombe
  du plateau dans le **lac fermé** de la combe sud-ouest par une petite cascade (moulin à eau) ;
- à l'**est**, un versant doux (2 → 10 m) puis une butte à 12 m : **champs, fermes, moulin à vent** (vue 6).

Le bas-village (place, forge, 5 intérieurs) reste sur le plateau plat à 3,6 m ; la **porte SO, le sentier du feu et
toutes les entrées de donjons sont inchangés**. L'enceinte passe de ~1 520 à ~3 300 m² (×2,2).

## 2. Éléments de la planche → emplacement

| Vue planche | Élément | Position (x ; z) | Dimensions / notes |
|---|---|---|---|
| 1 Entrée | Porte SO (inchangée) | (27,7 ; 25,2) | même ouverture qu'aujourd'hui (demi-porte 2,4 m), 2 torches existantes |
| 1 | Sentier pavé feu → porte | (5 ; 4,6) → (27,7 ; 25,2) | tracé INCHANGÉ (`Chemins.axe_village`), dallage du kit `AbordsVillage` |
| 1 | Clôtures de rondins | les 18 derniers m, des deux côtés, à ±2,1 m | barrière du kit, neige sur la lisse |
| 1 | 2 potences à lanterne | (24,2 ; 21,2) et (17,6 ; 15,2) | déjà dans le kit ; lanterne émissive, 1 seule OmniLight |
| 1 | Bannière (rouge, emblème) | (25,3 ; 23,8), mât 4,5 m | nouvelle ; tissu 0,8 × 1,8 m, léger balancement au vent |
| 2 Place | Place pavée | polygone (31;28)…(56;33)…(46;48,5)…(30;38), ≈ 24 × 20 m | pavés irréguliers, neige entre les pierres (C7a) |
| 2 | Puits couvert | (42 ; 38) | margelle Ø 3,4 m, 4 poteaux, toit à 2 pans 3,6 × 3,6 m, treuil |
| 2 | 3 étals à auvents rayés | (51,5;30,5), (54;36,5) tourné 90°, (52,5;42,5) | 3 × 2 m, auvent rouge/crème, tonneaux et caisses |
| 2 | 4 bannières | (38;28,5), (50;28,5) devant la halle ; (36;46), (48;47,5) | mâts 4 m |
| 2 | Brasero de la place | (36 ; 39) | une OmniLight (comme l'actuel brasero) |
| 2 | Bancs, tonneaux, charrette | bords de place, jamais sur l'axe porte → puits → pont | passages ≥ 3 m |
| 3 Rue | Rue pavée place → pont | (44 ; 48,5) → (44 ; 57), 3,6 m | 2 lanternes sur poteau en tête de pont |
| 3 | Volée 1 + terrasse T1 | escalier z 67 → 71 (+2,4 m) ; T1 h 6,0 m, x 39–50, z 71–73 | marches 0,24 × 0,40 m, largeur 3 m ; brasero T1 (40,6 ; 72) |
| 3 | Volée 2 + terrasse T2 | z 73 → 77 (+2,8 m) ; T2 h 8,8 m, x 39–51, z 77–79 | brasero T2 (40,6 ; 78), lanternes |
| 3 | Volée 3 + terrasse T3 | z 79 → 83 (+3,2 m) ; T3 h 12,0 m, x 37–55, z 83–91 | murs de soutènement en pierre sèche de 1 à 3 m |
| 3 | Maisons de la rue | H3 (35,5;72) sur T1, H4 (54;77,5) sur T2, H5 (32,5;84) sur T3 | façades seules, 6 × 5 m, décalées comme la vue 3 |
| 4 Rivière | Rivière du village | voir §4 | 5 m de large au village, bords gelés |
| 4 | Pont de pierre en arche | (44 ; 57 → 66), axe N-S | 9 × 3,2 m, une arche de 6 m, tablier à 1,6 m au-dessus de l'eau, parapets 0,7 m |
| 4 | Quai en bois | x 29–38, z 57,2–59,4 (rive nord) | 9 × 2,2 m sur pieux, 0,5 m au-dessus de l'eau, 1 barque optionnelle |
| 4 | Moulin à eau | maison M (25,5 ; 55,5) 6 × 6 m ; roue (21,5 ; 61) Ø 3,2 m | la roue tourne dans la petite cascade (2,5 m) du bord du plateau |
| 5 Forge | Forge ouverte (intérieur I2) | (27 ; 36), 7 × 6 m, ouverte à l'est sur la rue principale | foyer de pierre + soufflet + enclume (existants), enseigne pendante, auvent |
| — | Longue maison (halle, I1) | (44 ; 21), 14 × 7 m, porte au sud sur la place | domine la place comme la grande maison de la vue 2 |
| — | Tour-clocher | T (45 ; 87,5) sur T3, base 5 × 5 m | fût 15 m + flèche 4 m : sommet ≈ 31 m (rebord de la cuvette 17–21 m) ; cloche, 2 fenêtres éclairées |
| 6 Fermes | Champs enneigés + clôtures | F1 x 77–90 z 29–39,5 ; F2 x 76–86 z 41,5–50 ; F3 x 57–70 z -11 → -3 | sillons sous la neige, ~150 m de clôture |
| 6 | Ferme A + grange A | (83 ; 21,5) 9 × 6 m ; (89,5 ; 23) 5 × 7 m | façades seules ; tas de bois, charrette |
| 6 | Ferme B + grange B | (61 ; 3,5) 8 × 5 m ; (67,5 ; 6) 5 × 6 m | le long du chemin de la grotte |
| 6 | Moulin à vent | MV (94 ; 31), butte à 12 m | tour Ø 5 m, 9 m + toit, ailes Ø 12 m (sommet ≈ 33 m) qui tournent lentement ; 14 m du mur invisible |

## 3. Relief

- **Cuvette** : fond -6..+4 m, rebord 15..31 m ; le joueur est bloqué à |x|, |z| ≤ 108 m (`joueur.gd LIMITE`).
  Tout le plan reste à x ≤ 96 et z ≤ 91, soit ≥ 12 m du mur ; aucune construction sur le rebord.
- **Plateau du bas-village** : h = `h_village` = 3,6 m, inchangé. Il faut remplacer le disque d'aplanissement actuel
  (rayon 25 m plat, fondu 25–38 m autour de (44;40)) par une **forme suivant l'enceinte** (polygone de la palissade du
  bas-village élargi de 4 m, fondu sur 10 m). Zones à remblayer : l'angle nord-est (x 66–74, z 12–30, terrain 0–2 m :
  +2 à +3 m) ; partout ailleurs le terrain est déjà à 3–4 m.
- **Haute rue** : 3 terrasses (6,0 / 8,8 / 12,0 m) taillées dans la pente (le terrain naturel y est à 5,8 / 9,4 / 12,1 m :
  déblais/remblais < 1 m), murs de soutènement en pierre sèche entre elles.
- **Lit de la rivière** : creusé de 0,6 m sous l'eau, berges en pente douce jusqu'au plateau (voir §4).
- La zone témoin (x -58..4, z -64..4) n'est pas touchée ; le plan n'y entre pas.

## 4. Rivière (règle utilisateur : naît dans la carte, finit dans le lac fermé, ne touche aucun bord)

| Point | (x ; z) | Terrain | Eau | Largeur |
|---|---|---|---|---|
| Source : cascade du rocher | (90 ; 57) | 15,2 | lèvre 15,2 → bassin 12,5 | 2,5 m |
| Bassin de la source | (86,5 ; 58) | 14,2 | 12,5 | Ø 4,4 m |
| Descente du versant (gué en (78 ; 59)) | (80;59) → (68;61) | 12,2 → 7,1 | suit le terrain −0,4 m | 3 → 4 m |
| Grille d'eau E (entrée dans l'enceinte) | (65 ; 61,5) | ~5 | 4,0 | 4,5 m |
| Traversée du plateau (pont en x = 44, quai x 29–38) | (60;61,5) → (24;61) | 3,6 (berges) | 3,0 → 2,6 (pente 1 %) | 5 m |
| Petite cascade + roue du moulin | (22 ; 61) → (18 ; 61) | 2,2 → 0,0 | 2,6 → -0,8 | 4 m |
| Grille d'eau O puis LAC | (19,5 ; 61,5) → (12 ; 61) | -5 | -0,8 (niveau du lac) | — |

- Longueur ≈ 77 m, ≈ 330 m² d'eau. Dénivelé 15 m → -0,8 m. Plus proche bord de carte : 18 m (source, x = 90).
- Source : un **rocher-falaise** Blender (≈ 4 × 6 m, 3–4 m de haut) au pied du versant est, la cascade sort d'une
  fissure (préréglage `Cascade.creer(2.7, 2.0)`) → préréglage `ruisseau` jusqu'à la grille E, puis `riviere`
  (variante `BORDS_GELES`, `PLAQUES` près du quai). Le lac reste celui de C5 (`lac`, niveau -0,8 m, centre (-20 ; 44)).
- Franchissable : pont en arche (principal), gué de pierres plates en (78 ; 59) hors enceinte ; profondeur ≤ 0,6 m partout
  (aucune nage). Les 2 grilles de rondins empêchent de sortir de l'enceinte par le lit.
- **Conciliation avec C5** : C5 garde le lac et la **rivière de l'ouest** de `docs/EAU.md` (rebord ouest → lac) ; la
  rivière du village est un **second affluent, à l'est**, posé par C7c avec la même API `Eau`. Le lac reçoit donc deux
  cours d'eau et n'a pas d'exutoire (cuvette fermée). Voir choix n° 1.

## 5. Palissade et portes

- Palissade basse validée (pieux taillés) **prolongée** : polygone (20;34) – porte SO (27,7;25,2) – (36;15) – porte N
  (54;14,3) – (60;14) – (72;24) – porte E (73,5;36) – (74;48) – (66;56) – grille E (65;61,5) – (63;68) – (60;91) – (32;91)
  – (28;68) – (23;67) – grille O (19,5;61,5) – (15;52). **≈ 228 m** (aujourd'hui 138 m), ≈ 3 300 m² enclos.
- Sur la pente sud (z 68 → 91, 4 → 19 m) les pieux suivent le terrain un par un (aujourd'hui ils sont posés à y = 0
  dans le repère du village) : la haute rue et la tour sont dans l'enceinte (choix n° 2).
- 3 portes : SO (inchangée, garde Haldor), N (vers la grotte), E (vers les fermes). Portes N et E : même modèle que la
  porte SO, sans torches (lanterne émissive seulement).

## 6. Chemins vers les donjons (entrées INCHANGÉES)

- **Tertre / crypte** (façade (-38 ; -48)) et **cercle** (-38 ; -34) : porte SO → sentier du feu (inchangé) → feu (0;0)
  → `LIGNE_CERCLE` → `LIGNE_TUMULUS` (chemin témoin, inchangé). Rien à construire.
- **Grotte** (seuil (92 ; -27)) : nouveau chemin de terre porte N (54;14,3) → (53;4) → (53;-8) → (54;-18) → (53;-26,5),
  42 m, pente ≤ 8° (3,5 → 8,5 m), qui rejoint la **piste existante** (`GrotteAcces.axe_piste`, x 50..90). Aujourd'hui
  il n'y a pas de chemin village → grotte : c'est un ajout. À ajouter dans `Chemins` comme troisième polyligne.
- **Fermes** : porte E → (80;35,5) → moulin à vent (91;32), embranchement vers la ferme A ; ferme B sur le chemin N.

## 7. Les 5 intérieurs sans chargement (maisons déplacées, mobilier inchangé)

| Id | Bâtiment (`_maison` / `_forge`) | Ancienne position (repère local) | Nouvelle position monde | Porte |
|---|---|---|---|---|
| I1 | halle (cheffe) 14 × 7 | (0 ; -12) | (44 ; 21), long axe est-ouest | sud, sur la place |
| I2 | forge 7 × 6 | (-12,5 ; 6) | (27 ; 36) | côté est ouvert, rue principale |
| I3 | grima 7 × 5 | (-9,5 ; 13) | (28 ; 47,5), long axe nord-sud | est, sur la place |
| I4 | chasseurs 8 × 5,5 | (11,5 ; 7,5) | (63 ; 29), long axe nord-sud | ouest, rue de la porte E |
| I5 | sigrun 8 × 5,5 | (-11,5 ; -3) | (60 ; 47) | nord |

Tous restent **sur le plateau plat à 3,6 m** : aucun intérieur sur les terrasses (le code des intérieurs suppose le sol
local y = 0 ; choix n° 3). Façades seules (portes closes, pas d'intérieur) : H1–H6, moulin à eau, tour, fermes, granges.

## 8. PNJ, postes, promenade, quêtes

| PNJ | Poste (`lieux`) | Nouvelle position monde |
|---|---|---|
| Gunnhild (cheffe) | `longue_maison` | (44 ; 26), devant la porte de la halle |
| Brodd (forgeron, sédentaire) | `forge` | (25,2 ; 37,6), à genoux devant l'enclume (même repère local que la forge) |
| Ylva (chasseuse) | `enclos` | (66 ; 38,5), devant l'enclos/séchoirs (61–67 ; 37,5–42,5) |
| Sigrún (völva) | `place` | (39,5 ; 42) |
| Haldor (garde) | `porte` | (30,5 ; 28,4), 2,4 m à l'intérieur de la porte SO (comme aujourd'hui) |
| Grima (doyenne) | `puits` | (44,6 ; 39,6) |

- Promenade : les postes ci-dessus + 3 nouveaux points `pont` (44 ; 55), `quai` (34 ; 58), `moulin` (27 ; 59,5) ;
  **aucun point sur les escaliers ni hors enceinte** (choix n° 6).
- Quêtes : déclencheurs `parle:*`, `lieu:tertre`, `lieu:tombe_svanhild`, `ramasse:*`, `tue:*` → aucun ne dépend d'une
  coordonnée du village ; rien à changer dans `quetes.json`. À mettre à jour : `dragon.centre` (centre du village → (46;50)),
  les poses de capture/test qui visent le village (`test_palissade`, `test_interieurs`, `test_marche_pnj`,
  `test_villageois`, `test_pnj_village`, `test_gel_exterieur`, `test_musique`, audit_perf « village → halle »/« feu → forge »).
- Sauvegarde réelle : au chargement, si la position sauvée tombe dans un bâtiment, dans l'eau ou hors sol, replacer au
  point sûr le plus proche (filet de B) — nécessaire car des joueurs ont sauvé dans l'ancien village.

## 9. Performance estimée (cible : 60 i/s, < 8 ms GPU ; règle du lot C : +1 ms max par lot)

| Poste | Estimation | Moyen de tenir |
|---|---|---|
| Bâti neuf (6 façades, tour, 2 moulins, 2 fermes, 2 granges, pont, quai, terrasses) | +60 à +90 k triangles, +5 à +8 appels (les matières existantes sont réutilisées et fusionnées par `_finaliser`) | maillages fusionnés par matière, ailes et roue = 2 nœuds animés seulement |
| Mobilier (étals, bannières, tonneaux, clôtures 150 m) | +10 à +15 k triangles, +3 à +5 appels | MultiMesh, disparition au-delà de 40 m |
| Eau (330 m² + 2 cascades) | +0,3 à +0,8 ms GPU quand elle est à l'écran (reflets d'écran) | une seule `Eau`, résolution 4 cases/m, pas de reflet au-delà de 35 m |
| Lumières | au plus 3 OmniLight visibles (torches de porte, forge, brasero) | lanternes, fenêtres et braseros T1/T2 émissifs seulement, `distance_fade` 20 m |
| **Total vue la plus chargée (place → tour)** | **≈ +1,0 à +1,8 ms GPU**, ~150 → ~250 k primitives | si > +1,5 ms : tour et moulin à vent en imposteur au-delà de 60 m |
| Chargement | `village.gd` coûte déjà 370–550 ms ; ×2 de bâti ≈ +300 ms | précalcul (SOCLE §6) : cuire les maillages du village en fichier, comme les arbres |

Mesure obligatoire après chaque lot (`/tmp/mesure_perf.lock`, poses fixes place / pont / haut des escaliers / porte E).

## 10. Découpage en 3 lots (après validation)

**Ordre** : C7a commence seul par le relief (plateau, terrasses, lit de la rivière en creux « sec ») et le commite
(~1 h) ; C7b et C7c partent ensuite en parallèle sur ce relief.

- **C7a — sols, rues, place, mobilier, relief** (≈ 3 h 30 à 4 h 30) : nouvelle fonction d'aplanissement du village
  (polygone + terrasses + lit), chemin N → grotte et chemins des fermes dans `Chemins` ; pavés irréguliers à joints
  enneigés (rue principale, place, rue du pont, haute rue) sur la base du sol v2 de C1 ; escaliers de pierre (3 volées)
  avec **rampe de collision invisible** sous les marches ; murs de soutènement ; puits couvert, 3 étals, 6 bannières,
  3 braseros, lanternes, bancs, tonneaux, caisses, charrette, clôtures ; champs à sillons ; bannière de l'entrée.
  Tests : `test_chemin_biome`, `test_collisions_biome`, `test_palissade`, audit trous/blocages (`audit_terrain`, `audit_bords`).
- **C7b — bâtiments, palissade, PNJ** (≈ 4 h à 5 h) : déplacer les 5 intérieurs (I1–I5) et leurs portes, postes,
  promenade, `sedentaires` ; 6 façades H1–H6 variées (pas de copies) ; forge ouverte (auvent, enseigne) ; tour-clocher ;
  moulin à vent animé ; 2 fermes + 2 granges ; maison du moulin à eau ; palissade prolongée qui suit le terrain + portes
  N et E + 2 grilles d'eau ; collisions de tout ; replacement sûr au chargement. Tests : `test_interieurs`,
  `test_villageois`, `test_marche_pnj`, `test_pnj_village`, `test_quetes`, `test_sauvegarde`, `test_palissade`.
- **C7c — rivière, pont, quai, moulin à eau** (≈ 3 h à 4 h, en lien avec C5) : rocher de la source + cascade, ruisseau
  puis rivière avec le système `Eau` (bords gelés, plaques), petite cascade du moulin, roue animée, pont de pierre en arche
  (Blender, collision du tablier et des parapets), quai sur pieux, gué ; raccord au lac de C5 (si C5 n'a pas encore posé
  le lac, C7c pose seulement la rivière et s'arrête à la rive, x = 18). Tests : `test_eau` (branche eau), audit trous
  sous l'eau, `test_filet`.

Validation finale (brief C7) : 3 zones avant/après même angle et même lumière (rue en pente avec maisons, place,
entrée SO) + marche/course, planches dans `Desktop\Skyrim captures\refonte\C\C7a|C7b|C7c\`.

## 11. Choix discutables (à trancher par l'utilisateur)

1. **Deux rivières dans le lac** (celle de l'ouest de C5 + celle du village à l'est), ou une seule (abandonner la rivière
   ouest de C5 et garder seulement celle du village) ?
2. **Haute rue et tour dans l'enceinte** (palissade qui grimpe la pente jusqu'à z = 91, 228 m) ou palissade arrêtée à la
   rivière (≈ 180 m, moins chère) avec la tour en guet hors les murs ?
3. **Intérieurs seulement sur le plateau** : les maisons de la rue en pente sont des façades fermées. Rendre une maison
   de terrasse visitable demanderait d'adapter le code des intérieurs (sol local ≠ 0).
4. **Tour-clocher non visitable** (décor, cloche qui sonne au lever du jour ?).
5. **Fermes et moulin à vent hors palissade** (comme la vue 6), sans PNJ pour l'instant (des fermiers plus tard ?).
6. **PNJ qui ne prennent pas les escaliers** (promenade sur le plateau seulement : moins de risques de blocage).
7. **Le centre du village se déplace vers le sud** (de (44;40) à ≈ (46;50)) mais la porte SO, le sentier du feu et
   l'arrivée du joueur ne bougent pas ; la place est presque à l'emplacement de l'ancienne.
8. **Nouveau chemin village → grotte** par une porte N (aujourd'hui on y va à travers bois).
