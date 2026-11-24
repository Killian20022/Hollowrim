# Coop : PvP (sorts, télékinésie, flèches entre joueurs)

Réglage `pvp` : actif par défaut ; case « Combat entre joueurs (PvP) » dans Multijoueur > Héberger (choix de l'hôte, sauvegardé dans
`user://multijoueur.cfg`, section `multi`, clé `pvp`, diffusé aux invités par `pvp_reglage`, rediffusé toutes les 3 s). Argument `--sans-pvp`
(après `--`) : PvP coupé pour cette instance (rien ne passe, comme avant : aucun tir allié).

## Code
- `scripts/reseau/pvp_coop.gd` (`PvpCoop`) : cibles (`cibles`, `avatars_cibles`, `pvp_cible`), coups (`coup`, `frapper_sort`, `coup_fleche`, `coup_objet`),
  états (`op` : tenir / projeter / lacher), validation hôte, évènements `pvp_coup`, `pvp_op`, `pvp_reglage`.
- `scripts/reseau/pvp_victime.gd` (`PvpVictime`, enfant du joueur local) : perte de contrôle pendant la saisie, vol balistique après le lancer,
  dégâts d'impact limités (jamais mortels), ralenti à l'atterrissage.
- Branchements minimaux : `lanceur_sorts.gd` (`PvpCoop.cibles` à la place de `Elements.cibles_dans`, `frapper` route vers `PvpCoop.frapper_sort`),
  `zone_magie.gd`, `projectile_sort.gd` (candidats), `projectile.gd` (flèche du joueur), `sorts_esprit.gd` (un avatar = marionnette : `_envoyer_ennemi` -> `PvpCoop.op`),
  `telekinesie.gd` (objets lancés qui percutent un joueur), `ecran_multi.gd` (case), `reseau_projectiles.gd` (installation).

## Autorité
L'attaquant (hôte ou invité) demande ; l'hôte valide (PvP actif, pairs connus, victime debout, portée 160 m, cadence 30 ms, dégâts bruts <= 120)
puis applique : dégâts × 0,6, plafonnés à 40 % de la vie max de la victime (pas de one-shot). Le coup est résolu CHEZ LA VICTIME
(`CombatCoop.EV_SUBI` : armure, garde, esquive, mise « à terre » par `ATerre`, relevable). Les dégâts continus (rayons, souffles) sont regroupés
par 0,12 s côté attaquant. Saisie (lévitation / vortex d'attraction) : l'attaquant envoie `tenir {p}` à 10 Hz, l'hôte route vers le propriétaire
de l'avatar qui perd le contrôle (`en_dialogue`) et suit le point ; sans nouvelle depuis 0,6 s il retombe ; `projeter` / `lacher` = impulsion.

## Limites connues
- Statuts de sort (brûlure, gel prolongé, etc.) non appliqués aux joueurs : seuls dégâts, recul, ralenti (gel) et secousse (choc).
- Mêlée entre joueurs et armes lancées « à la main » (`arme_lancee.gd`) non traitées (hors chantier) ; armes/objets télékinésés : oui.
- Pas de ragdoll de l'avatar visé (le joueur n'en a pas) : vol balistique + chocs.
- Jamais testé sur 2 PC / Internet (localhost, headless).

## Tests
`bash outils/test_pvp.sh [pvp|sans]` : 2 instances ; passe PvP (boule de feu, éclair en chaîne, rayon noir, glace, flèche dans les deux sens, répulsion,
saisie + lancer par lévitation, coups falsifiés refusés/plafonnés) puis passe `--sans-pvp` (rien ne touche, pas de saisie). `test_projectiles.sh` passe désormais `--sans-pvp`
(ses scénarios supposent l'absence de tir allié).
