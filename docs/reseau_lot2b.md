# Réseau — lot 2b : monde vivant (villageois, gardes, heure, météo)

Code : `scripts/reseau/reseau_monde_vivant.gd` (classe `ReseauMondeVivant`, installée par `monde.gd` après `Vie.peupler`).
Test : `bash outils/test_monde_vivant.sh` (2 Godot headless, GODOT_MAX=2, port 24731 ; scène `scenes/test_monde_vivant.tscn`).

## Principe
- **Hôte** : IA inchangée (villageois.gd, garde_village.gd, Vie, GardesVillage, plannings depuis l'heure du cycle).
- **Invité** : chaque PNJ a `marionnette = true` (`_physics_process` retourne tout de suite) ; Vie et GardesVillage ont leur `_process` coupé. L'état (pos, `a_lacet`, `anim`, `vit`, `vis`, `mo`/`mq` = pose du corps couché/assis) vient du réplicateur à ~15 Hz, appliqué par `_appliquer_pnj`.
- Identifiants réseau : `v:<id>` (villageois, `donnees.id`) et `g:Garde_<id>` ; un scan par seconde enregistre les naissances différées.
- **Heure/météo** : l'hôte diffuse `mv_heure` {h, j, t} chaque seconde (+ instantané `Rejoindre.contributeur("monde_vivant")`). Invité : écart > 0,3 h = saut, sinon rattrape la moitié de l'écart ; le jour et la tempête sont ceux de l'hôte. `cycle.gd` divise son delta par `Engine.time_scale` en ligne : un ralenti local ne dérègle plus l'heure.
- **Cible** : `ReseauMondeVivant.joueur_proche(pos, joueur_local)` (registre `Reseau.registre.noeud(id)` + joueur local) remplace `joueur` pour tête, regard, distance, cession de passage (villageois/gardes) ; `distance_joueurs` pour les niveaux de détail (Vie, GardesVillage) afin qu'un PNJ proche d'un invité ne soit pas gelé chez l'hôte. Les interactions (E Parler, interpellation) restent sur le joueur LOCAL. Solo : `joueur_proche` renvoie `joueur`, comportement identique.
- `Reseau` est résolu dynamiquement dans `ReseauMondeVivant` : villageois.gd/cycle.gd en dépendent et certains tests `-s` les compilent avant l'enregistrement des autoloads.

## À la fusion avec 2a
- Les vrais autoloads `Replicateur` / `Rejoindre` sont utilisés d'office (`/root/Replicateur`) .
- 2a interpole elle-même (`a_` = angle). Le stub applique le dernier état sans interpolation.
- Les avatars distants doivent être inscrits : `Reseau.registre.definir_noeud(id, noeud)` (ProtoAvatar.creer ne le fait pas dans la base lot 1).

## Reporté (non traité ici)
- Lot 5 : crime/prime par joueur (Crime = dictionnaire unique), `PnjCombat` issu d'un villageois (`remplace`), dialogues/conversations E des invités (le dialogue est local), sommeil des invités, `Crime`/`Sommeil` non marionnettisés.
- Lot 3 : pause locale (`get_tree().paused`) et sommeil à vote ; le cycle est coupé quand l'hôte est dans un intérieur (`monde.gd` désactive `cycle`) : à revoir avec 2c (l'heure partagée doit continuer).
- La météo n'a qu'une variable (`Cycle.tempete`, personne ne la pilote encore) : elle est diffusée telle quelle.
