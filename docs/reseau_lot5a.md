# Réseau — lot 5a : crime par joueur, quêtes partagées, commerce, conversations

Décisions utilisateur appliquées : quêtes PARTAGÉES (état par l'hôte, récompense à chacun, une quête acceptée par un joueur l'est pour tous) ;
crime et prime PAR JOUEUR (un garde réagit au joueur fautif, la prime se paie/purge individuellement) ; butin premier arrivé (déjà fait).
Test : `bash outils/test_economie_quetes.sh` (2 Godot headless, `GODOT_MAX>=2`, port 25011, scène `outils/test_economie_quetes.tscn`). Verdict lu dans les journaux.
Solo / hors ligne : tout est inerte (`_coop` ne route rien, `Crime` n'a qu'un contexte, `ConversationsCoop.prendre` renvoie vrai, `Marchand` inchangé).

## 1. Crime par joueur (`scripts/crime.gd`, `scripts/reseau/crime_coop.gd`)
- L'état de justice est dans `Crime.Perso` (primes, réputation, hostilité, objets volés, arrestation, trêve, plaidoyer, mémoires d'agression…).
  Les anciennes variables de `Crime` (`primes`, `reputation`, `hostile`, `voles`, `perdue`, `plaide`, `arrestation`, `treve`, `joueur`…) sont des
  PROPRIÉTÉS qui lisent le Perso du joueur COURANT : tout le code existant (témoins, gardes, arrestation) marche « pour le joueur courant » sans changement.
- Contexte : `0` = joueur local, sinon identifiant réseau d'un invité (chez l'hôte seulement). `Crime.en_tant_que(peer, callable)` /
  `dans_contexte(ctx, callable)` exécutent pour un joueur (son avatar `Reseau.registre.noeud(peer)` devient `joueur`). `contexte_de(noeud)`, `peer_courant()`, `treve_de(ctx)`.
- L'hôte arbitre : `vol_arbitre`, `intrusion_arbitree`, `coup_sur_pnj` (info["attaquant"] = nœud joueur ; sinon contexte courant). `guerre()` ne rend hostile
  que la garde du joueur fautif ; `apaiser_tous()` ne calme que les combattants qui le poursuivent ; `baisser_prime`/réputation tournent pour chaque joueur.
- `PnjCombat` : champ `peer` (qui il poursuit / arrête), `cibler(ctx, noeud)`, `joueur` = le fautif, `treve_de(peer)`, agression/meurtre attribués à l'auteur du coup
  (`r["attaquant"]`, sinon joueur le plus proche). Un combattant déjà hostile contre A n'est pas détourné vers B.
- Invité : `signaler_vol` / `_intrusion` (crochetage compris) marquent l'objet volé dans SON sac puis envoient `crime_vol` / `crime_intrusion` à l'hôte. L'hôte renvoie
  un « miroir » (`crime_miroir` : primes, réputation, hostilité, réputation perdue, dédoublonné par hachage) : l'invité l'affiche et le SAUVEGARDE dans son personnage
  (`Crime.exporter()`). À la connexion il envoie `crime_perso` (état de son personnage) : l'hôte l'adopte. Avis et répliques de PNJ du crime vont chez le fautif (`crime_avis`, `crime_dire`).
- Réputation de faction (`Rangs`) : vit chez le personnage ; l'hôte envoie `crime_rangs` (punir / membre_tue / rendre) à l'invité qui l'applique à SES rangs.
- Arrestation d'un invité : un garde `PnjCombat` au contact envoie `crime_arret` ; le dialogue (amende / plaider / geôle / résister) s'ouvre chez l'invité via un faux PNJ
  `CrimeCoop.ArretDistant`. Amende payée et objets saisis chez lui (`choisir("amende")`), plaidoyer arbitré par l'hôte (`crime_plaidoyer`), geôle = l'hôte avance l'heure et lève la prime,
  l'invité purge sa peine (`crime_prison` : saisie, XP, sortie, vie). Échap = résister.
- PNJ tués (`morts`) partagés (`crime_morts` + contributeur Rejoindre « crime »). Un PNJ converti en `PnjCombat` est montré chez l'invité par le villageois-marionnette
  qui prend sa position/animation (`ReseauMondeVivant._etat_pnj`).

## 2. Quêtes partagées (`scripts/quetes.gd`, `scripts/reseau/quetes_coop.gd`)
- L'invité ne modifie jamais son état : `signaler`, `avancer_index`, `echouer` sont routés à l'hôte (`quete_op`, avec le contenu de son sac pour les conditions `objet:`).
  `signaler("")` n'est envoyé que si une étape `objet:` est remplie localement.
- L'hôte applique puis diffuse l'état complet (`quete_etat`, coalescé à l'image : index, événements vus, dates du journal, échecs). Contributeur Rejoindre « quetes » (instantané sans récompense rejouée).
- Récompense : `_donner_recompense(q)` (extrait de `_completer`) ; l'hôte la donne à la fin, chaque invité la reçoit chez lui quand l'état partagé franchit la dernière étape
  (`appliquer_partage` -> `_notifier_distant` : annonces, sons, récompense, `quete_terminee`). Une seule fois par joueur.
- Limite : une réplique de quête dite par un invité lit l'état avant le retour de l'hôte (la ligne « pendant » apparaît au dialogue suivant).

## 3. Commerce (`scripts/marchand.gd`, `scripts/reseau/marchand_coop.gd`)
- Stock et or de chaque marchand = ceux de l'hôte ; pièces et sac = ceux du joueur local. `Marchand.acheter_coop` / `vendre_coop(id, inv, oid, n, [quetes,] rappel)`.
  Hôte/solo : `acheter`/`vendre` puis diffusion de l'état (`march_etat`). Invité : contrôles locaux, puis demande à l'hôte (`march_demande`) qui accorde
  min(demandé, disponible) dans l'ordre d'arrivée et répond avec l'état à jour (`march_reponse`) ; l'invité règle alors pièces et sac. Un objet unique n'a qu'un acheteur.
- `Marchand.traiter()` (fenêtre) passe par là ; la fenêtre ouverte se redessine quand un autre joueur change le stock. Instantané Rejoindre « marchands ».
- Forge (`Forge`, `interieur_forge.gd`) : aucun état partagé (établi local, matériaux du sac local) : laissée locale.

## 4. Conversations (`scripts/reseau/conversations_coop.gd`, `dialogue.gd`, `villageois.gd`, `garde_village.gd`)
- Chez un invité, villageois et gardes (marionnettes) gardent « E Parler » et les interpellations (`_interactions(_dist_locale(), dt)`) ; le dialogue est local, ses effets passent par l'hôte
  (quêtes, commerce, crime). `_interactions` utilise désormais la distance au joueur LOCAL (et non au plus proche) : en coop l'invite ne s'affichait que par hasard.
- Verrou simple : `ConversationsCoop.prendre(pnj, refuse)` / `liberer(pnj)` appelés par `Dialogue._ouvrir/_fermer`. L'hôte arbitre (`conv_demande/conv_fin/conv_verrou/conv_refus`),
  fige le PNJ pendant qu'un invité lui parle (`_conv_distante`), libère à la déconnexion. Invité : réponse optimiste d'après les verrous connus, rappel `refuse` si l'hôte tranche autrement.
- `Dialogue._ready` appelle `ConversationsCoop.brancher()` ; `Marchand._ready` appelle `MarchandCoop.brancher()` (abonnements inertes hors ligne).

## Fichiers existants touchés
`scripts/crime.gd`, `scripts/pnj_combat.gd`, `scripts/quetes.gd`, `scripts/marchand.gd`, `scripts/dialogue.gd`, `scripts/villageois.gd`, `scripts/garde_village.gd`,
`scripts/reseau/reseau_monde_vivant.gd` (`_etat_pnj`). Nouveaux : `scripts/reseau/{crime_coop,quetes_coop,marchand_coop,conversations_coop}.gd`, `outils/test_economie_quetes.{gd,tscn,sh}`.
