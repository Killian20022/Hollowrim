# Réseau — lot 0 (fondations)

## API (autoload `Reseau`, `scripts/reseau/reseau.gd`) — contrat figé
- `heberger(port=24565) -> Error`, `rejoindre(ip, port=24565) -> Error`, `deconnecter()` (revient en solo).
- `est_hote()`, `est_en_ligne()`, `mon_id()`, `joueurs() -> Array[int]` (triés, hôte = 1).
- Signaux : `joueur_connecte(id)`, `joueur_deconnecte(id)`, `connexion_reussie`, `connexion_echouee`.
- Solo : aucun pair réseau ; `est_hote()=true`, `est_en_ligne()=false`, `mon_id()=1`, `joueurs()=[1]`.
- Évènements : `abonner(type, callable(expediteur, id, donnees))`, `desabonner`, `envoyer_evenement(type, id, donnees, vers=0)`
  (`vers=0` : hôte -> tous les invités, invité -> hôte ; sinon un pair précis), `emettre_local(...)`. Le RPC générique est `Reseau.evenement(type, id, donnees)` (fiable, any_peer) : ne pas l'appeler directement.
- Registre : `Reseau.registre` (`scripts/reseau/registre_joueurs.gd`) : `ajouter/retirer/ids/noeud/definir_noeud/infos/definir_info`, signaux `joueur_ajoute/joueur_retire`.
- Transport : `Reseau.transport` (`ReseauTransport` -> `ReseauTransportENet`, max 4 joueurs). EOS/Steam = nouvelle sous-classe fournissant `creer_hote/creer_client` (MultiplayerPeer).

## Banc de test
`bash outils/banc_reseau.sh` : lance 2 Godot headless (hôte + invité, 127.0.0.1, port 24577 ou `PORT=`) via `/tmp/godot_slot.sh` (copier `Jeux/godot_slot.sh` vers /tmp). **GODOT_MAX doit valoir au moins 2** (défaut du script) : avec 1 créneau, l'invité attendrait la fin de l'hôte. Vérifie solo, connexion, `joueurs()`, évènement ping/pong, déconnexion, retour solo. Script : `outils/banc_reseau.gd`.

## Déterminisme
`godot --headless --path . --script res://outils/test_determinisme_monde.gd` : génère deux fois (graine globale différente entre les deux) textures de palette + villageois et compare un hachage.
Corrigé : `villageois.gd` (cap, allure, minuteries de naissance, étape de métier), `garde_village.gd` (idem), `mobilier_village.gd` (phases des tissus), `vie/metiers.gd` (`duree` accepte un RNG). Graine = id/nom + position. `Palette.tex()` était déjà déterministe (graine = hash du nom) ; `Monde` utilise déjà `rng.seed=1234`.

## Reste à faire
- Les gardes ne sont pas couverts par le test (même correctif appliqué, non testé). Il reste des `randf()` globaux de gameplay (promenades, répliques, effets) : sans importance si l'hôte seul simule, à surveiller pour tout ce qui est calculé chez chaque joueur (flammes, lumières : cosmétique).
- Pas de test de génération du monde complet (deux processus + comparaison de hachage de terrain/props) : à faire au lot 2.
- Pas de réplication d'entités, d'avatars ni de Spawner (lot 1+). Pas de relais EOS/Steam (lot 6).
