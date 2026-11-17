# Réseau — lot 5b : sauvegardes monde + personnage, écran Multijoueur, poignée de main

## Partage monde / personnage
Code : `scripts/reseau/sauvegarde_multi.gd` (`SauvegardeMulti`, statique) ; `monde.gd` : `exporter_monde()`, `exporter_personnage()`,
`importer_monde(d)`, `importer_personnage(d, position := true)`, `sauvegarder_personnage()`.

| MONDE (hôte) | PERSONNAGE (chaque joueur) |
|---|---|
| version, heure, jour, quêtes, herse, dragon vaincu, gardiens morts, PNJ (Vie), sommeil, faune, butin/contenants/graine, marchands, objets vivants | joueur (position de retour, lacet, PV, endurance), progression, équipement porté, sac (inventaire), magie, coffres sûrs (Stockage), bulles d'aide, lieux vus, favoris du sac, PNJ déjà parlés, **crime** (primes, réputation, hostilité) et **rangs** |

- **Le fichier d'un emplacement reste UN fichier au format v2** (`Migration.VERSION`, inchangé) = monde + personnage de l'hôte. Une partie coop se
  rouvre donc en solo, et un ancien exe/solo lit un fichier d'hôte. `Monde.sauvegarder()` = `SauvegardeMulti.fusionner(exporter_monde(), exporter_personnage())` ;
  `Monde.charger()` = `Migration.migrer` puis `_importer_personnage_corps` + `importer_monde` + `_importer_personnage_social`
  (même ordre qu'avant pour ce qui dépend des PNJ restaurés).
- **Migration** : toute ancienne sauvegarde (v1 sans `version`, compétences à l'ancienne…) passe par `Migration.migrer` avant d'être lue
  (inchangé) ; `SauvegardeMulti.depuis_sauvegarde(d)` fait migrer + découper en `{monde, personnage}`. Test de non-régression : un fichier v1 est chargé
  dans le vrai monde (`outils/test_sauvegarde_multi.gd`), puis resauvegardé en v2, redécoupé et rechargé.
- **Fichier PERSONNAGE d'un invité** : `user://personnages/<nom>.json` (`{format:"personnage", version:1, nom, date, personnage:{…}}`), écrit de façon atomique
  (`Sauvegardes.ecrire`). Nom de fichier assaini (`nom_fichier` : minuscules, sans accent, pas de `/` ni `..`). Dossier de TEST séparé en `--script` / sans fenêtre.
- **Invité** (`Monde._invite_coop()`) : `charger()` ne lit aucun fichier de partie ; `sauvegarder()` (F5, menu pause, fermeture, sauvegarde automatique, retour au
  titre) n'écrit QUE son fichier personnage — jamais l'emplacement de partie. Si l'hôte part, `ApportPersonnage` sauvegarde le personnage.
- **Hôte** : sauvegarde le monde (+ son personnage) comme en solo ; hôte sans invité = solo.

## Apport du personnage (`scripts/reseau/apport_personnage.gd`, nœud enfant du monde, installé par `monde._ready`)
1. Invité, monde prêt : lit son fichier personnage et l'envoie (zstd) à l'hôte : évènement `apport_perso`.
2. Hôte : `SauvegardeMulti.valider` (voir ci-dessous), enregistre `niveau` et `personnage_valide` dans `Reseau.registre`, répond `apport_resultat`
   avec la version ASSAINIE + un point d'apparition à 2,2 m de lui (angle selon le rang du joueur) + la liste des corrections.
3. Invité : `Monde.importer_personnage(perso, false)` (la position de retour n'est PAS reprise : il apparaît près de l'hôte), message HUD.
   Sans fichier : personnage neuf. Sans réponse en 12 s : personnage neuf + message.

**Validation** (modèle Valheim : le personnage vit chez l'invité ; l'hôte n'écarte que l'impossible) : types simples seulement (objets Godot
écartés), 1,5 Mo au plus, pièces ≤ 1 000 000, quantités ≤ 9 999, ≤ 1 500 objets distincts, objets inconnus retirés, niveau ≤ 81, points ≤ 400, attributs ≤ 200,
compétences dans [15 ; 100], PV/endurance/mana ≤ 2 000, valeurs non finies ramenées, position de retour folle ignorée. **Limite assumée** : l'hôte ne peut pas
prouver qu'un sac a été gagné honnêtement (un invité peut éditer son fichier dans les bornes). Un anti-triche réel demanderait que l'hôte garde les personnages
(contraire à « sauvegardé chez l'invité »), à discuter ; piste légère : l'hôte garde la dernière empreinte par nom et signale une régression suspecte.

## Poignée de main (dans `reseau.gd`)
- `Reseau.VERSION_PROTOCOLE := 1` (à incrémenter si le format des évènements change), `MAX_JOUEURS := 4`.
- Invité : à `connected_to_server`, envoie `poignee {version, nom}` ; `connexion_reussie` n'est émis qu'à `poignee_ok` (la liste des présents et `infos_partie` de l'hôte arrivent avec).
- Hôte : un pair n'existe pour le jeu (registre, `joueur_connecte`, avatars) qu'APRÈS la poignée acceptée ; refus (« Version différente… », « La partie est pleine (4 joueurs au plus). »)
  envoyé puis pair coupé ; sans poignée en 6 s : coupé. Tout évènement d'un pair non présenté est ignoré. Nom unique (« Astrid (2) »). ENet : 7 places au lieu de 3
  pour que « partie pleine » soit refusée AVEC un message.
- Invité : les autres invités arrivent par `poignee_arrivee` (plus par `peer_connected`, pour ne pas voir passer un refusé).
- Erreurs lisibles : `Reseau.derniere_erreur` après `connexion_echouee` (hôte injoignable, version, plein, pas de réponse) ; `Reseau.nom_joueur`.
- Délai ENet allongé (`_tolerer` : 15 s min, 90 s max) : le chargement du monde bloque quelques secondes la lecture réseau.

## Écran Multijoueur (`scripts/reseau/ecran_multi.gd`, `EcranMulti`)
Bouton « Multijoueur » du titre (entre Charger et Options), même thème que les autres panneaux (`MenuStyle.theme_titre`). Vues : choix → Héberger (monde : ‹ › parmi
les sauvegardes valides + « Nouveau monde » ; nom ; port) | Rejoindre (adresse IP:port ; nom) → connexion → **salon** (liste des joueurs « ◆ Nom (hôte, vous) », compteur n / 4,
« Lancer la partie » pour l'hôte, attente pour les invités). Un invité qui arrive après le lancement entre directement dans le monde. Clavier (Haut/Bas en boucle, Gauche/Droite
sur le monde, Entrée, Échap) et manette (croix, A, B) ; la saisie de l'adresse demande un clavier. Nom, dernière adresse et port sont retenus dans `user://multijoueur.cfg`.
Validation : `EcranMulti.analyser_adresse / analyser_port / analyser_nom` (statiques, testées).
Lancement : l'écran titre émet `lancer_partie(role, nouveau, emplacement)` → `Sauvegardes.actif` = monde choisi (hôte) ; l'invité lance le monde avec `nouvelle_partie = false`.

## Tests / captures
- `bash outils/test_sauvegarde_multi.sh [solo|reseau|ecran]` : (1) `test_sauvegarde_multi.gd` (pur, ancienne sauvegarde v1, hôte, personnage), (2) `test_sauvegarde_multi_reseau.gd`
  (hôte faux monde + invité VRAI monde, 2 phases dont une relance), (3) `test_ecran_multi.gd` (écran). Ports 25031-25049 (`PORT=25033`), `GODOT_MAX=4`, jamais `--fixed-fps` (délais réseau en temps réel).
- `bash outils/captures_ecran_multi.sh` : rendu réel hors écran → `captures/ecran_multi/ecran_multi_*.png`.
