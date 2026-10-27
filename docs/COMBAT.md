# Combat à l'épée (vue FPS) — règles, valeurs, architecture

Référence visuelle : `references/combat_epee/planche_combat_epee_1100.jpg` ; cahier des charges : `references/combat_epee/prompt_utilisateur.md`.
État : phase 1 (pose FPS + animations passives) et phase 2 minimale (léger / lourd / tracé de lame / réactions existantes).
Les phases 3 à 6 (défense complète, combos riches, variantes, polish) s'appuient sur la même architecture.

## Lancer

| Quoi | Commande (depuis le worktree, `G` = Godot console, `W` = chemin Windows) |
|---|---|
| Scène de test (jouable) | `$G --path "$W" res://scenes/test_combat.tscn -- [--nuit] [--draugr=actif\|fige\|aucun] [--debug-combat]` |
| Test automatique | `bash outils/tous_les_tests.sh test_combat_epee` (≈ 6 s, sans fenêtre) |
| Planches | `bash /tmp/godot_slot.sh $G --path "$W" --script res://outils/captures_combat_epee.gd -- --sortie="$W\captures\combat_epee\scene"` |
| Film | idem avec `--write-movie "$W\captures\combat_epee\video\combat_epee.avi" --fixed-fps 30` avant `--script`, et `-- --film` |
| Pose de repos dans le village | `--captures="$W\outils\poses_combat_epee.txt"` (voir SOCLE_TECHNIQUE §6.1) |

En jeu : clic gauche court = coup léger, maintenu = charge puis coup lourd au relâchement ; clic droit = garde ;
T = torche ; **F3 = débogage** (tracé de lame, état de combat, endurance, charge, rayons).

## Architecture (`scripts/combat/`)

| Fichier | Rôle |
|---|---|
| `donnees_arme.gd` (`DonneesArme`, « WeaponData ») | Resource : modèle (.glb) + habillage + point de prise, pose de repos (poignée, lame, tranchant, pôle du coude), dégâts, vitesse, poids, coûts, réduction en garde, tracé de lame (garde → pointe + allonge), profil d'animation. Une `.tres` par objet dans `data/armes/`. |
| `equipement.gd` (`Equipement`) | Main droite / main gauche séparées ; deux mains = main gauche libérée ; T sort / range l'objet gauche ; l'épée de Skarnholt remplace l'épée de métal quand elle est dans l'inventaire. |
| `entrees_combat.gd` (`EntreesCombat`) | Entrées horodatées, durée d'appui, mémoire d'entrée (input buffer, 0,35 s), garde (bouton ou imposée). |
| `etat_combat.gd` (`EtatCombat`) | Machine à états : Idle, Moving, LightAttack, HeavyCharge, HeavyAttack, Blocking, Parrying, Staggered, Recovery, Equip ; table des transitions autorisées. |
| `profils_animation.gd` (`ProfilsAnimation`) | Gestes d'attaque (préparation, phase active à trois poses, récupération, fenêtre de dégâts), poses de charge / garde / sprint. Mêmes fonctions pour l'image et pour le tracé. |
| `trace_lame.gd` (`TraceLame`) | Détection par tracé de lame à pas fixe. |
| `degats_combat.gd` (`DegatsCombat`) | Calcul des dégâts, appel de `recevoir_coup` (avec `info` si la cible l'accepte), zone touchée. |
| `retour_coups.gd` (`RetourCoups`) | Arrêt sur image, secousse, étincelles et son sur les murs, signal discret de pleine charge. |
| `mouvements_passifs.gd` (`MouvementsPassifs`) | Respiration, marche, sprint, saut / atterrissage, inertie de la caméra, arrêt brutal (ressorts à pas fixe). |
| `debogage_combat.gd` | Dessin du tracé et texte d'état (F3). |
| `mannequin.gd` | Mannequin d'entraînement de la scène de test (encaisse, vacille, affiche les dégâts). |

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
LightAttack/HeavyAttack --lame arrêtée (mur, bouclier, cassable qui tient)--> Staggered (0,30 s) --> Idle
Idle/Moving --changement d'arme--> Equip (0,45 s) --> Idle
```
Pas d'attaque en garde (l'appui mémorisé est effacé) ; toute attaque passe par Recovery (pas d'attaque infinie).

## Valeurs (épée en métal, vitesse 1)

| Geste | Préparation | Phase active | Récupération | Fenêtre de dégâts (part de la phase active) |
|---|---|---|---|---|
| Léger 1 : diagonale droite → gauche | 0,10 s | 0,17 s | 0,30 s | 10 % → 92 % |
| Léger 2 : diagonale gauche → droite (revers) | 0,12 s | 0,17 s | 0,30 s | 10 % → 92 % |
| Léger 3 : horizontal | 0,13 s | 0,19 s | 0,34 s | 10 % → 92 % |
| Lourd : vertical | 0,06 s (après la charge) | 0,24 s | 0,46 s | 8 % → 94 % |

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

### Garde et parade (inchangées sur le fond, phase 3 à venir)
- Garde = clic droit tenu ; angle : l'attaquant doit être devant (produit scalaire > 0,3).
- Parade : coup reçu dans les 0,3 s après la levée de la garde (`FENETRE_PARADE`) → aucun dégât, coût × 0,3.
- Blocage : `1 − reduction_garde` des dégâts passent (15 % avec l'épée de métal).
- Impact encaissé : pose « encaisse » 0,18 s, la garde reste levée. Vitesse de marche × 0,5 en garde ; pas de sprint.

## Tracé de lame (détection)
- Échantillons à **pas fixe de 1/240 s** du temps du geste (indépendant des images par seconde) ; entre deux échantillons,
  un rayon par point de la lame (5 points de la garde à la pointe + allonge). La pose de chaque échantillon est calculée
  par la même fonction que l'image (Bézier + slerp), la caméra est interpolée entre deux images.
- Allonge de jeu : 0,33 m au-delà de la pointe (épées longues) ; portée effective ≈ 1,9 m depuis l'œil, celle des draugrs.
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
"chargee_max" / "contre" plus tard), `arme` (id), `stagger` (léger 0,3 ; lourd 0,7 × (1 + charge × 0,5)), `collider`,
plus `affaibli`, `charge`, `instant`.

## Retours (RetourCoups)
Arrêt sur image 0,05 s (léger) / 0,10 s (lourd) ; secousse 0,22 / 0,45 ; mur 0,18 ; bloqué 0,3. `RetourCoups.arret_actif`
coupe l'arrêt sur image (tests). Les ennemis jouent leur son de chair et leurs éclats eux-mêmes.

## Animations passives (MouvementsPassifs)
Ressorts amortis (raideur 110, amortissement 0,5, plus lents pour une arme lourde) intégrés à 240 Hz. Respiration
(±5 mm, 1,6 rad/s) et micro-dérives lentes ; balancement de marche au rythme des pas (2,4 rad/m), plus ample en courant ;
sprint (> 4,8 m/s) : épée abaissée vers l'avant, torche stabilisée (balancement × 0,35) ; saut : les bras restent en
arrière de l'impulsion ; atterrissage : amorti proportionnel à la vitesse de chute ; inertie : impulsion à chaque
mouvement de souris ; arrêt brutal : le ressort dépasse puis revient. Option **« Réduire les mouvements »** (menu Options) :
amplitude des bras × 0,35, balancement de tête × 0,4.

## Pose FPS de repos (phase 1)
Épée de métal : poignée (0,32 ; −0,28 ; −0,45), lame (−0,05 ; 0,86 ; −0,51), tranchant (−0,3 ; 0 ; −1), pôle du coude
(1,0 ; −0,3 ; 0,1). Torche (miroir) : poignée (−0,40 ; −0,30 ; −0,40), manche (−0,30 ; 0,86 ; −0,42). Le pôle du coude
écarté garde l'avant-bras presque horizontal : le poignet (déviation bornée à 35° par `orientation_main.gd`) peut alors
incliner la lame vers l'avant. Réglable par arme dans sa `.tres`.

## Limites connues / suite
- Phase 3 : garde orientée par le tracé de l'arme ennemie, parade parfaite avec déséquilibre ennemi, contre-attaque
  (`attaque = "contre"`), garde brisée quand l'endurance tombe à 0.
- Phase 4 : choix de direction selon le mouvement (pas de côté → horizontal, en avant → vertical), fenêtres de combo
  par geste, annulation de la récupération par la garde.
- Phase 5 : équilibrage des 4 variantes, lueurs (rubis, verre), effets d'enchantement.
- Phase 6 : sons d'impact par matériau, traînée de lame pixel, caméra, optimisation.
- Le corps 3e personne suit l'ancien état (Sword_Attack) : pas encore de geste par direction.
