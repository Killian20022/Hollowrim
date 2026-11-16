# Lot 6 : relais EOS (Epic Online Services), gratuit, PRÉPARATION

État : le code est écrit et isolé, **non testé avec le vrai plugin** (aucun compte Epic, plugin non téléchargé). ENet reste le transport par défaut et tous les tests restent verts. Les parties « plugin » (fichier `reseau_eos_adaptateur.gd`) sont écrites d'après la documentation et le code source du plugin ; elles sont à valider au premier essai réel (section 5).

## 1. Recherche : quel plugin pour Godot 4.7 ?

Retenu : **Epic Online Services Godot (EOSG)**, de 3ddelano. Vérifié sur GitHub (WebFetch/API, 2026-11-16) :

| Point | Constat |
|---|---|
| Dépôt | https://github.com/3ddelano/epic-online-services-godot (doc : https://3ddelano.github.io/epic-online-services-godot/) |
| Licence | MIT (le plugin). Le SDK C d'Epic, embarqué dans les zips de release, est soumis aux conditions du SDK Epic (gratuit, utilisable dans un jeu) ; non affilié à Epic. |
| Version | 2.3.1 (15 sept. 2026), SDK EOS 1.19.1.2. La note de version dit : « Fix plugin failing to load on Godot 4.7 » : 4.7 est donc explicitement visé. Prérequis annoncé : Godot 4.2+. |
| Plateformes | Windows x64, Linux x64/arm64, macOS, Android, iOS. |
| MultiplayerPeer | **Oui** : classe native `EOSGMultiplayerPeer` (dans `src/eosg_multiplayer_peer.cpp`, étend `MultiplayerPeerExtension`). Non décrite dans le README mais présente dans le code. Méthodes : `create_server(socket_id)`, `create_client(socket_id, remote_user_id)`, `create_mesh(socket_id)`, `add_mesh_peer`, `accept/deny_connection_request`, `get_all_peers`, `set_auto_accept_connection_requests`, signaux `peer_connection_established/interrupted/closed`, `incoming_connection_request`. Le `socket_id` : alphanumérique, 1 à 32 caractères. |
| Assistants GDScript « HEOS » | `HPlatform.setup_eos_async(HCredentials)`, `HAuth.login_anonymous_async(nom)` (Device ID, sans compte Epic), `HLobbies.create_lobby_async / search_by_attribute_async / join_async`, `HLobby.add_attribute / update_async / leave_async / destroy_async`. |
| Téléchargement | Releases : `epic-online-services-godot-windows-<hash>.zip` (12,6 Mo, sha256 `929d1fcb24c9f10834408f5c9fb80d76a6c942b2deadff553ff3f0ff57a30ee1`), `-linux-` (45 Mo), `-all-` (172 Mo). URL : https://github.com/3ddelano/epic-online-services-godot/releases/tag/2.3.1 |
| Limites | Le SDK Epic n'est pas dans le dépôt Git mais dans les zips de release (rien à compiler). Pas de relais « maison » : les paquets passent par le relais P2P d'Epic si le NAT bloque (réglable : `HP2P.set_relay_control`). Pas de plafond de joueurs dans le pair : notre limite à 4 est appliquée par le salon (4 places) et par `ReseauTransportEOS._sur_demande`. Le plugin n'est pas un serveur dédié : l'hôte reste un joueur. Lobbies : 64 membres max côté Epic, non limitant. |

**Non téléchargé** : je n'ai installé aucun binaire. Quand tu décides : télécharge le zip `windows` ci-dessus, compare son SHA-256 (`certutil -hashfile fichier.zip SHA256`), et copie le dossier `addons/epic-online-services-godot` dans `addons/` du projet (déjà ignoré par git, voir `.gitignore`).

Alternatives écartées : Steam (GodotSteam) = 100 $ de frais de publication ; aucun autre plugin EOS à `MultiplayerPeer` trouvé (la recherche GitHub non authentifiée n'a rien renvoyé, vérification limitée).

## 2. Ce qui a été construit (dans le dépôt)

| Fichier | Rôle |
|---|---|
| `scripts/reseau/reseau_transport.gd` | Interface étendue (valeurs par défaut = ENet inchangé) : `disponible()`, `salon_supporte()`, `preparer_async()`, `ouvrir_salon_async()`, `rejoindre_salon_async(code)`, `fermer_salon_async()`, `message`. |
| `scripts/reseau/reseau_transport_eos.gd` | `ReseauTransportEOS` : pair `EOSGMultiplayerPeer` via `ClassDB.instantiate` (aucun identifiant du plugin en dur), lecture de `user://eos.cfg`, salon. |
| `scripts/reseau/reseau_eos_adaptateur.gd` | Seul fichier qui nomme l'API du plugin (`HPlatform`, `HAuth`, `HLobbies`, `EOS`). Chargé dynamiquement, jamais lu sans plugin. |
| `scripts/reseau/reseau_transport_choix.gd` | `ReseauTransportChoix` : choix `--transport=enet\|eos`, sinon `user://reseau.cfg`, sinon ENet ; repli ENet + message si EOS indisponible. |
| `scripts/reseau/reseau_transport_salon.gd` | `ReseauSalonCode` : codes de 6 caractères (alphabet sans 0/O/1/I/L), normalisation de la saisie. |
| `scripts/reseau/reseau.gd` | **Seul fichier existant touché** : `_ready()` fait `transport = ReseauTransportChoix.depuis_arguments()` (une ligne). |
| `outils/test_transport_choix.gd` | Test headless (33 vérifications). |

### Choisir le transport
- Ligne de commande : `--transport=enet` (défaut) ou `--transport=eos`.
- Ou fichier `user://reseau.cfg` : `[reseau]` puis `transport="eos"`.
- Si EOS est demandé mais impossible (plugin absent, réglages incomplets), le jeu **retombe sur ENet** et écrit dans la console : « Transport EOS demandé mais indisponible : … Repli sur ENet (IP directe). »

### Flux d'une partie avec salon (à brancher dans le menu coop, hors périmètre du lot)
```gdscript
# Hôte
var t: ReseauTransport = Reseau.transport
var code: String = await t.ouvrir_salon_async()      # "" = échec, voir t.message
if code != "": Reseau.heberger()                     # afficher le code à l'écran
# Invité
if await t.rejoindre_salon_async(saisie): Reseau.rejoindre("")   # "" = hôte du salon
# Fin
await t.fermer_salon_async(); Reseau.deconnecter()
```
Avec ENet : `salon_supporte()` = false, on garde `Reseau.rejoindre(ip, port)`.

Mécanisme de salon EOS : l'hôte crée un lobby public (bucket `hollowrim`, 4 places) avec l'attribut `CODE` = code court et `HOTE` = son identifiant ; l'invité cherche le lobby par l'attribut `CODE`, le rejoint (réserve une place), lit le propriétaire et ouvre `create_client("hr<CODE>", <id hôte>)`. Aucune IP n'est jamais échangée ni affichée.

## 3. Assistant pas à pas : compte développeur Epic gratuit

Les libellés exacts du portail peuvent changer ; les noms ci-dessous sont ceux du portail à ma connaissance. À toi de vérifier à l'écran.

**Étape 1 : compte Epic.** https://www.epicgames.com/id/register (gratuit ; celui de Fortnite/Epic Games Store convient). Active la double authentification (2FA) : exigée pour le portail.

**Étape 2 : portail développeur.** https://dev.epicgames.com/portal → connecte-toi → accepte les conditions → crée une **Organisation** (nom libre, ex. « Killian Games »). Aucune carte bancaire.

**Étape 3 : produit.** Dans l'organisation : **Create Product** → nom « Hollowrim » (le nom ne sert qu'à l'affichage). Tu arrives sur le tableau de bord du produit.

**Étape 4 : repérer les 5 identifiants.** Menu **Product Settings** :
- **Product ID** (onglet *General*) → `product_id`.
- **Sandboxes** : il existe une sandbox « Live » (et « Stage » éventuel) ; copie son **Sandbox ID** → `sandbox_id`.
- **Deployments** : un déploiement est créé avec la sandbox ; copie son **Deployment ID** → `deployment_id`.
- **Clients** : **Add New Client**. Il faut d'abord une **Client Policy** (menu *Clients* → *Client Policies* → *Add*) : choisis le modèle « Peer2Peer » s'il existe, sinon « Custom » et active : accès *Connect* (création de compte par Device ID), *Lobby* et *P2P*. Puis crée le client avec cette policy. Une fois créé, copie **Client ID** → `client_id` et **Client Secret** → `client_secret` (le secret n'est affiché qu'une fois : note-le).
- **Identity Providers / Epic Account Services** : **inutile** pour notre usage (connexion anonyme par Device ID, sans compte Epic pour les joueurs).
- `encryption_key` : **laisser vide** (réservé au stockage de données joueur, non utilisé).

**Étape 5 : placer les identifiants (jamais dans le dépôt).** Crée le fichier texte :
`%APPDATA%\Hollowrim\eos.cfg` (ex. `C:\Users\<toi>\AppData\Roaming\Hollowrim\eos.cfg` ; le jeu utilise `config/custom_user_dir_name="Hollowrim"`, donc c'est `user://eos.cfg`). Ce dossier est hors du dépôt Git : impossible de le commiter par accident. Contenu :
```
[eos]
product_name="Hollowrim"
product_version="0.1"
product_id="..."
sandbox_id="..."
deployment_id="..."
client_id="..."
client_secret="..."
nom_joueur="TonPseudo"
```
**Ton ami doit avoir le MÊME fichier** avec les mêmes identifiants (même produit = même réseau) ; seul `nom_joueur` change. Transmets-le par un canal privé (jamais dans un message public, jamais dans Git). Remarque : le client secret finit dans chaque copie du jeu, c'est le fonctionnement normal d'EOS pour un client P2P sans serveur ; la Client Policy limite ce qu'il permet. Si le secret fuit : portail → Clients → régénérer.

**Étape 6 : plugin.** Voir section 1 (téléchargement + empreinte). Copie `addons/epic-online-services-godot` dans le projet, ouvre l'éditeur, **Projet → Paramètres du projet → Plugins**, active EOSG, redémarre l'éditeur (le plugin enregistre ses autoloads `HPlatform`, `HAuth`, `HLobbies`, `HP2P`…). Pour l'export : les DLL du plugin doivent être incluses (c'est automatique pour un GDExtension déclaré dans son `.gdextension`).

**Étape 7 : lancer.** `Hollowrim.exe --transport=eos` (ou `transport="eos"` dans `user://reseau.cfg`). Si la console dit « Repli sur ENet », lis la raison : plugin absent, fichier absent ou clé manquante (le message nomme la clé).

**Inviter un ami.** L'hôte lance en EOS, ouvre un salon : un code de 6 caractères s'affiche (ex. `K7PQ4X`). Tu le donnes à ton ami (message, vocal), il le saisit dans « Rejoindre par code ». Pas d'IP, pas de redirection de ports. (Option « ID de compte » : l'identifiant EOS de l'hôte peut être passé à `Reseau.rejoindre(<id>)` ; non exposé dans une interface, le code court suffit.)

## 4. Liste exacte de ce que TU dois faire

1. Créer le compte Epic + 2FA (étape 1).
2. Créer l'organisation, le produit, la Client Policy et le client (étapes 2 à 4) et noter les 5 identifiants.
3. Créer `%APPDATA%\Hollowrim\eos.cfg` chez toi et chez ton ami (étape 5).
4. Décider de télécharger le plugin (zip Windows ci-dessus, vérifier le SHA-256), le copier dans `addons/`, l'activer (étape 6).
5. Demander ensuite : (a) le branchement du salon dans le menu coop (champ « code » + bouton), (b) la validation à deux machines avec le vrai plugin.

## 5. Ce qui reste inconnu / à valider avec le plugin

- Noms exacts des options Lobby (`EOS.Lobby.CreateLobbyOptions`, `LobbyPermissionLevel.PublicAdvertised`), de `HLobby.available_slots` / `owner_product_user_id` : lus dans le code source mais jamais exécutés. Toute erreur sera localisée dans `reseau_eos_adaptateur.gd` seul.
- Le pair exige un « utilisateur local » (`ERR_UNCONFIGURED` sinon). Il devrait être défini après la connexion Device ID ; si `create_server` renvoie ce code, appeler le setter du plugin juste après `preparer()` (le message d'erreur guide).
- Le contenu du dictionnaire du signal `incoming_connection_request` n'est pas utilisé : on accepte/refuse en bloc selon le nombre de pairs (`get_all_peers`).
- Délais EOS (création de salon, recherche) : prévoir un indicateur « connexion… » dans l'interface ; aucun délai maximal n'est imposé par `preparer_async()` pour l'instant.
- Latence/NAT : EOS passe par un relais Epic si la connexion directe échoue ; mesurer le ressenti (parade/esquive) avec ton ami.
- Le banc à deux machines réelles n'existe pas : `outils/banc_reseau.sh` ne teste que ENet.

## 6. Tests

- `outils/banc_reseau.sh` (ENet, 2 Godot headless) : **OK** avec les nouveaux fichiers et le transport choisi par défaut.
- `outils/test_transport_choix.gd` : **TEST_TRANSPORT OK** (sélection par argument et fichier, priorité de la ligne de commande, repli propre sans plugin avec message, `creer_hote/creer_client` sans plugin = null + `ERR_UNAVAILABLE`, lecture et détection des clés manquantes de `eos.cfg`, codes de salon, échange de `Reseau.transport` sans toucher au reste, ENet sans salon).
  `godot --headless --path . --script res://outils/test_transport_choix.gd` (via `/tmp/godot_slot.sh`).
