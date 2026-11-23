# Foudre v2 (branche magie/foudre_v2, 2026-11-23)

Retour utilisateur : « le sort en lui-même est bien, ce sont les animations qui sont trop anarchiques et pas très belles ».
Références (principe seulement, aucun asset) : `references/foudre/` (The Force Unleashed 1 et 2, Battlefront II Palpatine,
Skyrim « All Lightning Spells ») et leurs planches `references/foudre/planches/`.

Code : `scripts/magie/foudre_v2.gd` (`FoudreV2`), `shaders/foudre_v2.gdshader`, branchements dans `gestion_magie.gd`
(`_jet_creer` / `_foudre_placer` / `_jet_arreter`, `_chaine_v2` / `_maj_chaines`, `foudre()`, `eclair()`, `_gen_main_v2`),
`noyau_ecole.gd` (lueur réduite), `elec_corps.gd` (moins de rampes et d'étincelles sous l'arc), `sons_magie.gd` (`claquement`).
La logique des sorts (dégâts, coûts, portées, statut choc, coop) n'est pas touchée : seul le rendu change.

## Ce qui change
- **Forme** : un tronc (cœur blanc-bleu 2 px, halo bleu au milieu / violet au bord 4-5 px) + 2-4 branches + filaments ;
  nervures d'un bruit de valeur fractal à interpolation linéaire (coudes nets, une seule direction générale).
- **Rythme** : chaque arc garde sa forme 2 à 4 images (`REGEN_MIN/MAX`), puis en prend une neuve ; l'ancienne reste 1-2
  images en rémanence (`REMANENCE`) ; l'éclat retombe par paliers (`ECLAT_AGE`) et la lumière du jet suit cet éclat.
  Entre deux formes, le maillage est seulement recalé sur ses deux bouts (pas reconstruit).
- **Arc électrique (canalisé)** : `FoudreV2.Canal`, 4 arcs (5 en double) qui partent des BOUTS DES DOIGTS (os
  `*_02/03_l|r` du squelette des mains, repère de l'accroche de la main), s'écartent en cône puis convergent et
  ACCROCHENT des os du corps visé (gardés 2-3 formes, suivis chaque image) ; petites griffes sur le corps ; éclats et
  claquement aux nouvelles formes ; la décharge texturée et le faisceau de la v1 ne sont plus créés.
- **Convulsions** : `FoudreV2.convulser` : impulsions de 0,11 s vers une image d'une réaction CAPTURÉE de la cible
  (Hit_Chest / Hit_Head de son AnimationPlayer), haut du corps seulement, par un SkeletonModifier3D (purement visuel).
- **Chaîne d'éclairs** : chaque saut apparaît 0,06 s après le précédent avec une image d'éclat plein, se reforme par
  à-coups, s'éteint avec des trous ; arc compagnon fin.
- **Main au repos** : 1-3 petits arcs doigt -> doigt / poignet / paume (parfois aucun), lueur du noyau réduite.
- **Autres éclairs électriques** (orage runique, tempête, statut choc, lancer d'école) : même shader, même nervure
  fractale, même cadence (`eclair()` / `foudre()` quand la teinte est l'électricité).
- **Ennemis** (mage) : mêmes fonctions de GestionMagie, même rendu. TPS / avatars : doigts du squelette si l'origine est
  sous une accroche d'os, sinon éventail de 5 points devant la paume.

## Comparer / vérifier
- `-- --foudre-v1` (ou `GestionMagie.foudre_v1 = true`) : ancien rendu.
- Test : `godot --headless --fixed-fps 60 --path . --script res://outils/test_foudre_v2.gd -- --nouvelle`
- Film / mesure (fenêtre hors écran via godot_slot.sh) : `outils/film_foudre.gd` (`--perf` : alternance v1/v2 dans la
  même séance, FPS repos / canalisation).
- Sons : `bash outils/sons_magie/generer_foudre.sh`.
