# Dégâts, réactions, sang et finishers (côté ennemi) — branche combat/degats_gore

Combat gore assumé (dark fantasy adulte) : giclées directionnelles, plaies qui restent sur les corps, décapitations, flaques et
traînées, voile rouge bref, morts variées. Option **Sang / gore** dans les options : Complet (défaut), Réduit, Désactivé
(`Jeu.option("combat", "gore")` : 2 / 1 / 0).

Le côté JOUEUR (pose FPS, attaques, tracé de lame, animation des finishers) est fait sur la branche combat/epee_fps ; ici tout ce
qui se passe dans l'ennemi et à l'écran quand il est touché.

## Fichiers (scripts/combat/)

| Fichier | Rôle |
|---|---|
| `profil_cible.gd` (Resource `ProfilCible`) | armure, résistances, zones, posture, seuils de réaction, sang, décapitable — par cible : `draugr`, `draugr_guerrier`, `squelette`, `bandit`, `mannequin` (surcharge possible : `data/combat/cible_<nom>.tres`) |
| `profil_impact.gd` (Resource `ProfilImpact`) | sensation : arrêt sur image, secousse, voile rouge, ralenti, sang, volume — `leger`, `moyen`, `lourd`, `critique`, `finisher` (surcharge : `data/combat/impact_<nom>.tres`) |
| `calcul_degats.gd` (`CalculDegats`) | calcul pur : complète l'info d'un coup, applique type / zone / armure / blocage / critique / posture |
| `combat_ennemi.gd` (`CombatEnnemi`) | composant branché dans l'ennemi : posture, choix de la réaction, fenêtre de finisher, effets d'impact et de mort, débogage |
| `sang.gd` (`Sang`) | giclées (particules pixel), jets pulsés, flaques et traînées (plans texturés au sol / au mur, plafonnés), textures peintes par code |
| `plaies.gd` (`Plaies`) | plaies persistantes : Decal accroché à l'os le plus proche (suit animation et ragdoll) |
| `decapitation.gd` (`Decapitation`) | tête détachée en corps rigide (copie des maillages, peau refaite), cou replié (modificateur `CouTranche`), bouchons, jet |
| `reaction_os.gd` (`ReactionOs`) | flexion procédurale du buste et de la tête dans le sens du coup (ressort), balancement quand étourdi |
| `retour_impact.gd` (`RetourImpact`) | arrêt sur image, secousse, voile rouge (`eclat_rouge` de `ps1_post.gdshader`), sons par matière (pack CC0) |
| `mannequin.gd` (`Mannequin`) | mannequin d'entraînement (ne meurt pas, compte les dégâts, posture, finisher : la tête s'envole et repousse) |
| `scene_test_degats.gd` + `scenes/test_degats.tscn` | scène de validation avec pilote automatique, captures, mesure de perf |
| `joueur_test.gd` | joueur factice de la scène de test |

Modifiés : `draugr.gd` (branchement, états `ETOURDI` et `CHUTE`, morts variées, API finisher), `dragon.gd` (4e paramètre accepté),
`effets.gd` (arrêts sur image cumulables + `Effets.ralenti`), `ps1_post.gdshader` (`eclat_rouge`), `jeu.gd` + `menu_options.gd`
(option), `project.godot` (`rendering/textures/decals/filter = plus proche`).

## Contrat avec l'épée (branche combat/epee_fps)

```gdscript
ennemi.recevoir_coup(degats: float, origine: Vector3, puissant := false, info: Dictionary = {}) -> String   # "touche" / "tue" / "bloque"
```
`info` (tout est facultatif) : `type` ("tranchant", "contondant", "feu", "glace", "magique"), `point` (Vector3 monde), `direction`
(Vector3 normalisé du mouvement de lame), `normale`, `zone` ("tete" / "torse" / "bras" / "jambes" / ""), `attaque` ("legere",
"lourde", "chargee_max", "contre"), `arme` (id), `stagger` (float), `collider`.

Sans info (mains.gd actuel, pièges, tests) : `type` tranchant, `attaque` lourde si `puissant` sinon légère, `point` = là où passe le
regard du joueur à la distance de la cible (12 cm sous le réticule), à défaut le torse ; `direction` = taille de biais alternée qui
pousse vers l'arrière de la cible ; `zone` déduite de la hauteur du point (taille réelle de l'ennemi : os de la tête + 12 cm).

## Calcul (CalculDegats.calculer)

1. **Blocage** (draugr guerrier, squelettes, jarl ; de face, en poursuite) : chance = `chance_blocage × (0,4 + 0,6 × posture restante)`,
   × 0,35 pour un coup lourd. Bloqué : la posture s'use (55 % du stagger, 90 % au lourd) ; si elle tombe à 0 la garde **cède** (le coup passe, posture brisée).
2. **Dégâts** = base × mult. d'attaque (légère/lourde 1, chargée max 1,25, contre 1,3) × résistance du type × zone
   (tête 1,6 ; torse 1 ; bras 0,75 ; jambes 0,85 ; squelette tête 1,8) − armure plate (tranchant ; `armure_tete` à la tête)
   × (1 − `armure_part`) ; os + coup lourd × 1,3 ; **critique** × 1,5 (cible étourdie, au sol, ou tête au coup lourd). Minimum 1.
3. **Stagger** = `info.stagger` (défaut : légère 12, lourde 28, chargée max 42, contre 34) / poids ; × 0,6 boss ; tête × 1,25 ; jambes × 1,25.
4. **Profil d'impact** : légère → léger (moyen à la tête), lourde/contre → lourd, chargée max → critique ; un critique monte d'un cran.

| Profil | arrêt (s) | secousse | voile rouge | ralenti | sang |
|---|---|---|---|---|---|
| leger | 0,05 | 0,22 | — | — | ×1 |
| moyen | 0,07 | 0,32 | — | — | ×1,4 |
| lourd | 0,11 | 0,50 | — | — | ×2,2 |
| critique | 0,14 | 0,62 | 0,16 | — | ×3 |
| finisher | 0,20 | 0,85 | 0,32 | 0,45 s à ×0,3 | ×4,5 |

## Posture et réactions

Posture (`posture_max` : draugr 40, guerrier 50, squelette 36, bandit 42, mannequin 60 ; boss × 2,2) réduite du stagger de chaque
coup, remonte de `posture_regen`/s après `posture_delai` s sans coup. Parade réussie du joueur : − 45 % de la posture, fenêtre
`apres_parade` de 1,4 s.

| Réaction | Condition | Effet (draugr.gd) |
|---|---|---|
| leger | stagger < `seuil_moyen` (11) | flexion procédurale ; titube 0,32 s seulement s'il n'attaque pas (sinon il continue : hyper-armure des coups légers) |
| moyen | ≥ `seuil_moyen` | titube 0,55 s, recul 1,8 m/s |
| lourd | ≥ `seuil_lourd` (24) | titube 0,7 s, recul 3,5 m/s |
| recul | lourd + chargée max | titube 0,85 s, recul 6 m/s |
| chute | ≥ `seuil_chute` (30), coup lourd aux jambes | renversé (Death01 accélérée), au sol ~1,3 s, se relève |
| etourdi | posture tombée à 0 | ÉTOURDI `duree_etourdi` (2,6 s ; boss × 0,6) : ne frappe plus, se balance ; carillon « coup de grâce » + éclat doré |
| interruption | attaque pas encore portée et réaction ≥ moyen (ou posture < 50 %) | le geste est annulé (titube) |

Les chefs en plein pouvoir (appel, souffle) ne titubent pas ; les chefs ignorent 60 % des coups légers.

## Finishers — API

```gdscript
ennemi.finisher_possible(joueur: Node3D) -> String        # "" ou catégorie
ennemi.subir_finisher(categorie: String, info := {}) -> String   # joue la mort spéciale, renvoie "tue"
```
Catégories (à ≤ 2,6 m, ±1,5 m en hauteur) : `etourdi` (posture brisée), `sol` (renversé), `apres_parade`, `rapide` (vie ≤ 18 %
— bandit 22 % — et posture < 60 %), `lateral` (étourdi ou rapide, pris de côté entre 65° et 140°). `subir_finisher` accepte aussi
`puissant` (arme lourde, à brancher).

Morts spéciales : toutes les catégories de taille → **décapitation** (draugr, squelette, bandit, si `decapitable` et gore ≠ 0 :
tête/casque en corps rigide, cou replié, bouchon de chair, jet pulsé ~2,6 s qui goutte, giclée, son de décapitation) ;
`sol` → coup de grâce (le corps est cloué au sol, flaque). Gore désactivé : même finisher, sans décapitation ni sang.

**Branché (integration/H)** : le déclenchement provisoire de `draugr.recevoir_coup` (et du mannequin) est RETIRÉ. C'est l'épée
du joueur qui appelle `finisher_possible` à chaque clic puis, après une courte séquence FPS (élan, verrou caméra, coup ≤ 0,8 s),
`subir_finisher(categorie, info)` au moment de l'impact (mains._tenter_finisher, docs/COMBAT.md « Finishers lancés par le
joueur »). Les tests (test_degats, scene_test_degats) jouent le rôle du joueur de la même façon.

## Morts variées (CombatEnnemi.type_mort)

`legere` (s'effondre), `titubante` (encaisse 0,38 s puis tombe), `lourde`, `recul` (projeté), `chute` (fauché aux jambes : impulsion
sur un mollet), `puissant` (chargée max ou critique lourd : projeté loin, double giclée, voile rouge), `finisher`. Toutes : giclée,
plaie, cri (râle de draugr, voix humaine pour les bandits, os pour les squelettes), son de chute de corps (pierre sous terre, neige
dehors), flaque qui s'étale sous le bassin, **signal `mort` (sauvegarde des morts) et butin dans tous les cas**.

## Sang, plaies, plafonds

- Giclée : particules pixel (cubes étirés dans le sens de la vitesse) + brume ; traces au sol le long du geste (rayons), au mur
  (sang complet, gros coups). Couleur par profil : draugr rouge sombre épais, bandit rouge franc ; squelette/mannequin : éclats d'os / copeaux.
- Traces au sol/mur : plans texturés (texels nets, découpe alpha, aspect mouillé) gérés par `GestionSang` : **48 au plus**
  (`Sang.MAX_TRACES`, les plus anciennes disparaissent), effacées après 150 s. (Pas de Decal pour le sol : le rendu Mobile limite
  les décals par maillage et le terrain est un seul maillage.)
- Plaies : Decal sur le calque de rendu 20 (seuls les maillages de l'ennemi le reçoivent), **6 par corps** (limite Mobile : 8
  décals par maillage) ; entaille (chair), fissure (os), copeau (bois). Elles restent sur le cadavre.
- Têtes coupées : 6 au plus, effacées après 30 s (comme les cadavres).
- Réduit : 35 % des particules, pas de traces au mur, flaques et plaies plus petites, jets courts. Désactivé : ni sang, ni plaie, ni décapitation, ni voile rouge.

## Sons (assets/sons/combat/, pack CC0, crédits dans assets/LICENCES.md)

`RetourImpact.son(noeud, categorie, point, volume, hauteur)` : variante au hasard sans répéter la dernière, hauteur ± 6 %, gain par
fichier mesuré (volume moyen ramené vers −19 dB). Catégories : chair, chair_gore, dechirure, os, armure, bois, pierre, jet_sang,
decapitation, chute_pierre, chute_neige, draugr_douleur, draugr_mort, douleur, coup_de_grace. Non écoutés à l'oreille : à régler.

## Performance (mesurée, fenêtre hors écran, --disable-vsync, `--perf` de la scène de test)

Pire cas : 5 draugrs autour du joueur, coups lourds + légers sur tous puis 5 finishers (5 décapitations, 5 jets pulsés) dans la
même image. Temps d'image moyen : 3,1 ms → 3,9 ms (froid) / 4,0 → 5,4 ms (préchauffé), plafond des traces atteint (48).
Pic unique dans l'image des 5 finishers simultanés : 79 ms à froid (première compilation des matériaux d'effets), 49 ms préchauffé
(5 × copie de tête + ragdoll + sons) — pendant l'arrêt sur image du finisher (0,2 s), donc peu visible ; un finisher réel est
unique (≈ 10 ms). Correctifs déjà faits : sons de combat préchargés en tâche de fond, au plus 6 sons de combat par image.
À faire si besoin : préchauffer les matériaux d'effets dans `prechauffe_rendu.gd` (supprime le surcoût « à froid »).

## Débogage et validation

- `CombatEnnemi.debug = true` : dégâts flottants (orange = critique), réaction (« INTERROMPU »), jauge de posture, ÉTOURDI / AU SOL,
  « FINISHER: <catégorie> » au-dessus de chaque ennemi.
- Scène : `godot --path . res://scenes/test_degats.tscn -- --nouvelle [--nuit] [--vue=fps] [--captures=res://captures/degats/x] [--gore=0|1|2] [--perf]`.
- Test sans fenêtre : `bash outils/tous_les_tests.sh test_degats` (32 vérifications).
