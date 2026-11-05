# Options, touches et sauvegardes (nuit du 2026-11-05)

## Touches (scripts/touches.gd)
- Chaque commande est une ACTION de l'InputMap (`avant`, `arriere`, `gauche`, `droite`, `course`, `saut`, `interagir`, `torche`, `vue`, `menu`
  (Tab), `inventaire`, `competences`, `quetes`, `carte`, `sauvegarde_rapide`, `chargement_rapide`, `aide`). Le code teste l'action
  (`e.is_action_pressed("torche", false)`), jamais une touche en dur.
- Deux touches par action (principale, secondaire). Touches PHYSIQUES ; `Touches.libelle(id)` les écrit comme le clavier du joueur.
- Réglages : `options.cfg`, section `touches` (`<action>` et `<action>_2`). Écran : Options > Touches (cliquer, appuyer ; Échap annule ;
  Retour arrière efface la secondaire). Une touche déjà prise est ÉCHANGÉE ; Échap, F11, Entrée, F3, P sont réservées.
- Restent fixes : souris (clic gauche frapper, clic droit parer), 1 - 0 (raccourcis), Échap (pause), F11, et la navigation interne des menus
  (E / Entrée valident, G main gauche, R lâcher…) — ces aides internes affichent donc la lettre fixe.
- Plus aucun picto manette dans les textes d'aide : l'entrée manette n'existe pas encore dans le jeu.
- Mode outil (tests, captures) : touches par défaut, rien n'est écrit.

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
