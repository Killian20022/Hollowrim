# Modèles Tripo par défaut, anciens modèles pour les factions

Lot tripo/gardiens (2026-11-10) : les dix autres gardes du village et Haldor passent aussi sur les corps `GardeTripo` (mêmes glb), avec des livrées en variantes de texture.

Lot 2 (2026-11-09, branche `integration/lot2`) : armure dorée (garde `halle_e`), mage, puits et auberge h2 Tripo ajoutés, par défaut eux aussi.

Depuis le 2026-11-09 (branche `integration/tripo_pnj`), les modèles Tripo validés sont ceux du jeu, **sans option** :

| Groupe (`ModelesTripo`) | Tripo (défaut) | Ancien corps (gardé, chargeable) |
|---|---|---|
| `gardes` | `GardeTripo` (`scripts/garde_tripo.gd`) : lancier `halle_o`, garde à l'épée `ronde_place`, archer `ronde_nord` (table `GardesVillage.GARDES_TRIPO`) ; **depuis tripo/gardiens, tous les autres** : champ `"tripo"` (corps) et `"livree"` (0-3) de leur entrée de `data/gardes.json` (lanciers `so`, `n_o`, `e_n`, `tour` ; épée `n_e`, `e_s`, `ronde_rue`, `ronde_est`, `ronde_ouest` ; archer `vigie`) ; **Haldor** (villageois `garde`) en garde à l'épée, livrée 3 (`Villageois.HALDOR_TRIPO`) | `GardesVillage.creer_modele` -> `GardienNordique` (`scripts/gardien_nordique.gd`) ; Haldor : `PnjNordique.creer("garde")` (`GuerrierNordique`) |
| `jarl` | `JarlTripo` (`scripts/jarl_tripo.gd`) : Gunnar Aldrsson, corps du villageois `chef` | `PnjNordique.creer("chef")` (`scripts/pnj_nordique.gd`, pièces `assets/pnj/chef_*.res`) |
| `ennemis` | `EnnemiTripo` (`scripts/ennemi_tripo.gd`) : draugr guerrier, archer draugr, squelette à mains nues (l'archer squelette garde l'arc) | `DraugrNordique` (`scripts/draugr_nordique.gd`), `SqueletteGuerrier` (`scripts/squelette_guerrier.gd`) ; le draugr zombie et les boss gardent toujours l'ancien corps |
| `gobelin` | gobelin Tripo au guetteur de l'entrée de la grotte des bandits (`bandit_4`, `scripts/grotte_jeu.gd`) | le bandit guetteur (`GuerrierNordique`) |
| `gardes` (armure dorée, lot 2) | garde `halle_e` (poste de la halle, à côté du lancier Tripo) en **armure dorée Tripo v10** (`ArmureTripo`, `scripts/armure_tripo.gd`, champ `"armure_tripo": true` de `data/gardes.json`, canons d'avant-bras rigides) | le Gardien (`GardesVillage.creer_modele`) |
| `mage` (lot 2) | PNJ **Mage Eirwen** sur la place (`MageTripo`, `scripts/mage_tripo.gd`, entrée `tripo_mage` de `data/habitants_tripo.json`) | aucun PNJ en plus ; les mages ENNEMIS gardent toujours `MageNordique` (sauf essai `--mage-tripo`) |
| `puits` (lot 2) | **puits Tripo** profond de la place (`PuitsTripo`, `scripts/puits_tripo.gd`, `assets/essai_tripo/puits.glb`, conduit `shaders/puits_conduit.gdshader`, seau rigide) | le puits kitbash Quaternius (`MobilierVillage`, module « puits ») ; aussi `--puits-ancien` |
| `maison` (lot 2) | auberge `h2` : extérieur **chaumière Tripo** + intérieur **taverne Tripo** (`MaisonTripo`, `scripts/maison_tripo.gd`) ; emprise, porte, collisions et données inchangées | le bâti de l'auberge (`VillageBati.maison`) ; aussi `--h2-ancien` |

Modèles Tripo : `assets/pnj/tripo_*_rig.glb` (gardes, jarl, mage), `assets/pnj/ennemis/tripo_*_rig.glb`, `assets/essai_tripo/` (armure dorée, puits, chaumière, taverne). Rien de l'ancien n'a été supprimé.

## Livrées des gardes Tripo (variantes de texture)

`GardeTripo.creer(id, ressorts, collisions, variante)` : 0 = texture Tripo d'origine ; 1 « lie-de-vin » (cramoisi sombre), 2 « garance »
(rouge rouille, fer et cuir noircis), 3 « passé » (rouge délavé, fer plus clair). Textures précalculées `assets/pnj/<corps>_v1..3.png`
(`outils/generer_variantes_gardes_tripo.gd`, masque sur la teinte cramoisie du tabard ; textures d'origine intactes). Choix par poste :
deux voisins n'ont jamais le même corps ET la même livrée. La carrure (`taille`, `largeur`) des nouvelles entrées est appliquée comme
sur le Gardien ; les trois premiers gardes Tripo gardent leur échelle validée. Preuves : `outils/capture_gardiens_tripo.gd`.

## Remettre les anciens

- **Toute la partie** : argument utilisateur `--modeles-anciens` (tous les groupes) ou `--modeles-anciens=gardes,jarl,ennemis,gobelin,mage,puits,maison`
  (seulement ceux listés). `-- --sans-tripo` remet à la fois l'ancien puits et l'ancienne auberge. Exemple : `godot --path . -- --modeles-anciens=ennemis`.
- **Un seul personnage** (une faction bleue, rouge…) : un seul champ partout, `"modele_ancien": true`, dans ses données :
  - garde : sur son entrée de `data/gardes.json` (le champ `tripo` y est alors ignoré) ;
  - Haldor : sur son entrée de `data/villageois.json` (id `garde`) ;
  - chef : sur son entrée de `data/villageois.json` (pas le champ `modele`, qui y désigne le corps Humain) ;
  - ennemi de la grotte : sur son entrée (garde le bandit au lieu du gobelin) ;
  - tout ennemi créé par `monde.creer_draugr(type, …, options)` : dans `options` (draugr -> `DraugrNordique`,
    squelette -> `SqueletteGuerrier`). Il suit le corps dans la dépouille et la sauvegarde (`spec_depouille`).
- Pour une faction entière, poser ces champs sur ses membres ; la faction elle-même reste le champ `faction` habituel (`Factions.de_donnees`).

Les options d'essai `--gardes-tripo`, `--jarl-tripo`, `--ennemis-tripo`, `--gobelin-tripo` sont désormais sans effet (acceptées).
`--mage-tripo` ne sert plus qu'à l'essai « mages ennemis en mage Tripo » (le PNJ est là par défaut).
`--gardes-tripo-en-plus` ajoute encore les trois gardes Tripo comme habitants supplémentaires (`data/habitants_tripo.json`, films).
Ne pas confondre avec `--pnj-anciens` / `--persos-anciens` : corps Humain Quaternius, plus anciens encore.

Test : `outils/test_ennemis_tripo.gd` (corps Tripo, `modele_ancien`, zombie, analyse de `--modeles-anciens=…`).
