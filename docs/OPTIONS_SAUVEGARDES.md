# Options, touches et sauvegardes (nuit du 2026-11-05)

## Touches (scripts/touches.gd)
- Chaque commande est une ACTION de l'InputMap (`avant`, `arriere`, `gauche`, `droite`, `course`, `saut`, `interagir`, `torche`, `vue`, `menu`
  (Tab), `inventaire`, `competences`, `quetes`, `carte`, `sauvegarde_rapide`, `chargement_rapide`, `aide`). Le code teste l'action
  (`e.is_action_pressed("torche", false)`), jamais une touche en dur.
- Deux touches par action (principale, secondaire). Touches PHYSIQUES ; `Touches.libelle(id)` les écrit comme le clavier du joueur.
- Réglages : `options.cfg`, section `touches` (`<action>` et `<action>_2`). Écran : Options > Touches (cliquer, appuyer ; Échap annule ;
  Retour arrière efface la secondaire). Une touche déjà prise est ÉCHANGÉE ; Échap, F11, Entrée, F3, P sont réservées.
- Restent fixes au clavier : souris (clic gauche frapper, clic droit parer), 1 - 0 (raccourcis), Échap (pause), F11, et la navigation interne des menus
  (E / Entrée valident, G main gauche, R lâcher…) — ces aides internes affichent donc la lettre fixe.
- Textes d'aide : touches du clavier par défaut ; noms de boutons de la manette quand la dernière entrée vient d'elle (voir « Manette »).
- Mode outil (tests, captures) : touches par défaut, rien n'est écrit.

## Manette (scripts/manette.gd, 2026-11-11)
Xbox / SDL standard (Godot lit les manettes avec la base SDL : noms affichés en boutons Xbox). Le clavier et la souris ne changent pas :
`Touches.appliquer()` appelle `Manette.appliquer()`, qui AJOUTE les événements de manette aux mêmes actions (appel répétable, sans doublon).

| Entrée | Commande (action) | | Entrée | Commande (action) |
|---|---|---|---|---|
| Stick gauche | se déplacer (`avant`… ; fixe) | | Stick droit | regarder (fixe) |
| RT | main droite : frapper, maintenir = coup puissant, sort de droite, bander l'arc (`main_droite`) | | LT | main gauche : garde, sort de gauche (`main_gauche`) |
| A | parler, ouvrir, ramasser (`interagir`) | | B | esquiver (`esquive`) |
| X | torche (`torche`) | | Y | sauter (`saut`) |
| LB | courir, maintenu (`course`) | | RB | carte (`carte`) |
| L3 | s'accroupir (`accroupi`, prête pour la furtivité) | | R3 | vue 1re / 3e personne (`vue`) |
| Croix haut / droite / bas / gauche | raccourcis 1 / 2 / 3 / 4 (`raccourci_1`…`4`) | | Vue (Back) | menu du personnage (`menu`) |
| Start | pause (fixe, réservé) | | | |

Sans bouton par défaut (réglables) : Attendre, Sac, Compétences, Quêtes, sauvegarde / chargement rapides, aide des touches.
- Menus : les boutons internes des écrans (déjà là depuis les lots C / L8) : A valider, B retour / fermer, X et Y actions (main gauche,
  lâcher, toute la pile…), LB / RB onglets, croix et STICK GAUCHE pour choisir ; ajoutés : fenêtre de sommeil (croix = heures, A, B),
  narration (A page suivante, B / Start passer), stick gauche dans le butin, la boutique, le coffre, la forge, les onglets du codex
  (OngletLivre.direction) et les menus à boutons (stick ajouté à `ui_up`… ; focus visible : contour runique de MenuStyle).
- Stick = un pas par poussée : le nœud `Manette` (dernier enfant de la racine, posé par l'autoload Lancement et par le joueur) avale les
  mouvements d'axe qui ne franchissent pas un seuil (0,5 ; relâché sous 0,35). L'état continu reste lu par `Input` (déplacement,
  regard, zoom de la carte). Une gâchette tenue n'envoie donc qu'un appui et un relâchement (`Manette.changement`).
- Caméra : zone morte RADIALE puis courbe (exposant : Linéaire 1, Douce 1,8, Forte 2,6), 3,2 rad/s en lacet et 2,2 rad/s en tangage au
  stick à fond × sensibilité ; inversion Y propre à la manette. Le déplacement prend la même zone morte (zone morte des actions).
- Dernière entrée : bouton, gâchette ou stick poussé = manette ; touche, clic ou souris déplacée = clavier. `Manette.actif()`,
  `Manette.generation` (change à chaque bascule : le cartouche F1 du HUD se réécrit, les écrans dessinés se redessinent). Passent en
  boutons : bulles d'aide (`Aides.TEXTES_MANETTE`, « Maintiens LT »…), cartouche des commandes, bandeaux des menus et fenêtres
  (`Manette.traduire` : E -> A, R -> Y, G -> X, Échap -> B, Tab -> LB / RB ; sans équivalent = retiré), invite « [A] Parler »,
  « [X] Commercer », narration, fiches (« LT : lever le bouclier »), avis de l'arc.
- Le bouton qui ferme un menu (jeu en pause) ou un dialogue ne déclenche pas l'action du jeu à la reprise (B = esquive, Y = saut :
  joueur.gd, `reprise`).
- Options : « Sensibilité manette », « Inverser l'axe Y (manette) », « Zone morte des sticks », « Courbe du stick droit » ; Options >
  Touches : colonne « Manette » (choisir, appuyer sur le bouton ; Échap annule, Retour arrière efface ; même ÉCHANGE qu'au clavier ;
  Start, Guide et les sticks ne s'attribuent pas ; gâchettes permises), lignes propres à la manette (main droite / gauche,
  raccourcis 1 à 4, s'accroupir). « Rétablir » remet touches ET boutons.
- Réglages : `options.cfg`, section `manette` (`<action>` = code : bouton = `JOY_BUTTON_*`, axe = 100 + 2 × axe (+1 sens négatif),
  LT = 108, RT = 110, aucun = -1 ; `sensibilite`, `inverser_y`, `zone_morte`, `courbe`). Mode outil : défauts, rien d'écrit.
- Furtivité (branche gameplay/furtivite) : quand `accroupi` entre dans `Touches.ACTIONS` (Ctrl), sa ligne d'Options prend la touche
  et garde L3 ; rien d'autre à fusionner.
- Tests : `outils/test_manette.gd` (événements InputEventJoypad simulés dans le vrai monde : InputMap, zone morte, dernière entrée,
  aides, déplacement, caméra, saut, esquive, coup léger / puissant / garde, menu, dialogue, remappage, Options) ; étape « manette »
  de `outils/test_menus.sh` (écran titre et Options à la manette). Non testé sur une vraie manette (vibrations : aucune).

## Options graphiques (scripts/graphismes.gd)
Taille de la fenêtre (Automatique, 1280x720 … 2560x1440 ; sans effet en plein écran), synchronisation verticale, limite d'images par seconde
(30 à 144), ombres (désactivées, proches, normales, lointaines : facteur sur la portée d'origine de chaque lumière directionnelle).
Non fait : taille du texte de l'interface (l'interface est en pixels entiers sur un écran logique de 640x360), langue (pas d'infrastructure).

## Sauvegardes (scripts/sauvegardes.gd)
- 3 emplacements manuels + 1 automatique. L'emplacement 1 est l'ancien `sauvegarde.json` (aucune migration) ; `sauvegarde_2.json`,
  `sauvegarde_3.json`, `sauvegarde_auto.json`. Tests : mêmes suffixes sur le fichier de test du worktree.
- Écriture atomique : `.tmp`, relu et vérifié (JSON valide), puis renommé ; sinon la bonne sauvegarde reste intacte.
- Autosauvegarde (Monde.demander_autosauvegarde) : entrée et sortie de donjon, porte d'une maison, fin de quête, toutes les 10 minutes.
  Elle attend la fin du combat, d'un dialogue ou d'un menu, n'écrit que l'emplacement automatique et ne fait pas de copie de secours.
- F5 / « Sauvegarder » : emplacement choisi (menu pause) ou emplacement en cours. « Continuer » et F9 reprennent la sauvegarde la plus récente.
  « Nouvelle partie » prend le premier emplacement libre (sinon remplace le 1, après confirmation). « Charger » liste les 4 emplacements.
