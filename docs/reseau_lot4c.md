# Réseau — lot 4c : magie, arc, projectiles, pièges, mécanismes

Code : `scripts/reseau/reseau_projectiles.gd` (`ReseauProjectiles`, statique, paresseux ; solo = no-op). Test : `bash outils/test_projectiles.sh` (2 Godot headless, port 24831, `GODOT_MAX>=2`).
`ReseauProjectiles.installer()` (idempotent) abonne les évènements ; appelé par `ArcJoueur._ready`, `MainSort._ready`, `Mecanisme.Base._ready`.

## Principes
- Trajectoire déterministe : l'émetteur annonce `proj_spawn` / `sort_spawn` ; chaque machine fait voler sa COPIE (`Projectile.distant = true`, `id_reseau`). L'invité envoie à l'hôte, qui relaie aux autres.
- Dégâts sur ennemis : seule la copie du tireur touche. Invité : `proj_coup` / `sort_coup` (id de cible, dégâts, point) ; l'hôte valide (pair connu, cible vivante, plafond de dégâts, distance, cadence) puis applique (`DegatsCombat`, `LanceurSorts.infliger_distant`).
- Dégâts sur joueurs : la VICTIME décide. Projectiles et zones ennemis annoncés par l'hôte, rejoués chez chacun, ne touchent que le joueur LOCAL. Les avatars sont exclus des rayons (`exclus_avatars`) ; `LanceurSorts.frapper` ne frappe jamais un avatar.
- Pas de tir allié : flèches/sorts/zones du joueur ignorent les avatars. Soin et protection canalisés : alliés à < 6 m (`soigner_allies`, 75 % ; `proteger_allies`, 50 % de la réduction, aura de 0,7 s consommée par `MainSort.absorber` via `absorber_allie`).
- Identifiant de cible : `id_reseau` (propriété ou méta, à poser par le lot ennemis) sinon `ident` (« i:… ») sinon nom du nœud (« n:… »).
- Pièges : l'hôte arbitre la dalle (déclenchée par tout joueur : locaux + avatars), diffuse `declenche`/`tir`/`arme` ; chaque machine fait voler sa fléchette, qui ne blesse que son joueur local. Souffle de givre : phase de l'hôte diffusée toutes les 2 s ; chacun blesse son joueur local.
- Mécanismes (statues, braseros, socles, mur fragile) : invité -> `meca_demande` ; l'hôte accepte (`accepter_demande`), applique (`appliquer_distant`, conséquences/`on_fini` arbitrées par l'hôte seul) et diffuse `meca_evt`. Socle : l'objet n'est consommé qu'à la confirmation, chez celui qui l'a posé. Les portes passent toujours par `ReseauLieux`.

## Limites
- Non couverts : jets canalisés (visuel chez les autres), rayon du néant, drain/vol de vie vers un avatar, protection avec cône, zones persistantes ennemies, `PnjCombat`/archer Tripo (passent par `Projectile.tirer` donc OK si hôte). Dialogues d'un invité pour braseros (mauvais ordre) non renvoyés.
- Mise à l'échelle PV/dégâts selon le nombre de joueurs : non faite ici (lot ennemis).
- `ReseauProjectiles.refuses` / `journal` : compteurs de test.
