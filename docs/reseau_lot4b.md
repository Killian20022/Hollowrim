# Réseau — lot 4b : avatar distant complet

Code : `scripts/reseau/avatar_distant.gd` (`AvatarDistant`, applique l'état reçu), `scripts/reseau/avatars_coop.gd` (`AvatarsCoop`, nœud : envoi / réception / relais / cycle de vie).
Tests : `bash outils/test_avatars.sh` (2 Godot headless, port 24821, scène `outils/test_avatars.tscn`) ; captures `bash outils/captures_avatars.sh` -> `captures/avatars/*.png` (rendu réel, fenêtres hors écran).
`proto_avatar.gd` (lot 1) est inchangé (tests lot 1 / 3).

## API
- `AvatarsCoop.installer(parent, joueur_local, nom)` : même parent et même nom (« AvatarsCoop ») sur toutes les machines (RPC par chemin). Crée `Joueur_<id>` sous `parent` au premier état/évènement d'un pair, l'inscrit au registre (`Reseau.registre.definir_noeud`), le retire à la déconnexion. `avatars` : id -> `AvatarDistant`.
- Hors du gestionnaire : `AvatarDistant.capturer(joueur)` (état compact) et `capturer_equipement(joueur, nom)`.
- État compact (RPC non fiable, 20 Hz, relayé par l'hôte) : `[pos, lacet, tangage, vitesse, drapeaux, état de combat, n° de clip, temps du clip]`. Drapeaux : accroupi, garde, à terre, mort, au sol. Lu ~100 ms en retard (interpolation).
- Équipement (évènement fiable `avatar_equip`, sur changement + toutes les 2,5 s ; l'hôte relaie) : `{nom, droite, gauche, corps:{slot:id}}`.
- Le Replicateur (autorité hôte) ne porte pas l'état des joueurs invités (propriétaire -> hôte -> autres) : on reprend son principe (binaire compact, lecture à 100 ms), pas son code.

## Ce que fait l'avatar
- Gestes : `mains.pas_manuel = true` (la machine à états locale est coupée) ; `mains.anim.clip` / `.t` et `mains.combat.forcer(état)` viennent du réseau -> `CorpsCoupsTps` rejoue la même capture de mouvement (combos, puissants, 2 mains, garde, parade). Variantes d'arme (`anim.variante`) : celles de l'équipement répliqué.
- Mains / armure : `mains.magie.eq.equiper(main, id)` et `equipement_corps.emplacements` + `change` (sans passer par le sac) -> arme / bouclier tenus (CorpsMainsTps) et pièces visibles (ArmureVisible).
- À terre : `Death01` (×1,6) tenue sur sa dernière image ; relevé = `Death01` à l'envers ×2. Mort : ragdoll de corps_joueur, position gelée ; réapparition : corps recréé.
- Nom : `Label3D` billboard, filtre nearest, contour noir, fondu de 12 à 28 m ; descend près du corps à terre / mort.

## Fichier existant touché
- `scripts/joueur.gd` : `progression.activer()` seulement si `est_local` (un avatar distant devenait la progression « courante » de la machine : perks / compétences faux). Solo identique.

## Limites
- Sorts : l'avatar montre l'arme / le sort tenu mais pas l'incantation (état de combat figé hors coups) ; flèches / arc non répliqués.
- Épée de Skarnholt = « epee » côté EquipementMains (même id que l'épée de métal) : l'avatar montre l'épée de métal.
- Cadavre : le ragdoll est local à chaque machine (pas de physique commune). Épée tenue : en pose « à terre » l'arme reste dans la main (parfois dressée).
- L'état « à terre » vient aussi de `ATerre` (évènement) ; les drapeaux de l'état compact font foi pour l'affichage.
- Test d'intégration à ajouter à `test_tout_reseau.sh` : `"test_avatars|PORT=24821 bash outils/test_avatars.sh"`.
- Les tests réseau en 2 processus attendent un créneau `godot_slot` : l'hôte patiente jusqu'à 240 s l'invité.
