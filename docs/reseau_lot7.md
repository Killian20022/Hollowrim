# Réseau — lot 7 : latence, perte de paquets, déconnexions

Branche `multi/lot7` (base `multi/integ4`). Fichiers du lot : `scripts/reseau/simulateur_reseau.gd`, `scripts/reseau/resilience.gd`, `outils/test_resilience.{sh,gd,tscn}`, ce document, `docs/lot7_replicateur_compression.patch` (proposition, NON appliquée).

## 1. Simulateur de conditions réseau (`SimulateurReseau`)

Un `MultiplayerPeerExtension` qui enveloppe le `ENetMultiplayerPeer` (posé par `ReseauTransportENet` via `Resilience.preparer`). Il est TOUJOURS posé (compteurs et temporisations utiles en production) ; sans option il transmet les paquets tels quels.

Arguments utilisateur (après `--`), à passer aux DEUX processus :

| Option | Effet |
|---|---|
| `--sim-latence=ms` | RTT simulé : chaque processus retarde ses envois de latence/2 |
| `--sim-gigue=ms` | gigue ± (RTT), appliquée /2 par sens |
| `--sim-perte=%` | perte par sens et par paquet |
| `--sim-graine=n` | graine du tirage (reproductibilité) |
| `--debug-reseau` | journal `[RESEAU] rtt(...) env=… rec=…` toutes les 5 s |

Modèle de perte : paquet non fiable (`unreliable`, `unreliable_ordered`) = jeté pour de bon ; paquet fiable = « perdu puis retransmis » → arrive avec un retard de `max(2,5 x RTT, 120 ms)` par essai perdu, ordre des flux fiables/ordonnés conservé (blocage de tête de file, comme ENet).
API de test : `SimulateurReseau.definir(latence, gigue, perte)`, `SimulateurReseau.coupe_globale = true` (« trou noir » : tout est jeté, la liaison ENet reste vivante).

**Limites (honnêtes)** : l'enveloppe est AU-DESSUS d'ENet. ENet ne voit ni retard ni perte : son RTT (`ENet_rtt` dans les journaux, ~10 ms) et ses temporisations restent ceux de la boucle locale ; une coupure simulée ne déclenche donc pas les timeouts d'ENet (c'est la surveillance de `Resilience` qui la détecte) ; la vraie coupure se teste en tuant un processus (scénarios `depart`, `hote_perdu`). La réception n'est pas retardée (chaque émetteur applique son propre sens). Pas de réordonnancement des paquets `unreliable` autre que par la gigue.

## 2. Crochets posés hors de mes fichiers (lignes exactes)

- `scripts/reseau/reseau_transport_enet.gd` : 2 lignes (`return Resilience.preparer(pair, …)` dans `creer_hote` / `creer_client`).
- `scripts/reseau/reseau.gd` : 2 lignes : `signal hote_perdu(raison: String)` et `hote_perdu.emit("serveur_deconnecte")` en tête de `_serveur_perdu()` (avant `deconnecter()`).
- `scripts/reseau/combat_coop.gd` : 3 lignes : `"t": Time.get_ticks_msec()` dans le coup envoyé par l'invité ; `portee + Resilience.tolerance_portee(exp)` ; `Resilience.cadence_trop_rapide(cle, d, t, …)` à la place du test de cadence.
- Aucun changement de `project.godot` : `Resilience` est un nœud `/root/Resilience` créé au premier `heberger()/rejoindre()` (même chemin partout : RPC de ping).

## 3. `Resilience` : ce que le jeu peut brancher

Signaux de `Resilience.instance()` : `message(texte)`, `reconnexion_tentative(n, max)`, `reconnexion_reussie(ancien_id, nouvel_id)`, `reconnexion_abandonnee(texte)`, `retour_titre_demande(texte)`, `joueur_parti(id)`, `rtt_mis_a_jour(pair, ms)`.

### Hook « l'hôte est parti » (pour la sauvegarde personnage du lot 5b)
`Reseau.hote_perdu(raison)` est émis **avant** le retour en solo : `Reseau.est_en_ligne()` est encore vrai, le personnage (joueur, inventaire, progression) est intact → c'est le moment d'appeler la sauvegarde personnage. Raisons : `"serveur_deconnecte"` (ENet a vu la perte) ; `Resilience.derniere_raison == "silence"` si c'est la surveillance applicative (aucune réponse depuis `silence_max`). Ensuite `Reseau` passe en solo (joueurs()=[1]), `Resilience` fige les ennemis et tente la reconnexion.

### Reconnexion automatique (invité)
3 essais (`ESSAIS_MAX`), `pause_essais` (2 s) avant chaque, un essai réussit quand l'hôte répond à un ping (`delai_confirmation`). Réussite : évènement `res_reprise` (ancien id, nom) → l'hôte débranche l'ancien avatar s'il traîne et reporte nom/infos du registre sur le nouvel identifiant ; le personnage de l'invité n'a jamais quitté sa machine (modèle « chaque joueur = son personnage ») : position, inventaire, PV conservés ; `Rejoindre` ré-applique l'instantané du monde. Échec ×3 : `reconnexion_abandonnee` + `retour_titre_demande`, et retour au titre par `Jeu.relancer()` (relance du processus, seul moyen sûr) si `retour_titre_auto` (vrai par défaut) **et hors mode outil** (`Jeu.mode_outil()` : un test ou une capture garde sa scène et lit le signal). Le message est écrit dans `user://reseau_message.txt`. **À câbler côté interface** : l'écran titre doit afficher `Resilience.message_titre()` au démarrage (renvoie puis efface le message, "" sinon) ; un bandeau en jeu peut s'abonner à `message`.
Pendant la reconnexion les ennemis sont gelés (`geler_ennemis`) : sinon, Reseau repassant en solo, chaque marionnette redevient une IA locale au milieu d'un état répliqué (draugr en `ATTAQUE` sans `_attaque` → `SCRIPT ERROR` à chaque image dans `draugr.gd:562/782`, vérifié par la contre-épreuve `hote_perdu_sansgel`).

### Surveillance, temporisations
- Ping RPC non fiable 1/s (0,25 s dans les tests) dans les deux sens : `rtt[pair]` (moyenne lissée), `rtt_min/max`, `perte_mesuree(pair)` (pings restés > 2 s sans réponse ; aller + retour : 5 %/sens → ~9,75 % attendus).
- `silence_max` = 12 s : un pair qui ne répond plus à rien est déconnecté (hôte) ou l'hôte est déclaré perdu (invité). Choisi large exprès : un écran de chargement ne doit pas expulser un joueur (mesuré : un hôte et 3 invités chargés ont laissé > 3,5 s sans réponse → expulsions à tort quand le seuil était à 3,5 s).
- ENet : `set_timeout(16, 3000, 10000)` (défaut Godot : 32, 5000, 30000) → un processus tué est détecté par ENet seul en ≤ 10 s.
- `Resilience.compensation` (vrai) : compensation de latence de `CombatCoop` (voir § 5).

### Départ d'un invité (hôte)
`joueur_deconnecte(id)` → `Resilience._nettoyer_depart` : menace du parti retirée de chaque ennemi, cible rechoisie (l'hôte) si elle pointait l'avatar libéré, signal `joueur_parti(id)`. Avatar libéré par `AvatarsCoop` (existant), corps et butin restent dans le monde de l'hôte. NB : un `ENetMultiplayerPeer.disconnect_peer(force=true)` décidé par l'hôte **n'émet pas** `peer_disconnected` (constaté) : le wrapper l'annonce lui-même, sinon `SceneMultiplayer` garde un pair fantôme (« Invalid target peer », fantôme visible des autres invités).
Limite connue : si l'hôte a attribué un coffre à un invité qui part avant d'avoir reçu la réponse, le contenu est perdu (aucun accusé de réception dans `ReseauLieux`). Non traité (cas très étroit, demande un accusé côté lot 2c).

## 4. Tests (`bash outils/test_resilience.sh [motif]`, ports 25210-25223)

Verdict lu dans les journaux (`TEST_RESILIENCE <role> OK` partout, aucun `TEST ECHEC`/`SCRIPT ERROR`). Scénarios (un Godot headless par joueur) : `controle` (0 ms), `cond_100` (100 ms, gigue 20, 5 %), `cond_250` (250 ms, gigue 40, 10 %), `depart`, `hote_perdu`, `reconnexion`, `depart_enet` / `hote_perdu_enet` (détection par ENet seul), `debit2`, `debit4`, `debit2_nu/pnj/ennemis` (profil de débit). `hote_perdu_sansgel` = contre-épreuve qui ÉCHOUE exprès (lancer avec ce motif seulement).

Chaque scénario `conditions` vérifie, sous la simulation : RTT mesuré cohérent ; heure alignée à l'heure près ; coffre pris UNE fois (course simultanée) ; porte ouverte des deux côtés ; 8 coups d'invité acceptés ; PV de l'ennemi identiques ; salves de 3 coups/150 ms (12 coups) toutes acceptées ; course vers l'ennemi + frappe à 5,5 m (5/5) ; esquive / sans défense / garde levée de la victime locale (6 coups chacun) ; avatar visible à sa place (< 0,6 m).

## 5. Compensation de latence de la validation des coups (CombatCoop)

Deux faux rejets mesurés, corrigés :
1. **Portée** : l'avatar vu par l'hôte est en retard de (RTT/2 + 100 ms d'interpolation), l'ennemi vu par l'invité aussi. Tolérance ajoutée `(7 + 6 m/s) x (RTT/2 + 0,1 s)`, plafonnée à 5 m (2,9 m à 250 ms de RTT, 1,3 m même en local).
2. **Cadence** (0,1 s min.) : comparée à l'arrivée chez l'hôte, elle rejette à tort des coups légitimes que la gigue ou une retransmission fiable (un paquet perdu retient les suivants du même flux) fait arriver groupés. Les coups portent maintenant l'horodatage de l'émetteur (`"t"`) et la cadence se compare à ces horodatages ; garde-fou anti-triche : 12 coups acceptés par seconde et par cible au plus.
La parade/esquive de la victime n'a rien à compenser : la décision est prise chez elle, avec son état local à l'arrivée du message (fiable) ; mesuré 6/6 corrects dans les trois phases à 0, 100 et 250 ms.

## 6. Résultats mesurés

Dernière exécution complète (1 hôte + 1 invité, localhost, Godot 4.7.2 headless) ; tous les scénarios au vert (cond_250 relancé une fois après correction d'une course de fin de test : l'hôte partait avant le dernier « go » fiable).

| Mesure | 0 ms | 100 ms / 5 % | 250 ms / 10 % |
|---|---|---|---|
| RTT mesuré (ping RPC), hôte / invité | 11 / 8 ms | 114 / 110 ms | 265 / 255 ms |
| RTT min – max | 3 – 324 | 90 – 435 | 226 – 484 |
| perte de pings en fin de partie (aller+retour ; attendu 9,75 % / 19 %) | 6 % (démarrage) | 12 – 14 % | 15 – 21 % |
| paquets non fiables jetés / fiables retransmis (hôte, invité) | 0 / 0 | 100,88 / 11,3 | 201,197 / 24,17 |
| 8 coups espacés de l'invité | 8/8 acceptés | 8/8 | 8/8 |
| salves 3 coups / 150 ms (12 coups) : AVEC compensation | 12/12 | 12/12 | 12/12 |
| même salves SANS compensation (comportement d'avant) | 12/12 | 12/12 | **11/12** (1 faux rejet de cadence ; 2/12 sur une exécution précédente) |
| course + frappe à 5,5 m, AVEC compensation | 5/5 | 5/5 | 5/5 |
| même course SANS compensation (validation d'avant) | **0/5** | **0/5** | **0/5** |
| esquive / sans défense / garde de la victime (6 coups chacun) | 6/6 6/6 6/6 | 6/6 6/6 6/6 | 6/6 6/6 6/6 |
| coffre pris une fois, porte, heure (< 1 h), PV ennemi identiques, avatar à < 0,6 m | OK | OK | OK |

Lecture : à 250 ms / 10 %, tous les verrous d'état tiennent (les évènements d'état sont fiables : la perte ne fait que les retarder, d'environ 0,6 s par essai perdu). La validation d'AVANT le lot rejetait à tort tout coup porté en courant à plus de ~4,7 m de l'ennemi (0/5 même à 0 ms : l'avatar vu par l'hôte est en retard d'environ 0,1 s d'interpolation, soit ~1 m à 7 m/s) ; la portée de mêlée réelle des armes étant plus courte (2-3 m), l'effet réel est rare, mais la marge est nécessaire dès qu'on joue à plus de 100 ms.

Déconnexions (1 hôte + 1 invité, processus tué net par `OS.kill`, aucun paquet d'adieu) :

| Cas | Détection | Vérifié |
|---|---|---|
| invité tué en plein combat (surveillance applicative à 3,5 s dans le test) | 3,5 s | avatar retiré de la scène, de `AvatarsCoop` et du registre ; signal `joueur_parti` ; menace du parti retirée du guerrier qui le combattait, cible reprise par l'hôte ; corps non fouillé toujours fouillable (par l'hôte) ; corps déjà fouillé par le parti reste attribué (pas de doublon) ; le monde continue |
| idem, ENet seul (timeouts 3 s / 10 s de production) | 4,2 s | idem |
| hôte tué (surveillance 3,5 s) | 4,6 s | `Reseau.hote_perdu` émis avant le solo (en ligne, inventaire intact) ; retour solo propre ; 3 essais ; abandon avec message ; retour au titre demandé ; aucun `SCRIPT ERROR` (ennemis gelés) |
| idem, ENet seul | 5,2 s (dont 1 s de pause avant la mort de l'hôte) | idem |
| coupure réseau simulée de 3,5 s côté invité | détection 3,5 s | reconnexion automatique réussie au 1er essai (~3 s) ; nouvel id ; personnage inchangé (position, inventaire) ; hôte : ancien avatar remplacé par le nouveau, nom repris |
| coupure durable | 3 essais (~25 s au total) | abandon avec message ; l'hôte retire l'invité muet |

Reconnexion : ces délais sont ceux des tests (surveillance 3,5 s, pause 1 s). En production `silence_max` = 12 s, ENet 3-10 s, pause 2 s.

Rien n'a été mesuré sur Internet (localhost seulement) ; la simulation ne retarde que l'envoi.

Régressions : `banc_reseau`, `test_coop_proto`, `test_rejoindre`, `test_monde_vivant`, `test_integration2`, `test_pause_vote`, `test_projectiles`, `test_cadavres`, `test_avatars`, `test_integration4` verts avec les crochets ; `test_combat_coop` est instable sous charge (échec 1 fois sur 3 dans le worktree de base `integ5` ET dans le mien, mêmes 2 assertions « la victime a bien perdu des PV » + erreurs `draugr.gd:562/782` chez l'invité : problème préexistant, sensible à la charge CPU des autres agents) ; `test_lieux.sh` écrit dans des journaux fixes `/tmp/lieux_*.log` partagés entre agents (verdict de l'invité illisible quand deux lancements se chevauchent).

## 7. Budget de bande passante : DÉPASSEMENT

Plan : ~15 Ko/s par invité, ~50 Ko/s d'envoi pour l'hôte. Mesuré (charge utile + estimation « filaire » = +40 o/paquet), scène de test : joueurs qui courent en cercle et frappent, 12 villageois qui marchent, 6 guerriers éveillés :

| | par invité (hôte→invité) | hôte total (envoi) | invité (envoi) |
|---|---|---|---|
| 2 joueurs | 53,1 Ko/s | 53,1 Ko/s (pic 63) | 2,9 Ko/s |
| 4 joueurs (hôte + 3) | 56 Ko/s | 167,9 Ko/s (pic ~207) | 7,1 Ko/s |

Profil (2 joueurs) : avatars seuls 2,2 Ko/s ; + 12 villageois qui marchent : 34,6 Ko/s (≈ 2,7 Ko/s par PNJ en mouvement) ; + 6 ennemis éveillés : 20,6 Ko/s (≈ 3,2 Ko/s par ennemi). Cause : le `Replicateur` envoie un `Dictionary` encodé par `var_to_bytes` (clés en chaînes de caractères, ≈ 180 o par état) à 15 Hz par entité en mouvement : le budget de 15 Ko/s ne tient que pour ~5 entités mobiles dans la zone de pertinence (90-120 m) ; un village animé le dépasse d'un facteur 3 à 4. Le débit hôte (≈ 3 x 56) dépasse aussi 50 Ko/s dès 3 joueurs.
**Remède mesuré** (non appliqué : fichier du lot 2a) : compresser chaque lot du `Replicateur` en ZSTD avant l'envoi (`docs/lot7_replicateur_compression.patch`, 8 lignes) : 34,3 → 10,6 Ko/s pour les 12 villageois (÷ 3,2), les clés répétées se compriment très bien. Autres pistes : 15 → 8 Hz au-delà de 40 m, clés numériques, positions quantifiées, rayon de pertinence plus court pour les PNJ.
