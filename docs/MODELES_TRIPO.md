# Modèles Tripo par défaut, anciens modèles pour les factions

Depuis le 2026-11-09 (branche `integration/tripo_pnj`), les modèles Tripo validés sont ceux du jeu, **sans option** :

| Groupe (`ModelesTripo`) | Tripo (défaut) | Ancien corps (gardé, chargeable) |
|---|---|---|
| `gardes` | `GardeTripo` (`scripts/garde_tripo.gd`) : lancier `halle_o`, garde à l'épée `ronde_place`, archer `ronde_nord` | `GardesVillage.creer_modele` -> `GardienNordique` (`scripts/gardien_nordique.gd`) ; les autres gardes l'utilisent toujours |
| `jarl` | `JarlTripo` (`scripts/jarl_tripo.gd`) : Gunnar Aldrsson, corps du villageois `chef` | `PnjNordique.creer("chef")` (`scripts/pnj_nordique.gd`, pièces `assets/pnj/chef_*.res`) |
| `ennemis` | `EnnemiTripo` (`scripts/ennemi_tripo.gd`) : draugr guerrier, archer draugr, squelette à mains nues (l'archer squelette garde l'arc) | `DraugrNordique` (`scripts/draugr_nordique.gd`), `SqueletteGuerrier` (`scripts/squelette_guerrier.gd`) ; le draugr zombie et les boss gardent toujours l'ancien corps |
| `gobelin` | gobelin Tripo au guetteur de l'entrée de la grotte des bandits (`bandit_4`, `scripts/grotte_jeu.gd`) | le bandit guetteur (`GuerrierNordique`) |

Modèles Tripo : `assets/pnj/tripo_*_rig.glb` (gardes, jarl) et `assets/pnj/ennemis/tripo_*_rig.glb`. Rien de l'ancien n'a été supprimé.

## Remettre les anciens

- **Toute la partie** : argument utilisateur `--modeles-anciens` (tous les groupes) ou `--modeles-anciens=gardes,jarl,ennemis,gobelin`
  (seulement ceux listés). Exemple : `godot --path . -- --modeles-anciens=ennemis`.
- **Un seul personnage** (une faction bleue, rouge…) : un seul champ partout, `"modele_ancien": true`, dans ses données :
  - garde : sur son entrée de `data/gardes.json` ;
  - chef : sur son entrée de `data/villageois.json` (pas le champ `modele`, qui y désigne le corps Humain) ;
  - ennemi de la grotte : sur son entrée (garde le bandit au lieu du gobelin) ;
  - tout ennemi créé par `monde.creer_draugr(type, …, options)` : dans `options` (draugr -> `DraugrNordique`,
    squelette -> `SqueletteGuerrier`). Il suit le corps dans la dépouille et la sauvegarde (`spec_depouille`).
- Pour une faction entière, poser ces champs sur ses membres ; la faction elle-même reste le champ `faction` habituel (`Factions.de_donnees`).

Les options d'essai `--gardes-tripo`, `--jarl-tripo`, `--ennemis-tripo`, `--gobelin-tripo` sont désormais sans effet (acceptées).
`--gardes-tripo-en-plus` ajoute encore les trois gardes Tripo comme habitants supplémentaires (`data/habitants_tripo.json`, films).
Ne pas confondre avec `--pnj-anciens` / `--persos-anciens` : corps Humain Quaternius, plus anciens encore.

Test : `outils/test_ennemis_tripo.gd` (corps Tripo, `modele_ancien`, zombie, analyse de `--modeles-anciens=…`).
