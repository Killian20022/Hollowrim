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
| `demembrement.gd` (`Demembrement`) | membres tranchés à la mort (bras, avant-bras, jambe, mollet, coupe en deux au bassin ; tête → `Decapitation`) : membre replié (modificateur `MembreTranche`), morceau en corps rigide (pool de 6, 30 s), capuchons de moignon, jets en gros pixels (`Jets`, pool de 6) |
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
**Crypte, 2026-10-27 (« ça rame quand je frappe », Iris Xe)** — mesuré dans la vraie crypte (`outils/repro_crypte_combat.gd`,
alterné avant/après) : 1er coup 120-195 ms dans l'appel → 2-3 ms ; coup léger suivant ~4-10 ms → ~2 ms ; finisher sur draugr
80-195 ms → 10-20 ms ; gel par coup léger ~70 ms → 0-7 ms. Causes et correctifs :
- sons Ogg Vorbis : ~1,9 ms de fil principal par lecture (2 à 4 par coup) → copies `.wav` (QOA), lues avant les `.ogg` ;
- 1re giclée / 1er éclat / 1re décapitation : shaders de particules et textures peintes → `PrechauffeCombat` (caches au
  chargement + vitrine d'effets rendue hors écran dehors et sous terre par `PrechauffeRendu`) ; matériaux partagés (caches
  statiques de `Sang`, `Effets`, `Decapitation.mat_bouchon`, `Sang.pm_jet`) : un matériau neuf par effet faisait recompiler le
  shader dès que le précédent avait disparu ;
- `rendering/limits/global_shader_variables/buffer_size` = 262144 (le décor + les gardiens dépassaient 65536 : « Too many
  instances using shader instance variables » à chaque apparition, plus d'éclair sur les ennemis) ;
- arrêt sur image : option **Arrêt sur image** (`Jeu.option("combat", "arret_image")`) 0 désactivé, **1 bref (défaut)** :
  ralenti ×0,2 au lieu du gel ×0,03, durées ÷2, rien sous 40 ms (coups légers, coups moyens — tous les coups légers sur un
  squelette — parade), ralenti de finisher ×0,6 à ×0,5 ; 2 appuyé = valeurs du tableau. Garde-fous dans `Effets` (demande échue
  ignorée, 1,5 s au plus, `Effets.reinitialiser_temps()` à la mort du joueur).
Test : `bash outils/tous_les_tests.sh test_crypte_combat`.
**Pics d'apparition, 2026-10-27** — `outils/mesure_apparitions.gd` (fenêtre hors écran ; `--lieu=crypte|grotte|fond`, `--sort-direct`,
`--attendre-grotte`) : mage de la crypte 456 ms → ~18 ms (script `mage_nordique_ia.gd` compilé au 1er `load` : 243 ms ; modèle
`MageNordique.creer` : 181 ms) ; troll de la grotte 792 ms → ~20 ms (script 239 ms + `TrollGivre.creer` 500 ms) ; draugrs 6-14 ms
→ 2-4 ms par apparition (copie de la variante) ; entrée de la crypte : plus d'image > 25 ms une fois l'image revenue (une image de
~60 ms sous l'écran noir). Correctifs : `EnnemisNordiques.spec_ia` / `modele_ia` (modèle des ennemis à IA bâti par le fil de
préchauffage, script chargé par `ResourceLoader.load_threaded_request`), `EnnemisNordiques.preparer` (copies des prochains ennemis,
une par image : devant la porte du tertre, puis à 20 m de la distance d'apparition ; grotte idem), un ennemi non préparé apparaît
seul dans son passage, 1er passage des zones de la crypte sous l'écran noir. 1er trait d'ombre du mage : ~10 ms (pas de pic : les
shaders magie_* sont déjà dans la vitrine de `PrechauffeCombat`) ; le pic « au 1er sort » venait de la **pose de la grotte en fond**
(~1 500 nœuds ajoutés d'un coup, 150 ms vers 30 s après le chargement, donc souvent pendant le combat de la crypte) : la grotte entre
vide puis par tranches de 2 ms (`GrotteAcces._poser_enfants`). Reste : la pose de la coque solide de la grotte (un corps Jolt par
image, ~2 s) : images de 30-60 ms mesurées sur un PC chargé par un autre Godot, à revérifier sur PC libre.

## Débogage et validation

- `CombatEnnemi.debug = true` : dégâts flottants (orange = critique), réaction (« INTERROMPU »), jauge de posture, ÉTOURDI / AU SOL,
  « FINISHER: <catégorie> » au-dessus de chaque ennemi.
- Scène : `godot --path . res://scenes/test_degats.tscn -- --nouvelle [--nuit] [--vue=fps] [--captures=res://captures/degats/x] [--gore=0|1|2] [--perf]`.
- Test sans fenêtre : `bash outils/tous_les_tests.sh test_degats` (32 vérifications).

## Troll de givre et mage nordique (branche ennemis/troll_mage)

Socle commun **`scripts/combat/ennemi_base.gd` (`EnnemiBase`)** : les briques de draugr.gd (CombatEnnemi, contrat `recevoir_coup`
4 args, finisher provisoire, `finisher_possible` / `subir_finisher`, `_mourir` : ragdoll, morts variées, décapitation, butin et
signal `mort` dans tous les cas, `_eviter` / `_libre`, ligne de vue, gel) + déplacement (`_bouger` : marche à reculons / de côté
possible), télégraphes au sol (`_disque_sol`, `_bande_sol`) et pics de glace (`_pics_glace`). draugr.gd n'est pas modifié.
Chaque ennemi : sa machine d'états (`_ia`) et des crochets (`_etat_coup`, `_reagir`, `_apres_degats`, `_special_mort`, `_contenu_butin`).
Création dans le monde : `monde.creer_ennemi(preload("res://scripts/troll_givre_ia.gd"), position, lacet, {"ident": …})` —
enregistré dans `draugrs` (mort sauvegardée dans `draugrs_morts`, « tue:<ident> » signalé aux quêtes). Modèles inchangés
(`TrollGivre.creer`, `MageNordique.creer`).

| | Troll de givre (`troll_givre_ia.gd`, profil `troll_givre`) | Mage nordique (`mage_nordique_ia.gd`, profil `mage_nordique`) |
|---|---|---|
| Vie / armure | 420 PV, armure 1 + 3 % | 70 PV, aucune |
| Posture | 110, poids 2 (stagger ÷ 2), jamais renversé, étourdi 3,2 s | 22 (1-2 coups = étourdi), seuil moyen 7 : tout coup interrompt |
| Résistances | feu ×1,75 (coupe la régénération 8 s), glace ×0,25 | feu ×1,25, glace ×0,5, magique ×0,8 |
| Attaques | balayage (armement ~1,2 s, **parable** → titube, −45 % posture) ; écrasement (disque au sol 1,25 s, onde 3 m, **se pare mal** : 60 % traverse) ; charge (bande au sol 0,9 s, 8,5 m/s, 35 % traverse la garde, mur = assommé 1,6 s) | trait de givre (orbe 0,95 s, visée figée 0,25 s avant, 11 m/s, ralentit ×0,55 1,8 s) ; zone (disque 1,4 s, ralentit ×0,5 2,5 s, 50 % traverse) ; téléport à 7-9 m si collé ; coup de bâton faible |
| Autres | rage à mi-vie (une fois : posture pleine, +30 % vitesse, +20 % gestes, recharges ×0,6) ; régénération 6 PV/s après 5 s sans coup | garde 7-13 m : recule face au joueur, pas chassés, rejoint la ligne de vue |
| Mort | chute lourde (ragdoll), tremblement à l'impact, nuage de neige ; décapitation au finisher | éclatement du cristal (explosion de givre, éclair bleu, pics) ; décapitation au finisher |
| Butin | 25-45 pièces, fourrure de troll, crocs, cristal de givre (35 %) | 10-25 pièces, cristal de givre, amulette de givre (30 %) |

Côté joueur : `joueur.recevoir_coup(degats, origine, options := {})` accepte `imparable` (part qui traverse la garde, pas de parade),
`recul`, `ralenti` (Vector2(durée, facteur)), `secousse` ; `joueur.ralentir(duree, facteur)`. Avec la défense de phase 3 (docs/COMBAT.md) : le coup passe par `mains.defendre(degats, origine, sans_parade)` (cône, coût, garde brisée) ; un coup imparable force `sans_parade` (jamais de parade parfaite ni de contre), la part `imparable` traverse ensuite la garde (peut tuer), recul ×0,6 et ralentissement de moitié en garde. `Projectile.tirer_givre(...)` : trait
de givre (sans chute, se brise sur le décor). Scène : `scenes/test_troll_mage.tscn -- --nouvelle --seul=troll|mage [--vie=N]
[--captures=…]` (pilote : pare, esquive, sort des disques, poursuit le mage). Tests : `bash outils/tous_les_tests.sh test_troll_ia`,
`… test_mage_ia`.

## Retour à l'écran du corps à corps (lot L6, branche gameplay/retour_combat)
- **Nom + barre de l'ennemi** (`hud.gd`, `_barre_cible`) : nom centré au-dessus de la barre (or pour un boss), statut dessous
  (« Étourdi » = posture brisée, puis Brûlure / Gel / Choc / Corruption des `Statuts`). La barre s'affiche pour l'ennemi frappé
  ET pour un ennemi en combat sous le réticule (≤ 14 m, rayon contre le décor, tous les 0,12 s). Noms : `nom_affiche`
  (draugr.gd `_nommer` : sbire « Draugr », guerrier « Draugr ancien », profil bandit « Bandit » ; les noms imposés restent).
- **Chiffres de dégâts** (`chiffres_degats.gd`) : option Options > « Chiffres de dégâts », **coupée par défaut**
  (`Jeu.option("combat", "chiffres_degats")`, options.cfg) ; entiers, police pixel x2 (critique x3, or), « Bloqué » (acier),
  couleur d'école pour la magie ; tampon circulaire de 16, dessiné par le HUD, temps réel ; tics canalisés additionnés.
- **Gerbes de gros pixels** (`gerbe_pixels.gd`, shaders `gerbe_pixels*.gdshader`) : carrés de 3 à 8 px **à 480x270** (convertis
  selon le rendu) en palette selon la matière (`CombatEnnemi.matiere_gerbe` : os, draugr, sang, chair pour le troll, bois ; pierre ;
  poussière si gore coupé ; givre, givre_lueur, écailles, braise pour dragon / troll / mage / pièges / traits) ; **éclat d'impact**
  en deux paliers (rampe HDR : os → blanc, sang → rouge vif, carrés ×1,4) puis retombée (amorti + gravité) ; étincelles du métal
  en traits courts opaques jaune-blanc → orange (`rendu: "trait"`) ; magie de givre en additif (`rendu: "lueur"`) ; pool de
  20 émetteurs x 64 particules par scène, AUCUNE allocation par coup ; réutilisable (`GerbePixels.emettre(noeud, point,
  direction, matiere, force)`, nouvelles matières dans `MATIERES`). `Sang.eclats_matiere` passe par elles. Bouclier du joueur :
  étincelles projetées au-dessus de son bord à l'écran (`mains._fx_rebord`). Les anciens cubes `Effets.eclats` sont supprimés
  (2026-10-28) ; planches image par image : `outils/captures_gerbes.gd`.
- **Os qui volent** (`eclats_os.gd`) : coups lourds / critiques / finishers sur squelettes (3-6) et draugrs (1-4), mort d'un
  squelette (4-8) : pool de 14 corps rigides (calque 0, masque 1), 7 s au sol puis désactivés.
- Préchauffe : `PrechauffeCombat` crée les ressources et rend les deux shaders et un éclat dans sa vitrine ; pools créés au
  chargement et à l'apparition d'un ennemi. Mesure : `outils/perf_retour_crypte.gd` ; test : `outils/test_retour_combat.gd` ;
  planches : `outils/captures_retour_combat.gd`.


## Démembrement (étape 1 : draugrs, bandits — 2026-10-29)

`Demembrement.choisir(combat, r, sorte)` à la mort (draugr.gd `_mourir`), coups d'arme blanche tranchante du joueur seulement
(info de mains.gd : « instant » / « charge » ; ni flèches, ni pièges, ni sorts, ni masses) :
- chance : 35 % coup normal, 60 % lourd / recul / chute, 100 % coup puissant ; option « réduit » × 0,5 ; tirages sur
  un générateur propre (le hasard global des salles et du butin n'est pas consommé) ;
- membre : point ≥ 80 % de la taille (ou zone tête, ou horizontal ≥ 68 %) → tête ; < 42 % → jambe (mollet sous 24 %), côté le plus
  proche ; sinon bras / avant-bras le plus proche ;
- coupe en deux : coup puissant SEULEMENT, 1 fois sur 3 (avis utilisateur 2026-10-29), jamais en « réduit » ;
- finishers : inchangés (décapitation ; épée plantée, dos, pommeau, plongé : corps entier) ;
- technique : aucun maillage prédécoupé. Corps : os écrasé (échelle 0,002) par un modificateur placé après le ragdoll ; bassin de la
  coupe en deux écrasé SEUL (enfant `spine_01` compensé : position et échelle ÷ 0,002). Morceau : copie des maillages, peau
  B' = P_racine⁻¹ · P_os · B (pose du moment), autres attaches écrasées sur la coupe ; armes accrochées aux os du morceau partent avec ;
- moignons : capuchon procédural (chair, lèvre sombre, os blanc au centre ; draugr brun-rouge, bandit rouge) ; jet pulsé (battement
  0,42 s) en gros pixels `sang_jet` / `draugr_jet`, gouttes au sol (4 traces max par jet), éclaboussures sol + mur (`Sang._traces_giclee`) ;
- plafonds : 6 morceaux, 6 jets, 48 traces (`Sang.MAX_TRACES`, disparition lente : la trace se résorbe en 6 s) ;
- réglages de test : `Demembrement.chance_forcee`, `membre_force`, `duree` ; `outils/test_demembrement.gd`, planches et film :
  `outils/captures_demembrement.gd`.
Gerbes allégées tout près de la caméra (`Demembrement.attenuation_camera` : × 0,4 à moins de 1,8 m) à la coupe et à la mort.
Plaies (entailles) : décal plus fin (taille × 0,5 en hauteur, 26 cm de profondeur au lieu de 50), lèvres en couleur de palette
(`Plaies.couleur_levres`), texture « entaille » redessinée (fente noire, lèvres d'un texel, coulures).
