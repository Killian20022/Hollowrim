# Plan : finir la carte de base avant l'agrandissement (décidé le 2026-10-20)

Objectif utilisateur : que TOUT soit propre sur la carte actuelle (240 m) avant de passer, plus tard, à 1 km² avec
2 autres biomes. Règle machine : au plus 2 agents Godot en parallèle quand l'utilisateur travaille.

## En cours
1. Maisons/village, 2e passe « réalisme 32 bits » (worktree nordique_lot5).
2. Crypte, 2e passe « réalisme 32 bits » (worktree nordique_lot7).

## File d'attente (dans l'ordre, dès qu'une place se libère)
3. Troncs d'arbres « réalisme 32 bits » : écorce plus fine et plus nuancée, relief, racines, AO, mousse/neige
   (nordique_lot2 ; arbres.gd / textures_arbres.gd ; rameaux inchangés).
4. Intérieurs des maisons, SANS chargement (on passe la porte, on est dedans) : les 5 bâtiments du village
   (longue maison de la cheffe, 3 maisons, forge), chacun cohérent avec son occupant, même style que la crypte et le
   village (kit modulaire nordique, Macro/Méso/Micro, lumières seulement actives quand on est dedans). Après fusion
   de la 2e passe du village (village.gd partagé). Worktree nordique_kit.
5. Crypte agrandie ×7-8 : les salles actuelles deviennent l'entrée d'un vrai donjon (ailes, ossuaire, galeries
   gelées, niveau inférieur, passage secret, arène du boss), quête actuelle conservée (levier, herse, Eirik,
   Svanhild), plus de draugrs et de butin. Après fusion de la 2e passe crypte (mêmes fichiers).
6. Lot 7 : brouillard de distance ~50 m + lumière du jour.
7. Grotte vitrine, lots 4 (personnages) et 6 (objets tenus).

## Plus tard (à terme)
- Phase 3 / agrandissement à ~1 km² avec 2 nouveaux biomes (docs/SOCLE_TECHNIQUE.md : chunks, MultiMesh, lumières).
- Faune, ennemis, gameplay.
