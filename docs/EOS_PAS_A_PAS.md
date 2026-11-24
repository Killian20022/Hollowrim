# Jouer par Internet avec un code (Epic Online Services, gratuit)

But : toi (Grenoble) et ton ami (Montpellier), sans IP, sans réglage de box. Tu héberges, un code de 6 caractères s'affiche
(ex. `K7PQ4X`), ton ami le tape dans « Rejoindre avec un code ». Le relais est celui d'Epic (gratuit, pas de carte bancaire).
Une seule personne crée le compte Epic : toi. Ton ami reçoit simplement le fichier `eos.cfg`.

Le plugin (EOSG 2.3.1) est DÉJÀ dans le jeu. Il ne reste que le compte et le fichier `eos.cfg`.

## A. Créer le compte et le produit (une seule fois, ~15 min)

1. https://www.epicgames.com/id/register : crée un compte (ou connecte-toi avec celui de Fortnite / Epic Games Store).
   Active la double authentification (Paramètres du compte > Mot de passe et sécurité). Le portail l'exige.
2. https://dev.epicgames.com/portal : connecte-toi, accepte les conditions, crée une **Organisation** (nom libre, ex. « Killian Games »).
3. Dans l'organisation : **Create Product** > nom « Hollowrim ». Tu arrives sur le tableau de bord du produit.
   Les libellés du portail peuvent légèrement changer ; cherche les mots anglais cités.

## B. Autoriser ce qu'il faut (Client Policy + Client)

4. Menu de gauche **Product Settings** > **Clients**.
5. Onglet **Client Policies** > **Add New Client Policy** (ou « Create ») :
   - modèle **Peer2Peer** s'il existe, sinon **Custom** ;
   - coche **Connect** (création d'identité par Device ID), **P2P**, **Lobbies** (si une liste « Features » existe, coche aussi « Lobby » et « Create/Join »).
   - Pas besoin d'« Epic Account Services » : les joueurs n'ont PAS besoin de compte Epic.
6. Onglet **Clients** > **Add New Client** : nom « HollowrimClient », choisis la policy du point 5, enregistre.
7. Dans **Product Settings** > **Identity Providers** (ou « Connect ») : vérifie que **Device ID** est activé / autorisé
   (si la page propose « Device ID » dans une liste d'identités externes, active-le). C'est ce qui permet de se connecter sans compte.

## C. Copier les 5 identifiants

| Où dans le portail | Valeur | Clé dans eos.cfg |
|---|---|---|
| Product Settings > General (ou la page d'accueil du produit) | **Product ID** | `product_id` |
| Product Settings > Sandboxes : la sandbox « Live » | **Sandbox ID** | `sandbox_id` |
| Product Settings > Sandboxes > Deployments (ou « Deployments ») | **Deployment ID** | `deployment_id` |
| Product Settings > Clients : ton client | **Client ID** | `client_id` |
| Product Settings > Clients : ton client | **Client Secret** (affiché UNE fois : copie-le tout de suite) | `client_secret` |

Laisse `encryption_key` absent.

## D. Le fichier eos.cfg

Crée un fichier texte nommé exactement `eos.cfg` (pas `eos.cfg.txt` : dans l'Explorateur, Affichage > Extensions de noms de fichiers) :

```
[eos]
product_name="Hollowrim"
product_version="0.1"
product_id="COLLE_ICI"
sandbox_id="COLLE_ICI"
deployment_id="COLLE_ICI"
client_id="COLLE_ICI"
client_secret="COLLE_ICI"
```

Garde les guillemets. Place-le **à côté de `Hollowrim.exe`** (dans le même dossier). Variante : dans `%APPDATA%\Hollowrim\eos.cfg`.
Le fichier à côté de l'exe passe en premier.

**Ton ami met exactement le même fichier à côté de son exe** (mêmes identifiants = même réseau). Envoie-le-lui en privé
(message direct, pas de salon public, pas de dépôt Git) : il contient le Client Secret. S'il fuit : portail > Clients > régénère le secret
et renvoie un nouveau fichier.

## E. Jouer

1. Toi : Multijoueur > **Héberger par Internet (code)** > ton nom > **Ouvrir le salon**. Le code s'affiche. Envoie-le à ton ami.
2. Ton ami : Multijoueur > **Rejoindre avec un code** > saisit le code et son nom > **Rejoindre le salon**.
3. Toi : **Lancer la partie** quand il est dans la liste.

Messages possibles :
- « Jeu par Internet non configuré : placez le fichier eos.cfg… » : le fichier n'est pas à côté de l'exe (ou mal nommé).
- « eos.cfg incomplet : il manque … » : une des clés est vide ou absente.
- « EOS : initialisation refusée » : un identifiant est faux (recopie sans espace) ou la Client Policy est mal réglée.
- « connexion anonyme (Device ID) refusée » : le Device ID n'est pas autorisé (point 7) ou pas d'accès Internet.
- « Aucun salon avec le code … » : code mal recopié, ou l'hôte n'a pas (ou plus) son salon ouvert.
- Pare-feu Windows : accepte l'autorisation si Windows la demande au premier lancement.

Les fichiers `EOSSDK-Win64-Shipping.dll` et `xaudio2_9redist.dll` livrés avec le jeu doivent rester dans le même dossier que l'exe.

## F. Si ça ne marche pas

Lance `Hollowrim.exe --debug-reseau` depuis un terminal et envoie la console. Le jeu retombe seul sur l'adresse IP (ENet) si EOS est
indisponible ; les boutons « par Internet » expliquent alors ce qui manque.
Sources : https://dev.epicgames.com/docs (Epic Online Services, « Getting Started »), plugin
https://github.com/3ddelano/epic-online-services-godot.
