# Réseau — lot 4d (gore, ragdoll, cadavres, butin des corps, faune)

Code : `scripts/reseau/reseau_corps.gd` (`ReseauCorps`, nœud sous la racine créé par `CombatEnnemi._installer`, inerte en solo) + crochets dans
`ennemi_base.gd` / `draugr.gd` (`_mourir`, `_laisser_butin`), `combat_ennemi.gd`, `ragdoll.gd`, `butin.gd`, `faune.gd`.
Test : `bash outils/test_cadavres.sh` (2 Godot headless, `GODOT_MAX>=2` — les créneaux /tmp/godot_slot_N.lock sont PARTAGÉS entre agents : mettre 6 si d'autres tests tournent).

## Mort et gore
- `ReseauCorps.arbitrer_mort(ennemi, decisions, f_contenu)` est appelé dans `_mourir` après les tirages (membre tranché, décapitation, sort, force/os/montée du ragdoll,
  point, direction…). Solo : renvoie `decisions` (comportement identique). Hôte : ajoute une graine (`Demembrement._rng.seed`), le contenu du butin, puis diffuse
  l'évènement `corps_mort` (id = ident de l'ennemi). Invité : `_sur_mort` retrouve l'ennemi par `ident`, pose `plan_impose` et rejoue `_mourir` ; `arbitrer_mort`
  renvoie alors le plan reçu (même membre/décapitation/impulsions/graine ; réglage gore local à 0 = pas de coupe). Les ennemis doivent avoir le MÊME `ident` partout.
- `ReseauCorps.suivre_ragdoll(ident, ragdoll)` (après `declencher`) : plafond `ReseauCorps.max_ragdolls` (8) ragdolls actifs EN LIGNE (le plus ancien est figé tout de suite) ;
  l'hôte envoie `corps_repos` (bassin + tête) quand son corps se fige (`Ragdoll.fige`) ; l'invité fige le sien (au plus 8 s) puis `Ragdoll.recaler(bassin, tete)`
  (rotation autour de Y + translation de tous les os, même figés). `Ragdoll.forcer_figer()` / signal `fige` / `recaler()` sont nouveaux.

## Butin des corps (« premier arrivé »)
- `Butin.cle_reseau = "corps:<ident>"` (posée par `_laisser_butin`). `fouiller()` en ligne passe par `ReseauLieux.reclamer(cle, gagné, perdu, "corps")` : le gagnant ouvre la
  fenêtre (il peut rouvrir : `gagnant`), les autres voient le corps vidé (`perdre_fouille`). Les pièces : `reclamer(cle + ":or")` au moment du versement, les autres perdent la gerbe (`perdre_or`).
- Contributeur `Rejoindre` « cadavres » : `ReseauCorps.exporter()` = corps encore fouillables (modèle décrit, objets restants, non pris) ; `importer()` les repose en dépouille statique
  chez le nouvel invité. Limite : seuls les corps décrits par `modele_spec` (draugrs) sont exportés ; un corps pris par un autre est exclu (`ReseauLieux.deja_pris`).
- `ReseauCorps.contenu_de(ident, repli)` : le contenu du butin tiré par l'hôte remplace le tirage local (ennemi_base : `randi`).

## Faune (`faune.gd`)
- Hôte (et solo) : logique inchangée. Invité (`basculer_reseau(true)`, déclenché par `ReseauCorps` au changement de rôle) : plus d'apparition ni de `_tour` ; bêtes sauvages locales retirées,
  celles de l'hôte arrivent par `faune_spawn` {slot, membres[{ident, espece, pos, lacet, opts}]} (créées via `fabrique`) et l'instantané « faune » ; `faune_retire` à la disparition.
- Toutes les bêtes (domestiques déjà présentes des deux côtés + sauvages) sont enregistrées au `Replicateur` sous `b:<ident>` : pos, `a_lacet`, clip, vitesse, appliqués en marionnette
  (`set_physics_process(false)`). Mort : `faune_mort` {pos, dir, contenu butin} → l'invité joue `_mourir` (clip Death / MortAraignee) avec le MÊME contenu ; la fouille de la bête passe par le butin ci-dessus.
- La cible des bêtes (joueur le plus proche) reste au lot 4a ; il n'y a pas d'oiseaux ni de dépeçage dans le jeu (le « dépeçage » = fouille du butin du corps).

## Effets de coup
- `CombatEnnemi.effets_impact` appelle `ReseauCorps.diffuser_impact` : l'hôte (qui valide le coup) envoie `corps_impact` ; les invités rejouent sang, gerbe, étincelles, sons
  (`ReseauCorps.jouer_impact`, sans réaction ni arrêt sur image). `info["qui"]` (pair de l'attaquant, à poser par le lot 4a) évite de rejouer chez lui un effet déjà joué.

## Limites connues
- Mort « titubante » : le tirage des morceaux/ragdoll se fait 0,38 s après ; la graine est posée à l'annonce (deux morts dans cette fenêtre partagent le générateur).
- Les cadavres d'ennemis sans `ident` ne sont pas répliqués. Cadavre figé recalé par bassin + direction tête seulement (pas pose os par os).
- Les entités ennemies elles-mêmes (marionnettes, positions) = lot 4a ; ici seul le rejeu de la mort suppose que l'ennemi existe chez l'invité avec le même `ident`.
