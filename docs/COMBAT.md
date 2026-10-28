# Combat à l'épée (vue FPS) — règles, valeurs, architecture

Référence visuelle : `references/combat_epee/planche_combat_epee_1100.jpg` ; cahier des charges : `references/combat_epee/prompt_utilisateur.md`.
État : phase 1 (pose FPS + animations passives), phase 2 minimale (léger / lourd / tracé de lame / réactions existantes),
phase 4 (directions, enchaînements) ; passe 4 : coups conçus en espace écran + traînée de lame (voir plus bas) ;
**phase 3 (branche integration/H)** : branchement sur le système de dégâts/gore (docs/DEGATS.md), garde orientée, garde
brisée, parade parfaite, contre-attaque, finishers lancés par le joueur (section « Défense, contre-attaque, finishers »).
Les phases 5 et 6 (variantes, polish) s'appuient sur la même architecture.

## Lancer

| Quoi | Commande (depuis le worktree, `G` = Godot console, `W` = chemin Windows) |
|---|---|
| Scène de test (jouable) | `$G --path "$W" res://scenes/test_combat.tscn -- [--nuit] [--draugr=actif\|fige\|aucun] [--debug-combat]` |
| Test automatique | `bash outils/tous_les_tests.sh test_combat_epee` (≈ 6 s, sans fenêtre) |
| Test de la défense | `bash outils/tous_les_tests.sh test_defense` (garde, garde brisée, anti-spam, parade sur vraie attaque de draugr, contre, finisher) |
| Planches défense | `... --script res://outils/captures_defense.gd -- --sortie="$W\captures\combat_defense" [--poses]` |
| Film défense | idem avec `--write-movie "$W\captures\combat_defense\video\defense_parade_contre_finisher.avi" --fixed-fps 30` et `-- --film` |
| Planches | `bash /tmp/godot_slot.sh $G --path "$W" --script res://outils/captures_combat_epee.gd -- --sortie="$W\captures\combat_epee\scene"` |
| Film | idem avec `--write-movie "$W\captures\combat_epee\video\combat_epee.avi" --fixed-fps 30` avant `--script`, et `-- --film` |
| Mesures des coups (planches) | `-- --mesures [--gestes=diag_gd,horizontale,estoc] [--arme=epee_rubis] [--nuit] --sortie=...\coups_ecran` (lignes MESURE / RESUME) |
| Films des coups | `--write-movie ...\coups_ecran_reel.avi --fixed-fps 60 ... -- --film-coups [--ralenti=0.25]` |
| Régénérer les clips du bras | `blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/anim_bras_epee.py -- --godot --blend` (depuis le worktree, ≈ 40 s ; TOUJOURS sans `--clips` avant tests / captures) |
| Planches / films des coups animés | `... --script res://outils/captures_coups_animes.gd -- --seq=combo\|puissante[_avant\|_droite\|_arriere]\|garde\|contre\|horizontale\|revers\|estoc`, `--repos`, `--film [--ralenti=0.25]` (avec `--write-movie ... --fixed-fps 60`) |
| Tenue tranche / traînée (mesures + planches) | `... --script res://outils/mesures_tranche.gd -- [--images] [--seq=repos,marche,sprint,garde,combo,horizontale,revers,estoc,puissante,puissante_avant,puissante_droite,armes] --sortie=...\captures\tranche_trainee` (lignes MESURE / RESUME : plat/œil, vert, poings, fil, écart traînée) |
| Pose de repos dans le village | `--captures="$W\outils\poses_combat_epee.txt"` (voir SOCLE_TECHNIQUE §6.1) |

En jeu : clic gauche court = coup léger, maintenu = charge puis coup lourd au relâchement ; clic droit = garde ;
T = torche ; **F3 = débogage** (tracé de lame, état de combat, endurance, charge, rayons).

## Architecture (`scripts/combat/`)

| Fichier | Rôle |
|---|---|
| `donnees_arme.gd` (`DonneesArme`, « WeaponData ») | Resource : modèle (.glb) + habillage + point de prise, pose de repos (poignée, lame, tranchant, pôle du coude), dégâts, vitesse, poids, coûts, réduction en garde, tracé de lame (garde → pointe + allonge), profil d'animation. Une `.tres` par objet dans `data/armes/`. |
| `equipement.gd` (`Equipement`) | Main droite / main gauche séparées ; deux mains = main gauche libérée ; T sort / range l'objet gauche ; l'épée de Skarnholt remplace l'épée de métal quand elle est dans l'inventaire. |
| `entrees_combat.gd` (`EntreesCombat`) | Entrées horodatées, durée d'appui, mémoire d'entrée (input buffer, 0,35 s), garde (bouton ou imposée). |
| `etat_combat.gd` (`EtatCombat`) | Machine à états : Idle, Moving, LightAttack, HeavyCharge, HeavyAttack, Blocking, Parrying, Staggered, Recovery, Equip, **Counter, Finisher** (phase 3 : table `TRANSITIONS_PHASE3` à part) ; table des transitions autorisées. |
| `defense_joueur.gd` (`DefenseJoueur`) | Phase 3 : cône de garde, coût et réduction selon l'arme, garde brisée, fenêtre de parade parfaite (anti-spam), fenêtre de contre-attaque. Logique pure, tous les réglages en constantes. |
| `gestes_defense.gd` (`GestesDefense`) | Phase 3 : gestes « contre », « finisher_taille », « finisher_sol » (clés écran) et poses garde / encaisse / parade / garde brisée, À PART des profils d'attaque ; durées du finisher. |
| `profils_animation.gd` (`ProfilsAnimation`) | Gestes d'attaque (préparation, phase active à trois poses, récupération, fenêtre de dégâts), poses de charge / garde / sprint. Mêmes fonctions pour l'image et pour le tracé. |
| `trace_lame.gd` (`TraceLame`) | Détection par tracé de lame à pas fixe (rayons radiaux depuis l'œil + rayons latéraux). |
| `trainee_lame.gd` (`TraineeLame`) | Traînée de lame pixel (ruban garde → pointe, 0,1 s, `shaders/trainee_lame.gdshader`). |
| `degats_combat.gd` (`DegatsCombat`) | Calcul des dégâts, appel de `recevoir_coup` (avec `info` si la cible l'accepte), zone touchée. |
| `retour_coups.gd` (`RetourCoups`) | Étincelles et son sur les murs, signal discret de pleine charge ; coups qui portent sur une cible SANS CombatEnnemi (dragon…) → profils d'impact (`RetourImpact.jouer`). |
| `mouvements_passifs.gd` (`MouvementsPassifs`) | Respiration, marche, sprint, saut / atterrissage, inertie de la caméra, arrêt brutal (ressorts à pas fixe). |
| `camera_corps.gd` (`CameraCorps`) | Caméra FPS : balancement de tête aux pas, saut / atterrissage, accompagnement des attaques, impact, coup reçu, secousse ; options Balancement / Tête / Secousses. |
| `debogage_combat.gd` | Dessin du tracé et texte d'état (F3). |
| `mannequin.gd` (`Mannequin`) | UN mannequin pour les deux scènes de test (test_combat, test_degats) : CombatEnnemi (posture, réaction, finisher : la tête s'envole et repousse), chiffres de dégâts, journal `coups`, signal `touche`, groupe `cibles_combat`. |

`scripts/mains.gd` orchestre (entrées → machine à états → poses → IK des bras → tracé). Son interface d'avant reste :
`etat` (ancien enum, lu par `corps_joueur.gd`), `bloque`, `temps_garde`, `torche_sortie`, `_puissant`, `attaquer()`,
`encaisser()`, `pivot_epee`, `pivot_torche`, `porte_torche`. `_materiaux_equipement` / `_habiller` sont inchangés.

**Ajouter une arme** : copier `data/armes/epee_metal.tres`, changer `modele`, `habillage`, les stats ; l'équiper par
`mains.equipement.equiper("droite", load(...))`. Les repères `garde` / `pointe` du .glb sont lus automatiquement.

## Machine à états

```
Idle/Moving --clic--> LightAttack(préparation) --relâché--> LightAttack(phase active) --> Recovery --> Idle
                         \--tenu ≥ 0,28 s--> HeavyCharge --relâché--> HeavyAttack --> Recovery
Recovery --clic mémorisé (après 0,06 s)--> LightAttack (geste suivant du combo)
Idle/Moving/Recovery(> 0,12 s) --clic droit--> Parrying (0,3 s) --> Blocking --relâché--> Idle
LightAttack(préparation, lame pas encore active) --clic droit--> Parrying (annulation, 1 image ; mains.annulations)
LightAttack/HeavyAttack --lame arrêtée (mur, bouclier, cassable qui tient)--> Staggered (0,30 s) --> Idle
Idle/Moving --changement d'arme--> Equip (0,45 s) --> Idle
Blocking/Parrying --coup bloqué sans assez d'endurance--> Staggered (garde brisée, 0,45 s) --> Idle (garde impossible 1 s)
Blocking/Parrying/Idle/Moving/Recovery --clic dans la fenêtre de contre (0,6 s après une parade parfaite)--> Counter --> Recovery
Idle/Moving/Recovery/Blocking/Parrying --clic, cible achevable devant--> Finisher (élan + coup) --> Recovery
```
Pas d'attaque normale en garde (l'appui mémorisé est effacé, sauf contre-attaque ou finisher) ; toute attaque passe par
Recovery (pas d'attaque infinie).

## Valeurs (épée en métal, vitesse 1)

| Geste | Préparation | Tenue | Frappe | Suivi | Récupération (suivi compris) | Dégâts |
|---|---|---|---|---|---|---|
| Léger 1 : diagonale haut-droite → bas-gauche | 0,10 s | 0,04 | 0,09 (ease-in ×2,6) | 0,07 | 0,30 | ×1 |
| Léger 2 : horizontal gauche → droite | 0,11 s | 0,04 | 0,09 (×2,2) | 0,07 | 0,30 | ×1 |
| Léger 3 : vertical haut → bas | 0,12 s | 0,05 | 0,10 (×3,0) | 0,08 | 0,34 | ×1,25 + tassement caméra |
| Lourd : grand arc (après la charge) | 0,06 s | — | 0,14 (×2,8) | 0,10 | 0,46 | ×1 (+charge) + tassement |

La lame blesse sur toute la frappe (fenêtre 0 → 100 %, estoc 25 → 100 %).
Durées divisées par `vitesse` de l'arme. Combo : 1 → 2 → 3 → 1 ; il repart de 1 après 0,9 s sans coup.
Charge : seuil 0,28 s d'appui, plafond atteint 0,9 s plus tard ; dégâts lourds × (1 → 1,3) selon la charge ;
à pleine charge : tintement discret, reflet sur la lame, léger tremblement.

| Arme (`data/armes/`) | Léger | Lourd (plafond ×1,3) | Vitesse | Poids | Endurance léger / lourd | Réduction en garde |
|---|---|---|---|---|---|---|
| epee_metal (défaut) | 14 | 34 (44,2) | 1,0 | 1,6 | 8 / 26 | 85 % |
| epee_or | 16,8 | 40,8 | 1,15 | 1,2 | 7 / 22 | 80 % |
| epee_rubis | 25,2 | 61,2 | 1,0 | 1,6 | 8 / 26 | 85 % |
| epee_verre | 22,4 | 54,4 | 1,3 | 1,1 | 6 / 20 | 75 % |
| epee_obsidienne | 30,8 | 74,8 | 0,8 | 2,6 | 11 / 34 | 90 % |
| epee_skarnholt (quête) | 18,9 | 45,9 | 1,0 | 1,6 | 8 / 26 | 85 % |

Dégâts des épées longues = dégâts de la planche × 1,4 (léger) et × 3,4 (lourd) : le métal garde les 14 / 34 du jeu.
Les quatre variantes sont **provisoires** (phase 5 : équilibrage). Skarnholt = ancien bonus ×1,35 intégré à ses stats ;
la hache de Kolbeinn reste un trophée ×1,25 (sans cumul avec Skarnholt), comme avant.
Multiplicateurs communs : compétence Épée (+0,6 × progression), trophée.

### Endurance
- Coûts payés au **lancement de la phase active** (pas à l'appui) ; sprint 12 /s, saut 6 (joueur.gd).
- Régénération 22 /s, après 1 s sans dépense (0,6 s après un sprint).
- **Endurance insuffisante = coup AFFAIBLI** (choix documenté) : le coup part toujours (le joueur n'est jamais privé de
  réponse), mais dégâts × 0,5, gestes ralentis (× 1/0,75), jamais « puissant » (pas de titubement forcé), stagger × 0,5.
  Même règle pour le lourd. L'endurance tombe à 0 (jamais négative).
- Garde : coût par coup bloqué = dégâts × 1,1 × (réduction de la compétence Parade) × `cout_garde` ; parade : × 0,3.
- **Endurance insuffisante en garde = GARDE BRISÉE** (choix documenté, phase 3) : voir ci-dessous.
- Finisher : coût d'un coup léger ; contre-attaque : coût d'un coup léger (payé au lancement de la frappe).

## Défense, contre-attaque, finishers (phase 3)
Valeurs dans `scripts/combat/defense_joueur.gd` (garde, parade, contre) et `gestes_defense.gd` (gestes, finisher).

### Garde orientée
- Clic droit tenu. La garde couvre un **cône de 120°** devant le joueur (`ANGLE_DEFENSE`) : un coup venu de plus de 60°
  du regard (côté, dos) passe entièrement (test : 45° bloqué, 75° et dos touchés).
- Coup bloqué : `1 − reduction_garde` des dégâts passent (métal 85 % → 15 % ; or 80 %, verre 75 %, obsidienne 90 %) ×
  réduction de la compétence Parade ; coût d'endurance dégâts × 1,1 × compétence × `cout_garde`. Un coup bloqué ne tue
  pas (la vie reste ≥ 1). Son `metal_blocage` (pack CC0), étincelles, pose « encaisse » 0,18 s, secousse 0,35.
- Pas d'attaque normale en garde ; vitesse de marche × 0,5, pas de sprint.
- **Garde brisée** : si l'endurance ne suffit pas à payer le coup bloqué, la garde cède : 50 % des dégâts passent
  (`PART_BRISEE`, joués comme un coup reçu : recul, Hit_Chest en 3e personne), l'endurance tombe à 0, le joueur titube
  0,45 s (état Staggered, épée rabattue en bas à droite), **garde impossible 1 s** (`GARDE_IMPOSSIBLE`) même bouton tenu.

### Parade parfaite
- Coup reçu dans les **0,18 s** qui suivent la levée de la garde (`FENETRE_PARADE`) → aucun dégât, coût × 0,3.
- **Anti-spam** : chaque levée moins de 0,9 s après la précédente réduit la fenêtre de 0,045 s (0,18 → 0,135 → 0,09 →
  0,045, plancher 0,04) ; une levée après 0,9 s de calme retrouve la fenêtre entière.
- Retour : tintement clair `parade_parfaite` (distinct du blocage), gerbe d'étincelles, coup de poignet de la lame vers
  l'extérieur (pose « parade » 0,14 s), arrêt sur image 0,06 s.
- L'attaquant reçoit « parade » : le draugr appelle `combat.subir_parade()` (posture − 45 %, fenêtre `apres_parade`
  1,4 s, étourdi si la posture tombe à 0) et titube 0,7 s : il est **ouvert**.

### Garde au bouclier (main gauche, 2026-10-27, branche gameplay/bouclier)
- Objet de la main gauche défini par DONNÉES : `data/armes/bouclier.tres` (catégorie BOUCLIER, modèle
  `assets/modeles/armes/bouclier_nordique.glb`, source `sources_blender/scripts/bouclier_nordique.py`, habillé par
  `scripts/objets/bouclier_nordique.gd` : planches peintes en tourbillon rouge / ocre usé, cerclage et umbo de fer, 548
  triangles, face 128 x 128). Champs de garde de DonneesArme (groupe « Garde ») : `angle_garde` (épée 120°, bouclier
  170°), `recul_garde` (bouclier 2,2 m/s), `posture_parade` (épée 0,45, bouclier 0,8), `son_garde` (« bois »).
- Gestes à part des clips du bras droit : `scripts/combat/gestes_bouclier.gd` (repos = pose de la .tres, garde, impact,
  coup, brisee, attaque = contrepoids des coups, sprint), posés par IK sur la main gauche (`mains._poser_bouclier`).
- Clic droit tenu : le bouclier se lève devant, à gauche du centre, bord haut sous la ligne des yeux ; l'épée reste au
  repos (pas de clip « garde »). Bloc : 95 % absorbés, endurance × 0,6, recul du joueur, sons bois + fer de l'umbo,
  geste d'impact. Parade parfaite (même fenêtre) : **coup de bouclier** poussé en avant ; l'attaquant perd 80 % de sa
  posture (`CombatEnnemi.part_parade`, posée par `mains.defendre` juste avant son `subir_parade`). Garde brisée : même
  titubement et même garde impossible qu'à l'épée, mais c'est le bouclier qui est rabattu.
- Garde baissée : l'épée attaque et enchaîne son combo normalement (mêmes durées, même départ dans l'image de l'appui).
- Changement d'objet de la main gauche (torche ↔ sort ↔ bouclier ↔ vide) : cible de la main et pôle du coude passent de
  la pose affichée à la nouvelle en 0,35 s sur une courbe en S (`mains._lisser_gauche`) ; l'IK droite des sorts entre et
  sort en fondu 0,3 s (`MainSort._infl_d`). Plus grand déplacement d'une main en une image (test_bouclier) : avant
  0,13-0,27 m, après ≤ 0,03 m à gauche, 0,08 m à droite (dont le geste « dégainer » existant).
- Vérification : `outils/test_bouclier.gd` (37 vérifications), planches `outils/captures_bouclier.gd`.

### Contre-attaque
- Fenêtre de **0,6 s** après une parade parfaite (`FENETRE_CONTRE`) : un clic (depuis la garde, ou garde relâchée) lance
  le geste « contre » (diagonale haut-gauche → bas-droite, plus ample, préparation courte 0,06 s, frappe 0,09 s, tassement
  de caméra) au lieu d'un coup léger. Fouetté lourd.
- `attaque = "contre"` : dégâts de base légers × `force` 1,4 du geste, puis × 1,3 (CalculDegats) ; stagger de contre
  34 (× déséquilibre de l'arme) ; profil d'impact lourd. **Pas de critique automatique** : critique seulement selon les
  règles (tête au coup non léger, cible étourdie ou au sol).
- La contre-attaque dépense l'ouverture `apres_parade` de la cible touchée : le finisher ne suit que si **la posture
  casse** (cible étourdie) ou selon les autres catégories (vie basse, au sol). Test : la contre brise la posture d'un
  draugr guerrier paré → finisher « etourdi » au clic suivant.

### Finishers lancés par le joueur
- À chaque clic (léger ou lourd), `mains._chercher_finisher()` cherche une cible (groupes `ennemis` et `cibles_combat`)
  dont `finisher_possible(joueur)` renvoie une catégorie (portée 2,6 m, hauteur, état : CombatEnnemi), **devant la
  caméra** (cône ± 50°), le joueur **de face ou de côté** par rapport à elle (pas dans son dos, > 140°), sans mur entre
  les deux. Sinon, coup normal.
- Séquence FPS courte (`GestesDefense.FINISHER`, total 0,72 s ≤ 0,8 s) : élan 0,26 s vers la pose armée (ralenti léger
  × 0,7), **verrou bref de la caméra** sur le cou (lacet du joueur + tangage de la tête, ressort 14 /s) pendant l'élan et
  le coup, coup 0,12 s (traînée de lame, tassement) ; à mi-coup `subir_finisher(catégorie, info)` (info : point = cou,
  direction de la lame, zone tête, attaque « finisher », arme, origine, `puissant` si arme ≥ 2,4 kg) ; suivi 0,34 s en
  récupération. La cible joue sa mort spéciale (décapitation : tête en corps rigide, jet de sang ; coup de grâce au sol)
  et le profil d'impact « finisher » (arrêt 0,2 s, secousse, voile rouge, ralenti 0,45 s).
- Gestes : `finisher_taille` (coupe horizontale de droite à gauche à travers le centre de l'écran, là où le verrou met
  le cou) pour toutes les catégories de taille ; `finisher_sol` (abattu vertical) pour « sol ». Le finisher PROVISOIRE
  de `draugr.recevoir_coup` (et du mannequin) est retiré : seul le joueur déclenche un finisher.

### Retours d'impact : une seule source
Arrêt sur image, secousse et voile rouge d'un coup qui porte viennent des profils d'impact de degats_gore
(`ProfilImpact` : léger, moyen, lourd, critique, finisher), joués par la cible (CombatEnnemi) selon le profil calculé.
`RetourCoups` ne s'en sert plus que pour les cibles sans CombatEnnemi (dragon, cassables) ; `RetourCoups.arret_actif` /
`RetourImpact.arret_actif` coupent arrêts et ralentis (tests).

### Sons (pack CC0 `audio_combat_cc0`, copié dans assets/sons/combat/, crédits assets/LICENCES.md)
`RetourImpact.son` : `fouette_leger` (coups légers), `fouette_lourd` (lourd, contre, finisher), `metal_blocage`,
`parade_parfaite`, `degainer` / `rengainer` (préchargés, pas encore branchés sur l'équipement). Gain par fichier mesuré
(moyenne ramenée vers −19 dB) ; non écoutés à l'oreille.

### 3e personne
Contre et finisher passent par l'ancien état ARMER puis FRAPPE (`Sword_Attack` joué par corps_joueur.gd, vitesse du coup
lourd) ; garde : image de garde de `Sword_Attack` ; garde brisée : `Hit_Chest` (coup reçu). Pas d'animation dédiée
(parade, finisher) dans la bibliothèque.

## Tracé de lame (détection)
- Échantillons à **pas fixe de 1/240 s** du temps du geste (indépendant des images par seconde). La pose de chaque
  échantillon est calculée par la même fonction que l'image (Bézier + slerp), la caméra est interpolée entre deux images.
- **Tracé projeté (passe 4)** : la lame balaie l'écran EN TRAVERS à 0,5-0,9 m de l'œil ; chacun des 7 points de la lame
  vue (garde → pointe) est projeté le long de son rayon de visée jusqu'à `portee` (2,0 m ; la garde à `portee_garde`
  0,6 m). Par échantillon : un rayon œil → point (le premier obstacle sur la ligne de visée est touché : un mur devant la
  cible l'arrête toujours) puis un rayon latéral entre deux échantillons successifs de chaque point. Ce que la lame couvre
  à l'écran, dans la portée, est touché ; la pose du tracé vient de `AnimateurBras.pose_arme` (cinématique directe sur les
  pistes du clip) : image et tracé coïncident.
- Portée : 2,0 m depuis l'œil (mannequin touché par les 3 coups à 1,5 et à 2 m, test) ; `allonge` n'est plus utilisée
  par les coups légers / lourds (elle reste dans `points_lame` pour d'autres usages).
- Une seule touche par cible et par coup ; au plus `multi_cibles` (2) cibles par coup.
- Mur / décor : la lame s'arrête au point touché, étincelles + son, rebond (Staggered). Sol (normale verticale > 0,6) :
  la lame s'y arrête sans rebond. Cible vue à travers un mur : c'est le mur qui est touché. Ragdolls (calque 16) ignorés.
- Mur fragile (groupe `cassables`) : reçoit `frapper(puissant, origine)` ; s'il tient, la lame rebondit.
- Vérifié par `outils/test_combat_epee.gd` : mêmes touches, mêmes dégâts et même instant d'impact dans le geste à 30, 60 et
  144 i/s ; arrêt exact sur la face du mur.

### Contrat d'impact (commun avec la branche combat/degats_gore)
`recevoir_coup(degats, origine, puissant, info := {})` ; le 4e paramètre n'est passé que si la cible l'accepte.
`info` : `type` ("tranchant"), `point`, `direction` (mouvement de la lame au contact), `normale`, `zone`
("tete" > 83 % de la hauteur, "jambes" < 45 %, "bras" sur les côtés, sinon "torse"), `attaque` ("legere" / "lourde" /
"chargee_max" / "contre"), `arme` (id), `stagger` (dans l'unité des postures ennemies, `DegatsCombat.stagger` : léger 12,
lourd 28 × (1 + charge × 0,5) soit 42 à pleine charge, contre 34, × déséquilibre de l'arme / celui de l'épée de métal),
`collider`, plus `affaibli`, `charge`, `instant`. Transmis à CHAQUE touche du tracé de lame.

## Retours (RetourCoups)
Coups qui portent : profils d'impact (voir « Retours d'impact : une seule source ») ; mur 0,18 ; bloqué 0,3.
`RetourCoups.arret_actif` coupe l'arrêt sur image (tests). Les ennemis jouent leur son de chair et leurs éclats eux-mêmes.

## Animations passives (MouvementsPassifs)
Ressorts amortis (raideur 110, amortissement 0,65 : dépassement ~7 % à l'arrêt brutal, plus lents pour une arme lourde)
intégrés à 240 Hz. Respiration (±5 mm, 1,6 rad/s) et micro-dérives lentes ; balancement de marche au rythme des pas
(2,4 rad/m, courbe en sin² : creux au pas, sans pointe), plus ample en courant ; sprint (> 4,8 m/s) : épée abaissée vers
l'avant, torche stabilisée (balancement × 0,35) ; saut : les bras restent en arrière de l'impulsion ; atterrissage : amorti
proportionnel à la HAUTEUR de chute (point haut du vol − sol, `altitude` passée par mains.gd ; plein à 3 m) ; inertie :
la souris compte en angle tourné (pixels × sensibilité), impulsion RÉPARTIE sur les pas fixes de l'image, plafond doux
(tanh) à 4° ; l'inertie de rotation déplace aussi un peu les mains (8 cm/rad). **Main gauche** (torche, sort, bouclier) :
même mouvement, suivi par un ressort critique de 22 rad/s (retard mesuré ~50-70 ms) et balancement de marche en
opposition de phase. Impulsions de saut / atterrissage appliquées après l'intégration de l'image (même instant à toute
cadence). Amplitude = option **Balancement de l'arme**.

## Caméra « corps » (CameraCorps, scripts/combat/camera_corps.gd)
Appelée par joueur.gd (`camera_corps`, dans `_physics_process`) ; écrit `camera.position`, `camera.rotation`,
`h_offset` / `v_offset`. Ressorts CRITIQUES (sans dépassement) à pas fixe de 1/240 s : rapide 11 rad/s (saut, atterrissage,
attaques), lent 6,5 rad/s (amorti après un coup puissant, coup reçu, tangage d'atterrissage). La caméra ne fait jamais le
geste des bras ; au repos elle est immobile (0).
- **Balancement de tête** synchronisé aux sons de pas (même phase `_pas` : un pas à chaque multiple de π = point bas) :
  sprint 2,2 cm haut-bas, 0,9 cm de côté, roulis 0,2° ; marche (3,2 m/s) 1,1 cm / 0,44 cm / 0,1° (avant : 6 cm et 3,5 cm).
- **Saut** : la tête reste ~0,6 cm en arrière de l'impulsion ; **atterrissage** : creux 0,4 cm + 1,6 cm par mètre de chute
  (≤ 6 cm), tangage lent 0,25 rad/m de creux : 0,74 m (saut) → 1,5 cm / 0,2° ; 2 m → 3,3 cm / 0,5° ; 4 m → 5,5 cm / 0,8°.
- **Attaque** (`mains._accompagner_camera`, au début de la frappe) : la vue suit le sens de la lame de 0,25° environ
  (≤ 0,4°, ×1,4 pour lourd / contre, ×0,6 affaibli) — un accompagnement, pas le mouvement.
- **Impact** (montée de `joueur.secousse` pendant une attaque, profils d'impact inchangés) : recul de 0,004 × s rad ; coup
  puissant (s ≥ 0,45) : amorti lent vers le bas (0,5° et 0,6 cm à s = 0,5). Tassement (`joueur.tassement`) inchangé.
- **Secousse** : bruit CONTINU lent (~6 motifs/s au lieu de ~80 : l'ancien grésillait différemment à chaque cadence),
  s² × 6 cm de décalage et s² × 2° de roulis (avant 8 cm / 3,4°) : léger (0,22) 0,03 cm, lourd (0,5) ~0,5-0,7 cm, coup
  reçu (0,7) ~1,3-1,7 cm.
- **Coup reçu** (`recevoir_coup`, touche) : la tête part en arrière et penche du côté opposé au coup (roulis 0,7° pour
  12 dégâts de côté).
- **Arrêt sur image** : les ressorts avancent avec le temps de jeu (dt ralenti par `Effets.arret_image`) : ils se figent
  avec l'image et reprennent sans saut ; l'option « Arrêt sur image » n'est pas modifiée.

### Options (menu Options, user://options.cfg, section affichage)
`balancement_arme`, `mouvement_tete`, `secousses` (0..1, curseurs 0-100 %, défaut 100 %), dans le sous-panneau **Caméra**
(bouton en bas du panneau Options, comme « Touches » : trois lignes de plus débordaient du panneau de l'écran titre). **Réduire les mouvements**
plafonne : arme ≤ 35 %, tête ≤ 25 %, secousses (et tassement) ≤ 30 % (`CameraCorps.facteurs()`) ; un curseur plus bas
reste plus bas. À 0 % chaque canal est réellement coupé (vérifié par le test).

### Vérification : `outils/test_camera_corps.gd` (dans tous_les_tests.sh)
Scénario synthétique (repos, marche, sprint, virage 3000 px/s, saut, chute de 2 m, attaques + impacts, coup reçu) à 30, 60
et 144 i/s : écart aux instants communs 30/60 ≤ 0,8 mm et 0,00° ; pics par phase identiques (≤ 6 % ou 1 mm / 0,04°,
secousse ≤ 15 % : un bruit échantillonné) ; vraie physique (scène de test, chute de 2 m à 30/60/144 ticks : 2,000 m mesurés,
creux 3,27 / 3,29 / 3,29 cm). Courbes : `--courbes=<dossier>` (CSV + planche). Film : `outils/captures_camera_corps.gd`
(Movie Maker, lignes SEGMENT pour la découpe et MESURE par séquence).
Limite : sans interpolation de physique (projet à 60 ticks), à 144 i/s la caméra et le corps avancent par ticks de 1/60 s.

## Coups animés à la main (passe 5, remplace les poses procédurales des passes 3-4)
Le bras droit est joué par de **vraies animations à images clés** ; plus aucune IK ni pôle de coude à droite.
- **Source** : `sources_blender/scripts/gestes_bras_epee.py` (poses clés en espace écran : poing, direction de lame,
  roulis, coude, clavicule) → `anim_bras_epee.py` résout chaque clé dans les butées anatomiques (torsion de l'avant-bras
  −80…+85°, inclinaison −35…+20°, flexion −60…70°, angle du coude autour de l'axe épaule-poignet, continuité avec la clé
  précédente), pose des clés Blender (Bézier) et écrit `assets/animations/bras_epee.tres` (23 clips, 120 Hz, pistes
  `clavicle_r` / `upperarm_r` / `lowerarm_r` / `hand_r`, métadonnée `marqueurs` = arme, frappe, fin_frappe, suivi, fin).
  Le .blend d'auteur : `sources_blender/bras_fps_anims.blend`. `bras_godot.json` (repos, doigts, prises) vient de
  `outils/anim_bras/dump_bras.gd`.
- **Lecture** : `AnimateurBras` (`scripts/combat/animateur_bras.gd`) crée un AnimationPlayer « AnimationsEpee » en
  traitement manuel ; `mains.gd` choisit le clip selon l'état et fixe son temps sur les phases de la machine à états
  (`regler(t)`), fondus 0,06-0,12 s. Les durées des phases sont TIRÉES des marqueurs (÷ vitesse de l'arme).
- **Couche additive** : `DecalageBras` (SkeletonModifier3D sur `clavicle_r`) applique respiration, marche, inertie,
  recul, plongée d'équipement et tremblement de charge par-dessus le clip.
- **Prise au repos (tenue « tranche », 2026-10-27)** : épée DROITE d'après `references/combat_epee/tenue_epee_droite_1100.jpg`
  — lame à 12° de la verticale de l'écran (pointe vers le centre), pointe au bord haut, poing droit (0,52 ; −0,73), poing
  gauche / torche (−0,60 ; −0,78) ; **plat à 71° de l'œil** (0 = plat face caméra, 90 = tranche ; le plat ≈ 32 % de sa largeur
  — 79° / 19 % avant le retour « tourne un tout petit peu plus l'épée », 2026-10-27), poignet FIXÉ dans la clé REPOS
  (k=52, f=-11, r=-32, phi=0 : même pose au bout de chaque clip ; trouvé avec `anim_bras_epee.py -- --explorer=REPOS
  --grille=…`). Cible `TRANCHE_TENUE = 71` pour les poses tenues (repos, sprint, garde brisée, retours B / V3 / P2 ; garde
  `TRANCHE_TENUE + 4` avec `poids_roulis` : plat obtenu 71-75°, lame à <1° de la direction voulue) ; les armés et frappes
  gardent `TRANCHE = 78` (trajectoires inchangées). Identique pour les 5 épées.
  Mesures et planches : `outils/mesures_tranche.gd` (voir plus bas), `captures/tranche_trainee/`.
- **Bras** : brassards d'avant-bras façon Skarnholt (`sources_blender/scripts/brassards_skarnholt.py`, part de
  `sources_blender/bras_fps_lot6.glb`) : coque de cuir à facettes, canon de trois lames de fer rivetées, deux sangles à
  boucle, revers de fourrure au coude ; matières `brassard_cuir`, `sangle`, `fourrure_sombre` (HerosSkarnholt.materiaux_fps).

| Clip | Geste | Frappe (s) | Fin de la frappe | Fin du clip |
|---|---|---|---|---|
| coup_a | diagonale haut-droite → bas-gauche | 0,15 | 0,25 | 0,52 |
| coup_b (combo) | remonte à droite puis horizontal droite → gauche à plat, hauteur de poitrine | 0,17 | 0,27 | 0,54 |
| coup_gd (pas à droite) | revers gauche → droite | 0,11 | 0,21 | 0,50 |
| coup_c | vertical par-dessus + tassement caméra | 0,16 | 0,26 | 0,56 |
| lourd (arrêt, pas à gauche) | balayage horizontal droite → gauche | 0,08 après la charge (0,60) | 0,26 | 0,92 |
| lourd_vertical (en avançant) | vertical | idem | 0,26 | 0,92 |
| lourd_gd (pas à droite) | balayage vers la droite | idem | 0,26 | 0,92 |
| lourd_revers (en reculant) | revers / pommeau | idem | 0,22 | 0,86 |
| contre | revers rapide depuis la garde | 0,09 | 0,18 | 0,52 |
| finisher_taille / finisher_sol | | 0,26 | 0,38 | 0,72 |

Autres clips : repos, sprint, garde (épée en travers, pointe à gauche), encaisse, parade (petit choc), garde_brisee,
coup_horizontal, coup_revers, estoc, charge_* (une par puissante).

### Passe 6 (2026-10-27, branche combat/coups_finishers ; audit : docs/COMBAT_AUDIT.md)
Le tableau ci-dessus est l'historique ; valeurs actuelles (marqueurs arme / frappe / fin_frappe / suivi / fin, en s) :

| Clip | Geste (profil) | Marqueurs |
|---|---|---|
| coup_a | 1 du combo `diag_dg` : VRAIE diagonale haut-droite → bas-gauche, épée levée au-dessus de l'épaule, pronation sans retournement | 0,13 / 0,16 / 0,26 / 0,33 / 0,54 |
| coup_b | 2 du combo `revers_gd` : horizontal GAUCHE → DROITE à plat, lame qui traîne pointée à gauche (poids_torsion 0,4) | 0,10 / 0,13 / 0,23 / 0,30 / 0,50 |
| coup_c | 3 du combo `estoc_combo` : petit recul puis extension, le poing pousse vers l'avant | 0,11 / 0,15 / 0,25 / 0,30 / 0,50 |
| coup_c_ancien | ancien vertical (diagonale raide, lame à plat) : plus utilisé | inchangé |
| coup_v | vertical `verticale_l` (souris vers le bas, en avançant), V3_* (passe 7, branche combat/vertical) : armé court au coin haut droit, descente dans un plan vertical un peu à droite du centre, poignet qui casse, pointe finale sous le poing | 0,13 / 0,16 / 0,26 / 0,34 / 0,56 |
| coup_v2 | essai V2 abandonné (lame vue en bout pendant le suivi, avant-bras à 18 % à l'armé) | 0,14 / 0,17 / 0,27 / 0,34 / 0,56 |
| lourd | 4 phases : armé haut P2_ARME, tension (0,10), coup sec 0,10 → 0,25, grand suivi (0,42), retour 0,70, repos 0,96 | 0,10 / 0,10 / 0,25 / 0,42 / 0,96 |
| lourd_vertical | sur V2 | 0,06 / 0,06 / 0,21 / 0,40 / 0,92 |
| encaisse | coup bloqué : choc (lame chassée), rebond, replacement en garde | fin 0,26 (DUREE_ENCAISSE) |
| parade | parade parfaite : choc sec et rebond | fin 0,22 |

Lames : `sources_blender/epees_longues/epees_longues.py` (EPAIS 1,8, LARGE 1,12) : largeur apparente au repos (métal)
4,7 → 7,0 px, plat 79,2° inchangé. Les clips de finishers (finisher_plantee, _dos, _plonge, _pommeau, _taille) sont
dans la même bibliothèque ; leur logique est reprise par la branche combat/finishers_ennemis.
Vues de contrôle Blender : `anim_bras_epee.py -- --clips=<x> --rendu=<dossier> --vue=cote|dessus|epaule`.
Géométrie rapide sans rendu : `anim_bras_epee.py -- --clips=<x> --mesurer` (par image à 60 i/s : garde / pointe à l'écran,
part de la lame dans le cadre, part du plat vue, angle lame / visée) ; `--explorer=<CLE> [--grille=...]` liste les lames
atteignables pour un poing donné (utile : à poing bas, une lame pointée vers l'avant montre le plat).
Passe 7 (combat/vertical) : voir docs/COMBAT_AUDIT.md (vertical V3, 1re image de la diagonale et du revers).

### Point d'accroche de la main gauche (pour la magie)
Les clips n'animent QUE les os droits ; la main gauche est indépendante. Torche : `_accroche_g` (BoneAttachment3D sur
`hand_l`) porte `porte_torche` avec la prise `PRISE_G` ; le bras gauche suit la cible IK `pivot_torche` (TwoBoneIK3D,
seule IK restante, réglée par `MouvementsPassifs` et l'écartement pendant les coups). Un sort tenu en main gauche se
branche sur `_accroche_g` (ou remplace la cible `pivot_torche`) sans toucher aux clips d'épée.
Branché (fusion integration/combat_magie) : `mains.magie` (`scripts/magie/main_sort.gd`, docs/MAGIE.md) est le seul
crochet — entrées interceptées dans `_unhandled_input`, garde par `magie.garde_tenue()`, `magie.avancer(dt)` APRÈS la pose
de l'épée, arme de garde `magie.arme_de_garde(arme)` dans `defendre`. Main gauche : la magie pose `pivot_torche` (IK).
Main droite qui incante : `_ik_d` (TwoBoneIK3D sur le bras droit, ÉTEINTE par défaut) est allumée par MainSort tant
qu'un sort occupe la main droite (avec l'orienteur `_orient_d` ; la couche passive est alors mise à zéro, déjà incluse
dans la cible) ; dès que l'épée revient, l'IK s'éteint et les clips reprennent le bras.

## Pose FPS de repos (phase 1, historique)
Épée de métal : poignée (0,27 ; −0,24 ; −0,34) (poing gros, dans le coin bas droit), lame (−0,30 ; 0,70 ; −0,65)
(≈ 35° de la verticale à l'écran, pointe vers le centre haut), tranchant (−0,9 ; 0 ; −0,6) (plat et garde en croix
visibles), pôle du coude (0,7 ; 0,1 ; 0,4), déviation du poignet 40° (`deviation_poignet`). Torche (miroir) : poignée
(−0,40 ; −0,25 ; −0,33), manche (−0,24 ; 0,88 ; −0,42) (haut légèrement vers l'intérieur). Sprint : épée plus basse,
pointe vers l'avant. Tout se règle par arme dans sa `.tres`.
Teinte de la lame : la lame métal de la planche reçoit une copie de matériau légèrement chaude (1,3 ; 1,27 ; 1,22) ; le
reflet bleu restant vient de l'environnement (lumière ambiante bleue 0,32 ; 0,4 ; 0,62 sur une texture claire), voulu
pour la neige.

## Coups conçus en espace écran (passe 4, historique : remplacée par les clips de la passe 5)
Constat de la passe 3 : des gestes pensés comme un vrai bras qui frappe VERS la cible (en profondeur) montrent la lame
en bout et le poing énorme. Un viewmodel FPS (Skyrim, Mordhau, Chivalry) fait balayer la lame EN TRAVERS de l'écran.
- **Clés écran** (`profils_animation.gd`) : pour chaque clé (armer, milieu, fin, suivi) : `g` position écran de la garde
  (x, y normalisés −1…1), `z` profondeur de la garde (0,55-0,8 m), `t` position écran de la pointe ; la profondeur de la
  pointe découle de la longueur de lame (0,87 m, racine la plus lointaine). La main se déduit de la garde.
- **Règle de conception** (mesurée, voir plus bas) : la main reste dans la moitié basse / le bord droit, la lame reste
  LEVÉE (pointe vers le haut ou le côté) et balaie l'écran comme un essuie-glace ; une lame pointée vers le bas ou vers
  un bord latéral (rayons très obliques à 104° de champ horizontal) fuirait en profondeur. Les clés ont été résolues avec
  un petit solveur hors moteur (angle visé avec le rayon du milieu de lame, part visible), puis vérifiées dans Godot.
- **Bras** : pendant les coups, la main suit EXACTEMENT la pose (orientation_main sans borne) ; `mains._pole_ecran`
  choisit le coude sur son cercle (épaule, main, longueurs) pour que l'avant-bras PROLONGE LA POIGNÉE À L'ÉCRAN (plan
  caméra-main-pointe) : pas de poignet cassé visible. Si la main est hors de portée (bras de 0,5 m), l'épaule droite
  (os `upperarm_r`, hors écran) glisse vers elle ; le bras gauche ne bouge pas. Torche : abaissée de 0,30 m et écartée
  pendant les coups (contrepoids, la lame passe devant).
- **Tranchant** : il suit la tangente de l'arc de la pointe (le tranchant mène), transporté d'une clé à l'autre sans
  rotation de la lame sur elle-même.
- **Rythme** : préparation (ease-out) → tenue lisible (2-3 images) → frappe 0,09-0,10 s, ease-in fort → suivi
  0,07-0,08 s qui dépasse B → retour ~0,22 s ou coup suivant (fenêtres de combo et mémoire d'entrée inchangées).
- **Coup 3** : ×1,25, un peu plus lent ; **tassement caméra** (`joueur.tassement`, v_offset −3,5 cm en ~0,18 s, ×0,4
  avec « Réduire les mouvements ») à la fin de la frappe ; aussi sur le coup lourd.
- **Traînée** (`TraineeLame`) : ruban entre l'historique garde → pointe, échantillonné à 1/240 s pendant la frappe et le
  suivi (mêmes pistes que l'image : `AnimateurBras.pose_arme`, écart mesuré 0,0-0,1 px), en BANDE le long du tranchant
  (nulle au premier tiers de la lame, pleine au-delà de 80 % : `smoothstep(0.3, 0.8)`) — l'ancien croissant limité à la
  pointe restait collé au haut de l'écran, identique d'un coup à l'autre ; une pointe passée derrière le plan de la caméra
  est ramenée le long de la lame à z = −0,08 (`TraineeLame.PROCHE`) ; 4 paliers d'opacité, 3 tons (pas de dégradé, pas de tramage),
  sommets accrochés à la grille 270 lignes comme le shader ps1, unshaded / alpha (compatible Web) ; s'efface en 0,1 s.
  Couleur par arme (`couleur_trainee`, `couleur_trainee_coeur`) : acier bleu-blanc, or, rubis, verre vert, obsidienne
  rouge sombre.

### Contraintes et mesures (`captures_combat_epee.gd -- --mesures`)
Mesurées à chaque image de la frappe : lame visible ≥ 70 % (dans le cadre, non cachée par la main, le bras ou le manche
de la torche — flamme et halo transparents non comptés), angle lame / rayon de visée du milieu de lame ≥ 50°, main + bras
DROITS ≤ 15 % de l'écran (masque magenta, torche écartée), écart avant-bras / poignée à l'écran ≤ 15°, et « fil » :
angle tranchant / mouvement de la pointe (0 = le tranchant mène). Épée de métal, combo à l'arrêt :

| Coup | Lame visible | Angle visée | Main + bras | Avant-bras / poignée | Fil / mouvement | Violations |
|---|---|---|---|---|---|---|
| 1 diag_dg | 76-100 % | 54-61° | 4,3-5,1 % | 2-5° | ≤ 11° | 0 |
| 2 horizontale_gd | 96-100 % | 57-60° | 1,2-2,5 % | 5-7° | ≤ 12° | 0 |
| 3 verticale_l | 84-100 % | 53-58° | 7,2-11,7 % | 3-6° | ≤ 28° | 0 |
| Lourd verticale | 76-100 % | 54-61° | 4,1-5,4 % | 2-7° | ≤ 6° | 0 |
| diag_gd / horizontale / estoc | 80-100 % | 53-61° | ≤ 9,1 % | ≤ 11° | ≤ 13° (estoc : poussée dans l'axe) | 0 |

Planches : `captures/combat_epee/coups_ecran/coup_<n>_<geste>.png`, `geste_<nom>.png`, `armes/<arme>/` ; films :
`captures/combat_epee/video/coups_ecran_reel.mp4`, `coups_ecran_ralenti_x025.mp4`.

## Directions et enchaînements (phase 4)
Choix du geste léger à l'appui (`mains._choisir_geste`), par priorité :
1. souris balayée (> 40 px récents, oubli ~0,1 s) : horizontal dans le sens du balayage ; tirée vers le bas : vertical ;
2. déplacement : de côté (> 1,2 m/s) → horizontal dans le sens du pas ; en avant (> 1,5 m/s) → vertical ; en arrière
   (> 1,2 m/s) → estoc ;
3. à l'arrêt : combo du profil diag_dg → horizontale_gd → verticale_l.
Continuité : chaque geste a un côté de départ et d'arrivée ; dans un enchaînement, un geste du combo qui partirait du
mauvais côté est remplacé par son miroir, un geste contextuel répété alterne de sens (pas de côté : droite-gauche-droite),
et la préparation est raccourcie ×0,75 quand la lame est déjà du bon côté.
Les gestes contextuels suivent les mêmes règles écran : `diag_gd` (revers) a ses propres clés (main partie de l'épaule
gauche, finit en bas à droite, lame levée — un miroir du coup 1 tordrait le bras droit), `horizontale` est le miroir de
`horizontale_gd`, l'estoc pousse la main de la hanche droite vers le centre, lame à ≥ 50° du regard.
Fenêtres de combo par geste (début en s, fin en part de la récupération) : diagonales et horizontales 0,05 → 90 % ;
vertical léger 0,06 → 85 % ; estoc 0,06 → 80 % ; lourd 0,08 → 80 %. Un appui hors fenêtre relance le combo au geste 1.

| Geste | Préparation | Tenue | Frappe | Suivi | Récupération |
|---|---|---|---|---|---|
| diag_gd (revers) | 0,11 | 0,04 | 0,09 | 0,07 | 0,30 |
| horizontale (droite → gauche) | 0,11 | 0,04 | 0,09 | 0,07 | 0,30 |
| estoc (en reculant, dégâts de 25 % à 100 % de la frappe) | 0,11 | 0,04 | 0,10 | 0,05 | 0,30 |

3e personne : seule l'animation `Sword_Attack` existe pour l'épée ; l'estoc joue `Punch_Jab` (poussée droit devant).

## Limites connues / suite
- Coups animés (passe 5) : quelques clés gardent 20-40° d'écart de lame à cause des butées (armés de B et du revers,
  milieu de C) ; le coup C se lit comme une diagonale raide plutôt qu'un vertical pur (épaule sous l'œil) et l'avant-bras
  reste visible quelques images pendant son armé.
- Phase 3 (fait, integration/H) : la garde est orientée par la position de l'attaquant (cône de 120°), pas encore par le
  tracé de son arme ; seuls les draugrs (et squelettes, bandits : draugr.gd) réagissent à la parade (`subir_parade`) ;
  projectiles et pièges sont bloqués / parés sans déséquilibre. Pas d'animation 3e personne dédiée à la parade ni au
  finisher. Sons de garde non écoutés à l'oreille.
- Passe 6 : le vertical restait l'ancien coup_c_ancien ; passe 7 : vertical V3 (coup_v) et 1re image de la diagonale
  (84 %) et du revers (56 %), limites dans docs/COMBAT_AUDIT.md.
- Phase 4 (reste) : gestes 3e personne par direction (animations à créer).
- Phase 5 : équilibrage des 4 variantes, lueurs (rubis, verre), effets d'enchantement.
- Phase 6 : sons d'impact par matériau, caméra, optimisation.
- Coups en espace écran : l'armé du coup 1 a la main au bord droit à mi-hauteur (pas tout en haut) et l'armé du coup 3 au
  centre-haut, pas au-dessus de la tête : une main plus haute ferait sortir la lame (0,87 m) par le haut de l'écran. La
  frappe ne dure que 5-6 images à 60 i/s (rythme demandé) ; la traînée porte la lecture du mouvement. En 3e personne,
  rien ne change (animation `Sword_Attack`).
