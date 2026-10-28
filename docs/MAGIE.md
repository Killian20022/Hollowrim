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
| maintenir | — | charger (boule, lance, zones) / canaliser (jet, arc, drain, soin, protection) |
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

100 max ; régénération 7 /s après 1,2 s sans dépense ni incantation ; plein à la résurrection ; sauvegardé.
Coûts payés : RAPIDE / ZONE / ENCHANT au départ ; CHARGE au relâchement (`cout × lerp(cout_charge_min, 1, charge)` ; si le
mana manque, la charge est réduite à ce qui est payable) ; CANALISE par seconde (arrêt « Mana épuisé »).

## Les sorts (`data/sorts/`, valeurs de départ, phase 6 = équilibrage)

| Sort | École | Type | Coût | Dégâts | Statut | Portée / rayon | Recharge | Double (principaux ×) |
|---|---|---|---|---|---|---|---|---|
| Jet de flammes | feu | canalisé, jet (4 cibles) | 13 /s | 20 /s | brûlure 4 /s, 3 s | 5,5 m, largeur 0,9 | — | dégâts 2, coût 2,2, largeur 1,8, portée 1,25 |
| Boule de feu | feu | chargé 0,8 s, projectile 24 m/s | 24 (×0,6 sans charge) | 34 (×0,55) + explosion 50 % | brûlure 4 /s, 3 s | rayon 2,2 | 0,5 s | dégâts 2,2, coût 2,4, rayon 1,6 |
| Explosion incendiaire | feu | zone visée, chargée 1 s | 42 | 38 (×0,6) | brûlure 6 /s, 4 s | 14 m, rayon 3 | 4 s | dégâts 2, coût 2,3, rayon 1,5 |
| Éclat de glace | glace | rapide, 3 éclats 34 m/s | 8 | 8 ×3 | gel 0,25, 2,5 s | — | 0,3 s | 6 éclats, dégâts 1,6, coût 2,2 |
| Lance de givre | glace | chargé 0,9 s, traverse 1 | 26 | 40 | gel 0,45, 3 s | — | 0,8 s | lance + 2 cristaux, traverse 3, dégâts 2,1 |
| Nova gelée | glace | zone autour de soi | 40 | 20 | gel 0,55, 4 s | rayon 4,5 | 5 s | rayon 1,5, gel 1,4 |
| Arc électrique | électricité | canalisé, jet (1 cible) | 14 /s | 24 /s | choc 0,45 s | 9 m | — | portée 1,3, +2 rebonds (propagation) |
| Chaîne d'éclairs | électricité | rapide, chaîne | 22 | 24, ×0,75 par rebond, 3 rebonds | choc 0,4 s | 20 m, rebond 6,5 m | 1 s | +3 rebonds, dégâts 1,9 |
| Tempête statique | électricité | zone visée persistante 5 s | 52 | 9 par tic de 0,5 s | choc 0,3 s | 16 m, rayon 4 | 9 s | rayon 1,4, durée 1,3 |
| Trait d'ombre | ténèbres | rapide, projectile 30 m/s | 10 | 15 | corruption +15 %, 5 s | — | 0,35 s | dégâts 2,1, corruption 1,6 |
| Drain de vie | ténèbres | canalisé, jet | 11 /s | 13 /s, rend 60 % | corruption +10 %, 3 s | 8 m | — | dégâts 1,9, drain 1,3, +1 cible |
| Explosion obscure | ténèbres | zone visée chargée 1 s, vortex | 48 | 34 | corruption +20 %, 6 s | 14 m, rayon 3,5 | 6 s | rayon 1,5, attraction 1,5 |
| Soin | soin | canalisé, soi | 12 /s | soin 16 /s | — | — | — | soin 1,9 |
| Protection | protection | canalisé, soi | 5 /s + 0,4 par point absorbé | absorbe 60 % (coups) / 85 % (sorts) de face, cône 120° | — | — | jamais interrompue | réduction × 1,25 (plafond 90 / 97 %) |
| Lame ardente / de givre / d'orage / des ténèbres | 4 écoles | enchantement | 35 | +7 par coup d'épée | brûlure / gel / choc / corruption | 30 s | 2 s | — |

Stagger (posture ennemie) : 5 à 30 par coup (CANALISE : par seconde) ; ≥ 24 = « puissant ». Les sorts passent par la même
posture / réaction que l'épée : un mage nordique (seuil 7) est interrompu par presque tout, un draugr titube sous une boule
chargée, le troll (poids 2) encaisse. Interruption du JOUEUR : un coup reçu ≥ `seuil_interruption` (8, jets 10, protection
jamais) coupe incantation / charge / canalisation (récupération 0,5 s, rien n'est lancé, rien n'est payé pour une charge).

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
  lame), 30 s ; chaque coup d'épée ajoute 7 dégâts de l'école (× résistance de la cible) et pose son statut ; le modèle et la
  texture de l'arme ne changent pas (`EffetsMagie.enchant_arme`) ; relancer rafraîchit ; ranger l'épée l'efface.
- **Combos** (coup d'épée léger / lourd / contre sur une cible qui porte un statut, `combos_epee`) :
  embrasement (brûlure : × 1,3, brûlure prolongée de 2 s), brise-glace (gel : × 1,5 dégâts et stagger, gel consommé),
  ouverture (choc : × 1,3, stagger × 2), moisson (corruption : × 1,2, 25 % rendus en vie, corruption consommée).

## Réactions des ennemis

- Draugrs / squelettes / bandits (draugr.gd) et EnnemiBase : gel = ralentis ; choc = titubent (attaque interrompue) ;
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
d'abord : enchantement et deux mains). Les 18 sorts sont connus d'office (pas encore d'apprentissage).

## Tests
- `test_magie` (112 vérifications) : compatibilité (refus, deux mains, garde, bouclier), mana (coût / délai / régénération /
  refus), les 12 sorts + soin + protection (dégâts, statut, drain, chaîne, recharge), double (fenêtre, coût, dégâts, 4 écoles),
  6 réactions + réaction impayable, interruption (seuil), épée + magie (mémorisation, canalisation coupée, bonus), enchantement
  et combos, statuts sur un draugr (gel, choc + immunité, brûlure), contrats EffetsMagie / HUD, sauvegarde JSON.
- Non-régression : test_combat_epee, test_defense, test_degats, test_troll_ia, test_mage_ia.

## Limites / suite
- Visuels = bouchons tant que magie/effets n'est pas fusionnée ; sons de magie non faits (phase 6).
- 3e personne : aucune animation de sort (le corps garde ses animations d'épée / torche).
- Pas d'inventaire graphique des mains (raccourcis + API `magie.equiper`) ; HUD et sélection rapide = agent effets.
- La corruption n'affaiblit pas encore les coups DE l'ennemi (elle augmente les dégâts reçus).
- Pas d'arme à deux mains dans les données (gérée par les règles, testée). Bouclier : vrai modèle depuis 2026-10-27.
- Équilibrage complet (phase 6) à faire en jeu.
