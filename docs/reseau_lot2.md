# Réseau — lot 2 : réplicateur et rejoindre en cours de partie

Deux autoloads (project.godot) : `Replicateur` (`scripts/reseau/replicateur.gd`) et `Rejoindre` (`scripts/reseau/rejoindre.gd`).
Solo / hors ligne : ils ne font rien (aucun coût, aucun effet de bord).

## Replicateur : états continus (positions, vie, animation…)
L'hôte détient l'IA et envoie, chez chaque invité, l'état binaire des entités enregistrées ; l'invité applique en marionnette.
**Le même code d'enregistrement tourne chez tout le monde** (génération déterministe) : mêmes identifiants stables partout.

```gdscript
Replicateur.enregistrer(id: Variant, noeud: Node, fournisseur: Callable, appliquer: Callable, pertinence_m := 90.0)
Replicateur.retirer(id)            # à appeler quand l'entité disparaît (aussi automatique si le nœud est libéré)
Replicateur.est_marionnette()      # vrai chez un invité : IA/physique de l'entité à couper
Replicateur.diffuser(type, id, donnees, vers := 0, local := true)   # évènement ponctuel : applique en local PUIS envoie
```
- `fournisseur: Callable() -> Dictionary` (appelé chez l'hôte seulement, ~15 Hz). Garder l'état PETIT : nombres, Vector3, bool, String courts.
- `appliquer: Callable(etat: Dictionary) -> void` (chez l'invité seulement, à chaque image, avec l'état INTERPOLÉ ~100 ms en retard).
- Interpolation générique : `float`, `Vector2`, `Vector3` interpolés ; une clé qui commence par `a_` est un angle (lerp_angle, radians) ;
  tout le reste (int, bool, String, Array…) prend la valeur de l'échantillon le plus récent. Ex. : `{"pos": Vector3, "a_lacet": float, "vie": float, "anim": "marche"}`.
- `pertinence_m` : distance (m) entre l'entité (`noeud.global_position`) et l'avatar du pair (`Reseau.registre.noeud(peer)`) au-delà de laquelle
  RIEN n'est envoyé à ce pair ; 0 = toujours envoyé ; avatar du pair inconnu = tout est envoyé. Hors pertinence, la marionnette garde sa dernière valeur
  (à l'appelant de la cacher/geler si besoin : `Replicateur.est_pertinent(id, peer)` côté hôte).
- Transport : un RPC `unreliable_ordered` (canal 1) groupé par paquets ≤ ~1 Ko par pair ; un état identique au précédent n'est pas renvoyé (rappel toutes les 1 s).
  À la connexion d'un invité, tout lui est renvoyé.
- Entités créées en cours de partie (projectiles, butin lâché) : l'hôte envoie un évènement `diffuser("spawn_xxx", id, …)` ; chaque machine crée l'entité puis `enregistrer`.
- Les évènements ponctuels (mort, coup, ouverture de porte, ramassage) passent par `Reseau.envoyer_evenement` : **call_remote**, l'émetteur doit appliquer
  l'effet en local lui-même -> `Replicateur.diffuser` fait les deux.

## Rejoindre : instantané à la connexion
Quand un invité se connecte, il demande un instantané à l'hôte (`rejoindre_demande`) ; l'hôte appelle l'`exporter` de chaque contributeur, compresse et
envoie (fiable) ; l'invité appelle l'`importer` de chaque contributeur (dans l'ordre d'enregistrement). Si le contributeur n'est pas encore enregistré
quand l'instantané arrive (scène en chargement), les données attendent et sont importées à l'enregistrement.
```gdscript
Rejoindre.contributeur(nom: String, exporter: Callable() -> Dictionary, importer: Callable(donnees: Dictionary))
Rejoindre.retirer_contributeur(nom)
Rejoindre.instantane() -> Dictionary        # {nom: exporter()} (hôte)
Rejoindre.instantane_applique : signal(noms: Array)
```
Données : `Dictionary` de Variants simples (pas d'objets ni de nœuds) ; réutiliser les `exporter()/importer()` des systèmes (formats de sauvegarde).
Contributeurs branchés : `monde` (monde.gd : heure, jour, butin = graine/contenants pillés/uniques pris, ids des morts). À brancher : 2b (`vie`, `crime`,
`sommeil`, météo…), 2c (`contenants`, `portes`, `salle`…). Une fois l'hôte seul à décider, l'importer d'un contributeur doit être idempotent.

## Tests
`bash outils/test_rejoindre.sh` : 3 Godot headless (hôte + 2 invités, GODOT_MAX=3) ; invité qui rejoint après modifications, 3 joueurs, déconnexion/reconnexion,
pertinence par distance, interpolation.
