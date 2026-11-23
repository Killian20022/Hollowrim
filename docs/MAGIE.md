# Magie et deux mains (vue FPS) — règles, valeurs, architecture

Références : `references/magie/prompt_magie.md` (cahier des charges), `references/magie/referentiel_magie_1100.jpg`
(4 écoles × 3 sorts, poses, palettes) et `*_fps_1100.jpg` (rendu FPS visé). Branche `magie/sorts` (logique) ; les VISUELS
et l'interface sont faits sur `magie/effets` (contrat `EffetsMagie` plus bas) ; les coups d'épée authorés sur
`combat/coups_skyrim` (rien de leurs fichiers n'est touché ici).

## Lancer

| Quoi | Commande (`G` = Godot console, `W` = chemin Windows du worktree, toujours via `godot_slot.sh`) |
|---|---|
| Scène jouable | `$G --path "$W" res://scenes/test_magie.tscn -- [--pilote] [--draugr=actif\|fige\|aucun] [--troll] [--nuit]` |
| Test automatique | `bash outils/tous_les_tests.sh test_magie` (112 vérifications, ~40 s) |
| Planches des poses | `$G --path "$W" --script res://outils/captures_magie.gd -- --poses --sortie="$W\captures\magie\poses"` |
| Pilote + captures | `... --script res://outils/captures_magie.gd -- --sortie="$W\captures\magie\pilote"` (une image par `moment`) |
| Film du pilote | `... --write-movie "$W\captures\magie\video\pilote.avi" --fixed-fps 30 --script res://outils/captures_magie.gd -- --film` |
| Régénérer les sorts | `--headless --script res://outils/generer_sorts.gd` (ÉCRASE les .tres de data/sorts/ ; les .tres sont la source) |

## Contrôles (PC, reconfigurables : actions InputMap)

| Action | Défaut | Effet |
|---|---|---|
| `main_droite` | clic gauche | main droite : coup d'épée (comme avant) ou sort |
| `main_gauche` | clic droit | main gauche : sort ; **GARDE** si la règle « garde » s'applique (voir plus bas) |
| maintenir | — | charger (boule, éclat, lance, trait, orage, rayon, zones) / canaliser (jet, arc, drain, soin, protection) |
| relâcher | — | sort chargé (coût et dégâts selon la charge) ; fin de canalisation |
| les deux boutons | fenêtre 0,15 s | **double incantation** si les deux mains tiennent LE MÊME sort |
| `raccourci_1` … `raccourci_0` | touches 1-0 | équipe les deux mains (data/magie/raccourcis.json) |
| T | — | sortir / ranger la torche (inchangé) |
| `inventaire` | I | écran d'inventaire des deux mains (jeu en pause), voir plus bas |

Le joueur sait toujours pourquoi une action est refusée : signal `joueur.action_refusee(main, raison)` et `magie.refus[main]`
(« Pas assez de mana. », « Recharge : 2.4 s », « Il faut une épée dans l'autre main… », « Incantation interrompue. »,
« Mana épuisé. », « Soin et drain se contrarient… », « Déséquilibré. »). Un appui pendant un coup d'épée est **mémorisé**
0,35 s (`tampon_sort`) au lieu d'être refusé.

## Architecture (`scripts/magie/`, `scripts/combat/`)

| Fichier | Rôle |
|---|---|
| `magie/donnees_sort.gd` (`DonneesSort`) | Resource sur le modèle de DonneesArme : école, type (RAPIDE, CANALISE, CHARGE, ZONE, ENCHANT), portée (PROJECTILE, JET, CHAINE, ZONE_VISEE, ZONE_SOI, SOI), coûts, incantation, charge, récupération, recharge, dégâts, statut, portée, rayon, projectile, rebonds, drain, soin, protection, enchantement, multiplicateurs de double, profil d'animation, seuil d'interruption. Une `.tres` par sort dans `data/sorts/` (ennemis : `data/sorts/ennemis/`). |
| `magie/equipement_mains.gd` (`EquipementMains`) | Équipement généralisé : chaque main = arme / arme à deux mains / sort / bouclier / torche / vide. Règles **data-driven** `data/magie/regles_mains.json` (permis, refus lisibles, deux mains, garde, enchantement, simultané, épée+magie, double). Pousse vers `Equipement` (mains.gd) une DonneesArme par main ; une main qui incante reçoit `data/armes/main_sort.tres` (sans modèle). Raccourcis, sorts connus, export / import. |
| `magie/main_sort.gd` (`MainSort`) | Orchestrateur, **seul point d'accroche** dans mains.gd (`mains.magie`) : entrées interceptées avant l'épée, une `Incantation` par main, double incantation, interruption (signal `joueur.touche`), enchantement, protection (`absorber`), HUD, sauvegarde, poses des mains. |
| `magie/incantation.gd` (`Incantation`) | État d'une main : REPOS → INCANTE → CHARGE / CANALISE / départ → RECUPERATION. |
| `magie/lanceur_sorts.gd` (`LanceurSorts`) | Exécute un sort selon son TYPE (jamais par son nom) : projectiles, chaîne, jets canalisés (tics de 0,2 s), zones, soin ; aide à la visée ; versions doubles ; partagé avec le mage ennemi (camp « joueur »). |
| `magie/projectile_sort.gd` (`ProjectileSort`) | **Étend `projectile.gd`** : vol tendu, visuel EffetsMagie, touche par proximité de la trajectoire, traverse (lance). |
| `magie/zone_magie.gd` (`ZoneMagie`) | Zone persistante (tempête) et attraction (vortex). |
| `magie/poses_incantation.gd` (`PosesIncantation`) | Poses FPS des mains qui incantent (fichier à part des gestes de l'épée). |
| `magie/gestes_magie.gd` (`GestesMagie`) | Gestes des bras capturés (Mixamo, `data/magie/gestes_mixamo.json`) : lancer, charge, jet tenu, double incantation, zone ; à défaut, les poses fixes de PosesIncantation. |
| `magie/effets_magie.gd` (`EffetsMagie`) | Contrat visuel ; ici **bouchons** (sphères / boîtes colorées), remplacé par la branche magie/effets. |
| `magie/scene_test_magie.gd` + `scenes/test_magie.tscn` | Scène de test + pilote automatique (§10). |
| `combat/statuts.gd` (`Statuts`) | Statuts centralisés d'une cible (nœud enfant) : brûlure, brûlure obscure, gel, choc, corruption. |
| `combat/elements.gd` (`Elements`) | Branché dans `DegatsCombat.appliquer` (chemin unique des coups du joueur) : corruption, lame enchantée, combos épée + statut, bonus « épée après sort », puis réaction élémentaire / pose du statut / drain. Table `data/magie/reactions.json`. |

Modifiés (petits crochets) : `mains.gd` (variable `magie`, interception des entrées, garde selon les règles, `magie.avancer`
après la pose de l'épée, arme de garde = bouclier), `joueur.gd` (mana, signaux / propriétés HUD, `depenser_mana`, `soigner`,
protection dans `recevoir_coup`), `equipement.gd` (l'inventaire ne remet plus l'épée par-dessus un sort), `degats_combat.gd`
(Elements avant / après), `combat_ennemi.gd` (tic canalisé : ni plaie ni arrêt sur image ; moins de sang pour la magie),
`profil_cible.gd` (résistances électricité / ténèbres), `ennemi_base.gd` + `draugr.gd` (gel : vitesse × facteur),
`troll_givre_ia.gd` (peur du feu, choc atténué, brûlure = pas de régénération), `mage_nordique_ia.gd` (choc interrompt ;
sorts du système de magie), `monde.gd` (sauvegarde « magie »).

## Inventaire des deux mains (touche I)

`scripts/inventaire_mains.gd` (`InventaireMains`, CanvasLayer ajouté par `monde.gd` et `test_combat.gd`), jeu en **pause**.
Catégories Armes / Sorts / Divers (A/E en AZERTY = touches physiques Q/E, LB/RB) ; aperçu des deux mains en haut ; liste
des objets possédés (icônes `IconesCombat`) ; fiche (dégâts, coût en mana, vitesse, effet, recharge) qui dit d'avance,
pour chaque main, si l'objet peut y aller et sinon pourquoi. **Clic gauche / Entrée / D / A manette = main droite ;
clic droit / G / X manette = main gauche** ; refus et conséquences (« Occupe les deux mains : la main gauche sera
libérée. », « L'arme à deux mains sera rangée. ») dans le bandeau. **Raccourcis** : un chiffre 1-0 (ou clic sur une case)
range les deux mains ACTUELLES dans ce raccourci ; clic droit = le vider (la touche ne change plus rien). Les raccourcis
sont sauvegardés (`magie.raccourcis` dans la sauvegarde ; data/magie/raccourcis.json = valeurs de départ).
Données : `data/magie/inventaire.json` (catégories par genre, objets équipables avec condition `inventaire` facultative,
ordre des écoles) ; API `EquipementMains.objets_possedes / fiche / essai / assigner_raccourci / vider_raccourci`,
`objets_supplementaires` (objets ajoutés à l'exécution), `objet(id)` lit aussi toute DonneesArme de `data/armes/<id>.tres`.
Test : `bash outils/tous_les_tests.sh test_inventaire_mains`.

## Règles des deux mains (`data/magie/regles_mains.json`)

- Gauche : vide, sort, bouclier, torche. Droite : vide, arme, arme à deux mains, sort. Refus lisibles (« Une seule arme :
  elle se tient en main droite. », « Le bouclier se porte au bras gauche. »…).
- Arme à deux mains : occupe les deux ; équiper la gauche range l'arme (la droite redevient vide).
- **Clic droit = garde** si : bouclier à gauche (toute main droite) ; vide ou torche à gauche ET arme à droite ; arme à
  deux mains. Sinon clic droit = main gauche (sort). Avec bouclier, c'est le bouclier qui pare (`reduction_garde` 0,95,
  coût × 0,6, cône 170° ; `data/armes/bouclier.tres`, vrai modèle et gestes posés par mains.gd : docs/COMBAT.md, « Garde au bouclier »).
- Enchantement : exige une arme dans l'autre main.
- Deux sorts différents à la fois : chaque main paie son sort ; deux canalisations ensemble × 1,15 ; régénération de mana
  arrêtée tant qu'une main incante ; incompatibles : soin + drain de vie.
- Épée + magie : pas de sort pendant un coup d'épée (mémorisé 0,35 s) ni dans les premiers 35 % de sa récupération ; un
  coup d'épée **coupe la canalisation** de l'autre main (une charge est gardée, la main s'écarte en contrepoids) ; épée
  dans les 1,2 s après un sort sur la même cible : dégâts × 1,15 (ouverture du guerrier-mage).
- Combinaisons prioritaires (raccourcis 1-0) : 1 torche/épée, 2 feu/épée, 3 feu/feu, 4 glace/électricité,
  5 ténèbres/feu, 6 bouclier/épée, 7 vide/épée, 8 vide/électricité, 9 soin/ombre, 0 protection/épée.

## Mana

100 max (+ bonus de niveau) ; régénération **en combat** 7 /s après 1,2 s sans dépense ni incantation, **hors combat** 18 /s après
4 s sans lancer de sort (`Joueur.REGEN_MANA_CALME`, `DELAI_CALME_MANA` : le réservoir passe de ~14 s à ~6 s de remplissage quand
on a fini de se battre ; le mage qui temporise en plein combat ne le gagne qu'après 4 s sans dépenser) ; plein à la résurrection ;
sauvegardé. Potion de mana : +50 sur 4 s (`data/objets/consommables.json`, délai de réutilisation 3 s).
Coûts payés : RAPIDE / ZONE / ENCHANT au départ ; CHARGE au relâchement (`cout × ChargeSort.facteur_cout(s, charge)` ; la
charge cesse de monter quand le mana ne paierait plus davantage) ; CANALISE par seconde (arrêt « Mana épuisé »).

### Sorts lancés chargés (charge commune, 2026-11-05)

Retour joueur : « lorsqu'on reste appuyé, qu'il se charge et fasse plus de dégâts au maximum ; ça permet aussi de viser ».
UN mécanisme pour tous : `scripts/magie/charge_sort.gd` (`ChargeSort`), réglages `data/magie/charge_sorts.json`. Famille
« projectile chargé » = tout sort `type CHARGE` + `portée PROJECTILE` (boule de feu, éclat de glace, lance de givre, trait
d'ombre) : leurs `temps_charge` / `degats_charge_min` / `cout_charge_min` de .tres sont ignorés, `degats` et `cout` y sont les
valeurs à PLEINE charge.
- Appui : incantation (0,16 s) puis charge ; 1,2 s de charge (`temps_plein`) → maximum à ~1,35 s de l'appui. Pendant
  l'incantation et la charge (tous les sorts qui se chargent) le joueur avance à ×0,65 (`vitesse_joueur`), l'énergie de la main
  monte (aura 0,6 → 1, son de charge qui monte) ; on vise au réticule.
- Relâcher : tir vers le centre de l'écran. Tap (relâché avant la fin de l'incantation) = petit tir : 50 % des dégâts, 50 %
  du coût, projectile ×0,8. Juste avant le maximum : 72 %, ×1,12. AU maximum : palier à 100 % (×2 du tap), projectile ×1,5
  (lumière plus forte, touche un peu plus large), signal unique `EffetsMagie.charge_pleine` (son `pleine_charge.wav`, hauteur par
  école ; éclat de lumière dans la main) puis pulsation de l'aura par paliers francs. Maintenir plus longtemps ne surcharge pas.
- Main : l'énergie tenue grossit de +40 % à pleine charge (`croissance_main`, noyaux glace / ténèbres / électricité ; la flamme
  du feu grandit déjà) ; un tap sur un sort à charge joue l'entrée puis le départ du geste « charge » (comme
  une boule de feu non chargée avant) ; en DOUBLE, ce tap saute encore d'environ 12 cm entre l'entrée et le départ (capture
  double_charge, défaut antérieur, non corrigé : le parcours accéléré de la tenue tordait le poignet). Une boule de feu chargée naît à taille normale contre l'œil et
  prend sa pleine taille dans le premier mètre et demi.
- Restent à part : rayon du néant, orage runique, zones chargées (leurs propres temps et parts, mais même ralenti, signal et
  pulsation) ; instantanés : chaîne d'éclairs, enchantements ; canalisés : jets, arc, drain, soin, protection.
- Test : `outils/test_sorts_charges.gd` ; preuves : `outils/film_sorts_charges.gd` (film tap / charge pleine, gros plans de la main).

## Les sorts (`data/sorts/*.tres` = LA source : 21 sorts ; équilibrage du 2026-11-05, voir « Équilibrage » plus bas)

| Sort | École | Type | Coût | Dégâts | Statut | Portée / rayon | Recharge | Double (principaux ×) |
|---|---|---|---|---|---|---|---|---|
| Jet de flammes | feu | canalisé, jet (traverse 3) | 13 /s | 15 /s | brûlure 4 /s, 3 s | 9 m, largeur 0,9 | — | dégâts 2, coût 2,2, largeur 1,8, portée 1,25 |
| Boule de feu | feu | chargé 1,2 s (commun), projectile 24 m/s | 25 (×0,5 au tap) | 30 (×0,5 au tap, ×0,72 avant le max) + explosion | brûlure 4 /s, 3 s | rayon 2,2 | 0,5 s | dégâts 2,2, coût 2,4, rayon 1,6 |
| Explosion incendiaire | feu | zone visée, chargée 1 s | 42 | 38 | brûlure 6 /s, 4 s | 14 m, rayon 3 | 4 s | dégâts 2, coût 2,3, rayon 1,5 |
| Éclat de glace | glace | chargé 1,2 s (commun), 3 éclats 34 m/s | 16 (×0,5 au tap) | 12 ×3 (×0,5 au tap) | gel 0,25, 2,5 s | — | 0,3 s | 6 éclats, dégâts 1,6, coût 2,2 |
| Lance de givre | glace | chargé 1,2 s (commun), traverse 1 | 30 (×0,5 au tap) | 44 (×0,5 au tap) | gel 0,45, 3 s | — | 0,8 s | lance + 2 cristaux, traverse 3, dégâts 2,1 |
| Souffle de givre | glace | canalisé, jet (traverse 3) | 12 /s | 16 /s | gel 0,35, 2 s | 8 m, largeur 0,9 | — | dégâts 2, coût 2,2, largeur 1,6, portée 1,2 |
| Nova gelée | glace | zone autour de soi | 40 | 24 | gel 0,55, 4 s | rayon 4,5 | 5 s | rayon 1,5, gel 1,4 |
| Arc électrique | électricité | canalisé, jet (1 cible) | 14 /s | 24 /s | choc 0,45 s | 9 m | — | portée 1,3, +2 rebonds (propagation) |
| Chaîne d'éclairs | électricité | rapide, chaîne | 22 | 24, ×0,75 par rebond, 3 rebonds | choc 0,4 s | 20 m, rebond 6,5 m | 1 s | +3 rebonds, dégâts 1,9 |
| Tempête statique | électricité | zone visée persistante 5 s | 52 | 9 par tic de 0,5 s | choc 0,3 s | 16 m, rayon 4 | 9 s | rayon 1,4, durée 1,3 |
| Orage runique | électricité | chargé 1 s, foudre visée | 30 | 38 (×0,5 sans charge) | choc 0,5 (0,6 s) | 22 m, rayon 3 | 1 s | dégâts 2,1, coût 2,4, rayon 1,4 |
| Trait d'ombre | ténèbres | chargé 1,2 s (commun), projectile 30 m/s | 18 (×0,5 au tap) | 40 (×0,5 au tap) | corruption +15 %, 5 s | — | 0,35 s | dégâts 2,1, corruption 1,6 |
| Drain de vie | ténèbres | canalisé, jet | 11 /s | 18 /s, rend 60 % | corruption +10 %, 3 s | 8 m | — | dégâts 1,9, drain 1,3, +1 cible |
| Explosion obscure | ténèbres | zone visée chargée 1 s, vortex | 48 | 34 | corruption +20 %, 6 s | 14 m, rayon 3,5 | 6 s | rayon 1,5, attraction 1,5 |
| Rayon du néant | ténèbres | chargé 1,4 s, rayon qui traverse 3 | 52 (×0,55 sans charge) | 78 (×0,4 sans charge) | corruption +20 %, 6 s | 32 m | 3 s | dégâts 2, largeur 1,4 |
| Rayon noir | ténèbres | canalisé, rayon continu (s'arrête au 1er obstacle ou ennemi) | 9 /s | 15 /s, rend 10 % | corruption +12 %, 3 s | 13 m | — | dégâts 2, coût 2,2, largeur 1,5, portée 1,2 |
| Soin | soin | canalisé, soi | 12 /s | soin 16 /s | — | — | — | soin 1,9 |
| Protection | protection | canalisé, soi | 5 /s + 0,4 par point absorbé | absorbe 60 % (coups) / 85 % (sorts) de face, cône 120° | — | — | jamais interrompue | réduction × 1,25 (plafond 90 / 97 %) |
| Lame ardente / de givre / d'orage / des ténèbres | 4 écoles | enchantement | 35 | +5 par coup d'épée | brûlure / gel / choc / corruption | 30 s | 2 s | — |

Le doc affichait avant le 2026-11-05 des valeurs qui n'étaient plus celles des données (audit : jet 20 contre 15, boule 34 contre 24,
éclat 8 ×3 contre 6 ×3, lance 40 contre 28, arc 24 contre 18, chaîne 24 contre 18, enchantement +7 contre 5) et ignorait trois
sorts (souffle de givre, orage runique, rayon du néant). **Les `.tres` sont la source ; ce tableau les suit.** `outils/generer_sorts.gd`
(ancien générateur des douze premiers sorts) est PÉRIMÉ : ne pas le relancer, il écraserait les `.tres` de valeurs anciennes.

### Équilibrage (changement n°10 de l'audit, 2026-11-05, branche nuit/magie)

Constat (audit combat, écart 4) : la mêlée donne ~40 dégâts/s presque sans limite (14 par clic, un clic toutes les ~0,3 s, vigueur peu
entamée) ; les sorts font 15-28 /s ou par tir pour 8-52 de mana, soit 100 à 225 dégâts par réservoir de 100 : pas de quoi tuer deux
draugrs (104 PV depuis le +30 % de la nuit), alors qu'ils ne coûtaient déjà rien à lancer. **Objectif** : la magie VAUT la mêlée sans
l'écraser (piège de Lunacid : magie qui rend la mêlée inutile). Répartition voulue :

| | Mêlée | Magie |
|---|---|---|
| Dégâts soutenus au contact | **avantage** (~40 /s, sans mana) | 15-24 /s pour 11-14 de mana /s ; le réservoir s'épuise en 6-8 s |
| Distance | portée de l'épée | **avantage** (9 à 32 m) : le mage tue sans être touché tant qu'il a de l'espace |
| Contrôle | garde, parade, étourdissement de posture | **avantage** : gel (ralentit), choc (interrompt), zones, vortex, brûlure |
| Groupes | un coup, une cible | **avantage** : explosions, chaîne, jets qui traversent |
| Endurance | vigueur 100 (esquive 20) | mana 100 : 2 draugrs max par réservoir, puis il faut temporiser |

Réglages (cohérents sur les 21 sorts : les sorts à dégâts directs visent **~1,6-1,9 dégât effectif par point de mana** sur un draugr, les
zones et chaînes un peu moins en cible unique mais davantage en groupe ; ténèbres ×0,7 sur les morts-vivants est compensé par le
prix) :

| Sort | Avant | Après | Pourquoi |
|---|---|---|---|
| Trait d'ombre | 14 dégâts, 10 mana | 20, 9 | le sort le plus faible : 100 mana pour un draugr (ténèbres ×0,7 sur les morts-vivants) |
| Arc électrique | 18 /s | 24 /s | valeur du doc d'origine ; 81 mana par draugr, 2 draugrs impossibles |
| Chaîne d'éclairs | 18 | 24 | idem (−25 % par rebond) |
| Lance de givre | 28 | 38 | 26 mana pour 28 : la pire efficacité de la glace ; le doc disait 40 |
| Souffle de givre | 14 /s | 16 /s | aligné sur le jet de flammes + gel |
| Nova gelée | 18 | 24 | sort de contrôle de zone à 40 mana |
| Explosion incendiaire | 30 | 38 | valeur du doc d'origine, 42 mana |
| Explosion obscure | 28 | 34 | ténèbres ×0,7 sur les morts-vivants ; valeur du doc |
| Drain de vie | 13 /s | 18 /s | rend 60 % des dégâts : sa raison d'être est la survie, pas le coût |
| Mana hors combat | 7 /s | 18 /s après 4 s sans lancer | le mage qui a fini son combat repart plein en ~6 s (avant ~14 s) |
| Inchangés | | | boule de feu 25 (coût de pleine charge, 177b367e), jet de flammes 15 /s, éclat de glace 6 ×3 (8 mana), tempête, orage, rayon, soin, protection, enchantements (+5) |

**Banc « bot mage »** : `outils/test_mage_bot.gd` (voir « Tests »). Mesures du 2026-11-05 (graine fixe, draugrs de 104 PV, départ à 5,4 m comme le banc de
mêlée, 2 essais contre 1 draugr, 2 contre 2 ; le bot est un PLAFOND d'efficacité : il vise toujours) :

*Mage « naïf »* (il tient sa place, ne recule pas, ne se défend jamais : l'équivalent du bot qui spamme la mêlée). Référence mêlée : **1 draugr en 3,6 s, 23 PV perdus ; 2 draugrs en 5,7 s, 50 PV perdus.**

| Sort (simple) | 1 draugr AVANT | 1 draugr APRÈS | 2 draugrs AVANT | 2 draugrs APRÈS |
|---|---|---|---|---|
| Boule de feu (25 mana) | 4,1 s, 0 PV, 28 mana restants | inchangé | 7,1 s, 17 PV, 7 mana | inchangé |
| Éclat de glace (8 mana) | 3,2 s, 0 PV, 44 mana | inchangé | 7,1 s, 33 PV, 6 mana | inchangé |
| Arc électrique | **18,1 s, il meurt (0 kill sur 2), 100 PV** | 4,6 s, 0 PV, 38 mana | **meurt, 0 kill** | 6,4 s, 0 PV, 13 mana, 2 tués (rebond) |
| Trait d'ombre | 5,6 s, 16 PV, **0 mana** | 3,4 s, 0 PV, 37 mana | **meurt, 0 kill** | 11,9 s, 95 PV, 50 % de morts, 50 % tués |

Doubles (même sort aux deux mains) : 1 draugr en 1,7-2,6 s (mana restante 0-32) AVANT et APRÈS pour feu / glace ; arc 10,6 s et 63 PV → 2,4 s et 0 PV ;
trait d'ombre 8,6 s et 38 PV → 1,9 s et 0 PV. Contre 2 draugrs le double immobile reste fragile (une incantation longue se fait interrompre : 1 essai sur 2 se
termine mal), c'est voulu : le double est un coup de force à placer, pas une garde.

*Mage qui gère sa distance* (marche arrière à 2,6 m/s quand un draugr est à moins de 4 m, temporise quand la mana est vide, esquive à ~0,1 s de l'impact ; fond de salle à 1,5 m) :
**aucun PV perdu, tous les draugrs tués, 0 mort, pour les 8 configurations** (APRÈS). Durées : 1 draugr 1,7-4,6 s, 2 draugrs 6,4-13,8 s, mana restante 0-44 (simples).
Indicatif (départ à 9 m, bot sans fond de salle, AVANT) : arc 6,4 s / 81 de mana, 2 draugrs tués dans 50 % des cas en 30 s ; trait d'ombre 5,1 s / 100 de mana, 2 draugrs tués dans
17 % des cas ; APRÈS : arc 5,0 s / 62, 2 draugrs en 21 s à 100 % ; trait 3,5 s / 63, 2 draugrs en 14 s à 100 %.

Lecture : la boule de feu et l'éclat de glace étaient déjà au niveau (zone + brûlure ; gel + posture brisée) ; le déséquilibre venait de l'arc électrique et du trait d'ombre
(un draugr = 81 à 100 mana, un deuxième hors de portée), corrigés. Un mage qui reste planté sous les coups paie autant que le guerrier qui spamme (17-95 PV contre 2 draugrs) : la magie
récompense la distance, pas l'inertie. Les sorts de zone ou à rebond (boule, arc, chaîne) battent la mêlée contre un groupe ; la mêlée garde l'avantage au contact sans limite de mana.

Stagger (posture ennemie) : 5 à 30 par coup (CANALISE : par seconde) ; ≥ 24 = « puissant ». Les sorts passent par la même
posture / réaction que l'épée : un mage nordique (seuil 7) est interrompu par presque tout, un draugr titube sous une boule
chargée, le troll (poids 2) encaisse. Interruption du JOUEUR : un coup reçu ≥ `seuil_interruption` (8, jets 10, protection
jamais) coupe incantation / charge / canalisation (récupération 0,5 s, rien n'est lancé, rien n'est payé pour une charge).

### Le risque de la distance (2026-11-11, branche gameplay/magie_risque)
But : pas de spam sûr à distance. Le mage paie déjà la mana, la charge et l'interruption (coup ≥ 8 = sort coupé) ; s'y ajoute
une **exposition** : lancer un sort se voit, et les ennemis y répondent. Réglages : `ReglagesCombat` (bloc « distance risquée »).
- **Lanceur** (`MainSort.est_lanceur()`) : vrai tant qu'une main incante / charge / canalise, et pendant `LANCEUR_MEMOIRE` = 2,5 s
  après un lancer (`t_sans_sort`).
- **Charge** (draugr.gd, TRAQUE) : un ennemi courant (draugr guerrier / squelette / bandit ; ni zombie, ni chef, ni archer) qui
  traque un lanceur court à `CHARGE_LANCEUR` = 1,4 × sa course (3,4 → ~4,8 m/s) **jusqu'à sa portée d'attaque**
  (`CHARGE_DIST_MIN` = 0) : la marche arrière (2,6 m/s) ne garde plus la distance, seul le sprint (vigueur) la reprend. Avec un
  seuil à 3 m, le draugr repassait à la marche (1,2 m/s) et le mage qui recule tenait 3 m indéfiniment (0 coup au banc) : corrigé.
- **Esquive des projectiles** : chaque projectile de sort du joueur (groupe `projectiles_joueur`, posé par `LanceurSorts`) est
  jugé UNE fois par ennemi courant, entre 0,18 et 0,9 s avant l'impact et à moins de 1,2 m de sa ligne : chance
  `(40 - v) / 40` plafonnée à 50 % (boule de feu 24 m/s ~ 40 %, trait d'ombre 30 m/s ~ 25 %, éclat 34 m/s ~ 15 % ; arc / jets
  canalisés : jamais). Succès : pas de côté de 5 m/s pendant 0,4 s, puis 2 s sans nouvelle esquive. Le tir rapproché ou le sort
  rapide passe ; le tir lent de loin se voit venir.
- **Archers** : recharge × `ARCHER_CADENCE_LANCEUR` = 0,65 contre un lanceur (ils punissent le mage planté à distance).

Banc `test_mage_bot` (graine fixe, n = 6 essais contre 1 draugr / 3 contre 2, départ 5,4 m), AVANT (28409609) → APRÈS :
| Bot | Mesure | AVANT | APRÈS |
|---|---|---|---|
| parfait (recule, esquive 100 %) | PV perdus, 16 lignes | 0 partout sauf trait d'ombre ×2 draugrs 4,4 | 0 partout sauf trait d'ombre ×2 draugrs 1,8 ; durées ±1 s ; seuils OK |
| `--esquive=0.6` (joueur réel) | PV perdus cumulés (16 lignes) | 98 | **216** (glace ×2 draugrs 19 → 39 ; ombre ×2 12 → 36 ; ombre double ×2 23 → 61, 1 mort sur 3) |
| naïf (planté, sans défense) | PV perdus contre 1 draugr | feu 2, glace 7, arc 0, ombre 20 | feu 21, glace 16, arc 9, ombre 24 (mêlée qui spamme : 23) |
| naïf | PV perdus contre 2 draugrs | feu 12, glace 47, arc 0, ombre 98 | feu 42, glace 66, arc 36, ombre 89 |
Lecture : le combat reste gagnable (bot parfait : 100 % tués, 0 mort, 2,4-23,5 s ; joueur à 60 % d'esquive : 100 % des combats à
1 draugr gagnés en 2,4-7,2 s), mais rester planté à distance coûte désormais autant que la mêlée qui spamme, et un joueur qui
rate ses esquives paie le double. `--esquive=<p>` (0-1) : chance de réussir chaque esquive ; en dessous de 1 le banc MESURE
(les seuils, calibrés sur le bot parfait, n'échouent pas).

### Double incantation (phase 3)
Même sort dans les deux mains, seconds appuis dans les **0,15 s** : la main « meneuse » lance la version double (données ×
`double` du sort), la « suiveuse » l'accompagne (pose rapprochée, aura × 1,5, `EffetsMagie.double`). Relâcher l'une des
deux mains termine un double chargé ou canalisé. Au-delà de 0,15 s : deux sorts séparés. Feu + feu : jet élargi, débit et
mana accrus ; glace + glace : lance massive + 2 cristaux, ralentissement renforcé (6 éclats pour l'éclat) ; électricité :
arc plus puissant, propagation (+2 / +3 rebonds) ; ténèbres : drain renforcé, vortex plus grand, corruption prolongée.

## Statuts (`Statuts`, centralisés)

| Statut | Effet | Durée / puissance |
|---|---|---|
| brûlure | dégâts de feu `puissance`/s (tics 0,5 s, résistance de la cible, sans arrêt sur image) ; troll : pas de régénération | 3-4 s |
| brûlure obscure | idem en ténèbres, rend 30 % au lanceur (réaction flammes obscures) | 5 s |
| gel | vitesse (déplacement + animation de marche) × (1 − puissance), plafond 0,9 | 2,5-4 s |
| choc | titube `puissance` s (`subir_choc` si l'ennemi le définit, sinon `_tituber`), puis **1,5 s d'immunité** | 0,3-0,8 s |
| corruption | dégâts reçus + puissance (plafond + 40 %) | 3-6 s |
Durées : la plus longue l'emporte ; puissances : la plus forte. Le mannequin compte les dégâts de statut dans son total.

## Réactions entre écoles (phase 4, `data/magie/reactions.json`)

Règle : un sort (ou une lame enchantée) de l'école X touche une cible qui porte le statut S. La réaction **consomme S**,
coûte au lanceur un **supplément de mana** (sans ce mana : coup normal, pas de réaction), remplace la pose du nouveau statut,
et la cible ne peut plus réagir pendant `recharge_cible`. Dégâts plafonnés à ~1 sort léger (10-22) : rien de trop puissant.

| Réaction | Statut × école | Effet | Coût | Recharge cible |
|---|---|---|---|---|
| Vapeur | gel × feu, brûlure × glace | 18 dégâts rayon 2,5 m, cibles aveuglées (choc 0,6 s) | 6 | 2,5 s |
| Décharge | gel × électricité | 22 dégâts rayon 3 m, choc 0,8 s à toute la zone | 8 | 3 s |
| Décharge incendiaire | brûlure × électricité | 16 dégâts de feu rayon 2,5 m, brûlure propagée aux voisins | 7 | 3 s |
| Cristaux corrompus | corruption × glace | 20 dégâts rayon 1,5 m, gel 0,65 pendant 3 s | 7 | 3 s |
| Flammes obscures | corruption × feu, brûlure × ténèbres | 10 dégâts + brûlure obscure 6 /s 5 s (rend 30 %) | 6 | 4 s |
| Arcs violets | corruption × électricité, choc × ténèbres | 12 dégâts, saute vers 2 voisins (5 m) et les corrompt | 6 | 3 s |

## Épée + magie : combos et enchantements (phase 5)

- **Enchanter la lame** (4 sorts, main gauche, épée à droite) : 35 mana, incantation 0,5 s (la main passe le long de la
  lame), 30 s ; chaque coup d'épée ajoute 5 dégâts de l'école (× résistance de la cible) et pose son statut ; le modèle et la
  texture de l'arme ne changent pas (`EffetsMagie.enchant_arme`) ; relancer rafraîchit ; ranger l'épée l'efface.
- **Combos** (coup d'épée léger / lourd / contre sur une cible qui porte un statut, `combos_epee`) :
  embrasement (brûlure : × 1,3, brûlure prolongée de 2 s), brise-glace (gel : × 1,5 dégâts et stagger, gel consommé),
  ouverture (choc : × 1,3, stagger × 2), moisson (corruption : × 1,2, 25 % rendus en vie, corruption consommée).

## Réactions des ennemis

- Draugrs / squelettes / bandits (draugr.gd) et EnnemiBase : gel = ralentis ; choc = titubent (attaque interrompue) ; face à un lanceur : chargent, esquivent parfois les sorts lents (voir « Le risque de la distance ») ;
  les sorts usent la posture comme l'épée (étourdi → finisher). Morts-vivants : ténèbres × 0,7, feu × 1,25.
- Troll de givre : feu × 1,75, glace × 0,25 ; brûlure = pas de régénération ; **peur du feu** : déjà en flammes et touché
  par le feu, il recule d'effroi (4 m/s, 0,7 s ; une fois toutes les 6 s ; jamais en rage, étourdi, sonné ou en charge) ;
  choc moitié moins long, ignoré en rage / charge.
- Mage nordique : un choc interrompt toujours son sort ; électricité × 1,3.

### Mage ennemi sur le système de magie
Ses sorts sont des `DonneesSort` (`data/sorts/ennemis/`) lancés par `LanceurSorts` (camp « joueur ») : mêmes projectiles
(`ProjectileSort`), mêmes visuels (`EffetsMagie.aura_main` dans sa main gauche, `projectile_visuel`, `impact`, `zone`).
Trait de givre (11 m/s, 14 dégâts, gel → `joueur.ralentir(1,8 s, × 0,55)`), trait d'ombre un tir sur trois (15 m/s, 11
dégâts, vole 12 de mana), pics de givre (zone télégraphiée 1,4 s, 22 dégâts, 50 % traversent la garde, ralenti 2,5 s × 0,5).
Comportement inchangé (distance 7-13 m, téléport, fragile, mort marquée) ; la protection du joueur absorbe ses sorts (85 %).

## Animations des mains (PosesIncantation, MainSort._poser_mains)

Poses (repère caméra, main gauche ; la droite en miroir) : repos (main levée, lueur dans la paume), incante (la main
monte et s'ouvre), charge (griffe) / poing (boule, lance), lance (bras tendu), canalise (doigts écartés), levée (zone :
paume au ciel puis frappée vers le sol), soi (soin, protection), lame (enchantement), écartée (l'épée frappe : la main du sort
s'écarte en contrepoids), double (mains rapprochées) ; repos recalé le 2026-10-27 sur la tenue validée (main basse à gauche, paume
vers le haut, aura visible ; le bouclier n'est plus une pose de sort : GestesBouclier). Appliquées APRÈS la pose de l'épée par
mains.gd : cible d'IK de la main (`pivot_torche` / `pivot_epee`), orientation libre du poignet pendant l'incantation, coude
écarté, doigts mélangés entre la pose de repos du squelette (ouverte) et le poing (`mains._doigts`). Ressort de 16 /s,
tremblement léger en canalisation et à pleine charge. Le geste de l'épée (clés, rig, bras_fps.glb) n'est jamais modifié.

### Gestes Mixamo (2026-10-29, branche magie/gestes_mixamo)

Les gestes de lancer viennent de captures de mouvement Mixamo (« Magic Spell Pack », gratuit, usage commercial permis ;
les `.fbx` restent dans `references/mixamo/magic_spell_pack/`, **jamais commités** : seules les données converties le sont),
retargetées comme les coups d'épée (`anim_bras_epee.py`, « Coups Mixamo ») :

1. `sources_blender/scripts/extraire_mixamo_magie.py` (Blender, `-b`) : positions des deux bras (épaule, coude, poignet, base de
   l'index / de l'auriculaire / du majeur, bout du majeur) relatives au cou, repère caméra -> `sources_blender/mixamo/gestes_magie_mixamo.json`
   (`--tous` : tout le pack, pour choisir).
2. `sources_blender/scripts/gestes_magie.py` (Python 3 seul) : la capture pilote le corps, la caméra est la tête ; on garde les
   DIRECTIONS épaule -> coude -> poignet posées sur notre bras FPS (épaules (±0,212, -0,314, -0,092), bras 0,251, avant-bras 0,244 :
   `outils/captures_gestes_magie.gd --bras`), la main portée par l'avant-bras (flexion / inclinaison du poignet = celles de la capture),
   puis par geste : amplitude (ramenée vers l'image « centre »), cadrage (rotation autour de l'épaule), « poignet » (extension ajoutée
   pour tourner la paume vers la cible, en rampe pendant la poussée), cadre (paume dans l'écran, devant l'œil, à 0,55 m au moins),
   butées du poignet (extension 70°, flexion 60°, cubitale 30°, radiale 20°) sur l'avant-bras que donne l'IK, fondu depuis / vers la
   pose de repos actuelle (inchangée), fermeture des doigts lue sur la courbure du majeur, pôle du coude = coude de la capture
   -> `data/magie/gestes_mixamo.json` (poses au format PosesIncantation + `coude`).
3. `GestesMagie.pose()` (une instance dans MainSort) : incantation -> phase `entree` (u = t / incantation), charge -> `tenue`
   (u = charge), canalisation -> `boucle` (maintien, aller-retour), après le lancer -> `depart`, après un jet -> `fin` ; ces deux
   dernières continuent au repos jusqu'à la pose de repos. MainSort applique la pose (ressort 34 /s au lieu de 16, pôle du coude
   lissé) ; l'écart de la main quand l'épée frappe et le tremblement restent. Interruption : retour aux poses fixes.

| Geste (sorts) | Clip Mixamo, piste | Phases |
|---|---|---|
| `lance` : sort rapide à une main (éclat de glace, trait d'ombre, chaîne d'éclairs) | Standing 1H Magic Attack 01, main droite (miroir pour la gauche) | armé 12->20 pendant l'incantation, poussée paume en avant, retour |
| `charge` : sort chargé (boule de feu, lance de givre) | même clip : l'armé (13->18) est TENU, poing fermé, pendant la charge | entree, tenue, depart |
| `jet` : jet tenu à une main (jet de flammes, arc, drain) | Standing 2H Magic Attack 03, main gauche (miroir pour la droite) : maintien bras tendu ~2 s | entree 24->33, boucle 36->96, fin |
| `double` / `double_charge` / `double_jet` : double incantation | Standing 2H Magic Attack 04, chaque main SA piste (paumes jointes en avant) | rapprochement, poussée, maintien |
| `zone` : explosion, tempête statique, nova | Standing 2H Magic Area Attack 01, main gauche (miroir pour la droite : la piste droite roule la main d'un tour complet) (main levée poing fermé, frappe vers le sol) | entree 26->31, tenue, depart |

Poses fixes gardées : soin / protection (`soi`), enchantement de la lame (`lame`), repos, écart pendant un coup d'épée.
Écartés : 1H Cast Spell 01 (main levée au-dessus de la tête : hors champ), 1H Attack 02 / 03 (balayage qui traverse l'écran,
lancer par en dessous), 2H Attack 01 / 02 / 05 et Area Attack 02 (mains derrière la tête ou écartées hors champ), Sword And Shield
Casting (bras gauche levé derrière la tête). `GestesMagie.actif = false` rend les anciennes poses (planches avant / après).
Films et planches : `outils/captures_gestes_magie.gd` (`--geste=… [--ralenti=0.5] [--avant] [--vue=face|cote]`, `--planche=`), tests `test_gestes_magie`, `test_articulations_magie`.

**Avant-bras sans dislocation** (même cause que les coups d'épée, `anim_bras_epee.py` b720b15) : le rig n'a pas d'os de torsion,
toute la pronation tombe au poignet. Mesuré sur 18e103d : la capture roulait la main jusqu'à 195° autour de l'avant-bras
(et d'un tour complet sur la piste droite de la zone), jusqu'à 38° par image à 60 i/s au début du geste (cible de la main qui
suit une incantation courte), plan du coude jusqu'à 20° par image (zone). Correctif :
- `gestes_magie.py` : pronation mesurée sur le plan du coude (repère de lowerarm), suivie CONTINÛMENT d'une phase à l'autre
  (pas de saut de ±360°), bornée en douceur à -40..+125° depuis la pose de repos (`PRONATION`, marge 20°) ; la main tourne autour
  de l'avant-bras (flexion / inclinaison du poignet inchangées). Zone : la main droite joue le miroir de la piste gauche.
- `GestesMagie.pas_rotation` / `limiter_pole` (appelés par MainSort pendant un geste capturé seulement) : rotation de la main
  ≤ 480°/s (8° par image à 60 i/s), pôle du coude ≤ 420°/s autour de l'épaule (le plan du coude ne bascule plus).
- `test_articulations_magie` (pose finale du squelette, après IK et OrientationMain, deux bras, 60 et 30 i/s).

## Télékinésie (école « esprit », 2026-11-23, branche magie/telekinesie)

Référence : `references/insta_2026-11-23/Df0KoxniPDA.mp4` (main tendue, épée qui lévite entourée d'étincelles, projetée dans un
squelette). Code : `scripts/magie/telekinesie.gd` (`Telekinesie`, un nœud enfant de MainSort), `arme_telekinesie.gd` (arme posée changée en
corps), `corps_telekinesie.gd` (prop physique de test / démo), `shaders/magie_telekinesie.gdshader` (lueur), `data/sorts/telekinesie.tres`.

- **École** : nouvelle école `esprit` (le système de données le permet : `DonneesSort.ecole` est une chaîne, les coûts passent par
  `Progression.facteur_cout_sort`). Les visuels DE LA MAIN reprennent ceux de `protection` (aura bleu pâle, son de charge) :
  `Telekinesie.ECOLE_VISUELLE`, appliqué par `MainSort._aura_vers` ; l'école n'a pas d'aura propre dans GestionMagie (à faire si l'école
  grandit : Répulsion, Lévitation d'ennemi, Attraction). Type CANALISE, portée `DonneesSort.Portee.TELEKINESIE` (nouvelle valeur, en fin
  d'énumération : les .tres existants ne bougent pas). Pas de double incantation (`double = {}`).
- **Contrôles** : `X` (action `telekinesie`, remappable dans Options > Touches) met le sort dans la main gauche (épée à droite gardée) ;
  second appui = main d'avant. Clic droit MAINTENU en visant un objet : il s'arrache (à-coup vers le haut, poussière, éclat) puis lévite
  devant la main (~2 m, décalé de son côté), suit le regard avec un ressort amorti (raideur 7,5, amorti 9), tremble et tourne lentement ;
  collisions gardées (il bute sur les murs ; coincé > 0,6 s à plus de 3,5 m de sa place : lâché). Molette : rapprocher / éloigner
  (1,3-3,2 m). RELÂCHER : lancé vers le réticule (trajectoire corrigée de la gravité), aide à la visée 8° vers l'ennemi le plus proche
  du réticule. Relâcher avant 0,12 s de tenue : l'objet tombe. Un coup reçu ≥ 14 coupe la tenue (l'objet tombe).
- **Visée** : candidats = groupe `telekinesable` + (repli) petits objets vivants (`ObjetVivant`) ; aide douce de 7° élargie de la taille
  apparente de l'objet, portée 14 m, pas à travers un mur ; l'objet visé est en SURBRILLANCE (lueur faible) dès que le sort est en main.
- **Mana** : arrachement `8 + 0,8 × masse` ; drain `3 + 0,35 × masse` par seconde. Chaise 7 kg : 13,6 puis 5,5 /s ; épée 1,6 kg : 9,3 puis
  3,6 /s ; tonneau 28 kg : 30,4 puis 12,8 /s. Masse max 60 kg (« Trop lourd. ») ; « Pas assez de mana. » si l'arrachement ne se paie pas ;
  mana à zéro pendant la tenue : l'objet tombe (« Mana épuisé. »).
- **Lancer** : vitesse `lerp(12, 24, charge) × clamp((4 / masse)^0,3, 0,5, 1,25)` m/s, charge = (tenue − 0,2 s) / 0,9 s : chaise 10-20 m/s,
  tonneau 6,5-13, épée 15-30. Une arme vole POINTE EN AVANT (+Y de la lame aligné sur la vitesse à chaque pas).
- **Impacts** (intégration 2026-11-23) : au lâcher et au lancer, `ImpactsLances.suivre(objet, joueur)` (SuiviLancer : balayage, lame stabilisée nez en avant) fait TOUTE la détection ; la détection et le repli ci-dessous de Telekinesie ne servent plus que sans ImpactsLances. Une arme plantée se ressaisit (`saisi_telekinesie(true)` l'arrache, giclée). Avant l'intégration : à chaque contact rapide (> 6 m/s) d'un objet lancé — balayage de la trajectoire contre la
  capsule de chaque ennemi, contacts physiques avec le décor — `ImpactsLances.objet_touche(objet, cible, point, normale, vitesse, lanceur)`
  si la classe existe (cherchée dans `ProjectSettings.get_global_class_list()`), sinon REPLI : dégâts par `LanceurSorts.frapper` (chemin des
  sorts : perks, résistances, réseau) = `0,22 × masse^0,83 × vitesse` contondant (chaise à 20 m/s ≈ 22, tonneau à 10 m/s ≈ 35) ou
  `dégâts lourds de l'arme × clamp(v / 24, 0,5, 1,4)` tranchant ; l'arme se plante (suit la cible jusqu'à sa mort) ou TRAVERSE si elle tue ;
  `recevoir_choc(vitesse, masse, point)` de l'objet et de ce qu'il percute (contrat cassables), sinon `frapper` des Cassable / ObjetVivant.
  Méta posées pendant le vol : `lance_par` (joueur), `lance_jusqu_a` (horloge de Telekinesie).
- **Armes** : `ObjetMonde.creer` d'une arme et l'arme lâchée par un ennemi mort (`ArmesEnnemis.poser_au_sol`) entrent dans le groupe
  `telekinesable` (meta `tk_arme`) ; à la saisie elles deviennent une `ArmeLancee` (scripts/combat/arme_lancee.gd, intégration 2026-11-23 : la seule classe d'arme lancée ; `Telekinesie.arme_depuis_visuel`) (corps rigide,
  masse = `DonneesArme.poids`) ; l'arme quitte le butin du corps (pas de double) ; au repos après le vol, elle reste posée, gelée,
  RAMASSABLE (« Prendre ») et de nouveau saisissable. Râteliers de la crypte : armes fondues dans le décor, PAS saisissables (limite).
- **Effets** (DA PS1, paliers francs, pas de tramage) : coque additive bleu pâle sur l'objet (bord + motes qui montent + onde, accrochée à la
  grille ps1), étincelles fines qui s'élèvent de l'objet et halo doux, fil d'énergie à deux brins de la paume à l'objet (traits de la couche
  fine) avec des étincelles qui courent dessus, lumière bleue qui suit l'objet ; poussière au sol et éclat à l'arrachement ; éclat et
  traînée au lancer ; la lueur s'éteint en 0,6 s. Réglages de particules `tk_*` ajoutés à `PresetsMagie.R` au premier usage.
- **Sons** : `esprit_saisie_1/2`, `esprit_lancer_1/2`, boucle `esprit_tenue` (`outils/sons_magie/generer_telekinesie.sh`, synthèse + CC0),
  `SonsMagie.telekinesie_saisie / _lancer / _tenue`.
- **Gestes** : maintien = geste capturé `jet` (boucle bras tendu), relâcher = départ du geste capturé `lance` (`GestesMagie.forcer`) ;
  aucune pose écrite à la main. FPS et TPS (les effets partent des paumes du corps en 3e personne, `MainSort._p`).
- **Réseau** : saisie / positions de tenue (10 /s) / lancer / lâcher annoncés (`tk_saisie`, `tk_tenu`, `tk_lancer`, `tk_lacher`), l'objet
  repéré par `ObjetVivant.ident` ou son chemin dans la scène ; chaque machine fait voler sa copie, seuls les impacts du lanceur comptent
  (dégâts de repli : `LanceurSorts.frapper` délègue à l'hôte pour un invité). LIMITES : non essayé à 2 PC ; une arme changée en
  ArmeLancee créée à la saisie n'existe que chez le lanceur (les autres voient l'arme rester au sol).
- **Interrupteur** : `-- --sans-telekinesie` (le sort n'existe pas : ni connu, ni raccourci, ni groupe sur les armes).
- **Test** : `bash outils/tous_les_tests.sh test_telekinesie` (37 vérifications). **Film** : `outils/film_telekinesie.gd` (crypte, pilote).

## Sorts de l'esprit : Répulsion, Lévitation d'ennemi, Attraction (2026-11-23, branche magie/sorts_esprit)

Autour de la télékinésie (même école `esprit`, même lueur bleu pâle, mêmes paliers de particules fines, pas de tramage). Code :
`scripts/magie/sorts_esprit.gd` (`SortsEsprit`, nœud enfant de MainSort « SortsEsprit »), `data/sorts/repulsion.tres`, `levitation.tres`,
`attraction.tres` ; trois valeurs ajoutées EN FIN de `DonneesSort.Portee` (REPULSION, LEVITATION, ATTRACTION : les .tres existants ne
bougent pas) et un groupe d'exports « Esprit ». Les ennemis pris (vol, tenue, vortex) ont leur `_physics_process` coupé (IA, gravité) ;
SortsEsprit les déplace (`move_and_collide`) et le leur REND toujours à l'atterrissage, à terre : draugr en CHUTE (Death01, ~1,3 s au sol,
il se relève et repart en TRAQUE), troll SONNE, autres `_reagir("lourd")` ; vol coupé après 3 s quoi qu'il arrive ; mort en vol = son
ragdoll prend le relais. Pas d'IA bloquée (test_sorts_esprit, « il s'est relevé et reprend le combat »).

- **Contrôles** (raccourcis de test, main gauche comme `X` ; remappables dans Options > Touches ; second appui = main d'avant) :
  `G` Répulsion, `N` Lévitation, `U` Attraction. Clic droit pour la main gauche.
- **Répulsion** (type CHARGE, geste capturé `charge` puis départ) : maintenir charge (1,2 s), relâcher = onde de choc en cône (demi-angle
  35°) devant la main, portée 4 m (tap) à 8 m (pleine charge). Ennemis : vitesse `lerp(6, 11, charge) × k × clamp(1/√P, 0,3, 1,15)` (k : 1 près, 0,45 au
  bout ; P : puissance, voir plus bas), un tiers vers le haut ; moins de 3,5 m/s = simple recul ; chefs ×0,25 (ébranlés, pas envolés).
  Dégâts directs `12 × lerp(0,4, 1, charge) × k` contondant + choc. Objets (groupe `telekinesable`, objets vivants, cassables) :
  `1,25 × force × k × clamp((4/masse)^0,3)` m/s, suivis par la télékinésie pour leurs impacts (ImpactsLances, `recevoir_choc` : ils
  cassent contre les murs). Coût `28 × lerp(0,4, 1, charge)` : 11,2 au tap, 28 à pleine charge (ChargeSort, MainSort._lancer).
- **Chocs** d'un ennemi projeté (Répulsion, Lévitation, Attraction) : contre un mur `(v − 2,25) × 1,8` dégâts (v : vitesse contre la
  surface, à partir de 4,5 m/s ; 12 m/s ≈ 17), stagger 32 ; contre un autre ennemi : les deux encaissent (×0,8 pour l'autre, emporté s'il
  n'est pas un chef) ; contre un cassable : `recevoir_choc(v, 70 kg × P, point)` — y compris les urnes, tonneaux et meubles que son
  corps TRAVERSE (leur calque n'arrête pas un corps d'ennemi : balayage autour de lui, une fois par objet ; sinon ils sont poussés) ;
  chute : `(vy − 7) × 3` au-delà de 7 m/s.
- **Lévitation d'ennemi** (type CANALISE, geste `jet` tenu puis `lance`) : maintenir en visant un ennemi (aide 9°, portée 16 m, pas à
  travers un mur, surbrillance de la cible) : il est arraché (0,4 s de montée), puis suit le regard à 3-4,2 m (son centre sur la ligne du regard, pieds 0,45 à 1,1 m au-dessus du sol d'où il a été arraché), par un
  ressort LOURD (raideur 4,2, amorti 5,5, vitesse max 8 / √P m/s) ; il tangue, rejoue ses coups encaissés, ses membres battent
  (ReactionOs), lueur et fil d'énergie à trois brins. Relâcher = projeté vers le réticule (aide 8° vers un autre ennemi) à
  `lerp(9, 17, charge) × clamp(1/√P, 0,4, 1,3)` m/s (charge = tenue − 0,3 s sur 1 s). Appui bref : il retombe.
  **Mana selon la PUISSANCE** P = PV max (hors échelle coop) / 100 × poids du profil : saisie `8 + 16 × P^0,75`, drain
  `3 + 7 × P^0,75` /s. Refus lisibles : « Trop puissant. » (chef : draugr nommé, groupe `boss`, dragon ; ou P > 10), « Pas assez de
  mana. » ; mana à 0 : il retombe (« Mana épuisé. ») ; P > 3 : il BRISE l'emprise après 8 / P s (« Il brise l'emprise ! », petit bond).

| Ennemi | PV max | poids | P | saisie | drain /s | emprise |
|---|---|---|---|---|---|---|
| Squelette | 65 | 0,8 | 0,52 | 17,8 | 7,3 | illimitée |
| Draugr chétif (sbire) | 60 | 1,0 | 0,60 | 18,9 | 7,8 | illimitée |
| Draugr / bandit | 104 | 1,0 | 1,04 | 24,5 | 10,2 | illimitée |
| Draugr ancien (guerrier) | 135 | 1,1 | 1,49 | 29,6 | 12,4 | illimitée |
| Mage nordique | 70 | 0,9 | 0,63 | 19,3 | 7,9 | illimitée |
| Troll de givre (mini-chef) | 420 | 2,0 | 8,40 | 86,9 | 37,5 | 0,95 s |
| Chefs (Svanhild, Hrafn, Jarl), dragon | — | — | — | refus | — | — |

  Repère : 100 de mana tiennent un squelette ~11 s, un draugr ancien ~5,7 s ; un troll ne fait que décoller (0,35 s avec 100 de
  mana ; avec 200, il brise l'emprise après 0,95 s). Un squelette lancé à
  ~20 m/s contre un mur : ~32 dégâts (≈ 1,3 dégât par point de mana, plus le contrôle ; comparable au jet de flammes).
- **Attraction** (type RAPIDE, geste `lance`, recharge 4 s) : un point d'énergie (orbe d'étincelles) part à 16 m/s vers le réticule et
  s'arrête au premier obstacle (sur un ennemi visé : sur lui), à au moins 1,2 m du sol ; il s'ouvre en VORTEX 3 s (rayon 5,5 m) :
  étincelles aspirées vers le centre, cœur et anneau au sol spiralés (shader des disques magie_sol, `spirale`), lueur pulsée, souffle
  tournant. Les ennemis sont soulevés et tournent autour du centre en se rapprochant (vitesse 5 / √P m/s), en se débattant ; les chefs
  (et ceux qu'on ne peut plus payer) sont seulement tirés au sol (`_recul`, comme ZoneMagie.attirer). Les objets tournent sans gravité et
  s'entrechoquent au centre. À la fin, tout est RELÂCHÉ d'un coup : petite explosion (éclat, disque, lumière, claquement), 10 dégâts
  contondants, ennemis projetés à 11 / √P m/s, objets à ~13 m/s (suivis : ils cassent). Coût 30 + supplément `3 × P^0,75` par ennemi
  aspiré (squelette 1,8, draugr 3,1, draugr ancien 4,0, troll 14,8).
- **Sons** (`outils/sons_magie/generer_sorts_esprit.sh`, synthèse + CC0) : `esprit_onde_1/2`, boucle `esprit_vortex`, `esprit_vortex_fin`,
  `esprit_emprise` ; tenue et lancer de la lévitation : ceux de la télékinésie. `SonsMagie.esprit_onde / esprit_emprise / esprit_vortex /
  esprit_vortex_fin`.
- **Réseau** : l'HÔTE détient l'IA ; ses vols d'ennemis sont répliqués tels quels (position, lacet, animation : CombatCoop). Un INVITÉ
  ne déplace pas ses marionnettes : il envoie `es_ennemi` (projeter / tenir à 10 /s / lâcher) à l'hôte, qui applique le vol et les chocs
  (dégâts calculés chez l'hôte). Onde, vortex et objets poussés : `es_onde`, `es_vortex`, `es_objets` (visuels et objets rejoués chez les
  autres). Pas de finisher ni de ralenti dans ces sorts (décision coop respectée). LIMITES : non essayé à 2 PC ; chez un invité, un
  ennemi tenu suit avec la latence de l'aller-retour ; les objets aspirés par un vortex distant bougent localement (cosmétique).
- **Interrupteur** : `-- --sans-sorts-esprit` (les trois sorts n'existent pas : ni connus, ni raccourcis).
- **Test** : `bash outils/tous_les_tests.sh test_sorts_esprit` (45 vérifications). **Films** : `outils/film_sorts_esprit.gd --sort=repulsion |
  levitation | attraction` (crypte, pilote, ennemis du film avec leur IA, joueur sans dégâts et non interrompu), rendus dans
  `rendus/telekinesie_2026-11-23/sorts_esprit/`.
- **Coût en jeu (perf)** : rien tant que les sorts ne servent pas (deux dictionnaires vides parcourus par image) ; la surbrillance de la
  lévitation cherche sa cible 10 fois par seconde, sort en main seulement.

## Rayon noir : sort continu des ténèbres (2026-11-23, branche magie/rayon_noir_continu)

Demande : comme le feu, la glace et l'électricité, un sort CONTINU qui coûte peu, « un rayon noir continu », appuyé sur le rayon
tiré d'un coup (rayon du néant), avec de petites runes. Données : `data/sorts/rayon_noir.tres` (CANALISE, portée JET, `forme`
« rayon_noir » : c'est elle, pas le nom, qui choisit le visuel). Tout le reste est le chemin commun des canalisés : tics de 0,2 s
(`LanceurSorts.TIC_CANAL`), coût par seconde (`MainSort`, « Mana épuisé. » à 0), interruption (seuil 10), double incantation
(une main meneuse, UN rayon depuis le point de fusion), geste capturé « jet » / « double_jet », coop (les coups passent par
`frapper` → `ReseauProjectiles.deleguer_coup_sort` ; comme les autres jets, le visuel n'est pas rejoué chez les autres joueurs).
- **Équilibrage** : 9 mana/s (le moins cher des canalisés offensifs : drain 11, souffle 12, jet 13, arc 14), 15 dégâts/s
  (= 3 par tic), corruption +12 % 3 s, drain 10 % (1,5 PV/s : un soupçon de survie, le Drain de vie reste le sort de soin, 60 %),
  stagger 5/s, 13 m. ~1,7 dégât par point de mana (2,0 avec la corruption), dans la cible de l'équilibrage (1,6-1,9), sans zone
  ni traversée (un seul ennemi). Double : ×2 dégâts, ×2,2 coût, ×1,5 largeur.
- **Logique** (`LanceurSorts`, branche `forme == "rayon_noir"` de `canaliser`) : la visée est lissée (`_inertie`, constante
  16 /s : ~15° de retard une image après un coup de 20°, rattrapé en 0,3 s ; demi-tour brusque = pas de balayage), la même
  direction sert aux dégâts et à l'image ; `bout_rayon_noir` : premier décor, ou premier ennemi dans le rayon avant lui ; les
  candidats d'un tic sont triés du plus proche (seul le premier est touché, `traverse` 0) ; `derniers_bouts[main]` (tests).
- **Visuel** (`scripts/magie/rayon_noir.gd`, `RayonNoir`, un nœud par main, piloté par `EffetsMagie.rayon_noir`) : tube de
  `RayonNeant._tube()` + `shaders/rayon_noir_faisceau.gdshader` (dérivé du faisceau du néant : cœur noir, liseré pourpre, filet
  pâle, fumée déchirée et brins enroulés, ONDULATION lente qui court vers la cible et avive le liseré) ; allumage 0,2 s (la tête
  file de la main à la cible), extinction 0,35 s (il se resserre et se dissipe en bouffées le long de l'axe) ; au bout : tache
  d'ombre (`rayon_neant_tache.gdshader`) qui grandit et bouillonne tant qu'on tient le point, balayée elle en laisse jusqu'à 5 qui
  s'effacent en 3 s ; volutes et braises violettes (2 MultiMesh, 26 + 14 au plus) ; fumée qui s'échappe du rayon ; 2 lumières
  violettes faibles du pool (bout et milieu : la crypte se teinte, le noir reste lisible) ; sur un ennemi :
  `ImpactCorps.embraser(.., "tenebres", ..)` toutes les 0,7 s (l'ombre qui rampe, OmbreCorps) + la corruption du statut ;
  RUNES : celles de la main (RunesOrbite, état CANALISE : serrées et vives) et 3 à 5 runes violet pâle (shader des runes) qui
  glissent le long du rayon en tournant autour de l'axe et s'éteignent avant la cible. Ombre au sol (EffetsSol.ombrer) sous le bout.
- **v2 (retour utilisateur : « un effet plus rapide, que ça fasse plus rayon »)** : plus d'ondulation lente ; des IMPULSIONS
  pourpres filent de la main vers la cible (26 m/s, une tous les 1,7 m, ~15 par seconde en un point), stries fines au cœur ; cœur
  noir tendu (bord fixe), liseré fin et vif qui scintille (24 Hz, paliers, sans tramage), fumée plus légère qui ne déforme plus la
  silhouette, évasement au contact réduit (×1,12) ; allumage 0,1 s (le rayon jaillit d'un coup, petit éclair de départ), coupure
  en 0,07 s puis la fumée reste ; runes 2× plus rapides ; orbe de la main ×0,64 pendant ce sort (`RayonNoir.TAILLE_ORBE`).
- **Son** : `outils/sons_magie/generer_rayon_noir.sh` (synthèse ffmpeg) : boucle de 4 s (grondement 41 Hz qui pulse à 0,5 Hz,
  souffle sombre, chuchotements), allumage, extinction ; impact : sons de l'école (EffetsMagie.impact via OmbreCorps / GestionMagie).
- **Raccourci de test** : touche Y (action « rayon_noir », Touches) → main gauche, second appui = la main d'avant ; sort de départ
  (`inventaire.json`) ; icône `rayon_noir` (IconesCombat).
- `--sans-rayon-noir` : le sort n'existe pas (ni connu, ni équipable, ni raccourci) : comportement d'avant.
- Test : `bash outils/tous_les_tests.sh test_rayon_noir` (coût, tics, statut, drain, mur, premier ennemi, relâchement, mana 0,
  double, inertie) ; film : `outils/film_rayon_noir.gd` (crypte, `--perf` = FPS par phase, `--zoom=<fov>` = gros plans).
### Ragdoll de projection puis relevé (2026-11-23, branche magie/ragdoll_esprit)

Demande : « pour la répulsion il faudrait vraiment que l'ennemi soit projeté en mode ragdoll et ensuite qu'il se relève » (référence de
mouvement : la poussée de Force de Star Wars). Code : `scripts/magie/ragdoll_esprit.gd` (`RagdollEsprit`, enfant « RagdollEsprit » de
SortsEsprit, `SortsEsprit.rag`). Branché dans `SortsEsprit.projeter` (Répulsion, Lévitation lancée, relâchement de l'Attraction, ennemi
percuté par un autre) et `SortsEsprit.lacher` (Lévitation lâchée / mana épuisé) ; le vol cinématique d'avant reste le repli.

- **Qui** : ennemis de `draugr.gd` (draugrs, bandits, squelettes : squelette humain de 65 os, `Ragdoll.gd`) qui ont les deux relevés ;
  pas les chefs ; le troll garde sa réaction lourde (SONNE : autre rig, pas de relevé capturé).
- **Vol** : le corps vivant passe en ragdoll (`Ragdoll.declencher`, le même que celui des morts) depuis sa pose animée, à la vitesse de
  l'onde, avec un basculement (`ROULIS` 3 rad/s autour de l'axe perpendiculaire à la poussée : le haut du corps part plus vite) et un peu de
  vrille ; « tonus » léger (`TONUS` 0,35, décroît en 1,6 s, ×0,3 au sol : le corps garde sa tenue en l'air, s'affaisse en touchant) ; os en
  détection continue (CCD : une main à 17 m/s ne traverse pas le mur), sans sommeil. IA, gravité et capsule coupées ; état CHUTE (frappé,
  il ne titube pas). Chocs : perte brutale de vitesse = choc (rayon le long de la vitesse d'avant : mur → `SortsEsprit._choc`, sol →
  dégâts de chute), autres ennemis sur la trajectoire (les deux encaissent, l'autre est emporté), objets traversés (`_chocs_objets` :
  `recevoir_choc`, casse) — mêmes formules et mêmes coûts qu'avant. Au sol : frottement 0,45 (il glisse), puis amorti 0,9 / 5 (il se pose).
  Deux corps de la même onde ne se percutent pas entre eux ; une seconde impulsion s'ajoute sans dépasser la plus forte des deux.
- **Repos** : centre du corps < 0,35 m/s et os le plus rapide < 1,2 m/s pendant 0,3 s (au plus tôt 0,7 s, au plus tard 3,2 s).
- **Relevé** : sur le dos ou le ventre selon le devant du torse (`spine_03`). Clips CAPTURÉS `Releve_Dos` (Mixamo « zombie stand up »,
  images 7-94) et `Releve_Ventre` (« zombie stand up (3) », images 15-104), Not So Scary Zombie Pack déjà utilisé pour les draugrs zombies :
  `sources_blender/scripts/extraire_mixamo_releve.py` → `sources_blender/mixamo/releve_mixamo.json` → `outils/zombie_retarget.gd
  --source=… --sortie=res://assets/modeles/humains/animations_releve.res` (fusionné par `Humain.bibliotheque()`). Joués ×1,5 (~1,9 s).
  Raccord : pose affichée de chaque os capturée (`Ragdoll.pose_monde`), physique coupée (`Ragdoll.arreter`), corps replacé pour que le
  bassin de la 1re image du clip tombe sous celui du ragdoll (lacet aligné sur l'axe bassin → tête du corps couché, pieds sur le sol mesuré
  sous le bassin), puis fondu de pose 0,3 s (`RagdollEsprit.FonduPose`, modificateur après l'animation) : ni saut ni capsule qui bondit (test :
  bassin affiché < 4 cm par image). Si la place debout est dans un mur ou un meuble (Releve_Ventre finit 1,2 m côté pieds), elle est
  rapprochée du bassin et le fondu allongé. Capsule rendue au début du relevé (on peut le frapper), IA rendue à la fin (TRAQUE, Sword_Idle en
  fondu 0,45 s ; `PiedsAuSol._decal` remis à zéro). Onde → IA : 3,4 à 3,9 s (test).
- **Mort en vol ou pendant le relevé** : le ragdoll reste et devient le cadavre ordinaire (`draugr._mourir` réutilise le même Ragdoll).
- **Plafond** : 6 ragdolls en vol à la fois (`PLAFOND`) ; au-delà, vol cinématique d'avant. Rien ne tourne au repos (process coupé tant
  qu'aucun corps n'est suivi).
- **Ciblage** : `draugr.point_impact()` rend le centre du corps en ragdoll (méta `es_centre`) : une seconde Répulsion le retrouve ; la
  Lévitation et le vortex ne saisissent pas un corps en vol (ils reprennent un ennemi qui se relève).
- **Coop** : l'hôte simule et envoie `es_ragdoll` (vol : vitesse + basculement ; relevé : place, lacet, clip). L'invité rejoue un ragdoll
  local cosmétique (sans dégâts ni chocs) puis le même relevé à la place choisie par l'hôte (repli : il se relève seul après 5 s). LIMITES :
  non essayé à 2 PC ; les trajectoires ne sont que voisines (la place finale est celle de l'hôte, le fondu absorbe l'écart) ; pendant le vol
  la racine de l'ennemi reste où il a décollé (position répliquée inchangée).
- **Perf** (crypte, 6 ennemis, Répulsion pleine charge toutes les 4 s, 960x540 sans vsync, `film_ragdoll_esprit.gd --mesure`, A/B
  entrelacé ; machine partagée avec d'autres Godot). Profil par étape (`PROFIL …`) : construire un ragdoll ~1,6 ms (x6 la même image = le
  gros à-coup d'origine), 1re image du clip de relevé ~0,8 ms, vol ~0,3 ms par corps et par image, le reste < 0,3 ms. Correctifs :
  ragdolls construits D'AVANCE quand un sort de l'esprit est en main (`SortsEsprit.preparer_ragdolls`, un par image, os en veille sans
  collision : `Ragdoll.mettre_en_veille`, l'impulsion ne coûte plus que 7 µs de construction) ; ombre fusionnée GARDÉE pendant le vol
  (`declencher(…, garder_ombre)`, plus de refusion au relevé) ; un relevé par image ; balayages du vol (ennemis, objets) une image sur
  deux, sol une sur trois, tonus une sur deux ; CCD seulement aux mains, avant-bras, pieds, tête.
  Résultat, combat (avec / sans ragdoll), FPS moyen et 1 % bas : 111 / 115 et 46 / 56 ; 117 / 114 et 54 / 55 (séries précédentes, même
  version sauf CCD et tonus : 103 / 121 et 53 / 66 ; 109 / 114 et 53 / 59). Avant les correctifs : 1 % bas 11-25 contre ~32.
  Au repos rien ne tourne (repos 147-165 FPS dans les deux cas).
- **Interrupteur** : `-- --sans-ragdoll-esprit` (vol cinématique et chute Death01 d'avant).
- **Test** : `bash outils/tous_les_tests.sh test_ragdoll_esprit` (28 vérifications) ; `test_sorts_esprit` adapté. **Film / mesure** :
  `outils/film_ragdoll_esprit.gd` (`--plans=normal,ralenti,levitation`, `--mesure`), rendus dans
  `rendus/telekinesie_2026-11-23/ragdoll_esprit/`.

## Sons (branche magie/sons)

`scripts/magie/sons_magie.gd` (`SonsMagie`) : charge (boucle douce, volume et hauteur suivent l'intensité), lancement (2 variantes par école), jet continu (boucle, s'éteint 0,25 s après le dernier appel), impact (2 variantes, volume selon la force), zone, chaîne, réactions (6), double incantation (une note par école), enchantement, « Pas assez de mana » (aussi « Mana épuisé »). Écoles feu, glace, électricité, ténèbres (+ soin, protection). Fichiers : `assets/sons/magie/*.wav` (PCM 16 bits, sources CC0 dans assets/LICENCES.md, fabriqués par `outils/sons_magie/generer.py`). Boucles : `edit/loop_mode=2` dans leur .import.

- Branchements (une ligne chacun) : `EffetsMagie.aura_main / jet / impact / zone / chaine / enchant_arme / reaction / double / tout_arreter`, `LanceurSorts.lancer` (départ du sort, joueur ET mage ennemi), `MainSort._refuser` (mana), `PrechauffeCombat.caches` (`SonsMagie.precharger()`).
- Mage ennemi : mêmes appels, sons 3D qui suivent SA main (charge, jet) ou le point d'impact. Bus « Effets » (Options) quand il existe.
- Perf : tout en .wav (jamais d'Ogg décodé au jeu), préchargé en tâche de fond ; pool de 12 lecteurs de coups + 8 de boucles créés une fois ; au plus 5 lectures par image, délai minimal par type de son. Mesuré (test_sons_magie, headless) : jet + charge chaque image ~80 us, un sort complet ~130 us, rien de créé par sort. `EffetsMagie.muet` : appels comptés (`SonsMagie.appels`), rien de joué.
- Test : `bash outils/tous_les_tests.sh test_sons_magie`.

## Contrats

### EffetsMagie (agent effets : remplace `scripts/magie/effets_magie.gd`, signatures figées)
`aura_main(main, ecole, intensite)` (0 = éteinte ; incante 0,35→0,75, charge 0,6→1, canalise 1 ; × 1,5 en double),
`jet(ecole, origine, direction, portee, largeur, actif)` (chaque image ; actif=false à la fin), `projectile_visuel(ecole,
forme) -> Node3D`, `impact(ecole, position, normale, force)`, `zone(ecole, position, rayon, duree)`, `chaine(ecole, points)`,
`statut_cible(cible, statut, duree)` (duree 0 = retiré), `enchant_arme(arme, ecole, actif)`, `reaction(nom, position,
rayon)`, `double(ecole, actif)`. `EffetsMagie.appels` (compteur) est lu par test_magie : à garder dans la vraie version.
Origines : nœuds `Paume_gauche` / `Paume_droite` (enfants des os des mains) ; arme : `mains._modele_arme_d`.

### HUD (joueur.gd)
Signal `etat_mains_change(gauche: Dictionary, droite: Dictionary)` (genre "sort" / "arme" / "bouclier" / "torche" / "vide",
id, nom, ecole, type, cout, par_seconde, recharge) ; signal `action_refusee(main, raison)` ; propriétés `mana`, `mana_max`,
`charge_gauche`, `charge_droite` (0..1), `recharges` ({id: s restantes}), `statuts_actifs` ([{nom, duree, ecole}] :
protection, double, enchant_<école>, lenteur). Détail : `joueur.mains.magie` (`inc[main].nom()`, `refus`, `journal`).

## Sauvegarde
`monde.sauvegarder` écrit `"magie": {gauche, droite, sorts_connus, mana, enchantement}` ; `charger` le relit (la droite
d'abord : enchantement et deux mains). Les 21 sorts sont connus d'office (pas encore d'apprentissage).

## Tests
- `test_magie` (112 vérifications) : compatibilité (refus, deux mains, garde, bouclier), mana (coût / délai / régénération /
  refus), les 12 sorts + soin + protection (dégâts, statut, drain, chaîne, recharge), double (fenêtre, coût, dégâts, 4 écoles),
  6 réactions + réaction impayable, interruption (seuil), épée + magie (mémorisation, canalisation coupée, bonus), enchantement
  et combos, statuts sur un draugr (gel, choc + immunité, brûlure), contrats EffetsMagie / HUD, sauvegarde JSON.
- `test_gestes_magie` (54 vérifications) : données (7 gestes × 2 mains), paume dans l'écran, départ et retour au repos, chaque
  sort joue son geste (une main, main droite, double, zone sans charge, interruption), la cible de la main ne saute jamais
  (pire écart entre deux images à 60 i/s : 4,5 à 8 cm, poussées capturées), soin / enchantement gardent les poses fixes.
- `test_articulations_magie` (156 vérifications) : 10 situations (dont zone main droite, double ×3 sur les deux bras), à 60 et
  30 i/s : longueurs ±1 mm, torsion bras / avant-bras / main ≤ 15° par image (30 à 30 i/s ; mesuré 13,9 / 27,8), plan du coude
  ≤ 20° par image (mesuré 10,0), accélération du coude ≤ 0,10 m/image² (mesuré 0,035), torsion de la main depuis le repos ≤ 140°
  (mesuré 134,7), retour au repos.
- `test_mage_bot` (banc « bot MAGE », 2026-11-05, `outils/test_mage_bot.gd`) : un bot qui ne porte que des sorts combat de VRAIS draugrs
  (104 PV) dans `test_combat.tscn`, comme `test_menace_bot` pour la mêlée. Configurations `<école>_<s|d>` : feu (boule de feu), glace
  (éclat), électricité (arc), ténèbres (trait d'ombre), en simple (main droite) ou double (même sort aux deux mains) ; `--variantes` ajoute
  jet de flammes, lance de givre, chaîne d'éclairs, drain de vie. Le bot tire dès que le sort est prêt (charge tenue jusqu'au bout,
  jets tenus tant que la cible est à portée), recule en marchant (2,6 m/s) quand un draugr est à moins de 4 m ou que la mana est vide
  (fond de salle à 1,5 m), esquive ~0,1 s avant l'impact des gestes ennemis ; `--statique` : ne recule jamais. Mesures : durée, PV perdus,
  mana restante / dépensée, ennemis tués, morts. Options : `--n=<essais>`, `--config=`, `--dist=<m>` (5,4 par défaut), `--nb=1|2`, `--esquive=<0-1>` (mesure), `--trace` ; colonne `coups` = coups reçus.
  Seuils : voir `_verifier` et « Équilibrage » ci-dessus.
- Non-régression : test_combat_epee, test_defense, test_degats, test_troll_ia, test_mage_ia, test_menace_bot (la mêlée ne bouge pas).

## Limites / suite
- Visuels = bouchons tant que magie/effets n'est pas fusionnée ; sons de magie non faits (phase 6).
- 3e personne : aucune animation de sort (le corps garde ses animations d'épée / torche).
- Pas d'inventaire graphique des mains (raccourcis + API `magie.equiper`) ; HUD et sélection rapide = agent effets.
- La corruption n'affaiblit pas encore les coups DE l'ennemi (elle augmente les dégâts reçus).
- Pas d'arme à deux mains dans les données (gérée par les règles, testée). Bouclier : vrai modèle depuis 2026-10-27.
- Équilibrage : fait au banc « bot » le 2026-11-05 (voir « Équilibrage ») ; il reste à le confirmer à la manette / au clavier : le bot vise
  toujours et ne rate jamais (plafond d'efficacité), un vrai joueur dépensera davantage de mana par draugr.
