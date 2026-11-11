# Armures : qui porte encore un ancien modèle (inventaire du 2026-11-11, branche `tripo/armures`)

Ancien = corps/armure bâti par code ou Blender avant Tripo (`GuerrierNordique`, `ChasseresseNordique`, `DraugrNordique`,
`SqueletteGuerrier`, `GardienNordique`). Tripo = `GardeTripo`, `ArmureTripo`, `EnnemiTripo`, `JarlTripo`, `MageTripo`
(voir `docs/MODELES_TRIPO.md`). Rien n'est supprimé : l'ancien reste chargeable (`--modeles-anciens`, `"modele_ancien": true`).

## Déjà en Tripo (rien à faire)

- Les 14 gardes du village + Haldor (`GardeTripo` : épée, lance, archer, armure de verre `n_e`, armure dorée v10 `halle_e`).
- Jarl Gunnar (`JarlTripo`), mage Eirwen (`MageTripo`), gobelin guetteur `bandit_4`.
- Draugrs guerriers et archers ordinaires, squelettes guerriers et archers (`EnnemiTripo`).
- **Jarl Kolbeinn le Gelé** (boss de la crypte) : passé sur le corps du draugr Tripo dans cette branche (voir plus bas).

## Encore en ANCIEN modèle, classé par visibilité en jeu

| Visibilité | Qui | Où / combien | Corps actuel (ancien) |
|---|---|---|---|
| **1 - très haute** | Bandits guerriers | grotte des bandits : `bandit_0..3, 5..8` (8) | `GuerrierNordique` variante « cuirs sombres dépareillés », casque cabossé ou tête nue, cape brune (`EnnemisNordiques._bandit`) |
| **1 - très haute** | Gants / gantelets du joueur (1re personne) | toujours à l'écran quand une paire est équipée (mains FPS, `ArmureVisible._habiller_fps`) | pièces Blender HD (`assets/modeles/armures/porte/gants_*.glb`, `gantelets_*.glb`) |
| 2 - haute | Hrafn, chef des bandits (boss) | fond de la grotte des bandits (1) | `GuerrierNordique` chef : casque nasal, mante de fourrure brune |
| 2 - haute | Bandits archers | grotte : `bandit_archer_0..2` (3) | `ChasseresseNordique` variante sombre (moitié homme, moitié femme) |
| 3 - moyenne | Svanhild, Dame de givre (boss) | tertre (1) | `DraugrNordique` femme, couronne de givre, cape bleue |
| 3 - moyenne | Armure du joueur à la 3e personne | seulement en vue 3e personne (touche V, défaut = 1re personne) | toutes les pièces `porte/*.glb` skinnées sur le squelette du héros (`ArmureVisible`) |
| 3 - moyenne | Pièces d'armure posées au sol / présentoirs / butin | partout (`assets/modeles/armures/sol/*.glb`) | mêmes pièces Blender HD |
| 4 - faible | Draugr « zombie » (mains nues, clips Zombie_*) | crypte, rares | `DraugrNordique` (exclu d'`EnnemiTripo` à cause des mains nues) |
| 4 - faible | Eirik (corps allongé, tertre) et son compagnon mort (crypte) | décor (2) | `GuerrierNordique` (`PnjNordique.creer("eirik" / "garde")`) |
| hors sujet | Villageois (forgeron, chasseurs/chasseresses, paysans, volva) | village | vêtements, pas d'armure (`PnjNordique`) |

### Armure du joueur : visible ou non ?

- **Oui, mais seulement en partie au quotidien.** La note « Armure non visible sur le héros (Q4 a) » de `data/objets/armures.json` est
  périmée : depuis `rpg/armures_legeres` + `integration/tps`, `ArmureVisible` habille le héros avec `porte/<id>.glb`.
- 1re personne (vue par défaut) : seuls les **gants/gantelets** se voient (sur les bras FPS). Casque, torse, jambières, bottes : invisibles.
- 3e personne (touche V, `--vue=3`) : tout l'ensemble (tête, torse, mains, pieds, jambières).
- Inventaire : pas de mannequin ; `scripts/menu/apercu_objet.gd` montre la pièce seule (glb au sol).
- Matériaux : cuir, fourrure, os de draugr, fer, acier nordique, puis or / verre / obsidienne / rubis / saphir (HD, 2026-11-02 à 11-10 ;
  le verre v5 `bbcdcf3b` est la référence de détail validée). Ces pièces sont RÉCENTES et skinnées sur le squelette du HÉROS (pas celui
  du garde Tripo) : un remplacement Tripo demanderait un rig sur ce squelette-là et la découpe en 5 emplacements + masques d'`ArmureVisible`.

## Remplacements Tripo de cette branche

| Qui | Avant | Maintenant | Retour arrière |
|---|---|---|---|
| Jarl Kolbeinn le Gelé (boss crypte) | `DraugrNordique` + couronne à cornes + cape royale | corps **draugr Tripo** (`tripo_draugr_rig.glb`, déjà validé pour les draugrs ordinaires), épée du jeu, couronne à cornes recalée sur le heaume Tripo, cape royale, givre | `--modeles-anciens=ennemis` ou `"modele_ancien": true` dans les options du boss |

## Prochains (génération Tripo nécessaire)

Le compte développeur Tripo (clé de `~/.config/tripo/cle`) est valide mais à **0 crédit** le 2026-11-11 : aucune génération possible.
Ordre proposé dès qu'il y aura des crédits (≈ 0,65-0,95 $ par perso, plafond de session 5 $) :
1. **Bandit guerrier** (cuir sombre, fourrure, casque cabossé ; UN mannequin en T-pose, face + dos, pas d'arme, gantelets ouverts) ;
2. **Hrafn** (même cadrage, mante de fourrure de loup, casque nasal, cuir clouté) ;
3. Bandit archer (sans arc : l'arc du jeu est posé), Svanhild (corps femme), puis éventuellement le joueur.
